import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Calendar navigation chrome.
///
/// Period navigation is swipe-first. The center calendar button expands the
/// four view choices inline, matching the mobile reference instead of opening
/// a generic vertical popup menu.
class CalendarChromeHeader extends StatefulWidget {
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

  @override
  State<CalendarChromeHeader> createState() => _CalendarChromeHeaderState();
}

class _CalendarChromeHeaderState extends State<CalendarChromeHeader> {
  bool _viewMenuOpen = false;

  String get _title {
    switch (widget.mode) {
      case CalendarViewMode.year:
        return '${widget.focusedMonth.year}';
      case CalendarViewMode.month:
        return DateFormat.MMMM(widget.loc).format(widget.focusedMonth);
      case CalendarViewMode.week:
        final start = widget.dayFocusActive
            ? calendarWeekStartMonday(widget.selectedDay)
            : widget.weekAnchor;
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return DateFormat.MMMM(widget.loc).format(start);
        }
        return '${DateFormat.MMM(widget.loc).format(start)}–${DateFormat.MMM(widget.loc).format(end)}';
      case CalendarViewMode.events:
        return DateFormat.MMMM(widget.loc).format(widget.selectedDay);
    }
  }

  String get _subtitle {
    if (widget.mode == CalendarViewMode.year) return '';
    return '${widget.mode == CalendarViewMode.week ? widget.weekAnchor.year : widget.focusedMonth.year}';
  }

  IconData _modeIcon(CalendarViewMode value) {
    return switch (value) {
      CalendarViewMode.year => Icons.calendar_view_month_rounded,
      CalendarViewMode.month => Icons.calendar_month_rounded,
      CalendarViewMode.week => Icons.calendar_view_week_rounded,
      CalendarViewMode.events => Icons.view_agenda_outlined,
    };
  }

  String _modeLabel(CalendarViewMode value) {
    return switch (value) {
      CalendarViewMode.year => t(widget.loc, 'calendar_year_view'),
      CalendarViewMode.month => t(widget.loc, 'calendar_month_view'),
      CalendarViewMode.week => t(widget.loc, 'calendar_week_view'),
      CalendarViewMode.events => t(widget.loc, 'calendar_events_view'),
    };
  }

  void _selectMode(CalendarViewMode value) {
    setState(() => _viewMenuOpen = false);
    widget.onModeChanged(value);
  }

  Widget _moreMenu(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-110, 8),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.today_rounded),
          onPressed: widget.onToday,
          child: Text(t(widget.loc, 'calendar_today')),
        ),
        if (widget.dayFocusActive)
          MenuItemButton(
            leadingIcon: const Icon(Icons.calendar_month_rounded),
            onPressed: widget.onCollapse,
            child: Text(t(widget.loc, 'calendar_collapse')),
          ),
      ],
      builder: (context, controller, child) => AppIconButton(
        icon: Icons.more_vert_rounded,
        tooltip: t(widget.loc, 'calendar_more_menu'),
        size: AppIconButtonSize.l,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _actionCapsule(BuildContext context) {
    return Material(
      color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: widget.scheme.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.search_rounded,
              tooltip: t(widget.loc, 'calendar_search'),
              size: AppIconButtonSize.l,
              onPressed: widget.onSearch,
            ),
            AppIconButton(
              icon: _modeIcon(widget.mode),
              tooltip: t(widget.loc, 'calendar_view_mode'),
              selected: _viewMenuOpen,
              size: AppIconButtonSize.l,
              onPressed: () => setState(() => _viewMenuOpen = !_viewMenuOpen),
            ),
            _moreMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _viewStrip(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !_viewMenuOpen
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  for (final value in CalendarViewMode.values) ...[
                    if (value != CalendarViewMode.values.first)
                      const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: value == widget.mode
                            ? widget.scheme.primaryContainer.withValues(alpha: 0.65)
                            : widget.scheme.surfaceContainerLow.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _selectMode(value),
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            height: 88,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _modeIcon(value),
                                  size: 27,
                                  color: value == widget.mode
                                      ? widget.scheme.primary
                                      : widget.scheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  _modeLabel(value),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: value == widget.mode
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: value == widget.mode
                                            ? widget.scheme.primary
                                            : widget.scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportW = MediaQuery.sizeOf(context).width;
    final isWide = viewportW >= kShellDesktopNavBreakpoint;
    final horizontalPadding =
        isWide ? kShellDesktopContentHorizontalPadding : 20.0;
    final topPadding = isWide ? kShellDesktopContentTopPadding : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: calendarHeaderTitleStyle(
                        context,
                        compact: !isWide,
                      ),
                    ),
                    if (_subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        _subtitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: widget.scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _actionCapsule(context),
            ],
          ),
          _viewStrip(context),
        ],
      ),
    );
  }
}
