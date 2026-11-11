import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/date_pager_settle_gate.dart';
import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/shared/diagnostics/runtime_log.dart';
import 'package:counter/shared/diagnostics/performance/runtime_flags.dart';
import 'package:counter/shared/diagnostics/platform_log.dart';
import 'package:counter/core/widgets/day_content_strip.dart';
import 'package:counter/core/widgets/day_window.dart';
import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/stats/stats_view.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:counter/features/timeline/timeline_helpers.dart';
import 'package:counter/features/timeline/timeline_day_page.dart';
import 'package:counter/features/timeline/timeline_header_controls.dart';
import 'package:counter/features/timeline/timeline_morning_start.dart';
// ---------------------------------------------------------------------------
// TIMELINE FEATURE вЂ” UI_ISOLATION (В§7). PLANETARY TIME PROTOCOL (В§5). ACTIVE_STATUS_LAW (В§2).
// All strings via t() from dictionary. Timeline **day** keys use profile wall-calendar via DatabaseService ([DATA_MAP] В§8).
// ---------------------------------------------------------------------------

// --- Time helpers: device-local calendar for day strip; profile offset for clock labels only ---
DateTime _localToday() => timelineLocalToday();

bool _isToday(DateTime date) => timelineIsToday(date);

DateTime _dateOnlyCalendar(DateTime d) => timelineDateOnlyCalendar(d);

String _wallCalendarDayKeyFromUtcInstant(DateTime startUtcOrAny) =>
    timelineWallCalendarDayKeyFromUtcInstant(startUtcOrAny);

String _formatTimeOfDay(DateTime dt) => timelineFormatTimeOfDay(dt);

DateTime _utcToDisplay(DateTime utc) => timelineUtcToDisplay(utc);

String _formatDuration(Duration d) => timelineFormatDuration(d);

