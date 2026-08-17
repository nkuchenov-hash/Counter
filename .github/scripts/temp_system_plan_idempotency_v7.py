from pathlib import Path

# Daily routine: one logical recurring series -> one deterministic plan_id.
p = Path('lib/app/shell/shared/shell_daily_routine.dart')
s = p.read_text(encoding='utf-8')

if "Future<void>? _dailyRoutineEnsureInFlightV7;" not in s:
    s = s.replace(
        "const String _dailyRoutineMarkerV6 = 'LIFEOS_DAILY_ROUTINE_V1|';\n",
        "const String _dailyRoutineMarkerV6 = 'LIFEOS_DAILY_ROUTINE_V1|';\n"
        "Future<void>? _dailyRoutineEnsureInFlightV7;\n",
        1,
    )

start = s.index('Future<bool> _scheduleRoutineSeriesV6({')
end = s.index('/// Creates the six baseline personal-routine series once.', start)
new_schedule = r'''String _systemIdTokenV7(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'unknown' : normalized;
}

String _routineSeriesPlanIdV7(
  CategoryRule category,
  _DailyRoutineSpecV6 spec,
) {
  final scope = (category.backendRowId ?? category.categoryKey).trim();
  return 'lifeos-routine-v1-${_systemIdTokenV7(scope)}-${_systemIdTokenV7(spec.key)}';
}

String _routineBackendIdV7(Map<String, dynamic> row) =>
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
  final deterministicPlanId = _routineSeriesPlanIdV7(category, spec);

  final backendId = existingBackendId?.trim() ?? '';
  if (backendId.isEmpty) {
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
      // DATA_MAP: plans.plan_id is unique. This is the hard idempotency anchor,
      // so a second copy of the same LIFE OS series cannot be inserted.
      clientPlanId: deterministicPlanId,
    );
  }

  return db.updatePlanningTask(
    backendId,
    planBusinessId: deterministicPlanId,
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
new_ensure = r'''Future<void> ensureDailyRoutineV6() {
  final running = _dailyRoutineEnsureInFlightV7;
  if (running != null) return running;
  late final Future<void> work;
  work = _ensureDailyRoutineOnceV7().whenComplete(() {
    if (identical(_dailyRoutineEnsureInFlightV7, work)) {
      _dailyRoutineEnsureInFlightV7 = null;
    }
  });
  _dailyRoutineEnsureInFlightV7 = work;
  return work;
}

Future<void> _ensureDailyRoutineOnceV7() async {
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
    if (key.isNotEmpty) {
      markerRows.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
    }
  }

  for (final spec in _dailyRoutineSpecsV6) {
    final deterministicPlanId = _routineSeriesPlanIdV7(category, spec);
    final rows = List<Map<String, dynamic>>.from(
      markerRows[spec.key] ?? const <Map<String, dynamic>>[],
    );

    if (rows.isNotEmpty) {
      // Adopt exactly one legacy row into the deterministic identity. Prefer an
      // already-normalized row, then a valid scheduled row, then any row that
      // has a real PB id. This is migration of old bad data, not the steady-state
      // duplicate-prevention mechanism.
      rows.sort((a, b) {
        int rank(Map<String, dynamic> row) {
          if (_routineBusinessIdV7(row) == deterministicPlanId) return 0;
          if (_routineRowHasScheduleV7(row)) return 1;
          if (_routineBackendIdV7(row).isNotEmpty) return 2;
          return 3;
        }
        return rank(a).compareTo(rank(b));
      });
      final keep = rows.first;
      final keepBackendId = _routineBackendIdV7(keep);
      final duplicateIds = <String>{
        for (final row in rows.skip(1))
          if (_routineBackendIdV7(row).isNotEmpty) _routineBackendIdV7(row),
      };
      if (duplicateIds.isNotEmpty) {
        await db.deletePlanningTasksBulk(duplicateIds);
      }
      if (keepBackendId.isNotEmpty) {
        final alreadyReady = _routineRowHasScheduleV7(keep) &&
            _routineBusinessIdV7(keep) == deterministicPlanId;
        if (!alreadyReady) {
          await _scheduleRoutineSeriesV6(
            category: category,
            spec: spec,
            existingBackendId: keepBackendId,
            existingBusinessId: _routineBusinessIdV7(keep),
          );
        }
        continue;
      }
    }

    // A user's own recurring plan with the same title wins. LIFE OS does not
    // create a second baseline series next to it.
    if (recurringTitles.contains(_normalizeRoutineTitleV6(spec.title))) {
      continue;
    }
    await _scheduleRoutineSeriesV6(category: category, spec: spec);
  }
}
'''
s = s[:start] + new_ensure
p.write_text(s, encoding='utf-8')

# Path planner: deterministic plan_id per canonical Path action + read-only
# duplicate prevention in normal scheduling. Deletion is reserved for legacy migration.
p = Path('lib/app/shell/shared/shell_path_governance.dart')
s = p.read_text(encoding='utf-8')

# Add deterministic system id helpers near marker constants.
marker_anchor = "const String _weekRoutinePlanMarkerV4 = 'LIFEOS_WEEK_ROUTINE_V4|';\n"
helpers = r'''const String _plannerBaselineMigrationV7 = 'lifeos_planner_baseline_migration_v7';

