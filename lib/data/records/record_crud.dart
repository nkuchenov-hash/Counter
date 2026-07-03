part of '../database_service.dart';

extension RecordCrudExtension on DatabaseService {
  Future<Map<String, dynamic>> _buildRecordPatchUpdates({
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
  }) async {
    var categoryForPatch = categoryId;
    var shouldPatchCategory = categoryId != null;
    if (syncSourcePlan && !clearSourcePlan) {
      final sp0 = DatabaseService.pocketRelationIdOrNull(
        sourcePlanPocketRecordId,
      );
      if (sp0 != null) {
        final pc = await _resolveCategoryIdFromSourcePlanPbId(sp0);
        if (_planLocalCategoryIdIsConcrete(pc)) {
          categoryForPatch = pc;
          shouldPatchCategory = true;
        }
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
      updates['category_id'] = _recordCategoryBusinessPkForApi(
        categoryForPatch,
      );
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
        final sp = DatabaseService.pocketRelationIdOrNull(
          sourcePlanPocketRecordId,
        );
        if (sp != null) updates['source_plan_id'] = sp;
      }
    }
    return updates;
  }

  Future<bool> _patchRecordUpdateNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
    required Map<String, dynamic> updates,
    Map<String, dynamic>? rollbackRow,
    int rollbackIndex = -1,
  }) async {
    DatabaseService._log('PATCH_ID_TRACE: record update pb id=$resolvedPbId');
    final patchCode = await _patchRecordsRowWith404Recovery(
      originalQueryId: originalInput,
      restId: resolvedPbId,
      fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
    );
    if (patchCode == 404) {
      if (rollbackRow != null && rollbackIndex >= 0) {
        _cachedFlatRecords[rollbackIndex] = rollbackRow;
        _notifyTimelineAfterRecordCacheMutation();
      }
      _purgeGhostRecordById(resolvedPbId);
      await _fetchRecordsIntoCache(forceNetwork: true);
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.failed();
      return false;
    }
    if (patchCode >= 200 && patchCode < 300) {
      _notifyTimelineAfterRecordCacheMutation();
      unawaited(offlineSync.refreshPendingCount());
      return true;
    }
    if (patchCode == 401 || patchCode == 403) {
      await _enqueueRecordUpdateMutation(
        originalInput: originalInput,
        businessId: businessId,
        patchFields: updates,
        pocketBaseId: resolvedPbId,
        error: patchCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $patchCode');
      final loc = currentLocale.value;
      final msg = patchCode == 401
          ? t(loc, 'error_record_create_unauthorized')
          : t(loc, 'error_record_create_forbidden');
      _brainSnackError(msg);
      return true;
    }
    if (_recordMutationRetriableHttpCode(patchCode)) {
      await _enqueueRecordUpdateMutation(
        originalInput: originalInput,
        businessId: businessId,
        patchFields: updates,
        pocketBaseId: resolvedPbId,
        error: patchCode,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    }
    if (rollbackRow != null && rollbackIndex >= 0) {
      _cachedFlatRecords[rollbackIndex] = rollbackRow;
      _notifyTimelineAfterRecordCacheMutation();
    }
    AppSnack.failed();
    return false;
  }

  Future<bool> _deleteRecordNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
    required Set<String> delKeys,
  }) async {
    DatabaseService._log('DELETE_ID_TRACE: deleteRecord pb id=$resolvedPbId');
    final delCode = await _deleteRecordsRowWithFallback(
      originalQueryId: originalInput,
      restId: resolvedPbId,
    );
    if (delCode == 404) {
      _purgeGhostRecordById(resolvedPbId);
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    }
    final ok = delCode >= 200 && delCode < 300;
    if (ok) {
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
      } catch (_) {}
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.deleted();
      unawaited(offlineSync.refreshPendingCount());
      return true;
    }
    if (delCode == 401 || delCode == 403) {
      await _enqueueRecordDeleteMutation(
        originalInput: originalInput,
        businessId: businessId,
        pocketBaseId: resolvedPbId,
        error: delCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $delCode');
      _snackDeleteHttpFailure(delCode);
      return true;
    }
    if (_recordMutationRetriableHttpCode(delCode)) {
      await _enqueueRecordDeleteMutation(
        originalInput: originalInput,
        businessId: businessId,
        pocketBaseId: resolvedPbId,
        error: delCode,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    }
    for (final k in delKeys) {
      _optimisticDeletedKeys.remove(k);
    }
    _notifyTimelineAfterRecordCacheMutation();
    _snackDeleteHttpFailure(delCode);
    return false;
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
      final sourcePlanForPayloadEarly = !((parentRecordId?.trim().isNotEmpty ?? false) || parentId != null)
          ? DatabaseService.pocketRelationIdOrNull(sourcePlanPocketRecordId)
          : null;
      int? cid = categoryId;
      if (sourcePlanForPayloadEarly != null) {
        final planCat = resolveCurrentPlanCategoryForRecordStart(
          sourcePlanPocketRecordId: sourcePlanForPayloadEarly,
          uiCategoryId: categoryId,
        );
        if (_planLocalCategoryIdIsConcrete(planCat)) {
          cid = planCat;
        }
      }
      if (sourcePlanForPayloadEarly == null ||
          !_planLocalCategoryIdIsConcrete(cid)) {
        cid = identifyCategory(parsed.title)?.id ?? cid;
        cid = _resolveRecordCategoryIdWithSmartLink(parsed.title, cid);
        if (!_planLocalCategoryIdIsConcrete(cid)) {
          final inferred = _smartInferCategoryId(parsed.title);
          if (_planLocalCategoryIdIsConcrete(inferred)) {
            cid = inferred;
          }
        }
      }
      cid = _resolveColdStartRecordCategoryId(cid);
      if (!_categoryIdResolvableForPbRecordPost(cid)) {
        DatabaseService._log(
          'writeRecord: cold-start could not resolve category_id',
        );
        AppSnack.failed();
        return null;
      }
      final now = DatabaseService.getPlanetaryNow();
      final start = explicitStartTime ?? now;
      final isStartingNow = explicitStartTime != null;
      final status = isStartingNow
          ? 'running'
          : (dateKey == _todayKey ? 'running' : 'completed');
      DateTime? endTime = isStartingNow
          ? null
          : (dateKey == _todayKey ? null : start);
      final startIso = start.toUtc().toIso8601String();
      final pr = parentRecordId?.trim();
      final hasParent = (pr != null && pr.isNotEmpty) || parentId != null;
      final sourcePlanForPayload = !hasParent
          ? DatabaseService.pocketRelationIdOrNull(sourcePlanPocketRecordId)
          : null;
      // Plan category from PocketBase must not run before primary Highlander shadow (§9 main thread).
      if (status == 'running') {
        final isPrimary = !hasParent;
        late final String runningRecordBizId;
        if (isPrimary) {
          runningRecordBizId = DatabaseService._newClientRecordUuid();
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
            'source_plan_id': ?sourcePlanForPayload,
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
            unawaited(() async {
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
            }());
            return runningRecordBizId;
          } catch (e, st) {
            DatabaseService._log(
              'writeRecord primary Highlander local phase: $e',
            );
            DatabaseService._log(st.toString());
            clearOptimisticTimelineUi();
            if (!netDone.isCompleted) netDone.complete();
            rethrow;
          }
        }
        runningRecordBizId = DatabaseService._newClientRecordUuid();
        final rows = List<Map<String, dynamic>>.from(_cachedFlatRecords);
        for (final r in rows) {
          var sameParent = false;
          if (pr != null && pr.isNotEmpty) {
            sameParent = _parentFieldEqualsRecordId(r, pr);
          } else if (parentId != null) {
            sameParent =
                CategoryServiceExtension._rowInt(r['parent_id']) == parentId;
          }
          if (!sameParent) continue;
          if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r)) continue;
          final id = CategoryServiceExtension.recordsTablePk(r);
          if (id.isEmpty) continue;
          DatabaseService._log('PATCH_ID_TRACE: child-stop pb id=$id');
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
          'source_plan_id': ?sourcePlanForPayload,
        });
        if (pr != null && pr.isNotEmpty) {
          runningFields['parent_id'] = pr;
        } else if (parentId != null) {
          runningFields['parent_id'] = parentId.toString();
        }
        final newId = await _createRecordPb(runningFields);
        if (newId == null) {
          DatabaseService._log('writeRecord PocketBase create failed');
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
          DatabaseService._log(
            'writeRecord completed branch: cold-start could not resolve category_id',
          );
          AppSnack.failed();
          return null;
        }
        final completedFields = _nocoFieldsForPatch(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'record_id': DatabaseService._newClientRecordUuid(),
          'status': 'completed',
          'title': parsed.title,
          'start_time': startIso,
          'end_time': endTime?.toUtc().toIso8601String(),
          'category_id': _recordCategoryBusinessPkForApi(cidForCompleted),
          'type': 'record',
          'checklist': <Map<String, dynamic>>[],
          if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
          'source_plan_id': ?sourcePlanForPayload,
        });
        if (pr != null && pr.isNotEmpty) {
          completedFields['parent_id'] = pr;
        } else if (parentId != null) {
          completedFields['parent_id'] = parentId.toString();
        }
        final newId = await _createRecordPb(completedFields);
        if (newId == null) {
          DatabaseService._log(
            'writeRecord PocketBase create failed (completed branch)',
          );
          return null;
        }
        await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
        _notifyTimelineAfterRecordCacheMutation();
        return newId;
      }
    } catch (e, st) {
      DatabaseService._log('writeRecord failed: $e');
      DatabaseService._log(st);
      final isChildPost =
          (parentRecordId?.trim().isNotEmpty ?? false) || parentId != null;
      if (!isChildPost) {
        clearOptimisticTimelineUi();
      }
      return null;
    } finally {
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
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return;
    final resolved =
        _tryResolveRecordIdFromCacheOnly(originalInput) ?? originalInput;
    final idx = _indexOfCachedRecordRow(resolved, originalInput);
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
      final sp = DatabaseService.pocketRelationIdOrNull(
        sourcePlanPocketRecordId,
      );
      if (sp != null) {
        final ic = _tryResolveCategoryIdFromSourcePlanPbIdSync(sp);
        if (_planLocalCategoryIdIsConcrete(ic)) {
          resolvedCategoryId = ic;
          shouldWriteCategory = true;
        }
      }
    }
    if (shouldWriteCategory && resolvedCategoryId != null) {
      _applyLocalRecordCategoryDualityToRow(row, resolvedCategoryId);
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
        final sp = DatabaseService.pocketRelationIdOrNull(
          sourcePlanPocketRecordId,
        );
        if (sp != null) row['source_plan_id'] = sp;
      }
    }
    _notifyTimelineAfterRecordCacheMutation();
  }

  String? _cachedRecordSourcePlanId(Map<String, dynamic> row) {
    final raw =
        normalizeLinkScalar(row['source_plan_id']) ?? row['source_plan_id'];
    return DatabaseService.pocketRelationIdOrNull(raw?.toString());
  }

  void _applyLocalRecordCategoryDualityToRow(
    Map<String, dynamic> row,
    int categoryId,
  ) {
    final pair = _recordCategoryDualityForLocalId(categoryId);
    if (pair == null) {
      row.remove('category_id');
      row.remove('category_link');
      row.remove('_expanded_category');
      return;
    }
    row['category_id'] = pair.businessId;
    row['category_link'] = pair.relationId;
    row['_expanded_category'] = <String, dynamic>{
      'id': pair.relationId,
      'category_id': pair.businessId,
    };
  }

  void _applyCachedRecordCategoryAt(int index, int categoryId) {
    if (index < 0 || index >= _cachedFlatRecords.length) return;
    _applyLocalRecordCategoryDualityToRow(_cachedFlatRecords[index], categoryId);
  }

  void _propagatePlanAutoCategoryToLoadedLinkedRecords({
    required String planPocketId,
    required int oldCategoryId,
    required int newCategoryId,
  }) {
    final planId = DatabaseService.pocketRelationIdOrNull(planPocketId);
    if (planId == null) return;
    if (!_planLocalCategoryIdIsConcrete(oldCategoryId) ||
        !_planLocalCategoryIdIsConcrete(newCategoryId) ||
        oldCategoryId == newCategoryId) {
      return;
    }
    final targets =
        <
          ({
            int index,
            String originalInput,
            String businessId,
            String? pbId,
            Map<String, dynamic> rollback,
          })
        >[];
    for (var i = 0; i < _cachedFlatRecords.length; i++) {
      final row = _cachedFlatRecords[i];
      if (_cachedRecordSourcePlanId(row) != planId) continue;
      final current = categoryIdFromRecordRow(row);
      if (current != oldCategoryId) continue;
      final pbId = _pbSystemIdFromCachedRecordRow(row);
      final biz = (row['record_id'] ?? '').toString().trim();
      final original = (pbId != null && pbId.isNotEmpty) ? pbId : biz;
      if (original.isEmpty || biz.isEmpty) continue;
      targets.add((
        index: i,
        originalInput: original,
        businessId: biz,
        pbId: pbId,
        rollback: Map<String, dynamic>.from(row),
      ));
    }
    if (targets.isEmpty) return;
    for (final t in targets) {
      _applyCachedRecordCategoryAt(t.index, newCategoryId);
    }
    _notifyTimelineAfterRecordCacheMutation();
    for (final t in targets) {
      unawaited(
        _patchLoadedLinkedRecordCategory(
          originalInput: t.originalInput,
          businessId: t.businessId,
          pocketBaseId: t.pbId,
          rollbackIndex: t.index,
          rollbackRow: t.rollback,
          newCategoryId: newCategoryId,
        ),
      );
    }
  }

  Future<void> _patchLoadedLinkedRecordCategory({
    required String originalInput,
    required String businessId,
    required String? pocketBaseId,
    required int rollbackIndex,
    required Map<String, dynamic> rollbackRow,
    required int newCategoryId,
  }) async {
    final updates = <String, dynamic>{
      'category_id': _recordCategoryBusinessPkForApi(newCategoryId),
    };
    try {
      var rid = pocketBaseId?.trim();
      if (rid == null ||
          rid.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(rid)) {
        rid = await _resolveRecordPbIdForOutboxReplay(
          businessId: businessId,
          pocketBaseId: pocketBaseId,
        );
      }
      if (rid == null ||
          rid.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(rid)) {
        await _enqueueRecordUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: updates,
          error: 'unresolved_pb_id',
        );
        offlineSync.setConnectivityOffline(true);
        return;
      }
      final code = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
      );
      if (code >= 200 && code < 300) {
        unawaited(offlineSync.refreshPendingCount());
        return;
      }
      if (code == 401 || code == 403) {
        await _enqueueRecordUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: updates,
          pocketBaseId: rid,
          error: code,
          syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        return;
      }
      if (_recordMutationRetriableHttpCode(code)) {
        await _enqueueRecordUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: updates,
          pocketBaseId: rid,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return;
      }
      if (rollbackIndex >= 0 && rollbackIndex < _cachedFlatRecords.length) {
        _cachedFlatRecords[rollbackIndex] = rollbackRow;
        _notifyTimelineAfterRecordCacheMutation();
      }
    } catch (e, st) {
      DatabaseService._log('AUTO_RECAT_RECORD_LINKED: $e');
      DatabaseService._log(st.toString());
      await _enqueueRecordUpdateMutation(
        originalInput: originalInput,
        businessId: businessId,
        patchFields: updates,
        pocketBaseId: pocketBaseId,
        error: e,
      );
      offlineSync.setConnectivityOffline(true);
    }
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
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return null;
    final businessId = _outboxBusinessIdForRecord(originalInput);
    try {
      final cacheRid =
          _tryResolveRecordIdFromCacheOnly(originalInput) ?? originalInput;
      final existingIndex = _indexOfCachedRecordRow(cacheRid, originalInput);
      final existingRow = existingIndex >= 0
          ? _cachedFlatRecords[existingIndex]
          : null;
      final oldCategoryId = existingRow != null
          ? categoryIdFromRecordRow(existingRow)
          : null;
      final autoCategoryId = _resolveCategoryIdForEditedTitle(
        newTitle: title,
        oldTitle: existingRow?['title']?.toString(),
        currentCategoryId: oldCategoryId,
        manualCategoryChanged: categoryId != null || syncSourcePlan,
      );
      final effectiveCategoryId = categoryId ?? autoCategoryId;
      final updates = await _buildRecordPatchUpdates(
        title: title,
        startTime: startTime,
        endTime: endTime,
        categoryId: effectiveCategoryId,
        note: note,
        tags: tags,
        checklist: checklist,
        syncSourcePlan: syncSourcePlan,
        clearSourcePlan: clearSourcePlan,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (updates.isEmpty) {
        return _timelineRecordFromCacheInput(originalInput);
      }
      Map<String, dynamic>? rollbackRow;
      var rollbackIndex = -1;
      rollbackIndex = existingIndex;
      if (rollbackIndex >= 0) {
        rollbackRow = Map<String, dynamic>.from(
          _cachedFlatRecords[rollbackIndex],
        );
      }
      applyOptimisticRecordRowEdit(
        recordId: originalInput,
        title: title,
        startTime: startTime,
        endTime: endTime,
        categoryId: effectiveCategoryId,
        note: note,
        tags: tags,
        checklist: checklist,
        syncSourcePlan: syncSourcePlan,
        clearSourcePlan: clearSourcePlan,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (autoCategoryId != null &&
          oldCategoryId != null &&
          oldCategoryId != autoCategoryId &&
          existingRow != null) {
        final sourcePlanId = _cachedRecordSourcePlanId(existingRow);
        if (sourcePlanId != null) {
          unawaited(
            _propagateRecordAutoCategoryToLinkedPlan(
              planPocketId: sourcePlanId,
              oldCategoryId: oldCategoryId,
              newCategoryId: autoCategoryId,
            ),
          );
        }
      }
      final optimistic = _timelineRecordFromCacheInput(originalInput);
      final shadowRid = _tryResolveRecordIdFromCacheOnly(originalInput);
      if (shadowRid != null &&
          DatabaseService._isLikelyPocketBaseRowId(shadowRid)) {
        final rb = rollbackRow;
        final ri = rollbackIndex;
        unawaited(
          _patchRecordUpdateNetworkPhase(
            originalInput: originalInput,
            resolvedPbId: shadowRid,
            businessId: businessId,
            updates: updates,
            rollbackRow: rb,
            rollbackIndex: ri,
          ).catchError((Object e, StackTrace st) async {
            DatabaseService._log('updateRecord shadow async: $e');
            DatabaseService._log(st.toString());
            if (e is ClientException) {
              final code = e.statusCode;
              if (code == 401 || code == 403) {
                await _enqueueRecordUpdateMutation(
                  originalInput: originalInput,
                  businessId: businessId,
                  patchFields: updates,
                  pocketBaseId: shadowRid,
                  error: code,
                  syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
                );
                offlineSync.setAuthPaused(true, message: 'HTTP $code');
                return true;
              }
              if (_recordMutationRetriableHttpCode(code)) {
                await _enqueueRecordUpdateMutation(
                  originalInput: originalInput,
                  businessId: businessId,
                  patchFields: updates,
                  pocketBaseId: shadowRid,
                  error: code,
                );
                offlineSync.setConnectivityOffline(true);
                return true;
              }
            } else if (_recordMutationRetriableHttpCode(0)) {
              await _enqueueRecordUpdateMutation(
                originalInput: originalInput,
                businessId: businessId,
                patchFields: updates,
                pocketBaseId: shadowRid,
                error: e,
              );
              offlineSync.setConnectivityOffline(true);
              return true;
            }
            if (rb != null && ri >= 0 && ri < _cachedFlatRecords.length) {
              _cachedFlatRecords[ri] = rb;
              _notifyTimelineAfterRecordCacheMutation();
            }
            AppSnack.failed();
            return false;
          }),
        );
        return optimistic;
      }
      unawaited(() async {
        try {
          final rid = await _resolveRecordIdForRestUrl(originalInput);
          if (!DatabaseService._isLikelyPocketBaseRowId(rid)) {
            await _enqueueRecordUpdateMutation(
              originalInput: originalInput,
              businessId: businessId,
              patchFields: updates,
              error: 'unresolved_pb_id',
            );
            offlineSync.setConnectivityOffline(true);
            return;
          }
          await _patchRecordUpdateNetworkPhase(
            originalInput: originalInput,
            resolvedPbId: rid,
            businessId: businessId,
            updates: updates,
            rollbackRow: rollbackRow,
            rollbackIndex: rollbackIndex,
          );
        } catch (e, st) {
          DatabaseService._log('updateRecord resolve async: $e');
          DatabaseService._log(st.toString());
          if (_recordMutationRetriableHttpCode(0)) {
            await _enqueueRecordUpdateMutation(
              originalInput: originalInput,
              businessId: businessId,
              patchFields: updates,
              error: e,
            );
            offlineSync.setConnectivityOffline(true);
          }
        }
      }());
      return optimistic;
    } catch (_) {
      AppSnack.failed();
      return _timelineRecordFromCacheInput(originalInput);
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
    final sp = DatabaseService.pocketRelationIdOrNull(sourcePlanPocketRecordId);
    if (sp == null || sp.isEmpty) return false;
    Map<String, dynamic>? rollbackRow;
    var rollbackIndex = -1;
    try {
      var rid = _tryResolveRecordIdFromCacheOnly(originalInput);
      if (rid == null ||
          rid.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(rid)) {
        final resolved = await _resolveRecordIdForRestUrl(originalInput);
        rid = DatabaseService._isLikelyPocketBaseRowId(resolved)
            ? resolved
            : null;
      }
      if (rid == null || rid.isEmpty) {
        DatabaseService._log(
          'patchRecordSourcePlanLink: no PocketBase id yet for recordId=$originalInput',
        );
        return false;
      }
      DatabaseService._log(
        'PATCH_ID_TRACE: patchRecordSourcePlanLink pb id=$rid',
      );
      final pc = await _resolveCategoryIdFromSourcePlanPbId(sp);
      final shouldPatchCategory = _planLocalCategoryIdIsConcrete(pc);
      final updates = <String, dynamic>{'source_plan_id': sp};
      if (shouldPatchCategory && pc != null) {
        updates['category_id'] = _recordCategoryBusinessPkForApi(pc);
      }
      rollbackIndex = _indexOfCachedRecordRow(rid, originalInput);
      if (rollbackIndex >= 0) {
        rollbackRow = Map<String, dynamic>.from(
          _cachedFlatRecords[rollbackIndex],
        );
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
      DatabaseService._log('patchRecordSourcePlanLink failed: $e');
      DatabaseService._log(st.toString());
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
  }) => updateRecord(
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
    final businessId = _outboxBusinessIdForRecord(originalInput);
    final delKeys = _collectRecordKeysFromCache(originalInput);
    for (final k in delKeys) {
      if (k.isNotEmpty) _optimisticDeletedKeys.add(k);
    }
    _notifyTimelineAfterRecordCacheMutation();

    final shadowRid = _tryResolveRecordIdFromCacheOnly(originalInput);
    if (shadowRid != null &&
        DatabaseService._isLikelyPocketBaseRowId(shadowRid)) {
      unawaited(
        _deleteRecordNetworkPhase(
          originalInput: originalInput,
          resolvedPbId: shadowRid,
          businessId: businessId,
          delKeys: delKeys,
        ).catchError((Object e, StackTrace st) async {
          DatabaseService._log('deleteRecordByDocId shadow async: $e');
          DatabaseService._log(st.toString());
          if (e is ClientException) {
            final code = e.statusCode;
            if (code == 401 || code == 403) {
              await _enqueueRecordDeleteMutation(
                originalInput: originalInput,
                businessId: businessId,
                pocketBaseId: shadowRid,
                error: code,
                syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
              );
              offlineSync.setAuthPaused(true, message: 'HTTP $code');
              return true;
            }
            if (_recordMutationRetriableHttpCode(code)) {
              await _enqueueRecordDeleteMutation(
                originalInput: originalInput,
                businessId: businessId,
                pocketBaseId: shadowRid,
                error: code,
              );
              offlineSync.setConnectivityOffline(true);
              return true;
            }
          } else if (_recordMutationRetriableHttpCode(0)) {
            await _enqueueRecordDeleteMutation(
              originalInput: originalInput,
              businessId: businessId,
              pocketBaseId: shadowRid,
              error: e,
            );
            offlineSync.setConnectivityOffline(true);
            return true;
          }
          for (final k in delKeys) {
            _optimisticDeletedKeys.remove(k);
          }
          _notifyTimelineAfterRecordCacheMutation();
          if (e is ClientException) {
            _snackDeleteHttpFailure(e.statusCode);
          } else {
            AppSnack.show(
              t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
              error: true,
            );
          }
          return false;
        }),
      );
      return true;
    }

    try {
      final rid = await _resolveRecordIdForStopOrDelete(originalInput);
      return await _deleteRecordNetworkPhase(
        originalInput: originalInput,
        resolvedPbId: rid,
        businessId: businessId,
        delKeys: delKeys,
      );
    } on LegacyIdResolutionException catch (e, st) {
      DatabaseService._log('deleteRecordByDocId: $e');
      DatabaseService._log(st.toString());
      await _enqueueRecordDeleteMutation(
        originalInput: originalInput,
        businessId: businessId,
        error: e,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    } on ClientException catch (e, st) {
      DatabaseService._log('deleteRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        await _enqueueRecordDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          error: code,
          syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        _snackDeleteHttpFailure(code);
        return true;
      }
      if (_recordMutationRetriableHttpCode(code)) {
        await _enqueueRecordDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      _snackDeleteHttpFailure(code);
      return false;
    } catch (e, st) {
      DatabaseService._log('deleteRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      if (_recordMutationRetriableHttpCode(0)) {
        await _enqueueRecordDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          error: e,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
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
    final nowIso = DatabaseService.getPlanetaryNow().toUtc().toIso8601String();
    DatabaseService._log(
      'PATCH_ID_TRACE: stopRecordByDocId pb id=$resolvedPbId',
    );
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
        _brainSnackError(t(currentLocale.value, 'error_stop_dead_letter_skip'));
      } else {
        _snackStopHttpFailure(404);
      }
      return false;
    }
    final ok = stopCode >= 200 && stopCode < 300;
    if (ok) {
      _clearOptimisticStopKeysForRecord(originalInput);
      AppSnack.updated();
      unawaited(offlineSync.refreshPendingCount());
      return true;
    }
    if (stopCode == 401 || stopCode == 403) {
      await _enqueueStopPatchMutation(
        originalInput: originalInput,
        pocketBaseId: resolvedPbId,
        error: stopCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $stopCode');
      _snackStopHttpFailure(stopCode);
      return true;
    }
    if (_recordMutationRetriableHttpCode(stopCode)) {
      await _enqueueStopPatchMutation(
        originalInput: originalInput,
        pocketBaseId: resolvedPbId,
        error: stopCode,
      );
      offlineSync.setConnectivityOffline(true);
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
      debugPrint(
        '[ABORT_REASON] Exiting early because: !_isInitialized (_isInitialized=$_isInitialized). No PATCH.',
      );
      _brainSnackError(t(currentLocale.value, 'error_stop_brain_not_ready'));
      return false;
    }
    if (!_hasAuthenticatedUserId) {
      debugPrint(
        '[ABORT_REASON] Exiting early because: PocketBase auth record id is missing (_isInitialized=$_isInitialized, currentProfileId=$currentProfileId). No PATCH.',
      );
      _brainSnackError(t(currentLocale.value, 'error_stop_brain_not_ready'));
      return false;
    }
    var rid = recordId.trim();
    if (rid.isEmpty) {
      debugPrint(
        '[ABORT_REASON] Exiting early because: trimmed recordId is empty. No PATCH.',
      );
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
    if (shadowRid != null &&
        DatabaseService._isLikelyPocketBaseRowId(shadowRid)) {
      unawaited(
        _patchStopRecordNetworkPhase(originalInput, shadowRid)
            .catchError((Object e, StackTrace st) async {
              DatabaseService._log('stopRecordByDocId shadow async: $e');
              DatabaseService._log(st.toString());
              if (e is ClientException) {
                final code = e.statusCode;
                if (code == 401 || code == 403) {
                  await _enqueueStopPatchMutation(
                    originalInput: originalInput,
                    pocketBaseId: shadowRid,
                    error: code,
                    syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
                  );
                  offlineSync.setAuthPaused(true, message: 'HTTP $code');
                  _snackStopHttpFailure(code);
                  return true;
                }
                if (_recordMutationRetriableHttpCode(code)) {
                  await _enqueueStopPatchMutation(
                    originalInput: originalInput,
                    pocketBaseId: shadowRid,
                    error: code,
                  );
                  offlineSync.setConnectivityOffline(true);
                  return true;
                }
              } else if (_recordMutationRetriableHttpCode(0)) {
                await _enqueueStopPatchMutation(
                  originalInput: originalInput,
                  pocketBaseId: shadowRid,
                  error: e,
                );
                offlineSync.setConnectivityOffline(true);
                return true;
              }
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
            })
            .whenComplete(() {
              _stopRecordInFlightKeys.remove(originalInput);
            }),
      );
      return true;
    }

    try {
      rid = await _resolveRecordIdForStopOrDelete(rid);
      if (!DatabaseService._isLikelyPocketBaseRowId(rid)) {
        debugPrint(
          '[ABORT_REASON] After resolve, rid="$rid" is not a PocketBase row id segment (fails _isLikelyPocketBaseRowId). Throwing LegacyIdResolutionException.',
        );
        throw LegacyIdResolutionException(originalInput);
      }
      return await _patchStopRecordNetworkPhase(originalInput, rid);
    } on LegacyIdResolutionException catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint(
        '[ABORT_REASON] LegacyIdResolutionException — could not map input to PB row id: $e',
      );
      DatabaseService._log('stopRecordByDocId: $e');
      DatabaseService._log(st.toString());
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _brainSnackError(t(currentLocale.value, 'error_stop_id_unresolved'));
      return false;
    } on ClientException catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint(
        '[ABORT_REASON] stopRecordByDocId: PocketBase ClientException status=${e.statusCode} $e',
      );
      DatabaseService._log('stopRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        await _enqueueStopPatchMutation(
          originalInput: originalInput,
          pocketBaseId: rid,
          error: code,
          syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        _snackStopHttpFailure(code);
        return true;
      }
      if (_recordMutationRetriableHttpCode(code)) {
        await _enqueueStopPatchMutation(
          originalInput: originalInput,
          pocketBaseId: rid,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _snackStopHttpFailure(code);
      return false;
    } catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint(
        '[ABORT_REASON] stopRecordByDocId: unexpected exception before/after PATCH: $e',
      );
      DatabaseService._log('stopRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      if (_recordMutationRetriableHttpCode(0)) {
        await _enqueueStopPatchMutation(
          originalInput: originalInput,
          pocketBaseId: rid,
          error: e,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
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
    String recordId,
    List<Map<String, dynamic>> checklist,
  ) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return;
    unawaited(updateRecord(recordId: originalInput, checklist: checklist));
  }
}
