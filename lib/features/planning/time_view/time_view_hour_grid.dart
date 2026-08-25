import 'dart:async';

import 'package:counter/core/widgets/life_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:counter/features/planning/time_view/planning_time_view.dart';
import 'package:counter/features/planning/time_view/time_view_canvas.dart';

extension PlanningTimeViewTimeViewHourGrid on PlanningTimeViewCoordinator {
  Future<void> onPlanningTaskDroppedOnHour(
    PlanningTask task,
    int targetHour,
  ) async {
    if (task.planRowIdForBackend.startsWith('optimistic-')) return;
    final h = targetHour.clamp(0, 23);
    final currentHour = wallClockHourFromTask(task);
    if (currentHour != null && currentHour == h) return;

    final d = host.pageWidget.selectedDate ?? host.today;
    var minute = 0;
    if (task.startTime != null) {
      minute = task.startTime!.minute;
    }
    final wallStart = DateTime(d.year, d.month, d.day, h, minute);

    final ok = await DatabaseService.instance.updatePlanningTask(
      task.planRowIdForBackend,
      planBusinessId: task.planRowId,
      startTimeDisplay: wallStart,
      suppressAppSnack: true,
      recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
    );
    if (!host.mounted) return;
    final loc = currentLocale.value;
    final label = '${h.toString().padLeft(2, '0')}:00';
    if (ok) {
      host.notifySetState(() {});
      ScaffoldMessenger.of(host.context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(host.context).colorScheme.primary,
          content: Text(
            t(loc, 'plan_task_moved_hour').replaceFirst('%s', label),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        host.context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
    }
  }

  Widget buildPhysicalUnscheduledPlanDrag({
    required PlanningTask task,
    required String key,
    required bool displayDone,
    required bool isSelected,
    required Map<String, int> planActualByPbId,
  }) {
    Widget buildCard({required bool dragFeedback}) {
      return host.planCardRow(
        context: host.context,
        task: task,
        key: key,
        displayDone: displayDone,
        isSelected: isSelected,
        planActualByPbId: planActualByPbId,
        omitLongPressForReorder: dragFeedback,
      );
    }

    final maxFeedbackWidth = MediaQuery.sizeOf(host.context).width * 0.9;
    return LongPressDraggable<PlanningTask>(
      delay: const Duration(milliseconds: 300),
      data: task,
      dragAnchorStrategy: childDragAnchorStrategy,
      onDragStarted: () {
        unawaited(HapticFeedback.selectionClick());
        setTimelineInteractionLock(true);
      },
      onDragUpdate: (details) {
        handleHourGridDragUpdateForEdgeScroll(details.globalPosition.dy);
      },
      onDragEnd: (_) {
        stopHourGridEdgeScroll();
        setTimelineInteractionLock(false);
      },
      onDraggableCanceled: (_, _) {
        stopHourGridEdgeScroll();
        setTimelineInteractionLock(false);
      },
      feedback: Material(
        type: MaterialType.transparency,
        child: AppPhysicalDragVisual(
          phase: AppPhysicalCardPhase.dragging,
          progress: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxFeedbackWidth),
            child: AbsorbPointer(child: buildCard(dragFeedback: true)),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.28,
        child: buildCard(dragFeedback: true),
      ),
      child: buildCard(dragFeedback: true),
    );
  }

  Widget buildHourGridView(
    List<PlanningTask> tasks,
    Map<String, int> planActualByPbId,
  ) {
    final scheme = Theme.of(host.context).colorScheme;
    final loc = currentLocale.value;
    final rangeStart = timelineHourStart;
    final rangeEnd = timelineHourEnd;
    final planWallDay = host.pageWidget.selectedDate ?? host.today;
    final selectedDayKey = host.pageWidget.selectedDateString.length >= 10
        ? host.pageWidget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final orderedProjected = projectedTasksForTimeMode(
      planningTasksForTimeViewWindow(planWallDay),
      planWallDay,
      rangeStart,
    );
    final schedulablePre = <PlanningTask>[];
    final unscheduled = <PlanningTask>[];
    final projections = <TimeModeProjectedPlan>[];
    for (final item in orderedProjected) {
      final task = item.task;
      final proj = item.projection;
      if (proj == null) {
        if (task.dateKey.length >= 10 &&
            task.dateKey.substring(0, 10) == selectedDayKey) {
          unscheduled.add(task);
        }
        continue;
      }
      if (!projectedPlanInTimeViewWindow(
        proj,
        planWallDay,
        rangeStart,
        rangeEnd,
      )) {
        continue;
      }
      schedulablePre.add(task);
      projections.add(proj);
    }
    if (schedulablePre.isNotEmpty) {
      maybeNormalizeTimeViewOverlapsOnce(planWallDay, schedulablePre);
    }
    cachedTimeModeProjections = projections;
    final visibleHours = PlanningSheetTimelinePrefs.visibleExtendedHoursOrdered(
      rangeStart,
      rangeEnd,
    );

    final inRangeScheduled = projections.map((p) => p.projectedTask).toList();
    logTimeModeRail(selectedDay: planWallDay, visibleHours: visibleHours);

    final children = <Widget>[];
    if (unscheduled.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            t(loc, 'plan_unscheduled'),
            style: Theme.of(
              host.context,
            ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
      for (final task in unscheduled) {
        final key = host.planKey(task);
        final displayDone = host.planDoneOverride[key] ?? task.isDone;
        children.add(
          buildPhysicalUnscheduledPlanDrag(
            task: task,
            key: key,
            displayDone: displayDone,
            isSelected: host.selectedPlanKeys.contains(key),
            planActualByPbId: planActualByPbId,
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }

    children.add(
      buildProportionalDayTimelineCanvas(
        scheme: scheme,
        loc: loc,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        visibleHours: visibleHours,
        scheduledInRange: inRangeScheduled,
        projections: projections,
        selectedDayKey: selectedDayKey,
        planActualByPbId: planActualByPbId,
      ),
    );

    return ListView(
      key: ValueKey<String>(
        'time-view-${DatabaseService.instance.settings.preferredTimeZone}-'
        '${DatabaseService.instance.settings.timezoneOffsetHours}-'
        '${DatabaseService.instance.profileTimezoneProjectionRevision}-'
        '${host.pageWidget.selectedDateString}',
      ),
      controller: hourGridScrollController,
      physics: timelineScrollLocked
          ? const NeverScrollableScrollPhysics()
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: timelineCompactLayout(host.context) ? 4 : 8,
        vertical: 8,
      ),
      children: children,
    );
  }
}
