// ---------------------------------------------------------------------------
// PLANNING FEATURE — Day planning & task list tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/bulk_planning_edit_sheet.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/features/planning/smart_plan_sheet.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

enum _PlanSortMode { category, time, tags, custom }

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
  final Future<void> Function(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) onStartRecordFromTask;
  final void Function(PlanningTask task) onEditTask;

  @override
  State<PlanningSwipeWrapper> createState() => _PlanningSwipeWrapperState();
}

class _PlanningSwipeWrapperState extends State<PlanningSwipeWrapper> {
  static const int initialPage = 5000;
  static const int totalPageCount = 10000;
  late PageController _controller;
  late DateTime _anchorDate;
  /// Page index currently shown; only this day’s [PlanningPage] subscribes to [DatabaseService.notifyPlanningRefresh].
  late int _visiblePageIndex;

  String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _anchorDate = DateUtils.dateOnly(DateTime.now());
    final daysOffset = _dateOnly(widget.selectedDate).difference(_anchorDate).inDays;
    _visiblePageIndex = initialPage + daysOffset;
    _controller = PageController(initialPage: _visiblePageIndex);
  }

  @override
  void didUpdateWidget(covariant PlanningSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      final daysOffset = _dateOnly(widget.selectedDate).difference(_anchorDate).inDays;
      final page = initialPage + daysOffset;
      if (page >= 0 && page < totalPageCount) {
        setState(() => _visiblePageIndex = page);
      }
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
    try {
      return ScrollConfiguration(
        behavior: const MouseDragScrollBehavior(),
        child: PageView.builder(
        controller: _controller,
        itemCount: totalPageCount,
        onPageChanged: (int index) {
          if (index >= 0 && index < totalPageCount) {
            setState(() => _visiblePageIndex = index);
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
            isActivePlanningDay: index == _visiblePageIndex,
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
      ),
    );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PlanningSwipeWrapper: $e\n$st');
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              t(currentLocale.value, 'no_data_found'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }
}

/// Single-day planning: task list, add task, date picker. [onEditTask] is called when user opens a task for edit (shell shows sheet).
class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.selectedDateString,
    this.selectedDate,
    this.isActivePlanningDay = false,
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
  /// Only the visible PageView day should be `true` so global planning refresh does not N× the same GET.
  final bool isActivePlanningDay;
  final int? selectedCategoryId;
  final void Function(int? categoryId) onCategoryChanged;
  final Future<void> Function(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) onStartRecordFromTask;
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
  final _quickAddFocus = FocusNode();
  final Set<String> _selectedPlanKeys = {};
  final List<PlanningTask> _optimisticTasks = [];
  final Map<String, bool> _planDoneOverride = {};
  Stream<List<PlanningTask>>? _planningStream;
  List<PlanningTask>? _dragOrder;
  bool _planSelectMode = false;
  _PlanSortMode _sortMode = _PlanSortMode.custom;
  int _timelineHourStart = 0;
  int _timelineHourEnd = 23;

  StreamSubscription<void>? _planningTimeSub;
  StreamSubscription<void>? _tagsCatalogSub;
  String? _activeRecordingTitleNorm;

  static const int _kUntaggedPlanGroupId = -1;

  /// Tags for quick-add row; reloaded after returning from [TagSettingsHub].
  List<Tag> _quickAddAvailableTags = [];
  bool _quickAddTagsLoading = true;
  /// M2M tags selected before submitting the inline task.
  List<Tag> _creationSelectedTags = [];

  DateTime get _today => DatabaseService.instance.getTimelineDeviceLocalToday();

  String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _planDateFromTaskDateKey(String key) {
    if (key.length < 10) return null;
    final y = int.tryParse(key.substring(0, 4));
    final m = int.tryParse(key.substring(5, 7));
    final d = int.tryParse(key.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  Future<void> _changeSingleTaskDate(PlanningTask task) async {
    if (task.planRowIdForBackend.startsWith('optimistic-')) return;
    if (task.id <= 0) return;
    final loc = currentLocale.value;
    final initial = _planDateFromTaskDateKey(task.dateKey) ??
        widget.selectedDate ??
        _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.utc(initial.year, initial.month, initial.day),
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2035),
    );
    if (picked == null || !mounted) return;
    var h = 9;
    var min = 0;
    if (task.startTime != null) {
      h = task.startTime!.hour;
      min = task.startTime!.minute;
    }
    final wallStart =
        DateTime(picked.year, picked.month, picked.day, h, min);
    DateTime? wallEnd;
    if (task.endDateTime != null) {
      wallEnd = DateTime(
        picked.year,
        picked.month,
        picked.day,
        task.endDateTime!.hour,
        task.endDateTime!.minute,
      );
    }
    final newKey = _dateKeyFromDate(picked);
    final anchorShort =
        DatabaseService.instance.planningAuditAnchorDateKey(task);
    const minKeyLen = 10;
    final persistInitial = anchorShort.length >= minKeyLen
        ? anchorShort
        : DatabaseService.instance.planningWallScheduleDateKey(task);
    final initForPatch =
        persistInitial.length >= minKeyLen ? persistInitial : newKey;
    final postponed = !task.isDone &&
        DatabaseService.instance.planningShouldMarkPostponed(
          anchorKey: initForPatch,
          newScheduleKey: newKey,
        );
    final updated = task.copyWith(
      dateKey: newKey,
      date: DateTime.utc(picked.year, picked.month, picked.day),
      startTime: wallStart,
      endDateTime: wallEnd,
      endDateKey: wallEnd != null ? newKey : null,
      clearEnd: task.endDateTime == null,
      initialDateKey: initForPatch,
      isPostponed: postponed,
    );
    DatabaseService.instance.applyOptimisticPlanningTask(updated);
    DatabaseService.instance.notifyPlanningRefresh();
    setState(() {});
    final ok = await DatabaseService.instance.updatePlanningTask(
      task.planRowIdForBackend,
      planBusinessId: task.planRowId,
      startTimeDisplay: wallStart,
      endDateTimeDisplay: wallEnd,
      clearEnd: task.endDateTime == null,
      suppressAppSnack: true,
      planInitialDateKey: initForPatch.length >= minKeyLen ? initForPatch : null,
      planIsPostponed: postponed,
    );
    if (!mounted) return;
    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      DatabaseService.instance.notifyPlanningRefresh();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'plan_save_failed'))),
      );
    }
  }

  /// Stable unique key for list tiles. Never use bare `id` alone — Noco `id` can be 0 for
  /// multiple rows before sync, which duplicates [ValueKey]s and crashes the Time grid.
  static String _planKey(PlanningTask t) {
    final p = t.planRowIdForBackend.trim();
    if (p.isNotEmpty) return p;
    return 'plan-fallback-${t.id}-${t.order}-${t.dateKey}-${t.categoryId}-${t.title}';
  }

  Stream<List<PlanningTask>> _createPlanningStream() =>
      DatabaseService.instance.planningStream(
        widget.selectedDate ?? _today,
        listenToGlobalPlanningRefresh: widget.isActivePlanningDay,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _planningStream = _createPlanningStream();
    _activeRecordingTitleNorm = DatabaseService.instance.cachedPrimaryRunningTitle
        ?.trim()
        .toLowerCase();
    _planningTimeSub =
        DatabaseService.instance.timeUpdates.listen((_) {
      if (!mounted) return;
      final t = DatabaseService.instance.cachedPrimaryRunningTitle
          ?.trim()
          .toLowerCase();
      if (t != _activeRecordingTitleNorm) {
        setState(() => _activeRecordingTitleNorm = t);
      }
    });
    _tagsCatalogSub =
        DatabaseService.instance.tagsCatalogUpdated.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    unawaited(_loadPlanningTimelineBounds());
    unawaited(_reloadQuickAddTags());
  }

  Future<void> _reloadQuickAddTags() async {
    if (!mounted) return;
    setState(() => _quickAddTagsLoading = true);
    final list = await DatabaseService.instance.fetchTagsForCurrentUser();
    if (!mounted) return;
    setState(() {
      _quickAddAvailableTags = list;
      _quickAddTagsLoading = false;
    });
  }

  Future<void> _openTagManagerFromQuickAdd() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (ctx) => const TagSettingsHub()),
    );
    await _reloadQuickAddTags();
  }

  void _toggleCreationTag(Tag tag) {
    setState(() {
      final next = List<Tag>.from(_creationSelectedTags);
      final i = next.indexWhere((x) => x.tagId == tag.tagId);
      if (i >= 0) {
        next.removeAt(i);
      } else {
        next.add(tag);
      }
      _creationSelectedTags = next;
    });
  }

  void _onPlanningQuickBarReorder(int oldIndex, int newIndex) {
    if (_quickAddAvailableTags.length < 2) return;
    if (oldIndex < 0 || oldIndex >= _quickAddAvailableTags.length) return;
    if (newIndex < 0 || newIndex > _quickAddAvailableTags.length) return;
    var ni = newIndex;
    if (oldIndex < ni) ni -= 1;
    if (ni < 0 || ni >= _quickAddAvailableTags.length) return;

    final previous = List<Tag>.from(_quickAddAvailableTags);
    final row = previous[oldIndex];
    final next = List<Tag>.from(previous);
    next.removeAt(oldIndex);
    next.insert(ni, row);
    final withSort = <Tag>[
      for (var i = 0; i < next.length; i++) next[i].copyWith(sortOrder: i),
    ];
    setState(() => _quickAddAvailableTags = withSort);
    unawaited(_persistPlanningQuickBarSortOrder(previous, withSort));
  }

  Future<void> _persistPlanningQuickBarSortOrder(
    List<Tag> previousUiOrder,
    List<Tag> ordered,
  ) async {
    final ok = await DatabaseService.instance
        .persistTagsSortOrderForCurrentUser(ordered);
    if (!mounted) return;
    if (ok) {
      DatabaseService.instance.notifyPlanningRefresh();
      return;
    }
    setState(() => _quickAddAvailableTags = List<Tag>.from(previousUiOrder));
    AppSnack.failed();
  }

  Widget _buildQuickAddTagStrip(ColorScheme scheme) {
    final loc = currentLocale.value;
    if (_quickAddTagsLoading) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
      );
    }
    if (_quickAddAvailableTags.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _openTagManagerFromQuickAdd,
          child: Text(t(loc, 'plan_quick_add_no_tags')),
        ),
      );
    }
    return TagQuickPickStrip(
      tags: _quickAddAvailableTags,
      selected: _creationSelectedTags,
      onToggle: _toggleCreationTag,
      fallbackColor: scheme.primary,
      onReorder: _quickAddAvailableTags.length >= 2
          ? _onPlanningQuickBarReorder
          : null,
    );
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

  void _shiftPlanningDay(int days) {
    if (_planSelectMode || days == 0) return;
    final base = widget.selectedDate ?? _today;
    final day = DateTime(base.year, base.month, base.day);
    widget.onDatePicked?.call(day.add(Duration(days: days)));
  }

  void _openPlanningHeaderDatePicker() {
    if (_planSelectMode) return;
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
              header: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.label_outline_rounded),
                    title: Text(t(loc, 'tag_settings_hub_title')),
                    subtitle: Text(
                      t(loc, 'tag_settings_sheet_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const TagSettingsHub(),
                        ),
                      );
                    },
                  ),
                ],
              ),
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
        oldWidget.selectedDateString != widget.selectedDateString ||
        oldWidget.isActivePlanningDay != widget.isActivePlanningDay) {
      setState(() {
        _planningStream = _createPlanningStream();
        if (oldWidget.selectedDate != widget.selectedDate ||
            oldWidget.selectedDateString != widget.selectedDateString) {
          _optimisticTasks.clear();
          _planDoneOverride.clear();
          _dragOrder = null;
          _selectedPlanKeys.clear();
          _planSelectMode = false;
          _sortMode = _PlanSortMode.custom;
        }
      });
    }
  }

  @override
  void dispose() {
    _planningTimeSub?.cancel();
    _tagsCatalogSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(DatabaseService.instance.flushPlanningOrderSyncNow());
    _textController.dispose();
    _quickAddFocus.dispose();
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
    setState(() {
      _selectedPlanKeys.clear();
      _planSelectMode = false;
    });
  }

  Future<void> _openBulkPlanningEdit(List<PlanningTask> tasks) async {
    if (_selectedPlanKeys.isEmpty) return;
    final loc = currentLocale.value;
    final initial = widget.selectedDate ?? _today;
    final selectedList = <PlanningTask>[];
    for (final t in tasks) {
      if (_selectedPlanKeys.contains(_planKey(t))) {
        selectedList.add(t);
      }
    }
    if (selectedList.isEmpty) return;

    final result = await showBulkPlanningEditSheet(
      context,
      initialDay: initial,
      selectedTasks: selectedList,
    );
    if (result == null || !mounted) return;

    final refDay = widget.selectedDate ?? _today;
    final sameDay = result.targetDate.year == refDay.year &&
        result.targetDate.month == refDay.month &&
        result.targetDate.day == refDay.day;
    if (sameDay && !result.applyTimeReanchor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'plan_bulk_edit_no_changes'))),
      );
      return;
    }
    if (sameDay &&
        result.applyTimeReanchor &&
        result.timeShift.inSeconds == 0 &&
        !selectedList.any((x) => x.startTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'plan_bulk_edit_no_changes'))),
      );
      return;
    }

    final patches = <PlanningBulkPatch>[];
    for (final key in _selectedPlanKeys.toList()) {
      PlanningTask? match;
      for (final t in tasks) {
        if (_planKey(t) == key) {
          match = t;
          break;
        }
      }
      if (match == null) continue;
      if (match.planRowIdForBackend.startsWith('optimistic-')) continue;
      final pbId = match.pocketRecordId?.trim() ?? '';
      if (pbId.isEmpty) continue;

      final wall = computeBulkEditWallTimes(match, result);
      final d = DateTime(wall.start.year, wall.start.month, wall.start.day);
      final newKey = _dateKeyFromDate(d);
      final anchorShort =
          DatabaseService.instance.planningAuditAnchorDateKey(match);
      const minKeyLen = 10;
      final persistInitial = anchorShort.length >= minKeyLen
          ? anchorShort
          : DatabaseService.instance.planningWallScheduleDateKey(match);
      final initForPatch =
          persistInitial.length >= minKeyLen ? persistInitial : newKey;
      final postponed = !match.isDone &&
          DatabaseService.instance.planningShouldMarkPostponed(
            anchorKey: initForPatch,
            newScheduleKey: newKey,
          );
      final updated = match.copyWith(
        dateKey: newKey,
        date: DateTime.utc(d.year, d.month, d.day),
        startTime: wall.start,
        endDateTime: wall.end,
        endDateKey: wall.end != null ? newKey : null,
        clearEnd: match.endDateTime == null,
        initialDateKey: initForPatch,
        isPostponed: postponed,
      );
      DatabaseService.instance.applyOptimisticPlanningTask(updated);
      patches.add(
        PlanningBulkPatch(
          planRowId: match.planRowIdForBackend,
          planBusinessId: match.planRowId,
          startTimeDisplay: wall.start,
          endDateTimeDisplay: wall.end,
          clearEnd: match.endDateTime == null,
          initialDateKey: initForPatch,
          isPostponed: postponed,
        ),
      );
    }

    if (patches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(loc, 'plan_save_failed'))),
        );
      }
      return;
    }

    DatabaseService.instance.notifyPlanningRefresh();
    if (mounted) setState(() {});
    final ok = await DatabaseService.instance.bulkUpdatePlans(
      patches,
      suppressAppSnack: true,
    );
    if (!mounted) return;
    setState(() {
      _selectedPlanKeys.clear();
      _planSelectMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? t(loc, 'plan_bulk_edit_success') : t(loc, 'plan_save_failed'),
        ),
      ),
    );
  }

  Future<void> _bulkDelete(List<PlanningTask> tasks) async {
    final ids = <String>[];
    for (final key in _selectedPlanKeys.toList()) {
      PlanningTask? match;
      for (final t in tasks) {
        if (_planKey(t) == key) {
          match = t;
          break;
        }
      }
      if (match == null) continue;
      if (match.planRowIdForBackend.startsWith('optimistic-')) continue;
      final rid = match.recordIdForBackend.trim();
      if (rid.isEmpty) continue;
      ids.add(rid);
    }
    await DatabaseService.instance.deletePlanningTasksBulk(ids);
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
      startTime: wall,
      date: DateTime.utc(d.year, d.month, d.day),
      endDateTime: null,
      checklist: const [],
      notes: null,
      parentPlanId: null,
      initialDateKey: widget.selectedDateString.length >= 10
          ? widget.selectedDateString.substring(0, 10)
          : null,
      isPostponed: false,
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
            unawaited(DatabaseService.instance.deletePlanningTask(task.planRowIdForBackend));
            if (mounted) setState(() {});
          },
        );
      },
    );
    overlay.insert(entry);
  }

  Future<void> _addTask() async {
    final taskDateKey = widget.selectedDateString;
    final raw = _textController.text;
    final baseDay = widget.selectedDate ?? _today;
    final wallDay = DateTime(baseDay.year, baseDay.month, baseDay.day);

    final range = SmartInputParser.parseTitleForTimeRange(raw);
    SmartTimeParseResult? parsed;
    String title;
    final DateTime? startStored;
    final DateTime? endStored;

    if (range != null) {
      title = range.cleanedTitle.trim();
      if (title.isEmpty) {
        title = t(currentLocale.value, 'plan_title_time_range_fallback');
      }
      startStored =
          DatabaseService.instance.displayTimeToUtc(range.startWallOn(wallDay));
      endStored =
          DatabaseService.instance.displayTimeToUtc(range.endWallOn(wallDay));
    } else {
      parsed = SmartInputParser.parseTitleForScheduledTime(raw);
      title = (parsed?.cleanedTitle ?? raw).trim();
      if (title.isEmpty) return;
      startStored = parsed != null
          ? DatabaseService.instance.displayTimeToUtc(
              parsed.wallDateTimeOn(wallDay),
            )
          : null;
      endStored = null;
    }

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
    final clientPlanId = DatabaseService.newClientUuid();
    final optimisticRow = 'optimistic-$clientPlanId';
    final tagsForCreate = List<Tag>.from(_creationSelectedTags);
    final pending = PlanningTask(
      id: optimisticId,
      planRowId: optimisticRow,
      title: title,
      categoryId: categoryId,
      isDone: false,
      dateKey: taskDateKey,
      order: nextOrder,
      startTime: startStored,
      endDateTime: endStored,
      checklist: const [],
      notes: null,
      parentPlanId: null,
      tags: tagsForCreate,
      isSynced: false,
    );
    setState(() => _optimisticTasks.add(pending));
    try {
      final ok = await DatabaseService.instance.addPlanningTask(
        PlanningTask(
          id: 0,
          title: title,
          categoryId: categoryId,
          isDone: false,
          dateKey: taskDateKey,
          order: nextOrder,
          startTime: startStored,
          endDateTime: endStored,
          checklist: const [],
          notes: null,
          parentPlanId: null,
          tags: tagsForCreate,
          isSynced: false,
        ),
        clientPlanId: clientPlanId,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _optimisticTasks.removeWhere((o) => o.planRowId == optimisticRow));
      } else {
        _textController.clear();
        setState(() {
          _creationSelectedTags = [];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PLAN_ADD_UI: $e');
      }
    }
  }

  DateTime _wallDateTimeFromHhmm(DateTime day, String hhmm) {
    final parts = hhmm.trim().split(':');
    final h = int.tryParse(parts[0].trim()) ?? 9;
    final mi = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return DateTime(
      day.year,
      day.month,
      day.day,
      h.clamp(0, 23),
      mi.clamp(0, 59),
    );
  }

  /// Smart Plan: append AI-parsed tasks for [widget.selectedDateString] (does not remove existing).
  Future<int> _injectSmartPlanTasks(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return 0;
    final taskDateKey = widget.selectedDateString;
    final baseDay = widget.selectedDate ?? _today;
    final wallDay = DateTime(baseDay.year, baseDay.month, baseDay.day);

    var nextOrder = await DatabaseService.instance
        .nextPlanningOrderForDate(widget.selectedDate ?? _today);
    for (final t in _optimisticTasks) {
      if (t.order >= nextOrder) nextOrder = t.order + 1;
    }

    var created = 0;
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      final title = (m['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final hhmm = (m['startTime'] ?? '09:00').toString().trim();
      final durRaw = m['durationMinutes'] ?? 60;
      final minutes = durRaw is int
          ? durRaw
          : (durRaw is num ? durRaw.round() : int.tryParse('$durRaw') ?? 60);
      final safeMinutes = minutes < 1 ? 1 : minutes;

      final startWall = _wallDateTimeFromHhmm(wallDay, hhmm);
      final endWall = startWall.add(Duration(minutes: safeMinutes));

      final startStored =
          DatabaseService.instance.displayTimeToUtc(startWall);
      final endStored =
          DatabaseService.instance.displayTimeToUtc(endWall);

      final aiCategoryStr = m['category']?.toString().trim();
      final fromAiId = DatabaseService.instance
          .resolveCategoryIdFromSmartPlanLabel(aiCategoryStr);
      final fromTitle = DatabaseService.instance.identifyCategory(title);
      final categoryId = fromAiId ??
          fromTitle?.id ??
          widget.selectedCategoryId ??
          DatabaseService.instance.defaultCategoryId ??
          (DatabaseService.instance.rules.isNotEmpty
              ? DatabaseService.instance.rules.first.id
              : 0);

      final order = nextOrder + i;
      final optimisticId = DatabaseService.instance.newId();
      final clientPlanId = DatabaseService.newClientUuid();
      final optimisticRow = 'optimistic-$clientPlanId';
      final pending = PlanningTask(
        id: optimisticId,
        planRowId: optimisticRow,
        title: title,
        categoryId: categoryId,
        isDone: false,
        dateKey: taskDateKey,
        order: order,
        startTime: startStored,
        endDateTime: endStored,
        checklist: const [],
        notes: null,
        parentPlanId: null,
        tags: <Tag>[],
        isSynced: false,
      );
      if (!mounted) return created;
      setState(() => _optimisticTasks.add(pending));

      try {
        final ok = await DatabaseService.instance.addPlanningTask(
          PlanningTask(
            id: 0,
            title: title,
            categoryId: categoryId,
            isDone: false,
            dateKey: taskDateKey,
            order: order,
            startTime: startStored,
            endDateTime: endStored,
            checklist: const [],
            notes: null,
            parentPlanId: null,
            tags: <Tag>[],
            isSynced: false,
          ),
          clientPlanId: clientPlanId,
        );
        if (!mounted) return created;
        if (ok) {
          created++;
        } else {
          setState(() => _optimisticTasks
              .removeWhere((o) => o.planRowId == optimisticRow));
        }
      } catch (_) {
        if (mounted) {
          setState(() => _optimisticTasks
              .removeWhere((o) => o.planRowId == optimisticRow));
        }
      }
    }
    return created;
  }

  void _openSmartPlanSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SmartPlanSheet(
        onCommit: _injectSmartPlanTasks,
      ),
    );
  }

  Future<void> _toggleDone(PlanningTask task, bool currentDisplayDone) async {
    if (task.planRowIdForBackend.startsWith('optimistic-')) return;
    final key = _planKey(task);
    final next = !currentDisplayDone;
    setState(() => _planDoneOverride[key] = next);
    try {
      final ok = await DatabaseService.instance.updatePlanningTask(
        task.planRowIdForBackend,
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
    } catch (e) {
      print('UI ERROR: $e');
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

  /// Bar index for [tagId] in [masterBarOrder]; tags not in the bar sort after all bar tags.
  int _masterBarIndexForTag(int tagId, List<Tag> masterBarOrder) {
    for (var i = 0; i < masterBarOrder.length; i++) {
      if (masterBarOrder[i].tagId == tagId) return i;
    }
    return 1 << 20;
  }

  /// Chip tag that appears earliest in the quick-pick / master sequence wins the group.
  /// Canonical [Tag] is taken from [masterBarOrder] when present, else the task tag.
  Tag? _priorityTagForPlanByMasterBar(
    PlanningTask p,
    List<Tag> masterBarOrder,
  ) {
    Tag? best;
    var bestIdx = 1 << 30;
    var bestBiz = 1 << 30;
    for (final tg in p.tags) {
      if (!tg.rendersAsChip) continue;
      final idx = _masterBarIndexForTag(tg.tagId, masterBarOrder);
      final id = tg.tagId;
      if (idx < bestIdx || (idx == bestIdx && id < bestBiz)) {
        bestIdx = idx;
        bestBiz = id;
        Tag? canonical;
        for (final m in masterBarOrder) {
          if (m.tagId == id) {
            canonical = m;
            break;
          }
        }
        best = canonical ?? tg;
      }
    }
    return best;
  }

  List<Tag> _tagSortMasterBarOrder() {
    if (_quickAddAvailableTags.isNotEmpty) {
      return _quickAddAvailableTags;
    }
    return DatabaseService.instance.cachedUserTagsCatalog;
  }

  Map<int, List<PlanningTask>> _groupTasksByMasterBar(
    List<PlanningTask> tasks,
    List<Tag> masterBarOrder,
  ) {
    final groups = <int, List<PlanningTask>>{};
    for (final p in tasks) {
      final pt = _priorityTagForPlanByMasterBar(p, masterBarOrder);
      final gid = pt == null ? _kUntaggedPlanGroupId : pt.tagId;
      groups.putIfAbsent(gid, () => []).add(p);
    }
    for (final e in groups.entries) {
      e.value.sort(_taskSortCmp);
    }
    return groups;
  }

  /// Group column order: follow [masterBarOrder], then orphan tag ids (by id), then “No tags”.
  List<int> _groupIdsInMasterBarSequence(
    Map<int, List<PlanningTask>> groups,
    List<Tag> masterBarOrder,
  ) {
    final seen = <int>{};
    final out = <int>[];
    for (final t in masterBarOrder) {
      final id = t.tagId;
      if (id == 0) continue;
      final bucket = groups[id];
      if (bucket != null && bucket.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        out.add(id);
      }
    }
    final orphan = groups.keys
        .where((k) => k != _kUntaggedPlanGroupId && !seen.contains(k))
        .toList()
      ..sort();
    out.addAll(orphan);
    final untagged = groups[_kUntaggedPlanGroupId];
    if (untagged != null && untagged.isNotEmpty) {
      out.add(_kUntaggedPlanGroupId);
    }
    return out;
  }

  _PlanningTaskCard _planningTaskCardForRow(
    PlanningTask task,
    String key,
    bool displayDone,
    bool isSelected, {
    required bool highlightAsRunning,
    bool omitLongPress = false,
    required Map<String, int> planActualByPbId,
  }) {
    final pbId = DatabaseService.pocketRelationIdOrNull(task.pocketRecordId);
    final tracked = pbId != null ? (planActualByPbId[pbId] ?? 0) : 0;
    final estimate = DatabaseService.planningWallEstimateSeconds(task);
    return _PlanningTaskCard(
      task: task,
      planTrackedSeconds: tracked,
      planEstimatedSeconds: estimate,
      displayIsDone: displayDone,
      selectMode: _planSelectMode,
      isSelected: isSelected,
      highlightAsRunning: highlightAsRunning,
      toggleDoneEnabled: !task.planRowIdForBackend.startsWith('optimistic-'),
      onToggleDone: () => _toggleDone(task, displayDone),
      onBodyTap: () {
        if (_planSelectMode) {
          _toggleKeySelection(key);
        } else {
          _openEditDialog(task);
        }
      },
      onLongPress: omitLongPress
          ? null
          : () {
              setState(() {
                _planSelectMode = true;
                _selectedPlanKeys.add(key);
              });
            },
      onPlay: () async {
        await widget.onStartRecordFromTask(
          task.title,
          task.categoryId,
          task.dateKey,
          sourcePlanPocketRecordId:
              DatabaseService.pocketRelationIdOrNull(task.pocketRecordId),
        );
        if (mounted) setState(() {});
      },
      onOpenMenu: (anchorCtx) => _showPlanRadialMenu(anchorCtx, task),
      onDateTap: () => unawaited(_changeSingleTaskDate(task)),
    );
  }

  int? _wallClockHourFromTask(PlanningTask task) {
    final st = task.startTime;
    if (st == null) return null;
    return st.hour;
  }

  Future<void> _onPlanningTaskDroppedOnHour(PlanningTask task, int targetHour) async {
    if (task.planRowIdForBackend.startsWith('optimistic-')) return;
    final h = targetHour.clamp(0, 23);
    final currentHour = _wallClockHourFromTask(task);
    if (currentHour != null && currentHour == h) return;

    final d = widget.selectedDate ?? _today;
    var minute = 0;
    if (task.startTime != null) {
      minute = task.startTime!.minute;
    }
    final wallStart = DateTime(d.year, d.month, d.day, h, minute);

    final ok = await DatabaseService.instance.updatePlanningTask(
      task.planRowIdForBackend,
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
        _planningStream = _createPlanningStream();
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
    required Map<String, int> planActualByPbId,
    bool enableLongPressDrag = false,
    /// When true, [InkWell.onLongPress] is omitted so [ReorderableDelayedDragStartListener] can claim long-press reorder.
    bool omitLongPressForReorder = false,
  }) {
    final highlightAsRunning = _activeRecordingTitleNorm != null &&
        _activeRecordingTitleNorm ==
            task.title.trim().toLowerCase();
    final omitLongPress = omitLongPressForReorder;
    final card = _planningTaskCardForRow(
      task,
      key,
      displayDone,
      isSelected,
      highlightAsRunning: highlightAsRunning,
      omitLongPress: omitLongPress,
      planActualByPbId: planActualByPbId,
    );
    final allowLongPressDrag = enableLongPressDrag &&
        !_planSelectMode &&
        !task.planRowIdForBackend.startsWith('optimistic-');
    if (!allowLongPressDrag) {
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
                child: _planningTaskCardForRow(
                  task,
                  key,
                  displayDone,
                  isSelected,
                  highlightAsRunning: highlightAsRunning,
                  omitLongPress: true,
                  planActualByPbId: planActualByPbId,
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _planningTaskCardForRow(
            task,
            key,
            displayDone,
            isSelected,
            highlightAsRunning: highlightAsRunning,
            omitLongPress: true,
            planActualByPbId: planActualByPbId,
          ),
        ),
        child: card,
      ),
    );
  }

  Widget _buildHourGridView(
    List<PlanningTask> tasks,
    Map<String, int> planActualByPbId,
  ) {
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
            planActualByPbId: planActualByPbId,
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
            planActualByPbId: planActualByPbId,
            enableLongPressDrag: true,
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }
    for (final hour in visibleHours) {
      final hourTasks = byHour[hour] ?? <PlanningTask>[];
      final label = hourLabel(hour);
      final dividerColor =
          scheme.outlineVariant.withValues(alpha: 0.45);
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(height: 1, thickness: 1, color: dividerColor),
                ),
              ),
              IconButton(
                tooltip: t(loc, 'plan_quick_add_hour'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor:
                      scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                iconSize: 20,
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _openQuickAddForHour(hour),
              ),
            ],
          ),
        ),
      );
      children.add(
        DragTarget<PlanningTask>(
          hitTestBehavior: HitTestBehavior.opaque,
          onWillAcceptWithDetails: (_) => !_planSelectMode,
          onAcceptWithDetails: (details) {
            unawaited(_onPlanningTaskDroppedOnHour(details.data, hour));
          },
          builder: (context, candidate, rejected) {
            final dropHover = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: dropHover
                    ? scheme.primaryContainer.withValues(alpha: 0.35)
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: hourTasks.isEmpty
                  ? SizedBox(height: dropHover ? 28 : 12)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final task in hourTasks)
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
                                planActualByPbId: planActualByPbId,
                                enableLongPressDrag: true,
                              );
                            },
                          ),
                      ],
                    ),
            );
          },
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: children,
    );
  }

  Widget _buildCategoryGroupedView(
    List<PlanningTask> tasks,
    Map<String, int> planActualByPbId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groupTasksByCategoryPath(tasks);
    final keys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final children = <Widget>[];
    var firstCategoryGroup = true;
    for (final k in keys) {
      if (!firstCategoryGroup) {
        children.add(const SizedBox(height: 32));
      }
      firstCategoryGroup = false;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              localizeCategoryBreadcrumbPath(k, currentLocale.value),
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
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
            planActualByPbId: planActualByPbId,
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: children,
    );
  }

  Widget _buildTagGroupedListView(
    List<PlanningTask> tasks,
    Map<String, int> planActualByPbId,
  ) {
    final masterBar = _tagSortMasterBarOrder();
    final groups = _groupTasksByMasterBar(tasks, masterBar);
    final orderedIds = _groupIdsInMasterBarSequence(groups, masterBar);
    final children = <Widget>[];
    Widget proxyDecorator(
      Widget child,
      int index,
      Animation<double> animation,
    ) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, c) {
          final v = Curves.easeInOut.transform(animation.value);
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
    }

    var firstGroup = true;
    for (final gid in orderedIds) {
      final bucket = groups[gid];
      if (bucket == null || bucket.isEmpty) continue;
      if (!firstGroup) {
        children.add(const SizedBox(height: 24));
      }
      firstGroup = false;
      if (_planSelectMode) {
        for (final task in bucket) {
          final key = _planKey(task);
          final displayDone = _planDoneOverride[key] ?? task.isDone;
          children.add(
            _planCardRow(
              context: context,
              task: task,
              key: key,
              displayDone: displayDone,
              isSelected: _selectedPlanKeys.contains(key),
              planActualByPbId: planActualByPbId,
            ),
          );
        }
      } else {
        children.add(
          ReorderableListView.builder(
            key: ValueKey<String>('tag-bucket-$gid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: proxyDecorator,
            itemCount: bucket.length,
            onReorder: (oldI, newI) =>
                _onTagBucketReorder(tasks, masterBar, gid, oldI, newI),
            itemBuilder: (context, index) {
              final task = bucket[index];
              final key = _planKey(task);
              final displayDone = _planDoneOverride[key] ?? task.isDone;
              final canReorder = !task.planRowIdForBackend.startsWith('optimistic-');
              return ReorderableDelayedDragStartListener(
                key: ValueKey<String>(key),
                index: index,
                enabled: canReorder,
                child: _planCardRow(
                  context: context,
                  task: task,
                  key: key,
                  displayDone: displayDone,
                  isSelected: _selectedPlanKeys.contains(key),
                  planActualByPbId: planActualByPbId,
                  omitLongPressForReorder: canReorder,
                ),
              );
            },
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: children,
    );
  }

  void _onTagBucketReorder(
    List<PlanningTask> allDisplayed,
    List<Tag> masterBar,
    int groupId,
    int oldIndex,
    int newIndex,
  ) {
    if (_planSelectMode || _sortMode != _PlanSortMode.tags) return;
    final groups = _groupTasksByMasterBar(allDisplayed, masterBar);
    final bucket = List<PlanningTask>.from(groups[groupId] ?? []);
    if (bucket.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= bucket.length) return;
    var ni = newIndex;
    if (ni > oldIndex) ni -= 1;
    if (ni < 0 || ni > bucket.length) return;
    final row = bucket[oldIndex];
    if (row.planRowIdForBackend.startsWith('optimistic-')) return;
    bucket.removeAt(oldIndex);
    bucket.insert(ni, row);
    groups[groupId] = bucket;
    final orderedIds = _groupIdsInMasterBarSequence(groups, masterBar);
    final flat = <PlanningTask>[];
    for (final gid in orderedIds) {
      flat.addAll(groups[gid] ?? const <PlanningTask>[]);
    }
    if (flat.length != allDisplayed.length) return;
    final withOrders = <PlanningTask>[
      for (var i = 0; i < flat.length; i++) flat[i].copyWith(order: i),
    ];
    setState(() => _dragOrder = withOrders);
    unawaited(
      DatabaseService.instance.persistPlanningTaskOrder(
        withOrders,
        baselineBeforeReorder: allDisplayed,
      ),
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
    if (row.planRowIdForBackend.startsWith('optimistic-')) return;
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

  Widget? _planningBulkBottomBar(
    BuildContext context,
    ColorScheme scheme,
    List<PlanningTask> tasks,
  ) {
    if (_selectedPlanKeys.isEmpty) return null;
    final loc = currentLocale.value;
    return SafeArea(
      child: Material(
        elevation: 6,
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t(loc, 'selected_count')
                      .replaceFirst('%s', '${_selectedPlanKeys.length}'),
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _clearSelection,
                child: Text(t(loc, 'cancel')),
              ),
              IconButton(
                tooltip: t(loc, 'plan_bulk_edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => unawaited(_openBulkPlanningEdit(tasks)),
              ),
              IconButton(
                tooltip: t(loc, 'delete'),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                onPressed: () => unawaited(_bulkDelete(tasks)),
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
    final headerDate = widget.selectedDate ?? _today;
    String dateStr;
    try {
      dateStr = DateFormat.yMMMMd(currentLocale.value).format(headerDate);
    } catch (_) {
      dateStr =
          '${headerDate.year}-${headerDate.month.toString().padLeft(2, '0')}-${headerDate.day.toString().padLeft(2, '0')}';
    }

    return StreamBuilder<List<PlanningTask>>(
      stream: _planningStream,
      builder: (context, snapshot) {
        List<PlanningTask>? displayedForChrome;
        late final Widget body;
        try {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            body = const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            body = Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t(currentLocale.value, 'no_data_found'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          } else {
            final server = snapshot.data ?? [];
            if (server.isNotEmpty && _optimisticTasks.isNotEmpty) {
              final toDrop = _optimisticTasks
                  .where((o) => server.any((s) =>
                      s.title.trim() == o.title.trim() &&
                      s.dateKey == o.dateKey))
                  .toList();
              if (toDrop.isNotEmpty) {
                final dropIds = toDrop.map((e) => e.planRowId).toSet();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _optimisticTasks
                      .removeWhere((o) => dropIds.contains(o.planRowId)));
                });
              }
            }
            final tasks = _displayTasks(server);
            displayedForChrome = tasks;
            body = _buildPlanningMainColumn(context, scheme, tasks);
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('PlanningPage stream builder: $e\n$st');
          }
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                t(currentLocale.value, 'no_data_found'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          );
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
            title: _planSelectMode
                ? Text(t(currentLocale.value, 'plan_select_mode'))
                : Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: t(currentLocale.value, 'date_previous_day'),
                        onPressed: () => _shiftPlanningDay(-1),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _openPlanningHeaderDatePicker,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${t(currentLocale.value, 'planning')} · $dateStr',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: t(currentLocale.value, 'date_next_day'),
                        onPressed: () => _shiftPlanningDay(1),
                      ),
                    ],
                  ),
            actions: [
              if (_planSelectMode && displayedForChrome != null)
                TextButton(
                  onPressed: () {
                    final list = displayedForChrome;
                    if (list == null) return;
                    setState(() {
                      for (final t in list) {
                        _selectedPlanKeys.add(_planKey(t));
                      }
                    });
                  },
                  child: Text(t(currentLocale.value, 'plan_select_all')),
                ),
              if (!_planSelectMode) ...[
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  tooltip: t(currentLocale.value, 'smart_plan_tooltip'),
                  onPressed: _openSmartPlanSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: t(currentLocale.value, 'plan_settings_tooltip'),
                  onPressed: _showPlanningSettingsSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today_rounded),
                  onPressed: _openPlanningHeaderDatePicker,
                ),
              ],
            ],
          ),
          body: body,
          bottomNavigationBar: displayedForChrome != null
              ? _planningBulkBottomBar(context, scheme, displayedForChrome)
              : null,
        );
      },
    );
  }

  Widget _buildPlanningMainColumn(
    BuildContext context,
    ColorScheme scheme,
    List<PlanningTask> tasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
              if (!_planSelectMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<_PlanSortMode>(
                        segments: [
                          ButtonSegment<_PlanSortMode>(
                            value: _PlanSortMode.category,
                            label: Text(
                                t(currentLocale.value, 'plan_sort_category')),
                          ),
                          ButtonSegment<_PlanSortMode>(
                            value: _PlanSortMode.time,
                            label: Text(
                                t(currentLocale.value, 'plan_sort_time')),
                          ),
                          ButtonSegment<_PlanSortMode>(
                            value: _PlanSortMode.tags,
                            label: Text(
                                t(currentLocale.value, 'plan_sort_tags')),
                          ),
                          ButtonSegment<_PlanSortMode>(
                            value: _PlanSortMode.custom,
                            label: Text(
                                t(currentLocale.value, 'plan_sort_custom')),
                          ),
                        ],
                        selected: {_sortMode},
                        onSelectionChanged: (Set<_PlanSortMode> next) {
                          if (next.isEmpty) return;
                          final mode = next.first;
                          setState(() {
                            _sortMode = mode;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 52,
                      child: _buildQuickAddTagStrip(scheme),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _quickAddFocus,
                            decoration: InputDecoration(
                              labelText:
                                  t(currentLocale.value, 'task_title'),
                              hintText: t(
                                  currentLocale.value, 'hint_task_example'),
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
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<void>(
                  stream: DatabaseService.instance.timeUpdates,
                  builder: (context, _) {
                    final planWallDay = widget.selectedDate ?? _today;
                    final planActualByPbId = DatabaseService.instance
                        .aggregateSourcePlanActualSecondsForWallCalendarDay(
                      planWallDay,
                    );
                    if (tasks.isEmpty) {
                      return EmptyStatePlaceholder(
                        icon: Icons.track_changes_rounded,
                        titleL10nKey: 'empty_planning_title',
                        subtitleL10nKey: 'empty_planning_subtitle',
                        actionLabelL10nKey:
                            'empty_action_focus_planning_field',
                        onAction: () =>
                            FocusScope.of(context).requestFocus(_quickAddFocus),
                      );
                    }
                    if (_sortMode == _PlanSortMode.time) {
                      return _buildHourGridView(tasks, planActualByPbId);
                    }
                    if (_sortMode == _PlanSortMode.category) {
                      return _buildCategoryGroupedView(tasks, planActualByPbId);
                    }
                    if (_sortMode == _PlanSortMode.tags) {
                      return _buildTagGroupedListView(tasks, planActualByPbId);
                    }
                    return ReorderableListView.builder(
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
                            !task.planRowIdForBackend.startsWith('optimistic-');
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(key),
                          index: index,
                          enabled: canReorder,
                          child: _planCardRow(
                            context: context,
                            task: task,
                            key: key,
                            displayDone: displayDone,
                            isSelected: _selectedPlanKeys.contains(key),
                            planActualByPbId: planActualByPbId,
                            omitLongPressForReorder: canReorder,
                          ),
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
    this.header,
  });

  final int initialStart;
  final int initialEnd;
  final void Function(int start, int end) onBoundsChanged;
  final String startTitle;
  final String startHint;
  final String endTitle;
  final String endHint;
  /// Optional row above timeline sliders (e.g. tag manager link).
  final Widget? header;

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
          if (widget.header != null) widget.header!,
          if (widget.header != null) const Divider(height: 1),
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
            // Parent [_openPlanningHeaderDatePicker] already pops via Navigator.of(ctx).pop().
            // A second pop here removed the route under the dialog (white screen).
            onDatePicked(date);
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
    required this.planTrackedSeconds,
    required this.planEstimatedSeconds,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.highlightAsRunning,
    required this.toggleDoneEnabled,
    required this.onToggleDone,
    required this.onBodyTap,
    this.onLongPress,
    required this.onPlay,
    required this.onOpenMenu,
    required this.onDateTap,
  });

  final PlanningTask task;
  /// Sum of record durations this wall day with [source_plan_id] → this plan’s PocketBase id.
  final int planTrackedSeconds;
  /// Planned span from task start/end wall times; null hides the progress strip.
  final int? planEstimatedSeconds;
  /// Merged server [PlanningTask.isDone] with optimistic override from parent.
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool highlightAsRunning;
  final bool toggleDoneEnabled;
  final VoidCallback onToggleDone;
  final VoidCallback onBodyTap;
  final VoidCallback? onLongPress;
  final VoidCallback onPlay;
  final void Function(BuildContext anchorContext) onOpenMenu;
  final VoidCallback onDateTap;

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

  static String _shortDur(int sec) {
    if (sec < 60) return '${sec}s';
    if (sec < 3600) return '${(sec / 60).round()}m';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Elapsed duration as `HH:mm` for compact “fact” line (not wall-clock time).
  static String _trackedDurationAsHhMm(int sec) {
    final s = sec.clamp(0, 8640000);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
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
    final categoryTrail = localizeCategoryBreadcrumbPath(
      DatabaseService.instance.getCategoryPath(task.categoryId).trim(),
      currentLocale.value,
    );
    final categoryTone =
        DatabaseService.instance.getCategoryColor(task.categoryId);
    final bg = selectMode && isSelected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final borderColor = highlightAsRunning ? scheme.primary : Colors.transparent;
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
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: highlightAsRunning ? 2 : 0),
      ),
      child: InkWell(
        onTap: onBodyTap,
        onLongPress: onLongPress,
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
                  child: selectMode
                      ? Checkbox(
                          value: isSelected,
                          tristate: false,
                          onChanged: (_) => onBodyTap(),
                        )
                      : Checkbox(
                          value: displayIsDone,
                          tristate: false,
                          onChanged: toggleDoneEnabled
                              ? (_) => onToggleDone()
                              : null,
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2, right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (categoryTrail.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              categoryTrail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    height: 1.2,
                                    letterSpacing: 0.12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        categoryTone.withValues(alpha: 0.88),
                                  ),
                            ),
                          ),
                        Text(
                          task.title,
                          textAlign: TextAlign.start,
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
                        if ((planEstimatedSeconds ?? 0) > 0) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: planTrackedSeconds <= planEstimatedSeconds!
                                  ? planTrackedSeconds / planEstimatedSeconds!
                                  : 1.0,
                              backgroundColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.65),
                              color: planTrackedSeconds > planEstimatedSeconds!
                                  ? scheme.error
                                  : scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            () {
                              final est = planEstimatedSeconds!;
                              final a = planTrackedSeconds;
                              final pct =
                                  est > 0 ? ((a * 100) / est).round() : 0;
                              return '${_shortDur(a)} / ${_shortDur(est)} ($pct%)';
                            }(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  height: 1.1,
                                  color: planTrackedSeconds >
                                          planEstimatedSeconds!
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                          ),
                        ] else if (planTrackedSeconds > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            t(currentLocale.value, 'plan_card_fact_time')
                                .replaceFirst(
                              '%s',
                              _trackedDurationAsHhMm(planTrackedSeconds),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  height: 1.1,
                                  color: scheme.primary
                                      .withValues(alpha: 0.92),
                                ),
                          ),
                        ],
                        if (task.tags.any((t) => t.rendersAsChip)) ...[
                          const SizedBox(height: 6),
                          StreamBuilder<UserSettings>(
                            stream: DatabaseService
                                .instance.userSettingsStream,
                            initialData:
                                DatabaseService.instance.settings,
                            builder: (context, snap) {
                              final mode = snap.data?.tagDisplayMode ??
                                  CategoryDisplayMode.letterChip;
                              return Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment:
                                    WrapCrossAlignment.start,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final tag in task.tags)
                                    if (tag.rendersAsChip)
                                      CategoryChip(
                                        mode: mode,
                                        label: tag.name
                                                .trim()
                                                .isNotEmpty
                                            ? tag.name.trim()
                                            : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                                        color: parseTagHexColor(
                                                tag.color) ??
                                            scheme.primary,
                                        icon:
                                            iconForTagKey(tag.icon),
                                        compactGlyphLayout: true,
                                      ),
                                ],
                              );
                            },
                          ),
                        ],
                        selectMode
                            ? Text(
                                _subtitle(task),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: scheme.onSurfaceVariant),
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onDateTap,
                                child: Text(
                                  _subtitle(task),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
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
