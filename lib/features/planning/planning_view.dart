// ---------------------------------------------------------------------------
// PLANNING FEATURE — Day planning & task list tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/global_app_header.dart';
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
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';

enum _PlanSortMode { category, time, tags, custom }

/// Order matches [SegmentedButton] segments (persisted as [DatabaseService.kPrefsPlanActiveTab]).
int _planSortModeToPersistedIndex(_PlanSortMode m) {
  switch (m) {
    case _PlanSortMode.category:
      return 0;
    case _PlanSortMode.time:
      return 1;
    case _PlanSortMode.tags:
      return 2;
    case _PlanSortMode.custom:
      return 3;
  }
}

_PlanSortMode _planSortModeFromPersistedIndex(int i) {
  switch (i) {
    case 0:
      return _PlanSortMode.category;
    case 1:
      return _PlanSortMode.time;
    case 2:
      return _PlanSortMode.tags;
    default:
      return _PlanSortMode.custom;
  }
}

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
  })
  onStartRecordFromTask;
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
    final daysOffset = _dateOnly(
      widget.selectedDate,
    ).difference(_anchorDate).inDays;
    _visiblePageIndex = initialPage + daysOffset;
    _controller = PageController(initialPage: _visiblePageIndex);
  }

  @override
  void didUpdateWidget(covariant PlanningSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      final daysOffset = _dateOnly(
        widget.selectedDate,
      ).difference(_anchorDate).inDays;
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
    if (targetIndex >= 0 &&
        targetIndex < totalPageCount &&
        _controller.hasClients) {
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
        body: AppErrorState(message: t(currentLocale.value, 'no_data_found')),
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
  })
  onStartRecordFromTask;
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

