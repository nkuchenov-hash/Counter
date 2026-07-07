import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Focused-day task list below the calendar grid (stream + plan cards).
class CalendarSelectedDayTaskPanel extends StatelessWidget {
  const CalendarSelectedDayTaskPanel({
    super.key,
    required this.loc,
    required this.selectedDay,
    required this.stream,
    required this.onCollapse,
    required this.onEditTask,
    required this.onAddPlan,
    required this.onStartRecordFromTask,
  });

  final String loc;
  final DateTime selectedDay;
  final Stream<List<PlanningTask>>? stream;
  final VoidCallback onCollapse;
  final void Function(PlanningTask task) onEditTask;
  final VoidCallback onAddPlan;
  final Future<void> Function(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) onStartRecordFromTask;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = DateFormat.yMMMEd(loc).format(selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
              ),
              IconButton(
                tooltip: t(loc, 'calendar_collapse'),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                onPressed: onCollapse,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: AppButton(
            label: t(loc, 'calendar_add_plan'),
            icon: Icons.add_rounded,
            onPressed: onAddPlan,
            expand: true,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PlanningTask>>(
            stream: stream,
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <PlanningTask>[];
              final scheduled = all
                  .where((t) => t.startTime != null)
                  .toList()
                ..sort((a, b) {
                  final as = a.startTime;
                  final bs = b.startTime;
                  if (as == null || bs == null) return 0;
                  return as.compareTo(bs);
                });
              if (snapshot.connectionState == ConnectionState.waiting &&
                  scheduled.isEmpty) {
                return const Center(
                  child: AppLoading(size: AppLoadingSize.small),
                );
              }
              if (scheduled.isEmpty) {
                return AppEmptyState(message: t(loc, 'no_planned_tasks_date'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: scheduled.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = scheduled[index];
                  String timeLabel() {
                    final st = task.startTime;
                    if (st == null) return '';
                    String hhmm(DateTime t) =>
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    final et = task.endDateTime;
                    if (et != null) return '${hhmm(st)} – ${hhmm(et)}';
                    return hhmm(st);
                  }
                  return PlanTimeTaskCard(
                    task: task,
                    density: planTimeCardDensityForList(task: task),
                    surface: PlanCardSurface.calendar,
                    timeLabel: timeLabel(),
                    displayIsDone: task.isDone,
                    toggleDoneEnabled:
                        !task.planRowIdForBackend.startsWith('optimistic-'),
                    onToggleDone: () {
                      final next = !task.isDone;
                      DatabaseService.instance.applyOptimisticPlanningTask(
                        task.copyWith(isDone: next),
                      );
                      unawaited(
                        DatabaseService.instance.updatePlanningTask(
                          task.planRowIdForBackend,
                          planBusinessId: task.planRowId,
                          isDone: next,
                          suppressAppSnack: true,
                        ),
                      );
                    },
                    onPlay: task.isDone
                        ? null
                        : () {
                            final dateKey = task.startTime != null
                                ? task.dateKey
                                : DatabaseService.instance
                                    .getTimelineDeviceLocalTodayDateKey();
                            unawaited(
                              onStartRecordFromTask(
                                task.title,
                                task.categoryId,
                                dateKey,
                                sourcePlanPocketRecordId:
                                    DatabaseService.pocketRelationIdOrNull(
                                  task.pocketRecordId,
                                ),
                              ),
                            );
                          },
                    onOpenMenu: (_) => onEditTask(task),
                    onTap: () => onEditTask(task),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
