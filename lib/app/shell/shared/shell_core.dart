part of '../app_shell.dart';

mixin ShellCoreLogic on ShellDashboardBase {
  void categoryVisibilityShellListener() {
    if (!mounted) return;
    final id = selectedCategoryId;
    if (id != null && CategoryVisibilityPrefs.isHiddenOrAncestor(id)) {
      int? firstVisible;
      for (final p in DatabaseService.instance.allCategoryIdPathPairs) {
        if (!CategoryVisibilityPrefs.isHiddenOrAncestor(p.id)) {
          firstVisible = p.id;
          break;
        }
      }
      setState(() => selectedCategoryId = firstVisible);
    }
  }

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
        now.difference(lastSyncFailedSnackAt!) < ShellDashboardBase.syncFailedSnackThrottle) {
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

  Future<void> retryWriteNewTask(
    String title,
    int? cid,
    String pathTag, {
    String? sourcePlanPocketRecordId,
  }) async {
    try {
      final startTime = DatabaseService.getPlanetaryNow();
      final serverId = await DatabaseService.instance.writeRecord(
        selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: startTime,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
        );
        return;
      }
      setState(() {
        tasks.add(
          Task(
            title: title,
            startTime: startTime,
            endTime: null,
            tags: [pathTag],
            isActive: true,
          ),
        );
        tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      await saveTasks();
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
        );
      }
    }
  }

  Future<void> startTaskFromInput() async {
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final tick = DateTime.now();
    if (lastPlayOrStartAction != null &&
        tick.difference(lastPlayOrStartAction!) < ShellDashboardBase.playStartDebounce) {
      return;
    }
    lastPlayOrStartAction = tick;

    unawaited(stopAnyActiveTask());

    final now = DatabaseService.getPlanetaryNow();
    final cid = effectiveCategoryId;
    final pathTag = cid != null
        ? DatabaseService.instance.getCategoryPath(cid)
        : 'Life';

    titleController.clear();
    titleFocus.requestFocus();

    try {
      final serverId = await DatabaseService.instance.writeRecord(
        selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: null,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
        );
        return;
      }
      setState(() {
        tasks.add(
          Task(
            title: title,
            startTime: now,
            endTime: null,
            tags: [pathTag],
            isActive: true,
          ),
        );
        tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      unawaited(saveTasks());
      if (mounted) {
        unawaited(
          deferSourcePlanLinkAfterFreeStart(
            title: title,
            dateKey: selectedDateString,
            recordBusinessId: serverId,
          ),
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
        );
      }
    }
  }

  Future<void> planTaskFromInput() async {
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final dateKey = selectedDateString;
    final cat = effectiveCategoryId;
    titleController.clear();
    titleFocus.requestFocus();
    unawaited(() async {
      try {
        await DatabaseService.instance.addPlannedTask(
          dateKey,
          title,
          categoryId: cat,
          isManual: false,
        );
      } catch (_) {}
    }());
  }

  Future<void> stopTask(Task t) async {
    if (!t.isRunning) return;
    setState(() {
      t.endTime = DatabaseService.getPlanetaryNow();
      t.isActive = false;
    });
    await saveTasks();
  }

  Future<void> deleteRecordByDocId(String recordId) async {
    try {
      final ok = await DatabaseService.instance.deleteRecordByDocId(recordId);
      if (!mounted) return;
      if (!ok) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(deleteRecordByDocId(recordId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                currentLocale.value,
                'failed_to_delete',
              ).replaceFirst('%s', e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> stopRecordByDocId(String systemRowId) async {
    final tick = DateTime.now();
    if (lastStopRecordAction != null &&
        tick.difference(lastStopRecordAction!) < ShellDashboardBase.stopRecordDebounce) {
      return;
    }
    lastStopRecordAction = tick;
    try {
      final ok = await DatabaseService.instance.stopRecordByDocId(systemRowId);
      if (!mounted) return;
      if (!ok) {
        debugPrint(
          'UI ERROR: stopRecordByDocId returned false (systemRowId=$systemRowId)',
        );
        // DatabaseService already showed error_stop_* / HTTP code — do not show sync_failed_retry.
        return;
      }
      await stopAnyActiveTask();
    } catch (e) {
      debugPrint('UI ERROR: $e');
    }
  }

  Future<void> stopAnyActiveTask() async {
    final running = tasks.where((t) => t.isRunning).toList();
    for (final t in running) {
      await stopTask(t);
    }
  }

  Future<SharedPreferences> recordLinkPrefs() =>
      SharedPreferences.getInstance();

  Future<bool> recordLinkSuggestionsEnabled() async {
    final prefs = await recordLinkPrefs();
    return prefs.getBool(shellPrefsRecordLinkSuggestionsEnabled) ?? true;
  }

  Future<String> recordLinkSuggestionMode() async {
    final prefs = await recordLinkPrefs();
    final raw = prefs.getString(shellPrefsRecordLinkSuggestionMode);
    return raw == shellRecordLinkSuggestionModeAuto
        ? shellRecordLinkSuggestionModeAuto
        : shellRecordLinkSuggestionModeAsk;
  }

  Future<bool> recordLinkSuggestionDismissed(String recordBusinessId) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return true;
    final prefs = await recordLinkPrefs();
    return (prefs.getStringList(shellPrefsRecordLinkSuggestionDismissed) ??
            const [])
        .contains(rid);
  }

  Future<void> markRecordLinkSuggestionDismissed(
    String recordBusinessId,
  ) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return;
    final prefs = await recordLinkPrefs();
    final existing =
        prefs.getStringList(shellPrefsRecordLinkSuggestionDismissed) ?? [];
    if (existing.contains(rid)) return;
    existing.add(rid);
    if (existing.length > 300) {
      existing.removeRange(0, existing.length - 300);
    }
    await prefs.setStringList(shellPrefsRecordLinkSuggestionDismissed, existing);
  }

  Future<void> disableRecordLinkSuggestions() async {
    final prefs = await recordLinkPrefs();
    await prefs.setBool(shellPrefsRecordLinkSuggestionsEnabled, false);
  }

  void showSourcePlanSuggestionSnack({
    required String title,
    required String recordBusinessId,
    required SourcePlanLinkSuggestion suggestion,
  }) {
    if (!mounted) return;
    final loc = currentLocale.value;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                loc,
                'record_link_suggestion_message',
              ).replaceFirst('%s', suggestion.planTitle),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () {
                    messenger.clearSnackBars();
                    unawaited(
                      markRecordLinkSuggestionDismissed(recordBusinessId),
                    );
                    unawaited(
                      patchSuggestedSourcePlanLink(
                        recordBusinessId: recordBusinessId,
                        planPocketRecordId: suggestion.planPocketRecordId,
                      ),
                    );
                  },
                  child: Text(t(loc, 'link_plan_confirm')),
                ),
                TextButton(
                  onPressed: () {
                    messenger.clearSnackBars();
                    unawaited(
                      markRecordLinkSuggestionDismissed(recordBusinessId),
                    );
                  },
                  child: Text(t(loc, 'skip_link_plan')),
                ),
                TextButton(
                  onPressed: () {
                    messenger.clearSnackBars();
                    unawaited(
                      markRecordLinkSuggestionDismissed(recordBusinessId),
                    );
                    unawaited(disableRecordLinkSuggestions());
                  },
                  child: Text(t(loc, 'record_link_suggestion_turn_off')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> patchSuggestedSourcePlanLink({
    required String recordBusinessId,
    required String planPocketRecordId,
  }) async {
    try {
      await DatabaseService.instance.primaryRecordWriteNetworkChain;
    } catch (_) {}
    if (!mounted) return;
    try {
      await DatabaseService.instance.patchRecordSourcePlanLink(
        recordId: recordBusinessId,
        sourcePlanPocketRecordId: planPocketRecordId,
      );
    } catch (e) {
      debugPrint('UI ERROR: $e');
    }
  }

  Future<void> deferSourcePlanLinkAfterFreeStart({
    required String title,
    required String dateKey,
    required String recordBusinessId,
  }) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return;
    if (!mounted) return;
    if (!await recordLinkSuggestionsEnabled()) return;
    if (await recordLinkSuggestionDismissed(rid)) return;
    final mode = await recordLinkSuggestionMode();
    final minSimilarity = mode == shellRecordLinkSuggestionModeAuto ? 0.92 : 0.72;
    final suggestion = await DatabaseService.instance
        .suggestSourcePlanForFreeStart(
          recordTitle: title,
          wallDateKey: dateKey,
          minSimilarity: minSimilarity,
        );
    if (!mounted || suggestion == null) return;
    if (mode == shellRecordLinkSuggestionModeAuto) {
      await markRecordLinkSuggestionDismissed(rid);
      await patchSuggestedSourcePlanLink(
        recordBusinessId: rid,
        planPocketRecordId: suggestion.planPocketRecordId,
      );
      return;
    }
    showSourcePlanSuggestionSnack(
      title: title,
      recordBusinessId: rid,
      suggestion: suggestion,
    );
  }

  Future<void> startRecordFromPlanning(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) async {
    final tick = DateTime.now();
    if (lastPlayOrStartAction != null &&
        tick.difference(lastPlayOrStartAction!) < ShellDashboardBase.playStartDebounce) {
      return;
    }
    lastPlayOrStartAction = tick;
    try {
      final id = await DatabaseService.instance.startTimerWithCategory(
        title,
        categoryId: categoryId,
        dateKey: dateKey,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (!mounted) return;
      if (id == null || id.trim().isEmpty) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            startRecordFromPlanning(
              title,
              categoryId,
              dateKey,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
        );
        return;
      }
      final loc = currentLocale.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(loc, 'record_started_message').replaceFirst('%s', title),
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            startRecordFromPlanning(
              title,
              categoryId,
              dateKey,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
        );
      }
    }
  }

  void jumpToConflictDate(DateTime d) {
    setState(() => setShellPageIndex(0));
    applySharedSelectedDate(
      DateTime(d.year, d.month, d.day),
      loadTimelineTasks: true,
    );
  }
}
