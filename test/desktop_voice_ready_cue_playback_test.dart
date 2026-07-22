import 'package:counter/shared/voice/commands/desktop_voice_capture_ready_policy.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_ready_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    DesktopVoiceReadyCue.debugPlayOverride = null;
    DesktopVoiceReadyCue.resetSession();
  });

  group('DesktopVoiceReadyCue playback honesty', () {
    test('does not report played when playback fails', () async {
      DesktopVoiceReadyCue.debugPlayOverride = () async => false;
      DesktopVoiceReadyCue.armAfterFirstAudio(
        captureStreamStarted: true,
        firstAudioCallbackReceived: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(DesktopVoiceReadyCue.playRequested, isTrue);
      expect(DesktopVoiceReadyCue.outputOk, isFalse);
      expect(DesktopVoiceReadyCue.playedThisSession, isFalse);
      expect(DesktopVoiceReadyCue.lastError, isNotNull);
    });

    test('reports played only when output ok', () async {
      DesktopVoiceReadyCue.debugPlayOverride = () async => true;
      DesktopVoiceReadyCue.armAfterFirstAudio(
        captureStreamStarted: true,
        firstAudioCallbackReceived: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(DesktopVoiceReadyCue.playedThisSession, isTrue);
      expect(DesktopVoiceReadyCue.outputOk, isTrue);
    });

    test('cue smoke self-test exists and records pass/fail', () async {
      DesktopVoiceReadyCue.debugPlayOverride = () async => true;
      final ok = await DesktopVoiceReadyCue.runPlaybackSmoke();
      expect(ok, isTrue);
      expect(DesktopVoiceReadyCue.cuePlaybackSmokePass, isTrue);

      DesktopVoiceReadyCue.debugPlayOverride = () async => false;
      final fail = await DesktopVoiceReadyCue.runPlaybackSmoke();
      expect(fail, isFalse);
      expect(DesktopVoiceReadyCue.cuePlaybackSmokePass, isFalse);
    });

    test('cue is short and not latency/speech', () {
      expect(
        DesktopVoiceCaptureReadyPolicy.isShortCue(
          DesktopVoiceCaptureReadyPolicy.readyCueDurationMs,
        ),
        isTrue,
      );
      expect(DesktopVoiceCaptureReadyPolicy.isCueCountedAsSpeech(), isFalse);
      expect(
        DesktopVoiceCaptureReadyPolicy.isCueCountedAsLatencyPass(),
        isFalse,
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.markerCueAudibleOrError,
        'DESKTOP_VOICE_READY_CUE_AUDIBLE_OR_ERROR',
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.markerCuePlaybackSmoke,
        'DESKTOP_VOICE_READY_CUE_PLAYBACK_SMOKE',
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.markerCueNotSilentlySkipped,
        'DESKTOP_VOICE_READY_CUE_NOT_SILENTLY_SKIPPED',
      );
      expect(
        DesktopVoiceCaptureReadyPolicy.markerNoLongBeep,
        'DESKTOP_VOICE_NO_LONG_START_BEEP',
      );
    });
  });
}
