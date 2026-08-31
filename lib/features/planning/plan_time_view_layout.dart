import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';

/// Shared absolute Y coordinate system for Time View cards + hour grid.
///
/// One global [rubberPxPerMinute] maps wall minutes → canvas Y for **both**
/// scheduled cards and hour rail/grid overlays. No per-hour bucket stacking.
class TimeViewYScale {
  TimeViewYScale({
    required this.visibleHours,
    required this.rangeStart,
    required this.totalMinutes,
    required this.rubberPxPerMinute,
    required this.packedBottomPx,
  });

  final List<int> visibleHours;
  final int rangeStart;
  final double totalMinutes;
  final double rubberPxPerMinute;
  final double packedBottomPx;

  /// Legacy alias used across [planning_view.dart].
  List<double> get rubberPxPerMinuteByHour =>
      List<double>.filled(visibleHours.length, rubberPxPerMinute);

  List<double> get hourHeightsPx =>
      List<double>.filled(visibleHours.length, rubberPxPerMinute * 60);

  List<double> get hourTopsPx => List<double>.generate(
        visibleHours.length,
        (i) => yForMinute(i * 60.0),
      );

  List<double> get hourHeights => hourHeightsPx;
  List<double> get hourTops => hourTopsPx;

  double get hourBandHeightPx => rubberPxPerMinute * 60;

  double get totalHeightPx => math.max(
        totalMinutes * rubberPxPerMinute + kPlanTimeHourVerticalPaddingPx,
        packedBottomPx + kPlanTimeHourVerticalPaddingPx,
      );

  double pxPerMinuteAtHourIndex(int hourIndex) => rubberPxPerMinute;

  int hourIndexForMinutesFromRangeStart(double minutesFromRangeStart) {
    final m = minutesFromRangeStart.clamp(0, totalMinutes - 0.001);
    return (m / 60.0).floor().clamp(0, visibleHours.length - 1);
  }

  /// Absolute Y for minutes from the visible range start (0 = first hour).
  double yForMinute(double minuteFromRangeStart) =>
      minuteFromRangeStart.clamp(0, totalMinutes) * rubberPxPerMinute;

  double yForMinutesFromRangeStart(double minutesFromRangeStart) =>
      yForMinute(minutesFromRangeStart);

  double minuteForY(double y) {
    if (rubberPxPerMinute <= 0) return 0;
    return (y / rubberPxPerMinute).clamp(0, totalMinutes);
  }

  double minutesFromY(double y) => minuteForY(y);

  /// Hour grid / rail line for extended hour at [visibleHours] index.
  double hourLineY(int hourIndex) => yForMinute(hourIndex * 60.0);

