import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:counter/data/database_service.dart';

/// Watches connectivity and drains the local PocketBase mutation outbox when online.
///
/// Logic stays thin; [DatabaseService] owns queues and I/O (@ARCHITECTURE).
class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _attached = false;

  void attachIfNeeded() {
    if (_attached) return;
    _attached = true;
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    unawaited(_probeInitialConnectivity());
  }

  Future<void> _probeInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _applyConnectivity(results);
    } catch (_) {}
    unawaited(DatabaseService.instance.offlineSync.refreshPendingCount());
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    _applyConnectivity(results);
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty) return;
    final onlyOffline =
        results.length == 1 && results.first == ConnectivityResult.none;
    DatabaseService.instance.offlineSync.setConnectivityOffline(onlyOffline);
    if (onlyOffline) return;
    unawaited(DatabaseService.instance.flushPendingLocalMutations());
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _attached = false;
  }
}
