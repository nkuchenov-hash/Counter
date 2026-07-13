import 'package:counter/core/services/desktop_voice_contamination_gate.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _scwTree() => CategoryRule(
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
                'en': ['southern computer warehouse'],
              },
              children: [
                CategoryRule(
                  id: 104,
                  name: 'DEL MOD',
                  backendRowId: 'scwdelmod123456',
                ),
              ],
            ),
          ],
        ),
      ],
    );

void main() {
  group('DesktopVoiceContaminationGate', () {
    final rules = [_scwTree()];
    const corrupted =
        'DEL MOD Submit BLINK Laredo Technical Services SELVENT Computer Warehouse DEL MOD Submit';

    test('Scenario F — blocks corrupted live title', () {
      final gate = DesktopVoiceContaminationGate.evaluate(
        transcript: corrupted,
        categoryRules: rules,
      );
      expect(gate.detected, isTrue);
      expect(gate.writeBlocked, isTrue);
      expect(gate.reason, isNotNull);
    });

    test('clean SCW command passes gate', () {
      final gate = DesktopVoiceContaminationGate.evaluate(
        transcript: 'Southern Computer Warehouse DEL MOD submit',
        categoryRules: rules,
      );
      expect(gate.detected, isFalse);
    });

    test('legitimate BLINK command is not blocked as stale fragment', () {
      final blinkRules = [
        CategoryRule(
          id: 300,
          name: 'BLINK',
          backendRowId: 'blinkroot123456',
          children: [
            CategoryRule(
              id: 301,
              name: 'Laredo Technical Services',
              backendRowId: 'blinklaredo1234',
            ),
          ],
        ),
      ];
      final transcript = 'Blink-Lorado Technical Services.';
      final parsed = parseVoiceCommand(
        rules: blinkRules,
        transcript: transcript,
      );
      final gate = DesktopVoiceContaminationGate.evaluate(
        transcript: transcript,
        categoryRules: blinkRules,
        parsed: parsed,
      );
      expect(gate.detected, isFalse);
    });

    test('Scenario A — BLINK then SCW: second must not include BLINK', () {
      const scw =
          'Southern Computer Warehouse, DEL MOD, Submit.';
      final gate = DesktopVoiceContaminationGate.evaluate(
        transcript: scw,
        categoryRules: rules,
        forbiddenFragments: const {'blink', 'laredo'},
      );
      expect(gate.detected, isFalse);
      final parsed = parseVoiceCommand(
        rules: rules,
        transcript: gate.canonicalTranscript,
      );
      expect(
        DesktopVoiceContaminationGate.isUsefulCandidate(
          transcript: gate.canonicalTranscript,
          categoryRules: rules,
          parsed: parsed,
        ),
        isTrue,
      );
      expect(parsed.recordTitle, 'Submit');
      expect(parsed.matchedCategoryDisplayPath, contains('DEL MOD'));
    });

    test('contaminated mega-string is blocked even if parser matches', () {
      final parsed = parseVoiceCommand(
        rules: rules,
        transcript: corrupted,
      );
      expect(
        DesktopVoiceContaminationGate.isUsefulCandidate(
          transcript: corrupted,
          categoryRules: rules,
          parsed: parsed,
        ),
        isFalse,
      );
    });
  });
}
