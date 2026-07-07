import 'dart:async';
import 'dart:io';

import 'package:counter/core/services/desktop_main_window.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

bool _trayReady = false;
VoidCallback? _onShowApp;
VoidCallback? _onStartVoice;
VoidCallback? _onStopRunningRecord;
VoidCallback? _onOpenSettings;
Future<void> Function()? _onExitApp;

class _DesktopTrayListener with TrayListener, WindowListener {
  @override
  void onTrayIconMouseDown() {
    _onShowApp?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _onShowApp?.call();
      case 'voice':
        _onStartVoice?.call();
      case 'stop':
        _onStopRunningRecord?.call();
      case 'settings':
        _onOpenSettings?.call();
      case 'exit':
        unawaited(_onExitApp?.call());
    }
  }

  @override
  void onWindowClose() {
    unawaited(hideDesktopMainWindow());
  }
}

final _listener = _DesktopTrayListener();

Future<void> refreshDesktopTrayMenu({
  required String showCounter,
  required String startVoice,
  required String stopRecord,
  required String settings,
  required String exitCounter,
}) async {
  if (!_trayReady) return;
  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'show', label: showCounter),
        MenuItem(key: 'voice', label: startVoice),
        MenuItem(key: 'stop', label: stopRecord),
        MenuItem.separator(),
        MenuItem(key: 'settings', label: settings),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: exitCounter),
      ],
    ),
  );
}

Future<void> initDesktopTray({
  required VoidCallback onShowApp,
  required VoidCallback onStartVoice,
  required VoidCallback onStopRunningRecord,
  required VoidCallback onOpenSettings,
  required Future<void> Function() onExitApp,
}) async {
  if (_trayReady) return;
  _onShowApp = onShowApp;
  _onStartVoice = onStartVoice;
  _onStopRunningRecord = onStopRunningRecord;
  _onOpenSettings = onOpenSettings;
  _onExitApp = onExitApp;

  await windowManager.ensureInitialized();
  windowManager.addListener(_listener);
  try {
    await trayManager.setIcon(File(Platform.resolvedExecutable).path);
  } catch (_) {}

  await trayManager.setToolTip('Counter');
  trayManager.addListener(_listener);
  await windowManager.setPreventClose(true);
  _trayReady = true;
}

Future<void> disposeDesktopTray() async {
  if (!_trayReady) return;
  trayManager.removeListener(_listener);
  windowManager.removeListener(_listener);
  _trayReady = false;
}

Future<void> hideDesktopMainWindow() async {
  await windowManager.hide();
}

Future<void> showDesktopMainWindow() async {
  await DesktopMainWindow.ensureSaneSizeOnShow();
  await windowManager.show();
  await windowManager.focus();
}

Future<void> applyDesktopAutostartRegistry() async {
  final settings = DesktopVoiceSettings.instance;
  await settings.loadIfNeeded();
  const keyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
  const valueName = 'Counter';
  try {
    final exe = Platform.resolvedExecutable;
    final args = settings.launchHidden ? ' --tray' : '';
    final value = '"$exe"$args';
    if (settings.autostart) {
      await Process.run(
        'reg',
        ['add', 'HKCU\\$keyPath', '/v', valueName, '/t', 'REG_SZ', '/d', value, '/f'],
        runInShell: true,
      );
    } else {
      await Process.run(
        'reg',
        ['delete', 'HKCU\\$keyPath', '/v', valueName, '/f'],
        runInShell: true,
      );
    }
  } catch (_) {}
}
