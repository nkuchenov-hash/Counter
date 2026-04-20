// ---------------------------------------------------------------------------
// CORE — Global themes (light / dark). No UI logic. Use Theme.of(context).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Max width for sign-in / register forms.
const double kAuthFormMaxWidth = 420;

// --- Planning task edit sheet (Strike 23: mobile / keyboard) ---
/// [QuillSimpleToolbarConfig.toolbarSize] when [multiRowsDisplay] is false (single horizontal strip).
const double kPlanningEditQuillToolbarRowSize = 13;
/// Passed to [QuillToolbarBaseButtonOptions.iconSize] for denser toolbar buttons.
const double kPlanningEditQuillToolbarIconSize = 17;
/// Vertical padding above the Save/Cancel row when the keyboard is hidden.
const double kPlanningEditActionBarPadV = 8;
/// Tighter vertical padding when [MediaQuery.viewInsets.bottom] > 0.
const double kPlanningEditActionBarPadVKeyboard = 2;
const double kPlanningEditActionBarPadH = 12;
const double kPlanningEditActionBarBottomPad = 12;
const double kPlanningEditActionBarBottomPadKeyboard = 4;
/// Min height for [QuillSimpleToolbar] so single-row controls are not vertically clipped.
const double kPlanningEditQuillToolbarMinHeight = 44;

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
