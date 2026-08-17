import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';

const String _dailyRoutineMarkerV6 = 'LIFEOS_DAILY_ROUTINE_V1|';

class _DailyRoutineSpecV6 {
  const _DailyRoutineSpecV6({
    required this.key,
    required this.title,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
  });

  final String key;
  final String title;
  final int hour;
  final int minute;
  final int durationMinutes;
}

const List<_DailyRoutineSpecV6> _dailyRoutineSpecsV6 = [
  _DailyRoutineSpecV6(
    key: 'morning-routine',
    title: 'Утренние процедуры',
    hour: 8,
    minute: 30,
    durationMinutes: 20,
  ),
  _DailyRoutineSpecV6(
    key: 'breakfast',
    title: 'Завтрак',
    hour: 8,
    minute: 50,
    durationMinutes: 25,
  ),
  _DailyRoutineSpecV6(
    key: 'exercise',
    title: 'Зарядка',
    hour: 9,
    minute: 15,
    durationMinutes: 20,
  ),
  _DailyRoutineSpecV6(
    key: 'lunch',
    title: 'Обед',
    hour: 13,
    minute: 30,
    durationMinutes: 30,
  ),
  _DailyRoutineSpecV6(
    key: 'dinner',
    title: 'Ужин',
    hour: 20,
    minute: 0,
    durationMinutes: 30,
  ),
  _DailyRoutineSpecV6(
    key: 'bed-prep',
    title: 'Подготовка ко сну',
    hour: 0,
    minute: 0,
    durationMinutes: 30,
  ),
];

String _normalizeRoutineTitleV6(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

String _routineDateKeyV6(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

CategoryRule? _findDailyRoutineCategoryV6() {
  final db = DatabaseService.instance;
  const aliases = <String>['Распорядок дня', 'Режим дня', 'Daily Routine'];
  final wanted = aliases.map(_normalizeRoutineTitleV6).toSet();
  for (final pair in db.allCategoryIdPathPairs) {
    final rule = db.getCategoryRuleById(pair.id);
    if (rule == null || rule.isArchived) continue;
    if (wanted.contains(_normalizeRoutineTitleV6(rule.name))) return rule;
  }
  return null;
}

Future<CategoryRule?> _ensureDailyRoutineCategoryV6() async {
  final existing = _findDailyRoutineCategoryV6();
  if (existing != null) return existing;

  final db = DatabaseService.instance;
  final status = db.classifyCategoryDisplayNameInput('Распорядок дня');
  if (status.activeLocalId != null) {
    return db.getCategoryRuleById(status.activeLocalId!);
  }
  if (status.archivedPbRowId != null) {
    final restored = await db.restoreArchivedCategory(status.archivedPbRowId!);
    if (restored != null) {
      await db.refreshCategoryRulesFromServer();
      return _findDailyRoutineCategoryV6();
    }
  }

  final created = await db.addNestedCategory(
    null,
    CategoryRule(
      id: db.newId(),
      name: 'Распорядок дня',
      colorValue: 0xFF607D8B,
      iconCodePoint: 0xe8b5,
      isSynced: false,
    ),
  );
  if (created == null) return null;
  await db.refreshCategoryRulesFromServer();
  return _findDailyRoutineCategoryV6();
}

DateTime _routineBaseStartV6(
  DatabaseService db,
  _DailyRoutineSpecV6 spec,
) {
  final today = db.getTimelineDeviceLocalToday();
  final nowWall = db.applyUserOffset(DateTime.now().toUtc());
  var start = DateTime(
    today.year,
    today.month,
    today.day,
    spec.hour,
    spec.minute,
  );
  if (!start.isAfter(nowWall.add(const Duration(minutes: 5)))) {
    final tomorrow = today.add(const Duration(days: 1));
    start = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      spec.hour,
      spec.minute,
    );
  }
  return start;
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

  var backendId = existingBackendId?.trim() ?? '';
  var businessId = existingBusinessId?.trim() ?? '';
  if (backendId.isEmpty) {
    businessId = DatabaseService.newClientUuid();
    final created = await db.addPlanningTask(
      PlanningTask(
        id: 0,
        title: spec.title,
        categoryId: category.id,
        isDone: false,
        dateKey: '',
        order: await db.nextBacklogPlanningOrder(),
        notesPlain:
            '$marker\nСистемная ежедневная опора LIFE OS. Время можно менять обычным редактированием повторяющейся серии.',
        rrule: 'FREQ=DAILY',
        isSynced: false,
      ),
      clientPlanId: businessId,
    );
    if (!created) return false;
    backendId = businessId;
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

/// Creates the six baseline personal-routine series once. Existing recurring
/// user plans with the same title win: their times are never overwritten.
Future<void> ensureDailyRoutineV6() async {
  final db = DatabaseService.instance;
  final category = await _ensureDailyRoutineCategoryV6();
  if (category == null) return;

  final rawPlans = await db.fetchPlans();
  // On a transient empty read, do not risk creating a second set of series.
  // This user already has normal Planner rows; the bootstrap can retry later.
  if (rawPlans.isEmpty) return;

  final markerRows = <String, Map<String, dynamic>>{};
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
    if (key.isNotEmpty) markerRows.putIfAbsent(key, () => row);
  }

  for (final spec in _dailyRoutineSpecsV6) {
    final existing = markerRows[spec.key];
    if (existing != null) {
      final rrule = (existing['rrule'] ?? '').toString().trim();
      final start = (existing['start_time'] ?? existing['startTime'])
          ?.toString()
          .trim();
      if (rrule.isNotEmpty && start != null && start.isNotEmpty) {
        continue;
      }
      await _scheduleRoutineSeriesV6(
        category: category,
        spec: spec,
        existingBackendId: (existing['id'] ?? existing['_pb_record_id'])
            ?.toString(),
        existingBusinessId: existing['plan_id']?.toString(),
      );
      continue;
    }

    if (recurringTitles.contains(_normalizeRoutineTitleV6(spec.title))) {
      continue;
    }
    await _scheduleRoutineSeriesV6(category: category, spec: spec);
  }
}
