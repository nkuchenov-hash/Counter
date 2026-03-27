import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/constants.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/features/profile/wall_clock.dart' as wall_clock;
import 'package:counter/nocodb_response.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// NocoDB REST (Brain). Only http + SharedPreferences here.

class _BuildNode {
  _BuildNode(this.label);
  final String label;
  int totalSeconds = 0;
  final Map<String, _BuildNode> children = {};
  final Map<String, List<Map<String, dynamic>>> sessionGroups = {};
}

class _SignInRequiredException implements Exception {
  _SignInRequiredException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// In-memory only: timeline shows [endUtc] until server confirms or optimistic layer is cleared.
class _OptimisticEndPatch {
  _OptimisticEndPatch(this.endUtc);
  final DateTime endUtc;
}

/// Thrown when profile fetch returns 404 or 422 (invalid session / UUID mismatch).
class _ProfileFetchFailedException implements Exception {
  _ProfileFetchFailedException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
  @override
  String toString() => message ?? 'Profile fetch failed: $statusCode';
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

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  /// NocoDB v3 Data API authentication (`xc-token` header on every REST call).
  static const String nocoXcToken =
      'Zi1tRdLEWLq4f8kQU4aJYILY255BV43PJ3fgVoAs';

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

  /// NocoDB v3 may return the new row id only in the HTTP `Location` header.
  static String? _recordIdFromResponseLocation(http.Response res) {
    try {
      final loc = res.headers['location'] ?? res.headers['Location'];
      if (loc == null || loc.trim().isEmpty) return null;
      final uri = Uri.tryParse(loc.trim());
      if (uri == null) return null;
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isEmpty) return null;
      if (segs.length >= 2 &&
          segs[segs.length - 2].toLowerCase() == 'records') {
        return _sanitizePkString(segs.last);
      }
      return _sanitizePkString(segs.last);
    } catch (_) {
      return null;
    }
  }

  /// Public host for Noco v3 Data API (no path — [baseUrl] adds `/api/v3/data/...`).
  static const String _nocoApiHost = '217-114-0-201.sslip.io';
  /// NocoDB v3 Base ID (verify in NocoDB: Project Settings / API). 404 on /tables is common in v3 — use UI to verify column names.
  static const String _baseId = 'pfew89z7fxv42ek';
  /// v3 Data API: `https://{host}/api/v3/data/{baseId}/...` (no `/noco/` segment — that path returns 404).
  static String get baseUrl => 'https://$_nocoApiHost/api/v3/data/$_baseId';

  /// `PATCH` / `DELETE` single record row: `.../{tableUid}/records/{Id}` (integer [Id] only).
  static String _recordsRowUrl(String rowId) =>
      '$baseUrl/$_recordsTableUid/records/${rowId.trim()}';

  /// Single-row PATCH URL candidates (some servers 404 all of these but accept [PATCH_BULK_TABLE]).
  List<String> _recordRowPatchUrlCandidates(String rowId) {
    final s = rowId.trim();
    if (s.isEmpty) return <String>[];
    final enc = Uri.encodeComponent(s);
    return <String>[
      '$baseUrl/$_recordsTableUid/records/$enc',
      '$baseUrl/tables/$_recordsTableUid/records/$enc',
      '$baseUrl/$_recordsTableUid/$enc',
    ];
  }

  /// Noco v3: bulk PATCH to the **collection** `[{"id":..., "fields":{...}}]` when `/records/{id}` returns 404.
  List<String> get _recordsBulkPatchUrls => <String>[
        '$baseUrl/$_recordsTableUid/records',
        '$baseUrl/tables/$_recordsTableUid/records',
      ];

  /// Plans `DELETE`: collection URL + bulk body `[{"Id":<int>},…]` (see [deletePlanningTasksBulk]).

  /// NocoDB v3 table IDs (Table Settings -> API). List: `baseUrl/{tableUid}/records`; row: `baseUrl/{tableUid}/records/{rowId}`.
  static const String _profilesRecords = NocoV3TablePaths.profiles;
  static const String _categoriesRecords = NocoV3TablePaths.categories;
  static const String _recordsRecords = NocoV3TablePaths.records;
  static const String _recordsTableUid = NocoV3TablePaths.recordsTableUid;
  static const String _plansRecords = NocoV3TablePaths.plans;
  static const String _plansTableUid = NocoV3TablePaths.plansTableUid;
  static bool get _isPlansTableConfigured =>
      _plansRecords.trim().isNotEmpty && _plansRecords != _recordsRecords;

  /// One-line proof at startup that timeline **records** REST uses @DATA_MAP `records` UID, not `categories`.
  void _logRecordVsCategoryTableRouting() {
    final ru = NocoV3TablePaths.recordsTableUid;
    final cu = NocoV3TablePaths.categoriesTableUid;
    _log(
      'NOCO_TABLE_ROUTE: records uid=$ru segment=$_recordsRecords | categories uid=$cu segment=$_categoriesRecords',
    );
  }

  String? currentProfileId;

