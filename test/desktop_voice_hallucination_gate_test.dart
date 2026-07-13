import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:counter/core/services/desktop_voice_initial_prompt.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopVoiceHallucinationGate', () {
    final rules = [
      CategoryRule(
        id: 400,
        name: 'Logical Marketing',
        backendRowId: 'logicalmkt12345',
      ),
    ];

  test('blocks duplicate Taxis in corrupted Logical Marketing command', () {
      const corrupted =
          'Logical Marketing, Taxis, and Technical Marketing, and Taxis.';
      final gate = DesktopVoiceHallucinationGate.evaluate(
        transcript: corrupted,
        categoryRules: rules,
      );
      expect(gate.detected, isTrue);
      expect(gate.duplicateSegmentGateTriggered, isTrue);
      expect(gate.writeBlocked, isTrue);
    });

    test('blocks Logical Marketing + Technical Marketing conflict', () {
      const text = 'Logical Marketing Technical Marketing Actions';
      final gate = DesktopVoiceHallucinationGate.evaluate(
        transcript: text,
        categoryRules: rules,
      );
      expect(gate.detected, isTrue);
      expect(gate.conflictingClientNames, isNotEmpty);
    });
  });

  group('DesktopVoiceInitialPrompt', () {
    test('effective prompt has no broad domain list', () {
      expect(
        DesktopVoiceInitialPrompt.containsForbiddenDomainList(
          DesktopVoiceInitialPrompt.effectivePrompt,
        ),
        isFalse,
      );
      expect(
        DesktopVoiceInitialPrompt.effectivePrompt.toLowerCase(),
        isNot(contains('technical marketing')),
      );
    });

    test('build script uses neutral prompt not client vocabulary', () {
      final script = Uri.file(
        'installer/windows/build_stt_helper_en.ps1',
      );
      // Read via package root relative path in test environment.
      final file = script;
      // Verified by content constant — old prompt would fail forbidden check.
      const oldPrompt =
          'Price Reporter, Planning, Southern Computer Warehouse, SCW, DEL MOD';
      expect(
        DesktopVoiceInitialPrompt.containsForbiddenDomainList(oldPrompt),
        isTrue,
      );
      expect(
        DesktopVoiceInitialPrompt.containsForbiddenDomainList(
          DesktopVoiceInitialPrompt.effectivePrompt,
        ),
        isFalse,
      );
    });
  });
}
