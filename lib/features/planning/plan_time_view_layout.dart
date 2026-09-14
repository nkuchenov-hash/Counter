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
    required this.packedBottomPx,
    List<double>? hourHeightsPx,
    List<double>? minuteBreaks,
    List<double>? yBreaks,
  }) {
    if (minuteBreaks != null && yBreaks != null) {
      assert(minuteBreaks.length == yBreaks.length);
      assert(minuteBreaks.length >= 2);
      _minuteBreaks = List<double>.unmodifiable(minuteBreaks);
      _yBreaks = List<double>.unmodifiable(yBreaks);
    } else {
      final heights =
          hourHeightsPx ??
          List<double>.filled(
            visibleHours.length,
            kPlanTimeViewBaseHourHeightMinPx,
          );
      assert(heights.length == visibleHours.length);
      final minutes = <double>[0];
      final ys = <double>[0];
      var y = 0.0;
      for (var i = 0; i < heights.length; i++) {
        y += heights[i];
        minutes.add((i + 1) * 60.0);
        ys.add(y);
      }
      _minuteBreaks = List<double>.unmodifiable(minutes);
      _yBreaks = List<double>.unmodifiable(ys);
    }
  }

  final List<int> visibleHours;
  final int rangeStart;
  final double totalMinutes;
  final double packedBottomPx;

  late final List<double> _minuteBreaks;
  late final List<double> _yBreaks;

  late final List<double> hourTopsPx = List<double>.generate(
    visibleHours.length,
    (index) => yForMinute(index * 60.0),
    growable: false,
  );

  late final List<double> hourHeightsPx = List<double>.generate(
    visibleHours.length,
    (index) =>
        yForMinute((index + 1) * 60.0) - yForMinute(index * 60.0),
    growable: false,
  );

  /// Legacy aliases kept for existing Time View call sites/tests.
  List<double> get rubberPxPerMinuteByHour => [
    for (final height in hourHeightsPx) height / 60.0,
  ];

  List<double> get hourHeights => hourHeightsPx;
  List<double> get hourTops => hourTopsPx;

  double get rubberPxPerMinute =>
      hourHeightsPx.isEmpty ? 0.0 : hourHeightsPx.first / 60.0;

  double get hourBandHeightPx =>
      hourHeightsPx.isEmpty ? 0.0 : hourHeightsPx.first;

  double hourHeightPxAtIndex(int hourIndex) =>
      hourHeightsPx[hourIndex.clamp(0, hourHeightsPx.length - 1)];

  double get _hourGridBottomPx => _yBreaks.isEmpty ? 0.0 : _yBreaks.last;

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

  int _segmentIndexForMinute(double minute) {
    var low = 0;
    var high = _minuteBreaks.length - 2;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final start = _minuteBreaks[mid];
      final end = _minuteBreaks[mid + 1];
      if (minute < start) {
        high = mid - 1;
      } else if (minute >= end) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return (low - 1).clamp(0, _minuteBreaks.length - 2);
  }

  int _segmentIndexForY(double y) {
    var low = 0;
    var high = _yBreaks.length - 2;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final start = _yBreaks[mid];
      final end = _yBreaks[mid + 1];
      if (y < start) {
        high = mid - 1;
      } else if (y >= end) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return (low - 1).clamp(0, _yBreaks.length - 2);
  }

  /// Canonical piecewise absolute Y for minutes from visible-range start.
  ///
  /// Breakpoints may exist inside an hour at plan boundaries. A short plan can
  /// therefore get the pixels it needs without inflating the remaining
  /// 50 minutes of the same wall-clock hour.
  double yForMinute(double minuteFromRangeStart) {
    if (_minuteBreaks.length < 2 || totalMinutes <= 0) return 0.0;
    final m = minuteFromRangeStart.clamp(0.0, totalMinutes).toDouble();
    if (m >= totalMinutes) return _hourGridBottomPx;
    final i = _segmentIndexForMinute(m);
    final startMin = _minuteBreaks[i];
    final endMin = _minuteBreaks[i + 1];
    final startY = _yBreaks[i];
    final endY = _yBreaks[i + 1];
    final spanMin = endMin - startMin;
    if (spanMin <= 0) return startY;
    final t = (m - startMin) / spanMin;
    return startY + (endY - startY) * t;
  }

  double yForMinutesFromRangeStart(double minutesFromRangeStart) =>
      yForMinute(minutesFromRangeStart);

  double minuteForY(double y) {
    if (_yBreaks.length < 2 || totalMinutes <= 0) return 0.0;
    final yy = y.clamp(0.0, _hourGridBottomPx).toDouble();
    if (yy >= _hourGridBottomPx) return totalMinutes;
    final i = _segmentIndexForY(yy);
    final startY = _yBreaks[i];
    final endY = _yBreaks[i + 1];
    final startMin = _minuteBreaks[i];
    final endMin = _minuteBreaks[i + 1];
    final spanY = endY - startY;
    if (spanY <= 0) return startMin;
    final t = (yy - startY) / spanY;
    return (startMin + (endMin - startMin) * t).clamp(
      0.0,
      totalMinutes,
    );
  }

  double minutesFromY(double y) => minuteForY(y);

  /// Hour grid / rail line in the same local piecewise scale as plan cards.
  double hourLineY(int hourIndex) {
    if (visibleHours.isEmpty) return 0.0;
    return yForMinute(
      hourIndex.clamp(0, visibleHours.length - 1) * 60.0,
    );
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

  /// Build a local piecewise wall-time scale.
  ///
  /// Each plan interval gets only the pixel density required by its canonical
  /// duration-responsive card. Empty time keeps the normal base density. This
  /// prevents a 10-minute task from stretching an entire hour and making a
  /// following 30/45-minute task unnecessarily huge.
  static ({List<double> minuteBreaks, List<double> yBreaks})
  _buildLocalScaleProfile({
    required List<_PlanTimeViewCardSlot> slots,
    required double totalMinutes,
    required double baseHourHeightPx,
  }) {
    final basePxPerMinute = baseHourHeightPx / 60.0;
    final breakSet = <double>{0.0, totalMinutes};

    for (var minute = 60.0; minute < totalMinutes; minute += 60.0) {
      breakSet.add(minute);
    }
    for (final slot in slots) {
      breakSet.add(slot.startMin.clamp(0.0, totalMinutes).toDouble());
      breakSet.add(slot.endMin.clamp(0.0, totalMinutes).toDouble());
    }

    final minuteBreaks = breakSet.toList()..sort();
    final yBreaks = <double>[0.0];
    var y = 0.0;

    for (var segmentIndex = 0;
        segmentIndex < minuteBreaks.length - 1;
        segmentIndex++) {
      final segmentStart = minuteBreaks[segmentIndex];
      final segmentEnd = minuteBreaks[segmentIndex + 1];
      final segmentMinutes = segmentEnd - segmentStart;
      if (segmentMinutes <= 0) {
        yBreaks.add(y);
        continue;
      }

      var pxPerMinute = basePxPerMinute;
      for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
        final slot = slots[slotIndex];
        if (slot.endMin <= segmentStart + 0.001 ||
            slot.startMin >= segmentEnd - 0.001) {
          continue;
        }
        final hasAdjacentNext =
            slotIndex + 1 < slots.length &&
            _wallAdjacent(slot.endMin, slots[slotIndex + 1].startMin);
        final desiredSpanPx =
            _cardHeightPx(slot.durationMin) +
            (hasAdjacentNext ? kPlanTimeCardGapPx : 0.0);
        final wallSpanMinutes = math.max(1.0, slot.endMin - slot.startMin);
        pxPerMinute = math.max(
          pxPerMinute,
          desiredSpanPx / wallSpanMinutes,
        );
      }

      y += segmentMinutes * pxPerMinute;
      yBreaks.add(y);
    }

    return (
      minuteBreaks: List<double>.unmodifiable(minuteBreaks),
      yBreaks: List<double>.unmodifiable(yBreaks),
    );
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

    final scaleProfile = _buildLocalScaleProfile(
      slots: slots,
      totalMinutes: totalMinutes,
      baseHourHeightPx: baseH,
    );
    final provisionalScale = TimeViewYScale(
      visibleHours: visibleHours,
      rangeStart: rangeStart,
      totalMinutes: totalMinutes,
      minuteBreaks: scaleProfile.minuteBreaks,
      yBreaks: scaleProfile.yBreaks,
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
      minuteBreaks: scaleProfile.minuteBreaks,
      yBreaks: scaleProfile.yBreaks,
      packedBottomPx: packedBottom,
    );
    final hourHeightsPx = yScale.hourHeightsPx;

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
