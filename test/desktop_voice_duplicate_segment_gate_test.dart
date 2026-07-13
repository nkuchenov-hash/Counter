import 'package:counter/core/services/desktop_voice_transcript_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('duplicate segment gate — comma dedupe', () {
    test('dedupes and Taxis segments', () {
      const raw =
          'Logical Marketing, Taxis, and Technical Marketing, and Taxis.';
      final deduped = DesktopVoiceTranscriptMerge.dedupeCommaSegments(raw);
      expect(deduped.toLowerCase().split('taxis').length - 1, lessThan(2));
      expect(deduped.toLowerCase(), isNot(contains('and taxis')));
    });
  });
}
