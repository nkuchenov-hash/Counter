from pathlib import Path

p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')

# Import persistent daily-routine bootstrap.
old = "import 'package:counter/data/models.dart';\n"
new = old + "\nimport 'shell_daily_routine.dart';\n"
if "import 'shell_daily_routine.dart';" not in s:
    if old not in s: raise SystemExit('import anchor missing')
    s = s.replace(old, new, 1)

# Use the actual persisted stage/action ids and make the constants useful.
s = s.replace(
    "const String _projectPlanApprovalStageIdV5 = 'project-plan-approval-v5';\n",
    "const String _projectPlanApprovalStageIdV5 = 'approval-v5-gate';\n",
)
s = s.replace(
    "const String _projectPlanApprovalActionIdV5 = 'project-plan-approval-v5-review';\n",
    "const String _projectPlanApprovalActionIdV5 = 'approval-v5-review';\n",
)
s = s.replace(
    "        'approval-v5-gate';\n",
    "        _projectPlanApprovalStageIdV5;\n",
    1,
)

# Canonicalize duplicate active roots per project/category. The latest Path is
# the only one that can drive Planner; older active rows remain preserved data.
anchor = "bool _projectPlanApprovedV5(PlanningTask root) =>\n    _hasProjectPlanApprovalGateV5(root) && root.checklist.first['isDone'] == true;\n\n"
helper = r'''List<PlanningTask> _canonicalActivePathRootsV6(
  Iterable<PlanningTask> roots,
) {
  final byCategory = <int, PlanningTask>{};
  for (final root in roots) {
    if ((root.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
    final current = byCategory[root.categoryId];
    if (current == null) {
      byCategory[root.categoryId] = root;
      continue;
    }
    final currentAt = current.updatedAt ?? current.createdAt;
    final candidateAt = root.updatedAt ?? root.createdAt;
    if (currentAt == null && candidateAt != null) {
      byCategory[root.categoryId] = root;
      continue;
    }
    if (currentAt != null &&
        candidateAt != null &&
        candidateAt.isAfter(currentAt)) {
      byCategory[root.categoryId] = root;
      continue;
    }
    if (currentAt == candidateAt &&
        root.planRowIdForBackend.compareTo(current.planRowIdForBackend) > 0) {
      byCategory[root.categoryId] = root;
    }
  }
  return byCategory.values.toList();
}

'''
if '_canonicalActivePathRootsV6(' not in s:
    if anchor not in s: raise SystemExit('canonical helper anchor missing')
    s = s.replace(anchor, anchor + helper, 1)

# Only the canonical active root gets an approval gate.
old = """Future<void> _ensureProjectPlanApprovalGatesV5() async {
  final db = DatabaseService.instance;
  final roots = await db.fetchBacklogPlans(includeCompleted: true);
  for (final root in roots) {
    if ((root.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
"""
new = """Future<void> _ensureProjectPlanApprovalGatesV5() async {
  final db = DatabaseService.instance;
  final roots = _canonicalActivePathRootsV6(
    await db.fetchBacklogPlans(includeCompleted: true),
  );
  for (final root in roots) {
"""
if old in s:
    s = s.replace(old, new, 1)
elif "final roots = _canonicalActivePathRootsV6(" not in s:
    raise SystemExit('approval gate root anchor missing')

# Seed ordinary-life recurrence before project scheduling.
old = """Future<void> upgradeRealityPathsV4() async {
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();

"""
new = """Future<void> upgradeRealityPathsV4() async {
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  await ensureDailyRoutineV6();

"""
if old in s:
    s = s.replace(old, new, 1)
elif 'await ensureDailyRoutineV6();' not in s:
    raise SystemExit('routine bootstrap anchor missing')

# Premature-action cleanup must also respect the canonical root only.
old = """  final roots = await db.fetchBacklogPlans(includeCompleted: true);
  final approvalByRootId = <String, bool>{};
  for (final root in roots) {
    if ((root.notesPlain ?? '').trim() != _activePathMarkerV4) continue;
"""
new = """  final roots = _canonicalActivePathRootsV6(
    await db.fetchBacklogPlans(includeCompleted: true),
  );
  final approvalByRootId = <String, bool>{};
  for (final root in roots) {
"""
if old in s:
    s = s.replace(old, new, 1)
elif 'final approvalByRootId = <String, bool>{};' not in s:
    raise SystemExit('premature cleanup root anchor missing')

