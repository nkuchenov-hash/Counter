// ignore_for_file: unused_import
part of 'database_service.dart';

/// Bootstrap, PocketBase init/health, lifecycle observer, realtime reconnect,
/// loadInitialData, clearLocalStateOnSignOut.
extension DbCoreExtension on DatabaseService {
  // ---------------------------------------------------------------------------
  // PocketBase init & health
  // ---------------------------------------------------------------------------

  Future<void> ensurePocketBaseReady() async {
    if (_pocketBase == null) {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = kPocketBaseUrl;
      _pocketBase = PocketBase(
        baseUrl,
        authStore: AsyncAuthStore(
          save: (data) async => prefs.setString(DatabaseService._pbAuthPrefsKey, data),
          initial: prefs.getString(DatabaseService._pbAuthPrefsKey),
          clear: () async => prefs.remove(DatabaseService._pbAuthPrefsKey),
        ),
      );
      if (kDebugMode && !_pbHttpBackoffActive) {
        debugPrint('[PB_BASE_URL] $baseUrl');
        debugPrint(
          '[PB] PocketBase SDK ready — base URL $baseUrl (auth prefs key $DatabaseService._pbAuthPrefsKey)',
        );
      }
    }
    await _maybeVerifyPocketBaseReachable();
    SyncManager.instance.attachIfNeeded();
  }

  Future<void> _maybeVerifyPocketBaseReachable() async {
    final now = DateTime.now();
    final until = _pbNextAllowedNetworkAt;
    if (until != null && now.isBefore(until)) {
      return;
    }
    final lastProbe = _pbLastHealthProbeAt;
    if (lastProbe != null &&
        _pbLastHealthOk == true &&
        now.difference(lastProbe) < DatabaseService._kMinGapHealthWhenOk) {
      return;
    }
    try {
      await _pb.health.check();
      _clearPocketBaseConnectivityBackoff();
      _pbLastHealthProbeAt = DateTime.now();
      final wasOk = _pbLastHealthOk;
      _pbLastHealthOk = true;
      if (kDebugMode && wasOk != true) {
        debugPrint('[PB] /api/health OK — $kPocketBaseUrl');
      }
    } catch (e) {
      _registerPocketBaseUnreachable(e);
    }
  }

  void _registerPocketBaseUnreachable(Object e) {
    _pbNextAllowedNetworkAt =
        DateTime.now().add(const Duration(seconds: DatabaseService._pbCircuitCooldownSeconds));
    _pbLastHealthProbeAt = DateTime.now();
    final wasOk = _pbLastHealthOk;
    _pbLastHealthOk = false;
    if (kDebugMode && wasOk != false) {
      debugPrint(
        '[PB] /api/health failed — circuit ${DatabaseService._pbCircuitCooldownSeconds}s: $e',
      );
    }
  }

  void _clearPocketBaseConnectivityBackoff() {
    _pbNextAllowedNetworkAt = null;
  }

  bool _isPbCircuitWorthyFailure(Object e) {
    if (e is ClientException) {
      final c = e.statusCode;
      if (c == 404) return true;
      if (c >= 500) return true;
      if (c <= 0) return true;
      final blob = '${e.originalError} $e'.toLowerCase();
      if (blob.contains('socket') ||
          blob.contains('connection refused') ||
          blob.contains('failed host lookup') ||
          blob.contains('network is unreachable') ||
          blob.contains('timed out') ||
          blob.contains('connection reset')) {
        return true;
      }
    }
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('connection refused') ||
        s.contains('failed host lookup') ||
        s.contains('connection reset') ||
        s.contains('err_connection_refused');
  }

  void _maybeOpenPbCircuitFromListFailure(Object e, String reason) {
    if (!_isPbCircuitWorthyFailure(e)) return;
    _pbNextAllowedNetworkAt =
        DateTime.now().add(const Duration(seconds: DatabaseService._pbCircuitCooldownSeconds));
    if (kDebugMode) {
      debugPrint(
        '[PB] $reason — circuit ${DatabaseService._pbCircuitCooldownSeconds}s (404/connection): $e',
      );
    }
  }

