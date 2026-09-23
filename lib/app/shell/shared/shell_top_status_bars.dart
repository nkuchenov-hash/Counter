import 'package:counter/features/profile/profile_hydration_status_bar.dart';
import 'package:flutter/material.dart';

/// Presentation-only top-of-shell status strip.
///
/// Unfilled-time prompts must never occupy this area; the desktop prompt lives
/// in the left navigation rail instead.
class ShellTopStatusBars extends StatelessWidget {
  const ShellTopStatusBars({super.key});

  @override
  Widget build(BuildContext context) {
    // Background synchronization is intentionally silent. Never reserve shell
    // layout space for sync progress/status UI.
    return const ProfileHydrationStatusBar();
  }
}
