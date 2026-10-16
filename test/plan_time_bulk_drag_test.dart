import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/bulk_planning_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask _task(String id, int hour, int minute, int durMin) {
  final start = DateTime(2026, 6, 15, hour, minute);
  return PlanningTask(
    id: id.hashCode,
    title: id,
    dateKey: '2026-06-15',
    startTime: start,
    endDateTime: start.add(Duration(minutes: durMin)),
    order: 0,
    isDone: false,
    categoryId: 1,
    planRowId: id,
    pocketRecordId: id.padRight(15, '0').substring(0, 15),
  );
}

TimeViewInsertionIntent _insertAfter(
  PlanningTask primary,
  PlanningTask target,
) {
  return TimeViewInsertionIntent(
    draggedPlanId: primary.planRowIdForBackend,
    targetPlanId: target.planRowIdForBackend,
    insertPosition: TimeViewInsertPosition.after,
    targetStartWall: target.startTime!,
    targetEndWall: target.endDateTime!,
    draggedDurationMinutes: 30,
    draggedHadEnd: true,
    source: TimeViewInsertionSource.targetCard,
  );
}

TimeViewInsertionIntent _insertBefore(
  PlanningTask primary,
  PlanningTask target,
) {
  return TimeViewInsertionIntent(
    draggedPlanId: primary.planRowIdForBackend,
    targetPlanId: target.planRowIdForBackend,
    insertPosition: TimeViewInsertPosition.before,
    targetStartWall: target.startTime!,
    targetEndWall: target.endDateTime!,
    draggedDurationMinutes: 30,
    draggedHadEnd: true,
    source: TimeViewInsertionSource.targetCard,
  );
}

