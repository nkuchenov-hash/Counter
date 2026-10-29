import 'dart:io';

import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stale acknowledgement cannot delete a newer plan edit', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final first = await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanUpdateItem(
        businessId: 'plan-1',
        originalQueryId: 'plan-1',
        patchFields: <String, dynamic>{'title': 'First'},
      ),
    );
    final latest = await PlanMutationOutbox.enqueue(
      prefs,
      PlanMutationOutbox.newPlanUpdateItem(
        businessId: 'plan-1',
        originalQueryId: 'plan-1',
        patchFields: <String, dynamic>{'title': 'Latest'},
      ),
    );

    expect(await PlanMutationOutbox.acknowledge(prefs, first), isFalse);
    var queue = await PlanMutationOutbox.load(prefs);
    expect(queue, hasLength(1));
    expect((queue.single['payload'] as Map)['title'], 'Latest');

    expect(await PlanMutationOutbox.acknowledge(prefs, latest), isTrue);
    queue = await PlanMutationOutbox.load(prefs);
    expect(queue, isEmpty);
  });

  test('plan create and update stage outbox before PocketBase network', () {
    final service = File('lib/data/plan_service.dart').readAsStringSync();
    final outbox = File(
      'lib/data/plans/plan_outbox_helpers.dart',
    ).readAsStringSync();
    final createStart = service.indexOf('Future<bool> _addPlanningTaskPocket');
    final createStage = service.indexOf(
      'await _enqueuePlanCreateMutation(',
      createStart,
    );
    final createPost = service.indexOf('.create(body: body)', createStart);
    expect(createStage, greaterThan(createStart));
    expect(createStage, lessThan(createPost));

    final updateStart = service.indexOf('Future<bool> updatePlanningTask(');
    final updateStage = service.indexOf(
      'await _stagePlanUpdateWriteAhead(',
      updateStart,
    );
    final updateDispatch = service.indexOf(
      '_patchPlanUpdateNetworkPhase(',
      updateStage,
    );
    expect(updateStage, greaterThan(updateStart));
    expect(updateStage, lessThan(updateDispatch));
    expect(
      outbox,
      contains('await _acknowledgePlanMutation(writeAheadReceipt)'),
    );
    expect(outbox, isNot(contains('await _pbTagRecordIdsFromTags(tags);')));
  });

  test('Notes blank create remains durable without weakening Plans validation', () {
    final notesSource = File(
      'lib/data/plans/notes_brain_helpers.dart',
    ).readAsStringSync();
    final planSource = File('lib/data/plan_service.dart').readAsStringSync();

    expect(
      notesSource,
      contains(
        "const String _notesBlankTitlePersistenceSentinel = '\\u2060';",
      ),
    );
    expect(
      notesSource,
      contains('title: _notesPersistenceTitle(trimmedTitle),'),
    );
    expect(
      notesSource,
      contains('await addPlanningTask(created, clientPlanId: clientPlanId)'),
    );

    expect(planSource, contains('if (titleTrimmed.isEmpty)'));
    expect(planSource, contains('ADD_PLAN: blocked — empty title'));
  });

  test('Notes reconcile optimistic ids and never project title sentinel', () {
    final source = File(
      'lib/data/plans/notes_brain_helpers.dart',
    ).readAsStringSync();

    expect(source, contains('_findCachedNoteTaskForEdit'));
    expect(source, contains("key.startsWith('optimistic-')"));
    expect(
      source,
      contains('planBusinessId: businessId.isEmpty ? null : businessId,'),
    );
    expect(source, contains('final visibleTitle = _notesVisibleTitle('));
    expect(
      source,
      contains('final plain = doc.toPlainText(title: visibleTitle);'),
    );
    expect(
      source,
      contains('title: _notesPersistenceTitle(updated.title),'),
    );
    expect(
      source,
      contains('materialized?.planRowIdForBackend ?? optimisticId'),
    );
  });

  test(
    'realtime is push-first and plan events do not perform tag HTTP fetch',
    () {
      final service = File('lib/data/plan_service.dart').readAsStringSync();
      final handlerStart = service.indexOf('void _onPbPlansSubscriptionEvent(');
      final handlerEnd = service.indexOf(
        'Future<void> _cancelPlansRealtimeSubscription()',
        handlerStart,
      );
      final handler = service.substring(handlerStart, handlerEnd);
      expect(handler, isNot(contains('_fetchPlanAndListTagCatalog')));
      expect(handler, contains('pocketTagCatalog: _userTagsCatalogCache'));

      final core = File('lib/data/db_core.dart').readAsStringSync();
      final foregroundStart = core.indexOf(
        'Future<void> refreshForegroundData()',
      );
      final foregroundEnd = core.indexOf(
        'Future<void> flushPendingLocalMutations()',
        foregroundStart,
      );
      final foreground = core.substring(foregroundStart, foregroundEnd);
      expect(
        foreground.indexOf('_startRecordsRealtimeSubscription()'),
        lessThan(
          foreground.indexOf('_fetchRecordsIntoCache(forceNetwork: true)'),
        ),
      );
      expect(foreground, isNot(contains('Timer.periodic')));

      final catalogs = File(
        'lib/data/realtime/catalog_realtime.dart',
      ).readAsStringSync();
      expect(catalogs, contains('PbCollections.categories'));
      expect(catalogs, contains('PbCollections.tags'));
      expect(catalogs, contains('PbCollections.profiles'));
      expect(catalogs, isNot(contains('Timer.periodic')));
    },
  );

  test('realtime keeps registered bridges across SDK reconnects', () {
    final core = File('lib/data/db_core.dart').readAsStringSync();
    final guardStart = core.indexOf('void _attachPocketBaseRealtimeGuards()');
    final guardEnd = core.indexOf(
      'bool _isRealtimeEndpointUnavailableError',
      guardStart,
    );
    final guard = core.substring(guardStart, guardEnd);
    expect(guard, contains('sdk autoreconnect active'));
    expect(guard, isNot(contains('_scheduleRecordsRealtimeReconnectAfterFailure')));
    expect(guard, isNot(contains('_schedulePlansRealtimeReconnectAfterFailure')));
    expect(guard, isNot(contains('_scheduleCatalogRealtimeReconnectAfterFailure')));

    final foregroundStart = core.indexOf('Future<void> _refreshForegroundDataBody()');
    final foregroundEnd = core.indexOf(
      'Future<void> flushPendingLocalMutations()',
      foregroundStart,
    );
    final foreground = core.substring(foregroundStart, foregroundEnd);
    expect(foreground, contains('final realtimeBridgesRegistered ='));
    expect(foreground, contains('_recordsRealtimeUnsubscribe != null'));
    expect(foreground, contains('_plansRealtimeUnsubscribe != null'));
    expect(foreground, contains('_categoriesRealtimeUnsubscribe != null'));
    expect(foreground, contains('_tagsRealtimeUnsubscribe != null'));
    expect(foreground, contains('_profileRealtimeUnsubscribe != null'));
    expect(foreground, contains('if (!realtimeBridgesRegistered)'));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('pocketbase: ^0.23.3'));
  });

  test('realtime transport gaps converge through PB_CONNECT without polling', () {
    final realtime = File(
      'lib/data/records/record_realtime.dart',
    ).readAsStringSync();
    final core = File('lib/data/db_core.dart').readAsStringSync();

    expect(realtime, contains("'PB_CONNECT'"));
    expect(realtime, contains('_realtimeTransportGapDetected = true;'));
    expect(realtime, contains('_onPocketBaseRealtimeConnect'));
    expect(realtime, contains('_scheduleRealtimeGapCatchUp()'));
    expect(realtime, contains('refreshForegroundData()'));
    expect(realtime, contains('authoritative catch-up armed'));
    expect(realtime, isNot(contains('Timer.periodic')));

    final refreshStart = core.indexOf(
      'Future<void> _refreshForegroundDataBody() async',
    );
    final refreshEnd = core.indexOf(
      'Future<void> flushPendingLocalMutations()',
      refreshStart,
    );
    expect(refreshStart, greaterThanOrEqualTo(0));
    expect(refreshEnd, greaterThan(refreshStart));
    final refresh = core.substring(refreshStart, refreshEnd);

    expect(refresh, contains('_fetchRecordsIntoCache(forceNetwork: true)'));
    expect(refresh, contains('_reconcileDuplicatePrimaryRunningRecords()'));
    expect(refresh, contains('_ensureAllPlansUserCacheFresh(force: true)'));
    expect(refresh, contains('_loadPlanningTasksForToday()'));
    expect(refresh, contains('_loadRulesFromNoco()'));
    expect(refresh, contains('flushPendingLocalMutations()'));
    expect(refresh, isNot(contains('Timer.periodic')));
  });

  test('late plans full-list response preserves newer SSE changes', () {
    final plans = File('lib/data/plan_service.dart').readAsStringSync();
    final cache = File('lib/data/plans/plan_cache_helpers.dart')
        .readAsStringSync();
    expect(cache, contains('_plansFullFetchesInFlight++'));
    expect(plans, contains('_plansRealtimeDuringFullFetch[task.planRowIdForBackend] = task;'));
    expect(plans, contains('_plansRealtimeDuringFullFetch[id] = null;'));
    expect(cache, contains('for (final change in _plansRealtimeDuringFullFetch.entries)'));
    expect(cache, contains('_upsertPlanInUserCache(change.value!)'));
    expect(cache, contains('_removePlanFromUserCache(change.key)'));
    expect(cache, contains('_plansFullFetchesInFlight--'));
    expect(cache, contains('_plansRealtimeDuringFullFetch.clear()'));
  });

  test('overlapping REST responses cannot roll back newer snapshots', () {
    final records = File('lib/data/record_service.dart').readAsStringSync();
    final recordRealtime =
        File('lib/data/records/record_realtime.dart').readAsStringSync();
    final plans = File('lib/data/plans/plan_cache_helpers.dart')
        .readAsStringSync();

    expect(recordRealtime, contains('int _recordsNetworkFetchSequence = 0;'));
    expect(recordRealtime, contains('int _recordsLastAppliedFetchSequence = 0;'));
    expect(records, contains('requestSequence = ++_recordsNetworkFetchSequence'));
    expect(records, contains('requestSequence < _recordsLastAppliedFetchSequence'));
    expect(records, contains('_recordsLastAppliedFetchSequence = requestSequence'));
    expect(records, contains('currentProfileId != pid'));
    // A valid authenticated empty REST list must remove remote-deleted rows.
    expect(records, contains('!_pb.authStore.isValid'));

    expect(plans, contains('int _plansNetworkFetchSequence = 0;'));
    expect(plans, contains('int _plansLastAppliedFetchSequence = 0;'));
    expect(plans, contains('requestSequence = ++_plansNetworkFetchSequence'));
    expect(plans, contains('requestSequence < _plansLastAppliedFetchSequence'));
    expect(plans, contains('_plansLastAppliedFetchSequence = requestSequence'));
    expect(plans, contains('currentProfileId != fetchProfileId'));
  });

  test('timeline stream observes record metadata revisions', () {
    final source = File('lib/data/records/record_cache_helpers.dart')
        .readAsStringSync();
    final start = source.indexOf(
      'String _timelineRecordsStreamDistinctSignature(',
    );
    final end = source.indexOf('debugTimelineRecordsStreamSignatureForDay(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    expect(source.substring(start, end), contains("r['updated']"));
  });

  test('visible Timeline repaints directly on PocketBase cache mutation', () {
    final timeline = File('lib/features/timeline/timeline_view.dart')
        .readAsStringSync();
    final brain = File('lib/data/database_service.dart').readAsStringSync();
    final pageStart = timeline.indexOf('class _TimelinePageState');
    final page = timeline.substring(pageStart);

    expect(page, contains('DatabaseService.instance.timeUpdates.listen'));
    expect(page, contains('_attachLiveTimelineUpdates();'));
    expect(page, contains('if (mounted && widget.isActivePage) setState(() {});'));
    expect(page, contains('DatabaseService.instance.peekTimelineRecordsForDate'));
    expect(page, isNot(contains('_lastCoalescedRecords')));
    expect(page, isNot(contains('recordsStream(_visibleDate)')));
    expect(page, isNot(contains('addPostFrameCallback')));

    // Same-count edit updates and live inserts must also invalidate the
    // cached per-record display VM before notifying an already-open page.
    final emitStart = brain.indexOf('void _emitTimelineRefreshRaw()');
    final emitEnd = brain.indexOf('Future<T> _runBatchedRecordCacheTimelineNotify', emitStart);
    expect(emitStart, greaterThanOrEqualTo(0));
    expect(emitEnd, greaterThan(emitStart));
    expect(brain.substring(emitStart, emitEnd),
        contains('_markTimelineDayIndexDirty();'));
    expect(brain.substring(emitStart, emitEnd),
        contains('_timeUpdateController.add(null);'));
  });

  test('late records full-list response preserves newer SSE changes', () {
    final records = File('lib/data/record_service.dart').readAsStringSync();
    final realtime =
        File('lib/data/records/record_realtime.dart').readAsStringSync();
    expect(records, contains('_recordsFullFetchesInFlight++'));
    expect(records, contains('_replayRecordRealtimeOverFetchedSnapshot()'));
    expect(records, contains('_recordsFullFetchesInFlight--'));
    expect(records, contains('_recordsRealtimeDuringFullFetch.clear()'));
    expect(realtime, contains('_recordsRealtimeDuringFullFetch[rec.id] = rec;'));
    expect(realtime, contains('_recordsRealtimeDuringFullFetch[id] = null;'));
    expect(realtime, contains('suppressTimelineNotify: true'));
  });

  test('repeated reconnects queue a second authoritative pull after in-flight refresh', () {
    final realtime =
        File('lib/data/records/record_realtime.dart').readAsStringSync();
    expect(realtime, contains('_realtimeGapCatchUpInFlight'));
    expect(realtime, contains('final earlierRefresh = _foregroundDataRefreshFuture;'));
    expect(realtime, contains('await earlierRefresh;'));
    expect(realtime, contains('await refreshForegroundData();'));
    expect(realtime, contains('if (_realtimeTransportGapDetected && _isInitialized'));
    expect(realtime, contains('delay: const Duration(seconds: 5)'));
    expect(realtime, isNot(contains('Timer.periodic')));
  });

  test('realtime gap guard ignores intentional PB_CONNECT-only transport', () {
    final realtime = File(
      'lib/data/records/record_realtime.dart',
    ).readAsStringSync();

    expect(realtime, contains("entry.key != 'PB_CONNECT'"));
    expect(realtime, contains('entry.value.isNotEmpty'));
    expect(realtime, contains('_cancelRealtimeRecoverySubscription()'));
    expect(realtime, contains('!_hasAuthenticatedUserId || isPbRealtimeUnavailable'));
  });

  test('open Timeline stays live without navigation, polling, or false empty', () {
    final cache = File(
      'lib/data/records/record_cache_helpers.dart',
    ).readAsStringSync();
    final timeline = File(
      'lib/features/timeline/timeline_day_page.dart',
    ).readAsStringSync();

    expect(cache, contains('if (!isReady()) return null;'));
    expect(cache, contains('await for (final _ in timeUpdates)'));
    expect(cache, contains('if (next == null)'));
    expect(cache, contains('continue;'));

    final activeStart = cache.indexOf(
      'Stream<Map<String, dynamic>?> get activeRecordLiveStream async*',
    );
    expect(activeStart, greaterThanOrEqualTo(0));
    final activeBody = cache.substring(activeStart);
    expect(activeBody, contains('await for (final _ in timeUpdates)'));
    expect(activeBody, isNot(contains('Future.delayed')));
    expect(activeBody, isNot(contains('Timer.periodic')));
    expect(timeline, contains('activeRecordLiveStream.listen'));
    expect(timeline, isNot(contains('activeRecordStream.listen')));

    expect(timeline, contains('!db.recordsSnapshotReadyForDisplay'));
    expect(timeline, contains('return const AppLoading();'));
  });

  test('browser companion uses PocketBase realtime instead of 15-second polling', () {
    final popup = File('browser_extension/popup.js').readAsStringSync();
    final worker = File(
      'browser_extension/service_worker.js',
    ).readAsStringSync();
    final manifest = File('browser_extension/manifest.json').readAsStringSync();

    expect(popup, contains("const RECORDS_REALTIME_TOPIC = 'records/*';"));
    expect(popup, contains(r'new EventSource(`${config.baseUrl}/api/realtime`)'));
    expect(popup, contains("source.addEventListener('PB_CONNECT'"));
    expect(popup, contains('applyRecordRealtimeEvent'));
    expect(popup, isNot(contains('refreshHandle = setInterval')));

    expect(worker, contains("type === 'getLifeOsRealtimeConfig'"));
    expect(worker, contains("auth: readBySuffix('pb_auth')"));
    expect(worker, contains("const POCKETBASE_BASE = 'https://217-114-0-201.sslip.io';"));

    expect(manifest, contains('"version": "0.2.4"'));
    expect(manifest, contains('"https://217-114-0-201.sslip.io/*"'));
    expect(manifest, contains('connect-src \'self\' https://217-114-0-201.sslip.io'));
  });

  test('Plan create cannot POST without a durable recovery receipt', () {
    final source = File('lib/data/plan_service.dart').readAsStringSync();
    final create = source.substring(
      source.indexOf('Future<bool> _addPlanningTaskPocket('),
      source.indexOf('Future<bool> addPlanningTask(',
          source.indexOf('Future<bool> _addPlanningTaskPocket(')),
    );
    final stage = create.indexOf('final writeAheadReceipt =');
    final guard = create.indexOf('if (writeAheadReceipt == null)');
    final post = create.indexOf('.create(body: body)');
    expect(stage, greaterThanOrEqualTo(0));
    expect(guard, greaterThan(stage));
    expect(post, greaterThan(guard));
    expect(create.substring(guard, post),
        contains('_rejectUnstagedPlanCreate(optimisticId)'));
    final helper = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    expect(helper, contains('bool _rejectUnstagedPlanCreate('));
    expect(helper, contains('clearOptimisticPlanningForPlanRow(optimisticId)'));
    expect(helper, contains('return false;'));
  });

  test('Rejected queued plan create remains durable instead of vanishing', () {
    final source = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    final start = source.indexOf(
        'if (kind == PlanMutationOutbox.kindPlanCreate)');
    final end = source.indexOf(
        'if (kind == PlanMutationOutbox.kindPlanUpdate)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final createReplay = source.substring(start, end);
    final clientCatch = createReplay.substring(
      createReplay.indexOf('on ClientException catch'),
      createReplay.indexOf('} catch (e) {',
          createReplay.indexOf('on ClientException catch')),
    );
    expect(clientCatch, contains("offlineSync.setLastError("));
    expect(clientCatch, contains('return false;'));
    expect(clientCatch, isNot(contains('return true;')));
  });

  test('Pending writes retry automatically and Viktor hides storage details', () {
    final shell = File('lib/app/shell/shared/shell_lifecycle.dart')
        .readAsStringSync();
    final manager = File('lib/data/local_sync/sync_manager.dart')
        .readAsStringSync();
    final executor = File('lib/data/ai/viktor_executor.dart')
        .readAsStringSync();
    final status = executor.substring(
        executor.indexOf('String _creationReceipt('),
        executor.indexOf('Future<ViktorBulkPreview> _planBulk('));
    expect(shell, contains('SyncManager.instance.attachIfNeeded()'));
    expect(manager, contains('_stalledDrainAttempts'));
    expect(manager, contains('db.flushPendingLocalMutations()'));
    expect(manager, contains('_schedulePendingDrain(delay: stalled'));
    expect(status, contains('отображение пока не подтверждено'));
    expect(status, contains(r'План «$name» добавлен на $day.'));
    expect(status, isNot(contains('PocketBase')));
  });



  test('Viktor only POSTs valid category relations; queues legacy keys', () {
    final source = File('lib/data/plan_service.dart').readAsStringSync();
    final method = source.substring(
      source.indexOf('Future<bool> addPlanningTask('),
      source.indexOf('Map<String, dynamic> _scalarPatchBodyForPlanningRow('),
    );
    expect(method, contains('resolvePlanCategoryRelationForCreate(catRule)'));
    final categoryLookup = File('lib/data/categories/category_lookup.dart')
        .readAsStringSync();
    expect(categoryLookup, contains('_resolveCategoryRowIdForPb(rule)'));
    expect(categoryLookup, contains('_fetchPbCategorySysIdByCategoryIdField('));
    expect(categoryLookup, contains('resolveQueuedPlanCreateCategory('));
    final replay = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    expect(replay, contains('resolveQueuedPlanCreateCategory('));
    expect(replay, contains("body['category_id'] = category;"));
    expect(method, isNot(contains('catNocoSys')));
    expect(method, contains('allowDeferredCategoryRelation'));
    final create = source.substring(
        source.indexOf('Future<bool> _addPlanningTaskPocket('),
        source.indexOf('Future<bool> addPlanningTask('));
    expect(create, contains('if (!categoryRelationReady) return true;'));
    final resolver = File('lib/data/ai/viktor_executor.dart')
        .readAsStringSync();
    expect(resolver, contains('db.refreshCategoryRulesFromServer()'));
    expect(resolver, contains('createSingleDateOnlyPlan('));
  });

  test('Failed initial plan POST keeps durable write and honest receipt', () {
    final source = File('lib/data/plan_service.dart').readAsStringSync();
    final method = source.substring(
      source.indexOf('Future<bool> _addPlanningTaskPocket('),
      source.indexOf('Future<bool> addPlanningTask('),
    );
    final failure = method.substring(
      method.indexOf('on ClientException catch'),
      method.indexOf('} catch (e, st) {',
          method.indexOf('on ClientException catch')),
    );
    expect(failure, contains('offlineSync.setLastError('));
    expect(failure, contains('return false;'));
    expect(failure, isNot(contains('_acknowledgePlanMutation(')));
    final outbox = File('lib/data/local_sync/plan_mutation_outbox.dart')
        .readAsStringSync();
    expect(outbox, contains('if (!saved) {'));
    final receipts = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    expect(receipts, contains('final queued = _hasPendingPlanMutationForBusinessId(clientPlanId)'));
    expect(receipts, contains('pendingSync: queued || (accepted && !confirmed)'));
    final executor = File('lib/data/ai/viktor_executor.dart')
        .readAsStringSync();
    expect(executor, contains(
        'if (!created.accepted && !created.pendingSync)'));
  });

  test('Viktor requires owned server readback and visible day before success', () {
    final outbox = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    final cache = File('lib/data/plans/plan_cache_helpers.dart')
        .readAsStringSync();
    final dialogue = File('lib/data/ai/viktor_executor.dart')
        .readAsStringSync();
    expect(outbox, contains('_confirmAgentPlanOnRequestedDay(task, clientPlanId)'));
    expect(outbox, contains('getFirstListItem(\'plan_id = "\$id" && user_id = "\$uid"\')'));
    expect(outbox, contains('planningDayTasksSnapshot(day)'));
    expect(outbox, contains("'initial_date_key': targetDay"));
    expect(cache, contains('preserveLocalConfirmedPlansInSnapshot('));
    expect(cache, contains('_plansLocalCommitsDuringFullFetch.values.toList()'));
    expect(dialogue, contains('отображение пока не подтверждено'));
  });

  test('Viktor direct POST and queued replay never race for a new plan', () {
    final plan = File('lib/data/plan_service.dart').readAsStringSync();
    final replay = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    final direct = plan.substring(
      plan.indexOf('Future<bool> _addPlanningTaskPocket('),
      plan.indexOf('Future<bool> addPlanningTask('),
    );
    final lock = direct.indexOf('_directPlanCreatesInFlight.add(clientPlanId)');
    final enqueue = direct.indexOf('final writeAheadReceipt =');
    final release = direct.indexOf('_directPlanCreatesInFlight.remove(clientPlanId)');
    expect(lock, greaterThanOrEqualTo(0));
    expect(enqueue, greaterThan(lock));
    expect(release, greaterThan(enqueue));
    expect(replay, contains('_directPlanCreatesInFlight.contains(receipt.businessId)'));
    expect(replay, contains('break; // normal in-flight work'));
    final chat = File('lib/features/viktor/viktor_chat_page.dart')
        .readAsStringSync();
    final send = chat.substring(chat.indexOf('Future<void> _send() async {'));
    expect(send.indexOf('independentPlan == null && !_settingsReady'),
        greaterThan(send.indexOf('independentDateOnlyPlan(input, profileToday)')));
    final composer = File('lib/features/viktor/viktor_composer.dart')
        .readAsStringSync();
    expect(composer, contains('bool _canSubmitWithoutAiSettings('));
    expect(composer, contains('!_canSubmitWithoutAiSettings(_controller.text)'));
    expect(composer, contains('_canSubmitWithoutAiSettings(value.text)'));
  });

  test('Viktor one-date plan does not double preview or reload the day', () {
    final ui = File('lib/features/viktor/viktor_dialogue_ui_state.dart')
        .readAsStringSync();
    final start = ui.indexOf(
        'Future<void> _createIndependentDateOnlyPlan(');
    final end = ui.indexOf('bool _showCorrectedScheduleDraft(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final fastUi = ui.substring(start, end);
    expect(fastUi, contains('executor.createSingleDateOnlyPlan('));
    expect(fastUi, isNot(contains('executor.describe(')));
    expect(fastUi, isNot(contains('executor.apply(')));

    final executor = File('lib/data/ai/viktor_executor.dart')
        .readAsStringSync();
    final begin = executor.indexOf('Future<String> createSingleDateOnlyPlan(');
    final finish = executor.indexOf('Future<String> apply(', begin);
    expect(begin, greaterThanOrEqualTo(0));
    expect(finish, greaterThan(begin));
    final direct = executor.substring(begin, finish);
    expect(direct, contains('_checkScope(batch, day)'));
    expect(direct, contains('_existingPlan(action)'));
    expect(direct, contains('_createPlan(action, null)'));
    expect(direct, isNot(contains('describe(batch,')));
    expect(direct, isNot(contains('apply(batch,')));
    expect(direct, isNot(contains('getPlanningTasksForWallDate(')));
    expect(executor, isNot(contains('canSave: (rule) =>')));
  });


  test('Agent safely queues unresolved category without invalid POST', () {
    final plans = File('lib/data/plan_service.dart').readAsStringSync();
    final create = plans.substring(
        plans.indexOf('Future<bool> _addPlanningTaskPocket('),
        plans.indexOf('Future<bool> addPlanningTask('));
    final enqueue = create.indexOf('_enqueuePlanCreateMutation(');
    final staged = create.indexOf('if (!categoryRelationReady) return true;');
    final post = create.indexOf('.create(body: body)');
    expect(enqueue, greaterThanOrEqualTo(0));
    expect(staged, greaterThan(enqueue));
    expect(post, greaterThan(staged),
        reason: 'Cannot POST a category business slug as a PB relation');
    final add = plans.substring(plans.indexOf('Future<bool> addPlanningTask('),
        plans.indexOf('/// Flat `plans` scalar PATCH map'));
    expect(add, contains('allowDeferredCategoryRelation = false'));
    expect(add, contains('categoryRelationIdForPlanCreate(catRule.id)'));
    expect(add, contains('categoryRelationReady: categoryRelation != null'));
    final receipt = File('lib/data/plans/plan_outbox_helpers.dart')
        .readAsStringSync();
    expect(receipt, contains('allowDeferredCategoryRelation: true'));
    expect(receipt, contains('final queued = _hasPendingPlanMutationForBusinessId(clientPlanId)'));
    expect(receipt, contains('pendingSync: queued || (accepted && !confirmed)'));
  });

}
