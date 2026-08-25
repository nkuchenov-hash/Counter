import 'dart:async';
import 'dart:math' as math;

import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/shared/diagnostics/performance/runtime_flags.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

extension PlanningTimeViewPlanningTimeView on PlanningTimeViewCoordinator {
  List<PlanningTask> planningTasksForTimeViewWindow(DateTime planWallDay) {
    final startExt = timelineHourStart;
    final endExt = timelineHourEnd;
    final seen = <String>{};
    final out = <PlanningTask>[];

    void mergeDay(DateTime day) {
      for (final task in DatabaseService.instance.planningDayTasksSnapshot(
        day,
      )) {
        final id = task.planRowIdForBackend;
        if (seen.add(id)) out.add(task);
      }
    }

    mergeDay(planWallDay);
    if (PlanningSheetTimelinePrefs.needsNextDayTasks(endExt)) {
      mergeDay(planWallDay.add(const Duration(days: 1)));
    }
    if (PlanningSheetTimelinePrefs.needsPreviousDayTasks(startExt)) {
      mergeDay(planWallDay.subtract(const Duration(days: 1)));
    }
    return out;
  }

  bool projectedPlanInTimeViewWindow(
    TimeModeProjectedPlan proj,
    DateTime planWallDay,
    int startExt,
    int endExt,
  ) {
    return PlanningSheetTimelinePrefs.projectedPlanOverlapsVisibleWindow(
      wallStart: proj.profileWallStart,
      wallEnd: proj.profileWallEnd,
      durationMinutes: proj.durationMinutes,
      selectedDay: planWallDay,
      startExtended: startExt,
      endExtended: endExt,
    );
  }

  int planningClockOrderMinutes(
    DateTime t,
    DateTime planWallDay,
    int startExtended,
  ) {
    return PlanningSheetTimelinePrefs.minutesFromWindowStart(
      t,
      planWallDay,
      startExtended,
    ).round();
  }

  List<({PlanningTask task, TimeModeProjectedPlan? projection})>
  projectedTasksForTimeMode(
    List<PlanningTask> tasks,
    DateTime planWallDay,
    int dayStartExtended,
  ) {
    final decorated =
        <({PlanningTask task, TimeModeProjectedPlan? projection})>[
          for (final task in tasks)
            (
              task: task,
              projection: DatabaseService.instance.projectPlanForTimeMode(task),
            ),
        ];
    decorated.sort((a, b) {
      final ap = a.projection;
      final bp = b.projection;
      if (ap == null && bp == null) return host.taskSortCmp(a.task, b.task);
      if (ap == null) return 1;
      if (bp == null) return -1;
      final ca = planningClockOrderMinutes(
        ap.profileWallStart,
        planWallDay,
        dayStartExtended,
      );
      final cb = planningClockOrderMinutes(
        bp.profileWallStart,
        planWallDay,
        dayStartExtended,
      );
      if (ca != cb) return ca.compareTo(cb);
      return host.taskSortCmp(a.task, b.task);
    });
    return decorated;
  }

  List<PlanningTask> tasksForTimeMode(
    List<PlanningTask> tasks,
    DateTime planWallDay,
    int dayStartExtended,
  ) => [
    for (final item in projectedTasksForTimeMode(
      tasks,
      planWallDay,
      dayStartExtended,
    ))
      item.task,
  ];

  bool timelineCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(host.context).width <
      PlanningTimeViewCoordinator.kTimelineCompactBreakpoint;

  double timelineRailWidthPx(BuildContext context) =>
      timelineCompactLayout(host.context)
      ? PlanningTimeViewCoordinator.kTimelineRailWidthMobilePx
      : PlanningTimeViewCoordinator.kTimelineRailWidthDesktopPx;

