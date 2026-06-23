import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';

/// Duration-true timeline scale with per-hour stretch (P0S Time View).
///
/// **Card height** uses [planTimeCardRenderedHeightPxForDuration] (stable scale).
/// **Hour height** stretches only to fit stacked cards + gaps — never feeds back
/// into card height.
class PlanTimeViewDurationGrid {
  PlanTimeViewDurationGrid({
    required this.visibleHours,
    required this.rangeStart,
    required this.hourHeightsPx,
    required this.hourTopsPx,
  });

  final List<int> visibleHours;
  final int rangeStart;
  final List<double> hourHeightsPx;
  final List<double> hourTopsPx;

  List<double> get hourHeights => hourHeightsPx;

  List<double> get hourTops => hourTopsPx;

  double get totalMinutes => visibleHours.length * 60.0;

  double get totalHeightPx {
    if (hourHeightsPx.isEmpty) return 0;
    return hourTopsPx.last + hourHeightsPx.last;
  }

  /// Hour-band ppm for y↔time mapping only — not for card height.
  double pxPerMinuteAtHourIndex(int hourIndex) {
    if (hourIndex < 0 || hourIndex >= hourHeightsPx.length) return 0;
    return hourHeightsPx[hourIndex] / 60.0;
  }

  int hourIndexForMinutesFromRangeStart(double minutesFromRangeStart) {
    final m = minutesFromRangeStart.clamp(0, totalMinutes - 0.001);
    return (m / 60.0).floor().clamp(0, visibleHours.length - 1);
  }

  double yForMinutesFromRangeStart(double minutesFromRangeStart) {
    if (visibleHours.isEmpty) return 0;
    final m = minutesFromRangeStart.clamp(0, totalMinutes);
    final hourIdx = (m / 60.0).floor().clamp(0, visibleHours.length - 1);
    final withinHour = m - hourIdx * 60.0;
    return hourTopsPx[hourIdx] +
        (withinHour / 60.0) * hourHeightsPx[hourIdx];
  }

  double minutesFromY(double y) {
    if (visibleHours.isEmpty || totalHeightPx <= 0) return 0;
    final clampedY = y.clamp(0, totalHeightPx);
    for (var i = 0; i < visibleHours.length; i++) {
      final top = hourTopsPx[i];
      final bottom = top + hourHeightsPx[i];
      if (clampedY <= bottom || i == visibleHours.length - 1) {
        final within = (clampedY - top).clamp(0, hourHeightsPx[i]);
        final ppm = hourHeightsPx[i] / 60.0;
        if (ppm <= 0) return i * 60.0;
        return i * 60.0 + within / ppm;
      }
    }
    return totalMinutes;
  }
}

/// Absolute placement for one scheduled task on the Time View canvas.
class PlanTimeViewBlockLayout {
  const PlanTimeViewBlockLayout({
    required this.task,
    required this.topPx,
    required this.heightPx,
    required this.density,
    this.projection,
    this.visualDensity = PlanTimeCardVisualDensity.medium,
    this.hasScheduleConflict = false,
  });

  final PlanningTask task;
  final TimeModeProjectedPlan? projection;
  final double topPx;
  final double heightPx;
  final PlanTimeTaskCardDensity density;
  final PlanTimeCardVisualDensity visualDensity;
  final bool hasScheduleConflict;
}

class _PlanTimeViewCardSlot {
  _PlanTimeViewCardSlot({
    required this.projection,
    required this.task,
    required this.startMin,
    required this.endMin,
    required this.durationMin,
  });

  final TimeModeProjectedPlan projection;
  final PlanningTask task;
  final double startMin;
  final double endMin;
  final int durationMin;
}

/// Pure Time View geometry: bounded stretchable hours + sequential cards.
abstract final class PlanTimeViewLayoutCalculator {
  static double baseHourHeightPx() {
    final cardH = planTimeCardMeasureHeight(
      hasTags: false,
      hasTrackedProgress: false,
    );
    return (cardH * 1.5).clamp(
      kPlanTimeViewBaseHourHeightMinPx,
      kPlanTimeViewBaseHourHeightMaxPx,
    );
  }

