import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import 'package:counter/features/planning/time_view/planning_time_view_host.dart';

class PlanningTimeViewCoordinator {
  PlanningTimeViewCoordinator(this.host) {
    nowLineTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!host.mounted) {
        timer.cancel();
        return;
      }
      if (host.sortMode != PlanSortMode.time ||
          !host.pageWidget.isActivePlanningDay ||
          !host.pageWidget.shellTabActive) {
        return;
      }
      final selectedDay = host.pageWidget.selectedDateString.trim();
      final todayKey = DatabaseService.instance.getProjectedTodayDateKey();
      if (selectedDay.length < 10 || selectedDay.substring(0, 10) != todayKey) {
        return;
      }
      host.notifySetState();
    });
  }

  final PlanningTimeViewHost host;
  Timer? nowLineTimer;

  // --- timeline state (public) ---
  String? timeViewCascadeNormalizedDayKey;
  int timelineHourStart = 0;
  int timelineHourEnd = 23;
  final ScrollController hourGridScrollController = ScrollController();
  List<TimeModeProjectedPlan> cachedTimeModeProjections = const [];
  List<PlanTimeViewBlockLayout> dragInsertLayoutsCache = const [];
  Set<String> timeViewFixedTagIds = {};
  Set<String> timelineDragExcludedPlanIds = {};
  Set<String> timelineBulkDragPlanIds = {};
  Map<String, int> timelineBulkDragRelativeOffsetMin = {};
  Map<String, double> _timelineBulkDragPreviewTopPxByPlanId = {};
  bool _preserveOverlapPreviewOnNextEmptyAssignment = false;
  PlanTimeViewDurationGrid? activeTimelineDurationGrid;
  bool timeModeDidAutoScrollToNow = false;
  double timelineVerticalDragCardHeightPx = 0;
  String? timelineVerticalDragPlanKey;
  double timelineVerticalDragDeltaPx = 0;
  double timelineVerticalDragVisualVelocityPxPerSec = 0;
  double timelineVerticalDragOriginTopPx = 0;
  int timelineVerticalDragDurationMin = kTimelineDefaultBlockMinutes;
  PlanningTask? timelineVerticalDragTask;
  bool timelineVerticalDragHadEnd = false;
  bool timelineScrollLocked = false;
  String? timelineVerticalDragTimeLabel;
  String? timelineDragInsertTargetKey;
  bool timelineDragInsertBefore = false;
  double? timelineDragInsertMarkerTopPx;
  TimeViewInsertionIntent? timelineStoredInsertionIntent;
  double timelineFingerDragDeltaPx = 0;
  double timelineFingerGrabOffsetCanvasPx = 0;
  int timelineVerticalDragSequenceId = 0;
  String? timelineResizePlanKey;
  TimelineResizeEdge? timelineResizeEdge;
  double timelineResizeOriginTopPx = 0;
  double timelineResizeOriginHeightPx = 0;
  int timelineResizeOriginStartMin = 0;
  int timelineResizeOriginEndMin = 0;
  double timelineResizePreviewTopPx = 0;
  double timelineResizePreviewHeightPx = 0;
  PlanningTask? timelineResizeTask;
  String? timelineResizeTimeLabel;
  late Ticker hourGridEdgeScrollTicker;
  double hourGridScrollVelocityPxPerSec = 0;
  Duration? hourGridTickerElapsedLast;
  String? lastTimeDurationLayoutLogKey;
  DateTime? lastTimeDurationLayoutLogAt;
  String? lastTimeModeRailLogKey;
  DateTime? lastTimeModeRailLogAt;
  String? lastTimeResizePreviewLogKey;
  DateTime? lastTimeResizePreviewLogAt;
  String? lastPlanTimeNowLineLogKey;
  DateTime? lastPlanTimeNowLineLogAt;

  Map<String, double> get timelineBulkDragPreviewTopPxByPlanId =>
      _timelineBulkDragPreviewTopPxByPlanId;

  set timelineBulkDragPreviewTopPxByPlanId(Map<String, double> value) {
    if (value.isEmpty && _preserveOverlapPreviewOnNextEmptyAssignment) {
      _preserveOverlapPreviewOnNextEmptyAssignment = false;
      return;
    }
    _timelineBulkDragPreviewTopPxByPlanId = value;
    _preserveOverlapPreviewOnNextEmptyAssignment = false;
  }

  void stageTimelineOverlapCascadePreview(Map<String, double> value) {
    _timelineBulkDragPreviewTopPxByPlanId = value;
    _preserveOverlapPreviewOnNextEmptyAssignment = true;
  }

  static const int kTimelineDefaultBlockMinutes = 30;
  static const double kTimelineHourHeightMinPx = 120;
  static const double kTimelineHourHeightMaxPx = 160;
  static const double kTimelineRailWidthDesktopPx = 48;
  static const double kTimelineRailWidthMobilePx = 28;
  static const double kTimelineCompactBreakpoint = 600;
  static const double kTimelineResizeHandlePx = 16;
  static const double kHourGridEdgeScrollSpeedPxPerSec = 400;
  static const double kTimelineBlockHorizontalPadPx = 8;
  static const Duration timeModeLogDebounce = Duration(seconds: 8);
  static const Duration planTimeNowLineLogDebounce = Duration(seconds: 8);
  static int timelineNextDragSequenceId = 0;

  void refreshAfterTimezoneChange() {
    timeViewCascadeNormalizedDayKey = null;
    activeTimelineDurationGrid = null;
  }
}
