part of '../app_shell.dart';

mixin ShellTaskActions on ShellCoreLogic {
  Future<void> retryWriteNewTask(
    String title,
    int? cid,
    String pathTag, {
    String? sourcePlanPocketRecordId,
    String? createBusinessId,
    DateTime? capturedStartTime,
  }) async {
    // An old snackbar must not resubmit a previous title after the user has
    // started typing a different recording (or create duplicate timers).
    if (titleController.text.trim() != title) return;
    final startTime = capturedStartTime ?? DatabaseService.getPlanetaryNow();
    final attemptId = createBusinessId ?? const Uuid().v4();
    try {
      unawaited(persistQuickEntryDraft(title));
      final serverId = await DatabaseService.instance.writeRecord(
        selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: startTime,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
        stableCreateBusinessId: attemptId,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        showSyncFailedSnackBar(
          message: t(currentLocale.value, 'record_create_not_saved'),
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
              createBusinessId: attemptId,
              capturedStartTime: startTime,
            ),
          ),
        );
        return;
      }
      if (titleController.text.trim() == title) {
        titleController.clear();
        unawaited(persistQuickEntryDraft(''));
      }
      setState(() {
        for (final old in tasks.where((t) => t.isRunning)) {
          old.isActive = false;
          if (startTime.isAfter(old.startTime)) old.endTime = startTime;
        }
        if (!tasks.any((t) => t.title == title && t.startTime == startTime)) {
          tasks.add(
            Task(
              title: title,
              startTime: startTime,
            endTime: null,
            tags: [pathTag],
              isActive: true,
            ),
          );
        }
        tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      await saveTasks();
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          message: t(currentLocale.value, 'record_create_not_saved'),
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
              createBusinessId: attemptId,
              capturedStartTime: startTime,
            ),
          ),
        );
      }
    }
  }

  Future<void> retryVoiceWriteNewTask(
    String title,
    int? cid,
    String pathTag, {
    String? sourcePlanPocketRecordId,
  }) async {
    try {
      final now = DatabaseService.getPlanetaryNow();
      final serverId = await DatabaseService.instance.writeRecord(
        timelineVoiceDateKey,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        showSyncFailedSnackBar(
          message: t(currentLocale.value, 'record_create_not_saved'),
          onRetry: () => unawaited(
            retryVoiceWriteNewTask(
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
            startTime: now,
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
          message: t(currentLocale.value, 'record_create_not_saved'),
          onRetry: () => unawaited(
            retryVoiceWriteNewTask(
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
    if (title.isEmpty || quickEntryStartPending.value) return;

    // Do not silently discard a click during a previous draft write or while
    // PocketBase is slow. Disable duplicate submissions immediately.
    quickEntryStartPending.value = true;
    final now = DatabaseService.getPlanetaryNow();
    final attemptId = const Uuid().v4();
    final cid = effectiveCategoryId;
    final pathTag = cid != null
        ? DatabaseService.instance.getCategoryPath(cid)
        : 'Life';

    try {
      // Draft persistence is a backup, not a prerequisite to writing a
      // record. The Brain first applies the local shadow and then durably
      // stages the outbox. A delayed browser draft transaction must never
      // prevent Start from reaching that path.
      unawaited(persistQuickEntryDraft(title));
      final serverId = await DatabaseService.instance.writeRecord(
        selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: null,
        stableCreateBusinessId: attemptId,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        showSyncFailedSnackBar(
          message: t(currentLocale.value, 'record_create_not_saved'),
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
              createBusinessId: attemptId,
              capturedStartTime: now,
            ),
          ),
        );
        return;
      }
      // Once the outbox has accepted this record, clear the input without
      // awaiting a second IndexedDB draft write. Never erase newer typing.
      if (titleController.text.trim() == title) {
        titleController.clear();
      }
      unawaited(persistQuickEntryDraft(titleController.text));
      setState(() {
        for (final old in tasks.where((t) => t.isRunning)) {
          old.isActive = false;
          if (now.isAfter(old.startTime)) old.endTime = now;
        }
        if (!tasks.any((t) => t.title == title && t.startTime == now)) {
          tasks.add(
            Task(
              title: title,
              startTime: now,
              endTime: null,
              tags: [pathTag],
              isActive: true,
            ),
          );
        }
        tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      unawaited(saveTasks());
      unawaited(
        deferSourcePlanLinkAfterFreeStart(
          title: title,
          dateKey: selectedDateString,
          recordBusinessId: serverId,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Quick entry start failed: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          message: t(currentLocale.value, 'record_create_not_saved'),
          onRetry: () => unawaited(
            retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
              createBusinessId: attemptId,
              capturedStartTime: now,
            ),
          ),
        );
      }
    } finally {
      if (mounted) quickEntryStartPending.value = false;
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
        tick.difference(lastStopRecordAction!) <
            ShellDashboardBase.stopRecordDebounce) {
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

  void showSourcePlanSuggestionSnack({
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
                      DatabaseService.instance.acceptSourcePlanLinkSuggestion(
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
                      DatabaseService.instance.dismissSourcePlanLinkSuggestion(
                        recordBusinessId,
                      ),
                    );
                  },
                  child: Text(t(loc, 'skip_link_plan')),
                ),
                TextButton(
                  onPressed: () {
                    messenger.clearSnackBars();
                    unawaited(
                      DatabaseService.instance.dismissSourcePlanLinkSuggestion(
                        recordBusinessId,
                      ),
                    );
                    unawaited(
                      DatabaseService.instance.disableSourcePlanLinkSuggestions(),
                    );
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

  Future<void> deferSourcePlanLinkAfterFreeStart({
    required String title,
    required String dateKey,
    required String recordBusinessId,
  }) async {
    if (!mounted) return;
    final suggestion = await DatabaseService.instance
        .prepareSourcePlanLinkSuggestionForFreeStart(
          recordTitle: title,
          wallDateKey: dateKey,
          recordBusinessId: recordBusinessId,
        );
    if (!mounted || suggestion == null) return;
    showSourcePlanSuggestionSnack(
      recordBusinessId: recordBusinessId,
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
        tick.difference(lastPlayOrStartAction!) <
            ShellDashboardBase.playStartDebounce) {
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
          message: t(currentLocale.value, 'record_create_not_saved'),
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
          message: t(currentLocale.value, 'record_create_not_saved'),
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
}
