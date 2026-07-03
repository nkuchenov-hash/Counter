part of '../database_service.dart';

extension RecordOverlapExtension on DatabaseService {
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
    final nowIso = DatabaseService.getPlanetaryNow().toUtc().toIso8601String();
    final next = <Map<String, dynamic>>[];
    for (final row in _cachedFlatRecords) {
      final copy = Map<String, dynamic>.from(row);
      final st = (copy['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'running') {
        final pk = CategoryServiceExtension.recordsTablePk(copy);
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
      DatabaseService._log(
        'HIGHLANDER: createBody missing record_id — aborting local append',
      );
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
  Map<String, dynamic>? _canonicalPrimaryRunningFlatRow() {
    final pend = _optimisticPendingStartRecordMap;
    if (pend != null &&
        pend['endTime'] == null &&
        CategoryServiceExtension.isRecordMapActuallyRunning(pend)) {
      return Map<String, dynamic>.from(pend);
    }
    Map<String, dynamic>? winner;
    DateTime? bestStart;
    for (final r in _cachedFlatRecords) {
      if (_rowHasNonEmptyParent(r['parent_id'])) continue;
      final merged = _mergeOptimisticIntoRecordMap(_rowToRecordMap(r));
      if (!CategoryServiceExtension.isRecordMapActuallyRunning(merged)) {
        continue;
      }
      final st = CategoryServiceExtension.startTimeFromRecord(merged);
      if (winner == null ||
          (st != null && (bestStart == null || st.isAfter(bestStart)))) {
        winner = merged;
        bestStart = st;
      }
    }
    return winner;
  }

  String? _businessIdFromCanonicalRunningRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final biz = (row['record_id'] ?? '').toString().trim();
    if (biz.isNotEmpty) return biz;
    final sys = (row['id'] ?? '').toString().trim();
    return sys.isEmpty ? null : sys;
  }

  /// One scan of [_cachedFlatRecords] for the newest primary running row id.
  String? resolveCanonicalPrimaryRunningBusinessId() {
    if (!_canonicalRunningBusinessIdCacheDirty) {
      return _cachedCanonicalRunningBusinessId;
    }
    _syncCanonicalRunningBusinessIdCache('resolve');
    return _cachedCanonicalRunningBusinessId;
  }

  String? get canonicalPrimaryRunningBusinessId =>
      resolveCanonicalPrimaryRunningBusinessId();

  void _resetCanonicalRunningBusinessIdCache() {
    _canonicalRunningBusinessIdCacheDirty = true;
    _cachedCanonicalRunningBusinessId = null;
  }

  /// Recompute running business id once (outside per-row VM loop).
  void _syncCanonicalRunningBusinessIdCache(String reason) {
    _cachedCanonicalRunningBusinessId =
        _businessIdFromCanonicalRunningRow(_canonicalPrimaryRunningFlatRow());
    _canonicalRunningBusinessIdCacheDirty = false;
  }

  /// Sacred singleton: if multiple primaries are open, keep newest and stop older rows.
  Future<void> _reconcileDuplicatePrimaryRunningRecords() async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;
    final primaries = <Map<String, dynamic>>[];
    for (final row in _cachedFlatRecords) {
      if (_rowHasNonEmptyParent(row['parent_id'])) continue;
      if (!CategoryServiceExtension._isNocoRowActiveRunning(row)) continue;
      primaries.add(row);
    }
    if (primaries.length <= 1) return;

    primaries.sort((a, b) {
      final ast = CategoryServiceExtension._parseDateTimeUtc(a['start_time']);
      final bst = CategoryServiceExtension._parseDateTimeUtc(b['start_time']);
      if (ast == null && bst == null) return 0;
      if (ast == null) return 1;
      if (bst == null) return -1;
      return bst.compareTo(ast);
    });

    final now = DatabaseService.getPlanetaryNow();
    for (var i = 1; i < primaries.length; i++) {
      final loser = primaries[i];
      final pk = CategoryServiceExtension.recordsTablePk(loser);
      final biz = (loser['record_id'] ?? '').toString().trim();
      for (final k in [pk, biz]) {
        if (k.isNotEmpty) {
          _optimisticEndByKey[k] = _OptimisticEndPatch(now);
        }
      }
      if (pk.isNotEmpty) {
        unawaited(stopRecordByDocId(pk));
      }
    }
    _notifyTimelineAfterRecordCacheMutation();
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
        final sys =
            (data['backendNumericId'] ?? data['nocoSystemId'])
                ?.toString()
                .trim() ??
            '';
        final matches =
            q == biz ||
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
      if (data['nocoSystemId'] != null) data['nocoSystemId'].toString().trim(),
      if (data['docId'] != null && data['docId'] != 0)
        data['docId'].toString().trim(),
    }.where((s) => s.isNotEmpty).toSet();
    for (final c in candidates) {
      if (excludeKeys.contains(c)) return true;
    }
    return false;
  }