  void onHourGridEdgeScrollTick(Duration elapsed) {
    if (!host.mounted) {
      return;
    }
    if (!hourGridScrollController.hasClients) {
      return;
    }
    final v = hourGridScrollVelocityPxPerSec;
    if (v == 0) {
      return;
    }
    final last = hourGridTickerElapsedLast;
    hourGridTickerElapsedLast = elapsed;
    if (last == null) {
      return;
    }
    final dtSeconds = (elapsed - last).inMicroseconds / 1000000.0;
    if (dtSeconds <= 0) {
      return;
    }
    final c = hourGridScrollController;
    final deltaPx = v * dtSeconds;
    final next = (c.offset + deltaPx).clamp(0.0, c.position.maxScrollExtent);
    c.jumpTo(next.toDouble());
  }

  void ensureHourGridEdgeTickerRunning() {
    if (!hourGridEdgeScrollTicker.isActive) {
      hourGridTickerElapsedLast = null;
      hourGridEdgeScrollTicker.start();
    }
  }

  void stopHourGridEdgeScroll() {
    hourGridScrollVelocityPxPerSec = 0;
    hourGridTickerElapsedLast = null;
    if (hourGridEdgeScrollTicker.isActive) {
      hourGridEdgeScrollTicker.stop();
    }
  }

  void handleHourGridDragUpdateForEdgeScroll(double globalDy) {
    if (host.sortMode != PlanSortMode.time) {
      return;
    }
    final viewH = MediaQuery.sizeOf(host.context).height;
    if (viewH <= 1) {
      return;
    }
    final topBand = viewH * 0.1;
    final bottomBand = viewH * 0.9;
    if (globalDy < topBand) {
      hourGridScrollVelocityPxPerSec =
          -PlanningTimeViewCoordinator.kHourGridEdgeScrollSpeedPxPerSec;
      ensureHourGridEdgeTickerRunning();
    } else if (globalDy > bottomBand) {
      hourGridScrollVelocityPxPerSec =
          PlanningTimeViewCoordinator.kHourGridEdgeScrollSpeedPxPerSec;
      ensureHourGridEdgeTickerRunning();
    } else {
      stopHourGridEdgeScroll();
    }
  }

  String timelineLogWallIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T'
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  int? wallClockHourFromTask(PlanningTask task) {
    final st = task.startTime;
    if (st == null) return null;
    return st.hour;
  }

  double timelineMinutesFromRangeStart(
    DateTime wall,
    DateTime planWallDay,
    int startExtended,
  ) {
    return PlanningSheetTimelinePrefs.minutesFromWindowStart(
      wall,
      planWallDay,
      startExtended,
    );
  }

  int timelineBlockDurationMinutes(PlanningTask task) {
    final proj = DatabaseService.instance.projectPlanForTimeMode(task);
    if (proj != null) return proj.durationMinutes;
    return PlanningTimeViewCoordinator.kTimelineDefaultBlockMinutes;
  }

  double timelineHourHeightPx() =>
      PlanTimeViewLayoutCalculator.baseHourHeightPx();

  double computeTimelinePxPerMinute(List<TimeModeProjectedPlan> projections) {
    return timelineHourHeightPx() / 60.0;
  }

  double timelineCanvasHeightPx(PlanTimeViewDurationGrid grid) =>
      grid.totalHeightPx;

  ({double startMin, double endMin}) timelineSpanMinutesFromProjection(
    TimeModeProjectedPlan proj,
    DateTime planWallDay,
    int startExtended,
  ) {
    final startMin = timelineMinutesFromRangeStart(
      proj.profileWallStart,
      planWallDay,
      startExtended,
    );
    final endMin = proj.profileWallEnd != null
        ? timelineMinutesFromRangeStart(
            proj.profileWallEnd!,
            planWallDay,
            startExtended,
          )
        : startMin + proj.durationMinutes;
    return (startMin: startMin, endMin: endMin);
  }

