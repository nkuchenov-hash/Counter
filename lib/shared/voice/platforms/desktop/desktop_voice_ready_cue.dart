import 'dart:async';
import 'dart:io';

import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/shared/voice/commands/desktop_voice_capture_ready_policy.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_native_overlay.dart';
import 'package:flutter/foundation.dart';

/// Non-blocking short ready click for Desktop Voice (output only).
///
/// Plays after capture is ready via native Win32 PlaySound (not PowerShell
/// console beep, which is often inaudible / routed wrong). Never blocks the
/// capture thread. Not counted as speech or as STT latency success.
///
/// [playedThisSession] is true only when playback was requested AND output
/// reported success. Silent failures set [outputOk]=false and [lastError].
abstract final class DesktopVoiceReadyCue {
  static bool _playRequested = false;
  static bool _playedThisSession = false;
  static bool _outputOk = false;
  static int? _playedAtMs;
  static String? _lastError;
  static String _outputDevice = 'default';
  static Timer? _armTimer;
  static bool? _smokePass;

  /// Optional override for tests (returns output_ok).
  static Future<bool> Function()? debugPlayOverride;

  static bool get playRequested => _playRequested;
  static bool get playedThisSession => _playedThisSession;
  static bool get outputOk => _outputOk;
  static int? get playedAtMs => _playedAtMs;
  static String? get lastError => _lastError;
  static String get outputDevice => _outputDevice;
  static bool? get cuePlaybackSmokePass => _smokePass;
  static bool get enabled =>
      DesktopVoiceCaptureReadyPolicy.readyCueDefaultEnabled;

  static void resetSession() {
    _armTimer?.cancel();
    _armTimer = null;
    _playRequested = false;
    _playedThisSession = false;
    _outputOk = false;
    _playedAtMs = null;
    _lastError = null;
    _outputDevice = 'default';
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
      cueAlreadyPlayed: _playedThisSession || _playRequested,
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
    if (_playRequested) return;
    _playRequested = true;
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCuePlayRequested,
    );

    var ok = false;
    String? err;
    try {
      if (debugPlayOverride != null) {
        ok = await debugPlayOverride!();
        _outputDevice = 'debug_override';
      } else if (!kIsWeb && Platform.isWindows) {
        final result = await DesktopVoiceNativeOverlay.playReadyCue(
          frequencyHz: DesktopVoiceCaptureReadyPolicy.readyCueFrequencyHz,
          durationMs: DesktopVoiceCaptureReadyPolicy.readyCueDurationMs,
        );
        ok = result.ok;
        err = result.error;
        _outputDevice = result.outputDevice;
      } else {
        err = 'ready_cue_unsupported_platform';
      }
    } catch (e) {
      ok = false;
      err = '$e';
    }

    _outputOk = ok;
    if (!ok && (err == null || err.isEmpty)) {
      err = 'playback_failed';
    }
    _lastError = err;
    if (ok) {
      _playedThisSession = true;
      _playedAtMs = DateTime.now().millisecondsSinceEpoch;
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerCueAfterCaptureReady,
        '${DesktopVoiceCaptureReadyPolicy.readyCueDurationMs}ms',
      );
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerCueAudibleOrError,
        'ok',
      );
    } else {
      _playedThisSession = false;
      _playedAtMs = null;
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerCueAudibleOrError,
        'error:${err ?? 'unknown'}',
      );
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerCueNotSilentlySkipped,
        err ?? 'playback_failed',
      );
    }
    // Always notify so UI can show "Говорите"; only [outputOk] claims audible.
    onPlayed?.call();
  }

  /// Installed-smoke / self-test: play cue once and record pass/fail.
  static Future<bool> runPlaybackSmoke() async {
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCuePlaybackSmoke,
      'start',
    );
    var ok = false;
    String? err;
    try {
      if (debugPlayOverride != null) {
        ok = await debugPlayOverride!();
      } else if (!kIsWeb && Platform.isWindows) {
        final result = await DesktopVoiceNativeOverlay.playReadyCue(
          frequencyHz: DesktopVoiceCaptureReadyPolicy.readyCueFrequencyHz,
          durationMs: DesktopVoiceCaptureReadyPolicy.readyCueDurationMs,
        );
        ok = result.ok;
        err = result.error;
      } else {
        err = 'ready_cue_unsupported_platform';
      }
    } catch (e) {
      ok = false;
      err = '$e';
    }
    _smokePass = ok;
    DesktopVoicePipeline.mark(
      DesktopVoiceCaptureReadyPolicy.markerCuePlaybackSmoke,
      ok ? 'pass' : 'fail:${err ?? 'unknown'}',
    );
    return ok;
  }

  static void cancelArm() {
    _armTimer?.cancel();
    _armTimer = null;
  }
}
