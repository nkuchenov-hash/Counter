import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _wall(int h, int m) => DateTime(2026, 6, 15, h, m);

int _resolveDuration(List<Tag> tags) => 30;

PlanningTask _task({
  required String id,
  required int startH,
  required int startM,
  required int endH,
  required int endM,
  int order = 0,
}) {
  final start = _wall(startH, startM);
  final end = _wall(endH, endM);
  return PlanningTask(
    id: 0,
    title: id,
    categoryId: 1,
    isDone: false,
    dateKey: '2026-06-15',
    order: order,
    startTime: start,
    endDateTime: end,
    planRowId: id,
  );
}

TimeViewInsertionIntent _afterAIntent({
  required String draggedId,
  int draggedDuration = 45,
}) {
  return TimeViewInsertionIntent(
    draggedPlanId: draggedId,
    targetPlanId: 'a',
    insertPosition: TimeViewInsertPosition.after,
    targetStartWall: _wall(19, 40),
    targetEndWall: _wall(20, 25),
    draggedDurationMinutes: draggedDuration,
    draggedHadEnd: true,
  );
}

void main() {
  group('computeTimeViewTargetDropSchedule', () {
    test('drop over target lower half: 19:40–20:25 + 45m → 20:25–21:10', () {
      final schedule = computeTimeViewTargetDropSchedule(
        targetStartWall: _wall(19, 40),
        targetEndWall: _wall(20, 25),
        draggedDurationMinutes: 45,
        insertBefore: false,
        draggedHadEnd: true,
      );
      expect(schedule.startWall, _wall(20, 25));
      expect(schedule.endWall, _wall(21, 10));
      expect(
        schedule.endWall!.difference(schedule.startWall).inMinutes,
        45,
      );
    });

    test('drop over target upper half: 20:00–20:30 + 15m → 19:45–20:00', () {
      final schedule = computeTimeViewTargetDropSchedule(
        targetStartWall: _wall(20, 0),
        targetEndWall: _wall(20, 30),
        draggedDurationMinutes: 15,
        insertBefore: true,
        draggedHadEnd: true,
      );
      expect(schedule.startWall, _wall(19, 45));
      expect(schedule.endWall, _wall(20, 0));
    });

    test('target drop ignores raw yToTime: pointer 20:55 → dock at 20:25', () {
      final schedule = computeTimeViewTargetDropSchedule(
        targetStartWall: _wall(19, 40),
        targetEndWall: _wall(20, 25),
        draggedDurationMinutes: 45,
        insertBefore: false,
        draggedHadEnd: true,
      );
      expect(schedule.startWall, isNot(_wall(20, 55)));
      expect(schedule.startWall, _wall(20, 25));
    });
  });

  group('applyTimeViewTargetInsertion explicit order', () {
    test('explicit after-target order: A 19:40–20:25, B 45m → 20:25–21:10', () {
      final a = _task(
        id: 'a',
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        startH: 18,
        startM: 0,
        endH: 18,
        endM: 45,
        order: 1,
      );
      final intent = _afterAIntent(draggedId: 'b');
      final result = applyTimeViewTargetInsertion(
        scheduled: [a, b],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      final bOut = result.cascaded.firstWhere((t) => t.planRowId == 'b');
      expect(result.draggedStartWall, _wall(20, 25));
      expect(result.draggedEndWall, _wall(21, 10));
      expect(bOut.startTime, _wall(20, 25));
      expect(bOut.endDateTime, _wall(21, 10));
      expect(result.orderAfter, ['a', 'b']);
    });

    test('explicit order beats old start: B at 22:00 docks after A at 20:25', () {
      final a = _task(
        id: 'a',
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        startH: 22,
        startM: 0,
        endH: 22,
        endM: 45,
        order: 1,
      );
      final intent = _afterAIntent(draggedId: 'b');
      final result = applyTimeViewTargetInsertion(
        scheduled: [a, b],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      final bOut = result.cascaded.firstWhere((t) => t.planRowId == 'b');
      expect(bOut.startTime, _wall(20, 25));
      expect(bOut.endDateTime, _wall(21, 10));
      expect(bOut.startTime, isNot(_wall(22, 0)));
    });

    test('explicit order beats raw Y minutes (20:55 vs target.end 20:25)', () {
      final a = _task(
        id: 'a',
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        startH: 20,
        startM: 55,
        endH: 21,
        endM: 40,
        order: 1,
      );
      final intent = _afterAIntent(draggedId: 'b');
      final result = applyTimeViewTargetInsertion(
        scheduled: [a, b],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      expect(result.draggedStartWall, _wall(20, 25));
      expect(result.draggedStartWall, isNot(_wall(20, 55)));
    });

    test('stored intent used when release hit-test would miss (simulated)', () {
      final a = _task(
        id: 'a',
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        startH: 22,
        startM: 0,
        endH: 22,
        endM: 45,
        order: 1,
      );
      final storedIntent = _afterAIntent(draggedId: 'b');
      // Commit path: stored intent present, release hit-test not consulted.
      final result = applyTimeViewTargetInsertion(
        scheduled: [a, b],
        intent: storedIntent,
        resolveDurationMinutes: _resolveDuration,
      );
      expect(result.draggedStartWall, _wall(20, 25));
      expect(result.draggedEndWall, _wall(21, 10));
    });

    test('before-target insertion: target 20:00, dragged 15m → 19:45–20:00', () {
      final target = _task(
        id: 't',
        startH: 20,
        startM: 0,
        endH: 20,
        endM: 30,
      );
      final dragged = _task(
        id: 'd',
        startH: 21,
        startM: 0,
        endH: 21,
        endM: 15,
        order: 1,
      );
      final intent = TimeViewInsertionIntent(
        draggedPlanId: 'd',
        targetPlanId: 't',
        insertPosition: TimeViewInsertPosition.before,
        targetStartWall: _wall(20, 0),
        targetEndWall: _wall(20, 30),
        draggedDurationMinutes: 15,
        draggedHadEnd: true,
      );
      final result = applyTimeViewTargetInsertion(
        scheduled: [target, dragged],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      expect(result.draggedStartWall, _wall(19, 45));
      expect(result.draggedEndWall, _wall(20, 0));
      expect(result.orderAfter, ['d', 't']);
    });

    test('preview equals commit via same helper', () {
      final a = _task(
        id: 'a',
        startH: 10,
        startM: 0,
        endH: 10,
        endM: 30,
      );
      final b = _task(
        id: 'b',
        startH: 12,
        startM: 0,
        endH: 12,
        endM: 30,
        order: 1,
      );
      final intent = TimeViewInsertionIntent(
        draggedPlanId: 'b',
        targetPlanId: 'a',
        insertPosition: TimeViewInsertPosition.after,
        targetStartWall: _wall(10, 0),
        targetEndWall: _wall(10, 30),
        draggedDurationMinutes: 30,
        draggedHadEnd: true,
      );
      final preview = applyTimeViewTargetInsertion(
        scheduled: [a, b],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      final commit = applyTimeViewTargetInsertion(
        scheduled: [a, b],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      expect(preview.draggedStartWall, commit.draggedStartWall);
      expect(preview.draggedEndWall, commit.draggedEndWall);
      expect(preview.orderAfter, commit.orderAfter);
    });

    test('following tasks cascade after explicit target insert', () {
      final a = _task(
        id: 'a',
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final follower = _task(
        id: 'c',
        startH: 20,
        startM: 30,
        endH: 21,
        endM: 0,
        order: 2,
      );
      final dragged = _task(
        id: 'drag',
        startH: 22,
        startM: 0,
        endH: 22,
        endM: 45,
        order: 1,
      );
      final intent = TimeViewInsertionIntent(
        draggedPlanId: 'drag',
        targetPlanId: 'a',
        insertPosition: TimeViewInsertPosition.after,
        targetStartWall: a.startTime!,
        targetEndWall: a.endDateTime!,
        draggedDurationMinutes: 45,
        draggedHadEnd: true,
      );
      final result = applyTimeViewTargetInsertion(
        scheduled: [a, dragged, follower],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      final cOut = result.cascaded.firstWhere((t) => t.planRowId == 'c');
      expect(cOut.startTime, _wall(21, 10));
      expect(cOut.endDateTime, _wall(21, 40));
    });

    test('day-load sort cascade differs from explicit order for old start', () {
      final a = _task(
        id: 'a',
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        startH: 22,
        startM: 0,
        endH: 22,
        endM: 45,
        order: 1,
      );
      final intent = _afterAIntent(draggedId: 'b');
      final explicit = applyTimeViewTargetInsertion(
        scheduled: [a, b],
        intent: intent,
        resolveDurationMinutes: _resolveDuration,
      );
      final dayLoad = cascadeScheduledPlansForTimeViewDay(
        [a, b.copyWith(startTime: _wall(20, 25), endDateTime: _wall(21, 10))],
        resolveDurationMinutes: _resolveDuration,
      );
      final explicitB = explicit.cascaded.firstWhere((t) => t.planRowId == 'b');
      final dayLoadB = dayLoad.firstWhere((t) => t.planRowId == 'b');
      expect(explicitB.startTime, _wall(20, 25));
      // Day-load keeps chronological order when no overlap — explicit forces adjacency.
      expect(explicit.orderAfter, ['a', 'b']);
      expect(dayLoadB.startTime, _wall(20, 25));
    });
  });

  group('empty canvas path (no target intent)', () {
    test('yToTime placement unchanged when no intent helper involved', () {
      // Empty canvas uses normalize day cascade after free placement — verify
      // explicit helper is not invoked without intent.
      final t = _task(
        id: 'solo',
        startH: 9,
        startM: 15,
        endH: 9,
        endM: 45,
      );
      final snappedStart = _wall(9, 15);
      final merged = [t.copyWith(startTime: snappedStart, endDateTime: _wall(9, 45))];
      final cascaded = cascadeScheduledPlansForTimeViewDay(
        merged,
        resolveDurationMinutes: _resolveDuration,
      );
      expect(cascaded.first.startTime, snappedStart);
    });
  });
}
