part of '../app_shell.dart';

mixin ShellLifecycle on ShellVoiceRouting {
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

    DesktopVoiceAcceptanceBridge.runCommand = runDesktopVoiceAcceptanceCommand;
    DesktopVoiceAcceptanceBridge.simulateHotkeyToggle =
        onDesktopVoiceHotkeyToggle;
    DesktopVoiceSmokeBridge.attachIfNeeded();
    DesktopVoiceSmokeBridge.onFireHotkey = onDesktopVoiceHotkeyToggle;
    unawaited(DesktopVoiceSmokeBridge.ensureVoiceEnabledForSmoke());
    DesktopVoiceSmokeBridge.startPolling();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupLog.deferred(
        name: 'timelineTasksLoad',
        reason: 'notNeededForFirstFrame',
      );
      unawaited(() async {
        await loadTasksAndExtras();
        try {
          await ensurePlannerBaselineV7();
        } catch (e) {
          debugPrint('[PLANNER_BASELINE_V7] ensure failed: $e');
        }
      }());
      StartupLog.deferred(name: 'syncBootstrap', reason: 'canRunAfterShell');
      unawaited(() async {
        await DatabaseService.instance.offlineSync.bootstrapFromOutboxes(
          pbBackoffActive: DatabaseService.instance.pbHttpBackoffActive,
        );
      }());
      StartupLog.deferred(name: 'sttInit', reason: 'notNeededForFirstFrame');
      unawaited(ensureSpeechReady());
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
    deviceLocalMidnightWatchTimer?.cancel();
    notificationSub?.cancel();
    categoryRulesSub?.cancel();
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
