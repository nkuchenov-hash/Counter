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

    // Ordinary Plans/Lists still reject empty titles. Only Notes adapt their
    // visually blank title at the persistence boundary.
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

    // An early subscription must stay attached until Brain/profile readiness;
    // it may not emit [] and terminate while startup is still in progress.
    expect(cache, contains('if (!isReady()) return null;'));
    expect(cache, contains('await for (final _ in timeUpdates)'));
    expect(cache, contains('if (next == null)'));
    expect(cache, contains('continue;'));

    // Active state propagation is event-driven by the same cache/realtime bus.
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

    // Online cold-start uncertainty renders Loading, never a fake empty state.
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
}
