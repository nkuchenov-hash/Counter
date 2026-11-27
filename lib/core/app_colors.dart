import 'package:counter/core/life_color_compat.dart';
import 'package:flutter/material.dart';

/// Life OS design tokens: neutral chrome shared across every feature.
/// Semantic category/tag color families live in category_color_palette.dart;
/// success/error controls keep their own meaning and never inherit category hues.
/// Pure neutral ramp for interface chrome; separate from semantic category
/// gray (which is a selectable tag/category identity). Keep white/black and
/// many true grays available without introducing random blue or beige tints.
abstract final class AppNeutralTones {
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray75 = Color(0xFFF7F7F7);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray150 = Color(0xFFF0F0F0);
  static const Color gray200 = Color(0xFFE5E5E5);
  static const Color gray300 = Color(0xFFD4D4D4);
  static const Color gray400 = Color(0xFFA3A3A3);
  static const Color gray500 = Color(0xFF737373);
  static const Color gray600 = Color(0xFF525252);
  static const Color gray700 = Color(0xFF404040);
  static const Color gray800 = Color(0xFF262626);
  static const Color gray900 = Color(0xFF171717);
  static const Color gray950 = Color(0xFF0A0A0A);
  static const Color black = Color(0xFF000000);
}

/// Only representational material colors (pencil wood, fountain-pen gold,
/// eraser rubber). These belong to drawings of physical objects, NOT to UI
/// states, categories, tags, brand colors or the drawing tool color picker.
abstract final class AppIllustrationColors {
  static const Color pencilWoodLight = Color(0xFFEAD6B2);
  static const Color pencilWoodMiddle = Color(0xFFF2E4C5);
  static const Color pencilWoodShadow = Color(0xFFE1C79C);

  static const Color fountainGoldShadow = Color(0xFF9D761C);
  static const Color fountainGoldHighlight = Color(0xFFFFEAA0);
  static const Color fountainGoldMiddle = Color(0xFFD0A233);
  static const Color fountainGoldDeep = Color(0xFF8F6B16);

  static const Color eraserRubberDark = Color(0xFFC9806F);
  static const Color eraserRubberHighlight = Color(0xFFF8CCBE);
  static const Color eraserRubberMiddle = Color(0xFFE5A091);
  static const Color eraserRubberShadow = Color(0xFFB97264);
}

abstract final class AppColors {
  // --- Action / brand (default UI chrome, not category data) ---
  static const Color actionPrimary = Color(0xFF111111);
  static const Color onActionPrimary = AppNeutralTones.white;
  static const Color actionPrimaryContainer = AppNeutralTones.gray100;
  static const Color onActionPrimaryContainer = Color(0xFF111111);

  // --- Surfaces ---
  // One global light canvas for Menu, Timeline, Plans and other destinations.
  static const Color appBackground = AppNeutralTones.gray75;
  static const Color cardSurface = AppNeutralTones.white;
  static const Color borderSubtle = AppNeutralTones.gray300;
  static const Color borderMuted = AppNeutralTones.gray200;
  static const Color surfaceMuted = AppNeutralTones.gray100;

  // Approved v45 editor glass material. Scoped to floating editor docks;
  // these translucent stops do not redefine the neutral app canvas.
  static const Color editorGlassDarkTop = Color(0xFF30333B);
  static const Color editorGlassDarkBottom = Color(0xFF181A1F);
  static const Color editorPaperDark = editorGlassDarkBottom;
  static const Color editorTimeCardLight = Color(0xFFF4F6F9);
  static const Color editorTimeCardDark = Color(0xFF252830);
  static const Color editorRuleLight = Color(0xFFE5E7EB);
  static const Color editorRuleDark = Color(0xFF373B45);

  // Navigation rows, shared across Settings and nested Settings pages.
  // Chevrons must be less prominent than labels; dividers must remain
  // visible on white cards even while neighboring rows are hovered.
  static const Color settingsChevron = AppNeutralTones.gray400;
  static const Color darkSettingsChevron = Color(0xFF9A9A9A);
  // Soft, still visible 1px separators against white/dark card surfaces.
  // Use the shared neutral ramp; avoid the former harsh 300/600 contrast.
  static const Color settingsDivider = AppNeutralTones.gray200;
  static const Color darkSettingsDivider = Color(0xFF3B3B3B);

