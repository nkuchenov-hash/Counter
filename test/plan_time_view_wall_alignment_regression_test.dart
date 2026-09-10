import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TimeModeProjectedPlan _projection({
  required int hour,
  required int minute,
  required int durationMinutes,
  required String id,
}) {
  final start = DateTime.utc(2026, 9, 10, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  final task = PlanningTask(
    id: id.hashCode.abs(),
    title: 'Task $id',
    dateKey: '2026-09-10',
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
    wallDateKey: '2026-09-10',
    plannedTimeLabel:
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
  );
}

({TimeViewYScale grid, List<PlanTimeViewBlockLayout> layouts}) _layout(
  List<TimeModeProjectedPlan> projections,
) {
  const rangeStart = 14;
  return PlanTimeViewLayoutCalculator.compute(
    projections: projections,
    visibleHours: const [14, 15, 16, 17],
    rangeStart: rangeStart,
    baseHourHeightPx: 120,
    startMinOf: (p) => (p.startMinuteOfDay - rangeStart * 60).toDouble(),
    endMinOf: (p) =>
        (p.startMinuteOfDay - rangeStart * 60 + p.durationMinutes).toDouble(),
  );
}

void main() {
  test('scheduled card starts stay on exact wall-time Y positions', () {
    final result = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 45, id: 'a'),
      _projection(hour: 15, minute: 45, durationMinutes: 15, id: 'b'),
      _projection(hour: 16, minute: 0, durationMinutes: 30, id: 'c'),
      _projection(hour: 16, minute: 30, durationMinutes: 30, id: 'd'),
    ]);

    final a = result.layouts[0];
    final b = result.layouts[1];
    final c = result.layouts[2];
    final d = result.layouts[3];
    expect(a.topPx, closeTo(result.grid.yForMinute(60), 0.01));
    expect(b.topPx, closeTo(result.grid.yForMinute(105), 0.01));
    expect(c.topPx, closeTo(result.grid.yForMinute(120), 0.01));
    expect(d.topPx, closeTo(result.grid.yForMinute(150), 0.01));
    expect(c.topPx, closeTo(result.grid.hourLineY(2), 0.01));
    expect(b.topPx, greaterThanOrEqualTo(a.topPx + a.heightPx + 3.49));
    expect(c.topPx, greaterThanOrEqualTo(b.topPx + b.heightPx + 3.49));
    expect(d.topPx, greaterThanOrEqualTo(c.topPx + c.heightPx + 3.49));
  });

  test('every 5-minute start uses the exact shared timeline Y coordinate', () {
    for (var minute = 0; minute < 60; minute += 5) {
      final result = _layout([
        _projection(
          hour: 14,
          minute: minute,
          durationMinutes: 10,
          id: 'five-$minute',
        ),
      ]);
      expect(
        result.layouts.single.topPx,
        closeTo(result.grid.yForMinute(minute.toDouble()), 0.001),
      );
    }

    final hourBoundary = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 10, id: 'hour'),
    ]);
    expect(
      hourBoundary.layouts.single.topPx,
      closeTo(hourBoundary.grid.hourLineY(1), 0.001),
    );
  });

  test(
    'touching scheduled cards keep the canonical 4px minimum visual gap',
    () {
      final result = _layout([
        _projection(hour: 15, minute: 0, durationMinutes: 10, id: 'gap-a'),
        _projection(hour: 15, minute: 10, durationMinutes: 10, id: 'gap-b'),
      ]);

      final a = result.layouts[0];
      final b = result.layouts[1];
      expect(a.topPx, closeTo(result.grid.yForMinute(60), 0.001));
      expect(b.topPx, closeTo(result.grid.yForMinute(70), 0.001));
      expect(
        b.topPx - (a.topPx + a.heightPx),
        greaterThanOrEqualTo(kPlanTimeCardGapPx - 0.01),
      );
    },
  );

  test('only hours that need room stretch', () {
    final result = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 45, id: 'a'),
      _projection(hour: 15, minute: 45, durationMinutes: 15, id: 'b'),
    ]);

    expect(result.grid.hourHeightsPx[0], closeTo(120, 0.01));
    expect(result.grid.hourHeightsPx[1], greaterThan(120));
    expect(result.grid.hourHeightsPx[2], closeTo(120, 0.01));
    expect(result.grid.hourHeightsPx[3], closeTo(120, 0.01));
  });

  test('piecewise time/Y conversion remains reversible', () {
    final result = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 45, id: 'a'),
      _projection(hour: 15, minute: 45, durationMinutes: 15, id: 'b'),
    ]);

    for (final minute in <double>[60, 75, 90, 105, 120, 150]) {
      final y = result.grid.yForMinute(minute);
      expect(result.grid.minuteForY(y), closeTo(minute, 0.01));
    }
  });

  testWidgets('compact Time View card keeps its progress slot', (tester) async {
    final projection = _projection(
      hour: 15,
      minute: 0,
      durationMinutes: 45,
      id: 'progress',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 104,
            child: PlanTimeTaskCard(
              task: projection.projectedTask,
              density: PlanTimeTaskCardDensity.compact,
              surface: PlanCardSurface.timeline,
              timelineVisualDensity: PlanTimeCardVisualDensity.compact,
              timelineBlockHeightPx: 104,
              timelineFillHeight: true,
              showProgressBar: true,
              timeLabel: '15:00 – 15:45',
              planTrackedSeconds: 900,
              planEstimatedSeconds: 2700,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('15m'), findsOneWidget);
  });

  testWidgets(
    'running progress time is fully visible and advances every second',
    (tester) async {
      final projection = _projection(
        hour: 15,
        minute: 0,
        durationMinutes: 60,
        id: 'live-progress',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 140,
              child: PlanTimeTaskCard(
                task: projection.projectedTask,
                density: PlanTimeTaskCardDensity.medium,
                surface: PlanCardSurface.timeline,
                timelineVisualDensity: PlanTimeCardVisualDensity.medium,
                timelineBlockHeightPx: 140,
                timelineFillHeight: true,
                showProgressBar: true,
                timeLabel: '15:00 – 16:00',
                planTrackedSeconds: 10,
                planEstimatedSeconds: 3600,
                highlightAsRunning: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final initial = find.text('00:10');
      expect(initial, findsOneWidget);
      expect(tester.getSize(initial).height, lessThanOrEqualTo(12.01));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
