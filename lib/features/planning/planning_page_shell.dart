// Planning date pager shell — wraps [PlanningPage] per day.
import 'dart:async';

import 'package:counter/core/date_pager_settle_gate.dart';
import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/diagnostics/runtime_log.dart';
import 'package:counter/core/diagnostics/platform_log.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

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
    if (kUseMountedDayStrip) return;
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
    RuntimeLog.p0tDisabled(platform: platform, enabled: kUseMountedDayStrip);
    RuntimeLog.biometricGate(enabled: false, reason: 'stabilization');
    _anchorDate = DateUtils.dateOnly(DateTime.now());
    final daysOffset =
        _dateOnly(widget.selectedDate).difference(_anchorDate).inDays;
    _visiblePageIndex = _initialPage + daysOffset;
    _controller = PageController(initialPage: _visiblePageIndex);
    _controller.addListener(_onPageControllerTick);
    if (kPlansWarmWindowEnabled && !kUseMountedDayStrip) {
      DatabaseService.instance.ensurePlansWarmWindow(widget.selectedDate);
    }
  }

  void _onPageControllerTick() {
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    RebuildMetrics.instance.dateSwipeDrag(
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
    rebuildMetricsTick('PlanningSwipeWrapper');
    if (kUseMountedDayStrip) {
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
              RebuildMetrics.instance.dateSwipeStart(
                section: 'Planning',
                fromDate: from,
              );
            }
            if (n is ScrollEndNotification) {
              _settleGate.onUserDragEnd();
              _applyPendingExternalPageIfNeeded();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                RebuildMetrics.instance.dateSwipeEnd(section: 'Planning');
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

  /// Legacy P0S/P0T path — disabled when [kUseMountedDayStrip] is false.
  Widget _buildMountedStripFallback(BuildContext context) {
    return AppErrorState(
      message: t(currentLocale.value, 'no_data_found'),
    );
  }
}

/// Single-day planning: task list, add task, date picker.
