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

void main() {
  group('planTimeCardVisualDensityForRenderedHeight', () {
    test('single 5-minute block is VerySmall at 38px', () {
      expect(
        planTimeCardVisualDensityForRenderedHeight(38),
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
    test('11 × 5-minute tasks in one hour — no overlap, min height, gap', () {
      final projections = <TimeModeProjectedPlan>[];
      for (var i = 0; i < 11; i++) {
        projections.add(
          _proj(hour: 11, minute: i * 5, durationMin: 5, id: 'p$i'),
        );
      }
      final result = PlanTimeViewLayoutCalculator.compute(
        projections: projections,
        visibleHours: [11],
        rangeStart: 11,
        baseHourHeightPx: 120,
        startMinOf: (p) => (p.startMinuteOfDay - 11 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 11 * 60 + p.durationMinutes).toDouble(),
      );
      expect(result.layouts.length, 11);
      for (final l in result.layouts) {
        expect(l.heightPx, greaterThanOrEqualTo(kPlanTimeCardMinHeightPx));
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
        reason: 'dense hour should stretch',
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
      final result = PlanTimeViewLayoutCalculator.compute(
        projections: projections,
        visibleHours: [10, 11],
        rangeStart: 10,
        baseHourHeightPx: 120,
        startMinOf: (p) => (p.startMinuteOfDay - 10 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 10 * 60 + p.durationMinutes).toDouble(),
      );
      expect(result.grid.hourHeightsPx[0], greaterThan(result.grid.hourHeightsPx[1]));
      expect(result.grid.hourHeightsPx[1], closeTo(120, 1));
    });
  });
}
