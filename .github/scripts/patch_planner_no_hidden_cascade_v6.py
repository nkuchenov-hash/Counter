from pathlib import Path

# 1) Restore the intended auto-placement policy and recover stale persisted state
# from the recent regression: nearest existing fitting gap, otherwise append.
helper = Path('lib/data/plans/plan_time_cascade_helpers.dart')
text = helper.read_text(encoding='utf-8')
old = """const String _keyPlanAutoPlacementMode = 'plan_auto_placement_mode';
const String _keyPlanAutoPlacementGapMigration =
    'plan_auto_placement_gap_v2_migrated';
const String _keyPlanAutoPlacementExplicitChoice =
    'plan_auto_placement_explicit_choice_v1';
PlanAutoPlacementMode _planAutoPlacementMode =
    PlanAutoPlacementMode.nearestFreeSlot;
"""
new = """const String _keyPlanAutoPlacementMode = 'plan_auto_placement_mode';
const String _keyPlanAutoPlacementRecoveryV3 =
    'plan_auto_placement_no_squeeze_v3_recovered';
const String _keyPlanAutoPlacementExplicitChoice =
    'plan_auto_placement_explicit_choice_v1';
PlanAutoPlacementMode _planAutoPlacementMode =
    PlanAutoPlacementMode.nearestFreeSlot;
"""
if old not in text:
    raise SystemExit('placement constants anchor not found')
text = text.replace(old, new, 1)

start = text.index('  Future<void> loadPlanAutoPlacementMode() async {')
end = text.index('\n  Future<void> setPlanAutoPlacementMode(', start)
replacement = """  Future<void> loadPlanAutoPlacementMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlanAutoPlacementMode);
    final recovered = prefs.getBool(_keyPlanAutoPlacementRecoveryV3) ?? false;

    // Recovery from the September placement regressions. The canonical automatic
    // behavior is: use the earliest already-free fitting gap; when none exists,
    // append after the final plan. Force that once even if a broken build persisted
    // afterLastPlan as the current preference. A later explicit user choice still
    // works normally after this one-time recovery.
    if (!recovered) {
      _planAutoPlacementMode = PlanAutoPlacementMode.nearestFreeSlot;
      await prefs.setString(
        _keyPlanAutoPlacementMode,
        PlanAutoPlacementMode.nearestFreeSlot.name,
      );
      await prefs.setBool(_keyPlanAutoPlacementRecoveryV3, true);
      return;
    }

    _planAutoPlacementMode = PlanAutoPlacementMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PlanAutoPlacementMode.nearestFreeSlot,
    );
  }
"""
text = text[:start] + replacement + text[end:]
helper.write_text(text, encoding='utf-8')

# 2) New-plan creation must never make room by moving existing plans. Re-check
# collision against the freshest local day snapshot and move only the new task.
service = Path('lib/data/plan_service.dart')
text = service.read_text(encoding='utf-8')
old = """  }) async {
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
"""
new = """  }) async {
    var createTask = task;
    final requestedStart = task.startTime;
    if (requestedStart != null) {
      final wallDay = DateTime(
        requestedStart.year,
        requestedStart.month,
        requestedStart.day,
      );
      final freshestDayPlans = planningDayTasksSnapshot(wallDay)
          .where(
            (existing) =>
                existing.planRowIdForBackend != task.planRowIdForBackend,
          )
          .toList(growable: false);
      createTask = resolvePlanningCreateCollision(
        task: task,
        wallDay: wallDay,
        existingDayPlans: freshestDayPlans,
      ).task;
    }

    final optimisticId = 'optimistic-$clientPlanId';
    applyOptimisticPlanningTask(
      createTask.copyWith(
        pocketRecordId: optimisticId,
        planRowId: clientPlanId,
        isSynced: false,
      ),
    );
    // Creation is not a reorder operation. Existing plans must never be shifted
    // just to make the new row fit; only createTask may be repositioned above.
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    late final Map<String, dynamic> body;
    try {
      body = await _buildPocketPlanCreateBody(
        createTask,
"""
if old not in text:
    raise SystemExit('create cascade anchor not found')
