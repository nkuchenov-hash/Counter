import 'dart:async';
import 'dart:math' as math;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/recurrence_scope_dialog.dart';
import 'package:counter/features/planning/time_view/planning_time_view.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/time_view_drag_controller.dart';
import 'package:counter/features/planning/time_view/time_view_resize_controller.dart';

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

    final ok = await DatabaseService.instance.updatePlanningTaskWithRecurrenceScope(
      mutationRowId,
      scope: scope,
      planBusinessId:
          businessId.isEmpty || businessId.startsWith('virt-') ? null : businessId,
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
