part of '../database_service.dart';

/// Scalar plan updates, bulk mutations, and ordinary deletion flows.
extension PlanMutationsExtension on DatabaseService {
  /// Flat `plans` scalar PATCH map (no `user_id` key). Shared by [updatePlanningTask] and [bulkUpdatePlans].
  Map<String, dynamic> _scalarPatchBodyForPlanningRow({
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
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,
  }) {
    final fields = <String, dynamic>{'user_id': _pidForPbFilter};
    if (title != null) fields['title'] = title;
    if (categoryId != null) {
      final cs = _categoryRelationIdForPlanPatch(categoryId);
      if (cs != null && cs.isNotEmpty) {
        fields['category_id'] = cs;
      }
    }
    if (isDone != null) fields['is_done'] = isDone;
    if (notesPlain != null) {
      final nt = notesPlain.trim();
      fields['notes_plain'] = nt.isEmpty ? null : nt;
    }
    if (notesDeltaJson != null) {
      final nd = notesDeltaJson.trim();
      if (nd.isEmpty) {
        fields['notes_delta'] = null;
      } else {
        try {
          fields['notes_delta'] = jsonDecode(nd);
        } catch (_) {
          fields['notes_delta'] = null;
        }
      }
    }
    if (checklist != null) fields['checklist'] = checklist;
    if (parentPlanId != null) {
      fields['parent_plan_id'] = parentPlanId.toString();
    }
    if (order != null) fields['order'] = order;
    if (startTimeDisplay != null) {
      fields['start_time'] = _profileUtcFromWall(
        startTimeDisplay,
      ).toIso8601String();
    } else if (startTime != null) {
      fields['start_time'] = _profileUtcFromWall(startTime).toIso8601String();
    }
    if (clearEnd) {
      fields['end_time'] = null;
    } else if (endDateTimeDisplay != null) {
      fields['end_time'] = _profileUtcFromWall(
        endDateTimeDisplay,
      ).toIso8601String();
    } else if (endDateTime != null) {
      fields['end_time'] = _profileUtcFromWall(endDateTime).toIso8601String();
    }
    final bizPid = planBusinessId?.trim() ?? '';
    if (bizPid.isNotEmpty && !bizPid.startsWith('optimistic-')) {
      fields['plan_id'] = bizPid;
    }
    final initK = planInitialDateKey?.trim() ?? '';
    if (initK.length >= 10) {
      fields['initial_date_key'] = initK.substring(0, 10);
    }
    if (planIsPostponed != null) {
      fields['is_postponed'] = planIsPostponed;
    }
    if (patchPlanAlarmRecurrence) {
      final rt = (planRrule ?? '').trim();
      if (rt.isNotEmpty) {
        fields['rrule'] = rt;
        fields['exception_dates'] = List<String>.from(
          planExceptionDates ?? const <String>[],
        );
      } else {
        fields['rrule'] = null;
        fields['exception_dates'] = const <String>[];
      }
      fields['reminder_offset'] = planReminderOffset;
    }
    final patchBody = <String, dynamic>{};
    for (final e in fields.entries) {
      if (e.key == 'user_id') continue;
      patchBody[e.key] = e.value;
    }
    return patchBody;
  }

  /// JIT expanded row id: `virt-<parentPocketId>-YYYY-MM-DD`. Never pass [virt-] IDs to PocketBase REST.

  Future<bool> updatePlanningTask(
    String planRowId, {

    /// @DATA_MAP `plan_id` (UUID) — send inside `fields` only; outer bulk `id` must be Integer Id.
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

    /// When true, `AppSnack` success/failure toasts are omitted (caller handles UX).
    bool suppressAppSnack = false,

    /// When non-null, replaces **tags_link** on PocketBase after successful scalar PATCH.
    List<Tag>? tags,
    String? planInitialDateKey,
    bool? planIsPostponed,
    bool patchPlanAlarmRecurrence = false,
    String? planRrule,
    int? planReminderOffset,
    List<String>? planExceptionDates,

    /// When [planRowId] is `virt-…`, prefer this wall `YYYY-MM-DD` over the id suffix (Phase 1 JIT rows).
    String? recurrenceInstanceDateKey,
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked updatePlanningTask because plans table id equals records table id.',
      );
      return false;
    }
    final rid = planRowId.trim();
    if (rid.isEmpty) return false;

