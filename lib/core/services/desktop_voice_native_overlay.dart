import 'dart:io' show Platform;

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_overlay_transparency.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Result of native ready-cue playback.
class DesktopVoiceReadyCuePlayResult {
  const DesktopVoiceReadyCuePlayResult({
    required this.ok,
    this.error,
    this.outputDevice = 'default',
  });

  final bool ok;
  final String? error;
  final String outputDevice;
}

/// Win32 HWND overlay via runner MethodChannel (independent of main Flutter window).
abstract final class DesktopVoiceNativeOverlay {
  static const MethodChannel _channel =
      MethodChannel('counter/desktop_voice_native_overlay');

  static bool _handlerBound = false;

  /// Last transparency snapshot from native metrics / show.
  static bool lastWindowTransparent = false;
  static String lastBackgroundMode =
      DesktopVoiceOverlayTransparency.backgroundModeOpaque;
  static bool lastHasBackdrop = true;
  static bool lastBlackBackdropDetected = true;
  static String lastWindowFlags = '';

  /// Native X / Escape close → Dart cancel session.
  static void Function()? onCloseRequested;

  static bool get isSupported => !kIsWeb && Platform.isWindows;

  static void _ensureHandler() {
    if (_handlerBound) return;
    _handlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'overlayCloseClicked') {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CANCEL_REQUESTED', 'native_x');
        onCloseRequested?.call();
      } else if (call.method == 'overlayEscapePressed') {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_CANCEL_REQUESTED',
          'native_escape',
        );
        onCloseRequested?.call();
      } else if (call.method == 'overlayBodyClicked') {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CORRECTION_TAP', 'native_body');
        onBodyClicked?.call();
      }
    });
  }

  /// Native overlay body click → open correction UI.
  static void Function()? onBodyClicked;

  static Future<bool> show({
    required String primary,
    String? secondary,
    required String state,
    double level = 0,
    String? timer,
    double progress = 0,
  }) async {
    if (!isSupported) return false;
    _ensureHandler();
    try {
      final ok = await _channel.invokeMethod<bool>('show', {
        'primary': primary,
        'secondary': secondary ?? '',
        'state': state,
        'level': level,
        'timer': timer ?? '',
        'progress': progress,
      });
      return ok == true;
    } catch (e) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_NATIVE_OVERLAY_UPDATE_FAILED',
        '$e',
      );
      return false;
    }
  }

  static Future<void> hide() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('hide');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_HIDDEN');
    } catch (e) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_NATIVE_OVERLAY_UPDATE_FAILED',
        'hide:$e',
      );
    }
  }

  static Future<bool> isMainWindowVisible() async {
    if (!isSupported) return true;
    try {
      final v = await _channel.invokeMethod<bool>('isMainWindowVisible');
      return v ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Short ready click via Win32 PlaySound (SND_MEMORY WAV).
  static Future<DesktopVoiceReadyCuePlayResult> playReadyCue({
    required int frequencyHz,
    required int durationMs,
  }) async {
    if (!isSupported) {
      return const DesktopVoiceReadyCuePlayResult(
        ok: false,
        error: 'ready_cue_unsupported_platform',
      );
    }
    _ensureHandler();
    try {
      final v = await _channel.invokeMethod<dynamic>('playReadyCue', {
        'frequencyHz': frequencyHz,
        'durationMs': durationMs,
      });
      if (v is Map) {
        final ok = v['ok'] == true;
        final err = v['error']?.toString();
        final device = v['output_device']?.toString() ?? 'default';
        return DesktopVoiceReadyCuePlayResult(
          ok: ok,
          error: ok ? null : (err ?? 'ready_cue_play_failed'),
          outputDevice: device,
        );
      }
      return const DesktopVoiceReadyCuePlayResult(
        ok: false,
        error: 'ready_cue_bad_response',
      );
    } catch (e) {
      return DesktopVoiceReadyCuePlayResult(ok: false, error: '$e');
    }
  }

  /// DPI / size / font / transparency diagnostics from the native overlay HWND.
  static Future<Map<String, Object?>?> overlayMetrics() async {
    if (!isSupported) return null;
    try {
      final v = await _channel.invokeMethod<dynamic>('overlayMetrics');
      if (v is Map) {
        final map = v.map((k, val) => MapEntry('$k', val));
        _applyTransparencyFromMetrics(map);
        return map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static void _applyTransparencyFromMetrics(Map<String, Object?> map) {
    lastWindowTransparent = map['overlay_window_transparent'] == true ||
        map['overlay_window_transparent'] == 'yes';
    lastBackgroundMode = map['overlay_background_mode']?.toString() ??
        DesktopVoiceOverlayTransparency.backgroundModeOpaque;
    lastHasBackdrop = map['overlay_has_backdrop'] == true ||
        map['overlay_has_backdrop'] == 'yes';
    lastBlackBackdropDetected =
        map['overlay_black_backdrop_detected'] == true ||
            map['overlay_black_backdrop_detected'] == 'yes';
    lastWindowFlags = map['overlay_window_flags']?.toString() ?? '';

    if (DesktopVoiceOverlayTransparency.isTransparentBackground(
      windowTransparent: lastWindowTransparent,
      backgroundMode: lastBackgroundMode,
      hasBackdrop: lastHasBackdrop,
      blackBackdropDetected: lastBlackBackdropDetected,
    )) {
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
    }
  }
}
