import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// App-lifecycle coordinator for sleep ingestion.
/// UI widgets must not own Health Connect / cloud reconciliation.
class SleepForegroundReconcileService with WidgetsBindingObserver {
  SleepForegroundReconcileService._();

  static final SleepForegroundReconcileService instance =
      SleepForegroundReconcileService._();

  static const Duration _foregroundPocketBaseCatchUpInterval =
      Duration(seconds: 30);

  bool _started = false;
  bool _reconcileRunning = false;
  bool _catchUpRunning = false;
  String? _catchUpOwner;
  DateTime? _lastMissingSleepPull;
  static const _missingSleepPullInterval = Duration(minutes: 5);
  Timer? _foregroundCatchUpTimer;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _startForegroundCatchUpTimer();
    unawaited(reconcile());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _foregroundCatchUpTimer?.cancel();
    _foregroundCatchUpTimer = null;
    _catchUpOwner = null;
    _lastMissingSleepPull = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _startForegroundCatchUpTimer() {
    _foregroundCatchUpTimer?.cancel();
    _foregroundCatchUpTimer = Timer.periodic(
      _foregroundPocketBaseCatchUpInterval,
      (_) {
        if (!_started ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          return;
        }
        unawaited(_catchUpFromPocketBase());
      },
    );
  }

  Future<void> reconcile() async {
    if (_reconcileRunning) return;
    _reconcileRunning = true;
    try {
      // PocketBase is the authoritative, shared sleep source on every
      // platform. Never wait for Android Health Connect permission, a device
      // plugin, or a local import before displaying server-backed sleep.
      final db = DatabaseService.instance;
      if (db.isInitialized && (db.currentProfileId?.isNotEmpty == true)) {
        try {
          await db.getRecords(forceNetwork: true);

          final localNow = db.applyUserOffset(DatabaseService.getPlanetaryNow());
          if (!_hasTodayXiaomiSleep(db, localNow)) {
            // A missing current Xiaomi night can trigger a server sync now;
            // syncNow itself refreshes PocketBase records on success.
            await _syncCloudSleepNow();
          }
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Sleep PocketBase reconciliation failed: $error');
          }
        }
      }

      // Device imports are optional, device-local enrichment. Their
      // availability or errors must not gate the shared PocketBase read.
      try {
        await _syncDeviceSleep();
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Optional device sleep sync failed: $error');
        }
      }
    } finally {
      _reconcileRunning = false;
    }
  }

  Future<void> _catchUpFromPocketBase() async {
    if (_catchUpRunning || _reconcileRunning) return;
    _catchUpRunning = true;
    try {
      final db = DatabaseService.instance;
      if (!db.isInitialized || (db.currentProfileId?.isNotEmpty != true)) return;
      final owner = db.currentProfileId;
      if (_catchUpOwner != owner) {
        _catchUpOwner = owner;
        _lastMissingSleepPull = null;
      }
      final localNow = db.applyUserOffset(DatabaseService.getPlanetaryNow());
      // The timer is a missed-realtime recovery path, not a second full
      // history synchronizer. Inspect the already hydrated snapshot first.
      if (_hasTodayXiaomiSleep(db, localNow)) return;
      final service = CloudSleepSyncService.instance;
      await service.loadStatus();
      if (!_started || db.currentProfileId != owner) return;
      if (!service.state.value.configured || !service.state.value.enabled) return;
      if (_hasTodayXiaomiSleep(db, localNow)) return;
      // loadStatus already triggers a refresh for a new server sync timestamp.
      // Keep a bounded fallback for missed events without polling the full
      // record history every 30 seconds; ordinary reads honor the DB throttle.
      final now = DateTime.now();
      final last = _lastMissingSleepPull;
      if (last != null && now.difference(last) < _missingSleepPullInterval) return;
      _lastMissingSleepPull = now;
      await db.getRecords();
    } catch (error) {
      if (kDebugMode) debugPrint('Sleep catch-up failed: $error');
    } finally {
      _catchUpRunning = false;
    }
  }

  Future<void> _syncDeviceSleep() async {
    final service = HealthSleepSyncService.instance;
    await service.start();
    final current = service.state.value;
    if (!current.enabled || !service.isSupported) return;
    await service.sync();
  }

  bool _hasTodayXiaomiSleep(
    DatabaseService db,
    DateTime localNow,
  ) {
    final rows = db.contextAwarenessCachedRecords();
    for (final row in rows) {
      final source = (row['sleep_source'] ?? row['external_source'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (source != 'xiaomi') continue;
      final rawEnd = row['end_time']?.toString().trim() ?? '';
      final end = DateTime.tryParse(rawEnd);
      if (end == null) continue;
      final localEnd = db.applyUserOffset(end.toUtc());
      if (localEnd.year == localNow.year &&
          localEnd.month == localNow.month &&
          localEnd.day == localNow.day) {
        return true;
      }
    }
    return false;
  }

  Future<void> _syncCloudSleepNow() async {
    final service = CloudSleepSyncService.instance;
    await service.loadStatus();
    final current = service.state.value;
    if (!current.configured || !current.enabled) return;
    await service.syncNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started || state != AppLifecycleState.resumed) return;
    unawaited(reconcile());
  }
}
