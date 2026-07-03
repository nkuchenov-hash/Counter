import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/diagnostics/platform_log.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/performance/shell_flags.dart';
import 'package:counter/core/time/plan_time_labels.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/plan_card.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/settings/default_plan_category_search.dart';
import 'package:counter/features/planning/settings/default_plan_timezone_search.dart';
import 'package:counter/features/planning/settings/plan_record_link_settings.dart';
import 'package:counter/features/planning/settings/planning_no_tags_settings.dart';
import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/planning_time_view_host.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:counter/features/planning/time_view/planning_time_view.dart';
extension PlanningTimeViewTimeViewResizeController on PlanningTimeViewCoordinator {
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

    double heightForSpan(int start, int end) {
      final top = grid.yForMinutesFromRangeStart(start.toDouble());
      final bottom = grid.yForMinutesFromRangeStart(end.toDouble());
      return math.max(bottom - top, kPlanTimeCardMinHeightPx);
    }

    var previewTop = timelineResizeOriginTopPx;
    var previewHeight = timelineResizeOriginHeightPx;
    var startMin = timelineResizeOriginStartMin;
    var endMin = timelineResizeOriginEndMin;

    if (edge == TimelineResizeEdge.top) {
      final fixedEndMin = timelineResizeOriginEndMin;
      final maxTopForDur = grid.yForMinutesFromRangeStart(
        math.max(0, fixedEndMin - minDur).toDouble(),
      );
      previewTop = (timelineResizeOriginTopPx + deltaPx).clamp(
        0.0,
        maxTopForDur,
      );
      startMin = snapTimelineMinutes(grid.minutesFromY(previewTop)).round();
      endMin = fixedEndMin;
      if (endMin - startMin < minDur) {
        startMin = endMin - minDur;
      }
      if (startMin < 0) {
        startMin = 0;
        endMin = math.max(endMin, minDur);
      }
      previewTop = grid.yForMinutesFromRangeStart(startMin.toDouble());
      previewHeight = heightForSpan(startMin, endMin);
    } else {
      previewTop = timelineResizeOriginTopPx;
      startMin = timelineResizeOriginStartMin;
      final originBottom = timelineResizeOriginTopPx + timelineResizeOriginHeightPx;
      final minBottom = grid.yForMinutesFromRangeStart(
        (startMin + minDur).toDouble(),
      );
      final newBottom = (originBottom + deltaPx).clamp(
        minBottom,
        grid.totalHeightPx,
      );
      endMin = snapTimelineMinutes(grid.minutesFromY(newBottom)).round();
      if (endMin > maxEndMin) endMin = maxEndMin;
      if (endMin - startMin < minDur) endMin = startMin + minDur;
      previewHeight = heightForSpan(startMin, endMin);
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
    host.notifySetState(clearTimelineInteractionState);
    persistTimelineScheduleChange(
      task: task,
      newStartWall: newStartWall,
      newEndWall: newEndWall,
    );
  }
}
