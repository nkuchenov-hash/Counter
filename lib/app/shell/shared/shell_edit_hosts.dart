part of '../app_shell.dart';

mixin ShellEditHosts on ShellCoreLogic {
  void openNewTaskForPastDate() {
    final ctx = context;
    // Synthetic empty record signals "create" to TimelineRecordSheetContent
    // (id == '' triggers the create branch in _save). Single shared edit sheet.
    final tzHours = DatabaseService.instance.settings.timezoneOffsetHours;
    final defaultStartDisplay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      9,
    );
    final defaultEndDisplay = defaultStartDisplay.add(const Duration(hours: 1));
    final placeholder = TimelineRecord(
      id: '',
      title: titleController.text.trim(),
      startTime: displayToUtc(defaultStartDisplay),
      endTime: displayToUtc(defaultEndDisplay),
      status: 'completed',
      timezoneOffsetHours: tzHours,
    );
    showAppEditSheet<void>(
      context: ctx,
      builder: (context, scrollController, sheetCtx) {
        return ActivityDetailSheet(
          kind: ActivityDetailKind.timelineRecord,
          timelineRecord: placeholder,
          scrollController: scrollController,
          onSaved: (_) {
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }

  void showEditRecordSheetForTimeline(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final record = TimelineRecord.fromMap(
      data,
      timezoneOffsetHours:
          DatabaseService.instance.settings.timezoneOffsetHours,
    );
    showAppEditSheet<void>(
      context: context,
      builder: (context, scrollController, sheetCtx) {
        return ActivityDetailSheet(
          kind: ActivityDetailKind.timelineRecord,
          timelineRecord: record,
          scrollController: scrollController,
          onSaved: (updated) {
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          },
          onDelete: () async {
            final ok = await DatabaseService.instance.deleteRecordByDocId(
              record.id,
            );
            if (!mounted) return;
            if (!ok) {
              showSyncFailedSnackBar(
                onRetry: () => unawaited(
                  DatabaseService.instance.deleteRecordByDocId(record.id),
                ),
              );
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          },
          onStop: () async {
            await DatabaseService.instance.stopRecordByDocId(record.id);
            if (!mounted) return;
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }

  Future<void> openEditDialog(PlanningTask task) async {
    final result = await showAppEditSheet<Object?>(
      context: context,
      useRootNavigator: false,
      builder: (context, scrollController, sheetCtx) {
        return ActivityDetailSheet(
          kind: ActivityDetailKind.planningTask,
          planningTask: task,
          scrollController: scrollController,
          onSaved: (dynamic updatedRaw) {
            Navigator.of(sheetCtx).pop(updatedRaw);
          },
          onDelete: shellIsNewPlanningDraft(task)
              ? null
              : () {
                  final backup = PlanningTask(
                    id: 0,
                    title: task.title,
                    categoryId: task.categoryId,
                    isDone: task.isDone,
                    dateKey: task.dateKey,
                    order: task.order,
                    startTime: task.startTime,
                    date: task.date,
                    tags: task.tags,
                  );
                  DatabaseService.instance.applyOptimisticPlanningTask(
                    task.copyWith(dateKey: shellOptimisticPurgeDateKey),
                  );
                  DatabaseService.instance.notifyPlanningRefresh();
                  unawaited(deletePlanningTaskOptimisticFollowUp(task, backup));
                },
        );
      },
    );
    if (result is! PlanningTask || !mounted) return;
    final loc = currentLocale.value;
    try {
      if (shellIsNewPlanningDraft(task)) {
        final day =
            planningDateFromKey(result.dateKey) ??
            DatabaseService.instance.getTimelineDeviceLocalToday();
        final nextOrder = await DatabaseService.instance
            .nextPlanningOrderForDate(day);
        final collision = DatabaseService.instance
            .resolvePlanningCreateCollision(
              task: result.copyWith(order: nextOrder),
              wallDay: day,
              existingDayPlans: DatabaseService.instance
                  .planningDayTasksSnapshot(day)
                  .where((candidate) => candidate.startTime != null)
                  .toList(),
            );
        final toCreate = collision.task;
        final ok = await DatabaseService.instance.addPlanningTask(toCreate);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
          return;
        }
        if (collision.adjusted && toCreate.startTime != null) {
          final movedTo =
              '${toCreate.startTime!.hour.toString().padLeft(2, '0')}:'
              '${toCreate.startTime!.minute.toString().padLeft(2, '0')}';
          AppSnack.warning(
            t(loc, 'plan_schedule_adjusted').replaceFirst('%s', movedTo),
          );
        }
        HapticFeedback.heavyImpact();
      } else {
        // Persisted plan edits: local apply + debounced PATCH run inside edit sheet.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(loc, 'save_failed').replaceFirst('%s', e.toString()),
            ),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> persistPlanningEditFromSheet(
    PlanningTask baseline,
    PlanningTask edited,
  ) async {
    final loc = currentLocale.value;
    try {
      final anchorShort = DatabaseService.instance.planningAuditAnchorDateKey(
        baseline,
      );
      const minKeyLen = 10;
      final persistInitial = anchorShort.length >= minKeyLen
          ? anchorShort
          : DatabaseService.instance.planningWallScheduleDateKey(baseline);
      final newSk = DatabaseService.instance.planningWallScheduleDateKey(
        edited,
      );
      final initForPatch = persistInitial.length >= minKeyLen
          ? persistInitial
          : (newSk.length >= minKeyLen ? newSk : '');
      final postponed =
          !edited.isDone &&
          initForPatch.length >= minKeyLen &&
          DatabaseService.instance.planningShouldMarkPostponed(
            anchorKey: initForPatch,
            newScheduleKey: newSk.length >= minKeyLen ? newSk : initForPatch,
          );
      final ok = await DatabaseService.instance.updatePlanningTask(
        edited.planRowIdForBackend,
        planBusinessId: edited.planRowId,
        title: edited.title,
        categoryId: edited.categoryId,
        isDone: edited.isDone,
        notesPlain: edited.notesPlain,
        notesDeltaJson: edited.notesDeltaJson,
        checklist: edited.checklist,
        parentPlanId: edited.parentPlanId,
        startTimeDisplay: edited.startTime,
        endDateTimeDisplay: edited.endDateTime,
        clearEnd: edited.endDateTime == null,
        tags: edited.tags,
        suppressAppSnack: true,
        planInitialDateKey: initForPatch.length >= minKeyLen
            ? initForPatch
            : null,
        planIsPostponed: postponed,
        patchPlanAlarmRecurrence: true,
        planRrule: edited.rrule,
        planReminderOffset: edited.reminderOffset,
        planExceptionDates:
            (edited.rrule != null && edited.rrule!.trim().isNotEmpty)
            ? edited.exceptionDates
            : const <String>[],
        recurrenceInstanceDateKey:
            edited.recurrenceInstanceDateKey ??
            baseline.recurrenceInstanceDateKey,
      );
      if (!mounted) return;
      if (!ok) {
        DatabaseService.instance.applyOptimisticPlanningTask(baseline);
        DatabaseService.instance.notifyPlanningRefresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
        return;
      }
      HapticFeedback.heavyImpact();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      DatabaseService.instance.applyOptimisticPlanningTask(baseline);
      DatabaseService.instance.notifyPlanningRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(loc, 'save_failed').replaceFirst('%s', e.toString())),
        ),
      );
    }
  }

  Future<void> deletePlanningTaskOptimisticFollowUp(
    PlanningTask task,
    PlanningTask backup,
  ) async {
    final loc = currentLocale.value;
    final backendId = task.recordIdForBackend.trim();
    if (backendId.isEmpty) {
      if (!mounted) return;
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      DatabaseService.instance.notifyPlanningRefresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
      return;
    }
    final ok = await DatabaseService.instance.deletePlanningTasksBulk([
      backendId,
    ]);
    if (!mounted) return;
    DatabaseService.instance.clearOptimisticPlanningForPlanRow(
      task.planRowIdForBackend,
    );
    DatabaseService.instance.notifyPlanningRefresh();
    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      DatabaseService.instance.notifyPlanningRefresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(loc, 'task_deleted')),
        action: SnackBarAction(
          label: t(loc, 'undo'),
          onPressed: () async {
            await DatabaseService.instance.addPlanningTask(backup);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}
