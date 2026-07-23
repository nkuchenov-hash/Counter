import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:counter/features/planning/time_view/planning_time_view.dart';
import 'package:counter/features/planning/time_view/time_view_drag_controller.dart';
import 'package:counter/features/planning/time_view/time_view_resize_controller.dart';

extension PlanningTimeViewTimeViewCardLayer on PlanningTimeViewCoordinator {
  String? timelineElevatedPlanKey() =>
      timelineResizePlanKey ?? timelineVerticalDragPlanKey;

  Widget buildTimelinePlanStackLayer({
    required PlanTimeViewBlockLayout layout,
    required double canvasHeight,
    required ColorScheme scheme,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required String selectedDayKey,
    required Map<String, int> planActualByPbId,
    required List<PlanningTask> scheduledInRange,
  }) {
    final planKey = host.planKey(layout.task);
    final inBulkDragPreview = timelineVerticalDragPlanKey != null &&
        timelineBulkDragPlanIds.contains(layout.task.planRowIdForBackend);
    final isDragging = inBulkDragPreview;
    final isResizing = timelineResizePlanKey == planKey;
    final isInteracting = isDragging || isResizing;
    final bulkPreviewTop =
        timelineBulkDragPreviewTopPxByPlanId[layout.task.planRowIdForBackend];
    final topPx = bulkPreviewTop ??
        (isDragging
            ? layout.topPx + timelineVerticalDragDeltaPx
            : isResizing
                ? timelineResizePreviewTopPx
                : layout.topPx);
    final heightPx = isResizing
        ? math.max(1.0, timelineResizePreviewHeightPx)
        : layout.heightPx;
    const horizontalPad =
        PlanningTimeViewCoordinator.kTimelineBlockHorizontalPadPx;
    final canMove = planCanMoveInTimeView(layout.task, planKey);
    final canResize =
        planIsTimelineScheduledDraggable(layout.task) && !host.planSelectMode;
    final durMin = timelineBlockDurationMinutes(layout.task);
    final hadEnd = layout.task.endDateTime != null;
    final times = timelineStartEndMinutesFromTask(
      layout.task,
      planWallDay,
      rangeStart,
    );
    final interactionLabel = isResizing
        ? timelineResizeTimeLabel
        : timelineVerticalDragTimeLabel;
    final blockDensity = layout.density;
    final resizeHeightPx = math.max(heightPx, kPlanTimeCardMinHeightPx);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isInteracting)
          Positioned(
            top: layout.topPx,
            left: 0,
            right: 0,
            height: layout.heightPx,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal:
                    PlanningTimeViewCoordinator.kTimelineBlockHorizontalPadPx,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
          ),
        if (isInteracting && (interactionLabel ?? '').isNotEmpty)
          Positioned(
            top: (topPx - 22).clamp(0, canvasHeight - 20),
            left: horizontalPad,
            child: Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(6),
              color: scheme.primary.withValues(alpha: 0.92),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  interactionLabel!,
                  style: Theme.of(host.context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                ),
              ),
            ),
          ),
        if (isInteracting)
          Positioned(
            top: topPx + heightPx - 2,
            left: horizontalPad,
            right: horizontalPad,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        Positioned(
          top: topPx,
          left: 0,
          right: 0,
          height: resizeHeightPx,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal:
                  PlanningTimeViewCoordinator.kTimelineBlockHorizontalPadPx,
            ),
            child: RepaintBoundary(
              child: TimelinePlanInteractionBlock(
                canMove: canMove,
                canResize: canResize,
                bulkSelectMode: host.planSelectMode,
                resizeHandlePx:
                    PlanningTimeViewCoordinator.kTimelineResizeHandlePx,
                blockHeightPx: resizeHeightPx,
                controlsLeftInset: planCardBodyGestureLeftInsetPx(
                  blockDensity,
                  timeline: true,
                ),
                controlsRightInset: planCardBodyGestureRightInsetPx(),
                onMovePointerDown: canMove
                    ? () {
                        setTimelineInteractionLock(true);
                      }
                    : null,
                onBodyTap: () {
                  if (host.planSelectMode) {
                    if (kDebugMode) {
                      debugPrint(
                        '[TIME_VIEW_BULK_SELECTION_TOGGLED] key=$planKey',
                      );
                    }
                    host.toggleKeySelection(planKey);
                  } else {
                    if (kDebugMode) {
                      debugPrint('[TIME_VIEW_TAP_OPEN_EDIT] key=$planKey');
                    }
                    host.openEditDialog(layout.task);
                  }
                },
                onVerticalDragStart: canMove
                    ? (fingerGrabOffset) => beginTimelineVerticalDrag(
                          task: layout.task,
                          planKey: planKey,
                          originTopPx: layout.topPx,
                          originCardHeightPx: layout.heightPx,
                          durationMin: durMin,
                          hadEnd: hadEnd,
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          selectedDayKey: selectedDayKey,
                          fingerGrabOffsetCanvasPx: fingerGrabOffset,
                          scheduledInRange: scheduledInRange,
                        )
                    : null,
                onVerticalDragVelocityChanged: canMove
                    ? (velocity) {
                        timelineVerticalDragVisualVelocityPxPerSec = velocity;
                      }
                    : null,
                onVerticalDragUpdate: canMove
                    ? (delta, globalDy) => updateTimelineVerticalDrag(
                          deltaPx: delta,
                          globalDy: globalDy,
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          canvasHeight: canvasHeight,
                          scheduledInRange: scheduledInRange,
                          planActualByPbId: planActualByPbId,
                        )
                    : null,
                onVerticalDragEnd: canMove
                    ? () => commitTimelineVerticalDrag(
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          scheduledInRange: scheduledInRange,
                        )
                    : null,
                onVerticalDragCancel:
                    canMove ? cancelTimelineVerticalDrag : null,
                onResizeStart: canResize
                    ? (edge) => beginTimelineResize(
                          edge: edge,
                          task: layout.task,
                          planKey: planKey,
                          originTopPx: layout.topPx,
                          originHeightPx: layout.heightPx,
                          originStartMin: times.startMin,
                          originEndMin: times.endMin,
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                        )
                    : null,
                onResizeUpdate: canResize
                    ? (delta, globalDy) => updateTimelineResize(
                          deltaPx: delta,
                          globalDy: globalDy,
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                        )
                    : null,
                onResizeEnd: canResize
                    ? () => commitTimelineResize(
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                        )
                    : null,
                onResizeCancel: canResize ? cancelTimelineResize : null,
                isInteracting: isInteracting,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: resizeHeightPx,
                    child: host.planCardRow(
                      context: host.context,
                      task: layout.task,
                      key: planKey,
                      displayDone:
                          host.planDoneOverride[planKey] ?? layout.task.isDone,
                      isSelected: host.selectedPlanKeys.contains(planKey),
                      planActualByPbId: planActualByPbId,
                      timelineEmbedded: true,
                      timelineInteracting: isInteracting,
                      timelineScheduleConflict: false,
                      timelineTimeLabel: layout.projection?.plannedTimeLabel,
                      timelineBlockHeightPx: resizeHeightPx,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
