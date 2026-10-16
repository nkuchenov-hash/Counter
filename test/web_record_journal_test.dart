@TestOn('browser')
import 'dart:convert';

import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:counter/data/local_sync/web_record_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web IndexedDB migrates existing captures and survives reload', () async {
    final legacy = RecordMutationOutbox.newHighlanderStartItem(
      businessId: 'web-legacy-capture',
      runningFields: <String, dynamic>{
        'record_id': 'web-legacy-capture',
        'title': 'SNAP ADD SIN Questions',
        'status': 'running',
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'record_mutation_outbox_v1': jsonEncode([legacy]),
    });
    final prefs = await SharedPreferences.getInstance();

    final first = await RecordMutationOutbox.load(prefs);
    expect(first, hasLength(1));
    expect(first.single['businessId'], 'web-legacy-capture');
    // Legacy data may only be removed after IndexedDB has committed.
    expect(prefs.getString('record_mutation_outbox_v1'), isNull);

    await RecordMutationOutbox.enqueue(
      prefs,
      RecordMutationOutbox.newHighlanderStartItem(
        businessId: 'web-new-capture',
        runningFields: <String, dynamic>{
          'record_id': 'web-new-capture',
          'title': 'AGE Solutions SRP Help',
          'status': 'running',
        },
      ),
    );
    await RecordMutationOutbox.enqueue(
      prefs,
      RecordMutationOutbox.newHighlanderStartItem(
        businessId: 'web-new-capture',
        runningFields: <String, dynamic>{
          'record_id': 'web-new-capture',
          'title': 'AGE Solutions SRP Help',
          'status': 'running',
        },
      ),
    );

    final durableRaw = await WebRecordJournal.readRaw();
    expect(durableRaw, isNotNull);
    expect((jsonDecode(durableRaw!) as List), hasLength(2));
    final reopenedPrefs = await SharedPreferences.getInstance();
    final after = await RecordMutationOutbox.load(reopenedPrefs);
    expect(after.map((e) => e['businessId']), [
      'web-legacy-capture',
      'web-new-capture',
    ]);

    const draftKey = 'test-record-journal-draft';
    expect(await WebRecordJournal.writeDraft(draftKey, 'AGE Solutions SRP Help'), isTrue);
    expect(await WebRecordJournal.readDraft(draftKey), 'AGE Solutions SRP Help');
    expect(await WebRecordJournal.writeDraft(draftKey, ''), isTrue);
    expect(await WebRecordJournal.readDraft(draftKey), isNull);
  });
}
