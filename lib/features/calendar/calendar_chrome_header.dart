import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Month/week mode toggle, prev/next, Today, collapse — top chrome row.
class CalendarChromeHeader extends StatelessWidget {
  const CalendarChromeHeader({
    super.key,
    required this.loc,
    required this.scheme,
    required this.mode,
    required this.focusedMonth,
    required this.selectedDay,
    required this.weekAnchor,
    required this.dayFocusActive,
    required this.onModeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onCollapse,
    required this.showToday,
  });

  final String loc;
  final ColorScheme scheme;
  final CalendarViewMode mode;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final DateTime weekAnchor;
  final bool dayFocusActive;
  final ValueChanged<CalendarViewMode> onModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onCollapse;
  final bool showToday;

  String _title(bool compact) {
    if (mode == CalendarViewMode.month) {
      return calendarMonthHeaderTitle(focusedMonth, loc);
    }
    final start = dayFocusActive
        ? selectedDay.subtract(Duration(days: selectedDay.weekday - 1))
        : weekAnchor;
    final end = start.add(const Duration(days: 6));
    if (compact) {
      return '${DateFormat.MMMd(loc).format(start)}–${DateFormat.MMMd(loc).format(end)}';
    }
    return '${DateFormat.MMMd(loc).format(start)} – ${DateFormat.MMMd(loc).format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final viewportW = MediaQuery.sizeOf(context).width;
    final compact = calendarIsCompactPhoneWidth(viewportW);
    final isWide = viewportW >= kShellDesktopNavBreakpoint;
    final title = _title(compact);
    final titleStyle = calendarHeaderTitleStyle(context, compact: compact);
    final sidePad = dayFocusActive ? (compact ? 88.0 : 96.0) : 48.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 16 : 8,
        isWide ? 12 : 8,
        isWide ? 16 : 8,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    if (dayFocusActive)
                      IconButton(
                        tooltip: t(loc, 'calendar_collapse'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onCollapse,
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: onPrev,
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: onNext,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: sidePad),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SegmentedButton<CalendarViewMode>(
                segments: [
                  ButtonSegment(
                    value: CalendarViewMode.month,
                    label: Text(
                      t(loc, 'calendar_month_view'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: CalendarViewMode.week,
                    label: Text(
                      t(loc, 'calendar_week_view'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: const Icon(Icons.view_week_rounded, size: 18),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onModeChanged(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (showToday)
                FilledButton.tonal(
                  onPressed: onToday,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(t(loc, 'calendar_today')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
