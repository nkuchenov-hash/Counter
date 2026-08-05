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
    _attachPocketBaseRealtimeGuards();
    SyncManager.instance.attachIfNeeded();
  }

  void _attachPocketBaseRealtimeGuards() {
    if (_pocketBaseRealtimeGuardsAttached || _pocketBase == null) return;
    _pocketBaseRealtimeGuardsAttached = true;
    _pocketBase!.realtime.onDisconnect = (_) {
      if (isPbRealtimeUnavailable) return;
      _scheduleRecordsRealtimeReconnectAfterFailure();
      _schedulePlansRealtimeReconnectAfterFailure();
      _scheduleCatalogRealtimeReconnectAfterFailure();
    };
  }

  bool _isRealtimeEndpointUnavailableError(Object e) {
    if (e is ClientException && e.statusCode == 404) return true;
    final s = e.toString().toLowerCase();
    return s.contains('/api/realtime') && s.contains('404') ||
        s.contains('failed to establish sse');
  }

  void _markRealtimeEndpointUnavailable(Object e, {String source = 'realtime'}) {
    if (!_isRealtimeEndpointUnavailableError(e) &&
        !(e is ClientException && e.statusCode == 404)) {
      return;
    }
    const retryDelay = Duration(seconds: 30);
    _realtimeEndpointUnavailableUntil = DateTime.now().add(retryDelay);
    planStreamLifecycleLog(
      'realtimeSubscribe status=error code=404 source=$source '
      'retryAt=${_realtimeEndpointUnavailableUntil!.toIso8601String()}',
    );
    unawaited(_cancelRecordsRealtimeSubscription());
    unawaited(_cancelPlansRealtimeSubscription());
    unawaited(_cancelCatalogRealtimeSubscriptions());
    _recordsRealtimeReconnectTimer?.cancel();
    _plansRealtimeReconnectTimer?.cancel();
    _catalogRealtimeReconnectTimer?.cancel();
    _recordsRealtimeReconnectTimer = Timer(retryDelay, () {
      _recordsRealtimeReconnectTimer = null;
      _realtimeEndpointUnavailableUntil = null;
      if (!_hasAuthenticatedUserId) return;
      unawaited(_startRecordsRealtimeSubscription());
      unawaited(_startPlansRealtimeSubscription());
      unawaited(_startCatalogRealtimeSubscriptions());
    });
    offlineSync.reconcileStuckSyncingBanner(
      syncFlushInFlight: isSyncFlushInFlight,
    );
  }

  void _handleRealtimeSubscribeFailure(Object e, {required String source}) {
    if (_isRealtimeEndpointUnavailableError(e) ||
        (e is ClientException && e.statusCode == 404)) {
      _markRealtimeEndpointUnavailable(e, source: source);
      return;
    }
    planStreamLifecycleLog(
      'realtimeSubscribe status=error source=$source exception=$e',
    );
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
    if (isPbRealtimeUnavailable) return;
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
    if (isPbRealtimeUnavailable) return;
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
      _syncCanonicalRunningBusinessIdCache('prefsHydrate');
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
    unawaited(NotificationService.instance.cancelAllPlanReminders());
    unawaited(_cancelPlansRealtimeSubscription());
    unawaited(_cancelCatalogRealtimeSubscriptions());
    _catalogRealtimeReconnectTimer?.cancel();
    _catalogRealtimeReconnectTimer = null;
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
      _resetCanonicalRunningBusinessIdCache();
      _timelineWarmWindow?.invalidateAll();
      _plansWarmWindow?.invalidateAll();
      _timelineBodyCache?.invalidateAll();
      _plansBodyCache?.invalidateAll();
      _settings = UserSettings(userId: '');
      _profileHydratedFromPb = false;
      _profileHydrationError = null;
      _profilePbRecordId = null;
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
        await prefs.remove(_profileTzLabelKey);
        await prefs.remove(_profileTzOffsetKey);
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
    _profileHydratedFromPb = false;
    _profileHydrationError = null;
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      _loadErrorMessage = 'Invalid profile';
      _isInitialized = true;
      return false;
    }
    currentProfileId = trimmed;
    try {
      _prefs = await SharedPreferences.getInstance();
      await _debugPocketBaseHealth();
      await StartupLog.stageAsync(
        'profileFetch',
        () => _loadSettingsFromNoco().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw _ProfileFetchFailedException(
              0,
              'Could not load your profile settings.',
            );
          },
        ),
        blocksFirstFrame: true,
      );
      await StartupLog.stageAsync(
        'localCacheRestore',
        () => _loadInnerAfterProfile().timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            _loadErrorMessage ??=
                'Data sync timed out; profile loaded — tap Profile to retry sync.';
          },
        ),
        blocksFirstFrame: true,
      );
      return true;
    } on _ProfileFetchFailedException catch (e) {
      _profileHydratedFromPb = false;
      _profileHydrationError =
          e.message ?? 'Could not load your profile settings.';
      _loadErrorMessage = _profileHydrationError;
      _isInitialized = false;
      return false;
    } catch (e, st) {
      // ignore: avoid_print
      print('DatabaseService.loadInitialData failed: $e\n$st');
      if (!_profileHydratedFromPb) {
        _profileHydrationError ??= 'Could not load your profile settings.';
        _isInitialized = false;
        return false;
      }
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
    _profileHydratedFromPb = false;
    _profileHydrationError = null;
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      _loadErrorMessage = 'Invalid profile';
      _isInitialized = true;
      return false;
    }
    currentProfileId = trimmed;
    try {
      _prefs = await SharedPreferences.getInstance();
      await _debugPocketBaseHealth();
      await _loadSettingsFromNoco().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw _ProfileFetchFailedException(
            0,
            'Could not load your profile settings.',
          );
        },
      );
      await _loadInnerWearLiteAfterProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _loadErrorMessage ??= 'Wear data sync timed out.';
        },
      );
      return true;
    } on _ProfileFetchFailedException catch (e) {
      _profileHydratedFromPb = false;
      _profileHydrationError =
          e.message ?? 'Could not load your profile settings.';
      _loadErrorMessage = _profileHydrationError;
      _isInitialized = false;
      return false;
    } catch (e, st) {
      // ignore: avoid_print
      print('DatabaseService.loadInitialDataWearLite failed: $e\n$st');
      if (!_profileHydratedFromPb) {
        _profileHydrationError ??= 'Could not load your profile settings.';
        _isInitialized = false;
        return false;
      }
      _isInitialized = true;
      _loadErrorMessage = 'Sync Error: $e';
      _settingsController.add(_settings);
      return true;
    }
  }

  Future<void> _loadInnerWearLiteAfterProfile() async {
    if (_pbHttpBackoffActive) {
      await bootstrapTimelineRecordsCacheFromPrefsAtBoot();
      _loadErrorMessage ??= 'PocketBase unreachable; retry scheduled.';
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      _isInitialized = true;
      return;
    }
    await _loadRulesFromNoco();
    await bootstrapTimelineRecordsCacheFromPrefsAtBoot();
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

  Future<void> _loadInnerAfterProfile() async {
    if (_pbHttpBackoffActive) {
      await bootstrapTimelineRecordsCacheFromPrefsAtBoot(criticalOnly: true);
      await restorePlansWarmSnapshotsFromDiskAtBoot();
      await DatabaseService.instance.scrubPersistedPlanningDayCachesOnRestore();
      await restoreTimelineWarmSnapshotsFromDiskAtBoot();
      _loadErrorMessage ??= 'PocketBase unreachable; retry scheduled.';
      _settingsController.add(_settings);
      _categoryController.add(List.from(_rules));
      _tasksController.add(List.from(_tasksCache));
      _isInitialized = true;
      _registerAppLifecycleObserverOnce();
      StartupLog.scheduleAfterFirstFrame(
        'deferredBootWork',
        _runDeferredBootWorkAfterFirstShell,
      );
      return;
    }
    await _loadRulesFromNoco();
    await bootstrapTimelineRecordsCacheFromPrefsAtBoot(criticalOnly: true);
    await restorePlansWarmSnapshotsFromDiskAtBoot();
    await restoreTimelineWarmSnapshotsFromDiskAtBoot();
    _settingsController.add(_settings);
    _categoryController.add(List.from(_rules));
    _tasksController.add(List.from(_tasksCache));
    _isInitialized = true;
    _registerAppLifecycleObserverOnce();
    StartupLog.scheduleAfterFirstFrame(
      'deferredBootWork',
      _runDeferredBootWorkAfterFirstShell,
    );
  }

  /// Non-critical boot work — runs after first rendered frame (P0U.3).
  Future<void> _runDeferredBootWorkAfterFirstShell() async {
    final projected = getProjectedToday();
    final timelineToday = getTimelineDeviceLocalToday();
    // Subscribe first so cross-device changes arriving during catch-up are not missed.
    if (!_pbHttpBackoffActive) {
      try {
        await Future.wait<void>([
          _startRecordsRealtimeSubscription(),
          _startPlansRealtimeSubscription(),
          _startCatalogRealtimeSubscriptions(),
        ]);
      } catch (_) {}
    }
    if (kUseMountedDayStrip) {
      preparePlansMountedWindowBoot(projected, criticalOnly: true);
      prepareTimelineMountedWindowBoot(timelineToday, criticalOnly: true);
      preparePlansCriticalRenderReady(projected);
      prepareTimelineCriticalRenderReady(timelineToday);
      schedulePlansMountedWindowBootBackground(projected);
      scheduleTimelineMountedWindowBootBackground(timelineToday);
    } else {
      StartupLog.deferred(
        name: 'plansWarmWindow',
        reason: 'backgroundOnly',
      );
      StartupLog.deferred(
        name: 'timelineWarmWindow',
        reason: 'backgroundOnly',
      );
      final warmSw = Stopwatch()..start();
      if (kPlansWarmWindowEnabled) {
        ensurePlansWarmWindow(projected);
        StartupLog.deferredConfirmedAfterFrame(name: 'plansWarmWindow');
      } else {
        StartupLog.deferred(
          name: 'plansWarmWindow',
          reason: 'p0DuplicateSafetyDisabled',
        );
      }
      ensureTimelineWarmWindow(timelineToday);
      prebuildTimelineCriticalBodiesSync(timelineToday);
      StartupLog.deferredConfirmedAfterFrame(name: 'recordsWarmWindow');
      warmSw.stop();
      StartupLog.bootStage(
        name: 'plansWarmWindow',
        ms: warmSw.elapsedMilliseconds,
        blocksFirstFrame: false,
      );
      StartupLog.bootStage(
        name: 'recordsWarmWindow',
        ms: warmSw.elapsedMilliseconds,
        blocksFirstFrame: false,
      );
    }
    if (!_pbHttpBackoffActive) {
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
        await _reconcileDuplicatePrimaryRunningRecords();
      } catch (_) {}
      try {
        await _loadPlanningTasksForToday();
      } catch (_) {}
      unawaited(_loadRulesFromNoco().catchError((Object _, StackTrace _) {}));
      persistPlansWarmSnapshotsToDisk();
      persistTimelineWarmSnapshotsToDisk();
    }
    StartupLog.deferred(
      name: 'syncBootstrap',
      reason: 'canRunAfterShell',
    );
    unawaited(() async {
      try {
        await _ensureAllPlansUserCacheFresh(force: true);
        notifyPlanningRefresh(scheduleNetworkRefresh: false, pumpNetworkNow: true);
      } catch (_) {}
    }());
    unawaited(
      _runOneShotUntitledGhostRecordCleanDeferred()
          .catchError((Object _, StackTrace _) {}),
    );
    final syncSw = Stopwatch()..start();
    try {
      await offlineSync.bootstrapFromOutboxes(
        pbBackoffActive: _pbHttpBackoffActive,
      );
      await flushPendingLocalMutations();
    } catch (_) {}
    syncSw.stop();
    StartupLog.bootStage(
      name: 'syncBootstrap',
      ms: syncSw.elapsedMilliseconds,
      blocksFirstFrame: false,
    );
    StartupLog.markInteractive();
  }

  /// Foreground/resume refresh: records + today's plans + stream pumps (no user input required).
  Future<void> refreshForegroundData() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return;
    if (!_isInitialized) return;
    await offlineSync.bootstrapFromOutboxes(
      pbBackoffActive: _pbHttpBackoffActive,
    );
    // Re-arm push channels before flush/catch-up. The following fetch is a one-shot
    // reconciliation for events missed while the app was suspended, never polling.
    if (!_pbHttpBackoffActive) {
      try {
        await Future.wait<void>([
          _startRecordsRealtimeSubscription(),
          _startPlansRealtimeSubscription(),
          _startCatalogRealtimeSubscriptions(),
        ]);
      } catch (_) {}
    }
    await flushPendingLocalMutations();
    if (_pbHttpBackoffActive) return;
    try {
      _lastSuccessfulRecordsNetworkFetchAt = null;
      await _fetchRecordsIntoCache(forceNetwork: true);
      await _reconcileDuplicatePrimaryRunningRecords();
      await _ensureAllPlansUserCacheFresh(force: true);
      await _loadPlanningTasksForToday();
      notifyPlanningRefresh(scheduleNetworkRefresh: false, pumpNetworkNow: true);
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
    await offlineSync.refreshPendingCount();
    offlineSync.reconcileStuckSyncingBanner(
      syncFlushInFlight: isSyncFlushInFlight,
    );
    offlineSync.reconcileAfterDrain();
  }
}
