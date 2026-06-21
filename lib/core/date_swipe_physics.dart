import 'package:flutter/material.dart';

/// Lighter horizontal day pager: ~25% viewport drag commits next/prev day;
/// medium fling uses standard velocity rules. Ignores micro-movements below
/// [dragStartDistanceMotionThreshold].
class LightDateSwipePhysics extends PageScrollPhysics {
  const LightDateSwipePhysics({
    super.parent,
    this.pageAcceptThreshold = 0.25,
    this.motionThreshold = 12.0,
  });

  /// Fraction of viewport (0–0.5) away from the nearest page center required
  /// to commit to the adjacent page when velocity is near zero.
  final double pageAcceptThreshold;

  final double motionThreshold;

  @override
  double get dragStartDistanceMotionThreshold => motionThreshold;

  @override
  LightDateSwipePhysics applyTo(ScrollPhysics? ancestor) {
    return LightDateSwipePhysics(
      parent: buildParent(ancestor),
      pageAcceptThreshold: pageAcceptThreshold,
      motionThreshold: motionThreshold,
    );
  }

  @override
  double get minFlingVelocity => 80.0;

  double getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final page = position.pixels / position.viewportDimension;
    if (velocity < -tolerance.velocity) {
      return page.floorToDouble() * position.viewportDimension;
    }
    if (velocity > tolerance.velocity) {
      return page.ceilToDouble() * position.viewportDimension;
    }
    final nearest = page.round();
    final distToNearest = (page - nearest).abs();
    final double targetPage;
    if (distToNearest < pageAcceptThreshold) {
      targetPage = nearest.toDouble();
    } else if (page > nearest) {
      targetPage = nearest + 1.0;
    } else {
      targetPage = nearest - 1.0;
    }
    return targetPage * position.viewportDimension;
  }
}

/// Logs swipe threshold diagnostics when a horizontal drag ends.
void logDateSwipeThresholdOnScrollEnd({
  required String section,
  required PageController controller,
  required ScrollEndNotification notification,
  required void Function({
    required String section,
    required double dragFraction,
    required double velocity,
    required bool accepted,
    required int fromPage,
    required int toPage,
  }) log,
}) {
  if (!controller.hasClients) return;
  final page = controller.page;
  if (page == null) return;
  final viewport = controller.position.viewportDimension;
  if (viewport <= 0) return;
  final nearest = page.round();
  final dragFraction = (page - nearest).abs();
  final velocity = notification.dragDetails?.velocity.pixelsPerSecond.dx ?? 0.0;
  final settledPage = controller.page?.round() ?? nearest;
  log(
    section: section,
    dragFraction: dragFraction,
    velocity: velocity,
    accepted: settledPage != nearest,
    fromPage: nearest,
    toPage: settledPage,
  );
}
