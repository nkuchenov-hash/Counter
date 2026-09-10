import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';

/// Shared piecewise Y coordinate system for Time View cards + hour grid.
///
/// Every wall-clock hour starts at the normal base height. Only an hour whose
/// cards cannot fit at that base density is stretched. Other hours keep their
/// normal scale, so one short/dense block never magnifies the whole day.
class TimeViewYScale {
  TimeViewYScale({
    required this.visibleHours,
    required this.rangeStart,
    required this.totalMinutes,
    required List<double> hourHeightsPx,
    required this.packedBottomPx,
  }) : hourHeightsPx = List<double>.unmodifiable(hourHeightsPx),
       assert(hourHeightsPx.length == visibleHours.length);

  final List<int> visibleHours;
  final int rangeStart;
  final double totalMinutes;
  final List<double> hourHeightsPx;
  final double packedBottomPx;

  late final List<double> hourTopsPx = _buildHourTops(hourHeightsPx);

  static List<double> _buildHourTops(List<double> heights) {
    var y = 0.0;
    return List<double>.generate(heights.length, (index) {
      final top = y;
      y += heights[index];
      return top;
    }, growable: false);
  }

  /// Legacy aliases kept for existing Time View call sites/tests.
  List<double> get rubberPxPerMinuteByHour => [
    for (final height in hourHeightsPx) height / 60.0,
  ];

  List<double> get hourHeights => hourHeightsPx;
  List<double> get hourTops => hourTopsPx;

  /// Compatibility getter only. Piecewise callers must use
  /// [pxPerMinuteAtHourIndex].
  double get rubberPxPerMinute =>
      hourHeightsPx.isEmpty ? 0.0 : hourHeightsPx.first / 60.0;

  /// Compatibility getter only. The canvas uses [hourHeightPxAtIndex].
  double get hourBandHeightPx =>
      hourHeightsPx.isEmpty ? 0.0 : hourHeightsPx.first;

  double hourHeightPxAtIndex(int hourIndex) =>
      hourHeightsPx[hourIndex.clamp(0, hourHeightsPx.length - 1)];

  double get _hourGridBottomPx {
    if (hourHeightsPx.isEmpty) return 0.0;
    return hourTopsPx.last + hourHeightsPx.last;
  }

  double get totalHeightPx =>
      math.max(_hourGridBottomPx, packedBottomPx) +
      kPlanTimeHourVerticalPaddingPx;

  double pxPerMinuteAtHourIndex(int hourIndex) {
    if (hourHeightsPx.isEmpty) return 0.0;
    return hourHeightPxAtIndex(hourIndex) / 60.0;
  }

  int hourIndexForMinutesFromRangeStart(double minutesFromRangeStart) {
    if (visibleHours.isEmpty) return 0;
    final m = minutesFromRangeStart.clamp(0.0, totalMinutes - 0.001);
    return (m / 60.0).floor().clamp(0, visibleHours.length - 1);
  }

  /// Piecewise absolute Y for minutes from visible-range start.
  double yForMinute(double minuteFromRangeStart) {
    if (hourHeightsPx.isEmpty || totalMinutes <= 0) return 0.0;
    final m = minuteFromRangeStart.clamp(0.0, totalMinutes).toDouble();
    if (m >= totalMinutes) return _hourGridBottomPx;
    final hourIndex = hourIndexForMinutesFromRangeStart(m);
    final localMinute = m - hourIndex * 60.0;
    return hourTopsPx[hourIndex] +
        localMinute * pxPerMinuteAtHourIndex(hourIndex);
  }

  double yForMinutesFromRangeStart(double minutesFromRangeStart) =>
      yForMinute(minutesFromRangeStart);

  double minuteForY(double y) {
    if (hourHeightsPx.isEmpty || totalMinutes <= 0) return 0.0;
    final yy = y.clamp(0.0, _hourGridBottomPx).toDouble();
    if (yy >= _hourGridBottomPx) return totalMinutes;
    for (var i = 0; i < hourHeightsPx.length; i++) {
      final top = hourTopsPx[i];
      final bottom = top + hourHeightsPx[i];
      if (yy <= bottom || i == hourHeightsPx.length - 1) {
        final ppm = pxPerMinuteAtHourIndex(i);
        if (ppm <= 0) return i * 60.0;
        return (i * 60.0 + (yy - top) / ppm).clamp(0.0, totalMinutes);
      }
    }
    return totalMinutes;
  }

