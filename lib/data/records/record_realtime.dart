part of '../database_service.dart';

Future<void> Function()? _realtimeRecoveryConnectUnsubscribe;
Future<void>? _realtimeRecoveryConnectSubscribeFuture;
bool _realtimeTransportGapDetected = false;
Timer? _realtimeGapCatchUpTimer;

extension RecordRealtimeExtension on DatabaseService {
  void _onPbRecordsSubscriptionEvent(RecordSubscriptionEvent e) {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    final action = e.action.toLowerCase().trim();
    if (action == 'delete') {
      final id = e.record?.id.trim() ?? '';
      if (id.isNotEmpty) {
        _removeCachedFlatRecordByPk(id);
      }
      return;
    }
    final rec = e.record;
    if (rec == null) return;
    try {
      _upsertFlatRecordFromPbModel(
        rec,
        preserveExpand: true,
        suppressTimelineNotify: false,
        logSuccessLine: false,
      );
    } catch (_) {}
  }

  /// PocketBase automatically restores SSE subscriptions after a transport
  /// reconnect, but events that happened while the transport was down are not
  /// replayed. Mark the gap and reconcile authoritative state on PB_CONNECT.
  void _installRealtimeGapGuard() {
    _pb.realtime.onDisconnect = (subscriptions) {
      if (isPbRealtimeUnavailable) return;
      final hasLiveDataTopic = subscriptions.entries.any(
        (entry) => entry.key != 'PB_CONNECT' && entry.value.isNotEmpty,
      );
      if (!hasLiveDataTopic) return;
      _realtimeTransportGapDetected = true;
      planStreamLifecycleLog(
        'realtime transport disconnected; sdk autoreconnect active; '
        'authoritative catch-up armed subscriptions=${subscriptions.length}',
      );
    };
  }

  void _onPocketBaseRealtimeConnect(dynamic _) {
    if (!_realtimeTransportGapDetected ||
        isPbRealtimeUnavailable ||
        !_isInitialized ||
        !_hasAuthenticatedUserId) {
      return;
    }
    _scheduleRealtimeGapCatchUp();
  }

  void _scheduleRealtimeGapCatchUp() {
    _realtimeGapCatchUpTimer?.cancel();
    _realtimeGapCatchUpTimer = Timer(const Duration(milliseconds: 200), () {
      _realtimeGapCatchUpTimer = null;
      if (!_realtimeTransportGapDetected ||
          !_isInitialized ||
          !_hasAuthenticatedUserId ||
          isPbRealtimeUnavailable) {
        return;
      }

      // Clear before dispatch so repeated PB_CONNECT messages cannot stack
      // duplicate full refreshes. refreshForegroundData itself also coalesces
      // overlapping calls and schedules retry when PocketBase backoff is active.
      _realtimeTransportGapDetected = false;
      planStreamLifecycleLog(
        'realtime transport reconnected; authoritative catch-up starting',
      );
      unawaited(
        refreshForegroundData().then((_) {
          planStreamLifecycleLog(
            'realtime reconnect authoritative catch-up complete',
          );
        }).catchError((Object _, StackTrace __) {
          // Preserve the gap marker so the next successful bridge/connect can
          // retry reconciliation instead of silently accepting stale state.
          _realtimeTransportGapDetected = true;
        }),
      );
    });
  }

  Future<void> _ensureRealtimeRecoverySubscription() async {
    _installRealtimeGapGuard();
    if (_realtimeRecoveryConnectUnsubscribe != null) {
      if (_realtimeTransportGapDetected) {
        _scheduleRealtimeGapCatchUp();
      }
      return;
    }

    final existing = _realtimeRecoveryConnectSubscribeFuture;
    if (existing != null) return existing;

    late final Future<void> run;
    run = () async {
      try {
        final unsubscribe = await _pb.realtime.subscribe(
          'PB_CONNECT',
          _onPocketBaseRealtimeConnect,
        );
        _realtimeRecoveryConnectUnsubscribe = unsubscribe;
        if (_realtimeTransportGapDetected) {
          _scheduleRealtimeGapCatchUp();
        }
      } catch (error) {
        _realtimeTransportGapDetected = true;
        _logRecordsRealtimeSubscribeQuiet(error);
      }
    }();
    _realtimeRecoveryConnectSubscribeFuture = run;
    try {
      await run;
    } finally {
      if (identical(_realtimeRecoveryConnectSubscribeFuture, run)) {
        _realtimeRecoveryConnectSubscribeFuture = null;
      }
    }
  }

