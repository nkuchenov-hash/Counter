import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/recurrence_scope_dialog.dart';
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
    final planId = layout.task.planRowIdForBackend;
    final inBulkDragPreview =
        timelineVerticalDragPlanKey != null &&
        timelineBulkDragPlanIds.contains(planId);
    final isDragging = inBulkDragPreview;
    final isPrimaryDraggedCard =
        isDragging && timelineVerticalDragTask?.planRowIdForBackend == planId;
    final isResizing = timelineResizePlanKey == planKey;
    final isInteracting = isDragging || isResizing;

    // The card held by the pointer must always follow raw pointer geometry.
    // Preview/cascade positions may move neighboring or secondary bulk cards,
    // but must never turn contact with another card into a physical barrier.
    final bulkPreviewTop = isPrimaryDraggedCard
        ? null
        : timelineBulkDragPreviewTopPxByPlanId[planId];
    final topPx =
        bulkPreviewTop ??
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
    final isRecurring = DatabaseService.instance
        .planningTaskIsRecurringForScope(layout.task);
    final canMove =
        planCanMoveInTimeView(layout.task, planKey) ||
        (isRecurring && !host.planSelectMode);
    final canResize =
        (planIsTimelineScheduledDraggable(layout.task) || isRecurring) &&
        !host.planSelectMode;
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
    final reduceMotion = MediaQuery.disableAnimationsOf(host.context);
    final settleDuration = isInteracting || reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 140);

    return KeyedSubtree(
      key: ValueKey<String>('time-view-card-layer-$planKey'),
      child: Stack(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    interactionLabel!,
                    style: Theme.of(host.context).textTheme.labelSmall
                        ?.copyWith(
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
          AnimatedPositioned(
            key: ValueKey<String>('time-view-card-position-$planKey'),
            duration: settleDuration,
            curve: Curves.easeOutCubic,
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
                  onMovePointerRelease: canMove
                      ? () {
                          setTimelineInteractionLock(false);
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
                      ? () =>
                          commitTimelineVerticalDragWithOptionalRecurrenceScope(
                            planWallDay: planWallDay,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            scheduledInRange: scheduledInRange,
                          )
                      : null,
                  onVerticalDragCancel: canMove
                      ? cancelTimelineVerticalDrag
                      : null,
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
                      ? () => commitTimelineResizeWithOptionalRecurrenceScope(
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                          scheduledInRange: scheduledInRange,
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
                            host.planDoneOverride[planKey] ??
                            layout.task.isDone,
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
      ),
    );
  }
}

/// Returns the row id that recurrence mutation APIs should receive.
///
/// A stored series row representing its first visible occurrence must be treated
/// as a virtual occurrence for `singleOccurrence`; otherwise the template itself
/// would be patched instead of materializing an exception.
String timeViewRecurringMutationRowId({
  required PlanningTask task,
  required RecurrenceEditScope scope,
  required String instanceDateKey,
}) {
  final backendId = task.planRowIdForBackend.trim();
  if (scope != RecurrenceEditScope.singleOccurrence ||
      backendId.startsWith('virt-') ||
      (task.recurrenceInstanceDateKey?.trim().isNotEmpty ?? false) ||
      task.parentPlanPocketId?.trim().isNotEmpty == true) {
    return backendId;
  }

  final rrule = task.rrule?.trim() ?? '';
  final parentPocketId = task.pocketRecordId?.trim() ?? '';
  final day = instanceDateKey.trim();
  if (rrule.isNotEmpty && parentPocketId.isNotEmpty && day.length >= 10) {
    return 'virt-$parentPocketId-${day.substring(0, 10)}';
  }
  return backendId;
}

extension PlanningTimeViewRecurringInteractionController
    on PlanningTimeViewCoordinator {
  bool timeViewTaskIsRecurring(PlanningTask task) =>
      DatabaseService.instance.planningTaskIsRecurringForScope(task);

  void commitTimelineVerticalDragWithOptionalRecurrenceScope({
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required List<PlanningTask> scheduledInRange,
  }) {
    final task = timelineVerticalDragTask;
    if (task == null || !timeViewTaskIsRecurring(task)) {
      commitTimelineVerticalDrag(
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        scheduledInRange: scheduledInRange,
      );
      return;
    }
    unawaited(
      _commitRecurringTimelineVerticalDrag(
        task: task,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      ),
    );
  }

  Future<void> _commitRecurringTimelineVerticalDrag({
    required PlanningTask task,
    required DateTime planWallDay,
    required int rangeStart,
  }) async {
    final planKey = timelineVerticalDragPlanKey;
    stopHourGridEdgeScroll();
    if (planKey == null) {
      cancelTimelineVerticalDrag();
      return;
    }
    if (planTimeViewMovementBelowDragThreshold(timelineFingerDragDeltaPx)) {
      cancelTimelineVerticalDrag();
      return;
    }

    final grid = activeTimelineDurationGrid;
    if (grid == null) {
      cancelTimelineVerticalDrag();
      return;
    }
    final durationMinutes = timelineVerticalDragDurationMin;
    final maxTopPx = grid.yForMinutesFromRangeStart(
      math.max(0, grid.totalMinutes - durationMinutes),
    );
    final fingerCanvasY = timelineFingerCanvasY(timelineFingerDragDeltaPx);
    final topPx = (fingerCanvasY - timelineFingerGrabOffsetCanvasPx)
        .clamp(0.0, maxTopPx)
        .toDouble();
    final startMinutes = snapTimelineMinutes(grid.minutesFromY(topPx));
    final newStartWall = wallTimeFromTimelineMinutes(
      startMinutes,
      planWallDay,
      rangeStart,
    );
    final newEndWall = timelineVerticalDragHadEnd
        ? newStartWall.add(Duration(minutes: durationMinutes))
        : null;

    host.notifySetState(clearTimelineInteractionState);
    await _chooseAndPersistRecurringSchedule(
      task: task,
      newStartWall: newStartWall,
      newEndWall: newEndWall,
    );
  }

  void commitTimelineResizeWithOptionalRecurrenceScope({
    required DateTime planWallDay,
    required int rangeStart,
    required List<PlanningTask> scheduledInRange,
  }) {
    final task = timelineResizeTask;
    if (task == null || !timeViewTaskIsRecurring(task)) {
      commitTimelineResize(
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        scheduledInRange: scheduledInRange,
      );
      return;
    }
    unawaited(
      _commitRecurringTimelineResize(
        task: task,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      ),
    );
  }

  Future<void> _commitRecurringTimelineResize({
    required PlanningTask task,
    required DateTime planWallDay,
    required int rangeStart,
  }) async {
    stopHourGridEdgeScroll();
    if (timelineResizePlanKey == null) {
      cancelTimelineResize();
      return;
    }
    final grid = activeTimelineDurationGrid;
    if (grid == null) {
      cancelTimelineResize();
      return;
    }

    final startMinutes = snapTimelineMinutes(
      grid.minutesFromY(timelineResizePreviewTopPx),
    );
    final endMinutes = snapTimelineMinutes(
      grid.minutesFromY(
        timelineResizePreviewTopPx + timelineResizePreviewHeightPx,
      ),
    );
    final newStartWall = wallTimeFromTimelineMinutes(
      startMinutes,
      planWallDay,
      rangeStart,
    );
    final newEndWall = wallTimeFromTimelineMinutes(
      endMinutes,
      planWallDay,
      rangeStart,
    );

    host.notifySetState(clearTimelineInteractionState);
    if (task.startTime == newStartWall && task.endDateTime == newEndWall) {
      return;
    }
    await _chooseAndPersistRecurringSchedule(
      task: task,
      newStartWall: newStartWall,
      newEndWall: newEndWall,
    );
  }

  Future<void> _chooseAndPersistRecurringSchedule({
    required PlanningTask task,
    required DateTime newStartWall,
    required DateTime? newEndWall,
  }) async {
    if (!host.mounted) return;
    final scope = await showRecurrenceScopeDialog(
      host.context,
      task: task,
      isDelete: false,
    );
    if (scope == null || !host.mounted) return;

    final instanceDay = task.recurrenceInstanceDateKey?.trim().isNotEmpty == true
        ? task.recurrenceInstanceDateKey!.trim().substring(0, 10)
        : DatabaseService.instance.planningWallScheduleDateKey(task);
    final mutationRowId = timeViewRecurringMutationRowId(
      task: task,
      scope: scope,
      instanceDateKey: instanceDay,
    );
    final businessId = task.planRowId?.trim() ?? '';
    final updated = task.copyWith(
      startTime: newStartWall,
      endDateTime: newEndWall,
      clearEnd: newEndWall == null,
    );

    DatabaseService.instance.applyOptimisticPlanningTask(updated);
    DatabaseService.instance.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    if (host.mounted) host.notifySetState(() {});

    final ok =
        await DatabaseService.instance.updatePlanningTaskWithRecurrenceScope(
      mutationRowId,
      scope: scope,
      planBusinessId:
          businessId.isEmpty || businessId.startsWith('virt-')
              ? null
              : businessId,
      startTimeDisplay: newStartWall,
      endDateTimeDisplay: newEndWall,
      clearEnd: newEndWall == null,
      suppressAppSnack: true,
      recurrenceInstanceDateKey: instanceDay,
    );

    DatabaseService.instance.clearOptimisticPlanningForPlanRow(
      task.planRowIdForBackend,
    );
    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
    }
    DatabaseService.instance.notifyPlanningRefresh();
    if (host.mounted) host.notifySetState(() {});
  }
}
