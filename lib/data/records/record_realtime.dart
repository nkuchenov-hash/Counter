part of '../database_service.dart';

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
      _logRecordsRealtimeSubscribeQuiet('realtime_endpoint_unavailable');
      return;
    }
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
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
      _recordsRealtimeFailureStreak = 0;
      _recordsRealtimeReconnectTimer?.cancel();
      _recordsRealtimeReconnectTimer = null;
    } catch (e) {
      _logRecordsRealtimeSubscribeQuiet(e);
      _handleRealtimeSubscribeFailure(e, source: 'records');
      _scheduleRecordsRealtimeReconnectAfterFailure();
    }
  }
}
