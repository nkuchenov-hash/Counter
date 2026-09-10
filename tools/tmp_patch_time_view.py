from pathlib import Path

layout_path = Path('lib/features/planning/plan_time_view_layout.dart')
s = layout_path.read_text(encoding='utf-8')

start = s.index('  static int _slotStartHourIndex(')
end = s.index('\n  static ({\n    TimeViewYScale grid,', start)
replacement = r'''  /// Resolve only the wall-clock hours that need extra visual room.
  ///
  /// Time remains the source of truth: card starts are never packed away from
  /// their scheduled minute. Instead, an affected hour gets a larger local
  /// px/min scale so the canonical card body (plus the 4px boundary gap when
  /// another task starts exactly at its end) fits inside its real time span.
  static List<double> _resolveHourHeightsPx({
    required List<_PlanTimeViewCardSlot> slots,
    required int hourCount,
    required double baseHourHeightPx,
  }) {
    final heights = List<double>.filled(hourCount, baseHourHeightPx);
    if (hourCount == 0 || slots.isEmpty) return heights;
    final totalMinutes = hourCount * 60.0;

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final visibleStart = slot.startMin.clamp(0.0, totalMinutes).toDouble();
      final visibleEnd = slot.endMin.clamp(0.0, totalMinutes).toDouble();
      if (visibleEnd <= visibleStart + 0.01) continue;

      final hasAdjacentNext =
          i + 1 < slots.length &&
          _wallAdjacent(slot.endMin, slots[i + 1].startMin);
      final minimumCardHeight = _cardHeightPx(slot.durationMin);
      final requiredSpanPx = minimumCardHeight +
          (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0);
      final wallSpanMinutes = math.max(1.0, slot.endMin - slot.startMin);
      final requiredHourHeight = (requiredSpanPx / wallSpanMinutes * 60.0)
          .clamp(baseHourHeightPx, kPlanTimeMaxHourHeightPx)
          .toDouble();

      final firstHour = (visibleStart / 60.0)
          .floor()
          .clamp(0, hourCount - 1);
      final lastMinute = math.max(visibleStart, visibleEnd - 0.001);
      final lastHour = (lastMinute / 60.0)
          .floor()
          .clamp(0, hourCount - 1);
      for (var hour = firstHour; hour <= lastHour; hour++) {
        heights[hour] = math.max(heights[hour], requiredHourHeight);
      }
    }
    return heights;
  }
'''
s = s[:start] + replacement + s[end:]

place_start = s.index('  static List<PlanTimeViewBlockLayout> _placeCards(')
place_end = s.index('\n  static void _logEmptySlots', place_start)
place_replacement = r'''  static List<PlanTimeViewBlockLayout> _placeCards(
    List<_PlanTimeViewCardSlot> slots,
    TimeViewYScale yScale,
  ) {
    final layouts = <PlanTimeViewBlockLayout>[];

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final minimumHeight = _cardHeightPx(slot.durationMin);
      final topPx = yScale.yForMinute(slot.startMin);
      final endPx = yScale.yForMinute(slot.endMin);
      final spanPx = math.max(0.0, endPx - topPx);
      final hasAdjacentNext =
          i + 1 < slots.length &&
          _wallAdjacent(slot.endMin, slots[i + 1].startMin);
      final gapAfter = hasAdjacentNext
          ? math.min(
              kPlanTimeCardGapPx,
              math.max(0.0, spanPx - minimumHeight),
            )
          : 0.0;
      final heightPx = math.max(minimumHeight, spanPx - gapAfter);

      // TIME_VIEW_CARD_CONTENT_DENSITY_FROM_AVAILABLE_HEIGHT — inner layout only.
      final visual = planTimeCardVisualDensityForRenderedHeight(heightPx);
      layouts.add(
        PlanTimeViewBlockLayout(
          task: slot.task,
          projection: slot.projection,
          topPx: topPx,
          heightPx: heightPx,
          density: planTimeCardTaskDensityForVisual(visual),
          visualDensity: visual,
        ),
      );

      final startWall = slot.projection.profileWallStart;
      final endWall = slot.projection.profileWallEnd;
      final sh = startWall.hour.toString().padLeft(2, '0');
      final sm = startWall.minute.toString().padLeft(2, '0');
      final eh = endWall?.hour.toString().padLeft(2, '0') ?? sh;
      final em = endWall?.minute.toString().padLeft(2, '0') ?? sm;
      _logTimeLayout(
        'TIME_LAYOUT_CARD',
        'id=${slot.task.planRowIdForBackend} start=$sh:$sm end=$eh:$em '
        'top=${topPx.toStringAsFixed(1)} bottom=${(topPx + heightPx).toStringAsFixed(1)}',
      );
    }
    return layouts;
  }
'''
s = s[:place_start] + place_replacement + s[place_end:]

