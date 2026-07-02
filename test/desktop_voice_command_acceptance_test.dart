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

void main() {
  group('P0 desktop voice acceptance — command grammar', () {
    final rules = [_fixtureTree()];

    test('Case A: Price Reporter Planning → root path + Planning title', () {
      final r = parseVoiceCommand(
        rules: rules,
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
        rules: rules,
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, contains('AGE SOLUTIONS'));
      expect(r.matchedLocalCategoryId, 101);
      expect(r.recordTitle, 'ADD MOD');
    });

    test('STT near-miss aliases still map to Case A', () {
      const aliases = [
        'press reporter Planning',
        'prize reporter Planning',
        'price rep Planning',
        'price report Planning',
        'райсфер Planning',
        'прайс репортер Planning',
      ];
      for (final phrase in aliases) {
        final r = parseVoiceCommand(rules: rules, transcript: phrase);
        expect(
          r.confidence,
          VoiceCommandMatchConfidence.exact,
          reason: 'alias failed: $phrase',
        );
        expect(r.recordTitle, 'Planning', reason: 'alias failed: $phrase');
        expect(
          r.matchedCategoryDisplayPath,
          'Price Reporter',
          reason: 'alias failed: $phrase',
        );
      }
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
        final r = parseVoiceCommand(rules: rules, transcript: phrase);
        expect(r.isSafeToStart, isTrue, reason: phrase);
        expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: phrase);
        expect(r.matchedCategoryDisplayPath, 'Price Reporter', reason: phrase);
        expect(r.recordTitle, 'Planning', reason: phrase);
      }
    });

    test('STT near-miss price report maps to Case B', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'price report AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.recordTitle, 'ADD MOD');
      expect(r.matchedLocalCategoryId, 101);
    });

    test('child-only command uses display name as record title', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Price Reporter AGE SOLUTIONS',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'AGE SOLUTIONS');
    });

    test('Price Reporter Plenty STT mis-hear maps to Planning', () {
      for (final phrase in ['Price Reporter Plenty', 'Price Reporter plenty']) {
        final r = parseVoiceCommand(rules: rules, transcript: phrase);
        expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: phrase);
        expect(r.isSafeToStart, isTrue, reason: phrase);
        expect(r.recordTitle, 'Planning', reason: phrase);
        expect(r.recordTitle, isNot('Plenty'), reason: phrase);
      }
    });

    test('low confidence unsupported command does not start record', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'start random task now',
      );
      expect(r.isSafeToStart, isFalse);
      expect(r.confidence, VoiceCommandMatchConfidence.noMatch);
    });

    test('unknown client text falls back to root record title', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Price Reporter UNKNOWN CLIENT ADD MOD',
      );
      expect(r.isSafeToStart, isTrue);
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.matchedLocalCategoryId, 100);
      expect(r.recordTitle, 'UNKNOWN CLIENT ADD MOD');
    });
  });

  group('P0 desktop voice acceptance — confirmation copy', () {
    test('EN confirmation for Case A', () {
      final r = parseVoiceCommand(
        rules: [_fixtureTree()],
        transcript: 'Price Reporter Planning',
      );
      expect(
        voiceCommandStartConfirmationMessage(r, localeCode: 'en'),
        'Started: Price Reporter — Planning',
      );
    });

    test('RU confirmation for Case B', () {
      final r = parseVoiceCommand(
        rules: [_fixtureTree()],
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
      );
      expect(
        voiceCommandStartConfirmationMessage(r, localeCode: 'ru'),
        'Запущено: Price Reporter > AGE SOLUTIONS — ADD MOD',
      );
    });
  });
}
