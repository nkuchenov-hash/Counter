import 'dart:async';

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/date_pager_settle_gate.dart';
import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/core/p0_date_nav_diag.dart';
import 'package:counter/core/perf_diag.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/stats/stats_view.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
// ---------------------------------------------------------------------------
// TIMELINE FEATURE вЂ” UI_ISOLATION (В§7). PLANETARY TIME PROTOCOL (В§5). ACTIVE_STATUS_LAW (В§2).
// All strings via t() from dictionary. Timeline **day** keys use profile wall-calendar via DatabaseService ([DATA_MAP] В§8).
// ---------------------------------------------------------------------------

// --- Time helpers: device-local calendar for day strip; profile offset for clock labels only ---
DateTime _localToday() =>
    DatabaseService.instance.getTimelineDeviceLocalToday();

bool _isToday(DateTime date) {
  final today = DatabaseService.instance.getTimelineDeviceLocalToday();
  return date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
}

/// Calendar strip / timeline keys (naive date components from picker / swipe).
DateTime _dateOnlyCalendar(DateTime d) => DateTime(d.year, d.month, d.day);

/// For record `startTime` (UTC): **profile wall-calendar** Y-M-D (must match [recordsStream] buckets; [DATA_MAP] В§8).
String _wallCalendarDayKeyFromUtcInstant(DateTime startUtcOrAny) {
  final wall = DatabaseService.instance.applyUserOffset(startUtcOrAny.toUtc());
  return '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
}

String _formatTimeOfDay(DateTime dt) =>
    DateFormat.Hm(currentLocale.value).format(dt);

DateTime _utcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);

String _formatDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  if (m > 0) {
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${s}s';
}

