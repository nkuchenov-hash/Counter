import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';

/// Duration-true timeline scale with per-hour **rubber** px-per-minute (P0 Time View).
///
/// Three separate concepts:
/// - **Time scale:** wall minutes → Y via [PlanTimeViewDurationGrid] (hour boundaries).
/// - **Card visual height:** `durationMinutes * rubberPxPerMinute` (never fills unused hour).
/// - **Card packing:** wall-adjacent cards get [kPlanTimeCardGapPx]; real schedule gaps stay proportional.
class PlanTimeViewDurationGrid {
  PlanTimeViewDurationGrid({
    required this.visibleHours,
    required this.rangeStart,
    required this.hourHeightsPx,
    required this.hourTopsPx,
    required this.rubberPxPerMinuteByHour,
  });

  final List<int> visibleHours;
  final int rangeStart;
  final List<double> hourHeightsPx;
  final List<double> hourTopsPx;

  /// Rubber scale per visible hour band (`hourHeight / 60`).
  final List<double> rubberPxPerMinuteByHour;

  List<double> get hourHeights => hourHeightsPx;

  List<double> get hourTops => hourTopsPx;

  double get totalMinutes => visibleHours.length * 60.0;

  double get totalHeightPx {
    if (hourHeightsPx.isEmpty) return 0;
    return hourTopsPx.last + hourHeightsPx.last;
  }

  double pxPerMinuteAtHourIndex(int hourIndex) {
    if (hourIndex < 0 || hourIndex >= rubberPxPerMinuteByHour.length) return 0;
    return rubberPxPerMinuteByHour[hourIndex];
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

String? _lastTimeLayoutLogKey;
DateTime? _lastTimeLayoutLogAt;

void _logTimeLayout(String message) {
  if (!kDebugMode) return;
  final now = DateTime.now();
  if (_lastTimeLayoutLogKey == message &&
      _lastTimeLayoutLogAt != null &&
      now.difference(_lastTimeLayoutLogAt!) <
          const Duration(milliseconds: 120)) {
    return;
  }
  _lastTimeLayoutLogKey = message;
  _lastTimeLayoutLogAt = now;
  debugPrint('[TIME_LAYOUT] $message');
}

/// Pure Time View geometry: rubber minute scale + sequential card packing.
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

  /// Minimum rubber ppm so card meets CardPlan min height for its duration.
  static double _requiredRubberPxPerMinute(int durationMin) {
    final minHeight = planTimeCardRenderedHeightPxForDuration(durationMin);
    return minHeight / math.max(5, durationMin);
  }

  static double _cardHeightPx(int durationMin, double rubberPxPerMinute) =>
      durationMin * rubberPxPerMinute;

  static bool _wallAdjacent(double prevEndMin, double nextStartMin) =>
      (nextStartMin - prevEndMin).abs() < 0.01;

  /// Packed bottom within one hour at a given rubber scale.
  static double _packedBottomPxInHour({
    required List<_PlanTimeViewCardSlot> sorted,
    required double hourStartMin,
    required double rubberPxPerMinute,
  }) {
    if (sorted.isEmpty) return 0;
    double? prevBottom;
    double? prevEndMin;
    var maxBottom = 0.0;
    for (final c in sorted) {
      final relStart = c.startMin - hourStartMin;
      final idealTop = relStart * rubberPxPerMinute;
      final h = _cardHeightPx(c.durationMin, rubberPxPerMinute);
      final top = prevEndMin != null &&
              _wallAdjacent(prevEndMin, c.startMin)
          ? prevBottom! + kPlanTimeCardGapPx
          : idealTop;
      final bottom = top + h;
      maxBottom = math.max(maxBottom, bottom);
      prevBottom = bottom;
      prevEndMin = c.endMin;
    }
    return maxBottom;
  }

  static bool _hourHasAdjacentWallChain(List<_PlanTimeViewCardSlot> sorted) {
    for (var i = 1; i < sorted.length; i++) {
      if (_wallAdjacent(sorted[i - 1].endMin, sorted[i].startMin)) {
        return true;
      }
    }
    return false;
  }

  /// Rubber ppm + hour height for one hour band.
  static ({double rubberPxPerMinute, double hourHeightPx}) _rubberForHour({
    required List<_PlanTimeViewCardSlot> cards,
    required double hourStartMin,
    required double baseHourHeightPx,
    required int visibleHour,
  }) {
    if (cards.isEmpty) {
      final rubber = _basePxPerMinute(baseHourHeightPx);
      return (rubberPxPerMinute: rubber, hourHeightPx: rubber * 60);
    }

    final sorted = List<_PlanTimeViewCardSlot>.from(cards)
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    var rubber = _basePxPerMinute(baseHourHeightPx);
    for (final c in sorted) {
      rubber = math.max(rubber, _requiredRubberPxPerMinute(c.durationMin));
    }

    final packedBottom = _packedBottomPxInHour(
      sorted: sorted,
      hourStartMin: hourStartMin,
      rubberPxPerMinute: rubber,
    );
    final nominalHourHeight = rubber * 60.0;
    final needsPackStretch =
        _hourHasAdjacentWallChain(sorted) && packedBottom > nominalHourHeight;
    final hourHeight = math.min(
      needsPackStretch
          ? packedBottom + kPlanTimeHourVerticalPaddingPx
          : nominalHourHeight,
      kPlanTimeMaxReasonableHourHeightPx,
    );

    _logTimeLayout(
      'SCALE hour=$visibleHour requiredPxPerMinute=${rubber.toStringAsFixed(3)} '
      'hourHeight=${hourHeight.toStringAsFixed(1)} reason=cardMinHeight',
    );

    return (rubberPxPerMinute: rubber, hourHeightPx: hourHeight);
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
      for (var hourIdx = 0; hourIdx < visibleHours.length; hourIdx++) {
        final hourStart = hourIdx * 60.0;
        final hourEnd = hourStart + 60.0;
        if (slot.startMin < hourEnd - 0.001 && slot.endMin > hourStart + 0.001) {
          byHour.putIfAbsent(hourIdx, () => []).add(slot);
        }
      }
    }

    final hourHeights = <double>[];
    final rubberByHour = <double>[];
    for (var hourIdx = 0; hourIdx < visibleHours.length; hourIdx++) {
      final hourStart = hourIdx * 60.0;
      final result = _rubberForHour(
        cards: byHour[hourIdx] ?? const [],
        hourStartMin: hourStart,
        baseHourHeightPx: baseH,
        visibleHour: visibleHours[hourIdx],
      );
      rubberByHour.add(result.rubberPxPerMinute);
      hourHeights.add(result.hourHeightPx);
    }

    final grid = _buildGrid(visibleHours, rangeStart, hourHeights, rubberByHour);
    final layouts = _placeCards(slots, grid);
    assertPlanTimeViewLayoutDebug(grid: grid, layouts: layouts, slots: slots);
    return (grid: grid, layouts: layouts);
  }

