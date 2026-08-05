part of '../database_service.dart';

bool _planMutationRetriableHttpCode(int code) {
  if (code == 401 || code == 403 || code == 404) return false;
  if (code == 400 || code == 422) return false;
  if (code >= 200 && code < 300) return false;
  return true;
}

extension PlanOutboxSyncExtension on DatabaseService {
  /// Drains queued PocketBase **plans** mutations (offline outbox). Safe to call from [SyncManager].
  Future<void> flushPendingPlanMutations() async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) return;
    if (_planMutationOutboxFlushInFlight) return;
    if (offlineSync.authPaused) return;
    _planMutationOutboxFlushInFlight = true;
    offlineSync.setSyncing(true);
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final snapshot = await PlanMutationOutbox.load(prefs);
      if (snapshot.isEmpty) return;
      var allSynced = true;
      for (final raw in snapshot) {
        final item = Map<String, dynamic>.from(raw);
        final receipt = PlanMutationOutbox.receiptForItem(item);
        _rememberPendingPlanMutation(receipt);
        final ok = await _flushOnePlanOutboxEntry(item, prefs);
        if (ok) {
          await _acknowledgePlanMutation(receipt);
          continue;
        }
        allSynced = false;
        await PlanMutationOutbox.markRetryIfCurrent(
          prefs,
          receipt,
          lastError: offlineSync.lastError ?? 'sync_failed',
        );
        break;
      }
      if (allSynced) offlineSync.clearErrors();
      await offlineSync.refreshPendingCount();
    } finally {
      offlineSync.setSyncing(false);
      _planMutationOutboxFlushInFlight = false;
    }
  }

  /// Alias for [flushPendingPlanMutations].
  Future<void> flushPendingPlanCreates() => flushPendingPlanMutations();

  String _outboxBusinessPlanId(
    String planRowIdForBackend, {
    String? planBusinessId,
  }) {
    final biz = (planBusinessId ?? '').trim();
    if (biz.isNotEmpty && !biz.startsWith('optimistic-')) return biz;
    final p = planRowIdForBackend.trim();
    for (final t in _allPlansUserCache) {
      if (t.planRowIdForBackend == p || (t.planRowId ?? '').trim() == p) {
        final rowBiz = (t.planRowId ?? '').trim();
        if (rowBiz.isNotEmpty && !rowBiz.startsWith('optimistic-')) {
          return rowBiz;
        }
      }
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final t in m.values) {
        if (t.planRowIdForBackend == p || (t.planRowId ?? '').trim() == p) {
          final rowBiz = (t.planRowId ?? '').trim();
          if (rowBiz.isNotEmpty && !rowBiz.startsWith('optimistic-')) {
            return rowBiz;
          }
        }
      }
    }
    return p;
  }

  String? _tryResolvePlanPbIdFromCacheOnly(
    String planRowIdForBackend, {
    String? planBusinessId,
  }) {
    final p = planRowIdForBackend.trim();
    if (p.isEmpty) return null;
    if (DatabaseService._isLikelyPocketBaseRowId(p)) return p;
    final keys = <String>{
      p,
      if ((planBusinessId ?? '').trim().isNotEmpty) planBusinessId!.trim(),
    };
    PlanningTask? found;
    for (final t in _allPlansUserCache) {
      if (keys.contains(t.planRowIdForBackend) ||
          keys.contains((t.planRowId ?? '').trim())) {
        found = t;
        break;
      }
    }
    if (found == null) {
      for (final m in _planningOptimisticByDateKey.values) {
        for (final t in m.values) {
          if (keys.contains(t.planRowIdForBackend) ||
              keys.contains((t.planRowId ?? '').trim())) {
            found = t;
            break;
          }
        }
        if (found != null) break;
      }
    }
    if (found == null) return null;
    final pb = found.pocketRecordId?.trim() ?? '';
    if (pb.startsWith('optimistic-')) return null;
    if (DatabaseService._isLikelyPocketBaseRowId(pb)) return pb;
    final backend = found.planRowIdForBackend.trim();
    if (DatabaseService._isLikelyPocketBaseRowId(backend)) return backend;
    return null;
  }

  PlanningTask? _findCachedPlanningTaskForEdit(
    String planRowIdForBackend, {
    String? planBusinessId,
  }) {
    final p = planRowIdForBackend.trim();
    if (p.isEmpty) return null;
    final keys = <String>{
      p,
      if ((planBusinessId ?? '').trim().isNotEmpty) planBusinessId!.trim(),
    };
    for (final t in _allPlansUserCache) {
      if (keys.contains(t.planRowIdForBackend) ||
          keys.contains((t.planRowId ?? '').trim()) ||
          keys.contains((t.pocketRecordId ?? '').trim())) {
        return t;
      }
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final t in m.values) {
        if (keys.contains(t.planRowIdForBackend) ||
            keys.contains((t.planRowId ?? '').trim()) ||
            keys.contains((t.pocketRecordId ?? '').trim())) {
          return t;
        }
      }
    }
    return null;
  }

  void _applyOptimisticPlanningTaskPatch({
    required String planRowId,
    String? planBusinessId,
    String? title,
    int? categoryId,
    bool? isDone,
    String? notesPlain,
    String? notesDeltaJson,
    List<Map<String, dynamic>>? checklist,
    int? parentPlanId,
    int? order,
    DateTime? startTime,
    DateTime? startTimeDisplay,
    DateTime? endDateTime,
    DateTime? endDateTimeDisplay,
    bool clearEnd = false,
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,
  }) {
    final current = _findCachedPlanningTaskForEdit(
      planRowId,
      planBusinessId: planBusinessId,
    );
    if (current == null) return;
    final oldStartWall = current.startTime;
    final newStartWallInput = startTimeDisplay ?? startTime;
    final next = _coalescePlanningTaskWallUtcFields(
      current.copyWith(
        title: title,
        categoryId: categoryId,
        isDone: isDone,
        notesPlain: notesPlain,
        notesDeltaJson: notesDeltaJson,
        checklist: checklist,
        parentPlanId: parentPlanId,
        order: order,
        startTime: newStartWallInput,
        endDateTime: endDateTimeDisplay ?? endDateTime,
        clearEnd: clearEnd,
        tags: tags,
        initialDateKey: planInitialDateKey,
        isPostponed: planIsPostponed,
        rrule: patchPlanAlarmRecurrence ? planRrule : null,
        exceptionDates: patchPlanAlarmRecurrence ? planExceptionDates : null,
        reminderOffset: patchPlanAlarmRecurrence ? planReminderOffset : null,
        clearRrule:
            patchPlanAlarmRecurrence && (planRrule ?? '').trim().isEmpty,
        clearReminderOffset:
            patchPlanAlarmRecurrence && planReminderOffset == null,
        isSynced: false,
        startUtcInstant: newStartWallInput != null
            ? _profileUtcFromWall(newStartWallInput).toUtc()
            : current.startUtcInstant,
        endUtcInstant: clearEnd
            ? null
            : ((endDateTimeDisplay ?? endDateTime) != null
                  ? _profileUtcFromWall(
                      (endDateTimeDisplay ?? endDateTime)!,
                    ).toUtc()
                  : current.endUtcInstant),
        clearEndUtc: clearEnd,
      ),
    );
    if (newStartWallInput != null && next.startTime != null) {
      final instants = _planUtcInstants(next);
      if (instants != null) {
        _logPlanTimeEditWallToUtc(
          planId: (planBusinessId ?? planRowId).trim(),
          oldWall: oldStartWall,
          newWall: newStartWallInput,
          storedUtc: instants.startUtc,
          projectedWall: next.startTime!,
        );
      }
    }
    applyOptimisticPlanningTask(next);
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
  }

  Future<void> _propagateRecordAutoCategoryToLinkedPlan({
    required String planPocketId,
    required int oldCategoryId,
    required int newCategoryId,
  }) async {
    final planId = DatabaseService.pocketRelationIdOrNull(planPocketId);
    if (planId == null) return;
    final task = _findCachedPlanningTaskForEdit(planId);
    if (task == null) return;
    if (task.categoryId != oldCategoryId) return;
    await updatePlanningTask(
      planId,
      planBusinessId: task.planRowId,
      categoryId: newCategoryId,
      suppressAppSnack: true,
    );
  }

  Future<String?> _resolvePlanPbIdForOutboxReplay({
    required String businessId,
    String? pocketBaseId,
    required String originalQueryId,
  }) async {
    final stored = pocketBaseId?.trim();
    if (stored != null &&
        stored.isNotEmpty &&
        DatabaseService._isLikelyPocketBaseRowId(stored)) {
      return stored;
    }
    final cached = _tryResolvePlanPbIdFromCacheOnly(
      originalQueryId,
      planBusinessId: businessId,
    );
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final resolved = await _resolvePlanRestId(
        originalQueryId,
        planBusinessId: businessId,
      );
      if (DatabaseService._isLikelyPocketBaseRowId(resolved)) return resolved;
    } catch (_) {}
    return null;
  }

  Future<void> _cancelPendingPlanMutationsForBusinessId(
    String businessId,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await PlanMutationOutbox.removePendingForBusinessId(prefs, businessId);
      _pendingPlanMutationRevisionByBusinessId.remove(businessId.trim());
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_CANCEL: $e');
    }
  }

  void _rememberPendingPlanMutation(PlanMutationReceipt? receipt) {
    if (receipt == null) return;
    _pendingPlanMutationRevisionByBusinessId[receipt.businessId] =
        receipt.revision;
  }

  bool _hasPendingPlanMutationForBusinessId(String? businessId) {
    final key = businessId?.trim() ?? '';
    return key.isNotEmpty &&
        _pendingPlanMutationRevisionByBusinessId.containsKey(key);
  }

  Future<bool> _acknowledgePlanMutation(PlanMutationReceipt? receipt) async {
    if (receipt == null) return false;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final removed = await PlanMutationOutbox.acknowledge(prefs, receipt);
      if (removed &&
          _pendingPlanMutationRevisionByBusinessId[receipt.businessId] ==
              receipt.revision) {
        _pendingPlanMutationRevisionByBusinessId.remove(receipt.businessId);
      }
      await offlineSync.refreshPendingCount();
      return removed;
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ACK: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _planTagSnapshot(List<Tag> tags) =>
      <Map<String, dynamic>>[
        for (final tag in tags)
          <String, dynamic>{
            'id': tag.pbRecordId,
            'tag_id': tag.tagId,
            'name': tag.name,
            'color': tag.color,
            'icon': tag.icon,
            'sort_order': tag.sortOrder,
            'domain': tag.domain,
            'default_plan_duration_minutes': tag.defaultPlanDurationMinutes,
          },
      ];

  List<Tag> _planTagsFromSnapshot(dynamic raw) => <Tag>[
    if (raw is List)
      for (final item in raw)
        if (item is Map) Tag.fromPocketJson(Map<String, dynamic>.from(item)),
  ];

  Future<PlanMutationReceipt?> _enqueuePlanCreateMutation(
    Map<String, dynamic> body, {
    required String businessId,
    List<Tag>? tags,
    Object? error,
    String syncStatus = PlanMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      if (tags != null) {
        normalized[PlanMutationOutbox.payloadTagsSnapshotKey] =
            _planTagSnapshot(tags);
      }
      final receipt = await PlanMutationOutbox.enqueue(
        prefs,
        PlanMutationOutbox.newPlanCreateItem(
          businessId: businessId,
          payload: normalized,
          error: error,
          syncStatus: syncStatus,
        ),
      );
      _rememberPendingPlanMutation(receipt);
      unawaited(offlineSync.refreshPendingCount());
      return receipt;
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ENQUEUE create: $e');
      return null;
    }
  }

  Future<PlanMutationReceipt?> _enqueuePlanUpdateMutation({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchFields,
    String? pocketBaseId,
    List<String>? tagsLinkPbIds,
    Object? error,
    String syncStatus = PlanMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized =
          jsonDecode(jsonEncode(patchFields)) as Map<String, dynamic>;
      if (businessId.trim().isEmpty ||
          (normalized.isEmpty && tagsLinkPbIds == null)) {
        return null;
      }
      final receipt = await PlanMutationOutbox.enqueue(
        prefs,
        PlanMutationOutbox.newPlanUpdateItem(
          businessId: businessId.trim(),
          patchFields: normalized,
          pocketBaseId: pocketBaseId?.trim(),
          originalQueryId: originalInput.trim(),
          tagsLinkPbIds: tagsLinkPbIds,
          error: error,
          syncStatus: syncStatus,
        ),
      );
      _rememberPendingPlanMutation(receipt);
      unawaited(offlineSync.refreshPendingCount());
      return receipt;
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ENQUEUE update: $e');
      return null;
    }
  }

  Future<void> _enqueuePlanDeleteMutation({
    required String originalInput,
    required String businessId,
    String? pocketBaseId,
    Object? error,
    String syncStatus = PlanMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (businessId.trim().isEmpty) return;
      await PlanMutationOutbox.enqueue(
        prefs,
        PlanMutationOutbox.newPlanDeleteItem(
          businessId: businessId.trim(),
          pocketBaseId: pocketBaseId?.trim(),
          originalQueryId: originalInput.trim(),
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ENQUEUE delete: $e');
    }
  }

  Future<bool> _flushOnePlanOutboxEntry(
    Map<String, dynamic> item,
    SharedPreferences prefs,
  ) async {
    final kind = (item['kind'] ?? '').toString();
    final businessId = (item['businessId'] ?? '').toString().trim();
    final originalInput = (item['originalQueryId'] ?? businessId)
        .toString()
        .trim();

    if (kind == PlanMutationOutbox.kindPlanCreate) {
      final wrapped = item['payload'];
      if (wrapped is! Map) return true;
      final body = Map<String, dynamic>.from(wrapped);
      final tagsSnapshot = body.remove(
        PlanMutationOutbox.payloadTagsSnapshotKey,
      );
      body['user_id'] = _pidForPbFilter;
      try {
        final existingId = await _fetchPbPlanSysIdByPlanIdField(businessId);
        var record = existingId != null && existingId.isNotEmpty
            ? await _pb.collection(PbCollections.plans).getOne(existingId)
            : await _pb.collection(PbCollections.plans).create(body: body);
        final replayTags = _planTagsFromSnapshot(tagsSnapshot);
        if (replayTags.isNotEmpty || tagsSnapshot is List) {
          await _syncPlanTagsPocket(record.id, replayTags);
          record = await _pb
              .collection(PbCollections.plans)
              .getOne(record.id, expand: kPbPlanTagsExpand);
        }
        final tagCatalog = await _fetchPlanAndListTagCatalog();
        final merged = record;
        final fromServer = _planningTaskFromPocketRecord(
          merged,
          pocketTagCatalog: tagCatalog,
        );
        _upsertPlanInUserCache(fromServer);
        _allPlansUserCacheFetchedAt = DateTime.now();
        clearOptimisticPlanningForPlanRow('optimistic-$businessId');
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
        return true;
      } on ClientException catch (e) {
        final code = e.statusCode;
        _debugPrintPocketBaseClientException(
          operation: 'plan outbox create',
          e: e,
          payload: body,
        );
        if (code == 401 || code == 403) {
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          return false;
        }
        if (_planMutationRetriableHttpCode(code)) {
          offlineSync.setLastError('HTTP $code');
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.plans,
            operation: PlanMutationOutbox.kindPlanCreate,
            businessId: businessId,
            httpStatus: code,
            message: e.response['message']?.toString(),
          );
          return false;
        }
        return true;
      } catch (e) {
        if (_planMutationRetriableHttpCode(0)) {
          offlineSync.setLastError('$e');
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.plans,
            operation: PlanMutationOutbox.kindPlanCreate,
            businessId: businessId,
            message: e.toString(),
          );
          return false;
        }
        return true;
      }
    }

    if (kind == PlanMutationOutbox.kindPlanUpdate) {
      final wrapped = item['payload'];
      if (wrapped is! Map) return true;
      final rawPayload = Map<String, dynamic>.from(wrapped);
      final tagsRaw = rawPayload.remove(PlanMutationOutbox.payloadTagsLinkKey);
      final tagsSnapshot = rawPayload.remove(
        PlanMutationOutbox.payloadTagsSnapshotKey,
      );
      final patchBody = Map<String, dynamic>.from(rawPayload);
      patchBody.remove('user_id');
      if (patchBody.isEmpty && tagsRaw == null && tagsSnapshot == null) {
        return true;
      }
      final pbId = await _resolvePlanPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
        originalQueryId: originalInput,
      );
      if (pbId == null || pbId.isEmpty) {
        final cached = _tryResolvePlanPbIdFromCacheOnly(
          originalInput,
          planBusinessId: businessId,
        );
        if (cached == null || cached.isEmpty) {
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.plans,
            operation: PlanMutationOutbox.kindPlanUpdate,
            businessId: businessId,
            message: 'dropped_stale_no_cache',
          );
          return true;
        }
        offlineSync.setLastError('resolve_failed:plans/update');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.plans,
          operation: PlanMutationOutbox.kindPlanUpdate,
          businessId: businessId,
          message: 'unresolved_pb_id',
        );
        return false;
      }
      try {
        if (patchBody.isNotEmpty) {
          await _pb
              .collection(PbCollections.plans)
              .update(pbId, body: patchBody);
        }
        List<String>? replayTagIds;
        if (tagsRaw is List) {
          replayTagIds = [
            for (final e in tagsRaw)
              if (e != null) e.toString().trim(),
          ].where((s) => s.isNotEmpty).toList();
        } else if (tagsSnapshot is List) {
          replayTagIds = await _pbTagRecordIdsFromTags(
            _planTagsFromSnapshot(tagsSnapshot),
          );
        }
        if (replayTagIds != null) {
          await _pb
              .collection(PbCollections.plans)
              .update(
                pbId,
                body: <String, dynamic>{kPbPlanTagsExpand: replayTagIds},
              );
        }
        final tagCatalog = await _fetchPlanAndListTagCatalog();
        final merged = await _pb
            .collection(PbCollections.plans)
            .getOne(pbId, expand: kPbPlanTagsExpand);
        final taskFromServer = _planningTaskFromPocketRecord(
          merged,
          pocketTagCatalog: tagCatalog,
        );
        _upsertPlanInUserCache(taskFromServer);
        _allPlansUserCacheFetchedAt = DateTime.now();
        clearOptimisticPlanningForPlanRow(originalInput);
        clearOptimisticPlanningForPlanRow(pbId);
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
        return true;
      } on ClientException catch (e) {
        final code = e.statusCode;
        _debugPrintPocketBaseClientException(
          operation: 'plan outbox update',
          e: e,
          payload: patchBody,
        );
        if (code == 404) {
          _removePlanFromUserCache(pbId);
          _removePlanFromUserCache(originalInput);
          notifyPlanningRefresh(scheduleNetworkRefresh: false);
          return true;
        }
        if (code == 401 || code == 403) {
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          return false;
        }
        if (_planMutationRetriableHttpCode(code)) {
          offlineSync.setLastError('HTTP $code');
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.plans,
            operation: PlanMutationOutbox.kindPlanUpdate,
            businessId: businessId,
            pocketBaseId: pbId,
            httpStatus: code,
            message: e.response['message']?.toString(),
          );
          return false;
        }
        return true;
      } catch (e) {
        if (_planMutationRetriableHttpCode(0)) {
          offlineSync.setLastError('$e');
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.plans,
            operation: PlanMutationOutbox.kindPlanUpdate,
            businessId: businessId,
            pocketBaseId: pbId,
            message: e.toString(),
          );
          return false;
        }
        return true;
      }
    }

    if (kind == PlanMutationOutbox.kindPlanDelete) {
      final pbId = await _resolvePlanPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
        originalQueryId: originalInput,
      );
      if (pbId == null || pbId.isEmpty) return true;
      try {
        await _pb.collection(PbCollections.plans).delete(pbId);
        _removePlanFromUserCache(pbId);
        _removePlanFromUserCache(originalInput);
        clearOptimisticPlanningForPlanRow(originalInput);
        clearOptimisticPlanningForPlanRow(pbId);
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
        return true;
      } on ClientException catch (e) {
        if (e.statusCode == 404) {
          _removePlanFromUserCache(pbId);
          _removePlanFromUserCache(originalInput);
          notifyPlanningRefresh(scheduleNetworkRefresh: false);
          return true;
        }
        final code = e.statusCode;
        _debugPrintPocketBaseClientException(
          operation: 'plan outbox delete',
          e: e,
          payload: <String, dynamic>{'pbId': pbId},
        );
        if (code == 401 || code == 403) {
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          return false;
        }
        if (_planMutationRetriableHttpCode(code)) {
          offlineSync.setLastError('HTTP $code');
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.plans,
            operation: PlanMutationOutbox.kindPlanDelete,
            businessId: businessId,
            pocketBaseId: pbId,
            httpStatus: code,
            message: e.response['message']?.toString(),
          );
          return false;
        }
        return true;
      } catch (e) {
        if (_planMutationRetriableHttpCode(0)) {
          offlineSync.setLastError('$e');
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.plans,
            operation: PlanMutationOutbox.kindPlanDelete,
            businessId: businessId,
            pocketBaseId: pbId,
            message: e.toString(),
          );
          return false;
        }
        return true;
      }
    }
    return true;
  }

  /// Durable write-ahead staging for a plan edit. The optimistic cache is already
  /// visible before this awaits SharedPreferences; PocketBase network I/O starts only
  /// after the mutation survives process death.
  Future<PlanMutationReceipt?> _stagePlanUpdateWriteAhead({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchBody,
    String? pocketBaseId,
    List<Tag>? tags,
  }) async {
    final scalarBody = Map<String, dynamic>.from(patchBody);
    scalarBody.remove('user_id');
    if (tags != null) {
      scalarBody[PlanMutationOutbox.payloadTagsSnapshotKey] = _planTagSnapshot(
        tags,
      );
    }
    final receipt = await _enqueuePlanUpdateMutation(
      originalInput: originalInput,
      businessId: businessId,
      patchFields: scalarBody,
      pocketBaseId: pocketBaseId,
    );
    await offlineSync.refreshPendingCount();
    return receipt;
  }

  // --- Immediate update/delete network phase (not flush/replay) ---

  Future<bool> _patchPlanUpdateNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
    required PlanMutationReceipt? writeAheadReceipt,
    required Map<String, dynamic> patchBody,
    List<Tag>? tags,
    bool suppressAppSnack = false,
  }) async {
    final scalarBody = Map<String, dynamic>.from(patchBody);
    scalarBody.remove('user_id');
    try {
      if (scalarBody.isNotEmpty) {
        await _pb
            .collection(PbCollections.plans)
            .update(resolvedPbId, body: scalarBody);
      }
      if (tags != null) {
        await _syncPlanTagsPocket(resolvedPbId, tags);
      }
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final merged = await _pb
          .collection(PbCollections.plans)
          .getOne(resolvedPbId, expand: kPbPlanTagsExpand);
      final taskFromServer = _planningTaskFromPocketRecord(
        merged,
        pocketTagCatalog: tagCatalog,
      );
      _upsertPlanInUserCache(taskFromServer);
      _allPlansUserCacheFetchedAt = DateTime.now();
      final acknowledged = await _acknowledgePlanMutation(writeAheadReceipt);
      if (acknowledged) {
        clearOptimisticPlanningForPlanRow(originalInput);
        clearOptimisticPlanningForPlanRow(resolvedPbId);
      }
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return true;
    } on ClientException catch (e) {
      final code = e.statusCode;
      if (code == 404) {
        final acknowledged = await _acknowledgePlanMutation(writeAheadReceipt);
        if (acknowledged) {
          _removePlanFromUserCache(resolvedPbId);
          _removePlanFromUserCache(originalInput);
        }
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      if (code == 401 || code == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        if (!suppressAppSnack) AppSnack.failed();
        return true;
      }
      if (_planMutationRetriableHttpCode(code)) {
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      await _acknowledgePlanMutation(writeAheadReceipt);
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    } catch (e, st) {
      DatabaseService._log('PATCH_PLAN_NETWORK: $e');
      DatabaseService._log(st.toString());
      if (_planMutationRetriableHttpCode(0)) {
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      await _acknowledgePlanMutation(writeAheadReceipt);
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
  }

  Future<({bool ok, bool queued})> _deletePlanNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
  }) async {
    try {
      await _pb.collection(PbCollections.plans).delete(resolvedPbId);
      _removePlanFromUserCache(originalInput);
      _removePlanFromUserCache(resolvedPbId);
      clearOptimisticPlanningForPlanRow(originalInput);
      clearOptimisticPlanningForPlanRow(resolvedPbId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      _notifyTimelineAfterRecordCacheMutation();
      unawaited(offlineSync.refreshPendingCount());
      return (ok: true, queued: false);
    } on ClientException catch (e) {
      final code = e.statusCode;
      if (code == 404) {
        _removePlanFromUserCache(resolvedPbId);
        _removePlanFromUserCache(originalInput);
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
        return (ok: true, queued: false);
      }
      if (code == 401 || code == 403) {
        await _enqueuePlanDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          pocketBaseId: resolvedPbId,
          error: code,
          syncStatus: PlanMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        return (ok: true, queued: true);
      }
      if (_planMutationRetriableHttpCode(code)) {
        await _enqueuePlanDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          pocketBaseId: resolvedPbId,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return (ok: true, queued: true);
      }
      return (ok: false, queued: false);
    } catch (e, st) {
      DatabaseService._log('DELETE_PLAN_NETWORK: $e');
      DatabaseService._log(st.toString());
      if (_planMutationRetriableHttpCode(0)) {
        await _enqueuePlanDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          pocketBaseId: resolvedPbId,
          error: e,
        );
        offlineSync.setConnectivityOffline(true);
        return (ok: true, queued: true);
      }
      return (ok: false, queued: false);
    }
  }
}
