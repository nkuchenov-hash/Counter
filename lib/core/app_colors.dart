import 'package:flutter/material.dart';

/// Life OS / Counter design tokens (V3/V7). Change [actionPrimary] once to
/// retint buttons, tabs, nav selection, and other default action chrome.
abstract final class AppColors {
  // --- Action / brand (default UI chrome, not category data) ---
  static const Color actionPrimary = Color(0xFF111111);
  static const Color onActionPrimary = Color(0xFFFFFFFF);
  static const Color actionPrimaryContainer = Color(0xFFF0EFEC);
  static const Color onActionPrimaryContainer = Color(0xFF111111);

  // --- Surfaces ---
  static const Color appBackground = Color(0xFFFAFAF8);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE6E3DE);
  static const Color borderMuted = Color(0xFFE8E8E4);
  static const Color surfaceMuted = Color(0xFFF4F4F2);

  // --- Semantic (success only — not default action color) ---
  static const Color success = Color(0xFF2E7D32);
  static const Color onSuccess = Color(0xFFFFFFFF);

  // --- Dark surfaces ---
  static const Color darkAppBackground = Color(0xFF121212);
  static const Color darkCardSurface = Color(0xFF1E1E1E);
  static const Color darkActionPrimary = Color(0xFFE8E8E4);
  static const Color onDarkActionPrimary = Color(0xFF111111);
  static const Color darkActionPrimaryContainer = Color(0xFF2A2A2A);
  static const Color onDarkActionPrimaryContainer = Color(0xFFE8E8E4);

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
        error: Color(0xFFB3261E),
        onError: onActionPrimary,
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
        secondary: Color(0xFFCACACA),
        onSecondary: onDarkActionPrimary,
        secondaryContainer: Color(0xFF333333),
        onSecondaryContainer: darkActionPrimary,
        tertiary: Color(0xFF9E9E9E),
        onTertiary: onDarkActionPrimary,
        tertiaryContainer: Color(0xFF2A2A2A),
        onTertiaryContainer: darkActionPrimary,
        error: Color(0xFFF2B8B5),
        onError: Color(0xFF601410),
        errorContainer: Color(0xFF8C1D18),
        onErrorContainer: Color(0xFFF9DEDC),
        surface: darkAppBackground,
        onSurface: darkActionPrimary,
        surfaceContainerHighest: darkCardSurface,
        surfaceContainerHigh: darkCardSurface,
        surfaceContainer: darkCardSurface,
        surfaceContainerLow: darkAppBackground,
        surfaceContainerLowest: darkAppBackground,
        onSurfaceVariant: Color(0xFFB0B0B0),
        outline: Color(0xFF4A4A4A),
        outlineVariant: Color(0xFF3A3A3A),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: darkActionPrimary,
        onInverseSurface: onDarkActionPrimary,
        inversePrimary: Color(0xFF3D3D3D),
        surfaceTint: Colors.transparent,
      );
}