service.write_text(text.replace(old, new, 1), encoding='utf-8')

# 3) Rendering Time View must be read-only. Do not mutate plan times after frame.
hour_grid = Path('lib/features/planning/time_view/time_view_hour_grid.dart')
text = hour_grid.read_text(encoding='utf-8')
old = """    if (schedulablePre.isNotEmpty) {
      maybeNormalizeTimeViewOverlapsOnce(planWallDay, schedulablePre);
    }
"""
if old not in text:
    raise SystemExit('render normalization anchor not found')
hour_grid.write_text(text.replace(old, '', 1), encoding='utf-8')

# 4) Recurring target-card drag must resolve the same insertion/cascade geometry
# as a normal drag, then apply recurrence scope to the primary occurrence/series.
card = Path('lib/features/planning/time_view/time_view_card_layer.dart')
text = card.read_text(encoding='utf-8')
import_anchor = "import 'package:counter/data/models.dart';\n"
if "package:counter/data/plan_time_sequential_cascade.dart" not in text:
    if import_anchor not in text:
        raise SystemExit('card import anchor not found')
    text = text.replace(
        import_anchor,
        import_anchor + "import 'package:counter/data/plan_time_sequential_cascade.dart';\n",
        1,
    )

old_call = """      _commitRecurringTimelineVerticalDrag(
        task: task,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      ),
"""
new_call = """      _commitRecurringTimelineVerticalDrag(
        task: task,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        scheduledInRange: scheduledInRange,
      ),
"""
if old_call not in text:
    raise SystemExit('recurring drag call anchor not found')
text = text.replace(old_call, new_call, 1)

start = text.index('  Future<void> _commitRecurringTimelineVerticalDrag({')
end = text.index('\n  void commitTimelineResizeWithOptionalRecurrenceScope', start)
replacement = r'''  Future<void> _commitRecurringTimelineVerticalDrag({
    required PlanningTask task,
    required DateTime planWallDay,
    required int rangeStart,
    required List<PlanningTask> scheduledInRange,
  }) async {
    final planKey = timelineVerticalDragPlanKey;
    stopHourGridEdgeScroll();
    if (planKey == null) {
      cancelTimelineVerticalDrag();
      return;
    }
    if (planTimeViewMovementBelowDragThreshold(timelineFingerDragDeltaPx)) {
      cancelTimelineVerticalDrag();
      return;
    }

    final grid = activeTimelineDurationGrid;
    if (grid == null) {
      cancelTimelineVerticalDrag();
      return;
    }
    final durationMinutes = timelineVerticalDragDurationMin;
    final maxTopPx = grid.yForMinutesFromRangeStart(
      math.max(0, grid.totalMinutes - durationMinutes),
    );
    final fingerCanvasY = timelineFingerCanvasY(timelineFingerDragDeltaPx);
    final pointerAnchoredTopPx =
        (fingerCanvasY - timelineFingerGrabOffsetCanvasPx)
            .clamp(0.0, maxTopPx)
            .toDouble();

    var insertionIntent = timelineStoredInsertionIntent;
    if (insertionIntent != null) {
      insertionIntent = refreshTimeViewInsertionIntentFromScheduled(
        intent: insertionIntent,
        scheduled: scheduledInRange,
        resolveDurationMinutes:
            DatabaseService.instance.resolvePlanDurationMinutesFromTags,
      );
      if (insertionIntent == null) {
        cancelTimelineVerticalDrag();
        return;
      }
    }

    DateTime? emptyCanvasStartWall;
    if (insertionIntent == null) {
      final snappedMin = snapTimelineMinutes(
        grid.minutesFromY(pointerAnchoredTopPx),
      );
      emptyCanvasStartWall = wallTimeFromTimelineMinutes(
        snappedMin,
        planWallDay,
        rangeStart,
      );
    }

    final fixedPlanIds = timeViewFixedPlanIdsForTasks(scheduledInRange);
    // A separate recurrence series must never be silently rescheduled as a
    // collateral cascade; only the recurrence chosen by the user gets a scope.
    for (final candidate in scheduledInRange) {
      if (candidate.planRowIdForBackend != task.planRowIdForBackend &&
          timeViewTaskIsRecurring(candidate)) {
        fixedPlanIds.add(candidate.planRowIdForBackend);
      }
    }

    final cascadeResult = computeTimeViewInsertionCascade(
      scheduledTasks: scheduledInRange,
      draggedPlanIds: <String>{task.planRowIdForBackend},
      primaryDraggedPlanId: task.planRowIdForBackend,
      fixedPlanIds: fixedPlanIds,
      resolveDurationMinutes:
          DatabaseService.instance.resolvePlanDurationMinutesFromTags,
      targetIntent: insertionIntent,
      emptyCanvasStartWall: emptyCanvasStartWall,
      emptyCanvasHadEnd: timelineVerticalDragHadEnd,
      emptyCanvasDurationMin: durationMinutes,
    );
    if (!cascadeResult.accepted || cascadeResult.draggedStartWall == null) {
      cancelTimelineVerticalDrag();
      return;
    }

    host.notifySetState(clearTimelineInteractionState);
    await _chooseAndPersistRecurringSchedule(
      task: task,
      newStartWall: cascadeResult.draggedStartWall!,
      newEndWall: cascadeResult.draggedEndWall,
      cascadeResolved: cascadeResult.previewRows,
      scheduledBefore: scheduledInRange,
    );
  }
'''
text = text[:start] + replacement + text[end:]

