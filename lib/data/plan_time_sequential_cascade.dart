import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';

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
    return math.max(
      kPlanTimeMinDurationMinutes,
      end.difference(start).inMinutes,
    );
  }
  return math.max(
    kPlanTimeMinDurationMinutes,
    resolveDurationMinutes(task.tags),
  );
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
      .map((t) => cascadedById[t.planRowIdForBackend] ?? t)
      .toList(growable: false);
}

/// Applies one manual resize, then pushes only the following overlap chain.
///
/// Cards before [resizedTask] never move. Every pushed card keeps its original
/// duration and whether it had an explicit end time.
List<PlanningTask> cascadeScheduledPlansAfterManualResize({
  required List<PlanningTask> scheduledTasks,
  required PlanningTask resizedTask,
  required int Function(List<Tag> tags) resolveDurationMinutes,
}) {
  final resizedStart = resizedTask.startTime;
  if (resizedStart == null) return List<PlanningTask>.from(scheduledTasks);

  final resizedId = resizedTask.planRowIdForBackend;
  final scheduled =
      scheduledTasks
          .where((task) => task.startTime != null)
          .map(
            (task) =>
                task.planRowIdForBackend == resizedId ? resizedTask : task,
          )
          .toList()
        ..sort(_planCascadeSortCompare);
  final resizedIndex = scheduled.indexWhere(
    (task) => task.planRowIdForBackend == resizedId,
  );
  if (resizedIndex < 0) return List<PlanningTask>.from(scheduledTasks);

  final changedById = <String, PlanningTask>{resizedId: resizedTask};
  final resizedDuration = planWallDurationMinutesForCascade(
    resizedTask,
    resolveDurationMinutes: resolveDurationMinutes,
  );
  var cursorEnd =
      resizedTask.endDateTime ??
      resizedStart.add(Duration(minutes: resizedDuration));

  for (var index = resizedIndex + 1; index < scheduled.length; index += 1) {
    final task = scheduled[index];
    final originalStart = task.startTime!;
    final duration = planWallDurationMinutesForCascade(
      task,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    if (!originalStart.isBefore(cursorEnd)) break;
    final hadExplicitEnd = task.endDateTime != null;
    final shiftedStart = cursorEnd;
    final effectiveEnd = shiftedStart.add(Duration(minutes: duration));
    changedById[task.planRowIdForBackend] = task.copyWith(
      startTime: shiftedStart,
      endDateTime: hadExplicitEnd ? effectiveEnd : null,
      clearEnd: !hadExplicitEnd,
    );
    cursorEnd = effectiveEnd;
  }

  return scheduledTasks
      .map((task) => changedById[task.planRowIdForBackend] ?? task)
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

/// How the insertion intent was produced (target card vs empty canvas).
enum TimeViewInsertionSource { targetCard, emptyCanvas }

class TimeViewInsertionIntent {
  const TimeViewInsertionIntent({
    required this.draggedPlanId,
    required this.targetPlanId,
    required this.insertPosition,
    required this.targetStartWall,
    required this.targetEndWall,
    required this.draggedDurationMinutes,
    required this.draggedHadEnd,
    this.source = TimeViewInsertionSource.targetCard,
    this.dragSequenceId,
  });

  final String draggedPlanId;
  final String targetPlanId;
  final TimeViewInsertPosition insertPosition;
  final DateTime targetStartWall;
  final DateTime targetEndWall;
  final int draggedDurationMinutes;
  final bool draggedHadEnd;
  final TimeViewInsertionSource source;
  final int? dragSequenceId;

  bool get insertBefore => insertPosition == TimeViewInsertPosition.before;

  bool get isTargetCardMode => source == TimeViewInsertionSource.targetCard;
}

/// Whether a plan may be vertically dragged on the Time View canvas.
bool isPlanTimelineVerticallyDraggable(PlanningTask task) {
  if (task.startTime == null) return false;
  if (task.planRowIdForBackend.startsWith('optimistic-')) return false;
  final rrule = task.rrule?.trim() ?? '';
  if (rrule.isNotEmpty) return false;
  final inst = task.recurrenceInstanceDateKey?.trim() ?? '';
  if (inst.isNotEmpty) return false;
  return true;
}

/// Refresh target wall times from the live scheduled list before commit.
TimeViewInsertionIntent? refreshTimeViewInsertionIntentFromScheduled({
  required TimeViewInsertionIntent intent,
  required List<PlanningTask> scheduled,
  required int Function(List<Tag> tags) resolveDurationMinutes,
}) {
  if (!intent.isTargetCardMode) return intent;

  PlanningTask? target;
  for (final t in scheduled) {
    if (t.planRowIdForBackend == intent.targetPlanId) {
      target = t;
      break;
    }
  }
  final targetStart = target?.startTime;
  if (target == null || targetStart == null) return null;

  final targetDurMin = planWallDurationMinutesForCascade(
    target,
    resolveDurationMinutes: resolveDurationMinutes,
  );
  final targetEnd =
      target.endDateTime ?? targetStart.add(Duration(minutes: targetDurMin));

  return TimeViewInsertionIntent(
    draggedPlanId: intent.draggedPlanId,
    targetPlanId: intent.targetPlanId,
    insertPosition: intent.insertPosition,
    targetStartWall: targetStart,
    targetEndWall: targetEnd,
    draggedDurationMinutes: intent.draggedDurationMinutes,
    draggedHadEnd: intent.draggedHadEnd,
    source: intent.source,
    dragSequenceId: intent.dragSequenceId,
  );
}

/// Returns a cancel reason string, or null when the target-card intent is valid.
String? validateTimeViewTargetInsertionIntent({
  required TimeViewInsertionIntent intent,
  required List<PlanningTask> scheduled,
  String? expectedDayKey,
}) {
  if (!intent.isTargetCardMode) return null;
  if (intent.draggedPlanId == intent.targetPlanId) {
    return 'draggedEqualsTarget';
  }

  PlanningTask? dragged;
  PlanningTask? target;
  for (final t in scheduled) {
    final id = t.planRowIdForBackend;
    if (id == intent.draggedPlanId) dragged = t;
    if (id == intent.targetPlanId) target = t;
  }

  if (target == null) return 'targetMissing';
  if (dragged == null) return 'draggedMissing';
  if (target.startTime == null) return 'targetUnscheduled';
  if (dragged.startTime == null) return 'draggedUnscheduled';
  if (!isPlanTimelineVerticallyDraggable(dragged)) {
    return 'draggedNotDraggable';
  }

  if (expectedDayKey != null && expectedDayKey.isNotEmpty) {
    final dayKey = target.dateKey.trim();
    if (dayKey.isNotEmpty && dayKey != expectedDayKey) {
      return 'targetDateMismatch';
    }
  }

  return null;
}

String? _lastTimeDropGuardLogKey;
DateTime? _lastTimeDropGuardLogAt;

/// Single-line debug diagnostic for Time View target-card drop guard.
void logTimeDropGuard(String message) {
  if (!kDebugMode) return;
  final now = DateTime.now();
  if (_lastTimeDropGuardLogKey == message &&
      _lastTimeDropGuardLogAt != null &&
      now.difference(_lastTimeDropGuardLogAt!) <
          const Duration(milliseconds: 120)) {
    return;
  }
  _lastTimeDropGuardLogKey = message;
  _lastTimeDropGuardLogAt = now;
  debugPrint('[TIME_DROP_GUARD] $message');
}

/// Geometry for one scheduled card on the Time View canvas (canvas-local px).
class TimeViewCardLayout {
  const TimeViewCardLayout({
    required this.planId,
    required this.topPx,
    required this.heightPx,
    this.targetStartWall,
    this.targetEndWall,
  });

  final String planId;
  final double topPx;
  final double heightPx;
  final DateTime? targetStartWall;
  final DateTime? targetEndWall;

  double get bottomPx => topPx + heightPx;

  bool containsFingerY(double fingerCanvasY) =>
      fingerCanvasY >= topPx && fingerCanvasY <= bottomPx;
}

enum TimeViewDropIntentKind {
  targetCardBefore,
  targetCardAfter,
  emptyCanvas,
  cancel,
}

/// Resolved drop intent from finger position (preview + commit share this).
class TimeViewDropIntent {
  const TimeViewDropIntent._({
    required this.kind,
    this.targetPlanId,
    this.wallStartMinute,
    this.cancelReason,
  });

  final TimeViewDropIntentKind kind;
  final String? targetPlanId;
  final double? wallStartMinute;
  final String? cancelReason;

  factory TimeViewDropIntent.targetCardBefore(String targetPlanId) {
    return TimeViewDropIntent._(
      kind: TimeViewDropIntentKind.targetCardBefore,
      targetPlanId: targetPlanId,
    );
  }

  factory TimeViewDropIntent.targetCardAfter(String targetPlanId) {
    return TimeViewDropIntent._(
      kind: TimeViewDropIntentKind.targetCardAfter,
      targetPlanId: targetPlanId,
    );
  }

  factory TimeViewDropIntent.emptyCanvas(double wallStartMinute) {
    return TimeViewDropIntent._(
      kind: TimeViewDropIntentKind.emptyCanvas,
      wallStartMinute: wallStartMinute,
    );
  }

  factory TimeViewDropIntent.cancel(String reason) {
    return TimeViewDropIntent._(
      kind: TimeViewDropIntentKind.cancel,
      cancelReason: reason,
    );
  }

  bool get isTargetCard =>
      kind == TimeViewDropIntentKind.targetCardBefore ||
      kind == TimeViewDropIntentKind.targetCardAfter;

  bool get insertBefore => kind == TimeViewDropIntentKind.targetCardBefore;
}

/// Central finger-position resolver for Time View vertical drop.
///
/// Uses [fingerLocalPosition].dy in canvas coordinates only — never preview
/// delta, dragged card center, or start-time sort.
TimeViewDropIntent resolveTimeViewDropIntent({
  required Offset fingerLocalPosition,
  required List<TimeViewCardLayout> scheduledCardLayouts,
  required String draggedPlanId,
  required DateTime wallDate,
  required double Function(double canvasY) canvasYToMinutes,
}) {
  final fingerY = fingerLocalPosition.dy;

  // Topmost painted card under finger (reverse paint order).
  for (var i = scheduledCardLayouts.length - 1; i >= 0; i--) {
    final layout = scheduledCardLayouts[i];
    if (layout.planId == draggedPlanId) continue;
    if (!layout.containsFingerY(fingerY)) continue;

    final mid = layout.topPx + layout.heightPx / 2;
    final before = fingerY < mid;
    final intent = before
        ? TimeViewDropIntent.targetCardBefore(layout.planId)
        : TimeViewDropIntent.targetCardAfter(layout.planId);
    logTimeDropGuard(
      'phase=resolve source=targetCard position=${before ? 'before' : 'after'} '
      'dragged=$draggedPlanId target=${layout.planId}',
    );
    return intent;
  }

  final minute = canvasYToMinutes(fingerY);
  logTimeDropGuard(
    'phase=resolve source=emptyCanvas y=${fingerY.toStringAsFixed(1)} '
    'minute=${minute.toStringAsFixed(1)}',
  );
  return TimeViewDropIntent.emptyCanvas(minute);
}

TimeViewInsertionIntent? buildTimeViewInsertionIntentFromDropIntent({
  required TimeViewDropIntent drop,
  required List<TimeViewCardLayout> scheduledCardLayouts,
  required String draggedPlanId,
  required int draggedDurationMinutes,
  required bool draggedHadEnd,
  int? dragSequenceId,
}) {
  if (!drop.isTargetCard || drop.targetPlanId == null) return null;

  TimeViewCardLayout? layout;
  for (final l in scheduledCardLayouts) {
    if (l.planId == drop.targetPlanId) {
      layout = l;
      break;
    }
  }
  final targetStart = layout?.targetStartWall;
  if (layout == null || targetStart == null) return null;

  final targetEnd =
      layout.targetEndWall ??
      targetStart.add(Duration(minutes: draggedDurationMinutes));

  return TimeViewInsertionIntent(
    draggedPlanId: draggedPlanId,
    targetPlanId: drop.targetPlanId!,
    insertPosition: drop.insertBefore
        ? TimeViewInsertPosition.before
        : TimeViewInsertPosition.after,
    targetStartWall: targetStart,
    targetEndWall: targetEnd,
    draggedDurationMinutes: draggedDurationMinutes,
    draggedHadEnd: draggedHadEnd,
    source: TimeViewInsertionSource.targetCard,
    dragSequenceId: dragSequenceId,
  );
}

/// Debug guard: target-card drop must never fall through to raw Y.
void assertTimeViewTargetCardNoRawY({
  required TimeViewDropIntent dropIntent,
  required bool usedRawY,
}) {
  if (!kDebugMode || !dropIntent.isTargetCard || !usedRawY) return;
  logTimeDropGuard('ERROR targetCardIntentFellThroughToRawY');
  assert(false, '[TIME_DROP_GUARD] targetCardIntentFellThroughToRawY');
}

/// Reorder scheduled tasks for explicit bulk target insert (no start-time sort).
List<PlanningTask> buildExplicitOrderForBulkTargetInsert({
  required List<PlanningTask> scheduled,
  required Set<String> draggedPlanIds,
  required String targetPlanId,
  required bool insertBefore,
}) {
  if (scheduled.isEmpty || draggedPlanIds.isEmpty) return const [];

  final dragged = <PlanningTask>[];
  final rest = <PlanningTask>[];
  for (final t in scheduled) {
    if (draggedPlanIds.contains(t.planRowIdForBackend)) {
      dragged.add(t);
    } else {
      rest.add(t);
    }
  }
  if (dragged.isEmpty) return List<PlanningTask>.from(scheduled);

  dragged.sort(_planCascadeSortCompare);

  var targetIdx = -1;
  for (var i = 0; i < rest.length; i++) {
    if (rest[i].planRowIdForBackend == targetPlanId) {
      targetIdx = i;
      break;
    }
  }
  if (targetIdx < 0) return List<PlanningTask>.from(scheduled);

  final insertAt = insertBefore ? targetIdx : targetIdx + 1;
  rest.insertAll(insertAt, dragged);
  return rest;
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

enum TimeViewInsertionMode { targetCard, emptyCanvas, bulkGroup }

/// Result of [computeTimeViewInsertionCascade] (preview + commit share shape).
class TimeViewInsertionCascadeResult {
  const TimeViewInsertionCascadeResult({
    required this.accepted,
    this.blockedReason,
    this.patches = const [],
    this.previewRows = const [],
    this.shiftedPlanIds = const {},
    this.blockedByFixedPlanId,
    this.draggedStartWall,
    this.draggedEndWall,
  });

  final bool accepted;
  final String? blockedReason;
  final List<PlanTimeSequentialCascadePatch> patches;
  final List<PlanningTask> previewRows;
  final Set<String> shiftedPlanIds;
  final String? blockedByFixedPlanId;
  final DateTime? draggedStartWall;
  final DateTime? draggedEndWall;
}

/// Cascade explicit list order with optional fixed-time barriers.
List<PlanningTask>? cascadeScheduledPlansForExplicitTimeViewOrderWithBarriers({
  required List<PlanningTask> explicitOrder,
  required int Function(List<Tag> tags) resolveDurationMinutes,
  TimeViewInsertionIntent? targetIntent,
  Set<String> fixedPlanIds = const {},
  Set<String> draggedPlanIds = const {},
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
      if (fixedPlanIds.contains(id) && !draggedPlanIds.contains(id)) {
        logTimeDropGuard('TIME_VIEW_INSERTION_BLOCKED_BY_FIXED_TIME plan=$id');
        return null;
      }
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

  final out = explicitOrder
      .map((t) => cascadedById[t.planRowIdForBackend] ?? t)
      .toList(growable: false);

  if (scheduledPlansHaveWallOverlap(
    out.where((t) => t.startTime != null).toList(),
    resolveDurationMinutes: resolveDurationMinutes,
  )) {
    logTimeDropGuard('TIME_VIEW_INSERTION_NO_OVERLAP_VERIFIED failed');
    return null;
  }

  return out;
}

Map<String, int>? _resolveOriginalBulkRelativeOffsets({
  required List<PlanningTask> scheduledTasks,
  required Set<String> draggedPlanIds,
  required String primaryDraggedPlanId,
  Map<String, int>? suppliedOffsets,
}) {
  if (draggedPlanIds.isEmpty) return <String, int>{};
  final byId = {
    for (final task in scheduledTasks) task.planRowIdForBackend: task,
  };
  final primaryStart = byId[primaryDraggedPlanId]?.startTime;
  if (primaryStart == null) return null;

  final offsets = <String, int>{};
  for (final id in draggedPlanIds) {
    final start = byId[id]?.startTime;
    if (start == null) return null;
    final originalOffset = start.difference(primaryStart).inMinutes;
    final supplied = suppliedOffsets?[id];
    if (supplied != null && supplied != originalOffset && kDebugMode) {
      debugPrint(
        '[TIME_VIEW_BULK_OFFSET_IGNORED] id=$id '
        'supplied=$supplied original=$originalOffset',
      );
    }
    offsets[id] = originalOffset;
  }
  return offsets;
}

bool _bulkRelativeOffsetsPreserved({
  required List<PlanningTask> tasks,
  required Map<String, int> expectedOffsets,
  required String primaryDraggedPlanId,
}) {
  if (expectedOffsets.length <= 1) return true;
  final byId = {for (final task in tasks) task.planRowIdForBackend: task};
  final primaryStart = byId[primaryDraggedPlanId]?.startTime;
  if (primaryStart == null) return false;
  for (final entry in expectedOffsets.entries) {
    final start = byId[entry.key]?.startTime;
    if (start == null) return false;
    if (start.difference(primaryStart).inMinutes != entry.value) return false;
  }
  return true;
}

/// Pure scheduling for Time View drag insert / bulk move with fixed barriers.
TimeViewInsertionCascadeResult computeTimeViewInsertionCascade({
  required List<PlanningTask> scheduledTasks,
  required Set<String> draggedPlanIds,
  required String primaryDraggedPlanId,
  required Set<String> fixedPlanIds,
  required int Function(List<Tag> tags) resolveDurationMinutes,
  TimeViewInsertionIntent? targetIntent,
  DateTime? emptyCanvasStartWall,
  bool emptyCanvasHadEnd = false,
  int? emptyCanvasDurationMin,
  Map<String, int>? bulkRelativeOffsetMinutes,
}) {
  if (kDebugMode) {
    debugPrint(
      '[TIME_VIEW_INSERTION_CASCADE_STARTED] dragged=${draggedPlanIds.length} '
      'fixed=${fixedPlanIds.length}',
    );
  }

  List<PlanningTask> working = List<PlanningTask>.from(scheduledTasks);
  final resolvedBulkOffsets = _resolveOriginalBulkRelativeOffsets(
    scheduledTasks: scheduledTasks,
    draggedPlanIds: draggedPlanIds,
    primaryDraggedPlanId: primaryDraggedPlanId,
    suppliedOffsets: bulkRelativeOffsetMinutes,
  );
  if (resolvedBulkOffsets == null) {
    return const TimeViewInsertionCascadeResult(
      accepted: false,
      blockedReason: 'bulkScheduleMissing',
    );
  }

  if (targetIntent != null) {
    final primaryId = targetIntent.draggedPlanId;
    PlanningTask? primaryTask;
    for (final t in working) {
      if (t.planRowIdForBackend == primaryId) {
        primaryTask = t;
        break;
      }
    }
    if (primaryTask == null) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'primaryMissing',
      );
    }

    final offsets = resolvedBulkOffsets;

    final primaryDur = planWallDurationMinutesForCascade(
      primaryTask,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    final primaryHadEnd =
        targetIntent.draggedHadEnd || primaryTask.endDateTime != null;
    final anchorSchedule = computeTimeViewTargetDropSchedule(
      targetStartWall: targetIntent.targetStartWall,
      targetEndWall: targetIntent.targetEndWall,
      draggedDurationMinutes: primaryDur,
      insertBefore: targetIntent.insertBefore,
      draggedHadEnd: primaryHadEnd,
    );
    final anchorStart = anchorSchedule.startWall;

    working = working
        .map((t) {
          final id = t.planRowIdForBackend;
          if (!draggedPlanIds.contains(id)) return t;
          final offset = offsets[id]!;
          final start = anchorStart.add(Duration(minutes: offset));
          final dur = planWallDurationMinutesForCascade(
            t,
            resolveDurationMinutes: resolveDurationMinutes,
          );
          final end = primaryHadEnd || t.endDateTime != null
              ? start.add(Duration(minutes: dur))
              : null;
          return t.copyWith(
            startTime: start,
            endDateTime: end,
            clearEnd: end == null,
          );
        })
        .toList(growable: false);

    final ordered = draggedPlanIds.length > 1
        ? buildExplicitOrderForBulkTargetInsert(
            scheduled: working,
            draggedPlanIds: draggedPlanIds,
            targetPlanId: targetIntent.targetPlanId,
            insertBefore: targetIntent.insertBefore,
          )
        : buildExplicitOrderForTargetInsert(
            scheduled: working,
            draggedPlanId: primaryId,
            targetPlanId: targetIntent.targetPlanId,
            insertBefore: targetIntent.insertBefore,
          );

    final cascaded = cascadeScheduledPlansForExplicitTimeViewOrderWithBarriers(
      explicitOrder: ordered,
      resolveDurationMinutes: resolveDurationMinutes,
      fixedPlanIds: fixedPlanIds,
      draggedPlanIds: draggedPlanIds,
    );
    if (cascaded == null) {
      String? blockedId;
      for (final id in fixedPlanIds) {
        if (!draggedPlanIds.contains(id)) {
          blockedId = id;
          break;
        }
      }
      return TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'fixedBarrier',
        blockedByFixedPlanId: blockedId,
      );
    }
    if (scheduledPlansHaveWallOverlap(
      cascaded.where((t) => t.startTime != null).toList(),
      resolveDurationMinutes: resolveDurationMinutes,
    )) {
      logTimeDropGuard('TIME_VIEW_INSERTION_NO_OVERLAP_VERIFIED failed');
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'overlap',
      );
    }
    if (!_bulkRelativeOffsetsPreserved(
      tasks: cascaded,
      expectedOffsets: resolvedBulkOffsets,
      primaryDraggedPlanId: primaryDraggedPlanId,
    )) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'bulkRelativeOffsetsChanged',
      );
    }
    final patches = diffSequentialCascadePatches(scheduledTasks, cascaded);
    final shifted = patches.map((p) => p.task.planRowIdForBackend).toSet();
    if (shifted.isNotEmpty && kDebugMode) {
      debugPrint('[TIME_VIEW_INSERTION_SHIFTED_CHAIN] count=${shifted.length}');
    }
    final dragged = cascaded.firstWhere(
      (t) => t.planRowIdForBackend == primaryId,
    );
    if (draggedPlanIds.length > 1 && kDebugMode) {
      debugPrint(
        '[TIME_VIEW_BULK_DRAG_PATCHES_COMPUTED] targetCard patches=${patches.length}',
      );
    }
    return TimeViewInsertionCascadeResult(
      accepted: true,
      patches: patches,
      previewRows: cascaded,
      shiftedPlanIds: shifted,
      draggedStartWall: dragged.startTime,
      draggedEndWall: dragged.endDateTime,
    );
  }

  if (emptyCanvasStartWall != null && draggedPlanIds.isNotEmpty) {
    final primaryId = primaryDraggedPlanId;
    final durById = <String, int>{};
    for (final id in draggedPlanIds) {
      PlanningTask? match;
      for (final t in working) {
        if (t.planRowIdForBackend == id) {
          match = t;
          break;
        }
      }
      if (match == null) continue;
      durById[id] =
          emptyCanvasDurationMin ??
          planWallDurationMinutesForCascade(
            match,
            resolveDurationMinutes: resolveDurationMinutes,
          );
    }

    working = working
        .map((t) {
          final id = t.planRowIdForBackend;
          if (!draggedPlanIds.contains(id)) return t;
          final offset = resolvedBulkOffsets[id]!;
          final start = emptyCanvasStartWall.add(Duration(minutes: offset));
          final dur =
              durById[id] ??
              planWallDurationMinutesForCascade(
                t,
                resolveDurationMinutes: resolveDurationMinutes,
              );
          final end = emptyCanvasHadEnd || t.endDateTime != null
              ? start.add(Duration(minutes: dur))
              : null;
          return t.copyWith(
            startTime: start,
            endDateTime: end,
            clearEnd: end == null,
          );
        })
        .toList(growable: false);

    final sorted = working.where((t) => t.startTime != null).toList()
      ..sort(_planCascadeSortCompare);
    final cascaded = cascadeScheduledPlansForTimeViewDayWithBarriers(
      sorted,
      resolveDurationMinutes: resolveDurationMinutes,
      fixedPlanIds: fixedPlanIds,
      draggedPlanIds: draggedPlanIds,
    );
    if (cascaded == null) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'fixedBarrier',
      );
    }
    final merged = _mergeCascadeIntoFullList(working, cascaded);
    if (!_bulkRelativeOffsetsPreserved(
      tasks: merged,
      expectedOffsets: resolvedBulkOffsets,
      primaryDraggedPlanId: primaryDraggedPlanId,
    )) {
      return const TimeViewInsertionCascadeResult(
        accepted: false,
        blockedReason: 'bulkRelativeOffsetsChanged',
      );
    }
    final patches = diffSequentialCascadePatches(scheduledTasks, merged);
    final shifted = patches.map((p) => p.task.planRowIdForBackend).toSet();
    PlanningTask? primary;
    for (final t in merged) {
      if (t.planRowIdForBackend == primaryId) {
        primary = t;
        break;
      }
    }
    return TimeViewInsertionCascadeResult(
      accepted: true,
      patches: patches,
      previewRows: merged,
      shiftedPlanIds: shifted,
      draggedStartWall: primary?.startTime,
      draggedEndWall: primary?.endDateTime,
    );
  }

  return const TimeViewInsertionCascadeResult(
    accepted: false,
    blockedReason: 'missingIntent',
  );
}

