import 'package:counter/core/services/desktop_voice_capture_ready_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice capture ready cue policy', () {
    test('cue only after capture stream and first audio callback', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.mayPlayReadyCue(
          captureStreamStarted: false,
          firstAudioCallbackReceived: true,
          cueAlreadyPlayed: false,
          cueEnabled: true,
        ),
        isFalse,
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.mayPlayReadyCue(
          captureStreamStarted: true,
          firstAudioCallbackReceived: false,
          cueAlreadyPlayed: false,
          cueEnabled: true,
        ),
        isFalse,
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.mayPlayReadyCue(
          captureStreamStarted: true,
          firstAudioCallbackReceived: true,
          cueAlreadyPlayed: false,
          cueEnabled: true,
        ),
        isTrue,
      );
    });

    test('recording must start before cue', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.recordingStartedBeforeCue(
          captureStreamStartedMs: 1000,
          readyCuePlayedMs: 1150,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.recordingStartedBeforeCue(
          captureStreamStartedMs: 1200,
          readyCuePlayedMs: 1150,
        ),
        isFalse,
      );
    });

    test('first audio must precede cue', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.firstAudioBeforeCue(
          firstAudioCallbackMs: 1050,
          readyCuePlayedMs: 1200,
        ),
        isTrue,
      );
    });

    test('cue is short 30–60ms, not long beep', () {
      expect(DesktopVoiceCaptureReadyPolicy.isShortCue(45), isTrue);
      expect(DesktopVoiceCaptureReadyPolicy.isShortCue(1000), isFalse);
      expect(
        DesktopVoiceCaptureReadyPolicy.readyCueDurationMs,
        inInclusiveRange(30, 60),
      );
    });

    test('cue is not speech and not latency pass', () {
      expect(DesktopVoiceCaptureReadyPolicy.isCueCountedAsSpeech(), isFalse);
      expect(
        DesktopVoiceCaptureReadyPolicy.isCueCountedAsLatencyPass(),
        isFalse,
      );
    });

    test('required markers are stable', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.markerCaptureReadyBeforeCue,
        'DESKTOP_VOICE_CAPTURE_READY_BEFORE_CUE',
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.markerCueNotLatency,
        'DESKTOP_VOICE_READY_CUE_NOT_USED_AS_LATENCY_PASS',
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.markerNoLongBeep,
        'DESKTOP_VOICE_NO_LONG_START_BEEP',
      );
    });
  });
}
