import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Keeps the Counter window above others while the desktop voice overlay is open.
Future<void> setDesktopVoiceOverlayActive(bool active) async {
  if (kIsWeb) return;
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  try {
    await windowManager.setAlwaysOnTop(active);
  } catch (_) {}
}
