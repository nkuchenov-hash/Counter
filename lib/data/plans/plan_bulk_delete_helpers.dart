part of '../database_service.dart';

// Focused Notes/Lists bulk-delete flow, extracted from the oversized
// PlanService coordinator. PocketBase I/O stays in the Brain layer.
extension PlanBulkDeleteExtension on DatabaseService {
  /// Process every requested row. Failed IDs refer to the input IDs,
  /// allowing optimistic callers to restore only failed rows.
  /// Retriable/offline writes count as accepted once durably queued.
  Future<Set<String>> deletePlanningTasksBulkFailedIds(
    Iterable<String> planBackendIds,
  ) async {
    final requested = planBackendIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (!_isInitialized || !_hasAuthenticatedUserId || !_isPlansTableConfigured) {
      DatabaseService._log('TABLE_GUARD: blocked deletePlanningTasksBulk.');
      return requested;
    }
    final raw = planBackendIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (raw.isEmpty) return <String>{};

    final failedIds = <String>{};
    var deferredNotify = false;
    var skipDeletedSnack = false;
    for (final id in raw) {
      final trimmed = id.trim();
      try {
      if (trimmed.startsWith('optimistic-')) {
        clearOptimisticPlanningForPlanRow(trimmed);
        deferredNotify = true;
        continue;
      }
      final virt = _parseVirtualPlanRowId(trimmed);
      if (virt != null) {
        final ok = await _patchRecurringTemplateExceptionDates(
          parentPlanPocketId: virt.parentPocketId,
          instanceDateKey: virt.instanceDateKey,
          addException: true,
          suppressAppSnack: true,
          deferPlanningNotify: true,
        );
        if (!ok) {
          failedIds.add(trimmed);
          continue;
        }
        deferredNotify = true;
        continue;
      }
      final businessId = _outboxBusinessPlanId(trimmed);
      final shadowPb = _tryResolvePlanPbIdFromCacheOnly(trimmed);
      if (shadowPb != null &&
          DatabaseService._isLikelyPocketBaseRowId(shadowPb)) {
        final del = await _deletePlanNetworkPhase(
          originalInput: trimmed,
          resolvedPbId: shadowPb,
          businessId: businessId,
          deferPlanningNotify: true,
        );
        if (!del.ok) {
          failedIds.add(trimmed);
          continue;
        }
        if (del.queued) skipDeletedSnack = true;
        deferredNotify = true;
        continue;
      }
      try {
        final restId = await _resolvePlanRestId(trimmed);
        if (!DatabaseService._isLikelyPocketBaseRowId(restId)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: 'unresolved_pb_id',
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        final del = await _deletePlanNetworkPhase(
          originalInput: trimmed,
          resolvedPbId: restId,
          businessId: businessId,
          deferPlanningNotify: true,
        );
        if (!del.ok) {
          failedIds.add(trimmed);
          continue;
        }
        if (del.queued) skipDeletedSnack = true;
        deferredNotify = true;
      } on ClientException catch (e, st) {
        DatabaseService._log('DELETE_PLAN_PB_BULK: $e');
        DatabaseService._log(st.toString());
        final code = e.statusCode;
        if (code == 401 || code == 403) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: code,
            syncStatus: PlanMutationOutbox.syncStatusPausedAuth,
          );
          offlineSync.setAuthPaused(true, message: 'HTTP $code');
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        if (_planMutationRetriableHttpCode(code)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: code,
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        failedIds.add(trimmed);
        continue;
      } catch (e, st) {
        DatabaseService._log('DELETE_PLAN_PB_BULK: $e');
        DatabaseService._log(st.toString());
        if (_planMutationRetriableHttpCode(0)) {
          await _enqueuePlanDeleteMutation(
            originalInput: trimmed,
            businessId: businessId,
            error: e,
          );
          offlineSync.setConnectivityOffline(true);
          skipDeletedSnack = true;
          deferredNotify = true;
          continue;
        }
        failedIds.add(trimmed);
        continue;
      }
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Bulk plan delete failed for a row: $error\n$stackTrace');
        }
        failedIds.add(trimmed);
      }
    }
    if (deferredNotify) {
      notifyPlanningRefresh();
      _notifyTimelineAfterRecordCacheMutation();
    }
    if (failedIds.isNotEmpty) {
      AppSnack.failed();
    } else if (!skipDeletedSnack) {
      AppSnack.deleted();
    }
    return failedIds;
  }

}
