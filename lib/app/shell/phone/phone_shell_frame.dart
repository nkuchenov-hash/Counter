import 'package:counter/app/shell/phone/shell_bottom_navigation.dart';
import 'package:flutter/material.dart';

/// Phone (and current tablet) content frame: main column without side nav.
class PhoneShellFrame extends StatelessWidget {
  const PhoneShellFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Phone bottom navigation bar for compact shell widths.
class PhoneShellBottomNavigation extends StatelessWidget {
  const PhoneShellBottomNavigation({
    super.key,
    required this.viewportWidth,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final double viewportWidth;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ShellCompactBottomNav(
        viewportWidth: viewportWidth,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}