  ({PlanTimeViewDurationGrid grid, List<PlanTimeViewBlockLayout> layouts})
  computeTimelineDurationLayout(
    List<TimeModeProjectedPlan> projections,
    DateTime planWallDay,
    int startExtended,
    int endExtended,
    String selectedDayKey,
  ) {
    return RebuildMetrics.instance.perfBlock(
      'Planning.computeTimelineDurationLayout',
      () {
        final visibleHours =
            PlanningSheetTimelinePrefs.visibleExtendedHoursOrdered(
              startExtended,
              endExtended,
            );
        if (kVerbosePlanTimeTzProjectionLogs && !kReleaseMode) {
          for (final proj in projections) {
            DatabaseService.instance.logTimeTzProjectForTimeMode(
              proj,
              selectedDay: selectedDayKey,
              visible: true,
            );
          }
        }
        final result = PlanTimeViewLayoutCalculator.compute(
          projections: projections,
          visibleHours: visibleHours,
          rangeStart: startExtended,
          baseHourHeightPx: timelineHourHeightPx(),
          startMinOf: (proj) => timelineSpanMinutesFromProjection(
            proj,
            planWallDay,
            startExtended,
          ).startMin,
          endMinOf: (proj) => timelineSpanMinutesFromProjection(
            proj,
            planWallDay,
            startExtended,
          ).endMin,
        );
        for (final layout in result.layouts) {
          final proj = layout.projection;
          if (proj == null) continue;
          final span = timelineSpanMinutesFromProjection(
            proj,
            planWallDay,
            startExtended,
          );
          final hourIdx = result.grid.hourIndexForMinutesFromRangeStart(
            span.startMin,
          );
          logTimeDurationLayout(
            proj: proj,
            startMinute: span.startMin.round(),
            endMinute: span.endMin.round(),
            durationMin: math.max(
              kPlanTimeMinDurationMinutes,
              (span.endMin - span.startMin).round(),
            ),
            pxPerMinute: result.grid.pxPerMinuteAtHourIndex(hourIdx),
            topPx: layout.topPx,
            heightPx: layout.heightPx,
          );
        }
        return result;
      },
      meta: {'projections': projections.length},
    );
  }

  List<PlanTimeViewBlockLayout> timelineBlockLayouts(
    List<TimeModeProjectedPlan> projections,
    DateTime planWallDay,
    int startExtended,
    int endExtended,
    String selectedDayKey,
  ) {
    final result = computeTimelineDurationLayout(
      projections,
      planWallDay,
      startExtended,
      endExtended,
      selectedDayKey,
    );
    activeTimelineDurationGrid = result.grid;
    return result.layouts;
  }

