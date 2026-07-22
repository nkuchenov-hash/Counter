import 'dart:async';
import 'dart:io';

import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_capture_ready_policy.dart';
import 'package:counter/core/services/desktop_voice_native_overlay.dart';
import 'package:counter/core/services/desktop_voice_overlay_transparency.dart';
import 'package:counter/core/services/desktop_voice_ready_cue.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart';

/// Windows smoke-test hooks — production hotkey handler only.
abstract final class DesktopVoiceSmokeBridge {
  static Timer? _pollTimer;
  static void Function()? onFireHotkey;

  static bool simulateRunningRecordForPreservedCheck = false;

  static bool get isActive =>
      !kIsWeb &&
      Platform.isWindows &&
      Platform.environment['COUNTER_DESKTOP_VOICE_SMOKE'] == '1';

  static String get _tempDir => Platform.environment['TEMP'] ?? '.';

  static String _triggerPath(String name) =>
      '$_tempDir${Platform.pathSeparator}$name';

  static void attachIfNeeded() {
    if (!isActive) return;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_BRIDGE_ACTIVE');
  }

  static void startPolling() {
    if (!isActive) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _consumeTrigger('counter_voice_smoke_fire.hotkey', () {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HOTKEY_RECEIVED_FROM_NATIVE_TEST_HOOK',
        );
        onFireHotkey?.call();
      });
      _consumeTrigger('counter_voice_smoke_inject_running', () {
        simulateRunningRecordForPreservedCheck = true;
        DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_INJECT_RUNNING');
      });
    });
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<void> ensureVoiceEnabledForSmoke() async {
    if (!isActive) return;
    if (Platform.environment['COUNTER_DESKTOP_VOICE_SMOKE_FORCE_ENABLE'] != '1') {
      return;
    }
    await DesktopVoiceSettings.instance.loadIfNeeded();
    if (!DesktopVoiceSettings.instance.enabled) {
      await DesktopVoiceSettings.instance.setEnabled(true);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_FORCE_ENABLED');
    }
    // Defer UX self-checks slightly so the native channel is bound.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        unawaited(runInstalledUxSmokeChecks());
      }),
    );
  }

  /// Cue playback + overlay transparency self-checks for installed smoke.
  static Future<void> runInstalledUxSmokeChecks() async {
    if (!isActive) return;
    try {
      final cueOk = await DesktopVoiceReadyCue.runPlaybackSmoke();
      DesktopVoicePipeline.mark(
        'cue_playback_smoke_pass',
        cueOk ? 'yes' : 'no',
      );
    } catch (e) {
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerCuePlaybackSmoke,
        'fail:$e',
      );
    }

    try {
      // Briefly show the native pill so layered/transparency metrics are real.
      await DesktopVoiceNativeOverlay.show(
        primary: 'Smoke',
        state: 'listening',
        level: 0,
      );
      final metrics = await DesktopVoiceNativeOverlay.overlayMetrics();
      await DesktopVoiceNativeOverlay.hide();
      final transparent =
          DesktopVoiceNativeOverlay.lastWindowTransparent ||
              (metrics != null &&
                  (metrics['overlay_window_transparent'] == true ||
                      metrics['overlay_window_transparent'] == 'yes'));
      final mode = DesktopVoiceNativeOverlay.lastBackgroundMode.isNotEmpty
          ? DesktopVoiceNativeOverlay.lastBackgroundMode
          : (metrics?['overlay_background_mode']?.toString() ?? '');
      DesktopVoicePipeline.mark(
        'overlay_window_transparent',
        transparent ? 'yes' : 'no',
      );
      DesktopVoicePipeline.mark(
        'overlay_background_mode',
        mode.isEmpty ? 'unknown' : mode,
      );
      if (transparent) {
        DesktopVoicePipeline.mark(
          DesktopVoiceOverlayTransparency.markerTransparentBackground,
        );
        DesktopVoicePipeline.mark(
          DesktopVoiceOverlayTransparency.markerNoBlackBackdrop,
        );
        DesktopVoicePipeline.mark(
          DesktopVoiceOverlayTransparency.markerNoModalDim,
        );
        DesktopVoicePipeline.mark(
          DesktopVoiceOverlayTransparency.markerNativeAlpha,
        );
      } else {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_OVERLAY_TRANSPARENCY_SMOKE',
          'fail:not_transparent',
        );
      }
    } catch (e) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_OVERLAY_TRANSPARENCY_SMOKE',
        'fail:$e',
      );
    }
  }

  static void _consumeTrigger(String fileName, VoidCallback action) {
    final file = File(_triggerPath(fileName));
    if (!file.existsSync()) return;
    try {
      file.deleteSync();
    } catch (_) {}
    action();
  }
}
