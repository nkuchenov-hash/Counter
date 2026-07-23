import 'dart:async';
import 'dart:io';

import 'package:counter/core/services/desktop_tray_service_stub.dart'
    if (dart.library.io) 'package:counter/core/services/desktop_tray_service_io.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart';

/// Windows desktop tray + minimize-to-tray behavior.
abstract final class DesktopTrayService {
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  static Future<void> refreshMenuLabels({
    required String showCounter,
    required String startVoice,
    required String stopRecord,
    required String settings,
    required String exitCounter,
  }) async {
    if (!isSupported) return;
    await refreshDesktopTrayMenu(
      showCounter: showCounter,
      startVoice: startVoice,
      stopRecord: stopRecord,
      settings: settings,
      exitCounter: exitCounter,
    );
  }

  static Future<void> initialize({
    required VoidCallback onShowApp,
    required VoidCallback onStartVoice,
    required VoidCallback onStopRunningRecord,
    required VoidCallback onOpenSettings,
    required Future<void> Function() onExitApp,
  }) async {
    if (!isSupported) return;
    await initDesktopTray(
      onShowApp: onShowApp,
      onStartVoice: onStartVoice,
      onStopRunningRecord: onStopRunningRecord,
      onOpenSettings: onOpenSettings,
      onExitApp: onExitApp,
    );
  }

  static Future<void> dispose() => disposeDesktopTray();

  static Future<void> hideMainWindow() => hideDesktopMainWindow();

  static Future<void> showMainWindow() => showDesktopMainWindow();

  static Future<bool> shouldStartHidden() async {
    if (!isSupported) return false;
    await DesktopVoiceSettings.instance.loadIfNeeded();
    if (Platform.executableArguments.contains('--tray') ||
        Platform.executableArguments.contains('--hidden')) {
      return true;
    }
    return DesktopVoiceSettings.instance.launchHidden;
  }

  static Future<void> applyAutostartRegistry() async {
    if (!isSupported) return;
    await applyDesktopAutostartRegistry();
  }
}