  /// Same as [_maybeVerifyPocketBaseReachable] — used from [_loadInner] (debug builds).
  Future<void> _debugPocketBaseHealth() async {
    await _maybeVerifyPocketBaseReachable();
  }

  // ---------------------------------------------------------------------------
  // Realtime reconnect
  // ---------------------------------------------------------------------------

  /// Re-subscribe to `records` + `plans` realtime after auth when init ran without a session.
  Future<void> ensureRecordsRealtimeBridge() async {
    _recordsRealtimeReconnectTimer?.cancel();
    _recordsRealtimeReconnectTimer = null;
    _recordsRealtimeFailureStreak = 0;
    unawaited(_startRecordsRealtimeSubscription());
    unawaited(ensurePlansRealtimeBridge());
  }

  Duration _recordsRealtimeDelayForCurrentFailureStreak() {
    final idx =
        _recordsRealtimeFailureStreak.clamp(0, DatabaseService._kRealtimeBackoffSeconds.length - 1);
    return Duration(seconds: DatabaseService._kRealtimeBackoffSeconds[idx]);
  }

  void _logRecordsRealtimeSubscribeQuiet(Object e) {
    final now = DateTime.now();
    if (_lastRealtimeSubscribeErrorLogAt != null &&
        now.difference(_lastRealtimeSubscribeErrorLogAt!) <
            const Duration(seconds: 5)) {
      return;
    }
    _lastRealtimeSubscribeErrorLogAt = now;
    DatabaseService._log(
      'records realtime subscribe failed (next backoff ${_recordsRealtimeDelayForCurrentFailureStreak().inSeconds}s): $e',
    );
  }

  void _scheduleRecordsRealtimeReconnectAfterFailure() {
    if (!_hasAuthenticatedUserId) return;
    _recordsRealtimeReconnectTimer?.cancel();
    final delay = _recordsRealtimeDelayForCurrentFailureStreak();
    if (_recordsRealtimeFailureStreak < DatabaseService._kRealtimeBackoffSeconds.length) {
      _recordsRealtimeFailureStreak++;
    }
    _recordsRealtimeReconnectTimer = Timer(delay, () {
      _recordsRealtimeReconnectTimer = null;
      unawaited(_startRecordsRealtimeSubscription());
    });
  }

  // ---------------------------------------------------------------------------
  // Cache hydration
  // ---------------------------------------------------------------------------