  double minutesFromY(double y) => minuteForY(y);

  /// Hour grid / rail line for extended hour at [visibleHours] index.
  double hourLineY(int hourIndex) {
    if (hourTopsPx.isEmpty) return 0.0;
    return hourTopsPx[hourIndex.clamp(0, hourTopsPx.length - 1)];
  }

  void logHourLine(int hourIndex) {
    if (hourIndex < 0 || hourIndex >= visibleHours.length) return;
    final minute = hourIndex * 60;
    final hour = visibleHours[hourIndex];
    final label = '${hour.toString().padLeft(2, '0')}:00';
    _logTimeYScale(
      'minute=$minute label=$label y=${hourLineY(hourIndex).toStringAsFixed(1)} '
      'height=${hourHeightPxAtIndex(hourIndex).toStringAsFixed(1)}',
    );
  }
}

/// Legacy name retained for [planning_view.dart] call sites.
typedef PlanTimeViewDurationGrid = TimeViewYScale;

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

String? _lastTimeLayoutLogKey;
DateTime? _lastTimeLayoutLogAt;

void _logTimeLayout(String tag, String message) {
  if (!kDebugMode) return;
  final full = '$tag $message';
  final now = DateTime.now();
  if (_lastTimeLayoutLogKey == full &&
      _lastTimeLayoutLogAt != null &&
      now.difference(_lastTimeLayoutLogAt!) <
          const Duration(milliseconds: 120)) {
    return;
  }
  _lastTimeLayoutLogKey = full;
  _lastTimeLayoutLogAt = now;
  debugPrint('[$tag] $message');
}

void _logTimeYScale(String message) => _logTimeLayout('TIME_Y_SCALE', message);

