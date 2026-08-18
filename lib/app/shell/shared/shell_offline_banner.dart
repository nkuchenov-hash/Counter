import 'dart:async';

import 'package:counter/app/shell/shared/profile_hydration_status_bar.dart';
import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/features/timeline/unfilled_time_gap_banner.dart';
import 'package:flutter/material.dart';

/// Top-of-shell status strip: profile hydration and missing time only.
class ShellTopStatusBars extends StatefulWidget {
  const ShellTopStatusBars({super.key, required this.routeTab});

  final String routeTab;

  @override
  State<ShellTopStatusBars> createState() => _ShellTopStatusBarsState();
}

class _ShellTopStatusBarsState extends State<ShellTopStatusBars>
    with WidgetsBindingObserver {
  bool _sleepReconcileRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reconcileSleep());
    unawaited(UnfilledTimeGapService.instance.start());
  }

  Future<void> _startHealthSleepSync() async {
    final service = HealthSleepSyncService.instance;
    await service.start();
    final current = service.state.value;
    if (!current.enabled || !service.isSupported) return;

    // Foreground is the strongest wake-up signal available to the app. Always
    // re-read device sleep immediately instead of trusting a recent background
    // timestamp that may have been recorded just before the user woke up.
    await service.sync(force: true);
  }

  Future<void> _startCloudSleepSync() async {
    final service = CloudSleepSyncService.instance;
    await service.loadStatus();
    final current = service.state.value;
    if (!current.configured || !current.enabled) return;

    // Same behavior on web and native clients: opening/resuming LIFE OS asks
    // the server to reconcile Google Fit immediately, then refreshes records.
    await service.syncNow();
  }

  Future<void> _reconcileSleep() async {
    if (_sleepReconcileRunning) return;
    _sleepReconcileRunning = true;
    try {
      // Avoid racing two ingestion adapters against the same new night.
      // Device health writes first; cloud sync then reconciles into the same
      // canonical PocketBase record. On web the device step is a no-op.
      await _startHealthSleepSync();
      await _startCloudSleepSync();
    } finally {
      _sleepReconcileRunning = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileSleep());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileHydrationStatusBar(),
        UnfilledTimeGapBanner(),
      ],
    );
  }
}
