part of '../app_shell.dart';

mixin ShellVoiceRouting on ShellTaskActions {
  Future<bool> runDesktopVoiceAcceptanceCommand(String transcript) async {
    final outcome = await DesktopVoiceRecordSubmit.submitTranscript(
      categoryRules: List<CategoryRule>.from(rules),
      transcript: transcript,
      dateKey: timelineVoiceDateKey,
      localeCode: currentLocale.value,
      planetaryNow: DatabaseService.getPlanetaryNow,
      writeRecord: (req) async {
        return DatabaseService.instance.writeRecord(
          req.dateKey,
          req.title,
          categoryId: req.categoryId,
          explicitStartTime: req.explicitStartTime,
          sourcePlanPocketRecordId: null,
        );
      },
    );
    if (outcome == null) return false;
    unawaited(DesktopVoiceConfirmation.showRecordStarted(outcome.confirmationMessage));
    timelineTasksRevision.value++;
    final runningTitle = DatabaseService.instance.cachedPrimaryRunningTitle;
    final expectedTitle = parseVoiceCommand(
      rules: List<CategoryRule>.from(rules),
      transcript: transcript,
    ).recordTitle.trim();
    final visible = runningTitle != null &&
        runningTitle.trim().toLowerCase() == expectedTitle.toLowerCase();
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_TIMELINE_RECORD_VISIBLE_CHECK',
      visible ? 'yes' : 'no',
    );
    return outcome.writeRecordCalled && visible;
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

  Future<String?> desktopVoiceSubmitParsed(
    VoiceCommandParseResult result, {
    DateTime? explicitStartTime,
  }) async {
final outcome = await DesktopVoiceRecordSubmit.submitParsed(
      result: result,
      dateKey: timelineVoiceDateKey,
      localeCode: currentLocale.value,
      planetaryNow: DatabaseService.getPlanetaryNow,
      explicitStartTime: explicitStartTime,
      writeRecord: (req) async {
        unawaited(stopAnyActiveTask());
        try {
return await DatabaseService.instance.writeRecord(
            req.dateKey,
            req.title,
            categoryId: req.categoryId,
            explicitStartTime: req.explicitStartTime,
            sourcePlanPocketRecordId: null,
          );
        } catch (e) {
          DesktopVoicePipeline.mark('DESKTOP_VOICE_WRITE_RECORD_RESULT', 'error $e');
          debugPrint('UI ERROR: $e');
          if (mounted) {
            final pathTag =
                DatabaseService.instance.getCategoryPath(req.categoryId);
            showSyncFailedSnackBar(
              onRetry: () => unawaited(
                retryVoiceWriteNewTask(
                  req.title,
                  req.categoryId,
                  pathTag,
                  sourcePlanPocketRecordId: null,
                ),
              ),
            );
          }
          return null;
        }
      },
    );
if (outcome == null) {
      if (result.isSafeToStart && mounted) {
        final cid = result.matchedLocalCategoryId;
        final title = result.recordTitle.trim();
        if (cid != null && title.isNotEmpty) {
          final pathTag = DatabaseService.instance.getCategoryPath(cid);
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
      }
      return null;
    }
    if (!mounted) return outcome.serverId;
    unawaited(DesktopVoiceConfirmation.showRecordStarted(outcome.confirmationMessage));
    // Pipe-level confirmation that the hotkey-driven writeRecord produced a new
    // task the user can see (closes the silent-success gap: serverId ok but no
    // visible task in Timeline).
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_TASK_CREATED_VISIBLE',
      'serverId=${outcome.serverId} title=${result.recordTitle.trim()}'
      ' onTimelineTab=${shellPageIndex == 0}',
    );
    timelineTasksRevision.value++;
    if (shellPageIndex == 0) {
      final cid = result.matchedLocalCategoryId!;
      final title = result.recordTitle.trim();
      final pathTag = DatabaseService.instance.getCategoryPath(cid);
      final now = DatabaseService.getPlanetaryNow();
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
    }
    return outcome.serverId;
  }

  Future<void> desktopVoiceUndoStop(String? recordDocId) async {
    final id = recordDocId?.trim();
    if (id == null || id.isEmpty) return;
    unawaited(stopRecordByDocId(id));
  }

  void desktopVoiceHotkeyStopRunning(String runningId) {
    final title = DatabaseService.instance.cachedPrimaryRunningTitle ?? '';
    final loc = currentLocale.value;
    final message = voiceCommandStopConfirmationMessage(
      title: title,
      localeCode: loc,
    );

    DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_STOP_RUNNING', title);
    closeDesktopVoiceOverlayIfOpen();

    unawaited(DesktopVoiceConfirmation.showRecordStopped(message));
    unawaited(
      showDesktopVoiceStatusCapsule(
        primaryLine: loc == 'ru' ? 'Остановлено' : 'Stopped',
        secondaryLine: title.trim().isEmpty ? null : title.trim(),
      ),
    );
    timelineTasksRevision.value++;

    if (shellPageIndex == 0 && mounted) {
      setState(() {
        tasks.removeWhere((task) => task.isRunning);
      });
      unawaited(saveTasks());
    }

    unawaited(() async {
      final ok = await DatabaseService.instance.stopRecordByDocId(runningId);
      if (!ok) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STOP_RECORD_FAILED', title);
        if (mounted) {
          AppSnack.show(t(loc, 'desktop_voice_stop_failed'), error: true);
        }
      }
      if (mounted) await stopAnyActiveTask();
    }());
  }

  Future<void> toggleDesktopVoiceWidget() async {
    try {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_RECEIVED');
      if (!DesktopVoiceHotkey.isActive) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_BLOCKED', 'voice_inactive');
        return;
      }

      final overlayOpen = isDesktopVoiceOverlayOpen;
      final overlayListening = DesktopVoiceOverlayBridge.isListening;
      final overlayPreparing = DesktopVoiceOverlayBridge.isPreparing;
      final overlayProcessing = DesktopVoiceOverlayBridge.isProcessing;
      final runningId = DatabaseService.instance.canonicalPrimaryRunningBusinessId;
      final hasRunningRecord =
          runningId != null && runningId.trim().isNotEmpty;

      final action = resolveDesktopVoiceHotkeyAction(
        overlayOpen: overlayOpen,
        overlayListening: overlayListening,
        overlayPreparing: overlayPreparing,
        overlayProcessing: overlayProcessing,
        hasRunningRecord: hasRunningRecord,
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_ACTION_RESOLVED', '$action');

      switch (action) {
        case DesktopVoiceHotkeyAction.finishListening:
          if (DesktopVoiceOverlayBridge.requestFinishListening()) {
            DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_FINISH_LISTENING');
          }
          return;
        case DesktopVoiceHotkeyAction.cancelOverlay:
          if (overlayPreparing) {
            DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_CANCEL_PREPARING');
          }
          if (DesktopVoiceOverlayBridge.requestCancel()) {
            return;
          }
          closeDesktopVoiceOverlayIfOpen();
          return;
        case DesktopVoiceHotkeyAction.openOverlay:
          if (hasRunningRecord) {
            DesktopVoicePipeline.mark('DESKTOP_VOICE_RUNNING_RECORD_PRESERVED');
          }
          await openDesktopVoiceOverlay();
          return;
      }
    } catch (e) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HOTKEY_ERROR_CAUGHT', '$e');
    }
  }

  Future<void> openDesktopVoiceOverlay() async {
    if (isDesktopVoiceOverlayOpen) return;

    DesktopVoiceLog.instance.mark('hotkey_or_tray', 'received');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SHOW_MAIN_WINDOW_SKIPPED');

    final navCtx = appRootNavigatorKey.currentContext ?? context;
    if (!mounted && appRootNavigatorKey.currentContext == null) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_BLOCKED', 'no_context');
      return;
    }

    final opened = await showDesktopVoiceWidget(
      context: navCtx,
      categoryRules: List<CategoryRule>.from(rules),
      onStartRecord: (result, {explicitStartTime}) =>
          desktopVoiceSubmitParsed(
            result,
            explicitStartTime: explicitStartTime,
          ),
      onUndoStop: desktopVoiceUndoStop,
    );
    if (!opened) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_OVERLAY_BLOCKED',
        'overlay_unavailable',
      );
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
