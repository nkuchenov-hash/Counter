from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')

# 1) PlanningTask.copyWith must be able to invalidate stale UTC when wall time changes.
replace_once(
    'lib/data/models/planning.dart',
    """    DateTime? startUtcInstant,\n    DateTime? endUtcInstant,\n    bool clearEndUtc = false,\n""",
    """    DateTime? startUtcInstant,\n    DateTime? endUtcInstant,\n    bool clearStartUtc = false,\n    bool clearEndUtc = false,\n""",
)
replace_once(
    'lib/data/models/planning.dart',
    """      startUtcInstant: startUtcInstant ?? this.startUtcInstant,\n      endUtcInstant: clearEndUtc || clearEnd\n""",
    """      startUtcInstant:\n          clearStartUtc ? null : (startUtcInstant ?? this.startUtcInstant),\n      endUtcInstant: clearEndUtc || clearEnd\n""",
)

# 2) Collision resolution changes wall schedule: invalidate old UTC before optimistic projection.
replace_once(
    'lib/data/plans/plan_time_cascade_helpers.dart',
    """      task: task.copyWith(\n        dateKey: dayKey,\n        date: DateTime.utc(wallDay.year, wallDay.month, wallDay.day),\n        startTime: walls.startWall,\n        endDateTime: walls.endWall,\n        endDateKey: dayKey,\n        clearEnd: false,\n      ),\n""",
    """      task: task.copyWith(\n        dateKey: dayKey,\n        date: DateTime.utc(wallDay.year, wallDay.month, wallDay.day),\n        startTime: walls.startWall,\n        endDateTime: walls.endWall,\n        endDateKey: dayKey,\n        clearEnd: false,\n        clearStartUtc: true,\n        clearEndUtc: true,\n      ),\n""",
)

# 3) All Time View optimistic wall mutations must discard stale UTC first.
replace_once(
    'lib/features/planning/time_view/planning_time_view.dart',
    """    final updated = task.copyWith(\n      startTime: newStartWall,\n      endDateTime: newEndWall,\n      clearEnd: newEndWall == null,\n    );\n""",
    """    final updated = task.copyWith(\n      startTime: newStartWall,\n      endDateTime: newEndWall,\n      clearEnd: newEndWall == null,\n      clearStartUtc: true,\n      clearEndUtc: true,\n    );\n""",
)

p = Path('lib/features/planning/time_view/planning_time_view.dart')
text = p.read_text(encoding='utf-8')
old = """      DatabaseService.instance.applyOptimisticPlanningTask(task);\n      unawaited(\n        DatabaseService.instance.updatePlanningTask(\n          task.planRowIdForBackend,\n"""
replacement = """      final optimisticTask = task.copyWith(\n        clearStartUtc: true,\n        clearEndUtc: true,\n      );\n      DatabaseService.instance.applyOptimisticPlanningTask(optimisticTask);\n      unawaited(\n        DatabaseService.instance.updatePlanningTask(\n          task.planRowIdForBackend,\n"""
count = text.count(old)
if count < 1:
    raise SystemExit('optimistic cascade apply anchor not found')
text = text.replace(old, replacement)
p.write_text(text, encoding='utf-8')

# 4) Recurring drag optimistic row must use the dragged wall time, not inherited old UTC.
replace_once(
    'lib/features/planning/time_view/time_view_card_layer.dart',
    """    final updated = task.copyWith(\n      startTime: newStartWall,\n      endDateTime: newEndWall,\n      clearEnd: newEndWall == null,\n    );\n""",
    """    final updated = task.copyWith(\n      startTime: newStartWall,\n      endDateTime: newEndWall,\n      clearEnd: newEndWall == null,\n      clearStartUtc: true,\n      clearEndUtc: true,\n    );\n""",
)

# 5) Materialized recurrence single-occurrence edits must await the real PB patch.
p = Path('lib/data/plans/plan_recurrence_helpers.dart')
text = p.read_text(encoding='utf-8')
needle = """      );\n    }\n    return updatePlanningTask(\n      planRowId,\n"""
if needle not in text:
    raise SystemExit('recurrence default update anchor not found')