/// Wraps Timeline in a PageView for swipe-to-change date. Exported for LifeOSDashboard.
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
  static const int _centerIndex = 5000;
  late PageController _controller;
  late int _visiblePageIndex;

  /// External date from shell while this tab is inactive вЂ” applied on activation only.
  int? _pendingExternalPage;

  final DatePagerSettleGate _settleGate = DatePagerSettleGate();
  Timer? _prefetchDebounce;

  void _schedulePrefetch(DateTime center) {
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      DatabaseService.instance.prefetchTimelineDayNeighbors(center);
    });
  }

  void _applyPendingExternalPageIfNeeded() {
    final pending = _pendingExternalPage;
    if (pending == null || _settleGate.blocksExternalDateSync) return;
    _pendingExternalPage = null;
    if (pending < 0 || pending >= 10000) return;
    if (!_controller.hasClients) return;
    final cur = _controller.page?.round();
    if (cur == pending) return;
    _settleGate.resetCommittedPage(pending);
    setState(() => _visiblePageIndex = pending);
    _controller.jumpToPage(pending);
  }

  /// Shared across all [TimelinePage] indices so calendar/date changes keep List vs Stats.
  bool _showStatsView = false;

  int _pageIndexForDate(DateTime date) {
    final daysOffset = _dateOnlyCalendar(date).difference(_anchorToday).inDays;
    return _centerIndex + daysOffset;
  }

  void _syncOnTabActivated() {
    final page = _pendingExternalPage ?? _pageIndexForDate(widget.selectedDate);
    _pendingExternalPage = null;
    if (page < 0 || page >= 10000) return;
    setState(() => _visiblePageIndex = page);
    if (!_controller.hasClients) return;
    final cur = _controller.page?.round();
    if (cur == page) return;
    PerfDiag.instance.pagerSync(
      section: 'Timeline',
      op: 'jumpToPage',
      targetPage: page,
      shellTabActive: true,
      hidden: false,
    );
    _controller.jumpToPage(page);
  }

  void _deferHiddenExternalDate(DateTime date) {
    final page = _pageIndexForDate(date);
    if (page < 0 || page >= 10000) return;
    _pendingExternalPage = page;
    PerfDiag.instance.pagerSync(
      section: 'Timeline',
      op: 'deferHidden',
      targetPage: page,
      shellTabActive: false,
      hidden: true,
    );
  }

  DateTime get _anchorToday =>
      _dateOnlyCalendar(DatabaseService.instance.getTimelineDeviceLocalToday());

  DateTime _dateForIndex(int index) {
    final raw = _anchorToday.add(Duration(days: index - _centerIndex));
    return _dateOnlyCalendar(raw);
  }

  void _syncPagerToDate(DateTime date, {required bool animate}) {
    if (!widget.shellTabActive) {
      _deferHiddenExternalDate(date);
      return;
    }
    final page = _pageIndexForDate(date);
    if (page < 0 || page >= 10000) return;
    _visiblePageIndex = page;
    if (!_controller.hasClients) return;
    final cur = _controller.page;
    if (cur != null && cur.round() == page) return;
    if (animate) {
      PerfDiag.instance.pagerSync(
        section: 'Timeline',
        op: 'animateToPage',
        targetPage: page,
        shellTabActive: widget.shellTabActive,
        hidden: false,
      );
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
    } else {
      PerfDiag.instance.pagerSync(
        section: 'Timeline',
        op: 'jumpToPage',
        targetPage: page,
        shellTabActive: widget.shellTabActive,
        hidden: false,
      );
      _controller.jumpToPage(page);
    }
  }

  @override
  void initState() {
    super.initState();
    final daysOffset = _dateOnlyCalendar(
      widget.selectedDate,
    ).difference(_anchorToday).inDays;
    _visiblePageIndex = _centerIndex + daysOffset;
    _controller = PageController(initialPage: _visiblePageIndex);
    _controller.addListener(_onPageControllerTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfDiag.instance.scheduleAutoSwipeSequence(
        section: 'Timeline',
        controller: _controller,
        visiblePageIndex: _visiblePageIndex,
        shellTabActive: widget.shellTabActive,
        dateKeyForPage: (i) => _dateKeyShort(_dateForIndex(i)),
      );
    });
  }

  void _onPageControllerTick() {
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    PerfDiag.instance.dateSwipeDrag(
      section: 'Timeline',
      page: page.round(),
      pageFraction: page,
    );
  }

  String _dateKeyShort(DateTime d) => _dateKey(d);

  @override
  void didUpdateWidget(covariant TimelineSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.shellTabActive && widget.shellTabActive) {
      _syncOnTabActivated();
      return;
    }

    if (!widget.shellTabActive) {
      final oldD = _dateOnlyCalendar(oldWidget.selectedDate);
      final newD = _dateOnlyCalendar(widget.selectedDate);
      if (oldD.year != newD.year ||
          oldD.month != newD.month ||
          oldD.day != newD.day) {
        _deferHiddenExternalDate(widget.selectedDate);
      }
      return;
    }

    final oldD = _dateOnlyCalendar(oldWidget.selectedDate);
    final newD = _dateOnlyCalendar(widget.selectedDate);
    if (oldD.year == newD.year &&
        oldD.month == newD.month &&
        oldD.day == newD.day) {
      return;
    }
    if (_settleGate.blocksExternalDateSync) {
      _pendingExternalPage = _pageIndexForDate(widget.selectedDate);
      return;
    }
    setState(() {
      _syncPagerToDate(widget.selectedDate, animate: true);
    });
  }

  @override
  void dispose() {
    _prefetchDebounce?.cancel();
    _settleGate.dispose();
    _controller.removeListener(_onPageControllerTick);
    _controller.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    perfRebuildTick('TimelineSwipeWrapper');
    return ScrollConfiguration(
      behavior: const MouseDragScrollBehavior(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _settleGate.onUserDragStart();
            PerfDiag.instance.dateSwipeStart(
              section: 'Timeline',
              fromDate: _dateKeyShort(_dateForIndex(_visiblePageIndex)),
            );
          }
          if (n is ScrollEndNotification) {
            _settleGate.onUserDragEnd();
            _applyPendingExternalPageIfNeeded();
            logDateSwipeThresholdOnScrollEnd(
              section: 'Timeline',
              controller: _controller,
              notification: n,
              log: ({
                required String section,
                required double dragFraction,
                required double velocity,
                required bool accepted,
                required int fromPage,
                required int toPage,
              }) {
                PerfDiag.instance.dateSwipeThreshold(
                  section: section,
                  dragFraction: dragFraction,
                  velocity: velocity,
                  accepted: accepted,
                  fromPage: fromPage,
                  toPage: toPage,
                );
              },
            );
            SchedulerBinding.instance.addPostFrameCallback((_) {
              PerfDiag.instance.dateSwipeEnd(section: 'Timeline');
            });
          }
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          physics: const PageScrollPhysics(),
          itemCount: 10000,
          onPageChanged: (int index) {
            if (index < 0 || index >= 10000) return;
            P0DateNavDiag.timelineDateNav(
              'page=$index date=${_dateKeyShort(_dateForIndex(index))}',
            );
            setState(() => _visiblePageIndex = index);
            _settleGate.onPageSettled(
              pageIndex: index,
              onShellCommit: (page) {
                if (!mounted) return;
                final next = _dateForIndex(page);
                _schedulePrefetch(next);
                final sel = _dateOnlyCalendar(widget.selectedDate);
                final shellWillUpdate = !(next.year == sel.year &&
                    next.month == sel.month &&
                    next.day == sel.day);
                if (!shellWillUpdate) return;
                P0DateNavDiag.timelineDateNav('shell_commit date=${_dateKeyShort(next)}');
                widget.onDateChanged(next);
              },
            );
          },
        itemBuilder: (context, index) {
          final date = _dateForIndex(index);
          final dateKey = _dateKey(date);
          final isFuture = date.isAfter(_anchorToday);
          final isVisible =
              widget.shellTabActive && index == _visiblePageIndex;
          return TimelinePage(
            selectedDate: date,
            selectedDateString: dateKey,
            isFutureDate: isFuture,
            tasks: isVisible ? widget.tasks : const [],
            tasksLoading: isVisible ? widget.tasksLoading : false,
            isActivePage: isVisible,
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
            onShowStatsViewChanged: (v) => setState(() => _showStatsView = v),
          );
        },
        ),
      ),
    );
  }
}

