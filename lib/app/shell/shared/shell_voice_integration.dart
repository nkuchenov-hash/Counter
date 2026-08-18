part of '../app_shell.dart';

/// Desktop voice integration owned by the shell boundary.
/// Command parsing/submission remains in [ShellVoiceRouting].
mixin ShellVoiceIntegration on ShellVoiceRouting {
  Future<void> refreshDesktopTrayMenu() async {
    if (!DesktopTrayService.isSupported) return;
    final loc = currentLocale.value;
    await DesktopTrayService.refreshMenuLabels(
      showCounter: t(loc, 'tray_show_counter'),
      startVoice: t(loc, 'tray_start_voice'),
      stopRecord: t(loc, 'tray_stop_record'),
      settings: t(loc, 'tray_settings'),
      exitCounter: t(loc, 'tray_exit_counter'),
    );
  }

  Future<void> initDesktopVoiceLayer() async {
    if (!DesktopVoiceHotkey.isSupportedPlatform) return;
    await DesktopVoiceSettings.instance.loadIfNeeded();
    if (!mounted) return;

    DesktopVoiceInstalledIdentity.logBootMarkers();
    if (await DesktopTrayService.shouldStartHidden()) {
      unawaited(DesktopTrayService.hideMainWindow());
    }

    await DesktopTrayService.initialize(
      onShowApp: () {
        unawaited(DesktopTrayService.showMainWindow());
        setShellPageIndex(0);
        if (mounted) setState(() {});
      },
      onStartVoice: () => unawaited(toggleDesktopVoiceWidget()),
      onStopRunningRecord: () => unawaited(stopAnyActiveTask()),
      onOpenSettings: () {
        unawaited(DesktopTrayService.showMainWindow());
        setShellPageIndex(5);
        if (mounted) setState(() {});
      },
      onExitApp: () async {
        closeDesktopVoiceOverlayIfOpen();
        await DesktopVoiceHotkey.detachGlobal();
        await DesktopTrayService.dispose();
        DesktopSttHelperService.instance.dispose();
        if (Platform.isWindows) exit(0);
      },
    );
    await refreshDesktopTrayMenu();
    unawaited(DesktopTrayService.applyAutostartRegistry());

    if (DesktopVoiceHotkey.isActive) {
      final ok = await DesktopVoiceHotkey.attachGlobal(
        onToggle: onDesktopVoiceHotkeyToggle,
      );
      DesktopVoiceHotkeyMarkers.logRegistration(ok: ok);
      if (ok) {
        DesktopSttHelperService.instance.prewarmRecognizerInBackground();
        DesktopVoicePipeline.mark('DESKTOP_VOICE_APP_READY');
      }
    } else {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HOTKEY_SKIPPED',
        'voice_inactive',
      );
    }
  }

  void onDesktopVoiceHotkeyToggle() {
    unawaited(toggleDesktopVoiceWidget());
  }

  Future<bool> reattachDesktopVoiceHotkey() async {
    if (!mounted) return false;
    await DesktopVoiceSettings.instance.loadIfNeeded();
    if (!DesktopVoiceHotkey.isActive) {
      await DesktopVoiceHotkey.detachGlobal();
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HOTKEY_DETACHED',
        'voice_disabled',
      );
      if (mounted) setState(() {});
      return true;
    }
    final ok = await DesktopVoiceHotkey.reattachGlobal(
      onToggle: onDesktopVoiceHotkeyToggle,
    );
    DesktopVoiceHotkeyMarkers.logRegistration(
      ok: ok,
      error: ok
          ? null
          : DesktopVoiceSettings.instance.hotkeyRegistrationError,
    );
    if (ok) {
      DesktopSttHelperService.instance.prewarmRecognizerInBackground();
    }
    if (mounted) setState(() {});
    return ok;
  }
}
