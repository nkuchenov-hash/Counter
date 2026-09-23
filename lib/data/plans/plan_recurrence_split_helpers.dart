part of '../database_service.dart';

extension PlanRecurrenceSplitExtension on DatabaseService {
  PlanningTask planningRecurrenceEditSource(PlanningTask task) {
    if (task.rrule?.trim().isNotEmpty == true) return task;
    final parent = _resolveRecurrenceSeriesPocketId(
      planRowId: task.planRowIdForBackend,
      planBusinessId: task.planRowId,
      cached: task,
    );
    if (parent == null) return task;
    return _findCachedPlanningTaskForEdit(parent) ?? task;
  }

  String? _splitRecurrenceDay({
    required String planRowId,
    String? recurrenceInstanceDateKey,
    PlanningTask? cached,
  }) {
    final resolved = _resolveRecurrenceInstanceDateKey(
      planRowId: planRowId,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      cached: cached,
    );
    if (resolved != null) return resolved;
    final dk = cached?.dateKey.trim() ?? '';
    return dk.length >= 10 ? dk.substring(0, 10) : null;
  }

  DateTime? _wallDayForRecurrenceKey(String key) {
    if (key.length < 10) return null;
    final y = int.tryParse(key.substring(0, 4));
    final m = int.tryParse(key.substring(5, 7));
    final d = int.tryParse(key.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    final out = DateTime(y, m, d);
    return out.year == y && out.month == m && out.day == d ? out : null;
  }

  String _wallDateKey(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)}';

  Future<PlanningTask?> _recurrenceSeriesFromServer(String seriesPb) async {
    try {
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final rec = await _pb
          .collection(PbCollections.plans)
          .getOne(seriesPb, expand: kPbPlanTagsExpand);
      final task = _planningTaskFromPocketRecord(
        rec,
        pocketTagCatalog: tagCatalog,
      );
      return task.rrule?.trim().isNotEmpty == true ? task : null;
    } catch (_) {
      return null;
    }
  }