/// Single timeline tab page: list/stats toggle (above input), task input row, record list or StatsView.
class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    required this.selectedDate,
    required this.selectedDateString,
    required this.isFutureDate,
    required this.tasks,
    required this.tasksLoading,
    required this.isActivePage,
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

  /// Picks a calendar day (AppBar / Stats PageView); drives parent [TimelineSwipeWrapper] PageController.
  final void Function(DateTime date)? onNavigateToDate;

  /// List vs Stats segment; owned by [TimelineSwipeWrapper] so date jumps preserve mode.
  final bool showStatsView;
  final ValueChanged<bool> onShowStatsViewChanged;

  final DateTime selectedDate;
  final String selectedDateString;
  final bool isFutureDate;
  final List<Task> tasks;
  final bool tasksLoading;
  final bool isActivePage;
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
  Stream<List<Map<String, dynamic>>>? _recordsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _recordsSub;

  /// Last non-transient list for this calendar day; keeps ListView stable when stream
  /// briefly emits `waiting` + empty during background refresh.
  List<Map<String, dynamic>> _lastCoalescedRecords = [];

  void _initStream() {
    _recordsSub?.cancel();
    _lastCoalescedRecords = List<Map<String, dynamic>>.from(
      DatabaseService.instance.peekTimelineRecordsForDate(widget.selectedDate),
    );
    _recordsStream = DatabaseService.instance.recordsStream(
      widget.selectedDate,
    );
    _recordsSub = _recordsStream!.listen((records) {
      if (!mounted || !widget.isActivePage) return;
      if (records.isNotEmpty) {
        _lastCoalescedRecords = List<Map<String, dynamic>>.from(records);
      }
      setState(() {});
    });
  }

  List<Map<String, dynamic>> _recordsForListArea() {
    if (_lastCoalescedRecords.isNotEmpty) {
      return _lastCoalescedRecords;
    }
    return DatabaseService.instance.peekTimelineRecordsForDate(
      widget.selectedDate,
    );
  }

  /// List / stats / virtualized record list (lazy VMs in list builder).
  Widget _buildTimelineRecordsArea(BuildContext context) {
    if (widget.showStatsView) {
      final records = DatabaseService.instance.peekTimelineRecordsForDate(
        widget.selectedDate,
      );
      if (records.isEmpty) {
        return EmptyStatePlaceholder(
          icon: Icons.schedule_rounded,
          titleL10nKey: 'empty_timeline_title',
          subtitleL10nKey: 'empty_timeline_subtitle',
          actionLabelL10nKey: 'empty_action_focus_search',
          onAction: () => widget.titleFocus.requestFocus(),
        );
      }
      return StatsView(
        records: records,
        rules: widget.rules,
        isFutureDate: widget.isFutureDate,
        selectedDate: widget.selectedDate,
        onDayChanged: widget.onNavigateToDate,
      );
    }

    final recordMaps = _recordsForListArea();
    if (recordMaps.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.schedule_rounded,
        titleL10nKey: 'empty_timeline_title',
        subtitleL10nKey: 'empty_timeline_subtitle',
        actionLabelL10nKey: 'empty_action_focus_search',
        onAction: () => widget.titleFocus.requestFocus(),
      );
    }
    return _TimelineLazyRecordList(
      recordMaps: recordMaps,
      dateKey: widget.selectedDateString,
      selectedDate: widget.selectedDate,
      selectedDateString: widget.selectedDateString,
      onStop: widget.onStopRecord,
      onDelete: widget.onDeleteRecord,
      onEdit: (data) => _showEditRecordSheet(context, data),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActivePage) {
      _initStream();
    }
  }

  @override
  void dispose() {
    _recordsSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TimelinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActivePage && widget.isActivePage) {
      _initStream();
      return;
    }
    if (!widget.isActivePage) {
      if (oldWidget.isActivePage) {
        _recordsSub?.cancel();
        _recordsSub = null;
      }
      return;
    }
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month ||
        oldWidget.selectedDate.day != widget.selectedDate.day) {
      _initStream();
      setState(() {});
    }
  }

  void _showEditRecordSheet(BuildContext context, Map<String, dynamic> data) {
    widget.onShowEditRecordSheet(context, data);
  }

  @override
  Widget build(BuildContext context) {
    perfRebuildTick('TimelinePage');
    if (!widget.isActivePage) {
      return const ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      );
    }
    P0DateNavDiag.timelineBuild(
      'date=${widget.selectedDateString} records=${_lastCoalescedRecords.length}',
    );
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                height: kAppCompactControlHeight,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: appCompactSegmentedButtonStyle(
                    context,
                    segmentWidth: 112,
                  ),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.list_rounded),
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'list'),
                      ),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'stats'),
                      ),
                    ),
                  ],
                  selected: {widget.showStatsView},
                  onSelectionChanged: (Set<bool> sel) {
                    if (sel.isEmpty) return;
                    widget.onShowStatsViewChanged(sel.first);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.isActivePage
                          ? widget.titleController
                          : null,
                      focusNode: widget.isActivePage ? widget.titleFocus : null,
                      enabled: widget.isActivePage,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (widget.isFutureDate) {
                          widget.onPlan();
                        } else if (_isToday(widget.selectedDate)) {
                          widget.onStart();
                        } else {
                          widget.onNewTaskForPastDate();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: t(
                          currentLocale.value,
                          'input_placeholder_record',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final projectedToday = _localToday();
                      final isToday =
                          widget.selectedDate.year == projectedToday.year &&
                          widget.selectedDate.month == projectedToday.month &&
                          widget.selectedDate.day == projectedToday.day;
                      final isFuture = widget.isFutureDate;
                      return FilledButton.icon(
                        onPressed: () {
                          if (isFuture) {
                            widget.onPlan();
                          } else if (isToday) {
                            widget.onStart();
                          } else {
                            widget.onNewTaskForPastDate();
                          }
                        },
                        icon: Icon(
                          isFuture
                              ? Icons.event_rounded
                              : isToday
                              ? Icons.play_arrow_rounded
                              : Icons.add_task_rounded,
                        ),
                        label: Text(
                          isFuture
                              ? t(currentLocale.value, 'plan')
                              : isToday
                              ? t(currentLocale.value, 'start_timer')
                              : t(currentLocale.value, 'new_record_btn'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(child: _buildTimelineRecordsArea(context)),
          ],
        ),
      ),
    );
  }
}

