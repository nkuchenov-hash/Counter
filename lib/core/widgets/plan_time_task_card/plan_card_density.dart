import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/data/models.dart';

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

PlanTimeTaskCardDensity planTimeCardDensityForBlock(
  double heightPx,
  int durationMin,
) {
  return planTimeCardTaskDensityForVisual(
    planTimeCardVisualDensityForRenderedHeight(heightPx),
  );
}

String planCardWallTimeLabel(PlanningTask task) {
  final start = task.startTime;
  if (start == null) return '';
  final startLabel =
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final end = task.endDateTime;
  if (end != null) {
    return '$startLabel ? ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }
  return startLabel;
}

/// List/calendar rows always use medium so footer (breadcrumb + planned time) is consistent.
PlanTimeTaskCardDensity planTimeCardDensityForList({
  required PlanningTask task,
  int? planEstimatedSeconds,
  int planTrackedSeconds = 0,
}) {
  return PlanTimeTaskCardDensity.medium;
}

/// Minimum visible height for list/calendar surfaces (never collapse to 0).
double planTimeCardListMinHeight(PlanTimeTaskCardDensity density) =>
    switch (density) {
      PlanTimeTaskCardDensity.micro => PlanCardGeom.refHeightMicro,
      PlanTimeTaskCardDensity.compact => PlanCardGeom.refHeightSmall,
      PlanTimeTaskCardDensity.medium => PlanCardGeom.refHeightMedium,
      PlanTimeTaskCardDensity.large => PlanCardGeom.refHeightLarge,
    };

/// Intrinsic CardPlan height ? single source for list minHeight and Time mode blocks.
double planTimeCardMeasureHeight({
  required bool hasTags,
  required bool hasTrackedProgress,
  PlanTimeTaskCardDensity density = PlanTimeTaskCardDensity.medium,
  int titleLines = 1,
}) {
  if (density == PlanTimeTaskCardDensity.micro ||
      density == PlanTimeTaskCardDensity.compact) {
    return planTimeCardListMinHeight(density);
  }
  const spacing = PlanCardVerticalSpacing.shared;
  final titleBlock =
      spacing.titleTopInset +
      PlanCardGeom.titleRowHeight * (titleLines > 1 ? titleLines / 1.0 : 1.0);
  final tagsBlock = spacing.tagsSlotHeight(hasTags: hasTags);
  final progressBlock = spacing.progressSlotHeight(
    hasTrackedProgress: hasTrackedProgress,
  );
  final footerBlock = spacing.footerBlockGap + PlanCardGeom.footerTextHeight;
  final contentColumn =
      titleBlock +
      tagsBlock +
      PlanCardGeom.tagsToProgressGap +
      progressBlock +
      footerBlock;
  final contentWithPad = spacing.padTop + contentColumn + spacing.padBottom;
  const railInner =
      PlanCardGeom.controlSize +
      PlanCardGeom.checkboxPlayGap +
      PlanCardGeom.controlSize;
  final railWithPad = spacing.padTop + railInner + spacing.padBottom;
  return math.max(contentWithPad, railWithPad);
}

/// Time mode [Positioned] height: preferred visual height + border allowance.
double planTimeCardTimelineAllocatedHeight({
  required bool hasTags,
  required bool hasTrackedProgress,
}) {
  return planTimeCardMeasureHeight(
        hasTags: hasTags,
        hasTrackedProgress: hasTrackedProgress,
      ) +
      PlanCardGeom.timelineBlockAllowancePx;
}

/// Left inset for timeline drag/tap body zone ? excludes checkbox + play rail.
double planCardBodyGestureLeftInsetPx(
  PlanTimeTaskCardDensity density, {
  bool timeline = false,
}) => switch (density) {
  PlanTimeTaskCardDensity.micro => PlanCardGeom.contentXSmall,
  PlanTimeTaskCardDensity.compact =>
    timeline ? PlanCardGeom.contentXSmall : PlanCardGeom.contentXSmall,
  PlanTimeTaskCardDensity.medium || PlanTimeTaskCardDensity.large =>
    PlanCardGeom.padLeft +
        PlanCardGeom.railWidth +
        PlanCardGeom.railToContentGap,
};

/// Right inset for timeline drag/tap body zone ? excludes menu button column.
double planCardBodyGestureRightInsetPx({bool hasMenu = true}) =>
    hasMenu ? PlanCardGeom.menuSize + PlanCardGeom.padRight : 0;