/// Wraps Timeline in a PageView for swipe-to-change date. Exported for LifeOSDashboard.
///
/// SWIPE GUARD: Do not replace restored [PageView] date paging with custom slot pager. Failed P0H–P0L.
class TimelineSwipeWrapper extends StatefulWidget {
  const TimelineSwipeWrapper({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.shellTabActive = true,
    required this.onJumpToConflict,
    required this.tasks,
    required this.tasksLoading,
    required this.titleController,
    required this.titleFocus,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStart,
    required this.onPlan,
    required this.onNewTaskForPastDate,
    required this.onStopRecord,
    required this.onDeleteRecord,
    required this.rules,
    required this.onShowEditRecordSheet,
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateChanged;
  final bool shellTabActive;
  final void Function(DateTime date)? onJumpToConflict;
  final List<Task> tasks;
  final bool tasksLoading;
  final TextEditingController titleController;
  final FocusNode titleFocus;
  final int? selectedCategoryId;
  final void Function(int? categoryId) onCategoryChanged;
  final Future<void> Function() onStart;
  final Future<void> Function() onPlan;
  final VoidCallback onNewTaskForPastDate;

  /// PocketBase `records.id` (not legacy `record_id` UUID).
  final Future<void> Function(String systemRowId) onStopRecord;
  final Future<void> Function(String systemRowId) onDeleteRecord;
  final List<CategoryRule> rules;
  final void Function(BuildContext context, Map<String, dynamic> data)
  onShowEditRecordSheet;

  @override
  State<TimelineSwipeWrapper> createState() => _TimelineSwipeWrapperState();
}

class _TimelineSwipeWrapperState extends State<TimelineSwipeWrapper> {
  static const int _initialPage = 5000;
  static const int _totalPageCount = 10000;
  late PageController _controller;
  late DateTime _anchorDate;
  late int _visiblePageIndex;
  int? _pendingExternalPage;
  final DatePagerSettleGate _settleGate = DatePagerSettleGate();
  bool _showStatsView = false;
  bool _restoreQuickEntryFocusOnReturn = false;
  String? _swipeFromDateKey;

  String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _anchorToday =>
      _dateOnly(DatabaseService.instance.getTimelineDeviceLocalToday());

  void _applyPendingExternalPageIfNeeded() {
    if (_settleGate.blocksExternalDateSync) return;
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
    _scheduleAdjacentRowVmWarmup(widget.selectedDate);
  }

  void _deferHiddenExternalDate() {
    final page = _pageIndexForDate(widget.selectedDate);
    if (page < 0 || page >= _totalPageCount) return;
    _pendingExternalPage = page;
  }

  void _schedulePrefetch(DateTime center) {
    if (kUseMountedDayStrip) return;
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        DatabaseService.instance.extendTimelineWarmWindowIfNeeded(center);
        _ensureAdjacentRowVmWarmup(center);
      }),
    );
  }

  void _scheduleAdjacentRowVmWarmup(DateTime center) {
    if (kUseMountedDayStrip || !kTimelineAdjacentRowVmWarmup) return;
    final centerKey = _dateKeyFromDate(center);
    DatabaseService.instance.scheduleTimelineAdjacentRowVmWarmup(
      center,
      timelineTabActive: () => mounted && widget.shellTabActive,
      centerDateUnchanged: () =>
          mounted && _adjVmWarmCenterStillCurrent(centerKey),
    );
  }

  void _ensureAdjacentRowVmWarmup(DateTime center) {
    if (kUseMountedDayStrip || !kTimelineAdjacentRowVmWarmup) return;
    final centerKey = _dateKeyFromDate(center);
    DatabaseService.instance.ensureTimelineAdjacentRowVmWarmup(
      center,
      timelineTabActive: () => mounted && widget.shellTabActive,
      centerDateUnchanged: () =>
          mounted && _adjVmWarmCenterStillCurrent(centerKey),
    );
  }

  bool _adjVmWarmCenterStillCurrent(String centerKey) {
    final visibleKey = _dateKeyFromDate(_dateForIndex(_visiblePageIndex));
    if (visibleKey == centerKey) return true;
    return _dateKeyFromDate(widget.selectedDate) == centerKey;
  }

  @override
  void initState() {
    super.initState();
    final platform = p0uPlatformLabel();
    RuntimeLog.p0tDisabled(platform: platform, enabled: kUseMountedDayStrip);
    RuntimeLog.logAdjVmWarmDisabledIfNeeded();
    RuntimeLog.biometricGate(enabled: false, reason: 'stabilization');
    _anchorDate = DateUtils.dateOnly(DateTime.now());
    final daysOffset = _dateOnly(
      widget.selectedDate,
    ).difference(_anchorDate).inDays;
    _visiblePageIndex = _initialPage + daysOffset;
    _controller = PageController(initialPage: _visiblePageIndex);
    _controller.addListener(_onPageControllerTick);
    if (!kUseMountedDayStrip) {
      DatabaseService.instance.ensureTimelineWarmWindow(widget.selectedDate);
      if (widget.shellTabActive) {
        _scheduleAdjacentRowVmWarmup(widget.selectedDate);
      }
    }
  }

  // Use the existing native Timeline pager, never a separate date switcher.
  // The same PageView onPageChanged path owns the shell's date commit.
  void _navigateBySideArrow(int delta) {
    if (!widget.shellTabActive || delta == 0 || !_controller.hasClients) return;
    if (_controller.position.isScrollingNotifier.value) return;
    final current = _controller.page?.round() ?? _visiblePageIndex;
    final target = current + (delta < 0 ? -1 : 1);
    if (target < 0 || target >= _totalPageCount) return;
    _settleGate.markProgrammaticAnimStart();
    unawaited(_controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      if (!mounted) return;
      _settleGate.markProgrammaticAnimEnd();
      _applyPendingExternalPageIfNeeded();
    }));
  }

  void _onPageControllerTick() {
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    RebuildMetrics.instance.dateSwipeDrag(
      section: 'Timeline',
      page: page.round(),
      pageFraction: page,
    );
  }

  @override
  void didUpdateWidget(covariant TimelineSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shellTabActive && !widget.shellTabActive) {
      // Hidden tabs must not own the keyboard or reattach a shared FocusNode.
      _restoreQuickEntryFocusOnReturn = widget.titleFocus.hasFocus;
      widget.titleFocus.unfocus();
    }
    if (!oldWidget.shellTabActive && widget.shellTabActive) {
      _syncOnTabActivated();
      if (_restoreQuickEntryFocusOnReturn && !_showStatsView) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.shellTabActive && !_showStatsView) {
            widget.titleFocus.requestFocus();
          }
        });
      }
      _restoreQuickEntryFocusOnReturn = false;
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
    if (_settleGate.blocksExternalDateSync) {
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

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('TimelineSwipeWrapper');
    if (kUseMountedDayStrip) {
      return AppErrorState(message: t(currentLocale.value, 'no_data_found'));
    }
    final visibleDate = _dateForIndex(_visiblePageIndex);
    try {
      return Column(
        children: [
          TimelineHeaderControls(
            showStatsView: _showStatsView,
            inputActive: widget.shellTabActive,
            visibleDate: visibleDate,
            visibleIsFuture: visibleDate.isAfter(_anchorToday),
            titleController: widget.titleController,
            titleFocus: widget.titleFocus,
            onShowStatsViewChanged: (v) => setState(() => _showStatsView = v),
            onStart: widget.onStart,
            onPlan: widget.onPlan,
            onNewTaskForPastDate: widget.onNewTaskForPastDate,
          ),
          Expanded(
            child: TimelineWorkspaceDayArrows(
              visible: widget.shellTabActive,
              enabled: widget.shellTabActive,
              onPrevious: () => _navigateBySideArrow(-1),
              onNext: () => _navigateBySideArrow(1),
              child: ScrollConfiguration(
        behavior: const MouseDragScrollBehavior(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _settleGate.onUserDragStart();
              _swipeFromDateKey = _dateKeyFromDate(visibleDate);
              RebuildMetrics.instance.dateSwipeStart(
                section: 'Timeline',
                fromDate: _swipeFromDateKey!,
              );
            }
            if (n is ScrollEndNotification) {
              _settleGate.onUserDragEnd();
              _applyPendingExternalPageIfNeeded();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                RebuildMetrics.instance.dateSwipeEnd(section: 'Timeline');
              });
            }
            return false;
          },
          child: PageView.builder(
            controller: _controller,
            physics: const FeatherDateSwipePhysics(),
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
              return TimelinePage(
                key: ValueKey<String>('tl-page-$dateKey'),
                selectedDate: date,
                visibleDate: date,
                anchorToday: _anchorToday,
                isActivePage: isActive,
                shellTabActive: widget.shellTabActive,
                titleController: widget.titleController,
                titleFocus: widget.titleFocus,
                selectedCategoryId: widget.selectedCategoryId,
                onCategoryChanged: widget.onCategoryChanged,
                onStart: widget.onStart,
                onPlan: widget.onPlan,
                onNewTaskForPastDate: widget.onNewTaskForPastDate,
                onStopRecord: widget.onStopRecord,
                onDeleteRecord: widget.onDeleteRecord,
                onJumpToConflictDate: widget.onJumpToConflict,
                rules: widget.rules,
                onShowEditRecordSheet: widget.onShowEditRecordSheet,
                onNavigateToDate: widget.onDateChanged,
                showStatsView: _showStatsView,
                onShowStatsViewChanged: (v) =>
                    setState(() => _showStatsView = v),
              );
            },
          ),
        ),
            ),
            ),
          ),
        ],
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('TimelineSwipeWrapper: $e\n$st');
      return Scaffold(
        body: AppErrorState(message: t(currentLocale.value, 'no_data_found')),
      );
    }
  }
}

