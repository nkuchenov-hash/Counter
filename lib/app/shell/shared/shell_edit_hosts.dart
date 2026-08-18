part of '../app_shell.dart';

mixin ShellEditHosts on ShellCoreLogic {
  void openNewTaskForPastDate() {
    final ctx = context;
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
              : () => PlanningEditResultActions.deletePersisted(context, task),
        );
      },
    );
    if (result is! PlanningTask || !mounted) return;

    // Existing plans already autosave optimistically inside PlanningTaskEditSheet.
    if (shellIsNewPlanningDraft(task)) {
      try {
        await PlanningEditResultActions.createNewDraft(context, result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t(
                  currentLocale.value,
                  'save_failed',
                ).replaceFirst('%s', e.toString()),
              ),
            ),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }
}
