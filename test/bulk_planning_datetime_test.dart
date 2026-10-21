import 'package:counter/data/models.dart';
import 'package:counter/features/planning/bulk_planning_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask _task(
  int id, {
  int day = 21,
  int hour = 2,
  int minute = 50,
  int durationMinutes = 45,
}) {
  final start = DateTime(2026, 10, day, hour, minute);
  return PlanningTask(
    id: id,
    title: 'Task $id',
    categoryId: 1,
    dateKey: '2026-10-${day.toString().padLeft(2, '0')}',
    startTime: start,
    endDateTime: start.add(Duration(minutes: durationMinutes)),
  );
}

void main() {
  test('same-day 20:00 is a real change and schedules tasks consecutively', () {
    final tasks = [
      _task(1, durationMinutes: 45),
      _task(2, hour: 0, minute: 0, durationMinutes: 10),
      _task(3, hour: 0, minute: 10, durationMinutes: 50),
    ];
    final edit = BulkPlanningEditResult(
      targetDate: DateTime(2026, 10, 21),
      applyTargetTime: true,
      targetTime: const TimeOfDay(hour: 20, minute: 0),
    );
    final placed = computeSequentialBulkEditWallTimes(
      tasks, edit, durationMinutesForTask: (_) => 30,
    );

    expect(placed.map((p) => p.start).toList(), [
      DateTime(2026, 10, 21, 20),
      DateTime(2026, 10, 21, 20, 45),
      DateTime(2026, 10, 21, 20, 55),
    ]);
    expect(placed.last.end, DateTime(2026, 10, 21, 21, 45));
    expect(bulkPlacementMatchesTask(tasks.first, placed.first), isFalse);
  });

  test('no changes only when day, start AND end really match', () {
    final existing = _task(1, hour: 20, minute: 0);
    final sameWall = BulkEditWallTimes(
      // Simulate a different timezone representation with the same wall fields.
      start: DateTime.utc(2026, 10, 21, 20),
      end: DateTime.utc(2026, 10, 21, 20, 45),
    );
    expect(bulkPlacementMatchesTask(existing, sameWall), isTrue);
    expect(
      bulkPlacementMatchesTask(
        existing,
        BulkEditWallTimes(
          start: DateTime(2026, 10, 21, 21),
          end: DateTime(2026, 10, 21, 21, 45),
        ),
      ),
      isFalse,
    );
    expect(
      bulkPlacementMatchesTask(
        existing,
        BulkEditWallTimes(
          start: DateTime(2026, 10, 22, 20),
          end: DateTime(2026, 10, 22, 20, 45),
        ),
      ),
      isFalse,
    );
  });

  test('explicit date-only move keeps each task clock and duration', () {
    final tasks = [
      _task(1, hour: 2, minute: 50, durationMinutes: 45),
      _task(2, hour: 10, minute: 10, durationMinutes: 30),
    ];
    final placed = computeSequentialBulkEditWallTimes(
      tasks,
      BulkPlanningEditResult(targetDate: DateTime(2026, 10, 22)),
      durationMinutesForTask: (_) => 60,
    );
    expect(placed.first.start, DateTime(2026, 10, 22, 2, 50));
    expect(placed.first.end, DateTime(2026, 10, 22, 3, 35));
    expect(placed.last.start, DateTime(2026, 10, 22, 10, 10));
    expect(placed.last.end, DateTime(2026, 10, 22, 10, 40));
  });

  test('sequence has no gaps and preserves fallback durations at midnight', () {
    final tasks = [
      _task(1, hour: 12, minute: 0, durationMinutes: 60),
      PlanningTask(
        id: 2, title: 'Unscheduled', categoryId: 1,
        dateKey: '2026-10-21',
      ),
    ];
    final placed = computeSequentialBulkEditWallTimes(
      tasks,
      BulkPlanningEditResult(
        targetDate: DateTime(2026, 10, 21),
        applyTargetTime: true,
        targetTime: const TimeOfDay(hour: 23, minute: 0),
      ),
      durationMinutesForTask: (_) => 30,
    );
    expect(placed.first.start, DateTime(2026, 10, 21, 23));
    expect(placed.first.end, DateTime(2026, 10, 22, 0));
    expect(placed.last.start, placed.first.end);
    expect(placed.last.end, DateTime(2026, 10, 22, 0, 30));
  });

  test('only overlapping destination tasks are cascaded', () {
    final incumbent1 = _task(4, hour: 20, minute: 30, durationMinutes: 30);
    final incumbent2 = _task(5, hour: 22, minute: 0, durationMinutes: 30);
    final shifts = computeBulkDestinationConflictShifts(
      blockStart: DateTime(2026, 10, 21, 20),
      blockEnd: DateTime(2026, 10, 21, 21),
      existingDestinationPlans: [incumbent1, incumbent2],
      durationMinutesForTask: (_) => 30,
    );
    expect(shifts.length, 1);
    expect(shifts.single.task.id, 4);
    expect(shifts.single.times.start, DateTime(2026, 10, 21, 21));
    expect(shifts.single.times.end, DateTime(2026, 10, 21, 21, 30));
  });
}
