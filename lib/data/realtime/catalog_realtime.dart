part of '../database_service.dart';

Future<void> Function()? _categoriesRealtimeUnsubscribe;
Future<void> Function()? _tagsRealtimeUnsubscribe;
Future<void> Function()? _profileRealtimeUnsubscribe;
Future<void>? _catalogRealtimeSubscribeFuture;
Timer? _catalogRealtimeReconnectTimer;
Timer? _categoryRealtimeRefreshDebounce;
Timer? _tagRealtimeRefreshDebounce;
Timer? _profileRealtimeRefreshDebounce;
int _catalogRealtimeFailureStreak = 0;

extension CatalogRealtimeExtension on DatabaseService {
  String? _catalogOwnerFilter() {
    final uid = _userIdForWhere?.trim() ?? '';
    if (uid.isEmpty) return null;
    return 'user_id = "${_escapeForPbFilter(uid)}"';
  }

  void _onCategoryRealtimeEvent(RecordSubscriptionEvent _) {
    _categoryRealtimeRefreshDebounce?.cancel();
    _categoryRealtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 40),
      () => unawaited(_loadRulesFromNoco()),
    );
  }

  void _onTagRealtimeEvent(RecordSubscriptionEvent _) {
    _tagRealtimeRefreshDebounce?.cancel();
    _tagRealtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 40),
      () => unawaited(() async {
        await fetchTagsForCurrentUser(scope: TagCatalogScope.plan);
        notifyTagsCatalogChanged();
      }()),
    );
  }

  void _onProfileRealtimeEvent(RecordSubscriptionEvent e) {
    final authId = _userIdForWhere?.trim() ?? '';
    final rowId = e.record?.id.trim() ?? '';
    if (authId.isEmpty || (rowId.isNotEmpty && rowId != authId)) return;
    _profileRealtimeRefreshDebounce?.cancel();
    _profileRealtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 40),
      () => unawaited(_loadSettingsFromNoco()),
    );
  }

  Future<void> _cancelCatalogRealtimeSubscriptions() async {
    final callbacks = <Future<void> Function()?>[
      _categoriesRealtimeUnsubscribe,
      _tagsRealtimeUnsubscribe,
      _profileRealtimeUnsubscribe,
    ];
    _categoriesRealtimeUnsubscribe = null;
    _tagsRealtimeUnsubscribe = null;
    _profileRealtimeUnsubscribe = null;
    for (final callback in callbacks) {
      if (callback == null) continue;
      try {
        await callback();
      } catch (_) {}
    }
  }

  Future<void> _startCatalogRealtimeSubscriptions() async {
    final existing = _catalogRealtimeSubscribeFuture;
    if (existing != null) return existing;
    final future = _startCatalogRealtimeSubscriptionsBody();
    _catalogRealtimeSubscribeFuture = future;
    try {
      await future;
    } finally {
      _catalogRealtimeSubscribeFuture = null;
    }
  }

  Future<void> _startCatalogRealtimeSubscriptionsBody() async {
    await _cancelCatalogRealtimeSubscriptions();
    if (!_hasAuthenticatedUserId || isPbRealtimeUnavailable) return;
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final filter = _catalogOwnerFilter();
      final authId = _userIdForWhere?.trim() ?? '';
      if (filter == null || authId.isEmpty) return;
      _categoriesRealtimeUnsubscribe = await _pb
          .collection(PbCollections.categories)
          .subscribe('*', _onCategoryRealtimeEvent, filter: filter);
      _tagsRealtimeUnsubscribe = await _pb
          .collection(PbCollections.tags)
          .subscribe('*', _onTagRealtimeEvent, filter: filter);
      _profileRealtimeUnsubscribe = await _pb
          .collection(PbCollections.profiles)
          .subscribe(authId, _onProfileRealtimeEvent);
      _catalogRealtimeFailureStreak = 0;
      _catalogRealtimeReconnectTimer?.cancel();
      _catalogRealtimeReconnectTimer = null;
    } catch (error) {
      await _cancelCatalogRealtimeSubscriptions();
      _handleRealtimeSubscribeFailure(error, source: 'catalogs');
      _scheduleCatalogRealtimeReconnectAfterFailure();
    }
  }

  void _scheduleCatalogRealtimeReconnectAfterFailure() {
    if (!_hasAuthenticatedUserId || isPbRealtimeUnavailable) return;
    _catalogRealtimeReconnectTimer?.cancel();
    final index = _catalogRealtimeFailureStreak.clamp(
      0,
      DatabaseService._kRealtimeBackoffSeconds.length - 1,
    );
    final delay = Duration(
      seconds: DatabaseService._kRealtimeBackoffSeconds[index],
    );
    if (_catalogRealtimeFailureStreak <
        DatabaseService._kRealtimeBackoffSeconds.length) {
      _catalogRealtimeFailureStreak++;
    }
    _catalogRealtimeReconnectTimer = Timer(delay, () {
      _catalogRealtimeReconnectTimer = null;
      unawaited(_startCatalogRealtimeSubscriptions());
    });
  }

  Future<void> ensureCatalogRealtimeBridge() async {
    _catalogRealtimeReconnectTimer?.cancel();
    _catalogRealtimeReconnectTimer = null;
    _catalogRealtimeFailureStreak = 0;
    await _startCatalogRealtimeSubscriptions();
  }
}