  Future<void> _cancelRealtimeRecoverySubscription() async {
    _realtimeGapCatchUpTimer?.cancel();
    _realtimeGapCatchUpTimer = null;
    _realtimeTransportGapDetected = false;
    final unsubscribe = _realtimeRecoveryConnectUnsubscribe;
    _realtimeRecoveryConnectUnsubscribe = null;
    if (unsubscribe != null) {
      try {
        await unsubscribe();
      } catch (_) {}
    }
  }

  Future<void> _cancelRecordsRealtimeSubscription() async {
    final unsub = _recordsRealtimeUnsubscribe;
    _recordsRealtimeUnsubscribe = null;
    if (unsub != null) {
      try {
        await unsub();
      } catch (_) {}
    }
    try {
      await _pb.collection(PbCollections.records).unsubscribe();
    } catch (_) {}

    // During normal bridge re-arm the authenticated session is still present,
    // so keep PB_CONNECT alive. On sign-out/session teardown or when the
    // realtime endpoint is known unavailable, remove the recovery listener too
    // so the SSE transport can close cleanly instead of reconnecting forever.
    if (!_hasAuthenticatedUserId || isPbRealtimeUnavailable) {
      await _cancelRealtimeRecoverySubscription();
    }
  }

  Future<void> _startRecordsRealtimeSubscription() async {
    final existing = _recordsRealtimeSubscribeFuture;
    if (existing != null) {
      return existing;
    }
    final f = _startRecordsRealtimeSubscriptionBody();
    _recordsRealtimeSubscribeFuture = f;
    try {
      await f;
    } finally {
      _recordsRealtimeSubscribeFuture = null;
    }
  }

  Future<void> _startRecordsRealtimeSubscriptionBody() async {
    await _cancelRecordsRealtimeSubscription();
    if (!_hasAuthenticatedUserId) return;
    if (isPbRealtimeUnavailable) {
      _realtimeTransportGapDetected = true;
      _logRecordsRealtimeSubscribeQuiet('realtime_endpoint_unavailable');
      return;
    }
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        _realtimeTransportGapDetected = true;
        _logRecordsRealtimeSubscribeQuiet('pb_http_backoff_active');
        _scheduleRecordsRealtimeReconnectAfterFailure();
        return;
      }
      final filter = _pocketBaseOwnerFilterClauseForRecords();
      if (filter == null || filter.isEmpty) return;
      Future<void> Function()? unsub;
      try {
        unsub = await _pb
            .collection(PbCollections.records)
            .subscribe(
              '*',
              _onPbRecordsSubscriptionEvent,
              filter: filter,
              expand: '$kPbRecordCategoryExpand,$kPbRecordTagsExpand',
            );
      } on ClientException catch (_) {
        unsub = await _pb
            .collection(PbCollections.records)
            .subscribe(
              '*',
              _onPbRecordsSubscriptionEvent,
              filter: filter,
              expand: kPbRecordCategoryExpand,
            );
      } catch (_) {
        unsub = await _pb
            .collection(PbCollections.records)
            .subscribe('*', _onPbRecordsSubscriptionEvent, filter: filter);
      }
      _recordsRealtimeUnsubscribe = unsub;
      await _ensureRealtimeRecoverySubscription();
      _recordsRealtimeFailureStreak = 0;
      _recordsRealtimeReconnectTimer?.cancel();
      _recordsRealtimeReconnectTimer = null;
    } catch (e) {
      _realtimeTransportGapDetected = true;
      _logRecordsRealtimeSubscribeQuiet(e);
      _handleRealtimeSubscribeFailure(e, source: 'records');
      _scheduleRecordsRealtimeReconnectAfterFailure();
    }
  }
}
