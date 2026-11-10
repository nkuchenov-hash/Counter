import 'dart:math' as math;

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/plan_card.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/widgets/planning_empty_states.dart';
import 'package:flutter/material.dart';

/// Read-only neighboring day with the same cards and Time View geometry as the
/// live page. No active stream, edit handlers, shared ScrollController or IO.
class PlanningFrozenDayList extends StatelessWidget {
  const PlanningFrozenDayList({
    super.key,
    required this.tasks,
    required this.scheme,
    required this.wallDay,
    this.timeMode = false,
  });

  final List<PlanningTask> tasks;
  final ColorScheme scheme;
  final DateTime wallDay;
  final bool timeMode;

  @override
  Widget build(BuildContext context) {
    if (timeMode) {
      return PlanningFrozenTimeCanvas(
        wallDay: wallDay,
        scheme: scheme,
        tasks: tasks,
      );
    }
    if (tasks.isEmpty) return PlanningFrozenListEmptyState(scheme: scheme);
    return ColoredBox(
      color: scheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        physics: const ClampingScrollPhysics(),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PlanCard(
              key: ValueKey('planning-preview-${task.planRowIdForBackend}'),
              task: task,
              planTrackedSeconds: 0,
              planEstimatedSeconds: planningWallEstimateSeconds(task),
              displayIsDone: task.isDone,
              selectMode: false,
              isSelected: false,
              highlightAsRunning: false,
              toggleDoneEnabled: false,
              onToggleDone: () {},
              onBodyTap: () {},
              onPlay: null,
              onOpenMenu: (_) {},
            ),
          );
        },
      ),
    );
  }
}

/// Time-mode preview is built with the **same** projection, piecewise Y scale,
/// overlap lanes, card densities and PlanTimeTaskCard as the live Time View.
/// It cannot drift into the former tall, empty grey-rectangle imitation.
class PlanningFrozenTimeCanvas extends StatelessWidget {
  const PlanningFrozenTimeCanvas({
    super.key,
    required this.tasks,
    required this.scheme,
    required this.wallDay,
  });

  final List<PlanningTask> tasks;
  final ColorScheme scheme;
  final DateTime wallDay;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final range = PlanningSheetTimelinePrefs.cachedVisibleDayRange;
    final start = range?.start ?? PlanningSheetTimelinePrefs.defaultStartExtended;
    final end = range?.end ?? PlanningSheetTimelinePrefs.defaultEndExtended;
    final hours = PlanningSheetTimelinePrefs.visibleExtendedHoursOrdered(start, end);
    if (hours.isEmpty) return const SizedBox.expand();

    final projections = <TimeModeProjectedPlan>[];
    final untimed = <PlanningTask>[];
    final seen = <String>{};
    // The live canvas includes plans crossing the selected-day boundaries.
    final all = <PlanningTask>[
      ...tasks,
      if (PlanningSheetTimelinePrefs.needsPreviousDayTasks(start))
        ...db.planningDayTasksSnapshot(
          DateTime(wallDay.year, wallDay.month, wallDay.day - 1)),
      if (PlanningSheetTimelinePrefs.needsNextDayTasks(end))
        ...db.planningDayTasksSnapshot(
          DateTime(wallDay.year, wallDay.month, wallDay.day + 1)),
    ];
    final dayKey = '${wallDay.year.toString().padLeft(4, '0')}-'
        '${wallDay.month.toString().padLeft(2, '0')}-'
        '${wallDay.day.toString().padLeft(2, '0')}';
    for (final task in all) {
      if (!seen.add(task.planRowIdForBackend)) continue;
      final projected = db.projectPlanForTimeMode(task);
      if (projected == null) {
        if (task.dateKey.startsWith(dayKey)) untimed.add(task);
      } else if (PlanningSheetTimelinePrefs.projectedPlanOverlapsVisibleWindow(
        wallStart: projected.profileWallStart,
        wallEnd: projected.profileWallEnd,
        durationMinutes: projected.durationMinutes,
        selectedDay: wallDay,
        startExtended: start,
        endExtended: end,
      )) {
        projections.add(projected);
      }
    }
    projections.sort((a, b) =>
        a.profileWallStart.compareTo(b.profileWallStart));
    if (projections.isEmpty && untimed.isEmpty) {
      return PlanningFrozenListEmptyState(scheme: scheme);
    }

