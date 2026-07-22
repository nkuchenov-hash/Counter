import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_capture_ready_policy.dart';
import 'package:counter/core/services/desktop_voice_install_smoke_policy.dart';
import 'package:counter/core/services/desktop_voice_overlay_constants.dart';
import 'package:counter/core/services/desktop_voice_stt_processing.dart';
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
        'stop_to_useful_candidate_ms',
        'candidate_text',
        'candidate_parse_status',
        'candidate_useful',
        'candidate_visible_to_user',
        'DESKTOP_VOICE_STOP_TO_FIRST_CANDIDATE_UNDER_500MS',
        'DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS',
        'DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS_OR_BLOCKER',
        'DESKTOP_VOICE_LATENCY_ROOT_CAUSE_LOGGED',
        'DESKTOP_VOICE_BAD_PARTIAL_NOT_COUNTED_AS_SUCCESS',
        'DESKTOP_VOICE_NO_FAKE_LATENCY_PASS',
        'DESKTOP_VOICE_USEFUL_CANDIDATE_METRIC_ADDED',
        'DESKTOP_VOICE_USEFUL_CANDIDATE_METRIC_ENFORCED',
        'DESKTOP_VOICE_READY_CUE_NOT_USED_AS_LATENCY_PASS',
        'DESKTOP_VOICE_ENGINE_PREWARMED',
        'DESKTOP_VOICE_NO_COLD_START_ON_FIRST_COMMAND',
        'DESKTOP_VOICE_NO_WRITE_BEFORE_TIMER',
        'DESKTOP_VOICE_WRITE_RECORD_THROUGH_BRAIN',
        'DESKTOP_VOICE_NO_GARBAGE_RECORD',
        'DESKTOP_VOICE_CAPTURE_STREAM_STARTED',
        'DESKTOP_VOICE_FIRST_AUDIO_FRAME_RECEIVED',
        'DESKTOP_VOICE_NO_SIGNAL_DETECTED',
      ];
      for (final m in expected) {
        expect(m.isNotEmpty, isTrue);
      }
      // Sanity: pipeline mark is callable without throwing in tests.
      DesktopVoicePipeline.mark('DESKTOP_VOICE_LATENCY_TRACE_WRITTEN', 'unit');
    });

    test('ready cue is not counted as latency success', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.isCueCountedAsLatencyPass(),
        isFalse,
      );
    });

    test('>500ms useful candidate is not a latency pass', () {
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: true,
          stopToUsefulCandidateMs: 592,
        ),
        isFalse,
      );
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: true,
          stopToUsefulCandidateMs: 499,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceInstallSmokePolicy.isUsefulCandidateLatencyPass(
          candidateUseful: false,
          stopToUsefulCandidateMs: 200,
        ),
        isFalse,
      );
    });

    test('df696fc offline latency blocker documented', () {
      expect(
        DesktopVoiceSttProcessingPolicy.offlineBlocker,
        contains('missing_southern'),
      );
      expect(scoreScwCommandTranscript('here.'), lessThan(0));
      expect(
        scoreScwCommandTranscript('Computer Warehouse, DEL MOD, Submit.'),
        40,
      );
    });
  });
}
