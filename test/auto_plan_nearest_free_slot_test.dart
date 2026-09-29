import 'dart:io';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlanningTask _plan(String id, DateTime start, DateTime end) => PlanningTask(
  id: 0,
  planRowId: id,
  title: id,
  categoryId: 1,
  isDone: false,
  dateKey: '2026-07-24',
  order: 0,
  startTime: start,
  endDateTime: end,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.nearestFreeSlot,
    );
  });

  test(
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

  test('uses the earliest free gap even when current time is later', () {
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10)),
        _plan('b', DateTime(2026, 7, 24, 11), DateTime(2026, 7, 24, 12)),
      ],
      timelineDayStartHour: 8,
      currentWall: DateTime(2026, 7, 24, 10, 5),
    );
    expect(schedule.startWall, DateTime(2026, 7, 24, 8));
    expect(schedule.endWall, DateTime(2026, 7, 24, 8, 30));
  });

  test('skips a gap that is too short', () {
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('early', DateTime(2026, 7, 24, 8), DateTime(2026, 7, 24, 10, 45)),
        _plan('a', DateTime(2026, 7, 24, 11), DateTime(2026, 7, 24, 12)),
      ],
      timelineDayStartHour: 8,
      currentWall: DateTime(2026, 7, 24, 10, 45),
    );
    expect(schedule.startWall, DateTime(2026, 7, 24, 12));
    expect(schedule.endWall, DateTime(2026, 7, 24, 12, 30));
  });

  test('collision bump rounds forward and never back into occupied time', () {
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10, 2)),
      ],
      explicitStartWall: DateTime(2026, 7, 24, 10),
      explicitDurationMinutes: 30,
      timelineDayStartHour: 8,
    );

    expect(schedule.startWall, DateTime(2026, 7, 24, 10, 5));
    expect(schedule.endWall, DateTime(2026, 7, 24, 10, 35));
  });

  test(
    'recovers stale placement state once, then respects explicit choice',
    () async {
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
    },
  );

  test('after-last mode preserves the previous rule', () async {
    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.afterLastPlan,
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
    expect(schedule.startWall, DateTime(2026, 7, 24, 15));
    expect(schedule.endWall, DateTime(2026, 7, 24, 15, 30));
  });

  test('after-last mode still honors explicit user time', () async {
    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.afterLastPlan,
    );
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10)),
        _plan('b', DateTime(2026, 7, 24, 14), DateTime(2026, 7, 24, 15)),
      ],
      explicitStartWall: DateTime(2026, 7, 24, 10, 15),
      explicitDurationMinutes: 30,
      timelineDayStartHour: 8,
    );
    expect(schedule.startWall, DateTime(2026, 7, 24, 10, 15));
    expect(schedule.endWall, DateTime(2026, 7, 24, 10, 45));
  });

  test('after-last placement is resolved before category default lookup', () {
    final source = File(
      'lib/data/plans/plan_time_cascade_helpers.dart',
    ).readAsStringSync();
    final afterLastBranch = source.indexOf(
      '} else if (_planAutoPlacementMode == PlanAutoPlacementMode.afterLastPlan) {',
    );
    final categoryDefaultLookup = source.indexOf(
      'final catSchedule = effectiveDefaultPlanScheduleForCategory(categoryId);',
    );

    expect(afterLastBranch, greaterThanOrEqualTo(0));
    expect(categoryDefaultLookup, greaterThan(afterLastBranch));
  });

  test('explicit plan stays in a gap when its full duration fits', () {
    final first = _plan(
      'a',
      DateTime(2026, 7, 24, 9),
      DateTime(2026, 7, 24, 10),
    );
    final second = _plan(
      'b',
      DateTime(2026, 7, 24, 10, 20),
      DateTime(2026, 7, 24, 11),
    );

    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [first, second],
      explicitStartWall: DateTime(2026, 7, 24, 10),
      explicitEndWall: DateTime(2026, 7, 24, 10, 20),
      hasExplicitTimeRange: true,
    );

    expect(schedule.startWall, DateTime(2026, 7, 24, 10));
    expect(schedule.endWall, DateTime(2026, 7, 24, 10, 20));
  });

  test('explicit plan skips a too-small gap without squeezing plans', () {
    final first = _plan(
      'a',
      DateTime(2026, 7, 24, 9),
      DateTime(2026, 7, 24, 10),
    );
    final second = _plan(
      'b',
      DateTime(2026, 7, 24, 10, 20),
      DateTime(2026, 7, 24, 11),
    );
    final secondStartBefore = second.startTime;
    final secondEndBefore = second.endDateTime;

    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [first, second],
      explicitStartWall: DateTime(2026, 7, 24, 10),
      explicitEndWall: DateTime(2026, 7, 24, 10, 30),
      hasExplicitTimeRange: true,
    );

    expect(schedule.startWall, DateTime(2026, 7, 24, 11));
    expect(schedule.endWall, DateTime(2026, 7, 24, 11, 30));
    expect(second.startTime, secondStartBefore);
    expect(second.endDateTime, secondEndBefore);
  });

  test('ignores polluted scheduled plans owned by another day', () {
    final foreign = PlanningTask(
      id: 0,
      planRowId: 'foreign',
      title: 'foreign',
      categoryId: 1,
      isDone: false,
      dateKey: '2026-07-25',
      order: 0,
      startTime: DateTime(2026, 7, 24, 8),
      endDateTime: DateTime(2026, 7, 24, 22),
    );

    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [foreign],
      timelineDayStartHour: 8,
    );

    expect(schedule.startWall, DateTime(2026, 7, 24, 8));
    expect(schedule.endWall, DateTime(2026, 7, 24, 8, 30));
  });

  test('no fitting earlier gap appends after the final plan', () {
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

  test(
    'creation and Time View rendering never invoke hidden neighbor cascade',
    () {
      final service = File('lib/data/plan_service.dart').readAsStringSync();
      final createStart = service.indexOf(
        'Future<bool> _addPlanningTaskPocket(',
      );
      final createEnd = service.indexOf(
        'Future<bool> addPlanningTask(',
        createStart,
      );
      expect(createStart, greaterThanOrEqualTo(0));
      expect(createEnd, greaterThan(createStart));
      final createBlock = service.substring(createStart, createEnd);
      expect(createBlock, contains('resolvePlanningCreateCollision('));
      expect(
        createBlock,
        isNot(contains('applySequentialTimeViewCascadeIfNeeded(')),
      );

      final grid = File(
        'lib/features/planning/time_view/time_view_hour_grid.dart',
      ).readAsStringSync();
      expect(grid, isNot(contains('maybeNormalizeTimeViewOverlapsOnce(')));
    },
  );

  test('target-card drop after is exactly adjacent in scheduled time', () {
    final targetEnd = DateTime(2026, 7, 24, 10, 30);
    final result = computeTimeViewTargetDropSchedule(
      targetStartWall: DateTime(2026, 7, 24, 10),
      targetEndWall: targetEnd,
      draggedDurationMinutes: 45,
      insertBefore: false,
      draggedHadEnd: true,
    );

    expect(result.startWall, targetEnd);
    expect(result.endWall, DateTime(2026, 7, 24, 11, 15));
  });

  test('copyWith can invalidate stale UTC when wall schedule changes', () {
    final task = PlanningTask(
      id: 0,
      planRowId: 'plan-utc-move',
      title: 'Plan',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 10, 30),
      startUtcInstant: DateTime.utc(2026, 9, 29, 14),
      endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
    );

    final moved = task.copyWith(
      startTime: DateTime(2026, 9, 29, 12),
      endDateTime: DateTime(2026, 9, 29, 12, 30),
      clearStartUtc: true,
      clearEndUtc: true,
    );

    expect(moved.startTime, DateTime(2026, 9, 29, 12));
    expect(moved.startUtcInstant, isNull);
    expect(moved.endUtcInstant, isNull);
  });

  test(
    'collision-resolved create does not retain pre-collision UTC instant',
    () {
      final incoming = PlanningTask(
        id: 0,
        planRowId: 'incoming-utc',
        title: 'Incoming',
        categoryId: 1,
        dateKey: '2026-09-29',
        startTime: DateTime(2026, 9, 29, 10),
        endDateTime: DateTime(2026, 9, 29, 10, 30),
        startUtcInstant: DateTime.utc(2026, 9, 29, 14),
        endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
      );
      final occupied = PlanningTask(
        id: 0,
        planRowId: 'occupied-utc',
        title: 'Occupied',
        categoryId: 1,
        dateKey: '2026-09-29',
        startTime: DateTime(2026, 9, 29, 10),
        endDateTime: DateTime(2026, 9, 29, 11),
      );

      final resolved = DatabaseService.instance
          .resolvePlanningCreateCollision(
            task: incoming,
            wallDay: DateTime(2026, 9, 29),
            existingDayPlans: [occupied],
          )
          .task;

      expect(resolved.startTime, DateTime(2026, 9, 29, 11));
      expect(resolved.startUtcInstant, isNull);
      expect(resolved.endUtcInstant, isNull);
    },
  );
}