  /// Synchronous overlap probe on warm cache — safe before optimistic UI apply.
  Map<String, dynamic>? findFirstOverlappingRecordInCache(
    DateTime start,
    DateTime end, {
    String? excludeRecordId,
  }) {
    try {
      final now = DatabaseService.getPlanetaryNow();
      final excludeKeys =
          excludeRecordId == null || excludeRecordId.trim().isEmpty
          ? <String>{}
          : _excludeOverlapIdentityKeys(excludeRecordId);
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        final data = _rowToRecordMap(row);
        if (_recordMapOverlapsExcludeKeys(data, excludeKeys)) continue;
        final otherStart = CategoryServiceExtension.startTimeFromRecord(data);
        if (otherStart == null) continue;
        final otherEnd =
            CategoryServiceExtension.endTimeFromRecord(data) ?? now;
        if (_rangesOverlap(start, end, otherStart, otherEnd)) return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> findFirstOverlappingRecord(
    DateTime start,
    DateTime end, {
    String? excludeRecordId,
  }) async {
    try {
      final rows = await getRecords();
      final now = DatabaseService.getPlanetaryNow();
      final excludeKeys =
          excludeRecordId == null || excludeRecordId.trim().isEmpty
          ? <String>{}
          : _excludeOverlapIdentityKeys(excludeRecordId);
      for (final row in rows) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        final data = _rowToRecordMap(row);
        if (_recordMapOverlapsExcludeKeys(data, excludeKeys)) continue;
        final otherStart = CategoryServiceExtension.startTimeFromRecord(data);
        if (otherStart == null) continue;
        final otherEnd =
            CategoryServiceExtension.endTimeFromRecord(data) ?? now;
        if (_rangesOverlap(start, end, otherStart, otherEnd)) return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _rangesOverlap(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
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
  Future<bool> stopAllRunningRecords() async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    try {
      final nowIso = DatabaseService.getPlanetaryNow()
          .toUtc()
          .toIso8601String();
      final byPk = <String, Map<String, dynamic>>{};
      var serverOk = false;

      try {
        final serverRows = await _fetchRunningRecordsFromNoco();
        serverOk = true;
        for (final r in serverRows) {
          if (_rowHasNonEmptyParent(r['parent_id'])) continue;
          if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r)) continue;
          if (!_rowStartWallDayIsProjectedToday(r)) continue;
          final id = CategoryServiceExtension.recordsTablePk(r);
          if (id.isEmpty) continue;
          byPk[id] = r;
        }
        final todayOnly = byPk.length;
        _mergeSacredStaleOpenCandidates(serverRows, byPk);
        if (serverRows.isNotEmpty) {
          DatabaseService._log(
            'SACRED_LAW: server running=${serverRows.length} -> today=$todayOnly total_stop_candidates=${byPk.length}',
          );
        }
      } catch (e) {
        DatabaseService._log(
          'SACRED_LAW: server running-query failed ($e); using cache merge',
        );
      }

      if (!serverOk) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
          final local = _cachedFlatRecords;
          for (final r in local) {
            if (_rowHasNonEmptyParent(r['parent_id'])) continue;
            if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r)) {
              continue;
            }
            if (!_rowStartWallDayIsProjectedToday(r)) continue;
            final id = CategoryServiceExtension.recordsTablePk(r);
            if (id.isEmpty) continue;
            byPk[id] = r;
          }
          _mergeSacredStaleOpenCandidates(local, byPk);
        } catch (e) {
          DatabaseService._log('SACRED_LAW: cache merge failed ($e)');
        }
      }

      DatabaseService._log(
        'SACRED_LAW: PocketBase per-row stop ${byPk.length} record(s)',
      );
      for (final id in byPk.keys) {
        final row = byPk[id];
        if (row == null) continue;
        DatabaseService._log('PATCH_ID_TRACE: stopAllRunningRecords pb id=$id');
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
          DatabaseService._log(
            'STOP_SWITCH_ABORT: failed to stop record id=$id status=$code',
          );
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
        DatabaseService._log('writeCompletedRecord: no resolvable category_id');
        AppSnack.failed();
        return false;
      }
      final newId = await _createRecordPb(<String, dynamic>{
        'user_id': _pidForPbFilter,
        'record_id': DatabaseService._newClientRecordUuid(),
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
        DatabaseService._log('writeCompletedRecord PocketBase create failed');
        return false;
      }
      await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (e, st) {
      DatabaseService._log('writeCompletedRecord failed: $e');
      DatabaseService._log(st);
      return false;
    } finally {
      _writeRecordMutationInFlight = false;
    }
  }
}
