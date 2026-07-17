import 'dart:async';

import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_page.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:flutter/material.dart';

/// Host callbacks for [PlanningTimeViewCoordinator] (implemented by [_PlanningPageState]).
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
  void applyNoTagsChipSettings(bool visible, String colorHex);

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
