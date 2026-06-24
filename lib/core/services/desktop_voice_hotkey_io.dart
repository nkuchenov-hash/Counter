import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

HotKey? _desktopVoiceGlobalHotKey;

Future<void> registerDesktopVoiceGlobalHotkey(VoidCallback onToggle) async {
  if (_desktopVoiceGlobalHotKey != null) return;
  final hotKey = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );
  await hotKeyManager.register(
    hotKey,
    keyDownHandler: (_) => onToggle(),
  );
  _desktopVoiceGlobalHotKey = hotKey;
}

Future<void> unregisterDesktopVoiceGlobalHotkey() async {
  final hotKey = _desktopVoiceGlobalHotKey;
  if (hotKey == null) return;
  try {
    await hotKeyManager.unregister(hotKey);
  } catch (_) {}
  _desktopVoiceGlobalHotKey = null;
}
