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
import 'package:counter/features/planning/time_view/time_view_drop_preview.dart';
extension PlanningTimeViewTimeViewDragController on PlanningTimeViewCoordinator {
  double timelineFingerCanvasY(double deltaPx) =>
      timelineVerticalDragOriginTopPx +
      deltaPx +
      timelineFingerGrabOffsetCanvasPx;

  String? timelineDragLabelForTopPx(
    double topPx,
    DateTime planWallDay,
    int rangeStart,
    int durationMin,
    bool hadEnd,
  ) {
    final grid = activeTimelineDurationGrid;
    final startMin = grid?.minutesFromY(topPx) ?? topPx;
    final startWall = wallTimeFromTimelineMinutes(
      startMin,
      planWallDay,
      rangeStart,
    );
    final endWall = hadEnd
        ? startWall.add(Duration(minutes: durationMin))
        : null;
    return formatTimelineWallRangeLabel(startWall, endWall);
  }

  void beginTimelineVerticalDrag({
    required PlanningTask task,
    required String planKey,
    required double originTopPx,
    required double originCardHeightPx,
    required int durationMin,
    required bool hadEnd,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required String selectedDayKey,
    required double fingerGrabOffsetCanvasPx,
    required List<PlanningTask> scheduledInRange,
  }) {
    clearTimelineInteractionState();

    var dragIds = <String>{task.planRowIdForBackend};
    var relativeOffsets = <String, int>{};
    if (host.planSelectMode) {
      final selected = scheduledInRange
          .where((t) => host.selectedPlanKeys.contains(host.planKey(t)))
          .where((t) => t.startTime != null)
          .toList();
      if (selected.length > 1) {
        dragIds = selected.map((t) => t.planRowIdForBackend).toSet();
        final primaryStart = task.startTime!;
        for (final t in selected) {
          final st = t.startTime;
          if (st == null) continue;
          relativeOffsets[t.planRowIdForBackend] =
              st.difference(primaryStart).inMinutes;
        }
        if (kDebugMode) {
          debugPrint(
            '[TIME_VIEW_BULK_DRAG_STARTED] group=${dragIds.length}',
          );
        }
      }
    }

    timelineDragExcludedPlanIds = dragIds;
    timelineBulkDragPlanIds = dragIds;
    timelineBulkDragRelativeOffsetMin = relativeOffsets;

    if (ShellFlags.enableTimelineProjectionCache) {
      final filtered = cachedTimeModeProjections
          .where((p) => !dragIds.contains(p.task.planRowIdForBackend))
          .toList(growable: false);
      dragInsertLayoutsCache = timelineBlockLayouts(
        filtered,
        planWallDay,
        rangeStart,
        rangeEnd,
        selectedDayKey,
      );
    }
    if (kDebugMode) {
      debugPrint(
        '[TIME_VIEW_DRAG_EXCLUDED_FROM_COLLISION_SET] count=${dragIds.length}',
      );
      debugPrint(
        '[TIME_VIEW_DRAG_GRAB_OFFSET_CAPTURED] '
        'offset=${fingerGrabOffsetCanvasPx.toStringAsFixed(1)}',
      );
    }
    host.notifySetState(() {
      timelineVerticalDragPlanKey = planKey;
      timelineVerticalDragDeltaPx = 0;
      timelineFingerDragDeltaPx = 0;
      timelineFingerGrabOffsetCanvasPx = fingerGrabOffsetCanvasPx;
      timelineVerticalDragSequenceId = ++PlanningTimeViewCoordinator.timelineNextDragSequenceId;
      timelineVerticalDragOriginTopPx = originTopPx;
      timelineVerticalDragCardHeightPx = originCardHeightPx;
      timelineVerticalDragDurationMin = durationMin;
      timelineVerticalDragTask = task;
      timelineVerticalDragHadEnd = hadEnd;
      timelineVerticalDragTimeLabel = timelineDragLabelForTopPx(
        originTopPx,
        planWallDay,
        rangeStart,
        durationMin,
        hadEnd,
      );
    });
    setTimelineInteractionLock(true);
  }

