import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_day_events.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Week browsing grid — real time grid with hourly rows and positioned events.
class CalendarWeekPlannerGrid extends StatelessWidget {
  const CalendarWeekPlannerGrid({
    super.key,
    required this.weekStart,
    required this.today,
    required this.tasksByDay,
    required this.loading,
    required this.showEventPills,
    required this.onDayTap,
    required this.onTaskTap,
  });

  final DateTime weekStart;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final bool showEventPills;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<PlanningTask> onTaskTap;

  static const double _hourHeight = 64;
  static const double _timeGutter = 44;
  static const double _headerHeight = 52;

  double _topFor(DateTime time) =>
      (time.hour * 60 + time.minute) / 60 * _hourHeight;

  double _heightFor(PlanningTask task) {
    final start = task.startTime;
    if (start == null) return 0;
    final end = task.endDateTime ?? start.add(const Duration(minutes: 45));
    final minutes = end.difference(start).inMinutes.clamp(20, 24 * 60);
    return (minutes / 60 * _hourHeight).clamp(22.0, _hourHeight * 4);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final scrollController = ScrollController(
      initialScrollOffset: 7 * _hourHeight,
    );

    return Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: _timeGutter),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = weekStart.add(Duration(days: i));
                          final isToday =
                              day.year == today.year &&
                              day.month == today.month &&
                              day.day == today.day;
                          return InkWell(
                            onTap: () => onDayTap(day),
                            borderRadius: BorderRadius.circular(14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat.E(loc).format(day),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: scheme.onSurface,
                                          shape: BoxShape.circle,
                                        )
                                      : null,
                                  child: Text(
                                    '${day.day}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isToday
                                              ? scheme.surface
                                              : scheme.onSurface,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: SizedBox(
                  height: 24 * _hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _timeGutter,
                        child: Stack(
                          children: [
                            for (var hour = 0; hour < 24; hour++)
                              Positioned(
                                top: hour * _hourHeight - 7,
                                right: 6,
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.72),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            for (var hour = 0; hour <= 24; hour++)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: hour * _hourHeight,
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.42,
                                  ),
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < 7; i++)
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final day = weekStart.add(
                                          Duration(days: i),
                                        );
                                        final tasks =
                                            (tasksByDay[calendarDayKey(day)] ??
                                                    const <PlanningTask>[])
                                                .where(
                                                  (task) =>
                                                      task.startTime != null,
                                                )
                                                .toList()
                                              ..sort(
                                                (a, b) => a.startTime!.compareTo(
                                                  b.startTime!,
                                                ),
                                              );
                                        return DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: scheme.outlineVariant
                                                    .withValues(alpha: 0.34),
                                              ),
                                            ),
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              for (final task in tasks)
                                                Positioned(
                                                  top: _topFor(task.startTime!),
                                                  left: 2,
                                                  right: 2,
                                                  height: _heightFor(task),
                                                  child: Material(
                                                    color: scheme
                                                        .primaryContainer
                                                        .withValues(alpha: 0.72),
                                                    borderRadius:
                                                        BorderRadius.circular(7),
                                                    clipBehavior: Clip.antiAlias,
                                                    child: InkWell(
                                                      onTap: () =>
                                                          onTaskTap(task),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 5,
                                                              vertical: 4,
                                                            ),
                                                        child: Text(
                                                          task.title,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontSize: 10.5,
                                                                height: 1.05,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: scheme
                                                                    .onPrimaryContainer,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (loading)
          Positioned(
            top: 4,
            right: 4,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact week strip shown when a day is focused.
class CalendarWeekCompactStrip extends StatelessWidget {
  const CalendarWeekCompactStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.tasksByDay,
    required this.onDayTap,
    this.minimal = false,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final ValueChanged<DateTime> onDayTap;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final day = weekStart.add(Duration(days: i));
                final key = calendarDayKey(day);
                final tasks = tasksByDay[key] ?? const <PlanningTask>[];
                final selected =
                    day.year == selectedDay.year &&
                    day.month == selectedDay.month &&
                    day.day == selectedDay.day;
                final isToday =
                    day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;

                if (minimal) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: selected
                          ? scheme.primaryContainer.withValues(alpha: 0.65)
                          : isToday
                          ? scheme.surfaceContainerLow.withValues(alpha: 0.5)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: selected
                            ? BorderSide(color: scheme.primary, width: 1.5)
                            : isToday
                            ? BorderSide(
                                color: scheme.primary.withValues(alpha: 0.45),
                              )
                            : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onDayTap(day),
                        borderRadius: BorderRadius.circular(10),
                        child: Center(
                          child: Text(
                            '${DateFormat.E(loc).format(day)} ${day.day}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: isToday && !selected
                        ? scheme.surfaceContainerLow.withValues(alpha: 0.5)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isToday && !selected
                          ? BorderSide(
                              color: scheme.primary.withValues(alpha: 0.45),
                            )
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onDayTap(day),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.E(loc).format(day),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: selected
                                  ? BoxDecoration(
                                      color: scheme.primaryContainer.withValues(
                                        alpha: 0.65,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: scheme.primary,
                                        width: 1.5,
                                      ),
                                    )
                                  : null,
                              child: Text(
                                '${day.day}',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 4),
                            CalendarDayEventList(
                              tasks: tasks
                                  .where((t) => t.startTime != null)
                                  .toList(),
                              loc: loc,
                              showPills: false,
                              maxVisible: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
