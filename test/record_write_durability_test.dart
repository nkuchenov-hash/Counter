import 'dart:io';

import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> create(String id) =>
    RecordMutationOutbox.newHighlanderStartItem(
      businessId: id,
      runningFields: <String, dynamic>{
        'record_id': id,
        'title': 'Entry $id',
        'status': 'running',
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('rapid consecutive record creates retain every distinct entry', () async {
    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.generate(50, (i) => 'record-$i');

    await Future.wait(
      ids.map((id) => RecordMutationOutbox.enqueue(prefs, create(id))),
    );
    final queue = await RecordMutationOutbox.load(prefs);
    expect(queue, hasLength(50));
    expect(
      queue.map((item) => item['businessId']).toList(),
      equals(ids),
    );
    expect(
      queue.map((item) => item['operationId']).toSet(),
      hasLength(50),
    );
  });

  test('acknowledging an older POST does not delete a newer POST', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = create('one');
    await RecordMutationOutbox.enqueue(prefs, first);
    final sentSnapshot = await RecordMutationOutbox.load(prefs);

    await RecordMutationOutbox.enqueue(prefs, create('two'));
    expect(
      await RecordMutationOutbox.acknowledge(
        prefs,
        sentSnapshot.first['operationId'] as String,
      ),
      isTrue,
    );
    final left = await RecordMutationOutbox.load(prefs);
    expect(left, hasLength(1));
    expect(left.single['businessId'], 'two');
  });

  test('a stale PATCH acknowledgement never discards a later edit', () async {
    final prefs = await SharedPreferences.getInstance();
    final earlier = RecordMutationOutbox.newRecordUpdateItem(
      businessId: 'record',
      originalQueryId: 'record',
      patchFields: <String, dynamic>{'title': 'Earlier'},
    );
    final later = RecordMutationOutbox.newRecordUpdateItem(
      businessId: 'record',
      originalQueryId: 'record',
      patchFields: <String, dynamic>{'title': 'Latest'},
    );
    await RecordMutationOutbox.enqueue(prefs, earlier);
    await RecordMutationOutbox.enqueue(prefs, later);
    expect(
      await RecordMutationOutbox.acknowledge(
        prefs,
        earlier['operationId'] as String,
      ),
      isFalse,
    );
    final queue = await RecordMutationOutbox.load(prefs);
    expect(queue, hasLength(1));
    expect(queue.single['operationId'], later['operationId']);
    expect((queue.single['payload'] as Map)['title'], 'Latest');
  });

  test('dependent child stop and create retain FIFO across a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final stop = RecordMutationOutbox.newStopPatchItem(
      businessId: 'old-child',
      pocketBaseId: '123456789012345',
      originalQueryId: 'old-child',
      endTimeIso: '2026-10-15T14:00:00.000Z',
    );
    final next = RecordMutationOutbox.newRecordCreateItem(
      businessId: 'new-child',
      fields: <String, dynamic>{
        'record_id': 'new-child',
        'title': 'Next child',
        'parent_id': 'parent',
      },
    );
    await RecordMutationOutbox.enqueueAll(prefs, [stop, next]);

    // SharedPreferences is reconstructed from the persisted mock store.
    final reloadedPrefs = await SharedPreferences.getInstance();
    final queue = await RecordMutationOutbox.load(reloadedPrefs);
    expect(
      queue.map((item) => item['kind']).toList(),
      <String>[
        RecordMutationOutbox.kindStopPatch,
        RecordMutationOutbox.kindRecordCreate,
      ],
    );
    expect((queue.first['payload'] as Map)['end_time'], stop['payload']['end_time']);
    expect((queue.last['payload'] as Map)['title'], 'Next child');
  });

  test('failed sync retains original payload and retry metadata', () async {
    final prefs = await SharedPreferences.getInstance();
    final item = create('offline-record');
    await RecordMutationOutbox.enqueue(prefs, item);
    await RecordMutationOutbox.markFailure(
      prefs,
      item['operationId'] as String,
      error: 'HTTP 503',
    );

    final queue = await RecordMutationOutbox.load(prefs);
    expect(queue, hasLength(1));
    expect(queue.first['retryCount'], 1);
    expect(queue.first['lastError'], 'HTTP 503');
    expect((queue.first['payload'] as Map)['title'], 'Entry offline-record');
  });

  test('a missing category stays in the journal for later resolution', () async {
    final prefs = await SharedPreferences.getInstance();
    final item = RecordMutationOutbox.newHighlanderStartItem(
      businessId: 'category-recovery',
      runningFields: <String, dynamic>{
        'record_id': 'category-recovery',
        'title': 'SNAP ADD SIN Questions',
        'category_id': '912345',
        'status': 'running',
        'start_time': '2026-10-16T18:00:00.000Z',
      },
    );
    await RecordMutationOutbox.enqueue(prefs, item);
    final pending = await RecordMutationOutbox.load(prefs);
    expect((pending.single['payload'] as Map)['category_id'], '912345');
    expect((pending.single['payload'] as Map)['title'], 'SNAP ADD SIN Questions');
  });

  test('a corrupt journal is never silently treated as an empty queue', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'record_mutation_outbox_v1': '{invalid',
    });
    final prefs = await SharedPreferences.getInstance();
    await expectLater(RecordMutationOutbox.load(prefs), throwsFormatException);
    await expectLater(
      RecordMutationOutbox.enqueue(prefs, create('should-not-overwrite')),
      throwsFormatException,
    );
    expect(prefs.getString('record_mutation_outbox_v1'), '{invalid');
  });

  test('unavailable category does not reject record before durable handoff', () {
    final crud = File('lib/data/records/record_crud.dart').readAsStringSync();
    final start = crud.indexOf('Future<String?> writeRecord(');
    final end = crud.indexOf('/// In-memory cache patch', start);
    final body = crud.substring(start, end);
    final catBridge = File('lib/data/categories/category_record_bridge.dart')
        .readAsStringSync();
    expect(body, isNot(contains('cold-start could not resolve category_id')));
    expect(body, contains('_recordCategoryKeyForDurableCreate(cid)'));
    expect(body, contains('_recordCategoryKeyForDurableCreate(cidForCompleted)'));
    expect(body, contains('await _enqueueHighlanderStartMutation(runningFields)'));
    expect(catBridge, contains('final requestedLocalId = int.tryParse('));
  });

  test('quick entry is journaled before submit and restored on reload', () {
    final actions = File('lib/app/shell/shared/shell_task_actions.dart')
        .readAsStringSync();
    final lifecycle = File('lib/app/shell/shared/shell_lifecycle.dart')
        .readAsStringSync();
    final shell = File('lib/app/shell/shared/shell_core.dart')
        .readAsStringSync();
    final start = actions.indexOf('Future<void> startTaskFromInput() async');
    final end = actions.indexOf('Future<void> planTaskFromInput()', start);
    final method = actions.substring(start, end);
    expect(
      method.indexOf('await persistQuickEntryDraft(title)'),
      lessThan(method.indexOf('await DatabaseService.instance.writeRecord(')),
    );
    expect(lifecycle, contains('unawaited(restoreQuickEntryDraft())'));
    expect(lifecycle, contains('titleController.addListener(scheduleQuickEntryDraftWrite)'));
    expect(shell, contains('quickEntryDraftWriteBarrier.then('));
  });

  test('quick entry retains draft until local persistence succeeds', () {
    final source = File('lib/app/shell/shared/shell_task_actions.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> startTaskFromInput() async');
    final end = source.indexOf('Future<void> planTaskFromInput()', start);
    final method = source.substring(start, end);
    final write = method.indexOf('await DatabaseService.instance.writeRecord(');
    final clear = method.indexOf('titleController.clear()');
    expect(write, greaterThanOrEqualTo(0));
    expect(clear, greaterThan(write));
    expect(method, contains('if (titleController.text.trim() == title)'));
    expect(method, contains("'record_create_not_saved'"));
  });

  test('record create does not show generic error toast', () {
    final source = File('lib/data/records/record_crud.dart').readAsStringSync();
    final start = source.indexOf('Future<String?> writeRecord(');
    final end = source.indexOf('/// In-memory cache patch', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, isNot(contains('AppSnack.failed()')));
    expect(method, contains('_showRecordNotSavedError()'));
  });

  test('record write path saves before dispatch and never drops rapid input', () {
    final crud = File('lib/data/records/record_crud.dart').readAsStringSync();
    final sync = File('lib/data/records/record_outbox_helpers.dart')
        .readAsStringSync();
    final outbox = File('lib/data/local_sync/record_mutation_outbox.dart')
        .readAsStringSync();

    final createStart = crud.indexOf('Future<String?> writeRecord(');
    final createEnd = crud.indexOf('/// In-memory cache patch', createStart);
    final body = crud.substring(createStart, createEnd);
    expect(body, isNot(contains('if (_writeRecordMutationInFlight) return null;')));
    expect(body, contains('await _enqueueHighlanderStartMutation(runningFields)'));
    expect(body, contains('await _stageChildRecordHandoff('));
    expect(body, contains('await _enqueueRecordCreateMutation(completedFields)'));
    expect(
      body.indexOf('await _enqueueHighlanderStartMutation(runningFields)'),
      lessThan(body.indexOf('await flushPendingRecordMutations()')),
    );
    expect(sync, contains('await RecordMutationOutbox.enqueueAll(prefs, ['));
    expect(sync, contains('_existingRecordForCreate(businessId)'));
    expect(sync, contains('RecordMutationOutbox.acknowledge(prefs, operationId)'));
    expect(sync, isNot(contains('RecordMutationOutbox.replaceAll(prefs, [])')));
    expect(outbox, contains('static Future<void> enqueueAll('));
  });
}
