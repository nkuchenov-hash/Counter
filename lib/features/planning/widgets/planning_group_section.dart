import 'package:counter/data/models.dart';
import 'package:counter/features/planning/widgets/planning_list_helpers.dart';
import 'package:flutter/material.dart';

/// Builds one plan card row inside grouped category/tag lists.
typedef PlanningGroupedPlanCardRowBuilder = Widget Function({
  required BuildContext context,
  required PlanningTask task,
  required String key,
  required bool displayDone,
  required bool isSelected,
  required Map<String, int> planActualByPbId,
  bool omitLongPressForReorder,
});

/// Reorderable task bucket shared by category- and tag-grouped lists.
class PlanningGroupedReorderBucket extends StatelessWidget {
  const PlanningGroupedReorderBucket({
    super.key,
    required this.listKey,
    required this.bucket,
    required this.planSelectMode,
    required this.planKeyForTask,
    required this.resolveDisplayDone,
    required this.isSelectedKey,
    required this.canReorderTask,
    required this.planActualByPbId,
    required this.planCardRow,
    required this.onReorder,
  });

  final String listKey;
  final List<PlanningTask> bucket;
  final bool planSelectMode;
  final String Function(PlanningTask task) planKeyForTask;
  final bool Function(PlanningTask task, String key) resolveDisplayDone;
  final bool Function(String key) isSelectedKey;
  final bool Function(PlanningTask task) canReorderTask;
  final Map<String, int> planActualByPbId;
  final PlanningGroupedPlanCardRowBuilder planCardRow;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      key: ValueKey<String>(listKey),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: planningReorderProxyDecorator,
      itemCount: bucket.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final task = bucket[index];
        final key = planKeyForTask(task);
        final displayDone = resolveDisplayDone(task, key);
        final canReorder = !planSelectMode && canReorderTask(task);
        return ReorderableDelayedDragStartListener(
          key: ValueKey<String>(key),
          index: index,
          enabled: canReorder,
          child: planCardRow(
            context: context,
            task: task,
            key: key,
            displayDone: displayDone,
            isSelected: isSelectedKey(key),
            planActualByPbId: planActualByPbId,
            omitLongPressForReorder: canReorder,
          ),
        );
      },
    );
  }
}

/// Category breadcrumb header above a grouped plan bucket.
class PlanningCategoryGroupHeader extends StatelessWidget {
  const PlanningCategoryGroupHeader({
    super.key,
    required this.categoryPath,
    required this.scheme,
  });

  final String categoryPath;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          categoryPath,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