/// Virtualized timeline record list вЂ” no [StreamBuilder] over full list; active overlay optional.
class _TimelineLazyRecordList extends StatefulWidget {
  const _TimelineLazyRecordList({
    required this.recordMaps,
    required this.dateKey,
    required this.selectedDate,
    required this.selectedDateString,
    required this.onStop,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> recordMaps;
  final String dateKey;
  final DateTime selectedDate;
  final String selectedDateString;
  final Future<void> Function(String systemRowId) onStop;
  final Future<void> Function(String systemRowId) onDelete;
  final void Function(Map<String, dynamic> data) onEdit;

  @override
  State<_TimelineLazyRecordList> createState() => _TimelineLazyRecordListState();
}

class _TimelineLazyRecordListState extends State<_TimelineLazyRecordList> {
  StreamSubscription<Map<String, dynamic>?>? _activeSub;
  Map<String, dynamic>? _active;
  String? _activeOtherDayStr;

  bool _mapLooksRunning(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? 'record');
    if (type != 'record') return false;
    return CategoryServiceExtension.isRecordMapActuallyRunning(data);
  }

  bool get _needsActiveOverlay =>
      widget.recordMaps.any(_mapLooksRunning) ||
      _isToday(widget.selectedDate);

  @override
  void initState() {
    super.initState();
    if (_needsActiveOverlay) {
      _activeSub = DatabaseService.instance.activeRecordStream.listen((active) {
        if (!mounted) return;
        String? otherDay;
        if (active != null) {
          otherDay = active['calendarDayStr'] as String?;
          if ((otherDay == null || otherDay.isEmpty)) {
            final st = active['startTime'] as DateTime?;
            if (st != null) {
              otherDay = _wallCalendarDayKeyFromUtcInstant(st);
            }
          }
        }
        setState(() {
          _active = active;
          _activeOtherDayStr = otherDay;
        });
      });
    }
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = Stopwatch()..start();
    final maps = widget.recordMaps;
    if (kPerfDiagnosisEnabled) {
      PerfDiag.instance.logTimelineVisibleBuild(
        itemCount: maps.length,
        ms: sw.elapsedMilliseconds,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 320,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemCount: maps.length,
      itemBuilder: (context, index) {
        PerfDiag.instance.logTimelineRowBuildTick();
        final data = maps[index];
        final vm = DatabaseService.instance.timelineRowVmForRecordMapOrNull(
          widget.dateKey,
          data,
        );
        final biz = (data['record_id'] ?? '').toString().trim();
        final tileKey = ValueKey<String>(
          biz.isNotEmpty ? biz : 'record-fallback-$index',
        );
        String? otherDayBanner;
        if (_active != null &&
            biz.isNotEmpty &&
            biz == (_active!['record_id'] ?? '').toString().trim() &&
            _activeOtherDayStr != null &&
            _activeOtherDayStr!.isNotEmpty &&
            _activeOtherDayStr != widget.selectedDateString) {
          otherDayBanner = _activeOtherDayStr;
        }
        return Padding(
          padding: EdgeInsets.only(bottom: index < maps.length - 1 ? 10 : 0),
          child: KeyedSubtree(
            key: tileKey,
            child: RepaintBoundary(
              child: _TimelineRecordCard(
                vm: vm,
                currentActivityFromDate: otherDayBanner,
                onStop: widget.onStop,
                onDelete: widget.onDelete,
                onEdit: () => widget.onEdit(data),
              ),
            ),
          ),
        );
      },
    );
  }
}

List<Widget> _timelineRowMetaIconsFromVm(
  BuildContext context,
  TimelineRecordRowVm vm,
) {
  final base = Theme.of(context).iconTheme.color;
  final color = base?.withValues(alpha: 0.48);
  if (color == null) return const [];
  final out = <Widget>[];
  void add(IconData icon) {
    if (out.isNotEmpty) out.add(const SizedBox(width: 4));
    out.add(Icon(icon, size: 15, color: color));
  }

  if (vm.showNotesIcon) add(Icons.sticky_note_2_outlined);
  if (vm.showChecklistIcon) add(Icons.checklist_rounded);
  if (vm.showParentIcon) add(Icons.account_tree_outlined);
  if (vm.showLinkedSubsIcon) add(Icons.layers_outlined);
  return out;
}

/// Single timeline card: running shows live timer + Stop, completed shows duration.
class _TimelineRecordCard extends StatefulWidget {
  const _TimelineRecordCard({
    required this.vm,
    this.currentActivityFromDate,
    required this.onStop,
    required this.onDelete,
    required this.onEdit,
  });

  final TimelineRecordRowVm vm;
  final String? currentActivityFromDate;
  final Future<void> Function(String systemRowId) onStop;
  final Future<void> Function(String systemRowId) onDelete;
  final VoidCallback onEdit;

  @override
  State<_TimelineRecordCard> createState() => _TimelineRecordCardState();
}

class _TimelineRecordCardState extends State<_TimelineRecordCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfRunning();
  }

