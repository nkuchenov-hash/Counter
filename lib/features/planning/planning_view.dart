// ---------------------------------------------------------------------------
// PLANNING FEATURE — Day planning & task list tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:math' as math;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _PlanSortMode { category, time, custom }

/// Planning tab: swipeable day view, task list, add/edit/delete. Shell provides [onEditTask] to show the task edit sheet.
class PlanningSwipeWrapper extends StatefulWidget {
  const PlanningSwipeWrapper({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStartRecordFromTask,
    required this.onEditTask,
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateChanged;
  final int? selectedCategoryId;
  final void Function(int? categoryId) onCategoryChanged;
  final Future<void> Function(String title, int categoryId, String dateKey) onStartRecordFromTask;
  final void Function(PlanningTask task) onEditTask;

  @override
  State<PlanningSwipeWrapper> createState() => _PlanningSwipeWrapperState();
}

class _PlanningSwipeWrapperState extends State<PlanningSwipeWrapper> {
  static const int initialPage = 5000;
  static const int totalPageCount = 10000;
  late PageController _controller;
  late DateTime _anchorDate;

  String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _anchorDate = DateUtils.dateOnly(DateTime.now());
    final daysOffset = _dateOnly(widget.selectedDate).difference(_anchorDate).inDays;
    _controller = PageController(initialPage: initialPage + daysOffset);
  }

  @override
  void didUpdateWidget(covariant PlanningSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      final daysOffset = _dateOnly(widget.selectedDate).difference(_anchorDate).inDays;
      final page = initialPage + daysOffset;
      if (_controller.hasClients && page >= 0 && page < totalPageCount) {
        _controller.animateToPage(
          page,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToDate(DateTime date) {
    final dateOnly = _dateOnly(date);
    final offset = dateOnly.difference(_anchorDate).inDays;
    final targetIndex = initialPage + offset;
    if (targetIndex >= 0 && targetIndex < totalPageCount && _controller.hasClients) {
      _controller.jumpToPage(targetIndex);
      widget.onDateChanged(dateOnly);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: totalPageCount,
      onPageChanged: (int index) {
        if (index >= 0 && index < totalPageCount) {
          final date = _anchorDate.add(Duration(days: index - initialPage));
          widget.onDateChanged(_dateOnly(date));
        }
      },
      itemBuilder: (context, index) {
        final date = _anchorDate.add(Duration(days: index - initialPage));
        final dateKey = _dateKeyFromDate(date);
        return PlanningPage(
          key: ValueKey(dateKey),
          selectedDateString: dateKey,
          selectedDate: date,
          selectedCategoryId: widget.selectedCategoryId,
          onCategoryChanged: widget.onCategoryChanged,
          onStartRecordFromTask: widget.onStartRecordFromTask,
          onEditTask: widget.onEditTask,
          onDatePicked: _jumpToDate,
          pageController: _controller,
          anchorDate: _anchorDate,
          initialPage: initialPage,
          totalPageCount: totalPageCount,
          onDateChanged: widget.onDateChanged,
        );
      },
    );
  }
}

/// Single-day planning: task list, add task, date picker. [onEditTask] is called when user opens a task for edit (shell shows sheet).
class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.selectedDateString,
    this.selectedDate,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStartRecordFromTask,
    required this.onEditTask,
    this.onDatePicked,
    this.pageController,
    this.anchorDate,
    this.initialPage,
    this.totalPageCount,
    this.onDateChanged,
  });

  final String selectedDateString;
  final DateTime? selectedDate;
  final int? selectedCategoryId;
  final void Function(int? categoryId) onCategoryChanged;
  final Future<void> Function(String title, int categoryId, String dateKey) onStartRecordFromTask;
  final void Function(PlanningTask task) onEditTask;
  final void Function(DateTime date)? onDatePicked;
  final PageController? pageController;
  final DateTime? anchorDate;
  final int? initialPage;
  final int? totalPageCount;
  final void Function(DateTime date)? onDateChanged;

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final Set<String> _selectedPlanKeys = {};
  final List<PlanningTask> _optimisticTasks = [];
  final Map<String, bool> _planDoneOverride = {};
  Stream<List<PlanningTask>>? _planningStream;
  List<PlanningTask>? _dragOrder;
  bool _planSelectMode = false;
  _PlanSortMode _sortMode = _PlanSortMode.custom;

  DateTime get _today => DatabaseService.instance.getProjectedToday();

  /// Stable unique key for list tiles. Never use bare `id` alone — Noco `id` can be 0 for
  /// multiple rows before sync, which duplicates [ValueKey]s and crashes the Time grid.
  static String _planKey(PlanningTask t) {
    final p = t.planRowIdForNoco.trim();
    if (p.isNotEmpty) return p;
    return 'plan-fallback-${t.id}-${t.order}-${t.dateKey}-${t.categoryId}-${t.title}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _planningStream = DatabaseService.instance.planningStream(widget.selectedDate ?? _today);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(DatabaseService.instance.flushPlanningOrderSyncNow());
    }
  }