  Future<void> _hydrateRecordsCacheFromPrefsIfEmpty() async {
    if (_cachedFlatRecords.isNotEmpty) return;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(_scopedDataCacheKey(DatabaseService._cacheRecordsFlatKey));
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _cachedFlatRecords = [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Lifecycle observer
  // ---------------------------------------------------------------------------

  void _registerAppLifecycleObserverOnce() {
    if (DatabaseService._appLifecycleObserverRegistered) return;
    DatabaseService._appLifecycleObserver.onResumed = () {
      unawaited(refreshForegroundData());
    };
    WidgetsBinding.instance.addObserver(DatabaseService._appLifecycleObserver);
    DatabaseService._appLifecycleObserverRegistered = true;
  }

  void _unregisterAppLifecycleObserver() {
    if (!DatabaseService._appLifecycleObserverRegistered) return;
    WidgetsBinding.instance.removeObserver(DatabaseService._appLifecycleObserver);
    DatabaseService._appLifecycleObserverRegistered = false;
    DatabaseService._appLifecycleObserver.onResumed = null;
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  void clearLocalStateOnSignOut() {
    _unregisterAppLifecycleObserver();
    _planAlarmRescheduleDebounceTimer?.cancel();
    _planAlarmRescheduleDebounceTimer = null;
    _planningNotifyNetworkDebounceTimer?.cancel();
    _planningNotifyNetworkDebounceTimer = null;
    unawaited(_cancelPlansRealtimeSubscription());
    _allPlansUserCache = [];
    _allPlansUserCacheFetchedAt = null;
    _recordsRealtimeReconnectTimer?.cancel();
    _recordsRealtimeReconnectTimer = null;
    _recordsRealtimeFailureStreak = 0;
    _lastRealtimeSubscribeErrorLogAt = null;
    unawaited(_cancelRecordsRealtimeSubscription());
    try {
      _pocketBase?.authStore.clear();
    } catch (_) {}
    _clearPocketBaseConnectivityBackoff();
    _lastSuccessfulRecordsNetworkFetchAt = null;
    _pbLastHealthProbeAt = null;
    _pbLastHealthOk = null;
    try {
      _isInitialized = false;
      currentProfileId = null;
      _loadErrorMessage = null;
      _rules = [];
      _reservedCategorySlugsLower.clear();
      _categoryDialogUniverse = [];
      _tasksCache = [];
      _cachedFlatRecords = [];
      _settings = UserSettings(userId: '');
      _userTagsCatalogCache = [];
      _lastAggregatedKey = null;
      _lastStatsNodeRoots = null;
      _recordRestDefinitive404Keys.clear();
      _planningOptimisticByDateKey.clear();
      _primaryHighlanderNetworkChain = Future.value();
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      currentLocale.value = 'en';
      clearOptimisticTimelineUi();
      _stopRecordInFlightKeys.clear();
      _writeRecordMutationInFlight = false;
      _cancelPlanOrderDebounceTimer();
      _pendingPlanOrderSyncList = null;
      _planReorderBaselineByPlanId = null;
      _cancelCategoryOrderDebounceTimer();
      _pendingCategoryOrderSyncList = null;
      _categoryReorderBaselineByLocalId = null;
      _profilePbRecordId = null;
    } catch (_) {}
    unawaited(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        await prefs.remove(_profileThemeModeKey);
      } catch (_) {}
    }());
  }

  // ---------------------------------------------------------------------------
  // Data region
  // ---------------------------------------------------------------------------

  Future<void> setDataRegion(String region) async {
    _dataRegion = region == 'russia' ? 'russia' : 'global';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dataRegionKey, _dataRegion);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Load initial data
  // ---------------------------------------------------------------------------

  Future<bool> loadInitialData(String uid) async {
    await ensurePocketBaseReady();
    _isInitialized = false;
    _loadErrorMessage = null;
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      _loadErrorMessage = 'Invalid profile';
      _isInitialized = true;
      return false;
    }
    currentProfileId = trimmed;
    try {
      await _loadInner().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          final aid = _userIdForWhere ?? '';
          _settings = UserSettings(userId: aid.isNotEmpty ? aid : trimmed);
          _settingsController.add(_settings);
        },
      );
      return true;
    } on _ProfileFetchFailedException catch (e) {
      try {
        await onSessionInvalid?.call();
      } catch (_) {}
      clearLocalStateOnSignOut();
      _loadErrorMessage = e.message ?? 'Session invalid or profile not found';
      _isInitialized = true;
      return false;
    } catch (e, st) {
      // ignore: avoid_print
      print('DatabaseService.loadInitialData failed: $e\n$st');
      _isInitialized = true;
      _loadErrorMessage = 'Sync Error: $e';
      _settingsController.add(_settings);
      return true;
    }
  }

  /// Wear OS companion: skips planning fetch and startup maintenance.
  Future<bool> loadInitialDataWearLite(String uid) async {
    await ensurePocketBaseReady();
    _isInitialized = false;
    _loadErrorMessage = null;
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      _loadErrorMessage = 'Invalid profile';
      _isInitialized = true;
      return false;
    }
    currentProfileId = trimmed;
    try {
      await _loadInnerWearLite().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          final aid = _userIdForWhere ?? '';
          _settings = UserSettings(userId: aid.isNotEmpty ? aid : trimmed);
          _settingsController.add(_settings);
        },
      );
      return true;
    } on _ProfileFetchFailedException catch (e) {
      try {
        await onSessionInvalid?.call();
      } catch (_) {}
      clearLocalStateOnSignOut();
      _loadErrorMessage = e.message ?? 'Session invalid or profile not found';
      _isInitialized = true;
      return false;
    } catch (e, st) {
      // ignore: avoid_print
      print('DatabaseService.loadInitialDataWearLite failed: $e\n$st');
      _isInitialized = true;
      _loadErrorMessage = 'Sync Error: $e';
      _settingsController.add(_settings);
      return true;
    }
  }

  Future<void> _loadInnerWearLite() async {
    _prefs = await SharedPreferences.getInstance();
    await _debugPocketBaseHealth();
    if (_pbHttpBackoffActive) {
      _loadErrorMessage ??= 'PocketBase unreachable; retry scheduled.';
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      _isInitialized = true;
      return;
    }
    await _loadSettingsFromNoco();
    await _loadRulesFromNoco();
    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
    } catch (_) {}
    _settingsController.add(_settings);
    _categoryController.add(List.from(_rules));
    _tasksController.add(List.from(_tasksCache));
    _isInitialized = true;
    _registerAppLifecycleObserverOnce();
    // LAW_OF_THE_MAIN_THREAD / Wear-lite: do not block watch bootstrap on realtime socket.
    unawaited(
      _startRecordsRealtimeSubscription().catchError((Object _, StackTrace _) {}),
    );
  }

  Future<void> _loadInner() async {
    _prefs = await SharedPreferences.getInstance();
    await _debugPocketBaseHealth();
    if (_pbHttpBackoffActive) {
      _loadErrorMessage ??= 'PocketBase unreachable; retry scheduled.';
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      _isInitialized = true;
      unawaited(offlineSync.refreshPendingCount());
      unawaited(flushPendingLocalMutations());
      return;
    }
    await _loadSettingsFromNoco();
    await _loadRulesFromNoco();
    try {
      await _fetchRecordsIntoCache(forceNetwork: true);
      await _reconcileDuplicatePrimaryRunningRecords();
    } catch (_) {}
    await _loadPlanningTasksForToday();
    // Safety re-run: finish startup with a final category load.
    await _loadRulesFromNoco();
    _settingsController.add(_settings);
    _categoryController.add(List.from(_rules));
    _tasksController.add(List.from(_tasksCache));
    // Shell must not treat Brain as ready until profile settings + categories + tasks are loaded.
    _isInitialized = true;
    _registerAppLifecycleObserverOnce();
    try {
      await _startRecordsRealtimeSubscription();
    } catch (_) {}
    unawaited(
      _startPlansRealtimeSubscription().catchError((Object _, StackTrace _) {}),
    );
    unawaited(() async {
      await _ensureAllPlansUserCacheFresh(force: true);
      notifyPlanningRefresh(scheduleNetworkRefresh: false, pumpNetworkNow: true);
    }());
    unawaited(
      _runOneShotUntitledGhostRecordCleanDeferred()
          .catchError((Object _, StackTrace _) {}),
    );
    unawaited(offlineSync.refreshPendingCount());
    unawaited(flushPendingLocalMutations());
  }

  /// Foreground/resume refresh: records + today's plans + stream pumps (no user input required).
  Future<void> refreshForegroundData() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return;
    if (!_isInitialized) return;
    unawaited(offlineSync.refreshPendingCount());
    unawaited(flushPendingLocalMutations());
    if (_pbHttpBackoffActive) return;
    try {
      _lastSuccessfulRecordsNetworkFetchAt = null;
      await _fetchRecordsIntoCache(forceNetwork: true);
      await _reconcileDuplicatePrimaryRunningRecords();
      await _ensureAllPlansUserCacheFresh(force: true);
      await _loadPlanningTasksForToday();
      notifyPlanningRefresh(scheduleNetworkRefresh: false, pumpNetworkNow: true);
      try {
        await _startRecordsRealtimeSubscription();
      } catch (_) {}
      unawaited(
        _startPlansRealtimeSubscription().catchError((Object _, StackTrace _) {}),
      );
    } catch (_) {}
  }

  /// Drains all local PocketBase mutation outboxes (records + plans/lists).
  Future<void> flushPendingLocalMutations() async {
    if (_hasAuthenticatedUserId) {
      try {
        if (_pb.authStore.isValid) {
          offlineSync.resumeAfterAuthIfNeeded();
        }
      } catch (_) {}
    }
    await flushPendingRecordMutations();
    await flushPendingPlanMutations();
    unawaited(offlineSync.refreshPendingCount());
  }
}