  void updateTimelineVerticalDrag({
    required double deltaPx,
    required double globalDy,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required double canvasHeight,
    required List<PlanningTask> scheduledInRange,
    required Map<String, int> planActualByPbId,
  }) {
    final grid = activeTimelineDurationGrid;
    if (grid == null) return;
    timelineFingerDragDeltaPx = deltaPx;
    final durMin = timelineVerticalDragDurationMin.toDouble();
    final maxTopPx = grid.yForMinutesFromRangeStart(
      math.max(0, grid.totalMinutes - durMin),
    );
    final fingerCanvasY = timelineFingerCanvasY(deltaPx);
    final pointerAnchoredTopPx = (fingerCanvasY - timelineFingerGrabOffsetCanvasPx)
        .clamp(0.0, maxTopPx);
    final selectedDayKey = host.pageWidget.selectedDateString.length >= 10
        ? host.pageWidget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final layouts = timelineDragLayoutsForDay(
      planWallDay: planWallDay,
      startExtended: rangeStart,
      endExtended: rangeEnd,
      selectedDayKey: selectedDayKey,
    );
    final dragPlanId = timelineVerticalDragTask?.planRowIdForBackend ??
        timelineVerticalDragPlanKey ??
        '';
    final cardLayouts = timelineCardLayoutsForResolver(layouts);
    final dropIntent = timelineResolveDropIntent(
      fingerCanvasY: fingerCanvasY,
      layouts: layouts,
      draggedPlanId: dragPlanId,
      planWallDay: planWallDay,
      grid: grid,
      maxTopPx: maxTopPx,
    );

    double previewTop;
    String? insertKey;
    var insertBefore = false;
    double? markerTop;
    String? previewLabel;
    TimeViewInsertionIntent? storedIntent;

    if (dropIntent.isTargetCard) {
      insertBefore = dropIntent.insertBefore;
      insertKey = dropIntent.targetPlanId;
      storedIntent = buildTimeViewInsertionIntentFromDropIntent(
        drop: dropIntent,
        scheduledCardLayouts: cardLayouts,
        draggedPlanId: dragPlanId,
        draggedDurationMinutes: timelineVerticalDragDurationMin,
        draggedHadEnd: timelineVerticalDragHadEnd,
        dragSequenceId: timelineVerticalDragSequenceId,
      );
      storedIntent = storedIntent == null
          ? null
          : refreshTimeViewInsertionIntentFromScheduled(
              intent: storedIntent,
              scheduled: scheduledInRange,
              resolveDurationMinutes:
                  DatabaseService.instance.resolvePlanDurationMinutesFromTags,
            );
      if (storedIntent != null) {
        final cascadeResult = timelineCascadeForDrag(
          scheduledInRange: scheduledInRange,
          dragPlanId: dragPlanId,
          dragIds: timelineBulkDragPlanIds.isEmpty
              ? {dragPlanId}
              : timelineBulkDragPlanIds,
          bulkOffsets: timelineBulkDragRelativeOffsetMin,
          targetIntent: storedIntent,
          emptyCanvasStartWall: null,
          hadEnd: timelineVerticalDragHadEnd,
          durationMin: timelineVerticalDragDurationMin,
        );
        if (cascadeResult.accepted &&
            cascadeResult.draggedStartWall != null) {
          applyTimelineCascadePreviewTops(
            cascadeResult: cascadeResult,
            dragPlanId: dragPlanId,
            grid: grid,
            planWallDay: planWallDay,
            rangeStart: rangeStart,
            maxTopPx: maxTopPx,
          );
          previewTop = timelineBulkDragPreviewTopPxByPlanId[dragPlanId] ??
              timelinePreviewTopPxForStartWall(
                startWall: cascadeResult.draggedStartWall!,
                grid: grid,
                planWallDay: planWallDay,
                startExtended: rangeStart,
                maxTopPx: maxTopPx,
              );
          previewLabel = formatTimelineWallRangeLabel(
            cascadeResult.draggedStartWall!,
            cascadeResult.draggedEndWall,
          );
        } else {
          storedIntent = null;
          insertKey = null;
          timelineBulkDragPreviewTopPxByPlanId = {};
          final snappedMin = snapTimelineMinutes(
            grid.minutesFromY(pointerAnchoredTopPx),
          );
          previewTop = grid.yForMinutesFromRangeStart(snappedMin);
          previewLabel = timelineDragLabelForTopPx(
            previewTop,
            planWallDay,
            rangeStart,
            timelineVerticalDragDurationMin,
            timelineVerticalDragHadEnd,
          );
        }
        final targetLayout = timelineLayoutForPlanId(
          layouts,
          dropIntent.targetPlanId,
        );
        if (targetLayout != null) {
          if (insertBefore) {
            markerTop = targetLayout.topPx.clamp(0.0, canvasHeight);
          } else {
            markerTop = (targetLayout.topPx + targetLayout.heightPx).clamp(
              0.0,
              canvasHeight,
            );
          }
        }
      } else {
        storedIntent = null;
        insertKey = null;
        timelineBulkDragPreviewTopPxByPlanId = {};
        final snappedMin = snapTimelineMinutes(
          grid.minutesFromY(pointerAnchoredTopPx),
        );
        previewTop = grid.yForMinutesFromRangeStart(snappedMin);
        previewLabel = timelineDragLabelForTopPx(
          previewTop,
          planWallDay,
          rangeStart,
          timelineVerticalDragDurationMin,
          timelineVerticalDragHadEnd,
        );
      }
    } else {
      storedIntent = null;
      final snappedMin = dropIntent.wallStartMinute ??
          snapTimelineMinutes(grid.minutesFromY(pointerAnchoredTopPx));
      final emptyStart = wallTimeFromTimelineMinutes(
        snappedMin,
        planWallDay,
        rangeStart,
      );
      final cascadeResult = timelineCascadeForDrag(
        scheduledInRange: scheduledInRange,
        dragPlanId: dragPlanId,
        dragIds: timelineBulkDragPlanIds.isEmpty
            ? {dragPlanId}
            : timelineBulkDragPlanIds,
        bulkOffsets: timelineBulkDragRelativeOffsetMin,
        targetIntent: null,
        emptyCanvasStartWall: emptyStart,
        hadEnd: timelineVerticalDragHadEnd,
        durationMin: timelineVerticalDragDurationMin,
      );
      if (cascadeResult.accepted && cascadeResult.draggedStartWall != null) {
        applyTimelineCascadePreviewTops(
          cascadeResult: cascadeResult,
          dragPlanId: dragPlanId,
          grid: grid,
          planWallDay: planWallDay,
          rangeStart: rangeStart,
          maxTopPx: maxTopPx,
        );
        previewTop = timelineBulkDragPreviewTopPxByPlanId[dragPlanId] ??
            timelinePreviewTopPxForStartWall(
              startWall: cascadeResult.draggedStartWall!,
              grid: grid,
              planWallDay: planWallDay,
              startExtended: rangeStart,
              maxTopPx: maxTopPx,
            );
        previewLabel = formatTimelineWallRangeLabel(
          cascadeResult.draggedStartWall!,
          cascadeResult.draggedEndWall,
        );
      } else {
        timelineBulkDragPreviewTopPxByPlanId = {};
        previewTop = grid.yForMinutesFromRangeStart(snappedMin);
        previewLabel = timelineDragLabelForTopPx(
          previewTop,
          planWallDay,
          rangeStart,
          timelineVerticalDragDurationMin,
          timelineVerticalDragHadEnd,
        );
      }
    }

    host.notifySetState(() {
      timelineVerticalDragDeltaPx =
          previewTop - timelineVerticalDragOriginTopPx;
      timelineDragInsertTargetKey = insertKey;
      timelineDragInsertBefore = insertBefore;
      timelineDragInsertMarkerTopPx = markerTop;
      timelineStoredInsertionIntent = storedIntent;
      timelineVerticalDragTimeLabel = previewLabel;
    });
    handleHourGridDragUpdateForEdgeScroll(globalDy);
  }