  void logHourLine(int hourIndex) {
    if (hourIndex < 0 || hourIndex >= visibleHours.length) return;
    final minute = hourIndex * 60;
    final hour = visibleHours[hourIndex];
    final label =
        '${hour.toString().padLeft(2, '0')}:00';
    _logTimeYScale(
      'minute=$minute label=$label y=${hourLineY(hourIndex).toStringAsFixed(1)}',
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

/// Pure Time View geometry: global rubber scale + sequential card packing.
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

  static double _basePxPerMinute(double baseHourHeightPx) =>
      baseHourHeightPx / 60.0;

  static double _requiredRubberPxPerMinute(int durationMin) {
    final d = math.max(kPlanTimeMinDurationMinutes, durationMin);
    if (durationMin <= kPlanTimeMinDurationMinutes) {
      return kPlanTimeMinCardHeightPx / d;
    }
    return 1.0;
  }

  /// Scheduled slot height from duration × rubber scale (TIME_VIEW_CARD_SLOT_HEIGHT_FROM_DURATION).
  static double scheduledSlotHeightPx(
    int durationMin,
    double rubberPxPerMinute,
  ) {
    final timeTruth = durationMin * rubberPxPerMinute;
    if (durationMin <= kPlanTimeMinDurationMinutes) {
      return math.max(timeTruth, kPlanTimeMinCardHeightPx);
    }
    return timeTruth;
  }

  static double _cardHeightPx(int durationMin, double rubberPxPerMinute) =>
      scheduledSlotHeightPx(durationMin, rubberPxPerMinute);

  static bool _wallAdjacent(double prevEndMin, double nextStartMin) =>
      (nextStartMin - prevEndMin).abs() < 0.01;

  static double _packedBottomPx({
    required List<_PlanTimeViewCardSlot> sorted,
    required double rubberPxPerMinute,
  }) {
    if (sorted.isEmpty) return 0;
    double? prevBottom;
    double? prevEndMin;
    var maxBottom = 0.0;
    for (final c in sorted) {
      final top = _cardTopPx(
        slot: c,
        rubberPxPerMinute: rubberPxPerMinute,
        prevBottom: prevBottom,
        prevEndMin: prevEndMin,
      );
      final bottom = top + _cardHeightPx(c.durationMin, rubberPxPerMinute);
      maxBottom = math.max(maxBottom, bottom);
      prevBottom = bottom;
      prevEndMin = c.endMin;
    }
    return maxBottom;
  }

  static double _cardTopPx({
    required _PlanTimeViewCardSlot slot,
    required double rubberPxPerMinute,
    required double? prevBottom,
    required double? prevEndMin,
  }) {
    final idealTop = slot.startMin * rubberPxPerMinute;
    if (prevEndMin != null &&
        prevBottom != null &&
        _wallAdjacent(prevEndMin, slot.startMin)) {
      return prevBottom;
    }
    return idealTop;
  }

  /// Minimum rubber so a wall-positioned card clears packed 4px gaps before it.
  static double _minPpmForPackedToWallClearance({
    required List<_PlanTimeViewCardSlot> sorted,
  }) => 0.0;

  static double _resolveGlobalRubberPxPerMinute({
    required List<_PlanTimeViewCardSlot> slots,
    required double baseHourHeightPx,
    required double totalMinutes,
  }) {
    var ppm = _basePxPerMinute(baseHourHeightPx);
    for (final c in slots) {
      ppm = math.max(ppm, _requiredRubberPxPerMinute(c.durationMin));
    }
    ppm = math.max(
      ppm,
      _minPpmForPackedToWallClearance(sorted: slots),
    );
    if (totalMinutes <= 0) return ppm;

    for (var iter = 0; iter < 24; iter++) {
      final packedBottom = _packedBottomPx(
        sorted: slots,
        rubberPxPerMinute: ppm,
      );
      final neededPpm = packedBottom / totalMinutes;
      if (neededPpm > ppm + 0.0001) {
        ppm = neededPpm;
      } else {
        break;
      }
    }
    final maxPpm = kPlanTimeMaxHourHeightPx / 60.0;
    return ppm.clamp(_basePxPerMinute(baseHourHeightPx), maxPpm);
  }

  static ({
    TimeViewYScale grid,
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

    final ppm = _resolveGlobalRubberPxPerMinute(
      slots: slots,
      baseHourHeightPx: baseH,
      totalMinutes: totalMinutes,
    );
    final packedBottom = _packedBottomPx(
      sorted: slots,
      rubberPxPerMinute: ppm,
    );

    final yScale = TimeViewYScale(
      visibleHours: visibleHours,
      rangeStart: rangeStart,
      totalMinutes: totalMinutes,
      rubberPxPerMinute: ppm,
      packedBottomPx: packedBottom,
    );

    for (var i = 0; i < visibleHours.length; i++) {
      yScale.logHourLine(i);
    }

    _logTimeLayout(
      'TIME_LAYOUT_SCALE',
      'rubberPxPerMinute=${ppm.toStringAsFixed(3)} '
      'totalMinutes=$totalMinutes canvasHeight=${yScale.totalHeightPx.toStringAsFixed(1)}',
    );

    final layouts = _placeCards(slots, yScale);
    assertPlanTimeViewLayoutDebug(yScale: yScale, layouts: layouts, slots: slots);
    return (grid: yScale, layouts: layouts);
  }

  static List<PlanTimeViewBlockLayout> _placeCards(
    List<_PlanTimeViewCardSlot> slots,
    TimeViewYScale yScale,
  ) {
    final layouts = <PlanTimeViewBlockLayout>[];
    final ppm = yScale.rubberPxPerMinute;
    double? globalPrevEndMin;
    double? globalPrevBottom;

    for (final slot in slots) {
      final heightPx = _cardHeightPx(slot.durationMin, ppm);

      var topPx = _cardTopPx(
        slot: slot,
        rubberPxPerMinute: ppm,
        prevBottom: globalPrevBottom,
        prevEndMin: globalPrevEndMin,
      );
      if (globalPrevEndMin != null &&
          globalPrevBottom != null &&
          _wallAdjacent(globalPrevEndMin, slot.startMin)) {
        _logTimeLayout(
          'TIME_LAYOUT_PACK',
          'adjacent previous=${layouts.last.task.planRowIdForBackend} '
          'current=${slot.task.planRowIdForBackend} visualGap=0',
        );
      }

      globalPrevEndMin = slot.endMin;
      globalPrevBottom = topPx + heightPx;

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
      {
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
      final hourSlots = slots
          .where((s) => s.startMin >= hourStartMin && s.startMin < hourEndMin)
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
        final inside =
            cardTop < hourY - 0.5 && hourY < cardBottom - 0.5;

        if (inside) {
          _logTimeLayout(
            'TIME_LAYOUT_ASSERT',
            'hourLineInsideCrossingCard hour=$hourClock card=${slot.task.planRowIdForBackend} '
            'start=${slot.startMin} end=${slot.endMin}',
          );
        } else if (hourY >= cardBottom - 0.5) {
          _logTimeLayout(
            'TIME_LAYOUT_NOTE',
            'hourLineAfterPiecewiseCard hour=$hourClock '
            'card=${slot.startMin}-${slot.endMin} hourY=${hourY.toStringAsFixed(1)} '
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

    final ppm = yScale.rubberPxPerMinute;

    for (var i = 0; i < layouts.length; i++) {
      final l = layouts[i];
      final slot = slots[i];
      final durationMin = slot.durationMin;
      final expected = _cardHeightPx(durationMin, ppm);

      assert(l.heightPx >= kPlanTimeCardMinHeightPx - 0.01, 'card height < min');
      assert(l.topPx >= 0, 'negative top');
      assert(l.heightPx > 0, 'non-positive height');
      assert(
        (l.heightPx - expected).abs() < 0.51,
        'TIME_VIEW_DURATION_VISUAL_MISMATCH_BLOCKED: height ${l.heightPx} != slot $expected',
      );

      final packedAfterAdjacent =
          i > 0 && _wallAdjacent(slots[i - 1].endMin, slot.startMin);
      final idealTop = yScale.yForMinute(slot.startMin);

      if (!packedAfterAdjacent) {
        assert(
          (l.topPx - idealTop).abs() < 1.5,
          'unpacked card top must match wall start minute',
        );
      }

      if (durationMin < 60 && !packedAfterAdjacent) {
        final hourIdx = (slot.endMin / 60).floor();
        if (slot.endMin < (hourIdx + 1) * 60 - 0.01) {
          final cardEndY = l.topPx + l.heightPx;
          final nextHourY = yScale.yForMinute((hourIdx + 1) * 60.0);
          final remaining = nextHourY - cardEndY;
          if (remaining > 0.5 && durationMin >= 45) {
            _logTimeLayout(
              'TIME_LAYOUT_EMPTY_SLOT',
              'hour=$hourIdx remaining=${remaining.toStringAsFixed(1)} '
              'cardEnd=${cardEndY.toStringAsFixed(1)} nextHour=${nextHourY.toStringAsFixed(1)}',
            );
          }
        }
      }
    }

    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      final slotA = slots[i];
      final slotB = slots[i + 1];
      if (_wallAdjacent(slotA.endMin, slotB.startMin)) {
        assert(
          (b.topPx - (a.topPx + a.heightPx + kPlanTimeCardGapPx)).abs() < 0.51,
          'adjacent gap must be ${kPlanTimeCardGapPx}px',
        );
      } else if (slotB.startMin > slotA.endMin + 0.01) {
        assert(
          b.topPx >= a.topPx + a.heightPx - 0.5,
          'overlap ${a.task.title} -> ${b.task.title}',
        );
      }
    }

    for (var h = 0; h < yScale.visibleHours.length; h++) {
      assert(
        yScale.hourBandHeightPx <= kPlanTimeMaxReasonableHourHeightPx + 0.5,
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
