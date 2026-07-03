#!/usr/bin/env python3
"""Pass 3 — extract Time View from planning_page.dart into time_view/ modules."""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
PAGE = ROOT / "lib" / "features" / "planning" / "planning_page.dart"
OUT = ROOT / "lib" / "features" / "planning" / "time_view"

# Methods moved to coordinator extensions (name without leading _)
EXTRACT_METHODS: dict[str, str] = {
    # settings / prefs
    "_loadTimeViewFixedTagIds": "time_view_settings_sheet.dart",
    "_loadPlanningTimelineBounds": "time_view_settings_sheet.dart",
    "_onPlanningTimelineBoundsChanged": "time_view_settings_sheet.dart",
    "_formatDayLengthValueSummary": "time_view_settings_sheet.dart",
    "_hhmmFromTimeOfDay": "time_view_search_delegate.dart",
    "_timeOfDayFromHhmm": "time_view_search_delegate.dart",
    "_editCategoryDefaultPlanSchedule": "time_view_search_delegate.dart",
    "_setCategoryDefaultPlanTime": "time_view_search_delegate.dart",
    "_clearCategoryDefaultPlanTime": "time_view_search_delegate.dart",
    "_showDefaultPlanTimesSheet": "time_view_settings_sheet.dart",
    "_showPlanningSettingsSheet": "time_view_settings_sheet.dart",
    # window / data helpers
    "_planningTasksForTimeViewWindow": "planning_time_view.dart",
    "_projectedPlanInTimeViewWindow": "planning_time_view.dart",
    "_planningClockOrderMinutes": "planning_time_view.dart",
    "_tasksForTimeMode": "planning_time_view.dart",
    "_timelineCompactLayout": "planning_time_view.dart",
    "_timelineRailWidthPx": "planning_time_view.dart",
    # hour grid scroll (edge auto-scroll — base layer to avoid import cycles)
    "_onHourGridEdgeScrollTick": "planning_time_view.dart",
    "_ensureHourGridEdgeTickerRunning": "planning_time_view.dart",
    "_stopHourGridEdgeScroll": "planning_time_view.dart",
    "_handleHourGridDragUpdateForEdgeScroll": "planning_time_view.dart",
    # layout / canvas helpers
    "_timelineLogWallIso": "planning_time_view.dart",
    "_wallClockHourFromTask": "planning_time_view.dart",
    "_timelineMinutesFromRangeStart": "planning_time_view.dart",
    "_timelineBlockDurationMinutes": "planning_time_view.dart",
    "_timelineHourHeightPx": "planning_time_view.dart",
    "_computeTimelinePxPerMinute": "planning_time_view.dart",
    "_timelineCanvasHeightPx": "planning_time_view.dart",
    "_timelineSpanMinutesFromProjection": "planning_time_view.dart",
    "_computeTimelineDurationLayout": "planning_time_view.dart",
    "_timelineBlockLayouts": "planning_time_view.dart",
    "_maybeNormalizeTimeViewOverlapsOnce": "planning_time_view.dart",
    "_logTimeDurationLayout": "planning_time_view.dart",
    "_logTimeResizePreview": "planning_time_view.dart",
    "_logTimeModeRail": "planning_time_view.dart",
    "_isProfileTodaySelectedForPlanning": "planning_time_view.dart",
    "_logPlanTimeNowLine": "planning_time_view.dart",
    "_profileWallNow": "planning_time_view.dart",
    "_timelineNowLineTopPx": "planning_time_view.dart",
    "_maybeAutoScrollTimelineToNow": "planning_time_view.dart",
    "_snapTimelineMinutes": "planning_time_view.dart",
    "_timeViewFixedPlanIdsForTasks": "planning_time_view.dart",
    "_planIsTimelineScheduledDraggable": "planning_time_view.dart",
    "_planCanMoveInTimeView": "planning_time_view.dart",
    "_planIsTimelineVerticallyDraggable": "planning_time_view.dart",
    "_wallTimeFromTimelineMinutes": "planning_time_view.dart",
    "_formatTimelineWallRangeLabel": "planning_time_view.dart",
    "_formatTimelineResizeLabel": "planning_time_view.dart",
    "_shortTimelineDuration": "planning_time_view.dart",
    "_timelineMaxVisibleMinutes": "planning_time_view.dart",
    "_timelineStartEndMinutesFromTask": "planning_time_view.dart",
    "_clearTimelineInteractionState": "planning_time_view.dart",
    "_setTimelineInteractionLock": "planning_time_view.dart",
    "_updateTimelineResizeLabel": "time_view_resize_controller.dart",
    "_beginTimelineResize": "time_view_resize_controller.dart",
    "_updateTimelineResize": "time_view_resize_controller.dart",
    "_cancelTimelineResize": "time_view_resize_controller.dart",
    "_commitTimelineResize": "time_view_resize_controller.dart",
    "_persistTimelineScheduleChange": "planning_time_view.dart",
    "_persistTimeViewCascadePatches": "planning_time_view.dart",
    "_persistTimelineDragWithCascade": "planning_time_view.dart",
    "_timelineTaskByPlanKey": "planning_time_view.dart",
    "_timelineCardLayoutsForResolver": "time_view_drop_preview.dart",
    "_timelineFingerCanvasY": "time_view_drag_controller.dart",
    "_applyTimelineCascadePreviewTops": "time_view_drop_preview.dart",
    "_timelineCascadeForDrag": "time_view_drop_preview.dart",
    "_timelineResolveDropIntent": "time_view_drop_preview.dart",
    "_timelineLayoutForPlanId": "time_view_drop_preview.dart",
    "_timelineInsertionIntentFromLayout": "time_view_drop_preview.dart",
    "_logTimeDropGuard": "time_view_drop_preview.dart",
    "_timelineTargetDropScheduleForLayout": "time_view_drop_preview.dart",
    "_timelinePreviewTopPxForStartWall": "time_view_drop_preview.dart",
    "_timelineDragLayoutsForDay": "time_view_drop_preview.dart",
    "_timelineDragLabelForTopPx": "time_view_drag_controller.dart",
    "_beginTimelineVerticalDrag": "time_view_drag_controller.dart",
    "_updateTimelineVerticalDrag": "time_view_drag_controller.dart",
    "_cancelTimelineVerticalDrag": "time_view_drag_controller.dart",
    "_commitTimelineVerticalDrag": "time_view_drag_controller.dart",
    "_onPlanningTaskDroppedOnHour": "time_view_hour_grid.dart",
    "_buildHourGridView": "time_view_hour_grid.dart",
    "_buildProportionalDayTimelineCanvas": "time_view_canvas.dart",
    "_timelineElevatedPlanKey": "time_view_card_layer.dart",
    "_buildTimelinePlanStackLayer": "time_view_card_layer.dart",
}

