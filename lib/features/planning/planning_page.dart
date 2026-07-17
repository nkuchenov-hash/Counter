// Single-day Planning tab body (task list, Time View, quick-add).
// ---------------------------------------------------------------------------
// PLANNING FEATURE — Day planning & task list tab. UI_ISOLATION (§7). FEATURE-FIRST (§17).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/widgets/day_content_strip.dart';
import 'package:counter/core/widgets/day_window.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/bulk_planning_edit_sheet.dart';
import 'package:counter/features/planning/recurrence_scope_dialog.dart';
import 'package:counter/data/smart_input_parser.dart';
import 'package:counter/features/planning/smart_plan_sheet.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/plan_card.dart';
import 'package:counter/features/planning/time_view/time_view_settings_sheet.dart';
import 'package:counter/features/planning/time_view/time_view_hour_grid.dart';
import 'package:counter/features/planning/time_view/planning_time_view.dart';
import 'package:counter/features/planning/time_view/planning_time_view_host.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/widgets/plan_card_reorder_settle.dart';
import 'package:counter/features/planning/widgets/planning_day_card_list_keep_alive.dart';
import 'package:counter/features/planning/widgets/planning_menu_overlay.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/widgets/planning_bulk_bar.dart';
import 'package:counter/features/planning/widgets/planning_empty_states.dart';
import 'package:counter/features/planning/widgets/planning_filter_controls.dart';
import 'package:counter/features/planning/widgets/planning_list_grouping.dart';
import 'package:counter/features/planning/widgets/planning_frozen_day_list.dart';
import 'package:counter/features/planning/widgets/planning_list_helpers.dart';
import 'package:counter/features/planning/widgets/planning_category_grouped_list.dart';
import 'package:counter/features/planning/widgets/planning_tag_grouped_list.dart';
import 'package:counter/features/planning/widgets/planning_select_mode_header.dart';
import 'package:counter/features/planning/widgets/planning_quick_add_strip.dart';


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
  final DayWindow? mountedWindow;
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin
    implements PlanningTimeViewHost {
  final _textController = TextEditingController();
  final _quickAddFocus = FocusNode();
  final Set<String> _selectedPlanKeys = {};
  final List<PlanningTask> _optimisticTasks = [];
  bool _planQuickAddInFlight = false;

  /// Last server list for this day from [planningStream] (avoids `nextPlanningOrderForDate` network on quick-add).
  List<PlanningTask> _latestPlanningDayTasks = const [];
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
  String? _planningStreamKey;
  List<PlanningTask>? _dragOrder;
  bool _planSelectMode = false;
  PlanSortMode _sortMode = PlanSortMode.custom;
  late final PlanningTimeViewCoordinator timeView;

  /// Hour-grid day timeline scroll (edge auto-scroll while dragging a plan).





  /// Duration-true timeline scale for the active Time-mode canvas build.


  /// Local preview height while dragging (intrinsic card height).

  /// Active vertical timeline drag (Time mode); local preview only until drop.

  /// Midpoint insert-before/after target while dragging over another card.

  /// Finger delta (never overwritten by preview snap); used for hit-test on release.

  /// Canvas-local Y of finger within dragged card at pointer-down (inset + local dy).

  /// Monotonic id per vertical drag gesture (stamped on target-card intents).

  /// Top/bottom edge resize (Time mode); local preview until release.



  static const double _kShellBulkBarReservePx = 56;

  /// Pixels per second while the drag pointer sits in the top/bottom 10% bands.

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
DatabaseService.instance.persistPlanningTaskOrder(
      withOrders,
      baselineBeforeReorder: baselineBefore,
    );
    setState(() => _dragOrder = null);
  }

  Stream<List<PlanningTask>> _planningStreamForCurrentDay() {
    final day = widget.selectedDate ?? _today;
    final listen = widget.isActivePlanningDay && widget.shellTabActive;
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}|$listen';
    if (_planningStreamKey == key && _planningStream != null) {
      return _planningStream!;
    }
    _planningStreamKey = key;
    _planningStream = DatabaseService.instance.planningStream(
      day,
      listenToGlobalPlanningRefresh: listen,
    );
    return _planningStream!;
  }


  @override
  BuildContext get context => super.context;

  @override
  PlanningPage get pageWidget => widget;

  @override
  DateTime get today => _today;

  @override
  PlanSortMode get sortMode => _sortMode;

  @override
  bool get planSelectMode => _planSelectMode;

  @override
  Set<String> get selectedPlanKeys => _selectedPlanKeys;

  @override
  Map<String, bool> get planDoneOverride => _planDoneOverride;

  @override
  bool get noTagsChipVisible => _noTagsChipVisible;

  @override
  String get noTagsColorHex => _noTagsColorHex;

  @override
  String get prefsKeyNoTagsVisible => _prefsKeyNoTagsVisible;

  @override
  String get prefsKeyNoTagsColor => _prefsKeyNoTagsColor;

  @override
  void notifySetState([VoidCallback? fn]) {
    if (fn == null) {
      setState(() {});
    } else {
      setState(fn);
    }
  }

  @override
  void onDatePagerLockChanged(bool locked) {
    widget.onDatePagerLockChanged?.call(locked);
  }

  @override
  Future<void> reloadQuickAddTags() => _reloadQuickAddTags();

  @override
  void applyNoTagsChipSettings(bool visible, String colorHex) {
    notifySetState(() {
      _noTagsChipVisible = visible;
      _noTagsColorHex = colorHex;
    });
  }

  @override
  String planKey(PlanningTask task) => _planKey(task);

  @override
  int taskSortCmp(PlanningTask a, PlanningTask b) =>
      planningTaskSortCmp(a, b, sortTreatAsDone: _sortTreatAsDone);

  @override
  Widget planCardRow({
    required BuildContext context,
    required PlanningTask task,
    required String key,
    required bool displayDone,
    required bool isSelected,
    required Map<String, int> planActualByPbId,
    bool enableLongPressDrag = false,
    bool omitLongPressForReorder = false,
    bool timelineEmbedded = false,
    bool timelineInteracting = false,
    bool timelineScheduleConflict = false,
    String? timelineTimeLabel,
    double? timelineBlockHeightPx,
    ValueChanged<double>? onHourGridDragGlobalDy,
    VoidCallback? onHourGridDragEnded,
  }) =>
      _planCardRow(
        context: context,
        task: task,
        key: key,
        displayDone: displayDone,
        isSelected: isSelected,
        planActualByPbId: planActualByPbId,
        enableLongPressDrag: enableLongPressDrag,
        omitLongPressForReorder: omitLongPressForReorder,
        timelineEmbedded: timelineEmbedded,
        timelineInteracting: timelineInteracting,
        timelineScheduleConflict: timelineScheduleConflict,
        timelineTimeLabel: timelineTimeLabel,
        timelineBlockHeightPx: timelineBlockHeightPx,
        onHourGridDragGlobalDy: onHourGridDragGlobalDy,
        onHourGridDragEnded: onHourGridDragEnded,
      );

  @override
  void openQuickAddForHour(int hour) => _openQuickAddForHour(hour);

  @override
  void openEditDialog(PlanningTask task) => _openEditDialog(task);

  @override
  void toggleKeySelection(String key) => _toggleKeySelection(key);

  @override
  List<PlanningTask> latestPlanningDayTasksSnapshot() => _latestPlanningDayTasks;

  @override
  void initState() {
    super.initState();
    final persisted = DatabaseService.instance.getPlanActiveTabIndexOrNull();
    if (persisted != null) {
      _sortMode = planSortModeFromPersistedIndex(persisted);
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
      _planningStream = _planningStreamForCurrentDay();
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
        _refreshPlanningTasksAfterTimezoneChange();
        DatabaseService.instance.notifyPlanningRefresh(
          scheduleNetworkRefresh: false,
        );
        setState(() {});
      }
    });
    timeView = PlanningTimeViewCoordinator(this);
    timeView.initHourGridTicker(createTicker);
    unawaited(timeView.loadPlanningTimelineBounds());
    unawaited(timeView.loadTimeViewFixedTagIds());
    unawaited(_reloadQuickAddTags());
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



  void _refreshPlanningTasksAfterTimezoneChange() {
    final day = widget.selectedDate ?? _today;
    _latestPlanningDayTasks = DatabaseService.instance
        .dedupePlanningTasksForDisplay(
          DatabaseService.instance.planningDayTasksSnapshot(day),
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
        oldWidget.isActivePlanningDay != widget.isActivePlanningDay ||
        oldWidget.shellTabActive != widget.shellTabActive) {
      setState(() {
        if (widget.isActivePlanningDay) {
          _planningStream = _planningStreamForCurrentDay();
        } else {
          _planningStream = null;
          _planningStreamKey = null;
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
          _sortMode = PlanSortMode.custom;
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
    timeView.disposeTimeView();
    _textController.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }




  /// While dragging in the hour grid, set scroll velocity from global Y bands
  /// (top/bottom 10% of viewport); motion is applied in [_onHourGridEdgeScrollTick].

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

  Future<void> _deletePlanningTaskWithOptionalRecurrenceScope(
    PlanningTask task,
  ) async {
    if (DatabaseService.instance.planningTaskIsRecurringForScope(task)) {
      final scope = await showRecurrenceScopeDialog(
        context,
        task: task,
        isDelete: true,
      );
      if (scope == null) return;
      await DatabaseService.instance.deletePlanningTaskWithRecurrenceScope(
        task.planRowIdForBackend,
        scope: scope,
        planBusinessId: task.planRowId,
        recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
      );
    } else {
      await DatabaseService.instance.deletePlanningTask(
        task.planRowIdForBackend,
      );
    }
    if (mounted) setState(() {});
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
        return SemicirclePlanningMenuOverlay(
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
            unawaited(_deletePlanningTaskWithOptionalRecurrenceScope(task));
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
      timelineStartHour: timeView.timelineHourStart,
      timelineEndHour: timeView.timelineHourEnd,
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
      timelineDayStartHour: timeView.timelineHourStart,
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
        timelineDayStartHour: timeView.timelineHourStart,
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

  List<Tag> _tagSortMasterBarOrder() => planningTagSortMasterBarOrder(
        quickAddAvailableTags: _quickAddAvailableTags,
        cachedUserTagsCatalog: DatabaseService.instance.cachedUserTagsCatalog,
        syntheticNoTagsTag: _syntheticNoTagsTag(),
      );

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
    final estimate = planningWallEstimateSeconds(task);
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


  /// Profile-wall minutes from the visible day window start on [planWallDay].


  /// ~1.5× normal CardPlan height; base hour band before per-hour stretch.


























































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
    final wrapped = PlanCardReorderSettle(
      animate: _planReorderSettleKeys.contains(planKey),
      child: card,
    );
    if (timelineEmbedded) return wrapped;
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: wrapped);
  }





  Widget _groupedListPlanCardRow({
    required BuildContext context,
    required PlanningTask task,
    required String key,
    required bool displayDone,
    required bool isSelected,
    required Map<String, int> planActualByPbId,
    bool omitLongPressForReorder = false,
  }) {
    return _planCardRow(
      context: context,
      task: task,
      key: key,
      displayDone: displayDone,
      isSelected: isSelected,
      planActualByPbId: planActualByPbId,
      omitLongPressForReorder: omitLongPressForReorder,
    );
  }

  Widget _buildCategoryGroupedView(
    List<PlanningTask> tasks,
    Map<String, int> planActualByPbId,
  ) {
    return PlanningCategoryGroupedList(
      tasks: tasks,
      planActualByPbId: planActualByPbId,
      sortTreatAsDone: _sortTreatAsDone,
      planSelectMode: _planSelectMode,
      planKeyForTask: _planKey,
      resolveDisplayDone: (task, key) => _planDoneOverride[key] ?? task.isDone,
      isSelectedKey: (key) => _selectedPlanKeys.contains(key),
      canReorderTask: _planCanReorderTask,
      planCardRow: _groupedListPlanCardRow,
      onCategoryBucketReorder: (path, oldI, newI) =>
          _onCategoryBucketReorder(tasks, path, oldI, newI),
    );
  }

  Widget _buildTagGroupedListView(
    List<PlanningTask> tasks,
    Map<String, int> planActualByPbId,
  ) {
    final masterBar = _tagSortMasterBarOrder();
    return PlanningTagGroupedList(
      tasks: tasks,
      planActualByPbId: planActualByPbId,
      masterBarOrder: masterBar,
      sortTreatAsDone: _sortTreatAsDone,
      planSelectMode: _planSelectMode,
      planKeyForTask: _planKey,
      resolveDisplayDone: (task, key) => _planDoneOverride[key] ?? task.isDone,
      isSelectedKey: (key) => _selectedPlanKeys.contains(key),
      canReorderTask: _planCanReorderTask,
      planCardRow: _groupedListPlanCardRow,
      onTagBucketReorder: (gid, oldI, newI) =>
          _onTagBucketReorder(tasks, masterBar, gid, oldI, newI),
    );
  }

  void _onCategoryBucketReorder(
    List<PlanningTask> allDisplayed,
    String categoryPath,
    int oldIndex,
    int newIndex,
  ) {
    if (_planSelectMode || _sortMode != PlanSortMode.category) return;
    final groups = groupPlanningTasksByCategoryPath(
      allDisplayed,
      sortTreatAsDone: _sortTreatAsDone,
    );
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
    if (_planSelectMode || _sortMode != PlanSortMode.tags) return;
    final groups = groupPlanningTasksByMasterBar(
      allDisplayed,
      masterBar,
      sortTreatAsDone: _sortTreatAsDone,
    );
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
    final orderedIds = planningGroupIdsInMasterBarSequence(groups, masterBar);
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
    if (_planSelectMode || _sortMode != PlanSortMode.custom) return;
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

  DateTime _dateForPageIndex(int index) =>
      widget.mountedWindow?.dateAt(index) ??
      (widget.selectedDate ?? _today);

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
      return PlanningDayEmptyState(
        onFocusQuickAdd: () => FocusScope.of(context).requestFocus(_quickAddFocus),
      );
    }
    if (_sortMode == PlanSortMode.time) {
      return timeView.buildHourGridView(tasks, planActualByPbId);
    }
    if (_sortMode == PlanSortMode.category) {
      return _buildCategoryGroupedView(tasks, planActualByPbId);
    }
    if (_sortMode == PlanSortMode.tags) {
      return _buildTagGroupedListView(tasks, planActualByPbId);
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      buildDefaultDragHandles: false,
      proxyDecorator: planningReorderProxyDecorator,
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
            DayWindow.dateOnly(wallDay) ==
                DayWindow.dateOnly(widget.selectedDate!));
    final bodyEntry = DatabaseService.instance.plansBodyEntryForDate(wallDay);
    final tasks = isActive ? visibleDayTasks : bodyEntry.tasks;
    if (!isActive) {
      final planActualByPbId = DatabaseService.instance
          .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
      if (_sortMode == PlanSortMode.time) {
        return RepaintBoundary(
          child: PlanningDayCardListKeepAlive(
            child: AbsorbPointer(
              child: timeView.buildHourGridView(tasks, planActualByPbId),
            ),
          ),
        );
      }
      return RepaintBoundary(
        child: PlanningDayCardListKeepAlive(
          child: PlanningFrozenDayList(
            tasks: tasks,
            scheme: scheme,
            wallDay: wallDay,
            activeRecordingTitleNorm: _activeRecordingTitleNorm,
          ),
        ),
      );
    }
    final planActualByPbId = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
    if (tasks.isEmpty) {
      return PlanningDayEmptyState(
        onFocusQuickAdd: () => FocusScope.of(context).requestFocus(_quickAddFocus),
      );
    }
    if (_sortMode == PlanSortMode.time) {
      return timeView.buildHourGridView(tasks, planActualByPbId);
    }
    if (_sortMode == PlanSortMode.category) {
      return _buildCategoryGroupedView(tasks, planActualByPbId);
    }
    if (_sortMode == PlanSortMode.tags) {
      return _buildTagGroupedListView(tasks, planActualByPbId);
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      buildDefaultDragHandles: false,
      proxyDecorator: planningReorderProxyDecorator,
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
    rebuildMetricsTick('PlanningPage');
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
                if (_planSelectMode)
                  PlanningSelectModeHeader(
                    scheme: scheme,
                    onExit: _exitSelectMode,
                    visiblePlans: visiblePlans,
                    allVisibleSelected: visiblePlans != null &&
                        _allVisiblePlanTasksSelected(visiblePlans),
                    onToggleSelectAll: visiblePlans != null
                        ? () => _toggleSelectAllVisiblePlans(visiblePlans)
                        : null,
                  ),
                Expanded(child: body),
              ],
            ),
          ),
          bottomNavigationBar: displayedForChrome != null
              ? PlanningBulkBottomBar(
                selectedCount: _selectedPlanKeys.length,
                onClear: _clearSelection,
                onBulkEdit: () => unawaited(_openBulkPlanningEdit(displayedForChrome!)),
                onBulkDelete: () => unawaited(_bulkDelete(displayedForChrome!)),
              )
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
          PlanningSortModeBar(
            sortMode: _sortMode,
            onSortModeChanged: (mode) => setState(() => _sortMode = mode),
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
                      child: PlanningQuickAddTagStrip(
                        scheme: scheme,
                        tagsLoading: _quickAddTagsLoading,
                        availableTags: _quickAddAvailableTags,
                        selectedTags: _creationSelectedTags,
                        onToggleTag: _toggleCreationTag,
                        onOpenTagManager: _openTagManagerFromQuickAdd,
                        onReorder: _quickAddAvailableTags.length >= 2
                            ? _onPlanningQuickBarReorder
                            : null,
                      ),
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
                    onPressed: timeView.showPlanningSettingsSheet,
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
          child: kUseMountedDayStrip &&
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
