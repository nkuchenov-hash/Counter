import 'dart:math' as math;

import 'package:counter/shared/diagnostics/performance/shell_flags.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:flutter/material.dart';

import 'package:counter/features/planning/time_view/planning_time_view.dart';

/// List-like reorder trigger based on the dragged card rectangle, not cursor Y.
/// Exact edge contact is not enough; one physical pixel of overlap is.
TimeViewDropIntent? resolveTimeViewOnePixelOverlapIntent({
  required double draggedTopPx,
  required double draggedHeightPx,
  required double verticalDeltaPx,
  required List<TimeViewCardLayout> scheduledCardLayouts,
  required String draggedPlanId,
  double minimumOverlapPx = 1.0,
}) {
  if (verticalDeltaPx == 0 || draggedHeightPx <= 0) return null;

  final draggedBottomPx = draggedTopPx + draggedHeightPx;
  final candidates = <TimeViewCardLayout>[];
  for (final layout in scheduledCardLayouts) {
    if (layout.planId == draggedPlanId) continue;
    final overlapPx = math.min(draggedBottomPx, layout.bottomPx) -
        math.max(draggedTopPx, layout.topPx);
    if (overlapPx >= minimumOverlapPx) candidates.add(layout);
  }
  if (candidates.isEmpty) return null;

  if (verticalDeltaPx > 0) {
    candidates.sort((a, b) => a.topPx.compareTo(b.topPx));
    return TimeViewDropIntent.targetCardAfter(candidates.last.planId);
  }

  candidates.sort((a, b) => a.bottomPx.compareTo(b.bottomPx));
  return TimeViewDropIntent.targetCardBefore(candidates.first.planId);
}

extension PlanningTimeViewTimeViewDropPreview on PlanningTimeViewCoordinator {
  List<TimeViewCardLayout> timelineCardLayoutsForResolver(
    List<PlanTimeViewBlockLayout> layouts,
  ) {
    return [
      for (final layout in layouts)
        TimeViewCardLayout(
          planId: layout.task.planRowIdForBackend,
          topPx: layout.topPx,
          heightPx: layout.heightPx,
          targetStartWall: layout.projection?.profileWallStart,
          targetEndWall: layout.projection?.profileWallEnd,
        ),
    ];
  }

  void applyTimelineCascadePreviewTops({
    required TimeViewInsertionCascadeResult cascadeResult,
    required PlanTimeViewDurationGrid grid,
    required DateTime planWallDay,
    required int rangeStart,
  }) {
    final preview = <String, double>{};
    for (final task in cascadeResult.previewRows) {
      final start = task.startTime;
      if (start == null) continue;
      final durationMin = planWallDurationMinutesForCascade(
        task,
        resolveDurationMinutes:
            DatabaseService.instance.resolvePlanDurationMinutesFromTags,
      );
      final ownMaxTopPx = grid.yForMinutesFromRangeStart(
        math.max(0, grid.totalMinutes - durationMin).toDouble(),
      );
      preview[task.planRowIdForBackend] = timelinePreviewTopPxForStartWall(
        startWall: start,
        grid: grid,
        planWallDay: planWallDay,
        startExtended: rangeStart,
        maxTopPx: ownMaxTopPx,
      );
    }
    stageTimelineOverlapCascadePreview(preview);
  }

  TimeViewInsertionCascadeResult timelineCascadeForDrag({
    required List<PlanningTask> scheduledInRange,
    required String dragPlanId,
    required Set<String> dragIds,
    required Map<String, int> bulkOffsets,
    required TimeViewInsertionIntent? targetIntent,
    required DateTime? emptyCanvasStartWall,
    required bool hadEnd,
    required int durationMin,
  }) {
    return computeTimeViewInsertionCascade(
      scheduledTasks: scheduledInRange,
      draggedPlanIds: dragIds,
      primaryDraggedPlanId: dragPlanId,
      fixedPlanIds: timeViewFixedPlanIdsForTasks(scheduledInRange),
      resolveDurationMinutes:
          DatabaseService.instance.resolvePlanDurationMinutesFromTags,
      targetIntent: targetIntent,
      emptyCanvasStartWall: emptyCanvasStartWall,
      emptyCanvasHadEnd: hadEnd,
      emptyCanvasDurationMin: durationMin,
      bulkRelativeOffsetMinutes: bulkOffsets.isEmpty ? null : bulkOffsets,
    );
  }

