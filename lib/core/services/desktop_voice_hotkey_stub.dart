import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart';

Future<bool> registerDesktopVoiceGlobalHotkey(
  VoidCallback onToggle, {
  required DesktopVoiceHotkeyConfig config,
}) async =>
    false;

Future<void> unregisterDesktopVoiceGlobalHotkey() async {}
