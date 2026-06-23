import 'dart:math' as math;

import 'package:counter/data/models.dart';

/// One plan whose wall schedule changed after sequential cascade.
class PlanTimeSequentialCascadePatch {
  const PlanTimeSequentialCascadePatch({
    required this.task,
    required this.beforeStart,
    required this.beforeEnd,
    required this.afterStart,
    required this.afterEnd,
  });

  final PlanningTask task;
  final DateTime beforeStart;
  final DateTime? beforeEnd;
  final DateTime afterStart;
  final DateTime afterEnd;
}

/// Wall-clock duration in minutes for cascade (preserved when shifting).
int planWallDurationMinutesForCascade(
  PlanningTask task, {
  required int Function(List<Tag> tags) resolveDurationMinutes,
}) {
  final start = task.startTime;
  if (start == null) return 30;
  final end = task.endDateTime;
  if (end != null && !end.isBefore(start)) {
    return math.max(5, end.difference(start).inMinutes);
  }
  return math.max(5, resolveDurationMinutes(task.tags));
}

int _planCascadeSortCompare(PlanningTask a, PlanningTask b) {
  final aStart = a.startTime;
  final bStart = b.startTime;
  if (aStart == null && bStart == null) {
    return a.planRowIdForBackend.compareTo(b.planRowIdForBackend);
  }
  if (aStart == null) return 1;
  if (bStart == null) return -1;
  final byStart = aStart.compareTo(bStart);
  if (byStart != 0) return byStart;
  final byOrder = a.order.compareTo(b.order);
  if (byOrder != 0) return byOrder;
  return a.planRowIdForBackend.compareTo(b.planRowIdForBackend);
}

bool _wallScheduleEqual(PlanningTask a, PlanningTask b) {
  final aStart = a.startTime;
  final bStart = b.startTime;
  if (aStart == null || bStart == null) return aStart == bStart;
  if (aStart != bStart) return false;
  return a.endDateTime == b.endDateTime;
}