old_sig = """  Future<void> _chooseAndPersistRecurringSchedule({
    required PlanningTask task,
    required DateTime newStartWall,
    required DateTime? newEndWall,
  }) async {
"""
new_sig = """  Future<void> _chooseAndPersistRecurringSchedule({
    required PlanningTask task,
    required DateTime newStartWall,
    required DateTime? newEndWall,
    List<PlanningTask>? cascadeResolved,
    List<PlanningTask>? scheduledBefore,
  }) async {
"""
if old_sig not in text:
    raise SystemExit('recurring persist signature anchor not found')
text = text.replace(old_sig, new_sig, 1)

old_tail = """    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
    }
    DatabaseService.instance.notifyPlanningRefresh();
"""
new_tail = """    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
    } else if (cascadeResolved != null && scheduledBefore != null) {
      final primaryId = task.planRowIdForBackend;
      persistTimeViewCascadePatches(
        resolved: <PlanningTask>[
          for (final row in cascadeResolved)
            if (row.planRowIdForBackend != primaryId) row,
        ],
        scheduledBefore: <PlanningTask>[
          for (final row in scheduledBefore)
            if (row.planRowIdForBackend != primaryId) row,
        ],
        commitSource: 'recurringTargetDrop:neighbors',
      );
    }
    DatabaseService.instance.notifyPlanningRefresh();
"""
if old_tail not in text:
    raise SystemExit('recurring persist tail anchor not found')
card.write_text(text.replace(old_tail, new_tail, 1), encoding='utf-8')

# 5) Regression tests: allocator semantics + no hidden cascade side effects.
test = Path('test/auto_plan_nearest_free_slot_test.dart')
text = test.read_text(encoding='utf-8')
old_migration = """  test('migrates stale persisted after-last default exactly once', () async {
    SharedPreferences.setMockInitialValues({
      'plan_auto_placement_mode': 'afterLastPlan',
    });

    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.nearestFreeSlot,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('plan_auto_placement_mode'),
      PlanAutoPlacementMode.nearestFreeSlot.name,
    );
    expect(prefs.getBool('plan_auto_placement_gap_v2_migrated'), isTrue);

    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.afterLastPlan,
    );
    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.afterLastPlan,
    );
  });
"""
new_migration = """  test('recovers stale placement state once, then respects explicit choice', () async {
    SharedPreferences.setMockInitialValues({
      'plan_auto_placement_mode': 'afterLastPlan',
      'plan_auto_placement_explicit_choice_v1': true,
    });

    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.nearestFreeSlot,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('plan_auto_placement_mode'),
      PlanAutoPlacementMode.nearestFreeSlot.name,
    );
    expect(
      prefs.getBool('plan_auto_placement_no_squeeze_v3_recovered'),
      isTrue,
    );

    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.afterLastPlan,
    );
    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.afterLastPlan,
    );
  });
"""
if old_migration not in text:
    raise SystemExit('migration test anchor not found')
