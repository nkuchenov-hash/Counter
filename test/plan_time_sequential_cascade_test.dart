import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:flutter_test/flutter_test.dart';

const _dayKey = '2026-06-15';

int _resolveDuration(List<Tag> tags) => 30;

PlanningTask _task({
  required String id,
  required int order,
  required int startH,
  required int startM,
  required int endH,
  required int endM,
}) {
  final start = DateTime(2026, 6, 15, startH, startM);
  final end = DateTime(2026, 6, 15, endH, endM);
  return PlanningTask(
    id: id.hashCode,
    title: 'Task $id',
    categoryId: 1,
    isDone: false,
    dateKey: _dayKey,
    order: order,
    startTime: start,
    endDateTime: end,
    planRowId: id,
  );
}

void main() {
  group('cascadeScheduledPlansForTimeViewDay', () {
    test('normalizes existing overlap A 19:40–20:25, B 20:05–20:50', () {
      final a = _task(
        id: 'a',
        order: 0,
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        order: 1,
        startH: 20,
        startM: 5,
        endH: 20,
        endM: 50,
      );
      final out = cascadeScheduledPlansForTimeViewDay(
        [a, b],
        resolveDurationMinutes: _resolveDuration,
      );
      final bOut = out.firstWhere((t) => t.planRowId == 'b');
      expect(bOut.startTime, DateTime(2026, 6, 15, 20, 25));
      expect(bOut.endDateTime, DateTime(2026, 6, 15, 21, 10));
    });

    test('drag/drop after target: B duration 45m becomes 20:25–21:10', () {
      final a = _task(
        id: 'a',
        order: 0,
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final bDur = 45;
      final bDropped = PlanningTask(
        id: 'b'.hashCode,
        title: 'Task b',
        categoryId: 1,
        isDone: false,
        dateKey: _dayKey,
        order: 1,
        startTime: DateTime(2026, 6, 15, 20, 25),
        endDateTime: DateTime(2026, 6, 15, 20, 25).add(
          Duration(minutes: bDur),
        ),
        planRowId: 'b',
      );
      final out = cascadeScheduledPlansForTimeViewDay(
        [a, bDropped],
        resolveDurationMinutes: _resolveDuration,
      );
      final bOut = out.firstWhere((t) => t.planRowId == 'b');
      expect(bOut.startTime, DateTime(2026, 6, 15, 20, 25));
      expect(bOut.endDateTime, DateTime(2026, 6, 15, 21, 10));
    });

    test('cascade chain A/B/C', () {
      final a = _task(
        id: 'a',
        order: 0,
        startH: 19,
        startM: 0,
        endH: 19,
        endM: 30,
      );
      final b = _task(
        id: 'b',
        order: 1,
        startH: 19,
        startM: 20,
        endH: 19,
        endM: 50,
      );
      final c = _task(
        id: 'c',
        order: 2,
        startH: 19,
        startM: 45,
        endH: 20,
        endM: 15,
      );
      final out = cascadeScheduledPlansForTimeViewDay(
        [a, b, c],
        resolveDurationMinutes: _resolveDuration,
      );
      final aOut = out.firstWhere((t) => t.planRowId == 'a');
      final bOut = out.firstWhere((t) => t.planRowId == 'b');
      final cOut = out.firstWhere((t) => t.planRowId == 'c');
      expect(aOut.startTime, DateTime(2026, 6, 15, 19, 0));
      expect(aOut.endDateTime, DateTime(2026, 6, 15, 19, 30));
      expect(bOut.startTime, DateTime(2026, 6, 15, 19, 30));
      expect(bOut.endDateTime, DateTime(2026, 6, 15, 20, 0));
      expect(cOut.startTime, DateTime(2026, 6, 15, 20, 0));
      expect(cOut.endDateTime, DateTime(2026, 6, 15, 20, 30));
    });

    test('preserves original duration for every shifted task', () {
      final tasks = [
        _task(
          id: 'a',
          order: 0,
          startH: 9,
          startM: 0,
          endH: 9,
          endM: 50,
        ),
        _task(
          id: 'b',
          order: 1,
          startH: 9,
          startM: 30,
          endH: 10,
          endM: 10,
        ),
        _task(
          id: 'c',
          order: 2,
          startH: 10,
          startM: 0,
          endH: 10,
          endM: 25,
        ),
      ];
      final beforeDur = {
        for (final t in tasks)
          t.planRowId: planWallDurationMinutesForCascade(
            t,
            resolveDurationMinutes: _resolveDuration,
          ),
      };
      final out = cascadeScheduledPlansForTimeViewDay(
        tasks,
        resolveDurationMinutes: _resolveDuration,
      );
      for (final t in out.where((p) => p.startTime != null)) {
        final dur = planWallDurationMinutesForCascade(
          t,
          resolveDurationMinutes: _resolveDuration,
        );
        expect(dur, beforeDur[t.planRowId]);
      }
    });

    test('quick-add collision: new task starts at previous.end', () {
      final existing = _task(
        id: 'a',
        order: 0,
        startH: 14,
        startM: 0,
        endH: 14,
        endM: 30,
      );
      const probeId = '__probe__';
      final probe = PlanningTask(
        id: 0,
        title: 'new',
        categoryId: 1,
        isDone: false,
        dateKey: _dayKey,
        order: 99,
        startTime: DateTime(2026, 6, 15, 14, 15),
        endDateTime: DateTime(2026, 6, 15, 14, 45),
        planRowId: probeId,
      );
      final out = cascadeScheduledPlansForTimeViewDay(
        [existing, probe],
        resolveDurationMinutes: _resolveDuration,
      );
      final p = out.firstWhere((t) => t.planRowId == probeId);
      expect(p.startTime, DateTime(2026, 6, 15, 14, 30));
      expect(p.endDateTime, DateTime(2026, 6, 15, 15, 0));
    });

    test('diffSequentialCascadePatches lists only changed rows', () {
      final a = _task(
        id: 'a',
        order: 0,
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        order: 1,
        startH: 20,
        startM: 5,
        endH: 20,
        endM: 50,
      );
      final cascaded = cascadeScheduledPlansForTimeViewDay(
        [a, b],
        resolveDurationMinutes: _resolveDuration,
      );
      final patches = diffSequentialCascadePatches([a, b], cascaded);
      expect(patches.length, 1);
      expect(patches.single.task.planRowId, 'b');
      expect(patches.single.afterStart, DateTime(2026, 6, 15, 20, 25));
      expect(patches.single.afterEnd, DateTime(2026, 6, 15, 21, 10));
    });

    test('scheduledPlansHaveWallOverlap detects overlap before cascade', () {
      final a = _task(
        id: 'a',
        order: 0,
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _task(
        id: 'b',
        order: 1,
        startH: 20,
        startM: 5,
        endH: 20,
        endM: 50,
      );
      expect(
        scheduledPlansHaveWallOverlap(
          [a, b],
          resolveDurationMinutes: _resolveDuration,
        ),
        isTrue,
      );
      final cascaded = cascadeScheduledPlansForTimeViewDay(
        [a, b],
        resolveDurationMinutes: _resolveDuration,
      );
      expect(
        scheduledPlansHaveWallOverlap(
          cascaded,
          resolveDurationMinutes: _resolveDuration,
        ),
        isFalse,
      );
    });

    test('virtual/recurring rows participate in cascade (no conflict layout)', () {
      final parent = _task(
        id: 'parent',
        order: 0,
        startH: 10,
        startM: 0,
        endH: 10,
        endM: 30,
      );
      final virt = PlanningTask(
        id: 'virt'.hashCode,
        title: 'Recurring virt',
        categoryId: 1,
        isDone: false,
        dateKey: _dayKey,
        order: 1,
        startTime: DateTime(2026, 6, 15, 10, 10),
        endDateTime: DateTime(2026, 6, 15, 10, 40),
        planRowId: 'virt-abc123',
        recurrenceInstanceDateKey: _dayKey,
        rrule: 'FREQ=DAILY',
      );
      final out = cascadeScheduledPlansForTimeViewDay(
        [parent, virt],
        resolveDurationMinutes: _resolveDuration,
      );
      final virtOut = out.firstWhere((t) => t.planRowIdForBackend == 'virt-abc123');
      expect(virtOut.startTime, DateTime(2026, 6, 15, 10, 30));
      expect(virtOut.endDateTime, DateTime(2026, 6, 15, 11, 0));
      expect(virtOut.recurrenceInstanceDateKey, _dayKey);
    });
  });
}