List<PlanningTask> _mergeCascadeIntoFullList(
  List<PlanningTask> original,
  List<PlanningTask> cascadedScheduled,
) {
  final byId = {for (final t in cascadedScheduled) t.planRowIdForBackend: t};
  return original
      .map((t) => byId[t.planRowIdForBackend] ?? t)
      .toList(growable: false);
}

/// Start-time sort cascade with fixed barriers (flexible cards shift; fixed block).
List<PlanningTask>? cascadeScheduledPlansForTimeViewDayWithBarriers(
  List<PlanningTask> tasks, {
  required int Function(List<Tag> tags) resolveDurationMinutes,
  Set<String> fixedPlanIds = const {},
  Set<String> draggedPlanIds = const {},
}) {
  if (tasks.isEmpty) return const [];

  final scheduled = tasks.where((t) => t.startTime != null).toList()
    ..sort(_planCascadeSortCompare);

  if (scheduled.isEmpty) return List<PlanningTask>.from(tasks);

  final cascadedById = <String, PlanningTask>{};
  DateTime? prevEnd;

  for (final task in scheduled) {
    final id = task.planRowIdForBackend;
    final origStart = task.startTime!;
    final durMin = planWallDurationMinutesForCascade(
      task,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    var newStart = origStart;
    if (prevEnd != null && newStart.isBefore(prevEnd)) {
      if (fixedPlanIds.contains(id) && !draggedPlanIds.contains(id)) {
        logTimeDropGuard('TIME_VIEW_INSERTION_BLOCKED_BY_FIXED_TIME plan=$id');
        return null;
      }
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
    cascadedById[id] = task.copyWith(
      startTime: newStart,
      endDateTime: newEnd,
      clearEnd: false,
    );
    prevEnd = newEnd;
  }

  return tasks
      .map((t) => cascadedById[t.planRowIdForBackend] ?? t)
      .toList(growable: false);
}
