import 'dart:ui' show ImageFilter;

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:flutter/material.dart';

/// Motion and frosted edge treatment scoped only to phone settings.
/// Avoids altering global scroll physics, other workspaces, or persisted data.
class MobileSettingsMotion extends StatelessWidget {
  const MobileSettingsMotion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (shellUsesSideNavigation(MediaQuery.sizeOf(context).width)) {
      return child;
    }
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ScrollConfiguration(
      behavior: reducedMotion
          ? ScrollConfiguration.of(context)
          : const _MobileSettingsBounceBehavior(),
      child: Stack(
        children: [
          child,
          for (final top in [true, false])
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: 0,
              right: 0,
              height: top ? 12 : 20,
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                    child: ColoredBox(
                      color: (theme.brightness == Brightness.dark
                              ? AppColors.darkAppBackground
                              : AppColors.appBackground)
                          .withValues(alpha: 0.28),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileSettingsBounceBehavior extends MaterialScrollBehavior {
  const _MobileSettingsBounceBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
