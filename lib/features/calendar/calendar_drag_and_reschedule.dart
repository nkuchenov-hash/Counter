import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
import 'package:counter/features/planning/bulk_planning_edit_sheet.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Drag one scheduled plan or an existing visual-only category group.
class CalendarDragPayload {
  CalendarDragPayload(List<PlanningTask> source)
      : tasks = List.unmodifiable(source.toList()
          ..sort((a, b) => a.startTime!.compareTo(b.startTime!)));

  final List<PlanningTask> tasks;
  bool get canMove => tasks.isNotEmpty && tasks.every(calendarPlanCanMove);
}

/// Match Time View's safeguards: do not mutate unsaved or recurring instances.
bool calendarPlanCanMove(PlanningTask task) {
  final id = task.planRowIdForBackend.trim();
  final pb = task.pocketRecordId?.trim() ?? '';
  return task.startTime != null &&
      pb.isNotEmpty &&
      id.isNotEmpty &&
      !id.startsWith('virt-') &&
      !id.startsWith('optimistic-') &&
      isPlanTimelineVerticallyDraggable(task);
}

class CalendarPlanDraggable extends StatelessWidget {
  const CalendarPlanDraggable({super.key, required this.tasks, required this.child});

  final List<PlanningTask> tasks;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty || !tasks.every(calendarPlanCanMove)) return child;
    final payload = CalendarDragPayload(tasks);
    final first = payload.tasks.first;
    final time = first.startTime!;
    final label = tasks.length == 1 ? first.title : '${tasks.length} × ${first.title}';
    final feedback = Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}  $label',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      );
    if (MediaQuery.sizeOf(context).width >= kShellDesktopNavBreakpoint) {
      // Desktop mirrors Time View: drag immediately with the pointer.
      return Draggable<CalendarDragPayload>(
        data: payload,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.32, child: child),
        child: child,
      );
    }
    // Phone scrolling remains intentional; hold before dragging a plan.
    return LongPressDraggable<CalendarDragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 190),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.32, child: child),
      child: child,
    );
  }
}

/// Move a category group rigidly: preserve original member gaps and durations.
List<({PlanningTask task, DateTime start, DateTime? end})>
calendarShiftedPlans(List<PlanningTask> tasks, DateTime targetStart) {
  if (tasks.isEmpty) return [];
  final ordered = tasks.toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
  final delta = targetStart.difference(ordered.first.startTime!);
  return [
    for (final task in ordered)
      (task: task, start: task.startTime!.add(delta), end: task.endDateTime?.add(delta)),
  ];
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Same data/collision pipeline as Planning's bulk move; never visual-only.
Future<bool> calendarReschedulePlans(
  BuildContext context,
  List<PlanningTask> source,
  DateTime targetStart,
) async {
  if (source.isEmpty || !source.every(calendarPlanCanMove)) return false;
  final db = DatabaseService.instance;
  final fixedTags = await TimeViewFixedTagPrefs.load();
  if (!context.mounted) return false;

  void error(String ru, String en) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(currentLocale.value == 'ru' ? ru : en),
    ));
  }
  if (source.any((task) => isPlanFixedInTimeView(task, fixedTags))) {
    error('План с фиксированным временем нельзя переносить',
        'A fixed-time plan cannot be moved');
    return false;
  }

  final shifted = calendarShiftedPlans(source, targetStart);
  final dragIds = source.map((t) => t.planRowIdForBackend).toSet();
  final effectiveEnd = shifted.map((row) =>
      row.end ?? row.start.add(Duration(
        minutes: planWallDurationMinutesForCascade(
          row.task, resolveDurationMinutes: db.resolvePlanDurationMinutesFromTags,
        ),
      ))).reduce((a, b) => a.isAfter(b) ? a : b);

  final incumbents = db.planningDayTasksSnapshot(targetStart)
      .where((task) => !dragIds.contains(task.planRowIdForBackend))
      .toList(growable: false);
  final collisions = computeBulkDestinationConflictShifts(
    blockStart: targetStart,
    blockEnd: effectiveEnd,
    existingDestinationPlans: incumbents,
    durationMinutesForTask: (task) => planWallDurationMinutesForCascade(
      task, resolveDurationMinutes: db.resolvePlanDurationMinutesFromTags,
    ),
  );
  if (collisions.any((row) => !calendarPlanCanMove(row.task) ||
      isPlanFixedInTimeView(row.task, fixedTags))) {
    error('Перенос пересекается с закреплённым или повторяющимся планом',
        'Drop conflicts with a fixed or recurring plan');
    return false;
  }

  final originals = <PlanningTask>[...source, ...collisions.map((row) => row.task)];
  final patches = <PlanningBulkPatch>[];
  void stage(PlanningTask task, DateTime start, DateTime? end) {
    final anchor = db.planningAuditAnchorDateKey(task);
    final rawInitial = anchor.length >= 10 ? anchor : db.planningWallScheduleDateKey(task);
    final day = DateTime(start.year, start.month, start.day);
    final newKey = _dayKey(day);
    final initial = rawInitial.length >= 10 ? rawInitial : newKey;
    final postponed = !task.isDone && db.planningShouldMarkPostponed(
      anchorKey: initial, newScheduleKey: newKey,
    );
    db.applyOptimisticPlanningTask(task.copyWith(
      dateKey: newKey,
      date: DateTime.utc(day.year, day.month, day.day),
      startTime: start,
      endDateTime: end,
      endDateKey: end == null ? null : _dayKey(end),
      clearEnd: end == null,
      initialDateKey: initial,
      isPostponed: postponed,
    ));
    patches.add(PlanningBulkPatch(
      planRowId: task.planRowIdForBackend,
      planBusinessId: task.planRowId,
      startTimeDisplay: start,
      endDateTimeDisplay: end,
      clearEnd: end == null,
      initialDateKey: initial,
      isPostponed: postponed,
    ));
  }

  for (final row in shifted) stage(row.task, row.start, row.end);
  for (final row in collisions) stage(row.task, row.times.start, row.times.end);
  db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
  final ok = await db.bulkUpdatePlans(patches, suppressAppSnack: true);
  if (!ok) {
    // Drop failed/partial optimistic overlays; server refresh becomes canonical.
    for (final task in originals) {
      db.clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
    }
    db.notifyPlanningRefresh();
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (currentLocale.value == 'ru' ? 'Планы перенесены' : 'Plans moved')
          : t(currentLocale.value, 'plan_save_failed')),
    ));
  }
  return ok;
}
