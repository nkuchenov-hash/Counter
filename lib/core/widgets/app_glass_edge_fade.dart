import 'dart:ui' show ImageFilter;

import 'package:counter/core/app_colors.dart';
import 'package:flutter/material.dart';

/// Canonical frosted edge for both shell header and bottom navigation.
///
/// This layer is purely visual and MUST NOT own any pointer events. Screen
/// controls are laid out outside its feather region; no second menu is built.
enum AppGlassEdge { top, bottom }

class AppGlassEdgeFade extends StatelessWidget {
  const AppGlassEdgeFade({
    super.key,
    required this.edge,
    required this.surfaceColor,
    this.blurSigma = 14,
  });

  final AppGlassEdge edge;
  final Color surfaceColor;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final start = edge == AppGlassEdge.top
        ? Alignment.topCenter
        : Alignment.bottomCenter;
    final end = edge == AppGlassEdge.top
        ? Alignment.bottomCenter
        : Alignment.topCenter;
    // One symmetric feather for the pinned header and floating dock.
    // The opaque edge protects labels, while the long easing prevents
    // a hard horizon in either light or dark themes.
    const fadeStops = [0.0, 0.35, 0.62, 0.82, 1.0];
    final tint = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: start,
          end: end,
          stops: fadeStops,
          colors: [
            surfaceColor.withValues(alpha: 0.94),
            surfaceColor.withValues(alpha: 0.90),
            surfaceColor.withValues(alpha: 0.74),
            surfaceColor.withValues(alpha: 0.30),
            AppNeutralTones.transparent,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: start,
          end: end,
          stops: fadeStops,
          colors: [
            AppNeutralTones.white,
            AppNeutralTones.white,
            AppNeutralTones.white.withValues(alpha: 0.90),
            AppNeutralTones.white.withValues(alpha: 0.43),
            AppNeutralTones.transparent,
          ],
        ).createShader(bounds),
        child: ClipRect(
          child: blurSigma <= 0
              ? tint
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: tint,
                ),
        ),
      ),
    );
  }
}


/// Canonical floating navigation material: real backdrop blur strictly
/// clipped to the rounded capsule, with no full-width colored backplate.
/// Its ancestor Scaffold uses extendBody to paint scroll content below it.
class AppFrostedNavigationPanel extends StatelessWidget {
  const AppFrostedNavigationPanel({
    super.key,
    required this.surfaceColor,
    required this.child,
  });

  final Color surfaceColor;
  final Widget child;
  static const double cornerRadius = 30;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(cornerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Minimal neutral tint *inside* the dock, never behind it.
            color: surfaceColor.withValues(alpha: dark ? 0.14 : 0.12),
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: dark ? 0.13 : 0.09),
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