String _pathSystemIdTokenV7(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'unknown' : normalized;
}

String _pathActionBusinessIdV7({
  required String rootId,
  required String stageId,
  required String actionId,
}) =>
    'lifeos-path-action-v1-${_pathSystemIdTokenV7(rootId)}-'
    '${_pathSystemIdTokenV7(stageId)}-${_pathSystemIdTokenV7(actionId)}';

'''
if '_pathActionBusinessIdV7' not in s:
    s = s.replace(marker_anchor, marker_anchor + helpers, 1)

# Replace approval detector with parser + backwards-compatible classification.
start = s.index('bool _isApprovalPlannerTaskV6(PlanningTask task) {')
end = s.index('Future<Set<int>> _dedupeCurrentWeekApprovalPlansV6()', start)
new_detector = r'''List<String>? _pathMarkerPartsV7(PlanningTask task) {
  final firstLine = (task.notesPlain ?? '').split('\n').first.trim();
  if (!firstLine.startsWith(_pathActionPlanMarkerV4)) return null;
  final parts = firstLine
      .substring(_pathActionPlanMarkerV4.length)
      .split('|')
      .map((e) => e.trim())
      .toList(growable: false);
  return parts.length >= 3 ? parts : null;
}

String _normalizeApprovalTitleV7(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

bool _isApprovalPlannerTaskV6(PlanningTask task) {
  final parts = _pathMarkerPartsV7(task);
  if (parts == null) return false;
  if (parts[1] == _projectPlanApprovalStageIdV5 &&
      parts[2] == _projectPlanApprovalActionIdV5) {
    return true;
  }
  final normalizedTitle = _normalizeApprovalTitleV7(task.title);
  return normalizedTitle.endsWith('согласоватьпланпроекта') ||
      normalizedTitle.endsWith('approveprojectplan');
}

Future<Set<int>> _currentWeekApprovalCategoryIdsV7() async {
  final db = DatabaseService.instance;
  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final categories = <int>{};
  for (var i = 0; i < 7; i++) {
    final tasks = await db.getPlanningTasksForWallDate(
      monday.add(Duration(days: i)),
    );
    for (final task in tasks) {
      if (!task.isDone && _isApprovalPlannerTaskV6(task)) {
        categories.add(task.categoryId);
      }
    }
  }
  return categories;
}

'''
s = s[:start] + new_detector + s[end:]

# Rename old delete-based function as explicit legacy migration and make it
# prefer the canonical root, then normalize the kept row's unique plan_id.
start = s.index('Future<Set<int>> _dedupeCurrentWeekApprovalPlansV6()')
end = s.index('\n\nFuture<PathWeekPlanReportV4> planCurrentWeekFromPathsV4()', start)
legacy_block = s[start:end]
new_migration = r'''Future<void> _migrateLegacyApprovalDuplicatesV7() async {
  final db = DatabaseService.instance;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_plannerBaselineMigrationV7) == true) return;

  final roots = _canonicalActivePathRootsV6(
    await db.fetchBacklogPlans(includeCompleted: true),
  );
  final canonicalRootByCategory = <int, String>{
    for (final root in roots)
      root.categoryId:
          (root.pocketRecordId ?? root.planRowIdForBackend).trim(),
  };

  final today = db.getTimelineDeviceLocalToday();
  final monday = _mondayOfV4(today);
  final byCategory = <int, List<PlanningTask>>{};
  for (var i = 0; i < 7; i++) {
    final tasks = await db.getPlanningTasksForWallDate(
      monday.add(Duration(days: i)),
    );
    for (final task in tasks) {
      if (task.isDone || !_isApprovalPlannerTaskV6(task)) continue;
      byCategory.putIfAbsent(task.categoryId, () => <PlanningTask>[]).add(task);
    }
  }

  for (final entry in byCategory.entries) {
    final tasks = entry.value;
    if (tasks.isEmpty) continue;
    final canonicalRootId = canonicalRootByCategory[entry.key] ?? '';
    tasks.sort((a, b) {
      int rank(PlanningTask task) {
        final parts = _pathMarkerPartsV7(task);
        if (parts != null && parts[0] == canonicalRootId) return 0;
        return 1;
      }
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final at = a.startTime;
      final bt = b.startTime;
      if (at != null && bt != null) {
        final byTime = at.compareTo(bt);
        if (byTime != 0) return byTime;
      }
      return a.planRowIdForBackend.compareTo(b.planRowIdForBackend);
    });

    final keep = tasks.first;
    final deleteIds = <String>{
      for (final duplicate in tasks.skip(1))
        if (duplicate.planRowIdForBackend.trim().isNotEmpty &&
            !duplicate.planRowIdForBackend.startsWith('virt-') &&
            !duplicate.planRowIdForBackend.startsWith('optimistic-'))
          duplicate.planRowIdForBackend.trim(),
    };
    if (deleteIds.isNotEmpty) {
      await db.deletePlanningTasksBulk(deleteIds);
    }

    final parts = _pathMarkerPartsV7(keep);
    if (parts != null && parts[0].isNotEmpty) {
      final deterministicPlanId = _pathActionBusinessIdV7(
        rootId: parts[0],
        stageId: parts[1],
        actionId: parts[2],
      );
      if ((keep.planRowId ?? '').trim() != deterministicPlanId) {
        await db.updatePlanningTask(
          keep.planRowIdForBackend,
          planBusinessId: deterministicPlanId,
          suppressAppSnack: true,
        );
      }
    }
  }

  await prefs.setBool(_plannerBaselineMigrationV7, true);
}

