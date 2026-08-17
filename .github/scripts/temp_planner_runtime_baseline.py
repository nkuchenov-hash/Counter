from pathlib import Path
import re

# 1) Make daily routine creation atomic and able to repair bad bootstrap rows.
p = Path('lib/app/shell/shared/shell_daily_routine.dart')
s = p.read_text(encoding='utf-8')

start = s.index('Future<bool> _scheduleRoutineSeriesV6({')
end = s.index('/// Creates the six baseline personal-routine series once.', start)
new_schedule = r'''String _routineBackendIdV7(Map<String, dynamic> row) =>
    (row['id'] ?? row['_pb_record_id'] ?? '').toString().trim();

String _routineBusinessIdV7(Map<String, dynamic> row) =>
    (row['plan_id'] ?? '').toString().trim();

bool _routineRowHasScheduleV7(Map<String, dynamic> row) {
  final rrule = (row['rrule'] ?? '').toString().trim();
  final start = (row['start_time'] ?? row['startTime'])?.toString().trim() ?? '';
  return rrule.isNotEmpty && start.isNotEmpty;
}

Future<bool> _scheduleRoutineSeriesV6({
  required CategoryRule category,
  required _DailyRoutineSpecV6 spec,
  String? existingBackendId,
  String? existingBusinessId,
}) async {
  final db = DatabaseService.instance;
  final start = _routineBaseStartV6(db, spec);
  final end = start.add(Duration(minutes: spec.durationMinutes));
  final dateKey = _routineDateKeyV6(start);
  final marker = '$_dailyRoutineMarkerV6${spec.key}';

  final backendId = existingBackendId?.trim() ?? '';
  var businessId = existingBusinessId?.trim() ?? '';
  if (backendId.isEmpty) {
    businessId = DatabaseService.newClientUuid();
    final wallDay = DateTime(start.year, start.month, start.day);
    return db.addPlanningTask(
      PlanningTask(
        id: 0,
        title: spec.title,
        categoryId: category.id,
        isDone: false,
        dateKey: dateKey,
        order: await db.nextPlanningOrderForDate(wallDay),
        startTime: start,
        endDateTime: end,
        initialDateKey: dateKey,
        notesPlain:
            '$marker\nСистемная ежедневная опора LIFE OS. Время можно менять обычным редактированием повторяющейся серии.',
        rrule: 'FREQ=DAILY',
        isSynced: false,
      ),
      clientPlanId: businessId,
    );
  }

  return db.updatePlanningTask(
    backendId,
    planBusinessId: businessId.isEmpty ? null : businessId,
    title: spec.title,
    categoryId: category.id,
    startTimeDisplay: start,
    endDateTimeDisplay: end,
    planInitialDateKey: dateKey,
    patchPlanAlarmRecurrence: true,
    planRrule: 'FREQ=DAILY',
    planExceptionDates: const <String>[],
    suppressAppSnack: true,
  );
}

'''
s = s[:start] + new_schedule + s[end:]

start = s.index('Future<void> ensureDailyRoutineV6() async {')
# Function is at EOF; replace to EOF.
new_ensure = r'''Future<void> ensureDailyRoutineV6() async {
  final db = DatabaseService.instance;
  final category = await _ensureDailyRoutineCategoryV6();
  if (category == null) return;

  final rawPlans = await db.fetchPlans();
  final markerRows = <String, List<Map<String, dynamic>>>{};
  final recurringTitles = <String>{};
  for (final row in rawPlans) {
    final title = (row['title'] ?? '').toString().trim();
    final rrule = (row['rrule'] ?? '').toString().trim();
    if (rrule.isNotEmpty && title.isNotEmpty) {
      recurringTitles.add(_normalizeRoutineTitleV6(title));
    }
    final notes = (row['notes_plain'] ?? row['notesPlain'] ?? '').toString();
    final firstLine = notes.split('\n').first.trim();
    if (!firstLine.startsWith(_dailyRoutineMarkerV6)) continue;
    final key = firstLine.substring(_dailyRoutineMarkerV6.length).trim();
    if (key.isEmpty) continue;
    markerRows.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
  }

  for (final spec in _dailyRoutineSpecsV6) {
    final rows = markerRows[spec.key] ?? const <Map<String, dynamic>>[];
    final scheduled = rows.where(_routineRowHasScheduleV7).toList();

    if (scheduled.isNotEmpty) {
      final keepId = _routineBackendIdV7(scheduled.first);
      final duplicateIds = <String>{
        for (final row in rows)
          if (_routineBackendIdV7(row).isNotEmpty &&
              _routineBackendIdV7(row) != keepId)
            _routineBackendIdV7(row),
      };
      if (duplicateIds.isNotEmpty) {
        await db.deletePlanningTasksBulk(duplicateIds);
      }
      continue;
    }

    if (rows.isNotEmpty) {
      Map<String, dynamic>? repairRow;
      for (final row in rows) {
        if (_routineBackendIdV7(row).isNotEmpty) {
          repairRow = row;
          break;
        }
      }
      var repaired = false;
      if (repairRow != null) {
        repaired = await _scheduleRoutineSeriesV6(
          category: category,
          spec: spec,
          existingBackendId: _routineBackendIdV7(repairRow),
          existingBusinessId: _routineBusinessIdV7(repairRow),
        );
      }
      if (repaired) {
        final keepId = _routineBackendIdV7(repairRow!);
        final duplicateIds = <String>{
          for (final row in rows)
            if (_routineBackendIdV7(row).isNotEmpty &&
                _routineBackendIdV7(row) != keepId)
              _routineBackendIdV7(row),
        };
        if (duplicateIds.isNotEmpty) {
          await db.deletePlanningTasksBulk(duplicateIds);
        }
        continue;
      }

      final staleIds = <String>{
        for (final row in rows)
          if (_routineBackendIdV7(row).isNotEmpty) _routineBackendIdV7(row),
      };
      if (staleIds.isNotEmpty) {
        await db.deletePlanningTasksBulk(staleIds);
      }
      await _scheduleRoutineSeriesV6(category: category, spec: spec);
      continue;
    }

    // A user's own recurring plan with the same title has priority over the
    // LIFE OS baseline; do not create a second series beside it.
    if (recurringTitles.contains(_normalizeRoutineTitleV6(spec.title))) {
      continue;
    }
    await _scheduleRoutineSeriesV6(category: category, spec: spec);
  }
}
'''
s = s[:start] + new_ensure
p.write_text(s, encoding='utf-8')

