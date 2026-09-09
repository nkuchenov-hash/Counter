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

  static double _basePxPerMinute(double baseHourHeightPx) =>
      baseHourHeightPx / 60.0;

  /// Compatibility surface retained for existing callers. Card height is a
  /// stable density metric; stretching an hour must not enlarge every card.
  static double scheduledSlotHeightPx(
    int durationMin,
    double rubberPxPerMinute,
  ) => planTimeCardRenderedHeightPxForDuration(durationMin);

  static double _cardHeightPx(int durationMin) =>
      math.max(
        kPlanTimeCardMinHeightPx,
        planTimeCardRenderedHeightPxForDuration(durationMin),
      ).toDouble();

  static bool _wallAdjacent(double prevEndMin, double nextStartMin) =>
      (nextStartMin - prevEndMin).abs() < 0.01;

  static int _slotStartHourIndex(
    _PlanTimeViewCardSlot slot,
    int hourCount,
  ) {
    if (hourCount <= 1) return 0;
    return (slot.startMin / 60.0).floor().clamp(0, hourCount - 1);
  }

  /// Resolve each hour independently. Normal hours stay at [baseHourHeightPx].
  /// A dense hour grows only enough to fit its own stable card rectangles and
  /// canonical 4px visual gaps, capped by [kPlanTimeMaxHourHeightPx].
  static List<double> _resolveHourHeightsPx({
    required List<_PlanTimeViewCardSlot> slots,
    required int hourCount,
    required double baseHourHeightPx,
  }) {
    final heights = List<double>.filled(hourCount, baseHourHeightPx);
    final basePpm = _basePxPerMinute(baseHourHeightPx);

    for (var hourIndex = 0; hourIndex < hourCount; hourIndex++) {
      final hourStartMin = hourIndex * 60.0;
      final hourEndMin = hourStartMin + 60.0;
      final hourSlots = slots
          .where(
            (slot) =>
                _slotStartHourIndex(slot, hourCount) == hourIndex &&
                slot.startMin < hourEndMin,
          )
          .toList(growable: false);
      if (hourSlots.isEmpty) continue;

      double? prevBottom;
      double? prevEndMin;
      var requiredHeight = baseHourHeightPx;

      for (final slot in hourSlots) {
        final localStartMin = (slot.startMin - hourStartMin).clamp(0.0, 60.0);
        final idealTop = localStartMin * basePpm;
        var top = idealTop;
        if (prevBottom != null && prevEndMin != null) {
          if (_wallAdjacent(prevEndMin, slot.startMin)) {
            top = prevBottom + kPlanTimeCardGapPx;
          } else if (top < prevBottom + kPlanTimeCardGapPx) {
            top = prevBottom + kPlanTimeCardGapPx;
          }
        }
        final bottom = top + _cardHeightPx(slot.durationMin);

        // A card ending inside this wall-clock hour must fit completely in the
        // hour. Cards that genuinely cross the hour boundary may continue into
        // the next hour and do not inflate their start hour just for crossing.
        if (slot.endMin <= hourEndMin + 0.01) {
          requiredHeight = math.max(requiredHeight, bottom);
        }
        prevBottom = bottom;
        prevEndMin = slot.endMin;
      }

      heights[hourIndex] = requiredHeight
          .clamp(baseHourHeightPx, kPlanTimeMaxHourHeightPx)
          .toDouble();
    }
    return heights;
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
    double? globalPrevEndMin;
    double? globalPrevBottom;

    for (final slot in slots) {
      final heightPx = _cardHeightPx(slot.durationMin);
      final idealTop = yScale.yForMinute(slot.startMin);
      var topPx = idealTop;

      if (globalPrevEndMin != null && globalPrevBottom != null) {
        if (_wallAdjacent(globalPrevEndMin, slot.startMin)) {
          topPx = globalPrevBottom + kPlanTimeCardGapPx;
          _logTimeLayout(
            'TIME_LAYOUT_PACK',
            'adjacent previous=${layouts.last.task.planRowIdForBackend} '
            'current=${slot.task.planRowIdForBackend} '
            'visualGap=${kPlanTimeCardGapPx.toStringAsFixed(0)}',
          );
        } else if (topPx < globalPrevBottom + kPlanTimeCardGapPx) {
          topPx = globalPrevBottom + kPlanTimeCardGapPx;
          _logTimeLayout(
            'TIME_LAYOUT_PACK',
            'visualCollision previous=${layouts.last.task.planRowIdForBackend} '
            'current=${slot.task.planRowIdForBackend}',
          );
        }
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
      final expectedHeight = _cardHeightPx(slot.durationMin);

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

      var expectedTop = yScale.yForMinute(slot.startMin);
      if (i > 0) {
        final prevLayout = layouts[i - 1];
        final prevSlot = slots[i - 1];
        final prevBottom = prevLayout.topPx + prevLayout.heightPx;
        if (_wallAdjacent(prevSlot.endMin, slot.startMin)) {
          expectedTop = prevBottom + kPlanTimeCardGapPx;
        } else if (expectedTop < prevBottom + kPlanTimeCardGapPx) {
          expectedTop = prevBottom + kPlanTimeCardGapPx;
        }
      }
      assert(
        (layout.topPx - expectedTop).abs() < 0.51,
        'card top must match piecewise wall position or packed visual clearance',
      );
    }

    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      assert(
        b.topPx >= a.topPx + a.heightPx + kPlanTimeCardGapPx - 0.51,
        'overlap ${a.task.title} -> ${b.task.title}',
      );
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
