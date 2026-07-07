import 'package:counter/core/services/desktop_voice_record_submit.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _fixtureTree() {
  return CategoryRule(
    id: 100,
    name: 'Price Reporter',
    backendRowId: 'prroot123456789',
    children: [
      CategoryRule(
        id: 101,
        name: 'AGE SOLUTIONS',
        backendRowId: 'ageclient123456',
        keywords: {
          'en': ['age solutions'],
        },
      ),
    ],
  );
}

CategoryRule _scwWorkTree() {
  return CategoryRule(
    id: 10,
    name: 'Work',
    backendRowId: 'workroot1234567',
    children: [
      CategoryRule(
        id: 100,
        name: 'Price Reporter',
        backendRowId: 'prroot123456789',
        children: [
          CategoryRule(
            id: 103,
            name: 'Southern Computer Warehouse',
            backendRowId: 'scwclient123456',
            keywords: {
              'en': ['southern computer warehouse', 'scw'],
            },
            children: [
              CategoryRule(
                id: 104,
                name: 'DEL MOD',
                backendRowId: 'scwdelmod12345',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  final rules = [_fixtureTree()];
  const dateKey = '2026-06-25';
  final fixedNow = DateTime.utc(2026, 6, 25, 12, 0);

  group('DesktopVoiceRecordSubmit — production path', () {
    test('Case A: Price Reporter Planning reaches writeRecord boundary', () async {
      DesktopVoiceWriteRecordRequest? captured;
      var writeCalls = 0;

      final outcome = await DesktopVoiceRecordSubmit.submitTranscript(
        categoryRules: rules,
        transcript: 'Price Reporter Planning',
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecord: (req) async {
          writeCalls++;
          captured = req;
          return 'pbaccept0000001';
        },
      );

      expect(outcome, isNotNull);
      expect(writeCalls, 1);
      expect(outcome!.writeRecordCalled, isTrue);
      expect(captured!.title, 'Planning');
      expect(captured!.categoryId, 100);
      expect(captured!.dateKey, dateKey);
      expect(captured!.explicitStartTime, fixedNow);
      expect(
        outcome.confirmationMessage,
        'Started: Price Reporter — Planning',
      );
    });

    test('Case B: Price Reporter AGE SOLUTIONS ADD MOD', () async {
      DesktopVoiceWriteRecordRequest? captured;

      final outcome = await DesktopVoiceRecordSubmit.submitTranscript(
        categoryRules: rules,
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
        dateKey: dateKey,
        localeCode: 'ru',
        planetaryNow: () => fixedNow,
        writeRecord: (req) async {
          captured = req;
          return 'pbaccept0000002';
        },
      );

      expect(outcome, isNotNull);
      expect(captured!.title, 'ADD MOD');
      expect(captured!.categoryId, 101);
      expect(
        outcome!.confirmationMessage,
        'Запущено: Price Reporter > AGE SOLUTIONS — ADD MOD',
      );
    });

    test('low-confidence command does not call writeRecord', () async {
      var writeCalls = 0;
      final outcome = await DesktopVoiceRecordSubmit.submitTranscript(
        categoryRules: rules,
        transcript: 'random unrelated phrase',
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecord: (_) async {
          writeCalls++;
          return 'pbaccept0000003';
        },
      );
      expect(outcome, isNull);
      expect(writeCalls, 0);
    });

    test('submitParsed rejects unsafe parse without writeRecord', () async {
      var writeCalls = 0;
      final unsafe = parseVoiceCommand(
        rules: rules,
        transcript: 'hello world',
      );
      expect(unsafe.isSafeToStart, isFalse);
      final outcome = await DesktopVoiceRecordSubmit.submitParsed(
        result: unsafe,
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecord: (_) async {
          writeCalls++;
          return 'x';
        },
      );
      expect(outcome, isNull);
      expect(writeCalls, 0);
    });

    test('SCW parent-only with unresolved DEL MOD submit does not writeRecord',
        () async {
      var writeCalls = 0;
      final scwRules = [_scwWorkTree()];
      final parsed = parseVoiceCommand(
        rules: scwRules,
        transcript: 'Solvent computer warehouse still model submit',
      );
      final outcome = await DesktopVoiceRecordSubmit.submitParsed(
        result: parsed,
        dateKey: dateKey,
        localeCode: 'en',
        planetaryNow: () => fixedNow,
        writeRecord: (_) async {
          writeCalls++;
          return 'pbaccept0000004';
        },
      );
      expect(outcome, isNull);
      expect(writeCalls, 0);
    });
  });
}
