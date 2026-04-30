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
class CalendarView extends StatefulWidget {
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
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView>
    with AutomaticKeepAliveClientMixin {
  late DateTime _focusedDay;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay;
  }

  // No didUpdateWidget — _focusedDay is owned entirely by local state.
  // TableCalendarBase.didUpdateWidget jumps pages whenever focusedDay changes,
  // so we must never let widget.focusedDay (parent state) overwrite _focusedDay.

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final scheme = Theme.of(context).colorScheme;
    try {
      return Scaffold(
        body: SafeArea(
          child: TableCalendar(
            locale: currentLocale.value,
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            sixWeekMonthsEnforced: true,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(day, widget.selectedDate),
            onDaySelected: (selectedDay, focused) {
              setState(() => _focusedDay = focused);
              unawaited(widget.onSelectDate(selectedDay, focused));
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: true,
              outsideTextStyle: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
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
