part of '../app_shell.dart';

/// Shared phone/web/desktop/iOS reconnect bridge.
///
/// PocketBase restores SSE subscriptions after a transport break, but events
/// that happened while the transport was down are not replayed. PB_CONNECT is
/// therefore a convergence boundary: every successful connect/reconnect
/// schedules one coalesced authoritative foreground refresh. This is push-first
/// recovery, not polling.
class _ShellRealtimeReconnectCatchUp {
  static bool _attached = false;
  static Timer? _debounce;

  static Future<void> attach() async {
    if (_attached) return;
    try {
      final realtime = DatabaseService.instance.pocketBase.realtime;
      await realtime.subscribe('PB_CONNECT', (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 75), () {
          _debounce = null;
          unawaited(DatabaseService.instance.refreshForegroundData());
        });
      });
      _attached = true;
    } catch (e) {
      _attached = false;
      if (kDebugMode) {
        debugPrint('[PB_CONNECT] catch-up subscription failed: $e');
      }
    }
  }
}

mixin ShellLifecycle
    on ShellTabHost, ShellVoiceIntegration, ShellBrowserExtensionQuickAdd {
  void initializeShellLifecycle() {
    selectedDate = DatabaseService.instance.getTimelineDeviceLocalToday();
    focusedDay = DatabaseService.instance.getTimelineDeviceLocalToday();
    selectedDateListenable = ValueNotifier(selectedDate);
    shellPageIndexListenable.value = shellPageIndex;
    timelineTabHost = ListenableBuilder(
      listenable: Listenable.merge([
        selectedDateListenable,
        timelineTasksRevision,
        shellPageIndexListenable,
      ]),
      builder: (context, _) => buildTimelineSwipeTab(),
    );
    planningTabHost = ListenableBuilder(
      listenable: Listenable.merge([
        selectedDateListenable,
        shellPageIndexListenable,
      ]),
      builder: (context, _) => buildPlanningSwipeTab(),
    );
    calendarTabHost = ListenableBuilder(
      listenable: selectedDateListenable,
      builder: (context, _) => buildCalendarTab(),
    );
    listsTabHost = ListenableBuilder(
      listenable: selectedDateListenable,
      builder: (context, _) => buildListsTab(),
    );
    rules = List.from(DatabaseService.instance.rules);
    selectedCategoryId = DatabaseService.instance.defaultCategoryId;

    // Realtime gaps must heal without navigation, pull-to-refresh, or relaunch.
    // PB_CONNECT fires for a restored SSE transport; the catch-up itself is
    // coalesced by DatabaseService.refreshForegroundData().
    unawaited(_ShellRealtimeReconnectCatchUp.attach());

    DesktopVoiceAcceptanceBridge.runCommand = runDesktopVoiceAcceptanceCommand;
    DesktopVoiceAcceptanceBridge.simulateHotkeyToggle =
        onDesktopVoiceHotkeyToggle;
    DesktopVoiceSmokeBridge.attachIfNeeded();
    DesktopVoiceSmokeBridge.onFireHotkey = onDesktopVoiceHotkeyToggle;
    unawaited(DesktopVoiceSmokeBridge.ensureVoiceEnabledForSmoke());
    DesktopVoiceSmokeBridge.startPolling();

    SleepForegroundReconcileService.instance.start();
    unawaited(UnfilledTimeGapService.instance.start());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        await initializeBrowserExtensionBridge();
        await consumeBrowserExtensionQuickAddIfPresent();
      }());
      StartupLog.deferred(
        name: 'timelineTasksLoad',
        reason: 'notNeededForFirstFrame',
      );
      unawaited(() async {
        await loadTasksAndExtras();
        try {
          await PlannerStartupService.instance.ensureBaseline();
        } catch (e) {
          debugPrint('[PLANNER_STARTUP] ensure failed: $e');
        }
      }());
      StartupLog.deferred(name: 'syncBootstrap', reason: 'canRunAfterShell');
      unawaited(() async {
        await DatabaseService.instance.offlineSync.bootstrapFromOutboxes(
          pbBackoffActive: DatabaseService.instance.pbHttpBackoffActive,
        );
      }());
      StartupLog.deferred(name: 'sttInit', reason: 'notNeededForFirstFrame');
      unawaited(speechEngine.ensureReady());
      unawaited(initDesktopVoiceLayer());
    });

    notificationSub = DatabaseService.instance.notifications.listen((msg) {
      if (!mounted || msg == null || msg.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });

    categoryRulesSub = DatabaseService.instance.categoryStream.listen((rules) {
      if (!mounted) return;
      setState(() => this.rules = List.from(rules));
    });

    deviceTodayAtLastMidnightCheck =
        DatabaseService.instance.getTimelineDeviceLocalToday();
    deviceLocalDayKeyLast =
        DatabaseService.instance.getTimelineDeviceLocalTodayDateKey();
    deviceLocalMidnightWatchTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => onDeviceLocalCalendarDayWatchTick(),
    );
  }

  void disposeShellLifecycle() {
    unawaited(speechEngine.dispose());
    SleepForegroundReconcileService.instance.stop();
    deviceLocalMidnightWatchTimer?.cancel();
    notificationSub?.cancel();
    categoryRulesSub?.cancel();
    browserExtensionRecordSub?.cancel();
    titleController.dispose();
    titleFocus.dispose();
    shellLayout.dispose();
    selectedDateListenable.dispose();
    timelineTasksRevision.dispose();
    shellPageIndexListenable.dispose();
    if (DesktopVoiceHotkey.isSupportedPlatform) {
      DesktopVoiceAcceptanceBridge.runCommand = null;
      DesktopVoiceAcceptanceBridge.simulateHotkeyToggle = null;
      unawaited(DesktopVoiceHotkey.detachGlobal());
      unawaited(DesktopTrayService.dispose());
    }
  }
}
