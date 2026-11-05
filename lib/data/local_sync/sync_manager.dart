import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:counter/data/database_service.dart';

/// Watches connectivity and continuously drains local PocketBase mutation
/// outboxes whenever a valid online session can reach the server.
///
/// The outboxes are durability only: there is no user-facing pending-sync flow
/// and no manual retry is required.
class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();

  static const Duration _pendingRetryDelay = Duration(seconds: 2);

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pendingDrainTimer;
  Timer? _offlineRecoveryTimer;
  int _offlineRecoveryAttempts = 0;
  bool _attached = false;
  bool _drainInFlight = false;
  int _stalledDrainAttempts = 0;

  void attachIfNeeded() {
    if (_attached) return;
    _attached = true;
    final db = DatabaseService.instance;
    db.offlineSync.addListener(_onSyncStateChanged);
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    unawaited(_probeInitialConnectivity());
  }

  Future<void> _probeInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _applyConnectivity(results);
    } catch (_) {}
    await DatabaseService.instance.offlineSync.refreshPendingCount();
    _onSyncStateChanged();
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    _applyConnectivity(results);
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty) return;
    final onlyOffline =
        results.length == 1 && results.first == ConnectivityResult.none;
    final sync = DatabaseService.instance.offlineSync;
    sync.setConnectivityOffline(onlyOffline);
    if (onlyOffline) {
      _pendingDrainTimer?.cancel();
      _pendingDrainTimer = null;
      _scheduleOfflineRecovery();
      return;
    }
    _offlineRecoveryTimer?.cancel();
    _offlineRecoveryTimer = null;
    _offlineRecoveryAttempts = 0;
    _schedulePendingDrain();
  }

  void _onSyncStateChanged() {
    final sync = DatabaseService.instance.offlineSync;
    if (sync.pendingCount <= 0 || sync.authPaused) {
      _pendingDrainTimer?.cancel();
      _pendingDrainTimer = null;
      _offlineRecoveryTimer?.cancel();
      _offlineRecoveryTimer = null;
      if (sync.pendingCount <= 0) _offlineRecoveryAttempts = 0;
      return;
    }
    if (sync.isOffline) {
      _pendingDrainTimer?.cancel();
      _pendingDrainTimer = null;
      _scheduleOfflineRecovery();
      return;
    }
    _offlineRecoveryTimer?.cancel();
    _offlineRecoveryTimer = null;
    _schedulePendingDrain();
  }

  /// Connectivity events only signal interface changes. A failed PocketBase
  /// write can mark the app offline while Wi-Fi remains connected forever.
  /// Probe only with durable pending work; never poll full collections.
  void _scheduleOfflineRecovery() {
    final sync = DatabaseService.instance.offlineSync;
    if (!_attached || sync.pendingCount <= 0 || !sync.isOffline ||
        sync.authPaused || (_offlineRecoveryTimer?.isActive ?? false)) {
      return;
    }
    final step = _offlineRecoveryAttempts > 3 ? 3 : _offlineRecoveryAttempts;
    _offlineRecoveryTimer = Timer(Duration(seconds: 2 * (1 << step)), () {
      _offlineRecoveryTimer = null;
      unawaited(_probeOfflineRecovery());
    });
  }

  Future<void> _probeOfflineRecovery() async {
    final sync = DatabaseService.instance.offlineSync;
    if (!_attached || sync.pendingCount <= 0 || !sync.isOffline ||
        sync.authPaused) {
      return;
    }
    if (_offlineRecoveryAttempts < 3) _offlineRecoveryAttempts++;
    try {
      final results = await Connectivity().checkConnectivity();
      final hasNetwork = results.isNotEmpty &&
          !(results.length == 1 && results.first == ConnectivityResult.none);
      if (hasNetwork) {
        // The outbox attempt tests server reachability. If PocketBase is still
        // down, its failure re-arms this bounded recovery loop.
        sync.setConnectivityOffline(false);
        _schedulePendingDrain();
        return;
      }
    } catch (_) {}
    _scheduleOfflineRecovery();
  }

  void _schedulePendingDrain({Duration delay = Duration.zero}) {
    if (_drainInFlight || (_pendingDrainTimer?.isActive ?? false)) return;
    _pendingDrainTimer = Timer(delay, () {
      _pendingDrainTimer = null;
      unawaited(_drainPendingMutations());
    });
  }

  Future<void> _drainPendingMutations() async {
    if (_drainInFlight) return;
    final db = DatabaseService.instance;
    final sync = db.offlineSync;
    if (sync.pendingCount <= 0 || sync.isOffline || sync.authPaused) return;

    final countBefore = sync.pendingCount;
    _drainInFlight = true;
    try {
      await db.flushPendingLocalMutations();
    } catch (_) {
      // The durable outboxes keep failed mutations for the next automatic try.
    } finally {
      _drainInFlight = false;
    }

    if (sync.pendingCount <= 0) {
      _stalledDrainAttempts = 0;
      _offlineRecoveryAttempts = 0;
      return;
    }
    if (sync.pendingCount < countBefore) _offlineRecoveryAttempts = 0;
    if (sync.isOffline) {
      _scheduleOfflineRecovery();
      return;
    }
    if (sync.authPaused) return;
    final stalled = sync.pendingCount >= countBefore &&
        (sync.lastError?.isNotEmpty ?? false);
    _stalledDrainAttempts = stalled
        ? (_stalledDrainAttempts < 8 ? _stalledDrainAttempts + 1 : 8)
        : 0;
    // Transient failures recover quickly; validation failures back off
    // automatically instead of hammering the endpoint every two seconds.
    final seconds = 2 * (1 << _stalledDrainAttempts);
    _schedulePendingDrain(delay: stalled
        ? Duration(seconds: seconds > 300 ? 300 : seconds)
        : _pendingRetryDelay);
  }

  Future<void> dispose() async {
    _pendingDrainTimer?.cancel();
    _pendingDrainTimer = null;
    _offlineRecoveryTimer?.cancel();
    _offlineRecoveryTimer = null;
    _offlineRecoveryAttempts = 0;
    DatabaseService.instance.offlineSync.removeListener(_onSyncStateChanged);
    await _sub?.cancel();
    _sub = null;
    _attached = false;
  }
}
