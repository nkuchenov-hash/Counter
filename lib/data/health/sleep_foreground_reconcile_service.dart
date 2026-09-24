import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
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
      await _syncDeviceSleep();

      final db = DatabaseService.instance;
      if (!db.isInitialized || (db.currentProfileId?.isNotEmpty != true)) {
        return;
      }

      // Always begin with authoritative PocketBase state. The server may have
      // already imported sleep while this client was open and a realtime event
      // may have been missed.
      await db.getRecords(forceNetwork: true);

      final localNow = db.applyUserOffset(DatabaseService.getPlanetaryNow());
      if (!await _hasTodayXiaomiSleep(db, localNow)) {
        // Opening or resuming LIFE OS must not wait for the next server cron.
        // If today's Xiaomi sleep is still absent, request one immediate server
        // sync, then re-read authoritative records.
        await _syncCloudSleepNow();
        await db.getRecords(forceNetwork: true);
      }
    } finally {
      _reconcileRunning = false;
    }
  }

  Future<void> _catchUpFromPocketBase() async {
    if (_catchUpRunning) return;
    _catchUpRunning = true;
    try {
      final db = DatabaseService.instance;
      if (!db.isInitialized || (db.currentProfileId?.isNotEmpty != true)) return;
      final localNow = db.applyUserOffset(DatabaseService.getPlanetaryNow());
      if (await _hasTodayXiaomiSleep(db, localNow)) return;
      await db.getRecords(forceNetwork: true);
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

  Future<bool> _hasTodayXiaomiSleep(
    DatabaseService db,
    DateTime localNow,
  ) async {
    final rows = await db.getRecords();
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
