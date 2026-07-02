import 'dart:math' as math;

import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';

/// Visual density bands from CardPlan reference screenshots (Time View).
enum PlanTimeCardVisualDensity {
  verySmall,
  small,
  moreCompact,
  compact,
  medium,
}

/// Maps final rendered block height to CardPlan visual density.
PlanTimeCardVisualDensity planTimeCardVisualDensityForRenderedHeight(
  double renderedHeightPx,
) {
  final h = math.max(renderedHeightPx, kPlanTimeCardMinHeightPx);
  if (h <= 38) return PlanTimeCardVisualDensity.verySmall;
  if (h <= 54) return PlanTimeCardVisualDensity.small;
  if (h <= 77) return PlanTimeCardVisualDensity.moreCompact;
  if (h <= 94) return PlanTimeCardVisualDensity.compact;
  return PlanTimeCardVisualDensity.medium;
}

PlanTimeTaskCardDensity planTimeCardTaskDensityForVisual(
  PlanTimeCardVisualDensity visual,
) {
  switch (visual) {
    case PlanTimeCardVisualDensity.verySmall:
      return PlanTimeTaskCardDensity.compact;
    case PlanTimeCardVisualDensity.small:
      return PlanTimeTaskCardDensity.micro;
    case PlanTimeCardVisualDensity.moreCompact:
    case PlanTimeCardVisualDensity.compact:
      return PlanTimeTaskCardDensity.compact;
    case PlanTimeCardVisualDensity.medium:
      return PlanTimeTaskCardDensity.medium;
  }
}

bool planTimeCardShowProgressForVisual(PlanTimeCardVisualDensity density) {
  return density == PlanTimeCardVisualDensity.compact ||
      density == PlanTimeCardVisualDensity.medium;
}

bool planTimeCardShowFooterBreadcrumbForVisual(
  PlanTimeCardVisualDensity density,
) {
  return density == PlanTimeCardVisualDensity.compact ||
      density == PlanTimeCardVisualDensity.medium;
}

bool planTimeCardUseTimelineFillHeightForVisual(
  PlanTimeCardVisualDensity density,
) {
  return density != PlanTimeCardVisualDensity.small;
}
