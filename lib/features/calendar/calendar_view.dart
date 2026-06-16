// ---------------------------------------------------------------------------
// CALENDAR FEATURE — Full-screen month/week + focused-day task list.
// UI_ISOLATION (§7). FEATURE-FIRST (§17). All strings via t().
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _CalendarViewMode { month, week }

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
  _CalendarViewMode _mode = _CalendarViewMode.month;
  bool _dayFocusActive = false;
  Map<String, List<PlanningTask>> _tasksByDayKey = {};
  bool _monthIndicatorsLoading = false;
  Stream<List<PlanningTask>>? _dayStream;
  StreamSubscription<void>? _planningRefreshSub;

  @override
  bool get wantKeepAlive => true;

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _weekStartMonday(DateTime anchor) =>
      anchor.subtract(Duration(days: anchor.weekday - 1));

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(widget.selectedDate);
    _focusedMonth = DateTime(widget.focusedDay.year, widget.focusedDay.month);
    _weekAnchor = _weekStartMonday(_selectedDay);
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
    final next = _dateOnly(widget.selectedDate);
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
    if (_mode == _CalendarViewMode.week) {
      final start = _dayFocusActive
          ? _weekStartMonday(_selectedDay)
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
    final d = _dateOnly(day);
    if (_dayFocusActive && _isSameDay(d, _selectedDay)) {
      _collapseDayFocus();
      return;
    }
    setState(() {
      _selectedDay = d;
      _dayFocusActive = true;
      _dayStream = _createDayStream(d);
      _weekAnchor = _weekStartMonday(d);
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
      _weekAnchor = _weekStartMonday(today);
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
      child: _mode == _CalendarViewMode.month
          ? _MonthGrid(
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
              ? _WeekCompactStrip(
                  weekStart: _weekStartMonday(_selectedDay),
                  selectedDay: _selectedDay,
                  today: today,
                  tasksByDay: _tasksByDayKey,
                  onDayTap: (d) => unawaited(_onDayTapped(d)),
                )
              : _WeekPlannerGrid(
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
            _CalendarChromeHeader(
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
                  if (m == _CalendarViewMode.week) {
                    _weekAnchor = _weekStartMonday(_selectedDay);
                  }
                });
                unawaited(_reloadIndicators());
              },
              onPrev: () => _mode == _CalendarViewMode.month
                  ? _shiftMonth(-1)
                  : _shiftWeek(-1),
              onNext: () => _mode == _CalendarViewMode.month
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
                flex: _mode == _CalendarViewMode.week ? 2 : 4,
                child: calendarArea,
              ),
              const Divider(height: 1),
              Expanded(
                flex: _mode == _CalendarViewMode.week ? 8 : 6,
                child: _SelectedDayTaskPanel(
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

class _CalendarChromeHeader extends StatelessWidget {
  const _CalendarChromeHeader({
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
  final _CalendarViewMode mode;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final DateTime weekAnchor;
  final bool dayFocusActive;
  final ValueChanged<_CalendarViewMode> onModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onCollapse;
  final bool showToday;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= kShellDesktopNavBreakpoint;
    final title = mode == _CalendarViewMode.month
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
      padding: EdgeInsets.fromLTRB(isWide ? 16 : 8, isWide ? 12 : 8, isWide ? 16 : 8, 4),
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
              SegmentedButton<_CalendarViewMode>(
                segments: [
                  ButtonSegment(
                    value: _CalendarViewMode.month,
                    label: Text(t(loc, 'calendar_month_view')),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: _CalendarViewMode.week,
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusedMonth,
    required this.highlightDay,
    required this.today,
    required this.tasksByDay,
    required this.loading,
    required this.showEventPills,
    required this.browsing,
    required this.onDayTap,
  });

  final DateTime focusedMonth;
  final DateTime? highlightDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final bool showEventPills;
  final bool browsing;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final weekdayLabels = List<String>.generate(
      7,
      (i) => DateFormat.E(loc).format(
        DateTime(2024, 1, 1 + i),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellH = constraints.maxHeight / 6;
              final maxEvents = cellH >= 100
                  ? 4
                  : cellH >= 72
                      ? 3
                      : 2;
              return Stack(
                children: [
                  Column(
                    children: [
                      for (var row = 0; row < 6; row++)
                        SizedBox(
                          height: cellH,
                          child: Row(
                            children: [
                              for (var col = 0; col < 7; col++)
                                Expanded(
                                  child: _MonthDayCell(
                                    day: gridStart.add(
                                      Duration(days: row * 7 + col),
                                    ),
                                    focusedMonth: focusedMonth,
                                    highlightDay: highlightDay,
                                    today: today,
                                    tasks: tasksByDay[
                                            _CalendarViewState._dayKey(
                                              gridStart.add(
                                                Duration(
                                                  days: row * 7 + col,
                                                ),
                                              ),
                                            )] ??
                                        const [],
                                    showEventPills: showEventPills,
                                    maxVisibleEvents: maxEvents,
                                    browsing: browsing,
                                    onTap: onDayTap,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (loading)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.focusedMonth,
    required this.highlightDay,
    required this.today,
    required this.tasks,
    required this.showEventPills,
    required this.maxVisibleEvents,
    required this.browsing,
    required this.onTap,
  });

  final DateTime day;
  final DateTime focusedMonth;
  final DateTime? highlightDay;
  final DateTime today;
  final List<PlanningTask> tasks;
  final bool showEventPills;
  final int maxVisibleEvents;
  final bool browsing;
  final ValueChanged<DateTime> onTap;

  bool get _inMonth => day.month == focusedMonth.month;
  bool get _selected =>
      highlightDay != null &&
      day.year == highlightDay!.year &&
      day.month == highlightDay!.month &&
      day.day == highlightDay!.day;
  bool get _isToday =>
      day.year == today.year &&
      day.month == today.month &&
      day.day == today.day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final scheduled = tasks.where((t) => t.startTime != null).toList();
    final bg = _selected
        ? scheme.primaryContainer.withValues(alpha: 0.5)
        : _isToday
            ? scheme.secondaryContainer.withValues(alpha: 0.28)
            : Colors.transparent;
    final side = _selected
        ? BorderSide(color: scheme.primary, width: 1.5)
        : _isToday
            ? BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8))
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35));

    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.fromBorderSide(side),
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onTap(day),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: _selected || _isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _inMonth
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.35),
                        ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: _DayEventList(
                      tasks: scheduled,
                      loc: loc,
                      showPills: showEventPills,
                      maxVisible: maxVisibleEvents,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekPlannerGrid extends StatelessWidget {
  const _WeekPlannerGrid({
    required this.weekStart,
    required this.today,
    required this.tasksByDay,
    required this.loading,
    required this.showEventPills,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final bool showEventPills;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final day = weekStart.add(Duration(days: i));
                    final key = _CalendarViewState._dayKey(day);
                    final tasks = tasksByDay[key] ?? const <PlanningTask>[];
                    final isToday = day.year == today.year &&
                        day.month == today.month &&
                        day.day == today.day;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isToday
                              ? scheme.secondaryContainer.withValues(alpha: 0.22)
                              : scheme.surfaceContainerLow.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                onTap: () => onDayTap(day),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                                  child: Column(
                                    children: [
                                      Text(
                                        DateFormat.E(loc).format(day),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        '${day.day}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                                  child: _DayEventList(
                                    tasks: tasks
                                        .where((t) => t.startTime != null)
                                        .toList(),
                                    loc: loc,
                                    showPills: showEventPills,
                                    maxVisible: 12,
                                    vertical: true,
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
        if (loading)
          Positioned(
            top: 4,
            right: 4,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekCompactStrip extends StatelessWidget {
  const _WeekCompactStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.tasksByDay,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final day = weekStart.add(Duration(days: i));
                final key = _CalendarViewState._dayKey(day);
                final tasks = tasksByDay[key] ?? const <PlanningTask>[];
                final selected = day.year == selectedDay.year &&
                    day.month == selectedDay.month &&
                    day.day == selectedDay.day;
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: selected
                        ? scheme.primaryContainer.withValues(alpha: 0.55)
                        : isToday
                            ? scheme.secondaryContainer.withValues(alpha: 0.3)
                            : scheme.surfaceContainerLow.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: selected
                          ? BorderSide(color: scheme.primary, width: 1.5)
                          : BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onDayTap(day),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.E(loc).format(day),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '${day.day}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            _DayEventList(
                              tasks: tasks
                                  .where((t) => t.startTime != null)
                                  .toList(),
                              loc: loc,
                              showPills: false,
                              maxVisible: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DayEventList extends StatelessWidget {
  const _DayEventList({
    required this.tasks,
    required this.loc,
    required this.showPills,
    required this.maxVisible,
    this.vertical = false,
  });

  final List<PlanningTask> tasks;
  final String loc;
  final bool showPills;
  final int maxVisible;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final visible = tasks.take(maxVisible).toList();
    final extra = tasks.length - visible.length;

    if (!showPills) {
      return Wrap(
        spacing: 3,
        runSpacing: 2,
        children: [
          for (final t in visible)
            Container(
              width: vertical ? double.infinity : 6,
              height: vertical ? 4 : 6,
              decoration: BoxDecoration(
                color: DatabaseService.instance
                    .getCategoryColor(t.categoryId)
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(vertical ? 2 : 99),
              ),
            ),
          if (extra > 0)
            Text(
              '+$extra',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _CalendarEventPill(task: t, loc: loc),
          ),
        if (extra > 0)
          Text(
            t(loc, 'calendar_more_tasks').replaceFirst('%s', '$extra'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }
}

class _CalendarEventPill extends StatelessWidget {
  const _CalendarEventPill({required this.task, required this.loc});

  final PlanningTask task;
  final String loc;

  String _timePrefix() {
    final st = task.startTime;
    if (st == null) return '';
    return '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')} ';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = DatabaseService.instance.getCategoryColor(task.categoryId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: tone.withValues(alpha: 0.88), width: 3),
        ),
      ),
      child: Text(
        '${_timePrefix()}${task.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
              decoration: task.isDone ? TextDecoration.lineThrough : null,
            ),
      ),
    );
  }
}

class _SelectedDayTaskPanel extends StatelessWidget {
  const _SelectedDayTaskPanel({
    required this.loc,
    required this.selectedDay,
    required this.stream,
    required this.onCollapse,
    required this.onEditTask,
    required this.onStartRecordFromTask,
  });

  final String loc;
  final DateTime selectedDay;
  final Stream<List<PlanningTask>>? stream;
  final VoidCallback onCollapse;
  final void Function(PlanningTask task) onEditTask;
  final Future<void> Function(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) onStartRecordFromTask;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = DateFormat.yMMMEd(loc).format(selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
              ),
              IconButton(
                tooltip: t(loc, 'calendar_collapse'),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                onPressed: onCollapse,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PlanningTask>>(
            stream: stream,
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <PlanningTask>[];
              final scheduled = all
                  .where((t) => t.startTime != null)
                  .toList()
                ..sort((a, b) {
                  final as = a.startTime;
                  final bs = b.startTime;
                  if (as == null || bs == null) return 0;
                  return as.compareTo(bs);
                });
              if (snapshot.connectionState == ConnectionState.waiting &&
                  scheduled.isEmpty) {
                return const Center(
                  child: AppLoading(size: AppLoadingSize.small),
                );
              }
              if (scheduled.isEmpty) {
                return AppEmptyState(message: t(loc, 'no_planned_tasks_date'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: scheduled.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = scheduled[index];
                  String timeLabel() {
                    final st = task.startTime;
                    if (st == null) return '';
                    String hhmm(DateTime t) =>
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    final et = task.endDateTime;
                    if (et != null) return '${hhmm(st)} – ${hhmm(et)}';
                    return hhmm(st);
                  }
                  return PlanTimeTaskCard(
                    task: task,
                    density: PlanTimeTaskCardDensity.medium,
                    timeLabel: timeLabel(),
                    displayIsDone: task.isDone,
                    toggleDoneEnabled:
                        !task.planRowIdForBackend.startsWith('optimistic-'),
                    onToggleDone: () {
                      final next = !task.isDone;
                      DatabaseService.instance.applyOptimisticPlanningTask(
                        task.copyWith(isDone: next),
                      );
                      unawaited(
                        DatabaseService.instance.updatePlanningTask(
                          task.planRowIdForBackend,
                          planBusinessId: task.planRowId,
                          isDone: next,
                          suppressAppSnack: true,
                        ),
                      );
                    },
                    onPlay: task.isDone
                        ? null
                        : () {
                            final dateKey = task.startTime != null
                                ? task.dateKey
                                : DatabaseService.instance
                                    .getTimelineDeviceLocalTodayDateKey();
                            unawaited(
                              onStartRecordFromTask(
                                task.title,
                                task.categoryId,
                                dateKey,
                                sourcePlanPocketRecordId:
                                    DatabaseService.pocketRelationIdOrNull(
                                  task.pocketRecordId,
                                ),
                              ),
                            );
                          },
                    onOpenMenu: (_) => onEditTask(task),
                    onTap: () => onEditTask(task),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
