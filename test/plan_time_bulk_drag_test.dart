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
}
