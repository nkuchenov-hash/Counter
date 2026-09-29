from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"needle not found in {path}: {old[:140]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Keep the already-oversized planning page from growing: same semantics, compact closure.
page = Path("lib/features/planning/planning_page.dart")
text = page.read_text(encoding="utf-8")
old = """      ..._optimisticTasks.where((t) {
        if (t.dateKey == taskDateKey) return true;
        final start = t.startTime;
        if (start == null) return false;
        return _dateKeyFromDate(start) == taskDateKey;
      }),
"""
new = """      ..._optimisticTasks.where(
        (t) =>
            t.dateKey == taskDateKey ||
            (t.startTime != null &&
                _dateKeyFromDate(t.startTime!) == taskDateKey),
      ),
"""
count = text.count(old)
if count != 2:
    raise SystemExit(f"expected 2 planning optimistic filters, found {count}")
page.write_text(text.replace(old, new), encoding="utf-8")

# Move the post-cascade lookup out of the already-oversized plan_service.dart.
helper_path = "lib/data/plans/plan_time_cascade_helpers.dart"
helper_marker = """  int? sanitizeTagDefaultPlanDurationMinutes(dynamic raw) {
"""
helper = """  PlanningTask cascadeCreatedPlan(
    DateTime wallDay,
    PlanningTask task,
    String planRowId,
  ) {
    applySequentialTimeViewCascadeIfNeeded(wallDay: wallDay);
    for (final candidate in planningDayTasksSnapshot(wallDay)) {
      if ((candidate.planRowId?.trim() ?? '') == planRowId) return candidate;
    }
    return task;
  }

"""
replace_once(helper_path, helper_marker, helper + helper_marker)

service_path = "lib/data/plan_service.dart"
replace_once(
    service_path,
    """    final optimisticId = 'optimistic-$clientPlanId';
    var taskForCreate = task;
""",
    """    final optimisticId = 'optimistic-$clientPlanId';
""",
)
replace_once(
    service_path,
    """          if (y != null && m != null && d != null) {
            final wallDay = DateTime(y, m, d);
            applySequentialTimeViewCascadeIfNeeded(wallDay: wallDay);
            for (final candidate in planningDayTasksSnapshot(wallDay)) {
              if ((candidate.planRowId?.trim() ?? '') == clientPlanId) {
                taskForCreate = candidate;
                break;
              }
            }
          }
""",
    """          if (y != null && m != null && d != null) {
            task = cascadeCreatedPlan(DateTime(y, m, d), task, clientPlanId);
          }
""",
)
replace_once(
    service_path,
    """      body = await _buildPocketPlanCreateBody(
        taskForCreate,
""",
    """      body = await _buildPocketPlanCreateBody(
        task,
""",
)

# Update regression source assertions for the extracted helper.
test_path = "test/auto_plan_nearest_free_slot_test.dart"
t = Path(test_path).read_text(encoding="utf-8")
old_test = """  test('create POST reads the post-cascade optimistic schedule', () {
    final source = File('lib/data/plan_service.dart').readAsStringSync();
    expect(source, contains('var taskForCreate = task;'));
    expect(source, contains('taskForCreate = candidate;'));
    expect(source, contains('_buildPocketPlanCreateBody(\\n        taskForCreate,'));
  });
"""
new_test = """  test('create POST reads the post-cascade optimistic schedule', () {
    final service = File('lib/data/plan_service.dart').readAsStringSync();
    final helper = File(
      'lib/data/plans/plan_time_cascade_helpers.dart',
    ).readAsStringSync();
    expect(service, contains('task = cascadeCreatedPlan('));
    expect(service, contains('_buildPocketPlanCreateBody(\\n        task,'));
    expect(helper, contains('PlanningTask cascadeCreatedPlan('));
    expect(helper, contains('planningDayTasksSnapshot(wallDay)'));
  });
"""
if old_test not in t:
    raise SystemExit("post-cascade source test not found")
Path(test_path).write_text(t.replace(old_test, new_test, 1), encoding="utf-8")
