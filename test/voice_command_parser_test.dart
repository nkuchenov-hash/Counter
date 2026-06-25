import 'package:counter/data/models.dart';
import 'package:counter/features/shared/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _priceReporterFixtureTree({
  List<CategoryRule>? extraChildren,
}) {
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
      CategoryRule(
        id: 102,
        name: 'BETA CORP',
        backendRowId: 'betaclient12345',
      ),
      if (extraChildren != null) ...extraChildren,
    ],
  );
}

void main() {
  group('VoiceCommandCategoryIndex.fromCategoryRules', () {
    test('finds Price Reporter root and child clients', () {
      final index = VoiceCommandCategoryIndex.fromCategoryRules([
        _priceReporterFixtureTree(),
      ]);
      expect(index, isNotNull);
      expect(index!.rootLabel, 'Price Reporter');
      expect(index.candidates.length, greaterThanOrEqualTo(2));
    });

    test('returns null when root missing', () {
      final index = VoiceCommandCategoryIndex.fromCategoryRules([
        CategoryRule(id: 1, name: 'Other', backendRowId: 'other1234567890'),
      ]);
      expect(index, isNull);
    });
  });

  group('parsePriceReporterVoiceCommand', () {
    late VoiceCommandCategoryIndex index;

    setUp(() {
      index = VoiceCommandCategoryIndex.fromCategoryRules([
        _priceReporterFixtureTree(),
      ])!;
    });

    test('exact match extracts client and record title', () {
      final r = parseVoiceCommand(
        rules: [_priceReporterFixtureTree()],
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryPocketBaseId, 'ageclient123456');
      expect(r.matchedLocalCategoryId, 101);
      expect(r.matchedCategoryDisplayPath, contains('AGE SOLUTIONS'));
      expect(r.recordTitle, 'ADD MOD');
      expect(r.rootLabel, 'Price Reporter');
      expect(r.originalTranscript, 'Price Reporter AGE SOLUTIONS ADD MOD');
    });

    test('STT repair: price report prefix still matches', () {
      final r = parseVoiceCommand(
        rules: [_priceReporterFixtureTree()],
        transcript: 'price report AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.recordTitle, 'ADD MOD');
    });

    test('no match when root scope missing', () {
      final r = parsePriceReporterVoiceCommand(
        index: index,
        transcript: 'AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.noMatch);
      expect(r.isSafeToStart, isFalse);
      expect(r.ambiguityReason, 'missing_root_scope');
    });

    test('no match for unknown client', () {
      final r = parsePriceReporterVoiceCommand(
        index: index,
        transcript: 'Price Reporter UNKNOWN CLIENT ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.matchedLocalCategoryId, 100);
      expect(r.recordTitle, 'UNKNOWN CLIENT ADD MOD');
      expect(r.isSafeToStart, isTrue);
    });

    test('ambiguous when two clients share longest prefix', () {
      final ambiguousIndex = VoiceCommandCategoryIndex.fromCategoryRules([
        _priceReporterFixtureTree(
          extraChildren: [
            CategoryRule(
              id: 103,
              name: 'AGE SOLUTIONS ALT',
              backendRowId: 'agealtclient12345',
              keywords: {'en': ['age solutions']},
            ),
          ],
        ),
      ])!;
      final r = parsePriceReporterVoiceCommand(
        index: ambiguousIndex,
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.ambiguous);
      expect(r.isSafeToStart, isFalse);
      expect(r.ambiguousCandidates, isNotEmpty);
    });

    test('no match when record title missing after client', () {
      final r = parsePriceReporterVoiceCommand(
        index: index,
        transcript: 'Price Reporter AGE SOLUTIONS',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.recordTitle, 'AGE SOLUTIONS');
      expect(r.isSafeToStart, isTrue);
    });

    test('root-only command: Price Reporter Planning', () {
      final r = parseVoiceCommand(
        rules: [_priceReporterFixtureTree()],
        transcript: 'Price Reporter Planning',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedCategoryDisplayPath, 'Price Reporter');
      expect(r.matchedLocalCategoryId, 100);
      expect(r.recordTitle, 'Planning');
    });

    test('alias press reporter Planning', () {
      final r = parseVoiceCommand(
        rules: [_priceReporterFixtureTree()],
        transcript: 'press reporter Planning',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.recordTitle, 'Planning');
    });
  });
}
