from pathlib import Path

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
const String _keyPlanAutoPlacementExplicitChoice =
    'plan_auto_placement_explicit_choice_v1';
PlanAutoPlacementMode _planAutoPlacementMode = PlanAutoPlacementMode.afterLastPlan;
"""
if old not in text:
    raise SystemExit('plan placement constants anchor not found')
text = text.replace(old, new, 1)

start = text.index('  Future<void> loadPlanAutoPlacementMode() async {')
end = text.index('\n  Future<void> setPlanAutoPlacementMode(', start)
replacement = """  Future<void> loadPlanAutoPlacementMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlanAutoPlacementMode);
    final explicitChoice =
        prefs.getBool(_keyPlanAutoPlacementExplicitChoice) ?? false;

    // Ordinary plan creation is append-only in Time View. Historical builds
    // persisted nearestFreeSlot as an implicit default, so any value that was
    // not explicitly chosen by the user is repaired to afterLastPlan on every
    // load. nearestFreeSlot remains available only as an explicit preference.
    if (!explicitChoice) {
      _planAutoPlacementMode = PlanAutoPlacementMode.afterLastPlan;
      await prefs.setString(
        _keyPlanAutoPlacementMode,
        PlanAutoPlacementMode.afterLastPlan.name,
      );
      return;
    }

    _planAutoPlacementMode = PlanAutoPlacementMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PlanAutoPlacementMode.afterLastPlan,
    );
  }
"""
text = text[:start] + replacement + text[end:]
helper.write_text(text, encoding='utf-8')

card = Path('lib/features/planning/time_view/time_view_card_layer.dart')
text = card.read_text(encoding='utf-8')
import_anchor = "import 'package:counter/features/planning/time_view/time_view_drag_controller.dart';\n"
if import_anchor not in text:
    raise SystemExit('time view card import anchor not found')
if 'time_view_drop_preview.dart' not in text:
    text = text.replace(
        import_anchor,
        import_anchor + "import 'package:counter/features/planning/time_view/time_view_drop_preview.dart';\n",
        1,
    )

start = text.index('  Future<void> _commitRecurringTimelineVerticalDrag({')
end = text.index('\n  void commitTimelineResizeWithOptionalRecurrenceScope', start)
recurring_drag = r'''  Future<void> _commitRecurringTimelineVerticalDrag({
    required PlanningTask task,
    required DateTime planWallDay,
    required int rangeStart,
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
    final selectedDayKey = host.pageWidget.selectedDateString.length >= 10
        ? host.pageWidget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();

    // Recurring drags must use the same target-card insertion/cascade resolver
    // as ordinary drags. The old path persisted the raw overlapped clock time;
    // the post-frame overlap normalizer then moved the occurrence back, which
    // made an accepted recurrence edit appear to do nothing.
    var insertionIntent = timelineStoredInsertionIntent;
    var commitSource = 'emptyCanvas';
    if (insertionIntent != null) {
      commitSource = 'targetCard';
      insertionIntent = refreshTimeViewInsertionIntentFromScheduled(
        intent: insertionIntent,
        scheduled: scheduledInRange,
        resolveDurationMinutes:
            DatabaseService.instance.resolvePlanDurationMinutesFromTags,
      );
      final cancelReason = validateTimeViewTargetInsertionIntent(
        intent: insertionIntent,
        scheduled: scheduledInRange,
        expectedDayKey: selectedDayKey,
      );
      if (cancelReason != null) {
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
    // Never silently rewrite another recurrence series as collateral cascade.
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

    final newStartWall = cascadeResult.draggedStartWall!;
    final newEndWall = cascadeResult.draggedEndWall;
    host.notifySetState(clearTimelineInteractionState);
    await _chooseAndPersistRecurringSchedule(
      task: task,
      newStartWall: newStartWall,
      newEndWall: newEndWall,
      cascadeResolved: cascadeResult.previewRows,
      scheduledBefore: scheduledInRange,
      commitSource: commitSource,
    );
  }
'''
text = text[:start] + recurring_drag + text[end:]

start = text.index('  Future<void> _chooseAndPersistRecurringSchedule({')
end = text.rfind('\n}')
if end <= start:
    raise SystemExit('recurring persistence method end not found')
choose = r'''  Future<void> _chooseAndPersistRecurringSchedule({
    required PlanningTask task,
    required DateTime newStartWall,
    required DateTime? newEndWall,
    List<PlanningTask>? cascadeResolved,
    List<PlanningTask>? scheduledBefore,
    String? commitSource,
  }) async {
    if (!host.mounted) return;
    final scope = await showRecurrenceScopeDialog(
      host.context,
      task: task,
      isDelete: false,
    );
    if (scope == null || !host.mounted) return;

    final instanceDay =
        task.recurrenceInstanceDateKey?.trim().isNotEmpty == true
        ? task.recurrenceInstanceDateKey!.trim().substring(0, 10)
        : DatabaseService.instance.planningWallScheduleDateKey(task);
    final mutationRowId = timeViewRecurringMutationRowId(
      task: task,
      scope: scope,
      instanceDateKey: instanceDay,
    );
    final businessId = task.planRowId?.trim() ?? '';
    final updated = task.copyWith(
      startTime: newStartWall,
      endDateTime: newEndWall,
      clearEnd: newEndWall == null,
    );

    DatabaseService.instance.applyOptimisticPlanningTask(updated);
    DatabaseService.instance.notifyPlanningRefresh(
      scheduleNetworkRefresh: false,
    );
    if (host.mounted) host.notifySetState(() {});

    final ok = await DatabaseService.instance
        .updatePlanningTaskWithRecurrenceScope(
          mutationRowId,
          scope: scope,
          planBusinessId: businessId.isEmpty || businessId.startsWith('virt-')
              ? null
              : businessId,
          startTimeDisplay: newStartWall,
          endDateTimeDisplay: newEndWall,
          clearEnd: newEndWall == null,
          suppressAppSnack: true,
          recurrenceInstanceDateKey: instanceDay,
        );

    DatabaseService.instance.clearOptimisticPlanningForPlanRow(
      task.planRowIdForBackend,
    );
    if (!ok) {
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
        commitSource: '${commitSource ?? 'recurring'}:neighbors',
      );
    }
    DatabaseService.instance.notifyPlanningRefresh();
    if (host.mounted) host.notifySetState(() {});
  }
'''
text = text[:start] + choose + text[end:]
card.write_text(text, encoding='utf-8')

test = Path('test/auto_plan_nearest_free_slot_test.dart')
text = test.read_text(encoding='utf-8')
old = """  test(
    'defaults to nearest fitting free slot when no placement preference exists',
    () async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseService.instance.loadPlanAutoPlacementMode();

      expect(
        DatabaseService.instance.planAutoPlacementMode,
        PlanAutoPlacementMode.nearestFreeSlot,
      );

      final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
        wallDay: DateTime(2026, 7, 24),
        categoryId: 1,
        tags: const [],
        existingDayPlans: [
          _plan('a', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10)),
          _plan('b', DateTime(2026, 7, 24, 14), DateTime(2026, 7, 24, 15)),
        ],
        timelineDayStartHour: 8,
        currentWall: DateTime(2026, 7, 24, 10, 5),
      );

      expect(schedule.startWall, DateTime(2026, 7, 24, 8));
      expect(schedule.endWall, DateTime(2026, 7, 24, 8, 30));
    },
  );