text = text.replace(old_migration, new_migration, 1)

insert_before = "  test('target-card drop after is exactly adjacent in scheduled time', () {"
contract = r'''  test('no fitting earlier gap appends after the final plan', () {
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 8), DateTime(2026, 7, 24, 9)),
        _plan('b', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10)),
        _plan('c', DateTime(2026, 7, 24, 10), DateTime(2026, 7, 24, 11)),
      ],
      timelineDayStartHour: 8,
      explicitDurationMinutes: 30,
    );
    expect(schedule.startWall, DateTime(2026, 7, 24, 11));
    expect(schedule.endWall, DateTime(2026, 7, 24, 11, 30));
  });

  test('creation and Time View rendering never invoke hidden neighbor cascade', () {
    final service = File('lib/data/plan_service.dart').readAsStringSync();
    final createStart = service.indexOf('Future<bool> _addPlanningTaskPocket(');
    final createEnd = service.indexOf('Future<bool> addPlanningTask(', createStart);
    expect(createStart, greaterThanOrEqualTo(0));
    expect(createEnd, greaterThan(createStart));
    final createBlock = service.substring(createStart, createEnd);
    expect(createBlock, contains('resolvePlanningCreateCollision('));
    expect(createBlock, isNot(contains('applySequentialTimeViewCascadeIfNeeded(')));

    final grid = File(
      'lib/features/planning/time_view/time_view_hour_grid.dart',
    ).readAsStringSync();
    expect(grid, isNot(contains('maybeNormalizeTimeViewOverlapsOnce(')));
  });

'''
if insert_before not in text:
    raise SystemExit('test insertion anchor not found')
if 'creation and Time View rendering never invoke hidden neighbor cascade' not in text:
    text = text.replace(insert_before, contract + insert_before, 1)
test.write_text(text, encoding='utf-8')

rec_test = Path('test/time_view_recurring_interaction_controller_test.dart')
text = rec_test.read_text(encoding='utf-8')
if "import 'dart:io';" not in text:
    text = "import 'dart:io';\n\n" + text
marker = "  test('entire series scope keeps the original recurrence identity', () {"
contract = r'''  test('recurring drag commit resolves insertion before recurrence persistence', () {
    final source = File(
      'lib/features/planning/time_view/time_view_card_layer.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Future<void> _commitRecurringTimelineVerticalDrag({',
    );
    final end = source.indexOf(
      'void commitTimelineResizeWithOptionalRecurrenceScope',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    expect(block, contains('scheduledInRange'));
    expect(block, contains('timelineStoredInsertionIntent'));
    expect(block, contains('computeTimeViewInsertionCascade('));
    expect(block, contains('cascadeResult.draggedStartWall'));
  });

'''
if marker not in text:
    raise SystemExit('recurring test marker not found')
if 'recurring drag commit resolves insertion before recurrence persistence' not in text:
    text = text.replace(marker, contract + marker, 1)
rec_test.write_text(text, encoding='utf-8')

# Changelog only; no new source/test files, so structure inventory remains stable.
changelog = Path('CHANGELOG.md')
c = changelog.read_text(encoding='utf-8')
entry = """## 2026-09-29 — Planner no-hidden-cascade recovery [fix]\n\n- New plans use an existing fitting gap or append after the last plan; creation never shifts existing plans to make room.\n- Time View rendering no longer performs hidden post-frame schedule mutations.\n- Recurring Time View drag/drop now resolves target insertion before applying occurrence/future recurrence scope.\n\n"""
if not c.startswith('## 2026-09-29 — Planner no-hidden-cascade recovery [fix]'):
    changelog.write_text(entry + c, encoding='utf-8')

for path in [
    Path('.github/scripts/patch_planner_no_hidden_cascade_v6.py'),
    Path('.github/workflows/run-planner-no-hidden-cascade-v6.yml'),
]:
    if path.exists():
        path.unlink()
