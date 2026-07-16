// ignore_for_file: avoid_print
part of 'database_service.dart';

/// Legacy **plans** M2M column key (historical Noco expand / JSON only — unused with PocketBase plans).
const String _plansToTagsLinkColumnSystemId = 'cnmo43ed26h293n';

bool get _isPlansTableConfigured => true;

bool _planMutationOutboxFlushInFlight = false;

bool _planMutationRetriableHttpCode(int code) {
  if (code == 401 || code == 403 || code == 404) return false;
  if (code == 400 || code == 422) return false;
  if (code >= 200 && code < 300) return false;
  return true;
}

/// In-memory all-user plans (single source for Planning + Lists); refreshed by fetch, PATCH merge, realtime.
List<PlanningTask> _allPlansUserCache = [];
DateTime? _allPlansUserCacheFetchedAt;
const Duration _allPlansUserCacheFreshTtl = Duration(seconds: 30);

List<PlanningTask> _tasksCache = [];

final Random _random = Random();

extension PlanServiceExtension on DatabaseService {
  /// Drains queued PocketBase **plans** mutations (offline outbox). Safe to call from [SyncManager].

  Future<bool> _patchPlanUpdateNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
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
      clearOptimisticPlanningForPlanRow(originalInput);
      clearOptimisticPlanningForPlanRow(resolvedPbId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      unawaited(offlineSync.refreshPendingCount());
      return true;
    } on ClientException catch (e) {
      final code = e.statusCode;
      if (code == 404) {
        _removePlanFromUserCache(resolvedPbId);
        _removePlanFromUserCache(originalInput);
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      if (code == 401 || code == 403) {
        List<String>? tagIds;
        if (tags != null) {
          tagIds = await _pbTagRecordIdsFromTags(tags);
        }
        await _enqueuePlanUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: scalarBody,
          pocketBaseId: resolvedPbId,
          tagsLinkPbIds: tagIds,
          error: code,
          syncStatus: PlanMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        if (!suppressAppSnack) AppSnack.failed();
        return true;
      }
      if (_planMutationRetriableHttpCode(code)) {
        List<String>? tagIds;
        if (tags != null) {
          tagIds = await _pbTagRecordIdsFromTags(tags);
        }
        await _enqueuePlanUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: scalarBody,
          pocketBaseId: resolvedPbId,
          tagsLinkPbIds: tagIds,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    } catch (e, st) {
      DatabaseService._log('PATCH_PLAN_NETWORK: $e');
      DatabaseService._log(st.toString());
      if (_planMutationRetriableHttpCode(0)) {
        List<String>? tagIds;
        if (tags != null) {
          tagIds = await _pbTagRecordIdsFromTags(tags);
        }
        await _enqueuePlanUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: scalarBody,
          pocketBaseId: resolvedPbId,
          tagsLinkPbIds: tagIds,
          error: e,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
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

  void _notifyTimelineAfterRecordCacheMutation() {
    if (_recordCacheTimelineNotifyBatchDepth > 0) return;
    _refreshTimelineWarmSnapshotsAfterCacheMutation();
    _emitTimelineRefreshRaw();
  }

  /// Stable business **plan_id** (UUID) for merge/dedupe — not PocketBase system id.
  String? _planBusinessUuidFromTask(PlanningTask task) {
    final row = task.planRowId?.trim() ?? '';
    if (row.isNotEmpty) {
      if (row.startsWith('optimistic-')) {
        final id = row.substring('optimistic-'.length).trim();
        return id.isEmpty ? null : id;
      }
      if (!row.startsWith('virt-')) return row;
    }
    final pr = task.pocketRecordId?.trim() ?? '';
    if (pr.startsWith('optimistic-')) {
      final id = pr.substring('optimistic-'.length).trim();
      return id.isEmpty ? null : id;
    }
    return null;
  }

  bool _isOptimisticPlanningTask(PlanningTask task) {
    final pr = task.pocketRecordId?.trim() ?? '';
    if (pr.startsWith('optimistic-')) return true;
    final row = task.planRowId?.trim() ?? '';
    return row.startsWith('optimistic-');
  }

  bool _isJitVirtualPlanningTask(PlanningTask task) {
    final row = task.planRowId?.trim() ?? '';
    if (row.startsWith('virt-')) return true;
    return task.planRowIdForBackend.startsWith('virt-');
  }

  bool _isMaterializedRecurrenceException(PlanningTask task) {
    if (_isJitVirtualPlanningTask(task)) return false;
    final inst = task.recurrenceInstanceDateKey?.trim();
    if (inst == null || inst.length < 10) return false;
    final series = task.parentPlanPocketId?.trim();
    return series != null && DatabaseService._isLikelyPocketBaseRowId(series);
  }

  /// UI + Brain: recurring occurrence, virtual JIT row, or materialized exception.
  bool planningTaskIsRecurringForScope(PlanningTask task) {
    if (_isJitVirtualPlanningTask(task)) return true;
    if (task.rrule?.trim().isNotEmpty == true) return true;
    return _isMaterializedRecurrenceException(task);
  }

  String? _resolveRecurrenceInstanceDateKey({
    required String planRowId,
    String? recurrenceInstanceDateKey,
    PlanningTask? cached,
  }) {
    final hint = recurrenceInstanceDateKey?.trim() ?? '';
    if (hint.length >= 10) return hint.substring(0, 10);
    final virt = _parseVirtualPlanRowId(planRowId);
    if (virt != null) return virt.instanceDateKey;
    final fromTask = cached?.recurrenceInstanceDateKey?.trim() ?? '';
    if (fromTask.length >= 10) return fromTask.substring(0, 10);
    return null;
  }

  String? _resolveRecurrenceSeriesPocketId({
    required String planRowId,
    String? planBusinessId,
    PlanningTask? cached,
  }) {
    final virt = _parseVirtualPlanRowId(planRowId);
    if (virt != null) return virt.parentPocketId;
    final task =
        cached ??
        _findCachedPlanningTaskForEdit(
          planRowId,
          planBusinessId: planBusinessId,
        );
    if (task == null) return null;
    if (task.rrule?.trim().isNotEmpty == true) {
      final pb = task.pocketRecordId?.trim();
      if (pb != null && DatabaseService._isLikelyPocketBaseRowId(pb)) {
        return pb;
      }
    }
    final parent = task.parentPlanPocketId?.trim();
    if (parent != null && DatabaseService._isLikelyPocketBaseRowId(parent)) {
      return parent;
    }
    final pb = task.pocketRecordId?.trim();
    if (pb != null && DatabaseService._isLikelyPocketBaseRowId(pb)) return pb;
    return null;
  }

  /// Stable list identity: PB system id → business plan_id → virt occurrence id.

  String? _virtParentPbFromJitRow(PlanningTask task) {
    final row = task.planRowId?.trim() ?? '';
    if (!row.startsWith('virt-')) return null;
    final m = RegExp(r'^virt-(.+)-(\d{4}-\d{2}-\d{2})$').firstMatch(row);
    return m?.group(1)?.trim();
  }

  bool _wallScheduleMatches(PlanningTask a, PlanningTask b) {
    if (a.startTime != b.startTime) return false;
    return a.endDateTime == b.endDateTime;
  }

  void _purgeOptimisticPlanRowsFromUserCache(String businessPlanId) {
    final biz = businessPlanId.trim();
    if (biz.isEmpty) return;
    _allPlansUserCache = [
      for (final t in _allPlansUserCache)
        if (!(_isOptimisticPlanningTask(t) &&
            _planBusinessUuidFromTask(t) == biz))
          t,
    ];
  }

  void _upsertPlanInUserCache(PlanningTask task) {
    final pid = task.planRowIdForBackend.trim();
    if (pid.isEmpty) return;
    if (_isJitVirtualPlanningTask(task)) {
      if (!kReleaseMode) {
        planDupTrace(
          'source=cache event=skipVirtUpsert key=$pid title=${task.title.trim()}',
        );
      }
      return;
    }
    final bizId = _planBusinessUuidFromTask(task);
    var i = -1;
    for (var j = 0; j < _allPlansUserCache.length; j++) {
      final t = _allPlansUserCache[j];
      final tPid = t.planRowIdForBackend.trim();
      if (tPid == pid) {
        i = j;
        break;
      }
      if (bizId != null &&
          bizId.isNotEmpty &&
          _planBusinessUuidFromTask(t) == bizId) {
        i = j;
        break;
      }
    }
    if (i >= 0) {
      _allPlansUserCache[i] = task;
    } else {
      _allPlansUserCache.add(task);
    }
    if (bizId != null && bizId.isNotEmpty && !_isOptimisticPlanningTask(task)) {
      _purgeOptimisticPlanRowsFromUserCache(bizId);
    }
  }

  void _removePlanFromUserCache(String planRowId) {
    final p = planRowId.trim();
    if (p.isEmpty) return;
    _allPlansUserCache = [
      for (final t in _allPlansUserCache)
        if (t.planRowIdForBackend.trim() != p) t,
    ];
  }

  Future<void> _ensureAllPlansUserCacheFresh({bool force = false}) async {
    if (!_isPlansTableConfigured) return;
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;
    if (!force &&
        _allPlansUserCache.isNotEmpty &&
        _allPlansUserCacheFetchedAt != null &&
        DateTime.now().difference(_allPlansUserCacheFetchedAt!) <
            _allPlansUserCacheFreshTtl) {
      return;
    }
    await _fetchAllPlanningTasksForCurrentUser();
  }

  /// 0..1 title similarity for plan–record linking heuristics (not category matching).

  /// One row: `plans.plan_id` (UUID) → system `id`.
  Future<String?> _fetchPbPlanSysIdByPlanIdField(String planBizId) async {
    final key = planBizId.trim();
    if (key.isEmpty || key.startsWith('optimistic-')) return null;
    if (DatabaseService._isLikelyPocketBaseRowId(key)) return key;
    try {
      await ensurePocketBaseReady();
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return null;
      final uid = _escapeForPbFilter(authId);
      final esc = _escapeForPbFilter(key);
      final rec = await _pb
          .collection(PbCollections.plans)
          .getFirstListItem('plan_id = "$esc" && user_id = "$uid"');
      final id = rec.id.trim();
      return id.isEmpty ? null : id;
    } on ClientException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Resolves planning row REST id when UI holds legacy `plan_id` UUID or mixed keys.
  Future<String> _resolvePlanRestId(
    String planRowIdForBackend, {
    String? planBusinessId,
  }) async {
    final p = planRowIdForBackend.trim();
    if (p.isEmpty) return p;
    if (DatabaseService._isLikelyPocketBaseRowId(p)) return p;
    final tried = <String>{};
    final biz = (planBusinessId ?? '').trim();
    for (final key in <String>[
      if (biz.isNotEmpty && !biz.startsWith('optimistic-')) biz,
      p,
    ]) {
      if (key.isEmpty || !tried.add(key)) continue;
      final sid = await _fetchPbPlanSysIdByPlanIdField(key);
      if (sid != null && sid.isNotEmpty && sid != p) {
        return sid;
      }
      if (sid != null && sid.isNotEmpty) return sid;
    }
    return p;
  }

  Future<void> _loadPlanningTasksForToday() async {
    try {
      final today = getTimelineDeviceLocalToday();
      _tasksCache = await _fetchPlanningTasksForDate(today);
      _tasksController.add(List.from(_tasksCache));
    } catch (_) {
      _tasksCache = [];
    }
  }

  /// Next `order` for a new plan on this wall day (for optimistic + POST).
  /// Plans for a wall day (same source as Planning tab). For UI manual `source_plan_id` linking.
  Future<List<PlanningTask>> getPlanningTasksForWallDate(DateTime wallDay) =>
      _fetchPlanningTasksForDate(wallDay);

  /// Warm plans cache for Calendar month indicators (no per-day network fan-out).
  Future<void> warmPlanningCacheForCalendar() =>
      _ensureAllPlansUserCacheFresh();

  /// Wall-clock estimate from plan start/end (profile wall [PlanningTask] times). Null if unknown.

  /// One pass over [_cachedFlatRecords]: seconds tracked per plan PocketBase id on [wallCalendarDay]
  /// (same day bucketing as timeline). Includes optimistic end overlay; running rows use [getPlanetaryNow].
  Map<String, int> aggregateSourcePlanActualSecondsForWallCalendarDay(
    DateTime wallCalendarDay,
  ) {
    final out = <String, int>{};
    try {
      if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
        return out;
      }
      final targetDayStr =
          '${wallCalendarDay.year}-${_two(wallCalendarDay.month)}-${_two(wallCalendarDay.day)}';
      final ownerIds = _recordRowOwnerIdMatchSet();
      if (ownerIds.isEmpty) return out;

      void addFromMerged(Map<String, dynamic> merged) {
        final planId = DatabaseService.pocketRelationIdOrNull(
          merged['source_plan_id']?.toString(),
        );
        if (planId == null) return;
        final st = merged['startTime'] as DateTime?;
        if (st == null) return;
        var en = merged['endTime'] as DateTime?;
        if (en == null) {
          final stStr = merged['status']?.toString() ?? '';
          if (stStr == 'running') {
            en = DatabaseService.getPlanetaryNow();
          } else {
            return;
          }
        }
        final sec = en.difference(st).inSeconds;
        if (sec <= 0) return;
        out[planId] = (out[planId] ?? 0) + sec;
      }

      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        if (_optimisticRowDeletedRaw(row)) continue;
        final rowUid = (row['user_id'] ?? '').toString().trim().toLowerCase();
        if (rowUid.isEmpty || !ownerIds.contains(rowUid)) continue;
        final stUtc = CategoryServiceExtension._parseDateTimeUtc(
          row['start_time'],
        );
        if (stUtc == null) continue;
        final recordDayStr = _timelineDeviceLocalDayKeyFromUtc(stUtc);
        if (recordDayStr != targetDayStr) continue;
        try {
          addFromMerged(_mergeOptimisticIntoRecordMap(_rowToRecordMap(row)));
        } catch (_) {}
      }
      final pend = _optimisticPendingStartRecordMap;
      if (pend != null) {
        final pDay = (pend['calendarDayStr'] ?? '').toString().trim();
        if (pDay == targetDayStr) {
          addFromMerged(Map<String, dynamic>.from(pend));
        }
      }
    } catch (_) {}
    return out;
  }

  Future<int> nextPlanningOrderForDate(DateTime selectedDate) async {
    final list = await _fetchPlanningTasksForDate(selectedDate);
    if (list.isEmpty) return 0;
    var m = 0;
    for (final t in list) {
      if (t.order > m) m = t.order;
    }
    return m + 1;
  }

  /// Next [PlanningTask.order] for undated backlog plans (Lists tab). Not tied to calendar day.
  Future<int> nextBacklogPlanningOrder() async {
    final list = await fetchBacklogPlans(categoryId: null);
    if (list.isEmpty) return 0;
    var m = 0;
    for (final t in list) {
      if (t.order > m) m = t.order;
    }
    return m + 1;
  }

  Future<List<PlanningTask>> _fetchPlanningTasksForDate(
    DateTime selectedDate,
  ) async {
    return RebuildMetrics.instance.perfBlockAsync(
      'Planning._fetchPlanningTasksForDate',
      () async {
        try {
          if (!_isPlansTableConfigured) {
            DatabaseService._log('TABLE_GUARD: plans fetch disabled.');
            return [];
          }
          if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
            return [];
          }
          final targetDayStr =
              '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}';
          try {
            await _ensureAllPlansUserCacheFresh();
            final plans = _filterPlansForWallDay(
              _allPlansUserCache,
              selectedDate,
            );
            final merged = _mergePlanningOptimistic(targetDayStr, plans);
            await _persistPlanningTasksDayCache(targetDayStr, merged);
            return merged;
          } catch (_) {
            final cached = await _loadPlanningTasksDayCache(targetDayStr);
            return _mergePlanningOptimistic(targetDayStr, cached);
          }
        } catch (_) {
          return [];
        }
      },
      meta: {
        'date':
            '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}',
      },
    );
  }

  /// Audit anchor: [PlanningTask.initialDateKey] or, for legacy rows, current schedule key.
  String planningAuditAnchorDateKey(PlanningTask t) {
    final i = t.initialDateKey?.trim() ?? '';
    if (i.length >= 10) return i.substring(0, 10);
    return planningWallScheduleDateKey(t);
  }

  /// True when [newScheduleKey] is strictly after [anchorKey] (lexicographic `YYYY-MM-DD`).
  bool planningShouldMarkPostponed({
    required String anchorKey,
    required String newScheduleKey,
  }) {
    if (anchorKey.length < 10 || newScheduleKey.length < 10) return false;
    return newScheduleKey.compareTo(anchorKey) > 0;
  }

  Future<List<PlanningTask>> _fetchAllPlanningTasksForCurrentUser() async {
    if (!_isPlansTableConfigured) return [];
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return [];
    final authId = _userIdForWhere;
    if (authId == null || authId.isEmpty) return [];
    final uid = _escapeForPbFilter(authId);
    final sw = Stopwatch()..start();
    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final list = await _pb
          .collection(PbCollections.plans)
          .getFullList(
            expand: kPbPlanTagsExpand,
            filter: 'user_id = "$uid"',
            batch: 200,
          );
      sw.stop();
      RebuildMetrics.instance.pbDuringSwipe(
        collection: 'plans',
        method: 'getFullList',
        durationMs: sw.elapsedMilliseconds,
        action: 'fetchAllPlansUserCache',
      );
      final out = [
        for (final r in list)
          _planningTaskFromPocketRecord(r, pocketTagCatalog: tagCatalog),
      ];
      _allPlansUserCache = scrubPlanningTasksForLocalCache(out);
      _scrubJitVirtualRowsFromUserCache();
      _allPlansUserCacheFetchedAt = DateTime.now();
      return out;
    } catch (_) {
      return _allPlansUserCache;
    }
  }

  /// Undated plans (`start_time` unset): backlog / Lists tab. Excludes virtual, optimistic rows.
  /// When [includeCompleted] is false (default), excludes [PlanningTask.isDone] (e.g. chip counts).
  Future<List<PlanningTask>> fetchBacklogPlans({
    int? categoryId,
    bool includeCompleted = false,
  }) async {
    try {
      await _ensureAllPlansUserCacheFresh();
      final filtered = _filterBacklogFromAll(
        _allPlansUserCache,
        categoryId: categoryId,
        includeCompleted: includeCompleted,
      );
      return _mergeBacklogOptimistic(filtered);
    } catch (_) {
      return getBacklogPlansSnapshot(
        categoryId: categoryId,
        includeCompleted: includeCompleted,
      );
    }
  }

  /// Basic plan vs fact for [wallDate]: tasks **scheduled** that day vs records that day.
  ///
  /// [recordsForDay]: same list as the Stats timeline tab (duration within day + category rollups).
  Future<BasicDayStats> getBasicDayStats(
    DateTime wallDate, {
    required List<Map<String, dynamic>> recordsForDay,
  }) async {
    final dk = '${wallDate.year}-${_two(wallDate.month)}-${_two(wallDate.day)}';
    final all = await _fetchAllPlanningTasksForCurrentUser();
    final dayPlans = <PlanningTask>[];
    for (final t in all) {
      if (t.planRowIdForBackend.startsWith('optimistic-')) continue;
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
      if (t.startTime == null) continue;
      final taskDk =
          '${t.startTime!.year}-${_two(t.startTime!.month)}-${_two(t.startTime!.day)}';
      if (taskDk != dk) continue;
      dayPlans.add(t);
    }
    dayPlans.addAll(expandRecurringPlans(all, wallDate, wallDate));

    var planTimeSec = 0;
    final plannedSecByCat = <int, int>{};
    for (final t in dayPlans) {
      final sec = planningWallEstimateSeconds(t);
      if (sec != null && sec > 0) {
        planTimeSec += sec;
        plannedSecByCat[t.categoryId] =
            (plannedSecByCat[t.categoryId] ?? 0) + sec;
      }
    }

    final actualSecByCat = <int, int>{};
    var factTimeSec = 0;
    final linkedPlanIds = <String>{};
    final offset = settings.timezoneOffsetHours;
    final tz = settings.preferredTimeZone;
    for (final rec in recordsForDay) {
      final sec =
          CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
            rec,
            wallDate,
            offset,
            tz,
          );
      if (sec <= 0) continue;
      factTimeSec += sec;
      final cid =
          resolvedCategoryIdForRecord(rec) ??
          CategoryRule.uncategorizedSyntheticId;
      actualSecByCat[cid] = (actualSecByCat[cid] ?? 0) + sec;
      final sp = DatabaseService.pocketRelationIdOrNull(
        rec['source_plan_id']?.toString(),
      );
      if (sp != null && sp.isNotEmpty) {
        linkedPlanIds.add(sp);
      }
    }

    return BasicDayStats(
      planTaskCount: dayPlans.length,
      factDistinctPlansFromRecords: linkedPlanIds.length,
      planTimeSeconds: planTimeSec,
      factTimeSeconds: factTimeSec,
      plannedSecByCategory: plannedSecByCat,
      actualSecByCategory: actualSecByCat,
      plansScheduledThisDay: dayPlans,
    );
  }