/// Startup baseline only: ensure recurring routine and migrate old broken
/// generated rows. It does not schedule new project work.
Future<void> ensurePlannerBaselineV7() async {
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  await ensureDailyRoutineV6();
  await _removeSupersededWeekRoutinesV5();
  await _migrateLegacyApprovalDuplicatesV7();
}
'''
s = s[:start] + new_migration + s[end:]

# _createScheduledTaskV4 gets an optional deterministic business id.
old_sig = '''Future<bool> _createScheduledTaskV4({
  required CategoryRule category,
  required String title,
  required String notes,
  required DateTime start,
  required int minutes,
}) async {'''
new_sig = '''Future<bool> _createScheduledTaskV4({
  required CategoryRule category,
  required String title,
  required String notes,
  required DateTime start,
  required int minutes,
  String? clientPlanId,
}) async {'''
if old_sig not in s:
    raise SystemExit('create scheduled signature anchor missing')
s = s.replace(old_sig, new_sig, 1)
s = s.replace('  return db.addPlanningTask(task);\n}\n', '  return db.addPlanningTask(task, clientPlanId: clientPlanId);\n}\n', 1)

# Normal planner path must never delete duplicates. It only reads whether a
# pending approval exists; legacy deletion happens in migration above.
s = s.replace(
    '  final existingApprovalCategoryIds =\n      await _dedupeCurrentWeekApprovalPlansV6();\n',
    '  final existingApprovalCategoryIds =\n      await _currentWeekApprovalCategoryIdsV7();\n',
    1,
)

# Track server-enforced unique business ids already present.
needle = '''  final existingMarkers = <String>{};
  final existingTitlesByDate = <String, Set<String>>{};
'''
replacement = '''  final existingMarkers = <String>{};
  final existingBusinessIds = <String>{};
  final existingTitlesByDate = <String, Set<String>>{};
'''
if needle not in s:
    raise SystemExit('existing marker anchor missing')
s = s.replace(needle, replacement, 1)
needle = '''  for (final row in allPlans) {
    final notes = (row['notes_plain'] ?? row['notesPlain'] ?? '').toString();
'''
replacement = '''  for (final row in allPlans) {
    final businessId = (row['plan_id'] ?? '').toString().trim();
    if (businessId.isNotEmpty) existingBusinessIds.add(businessId);
    final notes = (row['notes_plain'] ?? row['notesPlain'] ?? '').toString();
'''
s = s.replace(needle, replacement, 1)

# Before scheduling candidate, compute deterministic id and treat it as another
# idempotency guard. Then pass it into addPlanningTask.
needle = '''    final rootId = (candidate.root.pocketRecordId ?? candidate.root.planRowIdForBackend).trim();
    final marker = '$_pathActionPlanMarkerV4$rootId|${candidate.stageId}|${candidate.actionId}';
    if (existingMarkers.contains(marker)) {
'''
replacement = '''    final rootId = (candidate.root.pocketRecordId ?? candidate.root.planRowIdForBackend).trim();
    final marker = '$_pathActionPlanMarkerV4$rootId|${candidate.stageId}|${candidate.actionId}';
    final planBusinessId = _pathActionBusinessIdV7(
      rootId: rootId,
      stageId: candidate.stageId,
      actionId: candidate.actionId,
    );
    if (existingMarkers.contains(marker) ||
        existingBusinessIds.contains(planBusinessId)) {
'''
if needle not in s:
    raise SystemExit('candidate marker anchor missing')
s = s.replace(needle, replacement, 1)
needle = '''        start: cursor,
        minutes: candidate.minutes,
      );
'''
replacement = '''        start: cursor,
        minutes: candidate.minutes,
        clientPlanId: planBusinessId,
      );
'''
# Only the path-action scheduling call should get this; choose last relevant occurrence by
# replacing the first occurrence after "title: approvalTask".
pos = s.index('title: approvalTask')
pos2 = s.index(needle, pos)
s = s[:pos2] + s[pos2:].replace(needle, replacement, 1)
# Add business id to in-memory set after successful create.
needle = '''        created++;
        existingMarkers.add(marker);
        if (approvalTask) {
'''
replacement = '''        created++;
        existingMarkers.add(marker);
        existingBusinessIds.add(planBusinessId);
        if (approvalTask) {
'''
if needle not in s:
    raise SystemExit('success marker anchor missing')
s = s.replace(needle, replacement, 1)

# import SharedPreferences for one-time migration marker.
if "package:shared_preferences/shared_preferences.dart" not in s:
    s = s.replace(
        "import 'package:counter/data/models.dart';\n",
        "import 'package:counter/data/models.dart';\n"
        "import 'package:shared_preferences/shared_preferences.dart';\n",
        1,
    )
p.write_text(s, encoding='utf-8')

# Shell startup: baseline happens in ordinary app opening, after normal task load.
p = Path('lib/app/shell/app_shell.dart')
s = p.read_text(encoding='utf-8')
old = '''      unawaited(loadTasksAndExtras());
      StartupLog.deferred(
        name: 'syncBootstrap',
'''
new = '''      unawaited(() async {
        await loadTasksAndExtras();
        try {
          await ensurePlannerBaselineV7();
        } catch (e) {
          debugPrint('[PLANNER_BASELINE_V7] ensure failed: $e');
        }
      }());
      StartupLog.deferred(
        name: 'syncBootstrap',
'''
if old not in s:
    raise SystemExit('app startup anchor missing')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Regression contract.
p = Path('test/daily_routine_contract_test.dart')
s = p.read_text(encoding='utf-8')
# Replace entire test file for a stable contract.
s = r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily routine uses one deterministic recurring series per anchor', () {
    final source = File(
      'lib/app/shell/shared/shell_daily_routine.dart',
    ).readAsStringSync();

    for (final title in <String>[
      'Утренние процедуры',
      'Завтрак',
      'Зарядка',
      'Обед',
      'Ужин',
      'Подготовка ко сну',
    ]) {
      expect(source, contains("title: '$title'"));
    }
    expect(source, contains("rrule: 'FREQ=DAILY'"));
    expect(source, contains("planRrule: 'FREQ=DAILY'"));
    expect(source, contains('clientPlanId: deterministicPlanId'));
    expect(source, contains("'lifeos-routine-v1-"));
    expect(source, contains('_dailyRoutineEnsureInFlightV7'));
    expect(source, contains('startTime: start'));
    expect(source, contains('endDateTime: end'));
    expect(source, isNot(contains('backendId = businessId')));
  });

  test('path actions use unique deterministic plan ids and normal scheduling does not clean duplicates', () {
    final source = File(
      'lib/app/shell/shared/shell_path_governance.dart',
    ).readAsStringSync();

    expect(source, contains('_canonicalActivePathRootsV6'));
    expect(source, contains('_pathActionBusinessIdV7'));
    expect(source, contains("'lifeos-path-action-v1-"));
    expect(source, contains('existingBusinessIds.contains(planBusinessId)'));
    expect(source, contains('clientPlanId: planBusinessId'));
    expect(source, contains('_currentWeekApprovalCategoryIdsV7'));
    expect(source, isNot(contains('_dedupeCurrentWeekApprovalPlansV6')));
    expect(source, contains('_migrateLegacyApprovalDuplicatesV7'));
    expect(source, contains('_plannerBaselineMigrationV7'));
  });

  test('ordinary shell startup ensures planner baseline without scheduling project actions', () {
    final shell = File('lib/app/shell/app_shell.dart').readAsStringSync();
    final governance = File(
      'lib/app/shell/shared/shell_path_governance.dart',
    ).readAsStringSync();
    expect(shell, contains('await ensurePlannerBaselineV7();'));
    expect(governance, contains('Future<void> ensurePlannerBaselineV7()'));
    final start = governance.indexOf('Future<void> ensurePlannerBaselineV7()');
    final body = governance.substring(start, governance.indexOf('\n}', start) + 2);
    expect(body, contains('ensureDailyRoutineV6'));
    expect(body, contains('_migrateLegacyApprovalDuplicatesV7'));
    expect(body, isNot(contains('planCurrentWeekFromPathsV4')));
  });
}
'''
p.write_text(s, encoding='utf-8')
