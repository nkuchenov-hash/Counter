part of '../database_service.dart';

/// Plan creation entry points and PocketBase create orchestration.
extension PlanCreateExtension on DatabaseService {
  Future<void> addPlannedTask(
    String dateKey,
    String taskText, {
    int? categoryId,
    bool isManual = false,
    List<Tag>? tags,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked addPlannedTask because plans table id equals records table id.',
      );
      return;
    }
    try {
      final parsed = getCleanTitleAndTags(taskText);
      int cid = categoryId ?? defaultCategoryId ?? 0;
      if (!isManual) {
        cid = identifyCategory(parsed.title)?.id ?? (defaultCategoryId ?? 0);
      }
      await addPlanningTask(
        PlanningTask(
          id: 0,
          title: parsed.title,
          categoryId: cid,
          dateKey: dateKey,
          order: 0,
          tags: tags ?? const [],
        ),
      );
    } catch (_) {}
  }

  /// Planning-only voice / quick-add: same parsing as Planning UI, then [addPlanningTask].
  Future<bool> addPlanningTaskFromVoiceText({
    required String rawText,
    required DateTime wallDay,
    int? categoryIdHint,
    bool isBacklog = false,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) {
      DatabaseService._log('TABLE_GUARD: blocked addPlanningTaskFromVoiceText');
      return false;
    }

    if (isBacklog) {
      final stripped = SmartInputParser.backlogTitleFromRaw(rawText);
      final gt = getCleanTitleAndTags(stripped);
      final title = gt.title.trim();
      if (title.isEmpty) return false;
      final match = identifyCategory(title);
      final categoryId =
          match?.id ??
          categoryIdHint ??
          defaultCategoryId ??
          (rules.isNotEmpty ? rules.first.id : 0);

      if (getCategoryRuleById(categoryId) == null) {
        DatabaseService._log(
          'VOICE_PLAN: blocked — unknown category $categoryId',
        );
        return false;
      }

      final nextOrder = await nextBacklogPlanningOrder();
      final clientPlanId = DatabaseService.newClientUuid();

      return addPlanningTask(
        PlanningTask(
          id: 0,
          title: title,
          categoryId: categoryId,
          isDone: false,
          dateKey: '',
          order: nextOrder,
          startTime: null,
          endDateTime: null,
          rrule: null,
          checklist: const [],
          parentPlanId: null,
          tags: const [],
          isSynced: false,
        ),
        clientPlanId: clientPlanId,
      );
    }

    final ymd = DateTime(wallDay.year, wallDay.month, wallDay.day);
    final taskDateKey = '${ymd.year}-${_two(ymd.month)}-${_two(ymd.day)}';

    final range = SmartInputParser.parseTitleForTimeRange(rawText);
    SmartTimeParseResult? parsed;
    String title;

    title = SmartInputParser.preservedTitleFromRaw(rawText);
    if (title.isEmpty) return false;

    if (range != null) {
      parsed = null;
    } else {
      parsed = SmartInputParser.parseTitleForScheduledTime(rawText);
    }

    final match = identifyCategory(title);
    final categoryId =
        match?.id ??
        categoryIdHint ??
        defaultCategoryId ??
        (rules.isNotEmpty ? rules.first.id : 0);

    final existingDay = planningDayTasksSnapshot(ymd);
    final explicitStartWall = range != null
        ? range.startWallOn(ymd)
        : parsed?.wallDateTimeOn(ymd);
    final explicitEndWall = range?.endWallOn(ymd);
    final schedule = resolveAutoPlanSchedule(
      wallDay: ymd,
      categoryId: categoryId,
      tags: const [],
      existingDayPlans: existingDay,
      explicitStartWall: explicitStartWall,
      explicitEndWall: explicitEndWall,
      hasExplicitTimeRange: range != null,
      timelineDayStartHour: 0,
    );

    if (getCategoryRuleById(categoryId) == null) {
      DatabaseService._log(
        'VOICE_PLAN: blocked — unknown category $categoryId',
      );
      return false;
    }

    final nextOrder = await nextPlanningOrderForDate(ymd);
    final clientPlanId = DatabaseService.newClientUuid();

    return addPlanningTask(
      planningTaskWithAutoSchedule(
        PlanningTask(
          id: 0,
          title: title,
          categoryId: categoryId,
          isDone: false,
          dateKey: taskDateKey,
          order: nextOrder,
          checklist: const [],
          parentPlanId: null,
          tags: const [],
          isSynced: false,
        ),
        schedule,
      ),
      clientPlanId: clientPlanId,
    );
  }

  Future<void> addPlan({
    required String title,
    required int categoryId,
    required String dateKey,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked addPlan because plans table id equals records table id.',
      );
      return;
    }
    unawaited(() async {
      try {
        final d = dateKey.trim();
        if (d.length >= 10) {
          final y = int.tryParse(d.substring(0, 4));
          final m = int.tryParse(d.substring(5, 7));
          final day = int.tryParse(d.substring(8, 10));
          if (y != null && m != null && day != null) {
            final wallDay = DateTime(y, m, day);
            final existingDay = planningDayTasksSnapshot(wallDay);
            final schedule = resolveAutoPlanSchedule(
              wallDay: wallDay,
              categoryId: categoryId,
              tags: const [],
              existingDayPlans: existingDay,
              timelineDayStartHour: 0,
            );
            await addPlanningTask(
              planningTaskWithAutoSchedule(
                PlanningTask(
                  id: 0,
                  title: title,
                  categoryId: categoryId,
                  dateKey: dateKey,
                  order: 0,
                ),
                schedule,
              ),
            );
          }
        }
      } catch (_) {}
    }());
  }

  Future<Map<String, dynamic>> _buildPocketPlanCreateBody(
    PlanningTask task, {
    required String titleTrimmed,
    required String clientPlanId,
    required Object categoryFieldForPlan,
  }) async {
    final body = <String, dynamic>{
      'plan_id': clientPlanId,
      'user_id': _pidForPbFilter,
      'category_id': categoryFieldForPlan.toString(),
      'title': titleTrimmed,
      'is_done': task.isDone,
      'checklist': task.checklist.isNotEmpty
          ? List<dynamic>.from(task.checklist)
          : <dynamic>[],
      'order': task.order,
    };
    final isDatelessBacklog =
        task.startTime == null && task.dateKey.trim().length < 10;
    if (task.startTime != null) {
      final instants = _planUtcInstantsFromWall(task)!;
      body['start_time'] = instants.startUtc.toIso8601String();
    } else if (!isDatelessBacklog) {
      final dk = task.dateKey.trim();
      if (dk.length >= 10) {
        final iso = _planStartUtcIsoFromDateKey(dk);
        if (iso != null) body['start_time'] = iso;
      }
    }
    if (task.endDateTime != null) {
      final instants = _planUtcInstantsFromWall(task)!;
      if (instants.endUtc != null) {
        body['end_time'] = instants.endUtc!.toIso8601String();
      }
    }
    if (task.parentPlanPocketId != null &&
        task.parentPlanPocketId!.trim().isNotEmpty) {
      body['parent_plan_id'] = task.parentPlanPocketId!.trim();
    } else if (task.parentPlanId != null) {
      body['parent_plan_id'] = task.parentPlanId.toString();
    }
    final np = task.notesPlain?.trim() ?? '';
    if (np.isNotEmpty) {
      body['notes_plain'] = np;
    }
    final ndRaw = task.notesDeltaJson?.trim() ?? '';
    if (ndRaw.isNotEmpty) {
      try {
        body['notes_delta'] = jsonDecode(ndRaw);
      } catch (_) {}
    }
    final idk = task.initialDateKey?.trim() ?? '';
    if (idk.length >= 10) {
      body['initial_date_key'] = idk.substring(0, 10);
    } else {
      final dk = task.dateKey.trim();
      if (dk.length >= 10) {
        body['initial_date_key'] = dk.substring(0, 10);
      }
    }
    body['is_postponed'] = task.isPostponed;
    final rruleTrim = task.rrule?.trim() ?? '';
    if (rruleTrim.isNotEmpty) {
      body['rrule'] = rruleTrim;
      body['exception_dates'] = List<String>.from(task.exceptionDates);
    }
    if (task.reminderOffset != null) {
      body['reminder_offset'] = task.reminderOffset;
    }
    final instKey = task.recurrenceInstanceDateKey?.trim() ?? '';
    if (instKey.length >= 10) {
      body['recurrence_instance_date_key'] = instKey.substring(0, 10);
    }
    if (task.tags.isNotEmpty) {
      final pbIds = await _pbTagRecordIdsFromTags(task.tags);
      if (pbIds.isNotEmpty) {
        body['tags_link'] = pbIds;
      }
    }
    return body;
  }

  Future<bool> _addPlanningTaskPocket(
    PlanningTask task, {
    required String titleTrimmed,
    required String clientPlanId,
    required Object categoryFieldForPlan,
  }) async {
    final optimisticId = 'optimistic-$clientPlanId';
    applyOptimisticPlanningTask(
      task.copyWith(
        pocketRecordId: optimisticId,
        planRowId: clientPlanId,
        isSynced: false,
      ),
    );
    if (task.startTime != null) {
      final dk = task.dateKey.trim();
      if (dk.length >= 10) {
        final ymd = dk.substring(0, 10).split('-');
        if (ymd.length == 3) {
          final y = int.tryParse(ymd[0]);
          final m = int.tryParse(ymd[1]);
          final d = int.tryParse(ymd[2]);
          if (y != null && m != null && d != null) {
            applySequentialTimeViewCascadeIfNeeded(wallDay: DateTime(y, m, d));
          }
        }
      }
    }
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    late final Map<String, dynamic> body;
    try {
      body = await _buildPocketPlanCreateBody(
        task,
        titleTrimmed: titleTrimmed,
        clientPlanId: clientPlanId,
        categoryFieldForPlan: categoryFieldForPlan,
      );
    } catch (e, st) {
      DatabaseService._log('ADD_PLAN_BUILD_BODY: $e');
      DatabaseService._log(st.toString());
      clearOptimisticPlanningForPlanRow(optimisticId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return false;
    }
    try {
      final record = await _pb
          .collection(PbCollections.plans)
          .create(body: body);
      if (task.tags.isNotEmpty) {
        await _syncPlanTagsPocket(record.id, task.tags);
      }
      final tagCatalog = await _fetchPlanAndListTagCatalog();
      final merged = task.tags.isNotEmpty
          ? await _pb
                .collection(PbCollections.plans)
                .getOne(record.id, expand: kPbPlanTagsExpand)
          : record;
      final fromServer = _planningTaskFromPocketRecord(
        merged,
        pocketTagCatalog: tagCatalog,
      );
      _upsertPlanInUserCache(fromServer);
      _allPlansUserCacheFetchedAt = DateTime.now();
      clearOptimisticPlanningForPlanRow(optimisticId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return true;
    } on ClientException catch (e, st) {
      DatabaseService._log('ADD_PLAN_PB: $e');
      DatabaseService._log(st.toString());
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        await _enqueuePlanCreateMutation(
          body,
          businessId: clientPlanId,
          error: code,
          syncStatus: PlanMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        return true;
      }
      if (_planMutationRetriableHttpCode(code) || _pbHttpBackoffActive) {
        await _enqueuePlanCreateMutation(
          body,
          businessId: clientPlanId,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      clearOptimisticPlanningForPlanRow(optimisticId);
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      return false;
    } catch (e, st) {
      DatabaseService._log('ADD_PLAN_PB: $e');
      DatabaseService._log(st.toString());
      await _enqueuePlanCreateMutation(
        body,
        businessId: clientPlanId,
        error: e,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    }
  }

  Future<bool> addPlanningTask(
    PlanningTask task, {
    String? clientPlanId,
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }
    if (!_isPlansTableConfigured) {
      DatabaseService._log(
        'TABLE_GUARD: blocked addPlanningTask because plans table id equals records table id.',
      );
      AppSnack.failed();
      return false;
    }
    try {
      final catRule = getCategoryRuleById(task.categoryId);
      if (catRule == null) {
        DatabaseService._log(
          'ADD_PLAN: blocked — unknown category local id ${task.categoryId}',
        );
        AppSnack.failed();
        return false;
      }
      // Noco **Link** / FK columns on `plans.category_id` often expect the linked row’s system **Id** (int),
      // not the business slug. Prefer [CategoryRule.nocoId]; fall back to string PK like [addPlan] / DATA_MAP.
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
        DatabaseService._log('ADD_PLAN: blocked — empty title');
        AppSnack.failed();
        return false;
      }
      final cid = (clientPlanId != null && clientPlanId.trim().isNotEmpty)
          ? clientPlanId.trim()
          : DatabaseService._newClientRecordUuid();
      final normalized = _coalescePlanningTaskWallUtcFields(
        task,
        logCreate: task.startTime != null || task.startUtcInstant != null,
        titleForLog: titleTrimmed,
      );
      return _addPlanningTaskPocket(
        normalized,
        titleTrimmed: titleTrimmed,
        clientPlanId: cid,
        categoryFieldForPlan: categoryFieldForPlan,
      );
    } catch (e, st) {
      DatabaseService._log('[ADD_PLAN][FAIL] exception: $e\n$st');
      return false;
    }
  }

  /// Creates a child backlog plan linked via [parent_plan_id] → parent pocket id.
  Future<bool> addBacklogChildPlan({
    required String parentPocketPlanId,
    required String title,
    required int categoryId,
  }) async {
    final parent = parentPocketPlanId.trim();
    final titleTrimmed = title.trim();
    if (parent.isEmpty || titleTrimmed.isEmpty) return false;
    final ord = await nextBacklogPlanningOrder();
    return addPlanningTask(
      PlanningTask(
        id: 0,
        title: titleTrimmed,
        categoryId: categoryId,
        dateKey: '',
        order: ord,
        startTime: null,
        endDateTime: null,
        parentPlanPocketId: parent,
      ),
    );
  }
}
