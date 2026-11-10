import 'dart:math' as math;

import 'package:counter/core/widgets/plan_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/widgets/planning_empty_states.dart';
import 'package:flutter/material.dart';

/// Lightweight, read-only cached page for Planning's native finger pager.
///
/// Never calls PocketBase, builds a render snapshot or creates another active
/// Planning stream. Heavy Time View controllers are not mounted in neighbors.
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
    if (tasks.isEmpty) return PlanningFrozenListEmptyState(scheme: scheme);
    if (timeMode) {
      return _FrozenTimePreview(
        tasks: tasks, scheme: scheme, wallDay: wallDay);
    }
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

/// Static rail and proportional card preview for Time mode. This deliberately
/// does not instantiate the interactive Time View or attach its ScrollController.
class _FrozenTimePreview extends StatelessWidget {
  const _FrozenTimePreview({
    required this.tasks, required this.scheme, required this.wallDay,
  });

  final List<PlanningTask> tasks;
  final ColorScheme scheme;
  final DateTime wallDay;
  static const double _hourPx = 152;

  @override
  Widget build(BuildContext context) {
    final range = PlanningSheetTimelinePrefs.cachedVisibleDayRange;
    final start = range?.start ?? PlanningSheetTimelinePrefs.defaultStartExtended;
    final end = range?.end ?? PlanningSheetTimelinePrefs.defaultEndExtended;
    final hours = PlanningSheetTimelinePrefs.visibleExtendedHoursOrdered(
      start, end);
    final rail = MediaQuery.sizeOf(context).width < 600 ? 32.0 : 88.0;
    final windowStart = PlanningSheetTimelinePrefs.windowStartWall(wallDay, start);
    final windowEnd = PlanningSheetTimelinePrefs.windowEndWall(wallDay, end);
    final entries = tasks.where((task) {
      final wall = task.startTime;
      return wall != null && wall.isBefore(windowEnd) &&
          !wall.isBefore(windowStart);
    }).toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    final height = hours.length * _hourPx;
    return ColoredBox(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          SizedBox(
            height: height,
            child: Stack(
              children: [
                for (var i = 0; i < hours.length; i++) ...[
                  Positioned(
                    top: i * _hourPx,
                    left: 0, width: rail,
                    child: Text(
                      PlanningSheetTimelinePrefs.formatExtendedHourClock(
                        hours[i]),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Positioned(
                    top: i * _hourPx + 8, left: rail, right: 0,
                    child: Divider(height: 1, color: scheme.outlineVariant),
                  ),
                ],
                for (final task in entries)
                  Positioned(
                    top: (task.startTime!.difference(windowStart).inMinutes
                        * _hourPx / 60).clamp(0.0, height - 38.0).toDouble(),
                    left: rail + 8, right: 8,
                    height: math.max(38.0, math.min(
                      task.endDateTime == null ? 55.0 :
                      task.endDateTime!.difference(task.startTime!).inMinutes
                          * _hourPx / 60, _hourPx * 4)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border(
                          left: BorderSide(color: scheme.primary, width: 4),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                        child: Text(task.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface, fontSize: 16,
                            fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