  @override
  void didUpdateWidget(covariant PlanningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.selectedDateString != widget.selectedDateString) {
      _planningStream = DatabaseService.instance.planningStream(widget.selectedDate ?? _today);
      _optimisticTasks.clear();
      _planDoneOverride.clear();
      _dragOrder = null;
      _selectedPlanKeys.clear();
      _planSelectMode = false;
      _sortMode = _PlanSortMode.custom;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(DatabaseService.instance.flushPlanningOrderSyncNow());
    _textController.dispose();
    super.dispose();
  }

  List<PlanningTask> _mergeWithOptimistic(List<PlanningTask> server) {
    final pending = _optimisticTasks
        .where((o) => !server.any(
            (s) => s.title.trim() == o.title.trim() && s.dateKey == o.dateKey))
        .toList();
    final merged = [...pending, ...server];
    merged.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return merged;
  }

  List<PlanningTask> _displayTasks(List<PlanningTask> server) {
    final merged = _mergeWithOptimistic(server);
    if (_dragOrder != null && _dragOrder!.length == merged.length) {
      final keys = merged.map(_planKey).toSet();
      final dragKeys = _dragOrder!.map(_planKey).toSet();
      if (keys.length == dragKeys.length && keys.containsAll(dragKeys)) {
        return _dragOrder!;
      }
    }
    return merged;
  }

  void _exitSelectMode() {
    setState(() {
      _planSelectMode = false;
      _selectedPlanKeys.clear();
    });
  }

