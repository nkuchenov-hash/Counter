// ---------------------------------------------------------------------------
// PLANNING FEATURE — Day planning & task list tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:counter/core/app_diag.dart';
import 'package:counter/core/date_pager_settle_gate.dart';
import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/core/mounted_day_registry.dart';
import 'package:counter/core/p0u_feature_flags.dart';
import 'package:counter/core/p0u_diag.dart';
import 'package:counter/core/p0u_feature_flags.dart';
import 'package:counter/core/p0u_platform.dart';
import 'package:counter/core/pre_white_swipe_restore.dart';
import 'package:counter/core/widgets/eager_day_content_strip.dart';
import 'package:counter/core/widgets/mounted_day_window.dart';
import 'package:counter/core/perf_diag.dart';
import 'package:counter/core/perf_flags.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/time_drop_trace.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/p0t_render_snapshot.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/bulk_planning_edit_sheet.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/features/planning/smart_plan_sheet.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, Ticker;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/plan_card.dart';
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
///
/// SWIPE GUARD: Do not replace restored [PageView] date paging with custom slot pager. Failed P0H–P0L.
class PlanningSwipeWrapper extends StatefulWidget {
  const PlanningSwipeWrapper({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.shellTabActive = true,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStartRecordFromTask,
    required this.onEditTask,
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateChanged;
  final bool shellTabActive;
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
  static const int _initialPage = 5000;
  static const int _totalPageCount = 10000;
  late PageController _controller;
  late DateTime _anchorDate;
  late int _visiblePageIndex;
  int? _pendingExternalPage;
  bool _datePagerLocked = false;
  final DatePagerSettleGate _settleGate = DatePagerSettleGate();

  String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _onPlanningDatePagerLockChanged(bool locked) {
    if (_datePagerLocked == locked) return;
    setState(() => _datePagerLocked = locked);
    if (!locked) _applyPendingExternalPageIfNeeded();
  }

  void _applyPendingExternalPageIfNeeded() {
    if (_datePagerLocked || _settleGate.blocksExternalDateSync) return;
    final pending = _pendingExternalPage;
    if (pending == null) return;
    _pendingExternalPage = null;
    if (pending < 0 || pending >= _totalPageCount) return;
    if (!_controller.hasClients) return;
    final cur = _controller.page?.round();
    if (cur == pending) return;
    _settleGate.resetCommittedPage(pending);
    setState(() => _visiblePageIndex = pending);
    _controller.jumpToPage(pending);
  }

  int _pageIndexForDate(DateTime date) {
    final daysOffset = _dateOnly(date).difference(_anchorDate).inDays;
    return _initialPage + daysOffset;
  }

  DateTime _dateForIndex(int index) =>
      _dateOnly(_anchorDate.add(Duration(days: index - _initialPage)));

  void _syncOnTabActivated() {
    final page = _pendingExternalPage ?? _pageIndexForDate(widget.selectedDate);
    _pendingExternalPage = null;
    if (page < 0 || page >= _totalPageCount) return;
    setState(() => _visiblePageIndex = page);
    if (!_controller.hasClients) return;
    final cur = _controller.page?.round();
    if (cur == page) return;
    _controller.jumpToPage(page);
  }

  void _deferHiddenExternalDate() {
    final page = _pageIndexForDate(widget.selectedDate);
    if (page < 0 || page >= _totalPageCount) return;
    _pendingExternalPage = page;
  }

  void _schedulePrefetch(DateTime center) {
    if (kUseP0tMountedStrip) return;
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        DatabaseService.instance.extendPlansWarmWindowIfNeeded(center);
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    final platform = p0uPlatformLabel();
    P0uDiag.p0tDisabled(platform: platform, enabled: kUseP0tMountedStrip);
    P0uDiag.biometricGate(enabled: false, reason: 'stabilization');
    _anchorDate = DateUtils.dateOnly(DateTime.now());
    final daysOffset =
        _dateOnly(widget.selectedDate).difference(_anchorDate).inDays;
    _visiblePageIndex = _initialPage + daysOffset;
    _controller = PageController(initialPage: _visiblePageIndex);
    _controller.addListener(_onPageControllerTick);
    if (kPlansWarmWindowEnabled && !kUseP0tMountedStrip) {
      DatabaseService.instance.ensurePlansWarmWindow(widget.selectedDate);
    }
  }

  void _onPageControllerTick() {
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    PerfDiag.instance.dateSwipeDrag(
      section: 'Planning',
      page: page.round(),
      pageFraction: page,
    );
  }

  @override
  void didUpdateWidget(covariant PlanningSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.shellTabActive && widget.shellTabActive) {
      _syncOnTabActivated();
      return;
    }
    if (!widget.shellTabActive) {
      final oldD = _dateOnly(oldWidget.selectedDate);
      final newD = _dateOnly(widget.selectedDate);
      if (oldD != newD) _deferHiddenExternalDate();
      return;
    }
    final oldD = _dateOnly(oldWidget.selectedDate);
    final newD = _dateOnly(widget.selectedDate);
    if (oldD == newD) return;
    final page = _pageIndexForDate(widget.selectedDate);
    if (page < 0 || page >= _totalPageCount) return;
    if (_settleGate.blocksExternalDateSync || _datePagerLocked) {
      _pendingExternalPage = page;
      return;
    }
    setState(() => _visiblePageIndex = page);
    if (_controller.hasClients) {
      final cur = _controller.page;
      if (cur != null && cur.round() == page) return;
      _settleGate.markProgrammaticAnimStart();
      _controller
          .animateToPage(
            page,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (mounted) _settleGate.markProgrammaticAnimEnd();
          });
    }
  }

  @override
  void dispose() {
    _settleGate.dispose();
    _controller.removeListener(_onPageControllerTick);
    _controller.dispose();
    super.dispose();
  }

  void _jumpToDate(DateTime date) {
    final dateOnly = _dateOnly(date);
    final targetIndex = _pageIndexForDate(dateOnly);
    if (targetIndex >= 0 &&
        targetIndex < _totalPageCount &&
        _controller.hasClients) {
      _controller.jumpToPage(targetIndex);
      widget.onDateChanged(dateOnly);
    }
  }

  @override
  Widget build(BuildContext context) {
    perfRebuildTick('PlanningSwipeWrapper');
    if (kUseP0tMountedStrip) {
      return _buildMountedStripFallback(context);
    }
    try {
      return ScrollConfiguration(
        behavior: const MouseDragScrollBehavior(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _settleGate.onUserDragStart();
              final from = _dateKeyFromDate(_dateForIndex(_visiblePageIndex));
              PerfDiag.instance.dateSwipeStart(
                section: 'Planning',
                fromDate: from,
              );
            }
            if (n is ScrollEndNotification) {
              _settleGate.onUserDragEnd();
              _applyPendingExternalPageIfNeeded();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                PerfDiag.instance.dateSwipeEnd(section: 'Planning');
              });
            }
            return false;
          },
          child: PageView.builder(
            controller: _controller,
            physics: _datePagerLocked
                ? const NeverScrollableScrollPhysics()
                : const FeatherDateSwipePhysics(),
            itemCount: _totalPageCount,
            onPageChanged: (int index) {
              if (index < 0 || index >= _totalPageCount) return;
              setState(() => _visiblePageIndex = index);
              _settleGate.onPageSettled(
                pageIndex: index,
                onShellCommit: (page) {
                  if (!mounted) return;
                  final committed = _dateForIndex(page);
                  _schedulePrefetch(committed);
                  widget.onDateChanged(_dateOnly(committed));
                },
              );
            },
            itemBuilder: (context, index) {
              final date = _dateForIndex(index);
              final dateKey = _dateKeyFromDate(date);
              final isActive =
                  widget.shellTabActive && index == _visiblePageIndex;
              return PlanningPage(
                key: ValueKey<String>('plan-page-$dateKey'),
                selectedDateString: dateKey,
                selectedDate: date,
                isActivePlanningDay: isActive,
                shellTabActive: widget.shellTabActive,
                selectedCategoryId: widget.selectedCategoryId,
                onCategoryChanged: widget.onCategoryChanged,
                onStartRecordFromTask: widget.onStartRecordFromTask,
                onEditTask: widget.onEditTask,
                onDatePicked: _jumpToDate,
                onDateChanged: widget.onDateChanged,
                onDatePagerLockChanged: _onPlanningDatePagerLockChanged,
              );
            },
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('PlanningSwipeWrapper: $e\n$st');
      return Scaffold(
        body: AppErrorState(message: t(currentLocale.value, 'no_data_found')),
      );
    }
  }

  /// Legacy P0S/P0T path — disabled when [kUseP0tMountedStrip] is false.
  Widget _buildMountedStripFallback(BuildContext context) {
    return AppErrorState(
      message: t(currentLocale.value, 'no_data_found'),
    );
  }
}