  // --- Semantic (success only — not default action color) ---
  static const Color success = Color(0xFF2E7D32);
  static const Color onSuccess = AppNeutralTones.white;
  static const Color warning = Color(0xFFB0700A);
  static const Color onWarning = AppNeutralTones.white;
  static const Color information = kNordicWork;
  static const Color onInformation = AppNeutralTones.white;
  static const Color error = Color(0xFFB3261E);
  static const Color onError = AppNeutralTones.white;

  // Approved tag typography values, separate from the family root color.
  static const Color yellowTagText = Color(0xFFB18900);
  static const Color pinkTagText = Color(0xFFD25888);
  static const Color orangeTagText = Color(0xFFD95400);

  // --- Dark surfaces ---
  // Layered, achromatic graphite palette. The canvas is no longer pure black:
  // cards, controls, muted labels and outlines must remain visually distinct.
  // Semantic category/tag colors are not modified or persisted by theme changes.
  static const Color darkAppBackground = Color(0xFF101010);
  static const Color darkCardSurface = Color(0xFF212121);
  static const Color darkActionPrimary = Color(0xFFF2F2F2);
  static const Color onDarkActionPrimary = Color(0xFF171717);
  static const Color darkActionPrimaryContainer = Color(0xFF353535);
  static const Color onDarkActionPrimaryContainer = Color(0xFFF2F2F2);

  static ColorScheme lightColorScheme() => const ColorScheme(
        brightness: Brightness.light,
        primary: actionPrimary,
        onPrimary: onActionPrimary,
        primaryContainer: actionPrimaryContainer,
        onPrimaryContainer: onActionPrimaryContainer,
        secondary: Color(0xFF3D3D3D),
        onSecondary: onActionPrimary,
        secondaryContainer: borderMuted,
        onSecondaryContainer: actionPrimary,
        tertiary: Color(0xFF5C5C5C),
        onTertiary: onActionPrimary,
        tertiaryContainer: surfaceMuted,
        onTertiaryContainer: actionPrimary,
        error: error,
        onError: onError,
        errorContainer: Color(0xFFF9DEDC),
        onErrorContainer: Color(0xFF410E0B),
        surface: appBackground,
        onSurface: actionPrimary,
        surfaceContainerHighest: cardSurface,
        surfaceContainerHigh: cardSurface,
        surfaceContainer: cardSurface,
        surfaceContainerLow: appBackground,
        surfaceContainerLowest: appBackground,
        onSurfaceVariant: Color(0xFF5C5C5C),
        outline: borderSubtle,
        outlineVariant: borderMuted,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: actionPrimary,
        onInverseSurface: onActionPrimary,
        inversePrimary: Color(0xFFD4D4D4),
        surfaceTint: Colors.transparent,
      );

  static ColorScheme darkColorScheme() => const ColorScheme(
        brightness: Brightness.dark,
        primary: darkActionPrimary,
        onPrimary: onDarkActionPrimary,
        primaryContainer: darkActionPrimaryContainer,
        onPrimaryContainer: onDarkActionPrimaryContainer,
        secondary: Color(0xFFD5D5D5),
        onSecondary: onDarkActionPrimary,
        secondaryContainer: Color(0xFF303030),
        onSecondaryContainer: darkActionPrimary,
        tertiary: Color(0xFFC2C2C2),
        onTertiary: onDarkActionPrimary,
        tertiaryContainer: Color(0xFF292929),
        onTertiaryContainer: darkActionPrimary,
        error: Color(0xFFF2B8B5),
        onError: Color(0xFF601410),
        errorContainer: Color(0xFF8C1D18),
        onErrorContainer: Color(0xFFF9DEDC),
        surface: darkAppBackground,
        onSurface: darkActionPrimary,
        surfaceContainerHighest: Color(0xFF373737),
        surfaceContainerHigh: Color(0xFF282828),
        surfaceContainer: darkCardSurface,
        surfaceContainerLow: Color(0xFF181818),
        surfaceContainerLowest: darkAppBackground,
        onSurfaceVariant: Color(0xFFBDBDBD),
        outline: Color(0xFF5A5A5A),
        outlineVariant: Color(0xFF444444),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: darkActionPrimary,
        onInverseSurface: onDarkActionPrimary,
        inversePrimary: Color(0xFF3D3D3D),
        surfaceTint: Colors.transparent,
      );
}
