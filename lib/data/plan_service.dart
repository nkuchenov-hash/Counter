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
int _profileTimezoneProjectionRevision = 0;
Timer? _planningNotifyNetworkDebounceTimer;
bool _planningRefreshWantsNetworkPump = false;
Future<void>? _plansRealtimeSubscribeFuture;
Future<void> Function()? _plansRealtimeUnsubscribe;

int _planningStreamIdSeq = 0;
final Map<String, _PlanningDayStreamHub> _planningStreamHubs = {};

/// Shared planning day stream — one hub per (day, global-listen) key; ref-counted listeners.
final class _PlanningDayStreamHub {
  _PlanningDayStreamHub({
    required this.streamId,
    required this.dayKey,
    required this.wallDay,
    required this.listenGlobal,
  });

  final String streamId;
  final String dayKey;
  final DateTime wallDay;
  final bool listenGlobal;
  int refCount = 0;
  final StreamController<List<PlanningTask>> controller =
      StreamController<List<PlanningTask>>.broadcast();
  StreamSubscription<void>? _pokeSub;
  bool _pumpBusy = false;
  bool _disposed = false;

  void acquire(DatabaseService db) {
    refCount++;
    planStreamLifecycleLog(
      'create streamId=$streamId user=${db.currentProfileId ?? '-'} '
      'date=$dayKey mode=listenGlobal=$listenGlobal '
      'activeForDay=${_planningStreamHubs.length}',
    );
    if (refCount == 1) {
      _bind(db);
    }
  }

  void release() {
    refCount--;
    if (refCount <= 0) {
      planStreamLifecycleLog('dispose streamId=$streamId');
      _disposeHub();
    }
  }

  void _bind(DatabaseService db) {
    _emitFromCache(db);
    unawaited(_pump(db, network: true));
    if (!listenGlobal) return;
    _pokeSub = _planningRefreshController.stream.listen((_) {
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
      unawaited(_pump(db, network: stale));
    });
  }

  void _emitFromCache(DatabaseService db) {
    if (_disposed || controller.isClosed) return;
    List<PlanningTask> base = [];
    if (_allPlansUserCache.isNotEmpty) {
      base = db._filterPlansForWallDay(_allPlansUserCache, wallDay);
    }
    final merged = db._mergePlanningOptimistic(dayKey, base);
    db._logPlanDupTraceLayer(source: 'stream', tasks: merged, dayKey: dayKey);
    _logPlanningStreamEmit(merged);
    controller.add(merged);
  }

  Future<void> _pump(DatabaseService db, {required bool network}) async {
    _emitFromCache(db);
    if (!network || _pumpBusy || _disposed || controller.isClosed) return;
    _pumpBusy = true;
    try {
      List<PlanningTask> tasks;
      try {
        tasks = await db._fetchPlanningTasksForDate(wallDay);
      } catch (_) {
        tasks = <PlanningTask>[];
      }
      if (!_disposed && !controller.isClosed) {
        final merged = db._mergePlanningOptimistic(dayKey, tasks);
        db._logPlanDupTraceLayer(
          source: 'stream',
          tasks: merged,
          dayKey: dayKey,
        );
        _logPlanningStreamEmit(merged);
        controller.add(merged);
      }
    } finally {
      _pumpBusy = false;
    }
  }

  void _logPlanningStreamEmit(List<PlanningTask> merged) {
    final ids = merged.map((t) => t.planRowIdForBackend).toList();
    final unique = ids.toSet().length;
    planStreamLifecycleLog(
      'emit streamId=$streamId total=${merged.length} uniqueIds=$unique '
      'duplicateIds=${merged.length - unique}',
    );
  }

  void _disposeHub() {
    if (_disposed) return;
    _disposed = true;
    _pokeSub?.cancel();
    _pokeSub = null;
    _planningStreamHubs.remove('$dayKey|$listenGlobal');
    if (!controller.isClosed) {
      unawaited(controller.close());
    }
  }