strict = """      );\n    }\n\n    final rid = planRowId.trim();\n    final cached = _findCachedPlanningTaskForEdit(\n      rid,\n      planBusinessId: planBusinessId,\n    );\n    if (cached != null && _isMaterializedRecurrenceException(cached)) {\n      final ok = await _patchMaterializedOccurrenceStrict(\n        cached,\n        title: title,\n        categoryId: categoryId,\n        isDone: isDone,\n        notesPlain: notesPlain,\n        notesDeltaJson: notesDeltaJson,\n        checklist: checklist,\n        parentPlanId: parentPlanId,\n        order: order,\n        startTime: startTime,\n        startTimeDisplay: startTimeDisplay,\n        endDateTime: endDateTime,\n        endDateTimeDisplay: endDateTimeDisplay,\n        clearEnd: clearEnd,\n        tags: tags,\n        planInitialDateKey: planInitialDateKey,\n        planIsPostponed: planIsPostponed,\n      );\n      if (ok) {\n        await _fetchAllPlanningTasksForCurrentUser();\n        notifyPlanningRefresh(scheduleNetworkRefresh: false);\n        _notifyTimelineAfterRecordCacheMutation();\n        if (!suppressAppSnack) AppSnack.updated();\n      } else if (!suppressAppSnack) {\n        AppSnack.failed();\n      }\n      return ok;\n    }\n\n    return updatePlanningTask(\n      planRowId,\n"""
text = text.replace(needle, strict, 1)
p.write_text(text, encoding='utf-8')

# 6) Regression tests for stale UTC overriding changed wall schedules.
test = Path('test/plan_wall_utc_mutation_test.dart')
test.write_text(r'''import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith can invalidate stale UTC when wall schedule changes', () {
    final task = PlanningTask(
      id: 0,
      planRowId: 'plan-1',
      title: 'Plan',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 10, 30),
      startUtcInstant: DateTime.utc(2026, 9, 29, 14),
      endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
    );

    final moved = task.copyWith(
      startTime: DateTime(2026, 9, 29, 12),
      endDateTime: DateTime(2026, 9, 29, 12, 30),
      clearStartUtc: true,
      clearEndUtc: true,
    );

    expect(moved.startTime, DateTime(2026, 9, 29, 12));
    expect(moved.startUtcInstant, isNull);
    expect(moved.endUtcInstant, isNull);
  });

  test('collision-resolved create does not retain pre-collision UTC instant', () {
    final incoming = PlanningTask(
      id: 0,
      planRowId: 'incoming',
      title: 'Incoming',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 10, 30),
      startUtcInstant: DateTime.utc(2026, 9, 29, 14),
      endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
    );
    final occupied = PlanningTask(
      id: 0,
      planRowId: 'occupied',
      title: 'Occupied',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 11),
    );

    final resolved = DatabaseService.instance.resolvePlanningCreateCollision(
      task: incoming,
      wallDay: DateTime(2026, 9, 29),
      existingDayPlans: [occupied],
    ).task;

    expect(resolved.startTime, DateTime(2026, 9, 29, 11));
    expect(resolved.startUtcInstant, isNull);
    expect(resolved.endUtcInstant, isNull);
  });
}
''', encoding='utf-8')

p = Path('CHANGELOG.md')
text = p.read_text(encoding='utf-8')
entry = """- Planning Time View: fixed stale UTC instants overriding manual/recurring wall-time moves, so dragged recurring plans and collision-resolved creates no longer snap back to their old time.\n- Recurrence: single-occurrence edits of materialized recurring plans now await the PocketBase patch before optimistic state is released.\n"""
if entry not in text:
    lines = text.splitlines(keepends=True)
    lines.insert(1 if lines else 0, entry)
    p.write_text(''.join(lines), encoding='utf-8')
