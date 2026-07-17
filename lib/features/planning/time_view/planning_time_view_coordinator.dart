
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import 'package:counter/features/planning/time_view/planning_time_view_host.dart';

class PlanningTimeViewCoordinator {
  PlanningTimeViewCoordinator(this.host);

  final PlanningTimeViewHost host;

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
  Map<String, double> timelineBulkDragPreviewTopPxByPlanId = {};
  PlanTimeViewDurationGrid? activeTimelineDurationGrid;
  bool timeModeDidAutoScrollToNow = false;
  double timelineVerticalDragCardHeightPx = 0;
  String? timelineVerticalDragPlanKey;
  double timelineVerticalDragDeltaPx = 0;
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