  void emitCachedPlans(DatabaseService db) => _emitFromCache(db);
}

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
      if (t.startUtcInstant != null) ...<String, dynamic>{
        'start_utc': t.startUtcInstant!.toUtc().toIso8601String(),
        'start_time': t.startUtcInstant!.toUtc().toIso8601String(),
      },
      if (t.endUtcInstant != null)
        'end_utc': t.endUtcInstant!.toUtc().toIso8601String(),
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
    final startUtcRaw = m['start_utc']?.toString();
    final endUtcRaw = m['end_utc']?.toString();
    var startUtc = startUtcRaw != null && startUtcRaw.trim().isNotEmpty
        ? DateTime.tryParse(startUtcRaw.trim())?.toUtc()
        : null;
    if (startUtc == null) {
      final startTimeIso = m['start_time']?.toString().trim();
      if (startTimeIso != null && startTimeIso.isNotEmpty) {
        startUtc = DateTime.tryParse(startTimeIso)?.toUtc();
      }
    }
    final endUtc = endUtcRaw != null && endUtcRaw.trim().isNotEmpty
        ? DateTime.tryParse(endUtcRaw.trim())?.toUtc()
        : null;
    var task = PlanningTask(
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
      startUtcInstant: startUtc,
      endUtcInstant: endUtc,
    );
    if (startUtc != null) {
      task = _reprojectPlanningTaskWallTimes(task);
    }
    return task;
  }


  Future<void> _persistPlanningTasksDayCache(
    String targetDayStr,
    List<PlanningTask> plans,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final scrubbed = scrubPlanningTasksForLocalCache(plans);
      final payload = scrubbed
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
      return scrubPlanningTasksForLocalCache(out);
    } catch (_) {
      return [];
    }
  }

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
    _refreshPlansWarmSnapshotsAfterCacheMutation();
    persistPlansWarmSnapshotsToDisk();
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
    final task = cached ??
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

  static String? _lastPlanTimeTzLogKey;
  static DateTime? _lastPlanTimeTzLogAt;
  static const Duration _planTimeTzLogDebounce = Duration(seconds: 8);

  void _logPlanTimeTzProjection({
    required PlanningTask task,
    required String selectedDay,
    required bool visible,
    DateTime? startUtc,
    DateTime? endUtc,
    DateTime? wallStart,
    DateTime? wallEnd,
  }) {
    final planId = task.planRowIdForBackend.trim();
    final lineKey =
        '$planId|$selectedDay|${task.startUtcInstant?.toIso8601String()}|visible=$visible';
    final now = DateTime.now();
    if (_lastPlanTimeTzLogKey == lineKey &&
        _lastPlanTimeTzLogAt != null &&
        now.difference(_lastPlanTimeTzLogAt!) < _planTimeTzLogDebounce) {
      return;
    }
    _lastPlanTimeTzLogKey = lineKey;
    _lastPlanTimeTzLogAt = now;
    if (!kVerbosePlanTimeTzProjectionLogs || kReleaseMode) return;
    // ignore: avoid_print
    final startMin = wallStart != null
        ? wallStart.hour * 60 + wallStart.minute
        : null;
    final endMin = wallEnd != null ? wallEnd.hour * 60 + wallEnd.minute : null;
    print(
      'TIME_TZ_PROJECT planId=${planId.isEmpty ? '-' : planId} '
      'profileTz=${_settings.preferredTimeZone.trim().isEmpty ? 'offset:${_settings.timezoneOffsetHours}' : _settings.preferredTimeZone.trim()} '
      'startUtc=${startUtc?.toUtc().toIso8601String() ?? '-'} '
      'endUtc=${endUtc?.toUtc().toIso8601String() ?? '-'} '
      'wallStart=${wallStart != null ? _planLogWallIso(wallStart) : '-'} '
      'wallEnd=${wallEnd != null ? _planLogWallIso(wallEnd) : '-'} '
      'startMin=${startMin ?? '-'} endMin=${endMin ?? '-'} '
      'wallDateKey=${wallStart != null ? _dateKeyFromDate(wallStart) : '-'} '
      'selectedDay=$selectedDay visible=$visible',
    );
  }

  ({DateTime startUtc, DateTime? endUtc})? _planUtcInstants(PlanningTask t) {
    if (t.startUtcInstant != null) {
      return (
        startUtc: t.startUtcInstant!.toUtc(),
        endUtc: t.endUtcInstant?.toUtc(),
      );
    }
    final st = t.startTime;
    if (st == null) return null;
    return (
      startUtc: _profileUtcFromWall(st).toUtc(),
      endUtc: t.endDateTime != null
          ? _profileUtcFromWall(t.endDateTime!).toUtc()
          : null,
    );
  }

  String _planLogWallIso(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}T'
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _logPlanTimeCreateWallToUtc({
    required String title,
    required DateTime inputWall,
    required DateTime storedUtc,
    required DateTime projectedWall,
  }) {
    print(
      'PLAN_TIME_CREATE_WALL_TO_UTC title=$title '
      'inputWall=${_planLogWallIso(inputWall)} '
      'profileOffset=${_settings.timezoneOffsetHours} '
      'storedUtc=${storedUtc.toUtc().toIso8601String()} '
      'projectedWall=${_planLogWallIso(projectedWall)}',
    );
  }

  void _logPlanTimeEditWallToUtc({
    required String planId,
    DateTime? oldWall,
    DateTime? newWall,
    required DateTime storedUtc,
    required DateTime projectedWall,
  }) {
    print(
      'PLAN_TIME_EDIT_WALL_TO_UTC planId=$planId '
      'oldWall=${oldWall != null ? _planLogWallIso(oldWall) : '-'} '
      'newWall=${newWall != null ? _planLogWallIso(newWall) : '-'} '
      'storedUtc=${storedUtc.toUtc().toIso8601String()} '
      'projectedWall=${_planLogWallIso(projectedWall)}',
    );
  }

  void _logPlanTimeCacheProjected(PlanningTask task) {
    final instants = _planUtcInstants(task);
    if (instants == null || task.startTime == null) return;
    final planId = (task.planRowId ?? task.pocketRecordId ?? '').trim();
    print(
      'PLAN_TIME_CACHE_PROJECTED planId=${planId.isEmpty ? '-' : planId} '
      'startUtc=${instants.startUtc.toUtc().toIso8601String()} '
      'wallStart=${_planLogWallIso(task.startTime!)} '
      'dateKey=${task.dateKey}',
    );
  }

  /// Ensures [PlanningTask.startTime]/[PlanningTask.endDateTime] are profile wall-clock
  /// and [PlanningTask.startUtcInstant]/[PlanningTask.endUtcInstant] hold UTC source of truth.
  PlanningTask _coalescePlanningTaskWallUtcFields(
    PlanningTask task, {
    bool logCreate = false,
    String? titleForLog,
  }) {
    if (task.startTime == null && task.startUtcInstant == null) return task;
    // UTC instant from PocketBase/cache is source of truth; wall fields are projected.
    if (task.startUtcInstant != null) {
      return _reprojectPlanningTaskWallTimes(task);
    }
    if (task.startTime != null) {
      final inputWall = task.startTime;
      final projected = _reprojectPlanningTaskWallTimesFromWallInput(task);
      if (logCreate && inputWall != null && projected.startTime != null) {
        final instants = _planUtcInstants(projected);
        if (instants != null) {
          _logPlanTimeCreateWallToUtc(
            title: titleForLog ?? task.title,
            inputWall: inputWall,
            storedUtc: instants.startUtc,
            projectedWall: projected.startTime!,
          );
        }
      }
      return projected;
    }
    return task;
  }

  /// Derive UTC instants from profile wall fields only (create/edit path).
  ({DateTime startUtc, DateTime? endUtc})? _planUtcInstantsFromWall(
    PlanningTask t,
  ) {
    final st = t.startTime;
    if (st == null) return null;
    return (
      startUtc: _profileUtcFromWall(st).toUtc(),
      endUtc: t.endDateTime != null
          ? _profileUtcFromWall(t.endDateTime!).toUtc()
          : null,
    );
  }

  PlanningTask _reprojectPlanningTaskWallTimesFromWallInput(PlanningTask t) {
    final instants = _planUtcInstantsFromWall(t);
    if (instants == null) return t;
    final startWall = _profileWallFromUtc(instants.startUtc);
    final endWall = instants.endUtc != null
        ? _profileWallFromUtc(instants.endUtc!)
        : null;
    final dk = _dateKeyFromDate(startWall);
    final edk = endWall != null ? _dateKeyFromDate(endWall) : dk;
    return t.copyWith(
      startUtcInstant: instants.startUtc,
      endUtcInstant: instants.endUtc,
      startTime: startWall,
      endDateTime: endWall,
      dateKey: dk,
      endDateKey: edk,
      date: DateTime.utc(startWall.year, startWall.month, startWall.day),
    );
  }

  PlanningTask _reprojectPlanningTaskWallTimes(PlanningTask t) {
    final instants = _planUtcInstants(t);
    if (instants == null) return t;
    final startWall = _profileWallFromUtc(instants.startUtc);
    final endWall = instants.endUtc != null
        ? _profileWallFromUtc(instants.endUtc!)
        : null;
    final dk = _dateKeyFromDate(startWall);
    final edk = endWall != null ? _dateKeyFromDate(endWall) : dk;
    return t.copyWith(
      startUtcInstant: instants.startUtc,
      endUtcInstant: instants.endUtc,
      startTime: startWall,
      endDateTime: endWall,
      dateKey: dk,
      endDateKey: edk,
      date: DateTime.utc(startWall.year, startWall.month, startWall.day),
    );
  }

  /// Recompute profile wall-clock fields after timezone change (UTC instants unchanged).
  void reprojectAllPlansForProfileTimezone() {
    _allPlansUserCache = [
      for (final t in _allPlansUserCache) _reprojectPlanningTaskWallTimes(t),
    ];
    _rekeyPlanningOptimisticByProfileTimezone();
    _profileTimezoneProjectionRevision++;
    plansDayBodyCache.invalidateAll();
    P0tRenderSnapshotCache.instance.clearPlans();
    _refreshPlansWarmSnapshotsAfterCacheMutation(force: true);
    _pokeAllPlanningStreamHubsFromCache();
  }

  int get profileTimezoneProjectionRevision =>
      _profileTimezoneProjectionRevision;

  int plansProjectionCacheSignature() => Object.hash(
    _allPlansUserCache.length,
    _settings.timezoneOffsetHours,
    _settings.preferredTimeZone.trim(),
    _profileTimezoneProjectionRevision,
  );

  void _rekeyPlanningOptimisticByProfileTimezone() {
    final merged = <String, PlanningTask>{};
    for (final dayMap in _planningOptimisticByDateKey.values) {
      merged.addAll(dayMap);
    }
    _planningOptimisticByDateKey.clear();
    for (final t in merged.values) {
      final projected = _reprojectPlanningTaskWallTimes(t);
      final dk = _planOptimisticDayKeyFor(projected);
      _planningOptimisticByDateKey.putIfAbsent(
        dk,
        () => {},
      )[projected.planRowIdForBackend] = projected;
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final k in m.keys.toList()) {
        final v = m[k];
        if (v != null) {
          m[k] = _reprojectPlanningTaskWallTimes(v);
        }
      }
    }
  }

  void _pokeAllPlanningStreamHubsFromCache() {
    for (final hub in _planningStreamHubs.values) {
      hub.emitCachedPlans(this);
    }
  }

  /// Profile wall minute-of-day for a stored UTC instant (Time View / filter tests).
  int profileWallMinuteOfDayFromUtc(DateTime utc) {
    final wall = _profileWallFromUtc(utc.toUtc());
    return wall.hour * 60 + wall.minute;
  }

  /// Whether [startUtc] falls on [wallDay] in the active profile timezone.
  bool planUtcInstantOnProfileWallDay({
    required DateTime startUtc,
    required DateTime wallDay,
  }) {
    final startWall = _profileWallFromUtc(startUtc.toUtc());
    final targetDayStr =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    return _dateKeyFromDate(startWall) == targetDayStr;
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
      final instants = _planUtcInstants(t);
      if (instants == null) continue;
      final startWall = _profileWallFromUtc(instants.startUtc);
      final endWall = instants.endUtc != null
          ? _profileWallFromUtc(instants.endUtc!)
          : null;
      final planDayStr = _dateKeyFromDate(startWall);
      final visible = planDayStr == targetDayStr;
      _logPlanTimeTzProjection(
        task: t,
        selectedDay: targetDayStr,
        visible: visible,
        startUtc: instants.startUtc,
        endUtc: instants.endUtc,
        wallStart: startWall,
        wallEnd: endWall,
      );
      if (!visible) continue;
      plans.add(_reprojectPlanningTaskWallTimes(t));
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
    return dedupePlanningTasksForDisplay(
      plans,
      traceSource: 'cache',
      dayKey: targetDayStr,
    );
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
    final projected = _coalescePlanningTaskWallUtcFields(task);
    _logPlanTimeCacheProjected(projected);
    _planningOptimisticByDateKey.putIfAbsent(dk, () => {})[pid] = projected;
    _upsertPlanInUserCache(projected);
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
    if (overlay == null || overlay.isEmpty) {
      return dedupePlanningTasksForDisplay(
        filtered,
        traceSource: 'stream',
        dayKey: targetDayStr,
      );
    }
    final byId = <String, PlanningTask>{
      for (final t in filtered) t.planRowIdForBackend: t,
    };
    // Overlay wins for any row id present (tags/title edits until PATCH clears the overlay).
    for (final e in overlay.entries) {
      byId[e.key] = e.value;
    }
    final merged = dedupePlanningTasksForDisplay(
      _dedupePlanningTasksByBusinessId(byId.values.toList()),
      traceSource: 'stream',
      dayKey: targetDayStr,
    );
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

  /// Wall `YYYY-MM-DD` where the plan is currently scheduled (profile TZ projection).
  String planningWallScheduleDateKey(PlanningTask t) {
    final instants = _planUtcInstants(t);
    if (instants != null) {
      final wall = _profileWallFromUtc(instants.startUtc);
      return _dateKeyFromDate(wall);
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

  /// Default plan block minutes when no tag duration applies.

  /// Cache + optimistic overlay for one wall day (no network).
  List<PlanningTask> planningDayTasksSnapshot(DateTime wallDay) {
    final key = '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    final base = _filterPlansForWallDay(_allPlansUserCache, wallDay);
    return _mergePlanningOptimistic(key, base);
  }

  WarmSnapshotWindow<PlansDaySnapshot> get _plansWarm =>
      _plansWarmWindow ??= WarmSnapshotWindow(
        dateKeyOf: (d) => '${d.year}-${_two(d.month)}-${_two(d.day)}',
      );

  PlansDaySnapshot _buildPlansDaySnapshot(DateTime wallDay) {
    final tasks = planningDayTasksSnapshot(wallDay);
    return PlansDaySnapshot(
      dateKey: '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}',
      knownEmpty: tasks.isEmpty,
      tasks: List<PlanningTask>.from(tasks),
      cacheSignature: plansProjectionCacheSignature(),
    );
  }

  void ensurePlansWarmWindow(DateTime center) {
    // P0 duplicate safety: no Planning warm cache mutation before user opens Plans.
    if (!kPlansWarmWindowEnabled) return;
    _plansWarm.ensureInitialWindow(center, _buildPlansDaySnapshot);
  }

  /// P0T: critical ±1 sync at boot; full mounted window in background.
  void preparePlansMountedWindowBoot(
    DateTime center, {
    bool criticalOnly = false,
  }) {
    ensurePlansWarmWindow(center);
    if (criticalOnly) {
      for (final offset in [-1, 0, 1]) {
        final d = DateTime(
          center.year,
          center.month,
          center.day,
        ).add(Duration(days: offset));
        plansWarmSnapshotForDate(d);
        plansBodyEntryForDate(d, allowEmergencyBuild: true);
        buildPlansDayRenderSnapshot(d);
      }
      return;
    }
    final window = DayWindow(center: center);
    for (final d in window.dates) {
      plansWarmSnapshotForDate(d);
      plansBodyEntryForDate(d, allowEmergencyBuild: true);
      buildPlansDayRenderSnapshot(d);
    }
  }

  void schedulePlansMountedWindowBootBackground(DateTime center) {
    unawaited(
      Future.microtask(() {
        preparePlansMountedWindowBoot(center);
      }),
    );
  }

  PlansDayRenderSnapshot? plansRenderSnapshotForDate(DateTime wallDay) {
    return P0tRenderSnapshotCache.instance.peekPlans(p0tDateKey(wallDay));
  }

  bool isPlansDateFullyReady(DateTime wallDay) {
    final key = p0tDateKey(wallDay);
    final snap = P0tRenderSnapshotCache.instance.peekPlans(key);
    if (snap != null && snap.ready) {
      return true;
    }
    final missing = snap?.missing ?? _plansReadyMissingReason(wallDay);
    return false;
  }

  String _plansReadyMissingReason(DateTime wallDay) {
    final key = p0tDateKey(wallDay);
    final body = plansDayBodyCache.peek(key);
    if (body == null || !body.bodyReady) return 'tasks';
    if (_rules.isEmpty && body.tasks.any((t) => t.categoryId != 0)) {
      return 'category';
    }
    return 'metadata';
  }

  PlansDayRenderSnapshot buildPlansDayRenderSnapshot(
    DateTime wallDay, {
    String? activeRecordingTitleNorm,
  }) {
    final key = p0tDateKey(wallDay);
    final body = plansBodyEntryForDate(wallDay);
    final planActual = aggregateSourcePlanActualSecondsForWallCalendarDay(
      wallDay,
    );
    final cards = <PlanCardRenderDto>[];
    var missing = 'none';

    for (final task in body.tasks) {
      final hydrated = _hydratePlanTaskForRender(task);
      final pbId = DatabaseService.pocketRelationIdOrNull(
        hydrated.pocketRecordId,
      );
      final tracked = pbId != null ? (planActual[pbId] ?? 0) : 0;
      final estimate = planningWallEstimateSeconds(
        hydrated,
      );
      final titleNorm = hydrated.title.trim().toLowerCase();
      final highlight =
          activeRecordingTitleNorm != null &&
          activeRecordingTitleNorm == titleNorm;
      final categoryReady =
          hydrated.categoryId == 0 ||
          getCategoryRuleById(hydrated.categoryId) != null;
      final tagsReady = _planTaskTagsRenderReady(hydrated);
      if (!categoryReady) missing = 'category';
      if (!tagsReady && missing == 'none') missing = 'tags';

      final showPlay = !hydrated.isDone;
      cards.add(
        PlanCardRenderDto(
          task: hydrated,
          planTrackedSeconds: tracked,
          planEstimatedSeconds: estimate,
          displayIsDone: hydrated.isDone,
          showPlay: showPlay,
          highlightAsRunning: highlight,
          timeLabel: timelineTimeRangeLabel(hydrated),
          tagsReady: tagsReady,
          categoryReady: categoryReady,
        ),
      );
    }

    final ready = missing == 'none' && body.bodyReady;
    final snap = PlansDayRenderSnapshot(
      dateKey: key,
      knownEmpty: body.knownEmpty,
      cards: cards,
      cacheSignature: body.tasks.length,
      ready: ready,
      missing: ready ? 'none' : missing,
    );
    P0tRenderSnapshotCache.instance.putPlans(snap);
    return snap;
  }

  PlanningTask _hydratePlanTaskForRender(PlanningTask task) {
    final catalog = cachedUserTagsCatalog;
    if (task.tags.isEmpty || catalog.isEmpty) return task;
    final byPb = <String, Tag>{
      for (final t in catalog)
        if ((t.pbRecordId ?? '').trim().isNotEmpty) t.pbRecordId!: t,
    };
    if (byPb.isEmpty) return task;
    final tags = [
      for (final tag in task.tags) byPb[tag.pbRecordId ?? ''] ?? tag,
    ];
    return task.copyWith(tags: tags);
  }

  bool _planTaskTagsRenderReady(PlanningTask task) {
    if (task.tags.isEmpty) return true;
    return task.tags.every((t) => t.name.trim().isNotEmpty && t.rendersAsChip);
  }

  void preparePlansCriticalRenderReady(DateTime center) {
    final sw = Stopwatch()..start();
    var ready = 0;
    for (final offset in [-1, 0, 1]) {
      final day = DateTime(
        center.year,
        center.month,
        center.day,
      ).add(Duration(days: offset));
      buildPlansDayRenderSnapshot(day);
      if (isPlansDateFullyReady(day)) ready++;
    }
    sw.stop();
  }

  int get plansWarmWindowTaskEstimate {
    var n = 0;
    for (final key in _plansWarm.dateKeys) {
      n += _plansWarm.peek(key)?.tasks.length ?? 0;
    }
    return n;
  }

  void extendPlansWarmWindowIfNeeded(DateTime center) {
    if (!kPlansWarmWindowEnabled) return;
    _plansWarm.extendIfNeeded(center, _buildPlansDaySnapshot);
  }

  PlansDaySnapshot plansWarmSnapshotForDate(DateTime wallDay) {
    if (!kPlansWarmWindowEnabled) {
      return _buildPlansDaySnapshot(wallDay);
    }
    final lookupSw = Stopwatch()..start();
    final key = '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    final sig = _allPlansUserCache.length;
    final existing = _plansWarm.peek(key);
    if (existing != null && existing.cacheSignature == sig) {
      lookupSw.stop();
      return existing;
    }
    final built = _buildPlansDaySnapshot(wallDay);
    _plansWarm.put(key, built);
    lookupSw.stop();
    return built;
  }

  void _refreshPlansWarmSnapshotsAfterCacheMutation({bool force = false}) {
    if (_plansWarm.center == null) return;
    final sig = plansProjectionCacheSignature();
    for (final key in _plansWarm.dateKeys.toList()) {
      final snap = _plansWarm.peek(key);
      if (!force && snap != null && snap.cacheSignature == sig) continue;
      final day = WarmSnapshotWindow.parseDateKey(key);
      _plansWarm.put(key, _buildPlansDaySnapshot(day));
    }
  }

  DayBodyCache<PlansDayBodyEntry> get plansDayBodyCache =>
      _plansBodyCache ??= DayBodyCache<PlansDayBodyEntry>(screen: 'Plans');

  PlansDayBodyEntry _buildPlansBodyEntry(
    DateTime wallDay, {
    required String source,
  }) {
    final snap = plansWarmSnapshotForDate(wallDay);
    return PlansDayBodyEntry(
      dateKey: '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}',
      tasks: List<PlanningTask>.from(snap.tasks),
      knownEmpty: snap.knownEmpty,
      bodyReady: true,
      source: source,
    );
  }

  PlansDayBodyEntry plansBodyEntryForDate(
    DateTime wallDay, {
    bool allowEmergencyBuild = true,
  }) {
    final key = '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    final cache = plansDayBodyCache;
    final existing = cache.peek(key);
    if (existing != null && existing.bodyReady) {
      return existing;
    }
    if (!allowEmergencyBuild) {
      return PlansDayBodyEntry(
        dateKey: key,
        tasks: const [],
        knownEmpty: true,
        bodyReady: false,
        source: 'pending',
      );
    }
    final inside = cache.isInsideWarmRange(key);
    final sw = Stopwatch()..start();
    final built = _buildPlansBodyEntry(wallDay, source: 'emergencySyncBuild');
    sw.stop();
    cache.put(key, built);
    return built;
  }

  Future<void> restorePlansWarmSnapshotsFromDiskAtBoot() async {
    final sw = Stopwatch()..start();
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(
        _scopedDataCacheKey(DatabaseService._cachePlansWarmSnapshotsKey),
      );
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      var count = 0;
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final v = entry.value;
        if (v is! Map) continue;
        final tasksRaw = v['tasks'];
        if (tasksRaw is! List) continue;
        final tasks = <PlanningTask>[];
        for (final t in tasksRaw) {
          if (t is Map) {
            try {
              tasks.add(PlanningTask.fromJson(Map<String, dynamic>.from(t)));
            } catch (_) {}
          }
        }
        final scrubbed = scrubPlanningTasksForLocalCache(tasks);
        if (scrubbed.length != tasks.length && !kReleaseMode) {
          planDupTrace(
            'source=warmDiskRestore day=$key '
            'removed=${tasks.length - scrubbed.length}',
          );
        }
        final knownEmpty = v['knownEmpty'] == true;
        final sig = v['cacheSignature'] is int ? v['cacheSignature'] as int : 0;
        _plansWarm.put(
          key,
          PlansDaySnapshot(
            dateKey: key,
            knownEmpty: knownEmpty,
            tasks: scrubbed,
            cacheSignature: sig,
          ),
        );
        plansDayBodyCache.put(
          key,
          PlansDayBodyEntry(
            dateKey: key,
            tasks: List<PlanningTask>.from(scrubbed),
            knownEmpty: knownEmpty,
            bodyReady: true,
            source: 'diskRestore',
          ),
        );
        count++;
      }
      sw.stop();
    } catch (_) {}
  }

  void persistPlansWarmSnapshotsToDisk() {
    unawaited(() async {
      final sw = Stopwatch()..start();
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        final out = <String, dynamic>{};
        for (final key in _plansWarm.dateKeys) {
          final snap = _plansWarm.peek(key);
          if (snap == null) continue;
          out[key] = {
            'knownEmpty': snap.knownEmpty,
            'cacheSignature': snap.cacheSignature,
            'tasks': snap.tasks.map((t) => t.toJson()).toList(),
          };
        }
        await prefs.setString(
          _scopedDataCacheKey(DatabaseService._cachePlansWarmSnapshotsKey),
          jsonEncode(out),
        );
        sw.stop();
      } catch (_) {}
    }());
  }

  void prebuildPlansCriticalBodiesSync(DateTime center) {
    final cache = plansDayBodyCache;
    final centerKey =
        '${center.year}-${_two(center.month)}-${_two(center.day)}';
    cache.setCenter(centerKey);
    final sw = Stopwatch()..start();
    for (final offset in [-1, 0, 1]) {
      final day = DateTime(
        center.year,
        center.month,
        center.day,
      ).add(Duration(days: offset));
      final entry = _buildPlansBodyEntry(day, source: 'criticalPrebuild');
      cache.put(entry.dateKey, entry);
    }
    sw.stop();
    logPlansBootAdjacentReady(center);
  }

  void logPlansBootAdjacentReady(DateTime center) {
    for (final label in ['yesterday', 'today', 'tomorrow']) {
      final offset = label == 'yesterday'
          ? -1
          : label == 'tomorrow'
          ? 1
          : 0;
      final day = DateTime(
        center.year,
        center.month,
        center.day,
      ).add(Duration(days: offset));
      final key = '${day.year}-${_two(day.month)}-${_two(day.day)}';
      final cache = plansDayBodyCache;
      final snap = _plansWarm.peek(key);
    }
  }

  void schedulePlansWindowBodyPrebuild(DateTime center) {
    if (_plansWindowBodyPrebuildInFlight) return;
    _plansWindowBodyPrebuildInFlight = true;
    final gen = ++_plansBodyPrebuildGeneration;
    final centerKey =
        '${center.year}-${_two(center.month)}-${_two(center.day)}';
    plansDayBodyCache.setCenter(centerKey);
    unawaited(() async {
      final sw = Stopwatch()..start();
      final total = RenderedDayBodyConstants.radius * 2 + 1;
      var ready = 0;
      for (final offset in DayBodyCache.prioritizedOffsets(
        RenderedDayBodyConstants.radius,
      )) {
        if (gen != _plansBodyPrebuildGeneration) return;
        await Future<void>.delayed(Duration.zero);
        final day = DateTime(
          center.year,
          center.month,
          center.day,
        ).add(Duration(days: offset));
        final key = '${day.year}-${_two(day.month)}-${_two(day.day)}';
        final cache = plansDayBodyCache;
        if (cache.isBodyReady(key)) {
          ready++;
          continue;
        }
        final bodySw = Stopwatch()..start();
        final entry = _buildPlansBodyEntry(day, source: 'windowPrebuild');
        cache.put(key, entry);
        bodySw.stop();
        ready++;
        if (ready % 4 == 0 || ready == total) {}
      }
      sw.stop();
      plansDayBodyCache.logMemory(
        snapshotCount: _plansWarm.cachedDayCount,
        itemCount: _allPlansUserCache.length,
      );
      _plansWindowBodyPrebuildInFlight = false;
    }());
  }

  void extendPlansRenderedBodiesIfNeeded(DateTime center) {
    extendPlansWarmWindowIfNeeded(center);
    schedulePlansWindowBodyPrebuild(center);
  }

  void ensurePlansRenderedBodiesWarm(DateTime center) {
    prebuildPlansCriticalBodiesSync(center);
    schedulePlansWindowBodyPrebuild(center);
  }

  void markPlansDayBodyRendered(String dateKey, int buildMs) {
    final existing = plansDayBodyCache.peek(dateKey);
    if (existing != null && existing.bodyReady) return;
    if (existing != null) {
      plansDayBodyCache.put(
        dateKey,
        PlansDayBodyEntry(
          dateKey: dateKey,
          tasks: existing.tasks,
          knownEmpty: existing.knownEmpty,
          bodyReady: true,
          source: existing.source,
        ),
      );
    }
  }

  /// Auto start/end for a new plan on a day. Explicit parsed range always wins.
  /// When [startUtcInstant] is non-null, category default used a fixed/profile TZ
  /// for wall→UTC; callers should pass UTC to [PlanningTask] and let coalesce
  /// reproject display walls.
  ({
    DateTime startWall,
    DateTime endWall,
    DateTime? startUtcInstant,
    DateTime? endUtcInstant,
  })
  resolveAutoPlanSchedule({
    required DateTime wallDay,
    required int categoryId,
    required List<Tag> tags,
    required List<PlanningTask> existingDayPlans,
    DateTime? explicitStartWall,
    DateTime? explicitEndWall,
    bool hasExplicitTimeRange = false,
    int timelineDayStartHour = 0,
    int? explicitDurationMinutes,
  }) {
    if (hasExplicitTimeRange &&
        explicitStartWall != null &&
        explicitEndWall != null) {
      const probePlanId = '__auto_schedule_probe__';
      final dayKey =
          '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
      final probe = PlanningTask(
        id: 0,
        title: '',
        categoryId: categoryId,
        isDone: false,
        dateKey: dayKey,
        order: 999999,
        startTime: explicitStartWall,
        endDateTime: explicitEndWall,
        tags: tags,
        planRowId: probePlanId,
      );
      final cascadedProbe = normalizeSequentialPlanTimesForDay([
        ...existingDayPlans,
        probe,
      ]).firstWhere((t) => t.planRowId == probePlanId);
      return (
        startWall: cascadedProbe.startTime ?? explicitStartWall,
        endWall: cascadedProbe.endDateTime ?? explicitEndWall,
        startUtcInstant: null,
        endUtcInstant: null,
      );
    }

    final durationMin =
        explicitDurationMinutes != null && explicitDurationMinutes > 0
        ? explicitDurationMinutes.clamp(1, 24 * 60)
        : resolvePlanDurationMinutesFromTags(tags);

    String? categoryDefaultTimezoneIana;
    var usedCategoryDefault = false;
    late final DateTime startWall;
    if (explicitStartWall != null) {
      startWall = explicitStartWall;
    } else {
      DateTime? latestEnd;
      for (final p in existingDayPlans) {
        if (p.startTime == null) continue;
        final end = _resolvedPlanWallEnd(p);
        if (end == null) continue;
        if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;
      }
      if (latestEnd != null) {
        startWall = _snapPlanWallDateTime(latestEnd);
      } else {
        final catSchedule = effectiveDefaultPlanScheduleForCategory(categoryId);
        if (catSchedule?.hhmm != null) {
          final h = int.tryParse(catSchedule!.hhmm!.substring(0, 2));
          final m = int.tryParse(catSchedule.hhmm!.substring(3, 5));
          if (h != null && m != null) {
            usedCategoryDefault = true;
            categoryDefaultTimezoneIana = catSchedule.timezoneIana;
            startWall = _snapPlanWallDateTime(
              DateTime(wallDay.year, wallDay.month, wallDay.day, h, m),
            );
          } else {
            startWall = _snapPlanWallDateTime(
              PlanTimeVisibleWindow.windowStartWall(
                wallDay,
                timelineDayStartHour,
              ),
            );
          }
        } else {
          startWall = _snapPlanWallDateTime(
            PlanTimeVisibleWindow.windowStartWall(
              wallDay,
              timelineDayStartHour,
            ),
          );
        }
      }
    }

    var resolvedStart = _avoidPlanWallScheduleCollisions(
      startWall: startWall,
      durationMin: durationMin,
      existingDayPlans: existingDayPlans,
    );

    var endWall =
        explicitEndWall != null &&
            explicitEndWall.isAfter(resolvedStart) &&
            hasExplicitTimeRange
        ? explicitEndWall
        : resolvedStart.add(Duration(minutes: durationMin));

    final dayKey =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    const probePlanId = '__auto_schedule_probe__';
    final probe = PlanningTask(
      id: 0,
      title: '',
      categoryId: categoryId,
      isDone: false,
      dateKey: dayKey,
      order: 999999,
      startTime: resolvedStart,
      endDateTime: endWall,
      tags: tags,
      planRowId: probePlanId,
    );
    final cascadedProbe = normalizeSequentialPlanTimesForDay([
      ...existingDayPlans,
      probe,
    ]).firstWhere((t) => t.planRowId == probePlanId);
    resolvedStart = cascadedProbe.startTime ?? resolvedStart;
    endWall = cascadedProbe.endDateTime ?? endWall;

    if (usedCategoryDefault) {
      final startUtc = wallUtcForCategoryDefaultWall(
        wallDay: wallDay,
        hour: resolvedStart.hour,
        minute: resolvedStart.minute,
        timezoneIana: categoryDefaultTimezoneIana,
      );
      final endUtc = startUtc.add(Duration(minutes: durationMin));
      return (
        startWall: resolvedStart,
        endWall: endWall,
        startUtcInstant: startUtc,
        endUtcInstant: endUtc,
      );
    }

    return (
      startWall: resolvedStart,
      endWall: endWall,
      startUtcInstant: null,
      endUtcInstant: null,
    );
  }

  ({DateTime startWall, DateTime endWall}) profileDisplayWallsFromAutoSchedule(
    ({
      DateTime startWall,
      DateTime endWall,
      DateTime? startUtcInstant,
      DateTime? endUtcInstant,
    })
    schedule,
  ) {
    if (schedule.startUtcInstant != null) {
      final sw = _profileWallFromUtc(schedule.startUtcInstant!);
      final ew = schedule.endUtcInstant != null
          ? _profileWallFromUtc(schedule.endUtcInstant!)
          : schedule.endWall;
      return (startWall: sw, endWall: ew);
    }
    return (startWall: schedule.startWall, endWall: schedule.endWall);
  }

  PlanningTask planningTaskWithAutoSchedule(
    PlanningTask task,
    ({
      DateTime startWall,
      DateTime endWall,
      DateTime? startUtcInstant,
      DateTime? endUtcInstant,
    })
    schedule,
  ) {
    if (schedule.startUtcInstant != null) {
      return task.copyWith(
        startUtcInstant: schedule.startUtcInstant,
        endUtcInstant: schedule.endUtcInstant,
        startTime: null,
        endDateTime: null,
      );
    }
    return task.copyWith(
      startTime: schedule.startWall,
      endDateTime: schedule.endWall,
    );
  }

  /// Non-blocking overload hints after scheduling plans on a day.
  PlanDayOverloadReport evaluatePlanDayScheduleOverload({
    required List<PlanningTask> dayPlans,
    required int timelineStartHour,
    required int timelineEndHour,
  }) {
    var totalMinutes = 0;
    final byCategory = <int, int>{};
    DateTime? latestEnd;

    for (final p in dayPlans) {
      final st = p.startTime;
      if (st == null) continue;
      final end = _resolvedPlanWallEnd(p);
      if (end == null) continue;
      final dur = end.difference(st).inMinutes.clamp(1, 24 * 60);
      totalMinutes += dur;
      byCategory[p.categoryId] = (byCategory[p.categoryId] ?? 0) + dur;
      if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;
    }

    var exceedsVisibleDay = false;
    if (latestEnd != null) {
      DateTime? wallDay;
      for (final p in dayPlans) {
        final dk = p.dateKey.trim();
        if (dk.length >= 10) {
          final parts = dk.split('-');
          if (parts.length >= 3) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) {
              wallDay = DateTime(y, m, d);
              break;
            }
          }
        }
      }
      wallDay ??= DateTime(latestEnd.year, latestEnd.month, latestEnd.day);
      final windowStart = PlanTimeVisibleWindow.windowStartWall(
        wallDay,
        timelineStartHour,
      );
      final windowEnd = PlanTimeVisibleWindow.windowEndWall(
        wallDay,
        timelineEndHour,
      );
      exceedsVisibleDay =
          latestEnd.isAfter(windowEnd) || latestEnd.isBefore(windowStart);
    }

    final exceedsDailyTotal = totalMinutes > kPlanDayOverloadTotalMinutes;
    final hasCategoryOverload = byCategory.values.any(
      (m) => m > kPlanCategoryOverloadMinutes,
    );

    return PlanDayOverloadReport(
      exceedsVisibleDay: exceedsVisibleDay,
      exceedsDailyTotal: exceedsDailyTotal,
      hasCategoryOverload: hasCategoryOverload,
    );
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

  /// ISO UTC for start of a calendar [dateKey] (`YYYY-MM-DD`) in profile wall-clock, then stored as UTC.
  String? _planStartUtcIsoFromDateKey(String dateKey) {
    try {
      if (dateKey.length < 10) return null;
      final y = int.parse(dateKey.substring(0, 4));
      final m = int.parse(dateKey.substring(5, 7));
      final d = int.parse(dateKey.substring(8, 10));
      final startWall = DateTime(y, m, d, 0, 0, 0);
      return wall_clock
          .wallClockToUtcForLabel(
            startWall,
            _settings.timezoneOffsetHours,
            _settings.preferredTimeZone,
          )
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

    title = SmartInputParser.preservedTitleFromRaw(rawText);
    if (title.isEmpty) return false;

    if (range != null) {
      parsed = null;
    } else {
      parsed = SmartInputParser.parseTitleForScheduledTime(rawText);
    }

    final match = identifyCategory(title);
    final categoryId =
        match?.id ??
        categoryIdHint ??
        defaultCategoryId ??
        (rules.isNotEmpty ? rules.first.id : 0);

    final existingDay = planningDayTasksSnapshot(ymd);
    final explicitStartWall = range != null
        ? range.startWallOn(ymd)
        : parsed?.wallDateTimeOn(ymd);
    final explicitEndWall = range?.endWallOn(ymd);
    final schedule = resolveAutoPlanSchedule(
      wallDay: ymd,
      categoryId: categoryId,
      tags: const [],
      existingDayPlans: existingDay,
      explicitStartWall: explicitStartWall,
      explicitEndWall: explicitEndWall,
      hasExplicitTimeRange: range != null,
      timelineDayStartHour: 0,
    );

    if (getCategoryRuleById(categoryId) == null) {
      DatabaseService._log(
        'VOICE_PLAN: blocked — unknown category $categoryId',
      );
      return false;
    }

    final nextOrder = await nextPlanningOrderForDate(ymd);
    final clientPlanId = DatabaseService.newClientUuid();

    return addPlanningTask(
      planningTaskWithAutoSchedule(
        PlanningTask(
          id: 0,
          title: title,
          categoryId: categoryId,
          isDone: false,
          dateKey: taskDateKey,
          order: nextOrder,
          checklist: const [],
          parentPlanId: null,
          tags: const [],
          isSynced: false,
        ),
        schedule,
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
        final d = dateKey.trim();
        if (d.length >= 10) {
          final y = int.tryParse(d.substring(0, 4));
          final m = int.tryParse(d.substring(5, 7));
          final day = int.tryParse(d.substring(8, 10));
          if (y != null && m != null && day != null) {
            final wallDay = DateTime(y, m, day);
            final existingDay = planningDayTasksSnapshot(wallDay);
            final schedule = resolveAutoPlanSchedule(
              wallDay: wallDay,
              categoryId: categoryId,
              tags: const [],
              existingDayPlans: existingDay,
              timelineDayStartHour: 0,
            );
            await addPlanningTask(
              planningTaskWithAutoSchedule(
                PlanningTask(
                  id: 0,
                  title: title,
                  categoryId: categoryId,
                  dateKey: dateKey,
                  order: 0,
                ),
                schedule,
              ),
            );
          }
        }
      } catch (_) {}
    }());
  }

  /// Planning list stream. **No periodic polling** (PageView keeps many days alive).
  /// [listenToGlobalPlanningRefresh]: only the **visible** planning day should be `true` so [notifyPlanningRefresh]
  /// does not fan out identical GETs to every off-screen [PlanningPage].
  ///
  /// One shared hub per (wall-day, global-listen) — ref-counted; replaces snapshot on emit (never append).
  Stream<List<PlanningTask>> planningStream(
    DateTime selectedDate, {
    bool listenToGlobalPlanningRefresh = true,
  }) {
    final targetDayStr =
        '${selectedDate.year}-${_two(selectedDate.month)}-${_two(selectedDate.day)}';
    final hubKey = '$targetDayStr|$listenToGlobalPlanningRefresh';
    final hub = _planningStreamHubs.putIfAbsent(
      hubKey,
      () => _PlanningDayStreamHub(
        streamId: 'ps-${++_planningStreamIdSeq}',
        dayKey: targetDayStr,
        wallDay: selectedDate,
        listenGlobal: listenToGlobalPlanningRefresh,
      ),
    );
    return Stream.multi((controller) {
      hub.acquire(this);
      final sub = hub.controller.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      if (_allPlansUserCache.isEmpty) {
        unawaited(() async {
          final offline = await _loadPlanningTasksDayCache(targetDayStr);
          if (!hub.controller.isClosed && offline.isNotEmpty) {
            final merged = _mergePlanningOptimistic(targetDayStr, offline);
            hub.controller.add(merged);
          }
        }());
      }
      controller.onCancel = () {
        sub.cancel();
        hub.release();
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
      final instants = _planUtcInstantsFromWall(task)!;
      body['start_time'] = instants.startUtc.toIso8601String();
    } else if (!isDatelessBacklog) {
      final dk = task.dateKey.trim();
      if (dk.length >= 10) {
        final iso = _planStartUtcIsoFromDateKey(dk);
        if (iso != null) body['start_time'] = iso;
      }
    }
    if (task.endDateTime != null) {
      final instants = _planUtcInstantsFromWall(task)!;
      if (instants.endUtc != null) {
        body['end_time'] = instants.endUtc!.toIso8601String();
      }
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
    final instKey = task.recurrenceInstanceDateKey?.trim() ?? '';
    if (instKey.length >= 10) {
      body['recurrence_instance_date_key'] = instKey.substring(0, 10);
    }
    if (task.tags.isNotEmpty) {
      final pbIds = await _pbTagRecordIdsFromTags(task.tags);
      if (pbIds.isNotEmpty) {
        body['tags_link'] = pbIds;
      }
    }
    return body;
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
    if (task.startTime != null) {
      final dk = task.dateKey.trim();
      if (dk.length >= 10) {
        final ymd = dk.substring(0, 10).split('-');
        if (ymd.length == 3) {
          final y = int.tryParse(ymd[0]);
          final m = int.tryParse(ymd[1]);
          final d = int.tryParse(ymd[2]);
          if (y != null && m != null && d != null) {
            applySequentialTimeViewCascadeIfNeeded(wallDay: DateTime(y, m, d));
          }
        }
      }
    }
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
      final normalized = _coalescePlanningTaskWallUtcFields(
        task,
        logCreate: task.startTime != null || task.startUtcInstant != null,
        titleForLog: titleTrimmed,
      );
      return _addPlanningTaskPocket(
        normalized,
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

  Future<bool> _persistPlanningTaskOrdersBulkNow(
    List<PlanningTask> ordered,
  ) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) return false;

    final baseline = _planReorderBaselineByPlanId;
    var patched = 0;
    var hardFailed = false;

    try {
      await ensurePocketBaseReady();
      for (final t in ordered) {
        final input = t.planRowIdForBackend.trim();
        if (input.isEmpty || input.startsWith('optimistic-')) continue;
        if (input.startsWith('virt-')) {
          DatabaseService._log(
            'PLAN_REORDER_FAIL planId=$input pocketId=- status=virtual '
            'error=recurring_virtual_not_reorderable payload=order:${t.order}',
          );
          hardFailed = true;
          continue;
        }
        final newOrder = t.order;
        final oldOrder = baseline?[input];
        if (oldOrder != null && oldOrder == newOrder) continue;

        final businessId = _outboxBusinessPlanId(
          input,
          planBusinessId: t.planRowId,
        );
        final shadowPb = _tryResolvePlanPbIdFromCacheOnly(
          input,
          planBusinessId: t.planRowId,
        );
        final String resolved;
        if (shadowPb != null &&
            DatabaseService._isLikelyPocketBaseRowId(shadowPb)) {
          resolved = shadowPb;
        } else {
          resolved = await _resolvePlanRestId(
            input,
            planBusinessId: t.planRowId,
          );
        }
        if (!DatabaseService._isLikelyPocketBaseRowId(resolved)) {
          DatabaseService._log(
            'PLAN_REORDER_FAIL planId=$businessId pocketId=$resolved '
            'status=resolve error=invalid_pb_id payload=order:$newOrder',
          );
          hardFailed = true;
          continue;
        }

        DatabaseService._log(
          'PLAN_REORDER_PATCH planId=$businessId pocketId=$resolved '
          'oldOrder=${oldOrder ?? '-'} newOrder=$newOrder',
        );

        final ok = await _patchPlanUpdateNetworkPhase(
          originalInput: input,
          resolvedPbId: resolved,
          businessId: businessId,
          patchBody: <String, dynamic>{'order': newOrder},
          suppressAppSnack: true,
        );
        if (ok) {
          patched++;
        } else {
          DatabaseService._log(
            'PLAN_REORDER_FAIL planId=$businessId pocketId=$resolved '
            'status=patch error=network_phase_returned_false '
            'payload=order:$newOrder',
          );
          hardFailed = true;
        }
      }
    } catch (e, st) {
      DatabaseService._log('PLAN_REORDER_FAIL error=$e');
      DatabaseService._log(st.toString());
      hardFailed = true;
    }

    if (hardFailed && patched == 0) {
      _rollbackPlanningOrderBaseline(ordered);
      DatabaseService._log('PLAN_REORDER_ROLLBACK reason=all_patches_failed');
      try {
        final msg = t(currentLocale.value, 'plan_reorder_failed');
        if (!_notify.isClosed) _notify.add(msg);
      } catch (_) {}
      return false;
    }

    if (patched > 0) {
      DatabaseService._log('PLAN_REORDER_SUCCESS count=$patched');
      _planReorderBaselineByPlanId = null;
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
    }
    return !hardFailed || patched > 0;
  }

  void _rollbackPlanningOrderBaseline(List<PlanningTask> ordered) {
    final baseline = _planReorderBaselineByPlanId;
    if (baseline == null || baseline.isEmpty) return;
    for (final t in ordered) {
      final id = t.planRowIdForBackend.trim();
      if (id.isEmpty) continue;
      final old = baseline[id];
      if (old == null) continue;
      final current = _findCachedPlanningTaskForEdit(
        id,
        planBusinessId: t.planRowId,
      );
      if (current != null && current.order != old) {
        applyOptimisticPlanningTask(current.copyWith(order: old));
      }
    }
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
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
      fields['start_time'] = _profileUtcFromWall(startTime).toIso8601String();
    }
    if (clearEnd) {
      fields['end_time'] = null;
    } else if (endDateTimeDisplay != null) {
      fields['end_time'] = _profileUtcFromWall(
        endDateTimeDisplay,
      ).toIso8601String();
    } else if (endDateTime != null) {
      fields['end_time'] = _profileUtcFromWall(endDateTime).toIso8601String();
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
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final persisted = _planningTaskFromPocketRecord(
        record,
        pocketTagCatalog: tagCatalog,
      );
      _upsertPlanInUserCache(
        persisted.copyWith(
          parentPlanPocketId: task.parentPlanPocketId,
          recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
          initialDateKey: task.initialDateKey,
          isPostponed: task.isPostponed,
        ),
      );
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
        parentPlanPocketId: pid,
        recurrenceInstanceDateKey: day,
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

  bool _virtualPlanPatchIsDoneOnly({
    bool? isDone,
    String? title,
    int? categoryId,
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
    if (isDone == null) return false;
    return title == null &&
        categoryId == null &&
        notesPlain == null &&
        notesDeltaJson == null &&
        checklist == null &&
        parentPlanId == null &&
        order == null &&
        startTime == null &&
        startTimeDisplay == null &&
        endDateTime == null &&
        endDateTimeDisplay == null &&
        !clearEnd &&
        tags == null &&
        planInitialDateKey == null &&
        planIsPostponed == null &&
        !patchPlanAlarmRecurrence &&
        planRrule == null &&
        planReminderOffset == null &&
        planExceptionDates == null;
  }

  /// Materialize a JIT virtual occurrence as a concrete one-off plan (time/metadata edit).
  Future<bool> _materializeRecurringInstanceFromVirtualPatch({
    required String planRowId,
    required String parentPlanPocketId,
    required String instanceDateKey,
    String? planBusinessId,
    String? title,
    int? categoryId,
    bool? isDone,
    String? notesPlain,
    String? notesDeltaJson,
    List<Map<String, dynamic>>? checklist,
    int? order,
    DateTime? startTime,
    DateTime? startTimeDisplay,
    DateTime? endDateTime,
    DateTime? endDateTimeDisplay,
    bool clearEnd = false,
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    int? planReminderOffset,
    bool suppressAppSnack = false,
  }) async {
    final pid = parentPlanPocketId.trim();
    var day = instanceDateKey.trim();
    if (day.length < 10) return false;
    day = day.substring(0, 10);

    final cached = _findCachedPlanningTaskForEdit(
      planRowId,
      planBusinessId: planBusinessId,
    );
    final oldStart = cached?.startTime;
    final oldEnd = cached?.endDateTime;

    final newStartWall = startTimeDisplay ?? startTime ?? cached?.startTime;
    DateTime? newEndWall;
    if (clearEnd) {
      newEndWall = null;
    } else {
      newEndWall = endDateTimeDisplay ?? endDateTime ?? cached?.endDateTime;
    }

    // ignore: avoid_print
    if (kDebugMode) {
      debugPrint(
        'RECURRENCE_INSTANCE_EDIT_REQUEST planId=${planBusinessId ?? planRowId} '
        'pocketId=$pid isVirtual=true',
      );
    }

    final patched = await _patchRecurringTemplateExceptionDates(
      parentPlanPocketId: pid,
      instanceDateKey: day,
      addException: true,
      suppressAppSnack: true,
      deferPlanningNotify: true,
    );
    if (!patched) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }

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

      final scheduleDay = newStartWall != null
          ? DateTime(newStartWall.year, newStartWall.month, newStartWall.day)
          : DateTime(
              int.parse(day.substring(0, 4)),
              int.parse(day.substring(5, 7)),
              int.parse(day.substring(8, 10)),
            );
      final scheduleKey =
          '${scheduleDay.year}-${_two(scheduleDay.month)}-${_two(scheduleDay.day)}';
      final ord = order ?? await nextPlanningOrderForDate(scheduleDay);

      final material = PlanningTask(
        id: 0,
        title: (title ?? cached?.title ?? parent.title).trim(),
        categoryId: categoryId ?? cached?.categoryId ?? parent.categoryId,
        isDone: isDone ?? cached?.isDone ?? false,
        dateKey: scheduleKey,
        order: ord,
        startTime: newStartWall,
        endDateTime: newEndWall,
        checklist: checklist != null
            ? _copyChecklistForMaterialize(checklist)
            : _copyChecklistForMaterialize(
                cached?.checklist ?? parent.checklist,
              ),
        notesPlain: notesPlain ?? cached?.notesPlain ?? parent.notesPlain,
        notesDeltaJson:
            notesDeltaJson ?? cached?.notesDeltaJson ?? parent.notesDeltaJson,
        tags: List<Tag>.from(tags ?? cached?.tags ?? parent.tags),
        initialDateKey: planInitialDateKey ?? day,
        isPostponed: planIsPostponed ?? false,
        reminderOffset: planReminderOffset ?? cached?.reminderOffset,
        parentPlanPocketId: pid,
        recurrenceInstanceDateKey: day,
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

      clearOptimisticPlanningForPlanRow(planRowId);
      notifyPlanningRefresh();
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (e, st) {
      DatabaseService._log('RECURRENCE_INSTANCE_MATERIALIZE: $e');
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

      if (_virtualPlanPatchIsDoneOnly(
        isDone: isDone,
        title: title,
        categoryId: categoryId,
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
      )) {
        if (isDone!) {
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

      return _materializeRecurringInstanceFromVirtualPatch(
        planRowId: rid,
        parentPlanPocketId: virt.parentPocketId,
        instanceDateKey: effectiveDay,
        planBusinessId: planBusinessId,
        title: title,
        categoryId: categoryId,
        isDone: isDone,
        notesPlain: notesPlain,
        notesDeltaJson: notesDeltaJson,
        checklist: checklist,
        order: order,
        startTime: startTime,
        startTimeDisplay: startTimeDisplay,
        endDateTime: endDateTime,
        endDateTimeDisplay: endDateTimeDisplay,
        clearEnd: clearEnd,
        tags: tags,
        planInitialDateKey: planInitialDateKey,
        planIsPostponed: planIsPostponed,
        planReminderOffset: planReminderOffset,
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
    if (existingTask?.rrule?.trim().isNotEmpty == true &&
        (startTime != null ||
            startTimeDisplay != null ||
            endDateTime != null ||
            endDateTimeDisplay != null ||
            clearEnd)) {
      if (kDebugMode) {
        debugPrint(
          'RECURRENCE_INSTANCE_EDIT_SERIES_ROW planId=${planBusinessId ?? rid} '
          'pocketId=${existingTask?.pocketRecordId ?? '-'}',
        );
      }
    }
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

  /// Debounced bulk PATCH: [order] only (@DATA_MAP.md). One PATCH per changed row.
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

    for (final task in ordered) {
      applyOptimisticPlanningTask(task);
    }
    notifyPlanningRefresh(scheduleNetworkRefresh: false);

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

  /// Applies [scope] for recurring plan edits (virtual, materialized, or series row).
  Future<bool> updatePlanningTaskWithRecurrenceScope(
    String planRowId, {
    required RecurrenceEditScope scope,
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
    bool suppressAppSnack = false,
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,
    String? recurrenceInstanceDateKey,
  }) async {
    if (scope == RecurrenceEditScope.thisAndFuture) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    final cached = _findCachedPlanningTaskForEdit(
      planRowId,
      planBusinessId: planBusinessId,
    );
    if (scope == RecurrenceEditScope.entireSeries) {
      final seriesPb = _resolveRecurrenceSeriesPocketId(
        planRowId: planRowId,
        planBusinessId: planBusinessId,
        cached: cached,
      );
      if (seriesPb == null ||
          !DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      final seriesTask = cached?.rrule?.trim().isNotEmpty == true
          ? cached
          : _findCachedPlanningTaskForEdit(seriesPb);
      return updatePlanningTask(
        seriesPb,
        planBusinessId: seriesTask?.planRowId ?? planBusinessId,
        title: title,
        categoryId: categoryId,
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
        suppressAppSnack: suppressAppSnack,
        tags: tags,
        planInitialDateKey: planInitialDateKey,
        planIsPostponed: planIsPostponed,
        patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
        planRrule: planRrule,
        planReminderOffset: planReminderOffset,
        planExceptionDates: planExceptionDates,
        recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      );
    }
    return updatePlanningTask(
      planRowId,
      planBusinessId: planBusinessId,
      title: title,
      categoryId: categoryId,
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
      suppressAppSnack: suppressAppSnack,
      tags: tags,
      planInitialDateKey: planInitialDateKey,
      planIsPostponed: planIsPostponed,
      patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
      planRrule: planRrule,
      planReminderOffset: planReminderOffset,
      planExceptionDates: planExceptionDates,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
    );
  }

  /// Applies [scope] for recurring plan deletes.
  Future<bool> deletePlanningTaskWithRecurrenceScope(
    String planRowId, {
    required RecurrenceEditScope scope,
    String? planBusinessId,
    String? recurrenceInstanceDateKey,
    bool suppressAppSnack = false,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) return false;
    final rid = planRowId.trim();
    if (rid.isEmpty) return false;

    if (scope == RecurrenceEditScope.thisAndFuture) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }

    final cached = _findCachedPlanningTaskForEdit(
      rid,
      planBusinessId: planBusinessId,
    );

    if (scope == RecurrenceEditScope.entireSeries) {
      final seriesPb = _resolveRecurrenceSeriesPocketId(
        planRowId: rid,
        planBusinessId: planBusinessId,
        cached: cached,
      );
      if (seriesPb == null ||
          !DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      return deletePlanningTasksBulk([seriesPb]);
    }

    final virt = _parseVirtualPlanRowId(rid);
    if (virt != null) {
      return deletePlanningTasksBulk([rid]);
    }

    if (_isMaterializedRecurrenceException(
      cached ??
          PlanningTask(
            id: 0,
            title: '',
            categoryId: 0,
            isDone: false,
            dateKey: '',
            order: 0,
          ),
    )) {
      return deletePlanningTasksBulk([rid]);
    }

    final instDay = _resolveRecurrenceInstanceDateKey(
      planRowId: rid,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      cached: cached,
    );
    if (instDay != null && cached?.rrule?.trim().isNotEmpty == true) {
      final seriesPb = cached?.pocketRecordId?.trim();
      if (seriesPb != null &&
          DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
        return _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: seriesPb,
          instanceDateKey: instDay,
          addException: true,
          suppressAppSnack: suppressAppSnack,
        );
      }
    }

    return deletePlanningTasksBulk([rid]);
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
    try {
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
    } catch (_) {}
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
    if (isPbRealtimeUnavailable) {
      _logPlansRealtimeSubscribeQuiet('realtime_endpoint_unavailable');
      return;
    }
    planStreamLifecycleLog('realtimeSubscribe status=start collection=plans');
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
      _plansRealtimeFailureStreak = 0;
      _plansRealtimeReconnectTimer?.cancel();
      _plansRealtimeReconnectTimer = null;
      planStreamLifecycleLog(
        'realtimeSubscribe status=success collection=plans',
      );
    } catch (e) {
      _logPlansRealtimeSubscribeQuiet(e);
      _handleRealtimeSubscribeFailure(e, source: 'plans');
      _schedulePlansRealtimeReconnectAfterFailure();
    }
  }

  void _logPlansRealtimeSubscribeQuiet(Object e) {
    final now = DateTime.now();
    if (_lastPlansRealtimeSubscribeErrorLogAt != null &&
        now.difference(_lastPlansRealtimeSubscribeErrorLogAt!) <
            const Duration(seconds: 5)) {
      return;
    }
    _lastPlansRealtimeSubscribeErrorLogAt = now;
    if (kDebugMode) {
      debugPrint(
        'plans realtime subscribe failed (next backoff '
        '${_plansRealtimeDelayForCurrentFailureStreak().inSeconds}s): $e',
      );
    }
  }

  Duration _plansRealtimeDelayForCurrentFailureStreak() {
    final idx = _plansRealtimeFailureStreak.clamp(
      0,
      DatabaseService._kRealtimeBackoffSeconds.length - 1,
    );
    return Duration(seconds: DatabaseService._kRealtimeBackoffSeconds[idx]);
  }

  void _schedulePlansRealtimeReconnectAfterFailure() {
    if (!_hasAuthenticatedUserId) return;
    if (isPbRealtimeUnavailable) return;
    _plansRealtimeReconnectTimer?.cancel();
    final delay = _plansRealtimeDelayForCurrentFailureStreak();
    if (_plansRealtimeFailureStreak <
        DatabaseService._kRealtimeBackoffSeconds.length) {
      _plansRealtimeFailureStreak++;
    }
    _plansRealtimeReconnectTimer = Timer(delay, () {
      _plansRealtimeReconnectTimer = null;
      unawaited(
        _startPlansRealtimeSubscription().catchError((Object e, StackTrace _) {
          _handleRealtimeSubscribeFailure(e, source: 'plans-reconnect');
        }),
      );
    });
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
    if (isPbRealtimeUnavailable) return;
    _plansRealtimeReconnectTimer?.cancel();
    _plansRealtimeReconnectTimer = null;
    _plansRealtimeFailureStreak = 0;
    unawaited(
      _startPlansRealtimeSubscription().catchError((Object e, StackTrace _) {
        _handleRealtimeSubscribeFailure(e, source: 'plans-bridge');
      }),
    );
  }
}

