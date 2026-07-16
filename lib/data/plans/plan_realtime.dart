part of '../database_service.dart';

Future<void>? _plansRealtimeSubscribeFuture;
Future<void> Function()? _plansRealtimeUnsubscribe;

/// PocketBase plans subscription, event application, and reconnect backoff.
extension PlanRealtimeExtension on DatabaseService {
  // ---------------------------------------------------------------------------
  // Plans realtime (web + mobile multi-device sync)
  // ---------------------------------------------------------------------------

  String? _pocketBaseOwnerFilterClauseForPlans() {
    final uid = _userIdForWhere?.trim() ?? '';
    if (uid.isEmpty) return null;
    return 'user_id = "${_escapeForPbFilter(uid)}"';
  }

  void _onPbPlansSubscriptionEvent(RecordSubscriptionEvent e) {
    try {
      if (!_isInitialized || !_hasAuthenticatedUserId) return;
      final action = e.action.toLowerCase().trim();
      if (action == 'delete') {
        final id = e.record?.id.trim() ?? '';
        if (id.isNotEmpty) {
          _removePlanFromUserCache(id);
          clearOptimisticPlanningForPlanRow(id);
          notifyPlanningRefresh(scheduleNetworkRefresh: false);
        }
        return;
      }
      final rec = e.record;
      if (rec == null) return;
      unawaited(() async {
        try {
          final tagCatalog = await _fetchPlanAndListTagCatalog();
          final task = _planningTaskFromPocketRecord(
            rec,
            pocketTagCatalog: tagCatalog,
          );
          _upsertPlanInUserCache(task);
          _allPlansUserCacheFetchedAt = DateTime.now();
          final biz = _planBusinessUuidFromTask(task);
          if (biz != null && biz.isNotEmpty) {
            clearOptimisticPlanningForPlanRow('optimistic-$biz');
          }
          clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
          notifyPlanningRefresh(scheduleNetworkRefresh: false);
        } catch (_) {}
      }());
    } catch (_) {}
  }

  Future<void> _cancelPlansRealtimeSubscription() async {
    final unsub = _plansRealtimeUnsubscribe;
    _plansRealtimeUnsubscribe = null;
    if (unsub != null) {
      try {
        await unsub();
      } catch (_) {}
    }
    try {
      await _pb.collection(PbCollections.plans).unsubscribe();
    } catch (_) {}
  }

  Future<void> _startPlansRealtimeSubscriptionBody() async {
    await _cancelPlansRealtimeSubscription();
    if (!_hasAuthenticatedUserId) return;
    if (isPbRealtimeUnavailable) {
      _logPlansRealtimeSubscribeQuiet('realtime_endpoint_unavailable');
      return;
    }
    planStreamLifecycleLog('realtimeSubscribe status=start collection=plans');
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final filter = _pocketBaseOwnerFilterClauseForPlans();
      if (filter == null || filter.isEmpty) return;
      Future<void> Function()? unsub;
      try {
        unsub = await _pb
            .collection(PbCollections.plans)
            .subscribe(
              '*',
              _onPbPlansSubscriptionEvent,
              filter: filter,
              expand: kPbPlanTagsExpand,
            );
      } catch (_) {
        unsub = await _pb
            .collection(PbCollections.plans)
            .subscribe('*', _onPbPlansSubscriptionEvent, filter: filter);
      }
      _plansRealtimeUnsubscribe = unsub;
      _plansRealtimeFailureStreak = 0;
      _plansRealtimeReconnectTimer?.cancel();
      _plansRealtimeReconnectTimer = null;
      planStreamLifecycleLog(
        'realtimeSubscribe status=success collection=plans',
      );
    } catch (e) {
      _logPlansRealtimeSubscribeQuiet(e);
      _handleRealtimeSubscribeFailure(e, source: 'plans');
      _schedulePlansRealtimeReconnectAfterFailure();
    }
  }

  void _logPlansRealtimeSubscribeQuiet(Object e) {
    final now = DateTime.now();
    if (_lastPlansRealtimeSubscribeErrorLogAt != null &&
        now.difference(_lastPlansRealtimeSubscribeErrorLogAt!) <
            const Duration(seconds: 5)) {
      return;
    }
    _lastPlansRealtimeSubscribeErrorLogAt = now;
    if (kDebugMode) {
      debugPrint(
        'plans realtime subscribe failed (next backoff '
        '${_plansRealtimeDelayForCurrentFailureStreak().inSeconds}s): $e',
      );
    }
  }

  Duration _plansRealtimeDelayForCurrentFailureStreak() {
    final idx = _plansRealtimeFailureStreak.clamp(
      0,
      DatabaseService._kRealtimeBackoffSeconds.length - 1,
    );
    return Duration(seconds: DatabaseService._kRealtimeBackoffSeconds[idx]);
  }

  void _schedulePlansRealtimeReconnectAfterFailure() {
    if (!_hasAuthenticatedUserId) return;
    if (isPbRealtimeUnavailable) return;
    _plansRealtimeReconnectTimer?.cancel();
    final delay = _plansRealtimeDelayForCurrentFailureStreak();
    if (_plansRealtimeFailureStreak <
        DatabaseService._kRealtimeBackoffSeconds.length) {
      _plansRealtimeFailureStreak++;
    }
    _plansRealtimeReconnectTimer = Timer(delay, () {
      _plansRealtimeReconnectTimer = null;
      unawaited(
        _startPlansRealtimeSubscription().catchError((Object e, StackTrace _) {
          _handleRealtimeSubscribeFailure(e, source: 'plans-reconnect');
        }),
      );
    });
  }

  Future<void> _startPlansRealtimeSubscription() async {
    final existing = _plansRealtimeSubscribeFuture;
    if (existing != null) return existing;
    final f = _startPlansRealtimeSubscriptionBody();
    _plansRealtimeSubscribeFuture = f;
    try {
      await f;
    } finally {
      _plansRealtimeSubscribeFuture = null;
    }
  }

  /// Re-subscribe to `plans` realtime after auth when init ran without a session.
  Future<void> ensurePlansRealtimeBridge() async {
    if (isPbRealtimeUnavailable) return;
    _plansRealtimeReconnectTimer?.cancel();
    _plansRealtimeReconnectTimer = null;
    _plansRealtimeFailureStreak = 0;
    unawaited(
      _startPlansRealtimeSubscription().catchError((Object e, StackTrace _) {
        _handleRealtimeSubscribeFailure(e, source: 'plans-bridge');
      }),
    );
  }
}
