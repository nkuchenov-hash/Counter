// ---------------------------------------------------------------------------
// PLANNING FEATURE — Day planning & task list tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _timelineHourStart = 0;
  int _timelineHourEnd = 23;

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
    unawaited(_loadPlanningTimelineBounds());
  }

  Future<void> _loadPlanningTimelineBounds() async {
    final start = await PlanningSheetTimelinePrefs.loadStart();
    final end = await PlanningSheetTimelinePrefs.loadEnd();
    if (mounted) {
      setState(() {
        _timelineHourStart = start;
        _timelineHourEnd = end;
      });
    }
  }

  void _onPlanningTimelineBoundsChanged(int start, int end) {
    final s = PlanningSheetTimelinePrefs.clampHour(start);
    final e = PlanningSheetTimelinePrefs.clampHour(end);
    setState(() {
      _timelineHourStart = s;
      _timelineHourEnd = e;
    });
    unawaited(PlanningSheetTimelinePrefs.saveStartEnd(s, e));
  }

  void _showPlanningSettingsSheet() {
    final loc = currentLocale.value;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: _PlanningTimelineBoundsSheet(
              initialStart: _timelineHourStart,
              initialEnd: _timelineHourEnd,
              onBoundsChanged: _onPlanningTimelineBoundsChanged,
              startTitle: t(loc, 'plan_day_start_hour'),
              startHint: t(loc, 'plan_day_start_hint'),
              endTitle: t(loc, 'plan_day_end_hour'),
              endHint: t(loc, 'plan_day_end_hint'),
            ),
          ),
        );
      },
    );
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
    final ids = <int>[];
    for (final key in _selectedPlanKeys.toList()) {
      PlanningTask? match;
      for (final t in tasks) {
        if (_planKey(t) == key) {
          match = t;
          break;
        }
      }
      if (match == null) continue;
      if (match.id > 0) ids.add(match.id);
    }
    await DatabaseService.instance.deletePlanningTasksBulk(ids);
    if (mounted) {
      setState(() {
        _selectedPlanKeys.clear();
        _planSelectMode = false;
      });
    }
  }

  Future<void> _bulkMarkCompleted(List<PlanningTask> tasks) async {
    final ids = <int>[];
    for (final key in _selectedPlanKeys.toList()) {
      PlanningTask? match;
      for (final t in tasks) {
        if (_planKey(t) == key) {
          match = t;
          break;
        }
      }
      if (match == null) continue;
      if (match.id > 0) ids.add(match.id);
    }
    await DatabaseService.instance.markPlanningTasksCompletedBulk(
      ids,
      completed: true,
    );
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

  /// Opens edit sheet with [hour] (0–23) on the visible planning day (wall clock → UTC).
  void _openQuickAddForHour(int hour) {
    final h = hour.clamp(0, 23);
    final d = widget.selectedDate ?? _today;
    final wall = DateTime(d.year, d.month, d.day, h, 0);
    final startUtc = DatabaseService.instance.displayTimeToUtc(wall);
    final categoryId = widget.selectedCategoryId ??
        DatabaseService.instance.defaultCategoryId ??
        (DatabaseService.instance.rules.isNotEmpty
            ? DatabaseService.instance.rules.first.id
            : 0);
    final draft = PlanningTask(
      id: 0,
      planRowId: null,
      title: '',
      categoryId: categoryId,
      isDone: false,
      dateKey: widget.selectedDateString,
      order: 0,
      startTime: startUtc,
      date: DateTime.utc(d.year, d.month, d.day),
      endDateTime: null,
      checklist: const [],
      notes: null,
      parentPlanId: null,
    );
    widget.onEditTask(draft);
  }

  /// Semi-circle expanding FAB (long-press friendly targets) anchored at the card menu control.
  void _showPlanRadialMenu(BuildContext anchorContext, PlanningTask task) {
    final overlay = Overlay.maybeOf(anchorContext);
    if (overlay == null) return;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final anchorCenter = rect.center;

    late OverlayEntry entry;
    void dismiss() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) {
        return _SemicirclePlanningMenuOverlay(
          anchorCenter: anchorCenter,
          onDismiss: dismiss,
          onEdit: () {
            dismiss();
            _openEditDialog(task);
          },
          onSelect: () {
            dismiss();
            setState(() {
              _planSelectMode = true;
              _selectedPlanKeys.add(_planKey(task));
            });
          },
          onDelete: () {
            dismiss();
            unawaited(DatabaseService.instance.deletePlanningTask(task.planRowIdForNoco));
            if (mounted) setState(() {});
          },
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
      isDone: false,
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
        isDone: false,
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
      final ok = await DatabaseService.instance.updatePlanningTask(
        task.planRowIdForNoco,
        planBusinessId: task.planRowId,
        isDone: next,
      );
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

  /// [t] is profile wall time from [PlanningTask.startTime] (not UTC).
  int _planningClockOrderMinutes(DateTime t, int dayStartHour) {
    final slot = (t.hour - dayStartHour + 24) % 24;
    return slot * 60 + t.minute;
  }

  List<PlanningTask> _tasksForTimeMode(List<PlanningTask> tasks, int dayStartHour) {
    final copy = List<PlanningTask>.from(tasks);
    copy.sort((a, b) {
      final at = a.startTime;
      final bt = b.startTime;
      if (at == null && bt == null) return _taskSortCmp(a, b);
      if (at == null) return 1;
      if (bt == null) return -1;
      final ca = _planningClockOrderMinutes(at, dayStartHour);
      final cb = _planningClockOrderMinutes(bt, dayStartHour);
      if (ca != cb) return ca.compareTo(cb);
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

  _PlanningTaskCard _planningTaskCardForRow(
    PlanningTask task,
    String key,
    bool displayDone,
    bool isSelected,
  ) {
    return _PlanningTaskCard(
      task: task,
      displayIsDone: displayDone,
      selectMode: _planSelectMode,
      isSelected: isSelected,
      toggleDoneEnabled: !task.planRowIdForNoco.startsWith('optimistic-'),
      onToggleDone: () => _toggleDone(task, displayDone),
      onBodyTap: () {
        if (_planSelectMode) {
          _toggleKeySelection(key);
        } else {
          _openEditDialog(task);
        }
      },
      onPlay: () async {
        await widget.onStartRecordFromTask(
            task.title, task.categoryId, task.dateKey);
        if (mounted) setState(() {});
      },
      onOpenMenu: (anchorCtx) => _showPlanRadialMenu(anchorCtx, task),
    );
  }

  int? _wallClockHourFromTask(PlanningTask task) {
    final st = task.startTime;
    if (st == null) return null;
    return st.hour;
  }

  Future<void> _onPlanningTaskDroppedOnHour(PlanningTask task, int targetHour) async {
    if (task.planRowIdForNoco.startsWith('optimistic-')) return;
    final h = targetHour.clamp(0, 23);
    final currentHour = _wallClockHourFromTask(task);
    if (currentHour != null && currentHour == h) return;

    final d = widget.selectedDate ?? _today;
    var minute = 0;
    if (task.startTime != null) {
      minute = task.startTime!.minute;
    }
    final wallStart = DateTime(d.year, d.month, d.day, h, minute);

    assert(() {
      final off = DatabaseService.instance.settings.timezoneOffsetHours;
      final utc = DatabaseService.instance.displayTimeToUtc(wallStart);
      debugPrint(
        '[PLAN_GRID_DROP] slotHour=$h wall=$wallStart profileOffsetHours=$off '
        'savedUtc=${utc.toIso8601String()}',
      );
      return true;
    }());

    final ok = await DatabaseService.instance.updatePlanningTask(
      task.planRowIdForNoco,
      planBusinessId: task.planRowId,
      startTimeDisplay: wallStart,
      suppressAppSnack: true,
    );
    if (!mounted) return;
    final loc = currentLocale.value;
    final label =
        '${h.toString().padLeft(2, '0')}:00';
    if (ok) {
      setState(() {
        _planningStream =
            DatabaseService.instance.planningStream(widget.selectedDate ?? _today);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            t(loc, 'plan_task_moved_hour').replaceFirst('%s', label),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'plan_save_failed'))),
      );
    }
  }

  Widget _planCardRow({
    required BuildContext context,
    required PlanningTask task,
    required String key,
    required bool displayDone,
    required bool isSelected,
    bool enableLongPressDrag = false,
  }) {
    final card = _planningTaskCardForRow(task, key, displayDone, isSelected);
    if (!enableLongPressDrag ||
        _planSelectMode ||
        task.planRowIdForNoco.startsWith('optimistic-')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: card,
      );
    }

    final maxFeedbackW = MediaQuery.sizeOf(context).width * 0.9;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LongPressDraggable<PlanningTask>(
        delay: const Duration(milliseconds: 300),
        data: task,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: AbsorbPointer(
            child: Opacity(
              opacity: 0.88,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFeedbackW),
                child: _planningTaskCardForRow(task, key, displayDone, isSelected),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _planningTaskCardForRow(task, key, displayDone, isSelected),
        ),
        child: card,
      ),
    );
  }

  Widget _buildHourGridView(List<PlanningTask> tasks) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final rangeStart = _timelineHourStart;
    final rangeEnd = _timelineHourEnd;
    final ordered = _tasksForTimeMode(tasks, rangeStart);
    final unscheduled = ordered.where((t) => t.startTime == null).toList();
    final scheduled = ordered.where((t) => t.startTime != null).toList();
    final byHour = <int, List<PlanningTask>>{};
    for (final t in scheduled) {
      final st = t.startTime;
      if (st == null) continue;
      final h = st.hour.clamp(0, 23);
      byHour.putIfAbsent(h, () => []).add(t);
    }
    final visibleHours =
        PlanningSheetTimelinePrefs.visibleHoursOrdered(rangeStart, rangeEnd);
    final visibleSet = visibleHours.toSet();

    /// Slot labels match [PlanningSheetTimelinePrefs] hour integers — profile wall o'clock, not device TZ.
    String hourLabel(int hour) {
      final safeHour = hour.clamp(0, 23);
      return '${safeHour.toString().padLeft(2, '0')}:00';
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
            enableLongPressDrag: true,
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }
    final outsideHourTasks = <PlanningTask>[];
    for (final t in scheduled) {
      final st = t.startTime;
      if (st == null) continue;
      final wallH = st.hour.clamp(0, 23);
      if (!visibleSet.contains(wallH)) {
        outsideHourTasks.add(t);
      }
    }
    if (outsideHourTasks.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            t(loc, 'plan_outside_visible_hours'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
      for (final task in outsideHourTasks) {
        final key = _planKey(task);
        final displayDone = _planDoneOverride[key] ?? task.isDone;
        children.add(
          _planCardRow(
            context: context,
            task: task,
            key: key,
            displayDone: displayDone,
            isSelected: _selectedPlanKeys.contains(key),
            enableLongPressDrag: true,
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }
    for (final hour in visibleHours) {
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DragTarget<PlanningTask>(
                      hitTestBehavior: HitTestBehavior.opaque,
                      onWillAcceptWithDetails: (_) => !_planSelectMode,
                      onAcceptWithDetails: (details) {
                        unawaited(
                          _onPlanningTaskDroppedOnHour(
                              details.data, hour),
                        );
                      },
                      builder: (context, candidate, rejected) {
                        final dropHover = candidate.isNotEmpty;
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: dropHover
                                ? scheme.primaryContainer
                                    .withValues(alpha: 0.55)
                                : scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                          child: hourTasks.isEmpty
                              ? const SizedBox(height: 48)
                              : Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 6, 6, 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final task in hourTasks) ...[
                                        Builder(
                                          builder: (ctx) {
                                            final key = _planKey(task);
                                            final displayDone =
                                                _planDoneOverride[key] ??
                                                    task.isDone;
                                            return _planCardRow(
                                              context: ctx,
                                              task: task,
                                              key: key,
                                              displayDone: displayDone,
                                              isSelected: _selectedPlanKeys
                                                  .contains(key),
                                              enableLongPressDrag: true,
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        );
                      },
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        tooltip: t(loc, 'plan_quick_add_hour'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant
                              .withValues(alpha: 0.55),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        iconSize: 20,
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () => _openQuickAddForHour(hour),
                      ),
                    ),
                  ],
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
      resizeToAvoidBottomInset: true,
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
          if (!_planSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: t(currentLocale.value, 'plan_settings_tooltip'),
              onPressed: _showPlanningSettingsSheet,
            ),
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
                        onPressed: () => _bulkMarkCompleted(tasks),
                        child: Text(
                          t(currentLocale.value, 'plan_bulk_mark_done'),
                          style: TextStyle(color: scheme.primary),
                        ),
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
                                buildDefaultDragHandles: false,
                                proxyDecorator:
                                    (Widget child, int index, Animation<double> anim) {
                                  return AnimatedBuilder(
                                    animation: anim,
                                    builder: (context, c) {
                                      final v = Curves.easeInOut.transform(anim.value);
                                      return Material(
                                        elevation: lerpDouble(0, 10, v) ?? 0,
                                        shadowColor: Colors.black38,
                                        borderRadius: BorderRadius.circular(12),
                                        clipBehavior: Clip.antiAlias,
                                        child: c,
                                      );
                                    },
                                    child: child,
                                  );
                                },
                                itemCount: tasks.length,
                                onReorder: (oldI, newI) =>
                                    _onReorder(tasks, oldI, newI),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final key = _planKey(task);
                                  final displayDone =
                                      _planDoneOverride[key] ?? task.isDone;
                                  final canReorder = !_planSelectMode &&
                                      !task.planRowIdForNoco.startsWith('optimistic-');
                                  return ReorderableDelayedDragStartListener(
                                    key: ValueKey(key),
                                    index: index,
                                    enabled: canReorder,
                                    child: _planCardRow(
                                      context: context,
                                      task: task,
                                      key: key,
                                      displayDone: displayDone,
                                      isSelected:
                                          _selectedPlanKeys.contains(key),
                                    ),
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

/// Expanding semi-circle FAB menu: primary at [anchorCenter], three satellites with labels.
class _SemicirclePlanningMenuOverlay extends StatefulWidget {
  const _SemicirclePlanningMenuOverlay({
    required this.anchorCenter,
    required this.onDismiss,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
  });

  final Offset anchorCenter;
  final VoidCallback onDismiss;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  State<_SemicirclePlanningMenuOverlay> createState() =>
      _SemicirclePlanningMenuOverlayState();
}

class _SemicirclePlanningMenuOverlayState
    extends State<_SemicirclePlanningMenuOverlay>
    with SingleTickerProviderStateMixin {
  static const double _canvas = 300;
  /// Match planning card menu control (44) so the close hub covers the tap target.
  static const double _hub = 44;
  static const double _orbit = 100;
  static const double _satellite = 60;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    unawaited(_controller.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Polar offsets from hub center: standard math angle from +X (east), CCW.
  /// Flutter Y grows downward, so Y uses `-sin` for a visual CCW arc.
  /// Arc to the **left** of the hub uses angles π, 2π/3, 4π/3 (straight left, up-left, down-left).
  Offset _orbitOffsetLeftArc(double radians) {
    return Offset(
      math.cos(radians) * _orbit,
      -math.sin(radians) * _orbit,
    );
  }

  Widget _labeledAction({
    required int index,
    required Offset offsetFromHub,
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final delayed = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        index * 0.11,
        0.65 + index * 0.12,
        curve: Curves.easeOutBack,
      ),
    );
    return Positioned(
      left: _canvas / 2 + offsetFromHub.dx - _satellite / 2,
      top: _canvas / 2 + offsetFromHub.dy - _satellite / 2 - 22,
      child: FadeTransition(
        opacity: delayed,
        child: ScaleTransition(
          scale: delayed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 4,
                color: background,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: _satellite,
                    height: _satellite,
                    child: Icon(icon, color: foreground, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;

    // Hub center must align exactly with the menu button center (no clamp — that broke anchoring).
    final stackLeft = widget.anchorCenter.dx - _canvas / 2;
    final stackTop = widget.anchorCenter.dy - _canvas / 2;

    final hubAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.36)),
            ),
          ),
          Positioned(
            left: stackLeft,
            top: stackTop,
            width: _canvas,
            height: _canvas,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Left semicircle: up-left → Edit, mid-left → Select, down-left → Delete (thumb-friendly).
                _labeledAction(
                  index: 0,
                  offsetFromHub: _orbitOffsetLeftArc(2 * math.pi / 3),
                  icon: Icons.edit_rounded,
                  label: t(loc, 'plan_sheet_edit'),
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                  onTap: widget.onEdit,
                ),
                _labeledAction(
                  index: 1,
                  offsetFromHub: _orbitOffsetLeftArc(math.pi),
                  icon: Icons.checklist_rounded,
                  label: t(loc, 'plan_sheet_select'),
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                  onTap: widget.onSelect,
                ),
                _labeledAction(
                  index: 2,
                  offsetFromHub: _orbitOffsetLeftArc(4 * math.pi / 3),
                  icon: Icons.delete_outline_rounded,
                  label: t(loc, 'plan_sheet_delete'),
                  background: scheme.errorContainer,
                  foreground: scheme.onErrorContainer,
                  onTap: widget.onDelete,
                ),
                Positioned(
                  left: _canvas / 2 - _hub / 2,
                  top: _canvas / 2 - _hub / 2,
                  child: FadeTransition(
                    opacity: hubAnim,
                    child: ScaleTransition(
                      scale: hubAnim,
                      child: Tooltip(
                        message: t(loc, 'plan_radial_close'),
                        child: Material(
                          elevation: 6,
                          color: scheme.primary,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.onDismiss,
                            child: SizedBox(
                              width: _hub,
                              height: _hub,
                              child: Icon(
                                Icons.close_rounded,
                                color: scheme.onPrimary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// Bottom sheet: local timeline hour range (0–23) for the Planning grid.
class _PlanningTimelineBoundsSheet extends StatefulWidget {
  const _PlanningTimelineBoundsSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.onBoundsChanged,
    required this.startTitle,
    required this.startHint,
    required this.endTitle,
    required this.endHint,
  });

  final int initialStart;
  final int initialEnd;
  final void Function(int start, int end) onBoundsChanged;
  final String startTitle;
  final String startHint;
  final String endTitle;
  final String endHint;

  @override
  State<_PlanningTimelineBoundsSheet> createState() =>
      _PlanningTimelineBoundsSheetState();
}

class _PlanningTimelineBoundsSheetState
    extends State<_PlanningTimelineBoundsSheet> {
  late double _startValue;
  late double _endValue;

  @override
  void initState() {
    super.initState();
    _startValue =
        PlanningSheetTimelinePrefs.clampHour(widget.initialStart).toDouble();
    _endValue =
        PlanningSheetTimelinePrefs.clampHour(widget.initialEnd).toDouble();
  }

  void _commit() {
    widget.onBoundsChanged(_startValue.round(), _endValue.round());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final startLabel = _startValue.round();
    final endLabel = _endValue.round();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.startTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.startHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$startLabel',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _startValue.clamp(0, 23),
                  min: 0,
                  max: 23,
                  divisions: 23,
                  label: '$startLabel',
                  onChanged: (v) {
                    setState(() => _startValue = v);
                    _commit();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.endTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.endHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$endLabel',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _endValue.clamp(0, 23),
                  min: 0,
                  max: 23,
                  divisions: 23,
                  label: '$endLabel',
                  onChanged: (v) {
                    setState(() => _endValue = v);
                    _commit();
                  },
                ),
              ),
            ],
          ),
        ],
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
    required this.toggleDoneEnabled,
    required this.onToggleDone,
    required this.onBodyTap,
    required this.onPlay,
    required this.onOpenMenu,
  });

  final PlanningTask task;
  /// Merged server [PlanningTask.isDone] with optimistic override from parent.
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool toggleDoneEnabled;
  final VoidCallback onToggleDone;
  final VoidCallback onBodyTap;
  final VoidCallback onPlay;
  final void Function(BuildContext anchorContext) onOpenMenu;

  static String _formatPlanningTaskDate(PlanningTask task) {
    if (task.dateKey.isEmpty) return '';
    final d = _dateFromKey(task.dateKey);
    if (d == null) return task.dateKey;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = d.month >= 1 && d.month <= 12 ? months[d.month - 1] : '';
    return '${d.day} $m';
  }

  static DateTime? _dateFromKey(String key) {
    if (key.length < 10) return null;
    final y = int.tryParse(key.substring(0, 4));
    final m = int.tryParse(key.substring(5, 7));
    final d = int.tryParse(key.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// [wall] is profile wall time from [PlanningTask.startTime] / end (not UTC).
  static String _formatPlanningWallTime(DateTime wall) {
    return '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
  }

  static String _subtitle(PlanningTask task) {
    final dateStr = _formatPlanningTaskDate(task);
    final displayDate = dateStr.isNotEmpty ? dateStr : task.dateKey;
    if (task.startTime != null && task.endDateTime != null) {
      return '$displayDate • ${_formatPlanningWallTime(task.startTime!)} - ${_formatPlanningWallTime(task.endDateTime!)}';
    }
    if (task.startTime != null) {
      return '$displayDate • ${_formatPlanningWallTime(task.startTime!)}';
    }
    return displayDate;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selectMode && isSelected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final suppressChildInk = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      checkboxTheme: CheckboxThemeData(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBodyTap,
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: suppressChildInk,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, top: 4),
                  child: Checkbox(
                    value: displayIsDone,
                    tristate: false,
                    onChanged: toggleDoneEnabled
                        ? (_) => onToggleDone()
                        : null,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, top: 10),
                          child: Icon(
                            Icons.folder_rounded,
                            color: DatabaseService.instance
                                .getCategoryColor(task.categoryId),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
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
                                        ? scheme.onSurface
                                            .withValues(alpha: 0.62)
                                        : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _subtitle(task),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    hoverColor: Colors.transparent,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: onPlay,
                  tooltip: t(currentLocale.value, 'start'),
                ),
                Builder(
                  builder: (menuCtx) {
                    return IconButton(
                      tooltip: t(currentLocale.value, 'plan_radial_menu_tip'),
                      style: IconButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        hoverColor: Colors.transparent,
                        backgroundColor: scheme.secondaryContainer
                            .withValues(alpha: 0.92),
                        foregroundColor: scheme.onSecondaryContainer,
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.menu_open_rounded, size: 24),
                      onPressed: () => onOpenMenu(menuCtx),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