  static double _cardHeightPx(int durationMin) =>
      planTimeCardRenderedHeightPxForDuration(durationMin);

  static ({
    PlanTimeViewDurationGrid grid,
    List<PlanTimeViewBlockLayout> layouts,
  }) compute({
    required List<TimeModeProjectedPlan> projections,
    required List<int> visibleHours,
    required int rangeStart,
    required double Function(TimeModeProjectedPlan proj) startMinOf,
    required double Function(TimeModeProjectedPlan proj) endMinOf,
    double? baseHourHeightPx,
  }) {
    final baseH = baseHourHeightPx ?? PlanTimeViewLayoutCalculator.baseHourHeightPx();
    final hourHeights = List<double>.filled(visibleHours.length, baseH);

    final slots = <_PlanTimeViewCardSlot>[];
    for (final proj in projections) {
      final startMin = startMinOf(proj);
      final endMin = endMinOf(proj);
      final dur = math.max(5, (endMin - startMin).round());
      slots.add(
        _PlanTimeViewCardSlot(
          projection: proj,
          task: proj.projectedTask,
          startMin: startMin,
          endMin: endMin,
          durationMin: dur,
        ),
      );
    }
    slots.sort((a, b) {
      final c = a.startMin.compareTo(b.startMin);
      if (c != 0) return c;
      return a.task.planRowIdForBackend.compareTo(b.task.planRowIdForBackend);
    });

    final byHour = <int, List<_PlanTimeViewCardSlot>>{};
    for (final slot in slots) {
      final hourIdx = (slot.startMin / 60.0).floor().clamp(
        0,
        visibleHours.length - 1,
      );
      byHour.putIfAbsent(hourIdx, () => []).add(slot);
    }

    for (final entry in byHour.entries) {
      final hourIdx = entry.key;
      final hourStart = hourIdx * 60.0;
      hourHeights[hourIdx] = _boundedHourHeightPx(
        cards: entry.value,
        hourStartMin: hourStart,
        baseHourHeightPx: baseH,
      );
    }

    final grid = _buildGrid(visibleHours, rangeStart, hourHeights);
    final layouts = _placeCards(slots, grid);
    assertPlanTimeViewLayoutDebug(grid: grid, layouts: layouts, slots: slots);
    return (grid: grid, layouts: layouts);
  }

  /// Sequential one-column placement height for an hour (stable card heights).
  static double _boundedHourHeightPx({
    required List<_PlanTimeViewCardSlot> cards,
    required double hourStartMin,
    required double baseHourHeightPx,
  }) {
    if (cards.isEmpty) return baseHourHeightPx;
    final sorted = List<_PlanTimeViewCardSlot>.from(cards)
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    var hourHeight = baseHourHeightPx;
    for (var iter = 0; iter < 3; iter++) {
      double prevBottom = 0;
      var maxBottom = 0.0;
      for (final c in sorted) {
        final relMin = c.startMin - hourStartMin;
        final idealTop = (relMin / 60.0) * hourHeight;
        final h = _cardHeightPx(c.durationMin);
        final top = prevBottom <= 0
            ? idealTop
            : math.max(idealTop, prevBottom + kPlanTimeCardGapPx);
        prevBottom = top + h;
        maxBottom = math.max(maxBottom, prevBottom);
      }
      final needed = math.min(
        math.max(
          baseHourHeightPx,
          maxBottom + kPlanTimeHourVerticalPaddingPx,
        ),
        kPlanTimeMaxReasonableHourHeightPx,
      );
      if ((needed - hourHeight).abs() < 0.5) {
        return needed;
      }
      hourHeight = needed;
    }
    return hourHeight;
  }

  static PlanTimeViewDurationGrid _buildGrid(
    List<int> visibleHours,
    int rangeStart,
    List<double> hourHeights,
  ) {
    final tops = <double>[];
    var y = 0.0;
    for (var i = 0; i < hourHeights.length; i++) {
      tops.add(y);
      y += hourHeights[i];
    }
    return PlanTimeViewDurationGrid(
      visibleHours: visibleHours,
      rangeStart: rangeStart,
      hourHeightsPx: hourHeights,
      hourTopsPx: tops,
    );
  }