/// Timeline tab: static chrome once; stable PageView day body (P0U).
/// Stationary desktop day controls in the free Timeline workspace gutters.
///
/// The PageView still owns every swipe and each record row retains its original
/// layout, scroll viewport and optimistic update stream. This root overlay only
/// paints two independent hit targets, outside the centered record cards.
class TimelineWorkspaceDayArrows extends StatefulWidget {
  const TimelineWorkspaceDayArrows({
    super.key,
    required this.child,
    required this.visible,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
  });

  final Widget child;
  final bool visible;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<TimelineWorkspaceDayArrows> createState() =>
      _TimelineWorkspaceDayArrowsState();
}

class _TimelineWorkspaceDayArrowsState extends State<TimelineWorkspaceDayArrows> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlay.show();
    });
  }

  Widget _arrow(BuildContext context, {required bool previous}) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 1,
      shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: AppIconButton(
        icon: previous ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        tooltip: t(currentLocale.value,
            previous ? 'date_previous_day' : 'date_next_day'),
        size: AppIconButtonSize.l,
        onPressed: !widget.enabled
            ? null
            : previous ? widget.onPrevious : widget.onNext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, pane) {
      return OverlayPortal(
        overlayLocation: OverlayChildLocation.rootOverlay,
        controller: _overlay,
        overlayChildBuilder: (overlayContext) => Positioned.fill(
          child: LayoutBuilder(builder: (overlayContext, root) {
            final windowWidth = root.maxWidth;
            if (!widget.visible ||
                !shellUsesSideNavigation(windowWidth) ||
                pane.maxWidth < 600) {
              return const SizedBox.shrink();
            }
            final render = context.findRenderObject();
            if (render is! RenderBox || !render.hasSize) {
              return const SizedBox.shrink();
            }
            final paneLeft = render.localToGlobal(Offset.zero).dx;
            final paneRight = paneLeft + pane.maxWidth;
            // Exactly the same canonical desktop record frame as
            // TimelineLazyRecordList: a centered readable frame plus 24px
            // internal card padding. Unlike the pager, it is NOT full width.
            final frameWidth = math.min(
              pane.maxWidth, shellReadableContentMaxWidth(windowWidth));
            final frameInset = (pane.maxWidth - frameWidth) / 2;
            final cardLeft =
                paneLeft + frameInset + kShellDesktopContentHorizontalPadding;
            final cardRight =
                paneRight - frameInset - kShellDesktopContentHorizontalPadding;
            final navEdge = kShellSideNavWidth;
            final leftFree = cardLeft - navEdge;
            final rightFree = windowWidth - cardRight;
            // A 48px button needs room on both sides. Never overlap cards or
            // the permanent navigation when the desktop pane is too narrow.
            if (leftFree < 72 || rightFree < 72) {
              return const SizedBox.shrink();
            }
            final leftOffset = (navEdge + cardLeft) / 2 - paneLeft;
            final rightOffset = (cardRight + windowWidth) / 2 - paneRight;
            return Stack(children: [
              Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.centerLeft,
                  followerAnchor: Alignment.center,
                  offset: Offset(leftOffset, 0),
                  child: KeyedSubtree(
                    key: const ValueKey('timeline-side-previous-day'),
                    child: _arrow(overlayContext, previous: true),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.centerRight,
                  followerAnchor: Alignment.center,
                  offset: Offset(rightOffset, 0),
                  child: KeyedSubtree(
                    key: const ValueKey('timeline-side-next-day'),
                    child: _arrow(overlayContext, previous: false),
                  ),
                ),
              ),
            ]);
          }),
        ),
        child: CompositedTransformTarget(link: _link, child: widget.child),
      );
    });
  }
}

