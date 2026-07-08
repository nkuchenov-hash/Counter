import 'dart:io' show Platform;

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Win32 HWND overlay via runner MethodChannel (independent of main Flutter window).
abstract final class DesktopVoiceNativeOverlay {
  static const MethodChannel _channel =
      MethodChannel('counter/desktop_voice_native_overlay');

  static bool _handlerBound = false;

  /// Native X / Escape close → Dart cancel session.
  static void Function()? onCloseRequested;

  static bool get isSupported =>
      !kIsWeb && Platform.isWindows;

  static void _ensureHandler() {
    if (_handlerBound) return;
    _handlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'overlayCloseClicked') {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CANCEL_REQUESTED', 'native_x');
        onCloseRequested?.call();
      } else if (call.method == 'overlayEscapePressed') {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CANCEL_REQUESTED', 'native_escape');
        onCloseRequested?.call();
      } else if (call.method == 'overlayBodyClicked') {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CORRECTION_OPENED', 'native_tap');
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
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_UPDATE_FAILED', '$e');
      return false;
    }
  }

  static Future<void> hide() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('hide');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_HIDDEN');
    } catch (e) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_UPDATE_FAILED', 'hide:$e');
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

  /// DPI / size / font diagnostics from the native overlay HWND.
  static Future<Map<String, Object?>?> overlayMetrics() async {
    if (!isSupported) return null;
    try {
      final v = await _channel.invokeMethod<dynamic>('overlayMetrics');
      if (v is Map) {
        return v.map((k, val) => MapEntry('$k', val));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
