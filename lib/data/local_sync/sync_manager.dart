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
  bool _attached = false;
  bool _drainInFlight = false;

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
      return;
    }
    _schedulePendingDrain();
  }

  void _onSyncStateChanged() {
    final sync = DatabaseService.instance.offlineSync;
    if (sync.pendingCount <= 0 || sync.isOffline || sync.authPaused) {
      if (sync.pendingCount <= 0 || sync.isOffline) {
        _pendingDrainTimer?.cancel();
        _pendingDrainTimer = null;
      }
      return;
    }
    _schedulePendingDrain();
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

    _drainInFlight = true;
    try {
      await db.flushPendingLocalMutations();
    } catch (_) {
      // The durable outboxes keep failed mutations for the next automatic try.
    } finally {
      _drainInFlight = false;
    }

    if (sync.pendingCount > 0 && !sync.isOffline && !sync.authPaused) {
      _schedulePendingDrain(delay: _pendingRetryDelay);
    }
  }

  Future<void> dispose() async {
    _pendingDrainTimer?.cancel();
    _pendingDrainTimer = null;
    DatabaseService.instance.offlineSync.removeListener(_onSyncStateChanged);
    await _sub?.cancel();
    _sub = null;
    _attached = false;
  }
}
