import 'dart:async';
import 'dart:io' show Platform;

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_native_overlay.dart';
import 'package:counter/core/services/desktop_voice_overlay_host.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Unified desktop voice overlay API — native Win32 on Windows, in-app fallback elsewhere.
abstract final class DesktopVoiceOverlayService {
  static bool _visible = false;
  static bool _nativeCreated = false;

  static bool get isVisible => _visible;

  static bool get usesNativeOverlay =>
      !kIsWeb && Platform.isWindows && DesktopVoiceNativeOverlay.isSupported;

  static Future<bool> _showNative({
    required String primary,
    String? secondary,
    required String state,
    double level = 0,
    String? timer,
  }) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_HOST_REQUESTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_UPDATE', state);

    final ok = await DesktopVoiceNativeOverlay.show(
      primary: primary,
      secondary: secondary,
      state: state,
      level: level,
      timer: timer,
    );
    if (!ok) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_UPDATE_FAILED', state);
      return false;
    }

    if (!_nativeCreated) {
      _nativeCreated = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_CREATED');
    }

    final mainVisible = await DesktopVoiceNativeOverlay.isMainWindowVisible();
    if (mainVisible) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_SHOWN');
    } else {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_NATIVE_OVERLAY_SHOWN_WHILE_TRAY_HIDDEN',
      );
    }
    _visible = true;
    return true;
  }

  static Future<void> _notificationFallback(String message) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NOTIFICATION_FALLBACK_USED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OS_NOTIFICATION_REQUESTED', 'fallback');
    final ok = await NotificationService.instance
        .showDesktopVoiceOverlayUnavailable(message: message);
    if (!ok) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_OS_NOTIFICATION_FAILED', 'fallback');
    }
  }

  static Future<bool> showPreparing({String? timer}) async {
    final loc = currentLocale.value;
    if (usesNativeOverlay) {
      return _showNative(
        primary: t(loc, 'desktop_voice_overlay_stt_warming'),
        state: 'preparing',
        timer: timer,
      );
    }
    return true;
  }

  static Future<bool> showListening({String? timer, double level = 0}) async {
    final loc = currentLocale.value;
    if (usesNativeOverlay) {
      return _showNative(
        primary: t(loc, 'desktop_voice_overlay_listening_hint'),
        state: 'listening',
        level: level,
        timer: timer,
      );
    }
    return true;
  }

  static Future<void> updateLevel(double level, {String? timer}) async {
    if (!usesNativeOverlay || !_visible) return;
    final loc = currentLocale.value;
    await _showNative(
      primary: t(loc, 'desktop_voice_overlay_listening_hint'),
      state: 'listening',
      level: level,
      timer: timer,
    );
  }

  static Future<bool> showProcessing({
    String? transcript,
    String? timer,
  }) async {
    final loc = currentLocale.value;
    if (usesNativeOverlay) {
      return _showNative(
        primary: t(loc, 'desktop_voice_parsing'),
        secondary: transcript,
        state: 'processing',
        timer: timer,
      );
    }
    return true;
  }

  static Future<bool> showStarted({
    required String confirmationLine,
    Duration hold = const Duration(seconds: 2),
  }) async {
    final loc = currentLocale.value;
    if (usesNativeOverlay) {
      final ok = await _showNative(
        primary: t(loc, 'desktop_voice_state_started'),
        secondary: confirmationLine,
        state: 'started',
      );
      if (ok) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_CONFIRMATION_SHOWN');
        unawaited(Future<void>.delayed(hold, hide));
      }
      return ok;
    }
    return true;
  }

  static Future<bool> showStopped({
    required String titleLine,
    Duration hold = const Duration(seconds: 2),
  }) async {
    final loc = currentLocale.value;
    final primary =
        loc == 'ru' ? 'Остановлено' : 'Stopped';
    if (usesNativeOverlay) {
      final ok = await _showNative(
        primary: primary,
        secondary: titleLine.trim().isEmpty ? null : titleLine.trim(),
        state: 'stopped',
      );
      if (ok) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_CONFIRMATION_SHOWN');
        unawaited(Future<void>.delayed(hold, hide));
      }
      return ok;
    }
    return true;
  }

  static Future<bool> showError({
    required String message,
    String? detail,
  }) async {
    if (usesNativeOverlay) {
      final ok = await _showNative(
        primary: message,
        secondary: detail,
        state: 'error',
      );
      if (!ok) {
        await _notificationFallback(message);
      }
      return ok;
    }
    return true;
  }

  static Future<void> hide() async {
    _visible = false;
    if (usesNativeOverlay) {
      await DesktopVoiceNativeOverlay.hide();
    }
    await DesktopVoiceOverlayHost.deactivateAfterVoiceOverlay();
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_HIDDEN');
  }

  /// Force-hide overlay on timeout/cancel/error — never leaves orphan HWND.
  static Future<void> forceHide() async {
    _visible = false;
    if (usesNativeOverlay) {
      try {
        await DesktopVoiceNativeOverlay.hide();
      } catch (_) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_FORCE_HIDE');
      }
    }
    await DesktopVoiceOverlayHost.deactivateAfterVoiceOverlay();
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_HIDDEN', 'force');
  }

  /// Emergency fallback when native overlay cannot be created at session start.
  static Future<void> notifyNativeOverlayUnavailable() async {
    final loc = currentLocale.value;
    final message = loc == 'ru'
        ? 'Не удалось показать голосовой оверлей.'
        : 'Could not show the voice overlay.';
    await _notificationFallback(message);
  }
}
