// ---------------------------------------------------------------------------
// CALENDAR FEATURE — Full-screen month/week + focused-day task list.
// UI_ISOLATION (§7). FEATURE-FIRST (§17). All strings via t().
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_chrome_header.dart';
import 'package:counter/features/calendar/calendar_day_panel.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/features/calendar/calendar_month_grid.dart';
import 'package:counter/features/calendar/calendar_week_grid.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Calendar tab: Google Calendar–style browsing + focused-day details.
class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.selectedDate,
    required this.focusedDay,
    required this.onSelectDate,
    required this.onEditTask,
    required this.onStartRecordFromTask,
  });

  final DateTime selectedDate;
  final DateTime focusedDay;
  final Future<void> Function(DateTime selectedDay, DateTime focusedDay)
      onSelectDate;
  final void Function(PlanningTask task) onEditTask;
  final Future<void> Function(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) onStartRecordFromTask;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView>
    with AutomaticKeepAliveClientMixin {
  late DateTime _selectedDay;
  late DateTime _focusedMonth;
  late DateTime _weekAnchor;
  CalendarViewMode _mode = CalendarViewMode.month;
  bool _dayFocusActive = false;
  Map<String, List<PlanningTask>> _tasksByDayKey = {};
  bool _monthIndicatorsLoading = false;
  Stream<List<PlanningTask>>? _dayStream;
  StreamSubscription<void>? _planningRefreshSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedDay = calendarDateOnly(widget.selectedDate);
    _focusedMonth = DateTime(widget.focusedDay.year, widget.focusedDay.month);
    _weekAnchor = calendarWeekStartMonday(_selectedDay);
    _dayStream = _createDayStream(_selectedDay);
    unawaited(_warmAndReloadIndicators());
    _planningRefreshSub =
        DatabaseService.instance.planningRefreshEvents.listen((_) {
      if (!mounted) return;
      unawaited(_reloadIndicators());
    });
  }

  @override
  void didUpdateWidget(CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = calendarDateOnly(widget.selectedDate);
    if (!_isSameDay(next, _selectedDay)) {
      _selectedDay = next;
      _dayStream = _createDayStream(_selectedDay);
    }
  }

  @override
  void dispose() {
    _planningRefreshSub?.cancel();
    super.dispose();
  }

  Stream<List<PlanningTask>> _createDayStream(DateTime day) {
    return DatabaseService.instance.planningStream(
      day,
      listenToGlobalPlanningRefresh: true,
    );
  }

  Future<void> _warmAndReloadIndicators() async {
    await DatabaseService.instance.warmPlanningCacheForCalendar();
    if (!mounted) return;
    await _reloadIndicators();
  }

  ({DateTime start, DateTime end}) _visibleDataRange() {
    if (_mode == CalendarViewMode.week) {
      final start = _dayFocusActive
          ? calendarWeekStartMonday(_selectedDay)
          : _weekAnchor;
      return (start: start, end: start.add(const Duration(days: 6)));
    }
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final last = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final gridEnd = last.add(Duration(days: 7 - last.weekday));
    return (start: gridStart, end: gridEnd);
  }

  Future<void> _reloadIndicators() async {
    if (!mounted) return;
    setState(() => _monthIndicatorsLoading = true);
    final range = _visibleDataRange();
    final grouped = DatabaseService.instance
        .planningTasksGroupedByWallDayForRange(range.start, range.end);
    if (!mounted) return;
    setState(() {
      _tasksByDayKey = grouped;
      _monthIndicatorsLoading = false;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _collapseDayFocus() {
    if (!_dayFocusActive) return;
    setState(() => _dayFocusActive = false);
  }

  Future<void> _onDayTapped(DateTime day) async {
    final d = calendarDateOnly(day);
    if (_dayFocusActive && _isSameDay(d, _selectedDay)) {
      _collapseDayFocus();
      return;
    }
    setState(() {
      _selectedDay = d;
      _dayFocusActive = true;
      _dayStream = _createDayStream(d);
      _weekAnchor = calendarWeekStartMonday(d);
      if (d.month != _focusedMonth.month || d.year != _focusedMonth.year) {
        _focusedMonth = DateTime(d.year, d.month);
      }
    });
    await widget.onSelectDate(d, d);
    if (!mounted) return;
    unawaited(_reloadIndicators());
  }

  void _goToday() {
    final today = DatabaseService.instance.getTimelineDeviceLocalToday();
    setState(() {
      _selectedDay = today;
      _focusedMonth = DateTime(today.year, today.month);
      _weekAnchor = calendarWeekStartMonday(today);
      _dayStream = _createDayStream(today);
    });
    unawaited(widget.onSelectDate(today, today));
    unawaited(_reloadIndicators());
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
    });
    unawaited(_reloadIndicators());
  }

  void _shiftWeek(int delta) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final today = DatabaseService.instance.getTimelineDeviceLocalToday();
    final viewportW = MediaQuery.sizeOf(context).width;
    final showPills = calendarShowsEventPills(viewportW);

    final calendarArea = Padding(
      padding: EdgeInsets.fromLTRB(
        viewportW >= kShellDesktopNavBreakpoint ? 16 : 12,
        4,
        viewportW >= kShellDesktopNavBreakpoint ? 16 : 12,
        8,
      ),
      child: _mode == CalendarViewMode.month
          ? CalendarMonthGrid(
              focusedMonth: _focusedMonth,
              highlightDay: _dayFocusActive ? _selectedDay : null,
              today: today,
              tasksByDay: _tasksByDayKey,
              loading: _monthIndicatorsLoading,
              showEventPills: showPills,
              browsing: !_dayFocusActive,
              onDayTap: (d) => unawaited(_onDayTapped(d)),
            )
          : _dayFocusActive
              ? CalendarWeekCompactStrip(
                  weekStart: calendarWeekStartMonday(_selectedDay),
                  selectedDay: _selectedDay,
                  today: today,
                  tasksByDay: _tasksByDayKey,
                  onDayTap: (d) => unawaited(_onDayTapped(d)),
                )
              : CalendarWeekPlannerGrid(
                  weekStart: _weekAnchor,
                  today: today,
                  tasksByDay: _tasksByDayKey,
                  loading: _monthIndicatorsLoading,
                  showEventPills: showPills,
                  onDayTap: (d) => unawaited(_onDayTapped(d)),
                ),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalendarChromeHeader(
              loc: loc,
              scheme: scheme,
              mode: _mode,
              focusedMonth: _focusedMonth,
              selectedDay: _selectedDay,
              weekAnchor: _weekAnchor,
              dayFocusActive: _dayFocusActive,
              onModeChanged: (m) {
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
                  : _shiftWeek(1),
              onToday: _goToday,
              onCollapse: _collapseDayFocus,
              showToday: !_isSameDay(_selectedDay, today),
            ),
            if (!_dayFocusActive)
              Expanded(child: calendarArea)
            else ...[
              Flexible(
                flex: _mode == CalendarViewMode.week ? 2 : 4,
                child: calendarArea,
              ),
              const Divider(height: 1),
              Expanded(
                flex: _mode == CalendarViewMode.week ? 8 : 6,
                child: CalendarSelectedDayTaskPanel(
                  loc: loc,
                  selectedDay: _selectedDay,
                  stream: _dayStream,
                  onCollapse: _collapseDayFocus,
                  onEditTask: widget.onEditTask,
                  onStartRecordFromTask: widget.onStartRecordFromTask,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