  void _stageOnePixelOverlapCascade({
    required TimeViewDropIntent overlapIntent,
    required List<TimeViewCardLayout> cardLayouts,
    required String draggedPlanId,
    required DateTime planWallDay,
    required PlanTimeViewDurationGrid grid,
  }) {
    final isLiveUpdateFrame =
        (timelineFingerDragDeltaPx - timelineVerticalDragDeltaPx).abs() > 0.001;
    if (!isLiveUpdateFrame) return;

    final scheduledInRange = cachedTimeModeProjections
        .map((projection) => projection.projectedTask)
        .toList(growable: false);
    if (scheduledInRange.isEmpty) return;

    var insertionIntent = buildTimeViewInsertionIntentFromDropIntent(
      drop: overlapIntent,
      scheduledCardLayouts: cardLayouts,
      draggedPlanId: draggedPlanId,
      draggedDurationMinutes: timelineVerticalDragDurationMin,
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
    if (insertionIntent == null) return;

    final dragIds = timelineBulkDragPlanIds.isEmpty
        ? <String>{draggedPlanId}
        : Set<String>.from(timelineBulkDragPlanIds);
    final cascadeResult = timelineCascadeForDrag(
      scheduledInRange: scheduledInRange,
      dragPlanId: draggedPlanId,
      dragIds: dragIds,
      bulkOffsets: timelineBulkDragRelativeOffsetMin,
      targetIntent: insertionIntent,
      emptyCanvasStartWall: null,
      hadEnd: timelineVerticalDragHadEnd,
      durationMin: timelineVerticalDragDurationMin,
    );
    if (!cascadeResult.accepted) return;

    applyTimelineCascadePreviewTops(
      cascadeResult: cascadeResult,
      grid: grid,
      planWallDay: planWallDay,
      rangeStart: timelineHourStart,
    );
  }

  TimeViewDropIntent timelineResolveDropIntent({
    required double fingerCanvasY,
    required List<PlanTimeViewBlockLayout> layouts,
    required String draggedPlanId,
    required DateTime planWallDay,
    required PlanTimeViewDurationGrid grid,
    required double maxTopPx,
  }) {
    final cardLayouts = timelineCardLayoutsForResolver(layouts);
    final draggedTopPx =
        (timelineVerticalDragOriginTopPx + timelineFingerDragDeltaPx)
            .clamp(0.0, maxTopPx)
            .toDouble();
    final overlapIntent = resolveTimeViewOnePixelOverlapIntent(
      draggedTopPx: draggedTopPx,
      draggedHeightPx: timelineVerticalDragCardHeightPx,
      verticalDeltaPx: timelineFingerDragDeltaPx,
      scheduledCardLayouts: cardLayouts,
      draggedPlanId: draggedPlanId,
    );

    if (overlapIntent != null) {
      _stageOnePixelOverlapCascade(
        overlapIntent: overlapIntent,
        cardLayouts: cardLayouts,
        draggedPlanId: draggedPlanId,
        planWallDay: planWallDay,
        grid: grid,
      );
      logTimeDropGuard(
        'phase=resolve source=onePixelOverlap '
        'position=${overlapIntent.insertBefore ? 'before' : 'after'} '
        'dragged=$draggedPlanId target=${overlapIntent.targetPlanId}',
      );
      return overlapIntent;
    }

    final minute = snapTimelineMinutes(grid.minutesFromY(draggedTopPx));
    logTimeDropGuard(
      'phase=resolve source=emptyCanvas top=${draggedTopPx.toStringAsFixed(1)} '
      'finger=${fingerCanvasY.toStringAsFixed(1)} '
      'minute=${minute.toStringAsFixed(1)}',
    );
    return TimeViewDropIntent.emptyCanvas(minute);
  }

  PlanTimeViewBlockLayout? timelineLayoutForPlanId(
    List<PlanTimeViewBlockLayout> layouts,
    String? planId,
  ) {
    if (planId == null) return null;
    for (final layout in layouts) {
      if (layout.task.planRowIdForBackend == planId) return layout;
    }
    return null;
  }

  TimeViewInsertionIntent? timelineInsertionIntentFromLayout({
    required PlanTimeViewBlockLayout layout,
    required bool insertBefore,
    required String draggedPlanId,
    required int draggedDurationMin,
    required bool draggedHadEnd,
    required TimeViewInsertionSource source,
    int? dragSequenceId,
  }) {
    final proj = layout.projection ??
        DatabaseService.instance.projectPlanForTimeMode(layout.task);
    final targetStart = proj?.profileWallStart;
    if (proj == null || targetStart == null) return null;
    final targetEnd = proj.profileWallEnd ??
        targetStart.add(Duration(minutes: proj.durationMinutes));
    return TimeViewInsertionIntent(
      draggedPlanId: draggedPlanId,
      targetPlanId: layout.task.planRowIdForBackend,
      insertPosition: insertBefore
          ? TimeViewInsertPosition.before
          : TimeViewInsertPosition.after,
      targetStartWall: targetStart,
      targetEndWall: targetEnd,
      draggedDurationMinutes: draggedDurationMin,
      draggedHadEnd: draggedHadEnd,
      source: source,
      dragSequenceId: dragSequenceId,
    );
  }

  TimeViewTargetDropSchedule? timelineTargetDropScheduleForLayout({
    required PlanTimeViewBlockLayout layout,
    required bool insertBefore,
    required int draggedDurationMin,
    required bool draggedHadEnd,
  }) {
    final proj = layout.projection ??
        DatabaseService.instance.projectPlanForTimeMode(layout.task);
    final targetStart = proj?.profileWallStart;
    if (proj == null || targetStart == null) return null;
    final targetEnd = proj.profileWallEnd ??
        targetStart.add(Duration(minutes: proj.durationMinutes));
    return computeTimeViewTargetDropSchedule(
      targetStartWall: targetStart,
      targetEndWall: targetEnd,
      draggedDurationMinutes: draggedDurationMin,
      insertBefore: insertBefore,
      draggedHadEnd: draggedHadEnd,
    );
  }

  double timelinePreviewTopPxForStartWall({
    required DateTime startWall,
    required PlanTimeViewDurationGrid grid,
    required DateTime planWallDay,
    required int startExtended,
    required double maxTopPx,
  }) {
    final startMin = timelineMinutesFromRangeStart(
      startWall,
      planWallDay,
      startExtended,
    );
    return grid.yForMinutesFromRangeStart(startMin).clamp(0.0, maxTopPx);
  }

  List<PlanTimeViewBlockLayout> timelineDragLayoutsForDay({
    required DateTime planWallDay,
    required int startExtended,
    required int endExtended,
    required String selectedDayKey,
  }) {
    if (ShellFlags.enableTimelineProjectionCache &&
        dragInsertLayoutsCache.isNotEmpty) {
      return dragInsertLayoutsCache;
    }
    final projections = timelineDragExcludedPlanIds.isEmpty
        ? cachedTimeModeProjections
        : cachedTimeModeProjections
            .where(
              (p) =>
                  !timelineDragExcludedPlanIds
                      .contains(p.task.planRowIdForBackend),
            )
            .toList(growable: false);
    return timelineBlockLayouts(
      projections,
      planWallDay,
      startExtended,
      endExtended,
      selectedDayKey,
    );
  }
}
