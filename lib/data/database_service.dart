import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/plans/diagnostics/plan_duplicate_log.dart';
import 'package:counter/shared/diagnostics/runtime_log.dart';
import 'package:counter/shared/diagnostics/startup_log.dart';
import 'package:counter/shared/diagnostics/performance/runtime_flags.dart';
import 'package:counter/core/widgets/day_window.dart';
import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/core/link_scalar.dart';
import 'package:counter/data/cache/day_snapshot_window.dart';
import 'package:counter/data/cache/render_snapshot.dart';
import 'package:counter/data/cache/rendered_day_body_cache.dart';
import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/local_sync/offline_sync_state.dart';
import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:counter/data/local_sync/sync_manager.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart' as plan_time_seq;
import 'package:counter/data/pb_config.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:rrule/rrule.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/data/smart_input_parser.dart';
import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:counter/shared/time/plan_time_labels.dart';
import 'package:counter/shared/time/plan_time_visible_window.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:counter/shared/time/category_timezone_options.dart' as tz_cat;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'profile/profile_timezone.dart';
part 'profile/profile_hydration.dart';
part 'profile/profile_cache_helpers.dart';
part 'profile/profile_preferences.dart';
part 'profile/profile_admin.dart';
part 'profile/tag_catalog.dart';
part 'profile/tag_display_settings.dart';
part 'profile/profile_settings.dart';
part 'profile_service.dart';
part 'plans/plan_projection_types.dart';
part 'plans/plan_recurrence_helpers.dart';
part 'plans/plan_time_cascade_helpers.dart';
part 'plans/plan_tags_helpers.dart';
part 'plans/plan_cache_helpers.dart';
part 'plans/plan_outbox_helpers.dart';
part 'plans/plan_snapshot_helpers.dart';
part 'plans/plan_stream_helpers.dart';
part 'plans/plan_optimistic_helpers.dart';
part 'plans/plan_order_helpers.dart';
part 'plans/plan_record_link_helpers.dart';
part 'plans/notes_brain_helpers.dart';
part 'plans/plan_alarm_helpers.dart';
part 'plans/plan_ai_parse_helpers.dart';
part 'plan_service.dart';
part 'records/record_crud.dart';
part 'records/record_optimistic.dart';
part 'records/record_realtime.dart';
part 'records/record_timeline_vm.dart';
part 'records/record_outbox_helpers.dart';
part 'records/record_overlap_helpers.dart';
part 'records/record_ghost_cleanup.dart';
part 'records/record_cache_helpers.dart';
part 'record_service.dart';
part 'categories/category_crud.dart';
part 'categories/category_tree.dart';
part 'categories/category_lookup.dart';
part 'categories/category_stats.dart';
part 'categories/category_record_bridge.dart';
part 'categories/category_default_time.dart';
part 'categories/category_cache_helpers.dart';
part 'categories/category_order_helpers.dart';
part 'category_service.dart';
part 'db_core.dart';

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

  /// Unit/integration tests only — bypasses PocketBase auth for Brain record paths.
  @visibleForTesting
  static String? debugAuthUserIdForTests;

  /// Offline queue + sync indicator (O1). Updated by outbox enqueue/flush and [SyncManager].
  final OfflineSyncController offlineSync = OfflineSyncController();

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
      if (s != null && CategoryServiceExtension._isLikelyUuidOrLongPk(s)) return s;
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

  /// Exposed for sync-banner diagnostics only.
  bool get pbHttpBackoffActive => _pbHttpBackoffActive;

  String _scopedDataCacheKey(String base) {
    final u = (currentProfileId ?? _userIdForWhere ?? '').trim();
    if (u.isEmpty) return '${base}_anon';
    return '${base}_$u';
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

  static String? _lastSyncFlushFailLog;
  static DateTime? _lastSyncFlushFailLogAt;
  static const Duration _syncFlushFailLogDebounce = Duration(seconds: 15);

  /// Debounced console line for outbox flush failures (release-safe via print).
  static void logSyncFlushFailure({
    required String collection,
    required String operation,
    String? businessId,
    String? pocketBaseId,
    int? httpStatus,
    String? message,
  }) {
    final now = DateTime.now();
    final line =
        'SYNC_FLUSH_FAIL collection=$collection op=$operation '
        'businessId=${businessId ?? '-'} pbId=${pocketBaseId ?? '-'} '
        'http=${httpStatus ?? '-'} msg=${message ?? '-'}';
    if (_lastSyncFlushFailLog == line &&
        _lastSyncFlushFailLogAt != null &&
        now.difference(_lastSyncFlushFailLogAt!) < _syncFlushFailLogDebounce) {
      return;
    }
    _lastSyncFlushFailLog = line;
    _lastSyncFlushFailLogAt = now;
    // ignore: avoid_print
    print(line);
  }

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
    _syncCanonicalRunningBusinessIdCache('timelineEmit');
    _timelineDayIndexDirty = true;
    _timelineDayViewCache.clear();
    _timeUpdateController.add(null);
    // Plan alarms are reconciled from planning refresh / resume / hydrate only
    // (not on every record timeline emit — Law of the Main Thread).
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
    final row = _canonicalPrimaryRunningFlatRow();
    if (row == null) return null;
    final tit = (row['title'] ?? '').toString().trim();
    return tit.isEmpty ? null : tit;
  }

  /// Category display path for the primary running record (for stop confirmation).
  String? get cachedPrimaryRunningCategoryPath {
    final row = _canonicalPrimaryRunningFlatRow();
    if (row == null) return null;
    final cid = categoryIdFromRecordRow(row);
    if (cid == null || cid <= 0) return null;
    final path = getCategoryPath(cid).trim();
    return path.isEmpty ? null : path;
  }

  int _indexOfCachedRecordRow(String resolvedRid, String originalInput) {
    for (var i = 0; i < _cachedFlatRecords.length; i++) {
      final r = _cachedFlatRecords[i];
      final pk = CategoryServiceExtension.recordsTablePk(r);
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

  /// Date-key → filtered timeline rows; rebuilt lazily when flat cache or optimistic layer changes.
  Map<String, List<Map<String, dynamic>>> _timelineRecordsDayIndex = {};
  bool _timelineDayIndexDirty = true;
  int _timelineDayIndexBuiltAtRecordCount = -1;

  /// Render-ready per-day rows (with display times); invalidated on index rebuild.
  final Map<String, List<Map<String, dynamic>>> _timelineDayViewCache = {};

  /// Precomputed timeline row VMs per calendar day; invalidated with view cache.
  final Map<String, List<TimelineRecordRowVm>> _timelineDayVmCache = {};

  /// Lazy per-row VM cache (dateKey → recordKey → VM); avoids building all rows at once.
  final Map<String, Map<String, TimelineRecordRowVm>> _timelineLazyRowVmByDay = {};

  /// True while a deferred full day-index rebuild is running off the hot swipe path.
  bool _timelineDayIndexBuildInFlight = false;

  /// Latest center date for prefetch cancellation (YYYY-MM-DD).
  String? _timelinePrefetchCenterKey;

  /// In-flight neighbor prefetch keys (date YYYY-MM-DD).
  final Set<String> _timelinePrefetchInFlight = {};

  /// P0O: rolling warm day snapshots (data only — not full page widgets).
  WarmSnapshotWindow<TimelineDaySnapshot>? _timelineWarmWindow;
  WarmSnapshotWindow<PlansDaySnapshot>? _plansWarmWindow;

  /// P0P/P0R: render-warmed day body entries (content lists only).
  DayBodyCache<TimelineDayBodyEntry>? _timelineBodyCache;
  DayBodyCache<PlansDayBodyEntry>? _plansBodyCache;

  bool _timelineWindowBodyPrebuildInFlight = false;
  bool _plansWindowBodyPrebuildInFlight = false;
  int _timelineBodyPrebuildGeneration = 0;
  int _plansBodyPrebuildGeneration = 0;

  static const String _cachePlansWarmSnapshotsKey = 'warm_plans_snapshots_v1';
  static const String _cacheTimelineWarmSnapshotsKey =
      'warm_timeline_snapshots_v1';

  /// PocketBase realtime: unsubscribe function from [RecordService.subscribe] ('*').
  Future<void> Function()? _recordsRealtimeUnsubscribe;

  /// Exponential backoff for `/api/realtime` reconnects: 5s → 10s → 20s (caps spam + main-thread churn).
  static const List<int> _kRealtimeBackoffSeconds = [5, 10, 20];
  int _recordsRealtimeFailureStreak = 0;
  Timer? _recordsRealtimeReconnectTimer;  /// Prevents overlapping subscribe attempts (avoids recursive reconnect / stacked futures).
  Future<void>? _recordsRealtimeSubscribeFuture;
  DateTime? _lastRealtimeSubscribeErrorLogAt;

  /// Plans realtime backoff (mirrors records).
  int _plansRealtimeFailureStreak = 0;
  Timer? _plansRealtimeReconnectTimer;
  DateTime? _lastPlansRealtimeSubscribeErrorLogAt;

  /// When set, `/api/realtime` is unavailable (404/proxy) — skip subscribe until elapsed.
  DateTime? _realtimeEndpointUnavailableUntil;
  bool _pocketBaseRealtimeGuardsAttached = false;

  /// True while record/plan outbox flush holds [OfflineSyncController.isSyncing].
  bool get isSyncFlushInFlight =>
      _planMutationOutboxFlushInFlight || _recordMutationOutboxFlushInFlight;

  bool get isPbRealtimeUnavailable {
    final until = _realtimeEndpointUnavailableUntil;
    return until != null && DateTime.now().isBefore(until);
  }

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

  /// P0U.7 — cached newest primary running business id (O(1) Timeline VM path).
  bool _canonicalRunningBusinessIdCacheDirty = true;
  String? _cachedCanonicalRunningBusinessId;

  /// Dedupes rapid repeat **stop** taps for the same timeline id (UUID or REST id).
  final Set<String> _stopRecordInFlightKeys = <String>{};

  /// Dedupes overlapping **writeRecord** / **writeCompletedRecord** calls.
  bool _writeRecordMutationInFlight = false;

  /// Last PocketBase HTTP status from [_createRecordPb] (0 = none / non-HTTP failure).
  int _lastRecordCreateFailureHttpCode = 0;

  Stream<String?> get notifications => _notify.stream;
  List<CategoryRule> get rules => List.unmodifiable(_rules);
  static DateTime getPlanetaryNow() => DateTime.now().toUtc();
  List<CategoryRule> get categoryRules => rules;

  /// PocketBase **signed-in auth record id** only (same value as child-row `user_id`). No int surrogate.
  String? get _userIdForWhere {
    final testId = (debugAuthUserIdForTests ?? '').trim();
    if (testId.isNotEmpty) return testId;
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

  /// Refreshes timeline cache after PocketBase create; [pocketCreatedRecordId] is the new row id.

}
