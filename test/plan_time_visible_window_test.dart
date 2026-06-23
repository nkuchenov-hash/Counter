import 'package:counter/core/time/plan_time_visible_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlanTimeVisibleWindow extended day window', () {
    test('default 7→23 remains valid', () {
      final range = PlanTimeVisibleWindow.normalizeExtendedRange(7, 23);
      expect(range.start, 7);
      expect(range.end, 23);
      expect(PlanTimeVisibleWindow.visibleDurationHours(7, 23), 16);
    });

    test('-3→23 maps to previous-day 21:00 start', () {
      final day = DateTime(2026, 6, 23);
      final start = PlanTimeVisibleWindow.windowStartWall(day, -3);
      expect(start, DateTime(2026, 6, 22, 21, 0));
      final end = PlanTimeVisibleWindow.windowEndWall(day, 23);
      expect(end, DateTime(2026, 6, 23, 23, 0));
    });

    test('7→27 maps to next-day 03:00 end', () {
      final day = DateTime(2026, 6, 23);
      final start = PlanTimeVisibleWindow.windowStartWall(day, 7);
      expect(start, DateTime(2026, 6, 23, 7, 0));
      final end = PlanTimeVisibleWindow.windowEndWall(day, 27);
      expect(end, DateTime(2026, 6, 24, 3, 0));
      expect(PlanTimeVisibleWindow.visibleDurationHours(7, 27), 20);
    });

    test('legacy crossing start=20/end=2 migrates to 20→26', () {
      final migrated = PlanTimeVisibleWindow.migrateLegacyRange(
        legacyStart: 20,
        legacyEnd: 2,
      );
      expect(migrated.start, 20);
      expect(migrated.end, 26);
    });

    test('task at D+1 01:00 visible for D when range is 7→27', () {
      final day = DateTime(2026, 6, 23);
      final taskStart = DateTime(2026, 6, 24, 1, 0);
      final taskEnd = DateTime(2026, 6, 24, 1, 30);
      expect(
        PlanTimeVisibleWindow.projectedPlanOverlapsVisibleWindow(
          wallStart: taskStart,
          wallEnd: taskEnd,
          durationMinutes: 30,
          selectedDay: day,
          startExtended: 7,
          endExtended: 27,
        ),
        isTrue,
      );
    });

    test('task at D+1 04:00 not visible for D when range is 7→27', () {
      final day = DateTime(2026, 6, 23);
      final taskStart = DateTime(2026, 6, 24, 4, 0);
      expect(
        PlanTimeVisibleWindow.projectedPlanOverlapsVisibleWindow(
          wallStart: taskStart,
          wallEnd: taskStart.add(const Duration(minutes: 30)),
          durationMinutes: 30,
          selectedDay: day,
          startExtended: 7,
          endExtended: 27,
        ),
        isFalse,
      );
    });

    test('y→time conversion supports 25:30 on selected day D', () {
      final day = DateTime(2026, 6, 23);
      const startExt = 7;
      final minutes = (25 - startExt) * 60 + 30;
      final wall = PlanTimeVisibleWindow.wallFromWindowMinutes(
        day,
        startExt,
        minutes.toDouble(),
      );
      expect(wall, DateTime(2026, 6, 24, 1, 30));
    });

    test('now-line window: profile now inside 7→27 on selected day', () {
      final day = DateTime(2026, 6, 23);
      final nowInside = DateTime(2026, 6, 23, 22, 0);
      final nowAfterWindow = DateTime(2026, 6, 24, 4, 0);
      expect(
        PlanTimeVisibleWindow.wallInstantInsideVisibleWindow(
          nowInside,
          day,
          7,
          27,
        ),
        isTrue,
      );
      expect(
        PlanTimeVisibleWindow.wallInstantInsideVisibleWindow(
          nowAfterWindow,
          day,
          7,
          27,
        ),
        isFalse,
      );
    });

    test('visible extended hours are linear without wrap', () {
      expect(
        PlanTimeVisibleWindow.visibleExtendedHoursOrdered(7, 27),
        List<int>.generate(20, (i) => 7 + i),
      );
      expect(
        PlanTimeVisibleWindow.visibleExtendedHoursOrdered(-3, 23).first,
        -3,
      );
      expect(
        PlanTimeVisibleWindow.visibleExtendedHoursOrdered(-3, 23).last,
        22,
      );
    });

    test('formatExtendedHourClock maps -3 to 21:00', () {
      expect(
        PlanTimeVisibleWindow.formatExtendedHourClock(-3),
        '21:00',
      );
      expect(
        PlanTimeVisibleWindow.formatExtendedHourClock(27),
        '03:00',
      );
    });
  });
}
