import 'package:flutter/material.dart';

/// Keeps radial / semi-circle card action menus inside the visible viewport.
abstract final class RadialMenuViewport {
  static const double kSafeMargin = 8;

  /// Top-left for the menu canvas, shifting the hub when [anchorCenter] is near
  /// an edge so satellites + labels stay on screen.
  static Offset clampCanvasTopLeft({
    required BuildContext context,
    required Offset anchorCenter,
    required double canvasSize,
    required double orbitRadius,
    required double satelliteDiameter,
    double labelMaxWidth = 96,
    double labelBelowSatellite = 28,
  }) {
    final media = MediaQuery.of(context);
    final padding = media.viewPadding;
    final size = media.size;

    final satelliteRadius = satelliteDiameter / 2;
    final maxExtentX = orbitRadius + satelliteRadius + labelMaxWidth / 2;
    final maxExtentY = orbitRadius + satelliteRadius + labelBelowSatellite;

    final minHubX = padding.left + kSafeMargin + maxExtentX;
    final maxHubX = size.width - padding.right - kSafeMargin - maxExtentX;
    final minHubY = padding.top + kSafeMargin + maxExtentY;
    final maxHubY = size.height - padding.bottom - kSafeMargin - maxExtentY;

    final hubX = maxHubX >= minHubX
        ? anchorCenter.dx.clamp(minHubX, maxHubX)
        : size.width / 2;
    final hubY = maxHubY >= minHubY
        ? anchorCenter.dy.clamp(minHubY, maxHubY)
        : anchorCenter.dy;

    return Offset(hubX - canvasSize / 2, hubY - canvasSize / 2);
  }
}
