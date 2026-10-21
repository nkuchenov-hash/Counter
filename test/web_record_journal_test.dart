@TestOn('browser')
import 'dart:convert';

import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:counter/data/local_sync/web_record_journal.dart';
import 'package:counter/data/database_service.dart';
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
  test('morning check-in OFF persists in IndexedDB without localStorage writes', () async {
    final key = MorningStartPreference.deviceKey;
    await WebRecordJournal.writePreferenceBool(key, null);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    expect(await MorningStartPreference.isEnabled(null), isTrue);
    await MorningStartPreference.setEnabled(null, false);
    expect(await WebRecordJournal.readPreferenceBool(key), isFalse);
    expect(await MorningStartPreference.isEnabled(null), isFalse);
    // Simulate fresh browser session with a new SharedPreferences instance.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(await MorningStartPreference.isEnabled('another-account'), isFalse);
    await MorningStartPreference.setEnabled(null, true);
    expect(await WebRecordJournal.readPreferenceBool(key), isTrue);
    await WebRecordJournal.writePreferenceBool(key, null);
  });

  test('morning prompt migrates legacy OFF then no longer depends on localStorage', () async {
    final key = MorningStartPreference.deviceKey;
    await WebRecordJournal.writePreferenceBool(key, null);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lifeos.morning_start.old-profile.enabled': false,
    });
    expect(await MorningStartPreference.isEnabled('new-profile'), isFalse);
    expect(await WebRecordJournal.readPreferenceBool(key), isFalse);

    // A stale or malformed browser cache cannot turn a persisted OFF back ON.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lifeos.morning_start.enabled.v2': 'corrupted-not-bool',
    });
    expect(await MorningStartPreference.isEnabled(null), isFalse);
    await MorningStartPreference.setEnabled(null, true);
    expect(await MorningStartPreference.isEnabled(null), isTrue);
    await WebRecordJournal.writePreferenceBool(key, null);
  });

}
