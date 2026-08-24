import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask _task(String id, int hour, int minute, {int duration = 30}) {
  final start = DateTime(2026, 8, 24, hour, minute);
  return PlanningTask(
    id: id.hashCode,
    title: id,
    categoryId: 1,
    isDone: false,
    dateKey: '2026-08-24',
    order: 0,
    startTime: start,
    endDateTime: start.add(Duration(minutes: duration)),
    planRowId: id,
  );
}

void main() {
  test('bulk target-after keeps offsets when primary is later selected card', () {
    final early = _task('early', 9, 0);
    final primary = _task('primary', 10, 0);
    final target = _task('target', 11, 0);

    final intent = TimeViewInsertionIntent(
      draggedPlanId: primary.planRowIdForBackend,
      targetPlanId: target.planRowIdForBackend,
      insertPosition: TimeViewInsertPosition.after,
      targetStartWall: target.startTime!,
      targetEndWall: target.endDateTime!,
      draggedDurationMinutes: 30,
      draggedHadEnd: true,
    );

    final result = computeTimeViewInsertionCascade(
      scheduledTasks: [early, primary, target],
      draggedPlanIds: {
        early.planRowIdForBackend,
        primary.planRowIdForBackend,
      },
      primaryDraggedPlanId: primary.planRowIdForBackend,
      fixedPlanIds: const {},
      resolveDurationMinutes: (_) => 30,
      targetIntent: intent,
      bulkRelativeOffsetMinutes: {
        early.planRowIdForBackend: -60,
        primary.planRowIdForBackend: 0,
      },
    );

    expect(result.accepted, isTrue, reason: result.blockedReason);
    final byId = {
      for (final row in result.previewRows) row.planRowIdForBackend: row,
    };
    expect(byId[early.planRowIdForBackend]!.startTime,
        DateTime(2026, 8, 24, 11, 30));
    expect(byId[primary.planRowIdForBackend]!.startTime,
        DateTime(2026, 8, 24, 12, 30));
    expect(
      byId[primary.planRowIdForBackend]!.startTime!
          .difference(byId[early.planRowIdForBackend]!.startTime!)
          .inMinutes,
      60,
    );
  });

  test('bulk target-before keeps full selected group before target', () {
    final primary = _task('primary', 9, 0);
    final later = _task('later', 10, 0);
    final target = _task('target', 12, 0);

    final intent = TimeViewInsertionIntent(
      draggedPlanId: primary.planRowIdForBackend,
      targetPlanId: target.planRowIdForBackend,
      insertPosition: TimeViewInsertPosition.before,
      targetStartWall: target.startTime!,
      targetEndWall: target.endDateTime!,
      draggedDurationMinutes: 30,
      draggedHadEnd: true,
    );

    final result = computeTimeViewInsertionCascade(
      scheduledTasks: [primary, later, target],
      draggedPlanIds: {
        primary.planRowIdForBackend,
        later.planRowIdForBackend,
      },
      primaryDraggedPlanId: primary.planRowIdForBackend,
      fixedPlanIds: const {},
      resolveDurationMinutes: (_) => 30,
      targetIntent: intent,
      bulkRelativeOffsetMinutes: {
        primary.planRowIdForBackend: 0,
        later.planRowIdForBackend: 60,
      },
    );

    expect(result.accepted, isTrue, reason: result.blockedReason);
    final byId = {
      for (final row in result.previewRows) row.planRowIdForBackend: row,
    };
    expect(byId[primary.planRowIdForBackend]!.startTime,
        DateTime(2026, 8, 24, 10, 30));
    expect(byId[later.planRowIdForBackend]!.startTime,
        DateTime(2026, 8, 24, 11, 30));
    expect(byId[later.planRowIdForBackend]!.endDateTime,
        DateTime(2026, 8, 24, 12, 0));
  });

  test('bulk empty-canvas move preserves relative offsets', () {
    final early = _task('early', 9, 0);
    final primary = _task('primary', 10, 0);

    final result = computeTimeViewInsertionCascade(
      scheduledTasks: [early, primary],
      draggedPlanIds: {
        early.planRowIdForBackend,
        primary.planRowIdForBackend,
      },
      primaryDraggedPlanId: primary.planRowIdForBackend,
      fixedPlanIds: const {},
      resolveDurationMinutes: (_) => 30,
      emptyCanvasStartWall: DateTime(2026, 8, 24, 14, 0),
      emptyCanvasHadEnd: true,
      bulkRelativeOffsetMinutes: {
        early.planRowIdForBackend: -60,
        primary.planRowIdForBackend: 0,
      },
    );

    expect(result.accepted, isTrue, reason: result.blockedReason);
    final byId = {
      for (final row in result.previewRows) row.planRowIdForBackend: row,
    };
    expect(byId[early.planRowIdForBackend]!.startTime,
        DateTime(2026, 8, 24, 13, 0));
    expect(byId[primary.planRowIdForBackend]!.startTime,
        DateTime(2026, 8, 24, 14, 0));
  });
}
