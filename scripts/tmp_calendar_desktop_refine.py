from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, got {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Desktop calendar header: title left, navigation expands, selector stays right.
p = Path('lib/features/calendar/calendar_chrome_header.dart')
text = p.read_text(encoding='utf-8')
start = text.index('    if (isWide) {')
end = text.index('    final sidePad =', start)
wide = '''    if (isWide) {
      final isRu = loc.toLowerCase().startsWith('ru');
      final weekStart = calendarWeekStartMonday(selectedDay);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final desktopTitle = dayFocusActive
          ? '${DateFormat.MMMd(loc).format(weekStart)} – ${DateFormat.MMMd(loc).format(weekEnd)}'
          : title;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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

'''
text = text[:start] + wide + text[end:]
p.write_text(text, encoding='utf-8')


# 2) Desktop month shows only the focused month and uses only the weeks it needs.
replace_once(
    'lib/features/calendar/calendar_month_grid.dart',
    '    required this.browsing,\n    required this.onDayTap,\n  });',
    '    required this.browsing,\n    required this.onDayTap,\n    this.currentMonthOnly = false,\n  });',
)
replace_once(
    'lib/features/calendar/calendar_month_grid.dart',
    '  final bool browsing;\n  final ValueChanged<DateTime> onDayTap;',
    '  final bool browsing;\n  final ValueChanged<DateTime> onDayTap;\n  final bool currentMonthOnly;',
)
replace_once(
    'lib/features/calendar/calendar_month_grid.dart',
    "    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);\n    final gridStart = first.subtract(Duration(days: first.weekday - 1));",
    "    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);\n    final last = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);\n    final gridStart = first.subtract(Duration(days: first.weekday - 1));\n    final gridEnd = last.add(Duration(days: 7 - last.weekday));\n    final monthRowCount = currentMonthOnly\n        ? (gridEnd.difference(gridStart).inDays + 1) ~/ 7\n        : 6;",
)
replace_once(
    'lib/features/calendar/calendar_month_grid.dart',
    '              final cellH = constraints.maxHeight / 6;',
    '              final cellH = constraints.maxHeight / monthRowCount;',
)
replace_once(
    'lib/features/calendar/calendar_month_grid.dart',
    '                      for (var row = 0; row < 6; row++)',
    '                      for (var row = 0; row < monthRowCount; row++)',
)
old_cell = '''                              for (var col = 0; col < 7; col++)
                                Expanded(
                                  child: CalendarMonthDayCell(
                                    day: gridStart.add(
                                      Duration(days: row * 7 + col),
                                    ),
                                    focusedMonth: focusedMonth,
                                    highlightDay: highlightDay,
                                    today: today,
                                    tasks: tasksByDay[
                                            calendarDayKey(
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
                                ),'''
new_cell = '''                              for (var col = 0; col < 7; col++)
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final day = gridStart.add(
                                        Duration(days: row * 7 + col),
                                      );
                                      final inFocusedMonth =
                                          day.year == focusedMonth.year &&
                                          day.month == focusedMonth.month;
                                      if (currentMonthOnly && !inFocusedMonth) {
                                        return const SizedBox.shrink();
                                      }
                                      return CalendarMonthDayCell(
                                        day: day,
                                        focusedMonth: focusedMonth,
                                        highlightDay: highlightDay,
                                        today: today,
                                        tasks: tasksByDay[calendarDayKey(day)] ??
                                            const [],
                                        showEventPills: showEventPills,
                                        maxVisibleEvents: maxEvents,
                                        browsing: browsing,
                                        onTap: onDayTap,
                                      );
                                    },
                                  ),
                                ),'''
replace_once('lib/features/calendar/calendar_month_grid.dart', old_cell, new_cell)


# 3) Focused desktop day uses one minimal week line.
p = Path('lib/features/calendar/calendar_week_grid.dart')
text = p.read_text(encoding='utf-8')
marker = '/// Compact week strip shown when a day is focused in week mode.\n'
start = text.index(marker)
compact = r'''/// Compact week strip shown when a day is focused.
class CalendarWeekCompactStrip extends StatelessWidget {
  const CalendarWeekCompactStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.tasksByDay,
    required this.onDayTap,
    this.minimal = false,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final ValueChanged<DateTime> onDayTap;
  final bool minimal;

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
                final key = calendarDayKey(day);
                final tasks = tasksByDay[key] ?? const <PlanningTask>[];
                final selected = day.year == selectedDay.year &&
                    day.month == selectedDay.month &&
                    day.day == selectedDay.day;
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;

                if (minimal) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: selected
                          ? scheme.primaryContainer.withValues(alpha: 0.65)
                          : isToday
                              ? scheme.surfaceContainerLow.withValues(alpha: 0.5)
                              : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: selected
                            ? BorderSide(color: scheme.primary, width: 1.5)
                            : isToday
                                ? BorderSide(
                                    color: scheme.primary.withValues(alpha: 0.45),
                                  )
                                : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onDayTap(day),
                        borderRadius: BorderRadius.circular(10),
                        child: Center(
                          child: Text(
                            '${DateFormat.E(loc).format(day)} ${day.day}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: isToday && !selected
                        ? scheme.surfaceContainerLow.withValues(alpha: 0.5)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isToday && !selected
                          ? BorderSide(
                              color: scheme.primary.withValues(alpha: 0.45),
                            )
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onDayTap(day),
                      borderRadius: BorderRadius.circular(10),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: selected
                                  ? BoxDecoration(
                                      color: scheme.primaryContainer
                                          .withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: scheme.primary,
                                        width: 1.5,
                                      ),
                                    )
                                  : null,
                              child: Text(
                                '${day.day}',
                                maxLines: 1,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 4),
                            CalendarDayEventList(
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
'''
p.write_text(text[:start] + compact, encoding='utf-8')


# 4) Focused-day panel: desktop has canonical input + Add button and no duplicate date header.
replace_once(
    'lib/features/calendar/calendar_day_panel.dart',
    "import 'package:counter/core/widgets/app_button.dart';",
    "import 'package:counter/core/widgets/app_button.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';",
)
replace_once(
    'lib/features/calendar/calendar_day_panel.dart',
    '    required this.onAddPlan,\n    required this.onStartRecordFromTask,\n  });',
    '    required this.onAddPlan,\n    required this.onStartRecordFromTask,\n    this.desktopQuickAdd = false,\n  });',
)
replace_once(
    'lib/features/calendar/calendar_day_panel.dart',
    '  final VoidCallback onAddPlan;',
    '  final ValueChanged<String> onAddPlan;\n  final bool desktopQuickAdd;',
)
old_top = '''        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: AppButton(
            label: t(loc, 'calendar_add_plan'),
            icon: Icons.add_rounded,
            onPressed: onAddPlan,
            expand: true,
          ),
        ),'''
new_top = '''        if (!desktopQuickAdd)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
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
        Padding(
          padding: EdgeInsets.fromLTRB(12, desktopQuickAdd ? 8 : 0, 12, 8),
          child: desktopQuickAdd
              ? _CalendarDayQuickAdd(loc: loc, onAddPlan: onAddPlan)
              : AppButton(
                  label: t(loc, 'calendar_add_plan'),
                  icon: Icons.add_rounded,
                  onPressed: () => onAddPlan(''),
                  expand: true,
                ),
        ),'''
replace_once('lib/features/calendar/calendar_day_panel.dart', old_top, new_top)

p = Path('lib/features/calendar/calendar_day_panel.dart')
text = p.read_text(encoding='utf-8')
text += r'''

class _CalendarDayQuickAdd extends StatefulWidget {
  const _CalendarDayQuickAdd({required this.loc, required this.onAddPlan});

  final String loc;
  final ValueChanged<String> onAddPlan;

  @override
  State<_CalendarDayQuickAdd> createState() => _CalendarDayQuickAddState();
}

class _CalendarDayQuickAddState extends State<_CalendarDayQuickAdd> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    widget.onAddPlan(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AppQuickEntryRow(
      controller: _controller,
      focusNode: _focusNode,
      hintText: t(widget.loc, 'calendar_add_plan'),
      actionLabel: t(widget.loc, 'add'),
      actionIcon: Icons.add_rounded,
      onAction: _submit,
      onSubmitted: (_) => _submit(),
    );
  }
}
'''
p.write_text(text, encoding='utf-8')


# 5) Wire desktop-specific behavior in CalendarView.
replace_once(
    'lib/features/calendar/calendar_view.dart',
    '  void _openAddPlanForSelectedDay() {',
    "  void _openAddPlanForSelectedDay([String initialTitle = '']) {",
)
replace_once(
    'lib/features/calendar/calendar_view.dart',
    "      title: '',",
    '      title: initialTitle.trim(),',
)
replace_once(
    'lib/features/calendar/calendar_view.dart',
    '    final showPills = calendarShowsEventPills(viewportW);',
    '    final showPills = calendarShowsEventPills(viewportW);\n    final desktopCalendar = viewportW >= kShellDesktopNavBreakpoint;',
)
old_area = '''      child: _mode == CalendarViewMode.month
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
            ),'''
new_area = '''      child: desktopCalendar && _dayFocusActive
          ? CalendarWeekCompactStrip(
              weekStart: calendarWeekStartMonday(_selectedDay),
              selectedDay: _selectedDay,
              today: today,
              tasksByDay: _tasksByDayKey,
              onDayTap: (d) => unawaited(_onDayTapped(d)),
              minimal: true,
            )
          : _mode == CalendarViewMode.month
              ? CalendarMonthGrid(
                  focusedMonth: _focusedMonth,
                  highlightDay: _dayFocusActive ? _selectedDay : null,
                  today: today,
                  tasksByDay: _tasksByDayKey,
                  loading: _monthIndicatorsLoading,
                  showEventPills: showPills,
                  browsing: !_dayFocusActive,
                  onDayTap: (d) => unawaited(_onDayTapped(d)),
                  currentMonthOnly: desktopCalendar,
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
                    ),'''
replace_once('lib/features/calendar/calendar_view.dart', old_area, new_area)
old_focus = '''            if (!_dayFocusActive)
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
                  onAddPlan: _openAddPlanForSelectedDay,
                  onStartRecordFromTask: widget.onStartRecordFromTask,
                ),
              ),
            ],'''
new_focus = '''            if (!_dayFocusActive)
              Expanded(child: calendarArea)
            else if (desktopCalendar) ...[
              SizedBox(height: 58, child: calendarArea),
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
                  onAddPlan: _openAddPlanForSelectedDay,
                  onStartRecordFromTask: widget.onStartRecordFromTask,
                ),
              ),
            ],'''
replace_once('lib/features/calendar/calendar_view.dart', old_focus, new_focus)
