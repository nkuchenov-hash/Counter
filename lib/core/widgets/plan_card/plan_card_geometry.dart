import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';
import 'package:flutter/material.dart';
// --- Figma geometry (328px reference) ----------------------------------------

abstract final class PlanCardGeom {
  static const double refWidth = 328;
  static const double padLeft = 12;
  static const double padRight = 12;
  static const double padTopMediumLarge = 10;
  static const double padTopSmall = 10;
  static const double controlSize = 32;
  static const double playInlineX = 48;
  static const double contentXSmall = 84;
  static const double contentXMediumLarge = 56;
  static const double railWidth = 32;
  static const double railToContentGap = 12;
  static const double checkboxPlayGap = 8;
  static const double playIconWidth = 22;
  static const double playIconHeight = 24;
  static const double playIconCornerRadius = 4.0;
  static const double recurringIconSize = 15;
  static const double titleToRecurringGap = 5;
  static const double playAfterCheckboxGap = 4;
  static const double menuSize = 33;
  static const double timeViewRailToContentGap = 6;
  static const double contentSpanMediumLarge = 260;
  static const double radius = 12;
  static const double refHeightMicro = 38;
  static const double refHeightSmall = 54;
  static const double refHeightMedium = 106;
  static const double refHeightLarge = 147;
  static const double tagRowHeight = 16;
  static const double tagGap = 5;
  static const double titleToTagsGap = 2;
  static const double emptyTagsSlotHeight = 18;
  static const double tagsToProgressGap = 3;
  static const double actualTimeSlotHeight = 8;
  static const double progressAfterActualGap = 3;
  static const double progressBarHeight = 3;
  static const double footerBlockGap = 6;
  static const double footerTimeGap = 6;
  static const double footerTimeRightSafePad = 6;
  static const double footerTextHeight = 14;
  static const double footerBottomPad = 8;
  static const double titleTopInset = 0;
  static const double titleLineHeight = 16;
  static const double titleRowHeight = 33;
  static const double timelineBlockAllowancePx = 2;
  static const double watermarkMinCardHeight = 90;

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
  static const Color surface = Color(0xFFF8F8F8);
  static const Color titleColor = Color(0xFF353535);
  static const Color checkboxStroke = Color(0xFFCCCCCC);
  static const Color playFill = Color(0xFF696969);
  static const Color menuBg = Color(0xFFEBEBEB);
  static const Color menuStroke = Color(0xFF8E8E8E);
  static const Color dividerColor = Color(0x61D9D9D9);
  static const Color breadcrumbColor = Color(0xFF609CE1);
  static const Color breadcrumbFallbackColor = Color(0xFF878787);
  static const Color timeColor = Color(0xB8878787);
  static const Color tagPinkBg = Color(0xFFFFE8E8);
  static const Color tagPinkText = Color(0xFFF55D88);
  static const Color tagPurpleBg = Color(0xFFEEE5F8);
  static const Color tagPurpleText = Color(0xFF7118E5);

  static List<BoxShadow> cardShadow(bool interacting, {bool hovered = false}) =>
      [
        BoxShadow(
          color: Color(hovered ? 0x14000000 : 0x0A000000),
          blurRadius: interacting ? 6 : (hovered ? 8 : 4),
          offset: const Offset(0, 4),
        ),
      ];
}
