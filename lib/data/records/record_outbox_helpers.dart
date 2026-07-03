part of '../database_service.dart';

extension RecordOutboxSyncExtension on DatabaseService {
  Future<void> _enqueueHighlanderStartMutation(
    Map<String, dynamic> runningFields, {
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized =
          jsonDecode(jsonEncode(runningFields)) as Map<String, dynamic>;
      final businessId = (normalized['record_id'] ?? '').toString().trim();
      if (businessId.isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newHighlanderStartItem(
          businessId: businessId,
          runningFields: normalized,
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE highlander: $e');
    }
  }

  Future<void> _enqueueStopPatchMutation({
    required String originalInput,
    required String pocketBaseId,
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final businessId = _outboxBusinessIdForRecord(originalInput);
      if (businessId.isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newStopPatchItem(
          businessId: businessId,
          pocketBaseId: pocketBaseId.trim(),
          originalQueryId: originalInput.trim(),
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE stop: $e');
    }
  }

  String _outboxBusinessIdForRecord(String originalInput) {
    final id = originalInput.trim();
    if (id.isEmpty) return id;
    for (final row in _cachedFlatRecords) {
      final pk = CategoryServiceExtension.recordsTablePk(row);
      final biz = (row['record_id'] ?? '').toString().trim();
      if (pk == id || biz == id) {
        if (biz.isNotEmpty) return biz;
        return id;
      }
    }
    return id;
  }

  TimelineRecord? _timelineRecordFromCacheInput(String originalInput) {
    final idx = _indexOfCachedRecordRow(originalInput, originalInput);
    if (idx < 0) return null;
    final row = _cachedFlatRecords[idx];
    final sysId = CategoryServiceExtension.recordsTablePk(row);
    return TimelineRecord.fromMap(
      _rowToRecordMap(row),
      systemId: sysId.isNotEmpty ? sysId : originalInput,
      timezoneOffsetHours: _settings.timezoneOffsetHours,
    );
  }

  Future<void> _enqueueRecordUpdateMutation({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchFields,
    String? pocketBaseId,
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized =
          jsonDecode(jsonEncode(patchFields)) as Map<String, dynamic>;
      if (businessId.trim().isEmpty || normalized.isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newRecordUpdateItem(
          businessId: businessId.trim(),
          patchFields: normalized,
          pocketBaseId: pocketBaseId?.trim(),
          originalQueryId: originalInput.trim(),
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE update: $e');
    }
  }

  Future<void> _enqueueRecordDeleteMutation({
    required String originalInput,
    required String businessId,
    String? pocketBaseId,
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (businessId.trim().isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newRecordDeleteItem(
          businessId: businessId.trim(),
          pocketBaseId: pocketBaseId?.trim(),
          originalQueryId: originalInput.trim(),
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE delete: $e');
    }
  }
  Future<String?> _resolveRecordPbIdForOutboxReplay({
    required String businessId,
    String? pocketBaseId,
  }) async {
    final stored = pocketBaseId?.trim();
    if (stored != null &&
        stored.isNotEmpty &&
        DatabaseService._isLikelyPocketBaseRowId(stored)) {
      return stored;
    }
    final cached = _tryResolveRecordIdFromCacheOnly(businessId);
    if (cached != null &&
        cached.isNotEmpty &&
        DatabaseService._isLikelyPocketBaseRowId(cached)) {
      return cached;
    }
    try {
      final resolved = await _resolveRecordIdForStopOrDelete(businessId);
      if (DatabaseService._isLikelyPocketBaseRowId(resolved)) return resolved;
    } catch (_) {}
    return null;
  }
  Future<void> flushPendingRecordMutations() async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (_recordMutationOutboxFlushInFlight) return;
    if (offlineSync.authPaused) return;
    _recordMutationOutboxFlushInFlight = true;
    offlineSync.setSyncing(true);
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final q = await RecordMutationOutbox.load(prefs);
      if (q.isEmpty) return;
      var pendingTail = const <Map<String, dynamic>>[];
      var i = 0;
      for (; i < q.length; i++) {
        final item = Map<String, dynamic>.from(q[i]);
        final ok = await _flushOneRecordOutboxEntry(item);
        if (!ok) {
          item['retryCount'] = ((item['retryCount'] as num?)?.toInt() ?? 0) + 1;
          item['lastError'] = offlineSync.lastError ?? 'sync_failed';
          pendingTail = [item, ...q.sublist(i + 1)];
          break;
        }
      }
      if (pendingTail.isEmpty && i >= q.length) {
        await RecordMutationOutbox.replaceAll(prefs, []);
        offlineSync.clearErrors();
      } else if (pendingTail.isNotEmpty) {
        await RecordMutationOutbox.replaceAll(prefs, pendingTail);
      } else {
        await RecordMutationOutbox.replaceAll(prefs, q.sublist(i));
      }
    } finally {
      offlineSync.setSyncing(false);
      unawaited(offlineSync.refreshPendingCount());
      _recordMutationOutboxFlushInFlight = false;
    }
  }

  Future<bool> _flushOneRecordOutboxEntry(Map<String, dynamic> item) async {
    final kind = (item['kind'] ?? '').toString();
    if (kind == RecordMutationOutbox.kindHighlanderStart) {
      final wrapped = item['payload'];
      if (wrapped is! Map) return true;
      final payload = Map<String, dynamic>.from(wrapped);
      final businessId = (item['businessId'] ?? payload['record_id'] ?? '')
          .toString()
          .trim();
      // ignore: avoid_print
      print(
        'RECORD_OUTBOX_CREATE_PAYLOAD op=highlander_start '
        'businessId=${businessId.isEmpty ? '-' : businessId} '
        'category_id=${payload['category_id']} category_link=${payload['category_link']} '
        'source_plan_id=${payload['source_plan_id']}',
      );
      if (!_normalizeRecordCategoryFieldsForPbApi(
        payload,
        logBusinessId: businessId.isEmpty ? null : businessId,
      )) {
        // ignore: avoid_print
        print(
          'RECORD_OUTBOX_DROPPED_INVALID_CATEGORY '
          'businessId=${businessId.isEmpty ? '-' : businessId} '
          'reason=category_relation_not_resolved',
        );
        return true;
      }
      final failureCode = await _runHighlanderStartServerPhase(payload);
      if (failureCode == null) {
        clearOptimisticTimelineUi(notifyTimeline: false);
        return true;
      }
      if (failureCode == 401 || failureCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $failureCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(failureCode)) {
        offlineSync.setLastError('HTTP $failureCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindHighlanderStart,
          businessId: businessId,
          pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
          httpStatus: failureCode,
        );
        return false;
      }
      DatabaseService.logSyncFlushFailure(
        collection: PbCollections.records,
        operation: RecordMutationOutbox.kindHighlanderStart,
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
        httpStatus: failureCode,
      );
      return true;
    }
    if (kind == RecordMutationOutbox.kindStopPatch) {
      final originalInput =
          (item['originalQueryId'] ?? item['businessId'] ?? '')
              .toString()
              .trim();
      final pbId = (item['pocketBaseId'] ?? '').toString().trim();
      if (originalInput.isEmpty || pbId.isEmpty) return true;
      final nowIso = DatabaseService.getPlanetaryNow()
          .toUtc()
          .toIso8601String();
      final stopFields = _nocoFieldsForPatch(<String, dynamic>{
        'end_time': nowIso,
        'status': 'stopped',
      });
      final stopCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: pbId,
        fields: stopFields,
      );
      if (stopCode == 404) {
        _purgeGhostRecordById(pbId);
        _clearOptimisticStopKeysForRecord(originalInput);
        return true;
      }
      if (stopCode >= 200 && stopCode < 300) {
        _clearOptimisticStopKeysForRecord(originalInput);
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return true;
      }
      if (stopCode == 401 || stopCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $stopCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(stopCode)) {
        offlineSync.setLastError('HTTP $stopCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindStopPatch,
          businessId: originalInput,
          pocketBaseId: pbId,
          httpStatus: stopCode,
        );
        return false;
      }
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    }
    if (kind == RecordMutationOutbox.kindRecordUpdate) {
      final wrapped = item['payload'];
      if (wrapped is! Map) return true;
      final updates = Map<String, dynamic>.from(wrapped);
      if (updates.isEmpty) return true;
      final businessId = _bizKey(item);
      final originalInput = (item['originalQueryId'] ?? businessId)
          .toString()
          .trim();
      final pbId = await _resolveRecordPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
      );
      if (pbId == null || pbId.isEmpty) {
        final cached = _tryResolveRecordIdFromCacheOnly(businessId);
        if (cached == null || cached.isEmpty) {
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.records,
            operation: RecordMutationOutbox.kindRecordUpdate,
            businessId: businessId,
            message: 'dropped_stale_no_cache',
          );
          return true;
        }
        offlineSync.setLastError('resolve_failed:records/update');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindRecordUpdate,
          businessId: businessId,
          message: 'unresolved_pb_id',
        );
        return false;
      }
      final patchCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: pbId,
        fields: _nocoFieldsForPatch(updates),
      );
      if (patchCode == 404) {
        _purgeGhostRecordById(pbId);
        return true;
      }
      if (patchCode >= 200 && patchCode < 300) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return true;
      }
      if (patchCode == 401 || patchCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $patchCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(patchCode)) {
        offlineSync.setLastError('HTTP $patchCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindRecordUpdate,
          businessId: businessId,
          pocketBaseId: pbId,
          httpStatus: patchCode,
        );
        return false;
      }
      return true;
    }
    if (kind == RecordMutationOutbox.kindRecordDelete) {
      final businessId = _bizKey(item);
      final originalInput = (item['originalQueryId'] ?? businessId)
          .toString()
          .trim();
      final pbId = await _resolveRecordPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
      );
      if (pbId == null || pbId.isEmpty) {
        return true;
      }
      final delCode = await _deleteRecordsRowWithFallback(
        originalQueryId: originalInput,
        restId: pbId,
      );
      if (delCode == 404) {
        _purgeGhostRecordById(pbId);
        return true;
      }
      if (delCode >= 200 && delCode < 300) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return true;
      }
      if (delCode == 401 || delCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $delCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(delCode)) {
        offlineSync.setLastError('HTTP $delCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindRecordDelete,
          businessId: businessId,
          pocketBaseId: pbId,
          httpStatus: delCode,
        );
        return false;
      }
      return true;
    }
    return true;
  }

  String _bizKey(Map<String, dynamic> item) =>
      (item['businessId'] ?? '').toString().trim();

  /// Highlander server phase (PATCH old + POST new). Returns **null** on success, HTTP/synthetic code on failure.
  Future<int?> _runHighlanderStartServerPhase(
    Map<String, dynamic> runningFields,
  ) async {
    try {
      final sp = runningFields['source_plan_id'];
      if (sp != null) {
        final planId =
            DatabaseService.pocketRelationIdOrNull(sp.toString()) ??
            sp.toString().trim();
        if (planId.isNotEmpty) {
          final pc = await _resolveCategoryIdFromSourcePlanPbId(planId);
          if (_planLocalCategoryIdIsConcrete(pc)) {
            final resolved = _resolveColdStartRecordCategoryId(pc);
            if (_categoryIdResolvableForPbRecordPost(resolved)) {
              final pair = _recordCategoryDualityForLocalId(resolved);
              if (pair != null) {
                runningFields['category_id'] = pair.relationId;
                runningFields['category_link'] = pair.relationId;
              }
            }
          }
        }
      }
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return 0;

      _recordCacheTimelineNotifyBatchDepth++;
      try {
        final handoffIso = (runningFields['start_time'] ?? '')
            .toString()
            .trim();
        if (handoffIso.isEmpty) {
          return 500;
        }
        final serverPrimaries =
            await _fetchServerRunningSacredPrimariesByPbId();
        if (serverPrimaries.isEmpty) {
          DatabaseService._log(
            'SACRED_PREFLIGHT: no running primaries on server (POST new only)',
          );
        } else {
          DatabaseService._log(
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
            return code;
          }
        }
        final createdId = await _createRecordPb(runningFields);
        if (createdId == null || createdId.trim().isEmpty) {
          if (!_pb.authStore.isValid) return 401;
          final last = _lastRecordCreateFailureHttpCode;
          if (last > 0) return last;
          return 500;
        }
        await _finalizeRecordCreateHandshake(pocketCreatedRecordId: createdId);
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return null;
      } finally {
        _recordCacheTimelineNotifyBatchDepth--;
      }
    } on ClientException catch (e) {
      return e.statusCode;
    } catch (e) {
      DatabaseService._log('HIGHLANDER server phase failed: $e');
      return 0;
    }
  }

  /// Highlander server phase (PATCH old + POST new). Runs **after** local shadow; may log [DISPATCH].
  Future<void> _highlanderPrimaryServerSync({
    required _HighlanderRollbackToken? rollbackToken,
    required Map<String, dynamic> runningFields,
  }) async {
    final failureCode = await _runHighlanderStartServerPhase(runningFields);
    if (failureCode == null) {
      clearOptimisticTimelineUi(notifyTimeline: false);
      unawaited(offlineSync.refreshPendingCount());
      return;
    }
    if (failureCode == 401 || failureCode == 403) {
      await _enqueueHighlanderStartMutation(
        runningFields,
        error: failureCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $failureCode');
      final loc = currentLocale.value;
      final msg = failureCode == 401
          ? t(loc, 'error_record_create_unauthorized')
          : t(loc, 'error_record_create_forbidden');
      _brainSnackError(msg);
      return;
    }
    if (_recordMutationRetriableHttpCode(failureCode)) {
      await _enqueueHighlanderStartMutation(runningFields, error: failureCode);
      offlineSync.setConnectivityOffline(true);
      return;
    }
    DatabaseService._log('HIGHLANDER server phase failed: HTTP $failureCode');
    await _runBatchedRecordCacheTimelineNotify(() async {
      _restoreHighlanderRollbackToken(rollbackToken);
      clearOptimisticTimelineUi();
      _printAtomicCheckRunningCount();
    });
    AppSnack.failed();
  }
}
