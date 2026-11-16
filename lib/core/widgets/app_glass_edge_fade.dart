import 'dart:ui' show ImageFilter;

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
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: start,
          end: end,
          stops: const [0, 0.58, 1],
          colors: const [Colors.white, Colors.white, Colors.transparent],
        ).createShader(bounds),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: start,
                  end: end,
                  stops: const [0, 0.46, 1],
                  colors: [
                    surfaceColor.withValues(alpha: 0.96),
                    surfaceColor.withValues(alpha: 0.78),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
