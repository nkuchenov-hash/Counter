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

final StreamController<List<PlanningTask>> _tasksController =
    StreamController<List<PlanningTask>>.broadcast();

/// Planning UI: manual refresh in addition to the 2s poll (after PATCH/cross-day optimistic).
final StreamController<void> _planningRefreshController =
    StreamController<void>.broadcast();

/// Wall **dateKey** → (**planRowIdForBackend** → task) merged on top of server list until PATCH lands.
/// Dateless backlog rows use [_kBacklogOptimisticDayKey], not a calendar day.
final Map<String, Map<String, PlanningTask>> _planningOptimisticByDateKey = {};

const String _kBacklogOptimisticDayKey = '__backlog__';

/// In-memory all-user plans (single source for Planning + Lists); refreshed by fetch, PATCH merge, realtime.
List<PlanningTask> _allPlansUserCache = [];
DateTime? _allPlansUserCacheFetchedAt;
const Duration _allPlansUserCacheFreshTtl = Duration(seconds: 30);
Timer? _planningNotifyNetworkDebounceTimer;
bool _planningRefreshWantsNetworkPump = false;
Future<void>? _plansRealtimeSubscribeFuture;
Future<void> Function()? _plansRealtimeUnsubscribe;

List<PlanningTask> _tasksCache = [];

/// Planning reorder: debounced bulk PATCH of [order] only (@DATA_MAP `plans.order`, `user_id`).
const Duration _planOrderDebounce = Duration(seconds: 2);

Timer? _planOrderDebounceTimer;
List<PlanningTask>? _pendingPlanOrderSyncList;

/// `planRowId` → server `order` before the first drag of the current reorder session (for diff-only PATCH).
Map<String, int>? _planReorderBaselineByPlanId;

Timer? _planAlarmRescheduleDebounceTimer;
final Random _random = Random();

extension PlanServiceExtension on DatabaseService {
  /// Plans and Lists share the `plans.tags_link` relation but isolate chips by `tags.domain`.
  /// Use the full cached catalog when hydrating plan/list rows so plain `tags_link` ids
  /// can resolve whether the row is a dated plan (`plan`) or an undated list item (`list`).
  Future<List<Tag>> _fetchPlanAndListTagCatalog() async {
    await fetchTagsForCurrentUser(scope: TagCatalogScope.plan);
    final all = cachedUserTagsCatalog;
    if (all.isNotEmpty) return all;
    return fetchTagsForCurrentUser(scope: TagCatalogScope.list);
  }

