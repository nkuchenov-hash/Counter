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

  /// A frosted dock needs a faint tonal difference from the page canvas.
  /// Both LIFE OS themes intentionally assign the SAME color to
  /// surface and surfaceContainerLowest. Reusing either as the fade tint
  /// made the footer look like a solid, un-faded block over flat pages.
  ///
  /// This color depends on theme ONLY, never the active destination.
  /// The existing ten-stop alpha/blur ramp remains the only fade geometry.
  static Color bottomNavigationFadeColor(ColorScheme scheme) {
    final contrast = scheme.brightness == Brightness.dark ? 0.075 : 0.035;
    return Color.lerp(scheme.surface, scheme.onSurface, contrast)!;
  }

  @override
  Widget build(BuildContext context) {
    final start = edge == AppGlassEdge.top
        ? Alignment.topCenter
        : Alignment.bottomCenter;
    final end = edge == AppGlassEdge.top
        ? Alignment.bottomCenter
        : Alignment.topCenter;
    // Feather the header and dock past the visually recognizable edge.
    // Sparse, piecewise-linear alpha ramps create a faint horizontal horizon
    // when blurred scroll content moves beneath them. The denser eased tail
    // approaches zero well BEFORE the clip boundary and has no visible seam.
    final topHeader = edge == AppGlassEdge.top;
    const fadeStops = <double>[
      0.0, 0.12, 0.32, 0.48, 0.62, 0.74, 0.83, 0.90, 0.95, 1.0,
    ];
    final tint = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: start,
          end: end,
          stops: fadeStops,
          colors: topHeader
              ? [
                  surfaceColor.withValues(alpha: 0.98),
                  surfaceColor.withValues(alpha: 0.97),
                  surfaceColor.withValues(alpha: 0.92),
                  surfaceColor.withValues(alpha: 0.83),
                  surfaceColor.withValues(alpha: 0.67),
                  surfaceColor.withValues(alpha: 0.42),
                  surfaceColor.withValues(alpha: 0.20),
                  surfaceColor.withValues(alpha: 0.07),
                  surfaceColor.withValues(alpha: 0.015),
                  AppNeutralTones.transparent,
                ]
              : [
                  surfaceColor.withValues(alpha: 0.90),
                  surfaceColor.withValues(alpha: 0.85),
                  surfaceColor.withValues(alpha: 0.76),
                  surfaceColor.withValues(alpha: 0.61),
                  surfaceColor.withValues(alpha: 0.43),
                  surfaceColor.withValues(alpha: 0.25),
                  surfaceColor.withValues(alpha: 0.12),
                  surfaceColor.withValues(alpha: 0.04),
                  surfaceColor.withValues(alpha: 0.008),
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
          colors: topHeader
              ? [
                  AppNeutralTones.white,
                  AppNeutralTones.white,
                  AppNeutralTones.white,
                  AppNeutralTones.white.withValues(alpha: 0.98),
                  AppNeutralTones.white.withValues(alpha: 0.90),
                  AppNeutralTones.white.withValues(alpha: 0.73),
                  AppNeutralTones.white.withValues(alpha: 0.48),
                  AppNeutralTones.white.withValues(alpha: 0.25),
                  AppNeutralTones.white.withValues(alpha: 0.10),
                  AppNeutralTones.transparent,
                ]
              : [
                  AppNeutralTones.white,
                  AppNeutralTones.white,
                  AppNeutralTones.white.withValues(alpha: 0.97),
                  AppNeutralTones.white.withValues(alpha: 0.90),
                  AppNeutralTones.white.withValues(alpha: 0.75),
                  AppNeutralTones.white.withValues(alpha: 0.55),
                  AppNeutralTones.white.withValues(alpha: 0.33),
                  AppNeutralTones.white.withValues(alpha: 0.16),
                  AppNeutralTones.white.withValues(alpha: 0.06),
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
            color: surfaceColor.withValues(alpha: dark ? 0.10 : 0.08),
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: dark ? 0.10 : 0.07),
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
