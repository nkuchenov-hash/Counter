import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'viktor_action_contract.dart';
import 'viktor_schedule_planner.dart';

/// Application-only execution: re-read state, compare the approved result, then
/// use the existing Brain. No model is ever given direct database access.
class ViktorExecutor {
  ViktorExecutor(this.db);
  final DatabaseService db;
  final ViktorSchedulePlanner _planner = const ViktorSchedulePlanner();

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool _fixed(PlanningTask p) =>
      (db.getCategoryRuleById(p.categoryId)?.defaultPlanTime ?? '')
          .trim().isNotEmpty;

  void _checkScope(ViktorActionBatch batch, DateTime day) {
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
          lines.add('Добавить «${a['title']}» в ${a['start_time']} '
              'на ${a['duration_minutes']} мин.');
        case 'update_plan_duration':
          lines.add('Изменить длительность плана '
              '${a['expected_duration_minutes']} → '
              '${a['duration_minutes']} мин.');
        case 'move_plan_after':
          lines.add('Переставить план сразу после выбранного.');
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
    final fresh = await describe(batch, day);
    if (fresh != approvedPreview) {
      throw StateError('Расписание изменилось после подтверждения. '
          'Проверьте новый вариант.');
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