  @override
  void didUpdateWidget(_TimelineRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vm.isCanonicalRunning != widget.vm.isCanonicalRunning) {
      _startTimerIfRunning();
    }
  }

  void _startTimerIfRunning() {
    _timer?.cancel();
    _timer = null;
    if (widget.vm.isCanonicalRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(currentLocale.value, 'delete_record_confirm')),
        content: Text(t(currentLocale.value, 'cannot_undo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(currentLocale.value, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.onDelete(widget.vm.systemRowId);
    }
  }

  String _subtitleForBuild() {
    if (widget.vm.isPlanned) {
      return t(currentLocale.value, 'planned_label');
    }
    if (widget.vm.isCanonicalRunning) {
      final startTimeUtc = CategoryServiceExtension.startTimeFromRecord(
        widget.vm.rawData,
      );
      if (startTimeUtc != null) {
        final start = _formatTimeOfDay(_utcToDisplay(startTimeUtc));
        final duration = DatabaseService.getPlanetaryNow().difference(
          startTimeUtc,
        );
        return '$start вЂ” ... (${_formatDuration(duration)})';
      }
      return t(currentLocale.value, 'running_label');
    }
    if (widget.vm.subtitle == 'planned' || widget.vm.subtitle == 'running') {
      return t(currentLocale.value, 'running_label');
    }
    return widget.vm.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRunning = widget.vm.isCanonicalRunning;
    final subtitle = _subtitleForBuild();
    final metaIcons = _timelineRowMetaIconsFromVm(context, widget.vm);

    final runningFill = isRunning ? AppColors.cardSurface : null;
    final runningBorder = isRunning ? scheme.primary : Colors.transparent;
    final runningTextColor = isRunning ? scheme.onSurface : null;

    const cardRadius = 12.0;

    final paddedRow = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.currentActivityFromDate != null) ...[
                  Text(
                    t(
                      currentLocale.value,
                      'current_activity_from',
                    ).replaceFirst('%s', widget.currentActivityFromDate!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.vm.title,
                        style: Theme.of(context).textTheme.titleMedium,
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
                const SizedBox(height: 6),
                CategoryBreadcrumb(
                  breadcrumbPath: widget.vm.categoryPath,
                  accentColor: widget.vm.categoryColor,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isRunning
                          ? runningTextColor
                          : scheme.onSurfaceVariant,
                      fontWeight: isRunning ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isRunning)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: FilledButton.icon(
                onPressed: () => widget.onStop(widget.vm.systemRowId),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: Text(t(currentLocale.value, 'stop')),
              ),
            ),
          IconButton(
            style: IconButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: t(currentLocale.value, 'delete'),
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );

    return Material(
      elevation: isRunning ? 2 : 1,
      color: runningFill ?? scheme.surface,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(
          color: isRunning ? runningBorder : scheme.outlineVariant.withValues(alpha: 0.35),
          width: isRunning ? 2.0 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onEdit,
        borderRadius: BorderRadius.circular(cardRadius),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: widget.vm.categoryColor, width: 4),
            ),
          ),
          child: paddedRow,
        ),
      ),
    );
  }
}
