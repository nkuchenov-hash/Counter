import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'viktor_action_contract.dart';
import 'viktor_historical_records.dart';
import 'viktor_record_tools.dart';
import 'viktor_schedule_planner.dart';
import 'viktor_domain_tools.dart';
import 'viktor_date_scope.dart';
import 'viktor_plan_category.dart';
import 'viktor_existing_plan.dart';
import 'viktor_plan_timezone.dart';
import 'viktor_atomic_bulk_gateway.dart';
import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:timezone/timezone.dart' as tz;

/// Application-only execution: re-read state, compare the approved result, then
/// use the existing Brain. No model is ever given direct database access.
class ViktorExecutor {
  ViktorExecutor(this.db);
  final DatabaseService db;

  final ViktorSchedulePlanner _planner = const ViktorSchedulePlanner();
  final ViktorBulkPlanner _bulk = const ViktorBulkPlanner();
  final ViktorPlanInsertionPlanner _insertion = const ViktorPlanInsertionPlanner();
  late final ViktorDomainTools _domain = ViktorDomainTools(db);
  late final ViktorHistoricalRecords _history = ViktorHistoricalRecords(db);
  late final ViktorRecordTools _recordTools = ViktorRecordTools(db);

  Future<ViktorRecordCreatePreview> _recordCreatePreview(
      ViktorAction action) async {
    final a = action.arguments;
    return _recordTools.prepare(
      wallDay: a['wall_day'] as String,
      records: (a['records'] as List)
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList(),
    );
  }

  Future<ViktorHistoricalPreview> _historicalPreview(
      ViktorAction action) async {
    final args = action.arguments;
    return _history.prepare(
      wallDay: args['wall_day'] as String,
      beforeTitle: args['before_title'] as String,
      afterTitle: args['after_title'] as String,
      titles: (args['titles'] as List).cast<String>(),
    );
  }
  String? _bulkSignature;
  String? _insertionSignature;

  bool _isPriorityInsertion(ViktorAction a) =>
      a.name == 'create_plan' && a.arguments['conflict_policy'] == 'shift';

  DateTime _planStart(ViktorAction action) => viktorPlanStartInProfileWall(
    wallDay: action.arguments['wall_day'] as String,
    startTime: action.arguments['start_time'] as String,
    timezone: action.arguments['timezone'] as String?,
    profileTimezone: db.settings.preferredTimeZone,
    toProfileWall: db.applyUserOffset,
  );

  Future<PlanningTask?> _existingPlan(ViktorAction action) async {
    if (!action.arguments.containsKey('start_time')) {
      final dayKey = action.arguments['wall_day'] as String;
      final plans = await db.getPlanningTasksForWallDate(
          ViktorDateScope.parseDay(dayKey));
      return ViktorExistingPlan.findDateOnly(
        title: action.arguments['title'] as String,
        wallDay: dayKey,
        plans: plans,
      );
    }
    final start = _planStart(action);
    final plans = await db.getPlanningTasksForWallDate(start);
    return ViktorExistingPlan.find(
      title: action.arguments['title'] as String,
      start: start,
      plans: plans,
    );
  }

  Future<ViktorInsertionPreview> _planInsertion(ViktorAction action) async {
    final start = _planStart(action);
    final wallDay = DateTime(start.year, start.month, start.day);
    final plans = await db.getPlanningTasksForWallDate(wallDay);
    return _insertion.calculate(
      day: wallDay,
      plans: plans,
      start: start,
      durationMinutes: action.arguments['duration_minutes'] as int,
      shiftConflicts: true,
      fixedTime: _fixed,
    );
  }

  CategoryRule _planCategory(ViktorAction action) {
    return resolveViktorPlanCategory(
      title: action.arguments['title'] as String,
      identifyCategory: db.identifyCategory,
      categoryById: db.getCategoryRuleById,
      defaultCategoryId: db.defaultCategoryId,
      rootCategories: db.rules,
    );
  }

  String _planCategoryLabel(ViktorAction action) {
    final category = _planCategory(action);
    final path = db.getCategoryPath(category.id).trim();
    return path.isNotEmpty ? path : category.name;
  }

