import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'viktor_action_contract.dart';
import 'viktor_schedule_planner.dart';
import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:timezone/timezone.dart' as tz;

/// Application-only execution: re-read state, compare the approved result, then
/// use the existing Brain. No model is ever given direct database access.
class ViktorExecutor {
  ViktorExecutor(this.db);
  final DatabaseService db;

  final ViktorSchedulePlanner _planner = const ViktorSchedulePlanner();
  final ViktorBulkPlanner _bulk = const ViktorBulkPlanner();
  String? _bulkSignature;

  Future<ViktorBulkPreview> _planBulk(ViktorAction action, DateTime day) async {
    final operations = action.arguments['operations'] as List;
    final targetDays = <String>{
      for (final raw in operations)
        if ((raw as Map)['kind'] == 'move') raw['target_day'] as String,
    };
    if (targetDays.length > 1) {
      throw StateError('Несколько целевых дней: разделите запрос.');
    }
    final dest = targetDays.isEmpty ? null : targetDays.single;
    final source = await db.getPlanningTasksForWallDate(day);
    final target = dest == null ? <PlanningTask>[] :
      await db.getPlanningTasksForWallDate(DateTime.parse(dest));
    DateTime wallTime(String date, String time, String zone) {
      final parts = date.split('-').map(int.parse).toList();
      final clock = time.split(':').map(int.parse).toList();
      final requested = zone.trim();
      if (requested.isEmpty || requested == 'profile' ||
          profileTimezoneValuesMatch(requested, db.settings.preferredTimeZone)) {
        return DateTime(parts[0], parts[1], parts[2], clock[0], clock[1]);
      }
      final catalog = catalogEntryForStoredTimezone(requested);
      if (catalog == null) {
        throw StateError('Неизвестный часовой пояс: $requested');
      }
      final zoned = tz.TZDateTime(tz.getLocation(catalog.ianaId),
        parts[0], parts[1], parts[2], clock[0], clock[1]);
      if (zoned.year != parts[0] || zoned.month != parts[1] ||
          zoned.day != parts[2] || zoned.hour != clock[0] ||
          zoned.minute != clock[1]) {
        throw StateError('Указанное время отсутствует из-за перевода часов.');
      }
      return db.applyUserOffset(zoned.toUtc());
    }
    return _bulk.calculate(
      action: action, source: source, target: target,
      sourceDay: _key(day), targetDay: dest, wallTime: wallTime,
      fixedTime: _fixed,
    );
  }


  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool _fixed(PlanningTask p) =>
      (db.getCategoryRuleById(p.categoryId)?.defaultPlanTime ?? '')
          .trim().isNotEmpty;

  void _checkScope(ViktorActionBatch batch, DateTime day) {
    // Mixed command types cannot be rolled back as one transaction through the
    // current Brain. Permit multi-step schedule edits (one bulk operation) but
    // require separate confirmations for creates and record start/stop.
    final mutations = batch.actions.where((a) => a.isMutation).toList();
    if (mutations.length > 1 &&
        mutations.any((a) => a.name != 'update_plan_duration' &&
            a.name != 'move_plan_after')) {
      throw StateError('Выполните добавление и управление записью отдельными '
          'сообщениями. Несколько изменений расписания можно объединять.');
    }
    for (final a in batch.actions) {
      final selected = a.arguments['wall_day'];
      if (selected != null && selected != _key(day)) {
        throw StateError('ИИ предложил изменение другого дня.');
      }
      if (a.name == 'start_record' &&
          a.arguments.containsKey('category_id')) {
        throw StateError('Категорию записи требуется выбрать в приложении.');
      }
    }
  }

  ViktorSchedulePreview _schedule(
    ViktorActionBatch batch, DateTime day, List<PlanningTask> plans) =>
      _planner.calculate(
        day: day, plans: plans, actions: batch.actions, fixedTime: _fixed);

