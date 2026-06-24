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
  TimeViewYScale grid,
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

double _hourBottom(TimeViewYScale grid, int hourIndex) =>
    grid.yForMinute((hourIndex + 1) * 60.0);

PlanTimeViewBlockLayout _layoutCard(
  List<PlanTimeViewBlockLayout> layouts,
  String id,
) =>
    layouts.firstWhere((l) => l.task.planRowId == id);

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

    test('single 10-minute task — rubber scale, not full hour fill', () {
      final result = _layout([
        _proj(hour: 11, minute: 0, durationMin: 10, id: 'b'),
      ]);
      final card = result.layouts.single;
      final rubber = result.grid.pxPerMinuteAtHourIndex(0);
      expect(card.heightPx, closeTo(10 * rubber, 0.51));
      expect(card.topPx + card.heightPx, lessThan(_hourBottom(result.grid, 0)));
      expect(
        card.visualDensity,
        PlanTimeCardVisualDensity.verySmall,
      );
    });

    test('two 10-minute tasks — both VerySmall, hour not absurd', () {
      final result = _layout([
        _proj(hour: 11, minute: 0, durationMin: 10, id: 'c0'),
        _proj(hour: 11, minute: 10, durationMin: 10, id: 'c1'),
      ]);
      expect(result.layouts.length, 2);
      for (final l in result.layouts) {
        expect(l.heightPx, closeTo(38, 0.01));
        expect(l.visualDensity, PlanTimeCardVisualDensity.verySmall);
      }
      expect(result.grid.hourHeightsPx.single, lessThan(230));
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
        final rubber = result.grid.pxPerMinuteAtHourIndex(0);
        expect(l.heightPx, closeTo(5 * rubber, 0.51));
      }
      for (var i = 0; i < result.layouts.length - 1; i++) {
        final a = result.layouts[i];
        final b = result.layouts[i + 1];
        expect(
          b.topPx,
          closeTo(a.topPx + a.heightPx + kPlanTimeCardGapPx, 0.51),
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

    test('global rubber increases for dense hour; hour bands stay uniform', () {
      final projections = <TimeModeProjectedPlan>[];
      for (var i = 0; i < 11; i++) {
        projections.add(
          _proj(hour: 10, minute: i * 5, durationMin: 5, id: 'a$i'),
        );
      }
      projections.add(
        _proj(hour: 11, minute: 0, durationMin: 60, id: 'd'),
      );
      final sparse = _layout(
        [_proj(hour: 11, minute: 0, durationMin: 60, id: 'solo')],
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      final dense = _layout(
        projections,
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      expect(
        dense.grid.rubberPxPerMinute,
        greaterThan(sparse.grid.rubberPxPerMinute),
      );
      expect(dense.grid.hourHeightsPx[0], dense.grid.hourHeightsPx[1]);
      final hour11Card = _layoutCard(dense.layouts, 'd');
      expect(
        hour11Card.heightPx,
        closeTo(60 * dense.grid.rubberPxPerMinute, 0.51),
      );
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

  group('rubber minute scale', () {
    test('A: single 45-minute card leaves 15-minute slot', () {
      final result = _layout(
        [_proj(hour: 12, minute: 0, durationMin: 45, id: 'a')],
        visibleHours: [12],
        rangeStart: 12,
      );
      final card = result.layouts.single;
      final rubber = result.grid.pxPerMinuteAtHourIndex(0);
      final hourBottom = _hourBottom(result.grid, 0);
      expect(card.topPx, closeTo(0, 0.51));
      expect(card.heightPx, closeTo(45 * rubber, 0.51));
      expect(card.topPx + card.heightPx, lessThan(hourBottom));
      final remaining = hourBottom - (card.topPx + card.heightPx);
      expect(remaining, greaterThan(0));
      expect(remaining, closeTo(15 * rubber, 1.0));
    });

    test('B: single 30-minute card leaves 30-minute slot', () {
      final result = _layout(
        [_proj(hour: 12, minute: 0, durationMin: 30, id: 'a')],
        visibleHours: [12],
        rangeStart: 12,
      );
      final card = result.layouts.single;
      final rubber = result.grid.pxPerMinuteAtHourIndex(0);
      final remaining =
          _hourBottom(result.grid, 0) - (card.topPx + card.heightPx);
      expect(remaining, greaterThan(0));
      expect(remaining, closeTo(30 * rubber, 1.0));
    });

    test('C: full-hour 60-minute card may fill hour duration area', () {
      final result = _layout(
        [_proj(hour: 12, minute: 0, durationMin: 60, id: 'a')],
        visibleHours: [12],
        rangeStart: 12,
      );
      final card = result.layouts.single;
      final rubber = result.grid.pxPerMinuteAtHourIndex(0);
      expect(card.heightPx, closeTo(60 * rubber, 0.51));
      expect(
        card.topPx + card.heightPx,
        closeTo(_hourBottom(result.grid, 0), 5.0),
      );
    });

    test('D: adjacent 45 + 15 chain — 4px gap, hour fits both', () {
      final result = _layout(
        [
          _proj(hour: 10, minute: 0, durationMin: 45, id: 'a'),
          _proj(hour: 10, minute: 45, durationMin: 15, id: 'b'),
        ],
        visibleHours: [10],
        rangeStart: 10,
      );
      final a = result.layouts.firstWhere((l) => l.task.planRowId == 'a');
      final b = result.layouts.firstWhere((l) => l.task.planRowId == 'b');
      expect(b.topPx, closeTo(a.topPx + a.heightPx + kPlanTimeCardGapPx, 0.51));
      final packed = a.heightPx + kPlanTimeCardGapPx + b.heightPx;
      expect(
        result.grid.totalHeightPx,
        greaterThanOrEqualTo(packed - 0.5),
      );
    });

    test('E: adjacent 45 + 45 crossing hour — 4px gap, no fake blank gap', () {
      final result = _layout(
        [
          _proj(hour: 10, minute: 0, durationMin: 45, id: 'a'),
          _proj(hour: 10, minute: 45, durationMin: 45, id: 'b'),
        ],
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      final a = result.layouts.firstWhere((l) => l.task.planRowId == 'a');
      final b = result.layouts.firstWhere((l) => l.task.planRowId == 'b');
      expect(b.topPx, closeTo(a.topPx + a.heightPx + kPlanTimeCardGapPx, 0.51));
      expect(b.topPx, greaterThan(a.topPx + a.heightPx));
    });

    test('F: real 15-minute schedule gap preserved', () {
      final result = _layout(
        [
          _proj(hour: 10, minute: 0, durationMin: 30, id: 'a'),
          _proj(hour: 10, minute: 45, durationMin: 30, id: 'b'),
        ],
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      final a = result.layouts.firstWhere((l) => l.task.planRowId == 'a');
      final b = result.layouts.firstWhere((l) => l.task.planRowId == 'b');
      final rubber = result.grid.pxPerMinuteAtHourIndex(0);
      final visualGap = b.topPx - (a.topPx + a.heightPx);
      expect(visualGap, greaterThan(kPlanTimeCardGapPx + 0.5));
      expect(visualGap, closeTo(15 * rubber, 2.0));
    });

    test('G: dense three-card chain — all adjacent gaps 4px', () {
      final result = _layout(
        [
          _proj(hour: 10, minute: 0, durationMin: 20, id: 'a'),
          _proj(hour: 10, minute: 20, durationMin: 20, id: 'b'),
          _proj(hour: 10, minute: 40, durationMin: 20, id: 'c'),
        ],
        visibleHours: [10],
        rangeStart: 10,
      );
      final a = result.layouts[0];
      final b = result.layouts[1];
      final c = result.layouts[2];
      expect(b.topPx, closeTo(a.topPx + a.heightPx + kPlanTimeCardGapPx, 0.51));
      expect(c.topPx, closeTo(b.topPx + b.heightPx + kPlanTimeCardGapPx, 0.51));
      final packed = a.heightPx +
          kPlanTimeCardGapPx +
          b.heightPx +
          kPlanTimeCardGapPx +
          c.heightPx;
      expect(
        result.grid.totalHeightPx,
        greaterThanOrEqualTo(packed - 0.5),
      );
    });
  });

  group('shared TimeViewYScale hour lines + cards', () {
    test('A: 11:00 line inside 10:45–11:30 crossing card', () {
      final result = _layout(
        [_proj(hour: 10, minute: 45, durationMin: 45, id: 'b')],
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      final b = result.layouts.single;
      final y11 = result.grid.yForMinute(60);
      expect(y11, greaterThan(b.topPx));
      expect(y11, lessThan(b.topPx + b.heightPx));
    });

    test('B: 12:00 line inside 11:30–12:15 crossing card', () {
      final result = _layout(
        [_proj(hour: 11, minute: 30, durationMin: 45, id: 'c')],
        visibleHours: [10, 11, 12],
        rangeStart: 10,
      );
      final c = result.layouts.single;
      final y12 = result.grid.yForMinute(120);
      expect(y12, greaterThan(c.topPx));
      expect(y12, lessThan(c.topPx + c.heightPx));
    });

    test('C: adjacent chain A/B/C — 4px gaps + hour lines inside B and C', () {
      final result = _layout(
        [
          _proj(hour: 10, minute: 0, durationMin: 45, id: 'a'),
          _proj(hour: 10, minute: 45, durationMin: 45, id: 'b'),
          _proj(hour: 11, minute: 30, durationMin: 45, id: 'c'),
        ],
        visibleHours: [10, 11, 12],
        rangeStart: 10,
      );
      final a = _layoutCard(result.layouts, 'a');
      final b = _layoutCard(result.layouts, 'b');
      final c = _layoutCard(result.layouts, 'c');
      expect(b.topPx, closeTo(a.topPx + a.heightPx + kPlanTimeCardGapPx, 0.51));
      expect(c.topPx, closeTo(b.topPx + b.heightPx + kPlanTimeCardGapPx, 0.51));
      final y11 = result.grid.yForMinute(60);
      final y12 = result.grid.yForMinute(120);
      expect(y11, greaterThan(b.topPx));
      expect(y11, lessThan(b.topPx + b.heightPx));
      expect(y12, greaterThan(c.topPx));
      expect(y12, lessThan(c.topPx + c.heightPx));
    });

    test('D: 45-minute single card leaves 12:45–13:00 slot', () {
      final result = _layout(
        [_proj(hour: 12, minute: 0, durationMin: 45, id: 'a')],
        visibleHours: [12],
        rangeStart: 12,
      );
      final a = result.layouts.single;
      final y13 = result.grid.yForMinute(60);
      expect(a.topPx + a.heightPx, lessThan(y13));
      expect(y13 - (a.topPx + a.heightPx), closeTo(15 * result.grid.rubberPxPerMinute, 1.5));
    });

    test('E: real 15-minute schedule gap preserved', () {
      final result = _layout(
        [
          _proj(hour: 10, minute: 0, durationMin: 30, id: 'a'),
          _proj(hour: 10, minute: 45, durationMin: 30, id: 'b'),
        ],
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      final a = _layoutCard(result.layouts, 'a');
      final b = _layoutCard(result.layouts, 'b');
      final visualGap = b.topPx - (a.topPx + a.heightPx);
      expect(visualGap, greaterThan(kPlanTimeCardGapPx + 0.5));
      expect(visualGap, closeTo(15 * result.grid.rubberPxPerMinute, 2.0));
    });

    test('F: y(11:00) is not after bottom of 10:45–11:30 card', () {
      final result = _layout(
        [
          _proj(hour: 10, minute: 0, durationMin: 45, id: 'a'),
          _proj(hour: 10, minute: 45, durationMin: 45, id: 'b'),
        ],
        visibleHours: [10, 11],
        rangeStart: 10,
      );
      final b = _layoutCard(result.layouts, 'b');
      final y11 = result.grid.yForMinute(60);
      expect(y11, lessThan(b.topPx + b.heightPx));
      expect(y11, greaterThan(b.topPx));
    });

    test('hour lines are evenly spaced in shared coordinate system', () {
      final result = _layout(
        [_proj(hour: 10, minute: 0, durationMin: 30, id: 'solo')],
        visibleHours: [10, 11, 12],
        rangeStart: 10,
      );
      final y10 = result.grid.hourLineY(0);
      final y11 = result.grid.hourLineY(1);
      final y12 = result.grid.hourLineY(2);
      expect(y11 - y10, closeTo(y12 - y11, 0.01));
      expect(y11 - y10, closeTo(result.grid.hourBandHeightPx, 0.01));
    });
  });
}
