import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_day_events.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Week browsing grid — seven columns with scrollable event pills per day.
class CalendarWeekPlannerGrid extends StatelessWidget {
  const CalendarWeekPlannerGrid({
    super.key,
    required this.weekStart,
    required this.today,
    required this.tasksByDay,
    required this.loading,
    required this.showEventPills,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final bool showEventPills;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final day = weekStart.add(Duration(days: i));
                    final key = calendarDayKey(day);
                    final tasks = tasksByDay[key] ?? const <PlanningTask>[];
                    final isToday =
                        day.year == today.year &&
                        day.month == today.month &&
                        day.day == today.day;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isToday
                              ? scheme.secondaryContainer.withValues(
                                  alpha: 0.22,
                                )
                              : scheme.surfaceContainerLow.withValues(
                                  alpha: 0.35,
                                ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                onTap: () => onDayTap(day),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    6,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        DateFormat.E(loc).format(day),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        '${day.day}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    0,
                                    4,
                                    6,
                                  ),
                                  child: CalendarDayEventList(
                                    tasks: tasks
                                        .where((t) => t.startTime != null)
                                        .toList(),
                                    loc: loc,
                                    showPills: showEventPills,
                                    maxVisible: 12,
                                    vertical: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
