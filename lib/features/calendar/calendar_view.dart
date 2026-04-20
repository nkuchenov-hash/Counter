// ---------------------------------------------------------------------------
// CALENDAR FEATURE — Monthly view tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Calendar tab: TableCalendar only (no duplicate planning header / timeline jump).
class CalendarView extends StatelessWidget {
  const CalendarView({
    super.key,
    required this.selectedDate,
    required this.focusedDay,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final DateTime focusedDay;
  final Future<void> Function(DateTime selectedDay, DateTime focusedDay)
      onSelectDate;

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
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
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('CalendarView: $e\n$st');
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              t(currentLocale.value, 'no_data_found'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }
}