/// Sequential Time View day planner: shift overlapping tasks down, preserve duration.
///
/// Sort: start time → [order] → plan id. For each task after the first, if
/// `start < previous.end` then `start = previous.end` and `end = start + duration`.
List<PlanningTask> cascadeScheduledPlansForTimeViewDay(
  List<PlanningTask> tasks, {
  required int Function(List<Tag> tags) resolveDurationMinutes,
}) {
  if (tasks.isEmpty) return const [];

  final scheduled = tasks.where((t) => t.startTime != null).toList()
    ..sort(_planCascadeSortCompare);

  if (scheduled.isEmpty) return List<PlanningTask>.from(tasks);

  final cascadedById = <String, PlanningTask>{};
  DateTime? prevEnd;

  for (final task in scheduled) {
    final origStart = task.startTime!;
    final durMin = planWallDurationMinutesForCascade(
      task,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    var newStart = origStart;
    if (prevEnd != null && newStart.isBefore(prevEnd)) {
      newStart = DateTime(
        origStart.year,
        origStart.month,
        origStart.day,
        prevEnd.hour,
        prevEnd.minute,
        prevEnd.second,
        prevEnd.millisecond,
        prevEnd.microsecond,
      );
    }
    final newEnd = newStart.add(Duration(minutes: durMin));
    final updated = task.copyWith(
      startTime: newStart,
      endDateTime: newEnd,
      clearEnd: false,
    );
    cascadedById[task.planRowIdForBackend] = updated;
    prevEnd = newEnd;
  }

  return tasks
      .map(
        (t) => cascadedById[t.planRowIdForBackend] ?? t,
      )
      .toList(growable: false);
}

/// Patches where cascade changed wall start/end.
List<PlanTimeSequentialCascadePatch> diffSequentialCascadePatches(
  List<PlanningTask> before,
  List<PlanningTask> after,
) {
  final afterById = {for (final t in after) t.planRowIdForBackend: t};
  final patches = <PlanTimeSequentialCascadePatch>[];
  for (final orig in before) {
    final next = afterById[orig.planRowIdForBackend];
    if (next == null) continue;
    if (_wallScheduleEqual(orig, next)) continue;
    final beforeStart = orig.startTime;
    final afterStart = next.startTime;
    if (beforeStart == null || afterStart == null) continue;
    patches.add(
      PlanTimeSequentialCascadePatch(
        task: next,
        beforeStart: beforeStart,
        beforeEnd: orig.endDateTime,
        afterStart: afterStart,
        afterEnd: next.endDateTime ?? afterStart,
      ),
    );
  }
  return patches;
}

/// Target-card insertion schedule for Time View drag/drop (zero scheduled-time gap).
class TimeViewTargetDropSchedule {
  const TimeViewTargetDropSchedule({
    required this.startWall,
    this.endWall,
    required this.insertBefore,
  });

  final DateTime startWall;
  final DateTime? endWall;
  final bool insertBefore;
}

/// Exact adjacent insertion when dropping onto another scheduled card.
///
/// After target: `start = targetEnd`, `end = start + duration`.
/// Before target: `end = targetStart`, `start = end - duration`.
TimeViewTargetDropSchedule computeTimeViewTargetDropSchedule({
  required DateTime targetStartWall,
  required DateTime targetEndWall,
  required int draggedDurationMinutes,
  required bool insertBefore,
  required bool draggedHadEnd,
}) {
  final dur = math.max(1, draggedDurationMinutes);
  if (insertBefore) {
    final endWall = targetStartWall;
    final startWall = endWall.subtract(Duration(minutes: dur));
    return TimeViewTargetDropSchedule(
      startWall: startWall,
      endWall: draggedHadEnd ? endWall : null,
      insertBefore: true,
    );
  }
  final startWall = targetEndWall;
  return TimeViewTargetDropSchedule(
    startWall: startWall,
    endWall: draggedHadEnd ? startWall.add(Duration(minutes: dur)) : null,
    insertBefore: false,
  );
}

/// Stable target insertion captured during drag-over (not at pointer-up).
enum TimeViewInsertPosition { before, after }

class TimeViewInsertionIntent {
  const TimeViewInsertionIntent({
    required this.draggedPlanId,
    required this.targetPlanId,
    required this.insertPosition,
    required this.targetStartWall,
    required this.targetEndWall,
    required this.draggedDurationMinutes,
    required this.draggedHadEnd,
  });

  final String draggedPlanId;
  final String targetPlanId;
  final TimeViewInsertPosition insertPosition;
  final DateTime targetStartWall;
  final DateTime targetEndWall;
  final int draggedDurationMinutes;
  final bool draggedHadEnd;

  bool get insertBefore => insertPosition == TimeViewInsertPosition.before;
}

/// Reorder scheduled tasks for explicit target insert (no start-time sort).
List<PlanningTask> buildExplicitOrderForTargetInsert({
  required List<PlanningTask> scheduled,
  required String draggedPlanId,
  required String targetPlanId,
  required bool insertBefore,
}) {
  if (scheduled.isEmpty) return const [];

  PlanningTask? dragged;
  final rest = <PlanningTask>[];
  for (final t in scheduled) {
    if (t.planRowIdForBackend == draggedPlanId) {
      dragged = t;
    } else {
      rest.add(t);
    }
  }
  if (dragged == null) return List<PlanningTask>.from(scheduled);

  var targetIdx = -1;
  for (var i = 0; i < rest.length; i++) {
    if (rest[i].planRowIdForBackend == targetPlanId) {
      targetIdx = i;
      break;
    }
  }
  if (targetIdx < 0) return List<PlanningTask>.from(scheduled);

  final insertAt = insertBefore ? targetIdx : targetIdx + 1;
  rest.insert(insertAt, dragged);
  return rest;
}

/// Cascade in explicit list order (drag target insertion). Does not sort by start time.
List<PlanningTask> cascadeScheduledPlansForExplicitTimeViewOrder(
  List<PlanningTask> explicitOrder, {
  required int Function(List<Tag> tags) resolveDurationMinutes,
  TimeViewInsertionIntent? targetIntent,
}) {
  if (explicitOrder.isEmpty) return const [];

  final scheduled = explicitOrder.where((t) => t.startTime != null).toList();
  if (scheduled.isEmpty) return List<PlanningTask>.from(explicitOrder);

  final cascadedById = <String, PlanningTask>{};
  DateTime? prevEnd;

  for (final task in scheduled) {
    final id = task.planRowIdForBackend;
    final durMin = planWallDurationMinutesForCascade(
      task,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    var newStart = task.startTime!;
    DateTime? newEnd =
        task.endDateTime ?? newStart.add(Duration(minutes: durMin));

    if (targetIntent != null && id == targetIntent.draggedPlanId) {
      final sched = computeTimeViewTargetDropSchedule(
        targetStartWall: targetIntent.targetStartWall,
        targetEndWall: targetIntent.targetEndWall,
        draggedDurationMinutes: targetIntent.draggedDurationMinutes,
        insertBefore: targetIntent.insertBefore,
        draggedHadEnd: targetIntent.draggedHadEnd,
      );
      newStart = sched.startWall;
      newEnd = sched.endWall ?? newStart.add(Duration(minutes: durMin));
    } else if (prevEnd != null && newStart.isBefore(prevEnd)) {
      newStart = DateTime(
        newStart.year,
        newStart.month,
        newStart.day,
        prevEnd.hour,
        prevEnd.minute,
        prevEnd.second,
        prevEnd.millisecond,
        prevEnd.microsecond,
      );
      newEnd = newStart.add(Duration(minutes: durMin));
    }

    final updated = task.copyWith(
      startTime: newStart,
      endDateTime: newEnd,
      clearEnd: false,
    );
    cascadedById[id] = updated;
    prevEnd = newEnd;
  }

  return explicitOrder
      .map((t) => cascadedById[t.planRowIdForBackend] ?? t)
      .toList(growable: false);
}

class TimeViewTargetInsertionResult {
  const TimeViewTargetInsertionResult({
    required this.cascaded,
    required this.draggedStartWall,
    required this.draggedEndWall,
    required this.orderBefore,
    required this.orderAfter,
  });

  final List<PlanningTask> cascaded;
  final DateTime draggedStartWall;
  final DateTime? draggedEndWall;
  final List<String> orderBefore;
  final List<String> orderAfter;
}

/// Preview/commit path for stored target insertion intent.
TimeViewTargetInsertionResult applyTimeViewTargetInsertion({
  required List<PlanningTask> scheduled,
  required TimeViewInsertionIntent intent,
  required int Function(List<Tag> tags) resolveDurationMinutes,
}) {
  final orderBefore = scheduled.map((t) => t.planRowIdForBackend).toList();
  final ordered = buildExplicitOrderForTargetInsert(
    scheduled: scheduled,
    draggedPlanId: intent.draggedPlanId,
    targetPlanId: intent.targetPlanId,
    insertBefore: intent.insertBefore,
  );
  final orderAfter = ordered.map((t) => t.planRowIdForBackend).toList();
  final cascaded = cascadeScheduledPlansForExplicitTimeViewOrder(
    ordered,
    resolveDurationMinutes: resolveDurationMinutes,
    targetIntent: intent,
  );
  final dragged = cascaded.firstWhere(
    (t) => t.planRowIdForBackend == intent.draggedPlanId,
  );
  return TimeViewTargetInsertionResult(
    cascaded: cascaded,
    draggedStartWall: dragged.startTime ?? intent.targetEndWall,
    draggedEndWall: dragged.endDateTime,
    orderBefore: orderBefore,
    orderAfter: orderAfter,
  );
}

bool scheduledPlansHaveWallOverlap(
  List<PlanningTask> tasks, {
  required int Function(List<Tag> tags) resolveDurationMinutes,
}) {
  final scheduled = tasks.where((t) => t.startTime != null).toList()
    ..sort(_planCascadeSortCompare);
  DateTime? prevEnd;
  for (final task in scheduled) {
    final start = task.startTime!;
    if (prevEnd != null && start.isBefore(prevEnd)) return true;
    final durMin = planWallDurationMinutesForCascade(
      task,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    prevEnd = start.add(Duration(minutes: durMin));
  }
  return false;
}