void main() {
  group('bulk edit date + time: contiguous ordered block', () {
    final thursday = DateTime(2026, 10, 15);
    final monday = DateTime(2026, 10, 19);
    const startAtNine = TimeOfDay(hour: 9, minute: 0);
    final edit = BulkPlanningEditResult(
      targetDate: monday,
      applyTargetTime: true,
      targetTime: startAtNine,
    );

    PlanningTask plan(String id, int hour, int minute, int duration) {
      final start = DateTime(
        thursday.year, thursday.month, thursday.day, hour, minute,
      );
      return _task(id, hour, minute, duration).copyWith(
        startTime: start,
        endDateTime: start.add(Duration(minutes: duration)),
        dateKey: '2026-10-15',
      );
    }

    test('Monday 09:00 anchors the GROUP; no overlaps or arbitrary gaps', () {
      final a = plan('first', 9, 0, 45);
      final b = plan('second', 11, 0, 30);
      final c = plan('third', 15, 30, 10);
      final result = computeSequentialBulkEditWallTimes(
        [a, b, c], edit, durationMinutesForTask: (_) => 30,
      );
      expect(result.map((r) => r.start).toList(), [
        DateTime(2026, 10, 19, 9),
        DateTime(2026, 10, 19, 9, 45),
        DateTime(2026, 10, 19, 10, 15),
      ]);
      expect(result.last.end, DateTime(2026, 10, 19, 10, 25));
      for (var i = 1; i < result.length; i++) {
        expect(result[i].start, result[i - 1].end);
      }
    });

    test('follows the visible selection order, not old clock times', () {
      final a = plan('first', 15, 0, 40);
      final b = plan('second', 9, 0, 20);
      final result = computeSequentialBulkEditWallTimes(
        [a, b], edit, durationMinutesForTask: (_) => 30,
      );
      expect(result.first.start, DateTime(2026, 10, 19, 9));
      expect(result[1].start, DateTime(2026, 10, 19, 9, 40));
    });

    test('a plan with no explicit end consumes its tag/default duration', () {
      final incomplete = plan('no-end', 9, 0, 30).copyWith(clearEnd: true);
      final following = plan('following', 9, 0, 10);
      final result = computeSequentialBulkEditWallTimes(
        [incomplete, following],
        edit,
        durationMinutesForTask: (_) => 25,
      );
      expect(result[0].end, DateTime(2026, 10, 19, 9, 25));
      expect(result[1].start, DateTime(2026, 10, 19, 9, 25));
    });

    test('date-only move retains distinct source clocks', () {
      final first = plan('a', 11, 15, 30);
      final second = plan('b', 16, 10, 45);
      final onlyDate = BulkPlanningEditResult(targetDate: monday);
      final result = computeSequentialBulkEditWallTimes(
        [first, second], onlyDate, durationMinutesForTask: (_) => 30,
      );
      expect(result[0].start, DateTime(2026, 10, 19, 11, 15));
      expect(result[1].start, DateTime(2026, 10, 19, 16, 10));
      expect(result[1].end, DateTime(2026, 10, 19, 16, 55));
    });

    test('Monday incumbents shift only when a new block conflicts', () {
      PlanningTask onMonday(String id, int h, int m, int minutes) {
        final p = _task(id, h, m, minutes);
        final start = DateTime(2026, 10, 19, h, m);
        return p.copyWith(
          startTime: start,
          endDateTime: start.add(Duration(minutes: minutes)),
          dateKey: '2026-10-19',
        );
      }
      final shifts = computeBulkDestinationConflictShifts(
        blockStart: DateTime(2026, 10, 19, 9),
        blockEnd: DateTime(2026, 10, 19, 10, 15),
        existingDestinationPlans: [
          onMonday('later', 13, 0, 30),
          onMonday('collision2', 9, 25, 35),
          onMonday('earlier', 7, 0, 30),
          onMonday('collision1', 8, 50, 25),
          onMonday('collision3', 11, 0, 30),
        ],
        durationMinutesForTask: (_) => 30,
      );
      expect(shifts.map((s) => s.task.title).toList(), [
        'collision1', 'collision2', 'collision3',
      ]);
      expect(shifts.map((s) => s.times.start).toList(), [
        DateTime(2026, 10, 19, 10, 15),
        DateTime(2026, 10, 19, 10, 40),
        DateTime(2026, 10, 19, 11, 15),
      ]);
      expect(shifts.last.times.end, DateTime(2026, 10, 19, 11, 45));
    });
  });

  group('bulk empty-canvas cascade', () {
    test('group move preserves relative offsets', () {
      final a = _task('a', 11, 0, 30);
      final b = _task('b', 11, 30, 30);
      final scheduled = [a, b];
      final draggedPlanIds = {
        a.planRowIdForBackend,
        b.planRowIdForBackend,
      };
      final result = computeTimeViewInsertionCascade(
        scheduledTasks: scheduled,
        draggedPlanIds: draggedPlanIds,
        primaryDraggedPlanId: a.planRowIdForBackend,
        fixedPlanIds: const {},
        resolveDurationMinutes: (_) => 30,
        emptyCanvasStartWall: DateTime(2026, 6, 15, 12, 0),
        emptyCanvasHadEnd: true,
        bulkRelativeOffsetMinutes: {
          a.planRowIdForBackend: 0,
          b.planRowIdForBackend: 30,
        },
      );
      expect(result.accepted, isTrue);
      final movedA = result.previewRows.firstWhere(
        (t) => t.planRowIdForBackend == a.planRowIdForBackend,
      );
      final movedB = result.previewRows.firstWhere(
        (t) => t.planRowIdForBackend == b.planRowIdForBackend,
      );
      expect(movedA.startTime, DateTime(2026, 6, 15, 12, 0));
      expect(movedB.startTime, DateTime(2026, 6, 15, 12, 30));
    });
  });

  group('bulk target-card cascade', () {
    test('insert group after target preserves offsets', () {
      final a = _task('a', 9, 0, 30);
      final b = _task('b', 9, 30, 30);
      final target = _task('target00000001', 11, 0, 30);
      final draggedPlanIds = {
        a.planRowIdForBackend,
        b.planRowIdForBackend,
      };
      final result = computeTimeViewInsertionCascade(
        scheduledTasks: [a, b, target],
        draggedPlanIds: draggedPlanIds,
        primaryDraggedPlanId: a.planRowIdForBackend,
        fixedPlanIds: const {},
        resolveDurationMinutes: (_) => 30,
        targetIntent: _insertAfter(a, target),
        bulkRelativeOffsetMinutes: {
          a.planRowIdForBackend: 0,
          b.planRowIdForBackend: 30,
        },
      );
      expect(result.accepted, isTrue);
      final movedA = result.previewRows.firstWhere(
        (t) => t.planRowIdForBackend == a.planRowIdForBackend,
      );
      final movedB = result.previewRows.firstWhere(
        (t) => t.planRowIdForBackend == b.planRowIdForBackend,
      );
      expect(movedA.startTime, DateTime(2026, 6, 15, 11, 30));
      expect(movedB.startTime, DateTime(2026, 6, 15, 12, 0));
      expect(
        scheduledPlansHaveWallOverlap(
          result.previewRows.where((t) => t.startTime != null).toList(),
          resolveDurationMinutes: (_) => 30,
        ),
        isFalse,
      );
    });

    test('insert group before target preserves offsets', () {
      final a = _task('a', 13, 0, 30);
      final b = _task('b', 13, 30, 30);
      final target = _task('target00000001', 11, 0, 30);
      final draggedPlanIds = {
        a.planRowIdForBackend,
        b.planRowIdForBackend,
      };
      final result = computeTimeViewInsertionCascade(
        scheduledTasks: [target, a, b],
        draggedPlanIds: draggedPlanIds,
        primaryDraggedPlanId: a.planRowIdForBackend,
        fixedPlanIds: const {},
        resolveDurationMinutes: (_) => 30,
        targetIntent: _insertBefore(a, target),
        bulkRelativeOffsetMinutes: {
          a.planRowIdForBackend: 0,
          b.planRowIdForBackend: 30,
        },
      );
      expect(result.accepted, isTrue);
      final movedA = result.previewRows.firstWhere(
        (t) => t.planRowIdForBackend == a.planRowIdForBackend,
      );
      final movedB = result.previewRows.firstWhere(
        (t) => t.planRowIdForBackend == b.planRowIdForBackend,
      );
      // Two 30-minute plans inserted BEFORE the 11:00 target must span
      // 10:00–11:00, not overlap the target at 11:00.
      expect(movedA.startTime, DateTime(2026, 6, 15, 10, 0));
      expect(movedB.startTime, DateTime(2026, 6, 15, 10, 30));
      expect(
        scheduledPlansHaveWallOverlap(
          result.previewRows.where((t) => t.startTime != null).toList(),
          resolveDurationMinutes: (_) => 30,
        ),
        isFalse,
      );
    });

    test('insert after target shifts lower touching flexible chain', () {
      final a = _task('a', 9, 0, 30);
      final b = _task('b', 9, 30, 30);
      final target = _task('target00000001', 11, 0, 30);
      final lower = _task('lower000000001', 11, 30, 30);
      final draggedPlanIds = {
        a.planRowIdForBackend,
        b.planRowIdForBackend,
      };
      final result = computeTimeViewInsertionCascade(
        scheduledTasks: [a, b, target, lower],
        draggedPlanIds: draggedPlanIds,
        primaryDraggedPlanId: a.planRowIdForBackend,
        fixedPlanIds: const {},
        resolveDurationMinutes: (_) => 30,
        targetIntent: _insertAfter(a, target),
        bulkRelativeOffsetMinutes: {
          a.planRowIdForBackend: 0,
          b.planRowIdForBackend: 30,
        },
      );
      expect(result.accepted, isTrue);
      final movedLower = result.previewRows.firstWhere(
        (t) => t.planRowIdForBackend == lower.planRowIdForBackend,
      );
      expect(movedLower.startTime, DateTime(2026, 6, 15, 12, 30));
      expect(result.shiftedPlanIds, contains(lower.planRowIdForBackend));
    });

    test('insert blocked by fixed unselected target neighbor', () {
      final a = _task('a', 9, 0, 30);
      final b = _task('b', 9, 30, 30);
      final target = _task('target00000001', 11, 0, 30);
      final meeting = PlanningTask(
        id: 'meet'.hashCode,
        title: 'meet',
        dateKey: '2026-06-15',
        startTime: DateTime(2026, 6, 15, 11, 30),
        endDateTime: DateTime(2026, 6, 15, 12, 0),
        order: 0,
        isDone: false,
        categoryId: 1,
        planRowId: 'meet',
        pocketRecordId: 'meet00000000001',
        tags: const [
          Tag(tagId: 1, name: 'Meeting', pbRecordId: 'fixed0000000001'),
        ],
      );
      final draggedPlanIds = {
        a.planRowIdForBackend,
        b.planRowIdForBackend,
      };
      final result = computeTimeViewInsertionCascade(
        scheduledTasks: [a, b, target, meeting],
        draggedPlanIds: draggedPlanIds,
        primaryDraggedPlanId: a.planRowIdForBackend,
        fixedPlanIds: {meeting.planRowIdForBackend},
        resolveDurationMinutes: (_) => 30,
        targetIntent: _insertAfter(a, target),
        bulkRelativeOffsetMinutes: {
          a.planRowIdForBackend: 0,
          b.planRowIdForBackend: 30,
        },
      );
      expect(result.accepted, isFalse);
      expect(result.blockedReason, 'fixedBarrier');
    });
  });
}
