import 'package:flutter/material.dart';

/// Executable mapping of the Notes variables and geometry from APP-Design.
///
/// Visual source:
/// - Notes/Screen/Mobile Core · Mode=Filled Note · Project (601:8710)
/// - Notes/Screen/Desktop · Mode=Filled Editor (568:7944)
/// - Notes/Formatting Toolbar (604:8938)
///
/// Light values mirror the named Figma variables. Dark mode resolves through
/// the app ColorScheme so one shared component remains usable in both modes.
abstract final class NotesFigmaTokens {
  // Figma semantic variables.
  static const Color colorCanvas = Color(0xFFF1F5FA);
  static const Color colorTextPrimary = Color(0xFF111827);
  static const Color colorTextSecondary = Color(0xFF6B7280);
  static const Color colorIconSecondary = Color(0xFF6B7280);
  static const Color colorSurfaceCard = Color(0xFFFFFFFF);
  static const Color colorBorderSubtle = Color(0xFFE5E5EA);
  static const Color colorSurfaceGlassFillStart = Color(0xBFFFFFFF);
  static const Color colorSurfaceGlassStroke = Color(0xB2FFFFFF);
  static const Color colorSelectedSurface = Color(0xFF111827);
  static const Color colorSelectedIcon = Color(0xFFFFFFFF);

  // Screen geometry from the approved Notes frames.
  static const double editorSurfaceMaxWidth = 960;
  static const double editorContentMaxWidth = 880;
  static const double editorDesktopOuterInset = 20;
  static const double editorSurfaceRadius = 28;
  static const double editorContentInset = 20;
  static const double editorDesktopContentInset = 40;

  // Typography from Notes/Title Block V2 and Notes/Text Formatting.
  static const double titleSize = 32;
  static const double titleLineHeight = 40;
  static const double bodySize = 16;
  static const double bodyLineHeight = 24;
  static const double h1Size = 24;
  static const double h1LineHeight = 30;
  static const double h2Size = 20;
  static const double h2LineHeight = 26;
  static const double h3Size = 18;
  static const double h3LineHeight = 24;
  static const double badgeSize = 11;
  static const double badgeLineHeight = 13;

  // Notes/Formatting Toolbar.
  static const double toolbarWidth = 350;
  static const double toolbarHeight = 48;
  static const double toolbarRadius = 24;
  static const double toolbarHorizontalPadding = 16;
  static const double toolbarVerticalPadding = 8;
  static const double toolbarButtonSize = 32;
  static const double toolbarButtonRadius = 8;
  static const double toolbarIconSize = 16;

  static const double floatingMenuRadius = 16;
  static const double glassBlur = 4;
  static const double floatingMenuBlur = 24;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvas(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surface
      : colorCanvas;

  static Color textPrimary(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurface
      : colorTextPrimary;

  static Color textSecondary(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : colorTextSecondary;

  static Color iconSecondary(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : colorIconSecondary;

  static Color surfaceCard(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surface
      : colorSurfaceCard;

  static Color borderSubtle(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant
      : colorBorderSubtle;

  static Color glassFill(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.82)
      : colorSurfaceGlassFillStart;

  static Color glassStroke(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)
      : colorSurfaceGlassStroke;

  static Color selectedSurface(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurface
      : colorSelectedSurface;

  static Color selectedIcon(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surface
      : colorSelectedIcon;

  static BoxShadow get toolbarShadow => BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 6,
    offset: const Offset(0, 4),
  );

  static BoxShadow get editorShadow => BoxShadow(
    color: Colors.black.withValues(alpha: 0.08),
    blurRadius: 32,
    offset: const Offset(0, 12),
  );

  static BoxShadow get floatingMenuShadow => BoxShadow(
    color: Colors.black.withValues(alpha: 0.14),
    blurRadius: 30,
    offset: const Offset(0, 12),
  );
}