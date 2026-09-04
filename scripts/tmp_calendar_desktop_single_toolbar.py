from pathlib import Path

header = r'''import 'package:counter/core/shell_adaptive.dart';
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
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
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: onPrev,
                visualDensity: VisualDensity.compact,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
                child: Text(
                  title,
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
              const SizedBox(width: 18),
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
        ),
      );
    }

    final sidePad = dayFocusActive ? (compact ? 88.0 : 96.0) : 48.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
                style: const ButtonStyle(
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
'''
Path('lib/features/calendar/calendar_chrome_header.dart').write_text(header, encoding='utf-8')

p = Path('lib/features/calendar/calendar_view.dart')
text = p.read_text(encoding='utf-8')

def one(old, new):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'calendar_view expected one match, got {count}: {old[:80]!r}')
    text = text.replace(old, new, 1)

one(
"""  void _collapseDayFocus() {
    if (!_dayFocusActive) return;
    setState(() => _dayFocusActive = false);
  }

  Future<void> _onDayTapped(DateTime day) async {""",
"""  void _collapseDayFocus() {
    if (!_dayFocusActive) return;
    setState(() => _dayFocusActive = false);
  }

  void _activateDayView() {
    final d = _selectedDay;
    setState(() {
      _mode = CalendarViewMode.week;
      _dayFocusActive = true;
      _weekAnchor = calendarWeekStartMonday(d);
      _dayStream = _createDayStream(d);
    });
    unawaited(widget.onSelectDate(d, d));
    unawaited(_reloadIndicators());
  }

  Future<void> _onDayTapped(DateTime day) async {""",
)
one(
"""  void _shiftWeek(int delta) {
    if (_dayFocusActive) {
      unawaited(
        _onDayTapped(_selectedDay.add(Duration(days: delta * 7))),
      );
      return;
    }
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: delta * 7));
    });
    unawaited(_reloadIndicators());
  }

  void _openAddPlanForSelectedDay() {""",
"""  void _shiftWeek(int delta) {
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: delta * 7));
    });
    unawaited(_reloadIndicators());
  }

  void _shiftDay(int delta) {
    unawaited(_onDayTapped(_selectedDay.add(Duration(days: delta))));
  }

  void _openAddPlanForSelectedDay() {""",
)
one(
"""              onModeChanged: (m) {
                setState(() {
                  _mode = m;
                  if (m == CalendarViewMode.week) {
                    _weekAnchor = calendarWeekStartMonday(_selectedDay);
                  }
                });
                unawaited(_reloadIndicators());
              },
              onPrev: () => _mode == CalendarViewMode.month
                  ? _shiftMonth(-1)
                  : _shiftWeek(-1),
              onNext: () => _mode == CalendarViewMode.month
                  ? _shiftMonth(1)
                  : _shiftWeek(1),""",
"""              onModeChanged: (m) {
                setState(() {
                  _dayFocusActive = false;
                  _mode = m;
                  if (m == CalendarViewMode.week) {
                    _weekAnchor = calendarWeekStartMonday(_selectedDay);
                  }
                });
                unawaited(_reloadIndicators());
              },
              onDaySelected: _activateDayView,
              onPrev: () => _dayFocusActive
                  ? _shiftDay(-1)
                  : _mode == CalendarViewMode.month
                      ? _shiftMonth(-1)
                      : _shiftWeek(-1),
              onNext: () => _dayFocusActive
                  ? _shiftDay(1)
                  : _mode == CalendarViewMode.month
                      ? _shiftMonth(1)
                      : _shiftWeek(1),""",
)
p.write_text(text, encoding='utf-8')

p = Path('lib/app/shell/shared/shell_chrome.dart')
text = p.read_text(encoding='utf-8')
old = """                                  if (formFactor == ShellFormFactor.desktop)
                                    Padding("""
new = """                                  if (formFactor == ShellFormFactor.desktop &&
                                      shellPageIndex != 2)
                                    Padding("""
if text.count(old) != 1:
    raise SystemExit('shell desktop heading condition not found exactly once')
p.write_text(text.replace(old, new, 1), encoding='utf-8')

p = Path('docs/DESIGN_SYSTEM.md')
text = p.read_text(encoding='utf-8')
needle = 'Phone and tablet chrome remain feature-adaptive unless separately specified.'
replacement = needle + ' Calendar is the desktop exception for section-heading placement: its section title, period navigation, and Month / Week / Day selector share one feature toolbar row directly below the global LIFE OS header.'
if text.count(needle) != 1:
    raise SystemExit('DESIGN_SYSTEM desktop shell sentence not found exactly once')
p.write_text(text.replace(needle, replacement, 1), encoding='utf-8')
