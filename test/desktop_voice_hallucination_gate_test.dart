import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_voice_test_category_trees.dart';

void main() {
  final rules = desktopVoiceLogicalMarketingRules();

  test('corrupted Logical Marketing title blocked', () {
    final r = DesktopVoiceHallucinationGate.evaluate(
      transcript:
          'Logical Marketing - Taxis and Technical Marketing and Taxis',
      categoryRules: rules,
    );
    expect(r.detected, isTrue);
    expect(r.writeBlocked, isTrue);
  });

  test('duplicate segment gate finds repeated taxis', () {
    final tokens = DesktopVoiceHallucinationGate.findDuplicateSignificantTokens(
      'Logical Marketing Taxis and Taxis',
    );
    expect(tokens, contains('taxis'));
  });
}