"""
new = """  test(
    'ordinary creation defaults to after the final scheduled plan',
    () async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseService.instance.loadPlanAutoPlacementMode();

      expect(
        DatabaseService.instance.planAutoPlacementMode,
        PlanAutoPlacementMode.afterLastPlan,
      );

      final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
        wallDay: DateTime(2026, 7, 24),
        categoryId: 1,
        tags: const [],
        existingDayPlans: [
          _plan('a', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10)),
          _plan('b', DateTime(2026, 7, 24, 11), DateTime(2026, 7, 24, 12)),
          _plan('c', DateTime(2026, 7, 24, 15), DateTime(2026, 7, 24, 16)),
        ],
        timelineDayStartHour: 8,
        currentWall: DateTime(2026, 7, 24, 10, 5),
      );

      expect(schedule.startWall, DateTime(2026, 7, 24, 16));
      expect(schedule.endWall, DateTime(2026, 7, 24, 16, 30));
    },
  );
"""
if old not in text:
    raise SystemExit('default placement test anchor not found')
text = text.replace(old, new, 1)

old = """  test('migrates stale persisted after-last default exactly once', () async {
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
new = """  test('repairs stale implicit gap-fill preference to append-only', () async {
    SharedPreferences.setMockInitialValues({
      'plan_auto_placement_mode': 'nearestFreeSlot',
    });

    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.afterLastPlan,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('plan_auto_placement_mode'),
      PlanAutoPlacementMode.afterLastPlan.name,
    );

    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.nearestFreeSlot,
    );
    await DatabaseService.instance.loadPlanAutoPlacementMode();
    expect(
      DatabaseService.instance.planAutoPlacementMode,
      PlanAutoPlacementMode.nearestFreeSlot,
    );
  });
"""
if old not in text:
    raise SystemExit('placement migration test anchor not found')
test.write_text(text.replace(old, new, 1), encoding='utf-8')

recurring_test = Path('test/time_view_recurring_interaction_controller_test.dart')
text = recurring_test.read_text(encoding='utf-8')
if "import 'dart:io';" not in text:
    text = "import 'dart:io';\n\n" + text
marker = "  test('entire series scope keeps the original recurrence identity', () {"
if marker not in text:
    raise SystemExit('recurring controller test marker not found')
contract = r'''  test('recurring target drop resolves insertion cascade before persistence', () {
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

    expect(block, contains('timelineStoredInsertionIntent'));
    expect(block, contains('computeTimeViewInsertionCascade('));
    expect(block, contains('cascadeResult.draggedStartWall'));
    expect(block, contains('cascadeResolved: cascadeResult.previewRows'));
  });

'''
if 'recurring target drop resolves insertion cascade before persistence' not in text:
    text = text.replace(marker, contract + marker, 1)
recurring_test.write_text(text, encoding='utf-8')

for path in [
    Path('.github/workflows/one-shot-fix-planning-append-recurring-v5.yml'),
    Path('.github/workflows/run-planning-append-recurring-v5.yml'),
    Path('.github/scripts/patch_planning_append_recurring_v5.py'),
]:
    if path.exists():
        path.unlink()
