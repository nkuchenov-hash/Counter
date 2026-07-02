import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
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
      expect(movedA.startTime, DateTime(2026, 6, 15, 10, 30));
      expect(movedB.startTime, DateTime(2026, 6, 15, 11, 0));
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
