import 'package:counter/core/services/desktop_stt_diagnostics.dart';
import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_delayed_transcribe.dart';
import 'package:counter/core/services/desktop_voice_user_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopVoiceDelayedTranscribe policy', () {
    test('queues pending WAV when helper is not ready at stop', () {
      expect(
        DesktopVoiceDelayedTranscribe.hasValidPendingWav(
          wavExists: true,
          pcmByteLength: 6400,
          audioLevelSeen: true,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceDelayedTranscribe.shouldQueuePendingWav(
          hasValidPendingWav: true,
          helperFinalReadyAtStop: false,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceDelayedTranscribe.waitBudget(pendingWavQueued: true),
        DesktopVoiceDelayedTranscribe.coldStartMaxWait,
      );
      expect(
        DesktopSttHelperService.kVoiceColdStartMaxWait,
        const Duration(seconds: 45),
      );
    });

    test('uses short wait when helper already ready at stop', () {
      expect(
        DesktopVoiceDelayedTranscribe.shouldQueuePendingWav(
          hasValidPendingWav: true,
          helperFinalReadyAtStop: true,
        ),
        isFalse,
      );
      expect(
        DesktopVoiceDelayedTranscribe.waitBudget(pendingWavQueued: false),
        DesktopVoiceDelayedTranscribe.readyHelperMaxWait,
      );
    });

    test('suppresses false recognizer unavailable after helper ready', () {
      expect(
        DesktopVoiceDelayedTranscribe.suppressFalseRecognizerUnavailable(
          hasValidPendingWav: true,
          helperReadyAfterRecording: true,
        ),
        isTrue,
      );
      final kind = DesktopVoiceUserError.classifySttFailure(
        audioLevelSeen: true,
        errorText: 'Empty transcript',
        transcribeErrorKind: 'empty_transcript',
        helperExists: true,
        modelExists: true,
        helperReady: true,
        finalTranscribeReady: true,
        pendingWavAfterStop: true,
        helperReadyAfterRecording: true,
        delayedTranscribeCalled: true,
      );
      expect(kind, DesktopVoiceFailureKind.sttEmptyTranscript);
      expect(kind, isNot(DesktopVoiceFailureKind.recognizerUnavailable));
    });

    test('still reports recognizer unavailable when helper never becomes ready',
        () {
      final kind = DesktopVoiceUserError.classifySttFailure(
        audioLevelSeen: true,
        errorText: 'STT helper did not respond',
        helperExists: true,
        modelExists: true,
        helperReady: false,
        finalTranscribeReady: false,
        pendingWavAfterStop: true,
        helperReadyAfterRecording: false,
        delayedTranscribeCalled: false,
      );
      expect(kind, DesktopVoiceFailureKind.recognizerUnavailable);
    });

    test('diagnostics expose delayed-transcribe + raw WAV fields', () {
      const diag = DesktopSttDiagnostics(
        latestWavPath: r'C:\Users\nkuch\AppData\Local\Counter\voice_samples\latest_command.wav',
        latestWavExists: true,
        latestRawWavPath:
            r'C:\Users\nkuch\AppData\Local\Counter\voice_samples\latest_command_raw.wav',
        latestRawWavExists: true,
        latestRawWavSampleRate: 48000,
        latestRawWavChannels: 2,
        latestRawWavFormat: 'pcm16',
        latestRawWavDurationMs: 3650,
        processedWavPath:
            r'C:\Users\nkuch\AppData\Local\Counter\voice_samples\latest_command.wav',
        processedWavSampleRate: 16000,
        processedWavChannels: 1,
        pendingWavAfterStop: true,
        helperReadyAfterRecording: true,
        delayedTranscribeCalled: true,
        delayedTranscribeResult: 'success',
        finalText: 'Southern Computer Warehouse Del Mod, submit.',
        finalTranscriptSource: 'parakeet_final',
        overlayRendererActive: 'native_handy_pill',
      );
      final lines = diag.toDiagLines();
      expect(lines, contains('pending_wav_after_stop=yes'));
      expect(lines, contains('helper_ready_after_recording=yes'));
      expect(lines, contains('delayed_transcribe_called=yes'));
      expect(lines, contains('delayed_transcribe_result=success'));
      expect(lines, contains('latest_raw_wav_exists=yes'));
      expect(lines, contains('latest_raw_wav_sample_rate=48000'));
      expect(lines, contains('latest_raw_wav_channels=2'));
      expect(lines, contains('processed_wav_sample_rate=16000'));
      expect(lines, contains('overlay_renderer_active=native_handy_pill'));
      expect(
        lines.any((l) => l.startsWith('latest_raw_wav_path=') && l.contains('latest_command_raw.wav')),
        isTrue,
      );
    });
  });
}