STATE_FIELDS = [
    ("_timeViewCascadeNormalizedDayKey", "String?", "timeViewCascadeNormalizedDayKey"),
    ("_timelineHourStart", "int", "timelineHourStart"),
    ("_timelineHourEnd", "int", "timelineHourEnd"),
    ("_hourGridScrollController", "ScrollController", "hourGridScrollController"),
    ("_cachedTimeModeProjections", "List<TimeModeProjectedPlan>", "cachedTimeModeProjections"),
    ("_dragInsertLayoutsCache", "List<PlanTimeViewBlockLayout>", "dragInsertLayoutsCache"),
    ("_timeViewFixedTagIds", "Set<String>", "timeViewFixedTagIds"),
    ("_timelineDragExcludedPlanIds", "Set<String>", "timelineDragExcludedPlanIds"),
    ("_timelineBulkDragPlanIds", "Set<String>", "timelineBulkDragPlanIds"),
    ("_timelineBulkDragRelativeOffsetMin", "Map<String, int>", "timelineBulkDragRelativeOffsetMin"),
    ("_timelineBulkDragPreviewTopPxByPlanId", "Map<String, double>", "timelineBulkDragPreviewTopPxByPlanId"),
    ("_activeTimelineDurationGrid", "PlanTimeViewDurationGrid?", "activeTimelineDurationGrid"),
    ("_timeModeDidAutoScrollToNow", "bool", "timeModeDidAutoScrollToNow"),
    ("_timelineVerticalDragCardHeightPx", "double", "timelineVerticalDragCardHeightPx"),
    ("_timelineVerticalDragPlanKey", "String?", "timelineVerticalDragPlanKey"),
    ("_timelineVerticalDragDeltaPx", "double", "timelineVerticalDragDeltaPx"),
    ("_timelineVerticalDragOriginTopPx", "double", "timelineVerticalDragOriginTopPx"),
    ("_timelineVerticalDragDurationMin", "int", "timelineVerticalDragDurationMin"),
    ("_timelineVerticalDragTask", "PlanningTask?", "timelineVerticalDragTask"),
    ("_timelineVerticalDragHadEnd", "bool", "timelineVerticalDragHadEnd"),
    ("_timelineScrollLocked", "bool", "timelineScrollLocked"),
    ("_timelineVerticalDragTimeLabel", "String?", "timelineVerticalDragTimeLabel"),
    ("_timelineDragInsertTargetKey", "String?", "timelineDragInsertTargetKey"),
    ("_timelineDragInsertBefore", "bool", "timelineDragInsertBefore"),
    ("_timelineDragInsertMarkerTopPx", "double?", "timelineDragInsertMarkerTopPx"),
    ("_timelineStoredInsertionIntent", "TimeViewInsertionIntent?", "timelineStoredInsertionIntent"),
    ("_timelineFingerDragDeltaPx", "double", "timelineFingerDragDeltaPx"),
    ("_timelineFingerGrabOffsetCanvasPx", "double", "timelineFingerGrabOffsetCanvasPx"),
    ("_timelineVerticalDragSequenceId", "int", "timelineVerticalDragSequenceId"),
    ("_timelineResizePlanKey", "String?", "timelineResizePlanKey"),
    ("_timelineResizeEdge", "TimelineResizeEdge?", "timelineResizeEdge"),
    ("_timelineResizeOriginTopPx", "double", "timelineResizeOriginTopPx"),
    ("_timelineResizeOriginHeightPx", "double", "timelineResizeOriginHeightPx"),
    ("_timelineResizeOriginStartMin", "int", "timelineResizeOriginStartMin"),
    ("_timelineResizeOriginEndMin", "int", "timelineResizeOriginEndMin"),
    ("_timelineResizePreviewTopPx", "double", "timelineResizePreviewTopPx"),
    ("_timelineResizePreviewHeightPx", "double", "timelineResizePreviewHeightPx"),
    ("_timelineResizeTask", "PlanningTask?", "timelineResizeTask"),
    ("_timelineResizeTimeLabel", "String?", "timelineResizeTimeLabel"),
    ("_hourGridEdgeScrollTicker", "Ticker", "hourGridEdgeScrollTicker"),
    ("_hourGridScrollVelocityPxPerSec", "double", "hourGridScrollVelocityPxPerSec"),
    ("_hourGridTickerElapsedLast", "Duration?", "hourGridTickerElapsedLast"),
    ("_lastTimeDurationLayoutLogKey", "String?", "lastTimeDurationLayoutLogKey"),
    ("_lastTimeDurationLayoutLogAt", "DateTime?", "lastTimeDurationLayoutLogAt"),
    ("_lastTimeModeRailLogKey", "String?", "lastTimeModeRailLogKey"),
    ("_lastTimeModeRailLogAt", "DateTime?", "lastTimeModeRailLogAt"),
    ("_lastTimeResizePreviewLogKey", "String?", "lastTimeResizePreviewLogKey"),
    ("_lastTimeResizePreviewLogAt", "DateTime?", "lastTimeResizePreviewLogAt"),
    ("_lastPlanTimeNowLineLogKey", "String?", "lastPlanTimeNowLineLogKey"),
    ("_lastPlanTimeNowLineLogAt", "DateTime?", "lastPlanTimeNowLineLogAt"),
]

