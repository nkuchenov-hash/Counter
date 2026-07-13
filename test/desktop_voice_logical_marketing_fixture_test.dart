import 'package:counter/core/services/desktop_voice_contamination_gate.dart';
import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:counter/core/services/desktop_voice_useful_candidate_evaluator.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_voice_test_category_trees.dart';

void main() {
  final rules = desktopVoiceLogicalMarketingRules();

  group('DESKTOP_VOICE_LOGICAL_MARKETING_FAILURE_ARCHIVED', () {
    test('clean Logical Marketing Actions → path + title Actions', () {
      final cases = <(String, String)>[
        ('Logical Marketing Actions', 'actions'),
        ('Logical Marketing, Actions.', 'actions'),
        ('Logical Marketing action', 'action'),
      ];
      for (final (transcript, expectedTitle) in cases) {
        final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
          transcript: transcript,
          categoryRules: rules,
        );
        expect(eval.pendingEligible, isTrue, reason: transcript);
        expect(
          eval.matchedPath,
          contains('Logical Marketing'),
          reason: transcript,
        );
        expect(
          (eval.normalizedTitle ?? eval.parseResult?.recordTitle)
              ?.toLowerCase(),
          expectedTitle,
          reason: transcript,
        );
      }
    });

    test('corrupted live failure is blocked — zero useful candidate', () {
      const corrupted =
          'Logical Marketing, Taxis, and Technical Marketing, and Taxis.';
      final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: corrupted,
        categoryRules: rules,
      );
      expect(eval.useful, isFalse);
      expect(eval.pendingEligible, isFalse);
      expect(eval.contaminationDetected, isTrue);
    });

    test('partial Taxis replaced by final Actions', () {
      final partial = 'Logical Marketing Taxis';
      final finalText = 'Logical Marketing Actions';
      final merged = finalText;
      final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: merged,
        categoryRules: rules,
      );
      expect(eval.pendingEligible, isTrue);
      expect(eval.normalizedTitle ?? eval.parseResult?.recordTitle, 'Actions');
      expect(merged, isNot(contains('Taxis')));
      expect(partial, contains('Taxis'));
    });
  });

  group('hallucination gate markers', () {
    test('duplicate Taxis blocked', () {
      final r = DesktopVoiceHallucinationGate.evaluate(
        transcript: 'Logical Marketing Taxis and Taxis',
        categoryRules: rules,
      );
      expect(r.detected, isTrue);
      expect(r.duplicateTokens, contains('taxis'));
    });

    test('Technical Marketing not injected without spoken conflict', () {
      final r = DesktopVoiceHallucinationGate.evaluate(
        transcript: 'Logical Marketing Actions',
        categoryRules: rules,
      );
      expect(r.detected, isFalse);
    });

    test('conflicting Logical + Technical Marketing blocked', () {
      final r = DesktopVoiceHallucinationGate.evaluate(
        transcript:
            'Logical Marketing, Taxis, and Technical Marketing, and Taxis.',
        categoryRules: rules,
      );
      expect(r.detected, isTrue);
    });
  });

  group('initial prompt neutrality', () {
    test('neutral prompt has no domain client names', () {
      final p = DesktopVoiceHallucinationGate.neutralWhisperInitialPrompt
          .toLowerCase();
      expect(p.contains('technical marketing'), isFalse);
      expect(p.contains('logical marketing'), isFalse);
      expect(p.contains('southern computer'), isFalse);
      expect(p.contains('blink'), isFalse);
      expect(p.contains('laredo'), isFalse);
    });
  });

  test('Logical Marketing eval does not bind SCW path', () {
    final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
      transcript: 'Logical Marketing Actions',
      categoryRules: rules,
    );
    expect(eval.matchedPath ?? '', isNot(contains('Southern')));
  });
}
