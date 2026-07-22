import 'dart:async';
import 'dart:io' show Platform;

import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_native_overlay.dart';
import 'package:counter/core/services/desktop_voice_overlay_constants.dart';
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
    double progress = 0,
  }) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_HOST_REQUESTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NATIVE_OVERLAY_UPDATE', state);

    final ok = await DesktopVoiceNativeOverlay.show(
      primary: primary,
      secondary: secondary,
      state: state,
      level: level,
      timer: timer,
      progress: progress,
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
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_FORBIDDEN_PREPARING_REDIRECTED_TO_LISTENING',
    );
    return showListening(timer: timer);
  }

  static Future<bool> showSpeakReady({String? timer, double level = 0}) async {
    final loc = currentLocale.value;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SPEAK_READY_STATE');
    if (usesNativeOverlay) {
      final ok = await _showNative(
        primary: t(loc, 'desktop_voice_state_speak'),
        state: 'listening',
        level: level,
        timer: timer,
      );
      if (ok) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_OVERLAY_RENDERER_ACTIVE',
          'native_handy_pill',
        );
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerMinFont16);
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerNoTinyText);
        unawaited(_logOverlayMetrics(state: 'listening'));
      }
      return ok;
    }
    return true;
  }

  static Future<bool> showListening({String? timer, double level = 0}) async {
    final loc = currentLocale.value;
    if (usesNativeOverlay) {
      final ok = await _showNative(
        primary: t(loc, 'desktop_voice_state_listening'),
        state: 'listening',
        level: level,
        timer: timer,
      );
      if (ok) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_OVERLAY_RENDERER_ACTIVE',
          'native_handy_pill',
        );
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HANDY_STYLE_LISTENING_PILL_VISIBLE_INSTALLED',
        );
        DesktopVoicePipeline.mark('DESKTOP_VOICE_OLD_GRAY_OVERLAY_NOT_USED');
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerMinFont16);
        DesktopVoicePipeline.mark(
          DesktopVoiceOverlayConstants.markerListeningPill,
        );
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerNoTinyText);
        DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_READABLE_FONT');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CLOSE_BUTTON_CLICKABLE');
        unawaited(_logOverlayMetrics(state: 'listening'));
      }
      return ok;
    }
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_OVERLAY_RENDERER_ACTIVE',
      'flutter_capsule',
    );
    return true;
  }

  static Future<void> updateLevel(double level, {String? timer}) async {
    if (!usesNativeOverlay || !_visible) return;
    final loc = currentLocale.value;
    await _showNative(
      primary: t(loc, 'desktop_voice_state_listening'),
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
        primary: t(loc, 'desktop_voice_transcribing'),
        state: 'processing',
        timer: timer,
      );
    }
    return true;
  }

  static Future<bool> showPendingConfirmation({
    required String previewLine,
    String? hintLine,
    required double progress,
  }) async {
    final loc = currentLocale.value;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STATE_PENDING_CONFIRMATION');
    if (usesNativeOverlay) {
      final ok = await _showNative(
        primary: previewLine,
        secondary: hintLine ?? t(loc, 'desktop_voice_tap_to_edit'),
        state: 'pending',
        timer: '${(progress * 100).round()}%',
        progress: progress,
      );
      if (ok) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_PENDING_CONFIRMATION_READABLE');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_PENDING_FULL_COMMAND_VISIBLE');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_COMMAND_TEXT_CLIPPING');
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_OVERLAY_LAYOUT_NOT_OVERSIZED_NOT_CLIPPED',
        );
        DesktopVoicePipeline.mark(
          DesktopVoiceOverlayConstants.markerPendingCard,
        );
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerMinFont16);
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerNoTinyText);
        DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_READABLE_FONT');
        unawaited(_logOverlayMetrics(state: 'pending'));
      }
      return ok;
    }
    return true;
  }

  static Future<void> updatePendingProgress({
    required String previewLine,
    String? hintLine,
    required double progress,
  }) async {
    if (!usesNativeOverlay || !_visible) return;
    await showPendingConfirmation(
      previewLine: previewLine,
      hintLine: hintLine,
      progress: progress,
    );
  }

  static Future<bool> showStarted({
    required String confirmationLine,
    Duration hold = const Duration(milliseconds: 1600),
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
    final loc = currentLocale.value;
    // Readable error card title — never cram the full error into tiny pill text.
    final title = loc == 'ru' ? 'Не удалось распознать' : 'Could not recognize';
    final body = () {
      final m = message.trim();
      final d = (detail ?? '').trim();
      if (d.isNotEmpty && d != m) return d;
      // Prefer a short secondary line when the mapped message differs from the title.
      if (m.isNotEmpty && m != title) return m;
      return loc == 'ru'
          ? 'Подробности сохранены в диагностике'
          : 'Details saved in diagnostics';
    }();
    if (usesNativeOverlay) {
      final ok = await _showNative(
        primary: title,
        secondary: body,
        state: 'error',
      );
      if (ok) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_HEARD_TEXT_WRAPPED');
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_OVERLAY_LAYOUT_NOT_OVERSIZED_NOT_CLIPPED',
        );
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_CARD_READABLE');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_TINY_ERROR_TEXT_REMOVED');
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerErrorCard);
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerMinFont16);
        DesktopVoicePipeline.mark(DesktopVoiceOverlayConstants.markerNoTinyText);
        DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_READABLE_FONT');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_CLOSE_BUTTON_CLICKABLE');
        unawaited(_logOverlayMetrics(state: 'error'));
      }
      if (!ok) {
        await _notificationFallback(message);
      }
      return ok;
    }
    return true;
  }

  static Future<void> _logOverlayMetrics({required String state}) async {
    try {
      final m = await DesktopVoiceNativeOverlay.overlayMetrics();
      if (m == null) return;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_OVERLAY_METRICS',
        'dpi=${m['overlay_dpi']} scale=${m['overlay_scale_factor']} '
            'w=${m['overlay_width_px']} h=${m['overlay_height_px']} '
            'min_pt=${m['overlay_min_font_pt']} title_pt=${m['overlay_title_font_pt']} '
            'detail_pt=${m['overlay_detail_font_pt']} state=$state',
      );
      final transparent =
          m['overlay_window_transparent'] == true ||
              m['overlay_window_transparent'] == 'yes';
      final mode = m['overlay_background_mode']?.toString() ?? '';
      DesktopVoicePipeline.mark(
        'overlay_window_transparent',
        transparent ? 'yes' : 'no',
      );
      if (mode.isNotEmpty) {
        DesktopVoicePipeline.mark('overlay_background_mode', mode);
      }
      if (transparent) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_OVERLAY_TRANSPARENT_BACKGROUND',
        );
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_NO_BLACK_OVERLAY_BACKDROP',
        );
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_NO_MODAL_DIM_BACKDROP',
        );
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_NATIVE_OVERLAY_ALPHA_ENABLED',
        );
      }
    } catch (_) {}
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
