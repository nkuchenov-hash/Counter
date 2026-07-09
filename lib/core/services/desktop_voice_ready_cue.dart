import 'dart:async';
import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_capture_ready_policy.dart';
import 'package:flutter/foundation.dart';

/// Non-blocking short ready click for Desktop Voice (output only).
///
/// Plays after capture is ready. Never blocks the capture thread.
/// Not counted as speech or as STT latency success.
abstract final class DesktopVoiceReadyCue {
  static bool _playedThisSession = false;
  static bool _outputOk = false;
  static int? _playedAtMs;
  static Timer? _armTimer;

  static bool get playedThisSession => _playedThisSession;
  static bool get outputOk => _outputOk;
  static int? get playedAtMs => _playedAtMs;
  static bool get enabled =>
      DesktopVoiceCaptureReadyPolicy.readyCueDefaultEnabled;

  static void resetSession() {
    _armTimer?.cancel();
    _armTimer = null;
    _playedThisSession = false;
    _outputOk = false;
    _playedAtMs = null;
  }

  /// Arm cue [DesktopVoiceCaptureReadyPolicy.readyCueDelayAfterFirstAudioMs]
  /// after first audio callback. No-op if already armed/played or disabled.
  static void armAfterFirstAudio({
    required bool captureStreamStarted,
    required bool firstAudioCallbackReceived,
    VoidCallback? onPlayed,
  }) {
    if (!DesktopVoiceCaptureReadyPolicy.mayPlayReadyCue(
      captureStreamStarted: captureStreamStarted,
      firstAudioCallbackReceived: firstAudioCallbackReceived,
      cueAlreadyPlayed: _playedThisSession,
      cueEnabled: enabled,
    )) {
      return;
    }
    if (_armTimer != null) return;

    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCaptureReadyBeforeCue,
    );
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerFirstAudioBeforeCue,
    );
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCueNonBlocking,
    );
    DesktopVoicePipeline.mark(DesktopVoiceCaptureReadyPolicy.markerCueShort);
    DesktopVoicePipeline.mark(DesktopVoiceCaptureReadyPolicy.markerNoLongBeep);
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCueNotSpeech,
    );
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCueNotLatency,
    );

    _armTimer = Timer(
      const Duration(
        milliseconds:
            DesktopVoiceCaptureReadyPolicy.readyCueDelayAfterFirstAudioMs,
      ),
      () {
        unawaited(_play(onPlayed: onPlayed));
      },
    );
  }

  static Future<void> _play({VoidCallback? onPlayed}) async {
    if (_playedThisSession) return;
    _playedThisSession = true;
    _playedAtMs = DateTime.now().millisecondsSinceEpoch;
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCueAfterCaptureReady,
      '${DesktopVoiceCaptureReadyPolicy.readyCueDurationMs}ms',
    );
    try {
      if (!kIsWeb && Platform.isWindows) {
        // Detached console beep — output device only, non-blocking.
        await Process.start(
          'powershell',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            '[console]::beep('
                '${DesktopVoiceCaptureReadyPolicy.readyCueFrequencyHz},'
                '${DesktopVoiceCaptureReadyPolicy.readyCueDurationMs})',
          ],
          mode: ProcessStartMode.detached,
        );
        _outputOk = true;
      } else {
        _outputOk = false;
      }
    } catch (_) {
      _outputOk = false;
    }
    onPlayed?.call();
  }

  static void cancelArm() {
    _armTimer?.cancel();
    _armTimer = null;
  }
}
