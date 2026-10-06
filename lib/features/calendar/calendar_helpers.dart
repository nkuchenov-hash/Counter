// Shared date/mode helpers for Calendar feature UI (no Brain imports).
import 'package:counter/core/shell_adaptive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum CalendarViewMode { year, month, week, events }

DateTime calendarDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String calendarDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime calendarWeekStartMonday(DateTime anchor) =>
    anchor.subtract(Duration(days: anchor.weekday - 1));

bool calendarIsCompactPhoneWidth(double width) =>
    width < kShellDesktopNavBreakpoint;

/// Single-line month title without locale "г." orphan (e.g. RU «июль 2026 г.» wrap).
String calendarMonthHeaderTitle(DateTime month, String loc) {
  final monthName = DateFormat.MMMM(loc).format(month);
  return '$monthName ${month.year}';
}

/// Calendar chrome title. Mobile deliberately uses a large editorial scale so
/// the month reads as the primary object instead of another compact toolbar.
TextStyle? calendarHeaderTitleStyle(BuildContext context, {required bool compact}) {
  final base = Theme.of(context).textTheme.headlineMedium;
  if (!compact) {
    return base?.copyWith(fontWeight: FontWeight.w800, fontSize: 24, height: 1.05);
  }
  return base?.copyWith(
    fontWeight: FontWeight.w800,
    fontSize: 34,
    height: 1.02,
    letterSpacing: -0.8,
  );
}