class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    required this.selectedDate,
    required this.visibleDate,
    required this.anchorToday,
    this.isActivePage = false,
    this.shellTabActive = true,
    this.mountedWindow,
    this.stripController,
    this.onVisibleDateChanged,
    this.onUserDragStart,
    this.onUserDragEnd,
    this.onScrollTick,
    required this.titleController,
    required this.titleFocus,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStart,
    required this.onPlan,
    required this.onNewTaskForPastDate,
    required this.onStopRecord,
    required this.onDeleteRecord,
    required this.rules,
    this.onJumpToConflictDate,
    required this.onShowEditRecordSheet,
    this.onNavigateToDate,
    required this.showStatsView,
    required this.onShowStatsViewChanged,
  });

  final DateTime selectedDate;
  final DateTime visibleDate;
  final DateTime anchorToday;
  final bool isActivePage;
  final bool shellTabActive;
  final DayWindow? mountedWindow;
  final EagerDayContentStripController? stripController;
  final void Function(int windowIndex, DateTime date)? onVisibleDateChanged;
  final VoidCallback? onUserDragStart;
  final VoidCallback? onUserDragEnd;
  final void Function(double pageFraction)? onScrollTick;

  /// Picks a calendar day (AppBar / Stats PageView); drives parent strip.
  final void Function(DateTime date)? onNavigateToDate;

  final bool showStatsView;
  final ValueChanged<bool> onShowStatsViewChanged;

  final TextEditingController titleController;
  final FocusNode titleFocus;
  final int? selectedCategoryId;
  final void Function(int? categoryId) onCategoryChanged;
  final Future<void> Function() onStart;
  final Future<void> Function() onPlan;
  final VoidCallback onNewTaskForPastDate;

  /// PocketBase `records.id` (not legacy `record_id` UUID).
  final Future<void> Function(String systemRowId) onStopRecord;
  final Future<void> Function(String systemRowId) onDeleteRecord;
  final List<CategoryRule> rules;
  final void Function(DateTime date)? onJumpToConflictDate;

  /// Called when user taps a record to edit. Host (e.g. main) shows ActivityDetailSheet.
  final void Function(BuildContext context, Map<String, dynamic> data)
  onShowEditRecordSheet;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  // Repaint directly from the canonical Brain cache on every record mutation.
  // Do not hold an asynchronously coalesced list: it can lag behind realtime
  // and remain stale until the user leaves and reopens Timeline.
  StreamSubscription<void>? _timelineUpdatesSub;

  DateTime get _visibleDate => widget.visibleDate;

  String _dateKey(DateTime d) => DayWindow.dateKey(d);

  bool get _visibleIsFuture => _visibleDate.isAfter(widget.anchorToday);

  void _attachLiveTimelineUpdates() {
    if (!widget.isActivePage || _timelineUpdatesSub != null) return;
    // Listen synchronously during initState / activation, not after the first
    // frame or an awaited network read. Incoming SSE updates must never be
    // dropped during that window.
    _timelineUpdatesSub = DatabaseService.instance.timeUpdates.listen((_) {
      if (mounted && widget.isActivePage) setState(() {});
    });
  }

  List<Map<String, dynamic>>? _liveRecordsForVisibleDay() {
    if (!widget.isActivePage) return null;
    // One authoritative in-memory source for active Timeline rendering.
    // In particular, a confirmed remote delete must display an empty day.
    return DatabaseService.instance.peekTimelineRecordsForDate(_visibleDate);
  }

  @override
  void initState() {
    super.initState();
    _attachLiveTimelineUpdates();
  }

  @override
  void dispose() {
    _timelineUpdatesSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TimelinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActivePage && widget.isActivePage) {
      _attachLiveTimelineUpdates();
    } else if (oldWidget.isActivePage && !widget.isActivePage) {
      _timelineUpdatesSub?.cancel();
      _timelineUpdatesSub = null;
    }
    // The active day always reads the current cache in build. A date change
    // needs no asynchronous subscription teardown/recreation.
  }

  void _showEditRecordSheet(BuildContext context, Map<String, dynamic> data) {
    widget.onShowEditRecordSheet(context, data);
  }

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('TimelinePage');
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: MorningStartGate(
                selectedDate: _visibleDate,
                active: widget.isActivePage && widget.shellTabActive,
                titleController: widget.titleController,
                titleFocus: widget.titleFocus,
                onStart: widget.onStart,
                child:
                    kUseMountedDayStrip &&
                        widget.mountedWindow != null &&
                        widget.stripController != null &&
                        widget.onVisibleDateChanged != null
                    ? EagerDayContentStrip(
                        screen: 'Timeline',
                        dates: widget.mountedWindow!.dates,
                        initialIndex: () {
                          final raw = widget.mountedWindow!.indexOf(
                            _visibleDate,
                          );
                          return raw
                              .clamp(
                                0,
                                math.max(0, widget.mountedWindow!.length - 1),
                              )
                              .toInt();
                        }(),
                        activeIndex: () {
                          final raw = widget.mountedWindow!.indexOf(
                            _visibleDate,
                          );
                          return raw
                              .clamp(
                                0,
                                math.max(0, widget.mountedWindow!.length - 1),
                              )
                              .toInt();
                        }(),
                        controller: widget.stripController,
                        physics: const FeatherDateSwipePhysics(),
                        onUserDragStart: widget.onUserDragStart,
                        onUserDragEnd: widget.onUserDragEnd,
                        onScrollTick: widget.onScrollTick,
                        onIndexChanged: widget.onVisibleDateChanged!,
                        itemBuilder: (context, date, index, isActive) {
                          final dateKey = _dateKey(date);
                          return RepaintBoundary(
                            child: TimelineDayCardList(
                              key: ValueKey<String>('tl-day-$dateKey'),
                              date: date,
                              dateKey: dateKey,
                              isFutureDate: date.isAfter(widget.anchorToday),
                              isActive: isActive,
                              showStatsView: widget.showStatsView,
                              rules: widget.rules,
                              liveRecordMaps: isActive
                                  ? _liveRecordsForVisibleDay()
                                  : null,
                              onStop: widget.onStopRecord,
                              onDelete: widget.onDeleteRecord,
                              onEdit: (data) =>
                                  _showEditRecordSheet(context, data),
                              onNavigateToDate: widget.onNavigateToDate,
                              titleFocus: widget.titleFocus,
                            ),
                          );
                        },
                      )
                    : widget.isActivePage
                    ? RepaintBoundary(
                        child: TimelineDayCardList(
                          key: ValueKey<String>(
                            'tl-day-${_dateKey(_visibleDate)}',
                          ),
                          date: _visibleDate,
                          dateKey: _dateKey(_visibleDate),
                          isFutureDate: _visibleIsFuture,
                          isActive: true,
                          showStatsView: widget.showStatsView,
                          rules: widget.rules,
                          liveRecordMaps: _liveRecordsForVisibleDay(),
                          onStop: widget.onStopRecord,
                          onDelete: widget.onDeleteRecord,
                          onEdit: (data) => _showEditRecordSheet(context, data),
                          onNavigateToDate: widget.onNavigateToDate,
                          titleFocus: widget.titleFocus,
                        ),
                      )
                    : const ColoredBox(
                        color: Colors.transparent,
                        child: SizedBox.expand(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date-dependent timeline body only — real cards from warm snapshot (P0P).
