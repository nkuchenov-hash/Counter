import 'dart:math' as math;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/shared/diagnostics/performance/shell_flags.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';

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
          .where(planIsTimelineScheduledDraggable)
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
      timelineVerticalDragSequenceId =
          ++PlanningTimeViewCoordinator.timelineNextDragSequenceId;
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
    final pointerAnchoredTopPx =
        (fingerCanvasY - timelineFingerGrabOffsetCanvasPx)
            .clamp(0.0, maxTopPx)
            .toDouble();

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

    String? insertKey;
    var insertBefore = false;
    double? markerTop;
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
      if (storedIntent == null) {
        insertKey = null;
      } else {
        final targetLayout = timelineLayoutForPlanId(
          layouts,
          dropIntent.targetPlanId,
        );
        if (targetLayout != null) {
          markerTop = insertBefore
              ? targetLayout.topPx.clamp(0.0, canvasHeight).toDouble()
              : (targetLayout.topPx + targetLayout.heightPx)
                  .clamp(0.0, canvasHeight)
                  .toDouble();
        }
      }
    }

    final snappedMin = dropIntent.wallStartMinute ??
        snapTimelineMinutes(grid.minutesFromY(pointerAnchoredTopPx));
    final snappedTopPx = grid.yForMinutesFromRangeStart(snappedMin);
    final previewLabel = timelineDragLabelForTopPx(
      snappedTopPx,
      planWallDay,
      rangeStart,
      timelineVerticalDragDurationMin,
      timelineVerticalDragHadEnd,
    );

    host.notifySetState(() {
      timelineVerticalDragDeltaPx =
          pointerAnchoredTopPx - timelineVerticalDragOriginTopPx;
      timelineBulkDragPreviewTopPxByPlanId = {};
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

  TimeViewInsertionCascadeResult _computeRigidBulkDragCascade({
    required List<PlanningTask> scheduledTasks,
    required Set<String> draggedPlanIds,
    required String primaryDraggedPlanId,
    required Set<String> fixedPlanIds,
    required Map<String, int> capturedOffsets,
    TimeViewInsertionIntent? targetIntent,
    DateTime? emptyCanvasStartWall,
  }) {
    final resolveDuration =
        DatabaseService.instance.resolvePlanDurationMinutesFromTags;
    final byId = <String, PlanningTask>{
      for (final task in scheduledTasks) task.planRowIdForBackend: task,
    };
    final primary = byId[primaryDraggedPlanId];
    final primaryStart = primary?.startTime;
    if (primary == null || primaryStart == null) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'bulkScheduleMissing',
      );
    }

    final offsets = <String, int>{};
    var minOffset = 0;
    var maxEndOffset = 0;
    var first = true;
    for (final id in draggedPlanIds) {
      final member = byId[id];
      final start = member?.startTime;
      if (member == null || start == null) {
        return const TimeViewInsertionCascadeResult(
          accepted: false,
          blockedReason: 'bulkScheduleMissing',
        );
      }
      final actualOffset = start.difference(primaryStart).inMinutes;
      final offset = capturedOffsets[id] ?? actualOffset;
      offsets[id] = offset;
      final duration = planWallDurationMinutesForCascade(
        member,
        resolveDurationMinutes: resolveDuration,
      );
      if (first) {
        minOffset = offset;
        maxEndOffset = offset + duration;
        first = false;
      } else {
        minOffset = math.min(minOffset, offset);
        maxEndOffset = math.max(maxEndOffset, offset + duration);
      }
    }

    final DateTime desiredPrimaryStart;
    if (targetIntent != null) {
      if (!byId.containsKey(targetIntent.targetPlanId) ||
          draggedPlanIds.contains(targetIntent.targetPlanId)) {
        return const TimeViewInsertionCascadeResult(
          accepted: false,
          blockedReason: 'targetMissing',
        );
      }
      desiredPrimaryStart = targetIntent.insertBefore
          ? targetIntent.targetStartWall.subtract(
              Duration(minutes: maxEndOffset),
            )
          : targetIntent.targetEndWall.subtract(
              Duration(minutes: minOffset),
            );
    } else if (emptyCanvasStartWall != null) {
      desiredPrimaryStart = emptyCanvasStartWall;
    } else {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'missingIntent',
      );
    }

    final movedSelectedById = <String, PlanningTask>{};
    DateTime? groupStart;
    DateTime? groupEnd;
    for (final id in draggedPlanIds) {
      final member = byId[id]!;
      final offset = offsets[id]!;
      final start = desiredPrimaryStart.add(Duration(minutes: offset));
      final duration = planWallDurationMinutesForCascade(
        member,
        resolveDurationMinutes: resolveDuration,
      );
      final effectiveEnd = start.add(Duration(minutes: duration));
      final explicitEnd = member.endDateTime != null ? effectiveEnd : null;
      movedSelectedById[id] = member.copyWith(
        startTime: start,
        endDateTime: explicitEnd,
        clearEnd: explicitEnd == null,
      );
      if (groupStart == null || start.isBefore(groupStart)) {
        groupStart = start;
      }
      if (groupEnd == null || effectiveEnd.isAfter(groupEnd)) {
        groupEnd = effectiveEnd;
      }
    }

    if (groupStart == null || groupEnd == null) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'bulkScheduleMissing',
      );
    }

    final groupProxy = primary.copyWith(
      startTime: groupStart,
      endDateTime: groupEnd,
      clearEnd: false,
    );
    final reduced = <PlanningTask>[
      for (final row in scheduledTasks)
        if (!draggedPlanIds.contains(row.planRowIdForBackend))
          row
        else if (row.planRowIdForBackend == primaryDraggedPlanId)
          groupProxy,
    ];

    final List<PlanningTask>? cascadedReduced;
    if (targetIntent != null) {
      final ordered = buildExplicitOrderForTargetInsert(
        scheduled: reduced,
        draggedPlanId: primaryDraggedPlanId,
        targetPlanId: targetIntent.targetPlanId,
        insertBefore: targetIntent.insertBefore,
      );
      cascadedReduced = cascadeScheduledPlansForExplicitTimeViewOrderWithBarriers(
        explicitOrder: ordered,
        resolveDurationMinutes: resolveDuration,
        fixedPlanIds: fixedPlanIds,
        draggedPlanIds: <String>{primaryDraggedPlanId},
      );
    } else {
      cascadedReduced = cascadeScheduledPlansForTimeViewDayWithBarriers(
        reduced,
        resolveDurationMinutes: resolveDuration,
        fixedPlanIds: fixedPlanIds,
        draggedPlanIds: <String>{primaryDraggedPlanId},
      );
    }

    if (cascadedReduced == null) {
      String? blockedId;
      for (final id in fixedPlanIds) {
        if (!draggedPlanIds.contains(id)) {
          blockedId = id;
          break;
        }
      }
      return TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'fixedBarrier',
        blockedByFixedPlanId: blockedId,
      );
    }

    PlanningTask? cascadedProxy;
    for (final row in cascadedReduced) {
      if (row.planRowIdForBackend == primaryDraggedPlanId) {
        cascadedProxy = row;
        break;
      }
    }
    final cascadedGroupStart = cascadedProxy?.startTime;
    if (cascadedProxy == null || cascadedGroupStart == null) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'primaryMissing',
      );
    }

    final groupShift = cascadedGroupStart.difference(groupStart);
    final finalSelectedById = <String, PlanningTask>{};
    for (final entry in movedSelectedById.entries) {
      final member = entry.value;
      final start = member.startTime!.add(groupShift);
      final end = member.endDateTime?.add(groupShift);
      finalSelectedById[entry.key] = member.copyWith(
        startTime: start,
        endDateTime: end,
        clearEnd: end == null,
      );
    }

    final reducedById = <String, PlanningTask>{
      for (final row in cascadedReduced) row.planRowIdForBackend: row,
    };
    final resolved = <PlanningTask>[
      for (final original in scheduledTasks)
        if (finalSelectedById.containsKey(original.planRowIdForBackend))
          finalSelectedById[original.planRowIdForBackend]!
        else
          reducedById[original.planRowIdForBackend] ?? original,
    ];

    final finalPrimary = finalSelectedById[primaryDraggedPlanId];
    final finalPrimaryStart = finalPrimary?.startTime;
    if (finalPrimary == null || finalPrimaryStart == null) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'primaryMissing',
      );
    }
    for (final entry in offsets.entries) {
      final memberStart = finalSelectedById[entry.key]?.startTime;
      if (memberStart == null ||
          memberStart.difference(finalPrimaryStart).inMinutes != entry.value) {
        return const TimeViewInsertionCascadeResult(
          accepted: false,
          blockedReason: 'bulkRelativeOffsetsChanged',
        );
      }
    }

    if (scheduledPlansHaveWallOverlap(
      resolved.where((row) => row.startTime != null).toList(growable: false),
      resolveDurationMinutes: resolveDuration,
    )) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'overlap',
      );
    }

    final patches = diffSequentialCascadePatches(scheduledTasks, resolved);
    final shifted = patches.map((patch) => patch.task.planRowIdForBackend).toSet();
    return TimeViewInsertionCascadeResult(
      accepted: true,
      patches: patches,
      previewRows: resolved,
      shiftedPlanIds: shifted,
      draggedStartWall: finalPrimary.startTime,
      draggedEndWall: finalPrimary.endDateTime,
    );
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
    final pointerAnchoredTopPx =
        (fingerCanvasY - timelineFingerGrabOffsetCanvasPx)
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

    final cascadeResult = draggedPlanIds.length > 1
        ? _computeRigidBulkDragCascade(
            scheduledTasks: scheduledInRange,
            draggedPlanIds: draggedPlanIds,
            primaryDraggedPlanId: task.planRowIdForBackend,
            fixedPlanIds: fixedPlanIds,
            capturedOffsets: bulkOffsets,
            targetIntent: insertionIntent,
            emptyCanvasStartWall: emptyCanvasStartWall,
          )
        : computeTimeViewInsertionCascade(
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
