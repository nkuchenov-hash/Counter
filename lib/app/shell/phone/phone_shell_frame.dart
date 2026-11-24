import 'package:counter/app/shell/phone/shell_bottom_navigation.dart';
import 'package:counter/core/widgets/app_glass_edge_fade.dart';
import 'package:flutter/material.dart';

/// Phone (and current tablet) content frame: main column without side nav.
class PhoneShellFrame extends StatelessWidget {
  const PhoneShellFrame({super.key, required this.child});

  final Widget child;

  /// The full-height shell body owns the footer feather. A feather placed
  /// inside bottomNavigationBar cannot reliably paint above that bar's render
  /// bounds, which produced a solid dark rectangle behind the dock.
  ///
  /// The fade is painted inside the extended Scaffold body and remains
  /// identical for Timeline, Planning, Calendar, Lists and Settings.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: kPhoneShellDockFadeHeight,
          // Scaffold consumes the bottom view inset when resizing its body.
          // Observe the actual Flutter view only for this decorative layer,
          // without reintroducing the keyboard inset into page content.
          child: MediaQuery.fromView(
            view: View.of(context),
            child: Builder(
              builder: (context) {
                if (MediaQuery.viewInsetsOf(context).bottom > 0) {
                  return const SizedBox.shrink();
                }
                return RepaintBoundary(
                  child: AppGlassEdgeFade(
                    key: const ValueKey('life-os-canonical-bottom-fade'),
                    edge: AppGlassEdge.bottom,
                    surfaceColor: AppGlassEdgeFade.bottomNavigationFadeColor(scheme),
                    blurSigma: 14,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Independent of tab selection and page content. The gradient spans the
/// navigation capsule and fades naturally into the scroll viewport above.
const double kPhoneShellDockFadeHeight = 176;


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
    return ShellCompactBottomNav(
      viewportWidth: viewportWidth,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
    );
  }
}