  DateTime? _wallDateKeyToLocalDate(String dateKey) {
    if (dateKey.length < 10) return null;
    final y = int.tryParse(dateKey.substring(0, 4));
    final m = int.tryParse(dateKey.substring(5, 7));
    final d = int.tryParse(dateKey.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Heuristic: open plan on [wallDateKey] whose title matches [recordTitle] (word overlap + fuzzy).
  Future<SourcePlanLinkSuggestion?> suggestSourcePlanForFreeStart({
    required String recordTitle,
    required String wallDateKey,
    double minSimilarity = 0.42,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    final parsed = getCleanTitleAndTags(recordTitle);
    final title = parsed.title.trim();
    if (title.isEmpty) return null;
    final day = _wallDateKeyToLocalDate(wallDateKey);
    if (day == null) return null;
    final plans = await _fetchPlanningTasksForDate(day);
    SourcePlanLinkSuggestion? best;
    var bestScore = 0.0;
    for (final p in plans) {
      if (p.isDone) continue;
      final pid = DatabaseService.pocketRelationIdOrNull(p.pocketRecordId);
      if (pid == null) continue;
      final score = titlePlanLinkScore(title, p.title);
      if (score > bestScore) {
        bestScore = score;
        best = SourcePlanLinkSuggestion(
          planPocketRecordId: pid,
          planTitle: p.title,
          similarity: score,
        );
      }
    }
    if (best == null || bestScore < minSimilarity) return null;
    return best;
  }

  /// True when [id] is a real category (not uncategorized / unset / create placeholder `-1`).
  bool _planLocalCategoryIdIsConcrete(int? id) {
    if (id == null) return false;
    if (id == 0) return false;
    if (id == CategoryRule.uncategorizedSyntheticId) return false;
    return true;
  }

  /// Cached plans only — for instant UI cache rows and Play/start-from-plan.
  int? _tryResolveCategoryIdFromSourcePlanPbIdSync(
    String planPbId, {
    String? planBusinessId,
  }) {
    final want = planPbId.trim();
    if (want.isEmpty) return null;
    final fromEdit = _findCachedPlanningTaskForEdit(
      want,
      planBusinessId: planBusinessId,
    );
    if (fromEdit != null &&
        _planLocalCategoryIdIsConcrete(fromEdit.categoryId)) {
      return fromEdit.categoryId;
    }
    for (final t in _tasksCache) {
      if (DatabaseService.pocketRelationIdOrNull(t.pocketRecordId) == want) {
        return _planLocalCategoryIdIsConcrete(t.categoryId)
            ? t.categoryId
            : null;
      }
    }
    for (final t in _allPlansUserCache) {
      if (DatabaseService.pocketRelationIdOrNull(t.pocketRecordId) == want) {
        return _planLocalCategoryIdIsConcrete(t.categoryId)
            ? t.categoryId
            : null;
      }
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final t in m.values) {
        if (DatabaseService.pocketRelationIdOrNull(t.pocketRecordId) == want) {
          return _planLocalCategoryIdIsConcrete(t.categoryId)
              ? t.categoryId
              : null;
        }
      }
    }
    return null;
  }

  /// Fresh plan category for record create (Play). Brain cache wins over stale UI.
  int? resolveCurrentPlanCategoryForRecordStart({
    String? sourcePlanPocketRecordId,
    String? planBusinessId,
    int? uiCategoryId,
  }) {
    final planId = DatabaseService.pocketRelationIdOrNull(
      sourcePlanPocketRecordId,
    );
    if (planId == null) {
      return _planLocalCategoryIdIsConcrete(uiCategoryId) ? uiCategoryId : null;
    }
    final cached = _tryResolveCategoryIdFromSourcePlanPbIdSync(
      planId,
      planBusinessId: planBusinessId,
    );
    if (_planLocalCategoryIdIsConcrete(cached)) {
      if (uiCategoryId != null &&
          _planLocalCategoryIdIsConcrete(uiCategoryId) &&
          uiCategoryId != cached) {
        debugPrint(
          '[PLAN_START_CATEGORY_SYNC] stale UI category replaced with current plan category',
        );
      }
      return cached;
    }
    return _planLocalCategoryIdIsConcrete(uiCategoryId) ? uiCategoryId : null;
  }

  /// PocketBase **plans** row id → local [CategoryRule.id] for `records.category_id` inheritance.
  Future<int?> _resolveCategoryIdFromSourcePlanPbId(String? planPbIdRaw) async {
    final want = DatabaseService.pocketRelationIdOrNull(planPbIdRaw);
    if (want == null) return null;
    final cached = _tryResolveCategoryIdFromSourcePlanPbIdSync(
      want,
      planBusinessId: null,
    );
    if (cached != null) return cached;
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return null;
      final r = await _pb.collection(PbCollections.plans).getOne(want);
      final d = r.data;
      final cid = categoryIdFromRecordRow(<String, dynamic>{
        'category_id': d['category_id'],
      });
      return _planLocalCategoryIdIsConcrete(cid) ? cid : null;
    } catch (_) {
      return null;
    }
  }

  PlanningTask _planningTaskFromPocketRecord(
    RecordModel r, {
    required List<Tag> pocketTagCatalog,
  }) {
    final d = r.data;
    final startUtc = CategoryServiceExtension._parseDateTimeUtc(
      d['start_time'],
    );
    final startDisplay = startUtc != null
        ? _profileWallFromUtc(startUtc.toUtc())
        : null;
    final endUtc = CategoryServiceExtension._parseDateTimeUtc(d['end_time']);
    final endDisplay = endUtc != null
        ? _profileWallFromUtc(endUtc.toUtc())
        : null;
    final derivedDateKey = startDisplay != null
        ? _dateKeyFromDate(startDisplay)
        : (endDisplay != null ? _dateKeyFromDate(endDisplay) : '');
    final derivedEndDateKey = endDisplay != null
        ? _dateKeyFromDate(endDisplay)
        : derivedDateKey;
    dynamic expandTagsPayload;
    final exp = r.get<dynamic>('expand.tags_link');
    if (exp is List) {
      expandTagsPayload = <dynamic>[
        for (final item in exp)
          if (item is RecordModel)
            <String, dynamic>{...item.data, 'id': item.id}
          else if (item is Map)
            Map<String, dynamic>.from(item),
      ];
    } else if (exp is RecordModel) {
      expandTagsPayload = <String, dynamic>{...exp.data, 'id': exp.id};
    } else if (exp is Map) {
      expandTagsPayload = Map<String, dynamic>.from(exp);
    }
    Map<String, dynamic>? expandJson;
    if (expandTagsPayload != null) {
      if (expandTagsPayload is List) {
        if (expandTagsPayload.isNotEmpty) {
          expandJson = <String, dynamic>{'tags_link': expandTagsPayload};
        }
      } else {
        expandJson = <String, dynamic>{'tags_link': expandTagsPayload};
      }
    }
    final catId =
        categoryIdFromRecordRow(<String, dynamic>{
          'category_id': d['category_id'],
        }) ??
        0;
    return PlanningTask.fromJson(<String, dynamic>{
      'pocketRecordId': r.id,
      'plan_row_id': d['plan_id']?.toString(),
      'id': 0,
      'title': d['title']?.toString() ?? '',
      'categoryId': catId,
      'category_id': d['category_id'],
      'isDone': d['is_done'],
      'is_done': d['is_done'],
      'dateKey': derivedDateKey,
      'endDateKey': derivedEndDateKey,
      'order': d['order'] is num ? (d['order'] as num).toInt() : 0,
      'startTime': startDisplay,
      'endDateTime': endDisplay,
      'checklist': d['checklist'],
      'notes_plain': d['notes_plain'] ?? d['note'],
      'notes_delta': d['notes_delta'],
      'parent_plan_id': d['parent_plan_id'],
      'initial_date_key': d['initial_date_key'],
      'is_postponed': d['is_postponed'],
      'rrule': d['rrule'],
      'exception_dates': d['exception_dates'],
      'reminder_offset': d['reminder_offset'],
      'expand': ?expandJson,
      'tags_link': d['tags_link'],
    }, pocketTagCatalog: pocketTagCatalog).copyWith(
      startUtcInstant: startUtc?.toUtc(),
      endUtcInstant: endUtc?.toUtc(),
    );
  }

  /// All **plans** for the current user (raw maps; includes `tags_link` expand when present).
  Future<List<Map<String, dynamic>>> fetchPlans() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return [];
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        return [];
      }
      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return [];
      final uid = _escapeForPbFilter(authId);
      final list = await _pb
          .collection(PbCollections.plans)
          .getFullList(filter: 'user_id = "$uid"', expand: kPbPlanTagsExpand);
      final out = list.map((r) {
        final m = Map<String, dynamic>.from(r.data);
        m['id'] = r.id;
        m['_pb_record_id'] = r.id;
        return m;
      }).toList();
      if (kDebugMode) {
        debugPrint('[PB] fetchPlans: ${out.length} rows @ $kPocketBaseUrl');
      }
      return out;
    } catch (e) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchPlans');
      return [];
    }
  }

  /// Business key for plan rows: prefer **plan_id** (UUID); bulk PATCH outer `id` is [recordsTablePk] / [PlanningTask.id].
  static String planRowBusinessIdFromRow(Map<String, dynamic> row) {
    for (final key in <String>['plan_id', 'Plan_id']) {
      final v = row[key];
      if (v == null) continue;
      final s = DatabaseService._sanitizePkString(v.toString());
      if (s != null && s.isNotEmpty) return s;
    }
    final env = DatabaseService._sanitizePkString(
      row[DatabaseService._nocoEnvelopePkKey]?.toString(),
    );
    if (env != null && env.isNotEmpty) return env;
    for (final key in <String>['id', 'Id', 'ID']) {
      final v = row[key];
      if (v == null) continue;
      final s = DatabaseService._sanitizePkString(v.toString());
      if (s != null && s.isNotEmpty) return s;
    }
    return '';
  }

  int newId() => -DateTime.now().millisecondsSinceEpoch - _random.nextInt(9999);

  String _tasksKeyForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return 'tasks_${d.year}_${_two(d.month)}_${_two(d.day)}';
  }

  /// Planning [SegmentedButton] sort segment: 0=category, 1=time, 2=tags, 3=custom (my order).
  static const String kPrefsPlanActiveTab = 'prefs_plan_active_tab';

  /// Sync read for [PlanningPage.initState] — no flicker when [_prefs] is already loaded.
  int? getPlanActiveTabIndexOrNull() {
    final prefs = _prefs;
    if (prefs == null) return null;
    final raw = prefs.getInt(kPrefsPlanActiveTab);
    if (raw == null) return null;
    if (raw < 0 || raw > 3) return null;
    return raw;
  }

  Future<void> persistPlanActiveTabIndex(int index) async {
    final clamped = index < 0 ? 0 : (index > 3 ? 3 : index);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt(kPrefsPlanActiveTab, clamped);
    } catch (_) {}
  }



  /// Deletes one plan row via [deletePlanningTasksBulk].
  Future<void> deletePlanningTask(String planRowId) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked deletePlanningTask because plans table id equals records table id.',
      );
      return;
    }
    final id = planRowId.trim();
    if (id.isEmpty) return;
    unawaited(deletePlanningTasksBulk([id]));
  }

  /// Creates a child backlog plan linked via [parent_plan_id] → parent pocket id.
  Future<bool> addBacklogChildPlan({
    required String parentPocketPlanId,
    required String title,
    required int categoryId,
  }) async {
    final parent = parentPocketPlanId.trim();
    final titleTrimmed = title.trim();
    if (parent.isEmpty || titleTrimmed.isEmpty) return false;
    final ord = await nextBacklogPlanningOrder();
    return addPlanningTask(
      PlanningTask(
        id: 0,
        title: titleTrimmed,
        categoryId: categoryId,
        dateKey: '',
        order: ord,
        startTime: null,
        endDateTime: null,
        parentPlanPocketId: parent,
      ),
    );
  }
}
