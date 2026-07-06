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

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.sizeOf(context).width >= kShellDesktopNavBreakpoint;
    final title = mode == CalendarViewMode.month
        ? DateFormat.yMMMM(loc).format(focusedMonth)
        : () {
            final start = dayFocusActive
                ? selectedDay.subtract(
                    Duration(days: selectedDay.weekday - 1),
                  )
                : weekAnchor;
            final end = start.add(const Duration(days: 6));
            return '${DateFormat.MMMd(loc).format(start)} – ${DateFormat.MMMd(loc).format(end)}';
          }();
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
          Row(
            children: [
              if (dayFocusActive)
                IconButton(
                  tooltip: t(loc, 'calendar_collapse'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onCollapse,
                ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: onPrev,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isWide ? 20 : null,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: onNext,
              ),
              if (dayFocusActive) const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SegmentedButton<CalendarViewMode>(
                segments: [
                  ButtonSegment(
                    value: CalendarViewMode.month,
                    label: Text(t(loc, 'calendar_month_view')),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: CalendarViewMode.week,
                    label: Text(t(loc, 'calendar_week_view')),
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
