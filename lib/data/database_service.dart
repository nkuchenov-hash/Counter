import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/link_scalar.dart';
import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/local_sync/plan_create_outbox.dart';
import 'package:counter/data/local_sync/sync_manager.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:rrule/rrule.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/features/profile/wall_clock.dart' as wall_clock;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'profile_service.dart';
part 'plan_service.dart';

// Brain: PocketBase for profiles, records, categories, plans, tags.
// Wear OS DataClient / MethodChannel: only under lib/features/wear/ — nothing here sends to the watch.

/// Isolate target for prefs snapshot encoding (keeps main isolate clear during large jsonEncode).
String _encodeRecordsFlatForPrefs(List<Map<String, dynamic>> rows) => jsonEncode(rows);

class _BuildNode {
  _BuildNode(this.label);
  final String label;
  int totalSeconds = 0;
  final Map<String, _BuildNode> children = {};
  final Map<String, List<Map<String, dynamic>>> sessionGroups = {};
}


/// In-memory only: timeline shows [endUtc] until server confirms or optimistic layer is cleared.
class _OptimisticEndPatch {
  _OptimisticEndPatch(this.endUtc);
  final DateTime endUtc;
}

/// Legacy `record_id` / UI doc id could not be mapped to PocketBase **15-char** row `id` (@DATA_MAP).
/// Never send this value as the REST path segment.
class LegacyIdResolutionException implements Exception {
  LegacyIdResolutionException(this.docId);
  final String docId;
  @override
  String toString() => 'LegacyIdResolutionException($docId)';
}

/// PocketBase auth record id is required for mutating API calls (`user_id` on child rows).
class AuthenticatedUserIdRequiredException implements Exception {
  AuthenticatedUserIdRequiredException([this.message =
      'PocketBase auth record id is null or empty; refusing mutating request.']);
  final String message;
  @override
  String toString() => message;
}

/// App backend AI route returned an error or unusable payload (e.g. Smart Plan batch).
class AiBackendException implements Exception {
  AiBackendException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Noco may return `is_done` as bool, 0/1, or string.
bool _jsonBoolFromDynamic(dynamic v) {
  if (v == true) return true;
  if (v == false) return false;
  if (v == 1) return true;
  if (v == 0) return false;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return false;
}

String? _normPlanInitialDateKey(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.length >= 10) return s.substring(0, 10);
  return null;
}

/// Re-subscribes PocketBase `records` realtime and refreshes cache after OS resume (mobile WebSocket drop).
class _DatabaseServiceLifecycleObserver with WidgetsBindingObserver {
  void Function()? onResumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed?.call();
    }
  }
}

/// True when a flattened **categories** row should participate in the active tree / uniqueness checks.
bool _categoryFlatRowIsActive(Map<String, dynamic> row) {
  final fields =
      row['fields'] is Map ? Map<String, dynamic>.from(row['fields'] as Map) : row;
  final archRaw = row['is_archived'] ?? fields['is_archived'];
  if (_jsonBoolFromDynamic(archRaw)) return false;
  final st =
      (row['status'] ?? fields['status'] ?? '').toString().trim().toLowerCase();
  if (st == 'archived' || st == 'deleted') return false;
  return true;
}

/// O(#running) rollback for Highlander local apply (avoids cloning the full flat cache).
class _HighlanderRollbackToken {
  _HighlanderRollbackToken({
    required this.runningSnapshotsByIndex,
    required this.appendedPendingRow,
  });
  final Map<int, Map<String, dynamic>> runningSnapshotsByIndex;
  final bool appendedPendingRow;
}

