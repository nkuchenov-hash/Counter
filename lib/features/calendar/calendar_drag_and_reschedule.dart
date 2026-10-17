import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
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
  return task.startTime != null &&
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

/// Shared Time View insertion/cascade engine for Calendar's date and time drop.
/// Single group source and destination incumbents are one scheduling set.
Future<bool> calendarReschedulePlans(
  BuildContext context,
  List<PlanningTask> source,
  DateTime targetStart, [
  DateTime? fingerWallTime,
]) async {
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

  final ordered = source.toList()
    ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
  final movingIds = ordered.map((t) => t.planRowIdForBackend).toSet();
  final incumbents = db.planningDayTasksSnapshot(targetStart)
      .where((task) => task.startTime != null &&
          !movingIds.contains(task.planRowIdForBackend))
      .toList(growable: false);
  final scheduled = <PlanningTask>[...incumbents, ...ordered];
  final fixedIds = {
    for (final task in incumbents)
      if (isPlanFixedInTimeView(task, fixedTags)) task.planRowIdForBackend,
  };

  final primary = ordered.first;
  final resolveDuration = db.resolvePlanDurationMinutesFromTags;
  final primaryDuration = planWallDurationMinutesForCascade(
    primary, resolveDurationMinutes: resolveDuration,
  );

  // Exactly like Time View, a pointer on an existing card inserts before or
  // after that card. A pointer in empty canvas chooses a snapped wall time.
  TimeViewInsertionIntent? targetIntent;
  if (fingerWallTime != null) {
    for (final task in incumbents) {
      final st = task.startTime!;
      final duration = planWallDurationMinutesForCascade(
        task, resolveDurationMinutes: resolveDuration,
      );
      final end = task.endDateTime ?? st.add(Duration(minutes: duration));
      if (!fingerWallTime.isBefore(st) && fingerWallTime.isBefore(end)) {
        final midpoint = st.add(Duration(minutes: duration ~/ 2));
        targetIntent = TimeViewInsertionIntent(
          draggedPlanId: primary.planRowIdForBackend,
          targetPlanId: task.planRowIdForBackend,
          insertPosition: fingerWallTime.isBefore(midpoint)
              ? TimeViewInsertPosition.before
              : TimeViewInsertPosition.after,
          targetStartWall: st,
          targetEndWall: end,
          draggedDurationMinutes: primaryDuration,
          draggedHadEnd: primary.endDateTime != null,
        );
        break;
      }
    }
  }

  final result = computeTimeViewInsertionCascade(
    scheduledTasks: scheduled,
    draggedPlanIds: movingIds,
    primaryDraggedPlanId: primary.planRowIdForBackend,
    fixedPlanIds: fixedIds,
    resolveDurationMinutes: resolveDuration,
    targetIntent: targetIntent,
    emptyCanvasStartWall: targetIntent == null ? targetStart : null,
    // Keep each group member's explicit end-time semantics independently.
    emptyCanvasHadEnd: false,
  );
  if (!result.accepted) {
    error('Перенос невозможен: конфликт с фиксированным временем или порядком',
        'Drop blocked by fixed-time or sequencing constraints');
    return false;
  }
  final patches = <PlanningBulkPatch>[];
  final staged = <PlanningTask>[];
  for (final change in result.patches) {
    final task = change.task;
    if (!calendarPlanCanMove(task) ||
        isPlanFixedInTimeView(task, fixedTags)) {
      error('Каскад затрагивает закреплённый или повторяющийся план',
          'Cascade would modify a fixed or recurring plan');
      return false;
    }
  }

  for (final change in result.patches) {
    final task = change.task;
    final st = change.afterStart;
    // Time View's cascade diff includes the exact final times for ALL shifted
    // plans. Preserve real optional end markers rather than creating fake ends.
    final original = scheduled.firstWhere(
      (row) => row.planRowIdForBackend == task.planRowIdForBackend,
    );
    final end = original.endDateTime == null ? null : change.afterEnd;
    final anchor = db.planningAuditAnchorDateKey(original);
    final rawInitial = anchor.length >= 10
        ? anchor
        : db.planningWallScheduleDateKey(original);
    final day = DateTime(st.year, st.month, st.day);
    final key = _dayKey(day);
    final initial = rawInitial.length >= 10 ? rawInitial : key;
    final postponed = !original.isDone && db.planningShouldMarkPostponed(
      anchorKey: initial, newScheduleKey: key,
    );
    db.applyOptimisticPlanningTask(original.copyWith(
      dateKey: key,
      date: DateTime.utc(day.year, day.month, day.day),
      startTime: st,
      endDateTime: end,
      endDateKey: end == null ? null : _dayKey(end),
      clearEnd: end == null,
      initialDateKey: initial,
      isPostponed: postponed,
    ));
    staged.add(original);
    patches.add(PlanningBulkPatch(
      planRowId: original.planRowIdForBackend,
      planBusinessId: original.planRowId,
      startTimeDisplay: st,
      endDateTimeDisplay: end,
      clearEnd: end == null,
      initialDateKey: initial,
      isPostponed: postponed,
    ));
  }

  if (patches.isEmpty) return true;
  db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
  final ok = await db.bulkUpdatePlans(patches, suppressAppSnack: true);
  if (!ok) {
    for (final task in staged) {
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
