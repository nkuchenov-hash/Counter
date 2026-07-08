part of '../database_service.dart';

extension CategoryRecordBridgeExtension on DatabaseService {
  Map<String, dynamic>? _findCachedRecordRowByRestCandidate(String candidate) {
    final c = candidate.trim();
    if (c.isEmpty) return null;
    for (final r in _cachedFlatRecords) {
      if (CategoryServiceExtension.recordsTablePk(r) == c) return r;
      if ((r['record_id'] ?? '').toString().trim() == c) return r;
    }
    return null;
  }

  void _logRecordsPatchDispatch(String restId) {}

  void _logRecordsDeleteDispatch(String restId) {}

  /// PocketBase row `id` from a cached flat row — never a legacy UUID mistaken for REST id.
  String? _pbSystemIdFromCachedRecordRow(Map<String, dynamic> r) {
    final pb = r['_pb_record_id']?.toString().trim() ?? '';
    if (DatabaseService._isLikelyPocketBaseRowId(pb)) return pb;
    final idStr = r['id']?.toString().trim() ?? '';
    if (DatabaseService._isLikelyPocketBaseRowId(idStr)) return idStr;
    return null;
  }

  /// When UI still holds a [fields.record_id] UUID but REST needs wrapper [id], map to [CategoryServiceExtension.recordsTablePk].
  String? _resolveRecordsRestPathId(String candidate) {
    final c = candidate.trim();
    if (c.isEmpty) return null;
    for (final r in _cachedFlatRecords) {
      final rest = CategoryServiceExtension.recordsTablePk(r);
      if (rest.isNotEmpty &&
          rest == c &&
          DatabaseService._isLikelyPocketBaseRowId(rest)) {
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
    if (DatabaseService._isLikelyPocketBaseRowId(c)) return c;

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
    if (DatabaseService._isLikelyPocketBaseRowId(c)) return c;
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
    if (DatabaseService._isLikelyPocketBaseRowId(c)) return c;
    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
    } catch (_) {}
    final fromCache = _resolveRecordsRestPathId(c);
    if (fromCache != null &&
        fromCache.isNotEmpty &&
        DatabaseService._isLikelyPocketBaseRowId(fromCache)) {
      if (!DatabaseService._isLikelyPocketBaseRowId(c) && fromCache != c) {
        debugPrint(
          'ID TRANSLATION: Legacy UUID $c -> PocketBase ID $fromCache',
        );
      }
      if (fromCache != c) {
        DatabaseService._log(
          'REST_ID_RESOLVE: business/cache id "$c" -> Noco URL segment "$fromCache"',
        );
      }
      return fromCache;
    }
    final fromServer = await _fetchPbRecordSysIdByRecordIdField(c);
    if (fromServer != null && fromServer.isNotEmpty) {
      if (fromServer != c) {
        debugPrint(
          'ID TRANSLATION: Legacy UUID $c -> PocketBase ID $fromServer',
        );
      }
      return fromServer;
    }
    return c;
  }

  /// Records POST/PATCH category duality (@DATA_MAP): both fields are
  /// PocketBase **relation** ids → `categories.id` (15-char). Business slug is
  /// metadata only; never send slug alone into `records.category_id`.
  ({String businessId, String relationId})? _recordCategoryDualityForLocalId(
    int? localCategoryId,
  ) {
    if (!_planLocalCategoryIdIsConcrete(localCategoryId)) return null;
    final rule = getCategoryRuleById(localCategoryId!);
    if (rule == null || rule.isArchived) return null;
    final rel = _categoryBackendRowIdStrict(rule);
    if (rel == null ||
        rel.isEmpty ||
        !DatabaseService._isLikelyPocketBaseRowId(rel)) {
      return null;
    }
    // Prefer business slug when present; otherwise derive a stable non-empty key.
    // Relation id is the only value safe for records.category_id / category_link.
    var biz = _categoryStringPkForApi(rule);
    if (biz == null || biz.isEmpty || biz == 'uncategorized') {
      final slug = _slugifyCategoryDisplayName(rule.name);
      biz = slug.isNotEmpty ? slug : rel;
    }
    return (businessId: biz, relationId: rel);
  }

  int? _localCategoryIdFromRecordCategoryPayload(dynamic rawCat) {
    final key = rawCat?.toString().trim() ?? '';
    if (key.isEmpty) return null;
    var localId = int.tryParse(key);
    localId ??= findCategoryIdForStoredCategoryKey(key);
    if (localId == null &&
        DatabaseService._isLikelyPocketBaseRowId(key)) {
      localId = getCategoryRuleByBackendRowId(key)?.id;
    }
    return localId;
  }

  /// Normalize outgoing record category fields for PocketBase POST/PATCH.
  /// Returns false when no resolvable category relation id exists (caller may drop/reject).
  bool _normalizeRecordCategoryFieldsForPbApi(
    Map<String, dynamic> merged, {
    String? logBusinessId,
    bool allowFallback = true,
  }) {
    if (!merged.containsKey('category_id') &&
        !merged.containsKey('category_link')) {
      return true;
    }
    final recordBizId =
        logBusinessId ?? (merged['record_id'] ?? '').toString().trim();
    final beforeCat = merged['category_id'];
    final beforeLink = merged['category_link'];
    final oldCategory = beforeCat ?? beforeLink;

    var localId = _localCategoryIdFromRecordCategoryPayload(beforeCat);
    localId ??= _localCategoryIdFromRecordCategoryPayload(beforeLink);
    var resolvedBy = 'cache';

    if (localId != null &&
        _planLocalCategoryIdIsConcrete(localId) &&
        !_categoryIdResolvableForPbRecordPost(localId)) {
      localId = null;
    }

    if (localId == null || !_categoryIdResolvableForPbRecordPost(localId)) {
      if (!allowFallback) {
        merged.remove('category_id');
        merged.remove('category_link');
        return false;
      }
      final fallback = _resolveColdStartRecordCategoryId(localId);
      if (fallback == null || !_categoryIdResolvableForPbRecordPost(fallback)) {
        merged.remove('category_id');
        merged.remove('category_link');
        return false;
      }
      localId = fallback;
      resolvedBy = fallback == defaultCategoryId ? 'default' : 'fallback';
    }

    final pair = _recordCategoryDualityForLocalId(localId);
    if (pair == null) {
      merged.remove('category_id');
      merged.remove('category_link');
      return false;
    }

    merged['category_id'] = pair.relationId;
    merged['category_link'] = pair.relationId;

    final after = pair.relationId;
    if (beforeCat?.toString() != after || beforeLink?.toString() != after) {
      // ignore: avoid_print
      print(
        'RECORD_CATEGORY_NORMALIZED businessId=${recordBizId.isEmpty ? '-' : recordBizId} '
        'before=$oldCategory after=$after resolvedBy=$resolvedBy',
      );
      if (resolvedBy != 'cache' &&
          oldCategory != null &&
          oldCategory.toString().trim().isNotEmpty &&
          oldCategory.toString() != after) {
        // ignore: avoid_print
        print(
          'RECORD_OUTBOX_REPAIRED_CATEGORY businessId=${recordBizId.isEmpty ? '-' : recordBizId} '
          'oldCategory=$oldCategory newCategoryPbId=$after',
        );
      }
    }
    return true;
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

  /// True when [id] maps to a valid record category duality pair for outgoing POST/PATCH.
  bool _categoryIdResolvableForPbRecordPost(int? id) {
    return _recordCategoryDualityForLocalId(id) != null;
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

  /// Cold-start: prefer resolvable [preferred]; else [defaultCategoryId]; else first leaf.
  int? _resolveColdStartRecordCategoryId(int? preferred) {
    if (_categoryIdResolvableForPbRecordPost(preferred)) return preferred;

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
      DatabaseService._log('RECORDS_PB SKIP_PATCH: dead-letter 404 rid=$rid');
      _purgeGhostRecordById(rid.isNotEmpty ? rid : oq);
      return 404;
    }
    _requireAuthUserIdForWrite();
    var payloadForError = Map<String, dynamic>.from(fields);
    try {
      await ensurePocketBaseReady();
      final mergedRaw = Map<String, dynamic>.from(fields);
      mergedRaw['user_id'] = _pidForPbFilter;
      CategoryServiceExtension._mergeBusinessRecordIdIntoFields(
        mergedRaw,
        _findCachedRecordRowByRestCandidate(rid),
      );
      final merged = _recordsPatchFieldsJsonStrings(
        _nocoFieldsForPatch(mergedRaw),
      );
      _normalizeRecordCategoryFieldsForPbApi(merged);
      merged['user_id'] = _pidForPbFilter;
      payloadForError = merged;
      _logRecordsPatchDispatch(rid);
      final updated = await _pb
          .collection(PbCollections.records)
          .update(rid, body: merged);
      _upsertFlatRecordFromPbModel(updated, suppressTimelineNotify: true);
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
      debugPrint(
        '[ABORT_REASON] records PATCH failed inside try (before or after [DISPATCH]): $e',
      );
      DatabaseService._log(st.toString());
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
      DatabaseService._log('RECORDS_PB SKIP_DELETE: dead-letter rid=$rid');
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
    _lastRecordCreateFailureHttpCode = 0;
    try {
      await ensurePocketBaseReady();
      // DATA_MAP: identity is pb.authStore.model.id — in SDK 0.21 [model] aliases [record].
      final authRec = _pb.authStore.record;
      final authRowId = (authRec?.id ?? '').trim();
      if (authRowId.isEmpty) {
        throw AuthenticatedUserIdRequiredException();
      }
      final businessId = (rawFields['record_id'] ?? '').toString().trim();
      // ignore: avoid_print
      print(
        'RECORD_OUTBOX_CREATE_PAYLOAD op=create businessId=${businessId.isEmpty ? '-' : businessId} '
        'category_id=${rawFields['category_id']} category_link=${rawFields['category_link']} '
        'source_plan_id=${rawFields['source_plan_id']}',
      );
      final merged = _recordsPatchFieldsJsonStrings(
        _nocoFieldsForPatch(Map<String, dynamic>.from(rawFields)),
      );
      if (!_normalizeRecordCategoryFieldsForPbApi(
        merged,
        logBusinessId: businessId.isEmpty ? null : businessId,
      )) {
        _lastRecordCreateFailureHttpCode = 400;
        // ignore: avoid_print
        print(
          'PB_CREATE_ERROR_DETAILS: status=400 category relation not resolved '
          'rawCategory=${rawFields['category_id']}',
        );
        return null;
      }
      merged['user_id'] = authRowId;
      final created = await _pb
          .collection(PbCollections.records)
          .create(body: merged);
      _upsertFlatRecordFromPbModel(
        created,
        preserveExpand: false,
        suppressTimelineNotify: true,
      );
      return created.id;
    } on ClientException catch (e) {
      _lastRecordCreateFailureHttpCode = e.statusCode;
      // ignore: avoid_print
      print(
        'PB_CREATE_ERROR_DETAILS: status=${e.statusCode} ${e.response}',
      );
      DatabaseService._log('RECORDS_PB create failed: ${e.statusCode}');
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
      DatabaseService._log('RECORDS_PB create failed: $e');
      DatabaseService._log(st.toString());
      if (e is AuthenticatedUserIdRequiredException) {
        final loc = currentLocale.value;
        _brainSnackError(t(loc, 'error_record_create_unauthorized'));
      }
      return null;
    }
  }

  bool _rowStartWallDayIsProjectedToday(Map<String, dynamic> r) {
    try {
      final stUtc = CategoryServiceExtension._parseDateTimeUtc(r['start_time']);
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
      final stUtc = CategoryServiceExtension._parseDateTimeUtc(r['start_time']);
      if (stUtc == null) return false;
      return _timelineDeviceLocalDayKeyFromUtc(
            stUtc,
          ).compareTo(getTimelineDeviceLocalTodayDateKey()) <
          0;
    } catch (_) {
      return false;
    }
  }

  /// After [byPk] has today’s open rows, add up to [DatabaseService._sacredStaleOpenCap] **oldest** pre-today open
  /// rows from [rows] (singleton handoff for rare multi-day `running` without mass-PATCH).
  void _mergeSacredStaleOpenCandidates(
    List<Map<String, dynamic>> rows,
    Map<String, Map<String, dynamic>> byPk,
  ) {
    final stale = <Map<String, dynamic>>[];
    for (final r in rows) {
      if (_rowHasNonEmptyParent(r['parent_id'])) continue;
      if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r)) continue;
      if (_rowStartWallDayIsProjectedToday(r)) continue;
      if (!_rowStartWallDayIsBeforeProjectedToday(r)) continue;
      final id = CategoryServiceExtension.recordsTablePk(r);
      if (id.isEmpty) continue;
      if (byPk.containsKey(id)) continue;
      stale.add(r);
    }
    stale.sort((a, b) {
      final ta = CategoryServiceExtension._parseDateTimeUtc(a['start_time']);
      final tb = CategoryServiceExtension._parseDateTimeUtc(b['start_time']);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    var added = 0;
    for (final r in stale) {
      if (added >= DatabaseService._sacredStaleOpenCap) break;
      final id = CategoryServiceExtension.recordsTablePk(r);
      if (id.isEmpty) continue;
      byPk[id] = r;
      added++;
    }
    if (stale.isNotEmpty) {
      DatabaseService._log(
        'SACRED_LAW: stale pre-today open: merged $added of ${stale.length} candidate(s) (cap=$DatabaseService._sacredStaleOpenCap, oldest first)',
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
      final list = await _pb
          .collection(PbCollections.records)
          .getFullList(filter: 'user_id = "$uid" && status = "running"');
      return list.map(_recordMapFromPb).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fresh server map `pocketbase_row_id -> row` for **primary** rows in sacred running state.
  Future<Map<String, Map<String, dynamic>>>
  _fetchServerRunningSacredPrimariesByPbId() async {
    final rows = await _fetchRunningRecordsFromNoco();
    final byId = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      if (_rowHasNonEmptyParent(r['parent_id'])) continue;
      if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r)) continue;
      final id = CategoryServiceExtension.recordsTablePk(r);
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
    final handoff =
        CategoryServiceExtension._parseDateTimeUtc(handoffIsoUtc) ??
        DatabaseService.getPlanetaryNow().toUtc();
    final rowStart = CategoryServiceExtension._parseDateTimeUtc(serverRow['start_time']);
    final t = rowStart != null && handoff.isBefore(rowStart)
        ? rowStart
        : handoff;
    return t.toUtc().toIso8601String();
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
      if (prefs.getBool(DatabaseService._oneShotUntitledGhostCleanKey) ??
          false) {
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
        DatabaseService._log(
          'CLEAN_UNTITLED_GHOST: removed $removed local record cache row(s) (one-shot)',
        );
        _notifyTimelineAfterRecordCacheMutation();
      }
      await prefs.setBool(DatabaseService._oneShotUntitledGhostCleanKey, true);
    } catch (_) {}
  }
}
