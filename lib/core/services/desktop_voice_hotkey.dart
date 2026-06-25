import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/services/desktop_voice_hotkey_stub.dart'
    if (dart.library.io) 'package:counter/core/services/desktop_voice_hotkey_io.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop-only global / in-app hotkey for the Price Reporter voice widget.
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

  static bool get isActive {
    if (!kDesktopVoiceCommandEnabled || !isSupportedPlatform) return false;
    return DesktopVoiceSettings.instance.isDesktopVoiceActive;
  }

  static DesktopVoiceHotkeyConfig get currentConfig =>
      DesktopVoiceSettings.instance.hotkey;

  static SingleActivator activatorFromConfig(DesktopVoiceHotkeyConfig config) {
    return SingleActivator(
      config.logicalKey,
      control: config.control,
      shift: config.shift,
      alt: config.alt,
      meta: config.meta,
    );
  }

  static SingleActivator get inAppActivator =>
      activatorFromConfig(currentConfig);

  static Future<bool> attachGlobal({required VoidCallback onToggle}) async {
    if (!isActive) return false;
    return registerDesktopVoiceGlobalHotkey(
      onToggle,
      config: currentConfig,
    );
  }

  static Future<bool> reattachGlobal({required VoidCallback onToggle}) async {
    if (!isActive) {
      await detachGlobal();
      return false;
    }
    await unregisterDesktopVoiceGlobalHotkey();
    return registerDesktopVoiceGlobalHotkey(
      onToggle,
      config: currentConfig,
    );
  }

  static Future<void> detachGlobal() async {
    await unregisterDesktopVoiceGlobalHotkey();
  }
}

/// Hotkey press outcome — Windows Desktop Voice UX state machine.
enum DesktopVoiceHotkeyAction {
  /// State A: idle, no running primary record → open overlay + STT.
  openOverlay,

  /// State B: overlay listening → finish capture and process command.
  finishListening,

  /// Overlay open (preparing / processing / error) → cancel and hide.
  cancelOverlay,

  /// State D/E: running primary record, overlay closed → stop record.
  stopRunningRecord,
}

/// Resolves global hotkey behavior per Desktop Voice UX contract.
DesktopVoiceHotkeyAction resolveDesktopVoiceHotkeyAction({
  required bool overlayOpen,
  required bool overlayListening,
  required bool overlayPreparing,
  required bool overlayProcessing,
  required bool hasRunningRecord,
}) {
  if (overlayOpen && overlayListening) {
    return DesktopVoiceHotkeyAction.finishListening;
  }
  if (overlayOpen && (overlayPreparing || overlayProcessing)) {
    return DesktopVoiceHotkeyAction.cancelOverlay;
  }
  if (overlayOpen) {
    // Error / confirmation / idle-with-overlay → dismiss.
    return DesktopVoiceHotkeyAction.cancelOverlay;
  }
  if (!overlayOpen && hasRunningRecord) {
    return DesktopVoiceHotkeyAction.stopRunningRecord;
  }
  return DesktopVoiceHotkeyAction.openOverlay;
}
