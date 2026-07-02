import 'package:flutter/foundation.dart';

/// Desktop/web pointer drag starts after this movement (px).
const double kPlanTimeDragThresholdDesktopPx = 8;

/// Touch long-press drag starts after this movement (px).
const double kPlanTimeDragThresholdTouchPx = 12;

double planTimeViewDragMovementThresholdPx() {
  if (kIsWeb) return kPlanTimeDragThresholdDesktopPx;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return kPlanTimeDragThresholdDesktopPx;
    default:
      return kPlanTimeDragThresholdTouchPx;
  }
}

/// TIME_VIEW_TAP_NO_TIME_MUTATION — movement below threshold is a tap, not a drag commit.
bool planTimeViewMovementBelowDragThreshold(double movementPx) =>
    movementPx.abs() < planTimeViewDragMovementThresholdPx();
