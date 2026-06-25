import 'package:flutter/foundation.dart';

Future<void> refreshDesktopTrayMenu({
  required String showCounter,
  required String startVoice,
  required String stopRecord,
  required String settings,
  required String exitCounter,
}) async {}

Future<void> initDesktopTray({
  required VoidCallback onShowApp,
  required VoidCallback onStartVoice,
  required VoidCallback onStopRunningRecord,
  required VoidCallback onOpenSettings,
  required Future<void> Function() onExitApp,
}) async {}

Future<void> disposeDesktopTray() async {}

Future<void> hideDesktopMainWindow() async {}

Future<void> showDesktopMainWindow() async {}

Future<void> applyDesktopAutostartRegistry() async {}