/// Pure Time View geometry: stable card sizes + bounded per-hour stretch.
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

  /// Compatibility surface retained for existing callers. Card height is a
  /// stable density metric; stretching an hour must not enlarge every card.
  static double scheduledSlotHeightPx(
    int durationMin,
    double rubberPxPerMinute,
  ) => planTimeCardRenderedHeightPxForDuration(durationMin);

  static double _cardHeightPx(int durationMin) => math
      .max(
        kPlanTimeCardMinHeightPx,
        planTimeCardRenderedHeightPxForDuration(durationMin),
      )
      .toDouble();

  static bool _wallAdjacent(double prevEndMin, double nextStartMin) =>
      (nextStartMin - prevEndMin).abs() < 0.01;

  /// Resolve only the wall-clock hours that need extra visual room.
  ///
  /// Wall time is the source of truth: cards are never moved away from their
  /// scheduled minute to manufacture visual clearance. When stable card
  /// geometry needs more room, the affected hour(s) stretch through the same
  /// piecewise time/Y scale used by pointer-to-time conversion.
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
      // The hour only needs to stretch enough for the canonical minimum
      // rendered card height. Actual card height is derived from the shared
      // wall-time Y span below, so a wall-adjacent boundary can stay exactly
      // kPlanTimeCardGapPx instead of becoming an arbitrarily large empty gap.
      final requiredSpanPx =
          kPlanTimeCardMinHeightPx +
          (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0);
      final wallSpanMinutes = math.max(1.0, slot.endMin - slot.startMin);
      final requiredHourHeight = (requiredSpanPx / wallSpanMinutes * 60.0)
          .clamp(baseHourHeightPx, kPlanTimeMaxHourHeightPx)
          .toDouble();

      final firstHour = (visibleStart / 60.0).floor().clamp(0, hourCount - 1);
      final lastMinute = math.max(visibleStart, visibleEnd - 0.001);
      final lastHour = (lastMinute / 60.0).floor().clamp(0, hourCount - 1);
      for (var hour = firstHour; hour <= lastHour; hour++) {
        heights[hour] = math.max(heights[hour], requiredHourHeight);
      }
    }
    return heights;
  }

  static ({TimeViewYScale grid, List<PlanTimeViewBlockLayout> layouts})
  compute({
    required List<TimeModeProjectedPlan> projections,
    required List<int> visibleHours,
    required int rangeStart,
    required double Function(TimeModeProjectedPlan proj) startMinOf,
    required double Function(TimeModeProjectedPlan proj) endMinOf,
    double? baseHourHeightPx,
  }) {
    final baseH =
        baseHourHeightPx ?? PlanTimeViewLayoutCalculator.baseHourHeightPx();
    final totalMinutes = visibleHours.length * 60.0;

    final slots = <_PlanTimeViewCardSlot>[];
    for (final proj in projections) {
      final startMin = startMinOf(proj);
      final endMin = endMinOf(proj);
      final dur = math.max(
        kPlanTimeMinDurationMinutes,
        (endMin - startMin).round(),
      );
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

    final hourHeightsPx = _resolveHourHeightsPx(
      slots: slots,
      hourCount: visibleHours.length,
      baseHourHeightPx: baseH,
    );
    final provisionalScale = TimeViewYScale(
      visibleHours: visibleHours,
      rangeStart: rangeStart,
      totalMinutes: totalMinutes,
      hourHeightsPx: hourHeightsPx,
      packedBottomPx: 0,
    );
    final layouts = _placeCards(slots, provisionalScale);
    final packedBottom = layouts.fold<double>(
      0.0,
      (bottom, layout) => math.max(bottom, layout.topPx + layout.heightPx),
    );
    final yScale = TimeViewYScale(
      visibleHours: visibleHours,
      rangeStart: rangeStart,
      totalMinutes: totalMinutes,
      hourHeightsPx: hourHeightsPx,
      packedBottomPx: packedBottom,
    );

    for (var i = 0; i < visibleHours.length; i++) {
      yScale.logHourLine(i);
    }

    _logTimeLayout(
      'TIME_LAYOUT_SCALE',
      'hourHeights=${hourHeightsPx.map((h) => h.toStringAsFixed(1)).join(',')} '
          'totalMinutes=$totalMinutes canvasHeight=${yScale.totalHeightPx.toStringAsFixed(1)}',
    );

    assertPlanTimeViewLayoutDebug(
      yScale: yScale,
      layouts: layouts,
      slots: slots,
    );
    return (grid: yScale, layouts: layouts);
  }

  static List<PlanTimeViewBlockLayout> _placeCards(
    List<_PlanTimeViewCardSlot> slots,
    TimeViewYScale yScale,
  ) {
    final layouts = <PlanTimeViewBlockLayout>[];

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final topPx = yScale.yForMinute(slot.startMin);
      final endPx = yScale.yForMinute(slot.endMin);
      final hasAdjacentNext =
          i + 1 < slots.length &&
          _wallAdjacent(slot.endMin, slots[i + 1].startMin);
      final boundaryGapPx = hasAdjacentNext ? kPlanTimeCardGapPx : 0.0;
      final heightPx = math
          .max(kPlanTimeCardMinHeightPx, endPx - topPx - boundaryGapPx)
          .toDouble();

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

  static void _logEmptySlots({
    required TimeViewYScale yScale,
    required List<_PlanTimeViewCardSlot> slots,
    required List<int> visibleHours,
  }) {
    if (!kDebugMode) return;
    for (var h = 0; h < visibleHours.length; h++) {
      final hourStartMin = h * 60.0;
      final hourEndMin = hourStartMin + 60.0;
      final hourSlots =
          slots
              .where(
                (s) => s.startMin >= hourStartMin && s.startMin < hourEndMin,
              )
              .toList()
            ..sort((a, b) => a.startMin.compareTo(b.startMin));

      if (hourSlots.isEmpty) continue;

      final lastEnd = hourSlots.map((s) => s.endMin).reduce(math.max);
      if (lastEnd >= hourEndMin - 0.01) continue;

      final emptyTop = yScale.yForMinute(lastEnd);
      final emptyBottom = yScale.yForMinute(hourEndMin);
      if (emptyBottom - emptyTop < 0.5) continue;

      _logTimeLayout(
        'TIME_LAYOUT_EMPTY_SLOT',
        'hour=${visibleHours[h]} fromMin=${(lastEnd % 60).round()} toMin=60 '
            'top=${emptyTop.toStringAsFixed(1)} bottom=${emptyBottom.toStringAsFixed(1)}',
      );
    }
  }

  static void _assertHourLinesInsideCrossingCards({
    required TimeViewYScale yScale,
    required List<PlanTimeViewBlockLayout> layouts,
    required List<_PlanTimeViewCardSlot> slots,
  }) {
    if (kReleaseMode) return;

    for (var h = 1; h < yScale.visibleHours.length; h++) {
      final hourMinute = h * 60.0;
      final hourY = yScale.hourLineY(h);
      final hourClock = yScale.visibleHours[h];

      for (var i = 0; i < layouts.length; i++) {
        final slot = slots[i];
        final layout = layouts[i];
        if (slot.startMin >= hourMinute - 0.01 ||
            slot.endMin <= hourMinute + 0.01) {
          continue;
        }

        final cardTop = layout.topPx;
        final cardBottom = layout.topPx + layout.heightPx;
        final inside = cardTop < hourY - 0.5 && hourY < cardBottom - 0.5;

        if (inside) {
          _logTimeLayout(
            'TIME_LAYOUT_ASSERT',
            'hourLineInsideCrossingCard hour=$hourClock '
                'card=${slot.task.planRowIdForBackend} '
                'start=${slot.startMin} end=${slot.endMin}',
          );
        } else if (hourY >= cardBottom - 0.5) {
          _logTimeLayout(
            'TIME_LAYOUT_NOTE',
            'hourLineAfterPiecewiseCard hour=$hourClock '
                'card=${slot.startMin}-${slot.endMin} '
                'hourY=${hourY.toStringAsFixed(1)} '
                'cardBottom=${cardBottom.toStringAsFixed(1)}',
          );
        }
      }
    }
  }

  static void assertPlanTimeViewLayoutDebug({
    required TimeViewYScale yScale,
    required List<PlanTimeViewBlockLayout> layouts,
    required List<_PlanTimeViewCardSlot> slots,
  }) {
    if (kReleaseMode) return;

    _logEmptySlots(
      yScale: yScale,
      slots: slots,
      visibleHours: yScale.visibleHours,
    );
    _assertHourLinesInsideCrossingCards(
      yScale: yScale,
      layouts: layouts,
      slots: slots,
    );

    for (var i = 0; i < layouts.length; i++) {
      final layout = layouts[i];
      final slot = slots[i];
      final expectedTop = yScale.yForMinute(slot.startMin);
      final expectedEnd = yScale.yForMinute(slot.endMin);
      final hasAdjacentNext =
          i + 1 < slots.length &&
          _wallAdjacent(slot.endMin, slots[i + 1].startMin);
      final expectedHeight = math
          .max(
            kPlanTimeCardMinHeightPx,
            expectedEnd -
                expectedTop -
                (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0),
          )
          .toDouble();

      assert(
        layout.heightPx >= kPlanTimeCardMinHeightPx - 0.01,
        'card height < min',
      );
      assert(layout.topPx >= 0, 'negative top');
      assert(layout.heightPx > 0, 'non-positive height');
      assert(
        (layout.heightPx - expectedHeight).abs() < 0.51,
        'TIME_VIEW_DURATION_VISUAL_MISMATCH_BLOCKED: '
        'height ${layout.heightPx} != stable $expectedHeight',
      );
      assert(
        (layout.topPx - expectedTop).abs() < 0.51,
        'TIME_VIEW_WALL_START_MISMATCH: '
        'top ${layout.topPx} != wall-time y $expectedTop',
      );
    }

    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      final slotA = slots[i];
      final slotB = slots[i + 1];
      if (slotB.startMin >= slotA.endMin - 0.01) {
        final wallAdjacent = _wallAdjacent(slotA.endMin, slotB.startMin);
        final actualGap = b.topPx - (a.topPx + a.heightPx);
        if (wallAdjacent) {
          assert(
            (actualGap - kPlanTimeCardGapPx).abs() < 0.51,
            'TIME_VIEW_ADJACENT_GAP_MISMATCH: '
            '${a.task.title} -> ${b.task.title}; gap=$actualGap',
          );
        } else {
          assert(
            actualGap >= -0.51,
            'TIME_VIEW_VISUAL_OVERLAP: ${a.task.title} -> ${b.task.title}',
          );
        }
      }
    }

    for (var h = 0; h < yScale.visibleHours.length; h++) {
      assert(
        yScale.hourHeightPxAtIndex(h) <=
            kPlanTimeMaxReasonableHourHeightPx + 0.5,
        'hour band height exceeds cap',
      );
    }

    for (var probe = 0.0; probe <= yScale.totalMinutes; probe += 7) {
      final y = yScale.yForMinute(probe);
      final back = yScale.minuteForY(y);
      assert((back - probe).abs() < 0.75, 'y/time mismatch at minute $probe');
    }
  }
}
