import 'dart:async';
import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:flutter/foundation.dart';

/// Windows smoke-test hooks — production hotkey handler only.
abstract final class DesktopVoiceSmokeBridge {
  static Timer? _pollTimer;
  static void Function()? onFireHotkey;

  static bool simulateRunningRecordForPreservedCheck = false;

  static bool get isActive =>
      !kIsWeb &&
      Platform.isWindows &&
      Platform.environment['COUNTER_DESKTOP_VOICE_SMOKE'] == '1';

  static String get _tempDir => Platform.environment['TEMP'] ?? '.';

  static String _triggerPath(String name) =>
      '$_tempDir${Platform.pathSeparator}$name';

  static void attachIfNeeded() {
    if (!isActive) return;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_BRIDGE_ACTIVE');
  }

  static void startPolling() {
    if (!isActive) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _consumeTrigger('counter_voice_smoke_fire.hotkey', () {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HOTKEY_RECEIVED_FROM_NATIVE_TEST_HOOK',
        );
        onFireHotkey?.call();
      });
      _consumeTrigger('counter_voice_smoke_inject_running', () {
        simulateRunningRecordForPreservedCheck = true;
        DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_INJECT_RUNNING');
      });
    });
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<void> ensureVoiceEnabledForSmoke() async {
    if (!isActive) return;
    if (Platform.environment['COUNTER_DESKTOP_VOICE_SMOKE_FORCE_ENABLE'] != '1') {
      return;
    }
    await DesktopVoiceSettings.instance.loadIfNeeded();
    if (!DesktopVoiceSettings.instance.enabled) {
      await DesktopVoiceSettings.instance.setEnabled(true);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_SMOKE_FORCE_ENABLED');
    }
  }

  static void _consumeTrigger(String fileName, VoidCallback action) {
    final file = File(_triggerPath(fileName));
    if (!file.existsSync()) return;
    try {
      file.deleteSync();
    } catch (_) {}
    action();
  }
}