  int _recurrenceCountBefore(
    PlanningTask parent,
    String rrule,
    DateTime splitStartUtc,
  ) {
    try {
      final instants = _planUtcInstants(parent);
      if (instants == null) return 0;
      final base = instants.startUtc.toUtc();
      if (!base.isBefore(splitStartUtc)) return 0;
      final rule = RecurrenceRule.fromString(
        _normalizeRruleStringForDecoder(rrule),
        options: const RecurrenceRuleFromStringOptions.lenient(),
      );
      return rule
          .getAllInstances(
            start: base,
            after: base.subtract(const Duration(seconds: 1)),
            includeAfter: true,
            before: splitStartUtc,
            includeBefore: false,
          )
          .length;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> _createRecurringSplitRowStrict(PlanningTask task) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return null;
    final catRule = getCategoryRuleById(task.categoryId);
    if (catRule == null || task.title.trim().isEmpty) return null;
    try {
      final Object categoryField;
      final catSystem = _categoryBackendRowIdStrict(catRule);
      if (catSystem != null) {
        categoryField = catSystem;
      } else {
        final catString = _categoryStringPkForApi(catRule);
        categoryField = catString != null && catString.isNotEmpty
            ? catString
            : _recordCategoryBusinessPkForApi(task.categoryId);
      }
      final clientPlanId = DatabaseService._newClientRecordUuid();
      final body = await _buildPocketPlanCreateBody(
        task,
        titleTrimmed: task.title.trim(),
        clientPlanId: clientPlanId,
        categoryFieldForPlan: categoryField,
      );
      final record = await _pb.collection(PbCollections.plans).create(body: body);
      if (task.tags.isNotEmpty) await _syncPlanTagsPocket(record.id, task.tags);
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final merged = task.tags.isNotEmpty
          ? await _pb
              .collection(PbCollections.plans)
              .getOne(record.id, expand: kPbPlanTagsExpand)
          : record;
      _upsertPlanInUserCache(
        _planningTaskFromPocketRecord(merged, pocketTagCatalog: tagCatalog),
      );
      return record.id;
    } catch (e, st) {
      DatabaseService._log('RECURRENCE_SPLIT_CREATE: $e');
      DatabaseService._log(st.toString());
      return null;
    }
  }

  Future<List<PlanningTask>> _materializedChildrenFrom(
    String seriesPb,
    String splitDay,
  ) async {
    await _ensureAllPlansUserCacheFresh(force: true);
    return [
      for (final task in _allPlansUserCache)
        if ((task.parentPlanPocketId?.trim() ?? '') == seriesPb &&
            (task.recurrenceInstanceDateKey?.trim().length ?? 0) >= 10 &&
            task.recurrenceInstanceDateKey!
                    .substring(0, 10)
                    .compareTo(splitDay) >=
                0)
          task,
    ];
  }

  Future<bool> _reparentRecurrenceChildren(
    List<PlanningTask> children,
    String parentPb,
  ) async {
    final changed = <PlanningTask>[];
    try {
      for (final child in children) {
        final id = child.pocketRecordId?.trim() ?? '';
        if (!DatabaseService._isLikelyPocketBaseRowId(id)) continue;
        await _pb.collection(PbCollections.plans).update(
          id,
          body: <String, dynamic>{'parent_plan_id': parentPb},
        );
        changed.add(child);
        _upsertPlanInUserCache(child.copyWith(parentPlanPocketId: parentPb));
      }
      return true;
    } catch (e, st) {
      DatabaseService._log('RECURRENCE_SPLIT_REPARENT: $e');
      DatabaseService._log(st.toString());
      for (final child in changed) {
        final id = child.pocketRecordId?.trim() ?? '';
        final original = child.parentPlanPocketId?.trim() ?? '';
        if (!DatabaseService._isLikelyPocketBaseRowId(id) ||
            !DatabaseService._isLikelyPocketBaseRowId(original)) continue;
        try {
          await _pb.collection(PbCollections.plans).update(
            id,
            body: <String, dynamic>{'parent_plan_id': original},
          );
        } catch (_) {}
      }
      return false;
    }
  }

  Future<bool> _patchMaterializedOccurrenceStrict(
    PlanningTask child, {
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
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
  }) async {
    final id = child.pocketRecordId?.trim() ?? '';
    if (!DatabaseService._isLikelyPocketBaseRowId(id)) return false;
    final body = _scalarPatchBodyForPlanningRow(
      planBusinessId: child.planRowId,
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
      planInitialDateKey: planInitialDateKey,
      planIsPostponed: planIsPostponed,
    );
    try {
      if (body.isNotEmpty) {
        await _pb.collection(PbCollections.plans).update(id, body: body);
      }
      if (tags != null) await _syncPlanTagsPocket(id, tags);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _truncateRecurringSeriesStrict(
    PlanningTask parent,
    String splitDay,
    String oldRule,
  ) async {
    final id = parent.pocketRecordId?.trim() ?? '';
    if (!DatabaseService._isLikelyPocketBaseRowId(id)) return false;
    final pastExceptions = <String>[
      for (final e in parent.exceptionDates)
        if (e.trim().length >= 10 &&
            e.trim().substring(0, 10).compareTo(splitDay) < 0)
          e.trim().substring(0, 10),
    ]..sort();
    final body = _scalarPatchBodyForPlanningRow(
      planBusinessId: parent.planRowId,
      patchPlanAlarmRecurrence: true,
      planRrule: oldRule,
      planReminderOffset: parent.reminderOffset,
      planExceptionDates: pastExceptions,
    );
    try {
      await _pb.collection(PbCollections.plans).update(id, body: body);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _updateRecurringThisAndFuture(
    String planRowId, {
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
    String? recurrenceInstanceDateKey,
  }) async {
    final cached = _findCachedPlanningTaskForEdit(
      planRowId,
      planBusinessId: planBusinessId,
    );
    final seriesPb = _resolveRecurrenceSeriesPocketId(
      planRowId: planRowId,
      planBusinessId: planBusinessId,
      cached: cached,
    );
    final splitDay = _splitRecurrenceDay(
      planRowId: planRowId,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      cached: cached,
    );
    if (seriesPb == null || splitDay == null) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    final wallDay = _wallDayForRecurrenceKey(splitDay);
    final parent = await _recurrenceSeriesFromServer(seriesPb);
    if (wallDay == null || parent == null) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    final currentRule = parent.rrule!.trim();
    final splitStartUtc = _profileUtcFromWall(wallDay);
    final consumed = _recurrenceCountBefore(parent, currentRule, splitStartUtc);
    final oldRule = recurrenceRruleEndingBefore(currentRule, splitStartUtc);
    final requestedRule = patchPlanAlarmRecurrence
        ? (planRrule ?? '').trim()
        : currentRule;
    final sameRule = requestedRule.isNotEmpty &&
        _normalizeRruleStringForDecoder(requestedRule) ==
            _normalizeRruleStringForDecoder(currentRule);
    final futureRule = requestedRule.isEmpty
        ? null
        : (sameRule
            ? recurrenceRruleWithRemainingCount(requestedRule, consumed)
            : requestedRule);

    final originalTimes = _materializedWallStartEndForDay(parent, wallDay);
    var futureStart =
        startTimeDisplay ?? startTime ?? cached?.startTime ?? originalTimes.$1;
    futureStart ??= wallDay;
    if (_wallDateKey(futureStart).compareTo(splitDay) < 0) {
      futureStart = DateTime(
        wallDay.year,
        wallDay.month,
        wallDay.day,
        futureStart.hour,
        futureStart.minute,
        futureStart.second,
      );
    }
    DateTime? futureEnd;
    if (!clearEnd) {
      futureEnd = endDateTimeDisplay ?? endDateTime ?? cached?.endDateTime;
      if (futureEnd == null &&
          parent.startTime != null &&
          parent.endDateTime != null) {
        final duration = parent.endDateTime!.difference(parent.startTime!);
        if (!duration.isNegative) futureEnd = futureStart.add(duration);
      }
    }
    final futureExceptions = <String>[
      for (final e in parent.exceptionDates)
        if (e.trim().length >= 10 &&
            e.trim().substring(0, 10).compareTo(splitDay) >= 0)
          e.trim().substring(0, 10),
    ]..sort();
    final futureTask = PlanningTask(
      id: 0,
      title: (title ?? cached?.title ?? parent.title).trim(),
      categoryId: categoryId ?? cached?.categoryId ?? parent.categoryId,
      isDone: false,
      dateKey: _wallDateKey(futureStart),
      order: order ?? cached?.order ?? parent.order,
      startTime: futureStart,
      endDateTime: futureEnd,
      checklist: checklist != null
          ? _copyChecklistForMaterialize(checklist)
          : _copyChecklistForMaterialize(cached?.checklist ?? parent.checklist),
      notesPlain: notesPlain ?? cached?.notesPlain ?? parent.notesPlain,
      notesDeltaJson:
          notesDeltaJson ?? cached?.notesDeltaJson ?? parent.notesDeltaJson,
      tags: List<Tag>.from(tags ?? cached?.tags ?? parent.tags),
      initialDateKey: splitDay,
      isPostponed: _wallDateKey(futureStart).compareTo(splitDay) > 0,
      rrule: futureRule,
      exceptionDates: futureRule == null ? const <String>[] : futureExceptions,
      reminderOffset:
          planReminderOffset ?? cached?.reminderOffset ?? parent.reminderOffset,
    );

    final futureId = await _createRecurringSplitRowStrict(futureTask);
    if (futureId == null) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    final futureChildren = await _materializedChildrenFrom(seriesPb, splitDay);
    if (futureRule != null &&
        !await _reparentRecurrenceChildren(futureChildren, futureId)) {
      try {
        await _pb.collection(PbCollections.plans).delete(futureId);
      } catch (_) {}
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    if (!await _truncateRecurringSeriesStrict(parent, splitDay, oldRule)) {
      if (futureRule != null) {
        await _reparentRecurrenceChildren(futureChildren, seriesPb);
      }
      try {
        await _pb.collection(PbCollections.plans).delete(futureId);
      } catch (_) {}
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }

    if (futureRule == null) {
      for (final child in futureChildren) {
        final id = child.pocketRecordId?.trim() ?? '';
        if (!DatabaseService._isLikelyPocketBaseRowId(id)) continue;
        try {
          await _pb.collection(PbCollections.plans).delete(id);
          _removePlanFromUserCache(id);
        } catch (_) {}
      }
    } else if (cached != null && _isMaterializedRecurrenceException(cached)) {
      PlanningTask? selected;
      for (final child in futureChildren) {
        if (child.pocketRecordId == cached.pocketRecordId) {
          selected = child;
          break;
        }
      }
      if (selected != null) {
        await _patchMaterializedOccurrenceStrict(
          selected,
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
          tags: tags,
          planInitialDateKey: planInitialDateKey,
          planIsPostponed: planIsPostponed,
        );
      }
    }

    await _fetchAllPlanningTasksForCurrentUser();
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _notifyTimelineAfterRecordCacheMutation();
    if (!suppressAppSnack) AppSnack.updated();
    return true;
  }

  Future<bool> _deleteRecurringThisAndFuture(
    String planRowId, {
    String? planBusinessId,
    String? recurrenceInstanceDateKey,
    bool suppressAppSnack = false,
  }) async {
    final cached = _findCachedPlanningTaskForEdit(
      planRowId,
      planBusinessId: planBusinessId,
    );
    final seriesPb = _resolveRecurrenceSeriesPocketId(
      planRowId: planRowId,
      planBusinessId: planBusinessId,
      cached: cached,
    );
    final splitDay = _splitRecurrenceDay(
      planRowId: planRowId,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      cached: cached,
    );
    if (seriesPb == null || splitDay == null) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    final wallDay = _wallDayForRecurrenceKey(splitDay);
    final parent = await _recurrenceSeriesFromServer(seriesPb);
    if (wallDay == null || parent == null) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    final oldRule = recurrenceRruleEndingBefore(
      parent.rrule!.trim(),
      _profileUtcFromWall(wallDay),
    );
    if (!await _truncateRecurringSeriesStrict(parent, splitDay, oldRule)) {
      if (!suppressAppSnack) AppSnack.failed();
      return false;
    }
    var ok = true;
    for (final child in await _materializedChildrenFrom(seriesPb, splitDay)) {
      final id = child.pocketRecordId?.trim() ?? '';
      if (!DatabaseService._isLikelyPocketBaseRowId(id)) continue;
      try {
        await _pb.collection(PbCollections.plans).delete(id);
        _removePlanFromUserCache(id);
      } catch (_) {
        ok = false;
      }
    }
    await _fetchAllPlanningTasksForCurrentUser();
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _notifyTimelineAfterRecordCacheMutation();
    if (!suppressAppSnack) {
      if (ok) {
        AppSnack.updated();
      } else {
        AppSnack.failed();
      }
    }
    return ok;
  }
}
