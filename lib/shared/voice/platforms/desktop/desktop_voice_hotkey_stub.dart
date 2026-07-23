import 'package:counter/shared/voice/platforms/desktop/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart';

Future<bool> registerDesktopVoiceGlobalHotkey(
  VoidCallback onToggle, {
  required DesktopVoiceHotkeyConfig config,
}) async =>
    false;

Future<void> unregisterDesktopVoiceGlobalHotkey() async {}