String _two(int n) => n.toString().padLeft(2, '0');
String _dateKeyFromDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static final _DatabaseServiceLifecycleObserver _appLifecycleObserver =
      _DatabaseServiceLifecycleObserver();
  static bool _appLifecycleObserverRegistered = false;

  /// Sacred Law: at most this many **pre-today** open rows merged after today’s candidates (singleton
  /// implies ≤1 in a healthy DB; cap handles rare duplicate ghosts — oldest first).
  static const int _sacredStaleOpenCap = 1;

  /// Authoritative row PK from Noco **list item wrapper** only (`{ "id": ..., "fields": {} }`).
  /// Never copied from `fields` alone — prevents confusing category/order with row id.
  static const String _nocoEnvelopePkKey = '_noco_envelope_pk';

  /// NocoDB v3 **system row id** (wrapper `Id` / `id`, integer). **Only** this value may appear in
  /// Row URL: `.../{tableUid}/{id}` (no `/records/`). Business UUID lives in column `record_id` (inside `fields`).
  static const String _nocoSystemRowIdKey = '_noco_system_row_id';

  /// Categories table only: optional wrapper segment when PK is a non-integer string (slug).
  static const String _nocoCategoryRestSegmentKey = '_noco_category_rest_segment';

  static String? _sanitizePkString(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final low = s.toLowerCase();
    if (low == 'null' || low == 'undefined') return null;
    if (s == '0') return null;
    return s;
  }

  /// UUID v4 written to Noco column `record_id` on **create** so the row has a stable id in DB
  /// (Noco wrapper `id` may be a small int or missing; REST PATCH must match a real key).
  /// Client UUID for `user_id`, `record_id`, `plan_id`, etc. (@DATA_MAP).
  static String newClientUuid() => _newClientRecordUuid();

  static String _newClientRecordUuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    const hex = '0123456789abcdef';
    String h2(int x) => '${hex[(x >> 4) & 15]}${hex[x & 15]}';
    return '${h2(b[0])}${h2(b[1])}${h2(b[2])}${h2(b[3])}-'
        '${h2(b[4])}${h2(b[5])}-'
        '${h2(b[6])}${h2(b[7])}-'
        '${h2(b[8])}${h2(b[9])}-'
        '${h2(b[10])}${h2(b[11])}${h2(b[12])}${h2(b[13])}${h2(b[14])}${h2(b[15])}';
  }

  /// PK from the JSON **row wrapper** (list item), not from nested `fields`.
  static String? _envelopePkOnlyFromWrapper(Map<String, dynamic> record) {
    final v = record['id'] ??
        record['Id'] ??
        record['ID'] ??
        record['record_id'] ??
        record['Record_id'] ??
        record['row_id'] ??
        record['RowId'] ??
        record['rowId'] ??
        record['nc_record_id'] ??
        record['NcRecordId'];
    return _sanitizePkString(v?.toString());
  }

  /// Only Noco's **row id** for URL path — wrapper `id` / `Id` / `ID` (never `fields.record_id` alone).
  static String? _wrapperRestPathIdOnly(Map<String, dynamic> record) {
    final v = record['id'] ?? record['Id'] ?? record['ID'];
    return _sanitizePkString(v?.toString());
  }

  /// NocoDB v3 list-item **wrapper** primary key as **int** (REST `.../{tableUid}/{id}`).
  static int? _parseSystemIntFromWrapper(Map<String, dynamic> record) {
    final v = record['id'] ?? record['Id'] ?? record['ID'];
    if (v is int) return v;
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  /// Noco sometimes omits wrapper `id` but stores the real row UUID in `fields.record_id`.
  static String? _firstUuidLikeRecordIdInFields(Map<String, dynamic> fields) {
    for (final k in <String>[
      'record_id',
      'Record_id',
      'recordId',
      'RecordId',
    ]) {
      final s = _sanitizePkString(fields[k]?.toString());
      if (s != null && _isLikelyUuidOrLongPk(s)) return s;
    }
    return null;
  }

  String? currentProfileId;

  PocketBase? _pocketBase;

  static const String _pbAuthPrefsKey = 'pb_auth';

  /// After **health** or **list-sync** failure (404 / connection-style): no bulk list HTTP until this instant.
  /// Fixed **15s** cooldown to stop millisecond-rate retries (**@POCKETBASE_MANIFEST** / VPS).
  DateTime? _pbNextAllowedNetworkAt;
  static const int _pbCircuitCooldownSeconds = 15;

  /// Skips redundant **records** `getFullList` after a successful sync (manual refresh uses [forceNetwork]).
  DateTime? _lastSuccessfulRecordsNetworkFetchAt;
  static const Duration _kMinGapRecordsNetworkFetch = Duration(seconds: 60);

  /// Avoids hitting [/api/health] on every [ensurePocketBaseReady] when the last probe succeeded.
  DateTime? _pbLastHealthProbeAt;
  bool? _pbLastHealthOk;
  static const Duration _kMinGapHealthWhenOk = Duration(seconds: 60);

  bool get _pbHttpBackoffActive {
    final t = _pbNextAllowedNetworkAt;
    if (t == null) return false;
    return DateTime.now().isBefore(t);
  }

  void _clearPocketBaseConnectivityBackoff() {
    _pbNextAllowedNetworkAt = null;
  }

  /// Opens the 15s circuit for [/api/health] failures (always — tunnel/server down).
  void _registerPocketBaseUnreachable(Object e) {
    _pbNextAllowedNetworkAt =
        DateTime.now().add(const Duration(seconds: _pbCircuitCooldownSeconds));
    _pbLastHealthProbeAt = DateTime.now();
    final wasOk = _pbLastHealthOk;
    _pbLastHealthOk = false;
    if (kDebugMode && wasOk != false) {
      debugPrint(
        '[PB] /api/health failed — circuit ${_pbCircuitCooldownSeconds}s: $e',
      );
    }
  }

  /// True for **404** or transport-style errors — avoids cooling down on every 400 validation burst.
  bool _isPbCircuitWorthyFailure(Object e) {
    if (e is ClientException) {
      final c = e.statusCode;
      if (c == 404) return true;
      if (c >= 500) return true;
      if (c <= 0) return true;
      final blob = '${e.originalError} $e'.toLowerCase();
      if (blob.contains('socket') ||
          blob.contains('connection refused') ||
          blob.contains('failed host lookup') ||
          blob.contains('network is unreachable') ||
          blob.contains('timed out') ||
          blob.contains('connection reset')) {
        return true;
      }
    }
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('connection refused') ||
        s.contains('failed host lookup') ||
        s.contains('connection reset') ||
        s.contains('err_connection_refused');
  }

  /// Opens **15s** list-sync pause after a worthy API/transport failure (one debug line).
  void _maybeOpenPbCircuitFromListFailure(Object e, String reason) {
    if (!_isPbCircuitWorthyFailure(e)) return;
    _pbNextAllowedNetworkAt =
        DateTime.now().add(const Duration(seconds: _pbCircuitCooldownSeconds));
    if (kDebugMode) {
      debugPrint(
        '[PB] $reason — circuit ${_pbCircuitCooldownSeconds}s (404/connection): $e',
      );
    }
  }

  /// Probes [/api/health]. Respects circuit, **throttles** happy-path probes to [_kMinGapHealthWhenOk],
  /// and logs **only on OK↔FAIL transitions** (stops per-tick console spam).
  Future<void> _maybeVerifyPocketBaseReachable() async {
    final now = DateTime.now();
    final until = _pbNextAllowedNetworkAt;
    if (until != null && now.isBefore(until)) {
      return;
    }
    final lastProbe = _pbLastHealthProbeAt;
    if (lastProbe != null &&
        _pbLastHealthOk == true &&
        now.difference(lastProbe) < _kMinGapHealthWhenOk) {
      return;
    }
    try {
      await _pb.health.check();
      _clearPocketBaseConnectivityBackoff();
      _pbLastHealthProbeAt = DateTime.now();
      final wasOk = _pbLastHealthOk;
      _pbLastHealthOk = true;
      if (kDebugMode && wasOk != true) {
        debugPrint('[PB] /api/health OK — $kPocketBaseUrl');
      }
    } catch (e) {
      _registerPocketBaseUnreachable(e);
    }
  }

  Future<void> ensurePocketBaseReady() async {
    if (_pocketBase == null) {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = kPocketBaseUrl;
      _pocketBase = PocketBase(
        baseUrl,
        authStore: AsyncAuthStore(
          save: (data) async => prefs.setString(_pbAuthPrefsKey, data),
          initial: prefs.getString(_pbAuthPrefsKey),
          clear: () async => prefs.remove(_pbAuthPrefsKey),
        ),
      );
      if (kDebugMode && !_pbHttpBackoffActive) {
        debugPrint('[PB_BASE_URL] $baseUrl');
        debugPrint(
          '[PB] PocketBase SDK ready — base URL $baseUrl (auth prefs key $_pbAuthPrefsKey)',
        );
      }
    }
    await _maybeVerifyPocketBaseReachable();
    SyncManager.instance.attachIfNeeded();
  }

  /// Re-subscribe to `records` realtime after auth when init ran without a session (symmetric Web ↔ mobile).
  /// Does **not** touch [writeRecord] / shadow state — optimistic UI is independent of socket health.
  /// Resets backoff and attempts one subscribe (coalesced with [_startRecordsRealtimeSubscription]).
  Future<void> ensureRecordsRealtimeBridge() async {
    _recordsRealtimeReconnectTimer?.cancel();
    _recordsRealtimeReconnectTimer = null;
    _recordsRealtimeFailureStreak = 0;
    unawaited(_startRecordsRealtimeSubscription());
  }

  Duration _recordsRealtimeDelayForCurrentFailureStreak() {
    final idx = _recordsRealtimeFailureStreak.clamp(0, _kRealtimeBackoffSeconds.length - 1);
    return Duration(seconds: _kRealtimeBackoffSeconds[idx]);
  }

  void _logRecordsRealtimeSubscribeQuiet(Object e) {
    final now = DateTime.now();
    if (_lastRealtimeSubscribeErrorLogAt != null &&
        now.difference(_lastRealtimeSubscribeErrorLogAt!) <
            const Duration(seconds: 5)) {
      return;
    }
    _lastRealtimeSubscribeErrorLogAt = now;
    _log(
      'records realtime subscribe failed (next backoff ${_recordsRealtimeDelayForCurrentFailureStreak().inSeconds}s): $e',
    );
  }

  void _scheduleRecordsRealtimeReconnectAfterFailure() {
    if (!_hasAuthenticatedUserId) return;
    _recordsRealtimeReconnectTimer?.cancel();
    final delay = _recordsRealtimeDelayForCurrentFailureStreak();
    if (_recordsRealtimeFailureStreak < _kRealtimeBackoffSeconds.length) {
      _recordsRealtimeFailureStreak++;
    }
    _recordsRealtimeReconnectTimer = Timer(delay, () {
      _recordsRealtimeReconnectTimer = null;
      unawaited(_startRecordsRealtimeSubscription());
    });
  }

  String _scopedDataCacheKey(String base) {
    final u = (currentProfileId ?? _userIdForWhere ?? '').trim();
    if (u.isEmpty) return '${base}_anon';
    return '${base}_$u';
  }

  Future<void> _hydrateRecordsCacheFromPrefsIfEmpty() async {
    if (_cachedFlatRecords.isNotEmpty) return;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(_scopedDataCacheKey(_cacheRecordsFlatKey));
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _cachedFlatRecords = [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e as Map),
      ];
    } catch (_) {}
  }

  /// Same as [_maybeVerifyPocketBaseReachable] — used from [_loadInner] (debug builds).
  Future<void> _debugPocketBaseHealth() async {
    await _maybeVerifyPocketBaseReachable();
  }

  /// Shared client; call [ensurePocketBaseReady] from [main] and before auth.
  PocketBase get pocketBase {
    final p = _pocketBase;
    if (p == null) {
      throw StateError('Call ensurePocketBaseReady() before using pocketBase');
    }
    return p;
  }

  /// Brain tracing is off by default (production-quiet). Enable temporarily when debugging Noco locally.
  static void _log(Object? message) {}

  /// Resolves waiting UI (SnackBar via [notifications] in app_shell) after category 404 = gone.
  void _emitCategorySyncNotice(String l10nKey) {
    try {
      final msg = t(currentLocale.value, l10nKey);
      if (msg.isEmpty) return;
      if (_notify.isClosed) return;
      _notify.add(msg);
    } catch (_) {}
  }

  /// Called when profile fetch returns 422/404 so the app can clear secure storage. Set by shell.
  Future<void> Function()? onSessionInvalid;

  /// Called when user explicitly signs out so the shell can set _profileId = null. Set by RootAuthWrapper.
  void Function()? onSignOut;

  /// One-shot local clean of titleless / "Untitled" rows from [_cachedFlatRecords] (@DATA_MAP ghost / bad creates).
  static const String _oneShotUntitledGhostCleanKey =
      'brain_one_shot_untitled_ghost_clean_v1';
  static const String _cacheRecordsFlatKey = 'cache_records_flat_v1';
  static const String _cacheCategoriesRawKey = 'cache_categories_raw_v1';

  String? _loadErrorMessage;
  String? get loadErrorMessage => _loadErrorMessage;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SharedPreferences? _prefs;
  List<CategoryRule> _rules = [];
  /// All `category_id` / `normalized_id` (lowercase) for this user from PocketBase, **including archived** — reserved for new POSTs.
  Set<String> _reservedCategorySlugsLower = {};
  /// Display names + archive flags for **all** PB rows (see [_rebuildCategoryDialogUniverse]) — create dialog pre-flight.
  List<Map<String, dynamic>> _categoryDialogUniverse = [];

  int? _lastAggregatedKey;
  List<StatsNode>? _lastStatsNodeRoots;

  final StreamController<List<CategoryRule>> _categoryController =
      StreamController<List<CategoryRule>>.broadcast();
  final StreamController<String?> _notify =
      StreamController<String?>.broadcast();
  final StreamController<void> _timeUpdateController =
      StreamController<void>.broadcast();

  /// >0 during multi-step record cache writes (e.g. sacred stop + POST) — skips per-step
  /// [timeUpdates] so the timeline sees **one** refresh when the batch completes.
  int _recordCacheTimelineNotifyBatchDepth = 0;

  void _emitTimelineRefreshRaw() {
    _timeUpdateController.add(null);
    _requestPlanAlarmReschedule();
  }

  Future<T> _runBatchedRecordCacheTimelineNotify<T>(
    Future<T> Function() action,
  ) async {
    _recordCacheTimelineNotifyBatchDepth++;
    try {
      return await action();
    } finally {
      _recordCacheTimelineNotifyBatchDepth--;
      if (_recordCacheTimelineNotifyBatchDepth == 0) {
        _emitTimelineRefreshRaw();
      }
    }
  }

  /// Same as [_runBatchedRecordCacheTimelineNotify] but **synchronous** — no await before UI emit.
  void _runBatchedRecordCacheTimelineNotifySync(void Function() action) {
    _recordCacheTimelineNotifyBatchDepth++;
    try {
      action();
    } finally {
      _recordCacheTimelineNotifyBatchDepth--;
      if (_recordCacheTimelineNotifyBatchDepth == 0) {
        _emitTimelineRefreshRaw();
      }
    }
  }

  /// Serializes **network** for primary Highlander (PATCH/POST), not local shadow / UI emission.
  Future<void> _primaryHighlanderNetworkChain = Future.value();

  /// After optimistic [writeRecord] returns, await this before REST PATCH on the new row (PB id must exist).
  Future<void> get primaryRecordWriteNetworkChain =>
      _primaryHighlanderNetworkChain;

  PocketBase get _pb => pocketBase;

  /// PocketBase [ClientException] diagnostics (terminal): URL, body, status, full `response` + `data`, auth id.
  void _debugPrintPocketBaseClientException({
    required String operation,
    required ClientException e,
    required Map<String, dynamic> payload,
    String? fallbackUrl,
  }) {
    String pretty(dynamic v) {
      if (v == null) return 'null';
      try {
        return const JsonEncoder.withIndent('  ').convert(v);
      } catch (_) {
        return v.toString();
      }
    }

    final url = (e.url != null && e.url.toString().trim().isNotEmpty)
        ? e.url.toString()
        : (fallbackUrl ?? '(unknown URL)');

    final authId = () {
      try {
        return _pocketBase?.authStore.record?.id.trim() ?? '';
      } catch (_) {
        return '';
      }
    }();

    debugPrint('=== PB ClientException [$operation] ===');
    debugPrint('URL: $url');
    debugPrint('PAYLOAD: ${pretty(payload)}');
    debugPrint('STATUS: ${e.statusCode}');
    debugPrint('RESPONSE: ${pretty(e.response)}');
    debugPrint("RESPONSE['data']: ${pretty(e.response['data'])}");
    if (e.originalError != null) {
      debugPrint('ORIGINAL_ERROR: ${e.originalError}');
    }
    debugPrint('AUTH_ID: $authId');
    debugPrint('=== end PB ClientException ===');
  }

  Stream<void> get timeUpdates => _timeUpdateController.stream;

  /// When the device-local calendar day changes while the app stays open (midnight), ping [timeUpdates]
  /// so open timeline streams re-bucket without a manual refresh.
  void notifyTimelineDeviceLocalDayChanged() {
    _emitTimelineRefreshRaw();
  }

  /// Primary running record title from cache (no parent); for planning “active” highlight.
  String? get cachedPrimaryRunningTitle {
    for (final r in _cachedFlatRecords) {
      if (_rowHasNonEmptyParent(r['parent_id'])) continue;
      if (!_isNocoRowActiveRunning(r)) continue;
      final tit = (r['title'] ?? '').toString().trim();
      if (tit.isEmpty) continue;
      return tit;
    }
    return null;
  }

  int _indexOfCachedRecordRow(String resolvedRid, String originalInput) {
    for (var i = 0; i < _cachedFlatRecords.length; i++) {
      final r = _cachedFlatRecords[i];
      final pk = recordsTablePk(r);
      final biz = (r['record_id'] ?? '').toString().trim();
      if (pk == resolvedRid ||
          biz == resolvedRid ||
          pk == originalInput ||
          biz == originalInput) {
        return i;
      }
    }
    return -1;
  }

  Stream<UserSettings> get userSettingsStream => Stream.multi((c) {
        c.add(_settings);
        _settingsController.stream.listen(c.add, onError: c.addError);
      });

  Stream<List<CategoryRule>> get categoryStream => Stream.multi((c) {
        c.add(List.from(_rules));
        _categoryController.stream.listen(c.add, onError: c.addError);
      });

  /// Categories reorder: debounced bulk PATCH of [order] only (@DATA_MAP `categories`, `user_id`).
  static const Duration _categoryOrderDebounce = Duration(seconds: 2);
  Timer? _categoryOrderDebounceTimer;
  List<CategoryRule>? _pendingCategoryOrderSyncList;
  /// Local category id → list index before the first drag of the current reorder session.
  Map<int, int>? _categoryReorderBaselineByLocalId;

  /// Last successful flat fetch from Noco (same shape as [getRecords]). Timeline filters in-memory only.
  List<Map<String, dynamic>> _cachedFlatRecords = [];

  /// PocketBase realtime: unsubscribe function from [RecordService.subscribe] ('*').
  Future<void> Function()? _recordsRealtimeUnsubscribe;

  /// Exponential backoff for `/api/realtime` reconnects: 5s → 10s → 20s (caps spam + main-thread churn).
  static const List<int> _kRealtimeBackoffSeconds = [5, 10, 20];
  int _recordsRealtimeFailureStreak = 0;
  Timer? _recordsRealtimeReconnectTimer;  /// Prevents overlapping subscribe attempts (avoids recursive reconnect / stacked futures).
  Future<void>? _recordsRealtimeSubscribeFuture;
  DateTime? _lastRealtimeSubscribeErrorLogAt;

  /// Timeline row keys (REST id / business UUID) that returned **definitive** 404 after full retry — no repeat PATCH/DELETE until row reappears in GET.
  final Set<String> _recordRestDefinitive404Keys = <String>{};

  /// Set when [_patchRecordsRowWith404Recovery] returns **without** calling PB because [rid]/[originalQueryId] hit [_recordRestDefinitive404Keys].
  bool _lastRecordsPatchSkippedDeadLetter = false;

  // --- Optimistic timeline UI (merged into [recordsStream] / [activeRecordStream]; reverted on failure) ---

  /// Client-only: show ended state before PATCH returns.
  final Map<String, _OptimisticEndPatch> _optimisticEndByKey = {};

  /// Client-only: hide row before DELETE returns.
  final Set<String> _optimisticDeletedKeys = {};

  /// Synthetic running row while POST is in flight (primary timer start only).
  Map<String, dynamic>? _optimisticPendingStartRecordMap;

  /// Dedupes rapid repeat **stop** taps for the same timeline id (UUID or REST id).
  final Set<String> _stopRecordInFlightKeys = <String>{};

  /// Dedupes overlapping **writeRecord** / **writeCompletedRecord** calls.
  bool _writeRecordMutationInFlight = false;

  Stream<String?> get notifications => _notify.stream;
  List<CategoryRule> get rules => List.unmodifiable(_rules);
  static DateTime getPlanetaryNow() => DateTime.now().toUtc();
  List<CategoryRule> get categoryRules => rules;

  /// PocketBase **signed-in auth record id** only (same value as child-row `user_id`). No int surrogate.
  String? get _userIdForWhere {
    try {
      final id = _pocketBase?.authStore.record?.id.trim() ?? '';
      if (id.isEmpty) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Same identity set as [AuthBridge.checkSession]: profile data `user_id` when non-empty, else auth record id.
  /// Used for **GET** filters so we still find rows whose `user_id` matches the stored session UUID.
  String? _pocketBaseOwnerFilterClauseForRecords() {
    try {
      final rec = _pocketBase?.authStore.record;
      if (rec == null) return null;
      final dataUid = (rec.data['user_id'] ?? '').toString().trim();
      final rid = rec.id.trim();
      final ids = <String>{};
      if (rid.isNotEmpty) ids.add(rid);
      if (dataUid.isNotEmpty) ids.add(dataUid);
      if (ids.isEmpty) return null;
      if (ids.length == 1) {
        final only = ids.first;
        return 'user_id = "${_escapeForPbFilter(only)}"';
      }
      final ors = ids
          .map((id) => 'user_id = "${_escapeForPbFilter(id)}"')
          .join(' || ');
      return '($ors)';
    } catch (_) {
      return null;
    }
  }

  /// Lowercase set of owner ids for matching [Map] rows in [_filterCachedRecordsForDate].
  Set<String> _recordRowOwnerIdMatchSet() {
    final out = <String>{
      (currentProfileId ?? '').trim().toLowerCase(),
      (_userIdForWhere ?? '').trim().toLowerCase(),
    };
    try {
      final dataUid = (_pocketBase?.authStore.record?.data['user_id'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (dataUid.isNotEmpty) out.add(dataUid);
    } catch (_) {}
    out.removeWhere((e) => e.isEmpty);
    return out;
  }

  bool get _hasAuthenticatedUserId =>
      (_userIdForWhere?.isNotEmpty ?? false);

  /// Use for POST/PATCH bodies and any call that must not run without a valid auth id.
  String _requireAuthUserIdForWrite() {
    final id = _userIdForWhere;
    if (id == null || id.isEmpty) {
      throw AuthenticatedUserIdRequiredException();
    }
    return id;
  }

  /// PocketBase `user_id` on child rows — **strictly** the auth record id ([_requireAuthUserIdForWrite]).
  String get _pidForPbFilter => _requireAuthUserIdForWrite();

  String _escapeForPbFilter(String raw) =>
      raw.replaceAll(r'\', r'\\').replaceAll('"', r'\"');


  /// PocketBase collection row `id`: lowercase alphanumeric, ~15 chars, no hyphens (@DATA_MAP).
  static bool _isLikelyPocketBaseRowId(String s) {
    final t = s.trim();
    if (t.isEmpty || t.contains('-')) return false;
    if (t.length < 14 || t.length > 17) return false;
    return RegExp(r'^[a-z0-9]+$').hasMatch(t);
  }

  /// Single safe relation id for POST/PATCH (e.g. `records.source_plan_id`). Never pass UUIDs here.
  static String? pocketRelationIdOrNull(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!_isLikelyPocketBaseRowId(t)) return null;
    return t;
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    final m = s.length;
    final n = t.length;
    var row = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      var prev = row[0];
      row[0] = i;
      for (var j = 1; j <= n; j++) {
        final cur = row[j];
        final cost = s.codeUnitAt(i - 1) == t.codeUnitAt(j - 1) ? 0 : 1;
        row[j] = min(row[j] + 1, min(row[j - 1] + 1, prev + cost));
        prev = cur;
      }
    }
    return row[n];
  }

  /// `records.user_id` relation from list response (plain id or expanded map).
  static String _pbRecordRowUserIdString(RecordModel rec) {
    final v = rec.data['user_id'];
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is Map) {
      final id = v['id'];
      if (id != null) return id.toString().trim();
    }
    return v.toString().trim();
  }

  /// One row: `records.record_id` → system `id` for PATCH/DELETE URLs.
  ///
  /// Tries `record_id` + [user_id] first (@DATA_MAP). If that misses (e.g. dirty
  /// `user_id` still pointing at email/legacy owner), retries `record_id` only,
  /// logs [CONFLICT], and returns the row [id] anyway so PATCH can run (may 403).
  Future<String?> _fetchPbRecordSysIdByRecordIdField(
    String businessRecordId,
  ) async {
    final key = businessRecordId.trim();
    if (key.isEmpty) return null;
    if (_isLikelyPocketBaseRowId(key)) return key;
    try {
      await ensurePocketBaseReady();
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return null;
      final uid = _escapeForPbFilter(authId);
      final esc = _escapeForPbFilter(key);

      try {
        final scoped = 'record_id = "$esc" && user_id = "$uid"';
        final rec = await _pb
            .collection(PbCollections.records)
            .getFirstListItem(scoped);
        final id = rec.id.trim();
        return id.isEmpty ? null : id;
      } on ClientException catch (_) {
        try {
          debugPrint('SEARCHING PB FOR: record_id = "$key" (emergency: no user_id filter)');
          final solo = 'record_id = "$esc"';
          final rec =
              await _pb.collection(PbCollections.records).getFirstListItem(
                    solo,
                  );
          final foundOwner = _pbRecordRowUserIdString(rec);
          if (foundOwner != authId) {
            debugPrint('CONFLICT: Record found but owner mismatch. Found: $foundOwner, Expected: $authId');
          }
          final id = rec.id.trim();
          return id.isEmpty ? null : id;
        } on ClientException catch (_) {
          return null;
        }
      }
    } catch (_) {
      return null;
    }
  }

  /// One row: `categories.category_id` (slug/UUID) → system `id`.
  Future<String?> _fetchPbCategorySysIdByCategoryIdField(
    String categoryBizKey,
  ) async {
    final key = categoryBizKey.trim();
    if (key.isEmpty || key == 'uncategorized') return null;
    if (_isLikelyPocketBaseRowId(key)) return key;
    try {
      await ensurePocketBaseReady();
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return null;
      final uid = _escapeForPbFilter(authId);
      final esc = _escapeForPbFilter(key);
      final rec = await _pb
          .collection(PbCollections.categories)
          .getFirstListItem('category_id = "$esc" && user_id = "$uid"');
      final id = rec.id.trim();
      return id.isEmpty ? null : id;
    } on ClientException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Resolves PocketBase **categories** row `id` when [CategoryRule.backendRowId] still holds legacy `category_id`.
  Future<String> _resolveCategoryRowIdForPb(CategoryRule rule) async {
    var p = (_categoryBackendRowIdStrict(rule) ?? '').trim();
    if (p.isEmpty) return p;
    if (p == 'uncategorized') return p;
    if (_isLikelyPocketBaseRowId(p)) return p;
    final tried = <String>{};
    final biz = (_categoryStringPkForApi(rule) ?? '').trim();
    for (final key in <String>[
      if (biz.isNotEmpty && biz != 'uncategorized') biz,
      p,
    ]) {
      if (key.isEmpty || !tried.add(key)) continue;
      final sid = await _fetchPbCategorySysIdByCategoryIdField(key);
      if (sid != null && sid.isNotEmpty && sid != p) {
        return sid;
      }
      if (sid != null && sid.isNotEmpty) return sid;
    }
    return p;
  }

  void clearLocalStateOnSignOut() {
    _unregisterAppLifecycleObserver();
    _planAlarmRescheduleDebounceTimer?.cancel();
    _planAlarmRescheduleDebounceTimer = null;
    _recordsRealtimeReconnectTimer?.cancel();
    _recordsRealtimeReconnectTimer = null;
    _recordsRealtimeFailureStreak = 0;
    _lastRealtimeSubscribeErrorLogAt = null;
    unawaited(_cancelRecordsRealtimeSubscription());
    try {
      _pocketBase?.authStore.clear();
    } catch (_) {}
    _clearPocketBaseConnectivityBackoff();
    _lastSuccessfulRecordsNetworkFetchAt = null;
    _pbLastHealthProbeAt = null;
    _pbLastHealthOk = null;
    try {
      _isInitialized = false;
      currentProfileId = null;
      _cachedProfileUuid = null;
      _loadErrorMessage = null;
      _rules = [];
      _reservedCategorySlugsLower.clear();
      _categoryDialogUniverse = [];
      _tasksCache = [];
      _cachedFlatRecords = [];
      _settings = UserSettings(userId: '');
      _userTagsCatalogCache = [];
      _lastAggregatedKey = null;
      _lastStatsNodeRoots = null;
      _recordRestDefinitive404Keys.clear();
      _planningOptimisticByDateKey.clear();
      _primaryHighlanderNetworkChain = Future.value();
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      currentLocale.value = 'en';
      clearOptimisticTimelineUi();
      _stopRecordInFlightKeys.clear();
      _writeRecordMutationInFlight = false;
      _cancelPlanOrderDebounceTimer();
      _pendingPlanOrderSyncList = null;
      _planReorderBaselineByPlanId = null;
      _cancelCategoryOrderDebounceTimer();
      _pendingCategoryOrderSyncList = null;
      _categoryReorderBaselineByLocalId = null;
      _profilePbRecordId = null;
    } catch (_) {}
    unawaited(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        await prefs.remove(_profileThemeModeKey);
      } catch (_) {}
    }());
  }

  Future<void> setDataRegion(String region) async {
    _dataRegion = region == 'russia' ? 'russia' : 'global';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dataRegionKey, _dataRegion);
    } catch (_) {}
  }

  Future<bool> loadInitialData(String uid) async {
    await ensurePocketBaseReady();
    _isInitialized = false;
    _loadErrorMessage = null;
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      _loadErrorMessage = 'Invalid profile';
      _isInitialized = true;
      return false;
    }
    currentProfileId = trimmed;
    try {
      await _loadInner().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          final aid = _userIdForWhere ?? '';
          _settings = UserSettings(userId: aid.isNotEmpty ? aid : trimmed);
          _settingsController.add(_settings);
        },
      );
      return true;
    } on _ProfileFetchFailedException catch (e) {
      try {
        await onSessionInvalid?.call();
      } catch (_) {}
      clearLocalStateOnSignOut();
      _loadErrorMessage = e.message ?? 'Session invalid or profile not found';
      _isInitialized = true;
      return false;
    } catch (e, st) {
      // ignore: avoid_print
      print('DatabaseService.loadInitialData failed: $e\n$st');
      _isInitialized = true;
      _loadErrorMessage = 'Sync Error: $e';
      _settingsController.add(_settings);
      return true;
    }
  }

  /// Wear OS companion: skips planning fetch and startup maintenance.
  /// Platform Wear I/O (`MethodChannel`) lives in `lib/features/wear/` — not here.
  Future<bool> loadInitialDataWearLite(String uid) async {
    await ensurePocketBaseReady();
    _isInitialized = false;
    _loadErrorMessage = null;
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      _loadErrorMessage = 'Invalid profile';
      _isInitialized = true;
      return false;
    }
    currentProfileId = trimmed;
    try {
      await _loadInnerWearLite().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          final aid = _userIdForWhere ?? '';
          _settings = UserSettings(userId: aid.isNotEmpty ? aid : trimmed);
          _settingsController.add(_settings);
        },
      );
      return true;
    } on _ProfileFetchFailedException catch (e) {
      try {
        await onSessionInvalid?.call();
      } catch (_) {}
      clearLocalStateOnSignOut();
      _loadErrorMessage = e.message ?? 'Session invalid or profile not found';
      _isInitialized = true;
      return false;
    } catch (e, st) {
      // ignore: avoid_print
      print('DatabaseService.loadInitialDataWearLite failed: $e\n$st');
      _isInitialized = true;
      _loadErrorMessage = 'Sync Error: $e';
      _settingsController.add(_settings);
      return true;
    }
  }

  Future<void> _loadInnerWearLite() async {
    _prefs = await SharedPreferences.getInstance();
    await _debugPocketBaseHealth();
    if (_pbHttpBackoffActive) {
      _loadErrorMessage ??= 'PocketBase unreachable; retry scheduled.';
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      _isInitialized = true;
      return;
    }
    await _loadSettingsFromNoco();
    await _loadRulesFromNoco();
    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
    } catch (_) {}
    _settingsController.add(_settings);
    _categoryController.add(List.from(_rules));
    _tasksController.add(List.from(_tasksCache));
    _isInitialized = true;
    _registerAppLifecycleObserverOnce();
    // LAW_OF_THE_MAIN_THREAD / Wear-lite: do not block watch bootstrap on realtime socket.
    unawaited(
      _startRecordsRealtimeSubscription().catchError((Object _, StackTrace __) {}),
    );
  }

  Future<void> _loadInner() async {
    _prefs = await SharedPreferences.getInstance();
    await _debugPocketBaseHealth();
    if (_pbHttpBackoffActive) {
      _loadErrorMessage ??= 'PocketBase unreachable; retry scheduled.';
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      _isInitialized = true;
      return;
    }
    await _loadSettingsFromNoco();
    await _loadRulesFromNoco();
    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
    } catch (_) {}
    await _loadPlanningTasksForToday();
    // Safety re-run: finish startup with a final category load.
    await _loadRulesFromNoco();
    _settingsController.add(_settings);
    _categoryController.add(List.from(_rules));
    _tasksController.add(List.from(_tasksCache));
    // Shell must not treat Brain as ready until profile settings + categories + tasks are loaded.
    _isInitialized = true;
    _registerAppLifecycleObserverOnce();
    try {
      await _startRecordsRealtimeSubscription();
    } catch (_) {}
    unawaited(
      _runOneShotUntitledGhostRecordCleanDeferred()
          .catchError((Object _, StackTrace __) {}),
    );
    unawaited(flushPendingPlanCreates());
  }

  /// PocketBase: all **categories** for the signed-in `user_id` (@DATA_MAP).
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return [];
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        return [];
      }
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return [];
      final uid = _escapeForPbFilter(authId);
      final list = await _pb.collection(PbCollections.categories).getFullList(
        filter: 'user_id = "$uid" && is_archived = false',
      );
      final out = list.map((r) {
        final m = Map<String, dynamic>.from(r.data);
        m['id'] = r.id;
        m['_pb_record_id'] = r.id;
        return m;
      }).toList();
      if (kDebugMode) {
        debugPrint(
          '[PB] fetchCategories: ${out.length} rows (user_id filter) @ $kPocketBaseUrl',
        );
      }
      return out;
    } on ClientException catch (e) {
      debugPrint('PB_ERROR_RESPONSE: ${e.response}');
      _maybeOpenPbCircuitFromListFailure(e, 'fetchCategories');
      return [];
    } catch (e) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchCategories');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() => fetchCategories();

  /// PocketBase **categories**: every row for `user_id` (active + archived) for slug reservation / collision checks.
  Future<List<Map<String, dynamic>>> _fetchAllCategoryMapsForUser() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return [];
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        return [];
      }
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return [];
      final uid = _escapeForPbFilter(authId);
      final list = await _pb.collection(PbCollections.categories).getFullList(
        filter: 'user_id = "$uid"',
      );
      return list
          .map((r) {
            final m = Map<String, dynamic>.from(r.data);
            m['id'] = r.id;
            m['_pb_record_id'] = r.id;
            return m;
          })
          .toList();
    } on ClientException catch (e) {
      debugPrint('PB_ERROR_RESPONSE: ${e.response}');
      _maybeOpenPbCircuitFromListFailure(e, 'fetchAllCategories');
      return [];
    } catch (e) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchAllCategories');
      return [];
    }
  }

  void _rebuildReservedCategorySlugsFromRows(
      List<Map<String, dynamic>> rows) {
    final set = <String>{};
    for (final row in rows) {
      final flat = _flattenNocoRecord(row, allowCategoryIdAsRowPk: true);
      void add(dynamic v) {
        final s = (v ?? '').toString().trim().toLowerCase();
        if (s.isNotEmpty) set.add(s);
      }

      add(flat['category_id'] ?? flat['Category_id']);
      add(flat['normalized_id'] ?? flat['normalizedId']);
    }
    _reservedCategorySlugsLower = set;
  }

  void _rebuildCategoryDialogUniverse(List<Map<String, dynamic>> allRawRows) {
    final list = <Map<String, dynamic>>[];
    for (final row in allRawRows) {
      final flat = _flattenNocoRecord(row, allowCategoryIdAsRowPk: true);
      final name = _categoryDisplayNameFromRow(flat);
      final archRaw = flat['is_archived'] ?? flat['isArchived'];
      var isArc = _jsonBoolFromDynamic(archRaw);
      final st = (flat['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'archived' || st == 'deleted') isArc = true;
      final pb = (row['id'] ?? row['_pb_record_id'] ?? flat['id'] ?? '')
          .toString()
          .trim();
      list.add({
        'name': name,
        'nameLower': name.trim().toLowerCase(),
        'isArchived': isArc,
        'pbRowId': pb,
      });
    }
    _categoryDialogUniverse = list;
  }

  Map<String, dynamic> _recordMapFromPb(RecordModel r) {
    final d = Map<String, dynamic>.from(r.data);
    d['id'] = r.id;
    d['_pb_record_id'] = r.id;
    dynamic exp = r.get<dynamic>('expand.$kPbRecordCategoryExpand');
    if (exp == null) {
      exp = r.get<dynamic>('expand.category_id');
    }
    if (exp is RecordModel) {
      final cd = exp.data;
      d['category_id'] = cd['category_id']?.toString() ?? d['category_id'];
      d['_expanded_category'] = <String, dynamic>{...cd, 'id': exp.id};
    } else if (exp is List && exp.isNotEmpty) {
      final first = exp.first;
      if (first is RecordModel) {
        final cd = first.data;
        d['category_id'] = cd['category_id']?.toString() ?? d['category_id'];
        d['_expanded_category'] = <String, dynamic>{...cd, 'id': first.id};
      }
    }
    final expTags = r.get<dynamic>('expand.$kPbRecordTagsExpand');
    if (expTags is List) {
      d['_expanded_tags'] = <Map<String, dynamic>>[
        for (final item in expTags)
          if (item is RecordModel)
            <String, dynamic>{...item.data, 'id': item.id}
          else if (item is Map)
            Map<String, dynamic>.from(item),
      ];
    } else if (expTags is RecordModel) {
      d['_expanded_tags'] = <Map<String, dynamic>>[
        <String, dynamic>{...expTags.data, 'id': expTags.id},
      ];
    }
    final uidNorm = normalizeLinkScalar(d['user_id']);
    if (uidNorm != null) {
      d['user_id'] = uidNorm.toString().trim();
    }
    return d;
  }

  Map<int, Map<String, dynamic>> _snapshotRunningRowsForHighlanderRollback() {
    final m = <int, Map<String, dynamic>>{};
    for (var i = 0; i < _cachedFlatRecords.length; i++) {
      final r = _cachedFlatRecords[i];
      final st = (r['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'running') {
        m[i] = Map<String, dynamic>.from(r);
      }
    }
    return m;
  }

  void _restoreHighlanderRollbackToken(_HighlanderRollbackToken? token) {
    if (token == null) return;
    if (token.appendedPendingRow && _cachedFlatRecords.isNotEmpty) {
      _cachedFlatRecords.removeLast();
    }
    for (final e in token.runningSnapshotsByIndex.entries) {
      final i = e.key;
      if (i < _cachedFlatRecords.length) {
        _cachedFlatRecords[i] = Map<String, dynamic>.from(e.value);
      }
    }
  }

  /// Verification: at most one `running` row should exist after local Highlander apply.
  void _printAtomicCheckRunningCount() {}

  /// **Highlander** — local-only phase: every `status == running` row is forced to `stopped`
  /// with [end_time]; then the new primary running row is appended. Single notifier happens
  /// in the surrounding [_runBatchedRecordCacheTimelineNotify] after this returns.
  ///
  /// **startAtomicTaskSequence** (steps 1–3): memory stop-all-running → append pending POST row.
  void _startAtomicTaskSequenceApplyLocalPrimary({
    required Map<String, dynamic> createBody,
    required List<Map<String, String>> patchTargetsOut,
  }) {
    patchTargetsOut.clear();
    final nowIso = getPlanetaryNow().toUtc().toIso8601String();
    final next = <Map<String, dynamic>>[];
    for (final row in _cachedFlatRecords) {
      final copy = Map<String, dynamic>.from(row);
      final st = (copy['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'running') {
        final pk = recordsTablePk(copy);
        final biz = (copy['record_id'] ?? '').toString().trim();
        if (pk.isNotEmpty) {
          patchTargetsOut.add(<String, String>{
            'rid': pk,
            'oq': biz.isNotEmpty ? biz : pk,
          });
        }
        copy['status'] = 'stopped';
        copy['end_time'] = nowIso;
      }
      next.add(copy);
    }
    final pending = Map<String, dynamic>.from(createBody);
    final bizId = (pending['record_id'] ?? '').toString().trim();
    if (bizId.isEmpty) {
      _log('HIGHLANDER: createBody missing record_id — aborting local append');
      _cachedFlatRecords = next;
      return;
    }
    pending['id'] = bizId;
    pending['_pb_record_id'] = '';
    pending['status'] = 'running';
    pending['end_time'] = null;
    pending['_highlanderPendingPost'] = true;
    next.add(pending);
    _cachedFlatRecords = next;
  }

  /// True when [after] only advances REST/metadata (e.g. PocketBase `id`) but timeline-visible
  /// fields match [before] — skip [timeUpdates] to avoid ID-swap list blink.
  static bool _flatTimelineVisuallyEquivalent(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    String ns(dynamic v) {
      if (v == null) return '';
      final x = normalizeLinkScalar(v);
      return (x ?? v).toString().trim();
    }

    bool sameTime(dynamic a, dynamic b) {
      final da = _parseDateTimeUtc(a);
      final db = _parseDateTimeUtc(b);
      if (da != null && db != null) {
        final ua = da.toUtc();
        final ub = db.toUtc();
        final aSec = DateTime.utc(
            ua.year, ua.month, ua.day, ua.hour, ua.minute, ua.second);
        final bSec = DateTime.utc(
            ub.year, ub.month, ub.day, ub.hour, ub.minute, ub.second);
        return aSec == bSec;
      }
      final sa = normalizeRecordIsoToUtcSecondPrecision(a);
      final sb = normalizeRecordIsoToUtcSecondPrecision(b);
      if ((sa ?? '').isNotEmpty || (sb ?? '').isNotEmpty) {
        return sa == sb;
      }
      return ns(a) == ns(b);
    }

    if (ns(before['status']).toLowerCase() !=
        ns(after['status']).toLowerCase()) {
      return false;
    }
    if (ns(before['title']) != ns(after['title'])) return false;
    if (ns(before['record_id']) != ns(after['record_id'])) return false;
    if (!sameTime(before['start_time'], after['start_time'])) return false;
    if (!sameTime(before['end_time'], after['end_time'])) return false;
    if (ns(before['type']) != ns(after['type'])) return false;
    if (ns(before['parent_id']) != ns(after['parent_id'])) return false;
    if (ns(before['tags']) != ns(after['tags'])) return false;
    if (ns(before['category_id']) != ns(after['category_id'])) return false;
    if (ns(before['note']) != ns(after['note']) ||
        ns(before['notes']) != ns(after['notes'])) {
      return false;
    }
    try {
      final ea = jsonEncode(before['checklist'] ?? <dynamic>[]);
      final eb = jsonEncode(after['checklist'] ?? <dynamic>[]);
      if (ea != eb) return false;
    } catch (_) {
      if (ns(before['checklist']) != ns(after['checklist'])) return false;
    }
    return true;
  }

  /// Merge one PocketBase **records** row into [_cachedFlatRecords] without refetching the full list.
  void _upsertFlatRecordFromPbModel(
    RecordModel r, {
    bool preserveExpand = true,
    bool suppressTimelineNotify = false,
    bool logSuccessLine = true,
  }) {
    try {
      final m = _recordMapFromPb(r);
      final pk = recordsTablePk(m);
      if (pk.isEmpty) return;
      final biz = (m['record_id'] ?? '').toString().trim();
      final next = List<Map<String, dynamic>>.from(_cachedFlatRecords);
      for (var i = 0; i < next.length; i++) {
        final row = next[i];
        final rpk = recordsTablePk(row);
        final rbiz = (row['record_id'] ?? '').toString().trim();
        final same =
            rpk == pk || (biz.isNotEmpty && (rbiz == biz || rpk == biz));
        if (same) {
          if (preserveExpand &&
              m['_expanded_category'] == null &&
              row['_expanded_category'] != null) {
            m['_expanded_category'] = row['_expanded_category'];
          }
          final silent = rbiz.isNotEmpty &&
              biz.isNotEmpty &&
              rbiz == biz &&
              _flatTimelineVisuallyEquivalent(row, m);
          next[i] = m;
          _cachedFlatRecords = next;
          if (!suppressTimelineNotify && !silent) {
            _notifyTimelineAfterRecordCacheMutation();
          }
          return;
        }
      }
      next.add(m);
      _cachedFlatRecords = next;
      if (!suppressTimelineNotify) {
        _notifyTimelineAfterRecordCacheMutation();
      }
    } catch (e, st) {
      _log('_upsertFlatRecordFromPbModel failed: $e');
      _log(st.toString());
    }
  }

  void _removeCachedFlatRecordByPk(String pocketBaseRowId) {
    final id = pocketBaseRowId.trim();
    if (id.isEmpty) return;
    final before = _cachedFlatRecords.length;
    _cachedFlatRecords = [
      for (final row in _cachedFlatRecords)
        if (recordsTablePk(row) != id) row,
    ];
    if (_cachedFlatRecords.length != before) {
      _notifyTimelineAfterRecordCacheMutation();
    }
  }

  void _onPbRecordsSubscriptionEvent(RecordSubscriptionEvent e) {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    final action = e.action.toLowerCase().trim();
    if (action == 'delete') {
      final id = e.record?.id.trim() ?? '';
      if (id.isNotEmpty) {
        _removeCachedFlatRecordByPk(id);
      }
      return;
    }
    final rec = e.record;
    if (rec == null) return;
    try {
      _upsertFlatRecordFromPbModel(
        rec,
        preserveExpand: true,
        suppressTimelineNotify: false,
        logSuccessLine: false,
      );
    } catch (_) {}
  }

  void _registerAppLifecycleObserverOnce() {
    if (_appLifecycleObserverRegistered) return;
    _appLifecycleObserver.onResumed = _onAppLifecycleResumed;
    try {
      WidgetsBinding.instance.addObserver(_appLifecycleObserver);
      _appLifecycleObserverRegistered = true;
    } catch (_) {}
  }

  void _unregisterAppLifecycleObserver() {
    if (!_appLifecycleObserverRegistered) return;
    try {
      WidgetsBinding.instance.removeObserver(_appLifecycleObserver);
    } catch (_) {}
    _appLifecycleObserver.onResumed = null;
    _appLifecycleObserverRegistered = false;
  }

  void _onAppLifecycleResumed() {
    if (!(currentProfileId?.isNotEmpty ?? false)) return;
    if (!_hasAuthenticatedUserId) return;
    _recordsRealtimeFailureStreak = 0;
    unawaited(_resyncRecordsRealtimeAfterAppResume());
  }

  Future<void> _resyncRecordsRealtimeAfterAppResume() async {
    try {
      await _cancelRecordsRealtimeSubscription();
    } catch (_) {}
    unawaited(
      _startRecordsRealtimeSubscription()
          .catchError((Object _, StackTrace __) {}),
    );
    unawaited(
      fetchRecords(forceNetwork: true)
          .catchError((Object _, StackTrace __) {}),
    );
  }

  Future<void> _cancelRecordsRealtimeSubscription() async {
    final unsub = _recordsRealtimeUnsubscribe;
    _recordsRealtimeUnsubscribe = null;
    if (unsub != null) {
      try {
        await unsub();
      } catch (_) {}
    }
    try {
      await _pb.collection(PbCollections.records).unsubscribe();
    } catch (_) {}
  }

  Future<void> _startRecordsRealtimeSubscription() async {
    final existing = _recordsRealtimeSubscribeFuture;
    if (existing != null) {
      return existing;
    }
    final f = _startRecordsRealtimeSubscriptionBody();
    _recordsRealtimeSubscribeFuture = f;
    try {
      await f;
    } finally {
      _recordsRealtimeSubscribeFuture = null;
    }
  }

  Future<void> _startRecordsRealtimeSubscriptionBody() async {
    await _cancelRecordsRealtimeSubscription();
    if (!_hasAuthenticatedUserId) return;
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        _logRecordsRealtimeSubscribeQuiet('pb_http_backoff_active');
        _scheduleRecordsRealtimeReconnectAfterFailure();
        return;
      }
      final filter = _pocketBaseOwnerFilterClauseForRecords();
      if (filter == null || filter.isEmpty) return;
      Future<void> Function()? unsub;
      try {
        unsub = await _pb.collection(PbCollections.records).subscribe(
          '*',
          _onPbRecordsSubscriptionEvent,
          filter: filter,
          expand: '$kPbRecordCategoryExpand,$kPbRecordTagsExpand',
        );
      } on ClientException catch (_) {
        unsub = await _pb.collection(PbCollections.records).subscribe(
          '*',
          _onPbRecordsSubscriptionEvent,
          filter: filter,
          expand: kPbRecordCategoryExpand,
        );
      } catch (_) {
        unsub = await _pb.collection(PbCollections.records).subscribe(
          '*',
          _onPbRecordsSubscriptionEvent,
          filter: filter,
        );
      }
      _recordsRealtimeUnsubscribe = unsub;
      _recordsRealtimeFailureStreak = 0;
      _recordsRealtimeReconnectTimer?.cancel();
      _recordsRealtimeReconnectTimer = null;
    } catch (e) {
      _logRecordsRealtimeSubscribeQuiet(e);
      _scheduleRecordsRealtimeReconnectAfterFailure();
    }
  }

  /// PocketBase: **records** for the current user with category + tags expands (@POCKETBASE_MANIFEST).
  /// Updates [_cachedFlatRecords] for timeline filtering without repeated GETs.
  ///
  /// When [forceNetwork] is false (default), returns **cached** rows for [\_kMinGapRecordsNetworkFetch]
  /// after a successful sync — kills VPS spam from UI/timer loops. Use **true** after mutations / pull-to-refresh.
  Future<List<Map<String, dynamic>>> fetchRecords({bool forceNetwork = false}) async {
    final pid = currentProfileId;
    if (pid == null || pid.isEmpty) {
      _cachedFlatRecords = [];
      return [];
    }
    final now = DateTime.now();
    if (!forceNetwork &&
        _lastSuccessfulRecordsNetworkFetchAt != null &&
        now.difference(_lastSuccessfulRecordsNetworkFetchAt!) <
            _kMinGapRecordsNetworkFetch &&
        _cachedFlatRecords.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_cachedFlatRecords);
    }
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        return List<Map<String, dynamic>>.from(_cachedFlatRecords);
      }
      final filterClause = _pocketBaseOwnerFilterClauseForRecords();
      if (filterClause == null || filterClause.isEmpty) {
        _cachedFlatRecords = [];
        return [];
      }
      final expandRel =
          '$kPbRecordCategoryExpand,$kPbRecordTagsExpand';
      List<RecordModel> list;
      try {
        list = await _pb.collection(PbCollections.records).getFullList(
          filter: filterClause,
          expand: expandRel,
        );
      } on ClientException catch (_) {
        list = await _pb.collection(PbCollections.records).getFullList(
          filter: filterClause,
          expand: kPbRecordCategoryExpand,
        );
        if (kDebugMode) {
          debugPrint(
            '[PB] fetchRecords: retry without $kPbRecordTagsExpand (schema?)',
          );
        }
      }
      await Future<void>.delayed(Duration.zero);
      final kept = <Map<String, dynamic>>[];
      try {
        for (final r in list) {
          try {
            final m = _recordMapFromPb(r);
            final pk = recordsTablePk(m);
            if (pk.isEmpty) {
              _log(
                'GHOST_ROW_SKIPPED: PB record missing PK (keys=${m.keys.map((k) => k.toString()).take(12).join(",")})',
              );
              continue;
            }
            kept.add(Map<String, dynamic>.from(m));
          } catch (e, st) {
            final rowData = '${r.id} data=${r.data}';
            _log('RECORD_PARSE_ROW: $e | $rowData');
            _log(st.toString());
          }
        }
      } catch (e, st) {
        _log('fetchRecords: mapping loop failed: $e');
        _log(st.toString());
      }
      _cachedFlatRecords = kept;
      _pruneRecord404DeadletterUsingCache();
      _lastSuccessfulRecordsNetworkFetchAt = DateTime.now();
      if (kDebugMode && forceNetwork) {
        debugPrint(
          '[PB] fetchRecords: ${kept.length} rows (expand $expandRel) @ $kPocketBaseUrl',
        );
      }
      if (forceNetwork && _isInitialized) {
        _notifyTimelineAfterRecordCacheMutation();
      }
      final cacheKey = _scopedDataCacheKey(_cacheRecordsFlatKey);
      final keptJson = await compute(_encodeRecordsFlatForPrefs, kept);
      unawaited(() async {
        try {
          final prefs = _prefs ?? await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, keptJson);
        } catch (_) {}
      }());
      return _cachedFlatRecords;
    } catch (e) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchRecords');
      await _hydrateRecordsCacheFromPrefsIfEmpty();
      return List<Map<String, dynamic>>.from(_cachedFlatRecords);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRecordsIntoCache({
    bool forceNetwork = false,
  }) =>
      fetchRecords(forceNetwork: forceNetwork);

  Future<List<Map<String, dynamic>>> getRecords({bool forceNetwork = false}) =>
      fetchRecords(forceNetwork: forceNetwork);

  Future<void> _loadRulesFromNoco() async {
    List<Map<String, dynamic>>? allRows;
    try {
      allRows = await _fetchAllCategoryMapsForUser();
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        await prefs.setString(
          _scopedDataCacheKey(_cacheCategoriesRawKey),
          jsonEncode(allRows),
        );
      } catch (_) {}
    } catch (e) {
      _log('CATEGORY_FETCH: $e');
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        final raw = prefs.getString(_scopedDataCacheKey(_cacheCategoriesRawKey));
        if (raw != null && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            allRows = [
              for (final e in decoded)
                if (e is Map) Map<String, dynamic>.from(e as Map),
            ];
          }
        }
      } catch (_) {}
    }
    if (allRows == null || allRows.isEmpty) {
      _rules = [];
      _reservedCategorySlugsLower.clear();
      _categoryDialogUniverse = [];
      _categoryController.add(List.from(_rules));
      return;
    }
    try {
      _rebuildReservedCategorySlugsFromRows(allRows);
      _rebuildCategoryDialogUniverse(allRows);
      final flat = allRows
          .map((e) => _flattenNocoRecord(e, allowCategoryIdAsRowPk: true))
          .where(_categoryFlatRowIsActive)
          .toList();
      final built = flat.isEmpty
          ? (<CategoryRule>[], <List<CategoryRule>>[])
          : _buildCategoryTreeFromFlat(flat);
      _rules = built.$1;
      _categoryController.add(List.from(_rules));
      for (final g in built.$2) {
        unawaited(
          _persistCategoryOrdersBulkForce(g, contextLabel: 'nullOrderInit'),
        );
      }
      _log('Successfully loaded ${_rules.length} categories');
    } catch (e, s) {
      _log('CATEGORY_CRASH: $e');
      _log(s);
      _rules = [];
      _reservedCategorySlugsLower.clear();
      _categoryDialogUniverse = [];
      _categoryController.add(List.from(_rules));
    }
  }

  /// Reload categories (active + archived metadata) from PocketBase into [_rules] and dialog universe.
  Future<void> refreshCategoryRulesFromServer() => _loadRulesFromNoco();

  /// Breadcrumb of local category ids from root to [leafLocalId] (inclusive).
  List<int> categoryPathFromRootToLocalId(int leafLocalId) {
    List<int>? found;
    bool walk(CategoryRule node, List<int> prefix) {
      final path = [...prefix, node.id];
      if (node.id == leafLocalId) {
        found = path;
        return true;
      }
      for (final c in node.children ?? []) {
        if (walk(c, path)) return true;
      }
      return false;
    }

    for (final r in _rules) {
      if (walk(r, [])) break;
    }
    return found ?? const [];
  }

  CategoryRule? getCategoryRuleByBackendRowId(String pocketBaseRowId) {
    final t = pocketBaseRowId.trim();
    if (t.isEmpty) return null;
    CategoryRule? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if ((r.backendRowId ?? '').trim() == t) {
          found = r;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  int? findActiveLocalCategoryIdByDisplayName(String displayName) {
    final key = displayName.trim().toLowerCase();
    if (key.isEmpty) return null;
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.name.trim().toLowerCase() == key) {
          found = r.id;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  CategoryNameInputStatus classifyCategoryDisplayNameInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return CategoryNameInputStatus.empty;
    final activeId = findActiveLocalCategoryIdByDisplayName(trimmed);
    if (activeId != null) {
      return CategoryNameInputStatus.active(activeId);
    }
    final key = trimmed.toLowerCase();
    for (final e in _categoryDialogUniverse) {
      if ((e['nameLower'] as String?) != key) continue;
      if (e['isArchived'] == true) {
        final pb = (e['pbRowId'] ?? '').toString().trim();
        if (pb.isNotEmpty) return CategoryNameInputStatus.archived(pb);
      }
    }
    return CategoryNameInputStatus.available;
  }

  /// Sets `is_archived` false on a PocketBase **categories** row. Returns local id after reload.
  Future<int?> restoreArchivedCategory(String pbRowId) async {
    final rid = pbRowId.trim();
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return null;
    if (rid.isEmpty || !_isLikelyPocketBaseRowId(rid)) return null;
    try {
      await ensurePocketBaseReady();
      final rec = await _pb.collection(PbCollections.categories).getOne(rid);
      final m = Map<String, dynamic>.from(rec.data);
      final biz = _sanitizePkString(m['category_id']?.toString());
      final ordRaw = m['order'];
      final ord = ordRaw is int
          ? ordRaw
          : int.tryParse(ordRaw?.toString() ?? '') ?? 0;
      final patchBody = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'is_archived': false,
          'order': ord,
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
        }),
      );
      await _pb.collection(PbCollections.categories).update(rid, body: patchBody);
      await _loadRulesFromNoco();
      return getCategoryRuleByBackendRowId(rid)?.id;
    } on ClientException catch (e) {
      _log('RESTORE_CATEGORY: $e');
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      return null;
    } catch (e) {
      _log('RESTORE_CATEGORY: $e');
      return null;
    }
  }

  /// NocoDB v3 returns { id, fields: { ... } }; flatten so callers see one map.
  ///
  /// **Critical:** For the **records** (and plans) tables, never use [category_id] as the row PK.
  /// If the API omits top-level [id], falling back to category_id produces ghosts like
  /// `PATCH .../records/361` where 361 is a category — server returns 404, timers never stop.
  ///
  /// Stamps [_nocoEnvelopePkKey] from the **wrapper** only (never from fields alone) so REST
  /// always uses the real list-item PK when Noco sends it.
  ///
  /// For **categories** only, pass [allowCategoryIdAsRowPk] = true so string PKs like `astra`
  /// still resolve when they live under `category_id`.
  static Map<String, dynamic> _flattenNocoRecord(
    Map<String, dynamic> record, {
    bool allowCategoryIdAsRowPk = false,
  }) {
    if (record.containsKey('fields') && record['fields'] is Map) {
      final fields = Map<String, dynamic>.from(record['fields'] as Map);
      // Compatibility shim: some tables expose a string relational key as 'id1'.
      // We do not use 'id1' in app logic; we map it into 'normalized_id' if missing.
      if (!fields.containsKey('normalized_id') &&
          fields.containsKey('id1') &&
          fields['id1'] != null &&
          fields['id1'].toString().trim().isNotEmpty) {
        fields['normalized_id'] = fields['id1'].toString().trim();
      }
      final envPk = _envelopePkOnlyFromWrapper(record);
      final uuidInFields =
          allowCategoryIdAsRowPk ? null : _firstUuidLikeRecordIdInFields(fields);

      if (!allowCategoryIdAsRowPk) {
        // Records/plans: REST path = **system integer** from wrapper only (never business UUID).
        final sysInt = _parseSystemIntFromWrapper(record);
        if (sysInt != null) {
          fields[_nocoSystemRowIdKey] = sysInt;
          fields['id'] = sysInt;
        }
        if (uuidInFields != null &&
            (envPk == null || _isSmallIntegerString(envPk))) {
          fields[_nocoEnvelopePkKey] = uuidInFields;
        } else         if (envPk != null) {
          fields[_nocoEnvelopePkKey] = envPk;
        }
        // M2M link column may sit on the v3 list **envelope** (nested expand) or match `fields`
        // when using `fields=` GET. If the wrapper has the link key, **overwrite** `fields` so
        // chips survive refresh.
        final linkKey = _plansToTagsLinkColumnSystemId;
        if (record.containsKey(linkKey)) {
          fields[linkKey] = record[linkKey];
        }
        return fields;
      }

      if (envPk != null) {
        fields[_nocoEnvelopePkKey] = envPk;
      }

      dynamic resolvedPk = record['id'] ??
          record['Id'] ??
          record['ID'] ??
          record['record_id'] ??
          record['Record_id'];
      final rs = resolvedPk?.toString().trim() ?? '';
      if (rs.isEmpty) {
        resolvedPk = fields['record_id'] ??
            fields['Record_id'] ??
            fields['id'] ??
            fields['Id'] ??
            fields['ID'];
      }
      final rs2 = resolvedPk?.toString().trim() ?? '';
      if (rs2.isEmpty) {
        resolvedPk = fields['category_id'] ??
            fields['Category_id'] ??
            record['category_id'] ??
            record['Category_id'];
      }
      final stamped = _sanitizePkString(fields[_nocoEnvelopePkKey]?.toString());
      if (stamped != null && stamped.isNotEmpty) {
        fields['id'] = stamped;
        resolvedPk = stamped;
      }
      final pkStr = resolvedPk?.toString().trim() ?? '';
      if (pkStr.isNotEmpty) {
        fields['id'] = resolvedPk;
      }
      // Categories (@DATA_MAP): REST row URL must use wrapper **Id** (int). Never leave `id` as
      // `category_id` UUID after fallbacks above.
      final categoryWrapperSysId = _parseSystemIntFromWrapper(record);
      if (categoryWrapperSysId != null && categoryWrapperSysId > 0) {
        fields[_nocoSystemRowIdKey] = categoryWrapperSysId;
        fields['id'] = categoryWrapperSysId;
      }
      return fields;
    }
    final flat = Map<String, dynamic>.from(record);
    if (!allowCategoryIdAsRowPk) {
      final sysInt = _parseSystemIntFromWrapper(record);
      if (sysInt != null) {
        flat[_nocoSystemRowIdKey] = sysInt;
        flat['id'] = sysInt;
      }
      final envFlat = _envelopePkOnlyFromWrapper(flat);
      final uuidFlat = _firstUuidLikeRecordIdInFields(flat);
      if (uuidFlat != null &&
          (envFlat == null || _isSmallIntegerString(envFlat))) {
        flat[_nocoEnvelopePkKey] = uuidFlat;
      } else if (envFlat != null) {
        flat[_nocoEnvelopePkKey] = envFlat;
      }
      return flat;
    }
    final rpFlat = _wrapperRestPathIdOnly(record);
    if (rpFlat != null && rpFlat.isNotEmpty) {
      flat[_nocoCategoryRestSegmentKey] = rpFlat;
    }
    final envFlat = _envelopePkOnlyFromWrapper(flat);
    if (envFlat != null) {
      flat[_nocoEnvelopePkKey] = envFlat;
    }
    final catSys = _parseSystemIntFromWrapper(record);
    if (catSys != null && catSys > 0) {
      flat[_nocoSystemRowIdKey] = catSys;
      flat['id'] = catSys;
    }
    return flat;
  }

  /// PocketBase **records** row id (string) or legacy numeric id string.
  static String recordsTablePk(Map<String, dynamic> row) {
    final pb = row['_pb_record_id']?.toString().trim() ?? '';
    if (pb.isNotEmpty) return pb;
    final idStr = row['id']?.toString().trim() ?? '';
    if (idStr.isNotEmpty && int.tryParse(idStr) == null) {
      return idStr;
    }
    final sys = row[_nocoSystemRowIdKey];
    if (sys is int) return sys.toString();
    if (sys != null) {
      final p = int.tryParse(sys.toString());
      if (p != null) return p.toString();
    }
    final idRaw = row['id'];
    if (idRaw is int) return idRaw.toString();
    final parsed = int.tryParse((idRaw ?? '').toString().trim());
    if (parsed != null) return parsed.toString();
    return '';
  }

  /// When updating a row, include business `record_id` in `fields` if known (Noco column alignment).
  static void _mergeBusinessRecordIdIntoFields(
    Map<String, dynamic> fields,
    Map<String, dynamic>? row,
  ) {
    if (row == null) return;
    final biz = (row['record_id'] ?? '').toString().trim();
    if (biz.isNotEmpty) fields['record_id'] = biz;
  }

  Map<String, dynamic>? _findCachedRecordRowByRestCandidate(String candidate) {
    final c = candidate.trim();
    if (c.isEmpty) return null;
    for (final r in _cachedFlatRecords) {
      if (recordsTablePk(r) == c) return r;
      if ((r['record_id'] ?? '').toString().trim() == c) return r;
    }
    return null;
  }

  void _logRecordsPatchDispatch(String restId) {}

  void _logRecordsDeleteDispatch(String restId) {}

  /// PocketBase row `id` from a cached flat row — never a legacy UUID mistaken for REST id.
  String? _pbSystemIdFromCachedRecordRow(Map<String, dynamic> r) {
    final pb = r['_pb_record_id']?.toString().trim() ?? '';
    if (_isLikelyPocketBaseRowId(pb)) return pb;
    final idStr = r['id']?.toString().trim() ?? '';
    if (_isLikelyPocketBaseRowId(idStr)) return idStr;
    return null;
  }

  /// When UI still holds a [fields.record_id] UUID but REST needs wrapper [id], map to [recordsTablePk].
  String? _resolveRecordsRestPathId(String candidate) {
    final c = candidate.trim();
    if (c.isEmpty) return null;
    for (final r in _cachedFlatRecords) {
      final rest = recordsTablePk(r);
      if (rest.isNotEmpty &&
          rest == c &&
          _isLikelyPocketBaseRowId(rest)) {
        return rest;
      }
      final biz = (r['record_id'] ?? '').toString().trim();
      if (biz.isNotEmpty && biz == c) {
        final pbOnly = _pbSystemIdFromCachedRecordRow(r);
        if (pbOnly != null) return pbOnly;
      }
    }
    return null;
  }

  static void _logIdMapTranslated(String inputId, String pocketBaseId) {}

  /// Snack from the Brain; falls back to [notifications] when [appSnackMessengerKey] has no overlay yet.
  void _brainSnackError(String message) {
    try {
      final messenger = appSnackMessengerKey.currentState;
      if (messenger != null) {
        AppSnack.show(message, error: true);
        return;
      }
    } catch (_) {}
    try {
      if (!_notify.isClosed) {
        _notify.add(message);
      }
    } catch (_) {}
  }

  void _snackStopHttpFailure(int code) {
    final loc = currentLocale.value;
    final msg = code == 404
        ? t(loc, 'error_stop_not_found_404')
        : '${t(loc, 'error_stop_http_prefix')}$code';
    _brainSnackError(msg);
  }

  void _snackDeleteHttpFailure(int code) {
    final loc = currentLocale.value;
    final msg = code == 404
        ? t(loc, 'error_stop_not_found_404')
        : '${t(loc, 'error_delete_http_prefix')}$code';
    _brainSnackError(msg);
  }

  /// Stop / delete: **local** `record_id == docId` → PB id, then server lookup (@DATA_MAP).
  /// Throws [LegacyIdResolutionException] if no PocketBase row id can be found (**never** returns a legacy UUID).
  Future<String> _resolveRecordIdForStopOrDelete(String docId) async {
    final c = docId.trim();
    if (c.isEmpty) throw LegacyIdResolutionException(docId);
    if (_isLikelyPocketBaseRowId(c)) return c;

    String? scanLocal() {
      for (final r in _cachedFlatRecords) {
        final biz = (r['record_id'] ?? '').toString().trim();
        if (biz == c) {
          return _pbSystemIdFromCachedRecordRow(r);
        }
      }
      return null;
    }

    var pb = scanLocal();
    if (pb != null && pb.isNotEmpty) {
      _logIdMapTranslated(c, pb);
      return pb;
    }

    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
    } catch (_) {}

    pb = scanLocal();
    if (pb != null && pb.isNotEmpty) {
      _logIdMapTranslated(c, pb);
      return pb;
    }

    var fromServer = await _fetchPbRecordSysIdByRecordIdField(c);
    if (fromServer != null && fromServer.isNotEmpty) {
      _logIdMapTranslated(c, fromServer);
      return fromServer;
    }

    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
    } catch (_) {}
    pb = scanLocal();
    if (pb != null && pb.isNotEmpty) {
      _logIdMapTranslated(c, pb);
      return pb;
    }

    fromServer = await _fetchPbRecordSysIdByRecordIdField(c);
    if (fromServer != null && fromServer.isNotEmpty) {
      _logIdMapTranslated(c, fromServer);
      return fromServer;
    }

    throw LegacyIdResolutionException(c);
  }

  /// Cache-only resolution for shadow Stop (no network) — PB row id or null.
  String? _tryResolveRecordIdFromCacheOnly(String docId) {
    final c = docId.trim();
    if (c.isEmpty) return null;
    if (_isLikelyPocketBaseRowId(c)) return c;
    for (final r in _cachedFlatRecords) {
      final biz = (r['record_id'] ?? '').toString().trim();
      if (biz == c) {
        final pb = _pbSystemIdFromCachedRecordRow(r);
        if (pb != null && pb.isNotEmpty) return pb;
      }
    }
    return null;
  }

  Future<String> _resolveRecordIdForRestUrl(String candidate) async {
    final c = candidate.trim();
    if (c.isEmpty) return c;
    if (_isLikelyPocketBaseRowId(c)) return c;
    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
    } catch (_) {}
    final fromCache = _resolveRecordsRestPathId(c);
    if (fromCache != null &&
        fromCache.isNotEmpty &&
        _isLikelyPocketBaseRowId(fromCache)) {
      if (!_isLikelyPocketBaseRowId(c) && fromCache != c) {
        debugPrint('ID TRANSLATION: Legacy UUID $c -> PocketBase ID $fromCache');
      }
      if (fromCache != c) {
        _log(
          'REST_ID_RESOLVE: business/cache id "$c" -> Noco URL segment "$fromCache"',
        );
      }
      return fromCache;
    }
    final fromServer = await _fetchPbRecordSysIdByRecordIdField(c);
    if (fromServer != null && fromServer.isNotEmpty) {
      if (fromServer != c) {
        debugPrint('ID TRANSLATION: Legacy UUID $c -> PocketBase ID $fromServer');
      }
      return fromServer;
    }
    return c;
  }

  /// PocketBase **records**: when `category_id` is a **relation** to `categories`, the API body must
  /// contain the **categories** row system id (~15 chars), never the business slug (`life`, etc.).
  /// Optional field `category_link` is not sent here (timeline GET may still use `expand: category_link`
  /// per [kPbRecordCategoryExpand] if that field exists Admin-side).
  void _mapCategoryIdToLinkForPb(Map<String, dynamic> merged) {
    merged.remove('category_link');
    if (!merged.containsKey('category_id')) return;
    final rawCat = merged['category_id'];
    final key = rawCat?.toString().trim() ?? '';
    if (key.isEmpty) {
      merged.remove('category_id');
      return;
    }
    var localId = int.tryParse(key);
    localId ??= findCategoryIdForStoredCategoryKey(key);
    final rule = categoryRuleForRecordCategoryId(localId);
    final bid = _categoryBackendRowIdStrict(rule);
    if (bid != null &&
        bid.isNotEmpty &&
        bid != 'uncategorized' &&
        _isLikelyPocketBaseRowId(bid) &&
        _categoryPbRowIdKnownInRules(bid)) {
      merged['category_id'] = bid;
    } else {
      merged.remove('category_id');
    }
  }

  /// True if [pbId] matches a loaded [CategoryRule.backendRowId] (tree walk).
  bool _categoryPbRowIdKnownInRules(String pbId) {
    final t = pbId.trim();
    if (t.isEmpty) return false;
    var found = false;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if ((r.backendRowId ?? '').trim() == t) {
          found = true;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  /// Records POST/PATCH: strip legacy `category_link` key; ensure relation [category_id] is only a known PB id.
  void _sanitizeOutgoingCategoryLink(Map<String, dynamic> merged) {
    merged.remove('category_link');
    if (!merged.containsKey('category_id')) return;
    final raw = merged['category_id']?.toString().trim() ?? '';
    if (raw.isEmpty ||
        !_isLikelyPocketBaseRowId(raw) ||
        !_categoryPbRowIdKnownInRules(raw)) {
      merged.remove('category_id');
    }
  }

  /// True when [id] maps to a PocketBase **categories** system id for outgoing record POST/PATCH
  /// (same conditions as [_mapCategoryIdToLinkForPb] before [merged.remove] strips the field).
  bool _categoryIdResolvableForPbRecordPost(int? id) {
    if (!_planLocalCategoryIdIsConcrete(id)) return false;
    final rule = getCategoryRuleById(id!);
    if (rule == null || rule.isArchived) return false;
    final bid = _categoryBackendRowIdStrict(rule);
    if (bid == null || bid.isEmpty) return false;
    if (!_isLikelyPocketBaseRowId(bid)) return false;
    return _categoryPbRowIdKnownInRules(bid);
  }

  /// Prefer a leaf (no children) with a resolvable PB id; else first resolvable category in tree order.
  int? _firstLeafCategoryIdFromRules() {
    final pairs = allCategoryIdPathPairs;
    for (final p in pairs) {
      if (p.id == CategoryRule.uncategorizedSyntheticId) continue;
      if (getChildrenOf(p.id).isEmpty &&
          _categoryIdResolvableForPbRecordPost(p.id)) {
        return p.id;
      }
    }
    for (final p in pairs) {
      if (p.id == CategoryRule.uncategorizedSyntheticId) continue;
      if (_categoryIdResolvableForPbRecordPost(p.id)) {
        return p.id;
      }
    }
    return null;
  }

  /// Cold-start: when [preferred] is not a concrete local choice, use [defaultCategoryId] then first leaf.
  /// Does not replace a concrete [preferred] (even if it cannot be sent to PocketBase — caller may fail).
  int? _resolveColdStartRecordCategoryId(int? preferred) {
    if (_categoryIdResolvableForPbRecordPost(preferred)) return preferred;
    if (_planLocalCategoryIdIsConcrete(preferred)) return preferred;

    final d = defaultCategoryId;
    if (_categoryIdResolvableForPbRecordPost(d)) return d;
    return _firstLeafCategoryIdFromRules();
  }

  /// PocketBase **records** PATCH. Returns HTTP-style status (200, 404, …).
  Future<int> _patchRecordsRowWith404Recovery({
    required String originalQueryId,
    required String restId,
    required Map<String, dynamic> fields,
    bool debugPbClientException = false,
  }) async {
    _lastRecordsPatchSkippedDeadLetter = false;
    final rid = restId.trim();
    final oq = originalQueryId.trim();
    if (rid.isNotEmpty &&
        (_recordRestDefinitive404Keys.contains(rid) ||
            (oq.isNotEmpty && _recordRestDefinitive404Keys.contains(oq)))) {
      _lastRecordsPatchSkippedDeadLetter = true;
      _log('RECORDS_PB SKIP_PATCH: dead-letter 404 rid=$rid');
      _purgeGhostRecordById(rid.isNotEmpty ? rid : oq);
      return 404;
    }
    _requireAuthUserIdForWrite();
    var payloadForError = Map<String, dynamic>.from(fields);
    try {
      await ensurePocketBaseReady();
      final mergedRaw = Map<String, dynamic>.from(fields);
      mergedRaw['user_id'] = _pidForPbFilter;
      _mergeBusinessRecordIdIntoFields(
        mergedRaw,
        _findCachedRecordRowByRestCandidate(rid),
      );
      final merged = _recordsPatchFieldsJsonStrings(
        _nocoFieldsForPatch(mergedRaw),
      );
      _mapCategoryIdToLinkForPb(merged);
      _sanitizeOutgoingCategoryLink(merged);
      merged['user_id'] = _pidForPbFilter;
      payloadForError = merged;
      _logRecordsPatchDispatch(rid);
      final updated =
          await _pb.collection(PbCollections.records).update(rid, body: merged);
      _upsertFlatRecordFromPbModel(updated,
          suppressTimelineNotify: true);
      return 200;
    } on ClientException catch (e) {
      if (debugPbClientException) {
        final patchFallbackUrl = () {
          try {
            final b = (_pocketBase?.baseURL ?? '').trim();
            if (b.isEmpty) return '(unknown URL)';
            final bt = b.replaceAll(RegExp(r'/$'), '');
            return '$bt/api/collections/${PbCollections.records}/records/$rid';
          } catch (_) {
            return '(unknown URL)';
          }
        }();
        _debugPrintPocketBaseClientException(
          operation: 'records PATCH (stop / update)',
          e: e,
          payload: payloadForError,
          fallbackUrl: patchFallbackUrl,
        );
      }
      if (e.statusCode == 404) {
        _purgeGhostRecordById(rid.isNotEmpty ? rid : oq);
      }
      return e.statusCode;
    } catch (e, st) {
      debugPrint('[ABORT_REASON] records PATCH failed inside try (before or after [DISPATCH]): $e');
      _log(st.toString());
      return 500;
    }
  }

  Future<int> _deleteRecordsRowWithFallback({
    required String originalQueryId,
    required String restId,
  }) async {
    final rid = restId.trim();
    if (rid.isEmpty) return 400;
    final oq = originalQueryId.trim();
    if (_recordRestDefinitive404Keys.contains(rid) ||
        (oq.isNotEmpty && _recordRestDefinitive404Keys.contains(oq))) {
      _log('RECORDS_PB SKIP_DELETE: dead-letter rid=$rid');
      _purgeGhostRecordById(rid.isNotEmpty ? rid : oq);
      return 404;
    }
    try {
      await ensurePocketBaseReady();
      _logRecordsDeleteDispatch(rid);
      await _pb.collection(PbCollections.records).delete(rid);
      return 204;
    } on ClientException catch (e) {
      return e.statusCode;
    } catch (_) {
      return 500;
    }
  }

  Future<String?> _createRecordPb(Map<String, dynamic> rawFields) async {
    try {
      await ensurePocketBaseReady();
      // DATA_MAP: identity is pb.authStore.model.id — in SDK 0.21 [model] aliases [record].
      final authRec = _pb.authStore.record;
      final authRowId = (authRec?.id ?? '').trim();
      if (authRowId.isEmpty) {
        throw AuthenticatedUserIdRequiredException();
      }
      final merged = _recordsPatchFieldsJsonStrings(
        _nocoFieldsForPatch(Map<String, dynamic>.from(rawFields)),
      );
      _mapCategoryIdToLinkForPb(merged);
      _sanitizeOutgoingCategoryLink(merged);
      merged['user_id'] = authRowId;
      final created =
          await _pb.collection(PbCollections.records).create(body: merged);
      _upsertFlatRecordFromPbModel(created,
          preserveExpand: false, suppressTimelineNotify: true);
      return created.id;
    } on ClientException catch (e) {
      debugPrint('PB_CREATE_ERROR_DETAILS: ${e.response}');
      _log('RECORDS_PB create failed: ${e.statusCode}');
      final code = e.statusCode;
      if (code == 403 || code == 401) {
        final loc = currentLocale.value;
        final msg = code == 401
            ? t(loc, 'error_record_create_unauthorized')
            : t(loc, 'error_record_create_forbidden');
        _brainSnackError(msg);
      }
      return null;
    } catch (e, st) {
      _log('RECORDS_PB create failed: $e');
      _log(st.toString());
      if (e is AuthenticatedUserIdRequiredException) {
        final loc = currentLocale.value;
        _brainSnackError(t(loc, 'error_record_create_unauthorized'));
      }
      return null;
    }
  }

  void _purgeGhostRecordById(String recordId) {
    final rid = recordId.trim();
    if (rid.isEmpty) return;
    final blockKeys = _collectRecordKeysFromCache(rid);
    for (final k in blockKeys) {
      if (k.isNotEmpty) _recordRestDefinitive404Keys.add(k);
    }
    if (rid.isNotEmpty) _recordRestDefinitive404Keys.add(rid);
    _cachedFlatRecords.removeWhere((r) {
      final pk = recordsTablePk(r).trim();
      if (pk == rid) return true;
      final sys = r[_nocoSystemRowIdKey];
      if (sys is int && sys.toString() == rid) return true;
      if (sys != null && sys.toString().trim() == rid) return true;
      final env = (r[_nocoEnvelopePkKey] ?? '').toString().trim();
      if (env.isNotEmpty && env == rid) return true;
      final localId = (r['id'] ?? '').toString().trim();
      final localRecordId = (r['record_id'] ?? '').toString().trim();
      return localId == rid || localRecordId == rid;
    });
    _notifyTimelineAfterRecordCacheMutation();
    _log('SYNC: purged ghost local record id=$rid after 404');
  }

  /// ACTIVE_STATUS_LAW (@ARCHITECTURE.md): running ⇔ no end_time **and** status == running.
  static bool isRecordMapActuallyRunning(Map<String, dynamic> data) {
    final end = data['endTime'] ?? data['end_time'];
    if (end != null && end.toString().trim().isNotEmpty) return false;
    final s = (data['status'] as String? ?? '').trim();
    return s == 'running';
  }

  /// Flat Noco row (snake_case) before [_rowToRecordMap].
  /// UI / streams: only explicit `running` counts as active.
  static bool _isNocoRowActiveRunning(Map<String, dynamic> r) {
    final end = r['end_time'] ?? r['endTime'];
    if (end != null && end.toString().trim().isNotEmpty) return false;
    final s = (r['status'] ?? '').toString().trim().toLowerCase();
    return s == 'running';
  }

  /// Singleton enforcement: any **open** interval (no end_time) that is not clearly completed/stopped.
  /// Closes legacy rows missing `status` so two timers cannot stay open (@ARCHITECTURE §3).
  static bool _isNocoRowSacredStopTarget(Map<String, dynamic> r) {
    final end = r['end_time'] ?? r['endTime'];
    if (end != null && end.toString().trim().isNotEmpty) return false;
    final s = (r['status'] ?? '').toString().trim().toLowerCase();
    if (s == 'stopped' || s == 'completed') return false;
    if (s == 'running') return true;
    if (s.isEmpty) return true;
    return false;
  }

  /// Sacred Law scope: only rows whose [start_time] falls on **profile wall-clock today**
  /// (same as timeline buckets). Avoids PATCHing legacy `running` ghosts from other wall-clock days.
  bool _rowStartWallDayIsProjectedToday(Map<String, dynamic> r) {
    try {
      final stUtc = _parseDateTimeUtc(r['start_time']);
      if (stUtc == null) return false;
      return _timelineDeviceLocalDayKeyFromUtc(stUtc) ==
          getTimelineDeviceLocalTodayDateKey();
    } catch (_) {
      return false;
    }
  }

  /// True when [start_time] profile wall-clock day is **strictly before** projected today (multi-day open).
  bool _rowStartWallDayIsBeforeProjectedToday(Map<String, dynamic> r) {
    try {
      final stUtc = _parseDateTimeUtc(r['start_time']);
      if (stUtc == null) return false;
      return _timelineDeviceLocalDayKeyFromUtc(stUtc)
              .compareTo(getTimelineDeviceLocalTodayDateKey()) <
          0;
    } catch (_) {
      return false;
    }
  }

  /// After [byPk] has today’s open rows, add up to [_sacredStaleOpenCap] **oldest** pre-today open
  /// rows from [rows] (singleton handoff for rare multi-day `running` without mass-PATCH).
  void _mergeSacredStaleOpenCandidates(
    List<Map<String, dynamic>> rows,
    Map<String, Map<String, dynamic>> byPk,
  ) {
    final stale = <Map<String, dynamic>>[];
    for (final r in rows) {
      if (_rowHasNonEmptyParent(r['parent_id'])) continue;
      if (!_isNocoRowSacredStopTarget(r)) continue;
      if (_rowStartWallDayIsProjectedToday(r)) continue;
      if (!_rowStartWallDayIsBeforeProjectedToday(r)) continue;
      final id = recordsTablePk(r);
      if (id.isEmpty) continue;
      if (byPk.containsKey(id)) continue;
      stale.add(r);
    }
    stale.sort((a, b) {
      final ta = _parseDateTimeUtc(a['start_time']);
      final tb = _parseDateTimeUtc(b['start_time']);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    var added = 0;
    for (final r in stale) {
      if (added >= _sacredStaleOpenCap) break;
      final id = recordsTablePk(r);
      if (id.isEmpty) continue;
      byPk[id] = r;
      added++;
    }
    if (stale.isNotEmpty) {
      _log(
        'SACRED_LAW: stale pre-today open: merged $added of ${stale.length} candidate(s) (cap=$_sacredStaleOpenCap, oldest first)',
      );
    }
  }

  /// @DATA_MAP.md category display: `name` (legacy JSON may still carry `tag`; read only).
  static String _categoryDisplayNameFromRow(Map<String, dynamic> row) {
    final m = Map<String, dynamic>.from(row);
    if (row['fields'] is Map) {
      m.addAll(Map<String, dynamic>.from(row['fields'] as Map));
    }
    for (final k in <String>[
      'name',
      'Name',
      'tag',
      'Tag',
      'normalized_id',
      'normalizedId',
    ]) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return 'Untitled';
  }

  /// GET records where `status` is running for current user (server truth for Sacred Law).
  Future<List<Map<String, dynamic>>> _fetchRunningRecordsFromNoco() async {
    try {
      await ensurePocketBaseReady();
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return [];
      final uid = _escapeForPbFilter(authId);
      final list = await _pb.collection(PbCollections.records).getFullList(
        filter: 'user_id = "$uid" && status = "running"',
      );
      return list.map(_recordMapFromPb).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fresh server map `pocketbase_row_id -> row` for **primary** rows in sacred running state.
  Future<Map<String, Map<String, dynamic>>> _fetchServerRunningSacredPrimariesByPbId() async {
    final rows = await _fetchRunningRecordsFromNoco();
    final byId = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      if (_rowHasNonEmptyParent(r['parent_id'])) continue;
      if (!_isNocoRowSacredStopTarget(r)) continue;
      final id = recordsTablePk(r);
      if (id.isEmpty) continue;
      byId[id] = r;
    }
    return byId;
  }

  /// `end_time` for stopping [serverRow] when handing off to a new record that starts at [handoffIsoUtc].
  /// Never returns a value before the row's own [start_time] (avoids 400 / hook rejection).
  String _highlanderStopIsoForServerRow({
    required String handoffIsoUtc,
    required Map<String, dynamic> serverRow,
  }) {
    final handoff = _parseDateTimeUtc(handoffIsoUtc) ?? getPlanetaryNow().toUtc();
    final rowStart = _parseDateTimeUtc(serverRow['start_time']);
    final t =
        rowStart != null && handoff.isBefore(rowStart) ? rowStart : handoff;
    return t.toUtc().toIso8601String();
  }

  static int _rowInt(dynamic v, [int d = 0]) {
    if (v == null) return d;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? d;
  }

  /// Local [CategoryRule.id] only when Noco wrapper id is non-numeric — **not** for auth/`user_id`.
  static int _hashStringToPositiveIntForCategoryTreeLocalIdOnly(
    String raw, [
    int fallback = 0,
  ]) {
    final s = raw.trim();
    if (s.isEmpty) return fallback;
    var hash = 2166136261;
    for (final u in s.codeUnits) {
      hash ^= u;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    if (hash == 0) return fallback;
    return hash;
  }


  /// `true` if Noco sent an explicit `order` (including `0`); `false` if null / missing / empty string.
  static bool _categoryOrderRawIsExplicit(dynamic orderRaw) {
    if (orderRaw == null) return false;
    if (orderRaw is String && orderRaw.trim().isEmpty) return false;
    return true;
  }

  /// Normalizes flat NocoDB list into hierarchical CategoryRule tree. Re-links parents and children via parent_id; returns only roots.
  ///
  /// Second return: sibling groups that had null/missing `order` — each list shares one `parent_id` (roots use `''` key), renumbered 0..n−1 for persistence (@DATA_MAP §8).
  (List<CategoryRule> roots, List<List<CategoryRule>> orderInitGroups)
      _buildCategoryTreeFromFlat(List<Map<String, dynamic>> flat) {
    final all = <CategoryRule>[];
    final lookup = <String, CategoryRule>{};
    final parentIdsById = <int, String?>{};
    final orderExplicitByLocalId = <int, bool>{};
    for (final row in flat) {
      final fields = (row['fields'] is Map)
          ? Map<String, dynamic>.from(row['fields'] as Map)
          : row;
      final bizCategoryId = (fields['category_id'] ?? fields['Category_id'])
              ?.toString()
              .trim() ??
          '';
      final sysObj = row[_nocoSystemRowIdKey];
      final wrapperPk = ((sysObj != null &&
                  sysObj.toString().trim().isNotEmpty)
              ? sysObj.toString().trim()
              : (row['id'] ?? row['Id'])?.toString().trim()) ??
          '';
      final internalRowStr = wrapperPk;
      String? normalizedForMatching = bizCategoryId.isNotEmpty
          ? bizCategoryId
          : null;
      if (normalizedForMatching == null || normalizedForMatching.isEmpty) {
        final n = fields['normalized_id']?.toString().trim();
        if (n != null && n.isNotEmpty) normalizedForMatching = n;
      }
      final wrapperInt = _rowInt(wrapperPk);
      // Local list id = Noco wrapper **Id** when present (@DATA_MAP); else stable key from business fields only.
      final int nodeLocalId = wrapperInt != 0
          ? wrapperInt
          : _hashStringToPositiveIntForCategoryTreeLocalIdOnly(
              bizCategoryId.isNotEmpty
                  ? bizCategoryId
                  : (normalizedForMatching ??
                      fields['normalized_id']?.toString() ??
                      fields['tag']?.toString() ??
                      fields['name']?.toString() ??
                      'unknown'),
              1,
            );
      final pidRaw = row['parent_id'];
      final pidFlat = normalizeLinkScalar(pidRaw) ?? pidRaw;
      final parentIdStr = pidFlat == null || pidFlat.toString().trim().isEmpty
          ? null
          : pidFlat.toString().trim();
      parentIdsById[nodeLocalId] = parentIdStr;
      Map<String, List<String>>? keywords;
      final rawKw = row['keywords'];
      dynamic kwDecoded = rawKw;
      if (rawKw is String && rawKw.trim().isNotEmpty) {
        try {
          kwDecoded = jsonDecode(rawKw);
        } catch (_) {
          kwDecoded = null;
        }
      }
      if (kwDecoded is Map) {
        keywords = {};
        for (final e in kwDecoded.entries) {
          keywords[e.key.toString()] = e.value is List
              ? (e.value as List).map((x) => x.toString()).toList()
              : <String>[];
        }
      }
      Map<String, String>? loc;
      final rawLoc = row['localized_names'];
      dynamic locDecoded = rawLoc;
      if (rawLoc is String && rawLoc.trim().isNotEmpty) {
        try {
          locDecoded = jsonDecode(rawLoc);
        } catch (_) {
          locDecoded = null;
        }
      }
      if (locDecoded is Map) {
        loc = {};
        for (final e in locDecoded.entries) {
          loc[e.key.toString()] = e.value?.toString() ?? '';
        }
      }
      final orderRaw = row['order'] ?? fields['order'];
      final orderExplicit = _categoryOrderRawIsExplicit(orderRaw);
      orderExplicitByLocalId[nodeLocalId] = orderExplicit;
      final archRaw = row['is_archived'] ?? fields['is_archived'];
      final isArchivedCat = _jsonBoolFromDynamic(archRaw);
      final node = CategoryRule(
        id: nodeLocalId,
        name: _categoryDisplayNameFromRow(row),
        backendRowId: internalRowStr.isNotEmpty ? internalRowStr : null,
        normalizedId: normalizedForMatching,
        children: <CategoryRule>[],
        colorValue: _rowInt(row['color_value'], 0) == 0
            ? null
            : _rowInt(row['color_value']),
        iconCodePoint: _rowInt(row['icon_code_point'], 0) == 0
            ? null
            : _rowInt(row['icon_code_point']),
        keywords: keywords,
        localizedNames: loc,
        order: orderExplicit ? _rowInt(orderRaw) : 0,
        isArchived: isArchivedCat,
      );
      all.add(node);
      if (internalRowStr.isNotEmpty) lookup[internalRowStr] = node;
      if (bizCategoryId.isNotEmpty) lookup[bizCategoryId] = node;
      final nk = node.normalizedId?.trim();
      if (nk != null && nk.isNotEmpty) lookup[nk] = node;
      lookup[nodeLocalId.toString()] = node;
      final pbRowKey =
          (row['_pb_record_id'] ?? row['id'] ?? row['Id'])?.toString().trim();
      if (pbRowKey != null && pbRowKey.isNotEmpty) {
        lookup[pbRowKey] = node;
      }
    }
    var linksCreated = 0;
    for (final node in all) {
      final parentIdStr = parentIdsById[node.id];
      if (parentIdStr == null || parentIdStr.isEmpty) continue;
      final parent = lookup[parentIdStr];
      if (parent != null) {
        parent.children ??= <CategoryRule>[];
        parent.children!.add(node);
        linksCreated++;
      }
      // Missing parent: do not link — node is promoted to root in the pass below (dumb tree, always visible).
    }

    final roots = <CategoryRule>[];
    for (final node in all) {
      final parentIdStr = parentIdsById[node.id];
      if (parentIdStr == null ||
          parentIdStr.isEmpty ||
          lookup[parentIdStr] == null) {
        roots.add(node);
      }
    }

    final buckets = <String, List<CategoryRule>>{};
    for (final n in all) {
      final p = parentIdsById[n.id];
      final key = (p == null || p.isEmpty) ? '' : p;
      buckets.putIfAbsent(key, () => <CategoryRule>[]).add(n);
    }
    final orderInitGroups = <List<CategoryRule>>[];
    for (final bucket in buckets.values) {
      final anyImplicit =
          bucket.any((n) => orderExplicitByLocalId[n.id] != true);
      if (anyImplicit) {
        for (var i = 0; i < bucket.length; i++) {
          bucket[i].order = i;
        }
        orderInitGroups.add(List<CategoryRule>.from(bucket));
      }
    }

    _log(
        'TREE DEBUG: Total Categories: ${all.length}. Roots: ${roots.length}. Links: $linksCreated. Order init groups: ${orderInitGroups.length}',
    );
    _sortCategoryBranch(roots);
    return (roots, orderInitGroups);
  }

  void _sortCategoryBranch(List<CategoryRule> nodes) {
    nodes.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.id.compareTo(b.id);
    });
    for (final n in nodes) {
      final ch = n.children;
      if (ch != null && ch.isNotEmpty) {
        _sortCategoryBranch(ch);
      }
    }
  }


  DateTime _profileWallFromUtc(DateTime utc) => wall_clock.toWallClockForLabel(
        utc.toUtc(),
        _settings.timezoneOffsetHours,
        _settings.preferredTimeZone,
      );

  DateTime _profileUtcFromWall(DateTime naive) =>
      wall_clock.wallClockToUtcForLabel(
        naive,
        _settings.timezoneOffsetHours,
        _settings.preferredTimeZone,
      );

  /// Day-bucket key for a stored UTC instant: profile wall date, never raw UTC Y-M-D / never [DateTime.toLocal].
  String _timelineDeviceLocalDayKeyFromUtc(DateTime utcInstant) {
    final wall = _profileWallFromUtc(utcInstant.toUtc());
    return _dateKeyFromDate(DateTime(wall.year, wall.month, wall.day));
  }

  /// **Deprecated:** Full-tree category PATCH is disabled. Use [patchCategoryDelta], [updateCategory],
  /// [addNestedCategory], [updateCategoryParent], etc. — one network call per user intent.
  Future<void> persistRules() async {
    _log(
      'CATEGORY_FULL_SYNC_DISABLED: persistRules() is a no-op — use targeted category APIs (single id per PATCH).',
    );
  }

  /// Defers ghost sweep to after the current synchronous work yields — keeps init off the critical UI slice.
  Future<void> _runOneShotUntitledGhostRecordCleanDeferred() async {
    await Future<void>.delayed(Duration.zero);
    await runOneShotUntitledGhostRecordClean();
  }

  /// One-shot: drop title-empty / "Untitled" rows from in-memory record cache so reboot + polling do not keep syncing ghosts.
  Future<void> runOneShotUntitledGhostRecordClean() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (prefs.getBool(_oneShotUntitledGhostCleanKey) ?? false) {
        return;
      }
      final before = _cachedFlatRecords.length;
      _cachedFlatRecords.removeWhere((r) {
        final t = (r['title'] ?? '').toString().trim();
        if (t.isEmpty) return true;
        return t.toLowerCase() == 'untitled';
      });
      final removed = before - _cachedFlatRecords.length;
      if (removed > 0) {
        _log(
          'CLEAN_UNTITLED_GHOST: removed $removed local record cache row(s) (one-shot)',
        );
        _notifyTimelineAfterRecordCacheMutation();
      }
      await prefs.setBool(_oneShotUntitledGhostCleanKey, true);
    } catch (_) {}
  }

  /// Replaces the in-memory category tree only. Does **not** upload the whole table to Noco.
  /// Push per-row changes with [patchCategoryDelta] / [updateCategory] / [addNestedCategory].
  Future<void> setRulesAndSave(List<CategoryRule> newRules) async {
    _rules = List.from(newRules);
    _categoryController.add(List.from(_rules));
  }

  CategoryRule? findDeepestMatchForTitle(String title) {
    CategoryRule? best;
    var bestScore = -1;
    var bestDepth = -1;
    int depthOf(CategoryRule target, List<CategoryRule> roots, int level) {
      if (level > 4) return -1;
      for (final r in roots) {
        if (r.id == target.id) return level;
        final d = depthOf(target, r.children ?? [], level + 1);
        if (d >= 0) return d;
      }
      return -1;
    }

    void considerPhase(int Function(CategoryRule m) scoreOf) {
      for (final root in _rules) {
        final m = root.findDeepestMatch(
          title,
          scoreFor: (r, t) => scoreOf(r),
        );
        if (m != null) {
          final d = depthOf(m, _rules, 0);
          final sc = scoreOf(m);
          final mLen = m.name.trim().length;
          if (best == null ||
              sc > bestScore ||
              (sc == bestScore && d > bestDepth) ||
              (sc == bestScore &&
                  d == bestDepth &&
                  mLen > best!.name.trim().length)) {
            best = m;
            bestScore = sc;
            bestDepth = d;
          }
        }
      }
    }

    considerPhase((m) => m.categoryExactMatchScoreForTitle(title));
    if (best != null) return best;

    best = null;
    bestScore = -1;
    bestDepth = -1;
    considerPhase((m) => m.categoryConsecutiveTokenMatchScoreForTitle(title));
    if (best != null) return best;

    best = null;
    bestScore = -1;
    bestDepth = -1;
    considerPhase((m) => m.categoryTokenSetOverlapScoreForTitle(title));
    if (best != null) return best;

    best = null;
    bestScore = -1;
    bestDepth = -1;
    considerPhase((m) => m.categoryFuzzyMatchScoreForTitle(title));
    return best;
  }

  CategoryRule? identifyCategory(String input) => findDeepestMatchForTitle(input);

  /// Smart link: best exact [CategoryRule.categoryExactMatchScoreForTitle], else fuzzy
  /// [CategoryRule.categoryFuzzyMatchScoreForTitle]; then longest [CategoryRule.name] tie-break;
  /// requires valid PocketBase **categories** row id.
  String? _findBestCategoryMatch(String title) {
    if (title.trim().isEmpty) return null;
    final candidates = <CategoryRule>[];
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) continue;
        candidates.add(r);
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    CategoryRule? bestRule;
    var bestScore = -1;
    for (final r in candidates) {
      final sc = r.categoryExactMatchScoreForTitle(title);
      if (sc <= 0) continue;
      final pb = _categoryBackendRowIdStrict(r);
      if (pb == null || pb.isEmpty || !_isLikelyPocketBaseRowId(pb)) {
        continue;
      }
      if (bestRule == null ||
          sc > bestScore ||
          (sc == bestScore &&
              r.name.trim().length > bestRule.name.trim().length)) {
        bestRule = r;
        bestScore = sc;
      }
    }
    if (bestRule == null) {
      bestScore = -1;
      for (final r in candidates) {
        final sc = r.categoryConsecutiveTokenMatchScoreForTitle(title);
        if (sc <= 0) continue;
        final pb = _categoryBackendRowIdStrict(r);
        if (pb == null || pb.isEmpty || !_isLikelyPocketBaseRowId(pb)) {
          continue;
        }
        if (bestRule == null ||
            sc > bestScore ||
            (sc == bestScore &&
                r.name.trim().length > bestRule.name.trim().length)) {
          bestRule = r;
          bestScore = sc;
        }
      }
    }
    if (bestRule == null) {
      bestScore = -1;
      for (final r in candidates) {
        final sc = r.categoryTokenSetOverlapScoreForTitle(title);
        if (sc <= 0) continue;
        final pb = _categoryBackendRowIdStrict(r);
        if (pb == null || pb.isEmpty || !_isLikelyPocketBaseRowId(pb)) {
          continue;
        }
        if (bestRule == null ||
            sc > bestScore ||
            (sc == bestScore &&
                r.name.trim().length > bestRule.name.trim().length)) {
          bestRule = r;
          bestScore = sc;
        }
      }
    }
    if (bestRule == null) {
      bestScore = -1;
      for (final r in candidates) {
        final sc = r.categoryFuzzyMatchScoreForTitle(title);
        if (sc <= 0) continue;
        final pb = _categoryBackendRowIdStrict(r);
        if (pb == null || pb.isEmpty || !_isLikelyPocketBaseRowId(pb)) {
          continue;
        }
        if (bestRule == null ||
            sc > bestScore ||
            (sc == bestScore &&
                r.name.trim().length > bestRule.name.trim().length)) {
          bestRule = r;
          bestScore = sc;
        }
      }
    }
    if (bestRule != null) {
      final pb = _categoryBackendRowIdStrict(bestRule);
      if (pb != null && pb.isNotEmpty) {
        return pb;
      }
    }
    return null;
  }

  /// When [cid] is null or zero, fill from [_findBestCategoryMatch] so POST/optimistic body agree.
  int? _resolveRecordCategoryIdWithSmartLink(String title, int? cid) {
    if (cid != null && cid != 0) return cid;
    final pb = _findBestCategoryMatch(title);
    if (pb == null) return cid;
    return getCategoryRuleByBackendRowId(pb)?.id ?? cid;
  }

  /// Dropped from title/category tokens when scoring overlap ([_smartInferCategoryId]).
  static const Set<String> _smartInferNoiseWords = {
    'services',
    'call',
    'task',
    'app',
    'work',
    'project',
    'add',
    'sin',
  };

  static final RegExp _smartInferNonWordOrUnderscore =
      RegExp(r'[\W_]+', unicode: true);

  static final RegExp _smartInferWhitespaceRun = RegExp(r'\s+');

  Set<String> _smartInferMeaningfulTokens(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.isEmpty) return {};
    s = s.replaceAll(_smartInferNonWordOrUnderscore, ' ');
    s = s.replaceAll(_smartInferWhitespaceRun, ' ').trim();
    if (s.isEmpty) return {};
    return {
      for (final w in s.split(' '))
        if (w.isNotEmpty && !_smartInferNoiseWords.contains(w)) w
    };
  }

  String _smartInferCollapsedLower(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(_smartInferNonWordOrUnderscore, ' ');
    return s.replaceAll(_smartInferWhitespaceRun, ' ').trim();
  }

  /// Word-overlap + substring heuristic on cached [_rules] only (no AI / network).
  ///
  /// Normalizes text, tokenizes, ignores [_smartInferNoiseWords], then:
  /// - Match if meaningful token intersection size ≥ 2, OR
  /// - collapsed category name (length ≥ 3) is a substring of collapsed title.
  /// Tie-break: larger intersection, then substring bonus, then longer category name.
  int? _smartInferCategoryId(String title) {
    final t = title.trim();
    if (t.isEmpty) return null;
    final titleTokens = _smartInferMeaningfulTokens(t);
    final normTitle = _smartInferCollapsedLower(t);
    if (normTitle.isEmpty) return null;

    CategoryRule? best;
    var bestOverlap = -1;
    var bestSubstrBonus = 0;
    var bestNameLen = -1;

    void consider(CategoryRule r) {
      if (r.isArchived) return;
      if (r.id == CategoryRule.uncategorizedSyntheticId) return;
      final pb = _categoryBackendRowIdStrict(r);
      if (pb == null || pb.isEmpty || !_isLikelyPocketBaseRowId(pb)) return;
      final name = r.name.trim();
      if (name.isEmpty) return;
      final catTokens = _smartInferMeaningfulTokens(name);
      var overlap = 0;
      for (final w in catTokens) {
        if (titleTokens.contains(w)) overlap++;
      }
      final normCat = _smartInferCollapsedLower(name);
      final substr = normCat.length >= 3 && normTitle.contains(normCat);
      final isMatch = overlap >= 2 || substr;
      if (!isMatch) return;
      final subBonus = substr ? 1 : 0;
      if (overlap > bestOverlap ||
          (overlap == bestOverlap && subBonus > bestSubstrBonus) ||
          (overlap == bestOverlap &&
              subBonus == bestSubstrBonus &&
              name.length > bestNameLen)) {
        best = r;
        bestOverlap = overlap;
        bestSubstrBonus = subBonus;
        bestNameLen = name.length;
      }
    }

    void walk(List<CategoryRule> nodes) {
      for (final r in nodes) {
        consider(r);
        if (r.children != null) walk(r.children!);
      }
    }

    walk(_rules);
    return best?.id;
  }

  /// Voice / quick map: deepest category match + path label.
  ({int id, String path})? findCategoryByFuzzyMatch(String title) {
    final r = identifyCategory(title);
    if (r == null) return null;
    return (id: r.id, path: getCategoryPath(r.id));
  }

  List<({int id, String path})> get allCategoryIdPathPairs {
    final out = <({int id, String path})>[];
    void visit(List<CategoryRule> rules, List<String> soFar) {
      for (final r in rules) {
        if (r.isArchived) continue;
        final path = [...soFar, r.name].join(' > ');
        out.add((id: r.id, path: path));
        if (r.children != null) visit(r.children!, [...soFar, r.name]);
      }
    }

    visit(_rules, []);
    return out;
  }

  bool categoryExists(int categoryId) {
    bool found = false;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == categoryId) found = true;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  String getCategoryPath(int categoryId) {
    final parts = <String>[];
    void collect(List<CategoryRule> rules, List<String> soFar) {
      for (final r in rules) {
        final next = [...soFar, r.name];
        if (r.id == categoryId) {
          parts.addAll(next);
          return;
        }
        if (r.children != null) collect(r.children!, next);
      }
    }

    collect(_rules, []);
    return parts.isEmpty ? 'Life' : parts.join(' > ');
  }

  /// Full breadcrumb paths for Smart Plan AI (cached [_rules] only — no network).
  List<String> smartPlanAllowedCategoryLabels() {
    final out = <String>[];
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        out.add(getCategoryPath(r.id));
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    out.sort();
    return out;
  }

  /// Maps a Smart Plan [category] string from the LLM to a local category id
  /// (trimmed, case-insensitive path match, then unique leaf [CategoryRule.name]).
  int? resolveCategoryIdFromSmartPlanLabel(String? rawLabel) {
    if (rawLabel == null) return null;
    final t = rawLabel.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    if (lower == 'uncategorized' || lower == 'null' || lower == 'none') {
      return null;
    }

    final normLabel = normalizeCategoryLabel(t);

    int? foundId;
    void matchPath(List<CategoryRule> rules) {
      if (foundId != null) return;
      for (final r in rules) {
        if (foundId != null) return;
        if (r.isArchived) {
          if (r.children != null) matchPath(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) matchPath(r.children!);
          continue;
        }
        final path = getCategoryPath(r.id);
        if (normalizeCategoryLabel(path) == normLabel) {
          foundId = r.id;
          return;
        }
        if (r.children != null) matchPath(r.children!);
      }
    }

    matchPath(_rules);
    if (foundId != null) return foundId;

    CategoryRule? hit;
    var ambiguous = false;
    void matchLeaf(List<CategoryRule> rules) {
      if (ambiguous) return;
      for (final r in rules) {
        if (ambiguous) return;
        if (r.isArchived) {
          if (r.children != null) matchLeaf(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) matchLeaf(r.children!);
          continue;
        }
        if (normalizeCategoryLabel(r.name) == normLabel) {
          if (hit != null && hit!.id != r.id) ambiguous = true;
          hit = r;
        }
        if (r.children != null) matchLeaf(r.children!);
      }
    }

    matchLeaf(_rules);
    if (!ambiguous && hit != null) return hit!.id;

    final atBest = <CategoryRule>[];
    var bestFuzzy = -1;
    void matchLeafFuzzy(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) matchLeafFuzzy(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) matchLeafFuzzy(r.children!);
          continue;
        }
        final sc =
            fuzzyPhraseScoreAgainstTitle(normLabel, normalizeCategoryLabel(r.name));
        if (sc <= 0) continue;
        if (sc > bestFuzzy) {
          bestFuzzy = sc;
          atBest
            ..clear()
            ..add(r);
        } else if (sc == bestFuzzy) {
          atBest.add(r);
        }
        if (r.children != null) matchLeafFuzzy(r.children!);
      }
    }

    matchLeafFuzzy(_rules);
    if (bestFuzzy > 0 && atBest.length == 1) return atBest.first.id;
    return null;
  }

  int? resolvedCategoryIdForRecord(Map<String, dynamic> rec) {
    final cid = rec['categoryId'];
    if (cid == null) return null;
    if (cid is int) return cid;
    final parsed = int.tryParse(cid.toString());
    if (parsed != null) return parsed;
    final key = rec['categoryKey']?.toString();
    if (key != null && key.trim().isNotEmpty) {
      return findCategoryIdForStoredCategoryKey(key);
    }
    return findCategoryIdForStoredCategoryKey(cid.toString());
  }

  String resolvedCategoryPathForRecord(Map<String, dynamic> rec) {
    final resolved = resolvedCategoryIdForRecord(rec);
    if (resolved != null) return getCategoryPath(resolved);
    return 'Life';
  }

  int? findCategoryIdByNormalizedTag(String tag) {
    final t = tag.toLowerCase().replaceAll(' ', '');
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        final n = (r.normalizedId ?? r.name)
            .toLowerCase()
            .replaceAll(' ', '');
        if (n == t) found = r.id;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  int? findCategoryIdByTag(String tag) {
    final t = tag.trim().toLowerCase();
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.name.trim().toLowerCase() == t) found = r.id;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  List<CategoryRule> getChildrenOf(int? parentId) {
    if (parentId == null) return List.from(_rules);
    CategoryRule? target;
    void find(List<CategoryRule> list) {
      for (final r in list) {
        if (r.id == parentId) {
          target = r;
          return;
        }
        if (r.children != null) find(r.children!);
      }
    }

    find(_rules);
    return List.from(target?.children ?? []);
  }

  int? getParentId(int categoryId) {
    int? parentId;
    void visit(List<CategoryRule> rules, int? parent) {
      for (final r in rules) {
        if (r.id == categoryId) parentId = parent;
        if (r.children != null) visit(r.children!, r.id);
      }
    }

    visit(_rules, null);
    return parentId;
  }

  CategoryRule? getCategoryRuleById(int id) {
    CategoryRule? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == id) found = r;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  /// PocketBase **categories** row id — from [CategoryRule.backendRowId] only.
  String? _categoryBackendRowIdStrict(CategoryRule? rule) {
    if (rule == null) return null;
    if (rule.id == -1) return null;
    final s = (rule.backendRowId ?? '').trim();
    if (s.isNotEmpty && s != 'uncategorized') return s;
    return null;
  }

  /// Noco `category_id` string for **`fields`** and parent FK only (@DATA_MAP §2).
  String? _categoryStringPkForApi(CategoryRule? rule) {
    if (rule == null) return null;
    final s = _sanitizePkString(rule.normalizedId);
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  /// Records/plans **`category_id`** (@DATA_MAP): always the category row’s string PK, never a local int.
  String _recordCategoryBusinessPkForApi(int? localCategoryId) {
    final rule = categoryRuleForRecordCategoryId(localCategoryId);
    final s = _categoryStringPkForApi(rule);
    if (s != null && s.isNotEmpty) return s;
    final slug = _slugifyCategoryDisplayName(rule.name);
    if (slug.isNotEmpty) return slug;
    return 'uncategorized';
  }

  /// PocketBase **`categories.parent_id`** (self relation): must be the parent row’s **system `id`**
  /// (15-char), not the business slug in [CategoryRule.normalizedId].
  String? _parentCategoryIdStringForApi(int? parentLocalId) {
    if (parentLocalId == null) return null;
    return _categoryBackendRowIdStrict(getCategoryRuleById(parentLocalId));
  }

  /// Strip system-managed / read-only keys from payloads for any table (@DATA_MAP).
  static const Set<String> _nocoPatchStripFieldKeysLower = {
    'createdat',
    'updatedat',
    'created_at',
    'updated_at',
  };

  Map<String, dynamic> _nocoFieldsForPatch(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    for (final e in raw.entries) {
      if (_nocoPatchStripFieldKeysLower.contains(e.key.toLowerCase())) {
        continue;
      }
      out[e.key] = e.value;
    }
    return out;
  }

  /// @DATA_MAP `categories`: **keywords** and **localized_names** are stored as JSON **String** (LongText).
  /// Encode Maps for PATCH/POST so the HTTP body has string values Noco accepts.
  Map<String, dynamic> _categoryPatchFieldsWithJsonLongText(
    Map<String, dynamic> fields,
  ) {
    const jsonColumnKeys = <String>{'keywords', 'localized_names'};
    final out = Map<String, dynamic>.from(fields);
    for (final k in jsonColumnKeys) {
      if (!out.containsKey(k)) continue;
      final v = out[k];
      if (v == null) {
        out.remove(k);
        continue;
      }
      if (v is String) {
        continue;
      }
      try {
        // @DATA_MAP `categories`: LongText JSON — empty Map → "{}" so clears server column.
        out[k] = jsonEncode(v);
      } catch (e) {
        _log('CATEGORY_JSON_ENCODE_FAIL key=$k error=$e');
        out.remove(k);
      }
    }
    return out;
  }

  /// @DATA_MAP `records` and `plans`: **checklist** is stored as **JSON String** (LongText/CSV) — [jsonEncode] for API.
  Map<String, dynamic> _recordsPatchFieldsJsonStrings(Map<String, dynamic> fields) {
    final out = Map<String, dynamic>.from(fields);
    if (!out.containsKey('checklist')) return out;
    final v = out['checklist'];
    if (v == null) {
      out.remove('checklist');
      return out;
    }
    if (v is String) return out;
    try {
      out['checklist'] = jsonEncode(v);
    } catch (e) {
      _log('RECORD_CHECKLIST_JSON_ENCODE_FAIL error=$e');
      out.remove('checklist');
    }
    return out;
  }

  String _slugifyCategoryDisplayName(String displayName) {
    final t = displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return t.isEmpty ? 'untitled' : t;
  }

  String _categoryNormalizedIdForPersist(CategoryRule r) {
    final s = _sanitizePkString(r.normalizedId);
    if (s != null && s.isNotEmpty) return s;
    return _slugifyCategoryDisplayName(r.name);
  }

  /// Unique string PK for new category rows ([fields.category_id]).
  String _newCategoryIdString() => _newClientRecordUuid();

  String _randomCategoryKeySuffix() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final r = Random.secure();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _randomCategoryRecoverySuffix3() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final r = Random.secure();
    return List.generate(3, (_) => chars[r.nextInt(chars.length)]).join();
  }

  bool _rulesTreeClaimsCategorySlug(String slug) {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return false;
    bool visit(List<CategoryRule> rules) {
      for (final r in rules) {
        final nid = (r.normalizedId ?? '').trim().toLowerCase();
        if (nid.isNotEmpty && nid == s) return true;
        if (r.children != null && visit(r.children!)) return true;
      }
      return false;
    }
    return visit(_rules);
  }

  /// Reserved slugs include **archived** rows ([_reservedCategorySlugsLower]) + in-memory tree (placeholders).
  bool _categoryBusinessSlugReservedOrInRules(String slug) {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return true;
    if (_reservedCategorySlugsLower.contains(s)) return true;
    if (_rulesTreeClaimsCategorySlug(s)) return true;
    return false;
  }

  String _slugWithRandomSuffixUntaken(String base) {
    final trimmed = base.trim();
    final b = trimmed.isEmpty ? 'cat' : trimmed;
    for (var i = 0; i < 24; i++) {
      final candidate = '${b}_${_randomCategoryKeySuffix()}';
      if (!_categoryBusinessSlugReservedOrInRules(candidate)) {
        return candidate;
      }
    }
    final ts = DateTime.now().millisecondsSinceEpoch % 100000;
    final tsSlug = '${b}_$ts';
    if (!_categoryBusinessSlugReservedOrInRules(tsSlug)) return tsSlug;
    return _newCategoryIdString();
  }

  /// PocketBase [category_id] / [normalized_id]: always `base_xxxx` ([_randomCategoryKeySuffix])
  /// so POST avoids unique collisions; [base] from [normalizedId] or slugified [name].
  String _pickNewCategoryBusinessKey(CategoryRule child) {
    final explicit = _sanitizePkString(child.normalizedId);
    final baseRaw = (explicit != null && explicit.isNotEmpty)
        ? explicit
        : _slugifyCategoryDisplayName(child.name);
    final base = baseRaw.isEmpty ? 'cat' : baseRaw;
    return _slugWithRandomSuffixUntaken(base);
  }

  bool _pbErrorLooksLikeUniqueCategoryCollision(ClientException e) {
    final code = e.statusCode;
    if (code != 400 && code != 409) return false;
    final blob = '${e.response} $e'.toLowerCase();
    return blob.contains('unique') ||
        blob.contains('already exists') ||
        blob.contains('duplicate') ||
        blob.contains('validation_not_unique') ||
        blob.contains('failed unique') ||
        blob.contains('autoincrement');
  }

  void _patchPlaceholderCategoryBizId(
    int? parentId,
    String displayName,
    String newCategoryId,
  ) {
    final wantTag = displayName.trim();
    void patchIn(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        if (r.id == -1 && r.name.trim() == wantTag) {
          rules[i] = r.copyWith(normalizedId: newCategoryId);
          return;
        }
        if (r.children != null) patchIn(r.children!);
      }
    }

    if (parentId == null) {
      patchIn(_rules);
    } else {
      void findParent(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == parentId) {
            if (r.children != null) patchIn(r.children!);
            return;
          }
          if (r.children != null) findParent(r.children!);
        }
      }

      findParent(_rules);
    }
  }

  void _removeFailedPlaceholderCategory(int? parentId, String tag) {
    final wantTag = tag.trim();
    bool removeFrom(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        if (r.id == -1 && r.name.trim() == wantTag) {
          rules.removeAt(i);
          return true;
        }
        if (r.children != null && removeFrom(r.children!)) {
          if (r.children!.isEmpty) r.children = null;
          return true;
        }
      }
      return false;
    }

    if (parentId == null) {
      removeFrom(_rules);
    } else {
      void findParent(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == parentId) {
            if (r.children != null) {
              removeFrom(r.children!);
            }
            return;
          }
          if (r.children != null) findParent(r.children!);
        }
      }

      findParent(_rules);
    }
    _categoryController.add(List.from(_rules));
  }

  /// Resolves Noco [categoryId] to a [CategoryRule], or a synthetic "Uncategorized" rule.
  CategoryRule categoryRuleForRecordCategoryId(int? categoryId) {
    if (categoryId != null) {
      final r = getCategoryRuleById(categoryId);
      if (r != null) return r;
    }
    return CategoryRule.uncategorized();
  }

  String categoryDisplayPathForTimeline(int? categoryId) {
    final r = categoryRuleForRecordCategoryId(categoryId);
    if (r.id == CategoryRule.uncategorizedSyntheticId) return r.name;
    return getCategoryPath(categoryId!);
  }

  Color categoryDisplayColorForTimeline(int? categoryId) {
    return categoryRuleForRecordCategoryId(categoryId).colorOrDefault;
  }

  /// Timeline card color: active [CategoryRule] if present, else expanded category (archived OK).
  Color categoryDisplayColorForRecordData(Map<String, dynamic> data) {
    final rid = resolvedCategoryIdForRecord(data);
    final rule = categoryRuleForRecordCategoryId(rid);
    if (rule.id != CategoryRule.uncategorizedSyntheticId) {
      return rule.colorOrDefault;
    }
    final exp = data['_expanded_category'];
    if (exp is Map) {
      final cv = exp['color_value'] ?? exp['colorValue'];
      if (cv != null) {
        final n = cv is int ? cv : int.tryParse(cv.toString());
        if (n != null && n != 0) return Color(n);
      }
    }
    return Colors.grey;
  }

  /// Timeline category path: active tree, else single name from expand (archived OK).
  String categoryDisplayPathForRecordData(Map<String, dynamic> data) {
    final rid = resolvedCategoryIdForRecord(data);
    final rule = categoryRuleForRecordCategoryId(rid);
    if (rule.id != CategoryRule.uncategorizedSyntheticId) {
      return categoryDisplayPathForTimeline(rule.id);
    }
    final exp = data['_expanded_category'];
    if (exp is Map) {
      final n = exp['name']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
      final biz = exp['category_id']?.toString().trim();
      if (biz != null && biz.isNotEmpty) return biz;
    }
    return 'Life';
  }

  /// Glyph for timeline / chip UI: active rule, else expanded category metadata.
  IconData categoryDisplayIconForRecordData(Map<String, dynamic> data) {
    final rid = resolvedCategoryIdForRecord(data);
    final rule = categoryRuleForRecordCategoryId(rid);
    if (rule.id != CategoryRule.uncategorizedSyntheticId) {
      return rule.iconOrDefault;
    }
    final exp = data['_expanded_category'];
    if (exp is Map) {
      final icp = exp['icon_code_point'] ?? exp['iconCodePoint'];
      if (icp != null) {
        final n = icp is int ? icp : int.tryParse(icp.toString());
        if (n != null && n != 0) {
          return IconData(n, fontFamily: 'MaterialIcons');
        }
      }
    }
    return Icons.folder_rounded;
  }

  Color getCategoryColor(int categoryId) {
    return getCategoryRuleById(categoryId)?.colorOrDefault ?? Colors.grey;
  }

  int? getCategoryIdByParentAndTag(int? parentId, String tag) {
    final children = getChildrenOf(parentId);
    final t = tag.trim().toLowerCase();
    for (final c in children) {
      if (c.isArchived) continue;
      if (c.name.trim().toLowerCase() == t) return c.id;
    }
    return null;
  }

  bool siblingHasTag(int? parentId, String tag, {int? excludeId}) {
    final children = getChildrenOf(parentId);
    final t = tag.trim().toLowerCase();
    for (final c in children) {
      if (c.isArchived) continue;
      if (excludeId != null && c.id == excludeId) continue;
      if (c.name.trim().toLowerCase() == t) return true;
    }
    return false;
  }

  Future<({bool ok, String? errorDetail})> updateCategory(
    int targetId,
    String newName,
  ) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return (ok: false, errorDetail: 'not_initialized');
    }
    if (siblingHasTag(getParentId(targetId), newName, excludeId: targetId)) {
      return (ok: false, errorDetail: null);
    }
    final existing = getCategoryRuleById(targetId);
    if (existing == null) {
      return (ok: false, errorDetail: 'category_not_found');
    }

    final pbId = _categoryBackendRowIdStrict(existing);
    if (pbId == null) {
      return (ok: false, errorDetail: 'missing_backend_row_id');
    }
    final biz = _categoryStringPkForApi(existing);
    try {
      await ensurePocketBaseReady();
      final body = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'name': newName,
          'normalized_id': _slugifyCategoryDisplayName(newName),
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
          'order': existing.order,
        }),
      );
      await _pb.collection(PbCollections.categories).update(pbId, body: body);
      await _loadRulesFromNoco();
      return (ok: true, errorDetail: null);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      return (ok: false, errorDetail: e.toString());
    } catch (e) {
      _log('UPDATE_CATEGORY: $e');
      return (ok: false, errorDetail: e.toString());
    }
  }

  Future<({bool ok, String? errorDetail})> patchCategoryDelta(
    int targetId,
    Map<String, dynamic> fields,
  ) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return (ok: false, errorDetail: 'not_initialized');
    }
    if (fields.isEmpty) {
      return (ok: true, errorDetail: null);
    }
    final existing = getCategoryRuleById(targetId);
    if (existing == null) {
      return (ok: false, errorDetail: 'category_not_found');
    }
    final pbId = _categoryBackendRowIdStrict(existing);
    if (pbId == null) {
      return (ok: false, errorDetail: 'missing_backend_row_id');
    }
    final biz = _categoryStringPkForApi(existing);
    final mergedFields = Map<String, dynamic>.from(fields);
    if (!mergedFields.containsKey('order')) {
      mergedFields['order'] = existing.order;
    }
    try {
      final prepared = _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
        'user_id': _pidForPbFilter,
        if (biz != null && biz.isNotEmpty) 'category_id': biz,
        ...mergedFields,
      });
      final merged = _nocoFieldsForPatch(prepared);
      await ensurePocketBaseReady();
      await _pb.collection(PbCollections.categories).update(pbId, body: merged);
      await _loadRulesFromNoco();
      return (ok: true, errorDetail: null);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      return (ok: false, errorDetail: e.toString());
    } catch (e) {
      _log('PATCH_CATEGORY_DELTA: $e');
      return (ok: false, errorDetail: e.toString());
    }
  }

  /// After [updateNestedCategory] (or similar) mutates memory, push this row with one PATCH.
  Future<({bool ok, String? errorDetail})> saveCategoryRowToServer(int targetId) async {
    final r = getCategoryRuleById(targetId);
    if (r == null) return (ok: false, errorDetail: 'category_not_found');
    if (siblingHasTag(getParentId(targetId), r.name, excludeId: targetId)) {
      return (ok: false, errorDetail: 'duplicate_name');
    }
    return patchCategoryDelta(targetId, <String, dynamic>{
      'name': r.name,
      'normalized_id': _categoryNormalizedIdForPersist(r),
      'color_value': r.colorValue ?? 0,
      'icon_code_point': r.iconCodePoint ?? 0,
      'order': r.order,
      if (r.keywords != null) 'keywords': r.keywords,
      if (r.localizedNames != null) 'localized_names': r.localizedNames,
    });
  }


  /// UI-first: move category in _rules, push; then PocketBase PATCH `parent_id`.
  Future<bool> updateCategoryParent(int categoryId, int? newParentId) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return false;

    final oldParentId = getParentId(categoryId);
    if (!_moveCategoryInRules(categoryId, newParentId)) return false;

    void renumberLocal(int? parentKey) {
      applyLocalCategorySiblingOrder(
        parentKey,
        List<CategoryRule>.from(getChildrenOf(parentKey)),
      );
    }

    renumberLocal(oldParentId);
    renumberLocal(newParentId);
    _categoryController.add(List.from(_rules));

    try {
      final existing = getCategoryRuleById(categoryId);
      final pbId = _categoryBackendRowIdStrict(existing);
      if (pbId == null) {
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
        return false;
      }
      final newParentKey = newParentId == null
          ? null
          : _parentCategoryIdStringForApi(newParentId);
      if (newParentId != null &&
          (newParentKey == null || newParentKey.isEmpty)) {
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
        return false;
      }
      final rowBiz = _categoryStringPkForApi(existing);
      final movedOrder = existing?.order ?? 0;
      await ensurePocketBaseReady();
      final body = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          if (rowBiz != null && rowBiz.isNotEmpty) 'category_id': rowBiz,
          'parent_id': newParentKey,
          'order': movedOrder,
        }),
      );
      await _pb.collection(PbCollections.categories).update(pbId, body: body);
      await _persistCategoryOrdersBulkForce(
        List<CategoryRule>.from(getChildrenOf(oldParentId)),
        contextLabel: 'parentMoveOldSiblings',
      );
      await _persistCategoryOrdersBulkForce(
        List<CategoryRule>.from(getChildrenOf(newParentId)),
        contextLabel: 'parentMoveNewSiblings',
      );
      await _loadRulesFromNoco();
      return true;
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      await _loadRulesFromNoco();
      _categoryController.add(List.from(_rules));
      return false;
    } catch (e) {
      _log('UPDATE_CATEGORY_PARENT: $e');
      try {
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
      } catch (_) {}
      return false;
    }
  }

  /// Returns true if moved. Removes node from current parent and adds to new parent (or root).
  bool _moveCategoryInRules(int categoryId, int? newParentId) {
    CategoryRule? node;
    CategoryRule? oldParent;
    void find(List<CategoryRule> rules, CategoryRule? parent) {
      for (final r in rules) {
        if (r.id == categoryId) {
          node = r;
          oldParent = parent;
          return;
        }
        if (r.children != null) find(r.children!, r);
      }
    }
    find(_rules, null);
    if (node == null) return false;
    final nodeVal = node!;
    final op = oldParent;
    if (op != null && op.children != null) {
      final ch = op.children!;
      ch.removeWhere((c) => c.id == categoryId);
      if (ch.isEmpty) op.children = null;
    } else if (op == null) {
      _rules.removeWhere((r) => r.id == categoryId);
    }
    if (newParentId == null) {
      _rules.add(nodeVal);
    } else {
      void addTo(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == newParentId) {
            (r.children ??= []).add(nodeVal);
            return;
          }
          if (r.children != null) addTo(r.children!);
        }
      }
      addTo(_rules);
    }
    return true;
  }

  Future<bool> deleteCategory(int id) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return false;

    final rule = getCategoryRuleById(id);
    if (rule == null || rule.id == -1) {
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    if (_categoryBackendRowIdStrict(rule) == null) {
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    final delId = await _resolveCategoryRowIdForPb(rule);
    if (delId.isEmpty || !_isLikelyPocketBaseRowId(delId)) {
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    try {
      await ensurePocketBaseReady();
      final biz = _categoryStringPkForApi(rule);
      final patchBody = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'is_archived': true,
          'order': rule.order,
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
        }),
      );
      await _pb.collection(PbCollections.categories).update(
            delId,
            body: patchBody,
          );
      _removeCategoryFromRules(id);
      _categoryController.add(List.from(_rules));
      return true;
    } on ClientException catch (e) {
      final deleteFallbackUrl = () {
        try {
          final b = (_pocketBase?.baseURL ?? '').trim();
          if (b.isEmpty) return '(unknown URL)';
          final bt = b.replaceAll(RegExp(r'/$'), '');
          return '$bt/api/collections/${PbCollections.categories}/records/$delId';
        } catch (_) {
          return '(unknown URL)';
        }
      }();
      _debugPrintPocketBaseClientException(
        operation: 'categories soft-delete PATCH',
        e: e,
        payload: <String, dynamic>{'is_archived': true},
        fallbackUrl: deleteFallbackUrl,
      );
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      _log('SOFT_DELETE_CATEGORY: $e');
      return false;
    } catch (e) {
      _log('SOFT_DELETE_CATEGORY: $e');
      return false;
    }
  }

  /// Optimistic delete only — removes the subtree with this local id from [_rules].
  void _removeCategoryFromRules(int id) {
    bool removeFrom(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        if (rules[i].id == id) {
          rules.removeAt(i);
          return true;
        }
        if (rules[i].children != null && removeFrom(rules[i].children!)) {
          if (rules[i].children?.isEmpty ?? false) rules[i].children = null;
          return true;
        }
      }
      return false;
    }
    removeFrom(_rules);
  }

  /// Same id derivation as [_buildCategoryTreeFromFlat] so the local node matches the next reload.
  int _categoryDisplayIdFromServerPk(String rawPk, {required String tagFallback}) {
    final trimmed = rawPk.trim();
    if (trimmed.isEmpty) {
      return _hashStringToPositiveIntForCategoryTreeLocalIdOnly(tagFallback.trim(), 1);
    }
    final asInt = _rowInt(trimmed);
    if (asInt != 0) return asInt;
    final h = _hashStringToPositiveIntForCategoryTreeLocalIdOnly(trimmed, 0);
    if (h != 0) return h;
    return _hashStringToPositiveIntForCategoryTreeLocalIdOnly(tagFallback.trim(), 1);
  }

  void _applyCategoryCreateResponseToPlaceholderPb({
    required int? parentId,
    required String displayName,
    required RecordModel created,
  }) {
    try {
      final rowId = created.id.trim();
      if (rowId.isEmpty) return;
      final wantTag = displayName.trim();
      final biz = created.data['category_id']?.toString();
      final newId =
          _categoryDisplayIdFromServerPk(rowId, tagFallback: wantTag);
      CategoryRule upgraded(CategoryRule old) {
        return CategoryRule(
          id: newId,
          name: old.name,
          backendRowId: rowId,
          normalizedId:
              (biz != null && biz.isNotEmpty) ? biz : old.normalizedId,
          children: old.children,
          colorValue: old.colorValue,
          iconCodePoint: old.iconCodePoint,
          keywords: old.keywords,
          localizedNames: old.localizedNames,
          order: old.order,
          isArchived: false,
        );
      }

      if (parentId == null) {
        for (var i = 0; i < _rules.length; i++) {
          final r = _rules[i];
          if (r.id == -1 && r.name.trim() == wantTag) {
            _rules[i] = upgraded(r);
            return;
          }
        }
        return;
      }

      bool walk(List<CategoryRule> rules) {
        for (var i = 0; i < rules.length; i++) {
          if (rules[i].id == parentId) {
            final ch = rules[i].children;
            if (ch == null) return false;
            for (var j = 0; j < ch.length; j++) {
              final c = ch[j];
              if (c.id == -1 && c.name.trim() == wantTag) {
                ch[j] = upgraded(c);
                return true;
              }
            }
            return false;
          }
          if (rules[i].children != null && walk(rules[i].children!)) {
            return true;
          }
        }
        return false;
      }

      walk(_rules);
    } catch (_) {}
  }

  /// UI-first: add child to _rules (temp id -1), push; then PocketBase create.
  Future<bool> addNestedCategory(int? parentId, CategoryRule child) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return false;

    final ownerPbId = _userIdForWhere;
    if (ownerPbId == null || ownerPbId.isEmpty) {
      _log('ADD_CATEGORY: missing auth record id for user_id relation');
      return false;
    }

    if (siblingHasTag(parentId, child.name)) {
      return false;
    }

    final parentKey = _parentCategoryIdStringForApi(parentId);
    if (parentId != null && (parentKey == null || parentKey.isEmpty)) {
      _log(
        'ADD_CATEGORY: parent missing PocketBase row id (backendRowId) localParent=$parentId',
      );
      return false;
    }

    var categoryId = _pickNewCategoryBusinessKey(child);

    final nextOrder = _nextCategoryOrderAmongSiblings(parentId);

    final placeholder = CategoryRule(
      id: -1,
      name: child.name,
      normalizedId: categoryId,
      children: null,
      colorValue: child.colorValue,
      iconCodePoint: child.iconCodePoint,
      keywords: child.keywords,
      localizedNames: child.localizedNames,
      order: nextOrder,
      isArchived: false,
    );
    if (parentId == null) {
      _rules.add(placeholder);
    } else {
      void addTo(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == parentId) {
            (r.children ??= []).add(placeholder);
            return;
          }
          if (r.children != null) addTo(r.children!);
        }
      }
      addTo(_rules);
    }
    _categoryController.add(List.from(_rules));

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final fieldsRaw = <String, dynamic>{
          'user_id': ownerPbId,
          'category_id': categoryId,
          'name': child.name,
          if (parentKey != null && parentKey.isNotEmpty) 'parent_id': parentKey,
          'color_value': child.colorValue ?? 0,
          'icon_code_point': child.iconCodePoint ?? 0,
          'order': nextOrder,
          if (child.keywords != null) 'keywords': child.keywords,
          if (child.localizedNames != null)
            'localized_names': child.localizedNames,
          'normalized_id': categoryId,
          'is_archived': false,
        };
        final fields = _nocoFieldsForPatch(
          _categoryPatchFieldsWithJsonLongText(fieldsRaw),
        );
        final postedPk = (fields['category_id'] ?? '').toString().trim();
        if (postedPk.isEmpty) {
          _log('ADD_CATEGORY: POST blocked — category_id missing in fields map');
          _removeFailedPlaceholderCategory(parentId, child.name);
          return false;
        }
        await ensurePocketBaseReady();
        final created =
            await _pb.collection(PbCollections.categories).create(body: fields);
        _applyCategoryCreateResponseToPlaceholderPb(
          parentId: parentId,
          displayName: child.name,
          created: created,
        );
        _categoryController.add(List.from(_rules));
        unawaited(_loadRulesFromNoco());
        return true;
      } on ClientException catch (e) {
        debugPrint('[SERVER_ERROR_BODY] ${e.response}');
        if (attempt == 0 && _pbErrorLooksLikeUniqueCategoryCollision(e)) {
          final baseForRetry = categoryId.trim().isEmpty ? 'cat' : categoryId.trim();
          var newSlug = '${baseForRetry}_${_randomCategoryRecoverySuffix3()}';
          for (var k = 0; k < 12; k++) {
            if (!_categoryBusinessSlugReservedOrInRules(newSlug)) break;
            newSlug =
                '${baseForRetry}_${_randomCategoryRecoverySuffix3()}';
          }
          debugPrint('[CATEGORY_RECOVERY] Retrying creation with unique slug: $newSlug');
          categoryId = newSlug;
          _patchPlaceholderCategoryBizId(parentId, child.name, categoryId);
          _categoryController.add(List.from(_rules));
          continue;
        }
        _log('ADD_CATEGORY: $e');
        break;
      } catch (e) {
        _log('ADD_CATEGORY: $e');
        break;
      }
    }
    _removeFailedPlaceholderCategory(parentId, child.name);
    return false;
  }

  Future<bool> removeNestedCategory(int? parentId, int childId) async {
    return deleteCategory(childId);
  }

  Set<int> getRecordIdsInSubtree(int categoryId) {
    final out = <int>{};
    void collect(List<CategoryRule> rules) {
      for (final r in rules) {
        out.add(r.id);
        if (r.children != null) collect(r.children!);
      }
    }

    CategoryRule? target;
    void find(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == categoryId) {
          target = r;
          return;
        }
        if (r.children != null) find(r.children!);
      }
    }

    find(_rules);
    final t = target;
    if (t == null) return {categoryId};
    out.clear();
    out.add(t.id);
    if (t.children != null) collect(t.children!);
    return out;
  }

  bool updateNestedCategory(
    int id, {
    String? name,
    int? colorValue,
    int? iconCodePoint,
  }) {
    CategoryRule? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == id) {
          found = r;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    final f = found;
    if (f == null) return false;
    if (name != null) {
      if (siblingHasTag(getParentId(id), name, excludeId: id)) return false;
      f.name = name;
    }
    if (colorValue != null) f.colorValue = colorValue;
    if (iconCodePoint != null) f.iconCodePoint = iconCodePoint;
    return true;
  }

  Future<void> updateCategoryKeywords(
      int categoryId, Map<String, List<String>> keywords) async {
    try {
      final rule = getCategoryRuleById(categoryId);
      if (rule == null) return;
      final pbId = _categoryBackendRowIdStrict(rule);
      if (pbId == null) {
        return;
      }
      final biz = _categoryStringPkForApi(rule);
      await ensurePocketBaseReady();
      final body = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
          'keywords': keywords,
          'order': rule.order,
        }),
      );
      await _pb.collection(PbCollections.categories).update(pbId, body: body);
      await _loadRulesFromNoco();
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
    } catch (e, st) {
      _log('UPDATE_CATEGORY_KEYWORDS: $e');
      _log('$st');
    }
  }

  void updateCategoryLocalizedNames(int id, Map<String, String> names) {
    void visit(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        if (r.id == id) {
          rules[i] = r.copyWith(localizedNames: names);
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
  }

  Future<String?> translateKeyword(String text,
      {required String fromLang, required String toLang}) async {
    return text;
  }

  int? get defaultCategoryId {
    final d = _settings.defaultCategoryId;
    if (d != null && categoryExists(d)) return d;
    if (_rules.isNotEmpty) return _rules.first.id;
    return null;
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(' ', '').trim();

  static int recordDurationSeconds(Map<String, dynamic> rec) {
    final type = rec['type'] as String? ?? 'record';
    if (type == 'planned') return 0;
    final start = startTimeFromRecord(rec);
    if (start == null) return 0;
    final endParsed = endTimeFromRecord(rec);
    if (endParsed != null) {
      return endParsed.difference(start).inSeconds;
    }
    final status = (rec['status'] as String? ?? '').toLowerCase();
    if (status == 'running') {
      return getPlanetaryNow().difference(start).inSeconds;
    }
    return 0;
  }

  static DateTime? startTimeFromRecord(Map<String, dynamic> rec) {
    final v = rec['startTime'];
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  static DateTime? endTimeFromRecord(Map<String, dynamic> rec) {
    final status = rec['status'] as String? ?? 'completed';
    if (status == 'running') return null;
    final v = rec['endTime'];
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  /// Uses profile [offsetHours] (profiles.timezone_offset) for day bounds — same as timeline day bucket.
  static int recordDurationSecondsWithinDayFromTimestamps(
    Map<String, dynamic> rec,
    DateTime selectedDay,
    int offsetHours,
    String preferredTimeZone,
  ) {
    final type = rec['type'] as String? ?? 'record';
    if (type == 'planned') return 0;
    final start = startTimeFromRecord(rec);
    if (start == null) return 0;
    final endParsed = endTimeFromRecord(rec);
    final status = (rec['status'] as String? ?? '').toLowerCase();
    final DateTime end;
    if (endParsed != null) {
      end = endParsed;
    } else if (status == 'running') {
      end = getPlanetaryNow();
    } else {
      end = start;
    }
    final (DateTime dayStart, DateTime dayEnd) =
        utcRangeForWallClockDate(selectedDay, offsetHours, preferredTimeZone);
    final effectiveStart = start.isBefore(dayStart) ? dayStart : start;
    final effectiveEnd = end.isAfter(dayEnd) ? dayEnd : end;
    if (!effectiveStart.isBefore(effectiveEnd)) return 0;
    return effectiveEnd.difference(effectiveStart).inSeconds;
  }

  /// Strong signature so stats cache cannot reuse another day’s tree when length/first/last collide.
  static int statsRecordsSignature(
      List<Map<String, dynamic>> records, DateTime selectedDay) {
    var h = Object.hash(
      2,
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      records.length,
    );
    for (final r in records) {
      h = Object.hash(
        h,
        (r['record_id'] ?? r['id'] ?? '').toString(),
        r['startTime']?.toString() ?? '',
        r['endTime']?.toString() ?? '',
        (r['title'] ?? '').toString(),
      );
    }
    return h;
  }

  List<Map<String, dynamic>> getRecordsByCategoryId(
    int categoryId,
    List<Map<String, dynamic>> allRecords,
  ) {
    final ids = getRecordIdsInSubtree(categoryId);
    return allRecords.where((rec) {
      final cid = rec['categoryId'];
      final id = cid is int ? cid : int.tryParse(cid?.toString() ?? '');
      return id != null && ids.contains(id);
    }).toList();
  }

  Duration getDurationForCategory(
      int categoryId, List<Map<String, dynamic>> records) {
    final ids = getRecordIdsInSubtree(categoryId);
    var sec = 0;
    for (final rec in records) {
      final cid = rec['categoryId'];
      final id = cid is int ? cid : int.tryParse(cid?.toString() ?? '');
      if (id != null && ids.contains(id)) sec += recordDurationSeconds(rec);
    }
    return Duration(seconds: sec);
  }

  Duration getDurationForCategoryWithinDay(
    int categoryId,
    List<Map<String, dynamic>> records,
    DateTime selectedDay,
  ) {
    final ids = getRecordIdsInSubtree(categoryId);
    var sec = 0;
    for (final rec in records) {
      final cid = rec['categoryId'];
      final id = cid is int ? cid : int.tryParse(cid?.toString() ?? '');
      if (id != null && ids.contains(id)) {
        sec += recordDurationSecondsWithinDayFromTimestamps(
          rec,
          selectedDay,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        );
      }
    }
    return Duration(seconds: sec);
  }

  List<StatsNode> getAggregatedStats(
    List<Map<String, dynamic>> records,
    DateTime selectedDay,
  ) {
    final key = statsRecordsSignature(records, selectedDay);
    if (key == _lastAggregatedKey && _lastStatsNodeRoots != null) {
      return _lastStatsNodeRoots!;
    }
    final oh = _settings.timezoneOffsetHours;
    final tzLabel = _settings.preferredTimeZone;
    final Map<String, _BuildNode> roots = {};
    for (final rec in records) {
      final pathStr = resolvedCategoryPathForRecord(rec);
      var segments =
          pathStr.split(' > ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) segments = ['Legacy Data'];
      final sec = recordDurationSecondsWithinDayFromTimestamps(
        rec,
        selectedDay,
        oh,
        tzLabel,
      );
      Map<String, _BuildNode> current = roots;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final isLeaf = i == segments.length - 1;
        final node = current.putIfAbsent(segment, () => _BuildNode(segment));
        node.totalSeconds += sec;
        if (isLeaf) {
          final title = (rec['title'] as String?)?.trim();
          final taskLabel =
              (title != null && title.isNotEmpty) ? title : 'Untitled';
          final groupKey = _normalize(taskLabel);
          node.sessionGroups.putIfAbsent(groupKey, () => []);
          node.sessionGroups[groupKey]?.add(rec);
        } else {
          current = node.children;
        }
      }
    }
    List<StatsNode> toNodeList(Map<String, _BuildNode> map) {
      final list = map.values.toList();
      list.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
      return list.map((n) {
        final sortedGroups = n.sessionGroups.entries.map((e) {
          var groupSec = 0;
          for (final r in e.value) {
            groupSec += recordDurationSecondsWithinDayFromTimestamps(
              r,
              selectedDay,
              oh,
              tzLabel,
            );
          }
          final actualTitles = e.value
              .map((r) => (r['title'] as String?)?.trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet();
          final sortedByStart = List<Map<String, dynamic>>.from(e.value);
          sortedByStart.sort((a, b) {
            final at = startTimeFromRecord(a);
            final bt = startTimeFromRecord(b);
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
          var displayLabel = (sortedByStart.isNotEmpty &&
                  sortedByStart.first['title'] != null)
              ? (sortedByStart.first['title'] as String).trim()
              : '';
          if (displayLabel.isEmpty) displayLabel = e.key;
          return SessionGroup(
            label: displayLabel,
            totalSeconds: groupSec,
            records: e.value,
            actualTitles: actualTitles,
          );
        }).toList();
        sortedGroups.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
        return StatsNode(
          label: n.label,
          totalSeconds: n.totalSeconds,
          children: n.children.isEmpty ? const [] : toNodeList(n.children),
          sessionGroups: sortedGroups,
        );
      }).toList();
    }

    final result = toNodeList(roots);
    _lastAggregatedKey = key;
    _lastStatsNodeRoots = result;
    return result;
  }

  ({String title, List<String> tags}) getCleanTitleAndTags(String input) {
    final tags = <String>[];
    final words = input.trim().split(RegExp(r'\s+'));
    final titleParts = <String>[];
    for (final w in words) {
      if (w.startsWith('#')) {
        if (w.length > 1) tags.add(w);
      } else {
        titleParts.add(w);
      }
    }
    final title = titleParts.join(' ').trim();
    return (
      title: title.isEmpty ? input.trim() : title,
      tags: tags,
    );
  }

  Future<List<Task>> loadTasksForDate(DateTime date) async {
    final prefs = _prefs;
    if (prefs == null) return [];
    try {
      final key = _tasksKeyForDate(date);
      final list = prefs.getStringList(key);
      if (list == null || list.isEmpty) return [];
      return list
          .map((s) =>
              Task.fromMap(Map<String, dynamic>.from(jsonDecode(s) as Map)))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTasks(DateTime date, List<Task> tasks) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setStringList(
          _tasksKeyForDate(date), tasks.map((t) => t.toJson()).toList());
    } catch (_) {}
  }

  Stream<bool> get connectionStream => Stream.value(true);

  /// Parse NocoDB date string as UTC so Moscow (UTC+3) is not treated as UTC.
  static DateTime? _parseDateTimeUtc(dynamic v) {
    if (v == null) return null;
    // Local DateTime from any source: convert properly — never treat wall components as UTC.
    if (v is DateTime) return v.isUtc ? v : v.toUtc();
    if (v is String) {
      var s = v.trim();
      if (s.isEmpty) return null;
      // NocoDB often returns "YYYY-MM-DD HH:MM:SS+00" or without timezone.
      // Normalize to ISO-8601 before parse.
      s = s.replaceAll(' ', 'T');
      if (RegExp(r'[+-]\d{2}$').hasMatch(s)) {
        s = '$s:00';
      }
      final hasTz = s.endsWith('Z') || s.contains('+') || (s.length > 11 && s.substring(11).contains('-'));
      final parsed = DateTime.tryParse(hasTz ? s : '${s}Z');
      return parsed?.toUtc();
    }
    return null;
  }

  static bool _isLikelyUuidOrLongPk(String s) {
    final t = s.trim();
    if (t.length >= 28) return true;
    return RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(t);
  }

  static bool _isSmallIntegerString(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^\d{1,9}$').hasMatch(t);
  }

  /// Refreshes timeline cache after PocketBase create; [pocketCreatedRecordId] is the new row id.
  Future<String?> _finalizeRecordCreateHandshake({
    required String pocketCreatedRecordId,
  }) async {
    final id = pocketCreatedRecordId.trim();
    if (id.isEmpty) return null;
    _log('WRITE_RECORD_PK_OK: server_id=$id');
    return id;
  }

  /// True when [parent_id] points to a parent row (int PK, UUID string, or Link object).
  bool _rowHasNonEmptyParent(dynamic parentField) {
    if (parentField == null) return false;
    final flat = normalizeLinkScalar(parentField);
    final s = (flat ?? parentField).toString().trim();
    if (s.isEmpty || s == '0') return false;
    return true;
  }

  /// Resolves stored category key (int, slug, UUID, display id) to app [CategoryRule.id].
  int? findCategoryIdForStoredCategoryKey(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final asInt = int.tryParse(s);
    if (asInt != null && asInt != 0) return asInt;
    final t = s.toLowerCase();
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        final tag = r.name.trim().toLowerCase();
        final noco = (r.backendRowId ?? '').trim().toLowerCase();
        if (r.id.toString() == s) {
          found = r.id;
          return;
        }
        if (noco.isNotEmpty && noco == t) {
          found = r.id;
          return;
        }
        final n = (r.normalizedId ?? '').toString().trim().toLowerCase();
        if (n.isNotEmpty && n == t) {
          found = r.id;
          return;
        }
        if (tag.isNotEmpty && tag == t) {
          found = r.id;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    if (found != null) return found;
    return findCategoryIdByNormalizedTag(s) ?? findCategoryIdByTag(s);
  }

  /// Maps stored `category_id` (number, slug, UUID, link expand) to [CategoryRule.id].
  int? categoryIdFromRecordRow(Map<String, dynamic> row) {
    try {
      dynamic v =
          row['category_id'] ?? row['Category_id'] ?? row['categoryId'];
      v = normalizeLinkScalar(v);
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) {
          final asInt = _rowInt(v);
          if (asInt != 0) return asInt;
          final fromKey = findCategoryIdForStoredCategoryKey(s);
          if (fromKey != null) return fromKey;
        }
      }
      final exp = row['_expanded_category'];
      if (exp is Map) {
        final pid =
            (exp['id'] ?? exp['Id'] ?? '').toString().trim();
        if (pid.isNotEmpty) {
          int? byBackend;
          void visit(List<CategoryRule> rules) {
            for (final rule in rules) {
              final b = (rule.backendRowId ?? '').trim();
              if (b.isNotEmpty && b == pid) {
                byBackend = rule.id;
                return;
              }
              if (rule.children != null) visit(rule.children!);
            }
          }

          visit(_rules);
          if (byBackend != null) return byBackend;
          return CategoryRule.uncategorizedSyntheticId;
        }
      }
      final linkFlat =
          normalizeLinkScalar(row['category_link'] ?? row['categoryLink']);
      if (linkFlat != null && linkFlat.toString().trim().isNotEmpty) {
        return CategoryRule.uncategorizedSyntheticId;
      }
      if (v != null && v.toString().trim().isNotEmpty) {
        return CategoryRule.uncategorizedSyntheticId;
      }
      return null;
    } catch (_) {
      return CategoryRule.uncategorizedSyntheticId;
    }
  }

  Map<String, dynamic> _rowToRecordMap(Map<String, dynamic> row) {
    final start = _parseDateTimeUtc(row['start_time']);
    final end = _parseDateTimeUtc(row['end_time']);
    final pidRaw = row['parent_id'];
    final pidFlat = normalizeLinkScalar(pidRaw) ?? pidRaw;
    final pidStr = pidFlat?.toString().trim() ?? '';
    int? parentInt;
    if (pidStr.isNotEmpty && pidStr != '0') {
      parentInt = int.tryParse(pidStr);
      if (parentInt == null || parentInt == 0) {
        final ri = _rowInt(pidRaw);
        parentInt = ri == 0 ? null : ri;
      }
    }
    final categoryRaw =
        normalizeLinkScalar(row['category_id'] ?? row['Category_id'] ?? row['categoryId']);
    final catInt = categoryIdFromRecordRow(row);
    final statusFromRow = row['status']?.toString();
    // Basta: any row with end_time is closed — never surface as running in app maps.
    final String status;
    if (end != null) {
      status = 'completed';
    } else if (statusFromRow != null && statusFromRow.isNotEmpty) {
      status = statusFromRow;
    } else {
      status = 'running';
    }
    final restPk = recordsTablePk(row);
    final bizRid = (row['record_id'] ?? '').toString().trim();
    final sysObj = row[_nocoSystemRowIdKey];
    final int? sysInt =
        sysObj is int ? sysObj : int.tryParse(restPk.isNotEmpty ? restPk : '');
    // Calendar day for timeline bucket: profile wall Y-M-D ([DATA_MAP] records §8; [wall_clock]).
    String calendarDayStr;
    if (start != null) {
      calendarDayStr = _timelineDeviceLocalDayKeyFromUtc(start);
    } else {
      final stFallback = _parseDateTimeUtc(row['start_time']);
      calendarDayStr = stFallback != null
          ? _timelineDeviceLocalDayKeyFromUtc(stFallback)
          : '';
    }
    final ownerUid = normalizeLinkScalar(row['user_id'])?.toString().trim();
    final srcPlanRaw = normalizeLinkScalar(row['source_plan_id'])?.toString() ??
        row['source_plan_id']?.toString().trim();
    final srcPlan =
        srcPlanRaw != null && srcPlanRaw.isNotEmpty ? srcPlanRaw : null;
    return <String, dynamic>{
      'id': restPk,
      'backendRestPathId': restPk,
      'backendNumericId': sysInt,
      'record_id': bizRid,
      // Legacy: numeric Noco system id only; business UUID is [record_id].
      'docId': int.tryParse(restPk) ?? 0,
      'title': row['title'] as String? ?? '',
      'type': row['type'] as String? ?? 'record',
      'status': status,
      'startTime': start,
      'endTime': end,
      'categoryId': catInt,
      if (categoryRaw != null) 'categoryKey': categoryRaw.toString(),
      'parentId': parentInt,
      if (ownerUid != null && ownerUid.isNotEmpty) 'user_id': ownerUid,
      if (srcPlan != null && srcPlan.isNotEmpty) 'source_plan_id': srcPlan,
      'calendarDayStr': calendarDayStr,
      'tags': row['tags'] is List ? row['tags'] : null,
      'note': mergeRecordNoteFields(row['note'], row['notes']),
      'checklist': _parseRecordChecklistField(row['checklist']),
      if (row['_expanded_category'] != null)
        '_expanded_category': row['_expanded_category'],
    };
  }

  List<Map<String, dynamic>>? _parseRecordChecklistField(dynamic raw) =>
      parseChecklistFromNoco(raw);

  Set<String> _collectRecordKeysFromCache(String recordId) {
    final id = recordId.trim();
    final out = <String>{};
    if (id.isNotEmpty) out.add(id);
    for (final row in _cachedFlatRecords) {
      final pk = recordsTablePk(row);
      final biz = (row['record_id'] ?? '').toString().trim();
      if (pk == id || biz == id) {
        if (pk.isNotEmpty) out.add(pk);
        if (biz.isNotEmpty) out.add(biz);
        break;
      }
    }
    return out;
  }

  void _pruneRecord404DeadletterUsingCache() {
    if (_recordRestDefinitive404Keys.isEmpty) return;
    final alive = <String>{};
    for (final r in _cachedFlatRecords) {
      final pk = recordsTablePk(r).trim();
      final biz = (r['record_id'] ?? '').toString().trim();
      if (pk.isNotEmpty) alive.add(pk);
      if (biz.isNotEmpty) alive.add(biz);
    }
    final before = _recordRestDefinitive404Keys.length;
    _recordRestDefinitive404Keys.removeWhere((k) => alive.contains(k));
    if (before != _recordRestDefinitive404Keys.length) {
      _log(
        'RECORDS_404_DEADLETTER: dropped key(s) that match live server rows again (before=$before after=${_recordRestDefinitive404Keys.length})',
      );
    }
  }

  bool _optimisticRowDeletedRaw(Map<String, dynamic> row) {
    final pk = recordsTablePk(row);
    final biz = (row['record_id'] ?? '').toString().trim();
    for (final k in [pk, biz]) {
      if (k.isNotEmpty && _optimisticDeletedKeys.contains(k)) return true;
    }
    return false;
  }

  /// Merge [end_time] for rows the user just stopped (PATCH in flight).
  Map<String, dynamic> _mergeOptimisticIntoRecordMap(Map<String, dynamic> data) {
    final rid = (data['record_id'] ?? '').toString().trim();
    final nid = (data['id'] ??
            data['backendRestPathId'] ??
            data['nocoRestPathId'] ??
            '')
        .toString()
        .trim();
    _OptimisticEndPatch? p;
    for (final k in [rid, nid]) {
      if (k.isNotEmpty && _optimisticEndByKey.containsKey(k)) {
        p = _optimisticEndByKey[k];
        break;
      }
    }
    if (p == null) return data;
    final m = Map<String, dynamic>.from(data);
    m['endTime'] = p.endUtc;
    m['status'] = 'completed';
    return m;
  }

  void _applyOptimisticStopUiSnapshot(String recordId) {
    try {
      final keys = _collectRecordKeysFromCache(recordId);
      final now = getPlanetaryNow();
      for (final k in keys) {
        if (k.isNotEmpty) _optimisticEndByKey[k] = _OptimisticEndPatch(now);
      }
      _notifyTimelineAfterRecordCacheMutation();
    } catch (e, st) {
      _log('applyOptimisticStopUiSnapshot failed: $e');
      _log(st.toString());
    }
  }

  void _clearOptimisticStopKeysForRecord(String recordId) {
    try {
      final keys = _collectRecordKeysFromCache(recordId);
      for (final k in keys) {
        _optimisticEndByKey.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
    } catch (e, st) {
      _log('clearOptimisticStopKeysForRecord failed: $e');
      _log(st.toString());
    }
  }

  /// Clears optimistic overlay for timeline + active row (call after failed write or server sync).
  void clearOptimisticTimelineUi({bool notifyTimeline = true}) {
    try {
      _optimisticEndByKey.clear();
      _optimisticDeletedKeys.clear();
      _optimisticPendingStartRecordMap = null;
      if (notifyTimeline) {
        _notifyTimelineAfterRecordCacheMutation();
      }
    } catch (e, st) {
      _log('clearOptimisticTimelineUi failed: $e');
      _log(st.toString());
    }
  }

  Map<String, dynamic> _buildOptimisticPendingStartRecordMap({
    required String clientRecordId,
    required String title,
    required DateTime startUtc,
    int? categoryId,
  }) {
    final calendarDayStr = _timelineDeviceLocalDayKeyFromUtc(startUtc);
    final rid = clientRecordId.trim();
    return <String, dynamic>{
      'id': rid,
      'backendRestPathId': rid,
      'record_id': rid,
      'backendNumericId': null,
      'docId': 0,
      'title': title,
      'type': 'record',
      'status': 'running',
      'startTime': startUtc,
      'endTime': null,
      'categoryId': categoryId,
      'calendarDayStr': calendarDayStr,
      'parentId': null,
      '_optimisticPending': true,
    };
  }

  /// Stops all running primaries in the cache **visually** (Sacred Law) + inserts a pending running row.
  void applyOptimisticSacredHandoffForNewStart({
    required String clientRecordId,
    required String title,
    required DateTime startUtc,
    int? categoryId,
  }) {
    try {
      final now = getPlanetaryNow();
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        if (!_isNocoRowSacredStopTarget(row)) continue;
        final pk = recordsTablePk(row);
        final biz = (row['record_id'] ?? '').toString().trim();
        for (final k in [pk, biz]) {
          if (k.isNotEmpty) _optimisticEndByKey[k] = _OptimisticEndPatch(now);
        }
      }
      _optimisticPendingStartRecordMap = _buildOptimisticPendingStartRecordMap(
        clientRecordId: clientRecordId,
        title: title,
        startUtc: startUtc,
        categoryId: categoryId,
      );
      _notifyTimelineAfterRecordCacheMutation();
    } catch (e, st) {
      _log('applyOptimisticSacredHandoffForNewStart failed: $e');
      _log(st.toString());
    }
  }

  List<Map<String, dynamic>> _filterCachedRecordsForDate(DateTime date) {
    try {
      // Selected calendar day + record day: profile wall-clock Y-M-D (derived from getTimelineDeviceLocalToday); callers must pass a profile wall-clock date.
      final targetDayStr =
          '${date.year}-${_two(date.month)}-${_two(date.day)}';
      final ownerIds = _recordRowOwnerIdMatchSet();
      final filtered = <Map<String, dynamic>>[];
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) {
          continue;
        }
        if (_optimisticRowDeletedRaw(row)) {
          continue;
        }
        final rowUid =
            (row['user_id'] ?? '').toString().trim().toLowerCase();
        if (ownerIds.isEmpty) {
          continue;
        }
        if (rowUid.isEmpty || !ownerIds.contains(rowUid)) {
          continue;
        }

        final stUtc = _parseDateTimeUtc(row['start_time']);
        if (stUtc == null) {
          continue;
        }
        final recordDayStr = _timelineDeviceLocalDayKeyFromUtc(stUtc);
        if (recordDayStr != targetDayStr) {
          continue;
        }

        try {
          filtered.add(
              _mergeOptimisticIntoRecordMap(_rowToRecordMap(row)));
        } catch (e, st) {
          final rowData =
              '${recordsTablePk(row)} ${(row['record_id'] ?? '').toString().trim()} data=$row';
          _log('TIMELINE_ROW_MAP: $e | $rowData');
          _log(st.toString());
        }
      }
      final pend = _optimisticPendingStartRecordMap;
      if (pend != null) {
        final pRid = (pend['record_id'] ?? '').toString().trim();
        final cacheAlreadyHasPendId = pRid.isNotEmpty &&
            filtered.any(
              (e) => (e['record_id'] ?? '').toString().trim() == pRid,
            );
        if (!cacheAlreadyHasPendId) {
          final pDay = (pend['calendarDayStr'] ?? '').toString().trim();
          if (pDay == targetDayStr) {
            filtered.add(Map<String, dynamic>.from(pend));
          }
        }
      }
      filtered.sort((a, b) {
        final as = a['startTime'] as DateTime?;
        final bs = b['startTime'] as DateTime?;
        if (as == null && bs == null) return 0;
        if (as == null) return 1;
        if (bs == null) return -1;
        // Newest first within the day (latest start_time at top).
        return bs.compareTo(as);
      });
      // Dedupe by record_id (UUID); first row wins (server snapshot before optimistic overlay).
      final seenBiz = <String>{};
      final collapsed = <Map<String, dynamic>>[];
      for (final e in filtered) {
        final biz = (e['record_id'] ?? '').toString().trim();
        if (biz.isNotEmpty) {
          if (seenBiz.contains(biz)) continue;
          seenBiz.add(biz);
        }
        collapsed.add(e);
      }
      return collapsed;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _recordsForDate(DateTime date) async {
    if (_cachedFlatRecords.isEmpty &&
        _isInitialized &&
        (currentProfileId?.isNotEmpty ?? false)) {
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
      } catch (_) {}
    }
    return _filterCachedRecordsForDate(date);
  }

  List<Map<String, dynamic>> _withDisplayTimes(
      List<Map<String, dynamic>> filtered) {
    final list =
        filtered.map((e) => Map<String, dynamic>.from(e)).toList();
    for (final data in list) {
      final st = data['startTime'] as DateTime?;
      final en = data['endTime'] as DateTime?;
      if (st != null) {
        data['startTimeDisplay'] = _profileWallFromUtc(st);
      }
      if (en != null) {
        data['endTimeDisplay'] = _profileWallFromUtc(en);
      }
    }
    return list;
  }

  /// Fingerprint for [recordsStream] — skips a [timeUpdates] tick when the day’s rows are visually unchanged.
  String _timelineRecordsStreamDistinctSignature(
      List<Map<String, dynamic>> rows) {
    final b = StringBuffer();
    for (final r in rows) {
      b.write((r['record_id'] ?? '').toString().trim());
      b.write('|');
      b.write((r['status'] ?? '').toString().trim().toLowerCase());
      b.write('|');
      b.write((r['title'] ?? '').toString());
      b.write('|');
      final st = r['startTime'] as DateTime?;
      final en = r['endTime'] as DateTime?;
      if (st != null) {
        final u = st.toUtc();
        b.write(
          '${u.year}-${u.month}-${u.day}T${u.hour}:${u.minute}:${u.second}',
        );
      }
      b.write('|');
      if (en != null) {
        final u = en.toUtc();
        b.write(
          '${u.year}-${u.month}-${u.day}T${u.hour}:${u.minute}:${u.second}',
        );
      }
      b.write(';');
    }
    return b.toString();
  }

  /// Per-call **async\*** stream: one subscription per [TimelinePage] (recreated on date change only).
  /// Mutations update [_cachedFlatRecords] then [_timeUpdateController]; this stream **awaits** that
  /// broadcast and yields [nextPayload] — no intentional empty “reset” event before the new list.
  /// Do not tie this to [fetchRecords] re-entry in a way that completes the stream between ticks.
  Stream<List<Map<String, dynamic>>> recordsStream(DateTime date) async* {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      yield [];
      return;
    }
    try {
      if (_cachedFlatRecords.isEmpty) {
        await _fetchRecordsIntoCache(forceNetwork: true);
      }
    } catch (_) {}

    List<Map<String, dynamic>> nextPayload() {
      try {
        final filtered = _filterCachedRecordsForDate(date);
        return _withDisplayTimes(filtered);
      } catch (e, st) {
        _log('recordsStream nextPayload: $e');
        if (kDebugMode) {
          debugPrint(st.toString());
        }
        return <Map<String, dynamic>>[];
      }
    }

    String? lastStreamSig;
    try {
      final first = nextPayload();
      lastStreamSig = _timelineRecordsStreamDistinctSignature(first);
      yield first;
    } catch (_) {
      yield <Map<String, dynamic>>[];
    }
    await for (final _ in timeUpdates) {
      try {
        final next = nextPayload();
        final sig = _timelineRecordsStreamDistinctSignature(next);
        if (lastStreamSig == sig) {
          continue;
        }
        lastStreamSig = sig;
        yield next;
      } catch (_) {
        yield <Map<String, dynamic>>[];
      }
    }
  }

  Future<List<Map<String, dynamic>>> getRecordsForDate(DateTime date) =>
      _recordsForDate(date);

  Future<bool> checkOverlapWithExistingRecords(
    DateTime start,
    DateTime end, {
    String? excludeRecordId,
    bool bypassConflictCheck = false,
  }) async {
    if (bypassConflictCheck) return false;
    final c = await findFirstOverlappingRecord(start, end,
        excludeRecordId: excludeRecordId);
    return c != null;
  }

  /// Keys that identify the same record row as [excludeRecordId] (UUID, REST id, system id).
  Set<String> _excludeOverlapIdentityKeys(String excludeRecordId) {
    final q = excludeRecordId.trim();
    final out = <String>{};
    if (q.isEmpty) return out;
    out.add(q);
    try {
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        final data = _rowToRecordMap(row);
        final biz = (data['record_id'] ?? '').toString().trim();
        final pk = (data['id'] ?? '').toString().trim();
        final path = (data['backendRestPathId'] ?? data['nocoRestPathId'] ?? '')
            .toString()
            .trim();
        final sys = (data['backendNumericId'] ?? data['nocoSystemId'])
                ?.toString()
                .trim() ??
            '';
        final matches = q == biz ||
            q == pk ||
            (path.isNotEmpty && q == path) ||
            (sys.isNotEmpty && q == sys);
        if (matches) {
          if (biz.isNotEmpty) out.add(biz);
          if (pk.isNotEmpty) out.add(pk);
          if (path.isNotEmpty) out.add(path);
          if (sys.isNotEmpty) out.add(sys);
        }
      }
    } catch (_) {}
    return out.where((s) => s.isNotEmpty).toSet();
  }

  bool _recordMapOverlapsExcludeKeys(
    Map<String, dynamic> data,
    Set<String> excludeKeys,
  ) {
    if (excludeKeys.isEmpty) return false;
    final candidates = <String>{
      (data['record_id'] ?? '').toString().trim(),
      (data['id'] ?? '').toString().trim(),
      (data['backendRestPathId'] ?? data['nocoRestPathId'] ?? '')
          .toString()
          .trim(),
      if (data['backendNumericId'] != null)
        data['backendNumericId'].toString().trim(),
      if (data['nocoSystemId'] != null)
        data['nocoSystemId'].toString().trim(),
      if (data['docId'] != null && data['docId'] != 0)
        data['docId'].toString().trim(),
    }.where((s) => s.isNotEmpty).toSet();
    for (final c in candidates) {
      if (excludeKeys.contains(c)) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> findFirstOverlappingRecord(
    DateTime start,
    DateTime end, {
    String? excludeRecordId,
  }) async {
    try {
      final rows = await getRecords();
      final now = getPlanetaryNow();
      final excludeKeys = excludeRecordId == null || excludeRecordId.trim().isEmpty
          ? <String>{}
          : _excludeOverlapIdentityKeys(excludeRecordId);
      for (final row in rows) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        final data = _rowToRecordMap(row);
        if (_recordMapOverlapsExcludeKeys(data, excludeKeys)) continue;
        final otherStart = startTimeFromRecord(data);
        if (otherStart == null) continue;
        final otherEnd = endTimeFromRecord(data) ?? now;
        if (_rangesOverlap(start, end, otherStart, otherEnd)) return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _rangesOverlap(
      DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
    final a = _truncateToMinuteUtc(a1);
    final b = _truncateToMinuteUtc(a2);
    final c = _truncateToMinuteUtc(b1);
    final d = _truncateToMinuteUtc(b2);
    return a.isBefore(d) && c.isBefore(b);
  }

  static DateTime _truncateToMinuteUtc(DateTime d) {
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute);
  }

  Stream<Map<String, dynamic>?> get activeRecordStream async* {
    while (true) {
      try {
        final pend = _optimisticPendingStartRecordMap;
        if (pend != null &&
            pend['endTime'] == null &&
            isRecordMapActuallyRunning(pend)) {
          final data = Map<String, dynamic>.from(pend);
          final st = data['startTime'] as DateTime?;
          final en = data['endTime'] as DateTime?;
          if (st != null) {
            data['startTimeDisplay'] = _profileWallFromUtc(st);
          }
          if (en != null) {
            data['endTimeDisplay'] = _profileWallFromUtc(en);
          }
          yield data;
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        if (_cachedFlatRecords.isEmpty &&
            _isInitialized &&
            (currentProfileId?.isNotEmpty ?? false)) {
          try {
            await _fetchRecordsIntoCache(forceNetwork: true);
          } catch (_) {}
        }
        final rows = List<Map<String, dynamic>>.from(_cachedFlatRecords);
        Map<String, dynamic>? row;
        for (final r in rows) {
          if (_rowHasNonEmptyParent(r['parent_id'])) continue;
          if (!_isNocoRowActiveRunning(r)) continue;
          row = r;
          break;
        }
        if (row == null) {
          yield null;
        } else {
          final data = _mergeOptimisticIntoRecordMap(_rowToRecordMap(row));
          if (data['endTime'] != null || !isRecordMapActuallyRunning(data)) {
            yield null;
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          final st = data['startTime'] as DateTime?;
          final en = data['endTime'] as DateTime?;
          if (st != null) {
            data['startTimeDisplay'] = _profileWallFromUtc(st);
          }
          if (en != null) {
            data['endTimeDisplay'] = _profileWallFromUtc(en);
          }
          yield data;
        }
      } catch (_) {
        yield null;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  bool _parentFieldEqualsRecordId(
      Map<String, dynamic> childRow, String parentRecordId) {
    if (parentRecordId.isEmpty) return false;
    final raw = childRow['parent_id'];
    final u = normalizeLinkScalar(raw)?.toString().trim() ??
        raw?.toString().trim() ??
        '';
    if (u == parentRecordId) return true;
    final pInt = int.tryParse(parentRecordId);
    if (pInt != null && _rowInt(raw) == pInt) return true;
    return false;
  }

  /// Value to store in `parent_id` for child rows — prefers Noco `record_id` (UUID) when present.
  String resolveParentLinkForChildren(String recordIdOrPk) {
    final q = recordIdOrPk.trim();
    if (q.isEmpty) return q;
    try {
      for (final row in _cachedFlatRecords) {
        final pk = recordsTablePk(row);
        final biz = (row['record_id'] ?? '').toString().trim();
        if (pk == q || biz == q) {
          if (biz.isNotEmpty) return biz;
          if (pk.isNotEmpty) return pk;
          break;
        }
      }
    } catch (_) {}
    return q;
  }

  /// Subtasks still running; [parentRecordId] is Noco row PK string (UUID or int string).
  Stream<List<TimelineRecord>> runningChildrenStream(String parentRecordId) {
    return _streamFromPolling(() async {
      try {
        final pid = parentRecordId.trim();
        if (pid.isEmpty) return <TimelineRecord>[];
        final rows = await getRecords();
        final list = rows
            .where((r) => _parentFieldEqualsRecordId(r, pid))
            .where(_isNocoRowActiveRunning)
            .toList();
        list.sort((a, b) {
          final at = a['start_time']?.toString() ?? '';
          final bt = b['start_time']?.toString() ?? '';
          return bt.compareTo(at);
        });
        final out = <TimelineRecord>[];
        for (final row in list) {
          try {
            out.add(TimelineRecord.fromMap(
              _rowToRecordMap(row),
              systemId: recordsTablePk(row),
              timezoneOffsetHours: _settings.timezoneOffsetHours,
            ));
          } catch (e, st) {
            final rid = recordsTablePk(row);
            debugPrint('[CHILD_RECORD_PARSE] $e row=$rid data=${row.keys}');
            debugPrint(st.toString());
            _log('CHILD_RECORD_PARSE: $e | $rid');
          }
        }
        return out;
      } catch (_) {
        return <TimelineRecord>[];
      }
    });
  }

  Stream<List<TimelineRecord>> completedChildrenStream(String parentRecordId) {
    return _streamFromPolling(() async {
      try {
        final pid = parentRecordId.trim();
        if (pid.isEmpty) return <TimelineRecord>[];
        final rows = await getRecords();
        final list = rows
            .where((r) => _parentFieldEqualsRecordId(r, pid))
            .where((r) =>
                r['end_time'] != null && r['end_time'].toString().isNotEmpty)
            .toList();
        list.sort((a, b) {
          final at = a['start_time']?.toString() ?? '';
          final bt = b['start_time']?.toString() ?? '';
          return bt.compareTo(at);
        });
        final out = <TimelineRecord>[];
        for (final row in list.take(50)) {
          try {
            out.add(TimelineRecord.fromMap(
              _rowToRecordMap(row),
              systemId: recordsTablePk(row),
              timezoneOffsetHours: _settings.timezoneOffsetHours,
            ));
          } catch (e, st) {
            final rid = recordsTablePk(row);
            debugPrint('[CHILD_RECORD_PARSE] $e row=$rid');
            debugPrint(st.toString());
            _log('CHILD_RECORD_PARSE: $e | $rid');
          }
        }
        return out;
      } catch (_) {
        return <TimelineRecord>[];
      }
    });
  }

  /// Throttled polling (default **60s**) — uses [getRecords] cache path when [DatabaseService] fetch throttle applies.
  static Stream<T> _streamFromPolling<T>(
    Future<T> Function() fetch, {
    Duration period = const Duration(seconds: 60),
  }) async* {
    yield await fetch();
    await for (final _ in Stream.periodic(period)) {
      yield await fetch();
    }
  }

  Future<void> forceRefreshFromServer() async {
    try {
      await _loadRulesFromNoco();
      await _loadSettingsFromNoco();
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
      } catch (_) {}
      _settingsController.add(_settings);
      _notifyTimelineAfterRecordCacheMutation();
    } catch (_) {}
  }

  Future<void> stopAnyRunningRecordsForDate(String dateKey) async {
    await stopAllRunningRecords();
  }

  Future<String?> startTimerWithCategory(String title,
      {int? categoryId, String? dateKey, String? sourcePlanPocketRecordId}) async {
    final now = getPlanetaryNow();
    final trimmed = dateKey?.trim() ?? '';
    final key = trimmed.length >= 10
        ? trimmed.substring(0, 10)
        : getTimelineDeviceLocalTodayDateKey();
    return writeRecord(key, title,
        categoryId: categoryId,
        explicitStartTime: now,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId);
  }

  /// One-tap start from a backlog row ([PlanningTask.startTime] may be null). Uses “now” on the server record.
  Future<String?> startRecordFromPlanTask(PlanningTask plan) {
    return startTimerWithCategory(
      plan.title,
      categoryId: plan.categoryId,
      dateKey: plan.dateKey,
      sourcePlanPocketRecordId: pocketRelationIdOrNull(plan.pocketRecordId),
    );
  }

  Future<String?> startTimer(String title) async {
    return startTimerWithCategory(title);
  }

  Future<bool> stopAllRunningRecords() async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    try {
      final nowIso = getPlanetaryNow().toUtc().toIso8601String();
      final byPk = <String, Map<String, dynamic>>{};
      var serverOk = false;

      try {
        final serverRows = await _fetchRunningRecordsFromNoco();
        serverOk = true;
        for (final r in serverRows) {
          if (_rowHasNonEmptyParent(r['parent_id'])) continue;
          if (!_isNocoRowSacredStopTarget(r)) continue;
          if (!_rowStartWallDayIsProjectedToday(r)) continue;
          final id = recordsTablePk(r);
          if (id.isEmpty) continue;
          byPk[id] = r;
        }
        final todayOnly = byPk.length;
        _mergeSacredStaleOpenCandidates(serverRows, byPk);
        if (serverRows.isNotEmpty) {
          _log(
            'SACRED_LAW: server running=${serverRows.length} -> today=$todayOnly total_stop_candidates=${byPk.length}',
          );
        }
      } catch (e) {
        _log('SACRED_LAW: server running-query failed ($e); using cache merge');
      }

      if (!serverOk) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
          final local = _cachedFlatRecords;
          for (final r in local) {
            if (_rowHasNonEmptyParent(r['parent_id'])) continue;
            if (!_isNocoRowSacredStopTarget(r)) continue;
            if (!_rowStartWallDayIsProjectedToday(r)) continue;
            final id = recordsTablePk(r);
            if (id.isEmpty) continue;
            byPk[id] = r;
          }
          _mergeSacredStaleOpenCandidates(local, byPk);
        } catch (e) {
          _log('SACRED_LAW: cache merge failed ($e)');
        }
      }

      _log('SACRED_LAW: PocketBase per-row stop ${byPk.length} record(s)');
      for (final id in byPk.keys) {
        final row = byPk[id];
        if (row == null) continue;
        _log('PATCH_ID_TRACE: stopAllRunningRecords pb id=$id');
        final fields = _nocoFieldsForPatch(<String, dynamic>{
          'end_time': nowIso,
          'status': 'stopped',
        });
        final biz = (row['record_id'] ?? '').toString().trim();
        final originalOid = biz.isNotEmpty ? biz : id;
        final code = await _patchRecordsRowWith404Recovery(
          originalQueryId: originalOid,
          restId: id,
          fields: fields,
        );
        if (code == 404) {
          _purgeGhostRecordById(id);
          continue;
        }
        if (code < 200 || code >= 300) {
          _log('STOP_SWITCH_ABORT: failed to stop record id=$id status=$code');
          return false;
        }
      }
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (_) {
      return false;
    }
  }

  String get _todayKey => getTimelineDeviceLocalTodayDateKey();

  Future<bool> writeCompletedRecord(
    String title,
    DateTime startTime,
    DateTime endTime, {
    int? categoryId,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (_writeRecordMutationInFlight) return false;
    _writeRecordMutationInFlight = true;
    try {
      final parsed = getCleanTitleAndTags(title);
      var cid = categoryId ?? defaultCategoryId;
      cid = identifyCategory(parsed.title)?.id ?? cid;
      cid = _resolveRecordCategoryIdWithSmartLink(parsed.title, cid);
      cid = _resolveColdStartRecordCategoryId(cid);
      if (!_categoryIdResolvableForPbRecordPost(cid)) {
        _log('writeCompletedRecord: no resolvable category_id');
        AppSnack.failed();
        return false;
      }
      final newId = await _createRecordPb(<String, dynamic>{
        'user_id': _pidForPbFilter,
        'record_id': _newClientRecordUuid(),
        'status': 'completed',
        'title': parsed.title,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'category_id': _recordCategoryBusinessPkForApi(cid),
        'type': 'record',
        'parent_id': null,
        'checklist': <Map<String, dynamic>>[],
        if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
      });
      if (newId == null) {
        _log('writeCompletedRecord PocketBase create failed');
        return false;
      }
      await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (e, st) {
      _log('writeCompletedRecord failed: $e');
      _log(st);
      return false;
    } finally {
      _writeRecordMutationInFlight = false;
    }
  }

  /// Highlander server phase (PATCH old + POST new). Runs **after** local shadow; may log [DISPATCH].
  Future<void> _highlanderPrimaryServerSync({
    required _HighlanderRollbackToken? rollbackToken,
    required Map<String, dynamic> runningFields,
  }) async {
    try {
      final sp = runningFields['source_plan_id'];
      if (sp != null) {
        final planId =
            pocketRelationIdOrNull(sp.toString()) ?? sp.toString().trim();
        if (planId.isNotEmpty) {
          final pc = await _resolveCategoryIdFromSourcePlanPbId(planId);
          if (_planLocalCategoryIdIsConcrete(pc)) {
            final resolved = _resolveColdStartRecordCategoryId(pc);
            if (_categoryIdResolvableForPbRecordPost(resolved)) {
              runningFields['category_id'] =
                  _recordCategoryBusinessPkForApi(resolved);
            }
          }
        }
      }
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        await _runBatchedRecordCacheTimelineNotify(() async {
          _restoreHighlanderRollbackToken(rollbackToken);
          clearOptimisticTimelineUi();
          _printAtomicCheckRunningCount();
        });
        AppSnack.failed();
        return;
      }

      _recordCacheTimelineNotifyBatchDepth++;
      try {
        final handoffIso = (runningFields['start_time'] ?? '')
            .toString()
            .trim();
        if (handoffIso.isEmpty) {
          throw StateError('HIGHLANDER_MISSING_START_TIME');
        }
        final serverPrimaries = await _fetchServerRunningSacredPrimariesByPbId();
        if (serverPrimaries.isEmpty) {
          _log('SACRED_PREFLIGHT: no running primaries on server (POST new only)');
        } else {
          _log(
            'SACRED_PREFLIGHT: server running primaries=${serverPrimaries.length} (PATCH to handoff start)',
          );
        }
        for (final e in serverPrimaries.entries) {
          final rid = e.key;
          final row = e.value;
          final oq = (row['record_id'] ?? '').toString().trim();
          final stopIso = _highlanderStopIsoForServerRow(
            handoffIsoUtc: handoffIso,
            serverRow: row,
          );
          final stopFields = _nocoFieldsForPatch(<String, dynamic>{
            'end_time': stopIso,
            'status': 'stopped',
          });
          final code = await _patchRecordsRowWith404Recovery(
            originalQueryId: oq.isNotEmpty ? oq : rid,
            restId: rid,
            fields: stopFields,
          );
          if (code == 404) {
            _purgeGhostRecordById(rid);
            continue;
          }
          if (code < 200 || code >= 300) {
            throw StateError('HIGHLANDER_PATCH_FAILED_$code');
          }
        }
        final createdId = await _createRecordPb(runningFields);
        if (createdId == null || createdId.trim().isEmpty) {
          throw StateError('HIGHLANDER_POST_FAILED');
        }
        await _finalizeRecordCreateHandshake(
          pocketCreatedRecordId: createdId,
        );
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
      } finally {
        _recordCacheTimelineNotifyBatchDepth--;
      }
      clearOptimisticTimelineUi(notifyTimeline: false);
    } catch (e, st) {
      _log('HIGHLANDER server phase failed: $e');
      _log(st.toString());
      await _runBatchedRecordCacheTimelineNotify(() async {
        _restoreHighlanderRollbackToken(rollbackToken);
        clearOptimisticTimelineUi();
        _printAtomicCheckRunningCount();
      });
      AppSnack.failed();
    }
  }

  Future<String?> writeRecord(
    String dateKey,
    String taskText, {
    int? categoryId,
    DateTime? explicitStartTime,
    int? parentId,
    String? parentRecordId,
    String? sourcePlanPocketRecordId,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    if (_writeRecordMutationInFlight) return null;
    _writeRecordMutationInFlight = true;
    var deferWriteRecordMutationRelease = false;
    try {
      final parsed = getCleanTitleAndTags(taskText);
      int? cid = categoryId;
      cid = identifyCategory(parsed.title)?.id ?? cid;
      cid = _resolveRecordCategoryIdWithSmartLink(parsed.title, cid);
      if (!_planLocalCategoryIdIsConcrete(cid)) {
        final inferred = _smartInferCategoryId(parsed.title);
        if (_planLocalCategoryIdIsConcrete(inferred)) {
          cid = inferred;
        }
      }
      cid = _resolveColdStartRecordCategoryId(cid);
      if (!_categoryIdResolvableForPbRecordPost(cid)) {
        _log('writeRecord: cold-start could not resolve category_id');
        AppSnack.failed();
        return null;
      }
      final now = getPlanetaryNow();
      final start = explicitStartTime ?? now;
      final isStartingNow = explicitStartTime != null;
      final status =
          isStartingNow ? 'running' : (dateKey == _todayKey ? 'running' : 'completed');
      DateTime? endTime =
          isStartingNow ? null : (dateKey == _todayKey ? null : start);
      final startIso = start.toUtc().toIso8601String();
      final pr = parentRecordId?.trim();
      final hasParent =
          (pr != null && pr.isNotEmpty) || parentId != null;
      final sourcePlanForPayload = !hasParent
          ? pocketRelationIdOrNull(sourcePlanPocketRecordId)
          : null;
      // Plan category from PocketBase must not run before primary Highlander shadow (§9 main thread).
      if (status == 'running') {
        final isPrimary = !hasParent;
        late final String runningRecordBizId;
        if (isPrimary) {
          runningRecordBizId = _newClientRecordUuid();
          final runningFields = _nocoFieldsForPatch(<String, dynamic>{
            'user_id': _pidForPbFilter,
            'record_id': runningRecordBizId,
            'status': 'running',
            'title': parsed.title,
            'start_time': startIso,
            'end_time': null,
            'category_id': _recordCategoryBusinessPkForApi(cid),
            'type': 'record',
            'checklist': <Map<String, dynamic>>[],
            if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
            if (sourcePlanForPayload != null)
              'source_plan_id': sourcePlanForPayload,
          });
          if (pr != null && pr.isNotEmpty) {
            runningFields['parent_id'] = pr;
          } else if (parentId != null) {
            runningFields['parent_id'] = parentId.toString();
          }
          final patchTargets = <Map<String, String>>[];
          _HighlanderRollbackToken? rollbackToken;
          final prevNet = _primaryHighlanderNetworkChain;
          final netDone = Completer<void>();
          _primaryHighlanderNetworkChain = prevNet.then((_) => netDone.future);
          try {
            final shadowPerf = Stopwatch()..start();
            var msSnap = 0;
            var msApply = 0;
            try {
              _runBatchedRecordCacheTimelineNotifySync(() {
                final tSnap = Stopwatch()..start();
                final beforeLen = _cachedFlatRecords.length;
                final runningSnapshots =
                    _snapshotRunningRowsForHighlanderRollback();
                msSnap = tSnap.elapsedMilliseconds;
                final tApply = Stopwatch()..start();
                clearOptimisticTimelineUi();
                _startAtomicTaskSequenceApplyLocalPrimary(
                  createBody: runningFields,
                  patchTargetsOut: patchTargets,
                );
                final appended = _cachedFlatRecords.length > beforeLen;
                rollbackToken = _HighlanderRollbackToken(
                  runningSnapshotsByIndex: runningSnapshots,
                  appendedPendingRow: appended,
                );
                _printAtomicCheckRunningCount();
                msApply = tApply.elapsedMilliseconds;
              });
            } finally {
              if (kDebugMode) {
                debugPrint(
                  '[SHADOW_PERF] cache+notify=${shadowPerf.elapsedMilliseconds}ms '
                  '(snapshot_running=${msSnap}ms local_apply=${msApply}ms; '
                  'bottleneck=${msSnap >= msApply ? "_snapshotRunningRowsForHighlanderRollback" : "clearOptimistic+_startAtomicTaskSequenceApplyLocalPrimary+_printAtomicCheckRunningCount"})',
                );
              }
            }
            deferWriteRecordMutationRelease = true;
            unawaited(
              () async {
                try {
                  await prevNet;
                  await _highlanderPrimaryServerSync(
                    rollbackToken: rollbackToken,
                    runningFields: runningFields,
                  );
                } finally {
                  if (!netDone.isCompleted) netDone.complete();
                  _writeRecordMutationInFlight = false;
                }
              }(),
            );
            return runningRecordBizId;
          } catch (e, st) {
            _log('writeRecord primary Highlander local phase: $e');
            _log(st.toString());
            clearOptimisticTimelineUi();
            if (!netDone.isCompleted) netDone.complete();
            rethrow;
          }
        }
        runningRecordBizId = _newClientRecordUuid();
        final rows = List<Map<String, dynamic>>.from(_cachedFlatRecords);
        for (final r in rows) {
          var sameParent = false;
          if (pr != null && pr.isNotEmpty) {
            sameParent = _parentFieldEqualsRecordId(r, pr);
          } else if (parentId != null) {
            sameParent = _rowInt(r['parent_id']) == parentId;
          }
          if (!sameParent) continue;
          if (!_isNocoRowSacredStopTarget(r)) continue;
          final id = recordsTablePk(r);
          if (id.isEmpty) continue;
          _log('PATCH_ID_TRACE: child-stop pb id=$id');
          final childFields = _nocoFieldsForPatch(<String, dynamic>{
            'end_time': startIso,
            'status': 'stopped',
          });
          final biz = (r['record_id'] ?? '').toString().trim();
          final cr = await _patchRecordsRowWith404Recovery(
            originalQueryId: biz.isNotEmpty ? biz : id,
            restId: id,
            fields: childFields,
          );
          if (cr == 404) {
            _purgeGhostRecordById(id);
          }
        }
        final runningFields = _nocoFieldsForPatch(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'record_id': runningRecordBizId,
          'status': 'running',
          'title': parsed.title,
          'start_time': startIso,
          'end_time': null,
          'category_id': _recordCategoryBusinessPkForApi(cid),
          'type': 'record',
          'checklist': <Map<String, dynamic>>[],
          if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
          if (sourcePlanForPayload != null)
            'source_plan_id': sourcePlanForPayload,
        });
        if (pr != null && pr.isNotEmpty) {
          runningFields['parent_id'] = pr;
        } else if (parentId != null) {
          runningFields['parent_id'] = parentId.toString();
        }
        final newId = await _createRecordPb(runningFields);
        if (newId == null) {
          _log('writeRecord PocketBase create failed');
          return null;
        }
        await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
        _notifyTimelineAfterRecordCacheMutation();
        return newId;
      } else {
        var cidForCompleted = cid;
        if (sourcePlanForPayload != null) {
          final pc = await _resolveCategoryIdFromSourcePlanPbId(
            sourcePlanForPayload,
          );
          if (_planLocalCategoryIdIsConcrete(pc)) {
            cidForCompleted = pc;
          }
        }
        cidForCompleted = _resolveColdStartRecordCategoryId(cidForCompleted);
        if (!_categoryIdResolvableForPbRecordPost(cidForCompleted)) {
          _log('writeRecord completed branch: cold-start could not resolve category_id');
          AppSnack.failed();
          return null;
        }
        final completedFields = _nocoFieldsForPatch(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'record_id': _newClientRecordUuid(),
          'status': 'completed',
          'title': parsed.title,
          'start_time': startIso,
          'end_time': endTime?.toUtc().toIso8601String(),
          'category_id': _recordCategoryBusinessPkForApi(cidForCompleted),
          'type': 'record',
          'checklist': <Map<String, dynamic>>[],
          if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
          if (sourcePlanForPayload != null)
            'source_plan_id': sourcePlanForPayload,
        });
        if (pr != null && pr.isNotEmpty) {
          completedFields['parent_id'] = pr;
        } else if (parentId != null) {
          completedFields['parent_id'] = parentId.toString();
        }
        final newId = await _createRecordPb(completedFields);
        if (newId == null) {
          _log('writeRecord PocketBase create failed (completed branch)');
          return null;
        }
        await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
        _notifyTimelineAfterRecordCacheMutation();
        return newId;
      }
    } catch (e, st) {
      _log('writeRecord failed: $e');
      _log(st);
      final isChildPost = (parentRecordId?.trim().isNotEmpty ?? false) ||
          parentId != null;
      if (!isChildPost) {
        clearOptimisticTimelineUi();
      }
      return null;
    }
    finally {
      if (!deferWriteRecordMutationRelease) {
        _writeRecordMutationInFlight = false;
      }
    }
  }

  /// In-memory cache patch so timeline UI can refresh immediately when the record sheet closes.
  void applyOptimisticRecordRowEdit({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    String? tags,
    List<Map<String, dynamic>>? checklist,
    bool syncSourcePlan = false,
    bool clearSourcePlan = false,
    String? sourcePlanPocketRecordId,
  }) {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    var rid = recordId.trim();
    if (rid.isEmpty) return;
    final originalInput = rid;
    final idx = _indexOfCachedRecordRow(rid, originalInput);
    if (idx < 0) return;
    final row = _cachedFlatRecords[idx];
    if (title != null) row['title'] = title;
    if (startTime != null) {
      row['start_time'] = startTime.toUtc().toIso8601String();
      if (endTime == null) row['status'] = 'running';
    }
    if (endTime != null) {
      row['end_time'] = endTime.toUtc().toIso8601String();
      row['status'] = 'stopped';
    }
    var resolvedCategoryId = categoryId;
    var shouldWriteCategory = categoryId != null;
    if (syncSourcePlan && !clearSourcePlan) {
      final sp = pocketRelationIdOrNull(sourcePlanPocketRecordId);
      if (sp != null) {
        final ic = _tryResolveCategoryIdFromSourcePlanPbIdSync(sp);
        if (_planLocalCategoryIdIsConcrete(ic)) {
          resolvedCategoryId = ic;
          shouldWriteCategory = true;
        }
      }
    }
    if (shouldWriteCategory && resolvedCategoryId != null) {
      row['category_id'] = _recordCategoryBusinessPkForApi(resolvedCategoryId);
    }
    if (note != null) row['note'] = note;
    if (tags != null) {
      final t = tags.trim();
      if (t.isNotEmpty) row['tags'] = t;
    }
    if (checklist != null) row['checklist'] = checklist;
    if (syncSourcePlan) {
      if (clearSourcePlan) {
        row['source_plan_id'] = null;
      } else {
        final sp = pocketRelationIdOrNull(sourcePlanPocketRecordId);
        if (sp != null) row['source_plan_id'] = sp;
      }
    }
    _notifyTimelineAfterRecordCacheMutation();
  }

  Future<TimelineRecord?> updateRecord({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    /// Comma-separated tag **names** (@DATA_MAP `records.tags` string). Omitted when null or blank.
    String? tags,
    List<Map<String, dynamic>>? checklist,
    bool syncSourcePlan = false,
    bool clearSourcePlan = false,
    String? sourcePlanPocketRecordId,
    bool bypassConflictCheck = false,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    Map<String, dynamic>? rollbackRow;
    var rollbackIndex = -1;
    try {
      var rid = recordId.trim();
      if (rid.isEmpty) return null;
      final originalInput = rid;
      rid = await _resolveRecordIdForRestUrl(rid);
      _log('PATCH_ID_TRACE: updateRecord pb id=$rid');
      var categoryForPatch = categoryId;
      var shouldPatchCategory = categoryId != null;
      if (syncSourcePlan && !clearSourcePlan) {
        final sp0 = pocketRelationIdOrNull(sourcePlanPocketRecordId);
        if (sp0 != null) {
          final pc = await _resolveCategoryIdFromSourcePlanPbId(sp0);
          if (_planLocalCategoryIdIsConcrete(pc)) {
            categoryForPatch = pc;
            shouldPatchCategory = true;
          }
        }
      }
      if (title != null && !shouldPatchCategory) {
        final inferred = _smartInferCategoryId(title);
        if (_planLocalCategoryIdIsConcrete(inferred)) {
          categoryForPatch = inferred;
          shouldPatchCategory = true;
        }
      }
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (endTime != null) {
        updates['end_time'] = endTime.toUtc().toIso8601String();
        updates['status'] = 'stopped';
      }
      if (startTime != null) {
        updates['start_time'] = startTime.toUtc().toIso8601String();
        if (endTime == null && !updates.containsKey('status')) {
          updates['status'] = 'running';
        }
      }
      if (shouldPatchCategory && categoryForPatch != null) {
        updates['category_id'] =
            _recordCategoryBusinessPkForApi(categoryForPatch);
      }
      if (note != null) updates['note'] = note;
      if (tags != null) {
        final t = tags.trim();
        if (t.isNotEmpty) updates['tags'] = t;
      }
      if (checklist != null) updates['checklist'] = checklist;
      if (syncSourcePlan) {
        if (clearSourcePlan) {
          updates['source_plan_id'] = null;
        } else {
          final sp = pocketRelationIdOrNull(sourcePlanPocketRecordId);
          if (sp != null) updates['source_plan_id'] = sp;
        }
      }
      if (updates.isEmpty) {
        final rows = await getRecords();
        Map<String, dynamic>? found;
        for (final r in rows) {
          if (recordsTablePk(r) == rid ||
              (r['record_id'] ?? '').toString().trim() == rid ||
              (r['record_id'] ?? '').toString().trim() == originalInput) {
            found = r;
            break;
          }
        }
        if (found == null) return null;
        return TimelineRecord.fromMap(_rowToRecordMap(found),
            systemId: rid,
            timezoneOffsetHours: _settings.timezoneOffsetHours);
      }
      rollbackIndex = _indexOfCachedRecordRow(rid, originalInput);
      if (rollbackIndex >= 0) {
        rollbackRow = Map<String, dynamic>.from(_cachedFlatRecords[rollbackIndex]);
        final row = _cachedFlatRecords[rollbackIndex];
        if (title != null) row['title'] = title;
        if (startTime != null) {
          row['start_time'] = startTime.toUtc().toIso8601String();
          if (endTime == null) row['status'] = 'running';
        }
        if (endTime != null) {
          row['end_time'] = endTime.toUtc().toIso8601String();
          row['status'] = 'stopped';
        }
        if (shouldPatchCategory && categoryForPatch != null) {
          row['category_id'] = updates['category_id'];
        }
        if (note != null) row['note'] = note;
        if (tags != null) {
          final t = tags.trim();
          if (t.isNotEmpty) row['tags'] = t;
        }
        if (checklist != null) row['checklist'] = checklist;
        if (syncSourcePlan) {
          if (clearSourcePlan) {
            row['source_plan_id'] = null;
          } else {
            final sp = pocketRelationIdOrNull(sourcePlanPocketRecordId);
            if (sp != null) row['source_plan_id'] = sp;
          }
        }
        _notifyTimelineAfterRecordCacheMutation();
      }
      final patchCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
      );
      if (patchCode == 404) {
        if (rollbackRow != null && rollbackIndex >= 0) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
        _purgeGhostRecordById(rid);
        await _fetchRecordsIntoCache(forceNetwork: true);
        _notifyTimelineAfterRecordCacheMutation();
        AppSnack.failed();
        return null;
      }
      if (patchCode < 200 || patchCode >= 300) {
        if (rollbackRow != null && rollbackIndex >= 0) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
        AppSnack.failed();
        return null;
      }
      await _fetchRecordsIntoCache(forceNetwork: true);
      final rows = await getRecords(forceNetwork: true);
      final row = rows.firstWhere(
        (r) =>
            recordsTablePk(r) == rid ||
            (r['record_id'] ?? '').toString().trim() == rid ||
            (r['record_id'] ?? '').toString().trim() == originalInput,
        orElse: () => <String, dynamic>{},
      );
      if (row.isEmpty) {
        AppSnack.failed();
        return null;
      }
      _notifyTimelineAfterRecordCacheMutation();
      return TimelineRecord.fromMap(_rowToRecordMap(row),
          systemId: rid,
          timezoneOffsetHours: _settings.timezoneOffsetHours);
    } catch (_) {
      if (rollbackRow != null && rollbackIndex >= 0) {
        if (rollbackIndex < _cachedFlatRecords.length) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
      }
      AppSnack.failed();
      return null;
    }
  }

  /// Links `source_plan_id` after the Start tap (plan suggestion moved off the critical path).
  /// Does not run a full records refresh on success — local cache + one PATCH only.
  Future<bool> patchRecordSourcePlanLink({
    required String recordId,
    required String sourcePlanPocketRecordId,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return false;
    final sp = pocketRelationIdOrNull(sourcePlanPocketRecordId);
    if (sp == null || sp.isEmpty) return false;
    Map<String, dynamic>? rollbackRow;
    var rollbackIndex = -1;
    try {
      var rid = _tryResolveRecordIdFromCacheOnly(originalInput);
      if (rid == null ||
          rid.isEmpty ||
          !_isLikelyPocketBaseRowId(rid)) {
        final resolved = await _resolveRecordIdForRestUrl(originalInput);
        rid = _isLikelyPocketBaseRowId(resolved) ? resolved : null;
      }
      if (rid == null || rid.isEmpty) {
        _log(
          'patchRecordSourcePlanLink: no PocketBase id yet for recordId=$originalInput',
        );
        return false;
      }
      _log('PATCH_ID_TRACE: patchRecordSourcePlanLink pb id=$rid');
      final pc = await _resolveCategoryIdFromSourcePlanPbId(sp);
      final shouldPatchCategory = _planLocalCategoryIdIsConcrete(pc);
      final updates = <String, dynamic>{
        'source_plan_id': sp,
      };
      if (shouldPatchCategory && pc != null) {
        updates['category_id'] = _recordCategoryBusinessPkForApi(pc);
      }
      rollbackIndex = _indexOfCachedRecordRow(rid, originalInput);
      if (rollbackIndex >= 0) {
        rollbackRow =
            Map<String, dynamic>.from(_cachedFlatRecords[rollbackIndex]);
        final row = _cachedFlatRecords[rollbackIndex];
        row['source_plan_id'] = sp;
        if (shouldPatchCategory && pc != null) {
          row['category_id'] = updates['category_id'];
        }
        _notifyTimelineAfterRecordCacheMutation();
      }
      final patchCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
      );
      if (patchCode == 404) {
        if (rollbackRow != null && rollbackIndex >= 0) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
        _purgeGhostRecordById(rid);
        return false;
      }
      if (patchCode < 200 || patchCode >= 300) {
        if (rollbackRow != null && rollbackIndex >= 0) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
        AppSnack.failed();
        return false;
      }
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (e, st) {
      _log('patchRecordSourcePlanLink failed: $e');
      _log(st.toString());
      if (rollbackRow != null && rollbackIndex >= 0) {
        if (rollbackIndex < _cachedFlatRecords.length) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
      }
      AppSnack.failed();
      return false;
    }
  }

  /// Alias for [updateRecord] (PocketBase row PATCH by record id).
  Future<TimelineRecord?> patchRecord({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    String? tags,
    List<Map<String, dynamic>>? checklist,
    bool syncSourcePlan = false,
    bool clearSourcePlan = false,
    String? sourcePlanPocketRecordId,
    bool bypassConflictCheck = false,
  }) =>
      updateRecord(
        recordId: recordId,
        title: title,
        startTime: startTime,
        endTime: endTime,
        categoryId: categoryId,
        note: note,
        tags: tags,
        checklist: checklist,
        syncSourcePlan: syncSourcePlan,
        clearSourcePlan: clearSourcePlan,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
        bypassConflictCheck: bypassConflictCheck,
      );

  Future<bool> deleteRecordByDocId(String recordId) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return false;
    final delKeys = _collectRecordKeysFromCache(originalInput);
    for (final k in delKeys) {
      if (k.isNotEmpty) _optimisticDeletedKeys.add(k);
    }
    _notifyTimelineAfterRecordCacheMutation();
    try {
      final rid = await _resolveRecordIdForStopOrDelete(originalInput);
      final delCode = await _deleteRecordsRowWithFallback(
        originalQueryId: originalInput,
        restId: rid,
      );
      if (delCode == 404) {
        _purgeGhostRecordById(rid);
      }
      final ok = (delCode >= 200 && delCode < 300) || delCode == 404;
      if (!ok) {
        for (final k in delKeys) {
          _optimisticDeletedKeys.remove(k);
        }
        _notifyTimelineAfterRecordCacheMutation();
        _snackDeleteHttpFailure(delCode);
        return false;
      }
      await _fetchRecordsIntoCache(forceNetwork: true);
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.deleted();
      return true;
    } on LegacyIdResolutionException catch (e, st) {
      _log('deleteRecordByDocId: $e');
      _log(st.toString());
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.show(
        t(currentLocale.value, 'error_stop_id_unresolved'),
        error: true,
      );
      return false;
    } catch (e, st) {
      _log('deleteRecordByDocId failed: $e');
      _log(st.toString());
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.show(
        t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
        error: true,
      );
      return false;
    }
  }

  Future<void> deleteRecord(String recordId) async {
    await deleteRecordByDocId(recordId);
  }

  /// PocketBase PATCH stop after [resolvedPbId] is known (shadow or awaited resolve).
  Future<bool> _patchStopRecordNetworkPhase(
    String originalInput,
    String resolvedPbId,
  ) async {
    final nowIso = getPlanetaryNow().toUtc().toIso8601String();
    _log('PATCH_ID_TRACE: stopRecordByDocId pb id=$resolvedPbId');
    final stopFields = _nocoFieldsForPatch(<String, dynamic>{
      'end_time': nowIso,
      'status': 'stopped',
    });
    final stopCode = await _patchRecordsRowWith404Recovery(
      originalQueryId: originalInput,
      restId: resolvedPbId,
      fields: stopFields,
      debugPbClientException: true,
    );
    if (stopCode == 404) {
      _purgeGhostRecordById(resolvedPbId);
      _clearOptimisticStopKeysForRecord(originalInput);
      if (_lastRecordsPatchSkippedDeadLetter) {
        _brainSnackError(
          t(currentLocale.value, 'error_stop_dead_letter_skip'),
        );
      } else {
        _snackStopHttpFailure(404);
      }
      return false;
    }
    final ok = stopCode >= 200 && stopCode < 300;
    if (ok) {
      _clearOptimisticStopKeysForRecord(originalInput);
      AppSnack.updated();
      return true;
    }
    _clearOptimisticStopKeysForRecord(originalInput);
    _notifyTimelineAfterRecordCacheMutation();
    _snackStopHttpFailure(stopCode);
    return false;
  }

  /// Stops a record via PocketBase `records` PATCH — the argument must resolve to PB row **`id`** (15-char).
  /// Legacy column `record_id` (UUID) is mapped internally but must not be passed from UI as the primary key.
  /// Returns **`true` only** for **2xx** (not 404). Optimistic UI reverts when the request fails.
  Future<bool> stopRecordByDocId(String recordId) async {
    if (!_isInitialized) {
      debugPrint('[ABORT_REASON] Exiting early because: !_isInitialized (_isInitialized=$_isInitialized). No PATCH.');
      _brainSnackError(t(currentLocale.value, 'error_stop_brain_not_ready'));
      return false;
    }
    if (!_hasAuthenticatedUserId) {
      debugPrint('[ABORT_REASON] Exiting early because: PocketBase auth record id is missing (_isInitialized=$_isInitialized, currentProfileId=$currentProfileId). No PATCH.');
      _brainSnackError(t(currentLocale.value, 'error_stop_brain_not_ready'));
      return false;
    }
    var rid = recordId.trim();
    if (rid.isEmpty) {
      debugPrint('[ABORT_REASON] Exiting early because: trimmed recordId is empty. No PATCH.');
      _brainSnackError(t(currentLocale.value, 'error_stop_empty_doc_id'));
      return false;
    }
    if (_stopRecordInFlightKeys.contains(rid)) {
      return false;
    }
    _stopRecordInFlightKeys.add(rid);
    final originalInput = rid;
    _applyOptimisticStopUiSnapshot(originalInput);

    final shadowRid = _tryResolveRecordIdFromCacheOnly(originalInput);
    if (shadowRid != null && _isLikelyPocketBaseRowId(shadowRid)) {
      unawaited(
        _patchStopRecordNetworkPhase(originalInput, shadowRid)
            .catchError((Object e, StackTrace st) {
          _log('stopRecordByDocId shadow async: $e');
          _log(st.toString());
          _clearOptimisticStopKeysForRecord(originalInput);
          _notifyTimelineAfterRecordCacheMutation();
          if (e is ClientException) {
            _snackStopHttpFailure(e.statusCode);
          } else {
            _brainSnackError(
              t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
            );
          }
          return false;
        }).whenComplete(() {
          _stopRecordInFlightKeys.remove(originalInput);
        }),
      );
      return true;
    }

    try {
      rid = await _resolveRecordIdForStopOrDelete(rid);
      if (!_isLikelyPocketBaseRowId(rid)) {
        debugPrint('[ABORT_REASON] After resolve, rid="$rid" is not a PocketBase row id segment (fails _isLikelyPocketBaseRowId). Throwing LegacyIdResolutionException.');
        throw LegacyIdResolutionException(originalInput);
      }
      return await _patchStopRecordNetworkPhase(originalInput, rid);
    } on LegacyIdResolutionException catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint('[ABORT_REASON] LegacyIdResolutionException — could not map input to PB row id: $e');
      _log('stopRecordByDocId: $e');
      _log(st.toString());
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _brainSnackError(t(currentLocale.value, 'error_stop_id_unresolved'));
      return false;
    } on ClientException catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint('[ABORT_REASON] stopRecordByDocId: PocketBase ClientException status=${e.statusCode} $e');
      _log('stopRecordByDocId failed: $e');
      _log(st.toString());
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _snackStopHttpFailure(e.statusCode);
      return false;
    } catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint('[ABORT_REASON] stopRecordByDocId: unexpected exception before/after PATCH: $e');
      _log('stopRecordByDocId failed: $e');
      _log(st.toString());
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _brainSnackError(
        t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
      );
      return false;
    } finally {
      _stopRecordInFlightKeys.remove(originalInput);
    }
  }

  /// Alias for [stopRecordByDocId] (Sacred Law / singleton stop).
  Future<bool> stopRecord(String recordId) async => stopRecordByDocId(recordId);

  Future<void> updateRecordChecklist(
      String recordId, List<Map<String, dynamic>> checklist) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    try {
      var rid = recordId.trim();
      if (rid.isEmpty) return;
      final originalInput = rid;
      rid = await _resolveRecordIdForRestUrl(rid);
      final clFields = _nocoFieldsForPatch(<String, dynamic>{'checklist': checklist});
      final clCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: clFields,
      );
      if (clCode == 404) {
        _purgeGhostRecordById(rid);
      }
      await _fetchRecordsIntoCache(forceNetwork: true);
      _notifyTimelineAfterRecordCacheMutation();
    } catch (_) {}
  }

}
