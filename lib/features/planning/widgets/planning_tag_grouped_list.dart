import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/widgets/planning_group_section.dart';
import 'package:counter/features/planning/widgets/planning_list_grouping.dart';
import 'package:flutter/material.dart';

/// Tags-sort grouped plan list for one planning day.
class PlanningTagGroupedList extends StatelessWidget {
  const PlanningTagGroupedList({
    super.key,
    required this.tasks,
    required this.planActualByPbId,
    required this.masterBarOrder,
    required this.sortTreatAsDone,
    required this.planSelectMode,
    required this.planKeyForTask,
    required this.resolveDisplayDone,
    required this.isSelectedKey,
    required this.canReorderTask,
    required this.planCardRow,
    required this.onTagBucketReorder,
  });

  final List<PlanningTask> tasks;
  final Map<String, int> planActualByPbId;
  final List<Tag> masterBarOrder;
  final bool Function(PlanningTask task) sortTreatAsDone;
  final bool planSelectMode;
  final String Function(PlanningTask task) planKeyForTask;
  final bool Function(PlanningTask task, String key) resolveDisplayDone;
  final bool Function(String key) isSelectedKey;
  final bool Function(PlanningTask task) canReorderTask;
  final PlanningGroupedPlanCardRowBuilder planCardRow;
  final void Function(int groupId, int oldIndex, int newIndex)
  onTagBucketReorder;

  @override
  Widget build(BuildContext context) {
    final groups = groupPlanningTasksByMasterBar(
      tasks,
      masterBarOrder,
      sortTreatAsDone: sortTreatAsDone,
    );
    final orderedIds = planningGroupIdsInMasterBarSequence(
      groups,
      masterBarOrder,
    );
    final children = <Widget>[];
    var firstGroup = true;
    for (final gid in orderedIds) {
      final bucket = groups[gid];
      if (bucket == null || bucket.isEmpty) continue;
      if (!firstGroup) {
        children.add(const SizedBox(height: 24));
      }
      firstGroup = false;
      if (planSelectMode) {
        for (final task in bucket) {
          final key = planKeyForTask(task);
          final displayDone = resolveDisplayDone(task, key);
          children.add(
            planCardRow(
              context: context,
              task: task,
              key: key,
              displayDone: displayDone,
              isSelected: isSelectedKey(key),
              planActualByPbId: planActualByPbId,
            ),
          );
        }
      } else {
        children.add(
          PlanningGroupedReorderBucket(
            listKey: 'tag-bucket-$gid',
            bucket: bucket,
            planSelectMode: planSelectMode,
            planKeyForTask: planKeyForTask,
            resolveDisplayDone: resolveDisplayDone,
            isSelectedKey: isSelectedKey,
            canReorderTask: canReorderTask,
            planActualByPbId: planActualByPbId,
            planCardRow: planCardRow,
            onReorder: (oldI, newI) => onTagBucketReorder(gid, oldI, newI),
          ),
        );
      }
    }
    final sidePadding =
        shellUsesSideNavigation(MediaQuery.sizeOf(context).width)
        ? kShellDesktopContentHorizontalPadding
        : 8.0;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 8),
      children: children,
    );
  }
}
