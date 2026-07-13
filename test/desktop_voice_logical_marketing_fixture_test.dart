import 'package:counter/core/services/desktop_voice_contamination_gate.dart';
import 'package:counter/core/services/desktop_voice_transcript_merge.dart';
import 'package:counter/core/services/desktop_voice_useful_candidate_evaluator.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _logicalMarketingTree() => CategoryRule(
      id: 400,
      name: 'Logical Marketing',
      backendRowId: 'logicalmkt12345',
    );

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
  group('Logical Marketing — live 34f2a43 corruption', () {
    final rules = [_logicalMarketingTree(), _scwTree()];
    const corrupted =
        'Logical Marketing, Taxis, and Technical Marketing, and Taxis.';
    const clean = 'Logical Marketing Actions';

    test('clean transcript parses path Logical Marketing title Actions', () {
      final parsed = parseVoiceCommand(rules: rules, transcript: clean);
      expect(parsed.confidence, VoiceCommandMatchConfidence.exact);
      expect(parsed.matchedCategoryDisplayPath, 'Logical Marketing');
      expect(parsed.recordTitle, 'Actions');
      final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: clean,
        categoryRules: rules,
      );
      expect(eval.pendingEligible, isTrue);
      expect(eval.contaminationDetected, isFalse);
    });

    test('corrupted live title is blocked — zero useful candidate', () {
      final gate = DesktopVoiceContaminationGate.evaluate(
        transcript: corrupted,
        categoryRules: rules,
      );
      expect(gate.detected, isTrue);
      expect(gate.writeBlocked, isTrue);
      final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: corrupted,
        categoryRules: rules,
      );
      expect(eval.useful, isFalse);
      expect(eval.pendingEligible, isFalse);
    });

    test('partial/final replace — final Actions wins', () {
      const partial = 'Logical Marketing Taxis';
      const finalText = 'Logical Marketing Actions';
      final merged = DesktopVoiceTranscriptMerge.applyFinal(
        partial: partial,
        finalText: finalText,
      );
      expect(merged, finalText);
      final parsed = parseVoiceCommand(rules: rules, transcript: merged);
      expect(parsed.recordTitle, 'Actions');
    });

    test('Scenario A — Logical Marketing then SCW: no LM in SCW', () {
      const scw = 'Southern Computer Warehouse, DEL MOD, Submit.';
      final gate = DesktopVoiceContaminationGate.evaluate(
        transcript: scw,
        categoryRules: rules,
      );
      expect(gate.detected, isFalse);
      expect(scw.toLowerCase(), isNot(contains('logical marketing')));
    });
  });
}
