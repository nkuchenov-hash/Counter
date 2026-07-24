from __future__ import annotations

from pathlib import Path

CASCADE = Path("lib/data/plan_time_sequential_cascade.dart")
RESIZE = Path("lib/features/planning/time_view/time_view_resize_controller.dart")
CARD = Path("lib/features/planning/time_view/time_view_card_layer.dart")
TEST = Path("test/time_view_bulk_resize_rules_test.dart")


def replace_once(source: str, old: str, new: str, name: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{name}: expected one match, found {count}")
    return source.replace(old, new, 1)


cascade = CASCADE.read_text(encoding="utf-8")

resize_anchor = """  return tasks
      .map(
        (t) => cascadedById[t.planRowIdForBackend] ?? t,
      )
      .toList(growable: false);
}

/// Patches where cascade changed wall start/end.
"""
resize_helper = """  return tasks
      .map(
        (t) => cascadedById[t.planRowIdForBackend] ?? t,
      )
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
  final scheduled = scheduledTasks
      .where((task) => task.startTime != null)
      .map(
        (task) => task.planRowIdForBackend == resizedId ? resizedTask : task,
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
  var cursorEnd = resizedTask.endDateTime ??
      resizedStart.add(Duration(minutes: resizedDuration));

  for (var index = resizedIndex + 1; index < scheduled.length; index += 1) {
    final task = scheduled[index];
    final originalStart = task.startTime!;
    final duration = planWallDurationMinutesForCascade(
      task,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    final hadExplicitEnd = task.endDateTime != null;
    final shiftedStart = originalStart.isBefore(cursorEnd)
        ? cursorEnd
        : originalStart;
    final effectiveEnd = shiftedStart.add(Duration(minutes: duration));

    if (shiftedStart != originalStart) {
      changedById[task.planRowIdForBackend] = task.copyWith(
        startTime: shiftedStart,
        endDateTime: hadExplicitEnd ? effectiveEnd : null,
        clearEnd: !hadExplicitEnd,
      );
    }
    cursorEnd = effectiveEnd;
  }

  return scheduledTasks
      .map((task) => changedById[task.planRowIdForBackend] ?? task)
      .toList(growable: false);
}

/// Patches where cascade changed wall start/end.
"""
if "cascadeScheduledPlansAfterManualResize" not in cascade:
    cascade = replace_once(
        cascade,
        resize_anchor,
        resize_helper,
        "manual resize cascade helper",
    )

bulk_anchor = """/// Pure scheduling for Time View drag insert / bulk move with fixed barriers.
"""
bulk_helpers = """Map<String, int>? _resolveOriginalBulkRelativeOffsets({
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
"""
if "_resolveOriginalBulkRelativeOffsets" not in cascade:
    cascade = replace_once(cascade, bulk_anchor, bulk_helpers, "bulk offset helpers")

working_anchor = """  List<PlanningTask> working = List<PlanningTask>.from(scheduledTasks);

  if (targetIntent != null) {
"""
working_replacement = """  List<PlanningTask> working = List<PlanningTask>.from(scheduledTasks);
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
"""
if "blockedReason: 'bulkScheduleMissing'" not in cascade:
    cascade = replace_once(
        cascade,
        working_anchor,
        working_replacement,
        "resolve bulk offsets from original schedule",
    )

old_offsets = """    final offsets = <String, int>{
      for (final id in draggedPlanIds)
        id: bulkRelativeOffsetMinutes?[id] ?? (id == primaryId ? 0 : 0),
    };
    if (!offsets.containsKey(primaryId)) {
      offsets[primaryId] = 0;
    }
"""
if old_offsets in cascade:
    cascade = replace_once(
        cascade,
        old_offsets,
        """    final offsets = resolvedBulkOffsets;
""",
        "remove same-time bulk fallback",
    )
elif "    final offsets = resolvedBulkOffsets;" not in cascade:
    raise RuntimeError("bulk target offsets block missing")

cascade = cascade.replace(
    "      final offset = offsets[id] ?? 0;",
    "      final offset = offsets[id]!;",
    1,
)
cascade = cascade.replace(
    "      final offset = bulkRelativeOffsetMinutes?[id] ?? 0;",
    "      final offset = resolvedBulkOffsets[id]!;",
    1,
)

first_patch = """    final patches = diffSequentialCascadePatches(scheduledTasks, cascaded);
"""
first_validation = """    if (!_bulkRelativeOffsetsPreserved(
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
"""
if "expectedOffsets: resolvedBulkOffsets" not in cascade:
    cascade = replace_once(
        cascade,
        first_patch,
        first_validation,
        "target bulk offset invariant",
    )

merged_patch = """    final patches = diffSequentialCascadePatches(scheduledTasks, merged);
"""
merged_validation = """    if (!_bulkRelativeOffsetsPreserved(
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
"""
if cascade.count("blockedReason: 'bulkRelativeOffsetsChanged'") == 1:
    cascade = replace_once(
        cascade,
        merged_patch,
        merged_validation,
        "empty-canvas bulk offset invariant",
    )
elif cascade.count("blockedReason: 'bulkRelativeOffsetsChanged'") != 2:
    raise RuntimeError("bulk offset invariant count mismatch")

CASCADE.write_text(cascade, encoding="utf-8", newline="\n")

resize = RESIZE.read_text(encoding="utf-8")
if "data/database_service.dart" not in resize:
    resize = replace_once(
        resize,
        """import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/models.dart';
""",
        """import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
""",
        "resize imports",
    )

old_signature = """  void commitTimelineResize({
    required DateTime planWallDay,
    required int rangeStart,
  }) {
"""
new_signature = """  void commitTimelineResize({
    required DateTime planWallDay,
    required int rangeStart,
    required List<PlanningTask> scheduledInRange,
  }) {
"""
if old_signature in resize:
    resize = replace_once(resize, old_signature, new_signature, "resize signature")
elif new_signature not in resize:
    raise RuntimeError("resize signature missing")

old_commit = """    host.notifySetState(clearTimelineInteractionState);
    persistTimelineScheduleChange(
      task: task,
      newStartWall: newStartWall,
      newEndWall: newEndWall,
    );
"""
new_commit = """    final resizedTask = task.copyWith(
      startTime: newStartWall,
      endDateTime: newEndWall,
      clearEnd: false,
    );
    final resolved = cascadeScheduledPlansAfterManualResize(
      scheduledTasks: scheduledInRange,
      resizedTask: resizedTask,
      resolveDurationMinutes:
          DatabaseService.instance.resolvePlanDurationMinutesFromTags,
    );
    host.notifySetState(clearTimelineInteractionState);
    persistTimeViewCascadePatches(
      resolved: resolved,
      scheduledBefore: scheduledInRange,
      commitSource: 'resizeCascade',
    );
"""
if old_commit in resize:
    resize = replace_once(resize, old_commit, new_commit, "resize cascade commit")
elif "commitSource: 'resizeCascade'" not in resize:
    raise RuntimeError("resize commit block missing")
RESIZE.write_text(resize, encoding="utf-8", newline="\n")

card = CARD.read_text(encoding="utf-8")
old_card_call = """                      ? () => commitTimelineResize(
                            planWallDay: planWallDay,
                            rangeStart: rangeStart,
                          )
"""
new_card_call = """                      ? () => commitTimelineResize(
                            planWallDay: planWallDay,
                            rangeStart: rangeStart,
                            scheduledInRange: scheduledInRange,
                          )
"""
if old_card_call in card:
    card = replace_once(card, old_card_call, new_card_call, "resize scheduled list")
elif "scheduledInRange: scheduledInRange" not in card:
    raise RuntimeError("card resize call missing")
CARD.write_text(card, encoding="utf-8", newline="\n")

TEST.write_text(
    """import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:flutter_test/flutter_test.dart';

const _dayKey = '2026-07-24';

int _duration(List<Tag> tags) => 30;

PlanningTask _task(
  String id,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute, {
  int order = 0,
}) {
  return PlanningTask(
    id: id.hashCode,
    title: id,
    categoryId: 1,
    isDone: false,
    dateKey: _dayKey,
    order: order,
    startTime: DateTime(2026, 7, 24, startHour, startMinute),
    endDateTime: DateTime(2026, 7, 24, endHour, endMinute),
    planRowId: id,
  );
}

PlanningTask _byId(List<PlanningTask> tasks, String id) =>
    tasks.firstWhere((task) => task.planRowIdForBackend == id);

void main() {
  test('bulk empty-canvas move preserves every original relative time', () {
    final tasks = [
      _task('a', 9, 0, 9, 30),
      _task('b', 10, 15, 10, 45, order: 1),
      _task('c', 11, 45, 12, 15, order: 2),
    ];

    final result = computeTimeViewInsertionCascade(
      scheduledTasks: tasks,
      draggedPlanIds: {'a', 'b', 'c'},
      primaryDraggedPlanId: 'a',
      fixedPlanIds: const {},
      resolveDurationMinutes: _duration,
      emptyCanvasStartWall: DateTime(2026, 7, 24, 14),
      emptyCanvasHadEnd: true,
      bulkRelativeOffsetMinutes: const {'a': 0},
    );

    expect(result.accepted, isTrue);
    expect(_byId(result.previewRows, 'a').startTime,
        DateTime(2026, 7, 24, 14));
    expect(_byId(result.previewRows, 'b').startTime,
        DateTime(2026, 7, 24, 15, 15));
    expect(_byId(result.previewRows, 'c').startTime,
        DateTime(2026, 7, 24, 16, 45));
  });

  test('bulk target insertion never normalizes selected cards to one time', () {
    final target = _task('target', 8, 0, 8, 30);
    final a = _task('a', 10, 0, 10, 30, order: 1);
    final b = _task('b', 11, 15, 11, 45, order: 2);
    final result = computeTimeViewInsertionCascade(
      scheduledTasks: [target, a, b],
      draggedPlanIds: {'a', 'b'},
      primaryDraggedPlanId: 'a',
      fixedPlanIds: const {},
      resolveDurationMinutes: _duration,
      targetIntent: TimeViewInsertionIntent(
        draggedPlanId: 'a',
        targetPlanId: 'target',
        insertPosition: TimeViewInsertPosition.after,
        targetStartWall: target.startTime!,
        targetEndWall: target.endDateTime!,
        draggedDurationMinutes: 30,
        draggedHadEnd: true,
      ),
      bulkRelativeOffsetMinutes: const {'a': 0, 'b': 0},
    );

    expect(result.accepted, isTrue);
    expect(_byId(result.previewRows, 'a').startTime,
        DateTime(2026, 7, 24, 8, 30));
    expect(_byId(result.previewRows, 'b').startTime,
        DateTime(2026, 7, 24, 9, 45));
  });

  test('manual resize pushes the full following overlap chain', () {
    final resized = _task('a', 9, 0, 11, 0);
    final before = [
      _task('a', 9, 0, 10, 0),
      _task('b', 10, 15, 10, 45, order: 1),
      _task('c', 10, 40, 11, 10, order: 2),
      _task('d', 13, 0, 13, 30, order: 3),
    ];

    final result = cascadeScheduledPlansAfterManualResize(
      scheduledTasks: before,
      resizedTask: resized,
      resolveDurationMinutes: _duration,
    );

    expect(_byId(result, 'a').endDateTime,
        DateTime(2026, 7, 24, 11));
    expect(_byId(result, 'b').startTime,
        DateTime(2026, 7, 24, 11));
    expect(_byId(result, 'b').endDateTime,
        DateTime(2026, 7, 24, 11, 30));
    expect(_byId(result, 'c').startTime,
        DateTime(2026, 7, 24, 11, 30));
    expect(_byId(result, 'c').endDateTime,
        DateTime(2026, 7, 24, 12));
    expect(_byId(result, 'd').startTime,
        DateTime(2026, 7, 24, 13));
  });
}
""",
    encoding="utf-8",
    newline="\n",
)

print("patched Time View bulk offsets and resize cascade")