  Future<String> describe(ViktorActionBatch batch, DateTime day) async {
    _checkScope(batch, day);
    if (batch.actions.any((a) => a.name == 'bulk_replan')) {
      if (batch.actions.length != 1) {
        throw StateError('Групповая операция должна выполняться отдельно.');
      }
      final preview = await _planBulk(batch.actions.single, day);
      _bulkSignature = preview.signature;
      return preview.describe();
    }
    final plans = await db.getPlanningTasksForWallDate(day);
    final lines = <String>[];
    for (final action in batch.actions) {
      final a = action.arguments;
      switch (action.name) {
        case 'list_day_plans':
          final sorted = [...plans]..sort((a, b) =>
              (a.startTime ?? DateTime(2099)).compareTo(
                  b.startTime ?? DateTime(2099)));
          if (sorted.isEmpty) lines.add('На этот день планов нет.');
          for (final p in sorted) {
            final t = p.startTime;
            final clock = t == null ? '—' :
                '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}';
            lines.add('$clock  ${p.title}');
          }
        case 'create_plan':
          final parts = (a['wall_day'] as String).split('-').map(int.parse).toList();
          final clock = (a['start_time'] as String)
              .split(':').map(int.parse).toList();
          final start = DateTime(parts[0], parts[1], parts[2], clock[0], clock[1]);
          final end = start.add(Duration(minutes: a['duration_minutes'] as int));
          if (end.year != day.year || end.month != day.month ||
              end.day != day.day) {
            throw StateError('Новый план должен завершиться в выбранный день.');
          }
          for (final old in plans) {
            if (old.startTime != null && old.endDateTime != null &&
                old.startTime!.isBefore(end) &&
                old.endDateTime!.isAfter(start)) {
              throw StateError('Новое время пересекается с «${old.title}». '
                  'Попросите Виктора найти другой свободный интервал.');
            }
          }
          lines.add('Добавить «${a['title']}» в ${a['start_time']} '
              'на ${a['duration_minutes']} мин.');
        case 'update_plan_duration':
          lines.add('Изменить длительность плана '
              '${a['expected_duration_minutes']} → '
              '${a['duration_minutes']} мин.');
        case 'move_plan_after':
          lines.add('Переставить план сразу после выбранного.');
        case 'swap_plan_positions':
          lines.add('Поменять местами две выбранные карточки.');
        case 'start_record':
          if (db.canonicalPrimaryRunningBusinessId != null) {
            throw StateError('Уже есть активная запись. Остановите её сначала.');
          }
          lines.add('Начать запись «${a['title']}»');
        case 'stop_record':
          if (db.canonicalPrimaryRunningBusinessId != a['record_id']) {
            throw StateError('Указанная запись больше не является активной.');
          }
          lines.add('Остановить текущую запись');
      }
    }
    final preview = _schedule(batch, day, plans);
    if (preview.changed.isNotEmpty) {
      lines.add('');
      lines.add('Итоговое расписание:');
      final sorted = [...preview.changed]..sort(
          (a, b) => a.startTime!.compareTo(b.startTime!));
      for (final p in sorted) {
        String clock(DateTime t) =>
            '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';
        lines.add('${clock(p.startTime!)}–${clock(p.endDateTime!)}  ${p.title}');
      }
    }
    return lines.join('\n');
  }