  static List<PlanTimeViewBlockLayout> _placeCards(
    List<_PlanTimeViewCardSlot> slots,
    PlanTimeViewDurationGrid grid,
  ) {
    final layouts = <PlanTimeViewBlockLayout>[];
    final prevBottomByHour = <int, double>{};
    double? globalPrevBottom;

    for (final slot in slots) {
      final hourIdx = grid.hourIndexForMinutesFromRangeStart(slot.startMin);
      final hourStartMin = hourIdx * 60.0;
      final hourTopPx = grid.hourTopsPx[hourIdx];
      final hourHeightPx = grid.hourHeightsPx[hourIdx];

      final relMin = slot.startMin - hourStartMin;
      final idealTop = hourTopPx + (relMin / 60.0) * hourHeightPx;
      final heightPx = _cardHeightPx(slot.durationMin);

      var topPx = idealTop;
      final hourPrev = prevBottomByHour[hourIdx];
      if (hourPrev != null) {
        topPx = math.max(topPx, hourPrev + kPlanTimeCardGapPx);
      }
      if (globalPrevBottom != null) {
        topPx = math.max(topPx, globalPrevBottom + kPlanTimeCardGapPx);
      }

      prevBottomByHour[hourIdx] = topPx + heightPx;
      globalPrevBottom = topPx + heightPx;

      final visual = planTimeCardVisualDensityForRenderedHeight(heightPx);
      var conflict = false;
      for (final prev in layouts) {
        if (topPx < prev.topPx + prev.heightPx - 0.5) {
          conflict = true;
          break;
        }
      }
      layouts.add(
        PlanTimeViewBlockLayout(
          task: slot.task,
          projection: slot.projection,
          topPx: topPx,
          heightPx: heightPx,
          density: planTimeCardTaskDensityForVisual(visual),
          visualDensity: visual,
          hasScheduleConflict: conflict,
        ),
      );
    }
    return layouts;
  }

  /// Debug-only layout invariants (Time View acceptance).
  static void assertPlanTimeViewLayoutDebug({
    required PlanTimeViewDurationGrid grid,
    required List<PlanTimeViewBlockLayout> layouts,
    required List<_PlanTimeViewCardSlot> slots,
  }) {
    if (kReleaseMode) return;
    for (var i = 0; i < layouts.length; i++) {
      final l = layouts[i];
      final slot = i < slots.length ? slots[i] : null;
      assert(
        l.heightPx >= kPlanTimeCardMinHeightPx - 0.01,
        'card height ${l.heightPx} < min',
      );
      assert(l.topPx >= 0, 'negative top');
      assert(l.heightPx > 0, 'non-positive height');
      if (slot != null) {
        final expected = _cardHeightPx(slot.durationMin);
        assert(
          (l.heightPx - expected).abs() < 0.51,
          'card height ${l.heightPx} != stable $expected '
          '(duration=${slot.durationMin})',
        );
        if (slot.durationMin <= 10) {
          assert(
            l.heightPx <= kPlanTimeCardMinHeightPx + 0.51,
            '${slot.durationMin}min card inflated to ${l.heightPx} by hour stretch',
          );
        }
      }
    }
    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      assert(
        b.topPx >= a.topPx + a.heightPx + kPlanTimeCardGapPx - 0.5,
        'overlap ${a.task.title} -> ${b.task.title}',
      );
    }
    for (var h = 0; h < grid.visibleHours.length; h++) {
      assert(
        grid.hourHeightsPx[h] <= kPlanTimeMaxReasonableHourHeightPx + 0.5,
        'hour $h height ${grid.hourHeightsPx[h]} exceeds cap',
      );
    }
    for (var h = 0; h < grid.visibleHours.length; h++) {
      final min = h * 60.0 + 30.0;
      final y = grid.yForMinutesFromRangeStart(min);
      final back = grid.minutesFromY(y);
      assert((back - min).abs() < 0.75, 'y/time mismatch at hour $h');
    }
  }
}
