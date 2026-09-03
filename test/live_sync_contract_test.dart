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
}