/// Single-day planning: task list, add task, date picker.
class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.selectedDateString,
    this.selectedDate,
    this.isActivePlanningDay = false,
    this.shellTabActive = true,
    this.mountedWindow,
    this.stripController,
    this.datePagerLocked = false,
    this.onVisibleDateChanged,
    this.onUserDragStart,
    this.onUserDragEnd,
    this.onScrollTick,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStartRecordFromTask,
    required this.onEditTask,
    this.onDatePicked,
    this.onDateChanged,
    this.onDatePagerLockChanged,
  });

  final String selectedDateString;
  final DateTime? selectedDate;

  /// Only the visible PageView day should be true (live planning stream).
  final bool isActivePlanningDay;
  final bool shellTabActive;
  final MountedDayWindow? mountedWindow;
  final EagerDayContentStripController? stripController;
  final bool datePagerLocked;
  final void Function(int windowIndex, DateTime date)? onVisibleDateChanged;
  final VoidCallback? onUserDragStart;
  final VoidCallback? onUserDragEnd;
  final void Function(double pageFraction)? onScrollTick;
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
  final void Function(DateTime date)? onDateChanged;
  final void Function(bool locked)? onDatePagerLockChanged;

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
  String? _timeViewCascadeNormalizedDayKey;
  final Map<String, bool> _planDoneOverride = {};
  /// Keeps completed cards at their list index until the completion moment finishes.
  final Set<String> _planCompletionHoldKeys = {};
  final Map<String, Timer> _planCompletionHoldTimers = {};
  final Set<String> _planReorderSettleKeys = {};
  static const Duration _kPlanCompletionHoldDuration =
      Duration(milliseconds: 250);
  static const Duration _kPlanReorderSettleDuration =
      Duration(milliseconds: 280);
  Stream<List<PlanningTask>>? _planningStream;
  List<PlanningTask>? _dragOrder;
  bool _planSelectMode = false;
  _PlanSortMode _sortMode = _PlanSortMode.custom;
  int _timelineHourStart = 0;
  int _timelineHourEnd = 23;

  /// Hour-grid day timeline scroll (edge auto-scroll while dragging a plan).
  final ScrollController _hourGridScrollController = ScrollController();

  static const double _kTimelineHourHeightMinPx = 120;
  static const double _kTimelineHourHeightMaxPx = 160;
  static const double _kTimelineRailWidthDesktopPx = 48;
  static const double _kTimelineRailWidthMobilePx = 28;
  static const double _kTimelineCompactBreakpoint = 600;

  bool _timelineCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _kTimelineCompactBreakpoint;

  double _timelineRailWidthPx(BuildContext context) =>
      _timelineCompactLayout(context)
          ? _kTimelineRailWidthMobilePx
          : _kTimelineRailWidthDesktopPx;

  List<TimeModeProjectedPlan> _cachedTimeModeProjections = const [];
  List<PlanTimeViewBlockLayout> _dragInsertLayoutsCache = const [];

  static const int _kTimelineDefaultBlockMinutes = 30;

  /// Duration-true timeline scale for the active Time-mode canvas build.
  PlanTimeViewDurationGrid? _activeTimelineDurationGrid;

  bool _timeModeDidAutoScrollToNow = false;

  /// Local preview height while dragging (intrinsic card height).
  double _timelineVerticalDragCardHeightPx = 0;

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
  TimeViewInsertionIntent? _timelineStoredInsertionIntent;

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

  static const double _kTimelineResizeHandlePx = 16;

  late final Ticker _hourGridEdgeScrollTicker;
  double _hourGridScrollVelocityPxPerSec = 0;
  Duration? _hourGridTickerElapsedLast;

  static const double _kShellBulkBarReservePx = 56;

  /// Pixels per second while the drag pointer sits in the top/bottom 10% bands.
  static const double _kHourGridEdgeScrollSpeedPxPerSec = 400;

  StreamSubscription<void>? _planningTimeSub;
  StreamSubscription<void>? _tagsCatalogSub;
  StreamSubscription<UserSettings>? _settingsSub;
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
  bool _quickAddTagsLoading = false;
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
      recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
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

  bool _planCanReorderTask(PlanningTask task) {
    final id = task.planRowIdForBackend;
    return !id.startsWith('optimistic-') && !id.startsWith('virt-');
  }

  void _commitPlanningReorder({
    required String mode,
    required PlanningTask moved,
    required int fromIndex,
    required int toIndex,
    required List<PlanningTask> withOrders,
    required List<PlanningTask> baselineBefore,
  }) {
    appDebugDiag(
      'PLAN_REORDER_REQUEST mode=$mode visibleCount=${withOrders.length} '
      'movedPlanId=${moved.planRowId ?? moved.planRowIdForBackend} '
      'from=$fromIndex to=$toIndex',
    );
    DatabaseService.instance.persistPlanningTaskOrder(
      withOrders,
      baselineBeforeReorder: baselineBefore,
    );
    setState(() => _dragOrder = null);
  }

  Stream<List<PlanningTask>> _createPlanningStream() =>
      DatabaseService.instance.planningStream(
        widget.selectedDate ?? _today,
        listenToGlobalPlanningRefresh:
            widget.isActivePlanningDay && widget.shellTabActive,
      );

  @override
  void initState() {
    super.initState();
    final persisted = DatabaseService.instance.getPlanActiveTabIndexOrNull();
    if (persisted != null) {
      _sortMode = _planSortModeFromPersistedIndex(persisted);
    }
    WidgetsBinding.instance.addObserver(this);
    _activeRecordingTitleNorm = DatabaseService
        .instance
        .cachedPrimaryRunningTitle
        ?.trim()
        .toLowerCase();
    final day = widget.selectedDate ?? _today;
    DatabaseService.instance.scrubJitVirtualPlansFromUserCache();
    _latestPlanningDayTasks = DatabaseService.instance
        .dedupePlanningTasksForDisplay(
          DatabaseService.instance.planningDayTasksSnapshot(day),
        );
    if (widget.isActivePlanningDay) {
      _planningStream = _createPlanningStream();
    }
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
    var lastTzOffset = DatabaseService.instance.settings.timezoneOffsetHours;
    var lastTzLabel = DatabaseService.instance.settings.preferredTimeZone;
    _settingsSub = DatabaseService.instance.userSettingsStream.listen((s) {
      if (!mounted) return;
      if (s.timezoneOffsetHours != lastTzOffset ||
          s.preferredTimeZone != lastTzLabel) {
        lastTzOffset = s.timezoneOffsetHours;
        lastTzLabel = s.preferredTimeZone;
        DatabaseService.instance.reprojectAllPlansForProfileTimezone();
        _timeModeDidAutoScrollToNow = false;
        setState(() {
          _planningStream = _createPlanningStream();
        });
      }
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
    if (_quickAddTagsLoading && _quickAddAvailableTags.isEmpty) {
      return const SizedBox.shrink();
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

  Future<void> _editCategoryDefaultPlanSchedule(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    final loc = currentLocale.value;
    final db = DatabaseService.instance;
    final rule = db.getCategoryRuleById(categoryId);
    final currentTime = db.sanitizeDefaultPlanTime(rule?.defaultPlanTime) ??
        db.effectiveDefaultPlanTimeForCategory(categoryId);
    var pickedTime = _timeOfDayFromHhmm(currentTime);
    var useProfileTz = db.usesProfileDefaultPlanTimezone(rule?.defaultPlanTimezone);
    var fixedIana = db.sanitizeDefaultPlanTimezone(rule?.defaultPlanTimezone) ??
        tz_settings.kCategoryDefaultTimezoneOptions.first.ianaId;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final profileTzLabel = db.profileTimezoneShortLabel();
            final timeLabel = _hhmmFromTimeOfDay(pickedTime);
            final fixedShort = tz_settings.shortLabelForCategoryDefaultTimezoneIana(
              fixedIana,
            );
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t(loc, 'plan_default_time_set'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t(loc, 'plan_default_time_field_time')),
                      subtitle: Text(timeLabel),
                      trailing: const Icon(Icons.schedule_rounded),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: pickedTime,
                          initialEntryMode: appTimePickerEntryMode(),
                        );
                        if (picked == null) return;
                        setSheetState(() => pickedTime = picked);
                      },
                    ),
                    Text(
                      t(loc, 'plan_default_time_field_timezone'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(
                            t(loc, 'plan_default_time_tz_profile')
                                .replaceFirst('%s', profileTzLabel),
                          ),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(t(loc, 'plan_default_time_tz_fixed')),
                        ),
                      ],
                      selected: {useProfileTz},
                      onSelectionChanged: (s) {
                        setSheetState(() => useProfileTz = s.first);
                      },
                    ),
                    if (!useProfileTz) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showSearch<String?>(
                            context: context,
                            delegate: _DefaultPlanTimezoneSearchDelegate(
                              loc: loc,
                              options: tz_settings.kCategoryDefaultTimezoneOptions,
                            ),
                          );
                          if (picked == null) return;
                          setSheetState(() => fixedIana = picked);
                        },
                        icon: const Icon(Icons.public_rounded),
                        label: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            '$fixedShort (${fixedIana.replaceAll('_', ' ')})',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppButton.primary(
                      label: t(loc, 'save'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (saved != true || !mounted) return;

    final result = await db.updateCategoryDefaultPlanSchedule(
      categoryId,
      _hhmmFromTimeOfDay(pickedTime),
      useProfileTz ? null : fixedIana,
    );
    if (!mounted) return;
    if (!result.ok) {
      if (result.timezoneFieldMissing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(loc, 'plan_default_timezone_field_missing')),
          ),
        );
      } else {
        AppSnack.failed();
      }
      return;
    }
    setState(() {});
    modalSetState?.call(() {});
  }

  Future<void> _setCategoryDefaultPlanTime(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    await _editCategoryDefaultPlanSchedule(categoryId, modalSetState);
  }

  Future<void> _clearCategoryDefaultPlanTime(
    int categoryId,
    void Function(void Function())? modalSetState,
  ) async {
    final result = await DatabaseService.instance.updateCategoryDefaultPlanSchedule(
      categoryId,
      null,
      null,
    );
    if (!mounted) return;
    if (!result.ok) {
      if (result.timezoneFieldMissing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(currentLocale.value, 'plan_default_timezone_field_missing')),
          ),
        );
      } else {
        AppSnack.failed();
      }
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
                : db.effectiveDefaultPlanScheduleForCategory(
                    selectedCategoryId!,
                  );
            String statusText({
              required String? own,
              required String? ownTz,
              required ({String? hhmm, String? timezoneIana, int? sourceCategoryId})?
                  effective,
            }) {
              if (own != null) {
                return t(loc, 'plan_default_time_own').replaceFirst(
                  '%s',
                  db.formatDefaultPlanTimeWithTimezoneLabel(own, ownTz),
                );
              }
              if (effective?.hhmm != null) {
                return t(loc, 'plan_default_time_inherited').replaceFirst(
                  '%s',
                  db.formatDefaultPlanTimeWithTimezoneLabel(
                    effective!.hhmm!,
                    effective.timezoneIana,
                  ),
                );
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
                    const SizedBox(height: 4),
                    Text(
                      t(loc, 'plan_default_times_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(loc, 'plan_default_times_profile_tz_notice').replaceFirst(
                        '%s',
                        db.profileTimezoneShortLabel(),
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                                      ownTz: selectedRule?.defaultPlanTimezone,
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
                                final rule = db.getCategoryRuleById(pair.id);
                                final own = db.sanitizeDefaultPlanTime(
                                  rule?.defaultPlanTime,
                                );
                                final subtitle = own != null
                                    ? db.formatDefaultPlanTimeWithTimezoneLabel(
                                        own,
                                        rule?.defaultPlanTimezone,
                                      )
                                    : '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    pair.path,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(subtitle),
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
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(t(loc, 'tag_default_durations_title')),
                    subtitle: Text(
                      t(loc, 'tag_default_durations_sheet_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const TagSettingsHub(
                            initialTabIndex: 2,
                          ),
                        ),
                      );
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
        if (widget.isActivePlanningDay) {
          _planningStream = _createPlanningStream();
        }
        _latestPlanningDayTasks = DatabaseService.instance
            .dedupePlanningTasksForDisplay(
              DatabaseService.instance.planningDayTasksSnapshot(
                widget.selectedDate ?? _today,
              ),
            );
        if (oldWidget.selectedDate != widget.selectedDate ||
            oldWidget.selectedDateString != widget.selectedDateString) {
          _optimisticTasks.clear();
          _planDoneOverride.clear();
          _clearAllPlanCompletionHolds();
          _dragOrder = null;
          _selectedPlanKeys.clear();
          _planSelectMode = false;
          _sortMode = _PlanSortMode.custom;
          _timeViewCascadeNormalizedDayKey = null;
        }
      });
      _syncPlanningShellFabBulkReserve();
    }
  }

  @override
  void dispose() {
    _clearAllPlanCompletionHolds();
    _planningTimeSub?.cancel();
    _tagsCatalogSub?.cancel();
    _settingsSub?.cancel();
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
      if (_sortTreatAsDone(a) != _sortTreatAsDone(b)) {
        return _sortTreatAsDone(a) ? 1 : -1;
      }
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return merged;
  }

  /// Done for display uses override; done for sort can be held during completion moment.
  bool _sortTreatAsDone(PlanningTask task) {
    final key = _planKey(task);
    if (_planCompletionHoldKeys.contains(key)) return false;
    final override = _planDoneOverride[key];
    if (override != null) return override;
    return task.isDone;
  }

  void _clearAllPlanCompletionHolds() {
    for (final timer in _planCompletionHoldTimers.values) {
      timer.cancel();
    }
    _planCompletionHoldTimers.clear();
    _planCompletionHoldKeys.clear();
    _planReorderSettleKeys.clear();
  }

  void _cancelPlanCompletionHold(String key) {
    _planCompletionHoldTimers.remove(key)?.cancel();
    _planCompletionHoldKeys.remove(key);
    _planReorderSettleKeys.remove(key);
  }

  void _beginPlanCompletionHold(String key) {
    _planCompletionHoldTimers.remove(key)?.cancel();
    _planCompletionHoldKeys.add(key);
    _planCompletionHoldTimers[key] = Timer(_kPlanCompletionHoldDuration, () {
      if (!mounted) return;
      _planCompletionHoldTimers.remove(key);
      if (!_planCompletionHoldKeys.remove(key)) return;
      setState(() => _planReorderSettleKeys.add(key));
      Timer(_kPlanReorderSettleDuration, () {
        if (!mounted) return;
        setState(() => _planReorderSettleKeys.remove(key));
      });
    });
  }

  List<PlanningTask> _displayTasks(List<PlanningTask> server) {
    final dayKey = widget.selectedDateString.length >= 10
        ? widget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final merged = DatabaseService.instance.dedupePlanningTasksForDisplay(
      _mergeWithOptimistic(server),
      traceSource: 'ui',
      dayKey: dayKey,
    );
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

  void _maybeShowPlanScheduleOverloadWarning({
    required List<PlanningTask> dayPlans,
  }) {
    final report = DatabaseService.instance.evaluatePlanDayScheduleOverload(
      dayPlans: dayPlans,
      timelineStartHour: _timelineHourStart,
      timelineEndHour: _timelineHourEnd,
    );
    if (!report.shouldWarn) return;
    AppSnack.warning(t(currentLocale.value, 'plan_schedule_overload_warning'));
  }

  Future<void> _addTask() async {
    final taskDateKey = widget.selectedDateString;
    final raw = _textController.text;
    final baseDay = widget.selectedDate ?? _today;
    final wallDay = DateTime(baseDay.year, baseDay.month, baseDay.day);

    final range = SmartInputParser.parseTitleForTimeRange(raw);
    SmartTimeParseResult? parsed;
    final title = SmartInputParser.preservedTitleFromRaw(raw);
    if (title.isEmpty) return;

    if (range == null) {
      parsed = SmartInputParser.parseTitleForScheduledTime(raw);
    }

    final match = DatabaseService.instance.identifyCategory(title);
    final categoryId =
        match?.id ??
        widget.selectedCategoryId ??
        DatabaseService.instance.defaultCategoryId ??
        (DatabaseService.instance.rules.isNotEmpty
            ? DatabaseService.instance.rules.first.id
            : 0);
    final tagsForCreate = List<Tag>.from(_creationSelectedTags);
    final existingDay = [
      ..._latestPlanningDayTasks,
      ..._optimisticTasks.where(
        (t) => t.dateKey == taskDateKey || t.startTime != null,
      ),
    ];
    final explicitStartWall = range != null
        ? range.startWallOn(wallDay)
        : parsed?.wallDateTimeOn(wallDay);
    final explicitEndWall = range?.endWallOn(wallDay);
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: wallDay,
      categoryId: categoryId,
      tags: tagsForCreate,
      existingDayPlans: existingDay,
      explicitStartWall: explicitStartWall,
      explicitEndWall: explicitEndWall,
      hasExplicitTimeRange: range != null,
      timelineDayStartHour: _timelineHourStart,
    );
    var nextOrder = _nextPlanOrderForQuickAdd();
    final clientPlanId = DatabaseService.newClientUuid();
    if (_planQuickAddInFlight) return;
    _planQuickAddInFlight = true;
    unawaited(() async {
      try {
        final ok = await DatabaseService.instance.addPlanningTask(
          DatabaseService.instance.planningTaskWithAutoSchedule(
            PlanningTask(
              id: 0,
              title: title,
              categoryId: categoryId,
              isDone: false,
              dateKey: taskDateKey,
              order: nextOrder,
              checklist: const [],
              parentPlanId: null,
              tags: tagsForCreate,
              isSynced: false,
            ),
            schedule,
          ),
          clientPlanId: clientPlanId,
        );
        if (!mounted) return;
        if (ok) {
          _textController.clear();
          setState(() {
            _creationSelectedTags = [];
          });
          final displayWalls =
              DatabaseService.instance.profileDisplayWallsFromAutoSchedule(
            schedule,
          );
          _maybeShowPlanScheduleOverloadWarning(
            dayPlans: [
              ...existingDay,
              PlanningTask(
                id: 0,
                title: title,
                categoryId: categoryId,
                isDone: false,
                dateKey: taskDateKey,
                order: nextOrder,
                startTime: displayWalls.startWall,
                endDateTime: displayWalls.endWall,
                tags: tagsForCreate,
              ),
            ],
          );
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

  /// Smart Plan: append AI-parsed tasks sequentially on [widget.selectedDateString].
  Future<int> _injectSmartPlanTasks(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return 0;
    final taskDateKey = widget.selectedDateString;
    final baseDay = widget.selectedDate ?? _today;
    final wallDay = DateTime(baseDay.year, baseDay.month, baseDay.day);

    var nextOrder = _nextPlanOrderForQuickAdd();
    var cursorPlans = [
      ..._latestPlanningDayTasks,
      ..._optimisticTasks.where(
        (t) => t.dateKey == taskDateKey || t.startTime != null,
      ),
    ];

    var created = 0;
    PlanningTask? lastCreated;
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      final title = (m['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final durRaw = m['durationMinutes'];
      int? explicitDuration;
      if (durRaw != null) {
        explicitDuration = durRaw is int
            ? durRaw
            : (durRaw is num
                ? durRaw.round()
                : int.tryParse('$durRaw'));
        if (explicitDuration != null && explicitDuration < 1) {
          explicitDuration = null;
        }
      }

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

      final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
        wallDay: wallDay,
        categoryId: categoryId,
        tags: const [],
        existingDayPlans: cursorPlans,
        timelineDayStartHour: _timelineHourStart,
        explicitDurationMinutes: explicitDuration,
      );

      final order = nextOrder + i;
      final clientPlanId = DatabaseService.newClientUuid();

      try {
        final ok = await DatabaseService.instance.addPlanningTask(
          DatabaseService.instance.planningTaskWithAutoSchedule(
            PlanningTask(
              id: 0,
              title: title,
              categoryId: categoryId,
              isDone: false,
              dateKey: taskDateKey,
              order: order,
              checklist: const [],
              parentPlanId: null,
              tags: const [],
              isSynced: false,
            ),
            schedule,
          ),
          clientPlanId: clientPlanId,
        );
        if (!mounted) return created;
        if (ok) {
          created++;
          lastCreated = PlanningTask(
            id: 0,
            title: title,
            categoryId: categoryId,
            isDone: false,
            dateKey: taskDateKey,
            order: order,
            startTime: schedule.startWall,
            endDateTime: schedule.endWall,
            tags: const [],
          );
          cursorPlans = [...cursorPlans, lastCreated];
        }
      } catch (_) {}
    }
    if (created > 0 && lastCreated != null) {
      _maybeShowPlanScheduleOverloadWarning(dayPlans: cursorPlans);
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
    setState(() {
      _planDoneOverride[key] = next;
      if (next) {
        _beginPlanCompletionHold(key);
      } else {
        _cancelPlanCompletionHold(key);
      }
    });
    try {
      final ok = await DatabaseService.instance.updatePlanningTask(
        task.planRowIdForBackend,
        planBusinessId: task.planRowId,
        isDone: next,
        recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _planDoneOverride.remove(key);
          _cancelPlanCompletionHold(key);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        setState(() {
          _planDoneOverride.remove(key);
          _cancelPlanCompletionHold(key);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  int _taskSortCmp(PlanningTask a, PlanningTask b) {
    if (_sortTreatAsDone(a) != _sortTreatAsDone(b)) {
      return _sortTreatAsDone(a) ? 1 : -1;
    }
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
      final ap = DatabaseService.instance.projectPlanForTimeMode(a);
      final bp = DatabaseService.instance.projectPlanForTimeMode(b);
      if (ap == null && bp == null) return _taskSortCmp(a, b);
      if (ap == null) return 1;
      if (bp == null) return -1;
      final ca = _planningClockOrderMinutes(ap.profileWallStart, dayStartHour);
      final cb = _planningClockOrderMinutes(bp.profileWallStart, dayStartHour);
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

  PlanCard _planningTaskCardForRow(
    PlanningTask task,
    String key,
    bool displayDone,
    bool isSelected, {
    required bool highlightAsRunning,
    bool omitLongPress = false,
    required Map<String, int> planActualByPbId,
    bool timelineBlock = false,
    bool timelineInteracting = false,
    bool timelineScheduleConflict = false,
    String? timelineTimeLabel,
    double? timelineBlockHeightPx,
  }) {
    final pbId = DatabaseService.pocketRelationIdOrNull(task.pocketRecordId);
    final tracked = pbId != null ? (planActualByPbId[pbId] ?? 0) : 0;
    final estimate = PlanServiceExtension.planningWallEstimateSeconds(task);
    return PlanCard(
      task: task,
      planTrackedSeconds: tracked,
      planEstimatedSeconds: estimate,
      displayIsDone: displayDone,
      selectMode: _planSelectMode,
      isSelected: isSelected,
      highlightAsRunning: highlightAsRunning,
      timelineBlock: timelineBlock,
      timelineInteracting: timelineInteracting,
      timelineScheduleConflict: timelineScheduleConflict,
      timelineTimeLabel: timelineTimeLabel,
      timelineBlockHeightPx: timelineBlockHeightPx,
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
    final proj = DatabaseService.instance.projectPlanForTimeMode(task);
    if (proj != null) return proj.durationMinutes;
    return _kTimelineDefaultBlockMinutes;
  }

  /// ~1.5× normal CardPlan height; base hour band before per-hour stretch.
  double _timelineHourHeightPx() => PlanTimeViewLayoutCalculator.baseHourHeightPx();

  double _computeTimelinePxPerMinute(List<TimeModeProjectedPlan> projections) {
    return _timelineHourHeightPx() / 60.0;
  }

  double _timelineCanvasHeightPx(PlanTimeViewDurationGrid grid) =>
      grid.totalHeightPx;

  ({
    double startMin,
    double endMin,
  }) _timelineSpanMinutesFromProjection(
    TimeModeProjectedPlan proj,
    int rangeStart,
    int rangeEnd,
  ) {
    final startMin = _timelineMinutesFromRangeStart(
      proj.profileWallStart,
      rangeStart,
      rangeEnd,
    );
    final endMin = proj.profileWallEnd != null
        ? _timelineMinutesFromRangeStart(
            proj.profileWallEnd!,
            rangeStart,
            rangeEnd,
          )
        : startMin + proj.durationMinutes;
    return (startMin: startMin, endMin: endMin);
  }

  ({
    PlanTimeViewDurationGrid grid,
    List<PlanTimeViewBlockLayout> layouts,
  }) _computeTimelineDurationLayout(
    List<TimeModeProjectedPlan> projections,
    int rangeStart,
    int rangeEnd,
    String selectedDayKey,
  ) {
    return PerfDiag.instance.perfBlock(
      'Planning._computeTimelineDurationLayout',
      () {
        final visibleHours = PlanningSheetTimelinePrefs.visibleHoursOrdered(
          rangeStart,
          rangeEnd,
        );
        if (kVerbosePlanTimeTzProjectionLogs && !kReleaseMode) {
          for (final proj in projections) {
            DatabaseService.instance.logTimeTzProjectForTimeMode(
              proj,
              selectedDay: selectedDayKey,
              visible: true,
            );
          }
        }
        final result = PlanTimeViewLayoutCalculator.compute(
          projections: projections,
          visibleHours: visibleHours,
          rangeStart: rangeStart,
          baseHourHeightPx: _timelineHourHeightPx(),
          startMinOf: (proj) => _timelineSpanMinutesFromProjection(
            proj,
            rangeStart,
            rangeEnd,
          ).startMin,
          endMinOf: (proj) => _timelineSpanMinutesFromProjection(
            proj,
            rangeStart,
            rangeEnd,
          ).endMin,
        );
        for (final layout in result.layouts) {
          final proj = layout.projection;
          if (proj == null) continue;
          final span = _timelineSpanMinutesFromProjection(
            proj,
            rangeStart,
            rangeEnd,
          );
          final hourIdx = result.grid.hourIndexForMinutesFromRangeStart(
            span.startMin,
          );
          _logTimeDurationLayout(
            proj: proj,
            startMinute: span.startMin.round(),
            endMinute: span.endMin.round(),
            durationMin: math.max(5, (span.endMin - span.startMin).round()),
            pxPerMinute: result.grid.pxPerMinuteAtHourIndex(hourIdx),
            topPx: layout.topPx,
            heightPx: layout.heightPx,
          );
        }
        return result;
      },
      meta: {'projections': projections.length},
    );
  }

  List<PlanTimeViewBlockLayout> _timelineBlockLayouts(
    List<TimeModeProjectedPlan> projections,
    int rangeStart,
    int rangeEnd,
    String selectedDayKey,
  ) {
    final result = _computeTimelineDurationLayout(
      projections,
      rangeStart,
      rangeEnd,
      selectedDayKey,
    );
    _activeTimelineDurationGrid = result.grid;
    return result.layouts;
  }

  String? _lastTimeDurationLayoutLogKey;
  DateTime? _lastTimeDurationLayoutLogAt;
  String? _lastTimeModeRailLogKey;
  DateTime? _lastTimeModeRailLogAt;
  String? _lastTimeResizePreviewLogKey;
  DateTime? _lastTimeResizePreviewLogAt;
  static const Duration _timeModeLogDebounce = Duration(seconds: 8);

  String _timelineLogWallIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T'
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _maybeNormalizeTimeViewOverlapsOnce(
    DateTime planWallDay,
    List<PlanningTask> schedulable,
  ) {
    if (_sortMode != _PlanSortMode.time) return;
    final dayKey = '${planWallDay.year}-'
        '${planWallDay.month.toString().padLeft(2, '0')}-'
        '${planWallDay.day.toString().padLeft(2, '0')}';
    if (_timeViewCascadeNormalizedDayKey == dayKey) return;
    _timeViewCascadeNormalizedDayKey = dayKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sortMode != _PlanSortMode.time) return;
      DatabaseService.instance.applySequentialTimeViewCascadeIfNeeded(
        wallDay: planWallDay,
        scheduledSubset: schedulable,
      );
      if (mounted) setState(() {});
    });
  }

  void _logTimeDurationLayout({
    required TimeModeProjectedPlan proj,
    required int startMinute,
    required int endMinute,
    required int durationMin,
    required double pxPerMinute,
    required double topPx,
    required double heightPx,
  }) {
    final planId = proj.planId;
    final lineKey =
        '$planId|$startMinute|$endMinute|${topPx.toStringAsFixed(1)}|${heightPx.toStringAsFixed(1)}';
    final now = DateTime.now();
    if (_lastTimeDurationLayoutLogKey == lineKey &&
        _lastTimeDurationLayoutLogAt != null &&
        now.difference(_lastTimeDurationLayoutLogAt!) < _timeModeLogDebounce) {
      return;
    }
    _lastTimeDurationLayoutLogKey = lineKey;
    _lastTimeDurationLayoutLogAt = now;
    appDebugDiag(
      'TIME_DURATION_LAYOUT planId=${planId.isEmpty ? '-' : planId} '
      'profileTz=${DatabaseService.instance.profileTimezoneShortLabel()} '
      'wallStart=${_timelineLogWallIso(proj.profileWallStart)} '
      'wallEnd=${proj.profileWallEnd != null ? _timelineLogWallIso(proj.profileWallEnd!) : '-'} '
      'label=${proj.plannedTimeLabel} '
      'startMinute=$startMinute endMinute=$endMinute durationMin=$durationMin '
      'pxPerMinute=${pxPerMinute.toStringAsFixed(3)} '
      'top=${topPx.toStringAsFixed(1)} height=${heightPx.toStringAsFixed(1)}',
    );
  }

  void _logTimeResizePreview({
    required String planId,
    required String edge,
    required double pointerY,
    required int minute,
    required int snapped,
    required DateTime newStart,
    required DateTime? newEnd,
    required int durationMin,
  }) {
    final lineKey = '$planId|$edge|$snapped|$durationMin';
    final now = DateTime.now();
    if (_lastTimeResizePreviewLogKey == lineKey &&
        _lastTimeResizePreviewLogAt != null &&
        now.difference(_lastTimeResizePreviewLogAt!) < _timeModeLogDebounce) {
      return;
    }
    _lastTimeResizePreviewLogKey = lineKey;
    _lastTimeResizePreviewLogAt = now;
    appDebugDiag(
      'TIME_RESIZE_PREVIEW planId=${planId.isEmpty ? '-' : planId} '
      'edge=$edge pointerY=${pointerY.toStringAsFixed(1)} '
      'minute=$minute snapped=$snapped '
      'newStart=${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')} '
      'newEnd=${newEnd != null ? '${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}' : '-'} '
      'durationMin=$durationMin',
    );
  }

  void _logTimeModeRail({
    required DateTime selectedDay,
    required List<int> visibleHours,
  }) {
    final dayStr =
        '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
    final lineKey = '$dayStr|${visibleHours.join(',')}';
    final now = DateTime.now();
    if (_lastTimeModeRailLogKey == lineKey &&
        _lastTimeModeRailLogAt != null &&
        now.difference(_lastTimeModeRailLogAt!) < _timeModeLogDebounce) {
      return;
    }
    _lastTimeModeRailLogKey = lineKey;
    _lastTimeModeRailLogAt = now;
    appDebugDiag(
      'TIME_MODE_RAIL profileTz=${DatabaseService.instance.profileTimezoneShortLabel()} '
      'selectedDay=$dayStr visibleHours=${visibleHours.join(',')}',
    );
  }

  bool _isProfileTodaySelectedForPlanning() {
    final profileTodayKey =
        DatabaseService.instance.getProjectedTodayDateKey();
    final raw = widget.selectedDateString.trim();
    if (raw.length >= 10) {
      return raw.substring(0, 10) == profileTodayKey;
    }
    final planDay = widget.selectedDate ?? _today;
    final profileToday = DatabaseService.instance.getProjectedToday();
    return planDay.year == profileToday.year &&
        planDay.month == profileToday.month &&
        planDay.day == profileToday.day;
  }

  String? _lastPlanTimeNowLineLogKey;
  DateTime? _lastPlanTimeNowLineLogAt;
  static const Duration _planTimeNowLineLogDebounce = Duration(seconds: 8);

  void _logPlanTimeNowLine({
    required DateTime nowUtc,
    required DateTime wallNow,
    required String selectedDay,
    required bool visible,
    required double? yPx,
    required double pxPerMinute,
  }) {
    final lineKey =
        '$selectedDay|${wallNow.hour}:${wallNow.minute}|visible=$visible|y=${yPx?.toStringAsFixed(1) ?? '-'}';
    final now = DateTime.now();
    if (_lastPlanTimeNowLineLogKey == lineKey &&
        _lastPlanTimeNowLineLogAt != null &&
        now.difference(_lastPlanTimeNowLineLogAt!) <
            _planTimeNowLineLogDebounce) {
      return;
    }
    _lastPlanTimeNowLineLogKey = lineKey;
    _lastPlanTimeNowLineLogAt = now;
    appDebugDiag(
      'TIME_NOW_LINE visible=$visible '
      'profileTz=${DatabaseService.instance.profileTimezoneShortLabel()} '
      'nowMinute=${wallNow.hour * 60 + wallNow.minute} '
      'y=${yPx?.toStringAsFixed(1) ?? '-'} '
      'pxPerMinute=${pxPerMinute.toStringAsFixed(3)} '
      'selectedDay=$selectedDay',
    );
  }

  DateTime _profileWallNow() =>
      DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());

  double? _timelineNowLineTopPx(
    int rangeStart,
    int rangeEnd,
    PlanTimeViewDurationGrid grid,
  ) {
    final selectedDay = widget.selectedDateString.length >= 10
        ? widget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final minProbe = _timelineMinutesFromRangeStart(
      _profileWallNow(),
      rangeStart,
      rangeEnd,
    );
    final ppm = grid.pxPerMinuteAtHourIndex(
      grid.hourIndexForMinutesFromRangeStart(minProbe.toDouble()),
    );
    if (!_isProfileTodaySelectedForPlanning()) {
      _logPlanTimeNowLine(
        nowUtc: DatabaseService.getPlanetaryNow(),
        wallNow: _profileWallNow(),
        selectedDay: selectedDay,
        visible: false,
        yPx: null,
        pxPerMinute: ppm,
      );
      return null;
    }
    final nowUtc = DatabaseService.getPlanetaryNow();
    final wallNow = _profileWallNow();
    final min = _timelineMinutesFromRangeStart(wallNow, rangeStart, rangeEnd);
    if (min < 0 || min > grid.totalMinutes) {
      _logPlanTimeNowLine(
        nowUtc: nowUtc,
        wallNow: wallNow,
        selectedDay: selectedDay,
        visible: false,
        yPx: null,
        pxPerMinute: ppm,
      );
      return null;
    }
    final y = grid.yForMinutesFromRangeStart(min.toDouble());
    _logPlanTimeNowLine(
      nowUtc: nowUtc,
      wallNow: wallNow,
      selectedDay: selectedDay,
      visible: true,
      yPx: y,
      pxPerMinute: ppm,
    );
    return y;
  }

  void _maybeAutoScrollTimelineToNow(double nowTopPx, double canvasHeight) {
    if (!_isProfileTodaySelectedForPlanning()) return;
    if (_timeModeDidAutoScrollToNow) return;
    if (!_hourGridScrollController.hasClients) return;
    _timeModeDidAutoScrollToNow = true;
    final viewport = MediaQuery.sizeOf(context).height * 0.45;
    final target = (nowTopPx - viewport * 0.35).clamp(
      0.0,
      math.max(0.0, _hourGridScrollController.position.maxScrollExtent),
    ).toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hourGridScrollController.hasClients) return;
      _hourGridScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static const double _kTimelineBlockHorizontalPadPx = 8;

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

  ({int startMin, int endMin}) _timelineStartEndMinutesFromTask(
    PlanningTask task,
    int rangeStart,
    int rangeEnd,
  ) {
    final proj = DatabaseService.instance.projectPlanForTimeMode(task);
    if (proj == null) {
      return (startMin: 0, endMin: _kTimelineDefaultBlockMinutes);
    }
    final span = _timelineSpanMinutesFromProjection(proj, rangeStart, rangeEnd);
    return (startMin: span.startMin.round(), endMin: span.endMin.round());
  }

  void _clearTimelineInteractionState() {
    _timelineVerticalDragPlanKey = null;
    _timelineVerticalDragDeltaPx = 0;
    _timelineVerticalDragTask = null;
    _timelineVerticalDragTimeLabel = null;
    _timelineDragInsertTargetKey = null;
    _timelineDragInsertBefore = false;
    _timelineDragInsertMarkerTopPx = null;
    _timelineStoredInsertionIntent = null;
    _timelineResizePlanKey = null;
    _timelineResizeEdge = null;
    _timelineResizeTask = null;
    _timelineResizeTimeLabel = null;
    _setTimelineInteractionLock(false);
  }

  void _setTimelineInteractionLock(bool locked) {
    if (_timelineScrollLocked != locked) {
      setState(() => _timelineScrollLocked = locked);
    }
    widget.onDatePagerLockChanged?.call(locked);
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
      _setTimelineInteractionLock(true);
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
    final grid = _activeTimelineDurationGrid;
    if (grid == null) return;
    final minDur = PlanningSheetTimelinePrefs.timelineMinDurationMinutes;
    final maxEndMin = _timelineMaxVisibleMinutes(rangeStart, rangeEnd);

    double heightForSpan(int start, int end) {
      final top = grid.yForMinutesFromRangeStart(start.toDouble());
      final bottom = grid.yForMinutesFromRangeStart(end.toDouble());
      return math.max(bottom - top, kPlanTimeCardMinHeightPx);
    }

    var previewTop = _timelineResizeOriginTopPx;
    var previewHeight = _timelineResizeOriginHeightPx;
    var startMin = _timelineResizeOriginStartMin;
    var endMin = _timelineResizeOriginEndMin;

    if (edge == _TimelineResizeEdge.top) {
      final fixedEndMin = _timelineResizeOriginEndMin;
      final maxTopForDur = grid.yForMinutesFromRangeStart(
        math.max(0, fixedEndMin - minDur).toDouble(),
      );
      previewTop = (_timelineResizeOriginTopPx + deltaPx).clamp(
        0.0,
        maxTopForDur,
      );
      startMin = _snapTimelineMinutes(grid.minutesFromY(previewTop)).round();
      endMin = fixedEndMin;
      if (endMin - startMin < minDur) {
        startMin = endMin - minDur;
      }
      if (startMin < 0) {
        startMin = 0;
        endMin = math.max(endMin, minDur);
      }
      previewTop = grid.yForMinutesFromRangeStart(startMin.toDouble());
      previewHeight = heightForSpan(startMin, endMin);
    } else {
      previewTop = _timelineResizeOriginTopPx;
      startMin = _timelineResizeOriginStartMin;
      final originBottom = _timelineResizeOriginTopPx + _timelineResizeOriginHeightPx;
      final minBottom = grid.yForMinutesFromRangeStart(
        (startMin + minDur).toDouble(),
      );
      final newBottom = (originBottom + deltaPx).clamp(
        minBottom,
        grid.totalHeightPx,
      );
      endMin = _snapTimelineMinutes(grid.minutesFromY(newBottom)).round();
      if (endMin > maxEndMin) endMin = maxEndMin;
      if (endMin - startMin < minDur) endMin = startMin + minDur;
      previewHeight = heightForSpan(startMin, endMin);
    }

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
    _logTimeResizePreview(
      planId: _timelineResizeTask?.planRowIdForBackend ?? '-',
      edge: edge == _TimelineResizeEdge.top ? 'top' : 'bottom',
      pointerY: previewTop + previewHeight,
      minute: grid.minutesFromY(previewTop + previewHeight).round(),
      snapped: edge == _TimelineResizeEdge.top ? startMin : endMin,
      newStart: newStartWall,
      newEnd: newEndWall,
      durationMin: endMin - startMin,
    );

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
    final grid = _activeTimelineDurationGrid;
    if (grid == null) {
      _cancelTimelineResize();
      return;
    }
    final startMin = _snapTimelineMinutes(
      grid.minutesFromY(_timelineResizePreviewTopPx),
    ).round();
    final endMin = _snapTimelineMinutes(
      grid.minutesFromY(
        _timelineResizePreviewTopPx + _timelineResizePreviewHeightPx,
      ),
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
        recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
      ),
    );
  }

  void _persistTimelineDragWithCascade({
    required PlanningTask movedTask,
    required DateTime newStartWall,
    required DateTime? newEndWall,
    required List<PlanningTask> scheduledInRange,
    required int rangeStart,
    required int rangeEnd,
    required DateTime planWallDay,
    TimeViewInsertionIntent? insertionIntent,
    String? commitSource,
    double? rawYMinutesForTrace,
  }) {
    final movedKey = _planKey(movedTask);
    final List<PlanningTask> resolved;
    final List<String> orderBefore;
    final List<String> orderAfter;

    if (insertionIntent != null) {
      final result = DatabaseService.instance.applyTimeViewTargetInsertion(
        scheduledInRange,
        insertionIntent,
      );
      resolved = result.cascaded;
      orderBefore = result.orderBefore;
      orderAfter = result.orderAfter;
      newStartWall = result.draggedStartWall;
      newEndWall = result.draggedEndWall;
    } else {
      orderBefore = scheduledInRange.map(_planKey).toList();
      final movedUpdated = movedTask.copyWith(
        startTime: newStartWall,
        endDateTime: newEndWall,
        clearEnd: newEndWall == null,
      );
      final merged = scheduledInRange
          .map(
            (t) => _planKey(t) == movedKey ? movedUpdated : t,
          )
          .toList(growable: false);
      resolved = DatabaseService.instance.normalizeSequentialPlanTimesForDay(
        merged,
      );
      orderAfter = resolved.map(_planKey).toList();
    }

    final patchParts = <String>[];
    for (final task in resolved) {
      final key = _planKey(task);
      final before = key == movedKey
          ? movedTask
          : _timelineTaskByPlanKey(scheduledInRange, key);
      if (before == null) continue;
      if (before.startTime == task.startTime &&
          before.endDateTime == task.endDateTime) {
        continue;
      }
      final s = task.startTime;
      final e = task.endDateTime;
      if (s != null) {
        patchParts.add(
          '${task.planRowIdForBackend}:'
          '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}-'
          '${e != null ? '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}' : 'open'}',
        );
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
          recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
        ),
      );
    }

    timeDropTrace(
      'phase=commit source=${commitSource ?? 'unknown'} '
      'rawYMinutes=${rawYMinutesForTrace?.toStringAsFixed(1) ?? 'n/a'} '
      'targetStart=${insertionIntent?.targetStartWall.hour}:${insertionIntent?.targetStartWall.minute.toString().padLeft(2, '0') ?? 'n/a'} '
      'targetEnd=${insertionIntent?.targetEndWall.hour}:${insertionIntent?.targetEndWall.minute.toString().padLeft(2, '0') ?? 'n/a'} '
      'finalStart=${newStartWall.hour}:${newStartWall.minute.toString().padLeft(2, '0')} '
      'finalEnd=${newEndWall != null ? '${newEndWall.hour}:${newEndWall.minute.toString().padLeft(2, '0')}' : 'open'}',
    );
    timeDropTrace('explicitOrderBefore=$orderBefore');
    timeDropTrace('explicitOrderAfter=$orderAfter');
    timeDropTrace('patches=[${patchParts.join('](')}]');

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

  PlanTimeViewBlockLayout? _timelineLayoutUnderDragCenter({
    required List<PlanTimeViewBlockLayout> layouts,
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

  ({PlanTimeViewBlockLayout layout, bool insertBefore})?
  _timelineResolveDragInsertTarget({
    required List<PlanTimeViewBlockLayout> layouts,
    required double dragCenterY,
    required String? excludePlanKey,
  }) {
    final layout = _timelineLayoutUnderDragCenter(
      layouts: layouts,
      dragCenterY: dragCenterY,
      excludePlanKey: excludePlanKey,
    );
    if (layout == null) return null;
    final mid = layout.topPx + layout.heightPx / 2;
    return (layout: layout, insertBefore: dragCenterY < mid);
  }

  TimeViewInsertionIntent? _timelineInsertionIntentFromLayout({
    required PlanTimeViewBlockLayout layout,
    required bool insertBefore,
    required String draggedPlanId,
    required int draggedDurationMin,
    required bool draggedHadEnd,
  }) {
    final proj = layout.projection ??
        DatabaseService.instance.projectPlanForTimeMode(layout.task);
    final targetStart = proj?.profileWallStart;
    if (proj == null || targetStart == null) return null;
    final targetEnd = proj.profileWallEnd ??
        targetStart.add(Duration(minutes: proj.durationMinutes));
    return TimeViewInsertionIntent(
      draggedPlanId: draggedPlanId,
      targetPlanId: layout.task.planRowIdForBackend,
      insertPosition: insertBefore
          ? TimeViewInsertPosition.before
          : TimeViewInsertPosition.after,
      targetStartWall: targetStart,
      targetEndWall: targetEnd,
      draggedDurationMinutes: draggedDurationMin,
      draggedHadEnd: draggedHadEnd,
    );
  }

  TimeViewTargetDropSchedule? _timelineTargetDropScheduleForLayout({
    required PlanTimeViewBlockLayout layout,
    required bool insertBefore,
    required int draggedDurationMin,
    required bool draggedHadEnd,
  }) {
    final proj = layout.projection ??
        DatabaseService.instance.projectPlanForTimeMode(layout.task);
    final targetStart = proj?.profileWallStart;
    if (proj == null || targetStart == null) return null;
    final targetEnd = proj.profileWallEnd ??
        targetStart.add(Duration(minutes: proj.durationMinutes));
    return computeTimeViewTargetDropSchedule(
      targetStartWall: targetStart,
      targetEndWall: targetEnd,
      draggedDurationMinutes: draggedDurationMin,
      insertBefore: insertBefore,
      draggedHadEnd: draggedHadEnd,
    );
  }

  double _timelinePreviewTopPxForStartWall({
    required DateTime startWall,
    required PlanTimeViewDurationGrid grid,
    required int rangeStart,
    required int rangeEnd,
    required double maxTopPx,
  }) {
    final startMin = _timelineMinutesFromRangeStart(
      startWall,
      rangeStart,
      rangeEnd,
    );
    return grid.yForMinutesFromRangeStart(startMin).clamp(0.0, maxTopPx);
  }

  List<PlanTimeViewBlockLayout> _timelineDragLayoutsForDay({
    required int rangeStart,
    required int rangeEnd,
    required String selectedDayKey,
  }) {
    if (PerfFlags.enableTimelineProjectionCache &&
        _dragInsertLayoutsCache.isNotEmpty) {
      return _dragInsertLayoutsCache;
    }
    return _timelineBlockLayouts(
      _cachedTimeModeProjections,
      rangeStart,
      rangeEnd,
      selectedDayKey,
    );
  }

  String? _timelineDragLabelForTopPx(
    double topPx,
    DateTime planWallDay,
    int rangeStart,
    int durationMin,
    bool hadEnd,
  ) {
    final grid = _activeTimelineDurationGrid;
    final startMin = grid?.minutesFromY(topPx) ?? topPx;
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
    required double originCardHeightPx,
    required int durationMin,
    required bool hadEnd,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required String selectedDayKey,
  }) {
    _clearTimelineInteractionState();
    if (PerfFlags.enableTimelineProjectionCache) {
      _dragInsertLayoutsCache = _timelineBlockLayouts(
        _cachedTimeModeProjections,
        rangeStart,
        rangeEnd,
        selectedDayKey,
      );
    }
    setState(() {
      _timelineVerticalDragPlanKey = planKey;
      _timelineVerticalDragDeltaPx = 0;
      _timelineVerticalDragOriginTopPx = originTopPx;
      _timelineVerticalDragCardHeightPx = originCardHeightPx;
      _timelineVerticalDragDurationMin = durationMin;
      _timelineVerticalDragTask = task;
      _timelineVerticalDragHadEnd = hadEnd;
      _timelineVerticalDragTimeLabel = _timelineDragLabelForTopPx(
        originTopPx,
        planWallDay,
        rangeStart,
        durationMin,
        hadEnd,
      );
    });
    _setTimelineInteractionLock(true);
  }

  void _updateTimelineVerticalDrag({
    required double deltaPx,
    required double globalDy,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required double canvasHeight,
    required List<PlanningTask> scheduledInRange,
    required Map<String, int> planActualByPbId,
  }) {
    final grid = _activeTimelineDurationGrid;
    if (grid == null) return;
    final durMin = _timelineVerticalDragDurationMin.toDouble();
    final dragHeightPx = math.max(1.0, _timelineVerticalDragCardHeightPx);
    final maxTopPx = grid.yForMinutesFromRangeStart(
      math.max(0, grid.totalMinutes - durMin),
    );
    final rawTop = _timelineVerticalDragOriginTopPx + deltaPx;
    final dragCenterY = rawTop + dragHeightPx / 2;
    final selectedDayKey = widget.selectedDateString.length >= 10
        ? widget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final layouts = _timelineDragLayoutsForDay(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      selectedDayKey: selectedDayKey,
    );
    final insert = _timelineResolveDragInsertTarget(
      layouts: layouts,
      dragCenterY: dragCenterY,
      excludePlanKey: _timelineVerticalDragPlanKey,
    );

    double previewTop;
    String? insertKey;
    var insertBefore = false;
    double? markerTop;
    String? previewLabel;
    TimeViewInsertionIntent? storedIntent;

    if (insert != null) {
      insertBefore = insert.insertBefore;
      insertKey = _planKey(insert.layout.task);
      final dragPlanId = _timelineVerticalDragTask?.planRowIdForBackend ??
          _timelineVerticalDragPlanKey ??
          '';
      storedIntent = _timelineInsertionIntentFromLayout(
        layout: insert.layout,
        insertBefore: insertBefore,
        draggedPlanId: dragPlanId,
        draggedDurationMin: _timelineVerticalDragDurationMin,
        draggedHadEnd: _timelineVerticalDragHadEnd,
      );
      if (storedIntent != null) {
        final dropResult = DatabaseService.instance.applyTimeViewTargetInsertion(
          scheduledInRange,
          storedIntent,
        );
        previewTop = _timelinePreviewTopPxForStartWall(
          startWall: dropResult.draggedStartWall,
          grid: grid,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          maxTopPx: maxTopPx,
        );
        previewLabel = _formatTimelineWallRangeLabel(
          dropResult.draggedStartWall,
          dropResult.draggedEndWall,
        );
        timeDropTrace(
          'phase=over dragged=${storedIntent.draggedPlanId} '
          'target=${storedIntent.targetPlanId} '
          'position=${insertBefore ? 'before' : 'after'} '
          'pointerY=${dragCenterY.toStringAsFixed(1)}',
        );
      } else {
        storedIntent = null;
        final snappedMin = _snapTimelineMinutes(
          grid.minutesFromY(rawTop.clamp(0.0, maxTopPx)),
        );
        previewTop = grid.yForMinutesFromRangeStart(snappedMin);
        previewLabel = _timelineDragLabelForTopPx(
          previewTop,
          planWallDay,
          rangeStart,
          _timelineVerticalDragDurationMin,
          _timelineVerticalDragHadEnd,
        );
      }
      if (insertBefore) {
        markerTop = insert.layout.topPx.clamp(0.0, canvasHeight);
      } else {
        markerTop = (insert.layout.topPx + insert.layout.heightPx).clamp(
          0.0,
          canvasHeight,
        );
      }
    } else {
      final snappedMin = _snapTimelineMinutes(
        grid.minutesFromY(rawTop.clamp(0.0, maxTopPx)),
      );
      previewTop = grid.yForMinutesFromRangeStart(snappedMin);
      previewLabel = _timelineDragLabelForTopPx(
        previewTop,
        planWallDay,
        rangeStart,
        _timelineVerticalDragDurationMin,
        _timelineVerticalDragHadEnd,
      );
    }

    setState(() {
      _timelineVerticalDragDeltaPx =
          previewTop - _timelineVerticalDragOriginTopPx;
      _timelineDragInsertTargetKey = insertKey;
      _timelineDragInsertBefore = insertBefore;
      _timelineDragInsertMarkerTopPx = markerTop;
      _timelineStoredInsertionIntent = storedIntent;
      _timelineVerticalDragTimeLabel = previewLabel;
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
    final grid = _activeTimelineDurationGrid;
    if (grid == null) {
      _cancelTimelineVerticalDrag();
      return;
    }
    final dragHeightPx = math.max(1.0, _timelineVerticalDragCardHeightPx);
    final maxTopPx = grid.yForMinutesFromRangeStart(
      math.max(0, grid.totalMinutes - durMin),
    );
    final rawTop = (_timelineVerticalDragOriginTopPx + _timelineVerticalDragDeltaPx)
        .clamp(0.0, maxTopPx);
    final rawYMinutes = grid.minutesFromY(rawTop);
    final dragCenterY = rawTop + dragHeightPx / 2;
    final selectedDayKey = widget.selectedDateString.length >= 10
        ? widget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    final layouts = _timelineDragLayoutsForDay(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      selectedDayKey: selectedDayKey,
    );

    TimeViewInsertionIntent? insertionIntent = _timelineStoredInsertionIntent;
    String commitSource;
    if (insertionIntent != null) {
      commitSource = 'storedIntent';
    } else {
      final insert = _timelineResolveDragInsertTarget(
        layouts: layouts,
        dragCenterY: dragCenterY,
        excludePlanKey: planKey,
      );
      if (insert != null) {
        commitSource = 'releaseHitTest';
        insertionIntent = _timelineInsertionIntentFromLayout(
          layout: insert.layout,
          insertBefore: insert.insertBefore,
          draggedPlanId: task.planRowIdForBackend,
          draggedDurationMin: durMin,
          draggedHadEnd: _timelineVerticalDragHadEnd,
        );
      } else {
        commitSource = 'emptyCanvas';
      }
    }

    late final DateTime newStartWall;
    DateTime? newEndWall;

    if (insertionIntent != null) {
      final dropResult = DatabaseService.instance.applyTimeViewTargetInsertion(
        scheduledInRange,
        insertionIntent,
      );
      newStartWall = dropResult.draggedStartWall;
      newEndWall = dropResult.draggedEndWall;
    } else {
      final snappedMin = _snapTimelineMinutes(rawYMinutes);
      newStartWall = _wallTimeFromTimelineMinutes(
        snappedMin,
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
      insertionIntent: insertionIntent,
      commitSource: commitSource,
      rawYMinutesForTrace: rawYMinutes,
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
      recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
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
          backgroundColor: Theme.of(context).colorScheme.primary,
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

    /// True when stored schedule overlaps a prior task on the same day.
    bool timelineScheduleConflict = false,

    String? timelineTimeLabel,

    double? timelineBlockHeightPx,

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
      timelineScheduleConflict: timelineScheduleConflict,
      timelineTimeLabel: timelineTimeLabel,
      timelineBlockHeightPx: timelineBlockHeightPx,
    );
    final allowLongPressDrag =
        enableLongPressDrag &&
        !_planSelectMode &&
        !task.planRowIdForBackend.startsWith('optimistic-');
    if (!allowLongPressDrag) {
      return _wrapPlanCardForDisplay(key, card, timelineEmbedded: timelineEmbedded);
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
    if (timelineEmbedded) {
      return _wrapPlanCardForDisplay(key, draggable, timelineEmbedded: true);
    }
    return _wrapPlanCardForDisplay(key, draggable);
  }

  Widget _wrapPlanCardForDisplay(
    String planKey,
    Widget card, {
    bool timelineEmbedded = false,
  }) {
    final wrapped = _PlanCardReorderSettle(
      animate: _planReorderSettleKeys.contains(planKey),
      child: card,
    );
    if (timelineEmbedded) return wrapped;
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: wrapped);
  }

  Widget _buildHourGridView(
    List<PlanningTask> tasks,
    Map<String, int> planActualByPbId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final rangeStart = _timelineHourStart;
    final rangeEnd = _timelineHourEnd;
    final planWallDay = widget.selectedDate ?? _today;
    final selectedDayKey = widget.selectedDateString.length >= 10
        ? widget.selectedDateString.substring(0, 10)
        : DatabaseService.instance.getProjectedTodayDateKey();
    var ordered = _tasksForTimeMode(
      DatabaseService.instance.planningDayTasksSnapshot(planWallDay),
      rangeStart,
    );
    final schedulablePre = <PlanningTask>[];
    for (final t in ordered) {
      final proj = DatabaseService.instance.projectPlanForTimeMode(t);
      if (proj == null) continue;
      if (proj.profileWallDateKey != selectedDayKey) continue;
      final startMin = _timelineMinutesFromRangeStart(
        proj.profileWallStart,
        rangeStart,
        rangeEnd,
      );
      if (startMin < 0 ||
          startMin > _timelineMaxVisibleMinutes(rangeStart, rangeEnd)) {
        continue;
      }
      schedulablePre.add(t);
    }
    if (schedulablePre.isNotEmpty) {
      _maybeNormalizeTimeViewOverlapsOnce(planWallDay, schedulablePre);
      ordered = _tasksForTimeMode(
        DatabaseService.instance.planningDayTasksSnapshot(planWallDay),
        rangeStart,
      );
    }
    final unscheduled = <PlanningTask>[];
    final projections = <TimeModeProjectedPlan>[];
    for (final t in ordered) {
      final proj = DatabaseService.instance.projectPlanForTimeMode(t);
      if (proj == null) {
        unscheduled.add(t);
        continue;
      }
      if (proj.profileWallDateKey != selectedDayKey) continue;
      final startMin = _timelineMinutesFromRangeStart(
        proj.profileWallStart,
        rangeStart,
        rangeEnd,
      );
      if (startMin < 0 || startMin > _timelineMaxVisibleMinutes(rangeStart, rangeEnd)) {
        continue;
      }
      projections.add(proj);
    }
    _cachedTimeModeProjections = projections;
    final visibleHours = PlanningSheetTimelinePrefs.visibleHoursOrdered(
      rangeStart,
      rangeEnd,
    );

    final inRangeScheduled = projections.map((p) => p.projectedTask).toList();
    _logTimeModeRail(selectedDay: planWallDay, visibleHours: visibleHours);

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

    children.add(
      _buildProportionalDayTimelineCanvas(
        scheme: scheme,
        loc: loc,
        planWallDay: planWallDay,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        visibleHours: visibleHours,
        scheduledInRange: inRangeScheduled,
        projections: projections,
        selectedDayKey: selectedDayKey,
        planActualByPbId: planActualByPbId,
      ),
    );

    return ListView(
      controller: _hourGridScrollController,
      physics: _timelineScrollLocked
          ? const NeverScrollableScrollPhysics()
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: _timelineCompactLayout(context) ? 4 : 8,
        vertical: 8,
      ),
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
    required List<TimeModeProjectedPlan> projections,
    required String selectedDayKey,
    required Map<String, int> planActualByPbId,
  }) {
    final durationResult = _computeTimelineDurationLayout(
      projections,
      rangeStart,
      rangeEnd,
      selectedDayKey,
    );
    _activeTimelineDurationGrid = durationResult.grid;
    final grid = durationResult.grid;
    final layouts = durationResult.layouts;
    final canvasHeight = _timelineCanvasHeightPx(grid);
    final gridColor = scheme.outlineVariant.withValues(alpha: 0.28);
    final nowTop = _timelineNowLineTopPx(rangeStart, rangeEnd, grid);
    final wallNow = _profileWallNow();
    final nowLabel = nowTop != null
        ? '${wallNow.hour.toString().padLeft(2, '0')}:${wallNow.minute.toString().padLeft(2, '0')}'
        : null;
    if (nowTop != null) {
      _maybeAutoScrollTimelineToNow(nowTop, canvasHeight);
    }

    final compact = _timelineCompactLayout(context);
    final railWidth = _timelineRailWidthPx(context);
    String hourLabel(int hour) => compact
        ? '${hour.clamp(0, 23)}'
        : '${hour.clamp(0, 23).toString().padLeft(2, '0')}:00';

    final canvas = SizedBox(
      height: canvasHeight + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: railWidth,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < visibleHours.length; i++)
                      Positioned(
                        top: grid.hourTops[i] - 6,
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
                    if (nowTop != null && nowLabel != null)
                      Positioned(
                        top: nowTop.clamp(0, canvasHeight - 1) - 10,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.92),
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
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              scheme.surfaceContainerHighest.withValues(
                                alpha: 0.78,
                              ),
                              scheme.surfaceContainerHigh.withValues(
                                alpha: 0.94,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < visibleHours.length; i++)
                        Positioned(
                          top: grid.hourTops[i],
                          left: 0,
                          right: 0,
                          height: grid.hourHeights[i],
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
                                canvasHeight: canvasHeight,
                                scheme: scheme,
                                planWallDay: planWallDay,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                selectedDayKey: selectedDayKey,
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
                                canvasHeight: canvasHeight,
                                scheme: scheme,
                                planWallDay: planWallDay,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                selectedDayKey: selectedDayKey,
                                planActualByPbId: planActualByPbId,
                                scheduledInRange: scheduledInRange,
                              ),
                            ),
                      ],
                      if (nowTop != null)
                        Positioned(
                          top: nowTop.clamp(0, canvasHeight - 1),
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ],
      ),
    );
    if (PerfFlags.enableTimelineRepaintBoundary) {
      return RepaintBoundary(child: canvas);
    }
    return canvas;
  }

  String? _timelineElevatedPlanKey() =>
      _timelineResizePlanKey ?? _timelineVerticalDragPlanKey;

  Widget _buildTimelinePlanStackLayer({
    required PlanTimeViewBlockLayout layout,
    required double canvasHeight,
    required ColorScheme scheme,
    required DateTime planWallDay,
    required int rangeStart,
    required int rangeEnd,
    required String selectedDayKey,
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
    const horizontalPad = _kTimelineBlockHorizontalPadPx;
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
    final blockDensity = layout.density;
    final resizeHeightPx = math.max(heightPx, kPlanTimeCardMinHeightPx);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isInteracting)
          Positioned(
            top: layout.topPx,
            left: 0,
            right: 0,
            height: layout.heightPx,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kTimelineBlockHorizontalPadPx,
              ),
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
          ),
        if (isInteracting && (interactionLabel ?? '').isNotEmpty)
          Positioned(
            top: (topPx - 22).clamp(0, canvasHeight - 20),
            left: horizontalPad,
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
            left: horizontalPad,
            right: horizontalPad,
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
          left: 0,
          right: 0,
          height: resizeHeightPx,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kTimelineBlockHorizontalPadPx,
            ),
            child: _TimelinePlanInteractionBlock(
              canMove: canInteract,
              canResize: canInteract,
              resizeHandlePx: _kTimelineResizeHandlePx,
              blockHeightPx: resizeHeightPx,
              controlsLeftInset: planCardBodyGestureLeftInsetPx(
                blockDensity,
                timeline: true,
              ),
              controlsRightInset: planCardBodyGestureRightInsetPx(),
              onMovePointerDown: canInteract
                  ? () {
                      _setTimelineInteractionLock(true);
                    }
                  : null,
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
                      originCardHeightPx: layout.heightPx,
                      durationMin: durMin,
                      hadEnd: hadEnd,
                      planWallDay: planWallDay,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      selectedDayKey: selectedDayKey,
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
                      planActualByPbId: planActualByPbId,
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
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: resizeHeightPx,
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
                    timelineScheduleConflict: false,
                    timelineTimeLabel: layout.projection?.plannedTimeLabel,
                    timelineBlockHeightPx: resizeHeightPx,
                  ),
                ),
              ),
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

    var firstCategoryGroup = true;
    for (final k in keys) {
      final bucket = groups[k];
      if (bucket == null || bucket.isEmpty) continue;
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
            key: ValueKey<String>('category-bucket-$k'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: proxyDecorator,
            itemCount: bucket.length,
            onReorder: (oldI, newI) =>
                _onCategoryBucketReorder(tasks, k, oldI, newI),
            itemBuilder: (context, index) {
              final task = bucket[index];
              final key = _planKey(task);
              final displayDone = _planDoneOverride[key] ?? task.isDone;
              final canReorder = !_planSelectMode && _planCanReorderTask(task);
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
              final canReorder = !_planSelectMode && _planCanReorderTask(task);
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

  void _onCategoryBucketReorder(
    List<PlanningTask> allDisplayed,
    String categoryPath,
    int oldIndex,
    int newIndex,
  ) {
    if (_planSelectMode || _sortMode != _PlanSortMode.category) return;
    final groups = _groupTasksByCategoryPath(allDisplayed);
    final keys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final bucket = List<PlanningTask>.from(groups[categoryPath] ?? []);
    if (bucket.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= bucket.length) return;
    var ni = newIndex;
    if (ni > oldIndex) ni -= 1;
    if (ni < 0 || ni > bucket.length) return;
    final row = bucket[oldIndex];
    if (!_planCanReorderTask(row)) return;
    bucket.removeAt(oldIndex);
    bucket.insert(ni, row);
    groups[categoryPath] = bucket;
    final flat = <PlanningTask>[];
    for (final k in keys) {
      flat.addAll(groups[k] ?? const <PlanningTask>[]);
    }
    if (flat.length != allDisplayed.length) return;
    final withOrders = <PlanningTask>[
      for (var i = 0; i < flat.length; i++) flat[i].copyWith(order: i),
    ];
    _commitPlanningReorder(
      mode: 'category',
      moved: row,
      fromIndex: oldIndex,
      toIndex: ni,
      withOrders: withOrders,
      baselineBefore: allDisplayed,
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
    if (!_planCanReorderTask(row)) return;
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
    _commitPlanningReorder(
      mode: 'tags',
      moved: row,
      fromIndex: oldIndex,
      toIndex: ni,
      withOrders: withOrders,
      baselineBefore: allDisplayed,
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
    if (!_planCanReorderTask(row)) return;
    final next = List<PlanningTask>.from(current);
    next.removeAt(oldIndex);
    next.insert(ni, row);
    final withOrders = <PlanningTask>[
      for (var i = 0; i < next.length; i++) next[i].copyWith(order: i),
    ];
    _commitPlanningReorder(
      mode: 'custom',
      moved: row,
      fromIndex: oldIndex,
      toIndex: ni,
      withOrders: withOrders,
      baselineBefore: current,
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

  Widget _buildFrozenPlanCardList(
    List<PlanningTask> tasks,
    ColorScheme scheme,
    DateTime wallDay,
  ) {
    DatabaseService.instance.buildPlansDayRenderSnapshot(
      wallDay,
      activeRecordingTitleNorm: _activeRecordingTitleNorm,
    );
    final renderSnap =
        DatabaseService.instance.plansRenderSnapshotForDate(wallDay);
    final planActual = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);

    if (tasks.isEmpty) {
      return ColoredBox(
        color: scheme.surface,
        child: EmptyStatePlaceholder(
          icon: Icons.track_changes_rounded,
          titleL10nKey: 'empty_planning_title',
          subtitleL10nKey: 'empty_planning_subtitle',
        ),
      );
    }

    final cards = renderSnap?.ready == true
        ? renderSnap!.cards
        : tasks.map((task) {
            final pbId = DatabaseService.pocketRelationIdOrNull(
              task.pocketRecordId,
            );
            return PlanCardRenderDto(
              task: task,
              planTrackedSeconds: pbId != null ? (planActual[pbId] ?? 0) : 0,
              planEstimatedSeconds:
                  PlanServiceExtension.planningWallEstimateSeconds(task),
              displayIsDone: task.isDone,
              showPlay: !task.isDone,
              highlightAsRunning: false,
              timeLabel: PlanCard.timelineTimeRangeLabel(task),
              tagsReady: true,
              categoryReady: true,
            );
          }).toList();

    return ColoredBox(
      color: scheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        physics: const ClampingScrollPhysics(),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final dto = cards[index];
          return PlanCard(
            key: ValueKey<String>(
              'plan-day-${dto.task.planRowIdForBackend}',
            ),
            task: dto.task,
            planTrackedSeconds: dto.planTrackedSeconds,
            planEstimatedSeconds: dto.planEstimatedSeconds,
            displayIsDone: dto.displayIsDone,
            selectMode: false,
            isSelected: false,
            highlightAsRunning: dto.highlightAsRunning,
            toggleDoneEnabled: false,
            onToggleDone: () {},
            onBodyTap: () {},
            onPlay: dto.showPlay ? () {} : null,
            onOpenMenu: (_) {},
          );
        },
      ),
    );
  }

  DateTime _dateForPageIndex(int index) =>
      widget.mountedWindow?.dateAt(index) ??
      (widget.selectedDate ?? _today);

  String _dateKeyForPageIndex(int index) =>
      MountedDayWindow.dateKey(_dateForPageIndex(index));

  /// Stable PageView path — live planning stream for this page's day.
  Widget _buildActiveDayBody(
    BuildContext context,
    ColorScheme scheme,
    List<PlanningTask> tasks,
  ) {
    if (!widget.isActivePlanningDay) {
      return const ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      );
    }
    final wallDay = widget.selectedDate ?? _today;
    final planActualByPbId = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
    if (tasks.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.track_changes_rounded,
        titleL10nKey: 'empty_planning_title',
        subtitleL10nKey: 'empty_planning_subtitle',
        actionLabelL10nKey: 'empty_action_focus_planning_field',
        onAction: () => FocusScope.of(context).requestFocus(_quickAddFocus),
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
      proxyDecorator: (Widget child, int index, Animation<double> anim) {
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
        final canReorder = !_planSelectMode && _planCanReorderTask(task);
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
  }

  Widget _buildDayContentForPageIndex(
    BuildContext context,
    ColorScheme scheme,
    int index,
    List<PlanningTask> visibleDayTasks,
  ) {
    final wallDay = _dateForPageIndex(index);
    final isActive = widget.shellTabActive &&
        widget.selectedDate != null &&
        (widget.mountedWindow == null ||
            MountedDayWindow.dateOnly(wallDay) ==
                MountedDayWindow.dateOnly(widget.selectedDate!));
    final bodyEntry = DatabaseService.instance.plansBodyEntryForDate(wallDay);
    final tasks = isActive ? visibleDayTasks : bodyEntry.tasks;
    if (!isActive) {
      final planActualByPbId = DatabaseService.instance
          .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
      if (_sortMode == _PlanSortMode.time) {
        return RepaintBoundary(
          child: _PlanningDayCardListKeepAlive(
            child: AbsorbPointer(
              child: _buildHourGridView(tasks, planActualByPbId),
            ),
          ),
        );
      }
      return RepaintBoundary(
        child: _PlanningDayCardListKeepAlive(
          child: _buildFrozenPlanCardList(tasks, scheme, wallDay),
        ),
      );
    }
    final planActualByPbId = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
    if (tasks.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.track_changes_rounded,
        titleL10nKey: 'empty_planning_title',
        subtitleL10nKey: 'empty_planning_subtitle',
        actionLabelL10nKey: 'empty_action_focus_planning_field',
        onAction: () => FocusScope.of(context).requestFocus(_quickAddFocus),
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
      proxyDecorator: (Widget child, int index, Animation<double> anim) {
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
        final canReorder = !_planSelectMode && _planCanReorderTask(task);
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
  }

  @override
  Widget build(BuildContext context) {
    perfRebuildTick('PlanningPage');
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<PlanningTask>>(
      stream: _planningStream,
      builder: (context, snapshot) {
        List<PlanningTask>? displayedForChrome;
        late final Widget body;
        try {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              _latestPlanningDayTasks.isEmpty) {
            _latestPlanningDayTasks = DatabaseService.instance
                .dedupePlanningTasksForDisplay(
                  DatabaseService.instance.planningDayTasksSnapshot(
                    widget.selectedDate ?? _today,
                  ),
                );
          }
          if (snapshot.hasError && _latestPlanningDayTasks.isEmpty) {
            body = AppErrorState(
              message: t(currentLocale.value, 'no_data_found'),
            );
          } else {
            final server = snapshot.hasData
                ? snapshot.data!
                : _latestPlanningDayTasks;
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
          child: kUseP0tMountedStrip &&
                  widget.mountedWindow != null &&
                  widget.stripController != null &&
                  widget.onVisibleDateChanged != null
              ? StreamBuilder<void>(
                  stream: DatabaseService.instance.timeUpdates,
                  builder: (context, _) {
                    final window = widget.mountedWindow!;
                    final visibleDate = widget.selectedDate ?? _today;
                    final rawIdx = window.contains(visibleDate)
                        ? window.indexOf(visibleDate)
                        : window.indexOf(_today);
                    final activeIndex = rawIdx
                        .clamp(0, math.max(0, window.length - 1))
                        .toInt();
                    return EagerDayContentStrip(
                      screen: 'Plans',
                      dates: window.dates,
                      initialIndex: activeIndex,
                      activeIndex: activeIndex,
                      controller: widget.stripController,
                      physics: widget.datePagerLocked
                          ? const NeverScrollableScrollPhysics()
                          : const FeatherDateSwipePhysics(),
                      scrollLocked: widget.datePagerLocked,
                      onUserDragStart: widget.onUserDragStart,
                      onUserDragEnd: widget.onUserDragEnd,
                      onScrollTick: widget.onScrollTick,
                      onIndexChanged: widget.onVisibleDateChanged!,
                      itemBuilder: (context, date, index, isActive) {
                        return RepaintBoundary(
                          child: _buildDayContentForPageIndex(
                            context,
                            scheme,
                            index,
                            tasks,
                          ),
                        );
                      },
                    );
                  },
                )
              : RepaintBoundary(
                  child: _buildActiveDayBody(context, scheme, tasks),
                ),
        ),
      ],
    );
  }
}

/// Keeps offscreen plan day bodies alive in [PageView] (P0P render warm).
class _PlanningDayCardListKeepAlive extends StatefulWidget {
  const _PlanningDayCardListKeepAlive({required this.child});

  final Widget child;

  @override
  State<_PlanningDayCardListKeepAlive> createState() =>
      _PlanningDayCardListKeepAliveState();
}

class _PlanningDayCardListKeepAliveState extends State<_PlanningDayCardListKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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

class _DefaultPlanTimezoneSearchDelegate extends SearchDelegate<String?> {
  _DefaultPlanTimezoneSearchDelegate({
    required this.loc,
    required this.options,
  }) : super(searchFieldLabel: t(loc, 'plan_default_time_tz_search'));

  final String loc;
  final List<tz_settings.CategoryDefaultTimezoneOption> options;

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
            return o.searchLabel.toLowerCase().contains(q) ||
                o.ianaId.toLowerCase().contains(q) ||
                o.shortLabel.toLowerCase().contains(q);
          }).toList();
    if (matches.isEmpty) {
      return Center(child: Text(t(loc, 'plan_default_time_tz_search')));
    }
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = matches[index];
        return ListTile(
          title: Text(option.searchLabel),
          subtitle: Text(option.ianaId),
          trailing: Text(option.shortLabel),
          onTap: () => close(context, option.ianaId),
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

enum _TimelineResizeEdge { top, bottom }

/// Invisible move/resize gesture zones for proportional timeline plan blocks.
class _TimelinePlanInteractionBlock extends StatefulWidget {
  const _TimelinePlanInteractionBlock({
    required this.canMove,
    required this.canResize,
    required this.resizeHandlePx,
    required this.child,
    required this.isInteracting,
    this.blockHeightPx,
    this.controlsLeftInset = 0,
    this.controlsRightInset = 0,
    this.onBodyTap,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onMovePointerDown,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
  });

  final bool canMove;
  final bool canResize;
  final double resizeHandlePx;
  final bool isInteracting;
  final double? blockHeightPx;
  final Widget child;
  final double controlsLeftInset;
  final double controlsRightInset;
  final VoidCallback? onBodyTap;
  final VoidCallback? onVerticalDragStart;
  final void Function(double deltaPx, double globalDy)? onVerticalDragUpdate;
  final VoidCallback? onVerticalDragEnd;
  final VoidCallback? onVerticalDragCancel;
  final VoidCallback? onMovePointerDown;
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
  int? _activePointer;

  bool get _immediateBodyDrag =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  double get _resizeZoneInset {
    final h = widget.blockHeightPx ?? widget.resizeHandlePx * 2;
    if (h < 48) {
      return math.max(6.0, (h - 6) / 2);
    }
    return widget.resizeHandlePx;
  }

  void _endBodyDragSession() {
    _bodyDragActive = false;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _suppressBodyTap = false);
    });
  }

  Widget _moveZone() {
    if (!widget.canMove) return const SizedBox.shrink();
    final inset = widget.canResize ? _resizeZoneInset : 0.0;
    final zone = Positioned(
      top: inset,
      bottom: inset,
      left: widget.controlsLeftInset,
      right: widget.controlsRightInset,
      child: MouseRegion(
        cursor: _bodyDragActive
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: _immediateBodyDrag
            ? Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  widget.onMovePointerDown?.call();
                  _suppressBodyTap = true;
                  _bodyDragActive = true;
                  _moveAccumulatedDy = 0;
                  _activePointer = e.pointer;
                  widget.onVerticalDragStart?.call();
                },
                onPointerMove: (e) {
                  if (!_bodyDragActive || _activePointer != e.pointer) return;
                  _moveAccumulatedDy += e.delta.dy;
                  widget.onVerticalDragUpdate?.call(
                    _moveAccumulatedDy,
                    e.position.dy,
                  );
                },
                onPointerUp: (e) {
                  if (!_bodyDragActive || _activePointer != e.pointer) return;
                  widget.onVerticalDragEnd?.call();
                  _endBodyDragSession();
                  _activePointer = null;
                },
                onPointerCancel: (e) {
                  if (!_bodyDragActive || _activePointer != e.pointer) return;
                  widget.onVerticalDragCancel?.call();
                  _endBodyDragSession();
                  _activePointer = null;
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onBodyTap == null
                      ? null
                      : () {
                          if (_suppressBodyTap || _bodyDragActive) return;
                          widget.onBodyTap!();
                        },
                  child: const SizedBox.expand(),
                ),
              )
            : GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onBodyTap == null
            ? null
            : () {
                if (_suppressBodyTap || _bodyDragActive) return;
                widget.onBodyTap!();
              },
        onLongPressStart: (_) {
                _suppressBodyTap = true;
                _bodyDragActive = true;
                _moveAccumulatedDy = 0;
                widget.onMovePointerDown?.call();
                widget.onVerticalDragStart?.call();
              },
        onLongPressMoveUpdate: (details) {
                widget.onVerticalDragUpdate?.call(
                  details.offsetFromOrigin.dy,
                  details.globalPosition.dy,
                );
              },
        onLongPressEnd: (_) {
                widget.onVerticalDragEnd?.call();
                _endBodyDragSession();
              },
        onLongPressCancel: () {
                widget.onVerticalDragCancel?.call();
                _endBodyDragSession();
              },
        child: const SizedBox.expand(),
      ),
      ),
    );
    return zone;
  }

  Widget _resizeEdge({
    required bool isTop,
    required ColorScheme scheme,
  }) {
    return _TimelineResizeEdgeHandle(
      isTop: isTop,
      height: _resizeZoneInset,
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
            left: widget.controlsLeftInset,
            right: widget.controlsRightInset,
            child: _resizeEdge(isTop: true, scheme: scheme),
          ),
        if (widget.canResize)
          Positioned(
            bottom: 0,
            left: widget.controlsLeftInset,
            right: widget.controlsRightInset,
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
      cursor: SystemMouseCursors.resizeUpDown,
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
          width: double.infinity,
          child: showHairline
              ? Stack(
                  alignment: widget.isTop
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  children: [
                    Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: widget.isTop ? 4 : 0,
                        bottom: widget.isTop ? 0 : 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

/// One-shot slide settle when a completed card is allowed to reorder.
class _PlanCardReorderSettle extends StatefulWidget {
  const _PlanCardReorderSettle({
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<_PlanCardReorderSettle> createState() => _PlanCardReorderSettleState();
}

class _PlanCardReorderSettleState extends State<_PlanCardReorderSettle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  bool _wasAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.animate) {
      _wasAnimating = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _PlanCardReorderSettle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.animate && widget.animate) {
      _wasAnimating = true;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_wasAnimating && !widget.animate) return widget.child;
    return SlideTransition(position: _slide, child: widget.child);
  }
}