CONST_FIELDS = [
    ("_kTimelineDefaultBlockMinutes", "static const int kTimelineDefaultBlockMinutes = 30;"),
    ("_kTimelineHourHeightMinPx", "static const double kTimelineHourHeightMinPx = 120;"),
    ("_kTimelineHourHeightMaxPx", "static const double kTimelineHourHeightMaxPx = 160;"),
    ("_kTimelineRailWidthDesktopPx", "static const double kTimelineRailWidthDesktopPx = 48;"),
    ("_kTimelineRailWidthMobilePx", "static const double kTimelineRailWidthMobilePx = 28;"),
    ("_kTimelineCompactBreakpoint", "static const double kTimelineCompactBreakpoint = 600;"),
    ("_kTimelineResizeHandlePx", "static const double kTimelineResizeHandlePx = 16;"),
    ("_kHourGridEdgeScrollSpeedPxPerSec", "static const double kHourGridEdgeScrollSpeedPxPerSec = 400;"),
    ("_kTimelineBlockHorizontalPadPx", "static const double kTimelineBlockHorizontalPadPx = 8;"),
    ("_timeModeLogDebounce", "static const Duration timeModeLogDebounce = Duration(seconds: 8);"),
    ("_planTimeNowLineLogDebounce", "static const Duration planTimeNowLineLogDebounce = Duration(seconds: 8);"),
    ("_timelineNextDragSequenceId", "static int timelineNextDragSequenceId = 0;"),
]