# 2) Make approval duplicate recognition backward-compatible and expose a
# startup-only repair that does not create any new project work.
p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')
old = r'''bool _isApprovalPlannerTaskV6(PlanningTask task) {
  final firstLine = (task.notesPlain ?? '').split('\n').first.trim();
  if (!firstLine.startsWith(_pathActionPlanMarkerV4)) return false;
  final payload = firstLine.substring(_pathActionPlanMarkerV4.length);
  final parts = payload.split('|');
  if (parts.length < 3) return false;
  return parts[1].trim() == _projectPlanApprovalStageIdV5 &&
      parts[2].trim() == _projectPlanApprovalActionIdV5;
}
'''
new = r'''String _normalizeApprovalTitleV7(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

bool _isApprovalPlannerTaskV6(PlanningTask task) {
  final firstLine = (task.notesPlain ?? '').split('\n').first.trim();
  if (!firstLine.startsWith(_pathActionPlanMarkerV4)) return false;
  final payload = firstLine.substring(_pathActionPlanMarkerV4.length);
  final parts = payload.split('|');
  if (parts.length >= 3 &&
      parts[1].trim() == _projectPlanApprovalStageIdV5 &&
      parts[2].trim() == _projectPlanApprovalActionIdV5) {
    return true;
  }

  // PR #89 generated this user-visible title. Keep the LIFEOS marker as a
  // safety boundary, but accept older marker-id variants so already-created
  // duplicates are actually removable after an upgrade.
  final normalizedTitle = _normalizeApprovalTitleV7(task.title);
  return normalizedTitle.endsWith('согласоватьпланпроекта') ||
      normalizedTitle.endsWith('approveprojectplan');
}
'''
if old not in s:
    raise SystemExit('approval detector anchor not found')
s = s.replace(old, new, 1)

anchor = '\n\nFuture<PathWeekPlanReportV4> planCurrentWeekFromPathsV4() async {\n'
repair = r'''

/// Repairs persistent Planner infrastructure on ordinary app startup.
/// This deliberately does NOT schedule project Path actions.
Future<void> repairPlannerBaselineV7() async {
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  await ensureDailyRoutineV6();
  await _removeSupersededWeekRoutinesV5();
  await _dedupeCurrentWeekApprovalPlansV6();
}
'''
if 'Future<void> repairPlannerBaselineV7()' not in s:
    if anchor not in s:
        raise SystemExit('planner repair insertion anchor not found')
    s = s.replace(anchor, repair + anchor, 1)
p.write_text(s, encoding='utf-8')

# 3) Run the narrow repair automatically after the shell has loaded, not only
# when the user happens to open Project Paths.
p = Path('lib/app/shell/app_shell.dart')
s = p.read_text(encoding='utf-8')
old = '''      unawaited(loadTasksAndExtras());
      StartupLog.deferred(
        name: 'syncBootstrap',
'''
new = '''      unawaited(() async {
        try {
          await loadTasksAndExtras();
        } finally {
          try {
            await repairPlannerBaselineV7();
          } catch (e) {
            debugPrint('[PLANNER_BASELINE_V7] repair failed: $e');
          }
        }
      }());
      StartupLog.deferred(
        name: 'syncBootstrap',
'''
if old not in s:
    raise SystemExit('app shell load anchor not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# 4) Strengthen the regression contract around the actual runtime failure.
p = Path('test/daily_routine_contract_test.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    "    expect(source, contains(\"planRrule: 'FREQ=DAILY'\"));\n    expect(source, contains('recurringTitles.contains'));\n",
    "    expect(source, contains(\"planRrule: 'FREQ=DAILY'\"));\n"
    "    expect(source, contains('dateKey: dateKey'));\n"
    "    expect(source, contains('startTime: start'));\n"
    "    expect(source, contains('endDateTime: end'));\n"
    "    expect(source, contains('initialDateKey: dateKey'));\n"
    "    expect(source, isNot(contains('backendId = businessId')));\n"
    "    expect(source, contains('recurringTitles.contains'));\n",
    1,
)
old_tail = '''    expect(source, contains('existingApprovalCategoryIds'));
  });
}
'''
new_tail = '''    expect(source, contains('existingApprovalCategoryIds'));
    expect(source, contains('repairPlannerBaselineV7'));
    expect(source, contains("endsWith('согласоватьпланпроекта')"));
  });

  test('ordinary shell startup runs the planner baseline repair', () {
    final source = File('lib/app/shell/app_shell.dart').readAsStringSync();
    expect(source, contains('await repairPlannerBaselineV7();'));
  });
}
'''
if old_tail not in s:
    raise SystemExit('test tail anchor not found')
s = s.replace(old_tail, new_tail, 1)
p.write_text(s, encoding='utf-8')
