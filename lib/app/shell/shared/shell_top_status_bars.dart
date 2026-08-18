import 'package:counter/features/profile/profile_hydration_status_bar.dart';
import 'package:counter/features/timeline/unfilled_time_gap_banner.dart';
import 'package:flutter/material.dart';

/// Presentation-only top-of-shell status strip.
class ShellTopStatusBars extends StatelessWidget {
  const ShellTopStatusBars({super.key});

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