class _PlanningPageState extends State<PlanningPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _quickAddFocus = FocusNode();
  final Set<String> _selectedPlanKeys = {};
  final List<PlanningTask> _optimisticTasks = [];
  bool _planQuickAddInFlight = false;

  /// Last server list for this day from [planningStream] (avoids `nextPlanningOrderForDate` network on quick-add).
  List<PlanningTask> _latestPlanningDayTasks = const [];
  final Map<String, bool> _planDoneOverride = {};
  Stream<List<PlanningTask>>? _planningStream;
  List<PlanningTask>? _dragOrder;
  bool _planSelectMode = false;
  _PlanSortMode _sortMode = _PlanSortMode.custom;
  int _timelineHourStart = 0;
  int _timelineHourEnd = 23;

  /// Hour-grid day timeline scroll (edge auto-scroll while dragging a plan).
  final ScrollController _hourGridScrollController = ScrollController();

  static const double _kTimelineHourHeightBasePx = 80;
  static const double _kTimelineHourHeightMaxPx = 360;
  static const double _kTimelineMinReadableCardPx = 60;
  static const double _kTimelineRailWidthPx = 48;
  static const double _kTimelineMinBlockHeightPx = 56;

  /// Resolved per canvas build from shortest scheduled duration (readability over fixed scale).
  double _timelineHourHeightPx = _kTimelineHourHeightBasePx;
  static const int _kTimelineDefaultBlockMinutes = 30;

  /// Active vertical timeline drag (Time mode); local preview only until drop.
  String? _timelineVerticalDragPlanKey;
  double _timelineVerticalDragDeltaPx = 0;
  double _timelineVerticalDragOriginTopPx = 0;
  int _timelineVerticalDragDurationMin = _kTimelineDefaultBlockMinutes;
  PlanningTask? _timelineVerticalDragTask;
  bool _timelineVerticalDragHadEnd = false;
  bool _timelineScrollLocked = false;
  String? _timelineVerticalDragTimeLabel;

  /// Midpoint insert-before/after target while dragging over another card.
  String? _timelineDragInsertTargetKey;
  bool _timelineDragInsertBefore = false;
  double? _timelineDragInsertMarkerTopPx;

  /// Top/bottom edge resize (Time mode); local preview until release.
  String? _timelineResizePlanKey;
  _TimelineResizeEdge? _timelineResizeEdge;
  double _timelineResizeOriginTopPx = 0;
  double _timelineResizeOriginHeightPx = 0;
  int _timelineResizeOriginStartMin = 0;
  int _timelineResizeOriginEndMin = 0;
  double _timelineResizePreviewTopPx = 0;
  double _timelineResizePreviewHeightPx = 0;
  PlanningTask? _timelineResizeTask;
  String? _timelineResizeTimeLabel;

  static const double _kTimelineResizeHandlePx = 12;

  late final Ticker _hourGridEdgeScrollTicker;
  double _hourGridScrollVelocityPxPerSec = 0;
  Duration? _hourGridTickerElapsedLast;

  static const double _kShellBulkBarReservePx = 56;

  /// Pixels per second while the drag pointer sits in the top/bottom 10% bands.
  static const double _kHourGridEdgeScrollSpeedPxPerSec = 400;

  StreamSubscription<void>? _planningTimeSub;
  StreamSubscription<void>? _tagsCatalogSub;
  String? _activeRecordingTitleNorm;

  static const int _kUntaggedPlanGroupId = -1;

  /// Persisted order of tag ids in the quick-add strip, including [_kUntaggedPlanGroupId] for “No Tags”.
  static const String _prefsKeyQuickBarTagOrder =
      'planning_quick_bar_tag_ids_v1';

  /// Local-only prefs for the synthetic “No Tags” chip (not PocketBase).
  static const String _prefsKeyNoTagsVisible = 'no_tags_visible';
  static const String _prefsKeyNoTagsColor = 'no_tags_color';
  static const String _defaultNoTagsColorHex = '#9E9E9E';
  /// Tags for quick-add row; reloaded after returning from [TagSettingsHub].
  List<Tag> _quickAddAvailableTags = [];
  bool _quickAddTagsLoading = true;
  bool _noTagsChipVisible = true;
  String _noTagsColorHex = _defaultNoTagsColorHex;

  /// M2M tags selected before submitting the inline task.
  List<Tag> _creationSelectedTags = [];

  DateTime get _today => DatabaseService.instance.getTimelineDeviceLocalToday();

  int _nextPlanOrderForQuickAdd() {
    var m = -1;
    for (final t in _latestPlanningDayTasks) {
      if (t.order > m) m = t.order;
    }
    for (final t in _optimisticTasks) {
      if (t.order > m) m = t.order;
    }
    return m + 1;
  }

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
    final initial =
        _planDateFromTaskDateKey(task.dateKey) ?? widget.selectedDate ?? _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.utc(initial.year, initial.month, initial.day),
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2035),
      initialEntryMode: appDatePickerEntryMode(),
    );
    if (picked == null || !mounted) return;
    var h = 9;
    var min = 0;
    if (task.startTime != null) {
      h = task.startTime!.hour;
      min = task.startTime!.minute;
    }
    final wallStart = DateTime(picked.year, picked.month, picked.day, h, min);
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
    final anchorShort = DatabaseService.instance.planningAuditAnchorDateKey(
      task,
    );
    const minKeyLen = 10;
    final persistInitial = anchorShort.length >= minKeyLen
        ? anchorShort
        : DatabaseService.instance.planningWallScheduleDateKey(task);
    final initForPatch = persistInitial.length >= minKeyLen
        ? persistInitial
        : newKey;
    final postponed =
        !task.isDone &&
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
      planInitialDateKey: initForPatch.length >= minKeyLen
          ? initForPatch
          : null,
      planIsPostponed: postponed,
    );
    if (!mounted) return;
    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      DatabaseService.instance.notifyPlanningRefresh();
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
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
    final persisted = DatabaseService.instance.getPlanActiveTabIndexOrNull();
    if (persisted != null) {
      _sortMode = _planSortModeFromPersistedIndex(persisted);
    }
    WidgetsBinding.instance.addObserver(this);
    _planningStream = _createPlanningStream();
    _activeRecordingTitleNorm = DatabaseService
        .instance
        .cachedPrimaryRunningTitle
        ?.trim()
        .toLowerCase();
    _planningTimeSub = DatabaseService.instance.timeUpdates.listen((_) {
      if (!mounted) return;
      final t = DatabaseService.instance.cachedPrimaryRunningTitle
          ?.trim()
          .toLowerCase();
      if (t != _activeRecordingTitleNorm) {
        setState(() => _activeRecordingTitleNorm = t);
      }
    });
    _tagsCatalogSub = DatabaseService.instance.tagsCatalogUpdated.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    unawaited(_loadPlanningTimelineBounds());
    unawaited(_reloadQuickAddTags());
    _hourGridEdgeScrollTicker = createTicker(_onHourGridEdgeScrollTick);
  }

  Tag _syntheticNoTagsTag() {
    final loc = currentLocale.value;
    return Tag(
      tagId: _kUntaggedPlanGroupId,
      name: t(loc, 'plan_filter_no_tags'),
      color: _noTagsColorHex,
      sortOrder: 0,
      isSynced: true,
    );
  }

  List<Tag> _mergeQuickBarTagsFromServer(
    List<Tag> serverTags,
    List<int>? savedOrder,
  ) {
    final synthetic = _syntheticNoTagsTag();
    if (savedOrder == null || savedOrder.isEmpty) {
      return [...serverTags, synthetic];
    }
    final byId = {for (final t in serverTags) t.tagId: t};
    final out = <Tag>[];
    final usedServer = <int>{};
    var placedSynthetic = false;
    for (final id in savedOrder) {
      if (id == 0) continue;
      if (id == _kUntaggedPlanGroupId) {
        if (!placedSynthetic) {
          out.add(synthetic);
          placedSynthetic = true;
        }
        continue;
      }
      final t = byId[id];
      if (t != null) {
        out.add(t);
        usedServer.add(id);
      }
    }
    for (final t in serverTags) {
      if (!usedServer.contains(t.tagId)) {
        out.add(t);
      }
    }
    if (!placedSynthetic) {
      out.add(synthetic);
    }
    return out;
  }

  Future<void> _persistQuickBarTagIdOrderPrefs(List<Tag> ordered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyQuickBarTagOrder,
        jsonEncode(ordered.map((t) => t.tagId).toList()),
      );
    } catch (_) {}
  }

  Future<void> _reloadQuickAddTags() async {
    if (!mounted) return;
    setState(() => _quickAddTagsLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final visible = prefs.getBool(_prefsKeyNoTagsVisible) ?? true;
    final cr = prefs.getString(_prefsKeyNoTagsColor)?.trim();
    final colorHex =
        (cr != null &&
            cr.startsWith('#') &&
            cr.length >= 7 &&
            parseTagHexColor(cr) != null)
        ? cr
        : _defaultNoTagsColorHex;

    final list = await DatabaseService.instance.fetchTagsForCurrentUser(
      scope: TagCatalogScope.plan,
    );
    List<int>? order;
    try {
      final raw = prefs.getString(_prefsKeyQuickBarTagOrder);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          order = decoded
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .where((id) => id != 0)
              .toList();
        }
      }
    } catch (_) {}
    if (!mounted) return;
    _noTagsChipVisible = visible;
    _noTagsColorHex = colorHex;
    var merged = _mergeQuickBarTagsFromServer(list, order);
    if (!visible) {
      merged = merged.where((t) => t.tagId != _kUntaggedPlanGroupId).toList();
    }
    setState(() {
      _quickAddAvailableTags = merged;
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
    if (tag.tagId == _kUntaggedPlanGroupId) return;
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
    unawaited(_persistQuickBarTagIdOrderPrefs(withSort));
    unawaited(_persistPlanningQuickBarSortOrder(previous, withSort));
  }

  Future<void> _persistPlanningQuickBarSortOrder(
    List<Tag> previousUiOrder,
    List<Tag> ordered,
  ) async {
    final persistable = ordered
        .where((t) => t.tagId != _kUntaggedPlanGroupId)
        .toList();
    final withSort = <Tag>[
      for (var i = 0; i < persistable.length; i++)
        persistable[i].copyWith(sortOrder: i),
    ];
    final ok = await DatabaseService.instance
        .persistTagsSortOrderForCurrentUser(withSort);
    if (!mounted) return;
    if (ok) {
      await _persistQuickBarTagIdOrderPrefs(ordered);
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
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: _openTagManagerFromQuickAdd,
          child: Text(t(loc, 'plan_quick_add_no_tags')),
        ),
      );
    }
    final canReorder = _quickAddAvailableTags.length >= 2;
    return TagQuickPickStrip(
      tags: _quickAddAvailableTags,
      selected: _creationSelectedTags,
      onToggle: _toggleCreationTag,
      fallbackColor: scheme.primary,
      variant: CategoryChipVariant.largePicker,
      externalSelectionRing: true,
      onReorder: canReorder ? _onPlanningQuickBarReorder : null,
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

  String _hhmmFromTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _timeOfDayFromHhmm(String? raw) {
    final sanitized = DatabaseService.instance.sanitizeDefaultPlanTime(raw);
    if (sanitized == null) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.parse(sanitized.substring(0, 2)),
      minute: int.parse(sanitized.substring(3, 5)),
    );
  }

  Future<void> _setCategoryDefaultPlanTime(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    final current =
        DatabaseService.instance
            .getCategoryRuleById(categoryId)
            ?.defaultPlanTime ??
        DatabaseService.instance.effectiveDefaultPlanTimeForCategory(
          categoryId,
        );
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromHhmm(current),
      initialEntryMode: appTimePickerEntryMode(),
    );
    if (picked == null || !mounted) return;
    final ok = await DatabaseService.instance.updateCategoryDefaultPlanTime(
      categoryId,
      _hhmmFromTimeOfDay(picked),
    );
    if (!mounted) return;
    if (!ok.ok) {
      AppSnack.failed();
      return;
    }
    setState(() {});
    modalSetState?.call(() {});
  }

  Future<void> _clearCategoryDefaultPlanTime(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    final ok = await DatabaseService.instance.updateCategoryDefaultPlanTime(
      categoryId,
      null,
    );
    if (!mounted) return;
    if (!ok.ok) {
      AppSnack.failed();
      return;
    }
    setState(() {});
    modalSetState?.call(() {});
  }

  void _showDefaultPlanTimesSheet() {
    int? selectedCategoryId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final loc = currentLocale.value;
            final db = DatabaseService.instance;
            final pairs = db.allCategoryIdPathPairs
                .where((p) => p.id != CategoryRule.uncategorizedSyntheticId)
                .toList();
            final configuredPairs = pairs.where((p) {
              final rule = db.getCategoryRuleById(p.id);
              return db.sanitizeDefaultPlanTime(rule?.defaultPlanTime) != null;
            }).toList();
            ({int id, String path})? selectedPair;
            for (final p in pairs) {
              if (p.id == selectedCategoryId) {
                selectedPair = p;
                break;
              }
            }
            final selectedRule = selectedCategoryId == null
                ? null
                : db.getCategoryRuleById(selectedCategoryId!);
            final selectedOwn = db.sanitizeDefaultPlanTime(
              selectedRule?.defaultPlanTime,
            );
            final selectedEffective = selectedCategoryId == null
                ? null
                : db.effectiveDefaultPlanTimeForCategory(selectedCategoryId!);
            String statusText({
              required String? own,
              required String? effective,
            }) {
              if (own != null) {
                return t(loc, 'plan_default_time_own').replaceFirst('%s', own);
              }
              if (effective != null) {
                return t(
                  loc,
                  'plan_default_time_inherited',
                ).replaceFirst('%s', effective);
              }
              return t(loc, 'plan_default_time_none');
            }

            Future<void> pickCategory() async {
              final picked = await showSearch<_DefaultPlanCategoryOption?>(
                context: context,
                delegate: _DefaultPlanCategorySearchDelegate(
                  loc: loc,
                  options: [
                    for (final p in pairs)
                      _DefaultPlanCategoryOption(id: p.id, path: p.path),
                  ],
                ),
              );
              if (picked == null || !context.mounted) return;
              setModalState(() => selectedCategoryId = picked.id);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t(loc, 'plan_default_times_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pairs.isEmpty
                          ? null
                          : () => unawaited(pickCategory()),
                      icon: const Icon(Icons.search_rounded),
                      label: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          selectedPair?.path ??
                              t(loc, 'plan_default_time_select_category'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedPair != null)
                      Builder(
                        builder: (context) {
                          final pair = selectedPair!;
                          return Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    pair.path,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    statusText(
                                      own: selectedOwn,
                                      effective: selectedEffective,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      AppButton.secondary(
                                        label: t(loc, 'plan_default_time_set'),
                                        onPressed: () => unawaited(
                                          _setCategoryDefaultPlanTime(
                                            pair.id,
                                            setModalState,
                                          ),
                                        ),
                                      ),
                                      AppButton.ghost(
                                        label: t(
                                          loc,
                                          'plan_default_time_clear',
                                        ),
                                        onPressed: selectedOwn == null
                                            ? null
                                            : () => unawaited(
                                                _clearCategoryDefaultPlanTime(
                                                  pair.id,
                                                  setModalState,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    Text(
                      t(loc, 'plan_default_time_configured_categories'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                      ),
                      child: configuredPairs.isEmpty
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(t(loc, 'plan_default_time_none')),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: configuredPairs.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final pair = configuredPairs[i];
                                final own = db.sanitizeDefaultPlanTime(
                                  db
                                      .getCategoryRuleById(pair.id)
                                      ?.defaultPlanTime,
                                );
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    pair.path,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(own ?? ''),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: t(
                                          loc,
                                          'plan_default_time_set',
                                        ),
                                        icon: const Icon(Icons.edit_rounded),
                                        onPressed: () {
                                          setModalState(
                                            () => selectedCategoryId = pair.id,
                                          );
                                          unawaited(
                                            _setCategoryDefaultPlanTime(
                                              pair.id,
                                              setModalState,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: t(
                                          loc,
                                          'plan_default_time_clear',
                                        ),
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () => unawaited(
                                          _clearCategoryDefaultPlanTime(
                                            pair.id,
                                            setModalState,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => setModalState(
                                    () => selectedCategoryId = pair.id,
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    // TODO(F2C): remove sanity marker after web + APK verification.
                    Text(
                      'F2C selector UI',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                  _PlanningNoTagsSettingsBlock(
                    initialVisible: _noTagsChipVisible,
                    initialColorHex: _noTagsColorHex,
                    onApply: (visible, colorHex) async {
                      final p = await SharedPreferences.getInstance();
                      await p.setBool(_prefsKeyNoTagsVisible, visible);
                      await p.setString(_prefsKeyNoTagsColor, colorHex);
                      if (!mounted) return;
                      setState(() {
                        _noTagsChipVisible = visible;
                        _noTagsColorHex = colorHex;
                      });
                      await _reloadQuickAddTags();
                    },
                  ),
                  const Divider(height: 1),
                  const _PlanRecordLinkSuggestionSettingsBlock(),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(t(loc, 'plan_default_times_title')),
                    subtitle: Text(
                      t(loc, 'plan_default_times_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _showDefaultPlanTimesSheet();
                    },
                  ),
                  const Divider(height: 1),
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
      _syncPlanningShellFabBulkReserve();
    }
  }

  @override
  void dispose() {
    _planningTimeSub?.cancel();
    _tagsCatalogSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(DatabaseService.instance.flushPlanningOrderSyncNow());
    _stopHourGridEdgeScroll();
    _hourGridEdgeScrollTicker.dispose();
    _hourGridScrollController.dispose();
    _textController.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  void _onHourGridEdgeScrollTick(Duration elapsed) {
    if (!mounted) {
      return;
    }
    if (!_hourGridScrollController.hasClients) {
      return;
    }
    final v = _hourGridScrollVelocityPxPerSec;
    if (v == 0) {
      return;
    }
    final last = _hourGridTickerElapsedLast;
    _hourGridTickerElapsedLast = elapsed;
    if (last == null) {
      return;
    }
    final dtSeconds = (elapsed - last).inMicroseconds / 1000000.0;
    if (dtSeconds <= 0) {
      return;
    }
    final c = _hourGridScrollController;
    final deltaPx = v * dtSeconds;
    final next = (c.offset + deltaPx).clamp(0.0, c.position.maxScrollExtent);
    c.jumpTo(next.toDouble());
  }

  void _ensureHourGridEdgeTickerRunning() {
    if (!_hourGridEdgeScrollTicker.isActive) {
      _hourGridTickerElapsedLast = null;
      _hourGridEdgeScrollTicker.start();
    }
  }

  void _stopHourGridEdgeScroll() {
    _hourGridScrollVelocityPxPerSec = 0;
    _hourGridTickerElapsedLast = null;
    if (_hourGridEdgeScrollTicker.isActive) {
      _hourGridEdgeScrollTicker.stop();
    }
  }

  /// While dragging in the hour grid, set scroll velocity from global Y bands
  /// (top/bottom 10% of viewport); motion is applied in [_onHourGridEdgeScrollTick].
  void _handleHourGridDragUpdateForEdgeScroll(double globalDy) {
    if (_sortMode != _PlanSortMode.time) {
      return;
    }
    final viewH = MediaQuery.sizeOf(context).height;
    if (viewH <= 1) {
      return;
    }
    final topBand = viewH * 0.1;
    final bottomBand = viewH * 0.9;
    if (globalDy < topBand) {
      _hourGridScrollVelocityPxPerSec = -_kHourGridEdgeScrollSpeedPxPerSec;
      _ensureHourGridEdgeTickerRunning();
    } else if (globalDy > bottomBand) {
      _hourGridScrollVelocityPxPerSec = _kHourGridEdgeScrollSpeedPxPerSec;
      _ensureHourGridEdgeTickerRunning();
    } else {
      _stopHourGridEdgeScroll();
    }
  }

  static String? _planBusinessUuidForMerge(PlanningTask t) {
    final row = t.planRowId?.trim() ?? '';
    if (row.isNotEmpty) {
      if (row.startsWith('optimistic-')) {
        final id = row.substring('optimistic-'.length).trim();
        return id.isEmpty ? null : id;
      }
      if (!row.startsWith('virt-')) return row;
    }
    final pr = t.pocketRecordId?.trim() ?? '';
    if (pr.startsWith('optimistic-')) {
      final id = pr.substring('optimistic-'.length).trim();
      return id.isEmpty ? null : id;
    }
    return null;
  }

  List<PlanningTask> _mergeWithOptimistic(List<PlanningTask> server) {
    final pending = _optimisticTasks
        .where(
          (o) => !server.any((s) {
            final oBiz = _planBusinessUuidForMerge(o);
            final sBiz = _planBusinessUuidForMerge(s);
            if (oBiz != null &&
                sBiz != null &&
                oBiz.isNotEmpty &&
                oBiz == sBiz) {
              return true;
            }
            return s.title.trim() == o.title.trim() && s.dateKey == o.dateKey;
          }),
        )
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

  void _syncPlanningShellFabBulkReserve() {
    if (!mounted) {
      return;
    }
    final shell = ShellLayoutScope.read(context, listen: false);
    if (shell.primaryTabIndex != 1) {
      return;
    }
    final next = _selectedPlanKeys.isNotEmpty ? _kShellBulkBarReservePx : 0.0;
    shell.setFabBottomReservePx(next);
  }

  void _exitSelectMode() {
    setState(() {
      _planSelectMode = false;
      _selectedPlanKeys.clear();
    });
    _syncPlanningShellFabBulkReserve();
  }

  void _toggleKeySelection(String key) {
    setState(() {
      if (_selectedPlanKeys.contains(key)) {
        _selectedPlanKeys.remove(key);
      } else {
        _selectedPlanKeys.add(key);
      }
    });
    _syncPlanningShellFabBulkReserve();
  }

  void _clearSelection() {
    setState(() {
      _selectedPlanKeys.clear();
      _planSelectMode = false;
    });
    _syncPlanningShellFabBulkReserve();
  }

  bool _allVisiblePlanTasksSelected(List<PlanningTask> list) {
    if (list.isEmpty) return false;
    for (final t in list) {
      if (!_selectedPlanKeys.contains(_planKey(t))) return false;
    }
    return true;
  }

  void _toggleSelectAllVisiblePlans(List<PlanningTask> list) {
    if (list.isEmpty) return;
    setState(() {
      if (_allVisiblePlanTasksSelected(list)) {
        for (final t in list) {
          _selectedPlanKeys.remove(_planKey(t));
        }
      } else {
        for (final t in list) {
          _selectedPlanKeys.add(_planKey(t));
        }
      }
    });
    _syncPlanningShellFabBulkReserve();
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
    final sameDay =
        result.targetDate.year == refDay.year &&
        result.targetDate.month == refDay.month &&
        result.targetDate.day == refDay.day;
    if (sameDay && !result.applyTargetTime) {
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
      final anchorShort = DatabaseService.instance.planningAuditAnchorDateKey(
        match,
      );
      const minKeyLen = 10;
      final persistInitial = anchorShort.length >= minKeyLen
          ? anchorShort
          : DatabaseService.instance.planningWallScheduleDateKey(match);
      final initForPatch = persistInitial.length >= minKeyLen
          ? persistInitial
          : newKey;
      final postponed =
          !match.isDone &&
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
        clearEnd: wall.end == null,
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
          clearEnd: wall.end == null,
          initialDateKey: initForPatch,
          isPostponed: postponed,
        ),
      );
    }

    if (patches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
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
    _syncPlanningShellFabBulkReserve();
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
      _syncPlanningShellFabBulkReserve();
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
    final categoryId =
        widget.selectedCategoryId ??
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
            _syncPlanningShellFabBulkReserve();
          },
          onDelete: () {
            dismiss();
            unawaited(
              DatabaseService.instance.deletePlanningTask(
                task.planRowIdForBackend,
              ),
            );
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
    DateTime? startStored;
    DateTime? endStored;

    title = SmartInputParser.preservedTitleFromRaw(raw);
    if (title.isEmpty) return;

    if (range != null) {
      startStored = DatabaseService.instance.displayTimeToUtc(
        range.startWallOn(wallDay),
      );
      endStored = DatabaseService.instance.displayTimeToUtc(
        range.endWallOn(wallDay),
      );
    } else {
      parsed = SmartInputParser.parseTitleForScheduledTime(raw);
      startStored = parsed != null
          ? DatabaseService.instance.displayTimeToUtc(
              parsed.wallDateTimeOn(wallDay),
            )
          : null;
      endStored = null;
    }

    final match = DatabaseService.instance.identifyCategory(title);
    final categoryId =
        match?.id ??
        widget.selectedCategoryId ??
        DatabaseService.instance.defaultCategoryId ??
        (DatabaseService.instance.rules.isNotEmpty
            ? DatabaseService.instance.rules.first.id
            : 0);
    if (startStored == null && range == null && parsed == null) {
      final defaultWall = DatabaseService.instance
          .wallDateTimeForCategoryDefaultPlanTime(categoryId, wallDay);
      if (defaultWall != null) {
        startStored = DatabaseService.instance.displayTimeToUtc(defaultWall);
      }
    }
    var nextOrder = _nextPlanOrderForQuickAdd();
    final clientPlanId = DatabaseService.newClientUuid();
    final tagsForCreate = List<Tag>.from(_creationSelectedTags);
    if (_planQuickAddInFlight) return;
    _planQuickAddInFlight = true;
    unawaited(() async {
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
            parentPlanId: null,
            tags: tagsForCreate,
            isSynced: false,
          ),
          clientPlanId: clientPlanId,
        );
        if (!mounted) return;
        if (ok) {
          _textController.clear();
          setState(() {
            _creationSelectedTags = [];
          });
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PLAN_ADD_UI: $e');
        }
      } finally {
        _planQuickAddInFlight = false;
      }
    }());
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

    var nextOrder = _nextPlanOrderForQuickAdd();

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

      final startStored = DatabaseService.instance.displayTimeToUtc(startWall);
      final endStored = DatabaseService.instance.displayTimeToUtc(endWall);

      final aiCategoryStr = m['category']?.toString().trim();
      final fromAiId = DatabaseService.instance
          .resolveCategoryIdFromSmartPlanLabel(aiCategoryStr);
      final fromTitle = DatabaseService.instance.identifyCategory(title);
      final categoryId =
          fromAiId ??
          fromTitle?.id ??
          widget.selectedCategoryId ??
          DatabaseService.instance.defaultCategoryId ??
          (DatabaseService.instance.rules.isNotEmpty
              ? DatabaseService.instance.rules.first.id
              : 0);

      final order = nextOrder + i;
      final clientPlanId = DatabaseService.newClientUuid();

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
            parentPlanId: null,
            tags: <Tag>[],
            isSynced: false,
          ),
          clientPlanId: clientPlanId,
        );
        if (!mounted) return created;
        if (ok) {
          created++;
        }
      } catch (_) {}
    }
    return created;
  }

  void _openSmartPlanSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SmartPlanSheet(onCommit: _injectSmartPlanTasks),
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
      debugPrint('UI ERROR: $e');
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

  List<PlanningTask> _tasksForTimeMode(
    List<PlanningTask> tasks,
    int dayStartHour,
  ) {
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
    List<PlanningTask> tasks,
  ) {
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
    final raw = _quickAddAvailableTags.isNotEmpty
        ? _quickAddAvailableTags
        : List<Tag>.from(DatabaseService.instance.cachedUserTagsCatalog);
    if (raw.any((t) => t.tagId == _kUntaggedPlanGroupId)) {
      return raw;
    }
    return [...raw, _syntheticNoTagsTag()];
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

  /// Group column order: follow [masterBarOrder] (including synthetic “No Tags” at [-1]),
  /// then orphan tag ids (by id). Untagged tasks appear where [-1] sits in the bar order.
  List<int> _groupIdsInMasterBarSequence(
    Map<int, List<PlanningTask>> groups,
    List<Tag> masterBarOrder,
  ) {
    final seen = <int>{};
    final out = <int>[];
    for (final t in masterBarOrder) {
      final id = t.tagId;
      if (id == 0) continue;
      if (id == _kUntaggedPlanGroupId) {
        final bucket = groups[_kUntaggedPlanGroupId];
        if (bucket != null &&
            bucket.isNotEmpty &&
            !seen.contains(_kUntaggedPlanGroupId)) {
          seen.add(_kUntaggedPlanGroupId);
          out.add(_kUntaggedPlanGroupId);
        }
        continue;
      }
      final bucket = groups[id];
      if (bucket != null && bucket.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        out.add(id);
      }
    }
    final orphan =
        groups.keys
            .where((k) => k != _kUntaggedPlanGroupId && !seen.contains(k))
            .toList()
          ..sort();
    out.addAll(orphan);
    if (!seen.contains(_kUntaggedPlanGroupId)) {
      final untagged = groups[_kUntaggedPlanGroupId];
      if (untagged != null && untagged.isNotEmpty) {
        out.add(_kUntaggedPlanGroupId);
      }
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
    bool timelineBlock = false,
    bool timelineInteracting = false,
    double timelineBlockHeightPx = _kTimelineMinBlockHeightPx,
    int timelineDurationMin = _kTimelineDefaultBlockMinutes,
    bool timelineScheduleConflict = false,
  }) {
    final pbId = DatabaseService.pocketRelationIdOrNull(task.pocketRecordId);
    final tracked = pbId != null ? (planActualByPbId[pbId] ?? 0) : 0;
    final estimate = PlanServiceExtension.planningWallEstimateSeconds(task);
    return _PlanningTaskCard(
      task: task,
      planTrackedSeconds: tracked,
      planEstimatedSeconds: estimate,
      displayIsDone: displayDone,
      selectMode: _planSelectMode,
      isSelected: isSelected,
      highlightAsRunning: highlightAsRunning,
      timelineBlock: timelineBlock,
      timelineInteracting: timelineInteracting,
      timelineBlockHeightPx: timelineBlockHeightPx,
      timelineDurationMin: timelineDurationMin,
      timelineScheduleConflict: timelineScheduleConflict,
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
              _syncPlanningShellFabBulkReserve();
            },
      onPlay: () async {
        final dateKeyForRecord = task.startTime != null
            ? task.dateKey
            : DatabaseService.instance.getTimelineDeviceLocalTodayDateKey();
        await widget.onStartRecordFromTask(
          task.title,
          task.categoryId,
          dateKeyForRecord,
          sourcePlanPocketRecordId: DatabaseService.pocketRelationIdOrNull(
            task.pocketRecordId,
          ),
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

  /// Wall minutes from [rangeStart] o'clock on the visible day timeline.
  double _timelineMinutesFromRangeStart(
    DateTime wall,
    int rangeStart,
    int rangeEnd,
  ) {
    final h = wall.hour.clamp(0, 23);
    final m = wall.minute.clamp(0, 59);
    if (rangeStart <= rangeEnd) {
      return ((h - rangeStart) * 60 + m).toDouble();
    }
    if (h >= rangeStart) {
      return ((h - rangeStart) * 60 + m).toDouble();
    }
    if (h <= rangeEnd) {
      return ((24 - rangeStart + h) * 60 + m).toDouble();
    }
    return 0;
  }

  int _timelineBlockDurationMinutes(PlanningTask task) {
    final a = task.startTime;
    final b = task.endDateTime;
    if (a != null && b != null) {
      final sec = b.difference(a).inSeconds;
      if (sec > 0) return (sec / 60).ceil().clamp(5, 24 * 60);
    }
    return _kTimelineDefaultBlockMinutes;
  }

  double _timelineCanvasHeightPx(int rangeStart, int rangeEnd) {
    final hours = PlanningSheetTimelinePrefs.visibleHoursOrdered(
      rangeStart,
      rangeEnd,
    );
    return hours.length * _timelineHourHeightPx;
  }

  double _resolveTimelineHourHeightPx(List<PlanningTask> scheduled) {
    var shortestMin = 30.0;
    for (final t in scheduled) {
      final dur = _timelineBlockDurationMinutes(t).toDouble();
      if (dur > 0 && dur < shortestMin) shortestMin = dur;
    }
    final needed = _kTimelineMinReadableCardPx * 60 / shortestMin;
    return needed.clamp(_kTimelineHourHeightBasePx, _kTimelineHourHeightMaxPx);
  }

  List<_TimelineBlockLayout> _timelineBlockLayouts(
    List<PlanningTask> scheduled,
    int rangeStart,
    int rangeEnd,
  ) {
    final pxPerMin = _timelinePxPerMinute;
    const gapPx = 2.0;
    final spans =
        <({
          PlanningTask task,
          double startMin,
          double endMin,
        })>[];
    for (final t in scheduled) {
      final st = t.startTime;
      if (st == null) continue;
      final startMin = _timelineMinutesFromRangeStart(st, rangeStart, rangeEnd);
      final durMin = _timelineBlockDurationMinutes(t).toDouble();
      spans.add((
        task: t,
        startMin: startMin,
        endMin: startMin + durMin,
      ));
    }
    spans.sort((a, b) {
      final c = a.startMin.compareTo(b.startMin);
      if (c != 0) return c;
      return a.endMin.compareTo(b.endMin);
    });

    final layouts = <_TimelineBlockLayout>[];
    var prevVisualBottomPx = 0.0;
    for (var i = 0; i < spans.length; i++) {
      final span = spans[i];
      final timeTopPx = span.startMin * pxPerMin;
      final heightPx = math.max(
        1.0,
        (span.endMin - span.startMin) * pxPerMin,
      );
      final hasScheduleConflict =
          i > 0 && span.startMin < spans[i - 1].endMin - 0.25;
      final visualTopPx = hasScheduleConflict
          ? math.max(timeTopPx, prevVisualBottomPx + gapPx)
          : timeTopPx;
      layouts.add(
        _TimelineBlockLayout(
          task: span.task,
          topPx: visualTopPx,
          heightPx: heightPx,
          column: 0,
          totalColumns: 1,
          hasScheduleConflict: hasScheduleConflict,
        ),
      );
      prevVisualBottomPx = visualTopPx + heightPx;
    }
    return layouts;
  }

  bool _isSelectedPlanningWallDayToday(DateTime planWallDay) {
    final today = _today;
    return planWallDay.year == today.year &&
        planWallDay.month == today.month &&
        planWallDay.day == today.day;
  }

  double? _timelineNowLineTopPx(
    DateTime planWallDay,
    int rangeStart,
    int rangeEnd,
  ) {
    if (!_isSelectedPlanningWallDayToday(planWallDay)) return null;
    final now = DatabaseService.getPlanetaryNow();
    final min = _timelineMinutesFromRangeStart(now, rangeStart, rangeEnd);
    final maxMin = PlanningSheetTimelinePrefs.visibleHoursOrdered(
          rangeStart,
          rangeEnd,
        ).length *
        60;
    if (min < 0 || min > maxMin) return null;
    return min * _timelineHourHeightPx / 60;
  }

  double get _timelinePxPerMinute => _timelineHourHeightPx / 60;

  static const double _kTimelineBlockHorizontalPadPx = 6;

  double _timelineBlockWidth(double canvasW) =>
      math.max(0, canvasW - _kTimelineBlockHorizontalPadPx * 2);

  double _snapTimelineMinutes(double rawMinutes) {
    final snap = PlanningSheetTimelinePrefs.timelineSnapMinutes;
    return (rawMinutes / snap).round() * snap.toDouble();
  }

  bool _planIsTimelineVerticallyDraggable(PlanningTask task) {
    if (_planSelectMode) return false;
    if (task.startTime == null) return false;
    if (task.planRowIdForBackend.startsWith('optimistic-')) return false;
    final rrule = task.rrule?.trim() ?? '';
    if (rrule.isNotEmpty) return false;
    final inst = task.recurrenceInstanceDateKey?.trim() ?? '';
    if (inst.isNotEmpty) return false;
    return true;
  }

  DateTime _wallTimeFromTimelineMinutes(
    double minutesFromRangeStart,
    DateTime planWallDay,
    int rangeStart,
  ) {
    final snapped = _snapTimelineMinutes(minutesFromRangeStart);
    final total = snapped.round().clamp(0, 24 * 60 - 1);
    final hour = (rangeStart + (total ~/ 60)) % 24;
    final minute = total % 60;
    return DateTime(
      planWallDay.year,
      planWallDay.month,
      planWallDay.day,
      hour,
      minute,
    );
  }

  String _formatTimelineWallRangeLabel(DateTime start, DateTime? end) {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (end != null) return '${hhmm(start)} – ${hhmm(end)}';
    return hhmm(start);
  }

  String _formatTimelineResizeLabel(DateTime start, DateTime end) {
    final mins = end.difference(start).inMinutes.clamp(
      PlanningSheetTimelinePrefs.timelineMinDurationMinutes,
      24 * 60,
    );
    return '${_formatTimelineWallRangeLabel(start, end)} · ${_shortTimelineDuration(mins)}';
  }

  String _shortTimelineDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  int _timelineMaxVisibleMinutes(int rangeStart, int rangeEnd) {
    return PlanningSheetTimelinePrefs.visibleHoursOrdered(
          rangeStart,
          rangeEnd,
        ).length *
        60;
  }

  double _timelineMinDurationPx() =>
      PlanningSheetTimelinePrefs.timelineMinDurationMinutes *
      _timelinePxPerMinute;

  ({int startMin, int endMin}) _timelineStartEndMinutesFromTask(
    PlanningTask task,
    int rangeStart,
    int rangeEnd,
  ) {
    final st = task.startTime;
    final startMin = _timelineMinutesFromRangeStart(
      st!,
      rangeStart,
      rangeEnd,
    ).round();
    var endMin = startMin + _timelineBlockDurationMinutes(task);
    final et = task.endDateTime;
    if (et != null) {
      endMin = _timelineMinutesFromRangeStart(et, rangeStart, rangeEnd).round();
    }
    return (startMin: startMin, endMin: endMin);
  }

  void _clearTimelineInteractionState() {
    _timelineVerticalDragPlanKey = null;
    _timelineVerticalDragDeltaPx = 0;
    _timelineVerticalDragTask = null;
    _timelineVerticalDragTimeLabel = null;
    _timelineDragInsertTargetKey = null;
    _timelineDragInsertBefore = false;
    _timelineDragInsertMarkerTopPx = null;
    _timelineResizePlanKey = null;
    _timelineResizeEdge = null;
    _timelineResizeTask = null;
    _timelineResizeTimeLabel = null;
    _timelineScrollLocked = false;
  }

  void _updateTimelineResizeLabel({
    required int startMin,
    required int endMin,
    required DateTime planWallDay,
    required int rangeStart,
  }) {
    final startWall = _wallTimeFromTimelineMinutes(
      startMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    final endWall = _wallTimeFromTimelineMinutes(
      endMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    _timelineResizeTimeLabel = _formatTimelineResizeLabel(startWall, endWall);
  }

  void _beginTimelineResize({
    required _TimelineResizeEdge edge,
    required PlanningTask task,
    required String planKey,
    required double originTopPx,
    required double originHeightPx,
    required int originStartMin,
    required int originEndMin,
    required DateTime planWallDay,
    required int rangeStart,
  }) {
    _clearTimelineInteractionState();
    setState(() {
      _timelineResizePlanKey = planKey;
      _timelineResizeEdge = edge;
      _timelineResizeOriginTopPx = originTopPx;
      _timelineResizeOriginHeightPx = originHeightPx;
      _timelineResizeOriginStartMin = originStartMin;
      _timelineResizeOriginEndMin = originEndMin;
      _timelineResizePreviewTopPx = originTopPx;
      _timelineResizePreviewHeightPx = originHeightPx;
      _timelineResizeTask = task;
      _timelineScrollLocked = true;
      _updateTimelineResizeLabel(
        startMin: originStartMin,
        endMin: originEndMin,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      );
    });
  }

  void _updateTimelineResize({
    required double deltaPx,
    required double globalDy,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
  }) {
    final edge = _timelineResizeEdge;
    if (edge == null) return;
    final minDur = PlanningSheetTimelinePrefs.timelineMinDurationMinutes;
    final maxEndMin = _timelineMaxVisibleMinutes(rangeStart, rangeEnd);
    final pxPerMin = _timelinePxPerMinute;
    final minHeightPx = _timelineMinDurationPx();

    var previewTop = _timelineResizeOriginTopPx;
    var previewHeight = _timelineResizeOriginHeightPx;
    var startMin = _timelineResizeOriginStartMin;
    var endMin = _timelineResizeOriginEndMin;

    if (edge == _TimelineResizeEdge.top) {
      final fixedEndPx =
          _timelineResizeOriginTopPx + _timelineResizeOriginHeightPx;
      previewTop = (_timelineResizeOriginTopPx + deltaPx).clamp(
        0.0,
        fixedEndPx - minHeightPx,
      );
      startMin = _snapTimelineMinutes(previewTop / pxPerMin).round();
      endMin = _timelineResizeOriginEndMin;
      if (endMin - startMin < minDur) {
        startMin = endMin - minDur;
      }
      if (startMin < 0) {
        startMin = 0;
        endMin = math.max(endMin, minDur);
      }
      previewTop = startMin * pxPerMin;
      previewHeight = math.max(
        minHeightPx,
        (endMin - startMin) * pxPerMin,
      );
    } else {
      previewTop = _timelineResizeOriginTopPx;
      startMin = _timelineResizeOriginStartMin;
      final maxHeightPx = math.max(
        minHeightPx,
        (maxEndMin - startMin) * pxPerMin,
      );
      previewHeight = (_timelineResizeOriginHeightPx + deltaPx).clamp(
        minHeightPx,
        maxHeightPx,
      );
      endMin = _snapTimelineMinutes(
        startMin + previewHeight / pxPerMin,
      ).round();
      if (endMin > maxEndMin) endMin = maxEndMin;
      if (endMin - startMin < minDur) endMin = startMin + minDur;
      previewHeight = math.max(
        minHeightPx,
        (endMin - startMin) * pxPerMin,
      );
    }

    setState(() {
      _timelineResizePreviewTopPx = previewTop;
      _timelineResizePreviewHeightPx = previewHeight;
      _updateTimelineResizeLabel(
        startMin: startMin,
        endMin: endMin,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
      );
    });
    _handleHourGridDragUpdateForEdgeScroll(globalDy);
  }

  void _cancelTimelineResize() {
    if (_timelineResizePlanKey == null) return;
    _stopHourGridEdgeScroll();
    setState(_clearTimelineInteractionState);
  }

  void _commitTimelineResize({
    required DateTime planWallDay,
    required int rangeStart,
  }) {
    final task = _timelineResizeTask;
    _stopHourGridEdgeScroll();
    if (task == null || _timelineResizePlanKey == null) {
      _cancelTimelineResize();
      return;
    }
    final startMin = _snapTimelineMinutes(
      _timelineResizePreviewTopPx / _timelinePxPerMinute,
    ).round();
    final endMin = _snapTimelineMinutes(
      (_timelineResizePreviewTopPx + _timelineResizePreviewHeightPx) /
          _timelinePxPerMinute,
    ).round();
    final newStartWall = _wallTimeFromTimelineMinutes(
      startMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    final newEndWall = _wallTimeFromTimelineMinutes(
      endMin.toDouble(),
      planWallDay,
      rangeStart,
    );
    setState(_clearTimelineInteractionState);
    _persistTimelineScheduleChange(
      task: task,
      newStartWall: newStartWall,
      newEndWall: newEndWall,
    );
  }

  void _persistTimelineScheduleChange({
    required PlanningTask task,
    required DateTime newStartWall,
    required DateTime? newEndWall,
  }) {
    final updated = task.copyWith(
      startTime: newStartWall,
      endDateTime: newEndWall,
      clearEnd: newEndWall == null,
    );
    DatabaseService.instance.applyOptimisticPlanningTask(updated);
    DatabaseService.instance.notifyPlanningRefresh();
    if (mounted) setState(() {});
    unawaited(
      DatabaseService.instance.updatePlanningTask(
        task.planRowIdForBackend,
        planBusinessId: task.planRowId,
        startTimeDisplay: newStartWall,
        endDateTimeDisplay: newEndWall,
        clearEnd: newEndWall == null,
        suppressAppSnack: true,
      ),
    );
  }

  List<PlanningTask> _resolveTimelineCollisionsAfterMove({
    required List<PlanningTask> scheduled,
    required int rangeStart,
    required int rangeEnd,
    required DateTime planWallDay,
  }) {
    final sorted = [...scheduled]
      ..sort((a, b) {
        final aStart = _timelineMinutesFromRangeStart(
          a.startTime!,
          rangeStart,
          rangeEnd,
        );
        final bStart = _timelineMinutesFromRangeStart(
          b.startTime!,
          rangeStart,
          rangeEnd,
        );
        return aStart.compareTo(bStart);
      });

    for (var pass = 0; pass < sorted.length; pass++) {
      var changed = false;
      for (var i = 0; i < sorted.length - 1; i++) {
        final a = sorted[i];
        final b = sorted[i + 1];
        final aStart = _timelineMinutesFromRangeStart(
          a.startTime!,
          rangeStart,
          rangeEnd,
        );
        final aDur = _timelineBlockDurationMinutes(a);
        final aEnd = a.endDateTime != null
            ? _timelineMinutesFromRangeStart(
                a.endDateTime!,
                rangeStart,
                rangeEnd,
              )
            : aStart + aDur;
        final bStart = _timelineMinutesFromRangeStart(
          b.startTime!,
          rangeStart,
          rangeEnd,
        );
        if (bStart >= aEnd - 0.25) continue;

        final bDur = _timelineBlockDurationMinutes(b);
        final aEndWall = a.endDateTime ??
            a.startTime!.add(Duration(minutes: aDur));
        final newStartWall = aEndWall;
        final newEndWall = b.endDateTime != null
            ? newStartWall.add(Duration(minutes: bDur))
            : null;
        sorted[i + 1] = b.copyWith(
          startTime: newStartWall,
          endDateTime: newEndWall,
          clearEnd: newEndWall == null,
        );
        changed = true;
      }
      if (!changed) break;
    }
    return sorted;
  }

  void _persistTimelineDragWithCascade({
    required PlanningTask movedTask,
    required DateTime newStartWall,
    required DateTime? newEndWall,
    required List<PlanningTask> scheduledInRange,
    required int rangeStart,
    required int rangeEnd,
    required DateTime planWallDay,
  }) {
    final movedKey = _planKey(movedTask);
    final movedUpdated = movedTask.copyWith(
      startTime: newStartWall,
      endDateTime: newEndWall,
      clearEnd: newEndWall == null,
    );
    final others = scheduledInRange
        .where((t) => _planKey(t) != movedKey)
        .where(_planIsTimelineVerticallyDraggable)
        .toList();
    final resolved = _resolveTimelineCollisionsAfterMove(
      scheduled: [...others, movedUpdated],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      planWallDay: planWallDay,
    );

    for (final task in resolved) {
      final key = _planKey(task);
      final before = key == movedKey
          ? movedTask
          : _timelineTaskByPlanKey(others, key);
      if (before == null) continue;
      if (before.startTime == task.startTime &&
          before.endDateTime == task.endDateTime) {
        continue;
      }
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      unawaited(
        DatabaseService.instance.updatePlanningTask(
          task.planRowIdForBackend,
          planBusinessId: task.planRowId,
          startTimeDisplay: task.startTime,
          endDateTimeDisplay: task.endDateTime,
          clearEnd: task.endDateTime == null,
          suppressAppSnack: true,
        ),
      );
    }
    DatabaseService.instance.notifyPlanningRefresh();
    if (mounted) setState(() {});
  }

  PlanningTask? _timelineTaskByPlanKey(
    List<PlanningTask> scheduled,
    String planKey,
  ) {
    for (final t in scheduled) {
      if (_planKey(t) == planKey) return t;
    }
    return null;
  }

  _TimelineBlockLayout? _timelineLayoutUnderDragCenter({
    required List<_TimelineBlockLayout> layouts,
    required double dragCenterY,
    required String? excludePlanKey,
  }) {
    for (final layout in layouts) {
      if (_planKey(layout.task) == excludePlanKey) continue;
      final bottom = layout.topPx + layout.heightPx;
      if (dragCenterY >= layout.topPx && dragCenterY <= bottom) {
        return layout;
      }
    }
    return null;
  }

  String? _timelineDragLabelForTopPx(
    double topPx,
    DateTime planWallDay,
    int rangeStart,
    int durationMin,
    bool hadEnd,
  ) {
    final startMin = topPx / _timelinePxPerMinute;
    final startWall = _wallTimeFromTimelineMinutes(
      startMin,
      planWallDay,
      rangeStart,
    );
    final endWall = hadEnd
        ? startWall.add(Duration(minutes: durationMin))
        : null;
    return _formatTimelineWallRangeLabel(startWall, endWall);
  }

  void _beginTimelineVerticalDrag({
    required PlanningTask task,
    required String planKey,
    required double originTopPx,
    required int durationMin,
    required bool hadEnd,
    required DateTime planWallDay,
    required int rangeStart,
  }) {
    _clearTimelineInteractionState();
    setState(() {
      _timelineVerticalDragPlanKey = planKey;
      _timelineVerticalDragDeltaPx = 0;
      _timelineVerticalDragOriginTopPx = originTopPx;
      _timelineVerticalDragDurationMin = durationMin;
      _timelineVerticalDragTask = task;
      _timelineVerticalDragHadEnd = hadEnd;
      _timelineScrollLocked = true;
      _timelineVerticalDragTimeLabel = _timelineDragLabelForTopPx(
        originTopPx,
        planWallDay,
        rangeStart,
        durationMin,
        hadEnd,
      );
    });
  }

  void _updateTimelineVerticalDrag({
    required double deltaPx,
    required double globalDy,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required double canvasHeight,
    required List<PlanningTask> scheduledInRange,
  }) {
    final durMin = _timelineVerticalDragDurationMin.toDouble();
    final maxTopPx = math.max(
      0,
      (PlanningSheetTimelinePrefs.visibleHoursOrdered(rangeStart, rangeEnd)
                  .length *
              60 -
          durMin) *
          _timelinePxPerMinute,
    );
    final dragHeightPx = math.max(
      1.0,
      durMin * _timelinePxPerMinute,
    ).toDouble();
    final rawTop = _timelineVerticalDragOriginTopPx + deltaPx;
    final dragCenterY = rawTop + dragHeightPx / 2;
    final layouts = _timelineBlockLayouts(
      scheduledInRange,
      rangeStart,
      rangeEnd,
    );
    final insertTarget = _timelineLayoutUnderDragCenter(
      layouts: layouts,
      dragCenterY: dragCenterY,
      excludePlanKey: _timelineVerticalDragPlanKey,
    );

    double previewTop;
    String? insertKey;
    var insertBefore = false;
    double? markerTop;

    if (insertTarget != null) {
      final mid = insertTarget.topPx + insertTarget.heightPx / 2;
      insertBefore = dragCenterY < mid;
      insertKey = _planKey(insertTarget.task);
      if (insertBefore) {
        previewTop = insertTarget.topPx - dragHeightPx;
        markerTop = insertTarget.topPx.clamp(0.0, canvasHeight);
      } else {
        previewTop = insertTarget.topPx + insertTarget.heightPx;
        markerTop = (insertTarget.topPx + insertTarget.heightPx).clamp(
          0.0,
          canvasHeight,
        );
      }
      previewTop = previewTop.clamp(0.0, maxTopPx).toDouble();
    } else {
      previewTop = rawTop.clamp(0.0, maxTopPx).toDouble();
    }

    setState(() {
      _timelineVerticalDragDeltaPx =
          previewTop - _timelineVerticalDragOriginTopPx;
      _timelineDragInsertTargetKey = insertKey;
      _timelineDragInsertBefore = insertBefore;
      _timelineDragInsertMarkerTopPx = markerTop;
      _timelineVerticalDragTimeLabel = _timelineDragLabelForTopPx(
        previewTop,
        planWallDay,
        rangeStart,
        _timelineVerticalDragDurationMin,
        _timelineVerticalDragHadEnd,
      );
    });
    _handleHourGridDragUpdateForEdgeScroll(globalDy);
  }

  void _cancelTimelineVerticalDrag() {
    if (_timelineVerticalDragPlanKey == null) return;
    _stopHourGridEdgeScroll();
    setState(_clearTimelineInteractionState);
  }

  void _commitTimelineVerticalDrag({
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required List<PlanningTask> scheduledInRange,
  }) {
    final task = _timelineVerticalDragTask;
    final planKey = _timelineVerticalDragPlanKey;
    _stopHourGridEdgeScroll();
    if (task == null || planKey == null) {
      _cancelTimelineVerticalDrag();
      return;
    }
    final durMin = _timelineVerticalDragDurationMin;
    final maxTopPx = math.max(
      0,
      (PlanningSheetTimelinePrefs.visibleHoursOrdered(rangeStart, rangeEnd)
                  .length *
              60 -
          durMin) *
          _timelinePxPerMinute,
    );
    final newTopPx = (_timelineVerticalDragOriginTopPx +
            _timelineVerticalDragDeltaPx)
        .clamp(0.0, maxTopPx);

    DateTime newStartWall;
    DateTime? newEndWall;

    final insertKey = _timelineDragInsertTargetKey;
    if (insertKey != null) {
      final target = _timelineTaskByPlanKey(scheduledInRange, insertKey);
      final targetStart = target?.startTime;
      if (target != null && targetStart != null) {
        if (_timelineDragInsertBefore) {
          newEndWall = targetStart;
          newStartWall = newEndWall.subtract(Duration(minutes: durMin));
        } else {
          final targetEnd = target.endDateTime ??
              targetStart.add(
                Duration(minutes: _timelineBlockDurationMinutes(target)),
              );
          newStartWall = targetEnd;
          newEndWall = _timelineVerticalDragHadEnd
              ? newStartWall.add(Duration(minutes: durMin))
              : null;
        }
      } else {
        newStartWall = _wallTimeFromTimelineMinutes(
          newTopPx / _timelinePxPerMinute,
          planWallDay,
          rangeStart,
        );
        newEndWall = _timelineVerticalDragHadEnd
            ? newStartWall.add(Duration(minutes: durMin))
            : null;
      }
    } else {
      newStartWall = _wallTimeFromTimelineMinutes(
        newTopPx / _timelinePxPerMinute,
        planWallDay,
        rangeStart,
      );
      newEndWall = _timelineVerticalDragHadEnd
          ? newStartWall.add(Duration(minutes: durMin))
          : null;
    }

    setState(_clearTimelineInteractionState);
    _persistTimelineDragWithCascade(
      movedTask: task,
      newStartWall: newStartWall,
      newEndWall: newEndWall,
      scheduledInRange: scheduledInRange,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      planWallDay: planWallDay,
    );
  }

  Future<void> _onPlanningTaskDroppedOnHour(
    PlanningTask task,
    int targetHour,
  ) async {
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
    final label = '${h.toString().padLeft(2, '0')}:00';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
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

    /// When true, omits list trailing padding (timeline absolute blocks).
    bool timelineEmbedded = false,

    /// When true with [timelineEmbedded], elevates border during drag/resize preview.
    bool timelineInteracting = false,

    /// Proportional block height in px (Time mode absolute layout).
    double timelineBlockHeightPx = _kTimelineMinBlockHeightPx,

    /// Scheduled duration in minutes for adaptive timeline card density.
    int timelineDurationMin = _kTimelineDefaultBlockMinutes,

    /// True when stored schedule overlaps a prior task on the same day.
    bool timelineScheduleConflict = false,

    /// When set with [enableLongPressDrag], drives hour-grid edge auto-scroll from [DragUpdateDetails.globalPosition].
    ValueChanged<double>? onHourGridDragGlobalDy,
    VoidCallback? onHourGridDragEnded,
  }) {
    final highlightAsRunning =
        _activeRecordingTitleNorm != null &&
        _activeRecordingTitleNorm == task.title.trim().toLowerCase();
    final omitLongPress = omitLongPressForReorder;
    final card = _planningTaskCardForRow(
      task,
      key,
      displayDone,
      isSelected,
      highlightAsRunning: highlightAsRunning,
      omitLongPress: omitLongPress || timelineEmbedded,
      planActualByPbId: planActualByPbId,
      timelineBlock: timelineEmbedded,
      timelineInteracting: timelineInteracting,
      timelineBlockHeightPx: timelineBlockHeightPx,
      timelineDurationMin: timelineDurationMin,
      timelineScheduleConflict: timelineScheduleConflict,
    );
    final allowLongPressDrag =
        enableLongPressDrag &&
        !_planSelectMode &&
        !task.planRowIdForBackend.startsWith('optimistic-');
    if (!allowLongPressDrag) {
      if (timelineEmbedded) return card;
      return Padding(padding: const EdgeInsets.only(bottom: 6), child: card);
    }

    final maxFeedbackW = MediaQuery.sizeOf(context).width * 0.9;
    final onDragEnded = onHourGridDragEnded;
    final draggable = LongPressDraggable<PlanningTask>(
        delay: const Duration(milliseconds: 300),
        data: task,
        onDragUpdate: onHourGridDragGlobalDy == null
            ? null
            : (details) => onHourGridDragGlobalDy(details.globalPosition.dy),
        onDragEnd: onDragEnded == null ? null : (_) => onDragEnded(),
        onDraggableCanceled: onDragEnded == null
            ? null
            : (_, _) => onDragEnded(),
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
    );
    if (timelineEmbedded) return draggable;
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: draggable);
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
    final visibleHours = PlanningSheetTimelinePrefs.visibleHoursOrdered(
      rangeStart,
      rangeEnd,
    );
    final visibleSet = visibleHours.toSet();

    final planWallDay = widget.selectedDate ?? _today;
    final inRangeScheduled = <PlanningTask>[];
    final outsideHourTasks = <PlanningTask>[];
    for (final t in scheduled) {
      final st = t.startTime;
      if (st == null) continue;
      final wallH = st.hour.clamp(0, 23);
      if (!visibleSet.contains(wallH)) {
        outsideHourTasks.add(t);
      } else {
        inRangeScheduled.add(t);
      }
    }

    final children = <Widget>[];
    if (unscheduled.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            t(loc, 'plan_unscheduled'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
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
            onHourGridDragGlobalDy: _handleHourGridDragUpdateForEdgeScroll,
            onHourGridDragEnded: _stopHourGridEdgeScroll,
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }
    if (outsideHourTasks.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            t(loc, 'plan_outside_visible_hours'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
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
            onHourGridDragGlobalDy: _handleHourGridDragUpdateForEdgeScroll,
            onHourGridDragEnded: _stopHourGridEdgeScroll,
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }

    children.add(
      _buildProportionalDayTimelineCanvas(
        scheme: scheme,
        loc: loc,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        visibleHours: visibleHours,
        scheduledInRange: inRangeScheduled,
        planActualByPbId: planActualByPbId,
      ),
    );

    return ListView(
      controller: _hourGridScrollController,
      physics: _timelineScrollLocked
          ? const NeverScrollableScrollPhysics()
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: children,
    );
  }

  Widget _buildProportionalDayTimelineCanvas({
    required ColorScheme scheme,
    required String loc,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required List<int> visibleHours,
    required List<PlanningTask> scheduledInRange,
    required Map<String, int> planActualByPbId,
  }) {
    _timelineHourHeightPx = _resolveTimelineHourHeightPx(scheduledInRange);
    final canvasHeight = _timelineCanvasHeightPx(rangeStart, rangeEnd);
    final gridColor = scheme.outlineVariant.withValues(alpha: 0.28);
    final layouts = _timelineBlockLayouts(
      scheduledInRange,
      rangeStart,
      rangeEnd,
    );
    final nowTop = _timelineNowLineTopPx(planWallDay, rangeStart, rangeEnd);
    final nowLabel = nowTop != null
        ? () {
            final n = DatabaseService.getPlanetaryNow();
            return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
          }()
        : null;

    String hourLabel(int hour) =>
        '${hour.clamp(0, 23).toString().padLeft(2, '0')}:00';

    return SizedBox(
      height: canvasHeight + 8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _kTimelineRailWidthPx,
            height: canvasHeight,
            child: Stack(
              children: [
                for (var i = 0; i < visibleHours.length; i++)
                  Positioned(
                    top: i * _timelineHourHeightPx - 6,
                    left: 0,
                    right: 0,
                    child: Text(
                      hourLabel(visibleHours[i]),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: canvasHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasW = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLowest.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < visibleHours.length; i++)
                        Positioned(
                          top: i * _timelineHourHeightPx,
                          left: 0,
                          right: 0,
                          height: _timelineHourHeightPx,
                          child: Stack(
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: gridColor,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 4,
                                child: IconButton(
                                  tooltip: t(loc, 'plan_quick_add_hour'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 28,
                                    height: 28,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    foregroundColor: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  iconSize: 18,
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: () =>
                                      _openQuickAddForHour(visibleHours[i]),
                                ),
                              ),
                              Positioned.fill(
                                child: DragTarget<PlanningTask>(
                                  hitTestBehavior: HitTestBehavior.translucent,
                                  onWillAcceptWithDetails: (_) =>
                                      !_planSelectMode &&
                                      _timelineVerticalDragPlanKey == null &&
                                      _timelineResizePlanKey == null,
                                  onAcceptWithDetails: (details) {
                                    unawaited(
                                      _onPlanningTaskDroppedOnHour(
                                        details.data,
                                        visibleHours[i],
                                      ),
                                    );
                                  },
                                  builder: (context, candidate, rejected) {
                                    final hover = candidate.isNotEmpty;
                                    return GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () => _openQuickAddForHour(
                                        visibleHours[i],
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        decoration: BoxDecoration(
                                          color: hover
                                              ? scheme.primaryContainer
                                                    .withValues(alpha: 0.28)
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (nowTop != null && nowLabel != null)
                        Positioned(
                          top: nowTop.clamp(0, canvasHeight - 1),
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(
                                    alpha: 0.88,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  nowLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: scheme.primary.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_timelineDragInsertMarkerTopPx != null &&
                          _timelineVerticalDragPlanKey != null)
                        Positioned(
                          top: _timelineDragInsertMarkerTopPx!.clamp(
                            0,
                            canvasHeight - 4,
                          ),
                          left: 6,
                          right: 6,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ...[
                        ...layouts
                            .where(
                              (l) =>
                                  _planKey(l.task) !=
                                  _timelineElevatedPlanKey(),
                            )
                            .map(
                              (layout) => _buildTimelinePlanStackLayer(
                                layout: layout,
                                canvasW: canvasW,
                                canvasHeight: canvasHeight,
                                scheme: scheme,
                                planWallDay: planWallDay,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                planActualByPbId: planActualByPbId,
                                scheduledInRange: scheduledInRange,
                              ),
                            ),
                        ...layouts
                            .where(
                              (l) =>
                                  _planKey(l.task) ==
                                  _timelineElevatedPlanKey(),
                            )
                            .map(
                              (layout) => _buildTimelinePlanStackLayer(
                                layout: layout,
                                canvasW: canvasW,
                                canvasHeight: canvasHeight,
                                scheme: scheme,
                                planWallDay: planWallDay,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                planActualByPbId: planActualByPbId,
                                scheduledInRange: scheduledInRange,
                              ),
                            ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _timelineElevatedPlanKey() =>
      _timelineResizePlanKey ?? _timelineVerticalDragPlanKey;

  Widget _buildTimelinePlanStackLayer({
    required _TimelineBlockLayout layout,
    required double canvasW,
    required double canvasHeight,
    required ColorScheme scheme,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required Map<String, int> planActualByPbId,
    required List<PlanningTask> scheduledInRange,
  }) {
    final planKey = _planKey(layout.task);
    final isDragging = _timelineVerticalDragPlanKey == planKey;
    final isResizing = _timelineResizePlanKey == planKey;
    final isInteracting = isDragging || isResizing;
    final topPx = isDragging
        ? layout.topPx + _timelineVerticalDragDeltaPx
        : isResizing
        ? _timelineResizePreviewTopPx
        : layout.topPx;
    final heightPx = isResizing
        ? math.max(1.0, _timelineResizePreviewHeightPx)
        : layout.heightPx;
    final left = _kTimelineBlockHorizontalPadPx;
    final width = _timelineBlockWidth(canvasW);
    final canInteract = _planIsTimelineVerticallyDraggable(layout.task);
    final durMin = _timelineBlockDurationMinutes(layout.task);
    final hadEnd = layout.task.endDateTime != null;
    final times = _timelineStartEndMinutesFromTask(
      layout.task,
      rangeStart,
      rangeEnd,
    );
    final interactionLabel = isResizing
        ? _timelineResizeTimeLabel
        : _timelineVerticalDragTimeLabel;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isInteracting)
          Positioned(
            top: layout.topPx,
            left: left,
            width: width,
            height: layout.heightPx,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        if (isInteracting && (interactionLabel ?? '').isNotEmpty)
          Positioned(
            top: (topPx - 22).clamp(0, canvasHeight - 20),
            left: left,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(6),
              color: scheme.primary.withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  interactionLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        if (isInteracting)
          Positioned(
            top: topPx + heightPx - 2,
            left: left,
            width: width,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        Positioned(
          top: topPx,
          left: left,
          width: width,
          height: heightPx,
          child: _TimelinePlanInteractionBlock(
              canMove: canInteract,
              canResize: canInteract,
              resizeHandlePx: _kTimelineResizeHandlePx,
              onBodyTap: () {
                if (_planSelectMode) {
                  _toggleKeySelection(planKey);
                } else {
                  _openEditDialog(layout.task);
                }
              },
              onVerticalDragStart: canInteract
                  ? () => _beginTimelineVerticalDrag(
                      task: layout.task,
                      planKey: planKey,
                      originTopPx: layout.topPx,
                      durationMin: durMin,
                      hadEnd: hadEnd,
                      planWallDay: planWallDay,
                      rangeStart: rangeStart,
                    )
                  : null,
              onVerticalDragUpdate: canInteract
                  ? (delta, globalDy) => _updateTimelineVerticalDrag(
                      deltaPx: delta,
                      globalDy: globalDy,
                      planWallDay: planWallDay,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      canvasHeight: canvasHeight,
                      scheduledInRange: scheduledInRange,
                    )
                  : null,
              onVerticalDragEnd: canInteract
                  ? () => _commitTimelineVerticalDrag(
                      planWallDay: planWallDay,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      scheduledInRange: scheduledInRange,
                    )
                  : null,
              onVerticalDragCancel:
                  canInteract ? _cancelTimelineVerticalDrag : null,
              onResizeStart: canInteract
                  ? (edge) => _beginTimelineResize(
                      edge: edge,
                      task: layout.task,
                      planKey: planKey,
                      originTopPx: layout.topPx,
                      originHeightPx: layout.heightPx,
                      originStartMin: times.startMin,
                      originEndMin: times.endMin,
                      planWallDay: planWallDay,
                      rangeStart: rangeStart,
                    )
                  : null,
              onResizeUpdate: canInteract
                  ? (delta, globalDy) => _updateTimelineResize(
                      deltaPx: delta,
                      globalDy: globalDy,
                      planWallDay: planWallDay,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                    )
                  : null,
              onResizeEnd:
                  canInteract
                      ? () => _commitTimelineResize(
                          planWallDay: planWallDay,
                          rangeStart: rangeStart,
                        )
                      : null,
              onResizeCancel: canInteract ? _cancelTimelineResize : null,
              isInteracting: isInteracting,
              child: _planCardRow(
                context: context,
                task: layout.task,
                key: planKey,
                displayDone:
                    _planDoneOverride[planKey] ?? layout.task.isDone,
                isSelected: _selectedPlanKeys.contains(planKey),
                planActualByPbId: planActualByPbId,
                timelineEmbedded: true,
                timelineInteracting: isInteracting,
                timelineBlockHeightPx: heightPx,
                timelineDurationMin: durMin,
                timelineScheduleConflict: layout.hasScheduleConflict,
              ),
            ),
        ),
      ],
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
            alignment: AlignmentDirectional.centerStart,
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
              final canReorder = !task.planRowIdForBackend.startsWith(
                'optimistic-',
              );
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
                  t(
                    loc,
                    'selected_count',
                  ).replaceFirst('%s', '${_selectedPlanKeys.length}'),
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

    return StreamBuilder<List<PlanningTask>>(
      stream: _planningStream,
      builder: (context, snapshot) {
        List<PlanningTask>? displayedForChrome;
        late final Widget body;
        try {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            body = const AppLoading();
          } else if (snapshot.hasError) {
            body = AppErrorState(
              message: t(currentLocale.value, 'no_data_found'),
            );
          } else {
            final server = snapshot.data ?? [];
            _latestPlanningDayTasks = server;
            if (server.isNotEmpty && _optimisticTasks.isNotEmpty) {
              final toDrop = _optimisticTasks
                  .where(
                    (o) => server.any((s) {
                      final oBiz = _planBusinessUuidForMerge(o);
                      final sBiz = _planBusinessUuidForMerge(s);
                      if (oBiz != null &&
                          sBiz != null &&
                          oBiz.isNotEmpty &&
                          oBiz == sBiz) {
                        return true;
                      }
                      return s.title.trim() == o.title.trim() &&
                          s.dateKey == o.dateKey;
                    }),
                  )
                  .toList();
              if (toDrop.isNotEmpty) {
                final dropIds = toDrop.map((e) => e.planRowId).toSet();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(
                    () => _optimisticTasks.removeWhere(
                      (o) => dropIds.contains(o.planRowId),
                    ),
                  );
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
          body = AppErrorState(
            message: t(currentLocale.value, 'no_data_found'),
          );
        }

        final visiblePlans = displayedForChrome;
        _syncPlanningShellFabBulkReserve();
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_planSelectMode) ...[
                  Material(
                    color: scheme.surface,
                    elevation: 0,
                    surfaceTintColor: scheme.surfaceTint,
                    child: SizedBox(
                      height: kGlobalCompactHeaderHeight,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _exitSelectMode,
                            tooltip: t(currentLocale.value, 'plan_exit_select'),
                          ),
                          Expanded(
                            child: Text(
                              t(currentLocale.value, 'plan_select_mode'),
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (visiblePlans != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () =>
                                  _toggleSelectAllVisiblePlans(visiblePlans),
                              child: Text(
                                _allVisiblePlanTasksSelected(visiblePlans)
                                    ? t(
                                        currentLocale.value,
                                        'plan_deselect_visible',
                                      )
                                    : t(currentLocale.value, 'plan_select_all'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                ],
                Expanded(child: body),
              ],
            ),
          ),
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                height: kAppCompactControlHeight,
                child: SegmentedButton<_PlanSortMode>(
                  showSelectedIcon: false,
                  style: appCompactSegmentedButtonStyle(
                    context,
                    segmentWidth: 78,
                  ),
                  segments: [
                    ButtonSegment<_PlanSortMode>(
                      value: _PlanSortMode.category,
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'plan_sort_category'),
                      ),
                    ),
                    ButtonSegment<_PlanSortMode>(
                      value: _PlanSortMode.time,
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'plan_sort_time'),
                      ),
                    ),
                    ButtonSegment<_PlanSortMode>(
                      value: _PlanSortMode.tags,
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'plan_sort_tags'),
                      ),
                    ),
                    ButtonSegment<_PlanSortMode>(
                      value: _PlanSortMode.custom,
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'plan_sort_custom'),
                      ),
                    ),
                  ],
                  selected: {_sortMode},
                  onSelectionChanged: (Set<_PlanSortMode> next) {
                    if (next.isEmpty) return;
                    final mode = next.first;
                    setState(() {
                      _sortMode = mode;
                    });
                    unawaited(
                      DatabaseService.instance.persistPlanActiveTabIndex(
                        _planSortModeToPersistedIndex(mode),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: _buildQuickAddTagStrip(scheme),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.primary,
                      splashFactory: NoSplash.splashFactory,
                      hoverColor: Colors.transparent,
                    ),
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: t(currentLocale.value, 'plan_settings_tooltip'),
                    onPressed: _showPlanningSettingsSheet,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _quickAddFocus,
                      decoration: InputDecoration(
                        hintText: t(
                          currentLocale.value,
                          'input_placeholder_plan',
                        ),
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
                  const SizedBox(width: 8),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.primary,
                      splashFactory: NoSplash.splashFactory,
                      hoverColor: Colors.transparent,
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    tooltip: t(currentLocale.value, 'smart_plan_tooltip'),
                    onPressed: _openSmartPlanSheet,
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
                  actionLabelL10nKey: 'empty_action_focus_planning_field',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                onReorder: (oldI, newI) => _onReorder(tasks, oldI, newI),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final key = _planKey(task);
                  final displayDone = _planDoneOverride[key] ?? task.isDone;
                  final canReorder =
                      !_planSelectMode &&
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
    return Offset(math.cos(radians) * _orbit, -math.sin(radians) * _orbit);
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

/// Record-to-plan suggestion prefs (Planning settings sheet only).
///
/// Owns UI state so toggles rebuild inside the modal; reads/writes
/// [plans_record_link_suggestions_enabled] and [plans_record_link_suggestion_mode].
class _PlanRecordLinkSuggestionSettingsBlock extends StatefulWidget {
  const _PlanRecordLinkSuggestionSettingsBlock();

  @override
  State<_PlanRecordLinkSuggestionSettingsBlock> createState() =>
      _PlanRecordLinkSuggestionSettingsBlockState();
}

class _PlanRecordLinkSuggestionSettingsBlockState
    extends State<_PlanRecordLinkSuggestionSettingsBlock> {
  static const String _prefsEnabled = 'plans_record_link_suggestions_enabled';
  static const String _prefsMode = 'plans_record_link_suggestion_mode';
  static const String _modeAsk = 'ask';
  static const String _modeAuto = 'auto';

  bool _enabled = true;
  String _mode = _modeAsk;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFromPrefs());
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsEnabled) ?? true;
      final raw = prefs.getString(_prefsMode);
      final mode = raw == _modeAuto ? _modeAuto : _modeAsk;
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _mode = mode;
      });
    } catch (_) {}
  }

  Future<void> _persist({bool? enabled, String? mode}) async {
    final nextEnabled = enabled ?? _enabled;
    final nextMode = mode != null
        ? (mode == _modeAuto ? _modeAuto : _modeAsk)
        : _mode;
    setState(() {
      _enabled = nextEnabled;
      _mode = nextMode;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsEnabled, nextEnabled);
      await prefs.setString(_prefsMode, nextMode);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          title: Text(t(loc, 'record_link_suggestions_title')),
          subtitle: Text(
            t(loc, 'record_link_suggestions_subtitle'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onChanged: (value) => unawaited(_persist(enabled: value)),
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: _modeAsk,
                label: Text(t(loc, 'record_link_suggestion_mode_ask')),
              ),
              ButtonSegment<String>(
                value: _modeAuto,
                label: Text(t(loc, 'record_link_suggestion_mode_auto')),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (next) {
              if (next.isEmpty) return;
              unawaited(_persist(mode: next.first));
            },
          ),
        ],
      ],
    );
  }
}

/// “No Tags” synthetic chip: visibility + B/W presets (Planning settings sheet only).
class _PlanningNoTagsSettingsBlock extends StatefulWidget {
  const _PlanningNoTagsSettingsBlock({
    required this.initialVisible,
    required this.initialColorHex,
    required this.onApply,
  });

  final bool initialVisible;
  final String initialColorHex;
  final Future<void> Function(bool visible, String colorHex) onApply;

  @override
  State<_PlanningNoTagsSettingsBlock> createState() =>
      _PlanningNoTagsSettingsBlockState();
}

class _PlanningNoTagsSettingsBlockState
    extends State<_PlanningNoTagsSettingsBlock> {
  static const List<String> _presets = <String>[
    '#000000',
    '#FFFFFF',
    '#9E9E9E',
    '#F44336',
    '#2196F3',
    '#4CAF50',
    '#FF9800',
  ];

  late bool _visible;
  late String _colorHex;

  @override
  void initState() {
    super.initState();
    _visible = widget.initialVisible;
    _colorHex = widget.initialColorHex;
  }

  Future<void> _persist() async {
    await widget.onApply(_visible, _colorHex);
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t(loc, 'plan_filter_no_tags')),
            subtitle: Text(t(loc, 'category_visibility_toggle')),
            value: _visible,
            onChanged: (v) {
              setState(() => _visible = v);
              unawaited(_persist());
            },
          ),
          Text(
            t(loc, 'category_color'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _presets)
                GestureDetector(
                  onTap: () {
                    setState(() => _colorHex = h);
                    unawaited(_persist());
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: parseTagHexColor(h),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorHex == h
                            ? scheme.primary
                            : (h == '#FFFFFF'
                                  ? scheme.outline
                                  : Colors.transparent),
                        width: _colorHex == h ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultPlanCategoryOption {
  const _DefaultPlanCategoryOption({required this.id, required this.path});

  final int id;
  final String path;

  String get name {
    final parts = path.split('>');
    return parts.isEmpty ? path.trim() : parts.last.trim();
  }
}

class _DefaultPlanCategorySearchDelegate
    extends SearchDelegate<_DefaultPlanCategoryOption?> {
  _DefaultPlanCategorySearchDelegate({required this.loc, required this.options})
    : super(searchFieldLabel: t(loc, 'plan_default_time_search_category'));

  final String loc;
  final List<_DefaultPlanCategoryOption> options;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? options
        : options.where((o) {
            return o.path.toLowerCase().contains(q) ||
                o.name.toLowerCase().contains(q);
          }).toList();
    if (matches.isEmpty) {
      return Center(child: Text(t(loc, 'plan_default_time_search_category')));
    }
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = matches[index];
        return ListTile(
          title: Text(option.path),
          onTap: () => close(context, option),
        );
      },
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
    _startValue = PlanningSheetTimelinePrefs.clampHour(
      widget.initialStart,
    ).toDouble();
    _endValue = PlanningSheetTimelinePrefs.clampHour(
      widget.initialEnd,
    ).toDouble();
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
          Text(widget.endTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            widget.endHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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

List<Widget> _planningTaskMetaIcons(BuildContext context, PlanningTask task) {
  final base = Theme.of(context).iconTheme.color;
  final color = base?.withValues(alpha: 0.48);
  if (color == null) return const [];
  if (!task.hasNotes && !task.hasChecklist && !task.hasParentPlan) {
    return const [];
  }
  final out = <Widget>[];
  void add(IconData icon) {
    if (out.isNotEmpty) out.add(const SizedBox(width: 4));
    out.add(Icon(icon, size: 15, color: color));
  }

  if (task.hasNotes) add(Icons.sticky_note_2_outlined);
  if (task.hasChecklist) add(Icons.checklist_rounded);
  if (task.hasParentPlan) add(Icons.account_tree_outlined);
  return out;
}

enum _TimelineResizeEdge { top, bottom }

/// Invisible move/resize gesture zones for proportional timeline plan blocks.
class _TimelinePlanInteractionBlock extends StatefulWidget {
  const _TimelinePlanInteractionBlock({
    required this.canMove,
    required this.canResize,
    required this.resizeHandlePx,
    required this.child,
    required this.isInteracting,
    this.onBodyTap,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
  });

  final bool canMove;
  final bool canResize;
  final double resizeHandlePx;
  final bool isInteracting;
  final Widget child;
  final VoidCallback? onBodyTap;
  final VoidCallback? onVerticalDragStart;
  final void Function(double deltaPx, double globalDy)? onVerticalDragUpdate;
  final VoidCallback? onVerticalDragEnd;
  final VoidCallback? onVerticalDragCancel;
  final void Function(_TimelineResizeEdge edge)? onResizeStart;
  final void Function(double deltaPx, double globalDy)? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResizeCancel;

  @override
  State<_TimelinePlanInteractionBlock> createState() =>
      _TimelinePlanInteractionBlockState();
}

class _TimelinePlanInteractionBlockState
    extends State<_TimelinePlanInteractionBlock> {
  double _moveAccumulatedDy = 0;
  bool _resizing = false;
  bool _suppressBodyTap = false;
  bool _bodyDragActive = false;

  bool get _immediateBodyDrag =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  void _endBodyDragSession() {
    _bodyDragActive = false;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _suppressBodyTap = false);
    });
  }

  Widget _moveZone() {
    if (!widget.canMove) return const SizedBox.shrink();
    final topInset = widget.canResize ? widget.resizeHandlePx : 0.0;
    final bottomInset = widget.canResize ? widget.resizeHandlePx : 0.0;
    return Positioned(
      top: topInset,
      bottom: bottomInset,
      left: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onBodyTap == null
            ? null
            : () {
                if (_suppressBodyTap || _bodyDragActive) return;
                widget.onBodyTap!();
              },
        onLongPressStart: _immediateBodyDrag
            ? null
            : (_) {
                _suppressBodyTap = true;
                _bodyDragActive = true;
                _moveAccumulatedDy = 0;
                widget.onVerticalDragStart?.call();
              },
        onLongPressMoveUpdate: _immediateBodyDrag
            ? null
            : (details) {
                widget.onVerticalDragUpdate?.call(
                  details.offsetFromOrigin.dy,
                  details.globalPosition.dy,
                );
              },
        onLongPressEnd: _immediateBodyDrag
            ? null
            : (_) {
                widget.onVerticalDragEnd?.call();
                _endBodyDragSession();
              },
        onLongPressCancel: _immediateBodyDrag
            ? null
            : () {
                widget.onVerticalDragCancel?.call();
                _endBodyDragSession();
              },
        onVerticalDragStart: _immediateBodyDrag
            ? (_) {
                _suppressBodyTap = true;
                _bodyDragActive = true;
                _moveAccumulatedDy = 0;
                widget.onVerticalDragStart?.call();
              }
            : null,
        onVerticalDragUpdate: _immediateBodyDrag
            ? (details) {
                _moveAccumulatedDy += details.delta.dy;
                widget.onVerticalDragUpdate?.call(
                  _moveAccumulatedDy,
                  details.globalPosition.dy,
                );
              }
            : null,
        onVerticalDragEnd: _immediateBodyDrag
            ? (_) {
                widget.onVerticalDragEnd?.call();
                _endBodyDragSession();
              }
            : null,
        onVerticalDragCancel: _immediateBodyDrag
            ? () {
                widget.onVerticalDragCancel?.call();
                _endBodyDragSession();
              }
            : null,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _resizeEdge({
    required bool isTop,
    required ColorScheme scheme,
  }) {
    return _TimelineResizeEdgeHandle(
      isTop: isTop,
      height: widget.resizeHandlePx,
      active: _resizing || widget.isInteracting,
      onResizeStart: widget.canResize
          ? () {
              setState(() {
                _resizing = true;
                _suppressBodyTap = true;
              });
              widget.onResizeStart?.call(
                isTop ? _TimelineResizeEdge.top : _TimelineResizeEdge.bottom,
              );
            }
          : null,
      onResizeUpdate: widget.canResize
          ? (delta, globalDy) {
              widget.onResizeUpdate?.call(delta, globalDy);
            }
          : null,
      onResizeEnd: widget.canResize
          ? () {
              setState(() => _resizing = false);
              widget.onResizeEnd?.call();
              _endBodyDragSession();
            }
          : null,
      onResizeCancel: widget.canResize
          ? () {
              setState(() => _resizing = false);
              widget.onResizeCancel?.call();
              _endBodyDragSession();
            }
          : null,
      scheme: scheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canMove && !widget.canResize) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        _moveZone(),
        if (widget.canResize)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _resizeEdge(isTop: true, scheme: scheme),
          ),
        if (widget.canResize)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _resizeEdge(isTop: false, scheme: scheme),
          ),
      ],
    );
  }
}

class _TimelineResizeEdgeHandle extends StatefulWidget {
  const _TimelineResizeEdgeHandle({
    required this.isTop,
    required this.height,
    required this.active,
    required this.scheme,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
  });

  final bool isTop;
  final double height;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback? onResizeStart;
  final void Function(double deltaPx, double globalDy)? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResizeCancel;

  @override
  State<_TimelineResizeEdgeHandle> createState() =>
      _TimelineResizeEdgeHandleState();
}

class _TimelineResizeEdgeHandleState extends State<_TimelineResizeEdgeHandle> {
  bool _hover = false;
  bool _dragging = false;
  double _accumulatedDy = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final showHairline = _hover || _dragging;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) {
          _accumulatedDy = 0;
          setState(() => _dragging = true);
          widget.onResizeStart?.call();
        },
        onVerticalDragUpdate: (details) {
          _accumulatedDy += details.delta.dy;
          widget.onResizeUpdate?.call(
            _accumulatedDy,
            details.globalPosition.dy,
          );
        },
        onVerticalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onResizeEnd?.call();
        },
        onVerticalDragCancel: () {
          setState(() => _dragging = false);
          widget.onResizeCancel?.call();
        },
        child: SizedBox(
          height: widget.height,
          child: showHairline
              ? Align(
                  alignment: widget.isTop
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: scheme.primary.withValues(alpha: 0.38),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Absolute placement for one task block on the proportional day timeline.
class _TimelineBlockLayout {
  const _TimelineBlockLayout({
    required this.task,
    required this.topPx,
    required this.heightPx,
    required this.column,
    required this.totalColumns,
    this.hasScheduleConflict = false,
  });

  final PlanningTask task;
  final double topPx;
  final double heightPx;
  final int column;
  final int totalColumns;
  final bool hasScheduleConflict;
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
    this.timelineBlock = false,
    this.timelineInteracting = false,
    this.timelineBlockHeightPx = 56,
    this.timelineDurationMin = 30,
    this.timelineScheduleConflict = false,
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
  final bool timelineBlock;
  final bool timelineInteracting;
  final double timelineBlockHeightPx;
  final int timelineDurationMin;
  final bool timelineScheduleConflict;

  static String _formatPlanningTaskDate(PlanningTask task) {
    if (task.dateKey.isEmpty) return '';
    final d = _dateFromKey(task.dateKey);
    if (d == null) return task.dateKey;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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

  static String _timelineTimeRangeLabel(PlanningTask task) {
    final start = task.startTime;
    if (start == null) return '';
    final startLabel = _formatPlanningWallTime(start);
    final end = task.endDateTime;
    if (end != null) {
      return '$startLabel – ${_formatPlanningWallTime(end)}';
    }
    return startLabel;
  }

  @override
  Widget build(BuildContext context) {
    if (timelineBlock) {
      return _buildTimelineBlockCard(context);
    }
    return _buildListPlanningCard(context);
  }

  Widget _buildTimelineBlockCard(BuildContext context) {
    final suppressChildInk = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      checkboxTheme: CheckboxThemeData(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
    final density = planTimeCardDensityForBlock(
      timelineBlockHeightPx,
      timelineDurationMin,
    );
    return Theme(
      data: suppressChildInk,
      child: PlanTimeTaskCard(
        task: task,
        density: density,
        timeLabel: _timelineTimeRangeLabel(task),
        heightPx: timelineBlockHeightPx,
        displayIsDone: displayIsDone,
        selectMode: selectMode,
        isSelected: isSelected,
        highlightAsRunning: highlightAsRunning,
        interacting: timelineInteracting,
        toggleDoneEnabled: toggleDoneEnabled,
        planTrackedSeconds: planTrackedSeconds,
        planEstimatedSeconds: planEstimatedSeconds,
        scheduleConflict: timelineScheduleConflict,
        onToggleDone: onToggleDone,
        onSelectToggle: onBodyTap,
        onPlay: onPlay,
        onOpenMenu: onOpenMenu,
      ),
    );
  }

  Widget _buildListPlanningCard(BuildContext context) {
    final metaIcons = _planningTaskMetaIcons(context, task);
    final hasRepeat =
        (task.rrule?.trim().isNotEmpty ?? false) ||
        (task.recurrenceInstanceDateKey?.trim().isNotEmpty ?? false);
    final scheme = Theme.of(context).colorScheme;
    final categoryTrail = localizeCategoryBreadcrumbPath(
      DatabaseService.instance.getCategoryPath(task.categoryId).trim(),
      currentLocale.value,
    );
    final categoryTone = DatabaseService.instance.getCategoryColor(
      task.categoryId,
    );
    final bg = selectMode && isSelected
        ? scheme.primaryContainer
        : timelineBlock
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.05),
            scheme.surface,
          )
        : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final borderColor = highlightAsRunning
        ? scheme.primary
        : timelineInteracting
        ? scheme.primary.withValues(alpha: 0.55)
        : timelineBlock
        ? scheme.outlineVariant.withValues(alpha: 0.62)
        : Colors.transparent;
    final borderWidth = highlightAsRunning
        ? 2.0
        : timelineInteracting
        ? 1.5
        : timelineBlock
        ? 1.0
        : 0.0;
    final showPlayButton = !selectMode && !displayIsDone;
    final suppressChildInk = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      checkboxTheme: CheckboxThemeData(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Material(
      color: bg,
      elevation: timelineBlock ? (timelineInteracting ? 3 : 1.5) : 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: borderWidth),
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
                if (timelineBlock)
                  Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: categoryTone.withValues(alpha: 0.82),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2, top: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      selectMode
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
                      if (showPlayButton)
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            splashFactory: NoSplash.splashFactory,
                            hoverColor: Colors.transparent,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: onPlay,
                          tooltip: t(currentLocale.value, 'start'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 6,
                      bottom: 2,
                      end: 4,
                    ),
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
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    height: 1.2,
                                    letterSpacing: 0.12,
                                    fontWeight: FontWeight.w500,
                                    color: categoryTone.withValues(alpha: 0.88),
                                  ),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              fit: FlexFit.loose,
                              child: Text(
                                task.title,
                                textAlign: TextAlign.start,
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
                            ),
                            if (hasRepeat)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 4,
                                  top: 1,
                                ),
                                child: Icon(
                                  Icons.repeat_rounded,
                                  size: 17,
                                  color: scheme.primary.withValues(alpha: 0.85),
                                ),
                              ),
                            if (metaIcons.isNotEmpty)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 4,
                                  top: 1,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: metaIcons,
                                ),
                              ),
                          ],
                        ),
                        if ((planEstimatedSeconds ?? 0) > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    value:
                                        planTrackedSeconds <=
                                            planEstimatedSeconds!
                                        ? planTrackedSeconds /
                                              planEstimatedSeconds!
                                        : 1.0,
                                    backgroundColor: scheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.65),
                                    color:
                                        planTrackedSeconds >
                                            planEstimatedSeconds!
                                        ? scheme.error
                                        : scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 0,
                                child: Text(
                                  () {
                                    final est = planEstimatedSeconds!;
                                    final a = planTrackedSeconds;
                                    final pct = est > 0
                                        ? ((a * 100) / est).round()
                                        : 0;
                                    return '${_shortDur(a)} / ${_shortDur(est)} ($pct%)';
                                  }(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        height: 1.1,
                                        color:
                                            planTrackedSeconds >
                                                planEstimatedSeconds!
                                            ? scheme.error
                                            : scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (planTrackedSeconds > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            t(
                              currentLocale.value,
                              'plan_card_fact_time',
                            ).replaceFirst(
                              '%s',
                              _trackedDurationAsHhMm(planTrackedSeconds),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  height: 1.1,
                                  color: scheme.primary.withValues(alpha: 0.92),
                                ),
                          ),
                        ],
                        if (task.tags.any((t) => t.rendersAsChip)) ...[
                          const SizedBox(height: 6),
                          StreamBuilder<UserSettings>(
                            stream: DatabaseService.instance.userSettingsStream,
                            initialData: DatabaseService.instance.settings,
                            builder: (context, snap) {
                              final mode =
                                  snap.data?.tagDisplayMode ??
                                  CategoryDisplayMode.letterChip;
                              return SizedBox(
                                height: 28,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: task.tags
                                      .where((tag) => tag.rendersAsChip)
                                      .length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 6),
                                  itemBuilder: (context, i) {
                                    final visible = task.tags
                                        .where((tag) => tag.rendersAsChip)
                                        .toList(growable: false);
                                    final tag = visible[i];
                                    return Center(
                                      child: CategoryChip(
                                        mode: mode,
                                        label: tag.name.trim().isNotEmpty
                                            ? tag.name.trim()
                                            : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                                        color:
                                            parseTagHexColor(tag.color) ??
                                            scheme.primary,
                                        icon: iconForTagKey(tag.icon),
                                        compactGlyphLayout: true,
                                        syntheticNoTagsMonochrome:
                                            tag.tagId == -1,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                        selectMode
                            ? Text(
                                _subtitle(task),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onDateTap,
                                child: Text(
                                  _subtitle(task),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                Builder(
                  builder: (menuCtx) {
                    return IconButton(
                      tooltip: t(currentLocale.value, 'plan_radial_menu_tip'),
                      style: IconButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        hoverColor: Colors.transparent,
                        backgroundColor: scheme.secondaryContainer.withValues(
                          alpha: 0.92,
                        ),
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
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