HOST_IMPORTS = """import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/time/plan_time_labels.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/plan_card.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/settings/default_plan_category_search.dart';
import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';
import 'package:counter/features/planning/time_view/planning_time_view_host.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:shared_preferences/shared_preferences.dart';
"""

COORDINATOR_BODY = """class PlanningTimeViewCoordinator {
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
"""

HOST_BODY = """/// Host callbacks for [PlanningTimeViewCoordinator] (implemented by [_PlanningPageState]).
abstract class PlanningTimeViewHost {
  BuildContext get context;
  PlanningPage get pageWidget;
  bool get mounted;
  DateTime get today;
  PlanSortMode get sortMode;
  bool get planSelectMode;
  Set<String> get selectedPlanKeys;
  Map<String, bool> get planDoneOverride;
  bool get noTagsChipVisible;
  String get noTagsColorHex;
  String get prefsKeyNoTagsVisible;
  String get prefsKeyNoTagsColor;

  void notifySetState([VoidCallback? fn]);
  void onDatePagerLockChanged(bool locked);
  Future<void> reloadQuickAddTags();

  String planKey(PlanningTask task);
  int taskSortCmp(PlanningTask a, PlanningTask b);
  Widget planCardRow({
    required BuildContext context,
    required PlanningTask task,
    required String key,
    required bool displayDone,
    required bool isSelected,
    required Map<String, int> planActualByPbId,
    bool enableLongPressDrag,
    bool omitLongPressForReorder,
    bool timelineEmbedded,
    bool timelineInteracting,
    bool timelineScheduleConflict,
    String? timelineTimeLabel,
    double? timelineBlockHeightPx,
    ValueChanged<double>? onHourGridDragGlobalDy,
    VoidCallback? onHourGridDragEnded,
  });

  void openQuickAddForHour(int hour);
  void openEditDialog(PlanningTask task);
  void toggleKeySelection(String key);
  List<PlanningTask> latestPlanningDayTasksSnapshot();
}
"""


def find_method_start(lines: list[str], method: str) -> int:
    pat = re.compile(rf"^  \S.*\b{re.escape(method)}\s*\(")
    for i, line in enumerate(lines):
        if not pat.match(line):
            continue
        start = i
        while start > 0 and lines[start - 1].startswith("  "):
            prev = lines[start - 1].strip()
            if prev.startswith("@") or prev.startswith("({") or prev == "({":
                start -= 1
                continue
            if re.match(r"^[\w\?\<\>,\s\[\].]+$", prev) and ";" not in prev and "(" not in prev:
                start -= 1
                continue
            break
        return start
    raise KeyError(method)


def find_all_class_method_starts(lines: list[str]) -> list[tuple[int, str]]:
    pat = re.compile(r"^  \S.*\b(_\w+)\s*\(")
    out: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        m = pat.match(line)
        if m:
            out.append((find_method_start(lines, m.group(1)), m.group(1)))
    # dedupe by start line
    dedup: dict[int, str] = {}
    for start, name in out:
        dedup[start] = name
    return sorted(dedup.items())


