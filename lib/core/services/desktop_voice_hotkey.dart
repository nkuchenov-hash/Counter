import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/services/desktop_voice_hotkey_stub.dart'
    if (dart.library.io) 'package:counter/core/services/desktop_voice_hotkey_io.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop-only global / in-app hotkey for the Price Reporter voice command panel.
///
/// **Kill switch:** [kDesktopVoiceCommandEnabled] defaults false — no registration
/// unless explicitly enabled via `--dart-define=DESKTOP_VOICE_COMMAND=true`.
abstract final class DesktopVoiceHotkey {
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  static bool get isActive =>
      kDesktopVoiceCommandEnabled && isSupportedPlatform;

  /// Ctrl+Shift+Space — in-app [Shortcuts] activator (fallback + primary when global fails).
  static const SingleActivator inAppActivator = SingleActivator(
    LogicalKeyboardKey.space,
    control: true,
    shift: true,
  );

  static Future<void> attachGlobal({required VoidCallback onToggle}) async {
    if (!isActive) return;
    await registerDesktopVoiceGlobalHotkey(onToggle);
  }

  static Future<void> detachGlobal() async {
    if (!isActive) return;
    await unregisterDesktopVoiceGlobalHotkey();
  }
}
