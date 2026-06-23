// ---------------------------------------------------------------------------
// Canonical production Plan card — list + Time mode surfaces.
// Used by Planning screens and Component Lab (same widget, no fake clones).
// ---------------------------------------------------------------------------

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/time/plan_time_labels.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

/// Meta icons for notes / checklist / parent plan (shared list + time cards).
List<Widget> planningTaskMetaIcons(BuildContext context, PlanningTask task) {
  final base = Theme.of(context).iconTheme.color;
  final color = base?.withValues(alpha: 0.48);
  if (color == null) return const [];
  if (!task.hasNotes && !task.hasChecklist && !task.hasParentPlan) {
    return const [];
  }
  final out = <Widget>[];
  void add(IconData icon) {
    if (out.isNotEmpty) out.add(const SizedBox(width: 4));
    out.add(Icon(icon, size: 15, color: color));
  }

  if (task.hasNotes) add(Icons.sticky_note_2_outlined);
  if (task.hasChecklist) add(Icons.checklist_rounded);
  if (task.hasParentPlan) add(Icons.account_tree_outlined);
  return out;
}

/// Production plan task card (Category / Tags / Custom list + Time mode blocks).
///
/// Wraps [PlanTimeTaskCard] with the same layout paths as Planning screens.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.task,
    required this.planTrackedSeconds,
    required this.planEstimatedSeconds,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.highlightAsRunning,
    required this.toggleDoneEnabled,
    required this.onToggleDone,
    required this.onBodyTap,
    this.onLongPress,
    this.onPlay,
    required this.onOpenMenu,
    this.timelineBlock = false,
    this.timelineInteracting = false,
    this.timelineScheduleConflict = false,
    this.timelineTimeLabel,
    this.timelineBlockHeightPx,
  });

  final PlanningTask task;
  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool highlightAsRunning;
  final bool toggleDoneEnabled;
  final VoidCallback onToggleDone;
  final VoidCallback onBodyTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlay;
  final void Function(BuildContext anchorContext) onOpenMenu;
  final bool timelineBlock;
  final bool timelineInteracting;
  final bool timelineScheduleConflict;
  final String? timelineTimeLabel;
  final double? timelineBlockHeightPx;

  static String listTimeLabel(PlanningTask task) =>
      timelineTimeRangeLabel(task);

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('PlanCard');
    if (timelineBlock) {
      return _buildTimelineBlockCard(context);
    }
    return _buildListPlanningCard(context);
  }

  Widget _buildTimelineBlockCard(BuildContext context) {
    final metaIcons = planningTaskMetaIcons(context, task);
    final blockH = timelineBlockHeightPx ?? kPlanTimeCardMinHeightPx;
    final visual = planTimeCardVisualDensityForRenderedHeight(blockH);
    final density = planTimeCardTaskDensityForVisual(visual);
    final fillHeight = false;
    final showBreadcrumb = planTimeCardShowFooterBreadcrumbForVisual(visual);
    final showProgress = planTimeCardShowProgressForVisual(visual);
    final suppressChildInk = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      checkboxTheme: CheckboxThemeData(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
    return Theme(
      data: suppressChildInk,
      child: PlanTimeTaskCard(
        task: task,
        density: density,
        surface: PlanCardSurface.timeline,
        timelineVisualDensity: visual,
        timelineBlockHeightPx: blockH,
        timelineFillHeight: fillHeight,
        showFooterBreadcrumb: showBreadcrumb,
        showProgressBar: showProgress,
        timeLabel: timelineTimeLabel ?? timelineTimeRangeLabel(task),
        displayIsDone: displayIsDone,
        selectMode: selectMode,
        isSelected: isSelected,
        highlightAsRunning: highlightAsRunning,
        interacting: timelineInteracting,
        toggleDoneEnabled: toggleDoneEnabled,
        planTrackedSeconds: planTrackedSeconds,
        planEstimatedSeconds: planEstimatedSeconds,
        scheduleConflict: timelineScheduleConflict,
        metaIcons: metaIcons,
        onToggleDone: onToggleDone,
        onSelectToggle: onBodyTap,
        onPlay: onPlay,
        onOpenMenu: onOpenMenu,
      ),
    );
  }

  Widget _buildListPlanningCard(BuildContext context) {
    final metaIcons = planningTaskMetaIcons(context, task);
    final density = planTimeCardDensityForList(
      task: task,
      planEstimatedSeconds: planEstimatedSeconds,
      planTrackedSeconds: planTrackedSeconds,
    );
    final suppressChildInk = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      checkboxTheme: CheckboxThemeData(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
    return Theme(
      data: suppressChildInk,
      child: PlanTimeTaskCard(
        task: task,
        density: density,
        surface: PlanCardSurface.list,
        timeLabel: listTimeLabel(task),
        displayIsDone: displayIsDone,
        selectMode: selectMode,
        isSelected: isSelected,
        highlightAsRunning: highlightAsRunning,
        toggleDoneEnabled: toggleDoneEnabled,
        planTrackedSeconds: planTrackedSeconds,
        planEstimatedSeconds: planEstimatedSeconds,
        metaIcons: metaIcons,
        onToggleDone: onToggleDone,
        onSelectToggle: onBodyTap,
        onPlay: (!selectMode && !displayIsDone) ? onPlay : null,
        onOpenMenu: onOpenMenu,
        onTap: onBodyTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