def find_method_end(lines: list[str], start: int) -> int:
    """End line (exclusive) for a class method starting at [start]."""
    paren = 0
    found_arrow = False
    arrow_line = start
    body_open_line: int | None = None
    body_open_col: int | None = None

    for j in range(start, len(lines)):
        line = lines[j]
        if paren == 0 and "=>" in line:
            found_arrow = True
            arrow_line = j
            break
        for idx, ch in enumerate(line):
            if ch == "(":
                paren += 1
            elif ch == ")":
                paren -= 1
                if paren == 0:
                    rest = line[idx + 1 :].strip()
                    if rest.startswith("async {"):
                        body_open_line = j
                        body_open_col = line.index("{", idx)
                        break
                    if rest.startswith("{"):
                        body_open_line = j
                        body_open_col = line.index("{", idx)
                        break
        if body_open_line is not None:
            break

    if found_arrow:
        j = arrow_line
        while j < len(lines):
            if lines[j].rstrip().endswith(";"):
                return j + 1
            j += 1
        return j + 1

    if body_open_line is None:
        return start + 1

    depth = 0
    started = False
    for k in range(body_open_line, len(lines)):
        col_start = body_open_col if k == body_open_line else 0
        for ch in lines[k][col_start:]:
            if ch == "{":
                depth += 1
                started = True
            elif ch == "}":
                depth -= 1
                if started and depth == 0:
                    return k + 1
        body_open_col = 0
    return len(lines)


def find_method_spans(lines: list[str]) -> dict[str, tuple[int, int]]:
    spans: dict[str, tuple[int, int]] = {}
    for name in EXTRACT_METHODS:
        start = find_method_start(lines, name)
        end = find_method_end(lines, start)
        spans[name] = (start, end)
    return spans


def transform_method_body(body: str, method_name: str) -> str:
    public = method_name.lstrip("_")
    # Rename method declaration (last occurrence of name before opening paren on sig line)
    body = re.sub(
        rf"(\s){re.escape(method_name)}(\s*\()",
        rf"\1{public}\2",
        body,
        count=1,
    )

    # host / page rewrites (order matters)
    body = body.replace(
        "widget.onDatePagerLockChanged?.call(locked)",
        "host.onDatePagerLockChanged(locked)",
    )
    body = body.replace("widget.", "host.pageWidget.")
    body = body.replace("context: context", "context: host.context")
    body = body.replace(".of(context)", ".of(host.context)")
    body = body.replace("paddingOf(context)", "paddingOf(host.context)")
    body = body.replace("sizeOf(context)", "sizeOf(host.context)")
    body = body.replace("(context)", "(host.context)")
    body = body.replace("(host.context, setModalState)", "(context, setModalState)")
    body = body.replace("(host.context, setSheetState)", "(context, setSheetState)")
    body = body.replace("builder: (host.context,", "builder: (context,")
    body = body.replace("LayoutBuilder(\n                    builder: (host.context,", "LayoutBuilder(\n                    builder: (context,")
    body = body.replace("host.context: host.context", "context: host.context")
    body = body.replace("if (mounted)", "if (host.mounted)")
    body = body.replace("if (!mounted)", "if (!host.mounted)")
    body = body.replace("!mounted", "!host.mounted")
    body = body.replace("setState(", "host.notifySetState(")

    for old_name, _, new_name in STATE_FIELDS:
        body = body.replace(old_name, new_name)

    const_map = {
        "_timelineNextDragSequenceId": "PlanningTimeViewCoordinator.timelineNextDragSequenceId",
        "_kTimelineDefaultBlockMinutes": "PlanningTimeViewCoordinator.kTimelineDefaultBlockMinutes",
        "_kTimelineHourHeightMinPx": "PlanningTimeViewCoordinator.kTimelineHourHeightMinPx",
        "_kTimelineHourHeightMaxPx": "PlanningTimeViewCoordinator.kTimelineHourHeightMaxPx",
        "_kTimelineRailWidthDesktopPx": "PlanningTimeViewCoordinator.kTimelineRailWidthDesktopPx",
        "_kTimelineRailWidthMobilePx": "PlanningTimeViewCoordinator.kTimelineRailWidthMobilePx",
        "_kTimelineCompactBreakpoint": "PlanningTimeViewCoordinator.kTimelineCompactBreakpoint",
        "_kTimelineResizeHandlePx": "PlanningTimeViewCoordinator.kTimelineResizeHandlePx",
        "_kHourGridEdgeScrollSpeedPxPerSec": "PlanningTimeViewCoordinator.kHourGridEdgeScrollSpeedPxPerSec",
        "_kTimelineBlockHorizontalPadPx": "PlanningTimeViewCoordinator.kTimelineBlockHorizontalPadPx",
        "_timeModeLogDebounce": "PlanningTimeViewCoordinator.timeModeLogDebounce",
        "_planTimeNowLineLogDebounce": "PlanningTimeViewCoordinator.planTimeNowLineLogDebounce",
        "_kPlanningTimeViewCanvasColor": "kPlanningTimeViewCanvasColor",
    }
    for old, new in const_map.items():
        body = body.replace(old, new)

    host_methods = {
        "_planKey": "host.planKey",
        "_taskSortCmp": "host.taskSortCmp",
        "_planCardRow": "host.planCardRow",
        "_openQuickAddForHour": "host.openQuickAddForHour",
        "_openEditDialog": "host.openEditDialog",
        "_toggleKeySelection": "host.toggleKeySelection",
        "_sortMode": "host.sortMode",
        "_planSelectMode": "host.planSelectMode",
        "_selectedPlanKeys": "host.selectedPlanKeys",
        "_planDoneOverride": "host.planDoneOverride",
        "_today": "host.today",
        "_latestPlanningDayTasks": "host.latestPlanningDayTasksSnapshot()",
        "_noTagsChipVisible": "host.noTagsChipVisible",
        "_noTagsColorHex": "host.noTagsColorHex",
        "_prefsKeyNoTagsVisible": "host.prefsKeyNoTagsVisible",
        "_prefsKeyNoTagsColor": "host.prefsKeyNoTagsColor",
        "_reloadQuickAddTags": "host.reloadQuickAddTags()",
    }
    for old, new in host_methods.items():
        body = body.replace(old, new)

    for m in sorted(EXTRACT_METHODS, key=len, reverse=True):
        body = body.replace(m, m.lstrip("_"))

    return body


