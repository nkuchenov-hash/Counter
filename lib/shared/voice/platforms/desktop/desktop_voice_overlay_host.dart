import 'package:counter/shared/voice/platforms/desktop/desktop_voice_overlay_host_stub.dart'
    if (dart.library.io) 'package:counter/shared/voice/platforms/desktop/desktop_voice_overlay_host_io.dart';

export 'desktop_voice_overlay_host_stub.dart'
    if (dart.library.io) 'desktop_voice_overlay_host_io.dart'
    show desktopVoiceShellSuppressed;

/// Tray-safe voice overlay host — never mutates the main Counter window.
abstract final class DesktopVoiceOverlayHost {
  static Future<void> activateForVoiceOverlay() =>
      activateDesktopVoiceOverlayHost();

  static Future<void> deactivateAfterVoiceOverlay() =>
      deactivateDesktopVoiceOverlayHost();

  static Future<bool> isMainWindowVisible() => isDesktopMainWindowVisible();

  static Future<bool> canShowInAppOverlay() => canShowInAppVoiceOverlay();

  static Future<void> notifyTrayUnavailable() =>
      notifyTrayOverlayUnavailable();

  static bool get isShellSuppressed => desktopVoiceShellSuppressed.value;

  static void setShellSuppressed(bool value) {
    desktopVoiceShellSuppressed.value = value;
  }
}
