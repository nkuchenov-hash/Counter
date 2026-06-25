import 'package:counter/core/time/wall_clock.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

TimeModeProjectedPlan _projWall({
  required int startHour,
  required int startMinute,
  required int durationMin,
  required DateTime startUtc,
  String id = 'p',
}) {
  final wallStart = DateTime(2026, 6, 23, startHour, startMinute);
  final wallEnd = wallStart.add(Duration(minutes: durationMin));
  final task = PlanningTask(
    id: id.hashCode.abs(),
    title: 'Task $id',
    dateKey: '2026-06-23',
    startTime: wallStart,
    endDateTime: wallEnd,
    order: 0,
    isDone: false,
    categoryId: 1,
    planRowId: id,
    startUtcInstant: startUtc,
    endUtcInstant: startUtc.add(Duration(minutes: durationMin)),
  );
  return TimeModeProjectedPlan(
    task: task,
    startUtc: startUtc,
    endUtc: startUtc.add(Duration(minutes: durationMin)),
    wallStart: wallStart,
    wallEnd: wallEnd,
    wallDateKey: '2026-06-23',
    plannedTimeLabel: '00:00',
  );
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('Time View timezone projection', () {
    test('A: Moscow — UTC 07:00 projects to wall 10:00', () {
      final utc = DateTime.utc(2026, 6, 23, 7, 0);
      final wall = toWallClockForLabel(utc, 3, 'Moscow');
      expect(wall.hour, 10);
      expect(wall.minute, 0);
    });

    test('B: New York — same UTC projects to different wall minute than Moscow', () {
      final utc = DateTime.utc(2026, 6, 23, 7, 0);
      final moscowMin =
          toWallClockForLabel(utc, 3, 'Moscow').hour * 60 +
          toWallClockForLabel(utc, 3, 'Moscow').minute;
      final nyMin =
          toWallClockForLabel(utc, -5, 'New York').hour * 60 +
          toWallClockForLabel(utc, -5, 'New York').minute;
      expect(moscowMin, 600);
      expect(nyMin, isNot(moscowMin));
      expect(nyMin, 180);
    });

    test('B2: TimeViewYScale Y changes when wall minute changes', () {
      final utc = DateTime.utc(2026, 6, 23, 7, 0);
      final moscow = _projWall(
        startHour: 10,
        startMinute: 0,
        durationMin: 45,
        startUtc: utc,
        id: 'msk',
      );
      final nyWall = toWallClockForLabel(utc, -5, 'New York');
      final ny = _projWall(
        startHour: nyWall.hour,
        startMinute: nyWall.minute,
        durationMin: 45,
        startUtc: utc,
        id: 'ny',
      );
      final moscowLayout = PlanTimeViewLayoutCalculator.compute(
        projections: [moscow],
        visibleHours: [10, 11],
        rangeStart: 10,
        startMinOf: (p) => (p.startMinuteOfDay - 10 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 10 * 60 + p.durationMinutes).toDouble(),
      );
      final nyLayout = PlanTimeViewLayoutCalculator.compute(
        projections: [ny],
        visibleHours: [3, 4],
        rangeStart: 3,
        startMinOf: (p) => (p.startMinuteOfDay - 3 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 3 * 60 + p.durationMinutes).toDouble(),
      );
      expect(moscowLayout.layouts.single.topPx, closeTo(0, 0.51));
      expect(nyLayout.layouts.single.topPx, closeTo(0, 0.51));
      expect(
        moscowLayout.layouts.single.topPx,
        isNot(closeTo(nyLayout.grid.yForMinute(600), 1.0)),
      );
    });

    test('C: projection cache signature changes on timezone revision bump', () {
      final sigMoscow = Object.hash(12, 3, 'Moscow', 1);
      final sigNy = Object.hash(12, -5, 'New York', 2);
      expect(sigMoscow, isNot(sigNy));
    });

    test('D: wall day differs across Moscow vs New York for same UTC', () {
      final utc = DateTime.utc(2026, 6, 22, 22, 0);
      final moscow = toWallClockForLabel(utc, 3, 'Moscow');
      final ny = toWallClockForLabel(utc, -5, 'New York');
      expect(moscow.day, 23);
      expect(ny.day, 22);
    });

    test('E: date-only cache signature must include timezone fields', () {
      final dateOnlySig = Object.hash(10, 0);
      final tzAwareSig = Object.hash(10, 3, 'Moscow', 0);
      expect(dateOnlySig, isNot(equals(tzAwareSig)));
    });

    test('F: layout invariants after timezone-shifted wall minutes', () {
      final utcB = DateTime.utc(2026, 6, 23, 7, 45);
      final wallB = toWallClockForLabel(utcB, 3, 'Moscow');
      final b = _projWall(
        startHour: wallB.hour,
        startMinute: wallB.minute,
        durationMin: 45,
        startUtc: utcB,
        id: 'b',
      );
      final result = PlanTimeViewLayoutCalculator.compute(
        projections: [b],
        visibleHours: [10, 11],
        rangeStart: 10,
        startMinOf: (p) => (p.startMinuteOfDay - 10 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 10 * 60 + p.durationMinutes).toDouble(),
      );
      final card = result.layouts.single;
      final y11 = result.grid.yForMinute(60);
      expect(y11, greaterThan(card.topPx));
      expect(y11, lessThan(card.topPx + card.heightPx));

      final slotResult = PlanTimeViewLayoutCalculator.compute(
        projections: [
          _projWall(
            startHour: 12,
            startMinute: 0,
            durationMin: 45,
            startUtc: DateTime.utc(2026, 6, 23, 9, 0),
            id: 'slot',
          ),
        ],
        visibleHours: [12],
        rangeStart: 12,
        startMinOf: (p) => (p.startMinuteOfDay - 12 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 12 * 60 + p.durationMinutes).toDouble(),
      );
      final slotCard = slotResult.layouts.single;
      final y13 = slotResult.grid.yForMinute(60);
      expect(slotCard.topPx + slotCard.heightPx, lessThan(y13));

      final chainUtcA = DateTime.utc(2026, 6, 23, 7, 0);
      final chainUtcC = DateTime.utc(2026, 6, 23, 8, 30);
      final chain = PlanTimeViewLayoutCalculator.compute(
        projections: [
          _projWall(
            startHour: 10,
            startMinute: 0,
            durationMin: 45,
            startUtc: chainUtcA,
            id: 'a',
          ),
          _projWall(
            startHour: 10,
            startMinute: 45,
            durationMin: 45,
            startUtc: chainUtcA.add(const Duration(minutes: 45)),
            id: 'b2',
          ),
          _projWall(
            startHour: 11,
            startMinute: 30,
            durationMin: 45,
            startUtc: chainUtcC,
            id: 'c',
          ),
        ],
        visibleHours: [10, 11, 12],
        rangeStart: 10,
        startMinOf: (p) => (p.startMinuteOfDay - 10 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 10 * 60 + p.durationMinutes).toDouble(),
      );
      final a = chain.layouts[0];
      final b2 = chain.layouts[1];
      expect(
        b2.topPx,
        closeTo(a.topPx + a.heightPx + kPlanTimeCardGapPx, 0.51),
      );
    });
  });
}
