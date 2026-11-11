import 'package:flutter/material.dart';

/// Lighter horizontal day pager: ~25% viewport drag commits next/prev day;
/// medium fling uses standard velocity rules. Ignores micro-movements below
/// [dragStartDistanceMotionThreshold].
class LightDateSwipePhysics extends PageScrollPhysics {
  const LightDateSwipePhysics({
    super.parent,
    this.pageAcceptThreshold = 0.22,
    this.motionThreshold = 12.0,
    this.gestureOriginPage,
  });

  /// Fraction of viewport (0–0.5) away from the nearest page center required
  /// to commit to the adjacent page when velocity is near zero.
  final double pageAcceptThreshold;

  final double motionThreshold;

  /// Page at pointer-down, held until ballistic settling finishes. Without
  /// this anchor a fractional position like 0.7 used to snap BACK to 0
  /// because the old algorithm rounded to 1 and then subtracted 1.
  /// With no active drag use native nearest-page semantics.
  final int? Function()? gestureOriginPage;

  @override
  double get dragStartDistanceMotionThreshold => motionThreshold;

  @override
  LightDateSwipePhysics applyTo(ScrollPhysics? ancestor) {
    return LightDateSwipePhysics(
      parent: buildParent(ancestor),
      pageAcceptThreshold: pageAcceptThreshold,
      motionThreshold: motionThreshold,
      gestureOriginPage: gestureOriginPage,
    );
  }

  @override
  double get minFlingVelocity => 80.0;

  @override
  double getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final viewport = position.viewportDimension;
    if (viewport <= 0) return position.pixels;
    final page = position.pixels / viewport;
    final double targetPage;
    if (velocity < -tolerance.velocity) {
      targetPage = page.floorToDouble();
    } else if (velocity > tolerance.velocity) {
      targetPage = page.ceilToDouble();
    } else {
      final origin = gestureOriginPage?.call();
      if (origin == null || (page - origin).abs() < pageAcceptThreshold) {
        targetPage = origin?.toDouble() ?? page.roundToDouble();
      } else {
        // One monotonic step from the gesture's actual origin. Never choose
        // a target backwards after crossing 50% of a forward drag.
        targetPage = (origin + (page > origin ? 1 : -1)).toDouble();
      }
    }
    return (targetPage * viewport).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ).toDouble();
  }
}

/// Planning: feather-light day pager (~20% drag, lower fling threshold).
class FeatherDateSwipePhysics extends LightDateSwipePhysics {
  const FeatherDateSwipePhysics({
    ScrollPhysics? parent,
    super.gestureOriginPage,
  }) : super(
        parent: parent ?? const BouncingScrollPhysics(),
        pageAcceptThreshold: 0.20,
        motionThreshold: 8.0,
      );

  @override
  double get minFlingVelocity => 35.0;

  @override
  FeatherDateSwipePhysics applyTo(ScrollPhysics? ancestor) {
    return FeatherDateSwipePhysics(
      parent: buildParent(ancestor),
      gestureOriginPage: gestureOriginPage,
    );
  }
}
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