  Future<({bool accepted, bool pendingSync, String clientPlanId})>
      _createPlan(ViktorAction action, DateTime? start) {
    final category = _planCategory(action);
    return db.addPlanningTaskWithReceipt(PlanningTask(
      id: 0, title: action.arguments['title'] as String,
      categoryId: category.id,
      dateKey: start == null ? action.arguments['wall_day'] as String
          : ViktorDateScope.key(start),
      startTime: start,
      endDateTime: start == null ? null : start.add(Duration(
          minutes: action.arguments['duration_minutes'] as int)),
    ));
  }

  String _creationReceipt(
      ViktorAction action, ({bool accepted, bool pendingSync,
      String clientPlanId}) result) {
    final name = action.arguments['title'] as String;
    final day = action.arguments['wall_day'] as String;
    if (result.pendingSync) {
      return 'Добавляю план «$name» на $day. '
          'Сохранение пока не подтверждено; приложение продолжит '
          'автоматически. Повторять запрос не нужно.';
    }
    return 'План «$name» добавлен на $day.';
  }

  Future<ViktorBulkPreview> _planBulk(ViktorAction action) async {
    final operations = action.arguments['operations'] as List;
    final dates = <String>{
      for (final raw in operations) (raw as Map)['source_day'] as String,
      for (final raw in operations)
        if ((raw as Map)['kind'] == 'move') raw['target_day'] as String,
    };
    final allDays = <String, List<PlanningTask>>{};
    for (final date in dates.toList()..sort()) {
      allDays[date] = await db.getPlanningTasksForWallDate(
          ViktorDateScope.parseDay(date));
    }
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
    final firstSource = (operations.first as Map)['source_day'] as String;
    return _bulk.calculate(
      action: action, source: allDays[firstSource]!, target: const [],
      sourceDay: firstSource, targetDay: null, allDays: allDays,
      wallTime: wallTime, fixedTime: _fixed,
      categoryName: (plan) {
        final path = db.getCategoryPath(plan.categoryId).trim();
        return path.isNotEmpty ? path :
            (db.getCategoryRuleById(plan.categoryId)?.name ?? '');
      },
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
    // Multiple application-domain tools can form one approved intent.
    // Multi-row schedule recalculation and record timers still require an
    // isolated operation: their writes are not atomic with other domains.
    final mutations = batch.actions.where((a) => a.isMutation).toList();
    if (batch.actions.any((a) => a.name == 'bulk_replan') &&
        batch.actions.any((a) => a.name != 'bulk_replan' &&
            a.name != 'list_day_plans')) {
      throw StateError('Групповой перенос нельзя объединять с другими '
          'изменениями. Планы не изменены.');
    }
    if (mutations.length > 1 &&
        mutations.any((a) =>
            !ViktorDomainTools.names.contains(a.name) &&
            a.name != 'update_plan_duration' &&
            a.name != 'move_plan_after')) {
      throw StateError('Изменения расписания и запуск/остановка записи '
          'должны быть отдельной защищённой операцией.');
    }
    if (mutations.length > 12) {
      throw StateError('Не более 12 изменений за один шаг.');
    }
    if (batch.actions.any(_isPriorityInsertion) &&
        batch.actions.length != 1) {
      throw StateError('Приоритетная вставка с пересчётом расписания '
          'выполняется одной защищённой операцией.');
    }
    if (batch.actions.any((a) => a.name == 'create_completed_records') &&
        batch.actions.length != 1) {
      throw StateError('Создание завершённых записей должно быть одной '
          'защищённой операцией после просмотра данных.');
    }
    if (batch.actions.any((a) => a.name == 'read_day_records') &&
        mutations.isNotEmpty) {
      throw StateError('Сначала прочитайте существующие записи, затем '
          'предложите подтверждаемое изменение.');
    }
    if (batch.actions.any((a) =>
            a.name == 'create_completed_records_between') &&
        batch.actions.length != 1) {
      throw StateError('Добавление завершённых записей требует '
          'отдельного подтверждения.');
    }
    for (final a in batch.actions) {
      // Validated action dates may differ from the visible calendar date.
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
    if (batch.actions.any((a) => a.name == 'read_day_records') &&
        !batch.hasMutations) {
      final observations = <String>[];
      for (final action in batch.actions) {
        if (action.name == 'read_day_records') {
          observations.add(await _recordTools.listDay(
              action.arguments['wall_day'] as String));
        } else if (action.name == 'list_day_plans') {
          final dayKey = action.arguments['wall_day'] as String;
          final rows = await db.getPlanningTasksForWallDate(
              ViktorDateScope.parseDay(dayKey));
          observations.add('Планы за $dayKey: ' +
              rows.map((p) => p.title).join('; '));
        } else if (ViktorDomainTools.reads.contains(action.name)) {
          observations.add(await _domain.preview(action));
        } else {
          throw StateError('Неизвестная операция чтения.');
        }
      }
      return observations.join('\n\n');
    }
    if (batch.actions.length == 1 &&
        batch.actions.single.name == 'create_completed_records') {
      final preview = await _recordCreatePreview(batch.actions.single);
      return _recordTools.describe(preview);
    }
    if (batch.actions.length == 1 &&
        batch.actions.single.name == 'create_completed_records_between') {
      final proposal = await _historicalPreview(batch.actions.single);
      return proposal.describe(db.applyUserOffset);
    }
    if (batch.actions.length == 1 &&
        _isPriorityInsertion(batch.actions.single)) {
      final action = batch.actions.single;
      final existing = await _existingPlan(action);
      if (existing != null) {
        _insertionSignature = 'existing:${existing.recordIdForBackend}';
        return ViktorExistingPlan.describe(existing);
      }
      final placement = await _planInsertion(action);
      _insertionSignature = placement.signature;
      String clock(DateTime t) =>
          '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
      return [
        'Создать приоритетный план «${action.arguments['title']}» '
            'на ${action.arguments['wall_day']}, '
            '${clock(placement.start)}–${clock(placement.end)} '
            '(${action.arguments['duration_minutes']} мин.).',
        'Категория: ${_planCategoryLabel(action)}.',
        if (placement.shifted.isEmpty) 'Пересечений нет.',
        if (placement.shifted.isNotEmpty)
          'Перенести следующие планы, сохранив длительность:',
        for (final p in placement.shifted)
          '«${p.title}» → ${clock(p.startTime!)}–${clock(p.endDateTime!)}',
        'Подтвердите изменение расписания.',
      ].join('\n');
    }
    if (batch.actions.any((a) => a.name == 'bulk_replan')) {
      final bulk = batch.actions.singleWhere(
          (action) => action.name == 'bulk_replan');
      final preview = await _planBulk(bulk);
      _bulkSignature = preview.signature;
      final readLines = <String>[];
      for (final read in batch.actions.where(
          (action) => action.name == 'list_day_plans')) {
        final requestedDay = read.arguments['wall_day'] as String;
        final readPlans = await db.getPlanningTasksForWallDate(
            ViktorDateScope.parseDay(requestedDay));
        final ordered = [...readPlans]..sort((a, b) =>
            (a.startTime ?? DateTime(2099)).compareTo(
                b.startTime ?? DateTime(2099)));
        if (ordered.isEmpty) readLines.add('На $requestedDay планов нет.');
        for (final plan in ordered) {
          final t = plan.startTime;
          final clock = t == null ? '—' :
              '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}';
          readLines.add('$requestedDay $clock  ${plan.title}');
        }
      }
      return [
        if (readLines.isNotEmpty) ...readLines,
        if (readLines.isNotEmpty) '',
        preview.describe(),
      ].join('\n');
    }
    final scheduleDay = ViktorDateScope.scheduleDay(batch, day);
    final plans = await db.getPlanningTasksForWallDate(scheduleDay);
    final lines = <String>[];
    for (final action in batch.actions) {
      final a = action.arguments;
      switch (action.name) {
        case 'list_day_plans':
          final requestedDay = a['wall_day'] as String;
          final dayPlans = await db.getPlanningTasksForWallDate(
              ViktorDateScope.parseDay(requestedDay));
          final sorted = [...dayPlans]..sort((a, b) =>
              (a.startTime ?? DateTime(2099)).compareTo(
                  b.startTime ?? DateTime(2099)));
          if (sorted.isEmpty) lines.add('На $requestedDay планов нет.');
          for (final p in sorted) {
            final t = p.startTime;
            final clock = t == null ? '—' :
                '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}';
            lines.add('$requestedDay $clock  ${p.title}');
          }
        case 'create_plan':
          final existing = await _existingPlan(action);
          if (!a.containsKey('start_time')) {
            if (existing != null) {
              lines.add(ViktorExistingPlan.describe(existing));
            } else {
              lines.add('Добавить план «${a['title']}» на ${a['wall_day']} '
                  'без назначенного часа. '
                  'Категория: ${_planCategoryLabel(action)}.');
            }
            continue;
          }
          final start = _planStart(action);
          final end = start.add(Duration(minutes: a['duration_minutes'] as int));
          if (existing != null) {
            lines.add(ViktorExistingPlan.describe(existing));
            continue;
          }
          if (end.year != start.year || end.month != start.month ||
              end.day != start.day) {
            throw StateError('Новый план должен завершиться в один '
                'календарный день часового пояса профиля.');
          }
          final destinationPlans = await db.getPlanningTasksForWallDate(start);
          for (final old in destinationPlans) {
            if (old.startTime != null && old.endDateTime != null &&
                old.startTime!.isBefore(end) &&
                old.endDateTime!.isAfter(start)) {
              String clock(DateTime t) =>
                  '${t.hour.toString().padLeft(2, '0')}:'
                  '${t.minute.toString().padLeft(2, '0')}';
              throw StateError('Интервал ${clock(start)}–${clock(end)} '
                  'по времени профиля пересекается с «${old.title}» '
                  '(${clock(old.startTime!)}–${clock(old.endDateTime!)}). '
                  'Другой план не изменён.');
            }
          }
          final zone = (a['timezone'] as String?)?.trim();
          lines.add('Добавить «${a['title']}» на ${a['wall_day']} '
              'в ${a['start_time']}'
              '${zone == null || zone.isEmpty ? '' : ' ($zone)'} '
              'на ${a['duration_minutes']} мин. '
              'Категория: ${_planCategoryLabel(action)}.');
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
        case 'list_categories':
        case 'create_category':
        case 'list_tags':
        case 'create_tag':
        case 'rename_tag':
        case 'list_backlog_items':
        case 'set_list_item_done':
        case 'rename_list_item':
        case 'list_notes':
        case 'search_notes':
        case 'search_record_notes':
        case 'read_record_note':
        case 'read_note':
        case 'create_note':
        case 'edit_note':
        case 'edit_note_line':
        case 'list_paths':
        case 'create_path':
        case 'get_settings':
        case 'change_setting':
          lines.add(await _domain.preview(action));
      }
    }
    final preview = _schedule(batch, scheduleDay, plans);
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
    if (batch.actions.where((a) => a.isMutation).length > 1) {
      lines.add('');
      lines.add('Это несколько независимых операций. '
        'Если сохранение оборвётся, часть изменений может быть '
        'применена. Проверьте результат перед повторным запросом.');
    }
    return lines.join('\n');
  }

  Future<String> apply(ViktorActionBatch batch, DateTime day, {
    required String approvedPreview,
  }) async {
    final approvedSignature = _bulkSignature;
    final approvedInsertionSignature = _insertionSignature;
    final fresh = await describe(batch, day);
    if (fresh != approvedPreview ||
        (batch.actions.any((a) => a.name == 'bulk_replan') &&
         approvedSignature != _bulkSignature) ||
        (batch.actions.length == 1 &&
         _isPriorityInsertion(batch.actions.single) &&
         approvedInsertionSignature != _insertionSignature)) {
      throw StateError('Данные изменились после подтверждения. '
          'Проверьте новый вариант.');
    }
    if (batch.actions.length == 1 &&
        batch.actions.single.name == 'create_completed_records') {
      final proposal = await _recordCreatePreview(batch.actions.single);
      if (_recordTools.describe(proposal) != approvedPreview) {
        throw StateError('Записи изменились после подтверждения.');
      }
      return _recordTools.apply(proposal);
    }
    if (batch.actions.length == 1 &&
        batch.actions.single.name == 'create_completed_records_between') {
      final action = batch.actions.single;
      final proposal = await _historicalPreview(action);
      if (proposal.describe(db.applyUserOffset) != approvedPreview) {
        throw StateError('Исходные записи изменились, сохранение отменено.');
      }
      return _history.save(proposal,
          wallDay: action.arguments['wall_day'] as String);
    }
    if (batch.actions.length == 1 &&
        _isPriorityInsertion(batch.actions.single)) {
      final action = batch.actions.single;
      final existing = await _existingPlan(action);
      if (existing != null) return ViktorExistingPlan.describe(existing);
      final placement = await _planInsertion(action);
      if (placement.signature != _insertionSignature) {
        throw StateError('Планы изменились до сохранения. '
            'Запросите новый предварительный просмотр.');
      }
      final patches = <PlanningBulkPatch>[
        for (final p in placement.shifted)
          PlanningBulkPatch(
            planRowId: p.recordIdForBackend,
            planBusinessId: p.planRowId,
            startTimeDisplay: p.startTime,
            endDateTimeDisplay: p.endDateTime,
          ),
      ];
      if (patches.isNotEmpty &&
          !await db.bulkUpdatePlans(patches, suppressAppSnack: true)) {
        throw StateError('Сдвиг планов сохранён не полностью. '
            'Проверьте расписание перед повтором; встреча не создана.');
      }
      final created = await _createPlan(action, placement.start);
      if (!created.accepted) {
        if (patches.isNotEmpty) {
          final changedIds = placement.shifted
              .map((p) => p.recordIdForBackend).toSet();
          final rollback = <PlanningBulkPatch>[
            for (final old in placement.before)
              if (changedIds.contains(old.recordIdForBackend))
                PlanningBulkPatch(
                  planRowId: old.recordIdForBackend,
                  planBusinessId: old.planRowId,
                  startTimeDisplay: old.startTime,
                  endDateTimeDisplay: old.endDateTime,
                ),
          ];
          final restored = await db.bulkUpdatePlans(
              rollback, suppressAppSnack: true);
          if (!restored) {
            throw StateError('Создание встречи не удалось, а откат '
                'перенесённых планов неполный. Проверьте расписание.');
          }
        }
        throw StateError('Встреча не сохранилась. '
            'Ранее перенесённые планы восстановлены.');
      }
      return '${_creationReceipt(action, created)} '
          'Сдвинуто планов: ${placement.shifted.length}.';
    }
    if (batch.actions.any((a) => a.name == 'bulk_replan')) {
      final bulk = batch.actions.singleWhere(
          (action) => action.name == 'bulk_replan');
      final result = await _planBulk(bulk);
      if (result.signature != _bulkSignature) {
        throw StateError('Планы изменились после подтверждения.');
      }
      // One atomic server transaction and independent post-commit read.
      // NEVER fall back to a sequence of per-plan PATCH calls.
      return ViktorAtomicBulkGateway(db).commit(
        approved: result,
        requestId: batch.requestId,
      );
    }
    final scheduleDay = ViktorDateScope.scheduleDay(batch, day);
    final plans = await db.getPlanningTasksForWallDate(scheduleDay);
    final preview = _schedule(batch, scheduleDay, plans);
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
    final receipts = <String>[];
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
          final existing = await _existingPlan(action);
          if (existing != null) {
            receipts.add(ViktorExistingPlan.describe(existing));
            continue;
          }
          final created = await _createPlan(action,
              a.containsKey('start_time') ? _planStart(action) : null);
          if (!created.accepted) {
            throw StateError('Не удалось добавить план.');
          }
          receipts.add(_creationReceipt(action, created));
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
        case 'list_categories':
        case 'create_category':
        case 'list_tags':
        case 'create_tag':
        case 'rename_tag':
        case 'list_backlog_items':
        case 'set_list_item_done':
        case 'rename_list_item':
        case 'list_notes':
        case 'search_notes':
        case 'search_record_notes':
        case 'read_record_note':
        case 'read_note':
        case 'create_note':
        case 'edit_note':
        case 'edit_note_line':
        case 'list_paths':
        case 'create_path':
        case 'get_settings':
        case 'change_setting':
          try {
            receipts.add(await _domain.execute(action));
            if (action.isMutation) done++;
          } catch (error) {
            throw StateError('Операция «${action.name}» не завершилась: '
                '$error. Ранее выполненные действия могли сохраниться. '
                'Проверьте результат перед повтором.');
          }
      }
    }
    return done == 0 ? receipts.join('\n') :
        (receipts.isEmpty ?
          'Изменения переданы в LIFE OS. Проверьте синхронизацию.' :
          receipts.join('\n'));
  }
}
