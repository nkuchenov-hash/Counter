import 'package:counter/core/services/desktop_voice_glossary.dart';
import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_voice_test_category_trees.dart';

void main() {
  test('glossary STT prompt is neutral — no domain list', () {
    final pack = DesktopVoiceGlossaryPack.buildFromCategoryRules(
      desktopVoiceLogicalMarketingRules(),
    );
    final prompt = pack.toSttPrompt();
    expect(prompt, DesktopVoiceHallucinationGate.neutralWhisperInitialPrompt);
    expect(prompt.toLowerCase(), isNot(contains('technical marketing')));
    expect(prompt.toLowerCase(), isNot(contains('southern computer')));
  });
}
