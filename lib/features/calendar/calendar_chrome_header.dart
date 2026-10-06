import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Calendar navigation chrome.
///
/// Phone/tablet follows the compact reference pattern: title below a floating
/// action capsule. Horizontal date arrows are intentionally absent; period
/// navigation belongs to left/right swipe on the calendar surface.
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
    required this.onSearch,
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
  final VoidCallback onSearch;
  final VoidCallback onToday;
  final VoidCallback onCollapse;
  final bool showToday;

  String _title() {
    switch (mode) {
      case CalendarViewMode.year:
        return '${focusedMonth.year}';
      case CalendarViewMode.month:
        return DateFormat.MMMM(loc).format(focusedMonth);
      case CalendarViewMode.week:
        final start = dayFocusActive
            ? calendarWeekStartMonday(selectedDay)
            : weekAnchor;
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return DateFormat.MMMM(loc).format(start);
        }
        return '${DateFormat.MMM(loc).format(start)}–${DateFormat.MMM(loc).format(end)}';
      case CalendarViewMode.events:
        return DateFormat.MMMM(loc).format(selectedDay);
    }
  }

  String _subtitle() {
    if (mode == CalendarViewMode.year) return '';
    return '${mode == CalendarViewMode.week ? weekAnchor.year : focusedMonth.year}';
  }

  IconData _modeIcon(CalendarViewMode value) {
    return switch (value) {
      CalendarViewMode.year => Icons.calendar_view_month_rounded,
      CalendarViewMode.month => Icons.calendar_month_rounded,
      CalendarViewMode.week => Icons.calendar_view_week_rounded,
      CalendarViewMode.events => Icons.view_agenda_outlined,
    };
  }

  Widget _modeMenu(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-72, 8),
      menuChildren: [
        for (final value in CalendarViewMode.values)
          MenuItemButton(
            leadingIcon: Icon(_modeIcon(value)),
            trailingIcon: value == mode
                ? Icon(Icons.check_rounded, color: scheme.primary)
                : const SizedBox(width: 24),
            onPressed: () => onModeChanged(value),
            child: Text(
              switch (value) {
                CalendarViewMode.year => t(loc, 'calendar_year_view'),
                CalendarViewMode.month => t(loc, 'calendar_month_view'),
                CalendarViewMode.week => t(loc, 'calendar_week_view'),
                CalendarViewMode.events => t(loc, 'calendar_events_view'),
              },
            ),
          ),
      ],
      builder: (context, controller, child) => AppIconButton(
        icon: _modeIcon(mode),
        tooltip: t(loc, 'calendar_view_mode'),
        selected: true,
        size: AppIconButtonSize.l,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _moreMenu(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-110, 8),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.today_rounded),
          onPressed: onToday,
          child: Text(t(loc, 'calendar_today')),
        ),
        if (dayFocusActive)
          MenuItemButton(
            leadingIcon: const Icon(Icons.calendar_month_rounded),
            onPressed: onCollapse,
            child: Text(t(loc, 'calendar_collapse')),
          ),
      ],
      builder: (context, controller, child) => AppIconButton(
        icon: Icons.more_vert_rounded,
        tooltip: t(loc, 'calendar_more_menu'),
        size: AppIconButtonSize.l,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _actionCapsule(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.search_rounded,
              tooltip: t(loc, 'calendar_search'),
              size: AppIconButtonSize.l,
              onPressed: onSearch,
            ),
            _modeMenu(context),
            _moreMenu(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportW = MediaQuery.sizeOf(context).width;
    final isWide = viewportW >= kShellDesktopNavBreakpoint;
    final title = _title();
    final subtitle = _subtitle();

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          kShellDesktopContentHorizontalPadding,
          kShellDesktopContentTopPadding,
          kShellDesktopContentHorizontalPadding,
          8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: calendarHeaderTitleStyle(context, compact: false),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                ],
              ),
            ),
            _actionCapsule(context),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _actionCapsule(context),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: calendarHeaderTitleStyle(context, compact: true),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