assert_start = s.index('      final expectedHeight = _cardHeightPx(slot.durationMin);')
assert_end = s.index('\n    for (var i = 0; i < layouts.length - 1; i++) {', assert_start)
assert_replacement = r'''      final minimumHeight = _cardHeightPx(slot.durationMin);

      assert(
        layout.heightPx >= minimumHeight - 0.51,
        'TIME_VIEW_CARD_BELOW_CANONICAL_MINIMUM: '
        'height ${layout.heightPx} < minimum $minimumHeight',
      );
      assert(layout.topPx >= 0, 'negative top');
      assert(layout.heightPx > 0, 'non-positive height');
      final expectedTop = yScale.yForMinute(slot.startMin);
      assert(
        (layout.topPx - expectedTop).abs() < 0.51,
        'TIME_VIEW_WALL_START_MISMATCH: '
        'top ${layout.topPx} != wall-time y $expectedTop',
      );
'''
s = s[:assert_start] + assert_replacement + s[assert_end:]

pair_start = s.index('    for (var i = 0; i < layouts.length - 1; i++) {')
pair_end = s.index('\n    for (var h = 0; h < yScale.visibleHours.length; h++) {', pair_start)
pair_replacement = r'''    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      final slotA = slots[i];
      final slotB = slots[i + 1];
      if (slotB.startMin >= slotA.endMin - 0.01) {
        final requiredGap = _wallAdjacent(slotA.endMin, slotB.startMin)
            ? kPlanTimeCardGapPx
            : 0.0;
        assert(
          b.topPx >= a.topPx + a.heightPx + requiredGap - 0.51,
          'TIME_VIEW_VISUAL_OVERLAP: ${a.task.title} -> ${b.task.title}',
        );
      }
    }
'''
s = s[:pair_start] + pair_replacement + s[pair_end:]
layout_path.write_text(s, encoding='utf-8')

card_path = Path('lib/core/widgets/plan_time_task_card/plan_time_task_card.dart')
card = card_path.read_text(encoding='utf-8')
old = '''    final useInvariantSlots =
        (effectiveDensity == PlanTimeTaskCardDensity.medium ||
            effectiveDensity == PlanTimeTaskCardDensity.large) &&
        widget.showProgressBar;'''
new = '''    final useInvariantSlots =
        widget.showProgressBar &&
        (isTimeViewCard ||
            effectiveDensity == PlanTimeTaskCardDensity.medium ||
            effectiveDensity == PlanTimeTaskCardDensity.large);'''
if old not in card:
    raise SystemExit('progress-slot target not found')
card_path.write_text(card.replace(old, new, 1), encoding='utf-8')

metrics_path = Path('lib/core/widgets/plan_time_task_card/plan_card_metrics.dart')
metrics = metrics_path.read_text(encoding='utf-8')
old_metrics = '''/// Dense hour: at most six 10-minute cards with stable 56px card geometry.
const int kPlanTimeMaxCardsPerHour = 6;
const double kPlanTimeMaxHourHeightPx =
    kPlanTimeMaxCardsPerHour * kPlanTimeMinCardHeightPx +
    (kPlanTimeMaxCardsPerHour - 1) * kPlanTimeCardGapPx;'''
new_metrics = '''/// Dense hour: six exact 10-minute slots. Each 60px slot can hold the
/// canonical 56px minimum card and preserve the 4px boundary gap.
const int kPlanTimeMaxCardsPerHour = 6;
const double kPlanTimeMaxHourHeightPx =
    kPlanTimeMaxCardsPerHour *
    (kPlanTimeMinCardHeightPx + kPlanTimeCardGapPx);'''
if old_metrics not in metrics:
    raise SystemExit('hour-cap target not found')
metrics_path.write_text(metrics.replace(old_metrics, new_metrics, 1), encoding='utf-8')

test_path = Path('test/plan_time_view_wall_alignment_regression_test.dart')
test_path.write_text(r'''import 'package:counter/core/widgets/plan_time_task_card.dart';
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
    startMinOf: (p) =>
        (p.startMinuteOfDay - rangeStart * 60).toDouble(),
    endMinOf: (p) =>
        (p.startMinuteOfDay - rangeStart * 60 + p.durationMinutes).toDouble(),
  );
}

void main() {
  test('scheduled card starts stay on their exact wall-time Y positions', () {
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

  test('only hours that need room stretch; empty hours stay at base height', () {
    final result = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 45, id: 'a'),
      _projection(hour: 15, minute: 45, durationMinutes: 15, id: 'b'),
    ]);
    expect(result.grid.hourHeightsPx[0], closeTo(120, 0.01));
    expect(result.grid.hourHeightsPx[1], greaterThan(120));
    expect(result.grid.hourHeightsPx[2], closeTo(120, 0.01));
    expect(result.grid.hourHeightsPx[3], closeTo(120, 0.01));
  });

  test('piecewise time/Y conversion stays reversible through a stretched hour', () {
    final result = _layout([
      _projection(hour: 15, minute: 0, durationMinutes: 45, id: 'a'),
      _projection(hour: 15, minute: 45, durationMinutes: 15, id: 'b'),
    ]);
    for (final minute in <double>[60, 75, 90, 105, 120, 150]) {
      final y = result.grid.yForMinute(minute);
      expect(result.grid.minuteForY(y), closeTo(minute, 0.01));
    }
  });

  testWidgets('45-minute compact Time View card renders progress', (tester) async {
    final projection = _projection(
      hour: 15,
      minute: 0,
      durationMinutes: 45,
      id: 'progress',
    );
    final task = projection.projectedTask;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 104,
            child: PlanTimeTaskCard(
              task: task,
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
    expect(find.textContaining('15m / 45m'), findsOneWidget);
  });
}
''', encoding='utf-8')
