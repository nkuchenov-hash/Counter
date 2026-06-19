// ---------------------------------------------------------------------------
// CORE — Global themes (light / dark). No UI logic. Use Theme.of(context).
// ---------------------------------------------------------------------------

import 'package:counter/core/app_colors.dart';
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

ThemeData _buildAppTheme(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;
  final cardFill = isLight ? AppColors.cardSurface : AppColors.darkCardSurface;
  final fabBg = isLight ? AppColors.cardSurface : AppColors.darkCardSurface;
  final fabFg = isLight ? AppColors.actionPrimary : AppColors.darkActionPrimary;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      color: cardFill,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.85)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: fabBg,
      foregroundColor: fabFg,
      elevation: 2,
      highlightElevation: 4,
      shape: const CircleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardFill,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          size: 24,
        );
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      side: BorderSide(color: scheme.outline),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.surfaceContainerHighest;
      }),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: cardFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardFill,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
  );
}

/// Light theme — near-white surfaces, black primary actions.
ThemeData get appLightTheme => _buildAppTheme(AppColors.lightColorScheme());

/// Dark theme — same action contract inverted for contrast.
ThemeData get appDarkTheme => _buildAppTheme(AppColors.darkColorScheme());

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
