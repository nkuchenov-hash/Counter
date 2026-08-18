part of '../app_shell.dart';

mixin ShellCoreLogic on ShellDashboardBase {
  void onDeviceLocalCalendarDayWatchTick() {
    final key = DatabaseService.instance.getTimelineDeviceLocalTodayDateKey();
    if (key == deviceLocalDayKeyLast) {
      deviceTodayAtLastMidnightCheck = DatabaseService.instance
          .getTimelineDeviceLocalToday();
      return;
    }
    final oldToday =
        deviceTodayAtLastMidnightCheck ??
        DatabaseService.instance.getTimelineDeviceLocalToday();
    deviceLocalDayKeyLast = key;
    deviceTodayAtLastMidnightCheck = DatabaseService.instance
        .getTimelineDeviceLocalToday();
    DatabaseService.instance.notifyTimelineDeviceLocalDayChanged();
    if (!mounted) return;
    final sel = shellDateOnly(selectedDate);
    final wasFollowingLiveToday =
        sel.year == oldToday.year &&
        sel.month == oldToday.month &&
        sel.day == oldToday.day;
    if (wasFollowingLiveToday && shellPageIndex == 0) {
      final today = DatabaseService.instance.getTimelineDeviceLocalToday();
      applySharedSelectedDate(today, loadTimelineTasks: true);
    }
  }

  void setShellPageIndex(int index) {
    shellPageIndex = index;
    shellPageIndexListenable.value = index;
  }

  void applySharedSelectedDate(
    DateTime day, {
    bool loadTimelineTasks = false,
    bool syncFocusedDay = true,
  }) {
    final normalized = shellDateOnly(day);
    if (shellSameCalendarDay(selectedDate, normalized)) return;
    RebuildMetrics.instance.stateChange(
      source: 'Shell',
      field: 'selectedDate',
      duringSwipe: true,
    );
    selectedDate = normalized;
    if (syncFocusedDay) {
      focusedDay = normalized;
    }
    selectedDateListenable.value = normalized;
    if (loadTimelineTasks && shellPageIndex == 0) {
      unawaited(loadTasksForDate(normalized));
    }
  }

  Future<void> loadTasksAndExtras() async {
    await loadTasksForDate(selectedDate);
  }

  void selectShellHeaderDate(DateTime date) {
    applySharedSelectedDate(
      shellDateOnly(date),
      loadTimelineTasks: shellPageIndex == 0,
    );
  }

  Future<void> loadTasksForDate(DateTime date) async {
    await RebuildMetrics.instance.perfBlockAsync(
      'Shell.loadTasksForDate',
      () async {
        try {
          final loaded = await DatabaseService.instance.loadTasksForDate(date);
          if (!mounted) return;
          if (!shellSameCalendarDay(selectedDate, date)) return;
          RebuildMetrics.instance.stateChange(
            source: 'Shell',
            field: 'tasksLoading=false',
            duringSwipe: true,
          );
          tasks
            ..clear()
            ..addAll(loaded);
          tasksLoading = false;
          timelineTasksRevision.value++;
        } catch (_) {
          if (mounted && shellSameCalendarDay(selectedDate, date)) {
            tasks.clear();
            tasksLoading = false;
            timelineTasksRevision.value++;
          }
        }
      },
      meta: {
        'date':
            '${date.year}-${shellTwoDigits(date.month)}-${shellTwoDigits(date.day)}',
      },
    );
  }

  Future<void> saveTasks() async {
    try {
      await DatabaseService.instance.saveTasks(selectedDate, tasks);
    } catch (_) {}
  }

  void showSyncFailedSnackBar({VoidCallback? onRetry}) {
    if (!mounted) return;
    final now = DateTime.now();
    if (lastSyncFailedSnackAt != null &&
        now.difference(lastSyncFailedSnackAt!) <
            ShellDashboardBase.syncFailedSnackThrottle) {
      return;
    }
    lastSyncFailedSnackAt = now;
    final loc = currentLocale.value;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t(loc, 'sync_failed_retry')),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(seconds: 4),
        action: onRetry == null
            ? null
            : SnackBarAction(label: t(loc, 'try_again'), onPressed: onRetry),
      ),
    );
  }

  void jumpToConflictDate(DateTime d) {
    setState(() => setShellPageIndex(0));
    applySharedSelectedDate(
      DateTime(d.year, d.month, d.day),
      loadTimelineTasks: true,
    );
  }
}
