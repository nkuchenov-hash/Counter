import 'dart:math' as math;

enum PlanTimeTaskCardDensity { micro, compact, medium, large }

/// Minimum rendered CardPlan height in Time View.
/// 32px control + 12px inset on both edges = 56px.
const double kPlanTimeCardMinHeightPx = 56.0;
const double kPlanTimeMinCardHeightPx = kPlanTimeCardMinHeightPx;

/// Minimum scheduled duration in Time View (minutes).
const int kPlanTimeMinDurationMinutes = 10;

/// Minimum vertical gap between adjacent Time View cards.
const double kPlanTimeCardGapPx = 4.0;
const double kPlanTimeDenseGapPx = kPlanTimeCardGapPx;

/// Padding below the last card when computing stretched hour height.
const double kPlanTimeHourVerticalPaddingPx = 4.0;

/// Visual height of a full 60-minute card (Medium anchor).
const double kPlanTimeOneHourCardHeightPx = 120.0;

/// Dense hour: at most six 10-minute cards with stable 56px card geometry.
const int kPlanTimeMaxCardsPerHour = 6;
const double kPlanTimeMaxHourHeightPx =
    kPlanTimeMaxCardsPerHour * kPlanTimeMinCardHeightPx +
    (kPlanTimeMaxCardsPerHour - 1) * kPlanTimeCardGapPx;

/// Hard cap for a single hour band (prevents infinite day growth).
const double kPlanTimeMaxReasonableHourHeightPx = kPlanTimeMaxHourHeightPx;

/// Piecewise card height from scheduled duration (independent of hour stretch).
double planTimeCardRenderedHeightPxForDuration(int durationMinutes) {
  final dur = math.max(kPlanTimeMinDurationMinutes, durationMinutes);
  if (dur <= 10) return kPlanTimeMinCardHeightPx;
  if (dur <= 30) {
    return kPlanTimeMinCardHeightPx +
        (dur - 10) * (75 - kPlanTimeMinCardHeightPx) / 20;
  }
  if (dur <= 60) {
    return 75 + (dur - 30) * (kPlanTimeOneHourCardHeightPx - 75) / 30;
  }
  return kPlanTimeOneHourCardHeightPx +
      math.sqrt((dur - 60).toDouble()) * 8;
}

/// Default hour band height before stretch.
const double kPlanTimeViewBaseHourHeightMinPx = 120.0;
const double kPlanTimeViewBaseHourHeightMaxPx = 160.0;

/// Where the card is rendered — drives height/interaction assumptions.
enum PlanCardSurface { list, timeline, calendar }