  Future<String> apply(ViktorActionBatch batch, DateTime day, {
    required String approvedPreview,
  }) async {
    final approvedSignature = _bulkSignature;
    final fresh = await describe(batch, day);
    if (fresh != approvedPreview ||
        (batch.actions.length == 1 &&
         batch.actions.single.name == 'bulk_replan' &&
         approvedSignature != _bulkSignature)) {
      throw StateError('Расписание изменилось после подтверждения. '
          'Проверьте новый вариант.');
    }
    if (batch.actions.length == 1 &&
        batch.actions.single.name == 'bulk_replan') {
      final result = await _planBulk(batch.actions.single, day);
      if (result.signature != _bulkSignature) {
        throw StateError('Планы изменились после подтверждения.');
      }
      final patches = <PlanningBulkPatch>[
        for (final m in result.moves)
          PlanningBulkPatch(
            planRowId: m.plan.recordIdForBackend,
            planBusinessId: m.plan.planRowId,
            startTimeDisplay: m.start,
            endDateTimeDisplay: m.end,
            initialDateKey: m.kind == 'move'
              ? db.planningAuditAnchorDateKey(m.plan) : null,
            isPostponed: m.kind == 'move'
              ? db.planningShouldMarkPostponed(
                  anchorKey: db.planningAuditAnchorDateKey(m.plan),
                  newScheduleKey: m.day,
                ) : null,
          ),
      ];
      final ok = await db.bulkUpdatePlans(patches, suppressAppSnack: true);
      if (!ok) {
        throw StateError('Не все изменения сохранены. Проверьте оба дня '
            'перед повторной попыткой.');
      }
      return 'Изменено планов: ${result.moves.length}. '
          'Проверьте синхронизацию.';
    }
    final plans = await db.getPlanningTasksForWallDate(day);
    final preview = _schedule(batch, day, plans);
    final patches = <PlanningBulkPatch>[
      for (final p in preview.changed)
        PlanningBulkPatch(
          planRowId: p.recordIdForBackend,
          planBusinessId: p.planRowId,
          startTimeDisplay: p.startTime,
          endDateTimeDisplay: p.endDateTime,
        ),
    ];
    if (patches.isNotEmpty) {
      // The existing multi-row Brain write is not fully atomic. Never claim
      // full success if one patch fails.
      final ok = await db.bulkUpdatePlans(patches, suppressAppSnack: true);
      if (!ok) {
        throw StateError('Сохранение не завершено. Часть изменений могла '
            'примениться — проверьте расписание.');
      }
    }
    var done = patches.isNotEmpty ? 1 : 0;
    for (final action in batch.actions) {
      final a = action.arguments;
      switch (action.name) {
        case 'list_day_plans':
        case 'update_plan_duration':
        case 'move_plan_after':
        case 'swap_plan_positions':
        case 'bulk_replan':
          break;
        case 'create_plan':
          final category = db.defaultCategoryId ??
              (db.rules.where((r) => !r.isArchived).isNotEmpty
                  ? db.rules.firstWhere((r) => !r.isArchived).id
                  : null);
          if (category == null || db.getCategoryRuleById(category) == null) {
            throw StateError('Требуется выбрать категорию нового плана.');
          }
          final date = a['wall_day'] as String;
          final parts = date.split('-').map(int.parse).toList();
          final clock = (a['start_time'] as String)
              .split(':').map(int.parse).toList();
          final start = DateTime(
              parts[0], parts[1], parts[2], clock[0], clock[1]);
          final ok = await db.addPlanningTask(PlanningTask(
            id: 0, title: a['title'] as String, categoryId: category,
            dateKey: date, startTime: start,
            endDateTime: start.add(
                Duration(minutes: a['duration_minutes'] as int)),
          ));
          if (!ok) throw StateError('Не удалось добавить план.');
          done++;
        case 'start_record':
          if (db.canonicalPrimaryRunningBusinessId != null) {
            throw StateError('Уже запущена запись.');
          }
          final now = DatabaseService.getPlanetaryNow();
          final localDay = db.getTimelineDeviceLocalToday();
          final id = await db.writeRecord(
            _key(localDay), a['title'] as String,
            categoryId: db.defaultCategoryId,
            explicitStartTime: now,
          );
          if (id == null) throw StateError('Не удалось начать запись.');
          done++;
        case 'stop_record':
          final id = a['record_id'] as String;
          if (db.canonicalPrimaryRunningBusinessId != id) {
            throw StateError('Активная запись изменилась.');
          }
          final ok = await db.stopRecordByDocId(id);
          if (!ok) throw StateError('Не удалось остановить запись.');
          done++;
      }
    }
    return done == 0 ? 'План прочитан.' :
        'Изменения переданы в LIFE OS. Проверьте синхронизацию.';
  }
}
