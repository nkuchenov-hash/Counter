// ---------------------------------------------------------------------------
// CALENDAR FEATURE — Monthly view tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Calendar tab: TableCalendar, app bar with "Timeline" jump. Uses package paths and t().
class CalendarView extends StatelessWidget {
  const CalendarView({
    super.key,
    required this.selectedDate,
    required this.focusedDay,
    required this.onSelectDate,
    required this.onJumpToTimeline,
  });

  final DateTime selectedDate;
  final DateTime focusedDay;
  final Future<void> Function(DateTime selectedDay, DateTime focusedDay) onSelectDate;
  final VoidCallback onJumpToTimeline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(currentLocale.value, 'planning')),
        actions: [
          TextButton(
            onPressed: onJumpToTimeline,
            child: Text(t(currentLocale.value, 'timeline')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: TableCalendar(
          locale: currentLocale.value,
          firstDay: DateTime(2020, 1, 1),
          lastDay: DateTime(2100, 12, 31),
          focusedDay: focusedDay,
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (day) => isSameDay(day, selectedDate),
          onDaySelected: (selectedDay, focused) {
            unawaited(onSelectDate(selectedDay, focused));
            debugPrint('NAV_TRACE: Calendar tap - User selected: $selectedDay');
            onJumpToTimeline();
          },
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
      ),
    );
  }
}
