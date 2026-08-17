from pathlib import Path

p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')

# Do not bind a generic Finance category to the dedicated ZenMoney project.
s = s.replace("      'Финансы',\n", "")
s = s.replace("    'Финансы',\n", "")

# Atozed used to intentionally plan its second stage (growth, not daily ops).
# The approval stage is now prepended, so the original second stage moved to 2.
s = s.replace("    planningStageIndex: 1,\n", "    planningStageIndex: 2,\n", 1)

# Approval always wins over any project-specific stage index.
old = """  var targetStage = profile.planningStageIndex;
  if (targetStage == null) {
"""
new = """  var targetStage = _projectPlanApprovedV5(root)
      ? profile.planningStageIndex
      : 0;
  if (targetStage == null) {
"""
if old in s:
    s = s.replace(old, new, 1)
elif "? profile.planningStageIndex\n      : 0;" not in s:
    raise SystemExit('target stage anchor missing')

# Category creation must be observable immediately, otherwise first open could
# create the category but fail to create its Path until a second refresh.
old = """  if (created == null) return null;
  return db.getCategoryRuleById(created);
}
"""
new = """  if (created == null) return null;
  await db.refreshCategoryRulesFromServer();
  return _findCategoryByAliasesV4(const [
    'Управление деньгами / ZenMoney',
    'Управление деньгами',
    'ZenMoney',
    'Zen Money',
  ]);
}
"""
if old in s:
    s = s.replace(old, new, 1)

# Find a real free wall-clock slot around existing recurring and manual plans.
anchor = "Future<bool> _createScheduledTaskV4({\n"
helper = r'''DateTime? _firstFreeProjectSlotV5(
  DatabaseService db, {
  required DateTime earliest,
  required int minutes,
  required DateTime latestEnd,
  required List<PlanningTask> existing,
}) {
  var candidate = _roundUp5V4(earliest);
  final busy = <(DateTime, DateTime)>[];
  for (final task in existing) {
    final rawStart = task.startTime;
    if (rawStart == null) continue;
    final start = db.applyUserOffset(rawStart.toUtc());
    if (start.year != candidate.year ||
        start.month != candidate.month ||
        start.day != candidate.day) {
      continue;
    }
    final rawEnd = task.endDateTime;
    final end = rawEnd == null
        ? start.add(const Duration(minutes: 30))
        : db.applyUserOffset(rawEnd.toUtc());
    if (!end.isAfter(start)) continue;
    busy.add((start, end));
  }
  busy.sort((a, b) => a.$1.compareTo(b.$1));

  for (final interval in busy) {
    if (!interval.$2.isAfter(candidate)) continue;
    final requestedEnd = candidate.add(Duration(minutes: minutes));
    if (!requestedEnd.isAfter(interval.$1)) {
      return requestedEnd.isAfter(latestEnd) ? null : candidate;
    }
    candidate = _roundUp5V4(interval.$2);
    if (candidate.add(Duration(minutes: minutes)).isAfter(latestEnd)) {
      return null;
    }
  }
  return candidate.add(Duration(minutes: minutes)).isAfter(latestEnd)
      ? null
      : candidate;
}

'''
if '_firstFreeProjectSlotV5(' not in s:
    if anchor not in s: raise SystemExit('free-slot helper anchor missing')
    s = s.replace(anchor, helper + anchor, 1)

# Place project tasks around all existing Planner items, including recurrence.
old = """      final cursor = dayCursor[dk] ?? DateTime(day.year, day.month, day.day, 9);
      final end = cursor.add(Duration(minutes: candidate.minutes));
      if (end.isAfter(DateTime(day.year, day.month, day.day, 15, 30))) continue;
      final ok = await _createScheduledTaskV4(
        category: candidate.category,
        title: '${candidate.profile.name}: ${candidate.text}',
        notes: '$marker\\nОжидаемый результат: ${candidate.result}',
        start: cursor,
        minutes: candidate.minutes,
      );
      if (ok) {
        created++;
        existingMarkers.add(marker);
        dayCursor[dk] = end.add(const Duration(minutes: 5));
"""
new = """      final earliest = dayCursor[dk] ?? DateTime(day.year, day.month, day.day, 9);
      final existingDay = await db.getPlanningTasksForWallDate(
        DateTime(day.year, day.month, day.day),
      );
      final cursor = _firstFreeProjectSlotV5(
        db,
        earliest: earliest,
        minutes: candidate.minutes,
        latestEnd: DateTime(day.year, day.month, day.day, 15, 30),
        existing: existingDay,
      );
      if (cursor == null) continue;
      final end = cursor.add(Duration(minutes: candidate.minutes));
      final approvalTask = candidate.stageId.startsWith('approval-v5-');
      final ok = await _createScheduledTaskV4(
        category: candidate.category,
        title: approvalTask
            ? '${candidate.profile.name}: согласовать план проекта'
            : '${candidate.profile.name}: ${candidate.text}',
        notes: '$marker\\nОжидаемый результат: ${candidate.result}',
        start: cursor,
        minutes: candidate.minutes,
      );
      if (ok) {
        created++;
        existingMarkers.add(marker);
        dayCursor[dk] = end.add(const Duration(minutes: 5));
"""
if old in s:
    s = s.replace(old, new, 1)
elif "final approvalTask = candidate.stageId.startsWith('approval-v5-');" not in s:
    raise SystemExit('placement anchor missing')

p.write_text(s, encoding='utf-8')
