import 'package:counter/core/app_colors.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_day_events.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full-month 6×7 grid with weekday headers and per-day event indicators.
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
  });

  final DateTime focusedMonth;
  final DateTime? highlightDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final bool showEventPills;
  final bool browsing;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final weekdayLabels = List<String>.generate(
      7,
      (i) => DateFormat.E(loc).format(
        DateTime(2024, 1, 1 + i),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellH = constraints.maxHeight / 6;
              final maxEvents = cellH >= 100
                  ? 4
                  : cellH >= 72
                      ? 3
                      : 2;
              return Stack(
                children: [
                  Column(
                    children: [
                      for (var row = 0; row < 6; row++)
                        SizedBox(
                          height: cellH,
                          child: Row(
                            children: [
                              for (var col = 0; col < 7; col++)
                                Expanded(
                                  child: CalendarMonthDayCell(
                                    day: gridStart.add(
                                      Duration(days: row * 7 + col),
                                    ),
                                    focusedMonth: focusedMonth,
                                    highlightDay: highlightDay,
                                    today: today,
                                    tasks: tasksByDay[
                                            calendarDayKey(
                                              gridStart.add(
                                                Duration(
                                                  days: row * 7 + col,
                                                ),
                                              ),
                                            )] ??
                                        const [],
                                    showEventPills: showEventPills,
                                    maxVisibleEvents: maxEvents,
                                    browsing: browsing,
                                    onTap: onDayTap,
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
    final bg = _selected
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : _isToday
            ? AppColors.cardSurface
            : Colors.transparent;
    final side = _selected
        ? BorderSide(color: scheme.primary, width: 1.5)
        : _isToday
            ? BorderSide(color: scheme.primary.withValues(alpha: 0.5))
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35));

    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.fromBorderSide(side),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onTap(day),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: _selected || _isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _inMonth
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.35),
                        ),
                  ),
                  const SizedBox(height: 3),
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
        ),
      ),
    );
  }
}
