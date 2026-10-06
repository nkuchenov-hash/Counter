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
import 'package:intl/intl.dart';

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
  })
  onStartRecordFromTask;

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
  int _pageMotion = 0;
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
    _planningRefreshSub = DatabaseService.instance.planningRefreshEvents.listen(
      (_) {
        if (!mounted) return;
        unawaited(_reloadIndicators());
      },
    );
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
    switch (_mode) {
      case CalendarViewMode.year:
        return (
          start: DateTime(_focusedMonth.year, 1, 1),
          end: DateTime(_focusedMonth.year, 12, 31),
        );
      case CalendarViewMode.month:
        final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
        final last = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
        final gridStart = first.subtract(Duration(days: first.weekday - 1));
        final gridEnd = last.add(Duration(days: 7 - last.weekday));
        return (start: gridStart, end: gridEnd);
      case CalendarViewMode.week:
        final start = _dayFocusActive
            ? calendarWeekStartMonday(_selectedDay)
            : _weekAnchor;
        return (start: start, end: start.add(const Duration(days: 6)));
      case CalendarViewMode.events:
        final start = calendarDateOnly(_selectedDay);
        return (start: start, end: start.add(const Duration(days: 365)));
    }
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

  Future<void> _onDayTapped(DateTime day) async {
    final d = calendarDateOnly(day);
    setState(() {
      _selectedDay = d;
      _dayFocusActive = false;
      _dayStream = _createDayStream(d);
      _weekAnchor = calendarWeekStartMonday(d);
      if (_mode == CalendarViewMode.month &&
          (d.month != _focusedMonth.month || d.year != _focusedMonth.year)) {
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
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
    unawaited(_reloadIndicators());
  }

  void _shiftYear(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year + delta,
        _focusedMonth.month,
      );
    });
    unawaited(_reloadIndicators());
  }

  void _shiftWeek(int delta) {
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: delta * 7));
      _focusedMonth = DateTime(_weekAnchor.year, _weekAnchor.month);
    });
    unawaited(_reloadIndicators());
  }

  void _shiftDay(int delta) {
    unawaited(_onDayTapped(_selectedDay.add(Duration(days: delta))));
  }

  void _shiftEventsMonth(int delta) {
    final source = _selectedDay;
    final targetMonth = DateTime(source.year, source.month + delta, 1);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final next = DateTime(
      targetMonth.year,
      targetMonth.month,
      source.day > lastDay ? lastDay : source.day,
    );
    setState(() {
      _selectedDay = next;
      _focusedMonth = DateTime(next.year, next.month);
      _weekAnchor = calendarWeekStartMonday(next);
      _dayStream = _createDayStream(next);
    });
    unawaited(widget.onSelectDate(next, next));
    unawaited(_reloadIndicators());
  }

  void _shiftActivePeriod(int delta) {
    _pageMotion = delta.sign;
    if (_dayFocusActive) {
      _shiftDay(delta);
      return;
    }
    switch (_mode) {
      case CalendarViewMode.year:
        _shiftYear(delta);
      case CalendarViewMode.month:
        _shiftMonth(delta);
      case CalendarViewMode.week:
        _shiftWeek(delta);
      case CalendarViewMode.events:
        _shiftEventsMonth(delta);
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 260) return;
    _shiftActivePeriod(velocity < 0 ? 1 : -1);
  }

  void _setMode(CalendarViewMode mode) {
    setState(() {
      _dayFocusActive = false;
      _mode = mode;
      if (mode == CalendarViewMode.week) {
        _weekAnchor = calendarWeekStartMonday(_selectedDay);
      }
      if (mode == CalendarViewMode.year) {
        _focusedMonth = DateTime(_selectedDay.year, _selectedDay.month);
      }
    });
    unawaited(_reloadIndicators());
  }

  void _openMonthFromYear(DateTime month) {
    setState(() {
      _mode = CalendarViewMode.month;
      _dayFocusActive = false;
      _focusedMonth = DateTime(month.year, month.month);
    });
    unawaited(_reloadIndicators());
  }

  DateTime _taskDay(PlanningTask task) {
    final parsed = DateTime.tryParse(task.dateKey);
    if (parsed != null) return calendarDateOnly(parsed);
    final start = task.startTime;
    if (start != null) return calendarDateOnly(start);
    return _selectedDay;
  }

  Future<void> _openCalendarSearch() async {
    final all = <PlanningTask>[];
    final seen = <String>{};
    for (final tasks in _tasksByDayKey.values) {
      for (final task in tasks) {
        final key = '${task.planRowId ?? task.id}|${task.dateKey}';
        if (seen.add(key)) all.add(task);
      }
    }
    all.sort((a, b) {
      final dayCmp = _taskDay(a).compareTo(_taskDay(b));
      if (dayCmp != 0) return dayCmp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all.where((task) => task.title.toLowerCase().contains(q)).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: t(currentLocale.value, 'calendar_search_hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              t(currentLocale.value, 'calendar_no_events'),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final task = filtered[index];
                              final day = _taskDay(task);
                              return ListTile(
                                title: Text(task.title),
                                subtitle: Text(DateFormat.yMMMd(currentLocale.value).format(day)),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  unawaited(_onDayTapped(day));
                                  widget.onEditTask(task);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _calendarPageKey() {
    if (_dayFocusActive) return 'day-${calendarDayKey(_selectedDay)}';
    return switch (_mode) {
      CalendarViewMode.year => 'year-${_focusedMonth.year}',
      CalendarViewMode.month =>
        'month-${_focusedMonth.year}-${_focusedMonth.month}',
      CalendarViewMode.week => 'week-${calendarDayKey(_weekAnchor)}',
      CalendarViewMode.events => 'events-${calendarDayKey(_selectedDay)}',
    };
  }

  Widget _withHorizontalPaging(Widget child) {
    final pageKey = _calendarPageKey();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (transitionChild, animation) {
          final incoming = transitionChild.key == ValueKey<String>(pageKey);
          final direction = _pageMotion == 0 ? 1 : _pageMotion;
          final begin = Offset(
            incoming ? direction.toDouble() : -direction.toDouble(),
            0,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: transitionChild,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>(pageKey),
          child: child,
        ),
      ),
    );
  }

  void _openAddPlanForSelectedDay([String initialTitle = '']) {
    final d = _selectedDay;
    final dateKey = calendarDayKey(d);
    final categoryId =
        DatabaseService.instance.defaultCategoryId ??
        (DatabaseService.instance.rules.isNotEmpty
            ? DatabaseService.instance.rules.first.id
            : 0);
    final wall = DateTime(d.year, d.month, d.day, 9, 0);
    final draft = PlanningTask(
      id: 0,
      planRowId: null,
      title: initialTitle.trim(),
      categoryId: categoryId,
      isDone: false,
      dateKey: dateKey,
      order: 0,
      startTime: wall,
      date: DateTime.utc(d.year, d.month, d.day),
      endDateTime: null,
      checklist: const [],
      parentPlanId: null,
      initialDateKey: dateKey,
      isPostponed: false,
    );
    widget.onEditTask(draft);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final today = DatabaseService.instance.getTimelineDeviceLocalToday();
    final viewportW = MediaQuery.sizeOf(context).width;
    final showPills = calendarShowsEventPills(viewportW);
    final desktopCalendar = viewportW >= kShellDesktopNavBreakpoint;

    final calendarArea = Padding(
      padding: EdgeInsets.fromLTRB(
        desktopCalendar ? kShellDesktopContentHorizontalPadding : 20,
        desktopCalendar ? 4 : 2,
        desktopCalendar ? kShellDesktopContentHorizontalPadding : 20,
        desktopCalendar ? 8 : 92,
      ),
      child: desktopCalendar && _dayFocusActive
          ? CalendarWeekCompactStrip(
              weekStart: calendarWeekStartMonday(_selectedDay),
              selectedDay: _selectedDay,
              today: today,
              tasksByDay: _tasksByDayKey,
              onDayTap: (d) => unawaited(_onDayTapped(d)),
              minimal: true,
            )
          : _dayFocusActive
          ? CalendarWeekCompactStrip(
              weekStart: calendarWeekStartMonday(_selectedDay),
              selectedDay: _selectedDay,
              today: today,
              tasksByDay: _tasksByDayKey,
              onDayTap: (d) => unawaited(_onDayTapped(d)),
            )
          : switch (_mode) {
              CalendarViewMode.year => _CalendarYearGrid(
                  year: _focusedMonth.year,
                  selectedDay: _selectedDay,
                  today: today,
                  tasksByDay: _tasksByDayKey,
                  onMonthTap: _openMonthFromYear,
                  onDayTap: (d) => unawaited(_onDayTapped(d)),
                ),
              CalendarViewMode.month => CalendarMonthGrid(
                  focusedMonth: _focusedMonth,
                  highlightDay: _selectedDay,
                  today: today,
                  tasksByDay: _tasksByDayKey,
                  loading: _monthIndicatorsLoading,
                  showEventPills: showPills,
                  browsing: true,
                  onDayTap: (d) => unawaited(_onDayTapped(d)),
                  currentMonthOnly: true,
                ),
              CalendarViewMode.week => CalendarWeekPlannerGrid(
                  weekStart: _weekAnchor,
                  today: today,
                  tasksByDay: _tasksByDayKey,
                  loading: _monthIndicatorsLoading,
                  showEventPills: showPills,
                  onDayTap: (d) => unawaited(_onDayTapped(d)),
                  onTaskTap: widget.onEditTask,
                ),
              CalendarViewMode.events => _CalendarEventsList(
                  loc: loc,
                  selectedDay: _selectedDay,
                  tasksByDay: _tasksByDayKey,
                  onEditTask: widget.onEditTask,
                ),
            },
    );

    final body = SafeArea(
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
            onModeChanged: _setMode,
            onSearch: () => unawaited(_openCalendarSearch()),
            onToday: _goToday,
            onCollapse: _collapseDayFocus,
            showToday: !_isSameDay(_selectedDay, today),
          ),
          if (!_dayFocusActive)
            Expanded(child: _withHorizontalPaging(calendarArea))
          else if (desktopCalendar) ...[
            SizedBox(height: 58, child: _withHorizontalPaging(calendarArea)),
            const Divider(height: 1),
            Expanded(
              child: CalendarSelectedDayTaskPanel(
                loc: loc,
                selectedDay: _selectedDay,
                stream: _dayStream,
                onCollapse: _collapseDayFocus,
                onEditTask: widget.onEditTask,
                onAddPlan: _openAddPlanForSelectedDay,
                onStartRecordFromTask: widget.onStartRecordFromTask,
                desktopQuickAdd: true,
              ),
            ),
          ] else ...[
            Flexible(
              flex: _mode == CalendarViewMode.week ? 2 : 4,
              child: _withHorizontalPaging(calendarArea),
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
                onAddPlan: _openAddPlanForSelectedDay,
                onStartRecordFromTask: widget.onStartRecordFromTask,
              ),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: !desktopCalendar && !_dayFocusActive
          ? Stack(
              children: [
                Positioned.fill(child: body),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CalendarFloatingTextButton(
                        label: t(loc, 'calendar_today'),
                        onPressed: _goToday,
                      ),
                      _CalendarFloatingAddButton(
                        onPressed: () => _openAddPlanForSelectedDay(''),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : body,
    );
  }
}


class _CalendarFloatingTextButton extends StatelessWidget {
  const _CalendarFloatingTextButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarFloatingAddButton extends StatelessWidget {
  const _CalendarFloatingAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.98),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(Icons.add_rounded, size: 32, color: scheme.onSurface),
        ),
      ),
    );
  }
}


class _CalendarYearGrid extends StatelessWidget {
  const _CalendarYearGrid({
    required this.year,
    required this.selectedDay,
    required this.today,
    required this.tasksByDay,
    required this.onMonthTap,
    required this.onDayTap,
  });

  final int year;
  final DateTime selectedDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final ValueChanged<DateTime> onMonthTap;
  final ValueChanged<DateTime> onDayTap;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= kShellDesktopNavBreakpoint ? 4 : 3;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: width >= kShellDesktopNavBreakpoint ? 1.15 : 0.86,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = DateTime(year, index + 1, 1);
        final days = DateTime(year, index + 2, 0).day;
        final leading = month.weekday - 1;
        final rows = ((leading + days) / 7).ceil();
        final scheme = Theme.of(context).colorScheme;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onMonthTap(month),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat.MMM(loc).format(month),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selectedDay.year == year &&
                                selectedDay.month == month.month
                            ? scheme.primary
                            : scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Text(
                          DateFormat.E(loc)
                              .format(DateTime(2024, 1, 1 + i))
                              .characters
                              .first,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (var row = 0; row < rows; row++)
                        Expanded(
                          child: Row(
                            children: [
                              for (var col = 0; col < 7; col++)
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final dayNum = row * 7 + col - leading + 1;
                                      if (dayNum < 1 || dayNum > days) {
                                        return const SizedBox.shrink();
                                      }
                                      final day = DateTime(year, month.month, dayNum);
                                      final selected = _sameDay(day, selectedDay);
                                      final isToday = _sameDay(day, today);
                                      final hasTasks = (tasksByDay[calendarDayKey(day)] ?? const <PlanningTask>[]).isNotEmpty;
                                      return InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => onDayTap(day),
                                        child: Center(
                                          child: Container(
                                            width: 25,
                                            height: 25,
                                            alignment: Alignment.center,
                                            decoration: selected
                                                ? BoxDecoration(
                                                    color: scheme.primary,
                                                    shape: BoxShape.circle,
                                                  )
                                                : null,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.center,
                                              children: [
                                                Text(
                                                  '$dayNum',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        height: 1,
                                                        fontWeight: selected || isToday
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: selected
                                                            ? scheme.onPrimary
                                                            : isToday
                                                            ? scheme.primary
                                                            : scheme.onSurface,
                                                      ),
                                                ),
                                                if (hasTasks && !selected)
                                                  Positioned(
                                                    bottom: 1,
                                                    child: Container(
                                                      width: 3,
                                                      height: 3,
                                                      decoration: BoxDecoration(
                                                        color: scheme.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarEventsList extends StatelessWidget {
  const _CalendarEventsList({
    required this.loc,
    required this.selectedDay,
    required this.tasksByDay,
    required this.onEditTask,
  });

  final String loc;
  final DateTime selectedDay;
  final Map<String, List<PlanningTask>> tasksByDay;
  final ValueChanged<PlanningTask> onEditTask;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = calendarDateOnly(selectedDay);
    final entries = <({DateTime day, List<PlanningTask> tasks})>[];

    for (final entry in tasksByDay.entries) {
      final day = DateTime.tryParse(entry.key);
      if (day == null || day.isBefore(start)) continue;
      final tasks = entry.value.where((task) => !task.isDone).toList()
        ..sort((a, b) {
          final aStart = a.startTime;
          final bStart = b.startTime;
          if (aStart == null && bStart == null) return a.title.compareTo(b.title);
          if (aStart == null) return -1;
          if (bStart == null) return 1;
          return aStart.compareTo(bStart);
        });
      if (tasks.isNotEmpty) entries.add((day: day, tasks: tasks));
    }
    entries.sort((a, b) => a.day.compareTo(b.day));

    final firstHasSelected = entries.isNotEmpty &&
        calendarDayKey(entries.first.day) == calendarDayKey(start);
    final itemCount = entries.length + (firstHasSelected ? 0 : 1);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
      itemCount: itemCount,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.45),
      ),
      itemBuilder: (context, index) {
        if (!firstHasSelected && index == 0) {
          return _CalendarAgendaDay(
            loc: loc,
            day: start,
            tasks: const [],
            onEditTask: onEditTask,
          );
        }
        final entry = entries[index - (firstHasSelected ? 0 : 1)];
        return _CalendarAgendaDay(
          loc: loc,
          day: entry.day,
          tasks: entry.tasks,
          onEditTask: onEditTask,
        );
      },
    );
  }
}

class _CalendarAgendaDay extends StatelessWidget {
  const _CalendarAgendaDay({
    required this.loc,
    required this.day,
    required this.tasks,
    required this.onEditTask,
  });

  final String loc;
  final DateTime day;
  final List<PlanningTask> tasks;
  final ValueChanged<PlanningTask> onEditTask;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateLabel = DateFormat.MMMd(loc).format(day);
    final weekLabel = DateFormat.E(loc).format(day);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    weekLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      t(loc, 'calendar_no_events'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : Column(
                    children: [
                      for (final task in tasks)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onEditTask(task),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 3,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (task.startTime != null)
                                        Text(
                                          DateFormat.Hm(loc).format(task.startTime!),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
