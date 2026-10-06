import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _CalendarChromeView { month, week, day }

/// Calendar navigation chrome. Desktop uses one compact row; phone/tablet keep
/// the existing two-row layout.
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
    required this.onDaySelected,
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
  final VoidCallback onDaySelected;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onCollapse;
  final bool showToday;

  String _title(bool compact) {
    if (!compact && dayFocusActive) {
      return DateFormat.yMMMEd(loc).format(selectedDay);
    }
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

  _CalendarChromeView get _desktopSelection {
    if (dayFocusActive) return _CalendarChromeView.day;
    return mode == CalendarViewMode.month
        ? _CalendarChromeView.month
        : _CalendarChromeView.week;
  }

  void _onDesktopSelection(Set<_CalendarChromeView> selection) {
    switch (selection.first) {
      case _CalendarChromeView.month:
        onModeChanged(CalendarViewMode.month);
      case _CalendarChromeView.week:
        onModeChanged(CalendarViewMode.week);
      case _CalendarChromeView.day:
        onDaySelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportW = MediaQuery.sizeOf(context).width;
    final compact = calendarIsCompactPhoneWidth(viewportW);
    final isWide = viewportW >= kShellDesktopNavBreakpoint;
    final title = _title(compact);
    final titleStyle = calendarHeaderTitleStyle(context, compact: compact);

    if (isWide) {
      final isRu = loc.toLowerCase().startsWith('ru');
      final weekStart = calendarWeekStartMonday(selectedDay);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final desktopTitle = dayFocusActive
          ? '${DateFormat.MMMd(loc).format(weekStart)} – ${DateFormat.MMMd(loc).format(weekEnd)}'
          : title;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          kShellDesktopContentHorizontalPadding,
          kShellDesktopContentTopPadding,
          kShellDesktopContentHorizontalPadding,
          6,
        ),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Text(
                t(loc, 'calendar'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: onPrev,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text(
                        desktopTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: onNext,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (showToday) ...[
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: onToday,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(t(loc, 'calendar_today')),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SegmentedButton<_CalendarChromeView>(
                segments: [
                  ButtonSegment(
                    value: _CalendarChromeView.month,
                    label: Text(t(loc, 'calendar_month_view')),
                  ),
                  ButtonSegment(
                    value: _CalendarChromeView.week,
                    label: Text(t(loc, 'calendar_week_view')),
                  ),
                  ButtonSegment(
                    value: _CalendarChromeView.day,
                    label: Text(isRu ? 'День' : 'Day'),
                  ),
                ],
                selected: {_desktopSelection},
                onSelectionChanged: _onDesktopSelection,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final monthLabel = DateFormat.MMMM(loc).format(focusedMonth);
    final yearLabel = '${focusedMonth.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dayFocusActive) ...[
                _CalendarRoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: t(loc, 'calendar_collapse'),
                  onPressed: onCollapse,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayFocusActive ? title : monthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayFocusActive
                          ? DateFormat.y(loc).format(selectedDay)
                          : yearLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CalendarRoundIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: null,
                onPressed: onPrev,
              ),
              const SizedBox(width: 6),
              _CalendarRoundIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: null,
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SegmentedButton<CalendarViewMode>(
                segments: [
                  ButtonSegment(
                    value: CalendarViewMode.month,
                    label: Text(t(loc, 'calendar_month_view')),
                  ),
                  ButtonSegment(
                    value: CalendarViewMode.week,
                    label: Text(t(loc, 'calendar_week_view')),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onModeChanged(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarRoundIconButton extends StatelessWidget {
  const _CalendarRoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 26, color: scheme.onSurface),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