  Map<String, dynamic> _planningTaskToDayCacheMap(PlanningTask t) {
    return <String, dynamic>{
      'pocketRecordId': t.pocketRecordId,
      'plan_row_id': t.planRowId,
      'id': t.id,
      'title': t.title,
      'categoryId': t.categoryId,
      'category_id': t.categoryId,
      'is_done': t.isDone,
      'isDone': t.isDone,
      'dateKey': t.dateKey,
      'endDateKey': t.endDateKey,
      'order': t.order,
      if (t.startTime != null)
        'start_wall': <int>[
          t.startTime!.year,
          t.startTime!.month,
          t.startTime!.day,
          t.startTime!.hour,
          t.startTime!.minute,
          t.startTime!.second,
        ],
      if (t.endDateTime != null)
        'end_wall': <int>[
          t.endDateTime!.year,
          t.endDateTime!.month,
          t.endDateTime!.day,
          t.endDateTime!.hour,
          t.endDateTime!.minute,
          t.endDateTime!.second,
        ],
      'checklist': t.checklist,
      'notes_plain': t.notesPlain,
      'notes_delta': t.notesDeltaJson,
      if (t.parentPlanPocketId != null &&
          t.parentPlanPocketId!.trim().isNotEmpty)
        'parent_plan_pocket_id': t.parentPlanPocketId!.trim(),
      if (t.parentPlanId != null) 'parent_plan_id': t.parentPlanId,
      'isSynced': t.isSynced,
      if (t.initialDateKey != null && t.initialDateKey!.trim().length >= 10)
        'initial_date_key': t.initialDateKey!.trim().substring(0, 10),
      'is_postponed': t.isPostponed,
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) 'rrule': t.rrule,
      if (t.exceptionDates.isNotEmpty) 'exception_dates': t.exceptionDates,
      if (t.reminderOffset != null) 'reminder_offset': t.reminderOffset,
      if (t.recurrenceInstanceDateKey != null &&
          t.recurrenceInstanceDateKey!.trim().length >= 10)
        'recurrence_instance_date_key': t.recurrenceInstanceDateKey!
            .trim()
            .substring(0, 10),
      'tags': <Map<String, dynamic>>[
        for (final g in t.tags)
          <String, dynamic>{
            'tag_id': g.tagId,
            'name': g.name,
            'pocket_id': g.pbRecordId,
            'sort_order': g.sortOrder,
            'domain': g.domain,
          },
      ],
    };
  }

  PlanningTask _planningTaskFromOfflineDayMap(Map<String, dynamic> m) {
    DateTime? wallFromList(dynamic raw) {
      if (raw is! List || raw.length < 5) return null;
      return DateTime(
        (raw[0] as num).toInt(),
        (raw[1] as num).toInt(),
        (raw[2] as num).toInt(),
        (raw[3] as num).toInt(),
        (raw[4] as num).toInt(),
        raw.length > 5 ? (raw[5] as num).toInt() : 0,
      );
    }

    var tags = const <Tag>[];
    final tr = m['tags'];
    if (tr is List) {
      tags = [
        for (final e in tr)
          if (e is Map)
            Tag(
              tagId: int.tryParse((e['tag_id'] ?? '').toString()) ?? 0,
              name: (e['name'] ?? '').toString(),
              pbRecordId: e['pocket_id']?.toString(),
              sortOrder: int.tryParse((e['sort_order'] ?? '0').toString()) ?? 0,
              domain: e['domain']?.toString().trim().toLowerCase() == 'list'
                  ? 'list'
                  : 'plan',
            ),
      ];
    }
    final deltaRaw = m['notes_delta'];
    String? deltaJsonStr;
    if (deltaRaw != null) {
      if (deltaRaw is String) {
        final s = deltaRaw.trim();
        deltaJsonStr = s.isEmpty ? null : s;
      } else {
        try {
          deltaJsonStr = jsonEncode(deltaRaw);
        } catch (_) {
          deltaJsonStr = null;
        }
      }
    }
    return PlanningTask(
      id: int.tryParse((m['id'] ?? '').toString()) ?? 0,
      planRowId: m['plan_row_id']?.toString(),
      pocketRecordId: m['pocketRecordId']?.toString(),
      title: (m['title'] ?? '').toString(),
      categoryId:
          int.tryParse(
            (m['category_id'] ?? m['categoryId'] ?? '0').toString(),
          ) ??
          0,
      isDone: _jsonBoolFromDynamic(m['is_done'] ?? m['isDone']),
      dateKey: (m['dateKey'] ?? '').toString(),
      order: int.tryParse((m['order'] ?? '0').toString()) ?? 0,
      startTime: wallFromList(m['start_wall']),
      endDateTime: wallFromList(m['end_wall']),
      endDateKey: (m['endDateKey'] ?? m['dateKey'] ?? '').toString(),
      checklist: parseChecklistFromNocoList(m['checklist']),
      notesPlain: m['notes_plain']?.toString() ?? m['note']?.toString(),
      notesDeltaJson: deltaJsonStr,
      parentPlanPocketId: (m['parent_plan_pocket_id'] ?? m['parent_plan_id'])
          ?.toString()
          .trim(),
      parentPlanId: m['parent_plan_id'] == null
          ? null
          : int.tryParse(m['parent_plan_id'].toString()),
      tags: tags,
      isSynced: _jsonBoolFromDynamic(m['isSynced'] ?? true),
      initialDateKey: _normPlanInitialDateKey(
        m['initial_date_key'] ?? m['initialDateKey'],
      ),
      isPostponed: _jsonBoolFromDynamic(
        m['is_postponed'] ?? m['isPostponed'] ?? false,
      ),
      rrule: () {
        final s = (m['rrule'] ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }(),
      exceptionDates: _parsePlanExceptionDatesForOffline(m['exception_dates']),
      reminderOffset: int.tryParse((m['reminder_offset'] ?? '').toString()),
      recurrenceInstanceDateKey: _normPlanRecurrenceInstanceKey(
        m['recurrence_instance_date_key'] ?? m['recurrenceInstanceDateKey'],
      ),
    );
  }

  static List<String> _parsePlanExceptionDatesForOffline(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e.toString().trim().length >= 10)
          e.toString().trim().substring(0, 10),
    ];
  }

  static String? _normPlanRecurrenceInstanceKey(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    if (s.length >= 10) return s.substring(0, 10);
    return null;
  }

  Future<void> _persistPlanningTasksDayCache(
    String targetDayStr,
    List<PlanningTask> plans,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final payload = plans
          .map(_planningTaskToDayCacheMap)
          .toList(growable: false);
      await prefs.setString(
        '${_scopedDataCacheKey('cache_plans_day_v1')}_$targetDayStr',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<List<PlanningTask>> _loadPlanningTasksDayCache(
    String targetDayStr,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(
        '${_scopedDataCacheKey('cache_plans_day_v1')}_$targetDayStr',
      );
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <PlanningTask>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        out.add(_planningTaskFromOfflineDayMap(Map<String, dynamic>.from(e)));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

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
      final q = await PlanMutationOutbox.load(prefs);
      if (q.isEmpty) return;
      var pendingTail = const <Map<String, dynamic>>[];
      var i = 0;
      for (; i < q.length; i++) {
        final item = Map<String, dynamic>.from(q[i]);
        final ok = await _flushOnePlanOutboxEntry(item, prefs);
        if (!ok) {
          item['retryCount'] = ((item['retryCount'] as num?)?.toInt() ?? 0) + 1;
          item['lastError'] = offlineSync.lastError ?? 'sync_failed';
          pendingTail = [item, ...q.sublist(i + 1)];
          break;
        }
      }
      if (pendingTail.isEmpty && i >= q.length) {
        await PlanMutationOutbox.replaceAll(prefs, []);
        offlineSync.clearErrors();
      } else if (pendingTail.isNotEmpty) {
        await PlanMutationOutbox.replaceAll(prefs, pendingTail);
      } else {
        await PlanMutationOutbox.replaceAll(prefs, q.sublist(i));
      }
      unawaited(offlineSync.refreshPendingCount());
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
    final next = current.copyWith(
      title: title,
      categoryId: categoryId,
      isDone: isDone,
      notesPlain: notesPlain,
      notesDeltaJson: notesDeltaJson,
      checklist: checklist,
      parentPlanId: parentPlanId,
      order: order,
      startTime: startTimeDisplay ?? startTime,
      endDateTime: endDateTimeDisplay ?? endDateTime,
      clearEnd: clearEnd,
      tags: tags,
      initialDateKey: planInitialDateKey,
      isPostponed: planIsPostponed,
      rrule: patchPlanAlarmRecurrence ? planRrule : null,
      exceptionDates: patchPlanAlarmRecurrence ? planExceptionDates : null,
      reminderOffset: patchPlanAlarmRecurrence ? planReminderOffset : null,
      clearRrule: patchPlanAlarmRecurrence && (planRrule ?? '').trim().isEmpty,
      clearReminderOffset:
          patchPlanAlarmRecurrence && planReminderOffset == null,
      isSynced: false,
    );
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
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_CANCEL: $e');
    }
  }

  Future<void> _enqueuePlanCreateMutation(
    Map<String, dynamic> body, {
    required String businessId,
    Object? error,
    String syncStatus = PlanMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      await PlanMutationOutbox.enqueue(
        prefs,
        PlanMutationOutbox.newPlanCreateItem(
          businessId: businessId,
          payload: normalized,
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ENQUEUE create: $e');
    }
  }

  Future<void> _enqueuePlanUpdateMutation({
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
      if (businessId.trim().isEmpty || normalized.isEmpty) return;
      await PlanMutationOutbox.enqueue(
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
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('PLAN_OUTBOX_ENQUEUE update: $e');
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
      body['user_id'] = _pidForPbFilter;
      try {
        final record = await _pb
            .collection(PbCollections.plans)
            .create(body: body);
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
        if (code == 401 || code == 403) {
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          return false;
        }
        if (_planMutationRetriableHttpCode(code)) {
          offlineSync.setLastError('HTTP $code');
          return false;
        }
        return true;
      } catch (e) {
        if (_planMutationRetriableHttpCode(0)) {
          offlineSync.setLastError('$e');
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
      final patchBody = Map<String, dynamic>.from(rawPayload);
      patchBody.remove('user_id');
      if (patchBody.isEmpty && tagsRaw == null) return true;
      final pbId = await _resolvePlanPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
        originalQueryId: originalInput,
      );
      if (pbId == null || pbId.isEmpty) return false;
      try {
        if (patchBody.isNotEmpty) {
          await _pb
              .collection(PbCollections.plans)
              .update(pbId, body: patchBody);
        }
        if (tagsRaw is List) {
          final ids = [
            for (final e in tagsRaw)
              if (e != null) e.toString().trim(),
          ].where((s) => s.isNotEmpty).toList();
          await _pb
              .collection(PbCollections.plans)
              .update(pbId, body: <String, dynamic>{kPbPlanTagsExpand: ids});
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
          return false;
        }
        return true;
      } catch (e) {
        if (_planMutationRetriableHttpCode(0)) {
          offlineSync.setLastError('$e');
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
        if (code == 401 || code == 403) {
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          return false;
        }
        if (_planMutationRetriableHttpCode(code)) {
          offlineSync.setLastError('HTTP $code');
          return false;
        }
        return true;
      } catch (e) {
        if (_planMutationRetriableHttpCode(0)) {
          offlineSync.setLastError('$e');
          return false;
        }
        return true;
      }
    }
    return true;
  }

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

  /// Debounced: reschedules OS plan reminders after timeline/plan cache refresh (no await on callers).
  void _requestPlanAlarmReschedule() {
    if (kIsWeb) return;
    _planAlarmRescheduleDebounceTimer?.cancel();
    _planAlarmRescheduleDebounceTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_reschedulePlanAlarmsWork());
    });
  }

  Future<void> _reschedulePlanAlarmsWork() async {
    if (kIsWeb) return;
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;
    if (!_isPlansTableConfigured) return;
    try {
      await NotificationService.instance.ensureInitialized();
    } catch (_) {
      return;
    }
    try {
      final all = await _fetchAllPlanningTasksForCurrentUser();
      final today = getTimelineDeviceLocalToday();
      final todayWall = DateTime(today.year, today.month, today.day);
      final endWall = todayWall.add(const Duration(days: 6));
      final windowTasks = _collectPlanningTasksForWallRange(
        all,
        todayWall,
        endWall,
      );
      await NotificationService.instance.syncAlarms(windowTasks);
    } catch (_) {}
  }

  /// Merges non-recurring day matches + JIT [expandRecurringPlans] for each wall day in [startWall]…[endWall] inclusive.
  List<PlanningTask> _collectPlanningTasksForWallRange(
    List<PlanningTask> allTemplates,
    DateTime startWall,
    DateTime endWall,
  ) {
    DateTime wallOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    var d = wallOnly(startWall);
    final last = wallOnly(endWall);
    if (last.isBefore(d)) return [];
    final out = <PlanningTask>[];
    while (!d.isAfter(last)) {
      final dk = '${d.year}-${_two(d.month)}-${_two(d.day)}';
      for (final t in allTemplates) {
        if (t.planRowIdForBackend.startsWith('optimistic-')) continue;
        if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
        if (t.startTime == null) continue;
        final taskDk =
            '${t.startTime!.year}-${_two(t.startTime!.month)}-${_two(t.startTime!.day)}';
        if (taskDk != dk) continue;
        out.add(t);
      }
      out.addAll(expandRecurringPlans(allTemplates, d, d));
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  void _notifyTimelineAfterRecordCacheMutation() {
    if (_recordCacheTimelineNotifyBatchDepth > 0) return;
    _emitTimelineRefreshRaw();
  }

  /// Ping planning/list subscribers. UI streams emit cache+overlay first; network refresh is debounced.
  void notifyPlanningRefresh({
    bool scheduleNetworkRefresh = true,
    bool pumpNetworkNow = false,
  }) {
    if (pumpNetworkNow) {
      _planningRefreshWantsNetworkPump = true;
    }
    if (!_planningRefreshController.isClosed) {
      _planningRefreshController.add(null);
    }
    _requestPlanAlarmReschedule();
    if (scheduleNetworkRefresh) {
      _planningNotifyNetworkDebounceTimer?.cancel();
      _planningNotifyNetworkDebounceTimer = Timer(
        const Duration(milliseconds: 400),
        () {
          unawaited(() async {
            await _ensureAllPlansUserCacheFresh(force: true);
            _planningRefreshWantsNetworkPump = true;
            if (!_planningRefreshController.isClosed) {
              _planningRefreshController.add(null);
            }
          }());
        },
      );
    }
  }

  String _planOptimisticDayKeyFor(PlanningTask task) {
    var dk = task.dateKey.trim();
    if (dk.length >= 10) return dk.substring(0, 10);
    if (task.startTime != null) {
      final st = task.startTime!;
      return '${st.year}-${_two(st.month)}-${_two(st.day)}';
    }
    return _kBacklogOptimisticDayKey;
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

  PlanningTask _preferConfirmedPlanningTask(PlanningTask a, PlanningTask b) {
    final aOpt = _isOptimisticPlanningTask(a);
    final bOpt = _isOptimisticPlanningTask(b);
    if (aOpt && !bOpt) return b;
    if (bOpt && !aOpt) return a;
    final aPb = (a.pocketRecordId?.trim() ?? '').length == 15;
    final bPb = (b.pocketRecordId?.trim() ?? '').length == 15;
    if (aPb && !bPb) return a;
    if (bPb && !aPb) return b;
    return b;
  }

  List<PlanningTask> _dedupePlanningTasksByBusinessId(
    List<PlanningTask> tasks,
  ) {
    final byBiz = <String, PlanningTask>{};
    final noBiz = <PlanningTask>[];
    for (final t in tasks) {
      final biz = _planBusinessUuidFromTask(t);
      if (biz == null || biz.isEmpty) {
        noBiz.add(t);
        continue;
      }
      final existing = byBiz[biz];
      byBiz[biz] = existing == null
          ? t
          : _preferConfirmedPlanningTask(existing, t);
    }
    return [...byBiz.values, ...noBiz];
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

  bool _planTagsEqual(List<Tag> a, List<Tag> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].pbRecordId != b[i].pbRecordId ||
          a[i].name != b[i].name ||
          a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }

  List<Tag> _refreshTaskTagsFromCatalog(List<Tag> tags) {
    if (tags.isEmpty || _userTagsCatalogCache.isEmpty) return tags;
    final byPb = <String, Tag>{
      for (final t in _userTagsCatalogCache)
        if ((t.pbRecordId ?? '').trim().isNotEmpty) t.pbRecordId!: t,
    };
    if (byPb.isEmpty) return tags;
    return [for (final tag in tags) byPb[tag.pbRecordId ?? ''] ?? tag];
  }

  /// After tag catalog PATCH/create/delete, refresh embedded tag chips on cached plans.
  void syncEmbeddedPlanTagsFromCatalog() {
    var changed = false;
    final nextCache = <PlanningTask>[];
    for (final t in _allPlansUserCache) {
      final nt = _refreshTaskTagsFromCatalog(t.tags);
      if (!_planTagsEqual(nt, t.tags)) {
        changed = true;
        nextCache.add(t.copyWith(tags: nt));
      } else {
        nextCache.add(t);
      }
    }
    if (changed) _allPlansUserCache = nextCache;
    for (final m in _planningOptimisticByDateKey.values) {
      for (final e in m.entries.toList()) {
        final nt = _refreshTaskTagsFromCatalog(e.value.tags);
        if (!_planTagsEqual(nt, e.value.tags)) {
          m[e.key] = e.value.copyWith(tags: nt);
          changed = true;
        }
      }
    }
    if (changed) {
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
    }
  }

  List<PlanningTask> _filterBacklogFromAll(
    List<PlanningTask> all, {
    int? categoryId,
    bool includeCompleted = false,
  }) {
    final out = <PlanningTask>[];
    for (final t in all) {
      final pid = t.planRowIdForBackend.trim();
      if (pid.startsWith('optimistic-') || pid.startsWith('virt-')) continue;
      if (!includeCompleted && t.isDone) continue;
      if (t.startTime != null) continue;
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
      if (t.isBacklogChildItem) continue;
      final dk = t.dateKey.trim();
      if (dk.length >= 10) continue;
      if (categoryId != null && t.categoryId != categoryId) continue;
      out.add(t);
    }
    out.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return out;
  }

  List<PlanningTask> _mergeBacklogOptimistic(List<PlanningTask> server) {
    final overlay = _planningOptimisticByDateKey[_kBacklogOptimisticDayKey];
    if (overlay == null || overlay.isEmpty) return server;
    final byId = <String, PlanningTask>{
      for (final t in server) t.planRowIdForBackend: t,
    };
    for (final e in overlay.entries) {
      final t = e.value;
      if (t.startTime != null) continue;
      final dk = t.dateKey.trim();
      if (dk.length >= 10) continue;
      byId[e.key] = t;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return merged;
  }

  /// Instant backlog snapshot (cache + optimistic overlay) — no network.
  List<PlanningTask> getBacklogPlansSnapshot({
    int? categoryId,
    bool includeCompleted = false,
  }) {
    final base = _filterBacklogFromAll(
      _allPlansUserCache,
      categoryId: categoryId,
      includeCompleted: includeCompleted,
    );
    return _mergeBacklogOptimistic(base);
  }

  List<PlanningTask> _filterPlansForWallDay(
    List<PlanningTask> all,
    DateTime selectedDate,
  ) {
    final targetDayStr =
        '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}';
    final plans = <PlanningTask>[];
    for (final t in all) {
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
      if (t.startTime == null) continue;
      final anchorUtc = _profileUtcFromWall(t.startTime!).toUtc();
      final w = _profileWallFromUtc(anchorUtc);
      final planDayStr = '${w.year}-${_two(w.month)}-${_two(w.day)}';
      if (planDayStr != targetDayStr) continue;
      plans.add(t);
    }
    plans.addAll(expandRecurringPlans(all, selectedDate, selectedDate));
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

  /// Stats / Plan-vs-fact audit: listen to refresh planning data (same signal as [notifyPlanningRefresh]).
  Stream<void> get planningRefreshNotifications =>
      _planningRefreshController.stream;

  /// Apply client-side plan row for instant list updates; cleared when server PATCH succeeds.
  void applyOptimisticPlanningTask(PlanningTask task) {
    final pid = task.planRowIdForBackend.trim();
    if (pid.isEmpty || pid == '0') return;
    for (final m in _planningOptimisticByDateKey.values) {
      m.remove(pid);
    }
    final dk = _planOptimisticDayKeyFor(task);
    _planningOptimisticByDateKey.putIfAbsent(dk, () => {})[pid] = task;
    _upsertPlanInUserCache(task);
  }

  void clearOptimisticPlanningForPlanRow(String planRowIdForBackend) {
    final p = planRowIdForBackend.trim();
    if (p.isEmpty) return;
    final keysToRemove = <String>{p};
    if (p.startsWith('optimistic-')) {
      final biz = p.substring('optimistic-'.length).trim();
      if (biz.isNotEmpty) keysToRemove.add(biz);
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final key in keysToRemove) {
        m.remove(key);
      }
      m.removeWhere((key, task) {
        if (keysToRemove.contains(key)) return true;
        final biz = _planBusinessUuidFromTask(task);
        return biz != null && keysToRemove.contains(biz);
      });
    }
    if (p.startsWith('optimistic-')) {
      final clientPlanId = p.substring('optimistic-'.length).trim();
      if (clientPlanId.isNotEmpty) {
        _purgeOptimisticPlanRowsFromUserCache(clientPlanId);
        unawaited(_cancelPendingPlanMutationsForBusinessId(clientPlanId));
      }
    }
  }

  List<PlanningTask> _mergePlanningOptimistic(
    String targetDayStr,
    List<PlanningTask> serverPlans,
  ) {
    final hiddenOnThisDay = <String>{};
    for (final e in _planningOptimisticByDateKey.entries) {
      if (e.key == targetDayStr) continue;
      hiddenOnThisDay.addAll(e.value.keys);
    }
    final filtered = serverPlans
        .where((t) => !hiddenOnThisDay.contains(t.planRowIdForBackend))
        .toList();
    final overlay = _planningOptimisticByDateKey[targetDayStr];
    if (overlay == null || overlay.isEmpty) return filtered;
    final byId = <String, PlanningTask>{
      for (final t in filtered) t.planRowIdForBackend: t,
    };
    // Overlay wins for any row id present (tags/title edits until PATCH clears the overlay).
    for (final e in overlay.entries) {
      byId[e.key] = e.value;
    }
    final merged = _dedupePlanningTasksByBusinessId(byId.values.toList());
    merged.sort((a, b) {
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
    return merged;
  }

  Stream<List<PlanningTask>> get tasksStream => Stream.multi((c) {
    c.add(List.from(_tasksCache));
    _tasksController.stream.listen(c.add, onError: c.addError);
  });

  /// 0..1 title similarity for plan–record linking heuristics (not category matching).
  static double titleSimilarityForPlanLink(String a, String b) {
    final na = a.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final nb = b.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;
    final dist = DatabaseService._levenshteinDistance(na, nb);
    final denom = max(na.length, nb.length);
    if (denom <= 0) return 0;
    return 1.0 - dist / denom;
  }

  static Set<String> _planLinkTokenSet(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return {};
    return t
        .split(RegExp(r'[\s,.;:!?\-–—/\\]+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 2)
        .toSet();
  }

  /// Shared significant words / min(|A|,|B|) — good for "Уборка квартиры" vs "Уборка дома".
  static double planLinkWordOverlapRatio(String a, String b) {
    final ta = _planLinkTokenSet(a);
    final tb = _planLinkTokenSet(b);
    if (ta.isEmpty || tb.isEmpty) return 0;
    var inter = 0;
    for (final w in ta) {
      if (tb.contains(w)) inter++;
    }
    if (inter == 0) return 0;
    return inter / min(ta.length, tb.length);
  }

  /// Softer than pure Levenshtein: words + substring hint + legacy ratio.
  static double titlePlanLinkScore(String a, String b) {
    final lev = titleSimilarityForPlanLink(a, b);
    final word = planLinkWordOverlapRatio(a, b);
    final na = a.trim().toLowerCase();
    final nb = b.trim().toLowerCase();
    var contain = 0.0;
    if (na.isNotEmpty && nb.isNotEmpty) {
      if (na.contains(nb) || nb.contains(na)) contain = 0.72;
    }
    return max(lev, max(word, contain));
  }

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

  /// Broadcast when planning cache should be re-read by UI (optimistic PATCH, realtime, etc.).
  Stream<void> get planningRefreshEvents => _planningRefreshController.stream;

  /// Next `order` for a new plan on this wall day (for optimistic + POST).
  /// Plans for a wall day (same source as Planning tab). For UI manual `source_plan_id` linking.
  Future<List<PlanningTask>> getPlanningTasksForWallDate(DateTime wallDay) =>
      _fetchPlanningTasksForDate(wallDay);

  /// Warm plans cache for Calendar month indicators (no per-day network fan-out).
  Future<void> warmPlanningCacheForCalendar() =>
      _ensureAllPlansUserCacheFresh();

  /// Group scheduled plans by wall `YYYY-MM-DD` for [startWall]…[endWall] from Brain cache.
  Map<String, List<PlanningTask>> planningTasksGroupedByWallDayForRange(
    DateTime startWall,
    DateTime endWall,
  ) {
    final collected = _collectPlanningTasksForWallRange(
      _allPlansUserCache,
      startWall,
      endWall,
    );
    final map = <String, List<PlanningTask>>{};
    for (final t in collected) {
      if (t.startTime == null) continue;
      final dk = planningWallScheduleDateKey(t);
      if (dk.length < 10) continue;
      map.putIfAbsent(dk, () => <PlanningTask>[]).add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final as = a.startTime;
        final bs = b.startTime;
        if (as == null || bs == null) return 0;
        return as.compareTo(bs);
      });
    }
    return map;
  }

  /// Wall-clock estimate from plan start/end (profile wall [PlanningTask] times). Null if unknown.
  static int? planningWallEstimateSeconds(PlanningTask task) {
    final a = task.startTime;
    final b = task.endDateTime;
    if (a == null || b == null) return null;
    final sec = b.difference(a).inSeconds;
    if (sec <= 0) return null;
    return sec;
  }

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
        final plans = _filterPlansForWallDay(_allPlansUserCache, selectedDate);
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
  }

  /// Wall `YYYY-MM-DD` where the plan is currently scheduled (start wall, else [PlanningTask.dateKey]).
  String planningWallScheduleDateKey(PlanningTask t) {
    final st = t.startTime;
    if (st != null) {
      return '${st.year}-${_two(st.month)}-${_two(st.day)}';
    }
    final dk = t.dateKey.trim();
    if (dk.length >= 10) return dk.substring(0, 10);
    return '';
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
    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final list = await _pb
          .collection(PbCollections.plans)
          .getFullList(
            expand: kPbPlanTagsExpand,
            filter: 'user_id = "$uid"',
            batch: 200,
          );
      final out = [
        for (final r in list)
          _planningTaskFromPocketRecord(r, pocketTagCatalog: tagCatalog),
      ];
      _allPlansUserCache = out;
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

  /// True when [id] is a real category (not uncategorized / unset).
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
    }, pocketTagCatalog: pocketTagCatalog);
  }

  String _normalizeRruleStringForDecoder(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.toUpperCase().startsWith('RRULE:')) {
      s = 'RRULE:$s';
    }
    return s;
  }

  DateTime? _utcDateOnlyFromPlanDateKey(String dk) {
    if (dk.length < 10) return null;
    final y = int.tryParse(dk.substring(0, 4));
    final m = int.tryParse(dk.substring(5, 7));
    final d = int.tryParse(dk.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// JIT: expand [PlanningTask.rrule] into virtual rows between [viewStart] and [viewEnd] (wall dates).
  List<PlanningTask> expandRecurringPlans(
    List<PlanningTask> allPlans,
    DateTime viewStart,
    DateTime viewEnd,
  ) {
    final out = <PlanningTask>[];
    final templates = allPlans
        .where((p) => (p.rrule?.trim().isNotEmpty ?? false))
        .toList();
    if (templates.isEmpty) return out;

    DateTime wallOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final startWall = wallOnly(viewStart);
    final endWall = wallOnly(viewEnd);
    if (endWall.isBefore(startWall)) return out;

    final windowStartUtc = wall_clock
        .utcWallClockDayBoundsUtc(
          startWall,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        )
        .$1;
    final windowEndUtc = wall_clock
        .utcWallClockDayBoundsUtc(
          endWall,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        )
        .$2;

    for (final template in templates) {
      if (template.isDone) continue;
      final pr = template.pocketRecordId?.trim() ?? '';
      if (pr.isEmpty) continue;
      final st = template.startTime;
      if (st == null) continue;
      RecurrenceRule rule;
      try {
        rule = RecurrenceRule.fromString(
          _normalizeRruleStringForDecoder(template.rrule!.trim()),
          options: const RecurrenceRuleFromStringOptions.lenient(),
        );
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
            '[RRULE] skip plan $pr: parse failed for "${template.rrule}"',
          );
        }
        continue;
      }

      final baseStartUtc = _profileUtcFromWall(st);
      final dur = template.endDateTime != null
          ? _profileUtcFromWall(template.endDateTime!).difference(baseStartUtc)
          : Duration.zero;
      final durClamped = dur.isNegative ? Duration.zero : dur;

      final ex = <String>{
        for (final e in template.exceptionDates)
          if (e.trim().length >= 10) e.trim().substring(0, 10),
      };

      final List<DateTime> instances;
      try {
        instances = rule.getAllInstances(
          start: baseStartUtc.toUtc(),
          after: windowStartUtc,
          includeAfter: true,
          before: windowEndUtc,
          includeBefore: true,
        );
      } catch (_) {
        if (kDebugMode) {
          debugPrint('[RRULE] skip plan $pr: iteration failed');
        }
        continue;
      }

      for (final instanceUtc in instances) {
        final wall = _profileWallFromUtc(instanceUtc);
        final wallDay = wallOnly(wall);
        if (wallDay.isBefore(startWall) || wallDay.isAfter(endWall)) {
          continue;
        }
        final dk = '${wall.year}-${_two(wall.month)}-${_two(wall.day)}';
        if (ex.contains(dk)) continue;

        final startWallInstance = _profileWallFromUtc(instanceUtc);
        DateTime? endWallInstance;
        if (durClamped.inSeconds > 0) {
          endWallInstance = _profileWallFromUtc(instanceUtc.add(durClamped));
        }

        out.add(
          template.copyWith(
            planRowId: 'virt-$pr-$dk',
            dateKey: dk,
            startTime: startWallInstance,
            date: _utcDateOnlyFromPlanDateKey(dk),
            endDateTime: endWallInstance,
            recurrenceInstanceDateKey: dk,
            clearRrule: true,
            exceptionDates: const [],
          ),
        );
      }
    }
    return out;
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

  /// Natural-language → structured task hints via `POST …/api/ai/parse-task` only.
  /// Flutter stays **LLM-agnostic**; routing and provider live on the server.
  Future<AiParsedTaskHint?> parseTaskViaAiBackend({
    required String rawUtterance,
    String? wallDateKey,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    final text = rawUtterance.trim();
    if (text.isEmpty) return null;
    try {
      await ensurePocketBaseReady();
      final token = _pb.authStore.token.trim();
      if (token.isEmpty) return null;
      final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$base${PbAppApiRoutes.aiParseTask}');
      final payload = <String, dynamic>{
        'text': text,
        'ui_locale': currentLocale.value,
        if (wallDateKey != null && wallDateKey.trim().isNotEmpty)
          'wall_date_key': wallDateKey.trim(),
      };
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      int? ih(dynamic v) => v == null ? null : int.tryParse(v.toString());
      return AiParsedTaskHint(
        cleanedTitle:
            map['cleaned_title']?.toString() ?? map['title']?.toString(),
        startHour: ih(map['start_hour'] ?? map['hour']),
        startMinute: ih(map['start_minute'] ?? map['minute']),
        endHour: ih(map['end_hour']),
        endMinute: ih(map['end_minute']),
        rawJson: map,
      );
    } catch (_) {
      return null;
    }
  }

  static final RegExp _aiPlanningHhmm = RegExp(r'^(\d{1,2}):(\d{2})$');

  static String _normalizeAiPlanningTimeHHmm(String raw) {
    final t = raw.trim();
    final m = _aiPlanningHhmm.firstMatch(t);
    if (m != null) {
      final h = int.tryParse(m.group(1) ?? '') ?? 9;
      final mi = int.tryParse(m.group(2) ?? '') ?? 0;
      final hh = h.clamp(0, 23);
      final mm = mi.clamp(0, 59);
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }
    return '09:00';
  }

  /// Accept alternate key casing / missing fields; defaults match Smart Plan expectations.
  static Map<String, dynamic> _normalizeAiPlanningItem(Map<String, dynamic> m) {
    final title = (m['title'] ?? m['Title'] ?? '').toString().trim();

    var startRaw = (m['startTime'] ?? m['start_time'] ?? m['time'] ?? '09:00')
        .toString();
    startRaw = startRaw.trim();
    if (startRaw.isEmpty) startRaw = '09:00';

    final durRaw =
        m['durationMinutes'] ?? m['duration_minutes'] ?? m['duration'] ?? 60;
    var durationMinutes = 60;
    if (durRaw is int) {
      durationMinutes = durRaw;
    } else if (durRaw is num) {
      durationMinutes = durRaw.round();
    } else {
      durationMinutes = int.tryParse(durRaw.toString().trim()) ?? 60;
    }
    if (durationMinutes < 1) durationMinutes = 1;
    if (durationMinutes > 24 * 60) durationMinutes = 24 * 60;

    final hhmm = _normalizeAiPlanningTimeHHmm(startRaw);

    final catRaw =
        m['category'] ??
        m['Category'] ??
        m['categoryName'] ??
        m['category_name'];
    String? categoryLabel;
    if (catRaw != null) {
      final s = catRaw.toString().trim();
      if (s.isNotEmpty) {
        final sl = s.toLowerCase();
        if (sl != 'uncategorized' &&
            sl != 'null' &&
            sl != 'none' &&
            sl != 'n/a') {
          categoryLabel = s;
        }
      }
    }

    return <String, dynamic>{
      'title': title,
      'startTime': hhmm,
      'durationMinutes': durationMinutes,
      'category': categoryLabel,
    };
  }

  static List<dynamic>? _aiPlanningItemsListFromDecoded(dynamic decoded) {
    if (decoded is List<dynamic>) return decoded;
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    final raw =
        map['items'] ??
        map['tasks'] ??
        map['planning_items'] ??
        map['schedule'];
    if (raw is List<dynamic>) return raw;
    return null;
  }

  /// Smart Plan: natural-language batch via `POST …/api/ai/parse-task` with `output: planning_items`.
  /// Server returns a JSON object whose `items` / `tasks` / `planning_items` / `schedule` key holds
  /// the task list. Client stays vendor-neutral.
  Future<List<Map<String, dynamic>>> parsePlanningItemsViaAiBackend({
    required String rawText,
    required List<String> allowedCategoryNames,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty) return <Map<String, dynamic>>[];
    if (!_isInitialized || !_hasAuthenticatedUserId) {
      throw AiBackendException('Not signed in');
    }
    await ensurePocketBaseReady();
    final token = _pb.authStore.token.trim();
    if (token.isEmpty) {
      throw AiBackendException('Not signed in');
    }
    final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base${PbAppApiRoutes.aiParseTask}');
    final names = List<String>.from(allowedCategoryNames)
      ..removeWhere((s) => s.trim().isEmpty);
    final payload = <String, dynamic>{
      'text': text,
      'ui_locale': currentLocale.value,
      'output': 'planning_items',
      'allowed_category_names': names,
    };
    late final http.Response res;
    try {
      res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      throw AiBackendException('Network error: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiBackendException('Request failed (${res.statusCode})');
    }
    late final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      throw AiBackendException('Invalid response: $e');
    }
    final rawList = _aiPlanningItemsListFromDecoded(decoded);
    if (rawList == null) {
      throw AiBackendException('No planning items in response');
    }
    final out = <Map<String, dynamic>>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final m = _normalizeAiPlanningItem(
        Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
      final title = (m['title'] as String).trim();
      if (title.isEmpty) continue;
      out.add(m);
    }
    return out;
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

  Future<void> addPlannedTask(
    String dateKey,
    String taskText, {
    int? categoryId,
    bool isManual = false,
    List<Tag>? tags,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked addPlannedTask because plans table id equals records table id.',
      );
      return;
    }
    try {
      final parsed = getCleanTitleAndTags(taskText);
      int cid = categoryId ?? defaultCategoryId ?? 0;
      if (!isManual) {
        cid = identifyCategory(parsed.title)?.id ?? (defaultCategoryId ?? 0);
      }
      await addPlanningTask(
        PlanningTask(
          id: 0,
          title: parsed.title,
          categoryId: cid,
          dateKey: dateKey,
          order: 0,
          tags: tags ?? const [],
        ),
      );
    } catch (_) {}
  }

  /// Planning-only voice / quick-add: same parsing as Planning UI, then [addPlanningTask].
  Future<bool> addPlanningTaskFromVoiceText({
    required String rawText,
    required DateTime wallDay,
    int? categoryIdHint,
    bool isBacklog = false,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) {
      DatabaseService._log('TABLE_GUARD: blocked addPlanningTaskFromVoiceText');
      return false;
    }

    if (isBacklog) {
      final stripped = SmartInputParser.backlogTitleFromRaw(rawText);
      final gt = getCleanTitleAndTags(stripped);
      final title = gt.title.trim();
      if (title.isEmpty) return false;
      final match = identifyCategory(title);
      final categoryId =
          match?.id ??
          categoryIdHint ??
          defaultCategoryId ??
          (rules.isNotEmpty ? rules.first.id : 0);

      if (getCategoryRuleById(categoryId) == null) {
        DatabaseService._log(
          'VOICE_PLAN: blocked — unknown category $categoryId',
        );
        return false;
      }

      final nextOrder = await nextBacklogPlanningOrder();
      final clientPlanId = DatabaseService.newClientUuid();

      return addPlanningTask(
        PlanningTask(
          id: 0,
          title: title,
          categoryId: categoryId,
          isDone: false,
          dateKey: '',
          order: nextOrder,
          startTime: null,
          endDateTime: null,
          rrule: null,
          checklist: const [],
          parentPlanId: null,
          tags: const [],
          isSynced: false,
        ),
        clientPlanId: clientPlanId,
      );
    }

    final ymd = DateTime(wallDay.year, wallDay.month, wallDay.day);
    final taskDateKey = '${ymd.year}-${_two(ymd.month)}-${_two(ymd.day)}';

    final range = SmartInputParser.parseTitleForTimeRange(rawText);
    SmartTimeParseResult? parsed;
    String title;
    DateTime? startStored;
    DateTime? endStored;

    title = SmartInputParser.preservedTitleFromRaw(rawText);
    if (title.isEmpty) return false;

    if (range != null) {
      startStored = displayTimeToUtc(range.startWallOn(ymd));
      endStored = displayTimeToUtc(range.endWallOn(ymd));
    } else {
      parsed = SmartInputParser.parseTitleForScheduledTime(rawText);
      startStored = parsed != null
          ? displayTimeToUtc(parsed.wallDateTimeOn(ymd))
          : null;
      endStored = null;
    }

    final match = identifyCategory(title);
    final categoryId =
        match?.id ??
        categoryIdHint ??
        defaultCategoryId ??
        (rules.isNotEmpty ? rules.first.id : 0);
    if (startStored == null && range == null && parsed == null) {
      final defaultWall = wallDateTimeForCategoryDefaultPlanTime(
        categoryId,
        ymd,
      );
      if (defaultWall != null) {
        startStored = displayTimeToUtc(defaultWall);
      }
    }

    if (getCategoryRuleById(categoryId) == null) {
      DatabaseService._log(
        'VOICE_PLAN: blocked — unknown category $categoryId',
      );
      return false;
    }

    final nextOrder = await nextPlanningOrderForDate(ymd);
    final clientPlanId = DatabaseService.newClientUuid();

    return addPlanningTask(
      PlanningTask(
        id: 0,
        title: title,
        categoryId: categoryId,
        isDone: false,
        dateKey: taskDateKey,
        order: nextOrder,
        startTime: startStored,
        endDateTime: endStored,
        checklist: const [],
        parentPlanId: null,
        tags: const [],
        isSynced: false,
      ),
      clientPlanId: clientPlanId,
    );
  }

  Future<void> addPlan({
    required String title,
    required int categoryId,
    required String dateKey,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked addPlan because plans table id equals records table id.',
      );
      return;
    }
    unawaited(() async {
      try {
        DateTime? defaultStart;
        final d = dateKey.trim();
        if (d.length >= 10) {
          final y = int.tryParse(d.substring(0, 4));
          final m = int.tryParse(d.substring(5, 7));
          final day = int.tryParse(d.substring(8, 10));
          if (y != null && m != null && day != null) {
            final wall = wallDateTimeForCategoryDefaultPlanTime(
              categoryId,
              DateTime(y, m, day),
            );
            if (wall != null) defaultStart = displayTimeToUtc(wall);
          }
        }
        await addPlanningTask(
          PlanningTask(
            id: 0,
            title: title,
            categoryId: categoryId,
            dateKey: dateKey,
            order: 0,
            startTime: defaultStart,
          ),
        );
      } catch (_) {}
    }());
  }

  /// Planning list stream. **No periodic polling** (PageView keeps many days alive).
  /// [listenToGlobalPlanningRefresh]: only the **visible** planning day should be `true` so [notifyPlanningRefresh]
  /// does not fan out identical GETs to every off-screen [PlanningPage].
  Stream<List<PlanningTask>> planningStream(
    DateTime selectedDate, {
    bool listenToGlobalPlanningRefresh = true,
  }) {
    return Stream.multi((controller) {
      StreamSubscription<void>? pokeSub;
      var busy = false;
      final targetDayStr =
          '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}';

      void emitFastFromCache() {
        if (controller.isClosed) return;
        List<PlanningTask> base = [];
        if (_allPlansUserCache.isNotEmpty) {
          base = _filterPlansForWallDay(_allPlansUserCache, selectedDate);
        }
        if (base.isEmpty) {
          unawaited(() async {
            final offline = await _loadPlanningTasksDayCache(targetDayStr);
            if (!controller.isClosed && offline.isNotEmpty) {
              controller.add(_mergePlanningOptimistic(targetDayStr, offline));
            }
          }());
          return;
        }
        controller.add(_mergePlanningOptimistic(targetDayStr, base));
      }

      Future<void> pump({bool network = true}) async {
        emitFastFromCache();
        if (!network || busy || controller.isClosed) return;
        busy = true;
        try {
          List<PlanningTask> tasks;
          try {
            tasks = await _fetchPlanningTasksForDate(selectedDate);
          } catch (_) {
            tasks = <PlanningTask>[];
          }
          if (!controller.isClosed) controller.add(tasks);
        } finally {
          busy = false;
        }
      }

      emitFastFromCache();
      unawaited(pump());
      if (listenToGlobalPlanningRefresh) {
        pokeSub = _planningRefreshController.stream.listen((_) {
          final wantsNetwork = _planningRefreshWantsNetworkPump;
          if (wantsNetwork) {
            _planningRefreshWantsNetworkPump = false;
          }
          final stale =
              wantsNetwork ||
              _allPlansUserCache.isEmpty ||
              _allPlansUserCacheFetchedAt == null ||
              DateTime.now().difference(_allPlansUserCacheFetchedAt!) >
                  _allPlansUserCacheFreshTtl;
          unawaited(pump(network: stale));
        });
      }
      controller.onCancel = () {
        pokeSub?.cancel();
      };
    });
  }

  Future<Map<String, dynamic>> _buildPocketPlanCreateBody(
    PlanningTask task, {
    required String titleTrimmed,
    required String clientPlanId,
    required Object categoryFieldForPlan,
  }) async {
    final body = <String, dynamic>{
      'plan_id': clientPlanId,
      'user_id': _pidForPbFilter,
      'category_id': categoryFieldForPlan.toString(),
      'title': titleTrimmed,
      'is_done': task.isDone,
      'checklist': task.checklist.isNotEmpty
          ? List<dynamic>.from(task.checklist)
          : <dynamic>[],
      'order': task.order,
    };
    final isDatelessBacklog =
        task.startTime == null && task.dateKey.trim().length < 10;
    if (task.startTime != null) {
      body['start_time'] = task.startTime!.toUtc().toIso8601String();
    } else if (!isDatelessBacklog) {
      final dk = task.dateKey.trim();
      if (dk.length >= 10) {
        final iso = _planStartUtcIsoFromDateKey(dk);
        if (iso != null) body['start_time'] = iso;
      }
    }
    if (task.endDateTime != null) {
      body['end_time'] = task.endDateTime!.toUtc().toIso8601String();
    }
    if (task.parentPlanPocketId != null &&
        task.parentPlanPocketId!.trim().isNotEmpty) {
      body['parent_plan_id'] = task.parentPlanPocketId!.trim();
    } else if (task.parentPlanId != null) {
      body['parent_plan_id'] = task.parentPlanId.toString();
    }
    final np = task.notesPlain?.trim() ?? '';
    if (np.isNotEmpty) {
      body['notes_plain'] = np;
    }
    final ndRaw = task.notesDeltaJson?.trim() ?? '';
    if (ndRaw.isNotEmpty) {
      try {
        body['notes_delta'] = jsonDecode(ndRaw);
      } catch (_) {}
    }
    final idk = task.initialDateKey?.trim() ?? '';
    if (idk.length >= 10) {
      body['initial_date_key'] = idk.substring(0, 10);
    } else {
      final dk = task.dateKey.trim();
      if (dk.length >= 10) {
        body['initial_date_key'] = dk.substring(0, 10);
      }
    }
    body['is_postponed'] = task.isPostponed;
    final rruleTrim = task.rrule?.trim() ?? '';
    if (rruleTrim.isNotEmpty) {
      body['rrule'] = rruleTrim;
      body['exception_dates'] = List<String>.from(task.exceptionDates);
    }
    if (task.reminderOffset != null) {
      body['reminder_offset'] = task.reminderOffset;
    }
    if (task.tags.isNotEmpty) {
      final pbIds = await _pbTagRecordIdsFromTags(task.tags);
      if (pbIds.isNotEmpty) {
        body['tags_link'] = pbIds;
      }
    }
    return body;
  }

  Future<void> _syncPlanTagsPocket(String planRecordId, List<Tag> tags) async {
    final rid = planRecordId.trim();
    if (rid.isEmpty) return;
    try {
      final pbIds = await _pbTagRecordIdsFromTags(tags);
      if (tags.isNotEmpty &&
          pbIds.length < tags.where((t) => t.rendersAsChip).length &&
          kDebugMode) {
        debugPrint(
          '[PB] _syncPlanTagsPocket: resolved ${pbIds.length} link id(s) '
          'from ${tags.length} tag(s); missing rows need pbRecordId / tag_id in catalog. plan=$rid',
        );
      }
      await _pb
          .collection(PbCollections.plans)
          .update(rid, body: <String, dynamic>{kPbPlanTagsExpand: pbIds});
    } catch (e, st) {
      DatabaseService._log('SYNC_PLAN_TAGS_PB: $e');
      DatabaseService._log(st.toString());
    }
  }

  Future<bool> _addPlanningTaskPocket(
    PlanningTask task, {
    required String titleTrimmed,
    required String clientPlanId,
    required Object categoryFieldForPlan,
  }) async {
    final optimisticId = 'optimistic-$clientPlanId';
    applyOptimisticPlanningTask(
      task.copyWith(
        pocketRecordId: optimisticId,
        planRowId: clientPlanId,
        isSynced: false,
      ),
    );
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    late final Map<String, dynamic> body;
    try {
      body = await _buildPocketPlanCreateBody(
        task,
        titleTrimmed: titleTrimmed,
        clientPlanId: clientPlanId,
        categoryFieldForPlan: categoryFieldForPlan,
      );
    } catch (e, st) {
      DatabaseService._log('ADD_PLAN_BUILD_BODY: $e');
      DatabaseService._log(st.toString());
      clearOptimisticPlanningForPlanRow(optimisticId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return false;
    }
    try {
      final record = await _pb
          .collection(PbCollections.plans)
          .create(body: body);
      if (task.tags.isNotEmpty) {
        await _syncPlanTagsPocket(record.id, task.tags);
      }
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final merged = task.tags.isNotEmpty
          ? await _pb
                .collection(PbCollections.plans)
                .getOne(record.id, expand: kPbPlanTagsExpand)
          : record;
      final fromServer = _planningTaskFromPocketRecord(
        merged,
        pocketTagCatalog: tagCatalog,
      );
      _upsertPlanInUserCache(fromServer);
      _allPlansUserCacheFetchedAt = DateTime.now();
      clearOptimisticPlanningForPlanRow(optimisticId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return true;
    } on ClientException catch (e, st) {
      DatabaseService._log('ADD_PLAN_PB: $e');
      DatabaseService._log(st.toString());
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        await _enqueuePlanCreateMutation(
          body,
          businessId: clientPlanId,
          error: code,
          syncStatus: PlanMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        return true;
      }
      if (_planMutationRetriableHttpCode(code) || _pbHttpBackoffActive) {
        await _enqueuePlanCreateMutation(
          body,
          businessId: clientPlanId,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      clearOptimisticPlanningForPlanRow(optimisticId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return false;
    } catch (e, st) {
      DatabaseService._log('ADD_PLAN_PB: $e');
      DatabaseService._log(st.toString());
      await _enqueuePlanCreateMutation(
        body,
        businessId: clientPlanId,
        error: e,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    }
  }

  Future<bool> addPlanningTask(
    PlanningTask task, {
    String? clientPlanId,
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked addPlanningTask because plans table id equals records table id.',
      );
      AppSnack.failed();
      return false;
    }
    try {
      final catRule = getCategoryRuleById(task.categoryId);
      if (catRule == null) {
        DatabaseService._log(
          'ADD_PLAN: blocked — unknown category local id ${task.categoryId}',
        );
        AppSnack.failed();
        return false;
      }
      // Noco **Link** / FK columns on `plans.category_id` often expect the linked row’s system **Id** (int),
      // not the business slug. Prefer [CategoryRule.nocoId]; fall back to string PK like [addPlan] / DATA_MAP.
      final Object categoryFieldForPlan;
      final catNocoSys = _categoryBackendRowIdStrict(catRule);
      if (catNocoSys != null) {
        categoryFieldForPlan = catNocoSys;
      } else {
        final catStr = _categoryStringPkForApi(catRule);
        if (catStr != null && catStr.isNotEmpty) {
          categoryFieldForPlan = catStr;
        } else {
          categoryFieldForPlan = _recordCategoryBusinessPkForApi(
            task.categoryId,
          );
        }
      }
      final titleTrimmed = task.title.trim();
      if (titleTrimmed.isEmpty) {
        DatabaseService._log('ADD_PLAN: blocked — empty title');
        AppSnack.failed();
        return false;
      }
      final cid = (clientPlanId != null && clientPlanId.trim().isNotEmpty)
          ? clientPlanId.trim()
          : DatabaseService._newClientRecordUuid();
      return _addPlanningTaskPocket(
        task,
        titleTrimmed: titleTrimmed,
        clientPlanId: cid,
        categoryFieldForPlan: categoryFieldForPlan,
      );
    } catch (e, st) {
      DatabaseService._log('[ADD_PLAN][FAIL] exception: $e\n$st');
      return false;
    }
  }

  void _cancelPlanOrderDebounceTimer() {
    _planOrderDebounceTimer?.cancel();
    _planOrderDebounceTimer = null;
  }

  /// Seeds baseline **once** per reorder session from the list as shown **before** the drag (server orders).
  void _ensurePlanningOrderBaseline(List<PlanningTask> tasksWithServerOrders) {
    if (_planReorderBaselineByPlanId != null) return;
    final m = <String, int>{};
    for (final t in tasksWithServerOrders) {
      if (t.planRowIdForBackend.startsWith('optimistic-')) continue;
      final id = t.planRowIdForBackend.trim();
      if (id.isEmpty) continue;
      m[id] = t.order;
    }
    _planReorderBaselineByPlanId = m;
  }

  Future<void> _persistPlanningTaskOrdersBulkNow(
    List<PlanningTask> ordered,
  ) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) return;

    try {
      await ensurePocketBaseReady();
      for (var i = 0; i < ordered.length; i++) {
        final t = ordered[i];
        if (t.planRowIdForBackend.startsWith('optimistic-')) continue;
        final id = t.planRowIdForBackend.trim();
        if (id.isEmpty) continue;
        final base = _planReorderBaselineByPlanId?[id];
        if (base != null && base == i) continue;
        final restId = await _resolvePlanRestId(
          id,
          planBusinessId: t.planRowId,
        );
        await _pb
            .collection(PbCollections.plans)
            .update(
              restId,
              body: <String, dynamic>{'user_id': _pidForPbFilter, 'order': i},
            );
      }
    } catch (e, st) {
      DatabaseService._log('PLAN_ORDER_SYNC_PB: $e');
      DatabaseService._log(st.toString());
      try {
        final msg = t(currentLocale.value, 'plan_save_failed');
        if (!_notify.isClosed) _notify.add(msg);
      } catch (_) {}
      return;
    }
    DatabaseService._log(
      'PLAN_ORDER_SYNC: PocketBase PATCH ok (${ordered.length} task(s) checked)',
    );
    _planReorderBaselineByPlanId = null;
  }

  /// After navigation away or app pause: persist pending plan order immediately (no debounce).
  Future<void> flushPlanningOrderSyncNow() async {
    _cancelPlanOrderDebounceTimer();
    final pending = _pendingPlanOrderSyncList;
    _pendingPlanOrderSyncList = null;
    DatabaseService._log(
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
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;

    var n = 0;
    try {
      await ensurePocketBaseReady();
      for (final r in ordered) {
        if (r.id == -1) continue;
        final pbId = _categoryBackendRowIdStrict(r);
        if (pbId == null) continue;
        final biz = _categoryStringPkForApi(r);
        final body = _nocoFieldsForPatch(
          _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
            'user_id': _pidForPbFilter,
            if (biz != null && biz.isNotEmpty) 'category_id': biz,
            'order': r.order,
          }),
        );
        await _pb.collection(PbCollections.categories).update(pbId, body: body);
        n++;
      }
    } catch (e, st) {
      DatabaseService._log('$contextLabel: PB order sync exception $e');
      DatabaseService._log(st.toString());
    }
    DatabaseService._log('$contextLabel: PocketBase order ok ($n row(s))');
  }

  Future<void> _persistCategoryOrdersBulkNow(List<CategoryRule> ordered) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;

    var n = 0;
    try {
      await ensurePocketBaseReady();
      for (var i = 0; i < ordered.length; i++) {
        final r = ordered[i];
        if (r.id == -1) continue;
        final pbId = _categoryBackendRowIdStrict(r);
        if (pbId == null) continue;
        final base = _categoryReorderBaselineByLocalId?[r.id];
        if (base != null && base == i) continue;

        final biz = _categoryStringPkForApi(r);
        final body = _nocoFieldsForPatch(
          _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
            'user_id': _pidForPbFilter,
            if (biz != null && biz.isNotEmpty) 'category_id': biz,
            'order': i,
          }),
        );
        await _pb.collection(PbCollections.categories).update(pbId, body: body);
        n++;
      }
    } catch (e, st) {
      DatabaseService._log('CATEGORY_ORDER_SYNC: chunk exception $e');
      DatabaseService._log(st.toString());
      try {
        final msg = t(currentLocale.value, 'sync_failed');
        if (!_notify.isClosed) _notify.add(msg);
      } catch (_) {}
      return;
    }

    if (n == 0) {
      DatabaseService._log(
        'CATEGORY_ORDER_SYNC: skip — every index matches baseline (${ordered.length} row(s))',
      );
    } else {
      DatabaseService._log('CATEGORY_ORDER_SYNC: PocketBase ok ($n row(s))');
    }
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
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (parentId != null && getCategoryRuleById(parentId) == null) {
      return;
    }
    if (baselineBeforeReorder != null) {
      _ensureCategoryOrderBaseline(baselineBeforeReorder);
    }
    _pendingCategoryOrderSyncList = List<CategoryRule>.from(ordered);
    _cancelCategoryOrderDebounceTimer();
    DatabaseService._log(
      'CATEGORY_ORDER_SYNC: debounce arm ${ordered.length} row(s) parent=$parentId — fire in ${DatabaseService._categoryOrderDebounce.inSeconds}s',
    );
    _categoryOrderDebounceTimer = Timer(
      DatabaseService._categoryOrderDebounce,
      () {
        _categoryOrderDebounceTimer = null;
        final pending = _pendingCategoryOrderSyncList;
        _pendingCategoryOrderSyncList = null;
        if (pending == null || pending.isEmpty) return;
        DatabaseService._log(
          'CATEGORY_ORDER_SYNC: debounce elapsed — syncing ${pending.length} row(s)',
        );
        unawaited(_persistCategoryOrdersBulkNow(pending));
      },
    );
  }

  Future<void> flushCategoryOrderSyncNow() async {
    _cancelCategoryOrderDebounceTimer();
    final pending = _pendingCategoryOrderSyncList;
    _pendingCategoryOrderSyncList = null;
    DatabaseService._log(
      'CATEGORY_ORDER_SYNC: immediate flush (${pending?.length ?? 0} pending row(s))',
    );
    if (pending == null || pending.isEmpty) return;
    await _persistCategoryOrdersBulkNow(pending);
  }

  /// Flat `plans` scalar PATCH map (no `user_id` key). Shared by [updatePlanningTask] and [bulkUpdatePlans].
  Map<String, dynamic> _scalarPatchBodyForPlanningRow({
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
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,
  }) {
    final fields = <String, dynamic>{'user_id': _pidForPbFilter};
    if (title != null) fields['title'] = title;
    if (categoryId != null) {
      final cs = _categoryRelationIdForPlanPatch(categoryId);
      if (cs != null && cs.isNotEmpty) {
        fields['category_id'] = cs;
      }
    }
    if (isDone != null) fields['is_done'] = isDone;
    if (notesPlain != null) {
      final nt = notesPlain.trim();
      fields['notes_plain'] = nt.isEmpty ? null : nt;
    }
    if (notesDeltaJson != null) {
      final nd = notesDeltaJson.trim();
      if (nd.isEmpty) {
        fields['notes_delta'] = null;
      } else {
        try {
          fields['notes_delta'] = jsonDecode(nd);
        } catch (_) {
          fields['notes_delta'] = null;
        }
      }
    }
    if (checklist != null) fields['checklist'] = checklist;
    if (parentPlanId != null) {
      fields['parent_plan_id'] = parentPlanId.toString();
    }
    if (order != null) fields['order'] = order;
    if (startTimeDisplay != null) {
      fields['start_time'] = _profileUtcFromWall(
        startTimeDisplay,
      ).toIso8601String();
    } else if (startTime != null) {
      fields['start_time'] = startTime.toUtc().toIso8601String();
    }
    if (clearEnd) {
      fields['end_time'] = null;
    } else if (endDateTimeDisplay != null) {
      fields['end_time'] = _profileUtcFromWall(
        endDateTimeDisplay,
      ).toIso8601String();
    } else if (endDateTime != null) {
      fields['end_time'] = endDateTime.toUtc().toIso8601String();
    }
    final bizPid = planBusinessId?.trim() ?? '';
    if (bizPid.isNotEmpty && !bizPid.startsWith('optimistic-')) {
      fields['plan_id'] = bizPid;
    }
    final initK = planInitialDateKey?.trim() ?? '';
    if (initK.length >= 10) {
      fields['initial_date_key'] = initK.substring(0, 10);
    }
    if (planIsPostponed != null) {
      fields['is_postponed'] = planIsPostponed;
    }
    if (patchPlanAlarmRecurrence) {
      final rt = (planRrule ?? '').trim();
      if (rt.isNotEmpty) {
        fields['rrule'] = rt;
        fields['exception_dates'] = List<String>.from(
          planExceptionDates ?? const <String>[],
        );
      } else {
        fields['rrule'] = null;
        fields['exception_dates'] = const <String>[];
      }
      fields['reminder_offset'] = planReminderOffset;
    }
    final patchBody = <String, dynamic>{};
    for (final e in fields.entries) {
      if (e.key == 'user_id') continue;
      patchBody[e.key] = e.value;
    }
    return patchBody;
  }

  /// JIT expanded row id: `virt-<parentPocketId>-YYYY-MM-DD`. Never pass [virt-] IDs to PocketBase REST.
  static ({String parentPocketId, String instanceDateKey})?
  _parseVirtualPlanRowId(String raw) {
    final s = raw.trim();
    final m = RegExp(r'^virt-(.+)-(\d{4}-\d{2}-\d{2})$').firstMatch(s);
    if (m == null) return null;
    final pid = m.group(1)!.trim();
    final dk = m.group(2)!.trim();
    if (!DatabaseService._isLikelyPocketBaseRowId(pid)) return null;
    final y = int.tryParse(dk.substring(0, 4));
    final mo = int.tryParse(dk.substring(5, 7));
    final d = int.tryParse(dk.substring(8, 10));
    if (y == null || mo == null || d == null) return null;
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return (parentPocketId: pid, instanceDateKey: dk);
  }

  /// Skip or restore one recurring instance by mutating the template’s [exception_dates] only.
  Future<bool> _patchRecurringTemplateExceptionDates({
    required String parentPlanPocketId,
    required String instanceDateKey,
    required bool addException,
    bool suppressAppSnack = false,
    bool deferPlanningNotify = false,
  }) async {
    final pid = parentPlanPocketId.trim();
    if (pid.isEmpty || !DatabaseService._isLikelyPocketBaseRowId(pid)) {
      return false;
    }
    var day = instanceDateKey.trim();
    if (day.length < 10) return false;
    day = day.substring(0, 10);

    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final rec = await _pb
          .collection(PbCollections.plans)
          .getOne(pid, expand: kPbPlanTagsExpand);
      final parent = _planningTaskFromPocketRecord(
        rec,
        pocketTagCatalog: tagCatalog,
      );
      final rrule = parent.rrule?.trim() ?? '';
      if (rrule.isEmpty) {
        DatabaseService._log('VIRT_PLAN_PATCH: parent $pid has no rrule');
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      final next = <String>{
        for (final e in parent.exceptionDates)
          if (e.trim().length >= 10) e.trim().substring(0, 10),
      };
      if (addException) {
        next.add(day);
      } else {
        next.remove(day);
      }

      final restId = await _resolvePlanRestId(
        pid,
        planBusinessId: parent.planRowId,
      );
      final patchBody = _scalarPatchBodyForPlanningRow(
        planBusinessId: parent.planRowId,
        patchPlanAlarmRecurrence: true,
        planRrule: parent.rrule,
        planReminderOffset: parent.reminderOffset,
        planExceptionDates: next.toList()..sort(),
      );
      if (patchBody.isEmpty) return false;
      await _pb.collection(PbCollections.plans).update(restId, body: patchBody);
      clearOptimisticPlanningForPlanRow(pid);
      clearOptimisticPlanningForPlanRow(restId);
      if (!deferPlanningNotify) {
        notifyPlanningRefresh();
        _notifyTimelineAfterRecordCacheMutation();
      }
      return true;
    } catch (e, st) {
      DatabaseService._log('VIRT_PLAN_PATCH: $e');
      DatabaseService._log(st.toString());
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
  }

  /// Wall times for [day] using parent template’s clock (same as JIT [expandRecurringPlans] instance shape).
  (DateTime?, DateTime?) _materializedWallStartEndForDay(
    PlanningTask parent,
    DateTime wallDay,
  ) {
    final pst = parent.startTime;
    if (pst == null) {
      return (null, null);
    }
    final start = DateTime(
      wallDay.year,
      wallDay.month,
      wallDay.day,
      pst.hour,
      pst.minute,
      pst.second,
      pst.millisecond,
      pst.microsecond,
    );
    final pend = parent.endDateTime;
    if (pend == null) {
      return (start, null);
    }
    final dur = pend.difference(pst);
    final end = dur.isNegative ? start : start.add(dur);
    return (start, end);
  }

  List<Map<String, dynamic>> _copyChecklistForMaterialize(
    List<Map<String, dynamic>> src,
  ) {
    return [for (final m in src) Map<String, dynamic>.from(m)];
  }

  /// POST a new real plan row; returns **false** on any failure (no outbox “success”).
  Future<bool> _createPlanningTaskPocketStrict(PlanningTask task) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      return false;
    }
    try {
      final catRule = getCategoryRuleById(task.categoryId);
      if (catRule == null) {
        DatabaseService._log(
          'MATERIALIZE_PLAN: unknown category ${task.categoryId}',
        );
        return false;
      }
      final Object categoryFieldForPlan;
      final catNocoSys = _categoryBackendRowIdStrict(catRule);
      if (catNocoSys != null) {
        categoryFieldForPlan = catNocoSys;
      } else {
        final catStr = _categoryStringPkForApi(catRule);
        if (catStr != null && catStr.isNotEmpty) {
          categoryFieldForPlan = catStr;
        } else {
          categoryFieldForPlan = _recordCategoryBusinessPkForApi(
            task.categoryId,
          );
        }
      }
      final titleTrimmed = task.title.trim();
      if (titleTrimmed.isEmpty) {
        DatabaseService._log('MATERIALIZE_PLAN: empty title');
        return false;
      }
      final clientPlanId = DatabaseService._newClientRecordUuid();
      final body = await _buildPocketPlanCreateBody(
        task,
        titleTrimmed: titleTrimmed,
        clientPlanId: clientPlanId,
        categoryFieldForPlan: categoryFieldForPlan,
      );
      final record = await _pb
          .collection(PbCollections.plans)
          .create(body: body);
      if (task.tags.isNotEmpty) {
        await _syncPlanTagsPocket(record.id, task.tags);
      }
      return true;
    } catch (e, st) {
      DatabaseService._log('MATERIALIZE_PLAN_PB: $e');
      DatabaseService._log(st.toString());
      return false;
    }
  }

  /// Complete a recurring **virtual** row: PATCH parent [exception_dates] + POST one-off done plan on that wall day.
  Future<bool> _completeVirtualRecurringInstance({
    required String parentPlanPocketId,
    required String instanceDateKey,
    bool suppressAppSnack = false,
    bool deferPlanningNotify = false,
  }) async {
    final pid = parentPlanPocketId.trim();
    if (pid.isEmpty || !DatabaseService._isLikelyPocketBaseRowId(pid)) {
      return false;
    }
    var day = instanceDateKey.trim();
    if (day.length < 10) return false;
    day = day.substring(0, 10);

    final y = int.tryParse(day.substring(0, 4));
    final mo = int.tryParse(day.substring(5, 7));
    final d = int.tryParse(day.substring(8, 10));
    if (y == null || mo == null || d == null) return false;
    final wallDay = DateTime(y, mo, d);
    if (wallDay.year != y || wallDay.month != mo || wallDay.day != d) {
      return false;
    }

    final patched = await _patchRecurringTemplateExceptionDates(
      parentPlanPocketId: pid,
      instanceDateKey: day,
      addException: true,
      suppressAppSnack: suppressAppSnack,
      deferPlanningNotify: true,
    );
    if (!patched) return false;

    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final rec = await _pb
          .collection(PbCollections.plans)
          .getOne(pid, expand: kPbPlanTagsExpand);
      final parent = _planningTaskFromPocketRecord(
        rec,
        pocketTagCatalog: tagCatalog,
      );
      if (parent.rrule?.trim().isEmpty ?? true) {
        await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: pid,
          instanceDateKey: day,
          addException: false,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      final wallTimes = _materializedWallStartEndForDay(parent, wallDay);
      final ord = await nextPlanningOrderForDate(wallDay);

      final material = PlanningTask(
        id: 0,
        title: parent.title,
        categoryId: parent.categoryId,
        isDone: true,
        dateKey: day,
        order: ord,
        startTime: wallTimes.$1,
        endDateTime: wallTimes.$2,
        checklist: _copyChecklistForMaterialize(parent.checklist),
        notesPlain: parent.notesPlain,
        notesDeltaJson: parent.notesDeltaJson,
        tags: List<Tag>.from(parent.tags),
        initialDateKey: day,
        isPostponed: false,
      );

      final created = await _createPlanningTaskPocketStrict(material);
      if (!created) {
        await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: pid,
          instanceDateKey: day,
          addException: false,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      if (!deferPlanningNotify) {
        notifyPlanningRefresh();
        _notifyTimelineAfterRecordCacheMutation();
      }
      return true;
    } catch (e, st) {
      DatabaseService._log('VIRT_MATERIALIZE: $e');
      DatabaseService._log(st.toString());
      await _patchRecurringTemplateExceptionDates(
        parentPlanPocketId: pid,
        instanceDateKey: day,
        addException: false,
        suppressAppSnack: true,
        deferPlanningNotify: true,
      );
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
  }

  Future<bool> updatePlanningTask(
    String planRowId, {

    /// @DATA_MAP `plan_id` (UUID) — send inside `fields` only; outer bulk `id` must be Integer Id.
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

    /// When true, `AppSnack` success/failure toasts are omitted (caller handles UX).
    bool suppressAppSnack = false,

    /// When non-null, replaces **tags_link** on PocketBase after successful scalar PATCH.
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,

    /// When [planRowId] is `virt-…`, prefer this wall `YYYY-MM-DD` over the id suffix (Phase 1 JIT rows).
    String? recurrenceInstanceDateKey,
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked updatePlanningTask because plans table id equals records table id.',
      );
      return false;
    }
    final rid = planRowId.trim();
    if (rid.isEmpty) return false;

    final virt = _parseVirtualPlanRowId(rid);
    if (virt != null) {
      final hint = recurrenceInstanceDateKey?.trim() ?? '';
      final effectiveDay = hint.length >= 10
          ? hint.substring(0, 10)
          : virt.instanceDateKey;

      final disallowedExtras =
          title != null ||
          categoryId != null ||
          notesPlain != null ||
          notesDeltaJson != null ||
          checklist != null ||
          parentPlanId != null ||
          order != null ||
          startTime != null ||
          startTimeDisplay != null ||
          endDateTime != null ||
          endDateTimeDisplay != null ||
          clearEnd ||
          planInitialDateKey != null ||
          planIsPostponed != null ||
          patchPlanAlarmRecurrence ||
          tags != null ||
          planRrule != null ||
          planReminderOffset != null ||
          planExceptionDates != null;

      if (isDone == null || disallowedExtras) {
        DatabaseService._log(
          'VIRT_PLAN_UPDATE: blocked — virtual clone supports only is_done toggle '
          '(complete materializes a real row; uncomplete uses exception_dates only).',
        );
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      if (isDone) {
        return _completeVirtualRecurringInstance(
          parentPlanPocketId: virt.parentPocketId,
          instanceDateKey: effectiveDay,
          suppressAppSnack: suppressAppSnack,
        );
      }
      return _patchRecurringTemplateExceptionDates(
        parentPlanPocketId: virt.parentPocketId,
        instanceDateKey: effectiveDay,
        addException: false,
        suppressAppSnack: suppressAppSnack,
      );
    }

    final businessId = _outboxBusinessPlanId(
      rid,
      planBusinessId: planBusinessId,
    );
    final existingTask = _findCachedPlanningTaskForEdit(
      rid,
      planBusinessId: planBusinessId,
    );
    final oldCategoryId = existingTask?.categoryId;
    final autoCategoryId = _resolveCategoryIdForEditedTitle(
      newTitle: title,
      oldTitle: existingTask?.title,
      currentCategoryId: oldCategoryId,
      manualCategoryChanged: categoryId != null,
    );
    final effectiveCategoryId = categoryId ?? autoCategoryId;
    final patchBody = _scalarPatchBodyForPlanningRow(
      planBusinessId: planBusinessId,
      title: title,
      categoryId: effectiveCategoryId,
      isDone: isDone,
      notesPlain: notesPlain,
      notesDeltaJson: notesDeltaJson,
      checklist: checklist,
      parentPlanId: parentPlanId,
      order: order,
      startTime: startTime,
      startTimeDisplay: startTimeDisplay,
      endDateTime: endDateTime,
      endDateTimeDisplay: endDateTimeDisplay,
      clearEnd: clearEnd,
      planInitialDateKey: planInitialDateKey,
      planIsPostponed: planIsPostponed,
      patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
      planRrule: planRrule,
      planReminderOffset: planReminderOffset,
      planExceptionDates: planExceptionDates,
    );
    if (patchBody.isEmpty && tags == null) return false;

    _applyOptimisticPlanningTaskPatch(
      planRowId: rid,
      planBusinessId: planBusinessId,
      title: title,
      categoryId: effectiveCategoryId,
      isDone: isDone,
      notesPlain: notesPlain,
      notesDeltaJson: notesDeltaJson,
      checklist: checklist,
      parentPlanId: parentPlanId,
      order: order,
      startTime: startTime,
      startTimeDisplay: startTimeDisplay,
      endDateTime: endDateTime,
      endDateTimeDisplay: endDateTimeDisplay,
      clearEnd: clearEnd,
      tags: tags,
      planInitialDateKey: planInitialDateKey,
      planIsPostponed: planIsPostponed,
      patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
      planRrule: planRrule,
      planReminderOffset: planReminderOffset,
      planExceptionDates: planExceptionDates,
    );

    final shadowPb = _tryResolvePlanPbIdFromCacheOnly(
      rid,
      planBusinessId: planBusinessId,
    );
    if (autoCategoryId != null &&
        oldCategoryId != null &&
        oldCategoryId != autoCategoryId &&
        shadowPb != null) {
      _propagatePlanAutoCategoryToLoadedLinkedRecords(
        planPocketId: shadowPb,
        oldCategoryId: oldCategoryId,
        newCategoryId: autoCategoryId,
      );
    }
    if (shadowPb != null &&
        DatabaseService._isLikelyPocketBaseRowId(shadowPb)) {
      unawaited(
        _patchPlanUpdateNetworkPhase(
          originalInput: rid,
          resolvedPbId: shadowPb,
          businessId: businessId,
          patchBody: patchBody,
          tags: tags,
          suppressAppSnack: suppressAppSnack,
        ),
      );
      return true;
    }

    unawaited(() async {
      try {
        final restId = await _resolvePlanRestId(
          rid,
          planBusinessId: planBusinessId,
        );
        if (!DatabaseService._isLikelyPocketBaseRowId(restId)) {
          List<String>? tagIds;
          if (tags != null) {
            tagIds = await _pbTagRecordIdsFromTags(tags);
          }
          final scalarOnly = Map<String, dynamic>.from(patchBody);
          scalarOnly.remove('user_id');
          await _enqueuePlanUpdateMutation(
            originalInput: rid,
            businessId: businessId,
            patchFields: scalarOnly,
            tagsLinkPbIds: tagIds,
            error: 'unresolved_pb_id',
          );
          offlineSync.setConnectivityOffline(true);
          return;
        }
        await _patchPlanUpdateNetworkPhase(
          originalInput: rid,
          resolvedPbId: restId,
          businessId: businessId,
          patchBody: patchBody,
          tags: tags,
          suppressAppSnack: suppressAppSnack,
        );
      } catch (e, st) {
        DatabaseService._log('UPDATE_PLANNING_TASK_PB async: $e');
        DatabaseService._log(st.toString());
        if (_planMutationRetriableHttpCode(0)) {
          final scalarOnly = Map<String, dynamic>.from(patchBody);
          scalarOnly.remove('user_id');
          await _enqueuePlanUpdateMutation(
            originalInput: rid,
            businessId: businessId,
            patchFields: scalarOnly,
            error: e,
          );
          offlineSync.setConnectivityOffline(true);
        } else if (!suppressAppSnack) {
          AppSnack.failed();
        }
      }
    }());
    return true;
  }

  /// Multiple scalar `plans` PATCH calls; clears optimistic overlays per row; **one** [notifyPlanningRefresh] at end.
  ///
  /// Each [PlanningBulkPatch] carries the **final** wall times to persist. Callers may combine a calendar
  /// move and a time delta in one batch by precomputing `start_time` / `end_time` on the destination day.
  /// No per-row tag sync — use [updatePlanningTask] when tags change.
  Future<bool> bulkUpdatePlans(
    List<PlanningBulkPatch> patches, {
    bool suppressAppSnack = false,
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      DatabaseService._log('TABLE_GUARD: blocked bulkUpdatePlans.');
      return false;
    }
    if (patches.isEmpty) return false;
    var allOk = true;
    try {
      for (final p in patches) {
        final rid = p.planRowId.trim();
        if (rid.isEmpty || rid.startsWith('optimistic-')) continue;
        if (rid.startsWith('virt-')) {
          allOk = false;
          DatabaseService._log(
            'BULK_UPDATE_PLANS: skipped virtual clone $rid — use single-row update or exception_dates flow.',
          );
          continue;
        }
        final patchBody = _scalarPatchBodyForPlanningRow(
          planBusinessId: p.planBusinessId,
          startTimeDisplay: p.startTimeDisplay,
          endDateTimeDisplay: p.endDateTimeDisplay,
          clearEnd: p.clearEnd,
          planInitialDateKey: p.initialDateKey,
          planIsPostponed: p.isPostponed,
        );
        if (patchBody.isEmpty) continue;
        try {
          final restId = await _resolvePlanRestId(
            rid,
            planBusinessId: p.planBusinessId,
          );
          await _pb
              .collection(PbCollections.plans)
              .update(restId, body: patchBody);
          clearOptimisticPlanningForPlanRow(rid);
          clearOptimisticPlanningForPlanRow(restId);
        } catch (e, st) {
          allOk = false;
          DatabaseService._log('BULK_UPDATE_PLAN_PB: $e');
          DatabaseService._log(st.toString());
        }
      }
    } finally {
      notifyPlanningRefresh();
    }
    if (!suppressAppSnack) {
      if (allOk) {
        AppSnack.updated();
      } else {
        AppSnack.failed();
      }
    }
    return allOk;
  }

  /// PocketBase [plans] rows: each id is a **record id** string.
  Future<bool> deletePlanningTasksBulk(Iterable<String> planBackendIds) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) {
      DatabaseService._log('TABLE_GUARD: blocked deletePlanningTasksBulk.');
      return false;
    }
    final raw = planBackendIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (raw.isEmpty) return false;

    var deferredNotify = false;
    var skipDeletedSnack = false;
    for (final id in raw) {
      final trimmed = id.trim();
      if (trimmed.startsWith('optimistic-')) {
        clearOptimisticPlanningForPlanRow(trimmed);
        deferredNotify = true;
        continue;
      }
      final virt = _parseVirtualPlanRowId(trimmed);
      if (virt != null) {
        final ok = await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: virt.parentPocketId,
          instanceDateKey: virt.instanceDateKey,
          addException: true,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!ok) {
          AppSnack.failed();
          return false;
        }
        deferredNotify = true;
        continue;
      }
      final businessId = _outboxBusinessPlanId(trimmed);
      final shadowPb = _tryResolvePlanPbIdFromCacheOnly(trimmed);
      if (shadowPb != null &&
          DatabaseService._isLikelyPocketBaseRowId(shadowPb)) {
        final del = await _deletePlanNetworkPhase(
          originalInput: trimmed,
          resolvedPbId: shadowPb,
          businessId: businessId,
        );
        if (!del.ok) {
          AppSnack.failed();
          return false;
        }
        if (del.queued) skipDeletedSnack = true;
        deferredNotify = true;
        continue;
      }
      try {
        final restId = await _resolvePlanRestId(trimmed);
        if (!DatabaseService._isLikelyPocketBaseRowId(restId)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: 'unresolved_pb_id',
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        final del = await _deletePlanNetworkPhase(
          originalInput: trimmed,
          resolvedPbId: restId,
          businessId: businessId,
        );
        if (!del.ok) {
          AppSnack.failed();
          return false;
        }
        if (del.queued) skipDeletedSnack = true;
        deferredNotify = true;
      } on ClientException catch (e, st) {
        DatabaseService._log('DELETE_PLAN_PB_BULK: $e');
        DatabaseService._log(st.toString());
        final code = e.statusCode;
        if (code == 401 || code == 403) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: code,
            syncStatus: PlanMutationOutbox.syncStatusPausedAuth,
          );
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        if (_planMutationRetriableHttpCode(code)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: code,
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        AppSnack.failed();
        return false;
      } catch (e, st) {
        DatabaseService._log('DELETE_PLAN_PB_BULK: $e');
        DatabaseService._log(st.toString());
        if (_planMutationRetriableHttpCode(0)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: e,
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        AppSnack.failed();
        return false;
      }
    }
    if (deferredNotify) {
      notifyPlanningRefresh();
      _notifyTimelineAfterRecordCacheMutation();
    }
    if (!skipDeletedSnack) {
      AppSnack.deleted();
    }
    return true;
  }

  /// Bulk `is_done` — Noco: integer wrapper PK string; PocketBase: record id string.
  Future<bool> markPlanningTasksCompletedBulk(
    Iterable<String> planBackendIds, {
    required bool completed,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) return false;
    final raw = planBackendIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (raw.isEmpty) return false;

    const chunkSize = 10;
    var allOk = true;
    var needsNotify = false;
    for (var i = 0; i < raw.length; i += chunkSize) {
      final end = min(i + chunkSize, raw.length);
      final chunk = raw.sublist(i, end);
      for (final id in chunk) {
        try {
          final trimmed = id.trim();
          final virt = _parseVirtualPlanRowId(trimmed);
          if (virt != null) {
            final bool ok;
            if (completed) {
              ok = await _completeVirtualRecurringInstance(
                parentPlanPocketId: virt.parentPocketId,
                instanceDateKey: virt.instanceDateKey,
                suppressAppSnack: true,
                deferPlanningNotify: true,
              );
            } else {
              ok = await _patchRecurringTemplateExceptionDates(
                parentPlanPocketId: virt.parentPocketId,
                instanceDateKey: virt.instanceDateKey,
                addException: false,
                suppressAppSnack: true,
                deferPlanningNotify: true,
              );
            }
            if (!ok) {
              allOk = false;
            } else {
              needsNotify = true;
            }
            continue;
          }
          final restId = await _resolvePlanRestId(id);
          await _pb
              .collection(PbCollections.plans)
              .update(restId, body: <String, dynamic>{'is_done': completed});
          needsNotify = true;
        } catch (e, st) {
          allOk = false;
          DatabaseService._log('MARK_PLANS_DONE_PB: $e');
          DatabaseService._log(st.toString());
        }
      }
    }
    if (needsNotify) {
      notifyPlanningRefresh();
      _notifyTimelineAfterRecordCacheMutation();
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
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) return;
    if (baselineBeforeReorder != null) {
      _ensurePlanningOrderBaseline(baselineBeforeReorder);
    }
    _pendingPlanOrderSyncList = List<PlanningTask>.from(ordered);
    _cancelPlanOrderDebounceTimer();
    DatabaseService._log(
      'PLAN_ORDER_SYNC: debounce arm ${ordered.length} task(s) — fire in ${_planOrderDebounce.inSeconds}s',
    );
    _planOrderDebounceTimer = Timer(_planOrderDebounce, () {
      _planOrderDebounceTimer = null;
      final pending = _pendingPlanOrderSyncList;
      if (pending == null || pending.isEmpty) return;
      _pendingPlanOrderSyncList = null;
      DatabaseService._log(
        'PLAN_ORDER_SYNC: debounce elapsed — syncing ${pending.length} task(s)',
      );
      unawaited(_persistPlanningTaskOrdersBulkNow(pending));
    });
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

  /// Undated child rows for a backlog parent ([PlanningTask.parentPlanPocketId]).
  List<PlanningTask> backlogChildPlansForParent(String parentPocketPlanId) {
    final want = parentPocketPlanId.trim();
    if (want.isEmpty) return const [];
    final out = <PlanningTask>[];
    for (final t in _allPlansUserCache) {
      if (t.startTime != null) continue;
      if ((t.parentPlanPocketId ?? '').trim() != want) continue;
      out.add(t);
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final t in m.values) {
        if (t.startTime != null) continue;
        if ((t.parentPlanPocketId ?? '').trim() != want) continue;
        if (!out.any((x) => x.planRowIdForBackend == t.planRowIdForBackend)) {
          out.add(t);
        }
      }
    }
    out.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return out;
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

  // ---------------------------------------------------------------------------
  // Plans realtime (web + mobile multi-device sync)
  // ---------------------------------------------------------------------------

  String? _pocketBaseOwnerFilterClauseForPlans() {
    final uid = _userIdForWhere?.trim() ?? '';
    if (uid.isEmpty) return null;
    return 'user_id = "${_escapeForPbFilter(uid)}"';
  }

  void _onPbPlansSubscriptionEvent(RecordSubscriptionEvent e) {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    final action = e.action.toLowerCase().trim();
    if (action == 'delete') {
      final id = e.record?.id.trim() ?? '';
      if (id.isNotEmpty) {
        _removePlanFromUserCache(id);
        clearOptimisticPlanningForPlanRow(id);
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
      }
      return;
    }
    final rec = e.record;
    if (rec == null) return;
    unawaited(() async {
      try {
        final tagCatalog = await _fetchPlanAndListTagCatalog();
        final task = _planningTaskFromPocketRecord(
          rec,
          pocketTagCatalog: tagCatalog,
        );
        _upsertPlanInUserCache(task);
        _allPlansUserCacheFetchedAt = DateTime.now();
        final biz = _planBusinessUuidFromTask(task);
        if (biz != null && biz.isNotEmpty) {
          clearOptimisticPlanningForPlanRow('optimistic-$biz');
        }
        clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
      } catch (_) {}
    }());
  }

  Future<void> _cancelPlansRealtimeSubscription() async {
    final unsub = _plansRealtimeUnsubscribe;
    _plansRealtimeUnsubscribe = null;
    if (unsub != null) {
      try {
        await unsub();
      } catch (_) {}
    }
    try {
      await _pb.collection(PbCollections.plans).unsubscribe();
    } catch (_) {}
  }

  Future<void> _startPlansRealtimeSubscriptionBody() async {
    await _cancelPlansRealtimeSubscription();
    if (!_hasAuthenticatedUserId) return;
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final filter = _pocketBaseOwnerFilterClauseForPlans();
      if (filter == null || filter.isEmpty) return;
      Future<void> Function()? unsub;
      try {
        unsub = await _pb
            .collection(PbCollections.plans)
            .subscribe(
              '*',
              _onPbPlansSubscriptionEvent,
              filter: filter,
              expand: kPbPlanTagsExpand,
            );
      } catch (_) {
        unsub = await _pb
            .collection(PbCollections.plans)
            .subscribe('*', _onPbPlansSubscriptionEvent, filter: filter);
      }
      _plansRealtimeUnsubscribe = unsub;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('plans realtime subscribe failed: $e');
      }
    }
  }

  Future<void> _startPlansRealtimeSubscription() async {
    final existing = _plansRealtimeSubscribeFuture;
    if (existing != null) return existing;
    final f = _startPlansRealtimeSubscriptionBody();
    _plansRealtimeSubscribeFuture = f;
    try {
      await f;
    } finally {
      _plansRealtimeSubscribeFuture = null;
    }
  }

  /// Re-subscribe to `plans` realtime after auth when init ran without a session.
  Future<void> ensurePlansRealtimeBridge() async {
    unawaited(_startPlansRealtimeSubscription());
  }
}
