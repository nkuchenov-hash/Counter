// Planning shell: one persistent PlanningPage, never a pager of whole pages.
// Date swipes belong to the day content inside PlanningPage, not its chrome.
import 'dart:async';

import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/planning_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  }) onStartRecordFromTask;
  final void Function(PlanningTask task) onEditTask;

  @override
  State<PlanningSwipeWrapper> createState() => _PlanningSwipeWrapperState();
}

class _PlanningSwipeWrapperState extends State<PlanningSwipeWrapper> {
  late DateTime _visibleDate;
  late bool _timelineRangeReady;
  bool _datePagerLocked = false;
  DateTime? _deferredExternalDate;

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _visibleDate = DateUtils.dateOnly(widget.selectedDate);
    _timelineRangeReady =
        PlanningSheetTimelinePrefs.cachedVisibleDayRange != null;
    if (!_timelineRangeReady) unawaited(_loadTimelineRange());
    // Warm only the initial date. Never eagerly build two neighbor pages.
    DatabaseService.instance.ensurePlansWarmWindow(widget.selectedDate);
  }

  Future<void> _loadTimelineRange() async {
    try {
      await PlanningSheetTimelinePrefs.loadVisibleDayRange();
    } catch (e) {
      if (kDebugMode) debugPrint('Planning hour preferences: $e');
    }
    if (mounted) setState(() => _timelineRangeReady = true);
  }

  @override
  void didUpdateWidget(covariant PlanningSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (DateUtils.isSameDay(widget.selectedDate, oldWidget.selectedDate)) {
      return;
    }
    final requested = DateUtils.dateOnly(widget.selectedDate);
    if (_datePagerLocked) {
      _deferredExternalDate = requested;
    } else if (!DateUtils.isSameDay(requested, _visibleDate)) {
      setState(() => _visibleDate = requested);
    }
  }

  void _onDatePagerLockChanged(bool locked) {
    if (_datePagerLocked == locked) return;
    setState(() => _datePagerLocked = locked);
    if (!locked && _deferredExternalDate != null) {
      final pending = _deferredExternalDate!;
      _deferredExternalDate = null;
      if (!DateUtils.isSameDay(pending, _visibleDate)) {
        setState(() => _visibleDate = pending);
      }
    }
  }

  void _pickDate(DateTime date) {
    if (!widget.shellTabActive || _datePagerLocked) return;
    final selected = DateUtils.dateOnly(date);
    if (DateUtils.isSameDay(selected, _visibleDate)) return;
    setState(() => _visibleDate = selected);
    widget.onDateChanged(selected);
  }

  void _stepDay(int delta) {
    if (delta == 0) return;
    // Calendar arithmetic does not shift dates when crossing DST.
    _pickDate(DateTime(
      _visibleDate.year,
      _visibleDate.month,
      _visibleDate.day + (delta < 0 ? -1 : 1),
    ));
  }

  Widget _sideArrow(BuildContext context, {required bool previous}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: AppIconButton(
          icon: previous
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          tooltip: t(
            currentLocale.value,
            previous ? 'date_previous_day' : 'date_next_day',
          ),
          size: AppIconButtonSize.l,
          variant: AppIconButtonVariant.standard,
          onPressed: widget.shellTabActive && !_datePagerLocked
              ? () => _stepDay(previous ? -1 : 1)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The saved hour range must be known before mounting the day canvas.
    if (!_timelineRangeReady) return const SizedBox.expand();
    final planningPage = PlanningPage(
      key: const ValueKey('planning-single-persistent-page'),
      selectedDateString: _dayKey(_visibleDate),
      selectedDate: _visibleDate,
      isActivePlanningDay: widget.shellTabActive,
      shellTabActive: widget.shellTabActive,
      selectedCategoryId: widget.selectedCategoryId,
      onCategoryChanged: widget.onCategoryChanged,
      onStartRecordFromTask: widget.onStartRecordFromTask,
      onEditTask: widget.onEditTask,
      onDatePicked: _pickDate,
      onDateChanged: _pickDate,
      onAdjacentDayRequested: _stepDay,
      onDatePagerLockChanged: _onDatePagerLockChanged,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) return planningPage;
        return Row(
          children: [
            SizedBox(
              width: 64,
              child: _sideArrow(context, previous: true),
            ),
            Expanded(child: planningPage),
            SizedBox(
              width: 64,
              child: _sideArrow(context, previous: false),
            ),
          ],
        );
      },
    );
  }
}
