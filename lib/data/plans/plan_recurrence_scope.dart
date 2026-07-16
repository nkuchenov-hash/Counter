part of '../database_service.dart';

/// Recurrence edit-scope routing for instance, future, and series changes.
extension PlanRecurrenceScopeExtension on DatabaseService {
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
