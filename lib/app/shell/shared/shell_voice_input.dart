part of '../app_shell.dart';

/// Generic FAB / VoiceInputSheet routing for Timeline, Planning and Backlog.
/// Desktop global-hotkey/overlay command routing stays in [ShellVoiceRouting].
mixin ShellVoiceInput on ShellTaskActions {
  Future<void> retryVoicePlanningTask(String rawText) async {
    final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
      rawText: rawText,
      wallDay: shellDateOnly(selectedDate),
      categoryIdHint: effectiveCategoryId,
    );
    if (!mounted) return;
    if (!ok) {
      showSyncFailedSnackBar(
        onRetry: () => unawaited(retryVoicePlanningTask(rawText)),
      );
    }
  }

  Future<void> retryVoiceBacklogTask(String rawText) async {
    final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
      rawText: rawText,
      wallDay: shellDateOnly(selectedDate),
      categoryIdHint: effectiveCategoryId,
      isBacklog: true,
    );
    if (!mounted) return;
    if (!ok) {
      showSyncFailedSnackBar(
        onRetry: () => unawaited(retryVoiceBacklogTask(rawText)),
      );
    }
  }

  Future<bool> voiceSubmitTimeline(String recognized) async {
    final title = recognized.trim();
    if (title.isEmpty) return false;
    unawaited(stopAnyActiveTask());
    final now = DatabaseService.getPlanetaryNow();
    final alreadyExists = tasks.any(
      (t) =>
          t.title == title &&
          t.isActive &&
          t.startTime.difference(now).inSeconds.abs() <= 2,
    );
    if (alreadyExists) return true;
    final fuzzyMatch = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    final cid = fuzzyMatch?.id ?? effectiveCategoryId;
    final pathTag = cid != null
        ? DatabaseService.instance.getCategoryPath(cid)
        : 'Life';
    if (fuzzyMatch != null && mounted) {
      final loc = currentLocale.value;
      final pathUi = localizeCategoryBreadcrumbPath(fuzzyMatch.path, loc);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              loc,
              'mapped_to',
            ).replaceFirst('%s', title).replaceFirst('%s', pathUi),
          ),
        ),
      );
    }
    try {
      final serverId = await DatabaseService.instance.writeRecord(
        timelineVoiceDateKey,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: null,
      );
      if (!mounted) return false;
      if (serverId == null || serverId.trim().isEmpty) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            retryVoiceWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
        );
        return false;
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
            dateKey: timelineVoiceDateKey,
            recordBusinessId: serverId,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(
            retryVoiceWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> voiceSubmitPlanning(String recognized) async {
    final title = recognized.trim();
    if (title.isEmpty) return false;
    try {
      final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
        rawText: recognized,
        wallDay: shellDateOnly(selectedDate),
        categoryIdHint: effectiveCategoryId,
      );
      if (!mounted) return false;
      if (!ok) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(retryVoicePlanningTask(recognized)),
        );
      }
      return ok;
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(retryVoicePlanningTask(recognized)),
        );
      }
      return false;
    }
  }

  Future<bool> voiceSubmitBacklog(String recognized) async {
    final title = recognized.trim();
    if (title.isEmpty) return false;
    try {
      final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
        rawText: recognized,
        wallDay: shellDateOnly(selectedDate),
        categoryIdHint: effectiveCategoryId,
        isBacklog: true,
      );
      if (!mounted) return false;
      if (!ok) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(retryVoiceBacklogTask(recognized)),
        );
      }
      return ok;
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        showSyncFailedSnackBar(
          onRetry: () => unawaited(retryVoiceBacklogTask(recognized)),
        );
      }
      return false;
    }
  }

  Future<void> startVoiceInput() async {
    if (!kIsWeb) {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final res = await Permission.microphone.request();
        if (!res.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t(currentLocale.value, 'microphone_permission')),
            ),
          );
          return;
        }
      }
    }
    if (kIsWeb) {
      debugPrint(
        '[STT] Web: SpeechToText uses the browser Web Speech API (HTTPS + user gesture).',
      );
    }
    await speechEngine.ensureReady();
    if (!speechEngine.ready) {
      if (!mounted) return;
      final loc = currentLocale.value;
      final detail = speechEngine.lastInitError?.trim();
      final text = detail != null && detail.isNotEmpty
          ? t(loc, 'speech_error_prefix').replaceFirst('%s', detail)
          : t(loc, 'speech_unavailable');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      return;
    }

    if (!mounted) return;
    final Future<bool> Function(String) voiceSubmitIntent = shellPageIndex == 1
        ? voiceSubmitPlanning
        : shellPageIndex == 3
        ? voiceSubmitBacklog
        : voiceSubmitTimeline;
    final voiceSuccessKey = shellPageIndex == 1 || shellPageIndex == 3
        ? 'task_added_to_plan'
        : 'record_synced';
    final voicePrimaryKey = shellPageIndex == 1 || shellPageIndex == 3
        ? 'add_task'
        : 'start_task';
    final speechHandle = speechEngine.handle;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return VoiceInputSheet(
          speechHandle: speechHandle,
          setSpeechStatusCallback: speechEngine.setStatusCallback,
          onSpeechEngineHardReset: speechEngine.hardReset,
          onListeningChanged: (listening) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => isVoiceListening = listening);
            });
          },
          config: VoiceCaptureConfig(
            submitIntent: voiceSubmitIntent,
            successL10nKey: voiceSuccessKey,
            primaryActionL10nKey: voicePrimaryKey,
          ),
        );
      },
    );
    if (!mounted) return;
    speechEngine.setStatusCallback(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => isVoiceListening = false);
    });
  }
}
