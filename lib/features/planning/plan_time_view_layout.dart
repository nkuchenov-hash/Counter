import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';

/// Duration-true timeline scale with per-hour stretch (P0S Time View).
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

/// Pure Time View geometry: stretchable hours + sequential non-overlapping cards.
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

    for (var hourIdx = 0; hourIdx < visibleHours.length; hourIdx++) {
      final hourStart = hourIdx * 60.0;
      final hourEnd = hourStart + 60.0;
      final inHour = slots
          .where(
            (s) => s.startMin >= hourStart && s.startMin < hourEnd,
          )
          .toList();
      if (inHour.isEmpty) continue;
      hourHeights[hourIdx] = _minimumHourHeightForCards(inHour, hourStart, baseH);
    }

    // Global overlap resolution — bump hour height when adjacent cards collide.
    for (var pass = 0; pass < 24; pass++) {
      final grid = _buildGrid(visibleHours, rangeStart, hourHeights);
      final layouts = _placeCards(slots, grid);
      final overlapIdx = _firstOverlapIndex(layouts);
      if (overlapIdx == null) {
        assertPlanTimeViewLayoutDebug(grid: grid, layouts: layouts);
        return (grid: grid, layouts: layouts);
      }
      final earlier = layouts[overlapIdx];
      final later = layouts[overlapIdx + 1];
      final earlierHourIdx = grid.hourIndexForMinutesFromRangeStart(
        slots[overlapIdx].startMin,
      );
      final laterHourIdx = grid.hourIndexForMinutesFromRangeStart(
        slots[overlapIdx + 1].startMin,
      );
      final bumpIdx = laterHourIdx == earlierHourIdx
          ? laterHourIdx
          : earlierHourIdx;
      hourHeights[bumpIdx] = math.max(
        hourHeights[bumpIdx] + 4.0,
        hourHeights[bumpIdx] * 1.04,
      );
    }

    final grid = _buildGrid(visibleHours, rangeStart, hourHeights);
    final layouts = _placeCards(slots, grid);
    assertPlanTimeViewLayoutDebug(grid: grid, layouts: layouts);
    return (grid: grid, layouts: layouts);
  }

  static double _minimumHourHeightForCards(
    List<_PlanTimeViewCardSlot> cards,
    double hourStartMin,
    double baseHourHeightPx,
  ) {
    var lo = baseHourHeightPx;
    var hi = baseHourHeightPx;

    while (!_hourFits(hi, cards, hourStartMin)) {
      hi *= 1.35;
      if (hi > 4000) break;
    }

    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      if (_hourFits(mid, cards, hourStartMin)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    // Ensure stacked content fits (sequential reflow can exceed time-only height).
    final stacked = _stackedHourContentHeight(hi, cards, hourStartMin);
    return math.max(hi, stacked);
  }

  /// Sequential column height for cards in one hour (min 38px + 2px gaps).
  static double _stackedHourContentHeight(
    double hourHeightPx,
    List<_PlanTimeViewCardSlot> cards,
    double hourStartMin,
  ) {
    if (cards.isEmpty) return hourHeightPx;
    final ppm = hourHeightPx / 60.0;
    double prevBottom = 0;
    for (final c in cards) {
      final relMin = c.startMin - hourStartMin;
      final idealTop = (relMin / 60.0) * hourHeightPx;
      final h = math.max(c.durationMin * ppm, kPlanTimeCardMinHeightPx);
      final top = prevBottom <= 0
          ? idealTop
          : math.max(idealTop, prevBottom + kPlanTimeCardGapPx);
      prevBottom = top + h;
    }
    return prevBottom;
  }

  static bool _hourFits(
    double hourHeightPx,
    List<_PlanTimeViewCardSlot> cards,
    double hourStartMin,
  ) {
    final ppm = hourHeightPx / 60.0;
    double? prevBottom;
    for (final c in cards) {
      final relMin = c.startMin - hourStartMin;
      final idealTop = (relMin / 60.0) * hourHeightPx;
      final h = math.max(c.durationMin * ppm, kPlanTimeCardMinHeightPx);
      final top = prevBottom == null
          ? idealTop
          : math.max(idealTop, prevBottom + kPlanTimeCardGapPx);
      if (prevBottom != null && top < prevBottom + kPlanTimeCardGapPx - 0.01) {
        return false;
      }
      prevBottom = top + h;
    }
    return prevBottom == null || prevBottom <= hourHeightPx + 0.5;
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
    final byHour = <int, List<_PlanTimeViewCardSlot>>{};
    for (final slot in slots) {
      final hourIdx = grid.hourIndexForMinutesFromRangeStart(slot.startMin);
      byHour.putIfAbsent(hourIdx, () => []).add(slot);
    }

    double? globalPrevBottom;
    for (final slot in slots) {
      final hourIdx = grid.hourIndexForMinutesFromRangeStart(slot.startMin);
      final hourStartMin = hourIdx * 60.0;
      final hourTopPx = grid.hourTopsPx[hourIdx];
      final hourHeightPx = grid.hourHeightsPx[hourIdx];
      final ppm = hourHeightPx / 60.0;

      // Sequential reflow within hour: time-anchored tops, pushed down when needed.
      final hourSlots = byHour[hourIdx]!;
      final indexInHour = hourSlots.indexOf(slot);
      var topPx = hourTopPx;
      var heightPx = math.max(
        slot.durationMin * ppm,
        kPlanTimeCardMinHeightPx,
      );
      double prevBottom = hourTopPx;
      for (var i = 0; i <= indexInHour; i++) {
        final s = hourSlots[i];
        final relMin = s.startMin - hourStartMin;
        final idealTop = hourTopPx + (relMin / 60.0) * hourHeightPx;
        final h = math.max(s.durationMin * ppm, kPlanTimeCardMinHeightPx);
        var t = i == 0
            ? idealTop
            : math.max(idealTop, prevBottom + kPlanTimeCardGapPx);
        if (i == 0 && globalPrevBottom != null) {
          t = math.max(t, globalPrevBottom + kPlanTimeCardGapPx);
        }
        prevBottom = t + h;
        if (i == indexInHour) {
          topPx = t;
          heightPx = h;
        }
      }
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

  static int? _firstOverlapIndex(List<PlanTimeViewBlockLayout> layouts) {
    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      if (b.topPx < a.topPx + a.heightPx + kPlanTimeCardGapPx - 0.5) {
        return i;
      }
    }
    return null;
  }

  /// Debug-only layout invariants (Time View acceptance).
  static void assertPlanTimeViewLayoutDebug({
    required PlanTimeViewDurationGrid grid,
    required List<PlanTimeViewBlockLayout> layouts,
  }) {
    if (kReleaseMode) return;
    for (final l in layouts) {
      assert(
        l.heightPx >= kPlanTimeCardMinHeightPx - 0.01,
        'card height ${l.heightPx} < min',
      );
      assert(l.topPx >= 0, 'negative top');
      assert(l.heightPx > 0, 'non-positive height');
    }
    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      assert(
        b.topPx >= a.topPx + a.heightPx + kPlanTimeCardGapPx - 0.5,
        'overlap ${a.task.title} -> ${b.task.title}',
      );
    }
    // y/time round-trip sanity on hour midpoints.
    for (var h = 0; h < grid.visibleHours.length; h++) {
      final min = h * 60.0 + 30.0;
      final y = grid.yForMinutesFromRangeStart(min);
      final back = grid.minutesFromY(y);
      assert((back - min).abs() < 0.75, 'y/time mismatch at hour $h');
    }
  }
}
