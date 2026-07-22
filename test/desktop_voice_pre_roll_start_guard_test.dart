import 'package:counter/shared/voice/platforms/desktop/desktop_voice_audio_presentation.dart';
import 'package:counter/shared/voice/commands/desktop_voice_capture_ready_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice pre-roll / start-trim guard', () {
    test('pre-roll and leading pad constants are in range', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.preRollMs,
        inInclusiveRange(150, 300),
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.sttLeadingPadMs,
        inInclusiveRange(100, 300),
      );
      expect(
        DesktopVoiceCommandEndpoint.prePadMs,
        DesktopVoiceCaptureReadyPolicy.preRollMs,
      );
    });

    test('start trim guard preserves early speech', () {
      // Speech starts at 80ms (1280 samples @16k) — must not trim away start.
      final a = DesktopVoiceCaptureReadyPolicy.guardedTrimStartSample(
        firstSpeechSample: 1280,
        sampleRate: 16000,
      );
      expect(a, 0);
    });

    test('start trim still pads when speech is late', () {
      // Speech at 1.0s — natural pre-pad applies.
      final a = DesktopVoiceCaptureReadyPolicy.guardedTrimStartSample(
        firstSpeechSample: 16000,
        sampleRate: 16000,
        prePadMs: 250,
      );
      expect(a, 16000 - ((16000 * 250) ~/ 1000));
    });

    test('leading silence prepend increases STT copy length', () {
      final pcm = List<int>.filled(32000, 1); // 1s @16k mono pcm16
      final padded = DesktopVoiceCaptureReadyPolicy.prependLeadingSilencePcm16(
        pcm,
        padMs: 200,
      );
      expect(padded.length, greaterThan(pcm.length));
      expect(padded.take(100).every((b) => b == 0), isTrue);
      // Raw body preserved at end.
      expect(padded.sublist(padded.length - 10), pcm.sublist(pcm.length - 10));
    });

    test('trimSilencePcm16 does not throw on short buffer', () {
      final short = List<int>.filled(100, 0);
      expect(
        DesktopVoiceCommandEndpoint.trimSilencePcm16(short),
        same(short),
      );
    });

    test('markers for pre-roll and first phoneme', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.markerPreRoll,
        'DESKTOP_VOICE_PRE_ROLL_BUFFER_ENABLED',
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.markerFirstPhonemeNotTrimmed,
        'DESKTOP_VOICE_FIRST_PHONEME_NOT_TRIMMED',
      );
    });
  });
}