    final virt = _parseVirtualPlanRowId(rid);
    if (virt != null) {
      final hint = recurrenceInstanceDateKey?.trim() ?? '';
      final effectiveDay = hint.length >= 10
          ? hint.substring(0, 10)
          : virt.instanceDateKey;

      if (_virtualPlanPatchIsDoneOnly(
        isDone: isDone,
        title: title,
        categoryId: categoryId,
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
        patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
        planRrule: planRrule,
        planReminderOffset: planReminderOffset,
        planExceptionDates: planExceptionDates,
      )) {
        if (isDone!) {
          return _completeVirtualRecurringInstance(
            parentPlanPocketId: virt.parentPocketId,
            instanceDateKey: effectiveDay,
            suppressAppSnack: suppressAppSnack,
          );
        }
        return _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: virt.parentPocketId,
          instanceDateKey: effectiveDay,
          addException: false,
          suppressAppSnack: suppressAppSnack,
        );
      }

      return _materializeRecurringInstanceFromVirtualPatch(
        planRowId: rid,
        parentPlanPocketId: virt.parentPocketId,
        instanceDateKey: effectiveDay,
        planBusinessId: planBusinessId,
        title: title,
        categoryId: categoryId,
        isDone: isDone,
        notesPlain: notesPlain,
        notesDeltaJson: notesDeltaJson,
        checklist: checklist,
        order: order,
        startTime: startTime,
        startTimeDisplay: startTimeDisplay,
        endDateTime: endDateTime,
        endDateTimeDisplay: endDateTimeDisplay,
        clearEnd: clearEnd,
        tags: tags,
        planInitialDateKey: planInitialDateKey,
        planIsPostponed: planIsPostponed,
        planReminderOffset: planReminderOffset,
        suppressAppSnack: suppressAppSnack,
      );
    }

    final businessId = _outboxBusinessPlanId(
      rid,
      planBusinessId: planBusinessId,
    );
    final existingTask = _findCachedPlanningTaskForEdit(
      rid,
      planBusinessId: planBusinessId,
    );
    if (existingTask?.rrule?.trim().isNotEmpty == true &&
        (startTime != null ||
            startTimeDisplay != null ||
            endDateTime != null ||
            endDateTimeDisplay != null ||
            clearEnd)) {
      if (kDebugMode) {
        debugPrint(
          'RECURRENCE_INSTANCE_EDIT_SERIES_ROW planId=${planBusinessId ?? rid} '
          'pocketId=${existingTask?.pocketRecordId ?? '-'}',
        );
      }
    }
    final oldCategoryId = existingTask?.categoryId;
    final autoCategoryId = _resolveCategoryIdForEditedTitle(
      newTitle: title,
      oldTitle: existingTask?.title,
      currentCategoryId: oldCategoryId,
      manualCategoryChanged: categoryId != null,
    );
    final effectiveCategoryId = categoryId ?? autoCategoryId;
    final patchBody = _scalarPatchBodyForPlanningRow(
      planBusinessId: planBusinessId,
      title: title,
      categoryId: effectiveCategoryId,
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
      patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
      planRrule: planRrule,
      planReminderOffset: planReminderOffset,
      planExceptionDates: planExceptionDates,
    );
    if (patchBody.isEmpty && tags == null) return false;

    _applyOptimisticPlanningTaskPatch(
      planRowId: rid,
      planBusinessId: planBusinessId,
      title: title,
      categoryId: effectiveCategoryId,
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
      patchPlanAlarmRecurrence: patchPlanAlarmRecurrence,
      planRrule: planRrule,
      planReminderOffset: planReminderOffset,
      planExceptionDates: planExceptionDates,
    );

    final shadowPb = _tryResolvePlanPbIdFromCacheOnly(
      rid,
      planBusinessId: planBusinessId,
    );
    if (autoCategoryId != null &&
        oldCategoryId != null &&
        oldCategoryId != autoCategoryId &&
        shadowPb != null) {
      _propagatePlanAutoCategoryToLoadedLinkedRecords(
        planPocketId: shadowPb,
        oldCategoryId: oldCategoryId,
        newCategoryId: autoCategoryId,
      );
    }
    if (shadowPb != null &&
        DatabaseService._isLikelyPocketBaseRowId(shadowPb)) {
      unawaited(
        _patchPlanUpdateNetworkPhase(
          originalInput: rid,
          resolvedPbId: shadowPb,
          businessId: businessId,
          patchBody: patchBody,
          tags: tags,
          suppressAppSnack: suppressAppSnack,
        ),
      );
      return true;
    }

    unawaited(() async {
      try {
        final restId = await _resolvePlanRestId(
          rid,
          planBusinessId: planBusinessId,
        );
        if (!DatabaseService._isLikelyPocketBaseRowId(restId)) {
          List<String>? tagIds;
          if (tags != null) {
            tagIds = await _pbTagRecordIdsFromTags(tags);
          }
          final scalarOnly = Map<String, dynamic>.from(patchBody);
          scalarOnly.remove('user_id');
          await _enqueuePlanUpdateMutation(
            originalInput: rid,
            businessId: businessId,
            patchFields: scalarOnly,
            tagsLinkPbIds: tagIds,
            error: 'unresolved_pb_id',
          );
          offlineSync.setConnectivityOffline(true);
          return;
        }
        await _patchPlanUpdateNetworkPhase(
          originalInput: rid,
          resolvedPbId: restId,
          businessId: businessId,
          patchBody: patchBody,
          tags: tags,
          suppressAppSnack: suppressAppSnack,
        );
      } catch (e, st) {
        DatabaseService._log('UPDATE_PLANNING_TASK_PB async: $e');
        DatabaseService._log(st.toString());
        if (_planMutationRetriableHttpCode(0)) {
          final scalarOnly = Map<String, dynamic>.from(patchBody);
          scalarOnly.remove('user_id');
          await _enqueuePlanUpdateMutation(
            originalInput: rid,
            businessId: businessId,
            patchFields: scalarOnly,
            error: e,
          );
          offlineSync.setConnectivityOffline(true);
        } else if (!suppressAppSnack) {
          AppSnack.failed();
        }
      }
    }());
    return true;
  }

  /// Multiple scalar `plans` PATCH calls; clears optimistic overlays per row; **one** [notifyPlanningRefresh] at end.
  ///
  /// Each [PlanningBulkPatch] carries the **final** wall times to persist. Callers may combine a calendar
  /// move and a time delta in one batch by precomputing `start_time` / `end_time` on the destination day.
  /// No per-row tag sync — use [updatePlanningTask] when tags change.
  Future<bool> bulkUpdatePlans(
    List<PlanningBulkPatch> patches, {
    bool suppressAppSnack = false,
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      DatabaseService._log('TABLE_GUARD: blocked bulkUpdatePlans.');
      return false;
    }
    if (patches.isEmpty) return false;
    var allOk = true;
    try {
      for (final p in patches) {
        final rid = p.planRowId.trim();
        if (rid.isEmpty || rid.startsWith('optimistic-')) continue;
        if (rid.startsWith('virt-')) {
          allOk = false;
          DatabaseService._log(
            'BULK_UPDATE_PLANS: skipped virtual clone $rid — use single-row update or exception_dates flow.',
          );
          continue;
        }
        final patchBody = _scalarPatchBodyForPlanningRow(
          planBusinessId: p.planBusinessId,
          startTimeDisplay: p.startTimeDisplay,
          endDateTimeDisplay: p.endDateTimeDisplay,
          clearEnd: p.clearEnd,
          planInitialDateKey: p.initialDateKey,
          planIsPostponed: p.isPostponed,
        );
        if (patchBody.isEmpty) continue;
        try {
          final restId = await _resolvePlanRestId(
            rid,
            planBusinessId: p.planBusinessId,
          );
          await _pb
              .collection(PbCollections.plans)
              .update(restId, body: patchBody);
          clearOptimisticPlanningForPlanRow(rid);
          clearOptimisticPlanningForPlanRow(restId);
        } catch (e, st) {
          allOk = false;
          DatabaseService._log('BULK_UPDATE_PLAN_PB: $e');
          DatabaseService._log(st.toString());
        }
      }
    } finally {
      notifyPlanningRefresh();
    }
    if (!suppressAppSnack) {
      if (allOk) {
        AppSnack.updated();
      } else {
        AppSnack.failed();
      }
    }
    return allOk;
  }

  /// PocketBase [plans] rows: each id is a **record id** string.
  Future<bool> deletePlanningTasksBulk(Iterable<String> planBackendIds) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) {
      DatabaseService._log('TABLE_GUARD: blocked deletePlanningTasksBulk.');
      return false;
    }
    final raw = planBackendIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (raw.isEmpty) return false;

    var deferredNotify = false;
    var skipDeletedSnack = false;
    for (final id in raw) {
      final trimmed = id.trim();
      if (trimmed.startsWith('optimistic-')) {
        clearOptimisticPlanningForPlanRow(trimmed);
        deferredNotify = true;
        continue;
      }
      final virt = _parseVirtualPlanRowId(trimmed);
      if (virt != null) {
        final ok = await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: virt.parentPocketId,
          instanceDateKey: virt.instanceDateKey,
          addException: true,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!ok) {
          AppSnack.failed();
          return false;
        }
        deferredNotify = true;
        continue;
      }
      final businessId = _outboxBusinessPlanId(trimmed);
      final shadowPb = _tryResolvePlanPbIdFromCacheOnly(trimmed);
      if (shadowPb != null &&
          DatabaseService._isLikelyPocketBaseRowId(shadowPb)) {
        final del = await _deletePlanNetworkPhase(
          originalInput: trimmed,
          resolvedPbId: shadowPb,
          businessId: businessId,
        );
        if (!del.ok) {
          AppSnack.failed();
          return false;
        }
        if (del.queued) skipDeletedSnack = true;
        deferredNotify = true;
        continue;
      }
      try {
        final restId = await _resolvePlanRestId(trimmed);
        if (!DatabaseService._isLikelyPocketBaseRowId(restId)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: 'unresolved_pb_id',
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        final del = await _deletePlanNetworkPhase(
          originalInput: trimmed,
          resolvedPbId: restId,
          businessId: businessId,
        );
        if (!del.ok) {
          AppSnack.failed();
          return false;
        }
        if (del.queued) skipDeletedSnack = true;
        deferredNotify = true;
      } on ClientException catch (e, st) {
        DatabaseService._log('DELETE_PLAN_PB_BULK: $e');
        DatabaseService._log(st.toString());
        final code = e.statusCode;
        if (code == 401 || code == 403) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: code,
            syncStatus: PlanMutationOutbox.syncStatusPausedAuth,
          );
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        if (_planMutationRetriableHttpCode(code)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: code,
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        AppSnack.failed();
        return false;
      } catch (e, st) {
        DatabaseService._log('DELETE_PLAN_PB_BULK: $e');
        DatabaseService._log(st.toString());
        if (_planMutationRetriableHttpCode(0)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: e,
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        AppSnack.failed();
        return false;
      }
    }
    if (deferredNotify) {
      notifyPlanningRefresh();
      _notifyTimelineAfterRecordCacheMutation();
    }
    if (!skipDeletedSnack) {
      AppSnack.deleted();
    }
    return true;
  }

  /// Bulk `is_done` — Noco: integer wrapper PK string; PocketBase: record id string.
  Future<bool> markPlanningTasksCompletedBulk(
    Iterable<String> planBackendIds, {
    required bool completed,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) return false;
    final raw = planBackendIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (raw.isEmpty) return false;

    const chunkSize = 10;
    var allOk = true;
    var needsNotify = false;
    for (var i = 0; i < raw.length; i += chunkSize) {
      final end = min(i + chunkSize, raw.length);
      final chunk = raw.sublist(i, end);
      for (final id in chunk) {
        try {
          final trimmed = id.trim();
          final virt = _parseVirtualPlanRowId(trimmed);
          if (virt != null) {
            final bool ok;
            if (completed) {
              ok = await _completeVirtualRecurringInstance(
                parentPlanPocketId: virt.parentPocketId,
                instanceDateKey: virt.instanceDateKey,
                suppressAppSnack: true,
                deferPlanningNotify: true,
              );
            } else {
              ok = await _patchRecurringTemplateExceptionDates(
                parentPlanPocketId: virt.parentPocketId,
                instanceDateKey: virt.instanceDateKey,
                addException: false,
                suppressAppSnack: true,
                deferPlanningNotify: true,
              );
            }
            if (!ok) {
              allOk = false;
            } else {
              needsNotify = true;
            }
            continue;
          }
          final restId = await _resolvePlanRestId(id);
          await _pb
              .collection(PbCollections.plans)
              .update(restId, body: <String, dynamic>{'is_done': completed});
          needsNotify = true;
        } catch (e, st) {
          allOk = false;
          DatabaseService._log('MARK_PLANS_DONE_PB: $e');
          DatabaseService._log(st.toString());
        }
      }
    }
    if (needsNotify) {
      notifyPlanningRefresh();
      _notifyTimelineAfterRecordCacheMutation();
    }
    if (allOk) {
      AppSnack.updated();
    } else {
      AppSnack.failed();
    }
    return allOk;
  }
}