  void maybeNormalizeTimeViewOverlapsOnce(
    DateTime planWallDay,
    List<PlanningTask> schedulable,
  ) {
    if (host.sortMode != PlanSortMode.time) return;
    final dayKey =
        '${planWallDay.year}-'
        '${planWallDay.month.toString().padLeft(2, '0')}-'
        '${planWallDay.day.toString().padLeft(2, '0')}';
    if (timeViewCascadeNormalizedDayKey == dayKey) return;
    timeViewCascadeNormalizedDayKey = dayKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!host.mounted || host.sortMode != PlanSortMode.time) return;
      DatabaseService.instance.applySequentialTimeViewCascadeIfNeeded(
        wallDay: planWallDay,
        scheduledSubset: schedulable,
      );
      if (host.mounted) host.notifySetState(() {});
    });
  }

  void logTimeDurationLayout({
    required TimeModeProjectedPlan proj,
    required int startMinute,
    required int endMinute,
    required int durationMin,
    required double pxPerMinute,
    required double topPx,
    required double heightPx,
  }) {
    final planId = proj.planId;
    final lineKey =
        '$planId|$startMinute|$endMinute|${topPx.toStringAsFixed(1)}|${heightPx.toStringAsFixed(1)}';
    final now = DateTime.now();
    if (lastTimeDurationLayoutLogKey == lineKey &&
        lastTimeDurationLayoutLogAt != null &&
        now.difference(lastTimeDurationLayoutLogAt!) <
            PlanningTimeViewCoordinator.timeModeLogDebounce) {
      return;
    }
    lastTimeDurationLayoutLogKey = lineKey;
    lastTimeDurationLayoutLogAt = now;
  }

  void logTimeResizePreview({
    required String planId,
    required String edge,
    required double pointerY,
    required int minute,
    required int snapped,
    required DateTime newStart,
    required DateTime? newEnd,
    required int durationMin,
  }) {
    final lineKey = '$planId|$edge|$snapped|$durationMin';
    final now = DateTime.now();
    if (lastTimeResizePreviewLogKey == lineKey &&
        lastTimeResizePreviewLogAt != null &&
        now.difference(lastTimeResizePreviewLogAt!) <
            PlanningTimeViewCoordinator.timeModeLogDebounce) {
      return;
    }
    lastTimeResizePreviewLogKey = lineKey;
    lastTimeResizePreviewLogAt = now;
  }

  void logTimeModeRail({
    required DateTime selectedDay,
    required List<int> visibleHours,
  }) {
    final dayStr =
        '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
    final lineKey = '$dayStr|${visibleHours.join(',')}';
    final now = DateTime.now();
    if (lastTimeModeRailLogKey == lineKey &&
        lastTimeModeRailLogAt != null &&
        now.difference(lastTimeModeRailLogAt!) <
            PlanningTimeViewCoordinator.timeModeLogDebounce) {
      return;
    }
    lastTimeModeRailLogKey = lineKey;
    lastTimeModeRailLogAt = now;
  }

  bool isProfileTodaySelectedForPlanning() {
    final profileTodayKey = DatabaseService.instance.getProjectedTodayDateKey();
    final raw = host.pageWidget.selectedDateString.trim();
    if (raw.length >= 10) {
      return raw.substring(0, 10) == profileTodayKey;
    }
    final planDay = host.pageWidget.selectedDate ?? host.today;
    final profileToday = DatabaseService.instance.getProjectedToday();
    return planDay.year == profileToday.year &&
        planDay.month == profileToday.month &&
        planDay.day == profileToday.day;
  }

  void logPlanTimeNowLine({
    required DateTime nowUtc,
    required DateTime wallNow,
    required String selectedDay,
    required bool visible,
    required double? yPx,
    required double pxPerMinute,
  }) {
    final lineKey =
        '$selectedDay|${wallNow.hour}:${wallNow.minute}|visible=$visible|y=${yPx?.toStringAsFixed(1) ?? '-'}';
    final now = DateTime.now();
    if (lastPlanTimeNowLineLogKey == lineKey &&
        lastPlanTimeNowLineLogAt != null &&
        now.difference(lastPlanTimeNowLineLogAt!) <
            PlanningTimeViewCoordinator.planTimeNowLineLogDebounce) {
      return;
    }
    lastPlanTimeNowLineLogKey = lineKey;
    lastPlanTimeNowLineLogAt = now;
  }

  DateTime profileWallNow() => DatabaseService.instance.applyUserOffset(
    DatabaseService.getPlanetaryNow(),
  );

  double? timelineNowLineTopPx(
    DateTime planWallDay,
    int startExtended,
    int endExtended,
    PlanTimeViewDurationGrid grid,
  ) {
    final selectedDay = host.pageWidget.selectedDateString.length >= 10
        ? host.pageWidget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final wallNow = profileWallNow();
    final minProbe = timelineMinutesFromRangeStart(
      wallNow,
      planWallDay,
      startExtended,
    );
    final ppm = grid.pxPerMinuteAtHourIndex(
      grid.hourIndexForMinutesFromRangeStart(minProbe.toDouble()),
    );
    if (!isProfileTodaySelectedForPlanning()) {
      logPlanTimeNowLine(
        nowUtc: DatabaseService.getPlanetaryNow(),
        wallNow: profileWallNow(),
        selectedDay: selectedDay,
        visible: false,
        yPx: null,
        pxPerMinute: ppm,
      );
      return null;
    }
    final nowUtc = DatabaseService.getPlanetaryNow();
    final min = timelineMinutesFromRangeStart(
      wallNow,
      planWallDay,
      startExtended,
    );
    if (!PlanningSheetTimelinePrefs.wallInstantInsideVisibleWindow(
      wallNow,
      planWallDay,
      startExtended,
      endExtended,
    )) {
      logPlanTimeNowLine(
        nowUtc: nowUtc,
        wallNow: wallNow,
        selectedDay: selectedDay,
        visible: false,
        yPx: null,
        pxPerMinute: ppm,
      );
      return null;
    }
    final y = grid.yForMinutesFromRangeStart(min.toDouble());
    logPlanTimeNowLine(
      nowUtc: nowUtc,
      wallNow: wallNow,
      selectedDay: selectedDay,
      visible: true,
      yPx: y,
      pxPerMinute: ppm,
    );
    return y;
  }

  void maybeAutoScrollTimelineToNow(double nowTopPx, double canvasHeight) {
    if (!isProfileTodaySelectedForPlanning()) return;
    if (timeModeDidAutoScrollToNow) return;
    if (!hourGridScrollController.hasClients) return;
    timeModeDidAutoScrollToNow = true;
    final viewport = MediaQuery.sizeOf(host.context).height * 0.45;
    final target = (nowTopPx - viewport * 0.35)
        .clamp(
          0.0,
          math.max(0.0, hourGridScrollController.position.maxScrollExtent),
        )
        .toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hourGridScrollController.hasClients) return;
      hourGridScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  double snapTimelineMinutes(double rawMinutes) {
    final snap = PlanningSheetTimelinePrefs.timelineSnapMinutes;
    return (rawMinutes / snap).round() * snap.toDouble();
  }

  Set<String> timeViewFixedPlanIdsForTasks(Iterable<PlanningTask> tasks) {
    if (timeViewFixedTagIds.isEmpty) return {};
    final out = <String>{};
    for (final task in tasks) {
      if (isPlanFixedInTimeView(task, timeViewFixedTagIds)) {
        out.add(task.planRowIdForBackend);
      }
    }
    return out;
  }

  bool planIsTimelineScheduledDraggable(PlanningTask task) {
    if (task.startTime == null) return false;
    if (task.planRowIdForBackend.startsWith('optimistic-')) return false;
    final rrule = task.rrule?.trim() ?? '';
    if (rrule.isNotEmpty) return false;
    final inst = task.recurrenceInstanceDateKey?.trim() ?? '';
    if (inst.isNotEmpty) return false;
    return true;
  }

  bool planCanMoveInTimeView(PlanningTask task, String planKey) {
    if (!planIsTimelineScheduledDraggable(task)) return false;
    if (host.planSelectMode) {
      return host.selectedPlanKeys.contains(planKey);
    }
    return true;
  }

  bool planIsTimelineVerticallyDraggable(PlanningTask task) {
    if (host.planSelectMode) return false;
    return planIsTimelineScheduledDraggable(task);
  }

  DateTime wallTimeFromTimelineMinutes(
    double minutesFromRangeStart,
    DateTime planWallDay,
    int startExtended,
  ) {
    return PlanningSheetTimelinePrefs.wallFromWindowMinutes(
      planWallDay,
      startExtended,
      snapTimelineMinutes(minutesFromRangeStart),
    );
  }

  String formatTimelineWallRangeLabel(DateTime start, DateTime? end) {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (end != null) return '${hhmm(start)} – ${hhmm(end)}';
    return hhmm(start);
  }

  String formatTimelineResizeLabel(DateTime start, DateTime end) {
    final mins = end
        .difference(start)
        .inMinutes
        .clamp(PlanningSheetTimelinePrefs.timelineMinDurationMinutes, 24 * 60);
    return '${formatTimelineWallRangeLabel(start, end)} · ${shortTimelineDuration(mins)}';
  }

  String shortTimelineDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  int timelineMaxVisibleMinutes(int startExtended, int endExtended) {
    return PlanningSheetTimelinePrefs.visibleDurationHours(
          startExtended,
          endExtended,
        ) *
        60;
  }

  ({int startMin, int endMin}) timelineStartEndMinutesFromTask(
    PlanningTask task,
    DateTime planWallDay,
    int startExtended,
  ) {
    final proj = DatabaseService.instance.projectPlanForTimeMode(task);
    if (proj == null) {
      return (
        startMin: 0,
        endMin: PlanningTimeViewCoordinator.kTimelineDefaultBlockMinutes,
      );
    }
    final span = timelineSpanMinutesFromProjection(
      proj,
      planWallDay,
      startExtended,
    );
    return (startMin: span.startMin.round(), endMin: span.endMin.round());
  }

  void clearTimelineInteractionState() {
    timelineVerticalDragPlanKey = null;
    timelineVerticalDragDeltaPx = 0;
    timelineFingerDragDeltaPx = 0;
    timelineFingerGrabOffsetCanvasPx = 0;
    timelineVerticalDragTask = null;
    timelineVerticalDragTimeLabel = null;
    timelineDragInsertTargetKey = null;
    timelineDragInsertBefore = false;
    timelineDragInsertMarkerTopPx = null;
    timelineStoredInsertionIntent = null;
    timelineDragExcludedPlanIds = {};
    timelineBulkDragPlanIds = {};
    timelineBulkDragRelativeOffsetMin = {};
    timelineBulkDragPreviewTopPxByPlanId = {};
    dragInsertLayoutsCache = const [];
    timelineResizePlanKey = null;
    timelineResizeEdge = null;
    timelineResizeTask = null;
    timelineResizeTimeLabel = null;
    setTimelineInteractionLock(false);
  }

  void setTimelineInteractionLock(bool locked) {
    if (timelineScrollLocked != locked) {
      host.notifySetState(() => timelineScrollLocked = locked);
    }
    host.onDatePagerLockChanged(locked);
  }

  void persistTimelineScheduleChange({
    required PlanningTask task,
    required DateTime newStartWall,
    required DateTime? newEndWall,
  }) {
    final updated = task.copyWith(
      startTime: newStartWall,
      endDateTime: newEndWall,
      clearEnd: newEndWall == null,
    );
    DatabaseService.instance.applyOptimisticPlanningTask(updated);
    DatabaseService.instance.notifyPlanningRefresh();
    if (host.mounted) host.notifySetState(() {});
    unawaited(
      DatabaseService.instance.updatePlanningTask(
        task.planRowIdForBackend,
        planBusinessId: task.planRowId,
        startTimeDisplay: newStartWall,
        endDateTimeDisplay: newEndWall,
        clearEnd: newEndWall == null,
        suppressAppSnack: true,
        recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
      ),
    );
  }

  void persistTimeViewCascadePatches({
    required List<PlanningTask> resolved,
    required List<PlanningTask> scheduledBefore,
    String? commitSource,
  }) {
    if (kDebugMode) {
      debugPrint('[TIME_VIEW_INSERTION_COMMIT_PATCHES] source=$commitSource');
      debugPrint('[TIME_VIEW_BRAIN_PATCH_STARTED]');
    }
    final beforeByKey = {for (final t in scheduledBefore) host.planKey(t): t};
    for (final task in resolved) {
      final key = host.planKey(task);
      final before = beforeByKey[key];
      if (before == null) continue;
      if (before.startTime == task.startTime &&
          before.endDateTime == task.endDateTime) {
        continue;
      }
      if (kDebugMode) {
        debugPrint(
          '[TIME_VIEW_OPTIMISTIC_APPLIED] id=${task.planRowIdForBackend}',
        );
      }
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      unawaited(
        DatabaseService.instance.updatePlanningTask(
          task.planRowIdForBackend,
          planBusinessId: task.planRowId,
          startTimeDisplay: task.startTime,
          endDateTimeDisplay: task.endDateTime,
          clearEnd: task.endDateTime == null,
          suppressAppSnack: true,
          recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
        ),
      );
      if (kDebugMode) {
        debugPrint('[TIME_VIEW_NETWORK_PATCH_ENQUEUED_OR_SENT]');
      }
    }
    DatabaseService.instance.notifyPlanningRefresh();
    if (host.mounted) host.notifySetState(() {});
  }

  void persistTimelineDragWithCascade({
    required PlanningTask movedTask,
    required DateTime newStartWall,
    required DateTime? newEndWall,
    required List<PlanningTask> scheduledInRange,
    required int rangeStart,
    required int rangeEnd,
    required DateTime planWallDay,
    TimeViewInsertionIntent? insertionIntent,
    String? commitSource,
    double? rawYMinutesForTrace,
  }) {
    final movedKey = host.planKey(movedTask);
    final List<PlanningTask> resolved;
    final List<String> orderBefore;
    final List<String> orderAfter;

    if (insertionIntent != null) {
      final result = DatabaseService.instance.applyTimeViewTargetInsertion(
        scheduledInRange,
        insertionIntent,
      );
      resolved = result.cascaded;
      orderBefore = result.orderBefore;
      orderAfter = result.orderAfter;
      newStartWall = result.draggedStartWall;
      newEndWall = result.draggedEndWall;
    } else {
      orderBefore = scheduledInRange.map(host.planKey).toList();
      final movedUpdated = movedTask.copyWith(
        startTime: newStartWall,
        endDateTime: newEndWall,
        clearEnd: newEndWall == null,
      );
      final merged = scheduledInRange
          .map((t) => host.planKey(t) == movedKey ? movedUpdated : t)
          .toList(growable: false);
      resolved = DatabaseService.instance.normalizeSequentialPlanTimesForDay(
        merged,
      );
      orderAfter = resolved.map(host.planKey).toList();
    }

    final patchParts = <String>[];
    for (final task in resolved) {
      final key = host.planKey(task);
      final before = key == movedKey
          ? movedTask
          : timelineTaskByPlanKey(scheduledInRange, key);
      if (before == null) continue;
      if (before.startTime == task.startTime &&
          before.endDateTime == task.endDateTime) {
        continue;
      }
      final s = task.startTime;
      final e = task.endDateTime;
      if (s != null) {
        patchParts.add(
          '${task.planRowIdForBackend}:'
          '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}-'
          '${e != null ? '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}' : 'open'}',
        );
      }
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      unawaited(
        DatabaseService.instance.updatePlanningTask(
          task.planRowIdForBackend,
          planBusinessId: task.planRowId,
          startTimeDisplay: task.startTime,
          endDateTimeDisplay: task.endDateTime,
          clearEnd: task.endDateTime == null,
          suppressAppSnack: true,
          recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
        ),
      );
    }

    DatabaseService.instance.notifyPlanningRefresh();
    if (host.mounted) host.notifySetState(() {});
  }

  PlanningTask? timelineTaskByPlanKey(
    List<PlanningTask> scheduled,
    String planKey,
  ) {
    for (final t in scheduled) {
      if (host.planKey(t) == planKey) return t;
    }
    return null;
  }

  void initHourGridTicker(
    Ticker Function(void Function(Duration)) createTicker,
  ) {
    hourGridEdgeScrollTicker = createTicker(onHourGridEdgeScrollTick);
  }

  void disposeTimeView() {
    nowLineTimer?.cancel();
    nowLineTimer = null;
    stopHourGridEdgeScroll();
    hourGridEdgeScrollTicker.dispose();
    hourGridScrollController.dispose();
  }
}
