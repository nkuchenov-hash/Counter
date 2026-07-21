part of '../database_service.dart';

List<String> _parsePlanExceptionDatesForOffline(dynamic raw) {
  if (raw == null) return const [];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e.toString().trim().length >= 10)
        e.toString().trim().substring(0, 10),
  ];
}

String? _normPlanRecurrenceInstanceKey(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.length >= 10) return s.substring(0, 10);
  return null;
}

extension PlanRecurrenceExtension on DatabaseService {
  void _collectMaterializedRecurrenceSuppressionKeys(
    PlanningTask task,
    Set<String> keys,
  ) {
    if (_isJitVirtualPlanningTask(task)) return;
    final inst = task.recurrenceInstanceDateKey?.trim();
    if (inst == null || inst.length < 10) return;
    final instDay = inst.substring(0, 10);

    final seriesPb = task.parentPlanPocketId?.trim();
    if (seriesPb != null &&
        DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
      keys.add('$seriesPb|$instDay');
    }

    final pocket = task.pocketRecordId?.trim();
    if (pocket != null &&
        DatabaseService._isLikelyPocketBaseRowId(pocket) &&
        (seriesPb == null || seriesPb.isEmpty)) {
      keys.add('$pocket|$instDay');
    }

    final biz = _planBusinessUuidFromTask(task);
    if (biz != null && biz.isNotEmpty) {
      keys.add('biz:$biz|$instDay');
    }
  }