  void _toggleKeySelection(String key) {
    setState(() {
      if (_selectedPlanKeys.contains(key)) {
        _selectedPlanKeys.remove(key);
      } else {
        _selectedPlanKeys.add(key);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedPlanKeys.clear);
  }

  Future<void> _bulkDelete(List<PlanningTask> tasks) async {
    for (final key in _selectedPlanKeys.toList()) {
      PlanningTask? match;
      for (final t in tasks) {
        if (_planKey(t) == key) {
          match = t;
          break;
        }
      }
      if (match == null) continue;
      await DatabaseService.instance.deletePlanningTask(match.planRowIdForNoco);
    }
    if (mounted) {
      setState(() {
        _selectedPlanKeys.clear();
        _planSelectMode = false;
      });
    }
  }

  void _openEditDialog(PlanningTask task) {
    widget.onEditTask(task);
  }

  /// Round FAB actions anchored next to ⋮ (no full bottom sheet).
  void _showPlanRadialMenu(BuildContext anchorContext, PlanningTask task) {
    final overlay = Overlay.maybeOf(anchorContext);
    if (overlay == null) return;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final media = MediaQuery.sizeOf(anchorContext);
    final scheme = Theme.of(anchorContext).colorScheme;
    final loc = currentLocale.value;
    const fab = 48.0;
    const gap = 10.0;
    final rowW = fab * 3 + gap * 2;
    var left = pos.dx - rowW;
    if (left < 8) {
      left = pos.dx + size.width + gap;
    }
    if (left + rowW > media.width - 8) {
      left = math.max(8.0, media.width - rowW - 8);
    }
    var top = pos.dy + size.height / 2 - fab / 2;
    top = top.clamp(8.0, media.height - fab - 8);

    final hEdit = Object.hash(task.planRowIdForNoco, 'pe');
    final hSel = Object.hash(task.planRowIdForNoco, 'ps');
    final hDel = Object.hash(task.planRowIdForNoco, 'pd');

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => entry.remove(),
                  child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.32)),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: t(loc, 'plan_sheet_delete'),
                      child: FloatingActionButton.small(
                        heroTag: 'plan_radial_del_$hDel',
                        backgroundColor: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                        onPressed: () {
                          entry.remove();
                          unawaited(DatabaseService.instance
                              .deletePlanningTask(task.planRowIdForNoco));
                          if (mounted) setState(() {});
                        },
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                    SizedBox(width: gap),
                    Tooltip(
                      message: t(loc, 'plan_sheet_select'),
                      child: FloatingActionButton.small(
                        heroTag: 'plan_radial_sel_$hSel',
                        onPressed: () {
                          entry.remove();
                          setState(() {
                            _planSelectMode = true;
                            _selectedPlanKeys.add(_planKey(task));
                          });
                        },
                        child: const Icon(Icons.checklist_rounded),
                      ),
                    ),
                    SizedBox(width: gap),
                    Tooltip(
                      message: t(loc, 'plan_sheet_edit'),
                      child: FloatingActionButton.small(
                        heroTag: 'plan_radial_edit_$hEdit',
                        onPressed: () {
                          entry.remove();
                          _openEditDialog(task);
                        },
                        child: const Icon(Icons.edit_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    overlay.insert(entry);
  }

  Future<void> _addTask() async {
    final taskDateKey = widget.selectedDateString;
    final title = _textController.text.trim();
    if (title.isEmpty) return;
    final match = DatabaseService.instance.identifyCategory(title);
    final categoryId = match?.id ??
        widget.selectedCategoryId ??
        DatabaseService.instance.defaultCategoryId ??
        (DatabaseService.instance.rules.isNotEmpty
            ? DatabaseService.instance.rules.first.id
            : 0);
    var nextOrder = await DatabaseService.instance
        .nextPlanningOrderForDate(widget.selectedDate ?? _today);
    for (final t in _optimisticTasks) {
      if (t.order >= nextOrder) nextOrder = t.order + 1;
    }
    final optimisticId = -DateTime.now().millisecondsSinceEpoch;
    final optimisticRow = 'optimistic-${DateTime.now().microsecondsSinceEpoch}';
    final pending = PlanningTask(
      id: optimisticId,
      planRowId: optimisticRow,
      title: title,
      categoryId: categoryId,
      dateKey: taskDateKey,
      order: nextOrder,
      startTime: null,
      endDateTime: null,
      checklist: const [],
      notes: null,
      parentPlanId: null,
    );
    setState(() => _optimisticTasks.add(pending));
    _textController.clear();
    try {
      final ok = await DatabaseService.instance.addPlanningTask(PlanningTask(
        id: 0,
        title: title,
        categoryId: categoryId,
        dateKey: taskDateKey,
        order: nextOrder,
        startTime: null,
        endDateTime: null,
        checklist: const [],
        notes: null,
        parentPlanId: null,
      ));
      if (!mounted) return;
      if (!ok) {
        setState(() => _optimisticTasks.removeWhere((o) => o.planRowId == optimisticRow));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticTasks.removeWhere((o) => o.planRowId == optimisticRow));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  Future<void> _toggleDone(PlanningTask task, bool currentDisplayDone) async {
    if (task.planRowIdForNoco.startsWith('optimistic-')) return;
    final key = _planKey(task);
    final next = !currentDisplayDone;
    setState(() => _planDoneOverride[key] = next);
    try {
      final ok = await DatabaseService.instance
          .updatePlanningTask(task.planRowIdForNoco, isDone: next);
      if (!mounted) return;
      if (!ok) {
        setState(() => _planDoneOverride.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _planDoneOverride.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  int _taskSortCmp(PlanningTask a, PlanningTask b) {
    if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
    final o = a.order.compareTo(b.order);
    if (o != 0) return o;
    return a.title.compareTo(b.title);
  }

  List<PlanningTask> _tasksForTimeMode(List<PlanningTask> tasks) {
    final copy = List<PlanningTask>.from(tasks);
    copy.sort((a, b) {
      final at = a.startTime;
      final bt = b.startTime;
      if (at == null && bt == null) return _taskSortCmp(a, b);
      if (at == null) return 1;
      if (bt == null) return -1;
      final c = at.hour.compareTo(bt.hour);
      if (c != 0) return c;
      final m = at.minute.compareTo(bt.minute);
      if (m != 0) return m;
      return _taskSortCmp(a, b);
    });
    return copy;
  }

  Map<String, List<PlanningTask>> _groupTasksByCategoryPath(
      List<PlanningTask> tasks) {
    final groups = <String, List<PlanningTask>>{};
    for (final t in tasks) {
      final path = DatabaseService.instance.getCategoryPath(t.categoryId);
      groups.putIfAbsent(path, () => []).add(t);
    }
    for (final e in groups.entries) {
      e.value.sort(_taskSortCmp);
    }
    return groups;
  }

  Widget _planCardRow({
    required BuildContext context,
    required PlanningTask task,
    required String key,
    required bool displayDone,
    required bool isSelected,
    required bool showDrag,
    required int reorderIndex,
    required List<PlanningTask> reorderList,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final canDrag = showDrag &&
        !_planSelectMode &&
        !task.planRowIdForNoco.startsWith('optimistic-');
    return Material(
      key: ValueKey(key),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canDrag)
              ReorderableDragStartListener(
                index: reorderIndex,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.drag_handle_rounded, color: scheme.outline),
                ),
              )
            else
              const SizedBox(width: 8),
            Expanded(
              child: _PlanningTaskCard(
                task: task,
                displayIsDone: displayDone,
                selectMode: _planSelectMode,
                isSelected: isSelected,
                onBodyTap: () {
                  if (_planSelectMode) {
                    _toggleKeySelection(key);
                  } else {
                    _openEditDialog(task);
                  }
                },
                onToggleDone: () => _toggleDone(task, displayDone),
                onPlay: () async {
                  await widget.onStartRecordFromTask(
                      task.title, task.categoryId, task.dateKey);
                  if (mounted) setState(() {});
                },
                onOpenMenu: (anchorCtx) => _showPlanRadialMenu(anchorCtx, task),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourGridView(List<PlanningTask> tasks) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final ordered = _tasksForTimeMode(tasks);
    final unscheduled = ordered.where((t) => t.startTime == null).toList();
    final scheduled = ordered.where((t) => t.startTime != null).toList();
    final byHour = <int, List<PlanningTask>>{};
    for (final t in scheduled) {
      final st = t.startTime;
      if (st == null) continue;
      final h = st.hour.clamp(0, 23);
      byHour.putIfAbsent(h, () => []).add(t);
    }

    String hourLabel(int hour) {
      final safeHour = hour.clamp(0, 23);
      try {
        return TimeOfDay(hour: safeHour, minute: 0).format(context);
      } catch (_) {
        return '${safeHour.toString().padLeft(2, '0')}:00';
      }
    }

    final children = <Widget>[];
    if (unscheduled.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            t(loc, 'plan_unscheduled'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
      for (final task in unscheduled) {
        final key = _planKey(task);
        final displayDone = _planDoneOverride[key] ?? task.isDone;
        children.add(
          _planCardRow(
            context: context,
            task: task,
            key: key,
            displayDone: displayDone,
            isSelected: _selectedPlanKeys.contains(key),
            showDrag: false,
            reorderIndex: 0,
            reorderList: tasks,
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }
    for (var hour = 0; hour < 24; hour++) {
      final hourTasks = byHour[hour] ?? <PlanningTask>[];
      final label = hourLabel(hour);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: hourTasks.isEmpty
                      ? const SizedBox(height: 10)
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final task in hourTasks) ...[
                                Builder(
                                  builder: (ctx) {
                                    final key = _planKey(task);
                                    final displayDone =
                                        _planDoneOverride[key] ?? task.isDone;
                                    return _planCardRow(
                                      context: ctx,
                                      task: task,
                                      key: key,
                                      displayDone: displayDone,
                                      isSelected:
                                          _selectedPlanKeys.contains(key),
                                      showDrag: false,
                                      reorderIndex: 0,
                                      reorderList: tasks,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: children,
    );
  }

  Widget _buildCategoryGroupedView(List<PlanningTask> tasks) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groupTasksByCategoryPath(tasks);
    final keys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final children = <Widget>[];
    for (final k in keys) {
      children.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            k,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
      for (final task in groups[k] ?? const <PlanningTask>[]) {
        final key = _planKey(task);
        final displayDone = _planDoneOverride[key] ?? task.isDone;
        children.add(
          _planCardRow(
            context: context,
            task: task,
            key: key,
            displayDone: displayDone,
            isSelected: _selectedPlanKeys.contains(key),
            showDrag: false,
            reorderIndex: 0,
            reorderList: tasks,
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: children,
    );
  }

  void _onReorder(List<PlanningTask> current, int oldIndex, int newIndex) {
    if (_planSelectMode || _sortMode != _PlanSortMode.custom) return;
    if (oldIndex < 0 ||
        oldIndex >= current.length ||
        newIndex < 0 ||
        newIndex > current.length) {
      return;
    }
    var ni = newIndex;
    if (ni > oldIndex) ni -= 1;
    final row = current[oldIndex];
    if (row.planRowIdForNoco.startsWith('optimistic-')) return;
    final next = List<PlanningTask>.from(current);
    next.removeAt(oldIndex);
    next.insert(ni, row);
    final withOrders = <PlanningTask>[
      for (var i = 0; i < next.length; i++) next[i].copyWith(order: i),
    ];
    setState(() => _dragOrder = withOrders);
    unawaited(
      DatabaseService.instance.persistPlanningTaskOrder(
        withOrders,
        baselineBeforeReorder: current,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerDate = widget.selectedDate ?? _today;
    String dateStr;
    try {
      dateStr = DateFormat.yMMMMd(currentLocale.value).format(headerDate);
    } catch (_) {
      dateStr =
          '${headerDate.year}-${headerDate.month.toString().padLeft(2, '0')}-${headerDate.day.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        leading: _planSelectMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectMode,
                tooltip: t(currentLocale.value, 'plan_exit_select'),
              )
            : null,
        title: Text(
          _planSelectMode
              ? t(currentLocale.value, 'plan_select_mode')
              : '${t(currentLocale.value, 'planning')} · $dateStr',
        ),
        actions: [
          if (!_planSelectMode)
            IconButton(
              icon: const Icon(Icons.calendar_today_rounded),
              onPressed: () {
                final d = widget.selectedDate ?? _today;
                showDialog<void>(
                  context: context,
                  builder: (ctx) => _PlanningDatePickerDialog(
                    initialDate: d,
                    onDatePicked: (date) {
                      Navigator.of(ctx).pop();
                      widget.onDatePicked?.call(date);
                    },
                    pageController: widget.pageController,
                    anchorDate: widget.anchorDate,
                    initialPage: widget.initialPage,
                    totalPageCount: widget.totalPageCount,
                    onDateChanged: widget.onDateChanged,
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<PlanningTask>>(
        stream: _planningStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(t(currentLocale.value, 'error_prefix').replaceFirst('%s', '${snapshot.error}')));
          }
          final server = snapshot.data ?? [];
          if (server.isNotEmpty && _optimisticTasks.isNotEmpty) {
            final toDrop = _optimisticTasks
                .where((o) => server.any((s) =>
                    s.title.trim() == o.title.trim() && s.dateKey == o.dateKey))
                .toList();
            if (toDrop.isNotEmpty) {
              final dropIds = toDrop.map((e) => e.planRowId).toSet();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(
                    () => _optimisticTasks.removeWhere((o) => dropIds.contains(o.planRowId)));
              });
            }
          }
          final tasks = _displayTasks(server);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_planSelectMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SegmentedButton<_PlanSortMode>(
                    segments: [
                      ButtonSegment<_PlanSortMode>(
                        value: _PlanSortMode.category,
                        label: Text(
                            t(currentLocale.value, 'plan_sort_category')),
                      ),
                      ButtonSegment<_PlanSortMode>(
                        value: _PlanSortMode.time,
                        label:
                            Text(t(currentLocale.value, 'plan_sort_time')),
                      ),
                      ButtonSegment<_PlanSortMode>(
                        value: _PlanSortMode.custom,
                        label:
                            Text(t(currentLocale.value, 'plan_sort_custom')),
                      ),
                    ],
                    selected: {_sortMode},
                    onSelectionChanged: (Set<_PlanSortMode> next) {
                      if (next.isEmpty) return;
                      setState(() => _sortMode = next.first);
                    },
                  ),
                ),
              if (!_planSelectMode && _sortMode == _PlanSortMode.custom)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    t(currentLocale.value, 'plan_reorder_hint'),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          labelText: t(currentLocale.value, 'task_title'),
                          hintText: t(currentLocale.value, 'hint_task_example'),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(t(currentLocale.value, 'add')),
                    ),
                  ],
                ),
              ),
              if (_selectedPlanKeys.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(t(currentLocale.value, 'selected_count')
                          .replaceFirst('%s', '${_selectedPlanKeys.length}')),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _clearSelection,
                        child: Text(t(currentLocale.value, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () => _bulkDelete(tasks),
                        child: Text(t(currentLocale.value, 'delete'),
                            style: TextStyle(color: scheme.error)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          t(currentLocale.value, 'no_records'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : _sortMode == _PlanSortMode.time
                        ? _buildHourGridView(tasks)
                        : _sortMode == _PlanSortMode.category
                            ? _buildCategoryGroupedView(tasks)
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                itemCount: tasks.length,
                                onReorder: (oldI, newI) =>
                                    _onReorder(tasks, oldI, newI),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final key = _planKey(task);
                                  final displayDone =
                                      _planDoneOverride[key] ?? task.isDone;
                                  return _planCardRow(
                                    context: context,
                                    task: task,
                                    key: key,
                                    displayDone: displayDone,
                                    isSelected:
                                        _selectedPlanKeys.contains(key),
                                    showDrag: true,
                                    reorderIndex: index,
                                    reorderList: tasks,
                                  );
                                },
                              ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Date picker for planning header.
class _PlanningDatePickerDialog extends StatelessWidget {
  const _PlanningDatePickerDialog({
    required this.initialDate,
    required this.onDatePicked,
    this.pageController,
    this.anchorDate,
    this.initialPage,
    this.totalPageCount,
    this.onDateChanged,
  });

  final DateTime initialDate;
  final void Function(DateTime date) onDatePicked;
  final PageController? pageController;
  final DateTime? anchorDate;
  final int? initialPage;
  final int? totalPageCount;
  final void Function(DateTime date)? onDateChanged;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(currentLocale.value, 'calendar')),
      content: SizedBox(
        width: 300,
        child: CalendarDatePicker(
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          onDateChanged: (date) {
            onDatePicked(date);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

/// Single planning task card. Uses Theme.of(context). No hardcoded colors.
class _PlanningTaskCard extends StatelessWidget {
  const _PlanningTaskCard({
    required this.task,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.onBodyTap,
    required this.onToggleDone,
    required this.onPlay,
    required this.onOpenMenu,
  });

  final PlanningTask task;
  /// Merged server [PlanningTask.isDone] with optimistic override from parent.
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onBodyTap;
  final VoidCallback onToggleDone;
  final VoidCallback onPlay;
  final void Function(BuildContext anchorContext) onOpenMenu;

  static String _formatPlanningTaskDate(PlanningTask task) {
    if (task.dateKey.isEmpty) return '';
    final d = _dateFromKey(task.dateKey);
    if (d == null) return task.dateKey;
    final display = DatabaseService.instance.applyUserOffset(DateTime.utc(d.year, d.month, d.day, 12, 0));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = display.month >= 1 && display.month <= 12 ? months[display.month - 1] : '';
    return '${display.day} $m';
  }

  static DateTime? _dateFromKey(String key) {
    if (key.length < 10) return null;
    final y = int.tryParse(key.substring(0, 4));
    final m = int.tryParse(key.substring(5, 7));
    final d = int.tryParse(key.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  static String _formatPlanningTime(DateTime utc) {
    final t = DatabaseService.instance.applyUserOffset(utc);
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String _subtitle(PlanningTask task) {
    final dateStr = _formatPlanningTaskDate(task);
    final displayDate = dateStr.isNotEmpty ? dateStr : task.dateKey;
    if (task.startTime != null && task.endDateTime != null) {
      return '$displayDate • ${_formatPlanningTime(task.startTime!)} - ${_formatPlanningTime(task.endDateTime!)}';
    }
    if (task.startTime != null) {
      return '$displayDate • ${_formatPlanningTime(task.startTime!)}';
    }
    return displayDate;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selectMode && isSelected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: Icon(
                displayIsDone
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
              ),
              onPressed: onToggleDone,
              tooltip: displayIsDone
                  ? t(currentLocale.value, 'mark_incomplete')
                  : t(currentLocale.value, 'mark_done'),
            ),
            Expanded(
              child: InkWell(
                onTap: onBodyTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        color: DatabaseService.instance.getCategoryColor(task.categoryId),
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: displayIsDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: displayIsDone
                                    ? scheme.onSurface.withValues(alpha: 0.62)
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _subtitle(task),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: onPlay,
              tooltip: t(currentLocale.value, 'start'),
            ),
            Builder(
              builder: (menuCtx) => IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => onOpenMenu(menuCtx),
                tooltip: t(currentLocale.value, 'settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
