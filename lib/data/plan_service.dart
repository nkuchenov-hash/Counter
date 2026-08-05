// ignore_for_file: avoid_print
part of 'database_service.dart';

/// Legacy **plans** M2M column key (historical Noco expand / JSON only — unused with PocketBase plans).
const String _plansToTagsLinkColumnSystemId = 'cnmo43ed26h293n';

bool get _isPlansTableConfigured => true;

bool _planMutationOutboxFlushInFlight = false;
final Map<String, int> _pendingPlanMutationRevisionByBusinessId =
    <String, int>{};

final StreamController<List<PlanningTask>> _tasksController =
    StreamController<List<PlanningTask>>.broadcast();

/// In-memory all-user plans (single source for Planning + Lists); refreshed by fetch, PATCH merge, realtime.
List<PlanningTask> _allPlansUserCache = [];
DateTime? _allPlansUserCacheFetchedAt;
const Duration _allPlansUserCacheFreshTtl = Duration(seconds: 30);
Future<void>? _plansRealtimeSubscribeFuture;
Future<void> Function()? _plansRealtimeUnsubscribe;

List<PlanningTask> _tasksCache = [];

Timer? _planAlarmRescheduleDebounceTimer;
final Random _random = Random();

extension PlanServiceExtension on DatabaseService {
  /// Plans and Lists share the `plans.tags_link` relation but isolate chips by `tags.domain`.
  /// Use the full cached catalog when hydrating plan/list rows so plain `tags_link` ids
  /// can resolve whether the row is a dated plan (`plan`) or an undated list item (`list`).

  void _notifyTimelineAfterRecordCacheMutation() {
    if (_recordCacheTimelineNotifyBatchDepth > 0) return;
    _refreshTimelineWarmSnapshotsAfterCacheMutation();
    _emitTimelineRefreshRaw();
  }

  bool _wallScheduleMatches(PlanningTask a, PlanningTask b) {
    if (a.startTime != b.startTime) return false;
    return a.endDateTime == b.endDateTime;
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
    // Write-ahead: persist the create intent before the asynchronous POST.
    final writeAheadReceipt = await _enqueuePlanCreateMutation(
      body,
      businessId: clientPlanId,
      tags: task.tags,
    );
    await offlineSync.refreshPendingCount();
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
      await _acknowledgePlanMutation(writeAheadReceipt);
      if (!_hasPendingPlanMutationForBusinessId(clientPlanId)) {
        clearOptimisticPlanningForPlanRow(optimisticId);
      }
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return true;
    } on ClientException catch (e, st) {
      DatabaseService._log('ADD_PLAN_PB: $e');
      DatabaseService._log(st.toString());
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        return true;
      }
      if (_planMutationRetriableHttpCode(code) || _pbHttpBackoffActive) {
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      await _acknowledgePlanMutation(writeAheadReceipt);
      if (!_hasPendingPlanMutationForBusinessId(clientPlanId)) {
        clearOptimisticPlanningForPlanRow(optimisticId);
      }
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return false;
    } catch (e, st) {
      DatabaseService._log('ADD_PLAN_PB: $e');
      DatabaseService._log(st.toString());
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
    final writeAheadReceipt = await _stagePlanUpdateWriteAhead(
      originalInput: rid,
      businessId: businessId,
      patchBody: patchBody,
      pocketBaseId: shadowPb,
      tags: tags,
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
          writeAheadReceipt: writeAheadReceipt,
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
          offlineSync.setConnectivityOffline(true);
          return;
        }
        await _patchPlanUpdateNetworkPhase(
          originalInput: rid,
          resolvedPbId: restId,
          businessId: businessId,
          writeAheadReceipt: writeAheadReceipt,
          patchBody: patchBody,
          tags: tags,
          suppressAppSnack: suppressAppSnack,
        );
      } catch (e, st) {
        DatabaseService._log('UPDATE_PLANNING_TASK_PB async: $e');
        DatabaseService._log(st.toString());
        if (_planMutationRetriableHttpCode(0)) {
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
      // Realtime delivery must never wait for another HTTP request. The event
      // is merged immediately using the current tag catalog/expand payload.
      try {
        final task = _planningTaskFromPocketRecord(
          rec,
          pocketTagCatalog: _userTagsCatalogCache,
        );
        _upsertPlanInUserCache(task);
        _allPlansUserCacheFetchedAt = DateTime.now();
        final biz = _planBusinessUuidFromTask(task);
        if (!_hasPendingPlanMutationForBusinessId(biz)) {
          if (biz != null && biz.isNotEmpty) {
            clearOptimisticPlanningForPlanRow('optimistic-$biz');
          }
          clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
        }
        notifyPlanningRefresh(scheduleNetworkRefresh: false);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('plans realtime merge failed: $error\n$stackTrace');
        }
      }
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
