import 'package:counter/shared/voice/commands/desktop_voice_transcript_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopVoiceTranscriptMerge', () {
    test('partial replaces prior hypothesis — no phrase concatenation', () {
      final merged = DesktopVoiceTranscriptMerge.applyPartial(
        previous: 'DEL MOD Submit BLINK Laredo Technical Services',
        partial: 'Southern Computer Warehouse DEL MOD Submit',
      );
      expect(merged, 'Southern Computer Warehouse DEL MOD Submit');
      expect(merged, isNot(contains('BLINK')));
    });

    test('final replaces partial', () {
      final out = DesktopVoiceTranscriptMerge.applyFinal(
        partial: 'Southern Computer Warehouse DEL MOD',
        finalText: 'Southern Computer Warehouse DEL MOD Submit',
      );
      expect(out, 'Southern Computer Warehouse DEL MOD Submit');
    });

    test('dedupe comma segments removes duplicate tail', () {
      const raw =
          'Southern Computer Warehouse, DEL MOD, Submit, BLINK, Laredo Technical Services, SELVENT, Computer Warehouse, DEL MOD, Submit';
      final out = DesktopVoiceTranscriptMerge.dedupeCommaSegments(raw);
      expect(
        RegExp(r'del\s*mod,\s*submit', caseSensitive: false).allMatches(out).length,
        1,
      );
      expect(out.split(',').map((s) => s.trim().toLowerCase()).toSet().length,
          lessThan(raw.split(',').length));
    });

    test('detects repeated DEL MOD Submit suffix', () {
      expect(
        DesktopVoiceTranscriptMerge.hasRepeatedCommandSuffix(
          'DEL MOD Submit BLINK foo DEL MOD Submit',
        ),
        isTrue,
      );
    });
  });
}
