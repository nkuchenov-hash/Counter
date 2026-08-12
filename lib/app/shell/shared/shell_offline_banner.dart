import 'dart:async';

import 'package:counter/app/shell/shared/profile_hydration_status_bar.dart';
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

class _ShellTopStatusBarsState extends State<ShellTopStatusBars> {
  @override
  void initState() {
    super.initState();
    unawaited(HealthSleepSyncService.instance.start());
    unawaited(UnfilledTimeGapService.instance.start());
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
