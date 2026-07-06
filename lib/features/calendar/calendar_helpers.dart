/// Shared date/mode helpers for Calendar feature UI (no Brain imports).
enum CalendarViewMode { month, week }

DateTime calendarDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String calendarDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime calendarWeekStartMonday(DateTime anchor) =>
    anchor.subtract(Duration(days: anchor.weekday - 1));
