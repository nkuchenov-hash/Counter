import 'dart:async';

import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:flutter/widgets.dart';

/// App-lifecycle coordinator for sleep ingestion.
/// UI widgets must not own Health Connect / cloud reconciliation.
class SleepForegroundReconcileService with WidgetsBindingObserver {
  SleepForegroundReconcileService._();

  static final SleepForegroundReconcileService instance =
      SleepForegroundReconcileService._();

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
    await service.sync(force: true);
  }

  Future<void> _syncCloudSleep() async {
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