  void cancelTimelineVerticalDrag() {
    if (timelineVerticalDragPlanKey == null) return;
    stopHourGridEdgeScroll();
    host.notifySetState(clearTimelineInteractionState);
  }

  void commitTimelineVerticalDrag({
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required List<PlanningTask> scheduledInRange,
  }) {
    final task = timelineVerticalDragTask;
    final planKey = timelineVerticalDragPlanKey;
    final bulkDragIds = Set<String>.from(timelineBulkDragPlanIds);
    final bulkOffsets = Map<String, int>.from(timelineBulkDragRelativeOffsetMin);
    stopHourGridEdgeScroll();
    if (task == null || planKey == null) {
      cancelTimelineVerticalDrag();
      return;
    }
    if (planTimeViewMovementBelowDragThreshold(timelineFingerDragDeltaPx)) {
      logTimeDropGuard('phase=cancel reason=belowDragThreshold');
      cancelTimelineVerticalDrag();
      return;
    }
    final durMin = timelineVerticalDragDurationMin;
    final grid = activeTimelineDurationGrid;
    if (grid == null) {
      cancelTimelineVerticalDrag();
      return;
    }
    final maxTopPx = grid.yForMinutesFromRangeStart(
      math.max(0, grid.totalMinutes - durMin),
    );
    final fingerCanvasY = timelineFingerCanvasY(timelineFingerDragDeltaPx);
    final pointerAnchoredTopPx = (fingerCanvasY - timelineFingerGrabOffsetCanvasPx)
        .clamp(0.0, maxTopPx);
    final selectedDayKey = host.pageWidget.selectedDateString.length >= 10
        ? host.pageWidget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final layouts = timelineDragLayoutsForDay(
      planWallDay: planWallDay,
      startExtended: rangeStart,
      endExtended: rangeEnd,
      selectedDayKey: selectedDayKey,
    );
    final cardLayouts = timelineCardLayoutsForResolver(layouts);
    final dropIntent = timelineResolveDropIntent(
      fingerCanvasY: fingerCanvasY,
      layouts: layouts,
      draggedPlanId: task.planRowIdForBackend,
      planWallDay: planWallDay,
      grid: grid,
      maxTopPx: maxTopPx,
    );

    String commitSource;
    TimeViewInsertionIntent? insertionIntent;

    if (dropIntent.kind == TimeViewDropIntentKind.cancel) {
      logTimeDropGuard('phase=cancel reason=${dropIntent.cancelReason}');
      cancelTimelineVerticalDrag();
      return;
    } else if (dropIntent.isTargetCard) {
      commitSource = 'targetCard';
      logTimeDropGuard(
        'phase=commit source=targetCard '
        'position=${dropIntent.insertBefore ? 'before' : 'after'} noRawY=true',
      );
      insertionIntent = timelineStoredInsertionIntent;
      if (insertionIntent == null) {
        insertionIntent = buildTimeViewInsertionIntentFromDropIntent(
          drop: dropIntent,
          scheduledCardLayouts: cardLayouts,
          draggedPlanId: task.planRowIdForBackend,
          draggedDurationMinutes: durMin,
          draggedHadEnd: timelineVerticalDragHadEnd,
          dragSequenceId: timelineVerticalDragSequenceId,
        );
        insertionIntent = insertionIntent == null
            ? null
            : refreshTimeViewInsertionIntentFromScheduled(
                intent: insertionIntent,
                scheduled: scheduledInRange,
                resolveDurationMinutes:
                    DatabaseService.instance.resolvePlanDurationMinutesFromTags,
              );
      }
      final cancelReason = insertionIntent == null
          ? 'targetProjectionFailed'
          : validateTimeViewTargetInsertionIntent(
              intent: insertionIntent,
              scheduled: scheduledInRange,
              expectedDayKey: selectedDayKey,
            );
      if (cancelReason != null) {
        logTimeDropGuard('phase=cancel reason=$cancelReason');
        cancelTimelineVerticalDrag();
        return;
      }
    } else {
      commitSource = 'emptyCanvas';
      insertionIntent = null;
      logTimeDropGuard('phase=commit mode=emptyCanvas');
    }

    final fixedPlanIds = timeViewFixedPlanIdsForTasks(scheduledInRange);
    final draggedPlanIds = bulkDragIds.isEmpty
        ? {task.planRowIdForBackend}
        : bulkDragIds;

    DateTime? emptyCanvasStartWall;
    if (insertionIntent == null) {
      final snappedMin = snapTimelineMinutes(
        dropIntent.wallStartMinute ??
            grid.minutesFromY(pointerAnchoredTopPx),
      );
      emptyCanvasStartWall = wallTimeFromTimelineMinutes(
        snappedMin,
        planWallDay,
        rangeStart,
      );
    }

    final cascadeResult = computeTimeViewInsertionCascade(
      scheduledTasks: scheduledInRange,
      draggedPlanIds: draggedPlanIds,
      primaryDraggedPlanId: task.planRowIdForBackend,
      fixedPlanIds: fixedPlanIds,
      resolveDurationMinutes:
          DatabaseService.instance.resolvePlanDurationMinutesFromTags,
      targetIntent: insertionIntent,
      emptyCanvasStartWall: emptyCanvasStartWall,
      emptyCanvasHadEnd: timelineVerticalDragHadEnd,
      emptyCanvasDurationMin: durMin,
      bulkRelativeOffsetMinutes:
          bulkOffsets.isEmpty ? null : bulkOffsets,
    );

    if (!cascadeResult.accepted) {
      if (cascadeResult.blockedReason == 'fixedBarrier') {
        if (kDebugMode) {
          debugPrint('[TIME_VIEW_BULK_DRAG_BLOCKED_BY_FIXED_TIME]');
        }
        if (host.mounted) {
          AppSnack.warning(
            currentLocale.value == 'ru'
                ? 'Фиксированная встреча блокирует сдвиг'
                : 'Fixed-time meeting blocks this move',
          );
        }
      }
      logTimeDropGuard(
        'phase=cancel reason=${cascadeResult.blockedReason ?? 'cascadeRejected'}',
      );
      cancelTimelineVerticalDrag();
      return;
    }

    if (kDebugMode && draggedPlanIds.length > 1) {
      debugPrint(
        '[TIME_VIEW_BULK_DRAG_PATCHES_COMPUTED] patches=${cascadeResult.patches.length}',
      );
    }

    host.notifySetState(clearTimelineInteractionState);
    persistTimeViewCascadePatches(
      resolved: cascadeResult.previewRows,
      scheduledBefore: scheduledInRange,
      commitSource: commitSource,
    );
    if (kDebugMode && draggedPlanIds.length > 1) {
      debugPrint('[TIME_VIEW_BULK_DRAG_COMMITTED]');
    }
  }
}
