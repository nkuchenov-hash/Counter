import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/widgets/planning_group_section.dart';
import 'package:counter/features/planning/widgets/planning_list_grouping.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Category-sort grouped plan list for one planning day.
class PlanningCategoryGroupedList extends StatelessWidget {
  const PlanningCategoryGroupedList({
    super.key,
    required this.tasks,
    required this.planActualByPbId,
    required this.sortTreatAsDone,
    required this.planSelectMode,
    required this.planKeyForTask,
    required this.resolveDisplayDone,
    required this.isSelectedKey,
    required this.canReorderTask,
    required this.planCardRow,
    required this.onCategoryBucketReorder,
  });

  final List<PlanningTask> tasks;
  final Map<String, int> planActualByPbId;
  final bool Function(PlanningTask task) sortTreatAsDone;
  final bool planSelectMode;
  final String Function(PlanningTask task) planKeyForTask;
  final bool Function(PlanningTask task, String key) resolveDisplayDone;
  final bool Function(String key) isSelectedKey;
  final bool Function(PlanningTask task) canReorderTask;
  final PlanningGroupedPlanCardRowBuilder planCardRow;
  final void Function(String categoryPath, int oldIndex, int newIndex)
  onCategoryBucketReorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = groupPlanningTasksByCategoryPath(
      tasks,
      sortTreatAsDone: sortTreatAsDone,
    );
    final keys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final children = <Widget>[];
    var firstCategoryGroup = true;
    for (final k in keys) {
      final bucket = groups[k];
      if (bucket == null || bucket.isEmpty) continue;
      if (!firstCategoryGroup) {
        children.add(const SizedBox(height: 32));
      }
      firstCategoryGroup = false;
      children.add(
        PlanningCategoryGroupHeader(
          categoryPath: localizeCategoryBreadcrumbPath(k, currentLocale.value),
          scheme: scheme,
        ),
      );
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
            listKey: 'category-bucket-$k',
            bucket: bucket,
            planSelectMode: planSelectMode,
            planKeyForTask: planKeyForTask,
            resolveDisplayDone: resolveDisplayDone,
            isSelectedKey: isSelectedKey,
            canReorderTask: canReorderTask,
            planActualByPbId: planActualByPbId,
            planCardRow: planCardRow,
            onReorder: (oldI, newI) => onCategoryBucketReorder(k, oldI, newI),
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