# Add service-only approval-task de-duplication. Keep one unfinished approval
# per project/category, preserve completed history, never touch manual plans.
anchor = "\n\nFuture<PathWeekPlanReportV4> planCurrentWeekFromPathsV4() async {\n"
helper = r'''
bool _isApprovalPlannerTaskV6(PlanningTask task) {
  final firstLine = (task.notesPlain ?? '').split('\n').first.trim();
  if (!firstLine.startsWith(_pathActionPlanMarkerV4)) return false;
  final payload = firstLine.substring(_pathActionPlanMarkerV4.length);
  final parts = payload.split('|');
  if (parts.length < 3) return false;
  return parts[1].trim() == _projectPlanApprovalStageIdV5 &&
      parts[2].trim() == _projectPlanApprovalActionIdV5;
}

Future<Set<int>> _dedupeCurrentWeekApprovalPlansV6() async {
  final db = DatabaseService.instance;
  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final byCategory = <int, List<PlanningTask>>{};
  final categoriesWithApproval = <int>{};

  for (var i = 0; i < 7; i++) {
    final day = monday.add(Duration(days: i));
    final tasks = await db.getPlanningTasksForWallDate(day);
    for (final task in tasks) {
      if (!_isApprovalPlannerTaskV6(task)) continue;
      categoriesWithApproval.add(task.categoryId);
      byCategory.putIfAbsent(task.categoryId, () => <PlanningTask>[]).add(task);
    }
  }

  final deleteIds = <String>{};
  for (final tasks in byCategory.values) {
    final unfinished = tasks.where((task) => !task.isDone).toList()
      ..sort((a, b) {
        final at = a.startTime;
        final bt = b.startTime;
        if (at == null && bt == null) {
          return a.planRowIdForBackend.compareTo(b.planRowIdForBackend);
        }
        if (at == null) return 1;
        if (bt == null) return -1;
        final byTime = at.compareTo(bt);
        if (byTime != 0) return byTime;
        return a.planRowIdForBackend.compareTo(b.planRowIdForBackend);
      });
    if (unfinished.length <= 1) continue;
    for (final duplicate in unfinished.skip(1)) {
      final id = duplicate.planRowIdForBackend.trim();
      if (id.isEmpty || id.startsWith('virt-') || id.startsWith('optimistic-')) {
        continue;
      }
      deleteIds.add(id);
    }
  }
  if (deleteIds.isNotEmpty) {
    await db.deletePlanningTasksBulk(deleteIds);
  }
  return categoriesWithApproval;
}
'''
if '_dedupeCurrentWeekApprovalPlansV6()' not in s:
    if anchor not in s: raise SystemExit('dedupe insertion anchor missing')
    s = s.replace(anchor, '\n' + helper + anchor, 1)

# De-dupe first, then derive exactly one canonical Path root per category.
old = """  await upgradeRealityPathsV4();
  await _removeSupersededWeekRoutinesV5();
  await _removePrematurePathActionsV5();

  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
  final roots = <PlanningTask>[
    for (final task in backlog)
      if ((task.notesPlain ?? '').trim() == _activePathMarkerV4) task,
  ];
"""
new = """  await upgradeRealityPathsV4();
  await _removeSupersededWeekRoutinesV5();
  final existingApprovalCategoryIds =
      await _dedupeCurrentWeekApprovalPlansV6();
  await _removePrematurePathActionsV5();

  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
  final roots = _canonicalActivePathRootsV6(backlog);
"""
if old in s:
    s = s.replace(old, new, 1)
elif 'existingApprovalCategoryIds' not in s:
    raise SystemExit('planner canonical root anchor missing')

# Remove dead weekKey left from the old weekly-routine implementation.
s = s.replace("  final weekKey = _weekKeyV4(monday);\n", "")

# Approval budgets use the exact stage id.
s = s.replace(
    "(pools[profile]!.first.stageId.startsWith('approval-v5-')))\n",
    "(pools[profile]!.first.stageId == _projectPlanApprovalStageIdV5))\n",
)

# A retained old-root approval task blocks creating a new canonical-root copy.
old = """    final candidate = candidates[idx];
    indexes[profile] = idx + 1;
    if (candidate.minutes > budget) continue;
    final rootId = (candidate.root.pocketRecordId ?? candidate.root.planRowIdForBackend).trim();
"""
new = """    final candidate = candidates[idx];
    indexes[profile] = idx + 1;
    if (candidate.minutes > budget) continue;
    final isApprovalTask =
        candidate.stageId == _projectPlanApprovalStageIdV5 &&
        candidate.actionId == _projectPlanApprovalActionIdV5;
    if (isApprovalTask &&
        existingApprovalCategoryIds.contains(candidate.category.id)) {
      remainingBudget[profile] = budget - candidate.minutes;
      continue;
    }
    final rootId = (candidate.root.pocketRecordId ?? candidate.root.planRowIdForBackend).trim();
"""
if old in s:
    s = s.replace(old, new, 1)
elif 'existingApprovalCategoryIds.contains(candidate.category.id)' not in s:
    raise SystemExit('approval candidate dedupe anchor missing')

# Use exact approval flag for title and remember newly-created category gate.
old = """      final approvalTask = candidate.stageId.startsWith('approval-v5-');
      final ok = await _createScheduledTaskV4(
"""
new = """      final approvalTask = isApprovalTask;
      final ok = await _createScheduledTaskV4(
"""
if old in s:
    s = s.replace(old, new, 1)

old = """        created++;
        existingMarkers.add(marker);
        dayCursor[dk] = end.add(const Duration(minutes: 5));
"""
new = """        created++;
        existingMarkers.add(marker);
        if (approvalTask) {
          existingApprovalCategoryIds.add(candidate.category.id);
        }
        dayCursor[dk] = end.add(const Duration(minutes: 5));
"""
if old in s:
    s = s.replace(old, new, 1)
elif 'existingApprovalCategoryIds.add(candidate.category.id)' not in s:
    raise SystemExit('created approval dedupe anchor missing')

p.write_text(s, encoding='utf-8')