def main() -> None:
    text = PAGE.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    spans = find_method_spans(lines)

    missing = [m for m in EXTRACT_METHODS if m not in spans]
    if missing:
        raise SystemExit(f"Missing methods: {missing[:10]} ... ({len(missing)} total)")

    file_methods: dict[str, list[str]] = {}
    for method, target in EXTRACT_METHODS.items():
        start, end = spans[method]
        body = transform_method_body("".join(lines[start:end]), method)
        file_methods.setdefault(target, []).append(body)

    OUT.mkdir(parents=True, exist_ok=True)

    (OUT / "planning_time_view_host.dart").write_text(
        HOST_IMPORTS.replace("planning_time_view_coordinator.dart", "planning_time_view_host.dart")
        + "\n"
        + HOST_BODY,
        encoding="utf-8",
    )

    coord_imports = (
        HOST_IMPORTS.replace(
            "import 'package:counter/features/planning/time_view/planning_time_view_host.dart';\n",
            "",
        )
        + """
import 'package:counter/features/planning/time_view/planning_time_view_host.dart';
"""
    )
    (OUT / "planning_time_view_coordinator.dart").write_text(
        coord_imports + "\n" + COORDINATOR_BODY,
        encoding="utf-8",
    )

    ext_header = """import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/diagnostics/platform_log.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/performance/shell_flags.dart';
import 'package:counter/core/time/plan_time_labels.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/plan_card.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/settings/default_plan_category_search.dart';
import 'package:counter/features/planning/settings/default_plan_timezone_search.dart';
import 'package:counter/features/planning/settings/plan_record_link_settings.dart';
import 'package:counter/features/planning/settings/planning_no_tags_settings.dart';
import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/time_view/planning_time_view_host.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:shared_preferences/shared_preferences.dart';

"""

    canvas_color = "const kPlanningTimeViewCanvasColor = Color(0xFFD0D5DD);\n\n"

    ALL_EXT = sorted(file_methods.keys())
    EXT_IMPORTS: dict[str, list[str]] = {
        "planning_time_view.dart": [],
        "time_view_drop_preview.dart": ["planning_time_view.dart"],
        "time_view_drag_controller.dart": [
            "planning_time_view.dart",
            "time_view_drop_preview.dart",
        ],
        "time_view_resize_controller.dart": ["planning_time_view.dart"],
        "time_view_card_layer.dart": [
            "planning_time_view.dart",
            "time_view_drag_controller.dart",
            "time_view_resize_controller.dart",
        ],
        "time_view_canvas.dart": [
            "planning_time_view.dart",
            "time_view_card_layer.dart",
            "time_view_hour_grid.dart",
        ],
        "time_view_hour_grid.dart": [
            "planning_time_view.dart",
            "time_view_canvas.dart",
        ],
        "time_view_search_delegate.dart": [],
        "time_view_settings_sheet.dart": [
            "time_view_search_delegate.dart",
        ],
    }

    for fname, bodies in file_methods.items():
        content = ext_header
        for other in EXT_IMPORTS.get(fname, []):
            content += f"import 'package:counter/features/planning/time_view/{other}';\n"
        if fname == "time_view_canvas.dart":
            content += canvas_color
        content += f"extension PlanningTimeView{fname.replace('.dart', '').replace('_', ' ').title().replace(' ', '')} on PlanningTimeViewCoordinator {{\n"
        content += "\n".join(bodies)
        if fname == "planning_time_view.dart":
            content += """
  void initHourGridTicker(Ticker Function(void Function(Duration)) createTicker) {
    hourGridEdgeScrollTicker = createTicker(onHourGridEdgeScrollTick);
  }

  void disposeTimeView() {
    stopHourGridEdgeScroll();
    hourGridEdgeScrollTicker.dispose();
    hourGridScrollController.dispose();
  }
"""
        content += "}\n"
        (OUT / fname).write_text(content, encoding="utf-8")

    # Remove duplicate closing from old loop — handled above
    if False:
        pass

    # Strip extracted methods + state from planning_page.dart
    remove_lines = set()
    for method in EXTRACT_METHODS:
        start, end = spans[method]
        remove_lines.update(range(start, end))

    # Remove state field lines
    field_res = [
        re.compile(r"\b" + re.escape(old) + r"\s*(?:=|;|\{|\?)")
        for old, _, _ in STATE_FIELDS
    ]
    for i, line in enumerate(lines):
        stripped = line.strip()
        for rx in field_res:
            if rx.search(line):
                remove_lines.add(i)
                break
        if stripped.startswith("static const double _kTimeline") or stripped.startswith(
            "static const int _kTimeline"
        ):
            remove_lines.add(i)
        if "_kHourGridEdgeScrollSpeedPxPerSec" in stripped and "static const" in stripped:
            remove_lines.add(i)
        if stripped.startswith("bool _timelineCompactLayout"):
            remove_lines.add(i)
            remove_lines.add(i + 1)
            remove_lines.add(i + 2)
            remove_lines.add(i + 3)
        if stripped.startswith("double _timelineRailWidthPx"):
            remove_lines.add(i)
            remove_lines.add(i + 1)
            remove_lines.add(i + 2)
        if re.match(
            r"^(String\?|DateTime\?|Duration\?) _last(Time|PlanTime|TimeMode|TimeResize)",
            stripped,
        ):
            remove_lines.add(i)
        if stripped.startswith("static const Duration _timeModeLogDebounce") or stripped.startswith(
            "static const Duration _planTimeNowLineLogDebounce"
        ):
            remove_lines.add(i)
        if stripped.startswith("static int _timelineNextDragSequenceId"):
            remove_lines.add(i)
        if stripped.startswith("int _timelineHourStart") or stripped.startswith(
            "int _timelineHourEnd"
        ):
            remove_lines.add(i)
        if stripped.startswith("final ScrollController _hourGridScrollController"):
            remove_lines.add(i)
        if stripped.startswith("String? _timeViewCascadeNormalizedDayKey"):
            remove_lines.add(i)
        if stripped.startswith("late final Ticker _hourGridEdgeScrollTicker"):
            remove_lines.add(i)
        if stripped.startswith("double _hourGridScrollVelocityPxPerSec"):
            remove_lines.add(i)
        if stripped.startswith("Duration? _hourGridTickerElapsedLast"):
            remove_lines.add(i)

    if "/// Scheduled Time View canvas" in line:
        pass
    new_lines: list[str] = []
    for i, line in enumerate(lines):
        if i in remove_lines:
            continue
        if "/// Scheduled Time View canvas only" in line:
            continue
        if "_kPlanningTimeViewCanvasColor" in line:
            continue
        new_lines.append(line)

    kept = "".join(new_lines)

    # Inject imports after existing time_view imports
    new_imports = [
        "import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';\n",
        "import 'package:counter/features/planning/time_view/planning_time_view_host.dart';\n",
        "import 'package:counter/features/planning/time_view/planning_time_view.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_canvas.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_card_layer.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_drag_controller.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_drop_preview.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_hour_grid.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_resize_controller.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_search_delegate.dart';\n",
        "import 'package:counter/features/planning/time_view/time_view_settings_sheet.dart';\n",
    ]
    for imp in new_imports:
        if imp not in kept:
            kept = kept.replace(
                "import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';\n",
                "import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';\n" + imp,
            )

    # Class implements host
    kept = kept.replace(
        "class _PlanningPageState extends State<PlanningPage>\n    with WidgetsBindingObserver, SingleTickerProviderStateMixin {",
        "class _PlanningPageState extends State<PlanningPage>\n    with WidgetsBindingObserver, SingleTickerProviderStateMixin\n    implements PlanningTimeViewHost {",
    )

    # Add coordinator field after _sortMode
    kept = kept.replace(
        "  PlanSortMode _sortMode = PlanSortMode.custom;\n",
        "  PlanSortMode _sortMode = PlanSortMode.custom;\n  late final PlanningTimeViewCoordinator timeView;\n",
    )

    # initState wiring
    kept = kept.replace(
        "    unawaited(_loadPlanningTimelineBounds());\n    unawaited(_loadTimeViewFixedTagIds());\n",
        "    timeView = PlanningTimeViewCoordinator(this);\n    timeView.initHourGridTicker(createTicker);\n    unawaited(timeView.loadPlanningTimelineBounds());\n    unawaited(timeView.loadTimeViewFixedTagIds());\n",
    )
    kept = kept.replace(
        "    _hourGridEdgeScrollTicker = createTicker(_onHourGridEdgeScrollTick);\n",
        "",
    )
    kept = kept.replace(
        "        _timeModeDidAutoScrollToNow = false;\n",
        "        timeView.timeModeDidAutoScrollToNow = false;\n",
    )

    # dispose wiring
    kept = kept.replace(
        "    _stopHourGridEdgeScroll();\n    _hourGridEdgeScrollTicker.dispose();\n    _hourGridScrollController.dispose();\n",
        "    timeView.disposeTimeView();\n",
    )

    # refresh timezone
    kept = kept.replace(
        "    _timeViewCascadeNormalizedDayKey = null;\n    _activeTimelineDurationGrid = null;\n",
        "    timeView.refreshAfterTimezoneChange();\n",
    )

    # didUpdateWidget
    kept = kept.replace(
        "          _timeViewCascadeNormalizedDayKey = null;\n",
        "          timeView.timeViewCascadeNormalizedDayKey = null;\n",
    )

    # timeline hour refs in _maybeShowPlanScheduleOverloadWarning etc
    kept = re.sub(r"_timelineHour(Start|End)", r"timeView.timelineHour\1", kept)

    # build hour grid delegation
    kept = kept.replace("_buildHourGridView(", "timeView.buildHourGridView(")
    kept = kept.replace("_showPlanningSettingsSheet", "timeView.showPlanningSettingsSheet")

    # Host implementation stubs - insert before first method after state
    host_impl = """
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
  String planKey(PlanningTask task) => _planKey(task);

  @override
  int taskSortCmp(PlanningTask a, PlanningTask b) => _taskSortCmp(a, b);

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

"""
    kept = kept.replace(
        "  @override\n  void initState() {",
        host_impl + "  @override\n  void initState() {",
    )

    PAGE.write_text(kept, encoding="utf-8")

    print("planning_page lines:", len(kept.splitlines()))
    for fname in sorted(file_methods):
        p = OUT / fname
        print(f"  {fname}: {len(p.read_text(encoding='utf-8').splitlines())} lines")


if __name__ == "__main__":
    main()
