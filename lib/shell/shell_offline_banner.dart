import 'package:counter/features/shared/offline_sync_status_bar.dart';
import 'package:counter/shell/profile_hydration_status_bar.dart';
import 'package:flutter/material.dart';

/// Top-of-shell status strip: profile hydration + offline sync banner.
class ShellTopStatusBars extends StatelessWidget {
  const ShellTopStatusBars({super.key, required this.routeTab});

  final String routeTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileHydrationStatusBar(),
        OfflineSyncStatusBar(routeTab: routeTab),
      ],
    );
  }
}
