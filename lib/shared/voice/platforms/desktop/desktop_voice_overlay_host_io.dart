import 'dart:io';

import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_native_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<bool> desktopVoiceShellSuppressed = ValueNotifier(false);

bool _hostActive = false;

/// Safe overlay host — never mutates main Counter window (native HWND is separate).
Future<void> activateDesktopVoiceOverlayHost() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  if (_hostActive) return;
  _hostActive = true;
  DesktopVoicePipeline.mark(
    'DESKTOP_VOICE_OVERLAY_HOST_READY',
    'native_no_main_window_mutation',
  );
}

Future<void> deactivateDesktopVoiceOverlayHost() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  if (!_hostActive) return;
  _hostActive = false;
  desktopVoiceShellSuppressed.value = false;
}

Future<bool> isDesktopMainWindowVisible() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return true;
  }
  try {
    if (Platform.isWindows && DesktopVoiceNativeOverlay.isSupported) {
      return await DesktopVoiceNativeOverlay.isMainWindowVisible();
    }
    return await windowManager.isVisible();
  } catch (_) {
    return true;
  }
}

Future<bool> canShowInAppVoiceOverlay() async => true;

Future<void> notifyTrayOverlayUnavailable() async {
  DesktopVoicePipeline.mark('DESKTOP_VOICE_NOTIFICATION_FALLBACK_USED');
}
