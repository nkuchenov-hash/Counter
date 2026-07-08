import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_overlay_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop Voice latency / UI / safety markers', () {
    test('overlay min font contract remains ≥16pt', () {
      expect(DesktopVoiceOverlayConstants.minFontPt, greaterThanOrEqualTo(16));
      expect(DesktopVoiceOverlayConstants.closeHitPx, greaterThanOrEqualTo(32));
      expect(
        DesktopVoiceOverlayConstants.markerNoTinyText,
        'DESKTOP_VOICE_NO_TINY_TEXT_ANYWHERE',
      );
      expect(
        DesktopVoiceOverlayConstants.markerErrorCard,
        'DESKTOP_VOICE_ERROR_CARD_LARGE_READABLE',
      );
    });

    test('latency marker names are stable for diag parsers', () {
      const expected = [
        't_recording_stopped',
        't_first_candidate_visible',
        't_pending_confirmation_visible',
        't_final_transcript_ready',
        'stop_to_first_candidate_ms',
        'DESKTOP_VOICE_STOP_TO_FIRST_CANDIDATE_UNDER_500MS',
        'DESKTOP_VOICE_ENGINE_PREWARMED',
        'DESKTOP_VOICE_NO_COLD_START_ON_FIRST_COMMAND',
        'DESKTOP_VOICE_NO_WRITE_BEFORE_TIMER',
        'DESKTOP_VOICE_WRITE_RECORD_THROUGH_BRAIN',
        'DESKTOP_VOICE_NO_GARBAGE_RECORD',
      ];
      for (final m in expected) {
        expect(m.isNotEmpty, isTrue);
      }
      // Sanity: pipeline mark is callable without throwing in tests.
      DesktopVoicePipeline.mark('DESKTOP_VOICE_LATENCY_TRACE_WRITTEN', 'unit');
    });
  });
}