    double startMin(TimeModeProjectedPlan p) =>
        PlanningSheetTimelinePrefs.minutesFromWindowStart(
            p.profileWallStart, wallDay, start);
    double endMin(TimeModeProjectedPlan p) =>
        p.profileWallEnd == null
            ? startMin(p) + p.durationMinutes
            : PlanningSheetTimelinePrefs.minutesFromWindowStart(
                p.profileWallEnd!, wallDay, start);
    final result = PlanTimeViewLayoutCalculator.compute(
      projections: projections,
      visibleHours: hours,
      rangeStart: start,
      baseHourHeightPx: PlanTimeViewLayoutCalculator.baseHourHeightPx(),
      startMinOf: startMin,
      endMinOf: endMin,
    );
    final grid = result.grid;
    final canvasHeight = grid.totalHeightPx;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final railWidth = compact ? 28.0 : 88.0;
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    final canvasInset = desktop ? kShellDesktopContentHorizontalPadding : 8.0;
    const blockPad = 8.0;

    return ColoredBox(
      color: scheme.surface,
      child: ListView(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 8, vertical: 8),
        children: [
          if (untimed.isNotEmpty)
            ...untimed.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlanCard(
                task: t,
                planTrackedSeconds: 0,
                planEstimatedSeconds: planningWallEstimateSeconds(t),
                displayIsDone: t.isDone,
                toggleDoneEnabled: false,
                onBodyTap: () {},
                onToggleDone: () {},
                onOpenMenu: (_) {},
              ),
            )),
          SizedBox(
            height: canvasHeight + 8,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: canvasInset),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: canvasHeight,
                        width: railWidth,
                        child: Stack(children: [
                          Positioned(
                            left: railWidth - 10, top: 0, bottom: 0,
                            child: SizedBox(width: 1,
                              child: ColoredBox(color: scheme.outline)),
                          ),
                          for (var i = 0; i < hours.length; i++) ...[
                            Positioned(
                              top: grid.hourLineY(i) - 10,
                              left: 0, right: 0, height: 20,
                              child: Text(
                                compact
                                    ? '${PlanningSheetTimelinePrefs.displayHourMod24(hours[i])}'
                                    : PlanningSheetTimelinePrefs.formatExtendedHourClock(hours[i]),
                                style: TextStyle(
                                  color: scheme.onSurface.withValues(alpha: 0.78),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Positioned(
                              left: railWidth - 14,
                              top: grid.hourLineY(i) - 4,
                              child: SizedBox(
                                height: 8, width: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.outline,
                                    shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ),
                      Expanded(child: LayoutBuilder(
                        builder: (context, box) => SizedBox(
                          height: canvasHeight,
                          child: Stack(children: [
                            for (var i = 0; i < hours.length; i++)
                              Positioned(
                                top: grid.hourLineY(i),
                                left: 0, right: 0,
                                child: Divider(
                                  height: 1, thickness: 1,
                                  color: scheme.outlineVariant.withValues(alpha: 0.30)),
                              ),
                            for (final layout in result.layouts)
                              Positioned(
                                key: ValueKey(
                                  'planning-frozen-time-${layout.task.planRowIdForBackend}'),
                                top: layout.topPx,
                                left: layout.overlapLaneIndex *
                                    (box.maxWidth / math.max(1,layout.overlapLaneCount)) + blockPad,
                                width: box.maxWidth /
                                        math.max(1, layout.overlapLaneCount) -
                                    2 * blockPad,
                                height: layout.heightPx,
                                child: PlanTimeTaskCard(
                                  task: layout.task,
                                  density: layout.density,
                                  timelineVisualDensity: layout.visualDensity,
                                  timelineBlockHeightPx: layout.heightPx,
                                  timelineFillHeight: true,
                                  timeLabel: layout.projection?.plannedTimeLabel ?? '',
                                  displayIsDone: layout.task.isDone,
                                  toggleDoneEnabled: false,
                                  showProgressBar: planTimeCardShowProgressForVisual(
                                      layout.visualDensity),
                                  showFooterBreadcrumb:
                                      planTimeCardShowFooterBreadcrumbForVisual(
                                          layout.visualDensity),
                                  planEstimatedSeconds: planningWallEstimateSeconds(layout.task),
                                ),
                              ),
                          ]),
                        ),
                      )),
                    ],
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
