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

  static const Duration _cloudForegroundThrottle = Duration(minutes: 15);
  static const int _morningStartMinutes = 4 * 60;
  static const int _morningEndMinutes = 12 * 60;

  bool _started = false;
  bool _reconcileRunning = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(reconcile());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> reconcile() async {
    if (_reconcileRunning) return;
    _reconcileRunning = true;
    try {
      await _syncDeviceSleep();
      await _syncCloudSleep();
    } finally {
      _reconcileRunning = false;
    }
  }

  Future<void> _syncDeviceSleep() async {
    final service = HealthSleepSyncService.instance;
    await service.start();
    final current = service.state.value;
    if (!current.enabled || !service.isSupported) return;
    // Device sleep already has its own ten-minute automatic throttle.
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

  Future<void> _syncCloudSleep() async {
    final db = DatabaseService.instance;
    if (!db.isInitialized || (db.currentProfileId?.isNotEmpty != true)) return;

    final service = CloudSleepSyncService.instance;
    await service.loadStatus();
    final current = service.state.value;
    if (!current.configured || !current.enabled) return;

    // A foreground cloud pull is primarily a wake-up accelerator. Outside the
    // morning window the server-side scheduler owns reconciliation.
    final localNow = db.applyUserOffset(DatabaseService.getPlanetaryNow());
    final localMinutes = localNow.hour * 60 + localNow.minute;
    if (localMinutes < _morningStartMinutes ||
        localMinutes >= _morningEndMinutes) {
      return;
    }

    // Once today's completed Xiaomi sleep is present, foreground resumes stop
    // hitting Xiaomi for the rest of the morning.
    if (await _hasTodayXiaomiSleep(db, localNow)) return;

    // Opening/resuming LIFE OS several times must not repeatedly hit Xiaomi.
    // The server timestamp is shared by all clients, so this also suppresses
    // duplicate phone/web/desktop foreground pulls.
    final lastSync = current.lastSyncUtc;
    final nowUtc = DateTime.now().toUtc();
    if (lastSync != null) {
      final age = nowUtc.difference(lastSync);
      if (!age.isNegative && age < _cloudForegroundThrottle) return;
    }

    await service.syncNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started || state != AppLifecycleState.resumed) return;
    unawaited(reconcile());
  }
}
