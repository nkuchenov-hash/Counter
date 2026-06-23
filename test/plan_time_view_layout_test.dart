import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:flutter_test/flutter_test.dart';

TimeModeProjectedPlan _proj({
  required int hour,
  required int minute,
  required int durationMin,
  required String id,
}) {
  final start = DateTime.utc(2026, 6, 15, hour, minute);
  final end = start.add(Duration(minutes: durationMin));
  final task = PlanningTask(
    id: id.hashCode.abs(),
    title: 'Task $id',
    dateKey: '2026-06-15',
    startTime: start,
    endDateTime: end,
    order: 0,
    isDone: false,
    categoryId: 1,
    planRowId: id,
    startUtcInstant: start,
    endUtcInstant: end,
  );
  return TimeModeProjectedPlan(
    task: task,
    startUtc: start,
    endUtc: end,
    wallStart: start,
    wallEnd: end,
    wallDateKey: '2026-06-15',
    plannedTimeLabel: '00:00',
  );
}

({
  PlanTimeViewDurationGrid grid,
  List<PlanTimeViewBlockLayout> layouts,
}) _layout(
  List<TimeModeProjectedPlan> projections, {
  List<int> visibleHours = const [11],
  int rangeStart = 11,
  double baseHourHeightPx = 120,
}) {
  return PlanTimeViewLayoutCalculator.compute(
    projections: projections,
    visibleHours: visibleHours,
    rangeStart: rangeStart,
    baseHourHeightPx: baseHourHeightPx,
    startMinOf: (p) => (p.startMinuteOfDay - rangeStart * 60).toDouble(),
    endMinOf: (p) =>
        (p.startMinuteOfDay - rangeStart * 60 + p.durationMinutes).toDouble(),
  );
}

void main() {
  group('planTimeCardVisualDensityForRenderedHeight', () {
    test('single 5-minute block is VerySmall at 38px', () {
      expect(
        planTimeCardVisualDensityForRenderedHeight(38),
        PlanTimeCardVisualDensity.verySmall,
      );
      expect(planTimeCardRenderedHeightPxForDuration(5), 38);
    });

    test('single 10-minute block stays VerySmall at 38px', () {
      expect(planTimeCardRenderedHeightPxForDuration(10), 38);
      expect(
        planTimeCardVisualDensityForRenderedHeight(
          planTimeCardRenderedHeightPxForDuration(10),
        ),
        PlanTimeCardVisualDensity.verySmall,
      );
    });

    test('Small band 39–54px', () {
      expect(
        planTimeCardVisualDensityForRenderedHeight(45),
        PlanTimeCardVisualDensity.small,
      );
    });

    test('MoreCompact band 55–77px hides breadcrumbs flag', () {
      expect(
        planTimeCardVisualDensityForRenderedHeight(60),
        PlanTimeCardVisualDensity.moreCompact,
      );
      expect(
        planTimeCardShowFooterBreadcrumbForVisual(
          PlanTimeCardVisualDensity.moreCompact,
        ),
        isFalse,
      );
    });

    test('Compact band 78–94px', () {
      expect(
        planTimeCardVisualDensityForRenderedHeight(85),
        PlanTimeCardVisualDensity.compact,
      );
    });

    test('Medium band 95px+', () {
      expect(
        planTimeCardVisualDensityForRenderedHeight(120),
        PlanTimeCardVisualDensity.medium,
      );
    });

    test('Small band hides progress bar', () {
      expect(
        planTimeCardShowProgressForVisual(PlanTimeCardVisualDensity.small),
        isFalse,
      );
    });
  });

  group('PlanTimeViewLayoutCalculator', () {
    test('single 5-minute task — 38px VerySmall', () {
      final result = _layout([
        _proj(hour: 11, minute: 0, durationMin: 5, id: 'a'),
      ]);
      expect(result.layouts.single.heightPx, closeTo(38, 0.01));
      expect(
        result.layouts.single.visualDensity,
        PlanTimeCardVisualDensity.verySmall,
      );
    });

    test('single 10-minute task — 38px, not inflated by hour stretch', () {
      final result = _layout([
        _proj(hour: 11, minute: 0, durationMin: 10, id: 'b'),
      ]);
      expect(result.layouts.single.heightPx, closeTo(38, 0.01));
      expect(
        result.layouts.single.visualDensity,
        PlanTimeCardVisualDensity.verySmall,
      );
      expect(result.grid.hourHeightsPx.single, closeTo(120, 1));
    });

    test('two 10-minute tasks — both VerySmall, hour not absurd', () {
      final result = _layout([
        _proj(hour: 11, minute: 0, durationMin: 10, id: 'c0'),
        _proj(hour: 11, minute: 0, durationMin: 10, id: 'c1'),
      ]);
      expect(result.layouts.length, 2);
      for (final l in result.layouts) {
        expect(l.heightPx, closeTo(38, 0.01));
        expect(l.visualDensity, PlanTimeCardVisualDensity.verySmall);
      }
      expect(result.grid.hourHeightsPx.single, lessThan(200));
    });

    test('11 × 5-minute tasks — all 38px, gap, no overlap', () {
      final projections = <TimeModeProjectedPlan>[];
      for (var i = 0; i < 11; i++) {
        projections.add(
          _proj(hour: 11, minute: i * 5, durationMin: 5, id: 'p$i'),
        );
      }
      final result = _layout(projections);
      expect(result.layouts.length, 11);
      for (final l in result.layouts) {
        expect(l.heightPx, closeTo(38, 0.01));
      }
      for (var i = 0; i < result.layouts.length - 1; i++) {
        final a = result.layouts[i];
        final b = result.layouts[i + 1];
        expect(
          b.topPx,
          greaterThanOrEqualTo(a.topPx + a.heightPx + kPlanTimeCardGapPx - 0.5),
        );
      }
      expect(
        result.grid.hourHeightsPx.first,
        greaterThan(120),
        reason: 'dense hour should stretch container only',
      );
      expect(
        result.grid.hourHeightsPx.first,
        lessThanOrEqualTo(kPlanTimeMaxReasonableHourHeightPx),
      );
    });

    test('mixed dense hour + normal hour only stretches dense hour', () {
      final projections = <TimeModeProjectedPlan>[];
      for (var i = 0; i < 11; i++) {
        projections.add(
          _proj(hour: 10, minute: i * 5, durationMin: 5, id: 'a$i'),
        );
      }
      projections.add(
        _proj(hour: 11, minute: 0, durationMin: 60, id: 'd'),
      );
      final result = _layout(
        projections,
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      expect(result.grid.hourHeightsPx[0], greaterThan(result.grid.hourHeightsPx[1]));
      final hour11Card = result.layouts.firstWhere(
        (l) => l.task.planRowId == 'd',
      );
      expect(hour11Card.heightPx, greaterThan(90));
      expect(hour11Card.heightPx, closeTo(228, 1));
    });

    test('y/time mapping round-trip uses hour geometry', () {
      final result = _layout([
        _proj(hour: 11, minute: 15, durationMin: 30, id: 'rt'),
      ]);
      final grid = result.grid;
      const probeMin = 15.0;
      final y = grid.yForMinutesFromRangeStart(probeMin);
      final back = grid.minutesFromY(y);
      expect(back, closeTo(probeMin, 0.75));
    });
  });
}
