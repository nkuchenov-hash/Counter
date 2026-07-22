import 'dart:ui' show Offset;

import 'package:counter/shared/diagnostics/performance/shell_flags.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

import 'package:counter/features/planning/time_view/planning_time_view.dart';

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
    required String dragPlanId,
    required PlanTimeViewDurationGrid grid,
    required DateTime planWallDay,
    required int rangeStart,
    required double maxTopPx,
  }) {
    timelineBulkDragPreviewTopPxByPlanId = {};
    for (final t in cascadeResult.previewRows) {
      final id = t.planRowIdForBackend;
      if (!timelineBulkDragPlanIds.contains(id)) continue;
      final st = t.startTime;
      if (st == null) continue;
      timelineBulkDragPreviewTopPxByPlanId[id] =
          timelinePreviewTopPxForStartWall(
        startWall: st,
        grid: grid,
        planWallDay: planWallDay,
        startExtended: rangeStart,
        maxTopPx: maxTopPx,
      );
    }
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

  TimeViewDropIntent timelineResolveDropIntent({
    required double fingerCanvasY,
    required List<PlanTimeViewBlockLayout> layouts,
    required String draggedPlanId,
    required DateTime planWallDay,
    required PlanTimeViewDurationGrid grid,
    required double maxTopPx,
  }) {
    return resolveTimeViewDropIntent(
      fingerLocalPosition: Offset(0, fingerCanvasY),
      scheduledCardLayouts: timelineCardLayoutsForResolver(layouts),
      draggedPlanId: draggedPlanId,
      wallDate: planWallDay,
      canvasYToMinutes: (y) => snapTimelineMinutes(
        grid.minutesFromY(y.clamp(0.0, maxTopPx)),
      ),
    );
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

  void logTimeDropGuard(String message) => logTimeDropGuard(message);

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
