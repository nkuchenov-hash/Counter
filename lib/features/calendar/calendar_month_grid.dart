import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_day_events.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Month grid with weekday headers and per-day event indicators.
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.focusedMonth,
    required this.highlightDay,
    required this.today,
    required this.tasksByDay,
    required this.loading,
    required this.showEventPills,
    required this.browsing,
    required this.onDayTap,
    this.currentMonthOnly = false,
  });

  final DateTime focusedMonth;
  final DateTime? highlightDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final bool showEventPills;
  final bool browsing;
  final ValueChanged<DateTime> onDayTap;
  final bool currentMonthOnly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final last = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final gridEnd = last.add(Duration(days: 7 - last.weekday));
    final monthRowCount = currentMonthOnly
        ? (gridEnd.difference(gridStart).inDays + 1) ~/ 7
        : 6;
    final weekdayLabels = List<String>.generate(
      7,
      (i) => DateFormat.E(loc).format(DateTime(2024, 1, 1 + i)),
    );

    return Column(
      children: [
        Container(
          height: 42,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellH = constraints.maxHeight / monthRowCount;
              final maxEvents = cellH >= 100
                  ? 4
                  : cellH >= 72
                  ? 3
                  : 2;
              return Stack(
                children: [
                  Column(
                    children: [
                      for (var row = 0; row < monthRowCount; row++)
                        SizedBox(
                          height: cellH,
                          child: Row(
                            children: [
                              for (var col = 0; col < 7; col++)
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final day = gridStart.add(
                                        Duration(days: row * 7 + col),
                                      );
                                      final inFocusedMonth =
                                          day.year == focusedMonth.year &&
                                          day.month == focusedMonth.month;
                                      return inFocusedMonth
                                          ? CalendarMonthDayCell(
                                                day: day,
                                                focusedMonth: focusedMonth,
                                                highlightDay: highlightDay,
                                                today: today,
                                                tasks: tasksByDay[
                                                        calendarDayKey(day)] ??
                                                    const [],
                                                showEventPills: showEventPills,
                                                maxVisibleEvents: maxEvents,
                                                browsing: browsing,
                                              onTap: onDayTap,
                                            )
                                          : const SizedBox.expand();
                                    },
                                  ),
                                ),
                            ],
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
            },
          ),
        ),
      ],
    );
  }
}

class CalendarMonthDayCell extends StatelessWidget {
  const CalendarMonthDayCell({
    super.key,
    required this.day,
    required this.focusedMonth,
    required this.highlightDay,
    required this.today,
    required this.tasks,
    required this.showEventPills,
    required this.maxVisibleEvents,
    required this.browsing,
    required this.onTap,
  });

  final DateTime day;
  final DateTime focusedMonth;
  final DateTime? highlightDay;
  final DateTime today;
  final List<PlanningTask> tasks;
  final bool showEventPills;
  final int maxVisibleEvents;
  final bool browsing;
  final ValueChanged<DateTime> onTap;

  bool get _inMonth => day.month == focusedMonth.month;
  bool get _selected =>
      highlightDay != null &&
      day.year == highlightDay!.year &&
      day.month == highlightDay!.month &&
      day.day == highlightDay!.day;
  bool get _isToday =>
      day.year == today.year &&
      day.month == today.month &&
      day.day == today.day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final scheduled = tasks.where((t) => t.startTime != null).toList();

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CalendarDayNumberBadge(
                      label: '${day.day}',
                      inMonth: _inMonth,
                      selected: _selected,
                      isToday: _isToday,
                      scheme: scheme,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: CalendarDayEventList(
                    tasks: scheduled,
                    loc: loc,
                    showPills: showEventPills,
                    maxVisible: maxVisibleEvents,
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}

/// Fixed-size day number capsule — selection does not stretch the whole cell.
class _CalendarDayNumberBadge extends StatelessWidget {
  const _CalendarDayNumberBadge({
    required this.label,
    required this.inMonth,
    required this.selected,
    required this.isToday,
    required this.scheme,
  });

  static const double _size = 40;

  final String label;
  final bool inMonth;
  final bool selected;
  final bool isToday;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final fg = !inMonth
        ? scheme.onSurface.withValues(alpha: 0.35)
        : scheme.onSurface;
    BoxDecoration? decoration;
    if (selected) {
      decoration = BoxDecoration(
        color: scheme.onSurface,
        borderRadius: BorderRadius.circular(999),
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      );
    }

    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: decoration,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: selected || isToday
                  ? FontWeight.w700
                  : FontWeight.w500,
              fontSize: 18,
              height: 1,
              color: selected ? scheme.surface : (isToday ? scheme.primary : fg),
            ),
          ),
        ),
      ),
    );
  }
}
