import 'package:counter/core/services/desktop_voice_command_normalize.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _scwFixtureTree() {
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
            name: 'SOUTHERN COMPUTER WAREHOUSE',
            backendRowId: 'scwclient123456',
            keywords: {
              'en': ['southern computer warehouse', 'scw'],
            },
          ),
        ],
      ),
    ],
  );
}

CategoryRule _flatFixtureTree() {
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

CategoryRule _workPlanningFixtureTree() {
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
            id: 102,
            name: 'Planning',
            backendRowId: 'planningcat1234',
          ),
          CategoryRule(
            id: 101,
            name: 'AGE SOLUTIONS',
            backendRowId: 'ageclient123456',
            keywords: {
              'en': ['age solutions'],
            },
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('P0 desktop voice acceptance — command grammar', () {
    final flatRules = [_flatFixtureTree()];
    final workRules = [_workPlanningFixtureTree()];

    group('flat tree (no Planning child category)', () {
      test('Case A: Price Reporter Planning → root path + Planning title', () {
        final r = parseVoiceCommand(
          rules: flatRules,
          transcript: 'Price Reporter Planning',
        );
        expect(r.confidence, VoiceCommandMatchConfidence.exact);
        expect(r.isSafeToStart, isTrue);
        expect(r.matchedCategoryDisplayPath, 'Price Reporter');
        expect(r.matchedLocalCategoryId, 100);
        expect(r.matchedCategoryPocketBaseId, 'prroot123456789');
        expect(r.recordTitle, 'Planning');
      });

      test('Case B: Price Reporter AGE SOLUTIONS ADD MOD', () {
        final r = parseVoiceCommand(
          rules: flatRules,
          transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
        );
        expect(r.confidence, VoiceCommandMatchConfidence.exact);
        expect(r.isSafeToStart, isTrue);
        expect(r.matchedCategoryDisplayPath, contains('AGE SOLUTIONS'));
        expect(r.matchedLocalCategoryId, 101);
        expect(r.recordTitle, 'ADD MOD');
      });
    });

    group('Work > Price Reporter > Planning child category', () {
      test('Case A: Price Reporter Planning → Planning child category', () {
        final r = parseVoiceCommand(
          rules: workRules,
          transcript: 'Price Reporter Planning',
        );
        expect(r.confidence, VoiceCommandMatchConfidence.exact);
        expect(r.isSafeToStart, isTrue);
        expect(r.matchedCategoryDisplayPath, 'Work > Price Reporter > Planning');
        expect(r.matchedLocalCategoryId, 102);
        expect(r.matchedCategoryPocketBaseId, 'planningcat1234');
        expect(r.recordTitle, 'Planning');
        expect(r.recordTitle, isNot('Price Reporter'));
      });

      test('must not write to parent when Planning child exists', () {
        final r = parseVoiceCommand(
          rules: workRules,
          transcript: 'Price Reporter Planning',
        );
        expect(r.matchedLocalCategoryId, isNot(100));
        expect(r.matchedCategoryDisplayPath, isNot('Work > Price Reporter'));
      });

      test('STT near-miss aliases map to Planning child', () {
        const aliases = [
          'press reporter Planning',
          'prize reporter Planning',
          'price rep Planning',
          'price report Planning',
          'rice reporter planning.',
        ];
        for (final phrase in aliases) {
          final r = parseVoiceCommand(rules: workRules, transcript: phrase);
          expect(r.isSafeToStart, isTrue, reason: phrase);
          expect(
            r.matchedCategoryDisplayPath,
            'Work > Price Reporter > Planning',
            reason: phrase,
          );
          expect(r.recordTitle, 'Planning', reason: phrase);
        }
      });

      test('Porter Plenty STT mis-hear maps to Planning child', () {
        for (final phrase in [
          'Porter Plenty.',
          'Porter Plenty',
          'Importer plenty.',
        ]) {
          final r = parseVoiceCommand(
            rules: workRules,
            transcript: phrase,
          );
          expect(r.isSafeToStart, isTrue, reason: phrase);
          expect(
            r.matchedCategoryDisplayPath,
            'Work > Price Reporter > Planning',
            reason: phrase,
          );
          expect(r.recordTitle, 'Planning', reason: phrase);
        }
      });
    });

    test('play STT near-miss maps to Planning at Price Reporter root', () {
      const aliases = [
        'Right reporter play.',
        'right reporter play',
        'right reporter planning',
        'price reporter play',
        'press reporter play',
        'price rep play',
        'price report play',
        'rice reporter play',
      ];
      for (final phrase in aliases) {
        final r = parseVoiceCommand(rules: flatRules, transcript: phrase);
        expect(r.isSafeToStart, isTrue, reason: phrase);
        expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: phrase);
        expect(r.matchedCategoryDisplayPath, 'Price Reporter', reason: phrase);
        expect(r.recordTitle, 'Planning', reason: phrase);
      }
    });

    test('STT near-miss price report maps to Case B', () {
      final r = parseVoiceCommand(
        rules: flatRules,
        transcript: 'price report AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.recordTitle, 'ADD MOD');
      expect(r.matchedLocalCategoryId, 101);
    });

    test('child-only command uses display name as record title', () {
      final r = parseVoiceCommand(
        rules: flatRules,
        transcript: 'Price Reporter AGE SOLUTIONS',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'AGE SOLUTIONS');
    });

    test('Price Reporter Plenty STT mis-hear maps to Planning', () {
      for (final phrase in ['Price Reporter Plenty', 'Price Reporter plenty']) {
        final r = parseVoiceCommand(rules: flatRules, transcript: phrase);
        expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: phrase);
        expect(r.isSafeToStart, isTrue, reason: phrase);
        expect(r.recordTitle, 'Planning', reason: phrase);
        expect(r.recordTitle, isNot('Plenty'), reason: phrase);
      }
    });

    test('low confidence unsupported command does not start record', () {
      final r = parseVoiceCommand(
        rules: flatRules,
        transcript: 'start random task now',
      );
      expect(r.isSafeToStart, isFalse);
      expect(r.confidence, VoiceCommandMatchConfidence.noMatch);
    });

    test('unknown client text falls back to root record title', () {
      final r = parseVoiceCommand(
        rules: flatRules,
        transcript: 'Price Reporter UNKNOWN CLIENT ADD MOD',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.matchedLocalCategoryId, 100);
      expect(r.recordTitle, 'UNKNOWN CLIENT ADD MOD');
    });
  });

  group('Capture-parity safety — raw garbage STT must not write a record', () {
    final scwRules = [_scwFixtureTree()];

    test('"Solvan Computer Warehouse, Delmore, Submit." is blocked', () {
      // Raw Parakeet output for the SCW phrase on the pre-parity capture.
      // Even if fuzzy matching reaches the SOUTHERN COMPUTER WAREHOUSE client,
      // the unresolved DEL MOD / parent-only echo gate must return null.
      final parsed = parseVoiceCommand(
        rules: scwRules,
        transcript: 'Solvan Computer Warehouse, Delmore, Submit.',
      );
      final normalized = normalizeDesktopVoiceCommand(parsed);
      expect(
        normalized,
        isNull,
        reason: 'no parent-only / low-confidence record from garbage STT',
      );
    });

    test('empty / noise transcript is blocked', () {
      for (final phrase in ['', '   ', 'uh um hmm', 'the and to']) {
        final parsed = parseVoiceCommand(rules: scwRules, transcript: phrase);
        expect(normalizeDesktopVoiceCommand(parsed), isNull, reason: phrase);
      }
    });

    test('parent-only client echo (task lost) is blocked', () {
      // Parser matched the client but the "ADD MOD" task was not extracted,
      // so the title echoes the client leaf — must not write a parent-only
      // record while a command token stays unresolved.
      final parsed = parseVoiceCommand(
        rules: scwRules,
        transcript: 'Price Reporter SOUTHERN COMPUTER WAREHOUSE ADD MOD',
      );
      expect(parsed.recordTitle, 'SOUTHERN COMPUTER WAREHOUSE');
      expect(normalizeDesktopVoiceCommand(parsed), isNull);
    });

    test('clean command with resolved task is allowed (not over-blocked)', () {
      // Same gate must still pass a cleanly parsed task so the parity work does
      // not regress into blocking everything.
      final parsed = parseVoiceCommand(
        rules: [_flatFixtureTree()],
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
      );
      final normalized = normalizeDesktopVoiceCommand(parsed);
      expect(normalized, isNotNull);
      expect(normalized!.effectiveResult.recordTitle, 'ADD MOD');
    });
  });

  group('P0 desktop voice acceptance — confirmation copy', () {
    test('EN confirmation for Case A flat tree', () {
      final r = parseVoiceCommand(
        rules: [_flatFixtureTree()],
        transcript: 'Price Reporter Planning',
      );
      expect(
        voiceCommandStartConfirmationMessage(r, localeCode: 'en'),
        'Started: Price Reporter — Planning',
      );
    });

    test('EN confirmation for Planning child path', () {
      final r = parseVoiceCommand(
        rules: [_workPlanningFixtureTree()],
        transcript: 'Price Reporter Planning',
      );
      expect(
        voiceCommandStartConfirmationMessage(r, localeCode: 'en'),
        'Started: Work > Price Reporter > Planning — Planning',
      );
    });

    test('RU confirmation for Case B', () {
      final r = parseVoiceCommand(
        rules: [_flatFixtureTree()],
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
      );
      expect(
        voiceCommandStartConfirmationMessage(r, localeCode: 'ru'),
        'Запущено: Price Reporter > AGE SOLUTIONS — ADD MOD',
      );
    });
  });
}
