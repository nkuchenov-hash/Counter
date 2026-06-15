// ---------------------------------------------------------------------------
// CALENDAR FEATURE — Month/week calendar + selected-day task list.
// UI_ISOLATION (§7). FEATURE-FIRST (§17). All strings via t().
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _CalendarViewMode { month, week }

/// Calendar tab: month or week strip at top, scheduled plans for selected day below.
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
  _CalendarViewMode _mode = _CalendarViewMode.month;
  bool _userCondensedCalendar = false;
  Map<String, List<PlanningTask>> _tasksByDayKey = {};
  bool _monthIndicatorsLoading = false;
  Stream<List<PlanningTask>>? _dayStream;
  StreamSubscription<void>? _planningRefreshSub;

  @override
  bool get wantKeepAlive => true;

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(widget.selectedDate);
    _focusedMonth = DateTime(widget.focusedDay.year, widget.focusedDay.month);
    _dayStream = _createDayStream(_selectedDay);
    unawaited(_warmAndReloadIndicators());
    _planningRefreshSub =
        DatabaseService.instance.planningRefreshEvents.listen((_) {
      if (!mounted) return;
      unawaited(_reloadMonthIndicators());
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
    await _reloadMonthIndicators();
  }

  Future<void> _reloadMonthIndicators() async {
    if (!mounted) return;
    setState(() => _monthIndicatorsLoading = true);
    final range = _visibleGridRange(_focusedMonth);
    final grouped = DatabaseService.instance
        .planningTasksGroupedByWallDayForRange(range.start, range.end);
    if (!mounted) return;
    setState(() {
      _tasksByDayKey = grouped;
      _monthIndicatorsLoading = false;
    });
  }

  ({DateTime start, DateTime end}) _visibleGridRange(DateTime focusedMonth) {
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final last = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final gridEnd = last.add(Duration(days: 7 - last.weekday));
    return (start: gridStart, end: gridEnd);
  }

  DateTime _weekStripStart(DateTime anchor) {
    return anchor.subtract(Duration(days: anchor.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _selectDay(DateTime day, {bool userTap = false}) async {
    final d = _dateOnly(day);
    setState(() {
      _selectedDay = d;
      _userCondensedCalendar = userTap || _userCondensedCalendar;
      _dayStream = _createDayStream(d);
      if (d.month != _focusedMonth.month || d.year != _focusedMonth.year) {
        _focusedMonth = DateTime(d.year, d.month);
      }
    });
    await widget.onSelectDate(d, d);
    if (!mounted) return;
    unawaited(_reloadMonthIndicators());
  }

  void _goToday() {
    final today = DatabaseService.instance.getTimelineDeviceLocalToday();
    unawaited(_selectDay(today, userTap: false));
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
    });
    unawaited(_reloadMonthIndicators());
  }

  void _shiftWeek(int delta) {
    final next = _selectedDay.add(Duration(days: delta * 7));
    unawaited(_selectDay(next, userTap: true));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final today = DatabaseService.instance.getTimelineDeviceLocalToday();
    final calendarFlex = _mode == _CalendarViewMode.week
        ? 2
        : (_userCondensedCalendar ? 4 : 6);
    final listFlex = _mode == _CalendarViewMode.week
        ? 8
        : (_userCondensedCalendar ? 6 : 4);

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
              onModeChanged: (m) => setState(() => _mode = m),
              onPrev: () => _mode == _CalendarViewMode.month
                  ? _shiftMonth(-1)
                  : _shiftWeek(-1),
              onNext: () => _mode == _CalendarViewMode.month
                  ? _shiftMonth(1)
                  : _shiftWeek(1),
              onToday: _goToday,
              showToday: !_isSameDay(_selectedDay, today),
            ),
            Flexible(
              flex: calendarFlex,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: _mode == _CalendarViewMode.month
                    ? _MonthGrid(
                        focusedMonth: _focusedMonth,
                        selectedDay: _selectedDay,
                        today: today,
                        tasksByDay: _tasksByDayKey,
                        loading: _monthIndicatorsLoading,
                        onDayTap: (d) => unawaited(_selectDay(d, userTap: true)),
                      )
                    : _WeekStrip(
                        weekStart: _weekStripStart(_selectedDay),
                        selectedDay: _selectedDay,
                        today: today,
                        tasksByDay: _tasksByDayKey,
                        onDayTap: (d) => unawaited(_selectDay(d, userTap: true)),
                      ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: listFlex,
              child: _SelectedDayTaskPanel(
                loc: loc,
                selectedDay: _selectedDay,
                stream: _dayStream,
                onEditTask: widget.onEditTask,
                onStartRecordFromTask: widget.onStartRecordFromTask,
              ),
            ),
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
    required this.onModeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.showToday,
  });

  final String loc;
  final ColorScheme scheme;
  final _CalendarViewMode mode;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final ValueChanged<_CalendarViewMode> onModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final bool showToday;

  @override
  Widget build(BuildContext context) {
    final title = mode == _CalendarViewMode.month
        ? DateFormat.yMMMM(loc).format(focusedMonth)
        : () {
            final start = selectedDay.subtract(
              Duration(days: selectedDay.weekday - 1),
            );
            final end = start.add(const Duration(days: 6));
            final a = DateFormat.MMMd(loc).format(start);
            final b = DateFormat.MMMd(loc).format(end);
            return '$a – $b';
          }();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: onPrev,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: onNext,
              ),
            ],
          ),
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
                TextButton(
                  onPressed: onToday,
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
    required this.selectedDay,
    required this.today,
    required this.tasksByDay,
    required this.loading,
    required this.onDayTap,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    const weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    weekdayLabels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellH = constraints.maxHeight / 6;
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
                                    selectedDay: selectedDay,
                                    today: today,
                                    tasks: _tasksForCell(
                                      gridStart.add(
                                        Duration(days: row * 7 + col),
                                      ),
                                    ),
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
        if (kDebugMode && loc.isEmpty) const SizedBox.shrink(),
      ],
    );
  }

  List<PlanningTask> _tasksForCell(DateTime day) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return tasksByDay[key] ?? const [];
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.focusedMonth,
    required this.selectedDay,
    required this.today,
    required this.tasks,
    required this.onTap,
  });

  final DateTime day;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final DateTime today;
  final List<PlanningTask> tasks;
  final ValueChanged<DateTime> onTap;

  bool get _inMonth => day.month == focusedMonth.month;
  bool get _selected =>
      day.year == selectedDay.year &&
      day.month == selectedDay.month &&
      day.day == selectedDay.day;
  bool get _isToday =>
      day.year == today.year && day.month == today.month && day.day == today.day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final scheduled = tasks.where((t) => t.startTime != null).toList();
    final bg = _selected
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : _isToday
            ? scheme.secondaryContainer.withValues(alpha: 0.35)
            : Colors.transparent;
    final side = _selected
        ? BorderSide(color: scheme.primary, width: 1.5)
        : _isToday
            ? BorderSide(color: scheme.outlineVariant, width: 1)
            : BorderSide.none;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(day),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
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
                const SizedBox(height: 2),
                Expanded(
                  child: _DayTaskIndicators(
                    tasks: scheduled,
                    compact: false,
                    loc: loc,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
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
                final key =
                    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                final tasks = tasksByDay[key] ?? const <PlanningTask>[];
                final selected = day.year == selectedDay.year &&
                    day.month == selectedDay.month &&
                    day.day == selectedDay.day;
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final weekday = DateFormat.E(loc).format(day);
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
                              weekday,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.day}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            _DayTaskIndicators(
                              tasks: tasks
                                  .where((t) => t.startTime != null)
                                  .toList(),
                              compact: true,
                              loc: loc,
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

class _DayTaskIndicators extends StatelessWidget {
  const _DayTaskIndicators({
    required this.tasks,
    required this.compact,
    required this.loc,
  });

  final List<PlanningTask> tasks;
  final bool compact;
  final String loc;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    const maxDots = 3;
    final visible = tasks.take(maxDots).toList();
    final extra = tasks.length - visible.length;
    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final t in visible)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: DatabaseService.instance
                    .getCategoryColor(t.categoryId)
                    .withValues(alpha: 0.9),
                shape: BoxShape.circle,
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
      children: [
        for (final t in visible)
          Container(
            height: 4,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: DatabaseService.instance
                  .getCategoryColor(t.categoryId)
                  .withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        if (extra > 0)
          Text(
            t(loc, 'calendar_more_tasks').replaceFirst('%s', '$extra'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: scheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class _SelectedDayTaskPanel extends StatelessWidget {
  const _SelectedDayTaskPanel({
    required this.loc,
    required this.selectedDay,
    required this.stream,
    required this.onEditTask,
    required this.onStartRecordFromTask,
  });

  final String loc;
  final DateTime selectedDay;
  final Stream<List<PlanningTask>>? stream;
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
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
                return const Center(child: AppLoading(size: AppLoadingSize.small));
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
                  return _CalendarPlanCard(
                    task: task,
                    loc: loc,
                    onEdit: () => onEditTask(task),
                    onPlay: () {
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

class _CalendarPlanCard extends StatelessWidget {
  const _CalendarPlanCard({
    required this.task,
    required this.loc,
    required this.onEdit,
    required this.onPlay,
  });

  final PlanningTask task;
  final String loc;
  final VoidCallback onEdit;
  final VoidCallback onPlay;

  String _timeLabel() {
    final st = task.startTime;
    if (st == null) return '';
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final et = task.endDateTime;
    if (et != null) return '${hhmm(st)} – ${hhmm(et)}';
    return hhmm(st);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categoryTone =
        DatabaseService.instance.getCategoryColor(task.categoryId);
    final categoryPath = localizeCategoryBreadcrumbPath(
      DatabaseService.instance.getCategoryPath(task.categoryId).trim(),
      loc,
    );
    return Material(
      color: scheme.surface,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: categoryTone.withValues(alpha: 0.82),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: task.isDone,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: task.planRowIdForBackend
                                .startsWith('optimistic-')
                            ? null
                            : (_) {
                                final next = !task.isDone;
                                DatabaseService.instance
                                    .applyOptimisticPlanningTask(
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
                      ),
                      if (!task.isDone)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints.tightFor(width: 32, height: 32),
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: onPlay,
                          tooltip: t(loc, 'start'),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (categoryPath.isNotEmpty)
                              Text(
                                categoryPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: categoryTone.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                              ),
                            Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                decoration: task.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isDone
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _timeLabel(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded),
                        tooltip: t(loc, 'plan_radial_menu_tip'),
                        onPressed: onEdit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
