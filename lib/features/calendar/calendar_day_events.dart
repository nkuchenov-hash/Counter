import 'package:counter/data/database_service.dart';
import 'package:counter/features/calendar/calendar_drag_and_reschedule.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Category bars / event pills inside month/week day cells.
class CalendarDayEventList extends StatelessWidget {
  const CalendarDayEventList({
    super.key,
    required this.tasks,
    required this.loc,
    required this.showPills,
    required this.maxVisible,
    this.vertical = false,
    this.enableDrag = false,
    this.outsideMonth = false,
  });

  final List<PlanningTask> tasks;
  final String loc;
  final bool showPills;
  final int maxVisible;
  final bool vertical;
  final bool enableDrag;
  final bool outsideMonth;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final visible = tasks.take(maxVisible).toList();
    final extra = tasks.length - visible.length;

    if (!showPills) {
      return Wrap(
        spacing: 3,
        runSpacing: 2,
        children: [
          for (final task in visible)
            CalendarPlanDraggable(
              tasks: enableDrag ? [task] : const [],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  task.startTime == null
                      ? '•'
                      : '${task.startTime!.hour.toString().padLeft(2, '0')}:${task.startTime!.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: outsideMonth
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.70)
                        : DatabaseService.instance.getCategoryColor(task.categoryId),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (extra > 0)
            Text(
              '+$extra',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: CalendarPlanDraggable(
              tasks: enableDrag ? [t] : const [],
              child: Opacity(
                opacity: outsideMonth ? 0.62 : 1,
                child: CalendarEventPill(task: t, loc: loc),
              ),
            ),
          ),
        if (extra > 0)
          Text(
            t(loc, 'calendar_more_tasks').replaceFirst('%s', '$extra'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }
}

class CalendarEventPill extends StatelessWidget {
  const CalendarEventPill({super.key, required this.task, required this.loc});

  final PlanningTask task;
  final String loc;

  String _timePrefix() {
    final st = task.startTime;
    if (st == null) return '';
    return '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')} ';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = DatabaseService.instance.getCategoryColor(task.categoryId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: tone.withValues(alpha: 0.88), width: 3),
        ),
      ),
      child: Text(
        '${_timePrefix()}${task.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
              decoration: task.isDone ? TextDecoration.lineThrough : null,
            ),
      ),
    );
  }
}
