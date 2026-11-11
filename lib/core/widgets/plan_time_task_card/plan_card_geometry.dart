import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/app_colors.dart';
import 'package:counter/core/life_color_compat.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:flutter/material.dart';
// --- Figma geometry (328px reference) ----------------------------------------

abstract final class PlanCardGeom {
  static const double refWidth = 328;
  static const double padLeft = 12;
  static const double padRight = 12;
  static const double padTopMediumLarge = 12;
  static const double padTopSmall = 12;
  static const double controlSize = 32;
  static const double playInlineX = 48;
  static const double contentXSmall = 84;
  static const double contentXMediumLarge = 56;
  static const double railWidth = 32;
  static const double railToContentGap = 12;
  static const double checkboxPlayGap = 8;
  static const double playIconWidth = 24;
  static const double playIconHeight = 26;
  static const double playIconCornerRadius = 8.0;
  static const double recurringIconSize = 15;
  static const double titleToRecurringGap = 5;
  static const double playAfterCheckboxGap = 4;
  static const double menuSize = controlSize;
  static const double timeViewRailToContentGap = 12;
  static const double contentSpanMediumLarge = 260;
  static const double radius = 12;
  static const double refHeightMicro = 56;
  static const double refHeightSmall = 68;
  static const double refHeightMedium = 106;
  static const double refHeightLarge = 147;
  static const double tagRowHeight = 16;
  static const double tagGap = 5;
  static const double titleToTagsGap = 2;
  static const double emptyTagsSlotHeight = 18;
  static const double tagsToProgressGap = 3;
  static const double actualTimeSlotHeight = 12;
  static const double progressAfterActualGap = 3;
  static const double progressBarHeight = 2;
  static const double footerBlockGap = 6;
  static const double footerTimeGap = 6;
  static const double footerTimeRightSafePad = 0;
  static const double footerTextHeight = 14;
  static const double footerBottomPad = 12;
  static const double titleTopInset = 0;
  // Fit the 16px title font without clipping descenders.
  static const double titleLineHeight = 20;
  static const double titleRowHeight = 33;
  static const double timelineBlockAllowancePx = 2;
  static const double watermarkMinCardHeight = 90;
  // Time View CardPlan rhythm approved for duration-based layouts.
  static const double timeViewTitleToTagsGap = 6;
  static const double timeViewTagsToProgressGap = 6;
  static const double timeViewTightTagsToProgressGap = 8;
  static const double timeViewProgressToFooterGap = 5;
  static const double timeViewTightProgressToFooterGap = 4;
  static const double timeViewFooterBottomPad = 10;
  static const double timeViewTightFooterBottomPad = 5;
  static const double timeViewTightContentTop = 5;

  static double refHeight(PlanTimeTaskCardDensity d) => switch (d) {
    PlanTimeTaskCardDensity.micro => refHeightMicro,
    PlanTimeTaskCardDensity.compact => refHeightSmall,
    PlanTimeTaskCardDensity.medium => refHeightMedium,
    PlanTimeTaskCardDensity.large => refHeightLarge,
  };

  static double contentSpanWidth(double cardWidth) =>
      cardWidth - contentXMediumLarge - padRight;
}

/// Single shared vertical rhythm for list, calendar, and Time mode.
final class PlanCardVerticalSpacing {
  const PlanCardVerticalSpacing._({
    required this.padTop,
    required this.padBottom,
    required this.titleTopInset,
    required this.titleToTagsGap,
    required this.emptyTagsSlotHeight,
    required this.actualTimeSlotHeight,
    required this.progressAfterActualGap,
    required this.progressBarHeight,
    required this.footerBlockGap,
  });

  static const shared = PlanCardVerticalSpacing._(
    padTop: PlanCardGeom.padTopMediumLarge,
    padBottom: PlanCardGeom.footerBottomPad,
    titleTopInset: PlanCardGeom.titleTopInset,
    titleToTagsGap: PlanCardGeom.titleToTagsGap,
    emptyTagsSlotHeight: PlanCardGeom.emptyTagsSlotHeight,
    actualTimeSlotHeight: PlanCardGeom.actualTimeSlotHeight,
    progressAfterActualGap: PlanCardGeom.progressAfterActualGap,
    progressBarHeight: PlanCardGeom.progressBarHeight,
    footerBlockGap: PlanCardGeom.footerBlockGap,
  );

