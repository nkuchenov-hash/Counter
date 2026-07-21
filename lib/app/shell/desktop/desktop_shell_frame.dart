import 'package:counter/app/shell/desktop/shell_side_navigation.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:flutter/material.dart';

/// Desktop/web wide shell: side navigation + content column.
class DesktopShellFrame extends StatelessWidget {
  const DesktopShellFrame({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellSideNavigation(
          width: kShellSideNavWidth,
          selectedIndex: selectedIndex,
          onTabSelected: onTabSelected,
        ),
        Expanded(child: child),
      ],
    );
  }
}
