part of '../database_service.dart';

extension RecordOutboxSyncExtension on DatabaseService {
  void _showRecordNotSavedError() =>
      AppSnack.show(t(currentLocale.value, 'record_create_not_saved'), error: true);

  Future<bool> _enqueueHighlanderStartMutation(
    Map<String, dynamic> runningFields, {
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized =
          jsonDecode(jsonEncode(runningFields)) as Map<String, dynamic>;
      final businessId = (normalized['record_id'] ?? '').toString().trim();
      if (businessId.isEmpty) return false;
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
      return true;
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE highlander: $e');
      return false;
    }
  }

  /// Child start is a local atomic handoff: the stops and create enter the
  /// same durable queue before their first network request.
  Future<bool> _stageChildRecordHandoff({
    required Map<String, dynamic> fields,
    required String startIso,
    String? parentRecordId,
    int? parentId,
  }) async {
    final bizId = (fields['record_id'] ?? '').toString().trim();
    if (bizId.isEmpty) return false;
    final beforeRows = List<Map<String, dynamic>>.from(_cachedFlatRecords);
    final nextRows = <Map<String, dynamic>>[];
    final stopItems = <Map<String, dynamic>>[];
    final pr = parentRecordId?.trim();
    for (final row in beforeRows) {
      var sameParent = false;
      if (pr != null && pr.isNotEmpty) {
        sameParent = _parentFieldEqualsRecordId(row, pr);
      } else if (parentId != null) {
        sameParent =
            CategoryServiceExtension._rowInt(row['parent_id']) == parentId;
      }
      if (!sameParent ||
          !CategoryServiceExtension._isNocoRowSacredStopTarget(row)) {
        nextRows.add(row);
        continue;
      }
      final id = CategoryServiceExtension.recordsTablePk(row);
      if (id.isEmpty) {
        nextRows.add(row);
        continue;
      }
      final biz = (row['record_id'] ?? '').toString().trim();
      stopItems.add(
        RecordMutationOutbox.newStopPatchItem(
          businessId: biz.isNotEmpty ? biz : id,
          pocketBaseId: id,
          originalQueryId: biz.isNotEmpty ? biz : id,
          endTimeIso: startIso,
        ),
      );
      nextRows.add(<String, dynamic>{
        ...row,
        'end_time': startIso,
        'status': 'stopped',
      });
    }
    _runBatchedRecordCacheTimelineNotifySync(() {
      _cachedFlatRecords = nextRows;
      _appendPendingRecordCreateShadow(fields);
    });
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await RecordMutationOutbox.enqueueAll(prefs, [
        ...stopItems,
        RecordMutationOutbox.newRecordCreateItem(
          businessId: bizId,
          fields: fields,
        ),
      ]);
      unawaited(offlineSync.refreshPendingCount());
      unawaited(flushPendingRecordMutations());
      return true;
    } catch (e) {
      DatabaseService._log('writeRecord child persistence failed: $e');
      if (_cachedFlatRecords.isNotEmpty &&
          _cachedFlatRecords.last['record_id'] == bizId) {
        _cachedFlatRecords = beforeRows;
        _notifyTimelineAfterRecordCacheMutation();
      }
      _showRecordNotSavedError();
      return false;
    }
  }

  Future<bool> _enqueueRecordCreateMutation(
    Map<String, dynamic> fields,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized = jsonDecode(jsonEncode(fields)) as Map<String, dynamic>;
      final businessId = (normalized['record_id'] ?? '').toString().trim();
      if (businessId.isEmpty) return false;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newRecordCreateItem(
          businessId: businessId,
          fields: normalized,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
      return true;
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE create: $e');
      return false;
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
    if (_recordMutationOutboxFlushInFlight || offlineSync.authPaused) return;
    _recordMutationOutboxFlushInFlight = true;
    offlineSync.setSyncing(true);
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      // Snapshot for iteration only. Never replace the whole queue afterwards:
      // new user writes can arrive while a PocketBase request is in flight.
      final pending = await RecordMutationOutbox.load(prefs);
      for (final item in pending) {
        final operationId = (item['operationId'] ?? '').toString().trim();
        if (operationId.isEmpty) {
          offlineSync.setLastError('record_outbox_missing_operation_id');
          break;
        }
        final ok = await _flushOneRecordOutboxEntry(item);
        if (ok) {
          await RecordMutationOutbox.acknowledge(prefs, operationId);
        } else {
          await RecordMutationOutbox.markFailure(
            prefs,
            operationId,
            error: offlineSync.lastError ?? 'sync_failed',
          );
          break;
        }
      }
      if ((await RecordMutationOutbox.load(prefs)).isEmpty) {
        offlineSync.clearErrors();
      }
    } finally {
      offlineSync.setSyncing(false);
      unawaited(offlineSync.refreshPendingCount());
      _recordMutationOutboxFlushInFlight = false;
    }
  }

  Future<bool> _flushOneRecordOutboxEntry(Map<String, dynamic> item) async {
    final kind = (item['kind'] ?? '').toString();
    if (kind == RecordMutationOutbox.kindRecordCreate) {
      final wrapped = item['payload'];
      if (wrapped is! Map) {
        offlineSync.setLastError('record_create_missing_payload');
        return false;
      }
      final payload = Map<String, dynamic>.from(wrapped);
      final failureCode = await _runRecordCreateServerPhase(payload);
      if (failureCode == null) return true;
      if (failureCode == 401 || failureCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $failureCode');
        return false;
      }
      offlineSync.setLastError('record_create HTTP $failureCode');
      return false;
    }
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
        offlineSync.setLastError('record_create_category_invalid');
        return false;
      }
      final failureCode = await _runHighlanderStartServerPhase(payload);
      if (failureCode == null) return true;
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
      offlineSync.setLastError('record_start HTTP $failureCode');
      DatabaseService.logSyncFlushFailure(
        collection: PbCollections.records,
        operation: RecordMutationOutbox.kindHighlanderStart,
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
        httpStatus: failureCode,
      );
      // Validation errors require repair; never silently erase user input.
      return false;
    }
    if (kind == RecordMutationOutbox.kindStopPatch) {
      final originalInput =
          (item['originalQueryId'] ?? item['businessId'] ?? '')
              .toString()
              .trim();
      final storedId = (item['pocketBaseId'] ?? '').toString().trim();
      final businessId = (item['businessId'] ?? originalInput).toString().trim();
      if (originalInput.isEmpty || businessId.isEmpty) {
        offlineSync.setLastError('record_stop_missing_identity');
        return false;
      }
      final pbId = await _resolveRecordPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: storedId,
      );
      if (pbId == null || pbId.isEmpty) {
        offlineSync.setLastError('record_stop_waiting_for_create');
        return false;
      }
      final storedPayload = item['payload'];
      final storedEnd = storedPayload is Map
          ? (storedPayload['end_time'] ?? '').toString().trim()
          : '';
      final stopIso = storedEnd.isNotEmpty
          ? storedEnd
          : DatabaseService.getPlanetaryNow().toUtc().toIso8601String();
      final stopFields = _nocoFieldsForPatch(<String, dynamic>{
        'end_time': stopIso,
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

  /// A read-before-retry makes a create with a stable business UUID idempotent,
  /// including when PocketBase committed a request but its response timed out.
  Future<RecordModel?> _existingRecordForCreate(String businessId) async {
    final userId = (_pb.authStore.record?.id ?? '').trim();
    if (userId.isEmpty) throw AuthenticatedUserIdRequiredException();
    final result = await _pb.collection(PbCollections.records).getList(
      page: 1,
      perPage: 1,
      filter:
          'user_id = "${_escapeForPbFilter(userId)}" && '
          'record_id = "${_escapeForPbFilter(businessId)}"',
    );
    return result.items.isEmpty ? null : result.items.first;
  }

  /// Plain creates (completed records and child records) do not stop primary
  /// records. A confirmed existing UUID is an acknowledgement, not a re-POST.
  Future<int?> _runRecordCreateServerPhase(
    Map<String, dynamic> payload,
  ) async {
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return 0;
      final businessId = (payload['record_id'] ?? '').toString().trim();
      if (businessId.isEmpty) return 400;
      final existing = await _existingRecordForCreate(businessId);
      if (existing != null) {
        _upsertFlatRecordFromPbModel(existing);
        return null;
      }
      final createdId = await _createRecordPb(payload);
      if (createdId == null || createdId.trim().isEmpty) {
        if (!_pb.authStore.isValid) return 401;
        return _lastRecordCreateFailureHttpCode > 0
            ? _lastRecordCreateFailureHttpCode
            : 0;
      }
      await _finalizeRecordCreateHandshake(pocketCreatedRecordId: createdId);
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
      } catch (_) {}
      _notifyTimelineAfterRecordCacheMutation();
      return null;
    } on ClientException catch (e) {
      return e.statusCode;
    } catch (e) {
      DatabaseService._log('record create replay failed: $e');
      return 0;
    }
  }

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
      final businessId = (runningFields['record_id'] ?? '').toString().trim();
      if (businessId.isEmpty) return 400;
      final existing = await _existingRecordForCreate(businessId);
      if (existing != null) {
        _upsertFlatRecordFromPbModel(existing);
        return null;
      }

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
