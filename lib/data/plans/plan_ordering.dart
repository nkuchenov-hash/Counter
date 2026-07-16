part of '../database_service.dart';

/// Planning reorder: debounced bulk PATCH of [order] only (@DATA_MAP `plans.order`, `user_id`).
const Duration _planOrderDebounce = Duration(seconds: 2);

Timer? _planOrderDebounceTimer;
List<PlanningTask>? _pendingPlanOrderSyncList;

/// `planRowId` → server `order` before the first drag of the current reorder session (for diff-only PATCH).
Map<String, int>? _planReorderBaselineByPlanId;

/// Debounced plan-order persistence, diff baseline, and rollback.
extension PlanOrderingExtension on DatabaseService {
  void _cancelPlanOrderDebounceTimer() {
    _planOrderDebounceTimer?.cancel();
    _planOrderDebounceTimer = null;
  }

  /// Seeds baseline **once** per reorder session from the list as shown **before** the drag (server orders).
  void _ensurePlanningOrderBaseline(List<PlanningTask> tasksWithServerOrders) {
    if (_planReorderBaselineByPlanId != null) return;
    final m = <String, int>{};
    for (final t in tasksWithServerOrders) {
      if (t.planRowIdForBackend.startsWith('optimistic-')) continue;
      final id = t.planRowIdForBackend.trim();
      if (id.isEmpty) continue;
      m[id] = t.order;
    }
    _planReorderBaselineByPlanId = m;
  }

  Future<bool> _persistPlanningTaskOrdersBulkNow(
    List<PlanningTask> ordered,
  ) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (!_isPlansTableConfigured) return false;

    final baseline = _planReorderBaselineByPlanId;
    var patched = 0;
    var hardFailed = false;

    try {
      await ensurePocketBaseReady();
      for (final t in ordered) {
        final input = t.planRowIdForBackend.trim();
        if (input.isEmpty || input.startsWith('optimistic-')) continue;
        if (input.startsWith('virt-')) {
          DatabaseService._log(
            'PLAN_REORDER_FAIL planId=$input pocketId=- status=virtual '
            'error=recurring_virtual_not_reorderable payload=order:${t.order}',
          );
          hardFailed = true;
          continue;
        }
        final newOrder = t.order;
        final oldOrder = baseline?[input];
        if (oldOrder != null && oldOrder == newOrder) continue;

        final businessId = _outboxBusinessPlanId(
          input,
          planBusinessId: t.planRowId,
        );
        final shadowPb = _tryResolvePlanPbIdFromCacheOnly(
          input,
          planBusinessId: t.planRowId,
        );
        final String resolved;
        if (shadowPb != null &&
            DatabaseService._isLikelyPocketBaseRowId(shadowPb)) {
          resolved = shadowPb;
        } else {
          resolved = await _resolvePlanRestId(
            input,
            planBusinessId: t.planRowId,
          );
        }
        if (!DatabaseService._isLikelyPocketBaseRowId(resolved)) {
          DatabaseService._log(
            'PLAN_REORDER_FAIL planId=$businessId pocketId=$resolved '
            'status=resolve error=invalid_pb_id payload=order:$newOrder',
          );
          hardFailed = true;
          continue;
        }

        DatabaseService._log(
          'PLAN_REORDER_PATCH planId=$businessId pocketId=$resolved '
          'oldOrder=${oldOrder ?? '-'} newOrder=$newOrder',
        );

        final ok = await _patchPlanUpdateNetworkPhase(
          originalInput: input,
          resolvedPbId: resolved,
          businessId: businessId,
          patchBody: <String, dynamic>{'order': newOrder},
          suppressAppSnack: true,
        );
        if (ok) {
          patched++;
        } else {
          DatabaseService._log(
            'PLAN_REORDER_FAIL planId=$businessId pocketId=$resolved '
            'status=patch error=network_phase_returned_false '
            'payload=order:$newOrder',
          );
          hardFailed = true;
        }
      }
    } catch (e, st) {
      DatabaseService._log('PLAN_REORDER_FAIL error=$e');
      DatabaseService._log(st.toString());
      hardFailed = true;
    }

    if (hardFailed && patched == 0) {
      _rollbackPlanningOrderBaseline(ordered);
      DatabaseService._log('PLAN_REORDER_ROLLBACK reason=all_patches_failed');
      try {
        final msg = t(currentLocale.value, 'plan_reorder_failed');
        if (!_notify.isClosed) _notify.add(msg);
      } catch (_) {}
      return false;
    }

    if (patched > 0) {
      DatabaseService._log('PLAN_REORDER_SUCCESS count=$patched');
      _planReorderBaselineByPlanId = null;
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
    }
    return !hardFailed || patched > 0;
  }

  void _rollbackPlanningOrderBaseline(List<PlanningTask> ordered) {
    final baseline = _planReorderBaselineByPlanId;
    if (baseline == null || baseline.isEmpty) return;
    for (final t in ordered) {
      final id = t.planRowIdForBackend.trim();
      if (id.isEmpty) continue;
      final old = baseline[id];
      if (old == null) continue;
      final current = _findCachedPlanningTaskForEdit(
        id,
        planBusinessId: t.planRowId,
      );
      if (current != null && current.order != old) {
        applyOptimisticPlanningTask(current.copyWith(order: old));
      }
    }
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _planReorderBaselineByPlanId = null;
  }

  /// After navigation away or app pause: persist pending plan order immediately (no debounce).
  Future<void> flushPlanningOrderSyncNow() async {
    _cancelPlanOrderDebounceTimer();
    final pending = _pendingPlanOrderSyncList;
    _pendingPlanOrderSyncList = null;
    DatabaseService._log(
      'PLAN_ORDER_SYNC: immediate flush (${pending?.length ?? 0} pending task(s))',
    );
    if (pending == null || pending.isEmpty) return;
    await _persistPlanningTaskOrdersBulkNow(pending);
  }

  /// Debounced bulk PATCH: [order] only (@DATA_MAP.md). One PATCH per changed row.
  ///
  /// Pass [baselineBeforeReorder] as the task list **before** the drag (first drag in a session seeds diff
  /// baseline; further drags in the same session may pass the same argument — only the first non-null
  /// baseline is stored until a successful sync clears it).
  Future<void> persistPlanningTaskOrder(
    List<PlanningTask> ordered, {
    List<PlanningTask>? baselineBeforeReorder,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (!_isPlansTableConfigured) return;

    for (final task in ordered) {
      applyOptimisticPlanningTask(task);
    }
    notifyPlanningRefresh(scheduleNetworkRefresh: false);

    if (baselineBeforeReorder != null) {
      _ensurePlanningOrderBaseline(baselineBeforeReorder);
    }
    _pendingPlanOrderSyncList = List<PlanningTask>.from(ordered);
    _cancelPlanOrderDebounceTimer();
    DatabaseService._log(
      'PLAN_ORDER_SYNC: debounce arm ${ordered.length} task(s) — fire in ${_planOrderDebounce.inSeconds}s',
    );
    _planOrderDebounceTimer = Timer(_planOrderDebounce, () {
      _planOrderDebounceTimer = null;
      final pending = _pendingPlanOrderSyncList;
      if (pending == null || pending.isEmpty) return;
      _pendingPlanOrderSyncList = null;
      DatabaseService._log(
        'PLAN_ORDER_SYNC: debounce elapsed — syncing ${pending.length} task(s)',
      );
      unawaited(_persistPlanningTaskOrdersBulkNow(pending));
    });
  }
}
