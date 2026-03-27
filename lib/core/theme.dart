// ---------------------------------------------------------------------------
// CORE — Global themes (light / dark). No UI logic. Use Theme.of(context).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Light theme (default). Material 3 with green seed.
ThemeData get appLightTheme => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.green,
      brightness: Brightness.light,
    );

/// Dark theme. Same seed; brightness forced for contrast.
ThemeData get appDarkTheme => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.green,
      brightness: Brightness.dark,
    );

/// Legacy single export — same as [appLightTheme].
ThemeData get appTheme => appLightTheme;

/// Maps profiles.theme_mode (`light` / `dark` / `system`) to [ThemeMode].
ThemeMode parseAppThemeMode(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
}
