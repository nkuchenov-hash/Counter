part of 'lists_view.dart';

// Scoped bulk delete orchestration for the Notes/Lists tab. Keeps UI state
// changes local-first and reconciles only rejected PocketBase deletions.
extension _ListsBulkDeleteExtension on _ListsPageState {
  Future<void> _listsBulkDelete() async {
    if (_bulkDeleteInProgress) return;
    // Resolve from the current Brain snapshot, not a stale search/group slice.
    final tasks = _tasksMatchingSelectedKeys(_displayFlat);
    if (tasks.isEmpty) return;
    _bulkDeleteInProgress = true;
    final db = DatabaseService.instance;
    final ids = <String>[];
    final backups = <String, PlanningTask>{};
    final failedKeys = <String>{};
    for (final t in tasks) {
      final pid = t.planRowIdForBackend.trim();
      if (pid.startsWith('optimistic-')) {
        db.clearOptimisticPlanningForPlanRow(pid);
        continue;
      }
      if (pid.isEmpty) {
        failedKeys.add(_listKey(t));
        continue;
      }
      ids.add(pid);
      backups[pid] = t;
      db.applyOptimisticPlanningTask(
        t.copyWith(dateKey: _kOptimisticPurgeDateKey),
      );
    }
    db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _notifyBulkDeleteUI();

    Set<String> failedIds;
    try {
      failedIds = ids.isEmpty
          ? <String>{}
          : await db.deletePlanningTasksBulkFailedIds(ids);
    } catch (_) {
      failedIds = ids.toSet();
      AppSnack.failed();
    }

    // Successful deletes stay deleted. Restore only rejected ones.
    for (final id in failedIds) {
      final backup = backups[id];
      if (backup == null) continue;
      db.applyOptimisticPlanningTask(backup);
      failedKeys.add(_listKey(backup));
    }
    if (failedIds.isNotEmpty) {
      db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    }
    if (failedKeys.isNotEmpty) {
      final locale = currentLocale.value;
      final message = locale == 'ru'
          ? 'Не удалось удалить ${failedKeys.length} из ${tasks.length} заметок'
          : 'Could not delete ${failedKeys.length} of ${tasks.length} notes';
      AppSnack.show(message, error: true);
    }
    _finishBulkDelete(failedKeys);
  }
}
