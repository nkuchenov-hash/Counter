import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _wall(int h, int m) => DateTime(2026, 6, 15, h, m);

PlanningTask _task({
  required String id,
  required int startH,
  required int startM,
  required int endH,
  required int endM,
}) {
  final start = _wall(startH, startM);
  final end = _wall(endH, endM);
  return PlanningTask(
    id: id.hashCode,
    title: id,
    categoryId: 1,
    isDone: false,
    dateKey: '2026-06-15',
    order: 0,
    startTime: start,
    endDateTime: end,
    planRowId: id,
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

    test('preview equals commit helper path', () {
      const draggedDuration = 30;
      final preview = computeTimeViewTargetDropSchedule(
        targetStartWall: _wall(10, 0),
        targetEndWall: _wall(10, 30),
        draggedDurationMinutes: draggedDuration,
        insertBefore: false,
        draggedHadEnd: true,
      );
      final commit = computeTimeViewTargetDropSchedule(
        targetStartWall: _wall(10, 0),
        targetEndWall: _wall(10, 30),
        draggedDurationMinutes: draggedDuration,
        insertBefore: false,
        draggedHadEnd: true,
      );
      expect(preview.startWall, commit.startWall);
      expect(preview.endWall, commit.endWall);
    });

    test('following tasks cascade after target insert', () {
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
      );
      final insert = computeTimeViewTargetDropSchedule(
        targetStartWall: a.startTime!,
        targetEndWall: a.endDateTime!,
        draggedDurationMinutes: 45,
        insertBefore: false,
        draggedHadEnd: true,
      );
      final dragged = PlanningTask(
        id: 'drag'.hashCode,
        title: 'drag',
        categoryId: 1,
        isDone: false,
        dateKey: '2026-06-15',
        order: 1,
        startTime: insert.startWall,
        endDateTime: insert.endWall,
        planRowId: 'drag',
      );
      final cascaded = cascadeScheduledPlansForTimeViewDay(
        [a, dragged, follower],
        resolveDurationMinutes: (_) => 30,
      );
      final cOut = cascaded.firstWhere((t) => t.planRowId == 'c');
      expect(cOut.startTime, _wall(21, 10));
      expect(cOut.endDateTime, _wall(21, 40));
    });
  });
}
