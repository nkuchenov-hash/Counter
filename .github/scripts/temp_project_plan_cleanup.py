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

# Remove only rows created by the superseded PR #88 scheduler. User-authored
# recurrence/manual plans have neither of these LIFE OS service markers.
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

Future<void> _removePrematurePathActionsV5() async {
  final db = DatabaseService.instance;
  final roots = await db.fetchBacklogPlans(includeCompleted: true);
  final approvalByRootId = <String, bool>{};
  for (final root in roots) {
    if ((root.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
    final rootId = (root.pocketRecordId ?? root.planRowIdForBackend).trim();
    if (rootId.isEmpty) continue;
    approvalByRootId[rootId] = _projectPlanApprovedV5(root);
  }

  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final ids = <String>{};
  for (var i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final tasks = await db.getPlanningTasksForWallDate(day);
    for (final task in tasks) {
      if (task.isDone) continue;
      final firstLine = (task.notesPlain ?? '').split('\n').first.trim();
      if (!firstLine.startsWith(_pathActionPlanMarkerV4)) continue;
      final payload = firstLine.substring(_pathActionPlanMarkerV4.length);
      final parts = payload.split('|');
      if (parts.length < 3) continue;
      final rootId = parts[0].trim();
      final stageId = parts[1].trim();
      if (stageId.startsWith('approval-v5-')) continue;
      if (approvalByRootId[rootId] == true) continue;
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
elif '_removePrematurePathActionsV5()' not in s:
    insertion = s.find(anchor)
    if insertion == -1: raise SystemExit('week-plan function anchor missing')
    existing_start = s.rfind('Future<void> _removeSupersededWeekRoutinesV5()', 0, insertion)
    if existing_start == -1: raise SystemExit('existing cleanup helper missing')
    # Insert only the new helper after the existing cleanup helper block.
    marker = '\nFuture<PathWeekPlanReportV4> planCurrentWeekFromPathsV4() async {'
    new_helper = helper[helper.find('Future<void> _removePrematurePathActionsV5()'):]
    s = s.replace(marker, '\n' + new_helper + marker, 1)

old = """  final db = DatabaseService.instance;
  await upgradeRealityPathsV4();
  await _removeSupersededWeekRoutinesV5();

  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
"""
new = """  final db = DatabaseService.instance;
  await upgradeRealityPathsV4();
  await _removeSupersededWeekRoutinesV5();
  await _removePrematurePathActionsV5();

  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
"""
if old in s:
    s = s.replace(old, new, 1)
elif 'await _removePrematurePathActionsV5();' not in s:
    raise SystemExit('cleanup invocation anchor missing')

p.write_text(s, encoding='utf-8')
