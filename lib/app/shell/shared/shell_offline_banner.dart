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
  static const Duration _foregroundSleepSyncInterval = Duration(minutes: 10);

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

    final lastSync = current.lastSyncUtc;
    final needsForegroundCatchUp =
        lastSync == null ||
        DateTime.now().toUtc().difference(lastSync) >=
            _foregroundSleepSyncInterval;
    if (needsForegroundCatchUp) {
      await service.sync();
    }
  }

  Future<void> _startCloudSleepSync() async {
    final service = CloudSleepSyncService.instance;
    await service.loadStatus();
    final current = service.state.value;
    if (!current.configured || !current.enabled) return;

    final lastSync = current.lastSyncUtc;
    final needsForegroundCatchUp =
        lastSync == null ||
        DateTime.now().toUtc().difference(lastSync) >=
            _foregroundSleepSyncInterval;
    if (needsForegroundCatchUp) {
      await service.syncNow();
    }
  }

  Future<void> _reconcileSleep() async {
    await Future.wait<void>([
      _startHealthSleepSync(),
      _startCloudSleepSync(),
    ]);
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
