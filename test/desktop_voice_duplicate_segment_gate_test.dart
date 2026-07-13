import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_voice_test_category_trees.dart';

void main() {
  test('duplicate title segment blocked', () {
    final r = DesktopVoiceHallucinationGate.evaluate(
      transcript: 'Logical Marketing Taxis and Taxis',
      categoryRules: desktopVoiceLogicalMarketingRules(),
    );
    expect(r.detected, isTrue);
    expect(r.duplicateTokens, isNotEmpty);
  });
}
