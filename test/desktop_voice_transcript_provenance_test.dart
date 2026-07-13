import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:counter/core/services/desktop_voice_transcript_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provenance logs fragment sources', () {
    DesktopVoiceTranscriptProvenance.logAttemptSummary(
      partialText: 'Logical Marketing Taxis',
      finalText:
          'Logical Marketing, Taxis, and Technical Marketing, and Taxis.',
      cachedCandidate: null,
      effectiveInitialPrompt:
          DesktopVoiceHallucinationGate.neutralWhisperInitialPrompt,
      postprocessedText: null,
      parserInput: null,
      parserPath: null,
      parserTitle: null,
      voiceSessionId: 'vs_test',
    );
    expect(DesktopVoiceHallucinationGate.neutralWhisperInitialPrompt, isNotEmpty);
  });
}