  static PlanTimeViewDurationGrid _buildGrid(
    List<int> visibleHours,
    int rangeStart,
    List<double> hourHeights,
    List<double> rubberByHour,
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
      rubberPxPerMinuteByHour: rubberByHour,
    );
  }

  static List<PlanTimeViewBlockLayout> _placeCards(
    List<_PlanTimeViewCardSlot> slots,
    PlanTimeViewDurationGrid grid,
  ) {
    final layouts = <PlanTimeViewBlockLayout>[];
    double? globalPrevEndMin;
    double? globalPrevBottom;

    for (final slot in slots) {
      final hourIdx = grid.hourIndexForMinutesFromRangeStart(slot.startMin);
      final rubber = grid.pxPerMinuteAtHourIndex(hourIdx);
      final idealTop = grid.yForMinutesFromRangeStart(slot.startMin);
      final heightPx = _cardHeightPx(slot.durationMin, rubber);

      var topPx = idealTop;
      if (globalPrevEndMin != null &&
          globalPrevBottom != null &&
          _wallAdjacent(globalPrevEndMin, slot.startMin)) {
        topPx = globalPrevBottom + kPlanTimeCardGapPx;
        _logTimeLayout(
          'PACK adjacent previous=${layouts.last.task.planRowIdForBackend} '
          'current=${slot.task.planRowIdForBackend} visualGap=${kPlanTimeCardGapPx.toStringAsFixed(0)}',
        );
      }

      globalPrevEndMin = slot.endMin;
      globalPrevBottom = topPx + heightPx;

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
      if (startWall != null) {
        final sh = startWall.hour.toString().padLeft(2, '0');
        final sm = startWall.minute.toString().padLeft(2, '0');
        final eh = endWall?.hour.toString().padLeft(2, '0') ?? sh;
        final em = endWall?.minute.toString().padLeft(2, '0') ?? sm;
        _logTimeLayout(
          'CARD id=${slot.task.planRowIdForBackend} start=$sh:$sm end=$eh:$em '
          'duration=${slot.durationMin} top=${topPx.toStringAsFixed(1)} '
          'bottom=${(topPx + heightPx).toStringAsFixed(1)} '
          'height=${heightPx.toStringAsFixed(1)}',
        );
      }
    }
    return layouts;
  }

  static int _durationMinutesFromLayout(PlanTimeViewBlockLayout layout) {
    final proj = layout.projection;
    if (proj != null) return math.max(5, proj.durationMinutes);
    final st = layout.task.startTime;
    final en = layout.task.endDateTime;
    if (st != null && en != null) {
      return math.max(5, en.difference(st).inMinutes);
    }
    return 5;
  }

  static void _logEmptySlots({
    required PlanTimeViewDurationGrid grid,
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

      final emptyTop = grid.yForMinutesFromRangeStart(lastEnd);
      final emptyBottom = grid.yForMinutesFromRangeStart(hourEndMin);
      if (emptyBottom - emptyTop < 0.5) continue;

      final fromMin = (lastEnd % 60).round();
      _logTimeLayout(
        'EMPTY_SLOT hour=${visibleHours[h]} fromMin=$fromMin toMin=60 '
        'top=${emptyTop.toStringAsFixed(1)} bottom=${emptyBottom.toStringAsFixed(1)}',
      );
    }
  }

  /// Debug-only layout invariants (Time View acceptance).
  static void assertPlanTimeViewLayoutDebug({
    required PlanTimeViewDurationGrid grid,
    required List<PlanTimeViewBlockLayout> layouts,
    required List<_PlanTimeViewCardSlot> slots,
  }) {
    if (kReleaseMode) return;

    _logEmptySlots(grid: grid, slots: slots, visibleHours: grid.visibleHours);

    for (var i = 0; i < layouts.length; i++) {
      final l = layouts[i];
      final durationMin = _durationMinutesFromLayout(l);
      final slot = slots.firstWhere(
        (s) => s.task.planRowIdForBackend == l.task.planRowIdForBackend,
      );
      final hourIdx = grid.hourIndexForMinutesFromRangeStart(slot.startMin);
      final rubber = grid.pxPerMinuteAtHourIndex(hourIdx);
      final expected = _cardHeightPx(durationMin, rubber);

      assert(l.heightPx >= kPlanTimeCardMinHeightPx - 0.01, 'card height < min');
      assert(l.topPx >= 0, 'negative top');
      assert(l.heightPx > 0, 'non-positive height');
      assert(
        (l.heightPx - expected).abs() < 0.51,
        'card height ${l.heightPx} != duration*rubber $expected',
      );

      final packedAfterAdjacent = i > 0 &&
          _wallAdjacent(slots[i - 1].endMin, slot.startMin);
      final idealTop = grid.yForMinutesFromRangeStart(slot.startMin);
      final timeEndY = grid.yForMinutesFromRangeStart(slot.endMin);
      final cardEndY = l.topPx + l.heightPx;

      if (!packedAfterAdjacent) {
        final hourStretched =
            grid.hourHeightsPx[hourIdx] > rubber * 60 + 0.51;
        assert(
          (l.topPx - idealTop).abs() < 1.5,
          'unpacked card top must match wall start minute',
        );
        if (!hourStretched) {
          assert(
            (cardEndY - timeEndY).abs() < 1.5,
            'unpacked card bottom must align with wall end minute',
          );
        }
      }

      if (durationMin < 60 && !packedAfterAdjacent) {
        final hourStretched =
            grid.hourHeightsPx[hourIdx] > rubber * 60 + 0.51;
        if (!hourStretched) {
          final hourTop = grid.hourTopsPx[hourIdx];
          final hourBottom = hourTop + grid.hourHeightsPx[hourIdx];
          if (slot.endMin < hourIdx * 60 + 60 - 0.01) {
            final remaining = hourBottom - cardEndY;
            if (remaining > 0.5) {
              final effectivePpm = grid.hourHeightsPx[hourIdx] / 60.0;
              final expectedRemaining =
                  (hourIdx * 60 + 60 - slot.endMin) * effectivePpm;
              assert(
                (remaining - expectedRemaining).abs() < 2.5,
                'remaining slot height mismatch',
              );
            }
          }
          if (durationMin == 45 && slot.endMin - slot.startMin == 45) {
            final hour = grid.visibleHours[hourIdx];
            if (hourBottom - cardEndY < 0.5) {
              _logTimeLayout(
                'ERROR cardConsumesUnusedTime id=${l.task.planRowIdForBackend} '
                'duration=45 hour=$hour',
              );
              assert(false, 'cardConsumesUnusedTime');
            }
          }
        }
      }
    }

    for (var i = 0; i < layouts.length - 1; i++) {
      final a = layouts[i];
      final b = layouts[i + 1];
      final slotA = slots.firstWhere(
        (s) => s.task.planRowIdForBackend == a.task.planRowIdForBackend,
      );
      final slotB = slots.firstWhere(
        (s) => s.task.planRowIdForBackend == b.task.planRowIdForBackend,
      );
      if (_wallAdjacent(slotA.endMin, slotB.startMin)) {
        assert(
          (b.topPx - (a.topPx + a.heightPx + kPlanTimeCardGapPx)).abs() < 0.51,
          'adjacent gap must be ${kPlanTimeCardGapPx}px',
        );
      } else {
        assert(
          b.topPx >= a.topPx + a.heightPx - 0.5,
          'overlap ${a.task.title} -> ${b.task.title}',
        );
      }
    }

    for (var h = 0; h < grid.visibleHours.length; h++) {
      assert(
        grid.hourHeightsPx[h] <= kPlanTimeMaxReasonableHourHeightPx + 0.5,
        'hour $h height exceeds cap',
      );
      final rubber = grid.rubberPxPerMinuteByHour[h];
      assert(
        grid.hourHeightsPx[h] + 0.01 >= rubber * 60,
        'hour height must be at least rubber*60',
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
