import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:flutter_test/flutter_test.dart';

const _dayKey = '2026-07-24';

int _duration(List<Tag> tags) => 30;

PlanningTask _task(
  String id,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute, {
  int order = 0,
}) {
  return PlanningTask(
    id: id.hashCode,
    title: id,
    categoryId: 1,
    isDone: false,
    dateKey: _dayKey,
    order: order,
    startTime: DateTime(2026, 7, 24, startHour, startMinute),
    endDateTime: DateTime(2026, 7, 24, endHour, endMinute),
    planRowId: id,
    pocketRecordId: id,
  );
}

PlanningTask _byId(List<PlanningTask> tasks, String id) =>
    tasks.firstWhere((task) => task.planRowIdForBackend == id);

void main() {
  test('bulk empty-canvas move preserves every original relative time', () {
    final tasks = [
      _task('a', 9, 0, 9, 30),
      _task('b', 10, 15, 10, 45, order: 1),
      _task('c', 11, 45, 12, 15, order: 2),
    ];

    final result = computeTimeViewInsertionCascade(
      scheduledTasks: tasks,
      draggedPlanIds: {'a', 'b', 'c'},
      primaryDraggedPlanId: 'a',
      fixedPlanIds: const {},
      resolveDurationMinutes: _duration,
      emptyCanvasStartWall: DateTime(2026, 7, 24, 14),
      emptyCanvasHadEnd: true,
      bulkRelativeOffsetMinutes: const {'a': 0},
    );

    expect(result.accepted, isTrue);
    expect(_byId(result.previewRows, 'a').startTime, DateTime(2026, 7, 24, 14));
    expect(
      _byId(result.previewRows, 'b').startTime,
      DateTime(2026, 7, 24, 15, 15),
    );
    expect(
      _byId(result.previewRows, 'c').startTime,
      DateTime(2026, 7, 24, 16, 45),
    );
  });

  test('bulk target insertion never normalizes selected cards to one time', () {
    final target = _task('target', 8, 0, 8, 30);
    final a = _task('a', 10, 0, 10, 30, order: 1);
    final b = _task('b', 11, 15, 11, 45, order: 2);
    final result = computeTimeViewInsertionCascade(
      scheduledTasks: [target, a, b],
      draggedPlanIds: {'a', 'b'},
      primaryDraggedPlanId: 'a',
      fixedPlanIds: const {},
      resolveDurationMinutes: _duration,
      targetIntent: TimeViewInsertionIntent(
        draggedPlanId: 'a',
        targetPlanId: 'target',
        insertPosition: TimeViewInsertPosition.after,
        targetStartWall: target.startTime!,
        targetEndWall: target.endDateTime!,
        draggedDurationMinutes: 30,
        draggedHadEnd: true,
      ),
      bulkRelativeOffsetMinutes: const {'a': 0, 'b': 0},
    );

    expect(result.accepted, isTrue);
    expect(
      _byId(result.previewRows, 'a').startTime,
      DateTime(2026, 7, 24, 8, 30),
    );
    expect(
      _byId(result.previewRows, 'b').startTime,
      DateTime(2026, 7, 24, 9, 45),
    );
  });

  test('manual resize pushes only the connected overlap chain', () {
    final resized = _task('a', 9, 0, 11, 0);
    final before = [
      _task('a', 9, 0, 10, 0),
      _task('b', 10, 15, 10, 45, order: 1),
      _task('c', 10, 40, 11, 10, order: 2),
      _task('d', 13, 0, 13, 30, order: 3),
      _task('e', 13, 15, 13, 45, order: 4),
    ];

    final result = cascadeScheduledPlansAfterManualResize(
      scheduledTasks: before,
      resizedTask: resized,
      resolveDurationMinutes: _duration,
    );

    expect(_byId(result, 'a').endDateTime, DateTime(2026, 7, 24, 11));
    expect(_byId(result, 'b').startTime, DateTime(2026, 7, 24, 11));
    expect(_byId(result, 'b').endDateTime, DateTime(2026, 7, 24, 11, 30));
    expect(_byId(result, 'c').startTime, DateTime(2026, 7, 24, 11, 30));
    expect(_byId(result, 'c').endDateTime, DateTime(2026, 7, 24, 12));
    expect(_byId(result, 'd').startTime, DateTime(2026, 7, 24, 13));
    expect(_byId(result, 'e').startTime, DateTime(2026, 7, 24, 13, 15));
  });
}