  static void _log(Object? message) {
    debugPrint('[DatabaseService] $message');
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

  static const String _dataRegionKey = 'data_region';
  static const String _profileTzLabelKey = 'profile_preferred_timezone';
  static const String _profileTzOffsetKey = 'profile_timezone_offset_hours';
  static const String _profileThemeModeKey = 'profile_theme_mode';
  /// One-shot local clean of titleless / "Untitled" rows from [_cachedFlatRecords] (@DATA_MAP ghost / bad creates).
  static const String _oneShotUntitledGhostCleanKey =
      'brain_one_shot_untitled_ghost_clean_v1';

  String _dataRegion = 'global';
  String? _loadErrorMessage;
  String? get loadErrorMessage => _loadErrorMessage;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SharedPreferences? _prefs;
  List<CategoryRule> _rules = [];
  UserSettings _settings = UserSettings(userId: 0);
  UserSettings get settings => _settings;

  int? _lastAggregatedKey;
  List<StatsNode>? _lastStatsNodeRoots;
  /// Integer id from profile row (for user_id where clause when profile id is UUID).
  int? _cachedProfileIntId;
  /// user_id (UUID) from profile row when applicable.
  String? _cachedProfileUuid;

  final StreamController<UserSettings> _settingsController =
      StreamController<UserSettings>.broadcast();
  final StreamController<List<CategoryRule>> _categoryController =
      StreamController<List<CategoryRule>>.broadcast();
  final StreamController<List<PlanningTask>> _tasksController =
      StreamController<List<PlanningTask>>.broadcast();
  final StreamController<String?> _notify =
      StreamController<String?>.broadcast();
  final StreamController<void> _timeUpdateController =
      StreamController<void>.broadcast();

  Stream<void> get timeUpdates => _timeUpdateController.stream;

  Stream<UserSettings> get userSettingsStream => Stream.multi((c) {
        c.add(_settings);
        _settingsController.stream.listen(c.add, onError: c.addError);
      });

  Stream<List<CategoryRule>> get categoryStream => Stream.multi((c) {
        c.add(List.from(_rules));
        _categoryController.stream.listen(c.add, onError: c.addError);
      });

  Stream<List<PlanningTask>> get tasksStream => Stream.multi((c) {
        c.add(List.from(_tasksCache));
        _tasksController.stream.listen(c.add, onError: c.addError);
      });

  List<PlanningTask> _tasksCache = [];

  /// Planning reorder: debounced bulk PATCH of [order] only (@DATA_MAP `plans.order`, `user_id`).
  static const Duration _planOrderDebounce = Duration(seconds: 2);
  static const int _planOrderBulkChunkSize = 10;

  Timer? _planOrderDebounceTimer;
  List<PlanningTask>? _pendingPlanOrderSyncList;
  /// `planRowId` → server `order` before the first drag of the current reorder session (for diff-only PATCH).
  Map<String, int>? _planReorderBaselineByPlanId;

  /// Categories reorder: debounced bulk PATCH of [order] only (@DATA_MAP `categories`, `user_id`).
  static const Duration _categoryOrderDebounce = Duration(seconds: 2);
  Timer? _categoryOrderDebounceTimer;
  List<CategoryRule>? _pendingCategoryOrderSyncList;
  /// Local category id → list index before the first drag of the current reorder session.
  Map<int, int>? _categoryReorderBaselineByLocalId;

  /// Last successful flat fetch from Noco (same shape as [getRecords]). Timeline filters in-memory only.
  List<Map<String, dynamic>> _cachedFlatRecords = [];

  /// Timeline row keys (REST id / business UUID) that returned **definitive** 404 after full retry — no repeat PATCH/DELETE until row reappears in GET.
  final Set<String> _recordRestDefinitive404Keys = <String>{};

  // --- Optimistic timeline UI (merged into [recordsStream] / [activeRecordStream]; reverted on failure) ---

  /// Client-only: show ended state before PATCH returns.
  final Map<String, _OptimisticEndPatch> _optimisticEndByKey = {};

  /// Client-only: hide row before DELETE returns.
  final Set<String> _optimisticDeletedKeys = {};

  /// Synthetic running row while POST is in flight (primary timer start only).
  Map<String, dynamic>? _optimisticPendingStartRecordMap;

  Stream<String?> get notifications => _notify.stream;
  List<CategoryRule> get rules => List.unmodifiable(_rules);
  static DateTime getPlanetaryNow() => DateTime.now().toUtc();
  List<CategoryRule> get categoryRules => rules;

  Map<String, String> get _headers => <String, String>{
        'xc-token': nocoXcToken,
        'Content-Type': 'application/json',
      };

  String get _pid {
    final p = currentProfileId;
    if (p == null || p.isEmpty) throw StateError('No profile');
    return p;
  }

  /// Legacy int id for UserSettings when profile id is numeric; 0 for UUID.
  int get _pidInt => int.tryParse(_pid) ?? 0;

  void clearLocalStateOnSignOut() {
    try {
      _isInitialized = false;
      currentProfileId = null;
      _cachedProfileIntId = null;
      _cachedProfileUuid = null;
      _loadErrorMessage = null;
      _rules = [];
      _tasksCache = [];
      _cachedFlatRecords = [];
      _settings = UserSettings(userId: 0);
      _lastAggregatedKey = null;
      _lastStatsNodeRoots = null;
      _recordRestDefinitive404Keys.clear();
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      clearOptimisticTimelineUi();
      _timeUpdateController.add(null);
      _cancelPlanOrderDebounceTimer();
      _pendingPlanOrderSyncList = null;
      _planReorderBaselineByPlanId = null;
      _cancelCategoryOrderDebounceTimer();
      _pendingCategoryOrderSyncList = null;
      _categoryReorderBaselineByLocalId = null;
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

  /// Background refresh only; does not block UI.
  Future<void> reloadForDataRegionChange() async {
    if ((currentProfileId?.isNotEmpty ?? false)) {
      unawaited(loadInitialData(currentProfileId!));
    }
  }

  String get dataRegion => _dataRegion;

  Future<bool> loadInitialData(String uid) async {
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
          _settings = UserSettings(userId: _pidInt);
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
    } catch (e) {
      _isInitialized = true;
      _loadErrorMessage = 'Sync Error: $e';
      _settingsController.add(_settings);
      return true;
    }
  }

  Future<void> _loadInner() async {
    _prefs = await SharedPreferences.getInstance();
    _logRecordVsCategoryTableRouting();
    await _loadSettingsFromNoco();
    await _loadRulesFromNoco();
    try {
      await _fetchRecordsIntoCache();
    } catch (_) {}
    await _loadPlanningTasksForToday();
    // Safety re-run: finish startup with a final category load.
    await _loadRulesFromNoco();
    _settingsController.add(_settings);
    _categoryController.add(List.from(_rules));
    _tasksController.add(List.from(_tasksCache));
    // Shell must not treat Brain as ready until profile settings + categories + tasks are loaded.
    _isInitialized = true;
    try {
      await runOneShotUntitledGhostRecordClean();
    } catch (_) {}
  }

  Future<void> _loadPlanningTasksForToday() async {
    try {
      final today = getProjectedToday();
      _tasksCache = await _fetchPlanningTasksForDate(today);
      _tasksController.add(List.from(_tasksCache));
    } catch (_) {
      _tasksCache = [];
    }
  }

  /// Next `order` for a new plan on this wall day (for optimistic + POST).
  Future<int> nextPlanningOrderForDate(DateTime selectedDate) async {
    final list = await _fetchPlanningTasksForDate(selectedDate);
    if (list.isEmpty) return 0;
    var m = 0;
    for (final t in list) {
      if (t.order > m) m = t.order;
    }
    return m + 1;
  }

  Future<List<PlanningTask>> _fetchPlanningTasksForDate(DateTime selectedDate) async {
    try {
      if (!_isPlansTableConfigured) {
        _log('TABLE_GUARD: plans table is not configured (same as records). Skip plans fetch.');
        return [];
      }
      if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return [];
      final String where = _whereUserId;
      final rawRows = await _getList(_plansRecords, where, 1000);
      final rows = rawRows.map(_flattenNocoRecord).toList();
      final targetDayStr =
          '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}';
      final plans = <PlanningTask>[];
      for (final row in rows) {
        var anchorUtc = _parseDateTimeUtc(row['start_time']);
        anchorUtc ??= _parseDateTimeUtc(row['end_time']);
        if (anchorUtc == null) continue;
        final w = _profileWallFromUtc(anchorUtc);
        final planDayStr = '${w.year}-${_two(w.month)}-${_two(w.day)}';
        if (planDayStr != targetDayStr) continue;
        plans.add(_planRowToTask(row));
      }
      plans.sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        final o = a.order.compareTo(b.order);
        if (o != 0) return o;
        final at = a.startTime;
        final bt = b.startTime;
        if (at != bt) {
          if (at == null) return 1;
          if (bt == null) return -1;
          return at.compareTo(bt);
        }
        return a.title.compareTo(b.title);
      });
      return plans;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getList(
    String pathSegment,
    String? where,
    int? limit,
  ) async {
    try {
      final qp = <String, String>{};
      if (where != null) qp['where'] = where;
      if (limit != null) qp['limit'] = limit.toString();
      final uri = Uri.parse('$baseUrl/$pathSegment')
          .replace(queryParameters: qp.isEmpty ? null : qp);
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 422 && where != null && where.contains("'")) {
        final whereUnquoted = where.replaceAll("'", '');
        final fallbackUri = Uri.parse('$baseUrl/$pathSegment').replace(
          queryParameters: <String, String>{
            'where': whereUnquoted,
            if (limit != null) 'limit': limit.toString(),
          },
        );
        final fallbackRes = await http.get(fallbackUri, headers: _headers);
        if (fallbackRes.statusCode >= 200 && fallbackRes.statusCode < 300) {
          final j2 = jsonDecode(fallbackRes.body);
          if (j2 is! Map) return [];
          final list2 = j2['list'] ?? j2['records'];
          if (list2 is! List) return [];
          return list2.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        _log('GET failed for $pathSegment (422 with quoted/unquoted where).');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final j = jsonDecode(res.body);
      if (j is! Map) return [];
      final list = j['list'] ?? j['records'];
      if (list is! List) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      _log('GET failed for $pathSegment: $e');
      _log(st);
      return [];
    }
  }

  /// Fetches profile by user_id. OWNERSHIP_FILTER only — no unscoped GET (@ARCHITECTURE.md §3).
  Future<Map<String, dynamic>?> getUserProfile(String id) async {
    final whereValue = "(user_id,eq,'$id')";
    var uri = Uri.parse('$baseUrl/$_profilesRecords').replace(
      queryParameters: <String, String>{'where': whereValue},
    );
    var res = await http.get(uri, headers: _headers);
    if (res.statusCode == 422 && whereValue.contains("'")) {
      final whereUnquoted = whereValue.replaceAll("'", '');
      uri = Uri.parse('$baseUrl/$_profilesRecords').replace(
        queryParameters: <String, String>{'where': whereUnquoted},
      );
      res = await http.get(uri, headers: _headers);
    }
    if (res.statusCode == 404 || res.statusCode == 422) {
      throw _ProfileFetchFailedException(
        res.statusCode,
        'Session invalid or profile not found',
      );
    } else if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }
    final j = jsonDecode(res.body);
    if (j is! Map<String, dynamic>) return null;
    final rawList = (j['records'] ?? j['list']) as List?;
    if (rawList == null || rawList.isEmpty) return null;
    final item = rawList.first;
    if (item is! Map) return null;
    final record = Map<String, dynamic>.from(item);
    Map<String, dynamic> raw = record.containsKey('fields')
        ? Map<String, dynamic>.from(record['fields'] as Map)
        : record;
    if (record.containsKey('id') && record['id'] != null) {
      raw['id'] = record['id'];
    } else {
      final resolvedId = raw['user_id'] ?? raw['id'];
      if (resolvedId != null) raw['id'] = resolvedId;
    }
    return raw;
  }

  /// Shell: current profile as map (snake_case keys aligned with UI).
  /// Rethrows _ProfileFetchFailedException so loadInitialData can force logout on 422/404.
  Future<Map<String, dynamic>> getCurrentUserProfileMap() async {
    try {
      final id = currentProfileId;
      if (id == null || id.isEmpty) return {};
      final m = await getUserProfile(id);
      return m ?? {};
    } on _ProfileFetchFailedException {
      rethrow;
    } catch (_) {
      return {};
    }
  }

  /// Integer id for where clause; 0 when no cached profile id (stops network calls).
  int get _userIdForWhere => _cachedProfileIntId ?? _pidInt;

  /// Where clause for user_id: uses UUID from profile so NocoDB filter returns user's data.
  String get _whereUserId => "(user_id,eq,'$_pid')";

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return [];
    try {
      final qp = <String, String>{
        'where': _whereUserId,
        'limit': '1000',
      };
      final categoriesUri =
          Uri.parse('$baseUrl/$_categoriesRecords').replace(queryParameters: qp);
      final response = await http.get(categoriesUri, headers: _headers);
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      final decoded = jsonDecode(response.body);
      final rawRows = decoded is Map
          ? (decoded['records'] ?? decoded['list'] ?? <dynamic>[])
          : <dynamic>[];
      if (rawRows is! List) return [];
      return rawRows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Network fetch; updates [_cachedFlatRecords] for timeline filtering without repeated GETs.
  Future<List<Map<String, dynamic>>> _fetchRecordsIntoCache() async {
    final pid = currentProfileId;
    if (pid == null || pid.isEmpty) {
      _cachedFlatRecords = [];
      return [];
    }
    if (!(currentProfileId?.isNotEmpty ?? false)) {
      _cachedFlatRecords = [];
      return [];
    }
    // OWNERSHIP_FILTER: never GET all rows — only quoted user_id (@ARCHITECTURE.md §3).
    final where = _whereUserId;
    var list = await _getList(_recordsRecords, where, 1000);
    list = list.map(_flattenNocoRecord).toList();
    if (list.isEmpty) {
      _log('Records GET returned 0 rows for $where (no unfiltered fallback).');
    }
    final kept = <Map<String, dynamic>>[];
    for (final r in list) {
      final pk = nocoRecordsTablePk(r);
      if (pk.isEmpty) {
        _log(
            'GHOST_ROW_SKIPPED: record missing PK after flatten (keys=${r.keys.map((k) => k.toString()).take(12).join(",")})');
        continue;
      }
      kept.add(Map<String, dynamic>.from(r));
    }
    _cachedFlatRecords = kept;
    _pruneRecord404DeadletterUsingCache();
    return _cachedFlatRecords;
  }

  Future<List<Map<String, dynamic>>> getRecords() async {
    return _fetchRecordsIntoCache();
  }

  Future<void> _loadRulesFromNoco() async {
    try {
      final rows = await getCategories();
      final flat = rows
          .map((e) => _flattenNocoRecord(e, allowCategoryIdAsRowPk: true))
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
      _categoryController.add(List.from(_rules));
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
        } else if (envPk != null) {
          fields[_nocoEnvelopePkKey] = envPk;
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

  /// Segment for **REST row URL** `.../{tableUid}/{id}` — **wrapper Id integer only** (never business UUID).
  static String nocoRecordsTablePk(Map<String, dynamic> row) {
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
      if (nocoRecordsTablePk(r) == c) return r;
      if ((r['record_id'] ?? '').toString().trim() == c) return r;
    }
    return null;
  }

  /// When UI still holds a [fields.record_id] UUID but REST needs wrapper [id], map to [nocoRecordsTablePk].
  String? _resolveRecordsRestPathId(String candidate) {
    final c = candidate.trim();
    if (c.isEmpty) return null;
    for (final r in _cachedFlatRecords) {
      final rest = nocoRecordsTablePk(r);
      if (rest.isNotEmpty && rest == c) return rest;
      final biz = (r['record_id'] ?? '').toString().trim();
      if (biz.isNotEmpty && biz == c) return rest.isNotEmpty ? rest : null;
    }
    return null;
  }

  Future<String> _resolveRecordIdForRestUrl(String candidate) async {
    final c = candidate.trim();
    if (c.isEmpty) return c;
    try {
      await _fetchRecordsIntoCache();
    } catch (_) {}
    final resolved = _resolveRecordsRestPathId(c);
    if (resolved != null && resolved.isNotEmpty && resolved != c) {
      _log('REST_ID_RESOLVE: business/cache id "$c" -> Noco URL segment "$resolved"');
    }
    return (resolved != null && resolved.isNotEmpty) ? resolved : c;
  }

  /// Records PATCH: bulk-first then per-row URLs for one segment; **no** post-404 id re-query.
  Future<http.Response> _patchRecordsRowWith404Recovery({
    required String originalQueryId,
    required String restId,
    required Map<String, dynamic> fields,
  }) async {
    final rid = restId.trim();
    final oq = originalQueryId.trim();
    if (rid.isNotEmpty &&
        (_recordRestDefinitive404Keys.contains(rid) ||
            (oq.isNotEmpty && _recordRestDefinitive404Keys.contains(oq)))) {
      _log(
        'RECORDS_REST SKIP_PATCH: dead-letter 404 (no HTTP) rid=$rid tableUid=$_recordsTableUid',
      );
      _purgeGhostRecordById(rid.isNotEmpty ? rid : oq);
      return http.Response('', 404);
    }

    Future<http.Response> doPatchAllUrlsForSegment(
      String segment,
      Map<String, dynamic>? rowHint,
    ) async {
      final mergedRaw = Map<String, dynamic>.from(fields);
      mergedRaw['user_id'] = _pid;
      _mergeBusinessRecordIdIntoFields(
        mergedRaw,
        rowHint ?? _findCachedRecordRowByRestCandidate(segment),
      );
      final merged = _recordsPatchFieldsJsonStrings(
        _nocoFieldsForPatch(mergedRaw),
      );
      print('PATCHING DATA: records row restId=$segment fields=$merged');
      final parsed = int.tryParse(segment.trim());
      final bodies = <Map<String, dynamic>>[
        NocoRequest.single(fields: merged),
        if (parsed != null) NocoRequest.single(id: parsed, fields: merged),
      ];
      http.Response? last;
      // Prefer **bulk** PATCH first: many Noco v3 hosts 404 on `/records/{id}` but accept collection PATCH.
      // That avoids a dozen failed requests (and red browser console noise) before bulk runs.
      Object? bulkId;
      if (parsed != null) {
        bulkId = parsed;
      } else if (_isLikelyUuidOrLongPk(segment.trim())) {
        bulkId = segment.trim();
      }
      if (bulkId != null) {
        final payload = NocoRequest.bulk([
          NocoRequest(id: bulkId, fields: merged),
        ]);
        final bodyStr = jsonEncode(payload);
        _log(
          'RECORDS_REST PATCH_BULK_TRY tableUid=$_recordsTableUid id=$bulkId',
        );
        final resp =
            await _recordsBulkPatchHttpTry('patchRecordBulk', bodyStr);
        if (resp != null && resp.statusCode >= 200 && resp.statusCode < 300) {
          return resp;
        }
        last = resp;
      }
      // Fallback: single-row URLs (servers that only expose row PATCH).
      for (final url in _recordRowPatchUrlCandidates(segment)) {
        for (final body in bodies) {
          final resp = await http.patch(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode(body),
          );
          last = resp;
          if (resp.statusCode != 404) return resp;
        }
      }
      return last ?? http.Response('', 404);
    }

    final res = await doPatchAllUrlsForSegment(rid, null);
    if (res.statusCode == 404) {
      _log(
        'RECORDS_REST PATCH_404: no alternate-id retry (fix local cache / rest id) rid=$rid',
      );
    }
    return res;
  }

  /// Same routing as row PATCH: many v3 hosts **404** on `DELETE .../records/{id}` but accept **bulk** DELETE on the collection.
  Future<http.Response> _deleteRecordsRowWithFallback({
    required String originalQueryId,
    required String restId,
  }) async {
    final rid = restId.trim();
    if (rid.isEmpty) return http.Response('', 400);
    final oq = originalQueryId.trim();
    if (_recordRestDefinitive404Keys.contains(rid) ||
        (oq.isNotEmpty && _recordRestDefinitive404Keys.contains(oq))) {
      _log(
        'RECORDS_REST SKIP_DELETE: dead-letter 404 (no HTTP) rid=$rid tableUid=$_recordsTableUid',
      );
      _purgeGhostRecordById(rid.isNotEmpty ? rid : oq);
      return http.Response('', 404);
    }
    http.Response? last;

    Object? bulkId;
    final parsed = int.tryParse(rid);
    if (parsed != null) {
      bulkId = parsed;
    } else if (_isLikelyUuidOrLongPk(rid)) {
      bulkId = rid;
    }

    if (bulkId != null) {
      final delBody = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': bulkId},
      ]);
      for (final bulkUri in _recordsBulkPatchUrls) {
        _log(
          'RECORDS_REST DELETE_BULK_TRY tableUid=$_recordsTableUid uri=$bulkUri id=$bulkId',
        );
        final resp = await http.delete(
          Uri.parse(bulkUri),
          headers: _headers,
          body: delBody,
        );
        last = resp;
        if (resp.statusCode >= 200 && resp.statusCode < 300) return resp;
      }
    }

    for (final url in _recordRowPatchUrlCandidates(rid)) {
      final resp = await http.delete(Uri.parse(url), headers: _headers);
      last = resp;
      if (resp.statusCode != 404) return resp;
    }

    if (last?.statusCode == 404) {
      _log(
        'RECORDS_REST DELETE_404: no fresh-id requery (fix local rest id) rid=$rid',
      );
    }
    return last ?? http.Response('', 404);
  }

  /// Business key for plan rows: prefer **plan_id** (UUID); bulk PATCH outer `id` is [nocoRecordsTablePk] / [PlanningTask.id].
  static String nocoPlanRowPk(Map<String, dynamic> row) {
    for (final key in <String>['plan_id', 'Plan_id']) {
      final v = row[key];
      if (v == null) continue;
      final s = _sanitizePkString(v.toString());
      if (s != null && s.isNotEmpty) return s;
    }
    final env = _sanitizePkString(row[_nocoEnvelopePkKey]?.toString());
    if (env != null && env.isNotEmpty) return env;
    for (final key in <String>['id', 'Id', 'ID']) {
      final v = row[key];
      if (v == null) continue;
      final s = _sanitizePkString(v.toString());
      if (s != null && s.isNotEmpty) return s;
    }
    return '';
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
      final pk = nocoRecordsTablePk(r).trim();
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
    _timeUpdateController.add(null);
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

  /// Sacred Law scope: only rows whose [start_time] falls on **[getProjectedToday]** wall day.
  /// Avoids PATCHing dozens of legacy `running` ghosts from other days; see [_mergeSacredStaleOpenCandidates].
  bool _rowStartWallDayIsProjectedToday(Map<String, dynamic> r) {
    try {
      final stUtc = _parseDateTimeUtc(r['start_time']);
      if (stUtc == null) return false;
      final w = _profileWallFromUtc(stUtc);
      final t = getProjectedToday();
      return w.year == t.year && w.month == t.month && w.day == t.day;
    } catch (_) {
      return false;
    }
  }

  /// True when [start_time] wall day is **strictly before** [getProjectedToday] (multi-day open).
  bool _rowStartWallDayIsBeforeProjectedToday(Map<String, dynamic> r) {
    try {
      final stUtc = _parseDateTimeUtc(r['start_time']);
      if (stUtc == null) return false;
      final w = _profileWallFromUtc(stUtc);
      final t = getProjectedToday();
      final wd = DateTime(w.year, w.month, w.day);
      final td = DateTime(t.year, t.month, t.day);
      return wd.isBefore(td);
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
      final id = nocoRecordsTablePk(r);
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
      final id = nocoRecordsTablePk(r);
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
    final where =
        "(user_id,eq,'$_pid')~and(status,eq,running)";
    var list = await _getList(_recordsRecords, where, 500);
    if (list.isEmpty) {
      final whereUnquoted =
          '(user_id,eq,$_pid)~and(status,eq,running)';
      list = await _getList(_recordsRecords, whereUnquoted, 500);
    }
    return list.map(_flattenNocoRecord).toList();
  }

  /// ISO UTC for start of a calendar [dateKey] (`YYYY-MM-DD`) in profile wall-clock, then stored as UTC.
  String? _planStartUtcIsoFromDateKey(String dateKey) {
    try {
      if (dateKey.length < 10) return null;
      final y = int.parse(dateKey.substring(0, 4));
      final m = int.parse(dateKey.substring(5, 7));
      final d = int.parse(dateKey.substring(8, 10));
      final startWall = DateTime(y, m, d, 0, 0, 0);
      return wall_clock
          .wallClockToUtc(startWall, _settings.timezoneOffsetHours)
          .toIso8601String();
    } catch (_) {
      return null;
    }
  }

  static int _rowInt(dynamic v, [int d = 0]) {
    if (v == null) return d;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? d;
  }

  static int _stableIntFromString(String raw, [int fallback = 0]) {
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

  /// Noco wrapper **Id** (int) from create/PATCH response body — stored in [CategoryRule.nocoId] for URLs.
  static int? _parseNocoCategoryWrapperRowIdFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      int? fromMap(Map<String, dynamic> m) {
        for (final k in const ['id', 'Id', 'ID']) {
          final v = m[k];
          if (v == null) continue;
          final p = int.tryParse(v.toString().trim());
          if (p != null && p > 0) return p;
        }
        return null;
      }

      if (decoded is Map<String, dynamic>) {
        final top = fromMap(decoded);
        if (top != null) return top;
        final list = decoded['list'] ?? decoded['records'];
        if (list is List &&
            list.isNotEmpty &&
            list.first is Map<String, dynamic>) {
          return fromMap(Map<String, dynamic>.from(list.first as Map));
        }
      }
    } catch (_) {}
    return null;
  }

  /// Business key from PATCH/POST JSON: `fields.category_id`.
  static String? _parseCategoryFieldsCategoryIdFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      final fld = m['fields'] is Map
          ? Map<String, dynamic>.from(m['fields'] as Map)
          : m;
      final v = fld['category_id'] ?? fld['Category_id'];
      return _sanitizePkString(v?.toString());
    } catch (_) {}
    return null;
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
          : _stableIntFromString(
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
      final pidFlat = normalizeNocoLinkField(pidRaw) ?? pidRaw;
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
      final node = CategoryRule(
        id: nodeLocalId,
        name: _categoryDisplayNameFromRow(row),
        nocoId: internalRowStr.isNotEmpty ? internalRowStr : null,
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
      );
      all.add(node);
      if (internalRowStr.isNotEmpty) lookup[internalRowStr] = node;
      if (bizCategoryId.isNotEmpty) lookup[bizCategoryId] = node;
      final nk = node.normalizedId?.trim();
      if (nk != null && nk.isNotEmpty) lookup[nk] = node;
      lookup[nodeLocalId.toString()] = node;
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

  /// After Noco profile load: **device prefs win** for theme + timezone so a stale server row
  /// (e.g. default "New York" / `system`) cannot wipe what the user saved in-app (@DATA_MAP §profiles).
  void _mergeDeviceProfilePreferenceOverridesSync() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final tm = prefs.getString(_profileThemeModeKey)?.trim().toLowerCase();
      var next = _settings;
      if (tm == 'light' || tm == 'dark' || tm == 'system') {
        next = next.copyWith(themeMode: tm);
      }
      final tzLabel = prefs.getString(_profileTzLabelKey)?.trim();
      if (tzLabel != null && tzLabel.isNotEmpty) {
        final oh = prefs.getInt(_profileTzOffsetKey) ??
            _fixedOffsetHoursFromLabel(tzLabel);
        next = next.copyWith(
          preferredTimeZone: tzLabel,
          timezoneOffsetHours: oh,
        );
      }
      _settings = next;
    } catch (_) {}
  }

  Future<void> _loadSettingsFromNoco() async {
    try {
      final data = await getCurrentUserProfileMap();
      if (data.isEmpty) {
        throw _ProfileFetchFailedException(
          404,
          'Profile not found — cannot load timezone or user_id',
        );
      }
      final rowUid = data['user_id']?.toString().trim() ?? '';
      if (rowUid.isEmpty) {
        throw _ProfileFetchFailedException(
          422,
          'Profile row missing user_id',
        );
      }
      _log('Profile data loaded from NocoDB.');
      // Top-level integer PK from record (for user_id where clause).
      final rawId = data['id'];
      final intId = rawId == null ? null : _rowInt(rawId);
      if (intId != null && intId > 0) _cachedProfileIntId = intId;
      final uid = data['user_id']?.toString().trim();
      if (uid != null && uid.isNotEmpty) _cachedProfileUuid = uid;
      final raw = data['active_languages'];
      List<String>? activeLanguages;
      if (raw is List) {
        activeLanguages =
            raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        if (activeLanguages.isEmpty) activeLanguages = null;
      }
      final region = data['data_region'] as String?;
      if (region == 'russia' || region == 'global') _dataRegion = region!;
      final tzLabel =
          (data['preferred_timezone'] as String? ?? 'UTC').trim();
      final tzOffsetRaw = data['timezone_offset'];
      final tzOffset = tzOffsetRaw == null
          ? _fixedOffsetHoursFromLabel(tzLabel.isEmpty ? 'UTC' : tzLabel)
          : (tzOffsetRaw is int
              ? tzOffsetRaw
              : int.tryParse(tzOffsetRaw.toString()) ?? 0);
      final dc = data['default_category_id'];
      final rawTheme = (data['theme_mode'] as String?)?.trim().toLowerCase();
      String themeMode;
      if (rawTheme == 'light' || rawTheme == 'dark' || rawTheme == 'system') {
        themeMode = rawTheme!;
      } else {
        try {
          final prefs = _prefs ?? await SharedPreferences.getInstance();
          final cached = prefs.getString(_profileThemeModeKey)?.trim().toLowerCase();
          themeMode = (cached == 'light' || cached == 'dark' || cached == 'system')
              ? cached!
              : 'system';
        } catch (_) {
          themeMode = 'system';
        }
      }
      final dn = data['display_name'] as String?;
      _settings = UserSettings(
        userId: _pidInt,
        language: data['primary_language'] as String? ?? 'en',
        preferredTimeZone: tzLabel.isEmpty ? 'UTC' : tzLabel,
        timezoneOffsetHours: tzOffset,
        activeLanguages: activeLanguages,
        primaryLanguage: data['primary_language'] as String? ?? 'en',
        defaultCategoryId: dc == null ? null : _rowInt(dc),
        hasSeeded: data['has_seeded'] == true,
        dataRegion: region,
        biometricEnabled: data['biometric_enabled'] == true,
        themeMode: themeMode,
        displayName: dn != null && dn.trim().isNotEmpty ? dn.trim() : null,
      );
      _mergeDeviceProfilePreferenceOverridesSync();
      _settingsController.add(_settings);
    } on _ProfileFetchFailedException {
      rethrow;
    } catch (_) {
      _settings = UserSettings(userId: _pidInt);
      _mergeDeviceProfilePreferenceOverridesSync();
      _settingsController.add(_settings);
    }
  }

  static const List<String> _profileTimezoneOptions = [
    'UTC',
    'London',
    'Moscow',
    'Dubai',
    'New York',
  ];
  static List<String> get validTimezonesForProfile =>
      List.from(_profileTimezoneOptions);

  static String _normalizeTimezone(String timezone) {
    final t = timezone.trim();
    if (t.isEmpty) return 'UTC';
    switch (t) {
      case 'London':
      case 'London (UTC+0)':
        return 'UTC';
      case 'Moscow':
      case 'Moscow (UTC+3)':
      case 'Dubai':
        return 'GMT+3';
      case 'Dubai (UTC+4)':
        return 'Dubai';
      case 'New York':
      case 'New York (UTC-5)':
        return 'New York';
      default:
        if (t.contains('Moscow') || t.contains('UTC+3')) return 'GMT+3';
        if (t.contains('Dubai') || t.contains('UTC+4')) return 'Dubai';
        if (t.contains('New York') || t.contains('UTC-5')) return 'New York';
        if (t.contains('London') || t.contains('UTC+0')) return 'UTC';
        return t;
    }
  }

  static int _fixedOffsetHoursFromLabel(String timezone) {
    final tz = _normalizeTimezone(timezone);
    switch (tz) {
      case 'UTC':
        return 0;
      case 'GMT+3':
        return 3;
      case 'Dubai':
        return 4;
      case 'New York':
        return -5;
      default:
        return 0;
    }
  }

  static (DateTime, DateTime) utcRangeForDateInTimezone(
      DateTime selectedDate, String timezone) {
    final offset = _fixedOffsetHoursFromLabel(timezone);
    return wall_clock.utcWallClockDayBoundsUtc(
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
      offset,
      timezone,
    );
  }

  static (DateTime, DateTime) utcRangeForWallClockDate(
    DateTime wallClockDate,
    int offsetHours,
    String preferredTimeZone,
  ) {
    return wall_clock.utcWallClockDayBoundsUtc(
      wallClockDate,
      offsetHours,
      preferredTimeZone,
    );
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

  DateTime getProjectedToday() {
    final utc = DateTime.now().toUtc();
    final view = _profileWallFromUtc(utc);
    return DateTime(view.year, view.month, view.day);
  }

  DateTime applyUserOffset(DateTime utcDate) {
    return _profileWallFromUtc(utcDate);
  }

  DateTime displayTimeToUtc(DateTime displayNaive) {
    return _profileUtcFromWall(displayNaive);
  }

  String getProjectedTodayDateKey() {
    final t = getProjectedToday();
    return '${t.year}-${_two(t.month)}-${_two(t.day)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _dateKeyFromDate(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  /// UI-first: update state and clock immediately; then POST bulk upsert in background. Never revert on 400/404.
  Future<bool> saveSettings(UserSettings s) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    final recordId = _cachedProfileIntId ?? 1;
    if (recordId <= 0) return false;

    // 1. Immediate UI update — clock flips the moment the finger leaves the button.
    _settings = s.copyWith(userId: _pidInt);
    _settingsController.add(_settings);
    _timeUpdateController.add(null);

    // 2. Aggressive upsert: POST bulk via [NocoRequest] (`fields` envelope). Silent on 400/404.
    final nocoRequest = NocoRequest(
      id: recordId,
      fields: ProfileUpdate.fromSettings(s).toJson(),
    );
    try {
      final body = jsonEncode([nocoRequest.toJson()]);
      final baseUri = Uri.parse(baseUrl);
      final path = '${baseUri.path}/$_profilesRecords'.replaceAll('//', '/');
      final uri = baseUri.replace(path: path);
      _log('saveSettings payload prepared.');
      _log('saveSettings target URI prepared.');
      final res = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'xc-token': nocoXcToken,
        },
        body: body,
      );
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        _log('Timezone synced to server.');
        try {
          final prefs = _prefs ?? await SharedPreferences.getInstance();
          await prefs.setString(_profileThemeModeKey, s.themeMode);
          await prefs.setString(_profileTzLabelKey, s.preferredTimeZone);
          await prefs.setInt(_profileTzOffsetKey, s.timezoneOffsetHours);
        } catch (_) {}
        return true;
      }
      if (res.statusCode == 400 || res.statusCode == 404) {
        _log('SAVE_SETTINGS: server returned ${res.statusCode} — ${res.body}');
        return false;
      }
      return false;
    } catch (e, st) {
      _log('SAVE_SETTINGS: request failed — $e');
      _log(st);
      return false;
    }
  }

  Future<bool> updateTimeZone(String label) async {
    final ok = await saveSettings(_settings.copyWith(
        preferredTimeZone: label,
        timezoneOffsetHours: _fixedOffsetHoursFromLabel(label)));
    _timeUpdateController.add(null);
    return ok;
  }

  Future<bool> updateUserTimezone(double offsetHours) async {
    final ok = await saveSettings(_settings.copyWith(
        timezoneOffsetHours: offsetHours.round()));
    _timeUpdateController.add(null);
    return ok;
  }

  final Random _random = Random();
  int newId() => -DateTime.now().millisecondsSinceEpoch - _random.nextInt(9999);

  String _tasksKeyForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return 'tasks_${d.year}_${_two(d.month)}_${_two(d.day)}';
  }

  /// **Deprecated:** Full-tree category PATCH is disabled. Use [patchCategoryDelta], [updateCategory],
  /// [addNestedCategory], [updateCategoryParent], etc. — one network call per user intent.
  Future<void> persistRules() async {
    _log(
      'CATEGORY_FULL_SYNC_DISABLED: persistRules() is a no-op — use targeted category APIs (single id per PATCH).',
    );
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
        _timeUpdateController.add(null);
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
    int bestDepth = -1;
    int depthOf(CategoryRule target, List<CategoryRule> roots, int level) {
      if (level > 4) return -1;
      for (final r in roots) {
        if (r.id == target.id) return level;
        final d = depthOf(target, r.children ?? [], level + 1);
        if (d >= 0) return d;
      }
      return -1;
    }

    for (final root in _rules) {
      final m = root.findDeepestMatch(title);
      if (m != null) {
        final d = depthOf(m, _rules, 0);
        if (d >= bestDepth) {
          best = m;
          bestDepth = d;
        }
      }
    }
    return best;
  }

  CategoryRule? identifyCategory(String input) => findDeepestMatchForTitle(input);

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

  /// Noco **system** `Id` (integer) for category **bulk** envelope `id` — from [CategoryRule.nocoId] only.
  /// No fallback from local display id (may be a hash). Missing ⇒ sync / load bug; do not call REST.
  int? _categoryNocoSystemIdStrict(CategoryRule? rule) {
    if (rule == null) return null;
    if (rule.id == -1) return null;
    final p = int.tryParse((rule.nocoId ?? '').trim());
    if (p != null && p > 0) return p;
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

  String? _parentCategoryIdStringForApi(int? parentLocalId) {
    if (parentLocalId == null) return null;
    return _categoryStringPkForApi(getCategoryRuleById(parentLocalId));
  }

  /// **Bulk-only** collection URL `@DATA_MAP` table `mhg7mv6dfsgq9i0/records` — no row segment.
  Uri get _categoryBulkCollectionUri => Uri.parse('$baseUrl/$_categoriesRecords');

  /// Strip system-managed / read-only keys from Noco `fields` for **every** table (@DATA_MAP).
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

  /// @DATA_MAP `records`: **checklist** is stored as JSON **String** (LongText).
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

  /// `PATCH` body: `[{"id": <int>, "fields": {...}}]` (@DATA_MAP §2 bulk mandate).
  /// Verbose request/response logging happens in [_categoryBulkPatchHttp] (response is unavailable here).
  String _categoryBulkPatchJson(int systemId, Map<String, dynamic> fields) => jsonEncode([
        NocoRequest(
          id: systemId,
          fields: _nocoFieldsForPatch(Map<String, dynamic>.from(fields)),
        ).toJson(),
      ]);

  /// Single HTTP `PATCH` with many rows: `[{"id":7,"fields":{...}},{"id":32,"fields":{...}}]`.
  String _categoryBulkPatchJsonMany(List<NocoRequest> items) {
    final cleaned = items
        .map(
          (e) => NocoRequest(
            id: e.id,
            fields: _nocoFieldsForPatch(Map<String, dynamic>.from(e.fields)),
          ),
        )
        .toList();
    return jsonEncode(NocoRequest.bulk(cleaned));
  }

  Uri get _plansBulkCollectionUri => Uri.parse('$baseUrl/$_plansRecords');

  Future<http.Response> _plansBulkPatchHttp(String contextLabel, String bodyJson) async {
    print('PATCHING BODY [$contextLabel]: $bodyJson');
    _log('PLANS_PATCH_HTTP $contextLabel uri=$_plansBulkCollectionUri');
    final res = await http.patch(
      _plansBulkCollectionUri,
      headers: _headers,
      body: bodyJson,
    );
    print('RESPONSE STATUS [$contextLabel]: ${res.statusCode}');
    print('RESPONSE BODY [$contextLabel]: ${res.body}');
    _log(
      'PLANS_PATCH_RESPONSE $contextLabel status=${res.statusCode} body=${res.body}',
    );
    return res;
  }

  Future<http.Response> _plansBulkDeleteHttp(
    String contextLabel,
    String bodyJson,
  ) async {
    print('PLANS DELETE BODY [$contextLabel]: $bodyJson');
    _log('PLANS_DELETE_HTTP $contextLabel uri=$_plansBulkCollectionUri');
    final res = await http.delete(
      _plansBulkCollectionUri,
      headers: _headers,
      body: bodyJson,
    );
    print(
      'PLANS DELETE RESPONSE [$contextLabel]: ${res.statusCode} ${res.body}',
    );
    _log(
      'PLANS_DELETE_RESPONSE $contextLabel status=${res.statusCode} body=${res.body}',
    );
    return res;
  }

  /// Records table: collection bulk PATCH with verbose logging (mirrors [_categoryBulkPatchHttp]).
  Future<http.Response?> _recordsBulkPatchHttpTry(
    String contextLabel,
    String bodyJson,
  ) async {
    print('PATCHING BODY [$contextLabel]: $bodyJson');
    http.Response? last;
    for (final bulkUri in _recordsBulkPatchUrls) {
      _log('RECORDS_BULK_PATCH $contextLabel uri=$bulkUri');
      final res = await http.patch(
        Uri.parse(bulkUri),
        headers: _headers,
        body: bodyJson,
      );
      last = res;
      print('RESPONSE STATUS [$contextLabel]: ${res.statusCode}');
      print('RESPONSE BODY [$contextLabel]: ${res.body}');
      _log(
        'RECORDS_PATCH_RESPONSE $contextLabel status=${res.statusCode} body=${res.body}',
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res;
      }
    }
    return last;
  }

  /// Awaited category bulk `PATCH` with mandatory console + brain logs of status and body.
  Future<http.Response> _categoryBulkPatchHttp(String contextLabel, String bodyJson) async {
    print('PATCHING BODY [$contextLabel]: $bodyJson');
    _log('CATEGORY_PATCH_HTTP $contextLabel uri=$_categoryBulkCollectionUri');
    final res = await http.patch(
      _categoryBulkCollectionUri,
      headers: _headers,
      body: bodyJson,
    );
    print('RESPONSE STATUS [$contextLabel]: ${res.statusCode}');
    print('RESPONSE BODY [$contextLabel]: ${res.body}');
    _log(
      'CATEGORY_PATCH_RESPONSE $contextLabel status=${res.statusCode} body=${res.body}',
    );
    return res;
  }

  /// Unique string PK for new category rows ([fields.category_id]).
  String _newCategoryIdString() => _newClientRecordUuid();

  /// Resolves a non-empty [category_id] before any category **POST**. Uses a sanitized
  /// [CategoryRule.normalizedId] when valid; otherwise generates a client UUID. Returns
  /// **null** only if no safe id can be produced — caller must **not** call the API.
  String? _categoryIdRequiredForCreate(CategoryRule child) {
    var candidate = _sanitizePkString(child.normalizedId);
    candidate ??= _newCategoryIdString();
    candidate = _sanitizePkString(candidate);
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    return candidate;
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

  Color getCategoryColor(int categoryId) {
    return getCategoryRuleById(categoryId)?.colorOrDefault ?? Colors.grey;
  }

  int? getCategoryIdByParentAndTag(int? parentId, String tag) {
    final children = getChildrenOf(parentId);
    final t = tag.trim().toLowerCase();
    for (final c in children) {
      if (c.name.trim().toLowerCase() == t) return c.id;
    }
    return null;
  }

  bool siblingHasTag(int? parentId, String tag, {int? excludeId}) {
    final children = getChildrenOf(parentId);
    final t = tag.trim().toLowerCase();
    for (final c in children) {
      if (excludeId != null && c.id == excludeId) continue;
      if (c.name.trim().toLowerCase() == t) return true;
    }
    return false;
  }

  /// **PATCH** bulk-only: collection URL + `[{"id": <int>, "fields": {...}}]`.
  /// [errorDetail] is the server body (or diagnostic) when [ok] is false.
  Future<({bool ok, String? errorDetail})> updateCategory(
    int targetId,
    String newName,
  ) async {
    if (!_isInitialized || _userIdForWhere == 0) {
      return (ok: false, errorDetail: 'not_initialized');
    }
    if (siblingHasTag(getParentId(targetId), newName, excludeId: targetId)) {
      return (ok: false, errorDetail: null);
    }
    final existing = getCategoryRuleById(targetId);
    if (existing == null) {
      return (ok: false, errorDetail: 'category_not_found');
    }

    try {
      final sysId = _categoryNocoSystemIdStrict(existing);
      if (sysId == null) {
        _log(
          'UPDATE_CATEGORY: refuse PATCH — no Noco system Id (sync _loadRulesFromNoco)',
        );
        return (ok: false, errorDetail: 'missing_noco_row_id');
      }
      final biz = _categoryStringPkForApi(existing);
      _log(
        'CATEGORY_PATCH_SINGLE rename uri=$_categoryBulkCollectionUri id=$sysId (bulk array len=1)',
      );
      final bodyJson = _categoryBulkPatchJson(
        sysId,
        <String, dynamic>{
          'user_id': _pid,
          'name': newName,
          'normalized_id': _slugifyCategoryDisplayName(newName),
          'category_id': ?biz,
          'order': existing.order,
        },
      );
      final res = await _categoryBulkPatchHttp('updateCategory', bodyJson);
      if (res.statusCode == 404) {
        _log('UPDATE_CATEGORY: server 404 — ${res.body}');
        _emitCategorySyncNotice('category_sync_not_found');
        return (ok: false, errorDetail: res.body);
      }
      if (res.statusCode == 400) {
        _log('UPDATE_CATEGORY: server 400 — ${res.body}');
        return (ok: false, errorDetail: res.body);
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _reconcileCategoryNodeAfterWrite(
          previousId: targetId,
          previousRule: existing,
          newTag: newName,
          res: res,
        );
        await _loadRulesFromNoco();
        return (ok: true, errorDetail: null);
      }
      return (ok: false, errorDetail: res.body);
    } catch (e) {
      _log('UPDATE_CATEGORY: $e');
      return (ok: false, errorDetail: e.toString());
    }
  }

  /// One category row: bulk collection URL with **exactly one** `[{"id":…,"fields":…}]` element.
  Future<({bool ok, String? errorDetail})> patchCategoryDelta(
    int targetId,
    Map<String, dynamic> fields,
  ) async {
    if (!_isInitialized || _userIdForWhere == 0) {
      return (ok: false, errorDetail: 'not_initialized');
    }
    if (fields.isEmpty) {
      return (ok: true, errorDetail: null);
    }
    final existing = getCategoryRuleById(targetId);
    if (existing == null) {
      return (ok: false, errorDetail: 'category_not_found');
    }
    final sysId = _categoryNocoSystemIdStrict(existing);
    if (sysId == null) {
      return (ok: false, errorDetail: 'missing_noco_row_id');
    }
    final biz = _categoryStringPkForApi(existing);
    final mergedFields = Map<String, dynamic>.from(fields);
    if (!mergedFields.containsKey('order')) {
      mergedFields['order'] = existing.order;
    }
    try {
      final prepared = _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
        'user_id': _pid,
        'category_id': ?biz,
        ...mergedFields,
      });
      final merged = _nocoFieldsForPatch(prepared);
      if (merged.containsKey('localized_names')) {
        final s = merged['localized_names']?.toString() ?? '';
        _log(
          'CATEGORY_PATCH_DELTA localized_names json (${s.length} chars): ${s.length > 160 ? '${s.substring(0, 160)}…' : s}',
        );
      }
      if (merged.containsKey('keywords')) {
        final s = merged['keywords']?.toString() ?? '';
        _log(
          'CATEGORY_PATCH_DELTA keywords json (${s.length} chars): ${s.length > 160 ? '${s.substring(0, 160)}…' : s}',
        );
      }
      _log('CATEGORY_PATCH_SINGLE uri=$_categoryBulkCollectionUri id=$sysId (bulk array len=1)');
      final bodyJson = _categoryBulkPatchJson(sysId, merged);
      print('PATCHING DATA: category patchCategoryDelta id=$targetId body=$bodyJson');
      final res = await _categoryBulkPatchHttp('patchCategoryDelta', bodyJson);
      if (res.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
        return (ok: false, errorDetail: res.body);
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _loadRulesFromNoco();
        return (ok: true, errorDetail: null);
      }
      return (ok: false, errorDetail: res.body);
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

  void _replaceCategoryNodeById(int oldId, CategoryRule replacement) {
    bool replaceIn(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        if (rules[i].id == oldId) {
          rules[i] = replacement;
          return true;
        }
        final ch = rules[i].children;
        if (ch != null && replaceIn(ch)) return true;
      }
      return false;
    }

    replaceIn(_rules);
  }

  /// Locks in server PK + local display id from PATCH/POST body when Noco returns it.
  void _reconcileCategoryNodeAfterWrite({
    required int previousId,
    required CategoryRule previousRule,
    required String newTag,
    required http.Response res,
  }) {
    try {
      final bizFromBody = _parseCategoryFieldsCategoryIdFromBody(res.body);
      var internalRow = _parseNocoCategoryWrapperRowIdFromBody(res.body);
      String? nocoStr;
      if (internalRow != null && internalRow > 0) {
        nocoStr = internalRow.toString();
      } else {
        final fromPrev = _sanitizePkString(previousRule.nocoId);
        final parsedPrev = int.tryParse(fromPrev ?? '');
        if (parsedPrev != null && parsedPrev > 0) {
          internalRow = parsedPrev;
          nocoStr = parsedPrev.toString();
        }
      }
      if (nocoStr == null || nocoStr.isEmpty) {
        _updateCategoryTagInRules(previousId, newTag);
        return;
      }
      final norm = (bizFromBody != null && bizFromBody.isNotEmpty)
          ? bizFromBody
          : previousRule.normalizedId;
      final newLocalId = (internalRow != null && internalRow > 0)
          ? internalRow
          : int.tryParse(nocoStr) ??
              _categoryDisplayIdFromServerPk(nocoStr, tagFallback: newTag);
      _replaceCategoryNodeById(
        previousId,
        CategoryRule(
          id: newLocalId,
          name: newTag,
          nocoId: nocoStr,
          normalizedId: norm,
          children: previousRule.children,
          colorValue: previousRule.colorValue,
          iconCodePoint: previousRule.iconCodePoint,
          keywords: previousRule.keywords,
          localizedNames: previousRule.localizedNames,
          order: previousRule.order,
        ),
      );
    } catch (_) {
      _updateCategoryTagInRules(previousId, newTag);
    }
  }

  void _updateCategoryTagInRules(int id, String newTag) {
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == id) {
          r.name = newTag;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }
    visit(_rules);
  }

  /// UI-first: move category in _rules, push; then **PATCH** parent_id (same row), not bulk POST create.
  Future<bool> updateCategoryParent(int categoryId, int? newParentId) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;

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
      final sysId = _categoryNocoSystemIdStrict(existing);
      if (sysId == null) {
        _log(
          'UPDATE_CATEGORY_PARENT: no system Id on row — reload rules localId=$categoryId',
        );
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
        return false;
      }
      final newParentKey = newParentId == null
          ? null
          : _parentCategoryIdStringForApi(newParentId);
      if (newParentId != null &&
          (newParentKey == null || newParentKey.isEmpty)) {
        _log(
          'UPDATE_CATEGORY_PARENT: parent has no category_id string parentLocal=$newParentId',
        );
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
        return false;
      }
      final rowBiz = _categoryStringPkForApi(existing);
      final movedOrder = existing?.order ?? 0;
      _log(
        'CATEGORY_PATCH_SINGLE parent uri=$_categoryBulkCollectionUri id=$sysId (bulk array len=1)',
      );
      final bodyJson = _categoryBulkPatchJson(
        sysId,
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pid,
          'category_id': ?rowBiz,
          'parent_id': newParentKey,
          'order': movedOrder,
        }),
      );
      final res = await _categoryBulkPatchHttp('updateCategoryParent', bodyJson);
      if (res.statusCode == 400) {
        _log('UPDATE_CATEGORY_PARENT: server ${res.statusCode} — ${res.body}');
      }
      if (res.statusCode == 404) {
        _log('UPDATE_CATEGORY_PARENT: server 404 — ${res.body}');
        _emitCategorySyncNotice('category_sync_not_found');
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
        return false;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _persistCategoryOrdersBulkForce(
          List<CategoryRule>.from(getChildrenOf(oldParentId)),
          contextLabel: 'parentMoveOldSiblings',
        );
        await _persistCategoryOrdersBulkForce(
          List<CategoryRule>.from(getChildrenOf(newParentId)),
          contextLabel: 'parentMoveNewSiblings',
        );
        if (existing != null) {
          _reconcileCategoryNodeAfterWrite(
            previousId: categoryId,
            previousRule: existing,
            newTag: existing.name,
            res: res,
          );
        }
        await _loadRulesFromNoco();
        return true;
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

  /// **DELETE** bulk-only: collection URL + `[{"id": <int>}]`. Local [_rules] after **2xx** only.
  Future<bool> deleteCategory(int id) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;

    final rule = getCategoryRuleById(id);
    if (rule == null || rule.id == -1) {
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    final sysId = _categoryNocoSystemIdStrict(rule);
    if (sysId == null) {
      _log(
        'DELETE_CATEGORY: refuse — missing Noco system Id (nocoId=${rule.nocoId})',
      );
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    try {
      final body = jsonEncode([
        <String, dynamic>{'id': sysId},
      ]);
      _log(
        'CATEGORY_BULK_DELETE uri=$_categoryBulkCollectionUri body=$body',
      );
      final res = await http.delete(
        _categoryBulkCollectionUri,
        headers: _headers,
        body: body,
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _removeCategoryFromRules(id);
        _categoryController.add(List.from(_rules));
        return true;
      }
      if (res.statusCode == 404) {
        _log(
          'DELETE_CATEGORY: 404 — ${res.body} url=${res.request?.url}',
        );
        _emitCategorySyncNotice('category_sync_not_found');
      } else if (res.statusCode == 400) {
        _log(
          'DELETE_CATEGORY: server ${res.statusCode} — ${res.body} url=${res.request?.url}',
        );
      } else {
        _log(
          'DELETE_CATEGORY: server ${res.statusCode} — ${res.body} url=${res.request?.url}',
        );
      }
      return false;
    } catch (e) {
      _log('DELETE_CATEGORY: $e');
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
      return _stableIntFromString(tagFallback.trim(), 1);
    }
    final asInt = _rowInt(trimmed);
    if (asInt != 0) return asInt;
    final h = _stableIntFromString(trimmed, 0);
    if (h != 0) return h;
    return _stableIntFromString(tagFallback.trim(), 1);
  }

  /// After POST creates a category, map Noco's returned wrapper **Id** onto [CategoryRule.nocoId]
  /// (required for `.../records/{Id}`); [normalizedId] holds business [category_id].
  void _applyCategoryCreateResponseToPlaceholder({
    required int? parentId,
    required String displayName,
    required http.Response res,
  }) {
    try {
      var wrapperInt = _parseNocoCategoryWrapperRowIdFromBody(res.body);
      String? nocoStr;
      if (wrapperInt != null && wrapperInt > 0) {
        nocoStr = wrapperInt.toString();
      } else {
        final fromBody =
            _sanitizePkString(_recordIdFromNocoCreateResponseBody(res.body));
        final fromLoc = _recordIdFromResponseLocation(res);
        String? pick = fromBody;
        if (fromBody != null &&
            fromLoc != null &&
            fromBody.isNotEmpty &&
            fromLoc.isNotEmpty &&
            fromBody != fromLoc) {
          if (_isLikelyUuidOrLongPk(fromBody) &&
              _isSmallIntegerString(fromLoc)) {
            pick = fromLoc;
          } else if (_isLikelyUuidOrLongPk(fromLoc) &&
              _isSmallIntegerString(fromBody)) {
            pick = fromBody;
          }
        }
        if (pick != null &&
            !_isSmallIntegerString(pick) &&
            fromLoc != null &&
            _isSmallIntegerString(fromLoc)) {
          pick = fromLoc;
        }
        pick ??= fromLoc;
        final sanitized = _sanitizePkString(pick);
        if (sanitized != null && _isSmallIntegerString(sanitized)) {
          nocoStr = sanitized;
          wrapperInt = int.tryParse(sanitized);
        }
      }
      if (nocoStr == null || nocoStr.isEmpty) return;
      final wantTag = displayName.trim();
      final biz = _parseCategoryFieldsCategoryIdFromBody(res.body);
      final newId = (wrapperInt != null && wrapperInt > 0)
          ? wrapperInt
          : int.tryParse(nocoStr) ??
              _categoryDisplayIdFromServerPk(nocoStr, tagFallback: wantTag);
      CategoryRule upgraded(CategoryRule old) {
        return CategoryRule(
          id: newId,
          name: old.name,
          nocoId: nocoStr,
          normalizedId:
              (biz != null && biz.isNotEmpty) ? biz : old.normalizedId,
          children: old.children,
          colorValue: old.colorValue,
          iconCodePoint: old.iconCodePoint,
          keywords: old.keywords,
          localizedNames: old.localizedNames,
          order: old.order,
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

  /// UI-first: add child to _rules (temp id -1), push; then POST. On success refresh in background.
  Future<bool> addNestedCategory(int? parentId, CategoryRule child) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;

    final parentKey = _parentCategoryIdStringForApi(parentId);
    if (parentId != null && (parentKey == null || parentKey.isEmpty)) {
      _log('ADD_CATEGORY: parent missing category_id localParent=$parentId');
      return false;
    }

    final categoryId = _categoryIdRequiredForCreate(child);
    if (categoryId == null) {
      _log(
        'ADD_CATEGORY: POST blocked — category_id null/empty/invalid after client generation',
      );
      return false;
    }

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

    try {
      final fieldsRaw = <String, dynamic>{
        'user_id': _pid,
        'category_id': categoryId,
        'name': child.name,
        if (parentKey != null && parentKey.isNotEmpty) 'parent_id': parentKey,
        'color_value': child.colorValue ?? 0,
        'icon_code_point': child.iconCodePoint ?? 0,
        'order': nextOrder,
        if (child.keywords != null) 'keywords': child.keywords,
        if (child.localizedNames != null) 'localized_names': child.localizedNames,
        'normalized_id': _sanitizePkString(child.normalizedId) ?? categoryId,
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
      final res = await http.post(
        Uri.parse('$baseUrl/$_categoriesRecords'),
        headers: _headers,
        body: jsonEncode(NocoRequest.single(fields: fields)),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _applyCategoryCreateResponseToPlaceholder(
          parentId: parentId,
          displayName: child.name,
          res: res,
        );
        _categoryController.add(List.from(_rules));
        unawaited(_loadRulesFromNoco());
        return true;
      }
      if (res.statusCode == 400 || res.statusCode == 404) {
        _log('ADD_CATEGORY: server ${res.statusCode} — ${res.body}');
      }
    } catch (e) {
      _log('ADD_CATEGORY: $e');
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
      final sysId = _categoryNocoSystemIdStrict(rule);
      if (sysId == null) {
        _log(
          'UPDATE_CATEGORY_KEYWORDS: skip — no Noco system Id on rule localId=$categoryId',
        );
        return;
      }
      final biz = _categoryStringPkForApi(rule);
      _log(
        'CATEGORY_PATCH_SINGLE keywords uri=$_categoryBulkCollectionUri id=$sysId (bulk array len=1)',
      );
      final bodyJson = _categoryBulkPatchJson(
        sysId,
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pid,
          'category_id': ?biz,
          'keywords': keywords,
          'order': rule.order,
        }),
      );
      print('PATCHING DATA: category updateCategoryKeywords id=$categoryId body=$bodyJson');
      final res = await _categoryBulkPatchHttp('updateCategoryKeywords', bodyJson);
      if (res.statusCode == 404) {
        _log('UPDATE_CATEGORY_KEYWORDS: 404 — ${res.body}');
        _emitCategorySyncNotice('category_sync_not_found');
        return;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _loadRulesFromNoco();
      } else {
        _log(
          'UPDATE_CATEGORY_KEYWORDS: failed status=${res.statusCode} — ${res.body}',
        );
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

  Future<void> addLanguageToAllCategories(String langCode) async {
    Future<void> walk(CategoryRule r) async {
      final kw = Map<String, List<String>>.from(r.keywords ?? {});
      kw.putIfAbsent(langCode, () => [r.name]);
      await updateCategoryKeywords(r.id, kw);
      for (final c in r.children ?? []) {
        await walk(c);
      }
    }

    for (final root in _rules) {
      await walk(root);
    }
    await _loadRulesFromNoco();
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
    if (v is DateTime) return v.isUtc ? v : DateTime.utc(v.year, v.month, v.day, v.hour, v.minute, v.second, v.millisecond, v.microsecond);
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

  /// Preview for CRITICAL logs (avoid dumping huge bodies).
  static String _httpBodyPreview(String body, [int max = 500]) {
    if (body.length <= max) return body;
    return '${body.substring(0, max)}...';
  }

  /// JSON keys that may hold the real row PK. Never use `order`, `nc_order`, row index, or category_id.
  static const List<String> _nocoRowPkJsonKeys = <String>[
    'record_id',
    'Record_id',
    'recordId',
    'RecordId',
    'Id',
    'id',
    'ID',
  ];

  static String? _pickNocoPkFromMap(Map<String, dynamic> m) {
    for (final k in _nocoRowPkJsonKeys) {
      final v = m[k];
      if (v == null) continue;
      final s = _sanitizePkString(v.toString());
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  /// Deep-walk NocoDB v3 create/read JSON for a row PK (never uses order / category_id).
  static String? _walkNocoCreateResponseForPk(dynamic node, [int depth = 0]) {
    if (depth > 10 || node == null) return null;
    if (node is Map) {
      final m = Map<String, dynamic>.from(node);
      final direct = _pickNocoPkFromMap(m);
      if (direct != null) return direct;
      if (m['fields'] is Map) {
        final fm = Map<String, dynamic>.from(m['fields'] as Map);
        final inFields = _pickNocoPkFromMap(fm);
        if (inFields != null) return inFields;
      }
      for (final k in <String>['record', 'data', 'result', 'row']) {
        final inner = m[k];
        final w = _walkNocoCreateResponseForPk(inner, depth + 1);
        if (w != null) return w;
      }
      for (final k in <String>['records', 'list']) {
        final inner = m[k];
        if (inner is List) {
          for (final item in inner) {
            final w = _walkNocoCreateResponseForPk(item, depth + 1);
            if (w != null) return w;
          }
        }
      }
      return null;
    }
    if (node is List && node.isNotEmpty) {
      return _walkNocoCreateResponseForPk(node.first, depth + 1);
    }
    return null;
  }

  static String? _recordIdFromNocoCreateResponseBody(String body) {
    try {
      final j = jsonDecode(body);
      return _walkNocoCreateResponseForPk(j);
    } catch (_) {
      return null;
    }
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

  /// Prefer cache over POST when POST returns business UUID but cache has the **system** row id.
  static bool _preferCachePkOverPostParse(String? postId, String cacheId) {
    final p = _sanitizePkString(postId) ?? '';
    final c = _sanitizePkString(cacheId) ?? '';
    if (c.isEmpty) return false;
    if (p.isEmpty) return false;
    if (_isLikelyUuidOrLongPk(p) && _isSmallIntegerString(c)) return true;
    return _isSmallIntegerString(p) && _isLikelyUuidOrLongPk(c);
  }

  static bool _hasTrustedEnvelopePk(Map<String, dynamic> row) {
    return _sanitizePkString(row[_nocoEnvelopePkKey]?.toString()) != null;
  }

  /// Without POST id: trust cache PK when row has system id, envelope, or non–small-int PK.
  static bool _shouldTrustCachePkWithoutPost(
      String? cachePk, Map<String, dynamic>? row) {
    final pk = _sanitizePkString(cachePk);
    if (pk == null || pk.isEmpty || row == null) return false;
    if (row[_nocoSystemRowIdKey] != null) return true;
    if (_hasTrustedEnvelopePk(row)) return true;
    if (_isLikelyUuidOrLongPk(pk)) return true;
    if (!_isSmallIntegerString(pk)) return true;
    return false;
  }

  /// After POST, find the created row in [_cachedFlatRecords] (call [_fetchRecordsIntoCache] first).
  Map<String, dynamic>? _findRecordRowInCache({
    required String title,
    required String startIsoUtc,
    String? endIsoUtc,
  }) {
    try {
      final targetStart = _parseDateTimeUtc(startIsoUtc);
      final targetEnd =
          endIsoUtc != null ? _parseDateTimeUtc(endIsoUtc) : null;
      final pidStr = _pid.toString().trim();
      final wantTitle = title.trim();
      Map<String, dynamic>? bestRow;
      int? bestScore;
      for (final r in _cachedFlatRecords) {
        if (r['user_id']?.toString().trim() != pidStr) continue;
        if ((r['title'] ?? '').toString().trim() != wantTitle) continue;
        if (targetEnd != null) {
          final te = targetEnd;
          final en = _parseDateTimeUtc(r['end_time']);
          if (en == null ||
              en.difference(te).abs().inSeconds > 25) {
            continue;
          }
        }
        final st = _parseDateTimeUtc(r['start_time']);
        var d = 0;
        if (targetStart != null && st != null) {
          d = st.difference(targetStart).abs().inSeconds;
          if (d > 20) continue;
        }
        final pk = nocoRecordsTablePk(r);
        if (pk.isEmpty) continue;
        var score = d;
        if (r[_nocoSystemRowIdKey] == null) {
          score += 3000;
        }
        if (!_hasTrustedEnvelopePk(r)) {
          score += 5000;
        }
        if (_isSmallIntegerString(pk) &&
            r[_nocoSystemRowIdKey] == null &&
            !_hasTrustedEnvelopePk(r)) {
          score += 10000;
        }
        if (bestScore == null || score < bestScore) {
          bestScore = score;
          bestRow = r;
        }
      }
      return bestRow;
    } catch (_) {
      return null;
    }
  }

  /// Refreshes cache, resolves PK from body + optional cache repair; logs CRITICAL if still missing.
  Future<String?> _finalizeRecordCreateHandshake({
    required http.Response res,
    required String titleForMatch,
    required String startIsoUtc,
    String? endIsoUtc,
  }) async {
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final fromBody =
        _sanitizePkString(_recordIdFromNocoCreateResponseBody(res.body));
    final fromLoc = _recordIdFromResponseLocation(res);
    String? fromPost = fromBody ?? fromLoc;
    if (fromBody != null &&
        fromLoc != null &&
        fromBody.isNotEmpty &&
        fromLoc.isNotEmpty &&
        fromBody != fromLoc) {
      // Noco v3: REST `/records/{id}` uses **system integer**; body may return business UUID.
      if (_isLikelyUuidOrLongPk(fromBody) && _isSmallIntegerString(fromLoc)) {
        fromPost = fromLoc;
      } else if (_isLikelyUuidOrLongPk(fromLoc) &&
          _isSmallIntegerString(fromBody)) {
        fromPost = fromBody;
      } else {
        fromPost = fromBody;
      }
    }
    await _fetchRecordsIntoCache();
    final matchRow = _findRecordRowInCache(
      title: titleForMatch,
      startIsoUtc: startIsoUtc,
      endIsoUtc: endIsoUtc,
    );
    final cacheId =
        matchRow == null ? null : nocoRecordsTablePk(matchRow);

    String? newId;
    if (fromPost != null && fromPost.isNotEmpty) {
      if (_preferCachePkOverPostParse(fromPost, cacheId ?? '')) {
        _log(
            'PK_REPAIR: POST parsed id="$fromPost" ignored; using cache PK="$cacheId"');
        newId = cacheId;
      } else {
        newId = fromPost;
      }
    } else {
      if (_shouldTrustCachePkWithoutPost(cacheId, matchRow)) {
        newId = cacheId;
      } else {
        _log(
            'CRITICAL: No POST id and cache PK is untrusted (need wrapper id or non–small-int). '
            'cachePk=$cacheId envelope=${matchRow?[_nocoEnvelopePkKey]} body=${_httpBodyPreview(res.body)}');
        newId = null;
      }
    }

    if (newId == null || newId.isEmpty) {
      _log(
          'CRITICAL: Server returned ${res.statusCode} but no usable ID. body=${_httpBodyPreview(res.body)}');
    } else {
      _log('WRITE_RECORD_PK_OK: server_id=$newId');
    }
    _timeUpdateController.add(null);
    return (newId != null && newId.isNotEmpty) ? newId : null;
  }

  /// True when [parent_id] points to a parent row (int PK, UUID string, or Link object).
  bool _rowHasNonEmptyParent(dynamic parentField) {
    if (parentField == null) return false;
    final flat = normalizeNocoLinkField(parentField);
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
        final noco = (r.nocoId ?? '').trim().toLowerCase();
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

  /// Maps NocoDB `category_id` (number, string slug, UUID, or nested link / list) to [CategoryRule.id].
  int? categoryIdFromNocoRecordRow(Map<String, dynamic> row) {
    try {
      dynamic v =
          row['category_id'] ?? row['Category_id'] ?? row['categoryId'];
      v = normalizeNocoLinkField(v);
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final asInt = _rowInt(v);
      if (asInt != 0) return asInt;
      return findCategoryIdForStoredCategoryKey(s);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _rowToRecordMap(Map<String, dynamic> row) {
    final start = _parseDateTimeUtc(row['start_time']);
    final end = _parseDateTimeUtc(row['end_time']);
    final pidRaw = row['parent_id'];
    final pidFlat = normalizeNocoLinkField(pidRaw) ?? pidRaw;
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
        normalizeNocoLinkField(row['category_id'] ?? row['Category_id'] ?? row['categoryId']);
    final catInt = categoryIdFromNocoRecordRow(row);
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
    final restPk = nocoRecordsTablePk(row);
    final bizRid = (row['record_id'] ?? '').toString().trim();
    final sysObj = row[_nocoSystemRowIdKey];
    final int? sysInt =
        sysObj is int ? sysObj : int.tryParse(restPk.isNotEmpty ? restPk : '');
    // Wall-clock calendar day (profile offset), not raw UTC YYYY-MM-DD prefix.
    String calendarDayStr;
    if (start != null) {
      final w = _profileWallFromUtc(start.toUtc());
      calendarDayStr = '${w.year}-${_two(w.month)}-${_two(w.day)}';
    } else {
      calendarDayStr = _utcDatePrefixFromRaw(row['start_time']) ?? '';
    }
    return <String, dynamic>{
      'id': restPk,
      'nocoRestPathId': restPk,
      'nocoSystemId': ?sysInt,
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
      'calendarDayStr': calendarDayStr,
      'tags': row['tags'] is List ? row['tags'] : null,
      'note': mergeRecordNoteFields(row['note'], row['notes']),
      'checklist': _parseRecordChecklistField(row['checklist']),
    };
  }

  List<Map<String, dynamic>>? _parseRecordChecklistField(dynamic raw) =>
      parseChecklistFromNoco(raw);

  Set<String> _collectRecordKeysFromCache(String recordId) {
    final id = recordId.trim();
    final out = <String>{};
    if (id.isNotEmpty) out.add(id);
    for (final row in _cachedFlatRecords) {
      final pk = nocoRecordsTablePk(row);
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
      final pk = nocoRecordsTablePk(r).trim();
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
    final pk = nocoRecordsTablePk(row);
    final biz = (row['record_id'] ?? '').toString().trim();
    for (final k in [pk, biz]) {
      if (k.isNotEmpty && _optimisticDeletedKeys.contains(k)) return true;
    }
    return false;
  }

  /// Merge [end_time] for rows the user just stopped (PATCH in flight).
  Map<String, dynamic> _mergeOptimisticIntoRecordMap(Map<String, dynamic> data) {
    final rid = (data['record_id'] ?? '').toString().trim();
    final nid = (data['id'] ?? data['nocoRestPathId'] ?? '').toString().trim();
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
      _timeUpdateController.add(null);
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
      _timeUpdateController.add(null);
    } catch (e, st) {
      _log('clearOptimisticStopKeysForRecord failed: $e');
      _log(st.toString());
    }
  }

  /// Clears optimistic overlay for timeline + active row (call after failed write or server sync).
  void clearOptimisticTimelineUi() {
    try {
      _optimisticEndByKey.clear();
      _optimisticDeletedKeys.clear();
      _optimisticPendingStartRecordMap = null;
      _timeUpdateController.add(null);
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
    final w =
        _profileWallFromUtc(startUtc.toUtc());
    final calendarDayStr =
        '${w.year}-${_two(w.month)}-${_two(w.day)}';
    final rid = clientRecordId.trim();
    return <String, dynamic>{
      'id': rid,
      'nocoRestPathId': rid,
      'record_id': rid,
      'nocoSystemId': null,
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
        final pk = nocoRecordsTablePk(row);
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
      _timeUpdateController.add(null);
    } catch (e, st) {
      _log('applyOptimisticSacredHandoffForNewStart failed: $e');
      _log(st.toString());
    }
  }

  /// Noco stores wall-clock date in UTC strings; use the `YYYY-MM-DD` prefix only — no [.toLocal] day shift.
  static String? _utcDatePrefixFromRaw(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.length < 10) return null;
    final head = s.substring(0, 10);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(head)) return null;
    return head;
  }

  List<Map<String, dynamic>> _filterCachedRecordsForDate(DateTime date) {
    try {
      // Same basis as [getProjectedTodayDateKey]: wall calendar day for the given [date] naive fields.
      final targetDayStr =
          '${date.year}-${_two(date.month)}-${_two(date.day)}';
      final profileKey = (currentProfileId ?? '').trim().toLowerCase();
      final filtered = <Map<String, dynamic>>[];
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) {
          continue;
        }
        if (_optimisticRowDeletedRaw(row)) continue;
        final rowUid =
            (row['user_id'] ?? '').toString().trim().toLowerCase();
        if (rowUid != profileKey) continue;

        final stUtc = _parseDateTimeUtc(row['start_time']);
        if (stUtc == null) continue;
        final w = _profileWallFromUtc(stUtc);
        final recordDayStr =
            '${w.year}-${_two(w.month)}-${_two(w.day)}';
        if (recordDayStr != targetDayStr) continue;

        filtered.add(
            _mergeOptimisticIntoRecordMap(_rowToRecordMap(row)));
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
        await _fetchRecordsIntoCache();
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

  Stream<List<Map<String, dynamic>>> recordsStream(DateTime date) async* {
    if (!_isInitialized || _userIdForWhere == 0) {
      debugPrint(
          'SUCCESS: Date=${date.toIso8601String().split('T')[0]} | Found=0 records');
      yield [];
      return;
    }
    try {
      if (_cachedFlatRecords.isEmpty) {
        await _fetchRecordsIntoCache();
      }
    } catch (_) {}

    List<Map<String, dynamic>> nextPayload() {
      final filtered = _filterCachedRecordsForDate(date);
      debugPrint(
          'SUCCESS: Date=${date.toIso8601String().split('T')[0]} | Found=${filtered.length} records');
      return _withDisplayTimes(filtered);
    }

    yield nextPayload();
    await for (final _ in timeUpdates) {
      yield nextPayload();
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
        final path = (data['nocoRestPathId'] ?? '').toString().trim();
        final sys = data['nocoSystemId']?.toString().trim() ?? '';
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
      (data['nocoRestPathId'] ?? '').toString().trim(),
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
        final rows = await getRecords();
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
    final u = normalizeNocoLinkField(raw)?.toString().trim() ??
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
        final pk = nocoRecordsTablePk(row);
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
        return list
            .map((row) => TimelineRecord.fromMap(
                  _rowToRecordMap(row),
                  recordId: nocoRecordsTablePk(row),
                ))
            .toList();
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
        return list
            .take(50)
            .map((row) => TimelineRecord.fromMap(
                  _rowToRecordMap(row),
                  recordId: nocoRecordsTablePk(row),
                ))
            .toList();
      } catch (_) {
        return <TimelineRecord>[];
      }
    });
  }

  static Stream<T> _streamFromPolling<T>(Future<T> Function() fetch) async* {
    yield await fetch();
    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      yield await fetch();
    }
  }

  Future<void> forceRefreshFromServer() async {
    try {
      await _loadRulesFromNoco();
      await _loadSettingsFromNoco();
      try {
        await _fetchRecordsIntoCache();
      } catch (_) {}
      _settingsController.add(_settings);
      _timeUpdateController.add(null);
    } catch (_) {}
  }

  Future<void> stopAnyRunningRecordsForDate(String dateKey) async {
    await stopAllRunningRecords();
  }

  Future<String?> startTimerWithCategory(String title,
      {int? categoryId, String? dateKey}) async {
    final now = getPlanetaryNow();
    final key = dateKey ?? getProjectedTodayDateKey();
    return writeRecord(key, title,
        categoryId: categoryId, explicitStartTime: now);
  }

  Future<String?> startTimer(String title) async {
    return startTimerWithCategory(title);
  }

  Future<bool> stopAllRunningRecords() async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
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
          final id = nocoRecordsTablePk(r);
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
          await _fetchRecordsIntoCache();
          final local = _cachedFlatRecords;
          for (final r in local) {
            if (_rowHasNonEmptyParent(r['parent_id'])) continue;
            if (!_isNocoRowSacredStopTarget(r)) continue;
            if (!_rowStartWallDayIsProjectedToday(r)) continue;
            final id = nocoRecordsTablePk(r);
            if (id.isEmpty) continue;
            byPk[id] = r;
          }
          _mergeSacredStaleOpenCandidates(local, byPk);
        } catch (e) {
          _log('SACRED_LAW: cache merge failed ($e)');
        }
      }

      final bulkRequests = <NocoRequest>[];
      final idsIncludedInBulk = <String>{};
      for (final id in byPk.keys) {
        final row = byPk[id];
        if (row == null) continue;
        final fields = _nocoFieldsForPatch(<String, dynamic>{
          'end_time': nowIso,
          'status': 'stopped',
        });
        _mergeBusinessRecordIdIntoFields(fields, row);
        final p = int.tryParse(id);
        if (p != null) {
          bulkRequests.add(
            NocoRequest(id: p, fields: Map<String, dynamic>.from(fields)),
          );
          idsIncludedInBulk.add(id);
        } else if (_isLikelyUuidOrLongPk(id)) {
          bulkRequests.add(
            NocoRequest(id: id, fields: Map<String, dynamic>.from(fields)),
          );
          idsIncludedInBulk.add(id);
        }
      }

      var bulkStoppedAllEncodedRows = false;
      if (bulkRequests.isNotEmpty) {
        _log(
          'SACRED_LAW: bulk-stopping ${bulkRequests.length} record(s) before singleton handoff (one PATCH per chunk)',
        );
        const chunkSize = 80;
        var bulkAllOk = true;
        for (var i = 0; i < bulkRequests.length; i += chunkSize) {
          final end = min(i + chunkSize, bulkRequests.length);
          final chunk = bulkRequests.sublist(i, end);
          final payload = NocoRequest.bulk(chunk);
          var chunkOk = false;
          final res = await _recordsBulkPatchHttpTry(
            'stopAllRunningRecords',
            jsonEncode(payload),
          );
          if (res != null && res.statusCode >= 200 && res.statusCode < 300) {
            chunkOk = true;
          }
          if (!chunkOk) {
            bulkAllOk = false;
            _log(
              'SACRED_LAW: bulk chunk ${i + 1}-$end failed; will try per-row fallback',
            );
            break;
          }
        }
        if (bulkAllOk && idsIncludedInBulk.length == byPk.length) {
          await _fetchRecordsIntoCache();
          _timeUpdateController.add(null);
          return true;
        }
        if (bulkAllOk && idsIncludedInBulk.length < byPk.length) {
          _log(
            'SACRED_LAW: bulk stopped ${idsIncludedInBulk.length} row(s); per-row for ${byPk.length - idsIncludedInBulk.length} row(s) with non-bulk PK shape',
          );
          bulkStoppedAllEncodedRows = true;
        }
      }

      _log(
        'SACRED_LAW: per-row fallback stopping ${byPk.length} record(s) (bulk multi-row not available or failed)',
      );
      for (final id in byPk.keys) {
        if (bulkStoppedAllEncodedRows && idsIncludedInBulk.contains(id)) {
          continue;
        }
        final row = byPk[id];
        if (row == null) continue;
        debugPrint(
            '[DatabaseService] SACRED_LAW: Stopping record id=$id before singleton handoff (PATCH end_time + stopped)');
        _log(
            'PATCH_ID_TRACE: stopAllRunningRecords recordsUid=$_recordsTableUid url=${_recordsRowUrl(id)}',
        );
        final fields = _nocoFieldsForPatch(<String, dynamic>{
          'end_time': nowIso,
          'status': 'stopped',
        });
        final biz = (row['record_id'] ?? '').toString().trim();
        final originalOid = biz.isNotEmpty ? biz : id;
        final res = await _patchRecordsRowWith404Recovery(
          originalQueryId: originalOid,
          restId: id,
          fields: fields,
        );
        if (res.statusCode == 404) {
          _purgeGhostRecordById(id);
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          _log('STOP_SWITCH_ABORT: failed to stop record id=$id status=${res.statusCode}');
          return false;
        }
      }
      await _fetchRecordsIntoCache();
      _timeUpdateController.add(null);
      return true;
    } catch (_) {
      return false;
    }
  }

  String get _todayKey => getProjectedTodayDateKey();

  Future<bool> writeCompletedRecord(
    String title,
    DateTime startTime,
    DateTime endTime, {
    int? categoryId,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    try {
      final parsed = getCleanTitleAndTags(title);
      final res = await http.post(
        Uri.parse('$baseUrl/$_recordsRecords'),
        headers: _headers,
        body: jsonEncode(NocoRequest.single(fields: _recordsPatchFieldsJsonStrings(
          _nocoFieldsForPatch(<String, dynamic>{
            'user_id': _pid,
            'record_id': _newClientRecordUuid(),
            'status': 'completed',
            'title': parsed.title,
            'start_time': startTime.toUtc().toIso8601String(),
            'end_time': endTime.toUtc().toIso8601String(),
            'category_id': _recordCategoryBusinessPkForApi(categoryId),
            'type': 'record',
            'parent_id': null,
            'checklist': <Map<String, dynamic>>[],
            if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
          }),
        ))),
      );
      _log('writeCompletedRecord POST status=${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        await _finalizeRecordCreateHandshake(
          res: res,
          titleForMatch: parsed.title,
          startIsoUtc: startTime.toUtc().toIso8601String(),
          endIsoUtc: endTime.toUtc().toIso8601String(),
        );
        return true;
      } else {
        _log(
            'writeCompletedRecord POST failed: status=${res.statusCode} body=${res.body}');
        return false;
      }
    } catch (e, st) {
      _log('writeCompletedRecord failed: $e');
      _log(st);
      return false;
    }
  }

  Future<String?> writeRecord(
    String dateKey,
    String taskText, {
    int? categoryId,
    DateTime? explicitStartTime,
    int? parentId,
    String? parentRecordId,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return null;
    try {
      final parsed = getCleanTitleAndTags(taskText);
      int? cid = categoryId;
      cid = identifyCategory(parsed.title)?.id ?? cid;
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
      if (status == 'running') {
        final isPrimary = !hasParent;
        late final String runningRecordBizId;
        if (isPrimary) {
          runningRecordBizId = _newClientRecordUuid();
          final optTitle =
              parsed.title.trim().isEmpty ? taskText.trim() : parsed.title;
          applyOptimisticSacredHandoffForNewStart(
            clientRecordId: runningRecordBizId,
            title: optTitle,
            startUtc: start,
            categoryId: cid,
          );
          debugPrint(
              '[DatabaseService] SACRED_LAW: stopAllRunningRecords() before POST new task "${parsed.title}"');
          final stopped = await stopAllRunningRecords();
          if (!stopped) {
            _log('STOP_THEN_START_ABORT: did not start new record because stop failed.');
            clearOptimisticTimelineUi();
            return null;
          }
        } else {
          runningRecordBizId = _newClientRecordUuid();
          final rows = await getRecords();
          for (final r in rows) {
            var sameParent = false;
            if (pr != null && pr.isNotEmpty) {
              sameParent = _parentFieldEqualsRecordId(r, pr);
            } else if (parentId != null) {
              sameParent = _rowInt(r['parent_id']) == parentId;
            }
            if (!sameParent) continue;
            if (!_isNocoRowSacredStopTarget(r)) continue;
            final id = nocoRecordsTablePk(r);
            if (id.isEmpty) continue;
            _log(
                'PATCH_ID_TRACE: child-stop recordsUid=$_recordsTableUid url=${_recordsRowUrl(id)}',
            );
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
            if (cr.statusCode == 404) {
              _purgeGhostRecordById(id);
            }
          }
        }
        final runningFields = _nocoFieldsForPatch(<String, dynamic>{
          'user_id': _pid,
          'record_id': runningRecordBizId,
          'status': 'running',
          'title': parsed.title,
          'start_time': startIso,
          'end_time': null,
          'category_id': _recordCategoryBusinessPkForApi(cid),
          'type': 'record',
          'checklist': <Map<String, dynamic>>[],
          if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
        });
        if (pr != null && pr.isNotEmpty) {
          runningFields['parent_id'] = pr;
        } else if (parentId != null) {
          runningFields['parent_id'] = parentId.toString();
        }
        final res = await http.post(
          Uri.parse('$baseUrl/$_recordsRecords'),
          headers: _headers,
          body: jsonEncode(NocoRequest.single(
            fields: _recordsPatchFieldsJsonStrings(
              _nocoFieldsForPatch(runningFields),
            ),
          )),
        );
        _log('ROUTE_CHECK: POST records -> $_recordsRecords');
        _log('writeRecord POST status=${res.statusCode}');
        if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
          final newId = await _finalizeRecordCreateHandshake(
            res: res,
            titleForMatch: parsed.title,
            startIsoUtc: startIso,
            endIsoUtc: null,
          );
          if (isPrimary) {
            clearOptimisticTimelineUi();
          } else {
            _timeUpdateController.add(null);
          }
          return newId;
        } else {
          _log('writeRecord POST failed: status=${res.statusCode} body=${res.body}');
          if (isPrimary) clearOptimisticTimelineUi();
          return null;
        }
      } else {
        final completedFields = _nocoFieldsForPatch(<String, dynamic>{
          'user_id': _pid,
          'record_id': _newClientRecordUuid(),
          'status': 'completed',
          'title': parsed.title,
          'start_time': startIso,
          'end_time': endTime?.toUtc().toIso8601String(),
          'category_id': _recordCategoryBusinessPkForApi(cid),
          'type': 'record',
          'checklist': <Map<String, dynamic>>[],
          if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
        });
        if (pr != null && pr.isNotEmpty) {
          completedFields['parent_id'] = pr;
        } else if (parentId != null) {
          completedFields['parent_id'] = parentId.toString();
        }
        final res = await http.post(
          Uri.parse('$baseUrl/$_recordsRecords'),
          headers: _headers,
          body: jsonEncode(NocoRequest.single(
            fields: _recordsPatchFieldsJsonStrings(
              _nocoFieldsForPatch(completedFields),
            ),
          )),
        );
        _log('ROUTE_CHECK: POST records -> $_recordsRecords');
        _log('writeRecord POST status=${res.statusCode}');
        if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
          return _finalizeRecordCreateHandshake(
            res: res,
            titleForMatch: parsed.title,
            startIsoUtc: startIso,
            endIsoUtc: endTime?.toUtc().toIso8601String(),
          );
        } else {
          _log('writeRecord POST failed: status=${res.statusCode} body=${res.body}');
          return null;
        }
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
  }

  Future<void> addPlannedTask(
    String dateKey,
    String taskText, {
    int? categoryId,
    bool isManual = false,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return;
    if (!_isPlansTableConfigured) {
      _log('TABLE_GUARD: blocked addPlannedTask because plans table id equals records table id.');
      return;
    }
    try {
      final parsed = getCleanTitleAndTags(taskText);
      int cid = categoryId ?? defaultCategoryId ?? 0;
      if (!isManual) {
        cid = identifyCategory(parsed.title)?.id ?? (defaultCategoryId ?? 0);
      }
      final startIso = _planStartUtcIsoFromDateKey(dateKey);
      final planCat = _recordCategoryBusinessPkForApi(cid);
      await http.post(
        Uri.parse('$baseUrl/$_plansRecords'),
        headers: _headers,
        body: jsonEncode(NocoRequest.single(fields: _recordsPatchFieldsJsonStrings(
          _nocoFieldsForPatch(<String, dynamic>{
            'user_id': _pid,
            'plan_id': _newClientRecordUuid(),
            'title': parsed.title,
            'category_id': planCat,
            'is_done': false,
            'order': 0,
            'checklist': <Map<String, dynamic>>[],
            if (startIso != null) 'start_time': startIso,
          }),
        ))),
      );
      _log('ROUTE_CHECK: POST plans -> $_plansRecords');
    } catch (_) {}
  }

  Future<void> addPlan({
    required String title,
    required int categoryId,
    required String dateKey,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return;
    if (!_isPlansTableConfigured) {
      _log('TABLE_GUARD: blocked addPlan because plans table id equals records table id.');
      return;
    }
    unawaited(() async {
      try {
        final startIso = _planStartUtcIsoFromDateKey(dateKey);
        final planCat = _recordCategoryBusinessPkForApi(categoryId);
        await http.post(
          Uri.parse('$baseUrl/$_plansRecords'),
          headers: _headers,
          body: jsonEncode(NocoRequest.single(fields: _recordsPatchFieldsJsonStrings(
            _nocoFieldsForPatch(<String, dynamic>{
              'user_id': _pid,
              'plan_id': _newClientRecordUuid(),
              'title': title,
              'category_id': planCat,
              'is_done': false,
              'order': 0,
              'checklist': <Map<String, dynamic>>[],
              if (startIso != null) 'start_time': startIso,
            }),
          ))),
        );
        _log('ROUTE_CHECK: POST plans -> $_plansRecords');
      } catch (_) {}
    }());
  }

  Future<TimelineRecord?> updateRecord({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    List<Map<String, dynamic>>? checklist,
    bool bypassConflictCheck = false,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return null;
    try {
      var rid = recordId.trim();
      if (rid.isEmpty) return null;
      final originalInput = rid;
      rid = await _resolveRecordIdForRestUrl(rid);
      debugPrint('DB_TRACE: Using NocoDB record_id: $rid for sync.');
      _log(
          'PATCH_ID_TRACE: updateRecord recordsUid=$_recordsTableUid url=${_recordsRowUrl(rid)}',
      );
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
      if (categoryId != null) {
        updates['category_id'] = _recordCategoryBusinessPkForApi(categoryId);
      }
      if (note != null) updates['note'] = note;
      if (checklist != null) updates['checklist'] = checklist;
      if (updates.isEmpty) {
        final rows = await getRecords();
        Map<String, dynamic>? found;
        for (final r in rows) {
          if (nocoRecordsTablePk(r) == rid ||
              (r['record_id'] ?? '').toString().trim() == rid ||
              (r['record_id'] ?? '').toString().trim() == originalInput) {
            found = r;
            break;
          }
        }
        if (found == null) return null;
        return TimelineRecord.fromMap(_rowToRecordMap(found),
            recordId: rid);
      }
      final res = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
      );
      if (res.statusCode == 404) {
        _purgeGhostRecordById(rid);
        await _fetchRecordsIntoCache();
        _timeUpdateController.add(null);
        AppSnack.failed();
        return null;
      }
      await _fetchRecordsIntoCache();
      final rows = await getRecords();
      final row = rows.firstWhere(
        (r) =>
            nocoRecordsTablePk(r) == rid ||
            (r['record_id'] ?? '').toString().trim() == rid ||
            (r['record_id'] ?? '').toString().trim() == originalInput,
        orElse: () => <String, dynamic>{},
      );
      if (row.isEmpty) {
        AppSnack.failed();
        return null;
      }
      _timeUpdateController.add(null);
      AppSnack.saved();
      return TimelineRecord.fromMap(_rowToRecordMap(row), recordId: rid);
    } catch (_) {
      AppSnack.failed();
      return null;
    }
  }

  /// Alias: Noco row PATCH — [recordId] must resolve to **wrapper `Id`** (integer) for URL path.
  Future<TimelineRecord?> patchRecord({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    List<Map<String, dynamic>>? checklist,
    bool bypassConflictCheck = false,
  }) =>
      updateRecord(
        recordId: recordId,
        title: title,
        startTime: startTime,
        endTime: endTime,
        categoryId: categoryId,
        note: note,
        checklist: checklist,
        bypassConflictCheck: bypassConflictCheck,
      );

  Future<bool> deleteRecordByDocId(String recordId) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return false;
    final delKeys = _collectRecordKeysFromCache(originalInput);
    for (final k in delKeys) {
      if (k.isNotEmpty) _optimisticDeletedKeys.add(k);
    }
    _timeUpdateController.add(null);
    try {
      var rid = await _resolveRecordIdForRestUrl(originalInput);
      final res = await _deleteRecordsRowWithFallback(
        originalQueryId: originalInput,
        restId: rid,
      );
      if (res.statusCode == 404) {
        _purgeGhostRecordById(rid);
      }
      final ok = (res.statusCode >= 200 && res.statusCode < 300) ||
          res.statusCode == 404;
      if (!ok) {
        for (final k in delKeys) {
          _optimisticDeletedKeys.remove(k);
        }
        _timeUpdateController.add(null);
        AppSnack.failed();
        return false;
      }
      await _fetchRecordsIntoCache();
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _timeUpdateController.add(null);
      AppSnack.deleted();
      return true;
    } catch (e, st) {
      _log('deleteRecordByDocId failed: $e');
      _log(st.toString());
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _timeUpdateController.add(null);
      AppSnack.failed();
      return false;
    }
  }

  Future<void> deleteRecord(String recordId) async {
    await deleteRecordByDocId(recordId);
  }

  /// Stops a record (PATCH). Applies optimistic UI immediately; returns `false` if network/PATCH failed (UI reverts).
  Future<bool> stopRecordByDocId(String recordId) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    var rid = recordId.trim();
    if (rid.isEmpty) return false;
    final originalInput = rid;
    _applyOptimisticStopUiSnapshot(originalInput);
    try {
      rid = await _resolveRecordIdForRestUrl(rid);
      final nowIso = getPlanetaryNow().toUtc().toIso8601String();
      _log(
          'PATCH_ID_TRACE: stopRecordByDocId recordsUid=$_recordsTableUid url=${_recordsRowUrl(rid)}',
      );
      final stopFields = _nocoFieldsForPatch(<String, dynamic>{
        'end_time': nowIso,
        'status': 'stopped',
      });
      final res = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: stopFields,
      );
      if (res.statusCode == 404) {
        _purgeGhostRecordById(rid);
        _clearOptimisticStopKeysForRecord(originalInput);
        await _fetchRecordsIntoCache();
        _timeUpdateController.add(null);
        AppSnack.updated();
        return true;
      }
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        _clearOptimisticStopKeysForRecord(originalInput);
        await _fetchRecordsIntoCache();
        _timeUpdateController.add(null);
        AppSnack.updated();
        return true;
      }
      _clearOptimisticStopKeysForRecord(originalInput);
      _timeUpdateController.add(null);
      AppSnack.failed();
      return false;
    } catch (e, st) {
      _log('stopRecordByDocId failed: $e');
      _log(st.toString());
      _clearOptimisticStopKeysForRecord(originalInput);
      _timeUpdateController.add(null);
      AppSnack.failed();
      return false;
    }
  }

  /// Alias for [stopRecordByDocId] (Sacred Law / singleton stop).
  Future<bool> stopRecord(String recordId) async => stopRecordByDocId(recordId);

  Future<void> updateRecordChecklist(
      String recordId, List<Map<String, dynamic>> checklist) async {
    if (!_isInitialized || _userIdForWhere == 0) return;
    try {
      var rid = recordId.trim();
      if (rid.isEmpty) return;
      final originalInput = rid;
      rid = await _resolveRecordIdForRestUrl(rid);
      final clFields = _nocoFieldsForPatch(<String, dynamic>{'checklist': checklist});
      final res = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: clFields,
      );
      if (res.statusCode == 404) {
        _purgeGhostRecordById(rid);
      }
      await _fetchRecordsIntoCache();
      _timeUpdateController.add(null);
    } catch (_) {}
  }

  Stream<List<PlanningTask>> planningStream(DateTime selectedDate) {
    return Stream.multi((controller) async {
      StreamSubscription<void>? sub;
      try {
        controller.add(await _fetchPlanningTasksForDate(selectedDate));
        sub = Stream.periodic(const Duration(seconds: 2)).listen((_) async {
          try {
            if (!controller.isClosed) {
              controller.add(await _fetchPlanningTasksForDate(selectedDate));
            }
          } catch (_) {
            if (!controller.isClosed) controller.add(<PlanningTask>[]);
          }
        });
      } catch (_) {
        if (!controller.isClosed) controller.add(<PlanningTask>[]);
      }
      controller.onCancel = () => sub?.cancel();
    });
  }

  PlanningTask _planRowToTask(Map<String, dynamic> row) {
    final startUtc = _parseDateTimeUtc(row['start_time']);
    final startDisplay =
        startUtc != null ? _profileWallFromUtc(startUtc.toUtc()) : null;
    final endUtc = _parseDateTimeUtc(row['end_time']);
    final endDisplay =
        endUtc != null ? _profileWallFromUtc(endUtc.toUtc()) : null;
    final derivedDateKey = startDisplay != null
        ? _dateKeyFromDate(startDisplay)
        : (endDisplay != null ? _dateKeyFromDate(endDisplay) : '');
    final derivedEndDateKey =
        endDisplay != null ? _dateKeyFromDate(endDisplay) : derivedDateKey;
    final planPk = nocoPlanRowPk(row);
    return PlanningTask.fromJson(<String, dynamic>{
      'plan_row_id': planPk.isNotEmpty ? planPk : null,
      'id': _rowInt(row['id']),
      'title': row['title'] as String? ?? '',
      'categoryId': categoryIdFromNocoRecordRow(row) ?? 0,
      'isDone': _jsonBoolFromDynamic(row['is_done']),
      'dateKey': derivedDateKey,
      'order': row['order'] is int ? row['order'] as int : 0,
      'startTime': startDisplay,
      'endDateTime': endDisplay,
      'endDateKey': derivedEndDateKey,
      'checklist': row['checklist'],
      'note': mergeRecordNoteFields(row['note'], row['notes']),
      'parentPlanId': row['parent_plan_id'] == null
          ? null
          : _rowInt(row['parent_plan_id']),
      'subRecordIds': <int>[],
    });
  }

  Future<bool> addPlanningTask(PlanningTask task) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    if (!_isPlansTableConfigured) {
      _log('TABLE_GUARD: blocked addPlanningTask because plans table id equals records table id.');
      AppSnack.failed();
      return false;
    }
    try {
      final catStr = _categoryStringPkForApi(getCategoryRuleById(task.categoryId));
      if (catStr == null || catStr.isEmpty) {
        _log('ADD_PLAN: blocked — category_id string missing for local category ${task.categoryId}');
        AppSnack.failed();
        return false;
      }
      final planFieldsRaw = _nocoFieldsForPatch(<String, dynamic>{
        'user_id': _pid,
        'category_id': catStr,
        'plan_id': _newClientRecordUuid(),
        'title': task.title,
        // Explicit boolean so Noco never applies a wrong default (@DATA_MAP `is_done`).
        'is_done': task.isDone == true,
        'order': task.order,
        'checklist': task.checklist.isNotEmpty ? task.checklist : <Map<String, dynamic>>[],
      });
      final planFields = _recordsPatchFieldsJsonStrings(
        Map<String, dynamic>.from(planFieldsRaw),
      );
      if (task.startTime != null) {
        planFields['start_time'] = task.startTime!.toUtc().toIso8601String();
      } else if (task.dateKey.length >= 10) {
        final iso = _planStartUtcIsoFromDateKey(task.dateKey);
        if (iso != null) planFields['start_time'] = iso;
      }
      if (task.endDateTime != null) {
        planFields['end_time'] = task.endDateTime!.toUtc().toIso8601String();
      }
      if (task.notes != null && task.notes!.trim().isNotEmpty) {
        planFields['note'] = task.notes;
      }
      if (task.parentPlanId != null) {
        planFields['parent_plan_id'] = task.parentPlanId.toString();
      }
      final res = await http.post(
        Uri.parse('$baseUrl/$_plansRecords'),
        headers: _headers,
        body: jsonEncode(NocoRequest.single(fields: planFields)),
      );
      _log('ROUTE_CHECK: POST plans -> $_plansRecords');
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        AppSnack.saved();
      } else {
        AppSnack.failed();
      }
      return ok;
    } catch (_) {
      AppSnack.failed();
      return false;
    }
  }

  /// POST bulk upsert with NocoRequest. [planRowId] = Noco **plan_id** (@DATA_MAP.md).
  void _cancelPlanOrderDebounceTimer() {
    _planOrderDebounceTimer?.cancel();
    _planOrderDebounceTimer = null;
  }

  /// Seeds baseline **once** per reorder session from the list as shown **before** the drag (server orders).
  void _ensurePlanningOrderBaseline(List<PlanningTask> tasksWithServerOrders) {
    if (_planReorderBaselineByPlanId != null) return;
    final m = <String, int>{};
    for (final t in tasksWithServerOrders) {
      if (t.planRowIdForNoco.startsWith('optimistic-')) continue;
      final id = t.planRowIdForNoco.trim();
      if (id.isEmpty) continue;
      m[id] = t.order;
    }
    _planReorderBaselineByPlanId = m;
  }

  Future<void> _persistPlanningTaskOrdersBulkNow(List<PlanningTask> ordered) async {
    if (!_isInitialized || _userIdForWhere == 0) return;
    if (!_isPlansTableConfigured) return;

    final requests = <NocoRequest>[];
    for (var i = 0; i < ordered.length; i++) {
      final t = ordered[i];
      if (t.planRowIdForNoco.startsWith('optimistic-')) continue;
      final id = t.planRowIdForNoco.trim();
      if (id.isEmpty) continue;
      final base = _planReorderBaselineByPlanId?[id];
      if (base != null && base == i) continue;

      Object bulkId = id;
      final asInt = int.tryParse(id);
      if (asInt != null) bulkId = asInt;

      final fields = _nocoFieldsForPatch(<String, dynamic>{
        'user_id': _pid,
        'order': i,
      });
      requests.add(NocoRequest(id: bulkId, fields: fields));
    }

    if (requests.isEmpty) {
      _log(
        'PLAN_ORDER_SYNC: skip bulk PATCH — every order matches baseline (${ordered.length} tasks)',
      );
      _planReorderBaselineByPlanId = null;
      return;
    }

    for (var start = 0; start < requests.length; start += _planOrderBulkChunkSize) {
      final end = min(start + _planOrderBulkChunkSize, requests.length);
      final chunk = requests.sublist(start, end);
      final chunkIndex = start ~/ _planOrderBulkChunkSize + 1;
      final chunkCount = (requests.length + _planOrderBulkChunkSize - 1) ~/ _planOrderBulkChunkSize;
      final bodyJson = jsonEncode(NocoRequest.bulk(chunk));
      _log(
        'PLAN_ORDER_SYNC: bulk PATCH chunk $chunkIndex/$chunkCount rows=${chunk.length}',
      );
      try {
        final res =
            await _plansBulkPatchHttp('persistPlanningTaskOrderBulk', bodyJson);
        final ok = res.statusCode >= 200 && res.statusCode < 300;
        if (!ok) {
          _log(
            'PLAN_ORDER_SYNC: chunk failed status=${res.statusCode} body=${res.body}',
          );
          try {
            final msg = t(currentLocale.value, 'plan_save_failed');
            if (!_notify.isClosed) _notify.add(msg);
          } catch (_) {}
          return;
        }
      } catch (e, st) {
        _log('PLAN_ORDER_SYNC: chunk exception $e');
        _log(st.toString());
        try {
          final msg = t(currentLocale.value, 'plan_save_failed');
          if (!_notify.isClosed) _notify.add(msg);
        } catch (_) {}
        return;
      }
    }

    _log(
      'PLAN_ORDER_SYNC: bulk PATCH ok (${requests.length} row(s) across chunks)',
    );
    _planReorderBaselineByPlanId = null;
  }

  /// After navigation away or app pause: persist pending plan order immediately (no debounce).
  Future<void> flushPlanningOrderSyncNow() async {
    _cancelPlanOrderDebounceTimer();
    final pending = _pendingPlanOrderSyncList;
    _pendingPlanOrderSyncList = null;
    _log(
      'PLAN_ORDER_SYNC: immediate flush (${pending?.length ?? 0} pending task(s))',
    );
    if (pending == null || pending.isEmpty) return;
    await _persistPlanningTaskOrdersBulkNow(pending);
  }

  void _cancelCategoryOrderDebounceTimer() {
    _categoryOrderDebounceTimer?.cancel();
    _categoryOrderDebounceTimer = null;
  }

  void _ensureCategoryOrderBaseline(List<CategoryRule> listBeforeFirstDrag) {
    if (_categoryReorderBaselineByLocalId != null) return;
    final m = <int, int>{};
    for (var i = 0; i < listBeforeFirstDrag.length; i++) {
      m[listBeforeFirstDrag[i].id] = i;
    }
    _categoryReorderBaselineByLocalId = m;
  }

  /// Optimistic sibling order: sets [order] to 0..n-1 and replaces the sibling list in memory.
  void applyLocalCategorySiblingOrder(
    int? parentId,
    List<CategoryRule> ordered,
  ) {
    final next = List<CategoryRule>.from(ordered);
    for (var i = 0; i < next.length; i++) {
      next[i].order = i;
    }
    if (parentId == null) {
      _rules = next;
    } else {
      final parent = getCategoryRuleById(parentId);
      if (parent == null) return;
      parent.children = next;
    }
    _categoryController.add(List.from(_rules));
  }

  int _nextCategoryOrderAmongSiblings(int? parentId) {
    final sibs = getChildrenOf(parentId);
    var m = -1;
    for (final r in sibs) {
      if (r.id == -1) continue;
      if (r.order > m) m = r.order;
    }
    return m + 1;
  }

  /// Bulk PATCH `order` for **every** row (no baseline skip). Used for null-order init and post–parent-move sibling sync.
  Future<void> _persistCategoryOrdersBulkForce(
    List<CategoryRule> ordered, {
    String contextLabel = 'categoryOrderForce',
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return;

    final requests = <NocoRequest>[];
    for (var i = 0; i < ordered.length; i++) {
      final r = ordered[i];
      if (r.id == -1) continue;
      final sysId = _categoryNocoSystemIdStrict(r);
      if (sysId == null) continue;

      final biz = _categoryStringPkForApi(r);
      final fieldsRaw = <String, dynamic>{
        'user_id': _pid,
        if (biz != null && biz.isNotEmpty) 'category_id': biz,
        'order': r.order,
      };
      final fields = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(fieldsRaw),
      );
      requests.add(NocoRequest(id: sysId, fields: fields));
    }

    if (requests.isEmpty) {
      _log('$contextLabel: skip bulk PATCH (no rows)');
      return;
    }

    for (var start = 0; start < requests.length;
        start += _planOrderBulkChunkSize) {
      final end = min(start + _planOrderBulkChunkSize, requests.length);
      final chunk = requests.sublist(start, end);
      final chunkIndex = start ~/ _planOrderBulkChunkSize + 1;
      final chunkCount =
          (requests.length + _planOrderBulkChunkSize - 1) ~/
              _planOrderBulkChunkSize;
      final bodyJson = _categoryBulkPatchJsonMany(chunk);
      _log(
        '$contextLabel: bulk PATCH chunk $chunkIndex/$chunkCount rows=${chunk.length}',
      );
      try {
        final res =
            await _categoryBulkPatchHttp('$contextLabel bulk', bodyJson);
        final ok = res.statusCode >= 200 && res.statusCode < 300;
        if (!ok) {
          _log(
            '$contextLabel: chunk failed status=${res.statusCode} body=${res.body}',
          );
          return;
        }
      } catch (e, st) {
        _log('$contextLabel: chunk exception $e');
        _log(st.toString());
        return;
      }
    }
    _log('$contextLabel: bulk PATCH ok (${requests.length} row(s))');
  }

  Future<void> _persistCategoryOrdersBulkNow(List<CategoryRule> ordered) async {
    if (!_isInitialized || _userIdForWhere == 0) return;

    final requests = <NocoRequest>[];
    for (var i = 0; i < ordered.length; i++) {
      final r = ordered[i];
      if (r.id == -1) continue;
      final sysId = _categoryNocoSystemIdStrict(r);
      if (sysId == null) continue;
      final base = _categoryReorderBaselineByLocalId?[r.id];
      if (base != null && base == i) continue;

      final biz = _categoryStringPkForApi(r);
      final fieldsRaw = <String, dynamic>{
        'user_id': _pid,
        if (biz != null && biz.isNotEmpty) 'category_id': biz,
        'order': i,
      };
      final fields = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(fieldsRaw),
      );
      requests.add(NocoRequest(id: sysId, fields: fields));
    }

    if (requests.isEmpty) {
      _log(
        'CATEGORY_ORDER_SYNC: skip bulk PATCH — every index matches baseline (${ordered.length} row(s))',
      );
      _categoryReorderBaselineByLocalId = null;
      return;
    }

    for (var start = 0; start < requests.length;
        start += _planOrderBulkChunkSize) {
      final end = min(start + _planOrderBulkChunkSize, requests.length);
      final chunk = requests.sublist(start, end);
      final chunkIndex = start ~/ _planOrderBulkChunkSize + 1;
      final chunkCount =
          (requests.length + _planOrderBulkChunkSize - 1) ~/
              _planOrderBulkChunkSize;
      final bodyJson = _categoryBulkPatchJsonMany(chunk);
      _log(
        'CATEGORY_ORDER_SYNC: bulk PATCH chunk $chunkIndex/$chunkCount rows=${chunk.length}',
      );
      try {
        final res = await _categoryBulkPatchHttp(
          'persistCategoryOrderBulk',
          bodyJson,
        );
        final ok = res.statusCode >= 200 && res.statusCode < 300;
        if (!ok) {
          _log(
            'CATEGORY_ORDER_SYNC: chunk failed status=${res.statusCode} body=${res.body}',
          );
          try {
            final msg = t(currentLocale.value, 'sync_failed');
            if (!_notify.isClosed) _notify.add(msg);
          } catch (_) {}
          return;
        }
      } catch (e, st) {
        _log('CATEGORY_ORDER_SYNC: chunk exception $e');
        _log(st.toString());
        try {
          final msg = t(currentLocale.value, 'sync_failed');
          if (!_notify.isClosed) _notify.add(msg);
        } catch (_) {}
        return;
      }
    }

    _log(
      'CATEGORY_ORDER_SYNC: bulk PATCH ok (${requests.length} row(s) across chunks)',
    );
    _categoryReorderBaselineByLocalId = null;
  }

  /// Debounced bulk PATCH: [order] + [user_id] (@DATA_MAP.md `categories`).
  ///
  /// Pass [baselineBeforeReorder] as the sibling list **before** the drag; only the first non-null
  /// list seeds [_categoryReorderBaselineByLocalId] until a successful sync clears it.
  Future<void> persistCategorySiblingOrder(
    int? parentId,
    List<CategoryRule> ordered, {
    List<CategoryRule>? baselineBeforeReorder,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return;
    if (parentId != null && getCategoryRuleById(parentId) == null) {
      return;
    }
    if (baselineBeforeReorder != null) {
      _ensureCategoryOrderBaseline(baselineBeforeReorder);
    }
    _pendingCategoryOrderSyncList = List<CategoryRule>.from(ordered);
    _cancelCategoryOrderDebounceTimer();
    _log(
      'CATEGORY_ORDER_SYNC: debounce arm ${ordered.length} row(s) parent=$parentId — fire in ${_categoryOrderDebounce.inSeconds}s',
    );
    _categoryOrderDebounceTimer = Timer(_categoryOrderDebounce, () {
      _categoryOrderDebounceTimer = null;
      final pending = _pendingCategoryOrderSyncList;
      _pendingCategoryOrderSyncList = null;
      if (pending == null || pending.isEmpty) return;
      _log(
        'CATEGORY_ORDER_SYNC: debounce elapsed — syncing ${pending.length} row(s)',
      );
      unawaited(_persistCategoryOrdersBulkNow(pending));
    });
  }

  Future<void> flushCategoryOrderSyncNow() async {
    _cancelCategoryOrderDebounceTimer();
    final pending = _pendingCategoryOrderSyncList;
    _pendingCategoryOrderSyncList = null;
    _log(
      'CATEGORY_ORDER_SYNC: immediate flush (${pending?.length ?? 0} pending row(s))',
    );
    if (pending == null || pending.isEmpty) return;
    await _persistCategoryOrdersBulkNow(pending);
  }

  Future<bool> updatePlanningTask(
    String planRowId, {
    /// @DATA_MAP `plan_id` (UUID) — send inside `fields` only; outer bulk `id` must be Integer Id.
    String? planBusinessId,
    String? title,
    int? categoryId,
    bool? isDone,
    String? notes,
    List<Map<String, dynamic>>? checklist,
    int? parentPlanId,
    int? order,
    DateTime? startTime,
    DateTime? startTimeDisplay,
    DateTime? endDateTime,
    DateTime? endDateTimeDisplay,
    bool clearEnd = false,
    /// When true, `AppSnack` success/failure toasts are omitted (caller handles UX).
    bool suppressAppSnack = false,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    if (!_isPlansTableConfigured) {
      _log('TABLE_GUARD: blocked updatePlanningTask because plans table id equals records table id.');
      return false;
    }
    final rid = planRowId.trim();
    if (rid.isEmpty) return false;
    final fields = <String, dynamic>{'user_id': _pid};
    if (title != null) fields['title'] = title;
    if (categoryId != null) {
      final cs = _categoryStringPkForApi(getCategoryRuleById(categoryId));
      if (cs != null && cs.isNotEmpty) {
        fields['category_id'] = cs;
      }
    }
    if (isDone != null) fields['is_done'] = isDone;
    if (notes != null) fields['note'] = notes;
    if (checklist != null) fields['checklist'] = checklist;
    if (parentPlanId != null) {
      fields['parent_plan_id'] = parentPlanId.toString();
    }
    if (order != null) fields['order'] = order;
    if (startTimeDisplay != null) {
      fields['start_time'] =
          _profileUtcFromWall(startTimeDisplay).toIso8601String();
    } else if (startTime != null) {
      fields['start_time'] = startTime.toUtc().toIso8601String();
    }
    if (clearEnd) {
      fields['end_time'] = null;
    } else if (endDateTimeDisplay != null) {
      fields['end_time'] =
          _profileUtcFromWall(endDateTimeDisplay).toIso8601String();
    } else if (endDateTime != null) {
      fields['end_time'] = endDateTime.toUtc().toIso8601String();
    }
    if (fields.length <= 1) return false;

    final bizPid = planBusinessId?.trim() ?? '';
    if (bizPid.isNotEmpty && !bizPid.startsWith('optimistic-')) {
      fields['plan_id'] = bizPid;
    }

    try {
      final asInt = int.tryParse(rid.trim());
      if (asInt == null || asInt <= 0) {
        _log(
          'UPDATE_PLANNING_TASK: refuse bulk PATCH — outer id must be Noco Integer Id, got "$rid"',
        );
        return false;
      }
      final bulkId = asInt;
      final cleaned = _recordsPatchFieldsJsonStrings(
        _nocoFieldsForPatch(Map<String, dynamic>.from(fields)),
      );
      final bodyJson = jsonEncode(
        NocoRequest.bulk([NocoRequest(id: bulkId, fields: cleaned)]),
      );
      final res = await _plansBulkPatchHttp('updatePlanningTask', bodyJson);
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _log('UPDATE_PLANNING_TASK: server ${res.statusCode} — ${res.body}');
        if (!suppressAppSnack) AppSnack.failed();
      } else {
        if (!suppressAppSnack) AppSnack.saved();
      }
      return ok;
    } catch (e) {
      _log('UPDATE_PLANNING_TASK: $e');
      AppSnack.failed();
      return false;
    }
  }

  /// Collection DELETE: `[{"Id": <int>}, …]` then lowercase `id` fallback (Noco v3).
  Future<bool> deletePlanningTasksBulk(Iterable<int> nocoSystemIds) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    if (!_isPlansTableConfigured) {
      _log('TABLE_GUARD: blocked deletePlanningTasksBulk.');
      return false;
    }
    final ids = nocoSystemIds.where((i) => i > 0).toSet().toList()..sort();
    if (ids.isEmpty) return false;

    Future<http.Response> tryKey(String pkKey) async {
      final body = jsonEncode(
        ids.map((id) => <String, dynamic>{pkKey: id}).toList(),
      );
      return _plansBulkDeleteHttp('deletePlanningTasksBulk_$pkKey', body);
    }

    var res = await tryKey('Id');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      AppSnack.deleted();
      return true;
    }
    res = await tryKey('id');
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      AppSnack.deleted();
    } else {
      _log(
        'DELETE_PLANS_BULK: failed status=${res.statusCode} body=${res.body}',
      );
      AppSnack.failed();
    }
    return ok;
  }

  /// Bulk `is_done` — each element outer `id` is Integer wrapper PK (@DATA_MAP `plans`).
  Future<bool> markPlanningTasksCompletedBulk(
    Iterable<int> nocoSystemIds, {
    required bool completed,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return false;
    if (!_isPlansTableConfigured) return false;
    final ids = nocoSystemIds.where((i) => i > 0).toSet().toList()..sort();
    if (ids.isEmpty) return false;
    const chunkSize = 10;
    var allOk = true;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = min(i + chunkSize, ids.length);
      final chunk = ids.sublist(i, end);
      final requests = <NocoRequest>[];
      for (final id in chunk) {
        requests.add(
          NocoRequest(
            id: id,
            fields: _nocoFieldsForPatch(<String, dynamic>{
              'user_id': _pid,
              'is_done': completed,
            }),
          ),
        );
      }
      final bodyJson = jsonEncode(NocoRequest.bulk(requests));
      final res = await _plansBulkPatchHttp(
        'markPlanningTasksCompletedBulk',
        bodyJson,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        allOk = false;
        _log(
          'MARK_PLANS_DONE_BULK: chunk failed status=${res.statusCode} body=${res.body}',
        );
      }
    }
    if (allOk) {
      AppSnack.updated();
    } else {
      AppSnack.failed();
    }
    return allOk;
  }

  /// Debounced bulk PATCH: [order] + [user_id] only (@DATA_MAP.md). One multi-row bulk per chunk (max 10 rows).
  ///
  /// Pass [baselineBeforeReorder] as the task list **before** the drag (first drag in a session seeds diff
  /// baseline; further drags in the same session may pass the same argument — only the first non-null
  /// baseline is stored until a successful sync clears it).
  Future<void> persistPlanningTaskOrder(
    List<PlanningTask> ordered, {
    List<PlanningTask>? baselineBeforeReorder,
  }) async {
    if (!_isInitialized || _userIdForWhere == 0) return;
    if (!_isPlansTableConfigured) return;
    if (baselineBeforeReorder != null) {
      _ensurePlanningOrderBaseline(baselineBeforeReorder);
    }
    _pendingPlanOrderSyncList = List<PlanningTask>.from(ordered);
    _cancelPlanOrderDebounceTimer();
    _log(
      'PLAN_ORDER_SYNC: debounce arm ${ordered.length} task(s) — fire in ${_planOrderDebounce.inSeconds}s',
    );
    _planOrderDebounceTimer = Timer(_planOrderDebounce, () {
      _planOrderDebounceTimer = null;
      final pending = _pendingPlanOrderSyncList;
      if (pending == null || pending.isEmpty) return;
      _pendingPlanOrderSyncList = null;
      _log(
        'PLAN_ORDER_SYNC: debounce elapsed — syncing ${pending.length} task(s)',
      );
      unawaited(_persistPlanningTaskOrdersBulkNow(pending));
    });
  }

  /// Deletes one plan row via [deletePlanningTasksBulk] (collection DELETE, Integer PK only).
  Future<void> deletePlanningTask(String planRowId) async {
    if (!_isInitialized || _userIdForWhere == 0) return;
    if (!_isPlansTableConfigured) {
      _log('TABLE_GUARD: blocked deletePlanningTask because plans table id equals records table id.');
      return;
    }
    final id = planRowId.trim();
    if (id.isEmpty) return;
    final sysId = int.tryParse(id);
    if (sysId == null || sysId <= 0) {
      _log(
        'DELETE_PLANNING_TASK: refuse — row URL requires Noco system Id (int), got $id',
      );
      AppSnack.failed();
      return;
    }
    unawaited(deletePlanningTasksBulk([sysId]));
  }

  // Removed: Supabase OTP/Yandex/OAuth — use AuthBridge + Noco only.
  Future<void> signInWithYandex() async {}
  Future<void> exchangeCodeForSession(String code) async {}
  Future<void> signInWithOtp(String email) async {}
  Future<void> verifyOtp(String email, String code) async {}
}