  final double padTop;
  final double padBottom;
  final double titleTopInset;
  final double titleToTagsGap;
  final double emptyTagsSlotHeight;
  final double actualTimeSlotHeight;
  final double progressAfterActualGap;
  final double progressBarHeight;
  final double footerBlockGap;

  double progressSlotHeight({required bool hasTrackedProgress}) =>
      actualTimeSlotHeight + progressAfterActualGap + progressBarHeight;

  double tagsSlotHeight({required bool hasTags}) => emptyTagsSlotHeight;
}

// --- Visual tokens (design/CardPlan *.svg fallback) ---------------------------

abstract final class PlanCardTokens {
  // Component geometry belongs here; colors come exclusively from the
  // shared Life OS neutral and semantic design tokens.
  static const Color surface = AppColors.cardSurface;
  static const Color titleColor = AppNeutralTones.gray900;
  static const Color checkboxStroke = AppNeutralTones.gray300;
  static const Color playFill = AppNeutralTones.gray600;
  static const Color playHoverFill = AppNeutralTones.gray700;
  static const Color menuBg = AppNeutralTones.gray200;
  static const Color menuStroke = AppNeutralTones.gray500;
  static const Color dividerColor = AppNeutralTones.gray200;
  static const Color breadcrumbColor = kNordicWork;
  static const Color breadcrumbFallbackColor = AppNeutralTones.gray500;
  static const Color timeColor = AppNeutralTones.gray500;
  static final Color tagPinkBg = tagLetterChipPlate(kNordicPeople[500]!, AppColors.appBackground);
  static const Color tagPinkText = kTagPinkText;
  static final Color tagPurpleBg = tagLetterChipPlate(kNordicStudy[500]!, AppColors.appBackground);
  static const Color tagPurpleText = kNordicStudy;

  // Card surfaces are theme-aware; their foregrounds must follow the same
  // brightness. Keep legacy light tokens stable for existing light UI.
  static bool isDark(BuildContext context) =>
      Theme.of(context).colorScheme.brightness == Brightness.dark;

  static Color titleFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurface : titleColor;

  static Color timeFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurfaceVariant : timeColor;

  static Color mutedFor(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : breadcrumbFallbackColor;

  static Color dividerFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.outline : dividerColor;

  static Color playFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurfaceVariant : playFill;

  static Color checkboxStrokeFor(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : checkboxStroke;

  static Color checkboxFillFor(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : surface;

  static Color menuBackgroundFor(BuildContext context) =>
      isDark(context) ? AppNeutralTones.gray700 : menuBg;

  static Color menuStrokeFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurface : menuStroke;

  // Small category breadcrumbs must remain readable even when the persisted
  // category uses a dark/black hue. Do not recolor stored category data.
  static Color categoryTextFor(BuildContext context, Color color) {
    final scheme = Theme.of(context).colorScheme;
    if (color.a == 0) return mutedFor(context);
    if (scheme.brightness != Brightness.dark) return color;
    var adjusted = color;
    final backgroundLuminance = scheme.surfaceContainerHigh.computeLuminance();
    for (var i = 0; i < 12; i++) {
      final textLuminance = adjusted.computeLuminance();
      final brighter = textLuminance > backgroundLuminance
          ? textLuminance
          : backgroundLuminance;
      final darker = textLuminance > backgroundLuminance
          ? backgroundLuminance
          : textLuminance;
      if ((brighter + 0.05) / (darker + 0.05) >= 4.5) {
        return adjusted;
      }
      adjusted = Color.lerp(adjusted, scheme.onSurface, 0.2)!;
    }
    return scheme.onSurface;
  }

  static List<BoxShadow> cardShadow(bool interacting, {bool hovered = false}) =>
      [
        BoxShadow(
          color: Color(hovered ? 0x14000000 : 0x0A000000),
          blurRadius: interacting ? 6 : (hovered ? 8 : 4),
          offset: const Offset(0, 4),
        ),
      ];
}
