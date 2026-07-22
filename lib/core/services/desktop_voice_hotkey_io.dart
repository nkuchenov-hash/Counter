import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

HotKey? _desktopVoiceGlobalHotKey;

List<HotKeyModifier> _modifiersFromConfig(DesktopVoiceHotkeyConfig config) {
  final mods = <HotKeyModifier>[];
  if (config.control) mods.add(HotKeyModifier.control);
  if (config.shift) mods.add(HotKeyModifier.shift);
  if (config.alt) mods.add(HotKeyModifier.alt);
  if (config.meta) mods.add(HotKeyModifier.meta);
  return mods;
}

Future<bool> registerDesktopVoiceGlobalHotkey(
  VoidCallback onToggle, {
  required DesktopVoiceHotkeyConfig config,
}) async {
  if (!config.isValid) {
    DesktopVoiceSettings.instance.setHotkeyRegistrationError(
      'Invalid hotkey combination',
    );
    return false;
  }
  await unregisterDesktopVoiceGlobalHotkey();
  final hotKey = HotKey(
    key: config.physicalKey,
    modifiers: _modifiersFromConfig(config),
    scope: HotKeyScope.system,
  );
  try {
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) => onToggle(),
    );
    _desktopVoiceGlobalHotKey = hotKey;
    DesktopVoiceSettings.instance.setHotkeyRegistrationError(null);
    return true;
  } catch (e) {
    DesktopVoiceSettings.instance.setHotkeyRegistrationError(e.toString());
    // Pipe-level marker so a failed OS-level hotkey registration is visible in
    // the runtime smoke log (distinguishes "hotkey never registered" from
    // "hotkey registered but user never pressed it").
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_HOTKEY_REGISTER_FAILED',
      e.toString(),
    );
    return false;
  }
}

Future<void> unregisterDesktopVoiceGlobalHotkey() async {
  final hotKey = _desktopVoiceGlobalHotKey;
  if (hotKey == null) return;
  try {
    await hotKeyManager.unregister(hotKey);
  } catch (_) {}
  _desktopVoiceGlobalHotKey = null;
}
