part of '../database_service.dart';

/// Derived warm/render snapshot and day-body caches for Planning.
extension PlanSnapshotCacheExtension on DatabaseService {
  int plansProjectionCacheSignature() => Object.hash(
    _allPlansUserCache.length,
    _settings.timezoneOffsetHours,
    _settings.preferredTimeZone.trim(),
    _profileTimezoneProjectionRevision,
  );

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
      final estimate = planningWallEstimateSeconds(hydrated);
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
}
