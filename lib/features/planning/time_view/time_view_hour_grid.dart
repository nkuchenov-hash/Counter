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
    var ordered = tasksForTimeMode(
      planningTasksForTimeViewWindow(planWallDay),
      planWallDay,
      rangeStart,
    );
    final schedulablePre = <PlanningTask>[];
    for (final t in ordered) {
      final proj = DatabaseService.instance.projectPlanForTimeMode(t);
      if (proj == null) continue;
      if (!projectedPlanInTimeViewWindow(
        proj,
        planWallDay,
        rangeStart,
        rangeEnd,
      )) {
        continue;
      }
      schedulablePre.add(t);
    }
    if (schedulablePre.isNotEmpty) {
      maybeNormalizeTimeViewOverlapsOnce(planWallDay, schedulablePre);
      ordered = tasksForTimeMode(
        planningTasksForTimeViewWindow(planWallDay),
        planWallDay,
        rangeStart,
      );
    }
    final unscheduled = <PlanningTask>[];
    final projections = <TimeModeProjectedPlan>[];
    for (final t in ordered) {
      final proj = DatabaseService.instance.projectPlanForTimeMode(t);
      if (proj == null) {
        if (t.dateKey.length >= 10 &&
            t.dateKey.substring(0, 10) == selectedDayKey) {
          unscheduled.add(t);
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
      projections.add(proj);
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
          host.planCardRow(
            context: host.context,
            task: task,
            key: key,
            displayDone: displayDone,
            isSelected: host.selectedPlanKeys.contains(key),
            planActualByPbId: planActualByPbId,
            enableLongPressDrag: true,
            onHourGridDragGlobalDy: handleHourGridDragUpdateForEdgeScroll,
            onHourGridDragEnded: stopHourGridEdgeScroll,
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
