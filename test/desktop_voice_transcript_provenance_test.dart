import 'package:counter/core/services/desktop_voice_transcript_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('traceCorruptedLogicalMarketing runs without throw', () {
    expect(
      () => DesktopVoiceTranscriptProvenance.traceCorruptedLogicalMarketing(
        finalText:
            'Logical Marketing, Taxis, and Technical Marketing, and Taxis.',
        partialText: null,
        initialPrompt: 'Price Reporter, Southern Computer Warehouse',
      ),
      returnsNormally,
    );
  });
}