  String _normalizeRruleStringForDecoder(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.toUpperCase().startsWith('RRULE:')) {
      s = 'RRULE:$s';
    }
    return s;
  }

  DateTime? _utcDateOnlyFromPlanDateKey(String dk) {
    if (dk.length < 10) return null;
    final y = int.tryParse(dk.substring(0, 4));
    final m = int.tryParse(dk.substring(5, 7));
    final d = int.tryParse(dk.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// JIT: expand [PlanningTask.rrule] into virtual rows between [viewStart] and [viewEnd] (wall dates).
  List<PlanningTask> expandRecurringPlans(
    List<PlanningTask> allPlans,
    DateTime viewStart,
    DateTime viewEnd,
  ) {
    final out = <PlanningTask>[];
    final templates = allPlans
        .where((p) => (p.rrule?.trim().isNotEmpty ?? false))
        .toList();
    if (templates.isEmpty) return out;

    final materializedOccurrenceKeys = <String>{};
    for (final p in allPlans) {
      _collectMaterializedRecurrenceSuppressionKeys(
        p,
        materializedOccurrenceKeys,
      );
    }
    final emittedVirtKeys = <String>{};

    DateTime wallOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final startWall = wallOnly(viewStart);
    final endWall = wallOnly(viewEnd);
    if (endWall.isBefore(startWall)) return out;

    final windowStartUtc = wall_clock
        .utcWallClockDayBoundsUtc(
          startWall,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        )
        .$1;
    final windowEndUtc = wall_clock
        .utcWallClockDayBoundsUtc(
          endWall,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        )
        .$2;

    for (final template in templates) {
      if (template.isDone) continue;
      final pr = template.pocketRecordId?.trim() ?? '';
      if (pr.isEmpty) continue;
      RecurrenceRule rule;
      try {
        rule = RecurrenceRule.fromString(
          _normalizeRruleStringForDecoder(template.rrule!.trim()),
          options: const RecurrenceRuleFromStringOptions.lenient(),
        );
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
            '[RRULE] skip plan $pr: parse failed for "${template.rrule}"',
          );
        }
        continue;
      }

      final instants = _planUtcInstants(template);
      if (instants == null) continue;
      final baseStartUtc = instants.startUtc;
      final dur = instants.endUtc != null
          ? instants.endUtc!.difference(baseStartUtc)
          : Duration.zero;
      final durClamped = dur.isNegative ? Duration.zero : dur;

      final ex = <String>{
        for (final e in template.exceptionDates)
          if (e.trim().length >= 10) e.trim().substring(0, 10),
      };

      final List<DateTime> instances;
      try {
        instances = rule.getAllInstances(
          start: baseStartUtc.toUtc(),
          after: windowStartUtc,
          includeAfter: true,
          before: windowEndUtc,
          includeBefore: true,
        );
      } catch (_) {
        if (kDebugMode) {
          debugPrint('[RRULE] skip plan $pr: iteration failed');
        }
        continue;
      }

      for (final instanceUtc in instances) {
        final wall = _profileWallFromUtc(instanceUtc);
        final wallDay = wallOnly(wall);
        if (wallDay.isBefore(startWall) || wallDay.isAfter(endWall)) {
          continue;
        }
        final dk = '${wall.year}-${_two(wall.month)}-${_two(wall.day)}';
        if (ex.contains(dk)) continue;

        final virtKey = 'virt-$pr-$dk';
        if (materializedOccurrenceKeys.contains('$pr|$dk') ||
            materializedOccurrenceKeys.contains('biz:$pr|$dk') ||
            emittedVirtKeys.contains(virtKey)) {
          continue;
        }
        emittedVirtKeys.add(virtKey);

        final startWallInstance = _profileWallFromUtc(instanceUtc);
        DateTime? endWallInstance;
        if (durClamped.inSeconds > 0) {
          endWallInstance = _profileWallFromUtc(instanceUtc.add(durClamped));
        }

        out.add(
          template.copyWith(
            planRowId: 'virt-$pr-$dk',
            dateKey: dk,
            startTime: startWallInstance,
            date: _utcDateOnlyFromPlanDateKey(dk),
            endDateTime: endWallInstance,
            recurrenceInstanceDateKey: dk,
            clearRrule: true,
            exceptionDates: const [],
            startUtcInstant: instanceUtc.toUtc(),
            endUtcInstant: durClamped.inSeconds > 0
                ? instanceUtc.add(durClamped).toUtc()
                : null,
          ),
        );
      }
    }
    return out;
  }

  bool _isJitVirtualPlanningTask(PlanningTask task) {
    final row = task.planRowId?.trim() ?? '';
    if (row.startsWith('virt-')) return true;
    return task.planRowIdForBackend.startsWith('virt-');
  }

  bool _isMaterializedRecurrenceException(PlanningTask task) {
    if (_isJitVirtualPlanningTask(task)) return false;
    final inst = task.recurrenceInstanceDateKey?.trim();
    if (inst == null || inst.length < 10) return false;
    final series = task.parentPlanPocketId?.trim();
    return series != null && DatabaseService._isLikelyPocketBaseRowId(series);
  }

  /// UI + Brain: recurring occurrence, virtual JIT row, or materialized exception.
  bool planningTaskIsRecurringForScope(PlanningTask task) {
    if (_isJitVirtualPlanningTask(task)) return true;
    if (task.rrule?.trim().isNotEmpty == true) return true;
    return _isMaterializedRecurrenceException(task);
  }


  String? _resolveRecurrenceInstanceDateKey({
    required String planRowId,
    String? recurrenceInstanceDateKey,
    PlanningTask? cached,
  }) {
    final hint = recurrenceInstanceDateKey?.trim() ?? '';
    if (hint.length >= 10) return hint.substring(0, 10);
    final virt = _parseVirtualPlanRowId(planRowId);
    if (virt != null) return virt.instanceDateKey;
    final fromTask = cached?.recurrenceInstanceDateKey?.trim() ?? '';
    if (fromTask.length >= 10) return fromTask.substring(0, 10);
    return null;
  }

  String? _resolveRecurrenceSeriesPocketId({
    required String planRowId,
    String? planBusinessId,
    PlanningTask? cached,
  }) {
    final virt = _parseVirtualPlanRowId(planRowId);
    if (virt != null) return virt.parentPocketId;
    final task = cached ??
        _findCachedPlanningTaskForEdit(
          planRowId,
          planBusinessId: planBusinessId,
        );
    if (task == null) return null;
    if (task.rrule?.trim().isNotEmpty == true) {
      final pb = task.pocketRecordId?.trim();
      if (pb != null && DatabaseService._isLikelyPocketBaseRowId(pb)) {
        return pb;
      }
    }
    final parent = task.parentPlanPocketId?.trim();
    if (parent != null && DatabaseService._isLikelyPocketBaseRowId(parent)) {
      return parent;
    }
    final pb = task.pocketRecordId?.trim();
    if (pb != null && DatabaseService._isLikelyPocketBaseRowId(pb)) return pb;
    return null;
  }

  /// Stable list identity: PB system id → business plan_id → virt occurrence id.

  String? _virtParentPbFromJitRow(PlanningTask task) {
    final row = task.planRowId?.trim() ?? '';
    if (!row.startsWith('virt-')) return null;
    final m = RegExp(r'^virt-(.+)-(\d{4}-\d{2}-\d{2})$').firstMatch(row);
    return m?.group(1)?.trim();
  }

  /// JIT expanded row id: `virt-<parentPocketId>-YYYY-MM-DD`. Never pass [virt-] IDs to PocketBase REST.
  ({String parentPocketId, String instanceDateKey})?
  _parseVirtualPlanRowId(String raw) {
    final s = raw.trim();
    final m = RegExp(r'^virt-(.+)-(\d{4}-\d{2}-\d{2})$').firstMatch(s);
    if (m == null) return null;
    final pid = m.group(1)!.trim();
    final dk = m.group(2)!.trim();
    if (!DatabaseService._isLikelyPocketBaseRowId(pid)) return null;
    final y = int.tryParse(dk.substring(0, 4));
    final mo = int.tryParse(dk.substring(5, 7));
    final d = int.tryParse(dk.substring(8, 10));
    if (y == null || mo == null || d == null) return null;
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return (parentPocketId: pid, instanceDateKey: dk);
  }

  /// Skip or restore one recurring instance by mutating the template’s [exception_dates] only.
  Future<bool> _patchRecurringTemplateExceptionDates({
    required String parentPlanPocketId,
    required String instanceDateKey,
    required bool addException,
    bool suppressAppSnack = false,
    bool deferPlanningNotify = false,
  }) async {
    final pid = parentPlanPocketId.trim();
    if (pid.isEmpty || !DatabaseService._isLikelyPocketBaseRowId(pid)) {
      return false;
    }
    var day = instanceDateKey.trim();
    if (day.length < 10) return false;
    day = day.substring(0, 10);

    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final rec = await _pb
          .collection(PbCollections.plans)
          .getOne(pid, expand: kPbPlanTagsExpand);
      final parent = _planningTaskFromPocketRecord(
        rec,
        pocketTagCatalog: tagCatalog,
      );
      final rrule = parent.rrule?.trim() ?? '';
      if (rrule.isEmpty) {
        DatabaseService._log('VIRT_PLAN_PATCH: parent $pid has no rrule');
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      final next = <String>{
        for (final e in parent.exceptionDates)
          if (e.trim().length >= 10) e.trim().substring(0, 10),
      };
      if (addException) {
        next.add(day);
      } else {
        next.remove(day);
      }

      final restId = await _resolvePlanRestId(
        pid,
        planBusinessId: parent.planRowId,
      );
      final patchBody = _scalarPatchBodyForPlanningRow(
        planBusinessId: parent.planRowId,
        patchPlanAlarmRecurrence: true,
        planRrule: parent.rrule,
        planReminderOffset: parent.reminderOffset,
        planExceptionDates: next.toList()..sort(),
      );
      if (patchBody.isEmpty) return false;
      await _pb.collection(PbCollections.plans).update(restId, body: patchBody);
      clearOptimisticPlanningForPlanRow(pid);
      clearOptimisticPlanningForPlanRow(restId);
      if (!deferPlanningNotify) {
        notifyPlanningRefresh();
        _notifyTimelineAfterRecordCacheMutation();
      }
      return true;
    } catch (e, st) {
      DatabaseService._log('VIRT_PLAN_PATCH: $e');
      DatabaseService._log(st.toString());
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
  }

  /// Wall times for [day] using parent template’s clock (same as JIT [expandRecurringPlans] instance shape).
  (DateTime?, DateTime?) _materializedWallStartEndForDay(
    PlanningTask parent,
    DateTime wallDay,
  ) {
    final pst = parent.startTime;
    if (pst == null) {
      return (null, null);
    }
    final start = DateTime(
      wallDay.year,
      wallDay.month,
      wallDay.day,
      pst.hour,
      pst.minute,
      pst.second,
      pst.millisecond,
      pst.microsecond,
    );
    final pend = parent.endDateTime;
    if (pend == null) {
      return (start, null);
    }
    final dur = pend.difference(pst);
    final end = dur.isNegative ? start : start.add(dur);
    return (start, end);
  }

  List<Map<String, dynamic>> _copyChecklistForMaterialize(
    List<Map<String, dynamic>> src,
  ) {
    return [for (final m in src) Map<String, dynamic>.from(m)];
  }

  /// POST a new real plan row; returns **false** on any failure (no outbox “success”).
  Future<bool> _createPlanningTaskPocketStrict(PlanningTask task) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      return false;
    }
    try {
      final catRule = getCategoryRuleById(task.categoryId);
      if (catRule == null) {
        DatabaseService._log(
          'MATERIALIZE_PLAN: unknown category ${task.categoryId}',
        );
        return false;
      }
      final Object categoryFieldForPlan;
      final catNocoSys = _categoryBackendRowIdStrict(catRule);
      if (catNocoSys != null) {
        categoryFieldForPlan = catNocoSys;
      } else {
        final catStr = _categoryStringPkForApi(catRule);
        if (catStr != null && catStr.isNotEmpty) {
          categoryFieldForPlan = catStr;
        } else {
          categoryFieldForPlan = _recordCategoryBusinessPkForApi(
            task.categoryId,
          );
        }
      }
      final titleTrimmed = task.title.trim();
      if (titleTrimmed.isEmpty) {
        DatabaseService._log('MATERIALIZE_PLAN: empty title');
        return false;
      }
      final clientPlanId = DatabaseService._newClientRecordUuid();
      final body = await _buildPocketPlanCreateBody(
        task,
        titleTrimmed: titleTrimmed,
        clientPlanId: clientPlanId,
        categoryFieldForPlan: categoryFieldForPlan,
      );
      final record = await _pb
          .collection(PbCollections.plans)
          .create(body: body);
      if (task.tags.isNotEmpty) {
        await _syncPlanTagsPocket(record.id, task.tags);
      }
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final persisted = _planningTaskFromPocketRecord(
        record,
        pocketTagCatalog: tagCatalog,
      );
      _upsertPlanInUserCache(
        persisted.copyWith(
          parentPlanPocketId: task.parentPlanPocketId,
          recurrenceInstanceDateKey: task.recurrenceInstanceDateKey,
          initialDateKey: task.initialDateKey,
          isPostponed: task.isPostponed,
        ),
      );
      return true;
    } catch (e, st) {
      DatabaseService._log('MATERIALIZE_PLAN_PB: $e');
      DatabaseService._log(st.toString());
      return false;
    }
  }

  /// Complete a recurring **virtual** row: PATCH parent [exception_dates] + POST one-off done plan on that wall day.
  Future<bool> _completeVirtualRecurringInstance({
    required String parentPlanPocketId,
    required String instanceDateKey,
    bool suppressAppSnack = false,
    bool deferPlanningNotify = false,
  }) async {
    final pid = parentPlanPocketId.trim();
    if (pid.isEmpty || !DatabaseService._isLikelyPocketBaseRowId(pid)) {
      return false;
    }
    var day = instanceDateKey.trim();
    if (day.length < 10) return false;
    day = day.substring(0, 10);

    final y = int.tryParse(day.substring(0, 4));
    final mo = int.tryParse(day.substring(5, 7));
    final d = int.tryParse(day.substring(8, 10));
    if (y == null || mo == null || d == null) return false;
    final wallDay = DateTime(y, mo, d);
    if (wallDay.year != y || wallDay.month != mo || wallDay.day != d) {
      return false;
    }

    final patched = await _patchRecurringTemplateExceptionDates(
      parentPlanPocketId: pid,
      instanceDateKey: day,
      addException: true,
      suppressAppSnack: suppressAppSnack,
      deferPlanningNotify: true,
    );
    if (!patched) return false;

    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final rec = await _pb
          .collection(PbCollections.plans)
          .getOne(pid, expand: kPbPlanTagsExpand);
      final parent = _planningTaskFromPocketRecord(
        rec,
        pocketTagCatalog: tagCatalog,
      );
      if (parent.rrule?.trim().isEmpty ?? true) {
        await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: pid,
          instanceDateKey: day,
          addException: false,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      final wallTimes = _materializedWallStartEndForDay(parent, wallDay);
      final ord = await nextPlanningOrderForDate(wallDay);

      final material = PlanningTask(
        id: 0,
        title: parent.title,
        categoryId: parent.categoryId,
        isDone: true,
        dateKey: day,
        order: ord,
        startTime: wallTimes.$1,
        endDateTime: wallTimes.$2,
        checklist: _copyChecklistForMaterialize(parent.checklist),
        notesPlain: parent.notesPlain,
        notesDeltaJson: parent.notesDeltaJson,
        tags: List<Tag>.from(parent.tags),
        initialDateKey: day,
        isPostponed: false,
        parentPlanPocketId: pid,
        recurrenceInstanceDateKey: day,
      );

      final created = await _createPlanningTaskPocketStrict(material);
      if (!created) {
        await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: pid,
          instanceDateKey: day,
          addException: false,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      if (!deferPlanningNotify) {
        notifyPlanningRefresh();
        _notifyTimelineAfterRecordCacheMutation();
      }
      return true;
    } catch (e, st) {
      DatabaseService._log('VIRT_MATERIALIZE: $e');
      DatabaseService._log(st.toString());
      await _patchRecurringTemplateExceptionDates(
        parentPlanPocketId: pid,
        instanceDateKey: day,
        addException: false,
        suppressAppSnack: true,
        deferPlanningNotify: true,
      );
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
  }

  bool _virtualPlanPatchIsDoneOnly({
    bool? isDone,
    String? title,
    int? categoryId,
    String? notesPlain,
    String? notesDeltaJson,
    List<Map<String, dynamic>>? checklist,
    int? parentPlanId,
    int? order,
    DateTime? startTime,
    DateTime? startTimeDisplay,
    DateTime? endDateTime,
    DateTime? endDateTimeDisplay,
    bool clearEnd = false,
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,
  }) {
    if (isDone == null) return false;
    return title == null &&
        categoryId == null &&
        notesPlain == null &&
        notesDeltaJson == null &&
        checklist == null &&
        parentPlanId == null &&
        order == null &&
        startTime == null &&
        startTimeDisplay == null &&
        endDateTime == null &&
        endDateTimeDisplay == null &&
        !clearEnd &&
        tags == null &&
        planInitialDateKey == null &&
        planIsPostponed == null &&
        !patchPlanAlarmRecurrence &&
        planRrule == null &&
        planReminderOffset == null &&
        planExceptionDates == null;
  }

  /// Materialize a JIT virtual occurrence as a concrete one-off plan (time/metadata edit).
  Future<bool> _materializeRecurringInstanceFromVirtualPatch({
    required String planRowId,
    required String parentPlanPocketId,
    required String instanceDateKey,
    String? planBusinessId,
    String? title,
    int? categoryId,
    bool? isDone,
    String? notesPlain,
    String? notesDeltaJson,
    List<Map<String, dynamic>>? checklist,
    int? order,
    DateTime? startTime,
    DateTime? startTimeDisplay,
    DateTime? endDateTime,
    DateTime? endDateTimeDisplay,
    bool clearEnd = false,
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    int? planReminderOffset,
    bool suppressAppSnack = false,
  }) async {
    final pid = parentPlanPocketId.trim();
    var day = instanceDateKey.trim();
    if (day.length < 10) return false;
    day = day.substring(0, 10);

    final cached = _findCachedPlanningTaskForEdit(
      planRowId,
      planBusinessId: planBusinessId,
    );
    final oldStart = cached?.startTime;
    final oldEnd = cached?.endDateTime;

    final newStartWall = startTimeDisplay ?? startTime ?? cached?.startTime;
    DateTime? newEndWall;
    if (clearEnd) {
      newEndWall = null;
    } else {
      newEndWall = endDateTimeDisplay ?? endDateTime ?? cached?.endDateTime;
    }

    // ignore: avoid_print
    if (kDebugMode) {
      debugPrint(
        'RECURRENCE_INSTANCE_EDIT_REQUEST planId=${planBusinessId ?? planRowId} '
        'pocketId=$pid isVirtual=true',
      );
    }

    final patched = await _patchRecurringTemplateExceptionDates(
      parentPlanPocketId: pid,
      instanceDateKey: day,
      addException: true,
      suppressAppSnack: true,
      deferPlanningNotify: true,
    );
    if (!patched) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }

    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final rec = await _pb
          .collection(PbCollections.plans)
          .getOne(pid, expand: kPbPlanTagsExpand);
      final parent = _planningTaskFromPocketRecord(
        rec,
        pocketTagCatalog: tagCatalog,
      );
      if (parent.rrule?.trim().isEmpty ?? true) {
        await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: pid,
          instanceDateKey: day,
          addException: false,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      final scheduleDay = newStartWall != null
          ? DateTime(newStartWall.year, newStartWall.month, newStartWall.day)
          : DateTime(
              int.parse(day.substring(0, 4)),
              int.parse(day.substring(5, 7)),
              int.parse(day.substring(8, 10)),
            );
      final scheduleKey =
          '${scheduleDay.year}-${_two(scheduleDay.month)}-${_two(scheduleDay.day)}';
      final ord = order ?? await nextPlanningOrderForDate(scheduleDay);

      final material = PlanningTask(
        id: 0,
        title: (title ?? cached?.title ?? parent.title).trim(),
        categoryId: categoryId ?? cached?.categoryId ?? parent.categoryId,
        isDone: isDone ?? cached?.isDone ?? false,
        dateKey: scheduleKey,
        order: ord,
        startTime: newStartWall,
        endDateTime: newEndWall,
        checklist: checklist != null
            ? _copyChecklistForMaterialize(checklist)
            : _copyChecklistForMaterialize(
                cached?.checklist ?? parent.checklist,
              ),
        notesPlain: notesPlain ?? cached?.notesPlain ?? parent.notesPlain,
        notesDeltaJson:
            notesDeltaJson ?? cached?.notesDeltaJson ?? parent.notesDeltaJson,
        tags: List<Tag>.from(tags ?? cached?.tags ?? parent.tags),
        initialDateKey: planInitialDateKey ?? day,
        isPostponed: planIsPostponed ?? false,
        reminderOffset: planReminderOffset ?? cached?.reminderOffset,
        parentPlanPocketId: pid,
        recurrenceInstanceDateKey: day,
      );

      final created = await _createPlanningTaskPocketStrict(material);
      if (!created) {
        await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: pid,
          instanceDateKey: day,
          addException: false,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }

      clearOptimisticPlanningForPlanRow(planRowId);
      notifyPlanningRefresh();
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (e, st) {
      DatabaseService._log('RECURRENCE_INSTANCE_MATERIALIZE: $e');
      DatabaseService._log(st.toString());
      await _patchRecurringTemplateExceptionDates(
        parentPlanPocketId: pid,
        instanceDateKey: day,
        addException: false,
        suppressAppSnack: true,
        deferPlanningNotify: true,
      );
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
  }

  /// Applies [scope] for recurring plan edits (virtual, materialized, or series row).
  Future<bool> updatePlanningTaskWithRecurrenceScope(
    String planRowId, {
    required RecurrenceEditScope scope,
    String? planBusinessId,
    String? title,
    int? categoryId,
    bool? isDone,
    String? notesPlain,
    String? notesDeltaJson,
    List<Map<String, dynamic>>? checklist,
    int? parentPlanId,
    int? order,
    DateTime? startTime,
    DateTime? startTimeDisplay,
    DateTime? endDateTime,
    DateTime? endDateTimeDisplay,
    bool clearEnd = false,
    bool suppressAppSnack = false,
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,
    String? recurrenceInstanceDateKey,
  }) async {
    if (scope == RecurrenceEditScope.thisAndFuture) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    final cached = _findCachedPlanningTaskForEdit(
      planRowId,
      planBusinessId: planBusinessId,
    );
    if (scope == RecurrenceEditScope.entireSeries) {
      final seriesPb = _resolveRecurrenceSeriesPocketId(
        planRowId: planRowId,
        planBusinessId: planBusinessId,
        cached: cached,
      );
      if (seriesPb == null ||
          !DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      final seriesTask = cached?.rrule?.trim().isNotEmpty == true
          ? cached
          : _findCachedPlanningTaskForEdit(seriesPb);
      return updatePlanningTask(
        seriesPb,
        planBusinessId: seriesTask?.planRowId ?? planBusinessId,
        title: title,
        categoryId: categoryId,
        isDone: isDone,
        notesPlain: notesPlain,
        notesDeltaJson: notesDeltaJson,
        checklist: checklist,
        parentPlanId: parentPlanId,
        order: order,
        startTime: startTime,
        startTimeDisplay: startTimeDisplay,
        endDateTime: endDateTime,
        endDateTimeDisplay: endDateTimeDisplay,
        clearEnd: clearEnd,
        suppressAppSnack: suppressAppSnack,
        tags: tags,
        planInitialDateKey: planInitialDateKey,
        planIsPostponed: planIsPostponed,
        patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
        planRrule: planRrule,
        planReminderOffset: planReminderOffset,
        planExceptionDates: planExceptionDates,
        recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      );
    }
    return updatePlanningTask(
      planRowId,
      planBusinessId: planBusinessId,
      title: title,
      categoryId: categoryId,
      isDone: isDone,
      notesPlain: notesPlain,
      notesDeltaJson: notesDeltaJson,
      checklist: checklist,
      parentPlanId: parentPlanId,
      order: order,
      startTime: startTime,
      startTimeDisplay: startTimeDisplay,
      endDateTime: endDateTime,
      endDateTimeDisplay: endDateTimeDisplay,
      clearEnd: clearEnd,
      suppressAppSnack: suppressAppSnack,
      tags: tags,
      planInitialDateKey: planInitialDateKey,
      planIsPostponed: planIsPostponed,
      patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
      planRrule: planRrule,
      planReminderOffset: planReminderOffset,
      planExceptionDates: planExceptionDates,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
    );
  }

  /// Applies [scope] for recurring plan deletes.
  Future<bool> deletePlanningTaskWithRecurrenceScope(
    String planRowId, {
    required RecurrenceEditScope scope,
    String? planBusinessId,
    String? recurrenceInstanceDateKey,
    bool suppressAppSnack = false,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) return false;
    final rid = planRowId.trim();
    if (rid.isEmpty) return false;

    if (scope == RecurrenceEditScope.thisAndFuture) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }

    final cached = _findCachedPlanningTaskForEdit(
      rid,
      planBusinessId: planBusinessId,
    );

    if (scope == RecurrenceEditScope.entireSeries) {
      final seriesPb = _resolveRecurrenceSeriesPocketId(
        planRowId: rid,
        planBusinessId: planBusinessId,
        cached: cached,
      );
      if (seriesPb == null ||
          !DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
        if (!suppressAppSnack) AppSnack.failed();
        return false;
      }
      return deletePlanningTasksBulk([seriesPb]);
    }

    final virt = _parseVirtualPlanRowId(rid);
    if (virt != null) {
      return deletePlanningTasksBulk([rid]);
    }

    if (_isMaterializedRecurrenceException(
      cached ??
          PlanningTask(
            id: 0,
            title: '',
            categoryId: 0,
            isDone: false,
            dateKey: '',
            order: 0,
          ),
    )) {
      return deletePlanningTasksBulk([rid]);
    }

    final instDay = _resolveRecurrenceInstanceDateKey(
      planRowId: rid,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      cached: cached,
    );
    if (instDay != null && cached?.rrule?.trim().isNotEmpty == true) {
      final seriesPb = cached?.pocketRecordId?.trim();
      if (seriesPb != null &&
          DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
        return _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: seriesPb,
          instanceDateKey: instDay,
          addException: true,
          suppressAppSnack: suppressAppSnack,
        );
      }
    }

    return deletePlanningTasksBulk([rid]);
  }

}
