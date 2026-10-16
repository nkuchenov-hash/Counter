import 'dart:async';

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Present a category group without growing the Calendar controller.
void showCalendarTaskGroupSheet({
  required BuildContext context,
  required DateTime day,
  required String categoryName,
  required List<PlanningTask> tasks,
  required ValueChanged<PlanningTask> onEditTask,
  required Future<void> Function(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) onStartRecordFromTask,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => CalendarTaskGroupSheet(
      day: day,
      categoryName: categoryName,
      tasks: tasks,
      onEditTask: (task) {
        Navigator.of(sheetContext).pop();
        onEditTask(task);
      },
      onStartRecordFromTask: onStartRecordFromTask,
    ),
  );
}

/// Expanded normal-size LIFE OS cards for a visually grouped calendar category.
class CalendarTaskGroupSheet extends StatefulWidget {
  const CalendarTaskGroupSheet({
    super.key,
    required this.day,
    required this.categoryName,
    required this.tasks,
    required this.onEditTask,
    required this.onStartRecordFromTask,
  });

  final DateTime day;
  final String categoryName;
  final List<PlanningTask> tasks;
  final ValueChanged<PlanningTask> onEditTask;
  final Future<void> Function(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) onStartRecordFromTask;

  @override
  State<CalendarTaskGroupSheet> createState() => _CalendarTaskGroupSheetState();
}

class _CalendarTaskGroupSheetState extends State<CalendarTaskGroupSheet> {
  final Map<String, bool> _optimisticDone = {};

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final ordered = widget.tasks.toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    return FractionallySizedBox(
      heightFactor: 0.76,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.categoryName, style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(DateFormat.yMMMEd(loc).format(widget.day),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: ordered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = ordered[index];
                final st = task.startTime;
                final label = st == null ? '' :
                    '${_time(st)}${task.endDateTime == null ? '' : ' – ${_time(task.endDateTime!)}'}';
                final done = _optimisticDone[task.planRowIdForBackend] ?? task.isDone;
                return PlanTimeTaskCard(
                  task: task,
                  density: planTimeCardDensityForList(task: task),
                  surface: PlanCardSurface.calendar,
                  timeLabel: label,
                  displayIsDone: done,
                  toggleDoneEnabled: !task.planRowIdForBackend.startsWith('optimistic-'),
                  onTap: () => widget.onEditTask(task),
                  onOpenMenu: (_) => widget.onEditTask(task),
                  onToggleDone: () {
                    final next = !done;
                    setState(() => _optimisticDone[task.planRowIdForBackend] = next);
                    DatabaseService.instance.applyOptimisticPlanningTask(task.copyWith(isDone: next));
                    unawaited(DatabaseService.instance.updatePlanningTask(
                      task.planRowIdForBackend,
                      planBusinessId: task.planRowId,
                      isDone: next,
                      suppressAppSnack: true,
                    ));
                  },
                  onPlay: done ? null : () {
                    unawaited(widget.onStartRecordFromTask(
                      task.title,
                      task.categoryId,
                      task.dateKey,
                      sourcePlanPocketRecordId: DatabaseService.pocketRelationIdOrNull(task.pocketRecordId),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
