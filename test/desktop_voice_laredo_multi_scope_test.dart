// Multi-scope desktop voice parser tests — Laredo Technical Services + Price
// Reporter regression. Covers Part A of the runtime smoke fix:
//   - "Laredo TS SIN", "Laredo TS scene", "Laredo Technical Services ADD SIN",
//     "Laredo Technical Services add scene" must all resolve to the existing
//     Laredo Technical Services root with canonical SIN / ADD SIN titles.
//   - Price Reporter "Planning" must keep working unchanged.

import 'package:counter/data/models.dart';
import 'package:counter/data/voice/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _priceReporterTree() {
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

CategoryRule _laredoTree() {
  return CategoryRule(
    id: 200,
    name: 'Laredo Technical Services',
    backendRowId: 'laredoroot12345',
    normalizedId: 'laredo_ts',
    children: [
      CategoryRule(
        id: 201,
        name: 'Laredo TS',
        backendRowId: 'laredotsclient1',
        keywords: {
          'en': ['laredo ts'],
        },
      ),
    ],
  );
}

void main() {
  final rules = [_priceReporterTree(), _laredoTree()];

  group('Laredo Technical Services multi-scope acceptance', () {
    test('"Laredo TS SIN" → Laredo TS client + title SIN', () {
      final r = parseVoiceCommand(rules: rules, transcript: 'Laredo TS SIN');
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'SIN');
      expect(r.matchedLocalCategoryId, 201);
      expect(r.matchedCategoryPocketBaseId, 'laredotsclient1');
    });

    test('"Laredo TS scene" → STT near-miss repaired to SIN', () {
      final r = parseVoiceCommand(rules: rules, transcript: 'Laredo TS scene');
      expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: r.ambiguityReason ?? 'no reason');
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'SIN');
      expect(r.matchedLocalCategoryId, 201);
    });

    test('"Laredo Technical Services ADD SIN" → root + canonical ADD SIN', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Laredo Technical Services ADD SIN',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: r.ambiguityReason ?? 'no reason');
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'ADD SIN');
      // No client keyword under the Laredo root named differently → matches root.
      expect(r.matchedLocalCategoryId, 200);
      expect(r.matchedCategoryPocketBaseId, 'laredoroot12345');
    });

    test('"Laredo Technical Services add scene" → phrase repair to ADD SIN', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Laredo Technical Services add scene',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: r.ambiguityReason ?? 'no reason');
      expect(r.isSafeToStart, isTrue);
      expect(r.recordTitle, 'ADD SIN');
      expect(r.matchedLocalCategoryId, 200);
    });

    test('"Laredo Technical Services add seen" → seen-near-miss → ADD SIN', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Laredo Technical Services add seen',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: r.ambiguityReason ?? 'no reason');
      expect(r.recordTitle, 'ADD SIN');
    });

    test('"Laredo TS ad scene" → ad→ADD word repair to ADD SIN', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Laredo TS ad scene',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact, reason: r.ambiguityReason ?? 'no reason');
      expect(r.recordTitle, 'ADD SIN');
    });

    test('"Laredo" alone → root match with empty title (noMatch)', () {
      final r = parseVoiceCommand(rules: rules, transcript: 'Laredo');
      // "laredo" alone is not in the alias map (only "laredo ts" / "laredo
      // technical services"). It should NOT silently start a task.
      expect(r.isSafeToStart, isFalse);
    });

    test('Multi-scope dispatcher prefers an exact match across scopes', () {
      // Should NOT accidentally map a Laredo phrase to a Price Reporter root.
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Laredo Technical Services ADD SIN',
      );
      expect(r.rootLabel, 'Laredo Technical Services');
      expect(r.matchedCategoryPocketBaseId, 'laredoroot12345');
    });
  });

  group('STT repair helpers', () {
    test('repairVoiceCommandTranscript rewrites collapsed Laredo variants', () {
      // "Laredo Technical" / "Laredo tech" lack the trailing category word:
      // they're repaired into the canonical full scope name.
      expect(
        repairVoiceCommandTranscript('Laredo Technical'),
        'Laredo Technical Services',
      );
      expect(
        repairVoiceCommandTranscript('Laredo tech'),
        'Laredo Technical Services',
      );
      // "Laredo TS" is intentionally NOT rewritten — the "Laredo TS" client
      // sub-category's keyword ("laredo ts") handles it directly so the inner
      // category can still be resolved.
      expect(repairVoiceCommandTranscript('Laredo TS'), 'Laredo TS');
    });

    test('repairVoiceCommandTranscript rewrites SIN token near-misses', () {
      expect(repairVoiceCommandTranscript('scene'), 'SIN');
      expect(repairVoiceCommandTranscript('seen'), 'SIN');
      expect(repairVoiceCommandTranscript('sim.'), 'SIN');
      expect(repairVoiceCommandTranscript('sim'), 'SIN');
      expect(repairVoiceCommandTranscript('add scene'), 'ADD SIN');
      expect(repairVoiceCommandTranscript('add seen'), 'ADD SIN');
      expect(repairVoiceCommandTranscript('ad scene'), 'ADD SIN');
    });
  });

  group('Price Reporter regression (must still work after multi-scope refactor)', () {
    test('"Price Reporter Planning" still maps to root 100 / title Planning', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Price Reporter Planning',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.isSafeToStart, isTrue);
      expect(r.matchedLocalCategoryId, 100);
      expect(r.recordTitle, 'Planning');
    });

    test('"Price Reporter AGE SOLUTIONS ADD MOD" still maps to client 101', () {
      final r = parseVoiceCommand(
        rules: rules,
        transcript: 'Price Reporter AGE SOLUTIONS ADD MOD',
      );
      expect(r.confidence, VoiceCommandMatchConfidence.exact);
      expect(r.matchedLocalCategoryId, 101);
      expect(r.recordTitle, 'ADD MOD');
    });
  });
}
