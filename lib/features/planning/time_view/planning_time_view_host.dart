import 'dart:async';
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
import 'package:counter/features/planning/planning_page.dart';
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
