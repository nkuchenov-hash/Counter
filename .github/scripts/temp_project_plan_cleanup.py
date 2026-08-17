from pathlib import Path

p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')

# PlanningTask.startTime/endDateTime from getPlanningTasksForWallDate are already
# profile wall-clock projections. Applying the profile offset again would shift
# collision checks by the timezone offset.
s = s.replace(
    "    final start = db.applyUserOffset(rawStart.toUtc());\n",
    "    final start = rawStart;\n",
)
s = s.replace(
    "        : db.applyUserOffset(rawEnd.toUtc());\n",
    "        : rawEnd;\n",
)

# Remove only the routine rows created by the superseded PR #88 week scheduler.
# User-authored recurrence and manual plans have no LIFEOS_WEEK_ROUTINE_V4 marker.
anchor = "Future<PathWeekPlanReportV4> planCurrentWeekFromPathsV4() async {\n"
helper = r'''Future<void> _removeSupersededWeekRoutinesV5() async {
  final db = DatabaseService.instance;
  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final ids = <String>{};
  for (var i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final tasks = await db.getPlanningTasksForWallDate(day);
    for (final task in tasks) {
      final notes = (task.notesPlain ?? '').trim();
      if (!notes.startsWith(_weekRoutinePlanMarkerV4)) continue;
      final id = task.planRowIdForBackend.trim();
      if (id.isEmpty || id.startsWith('virt-') || id.startsWith('optimistic-')) {
        continue;
      }
      ids.add(id);
    }
  }
  if (ids.isNotEmpty) {
    await db.deletePlanningTasksBulk(ids);
  }
}

'''
if '_removeSupersededWeekRoutinesV5()' not in s:
    if anchor not in s: raise SystemExit('week-plan function anchor missing')
    s = s.replace(anchor, helper + anchor, 1)

old = """  final db = DatabaseService.instance;
  await upgradeRealityPathsV4();

  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
"""
new = """  final db = DatabaseService.instance;
  await upgradeRealityPathsV4();
  await _removeSupersededWeekRoutinesV5();

  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
"""
if old in s:
    s = s.replace(old, new, 1)
elif 'await _removeSupersededWeekRoutinesV5();' not in s:
    raise SystemExit('cleanup invocation anchor missing')

p.write_text(s, encoding='utf-8')
