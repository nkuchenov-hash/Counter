import 'package:counter/core/shell_adaptive.dart';
import 'package:flutter/foundation.dart';

/// Desktop / side-nav pointer drag starts after this movement (px).
const double kPlanTimeDragThresholdDesktopPx = 8;

/// Touch long-press drag starts after this movement (px).
const double kPlanTimeDragThresholdTouchPx = 12;

/// Drag threshold for Time View move/resize at [viewportWidth].
/// Phone-width shell (< [kShellDesktopNavBreakpoint]) matches APK touch thresholds.
double planTimeViewDragMovementThresholdForViewport(double viewportWidth) {
  if (shellUsesCompactPhoneLayout(viewportWidth)) {
    return kPlanTimeDragThresholdTouchPx;
  }
  return kPlanTimeDragThresholdDesktopPx;
}

/// Fallback when viewport width is unavailable (unit tests, legacy callers).
double planTimeViewDragMovementThresholdPx() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return kPlanTimeDragThresholdDesktopPx;
    default:
      return kPlanTimeDragThresholdTouchPx;
  }
}

/// Immediate pointer drag (no long-press) on wide / side-nav layouts only.
bool planTimeViewUsesImmediatePointerDrag(double viewportWidth) =>
    !shellUsesCompactPhoneLayout(viewportWidth);

/// TIME_VIEW_TAP_NO_TIME_MUTATION — movement below threshold is a tap, not a drag commit.
bool planTimeViewMovementBelowDragThreshold(
  double movementPx, {
  double? viewportWidth,
}) {
  final threshold = viewportWidth != null
      ? planTimeViewDragMovementThresholdForViewport(viewportWidth)
      : planTimeViewDragMovementThresholdPx();
  return movementPx.abs() < threshold;
}
