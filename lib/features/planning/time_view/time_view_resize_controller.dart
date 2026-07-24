import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';

import 'package:counter/features/planning/time_view/planning_time_view.dart';

extension PlanningTimeViewTimeViewResizeController
    on PlanningTimeViewCoordinator {
  void updateTimelineResizeLabel({
    required int startMin,
    required int endMin,
    required DateTime planWallDay,
    required int rangeStart,
  }) {
    final startWall = wallTimeFromTimelineMinutes(
      startMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    final endWall = wallTimeFromTimelineMinutes(
      endMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    timelineResizeTimeLabel = formatTimelineResizeLabel(startWall, endWall);
  }

  void beginTimelineResize({
    required TimelineResizeEdge edge,
    required PlanningTask task,
    required String planKey,
    required double originTopPx,
    required double originHeightPx,
    required int originStartMin,
    required int originEndMin,
    required DateTime planWallDay,
    required int rangeStart,
  }) {
    clearTimelineInteractionState();
    host.notifySetState(() {
      timelineResizePlanKey = planKey;
      timelineResizeEdge = edge;
      timelineResizeOriginTopPx = originTopPx;
      timelineResizeOriginHeightPx = originHeightPx;
      timelineResizeOriginStartMin = originStartMin;
      timelineResizeOriginEndMin = originEndMin;
      timelineResizePreviewTopPx = originTopPx;
      timelineResizePreviewHeightPx = originHeightPx;
      timelineResizeTask = task;
      setTimelineInteractionLock(true);
      updateTimelineResizeLabel(
        startMin: originStartMin,
        endMin: originEndMin,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      );
    });
  }

  void updateTimelineResize({
    required double deltaPx,
    required double globalDy,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
  }) {
    final edge = timelineResizeEdge;
    if (edge == null) return;
    final grid = activeTimelineDurationGrid;
    if (grid == null) return;
    final minDur = PlanningSheetTimelinePrefs.timelineMinDurationMinutes;
    final maxEndMin = timelineMaxVisibleMinutes(rangeStart, rangeEnd);

    var previewTop = timelineResizeOriginTopPx;
    var previewHeight = timelineResizeOriginHeightPx;
    var startMin = timelineResizeOriginStartMin;
    var endMin = timelineResizeOriginEndMin;

    if (edge == TimelineResizeEdge.top) {
      final fixedBottomPx =
          timelineResizeOriginTopPx + timelineResizeOriginHeightPx;
      final maxTopForDuration = grid.yForMinutesFromRangeStart(
        math.max(0, timelineResizeOriginEndMin - minDur).toDouble(),
      );
      final maxTopForCardHeight = fixedBottomPx - kPlanTimeCardMinHeightPx;
      final maxTop = math.min(maxTopForDuration, maxTopForCardHeight);

      previewTop = (timelineResizeOriginTopPx + deltaPx)
          .clamp(0.0, math.max(0.0, maxTop))
          .toDouble();
      previewHeight = math.max(
        kPlanTimeCardMinHeightPx,
        fixedBottomPx - previewTop,
      );

      startMin = snapTimelineMinutes(grid.minutesFromY(previewTop)).round();
      endMin = timelineResizeOriginEndMin;
      if (endMin - startMin < minDur) {
        startMin = endMin - minDur;
      }
      if (startMin < 0) {
        startMin = 0;
      }
    } else {
      previewTop = timelineResizeOriginTopPx;
      startMin = timelineResizeOriginStartMin;
      final originBottom =
          timelineResizeOriginTopPx + timelineResizeOriginHeightPx;
      final minBottomForDuration = grid.yForMinutesFromRangeStart(
        (startMin + minDur).toDouble(),
      );
      final minBottomForCardHeight = previewTop + kPlanTimeCardMinHeightPx;
      final minBottom = math.max(minBottomForDuration, minBottomForCardHeight);
      final rawBottom = (originBottom + deltaPx)
          .clamp(minBottom, grid.totalHeightPx)
          .toDouble();

      previewHeight = math.max(
        kPlanTimeCardMinHeightPx,
        rawBottom - previewTop,
      );
      endMin = snapTimelineMinutes(grid.minutesFromY(rawBottom)).round();
      if (endMin > maxEndMin) endMin = maxEndMin;
      if (endMin - startMin < minDur) endMin = startMin + minDur;
    }

    final newStartWall = wallTimeFromTimelineMinutes(
      startMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    final newEndWall = wallTimeFromTimelineMinutes(
      endMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    logTimeResizePreview(
      planId: timelineResizeTask?.planRowIdForBackend ?? '-',
      edge: edge == TimelineResizeEdge.top ? 'top' : 'bottom',
      pointerY: previewTop + previewHeight,
      minute: grid.minutesFromY(previewTop + previewHeight).round(),
      snapped: edge == TimelineResizeEdge.top ? startMin : endMin,
      newStart: newStartWall,
      newEnd: newEndWall,
      durationMin: endMin - startMin,
    );

    host.notifySetState(() {
      timelineResizePreviewTopPx = previewTop;
      timelineResizePreviewHeightPx = previewHeight;
      updateTimelineResizeLabel(
        startMin: startMin,
        endMin: endMin,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      );
    });
    handleHourGridDragUpdateForEdgeScroll(globalDy);
  }

  void cancelTimelineResize() {
    if (timelineResizePlanKey == null) return;
    stopHourGridEdgeScroll();
    host.notifySetState(clearTimelineInteractionState);
  }

  void commitTimelineResize({
    required DateTime planWallDay,
    required int rangeStart,
    required List<PlanningTask> scheduledInRange,
  }) {
    final task = timelineResizeTask;
    stopHourGridEdgeScroll();
    if (task == null || timelineResizePlanKey == null) {
      cancelTimelineResize();
      return;
    }
    final grid = activeTimelineDurationGrid;
    if (grid == null) {
      cancelTimelineResize();
      return;
    }
    final startMin = snapTimelineMinutes(
      grid.minutesFromY(timelineResizePreviewTopPx),
    ).round();
    final endMin = snapTimelineMinutes(
      grid.minutesFromY(
        timelineResizePreviewTopPx + timelineResizePreviewHeightPx,
      ),
    ).round();
    final newStartWall = wallTimeFromTimelineMinutes(
      startMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    final newEndWall = wallTimeFromTimelineMinutes(
      endMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    final resizedTask = task.copyWith(
      startTime: newStartWall,
      endDateTime: newEndWall,
      clearEnd: false,
    );
    final resolved = cascadeScheduledPlansAfterManualResize(
      scheduledTasks: scheduledInRange,
      resizedTask: resizedTask,
      resolveDurationMinutes:
          DatabaseService.instance.resolvePlanDurationMinutesFromTags,
    );
    host.notifySetState(clearTimelineInteractionState);
    persistTimeViewCascadePatches(
      resolved: resolved,
      scheduledBefore: scheduledInRange,
      commitSource: 'resizeCascade',
    );
  }
}
