import 'package:counter/core/shell_adaptive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Omni-Picker Law (see ARCHITECTURE.md §8.1): whenever **both** date and time
/// are required, use a single unified dialog (`showAppDateTimePicker` →
/// `showOmniDateTimePickerDialog` on keyboard-friendly surfaces). Never chain
/// `showDatePicker` then `showTimePicker` in one user flow.
///
/// Wide web / desktop (Windows, macOS, Linux): keyboard-friendly Material pickers.
/// Phone-width shell + mobile native (iOS, Android, Fuchsia): calendar / dial.
bool _keyboardFriendlyPickerSurfaces({double? viewportWidth}) {
  if (viewportWidth != null &&
      shellUsesCompactPhoneLayout(viewportWidth)) {
    return false;
  }
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

/// Web desktop and desktop native: use [appDatePickerEntryMode] / [appTimePickerEntryMode].
/// Phone-width shell and Android / iOS / Fuchsia: touch-oriented calendar / dial.
bool useKeyboardFriendlyMaterialPickers({double? viewportWidth}) =>
    _keyboardFriendlyPickerSurfaces(viewportWidth: viewportWidth);

bool useKeyboardFriendlyMaterialPickersFromContext(BuildContext context) =>
    useKeyboardFriendlyMaterialPickers(
      viewportWidth: MediaQuery.sizeOf(context).width,
    );

DatePickerEntryMode appDatePickerEntryMode({double? viewportWidth}) =>
    _keyboardFriendlyPickerSurfaces(viewportWidth: viewportWidth)
        ? DatePickerEntryMode.input
        : DatePickerEntryMode.calendar;

DatePickerEntryMode appDatePickerEntryModeFromContext(BuildContext context) =>
    appDatePickerEntryMode(viewportWidth: MediaQuery.sizeOf(context).width);

TimePickerEntryMode appTimePickerEntryMode({double? viewportWidth}) =>
    _keyboardFriendlyPickerSurfaces(viewportWidth: viewportWidth)
        ? TimePickerEntryMode.input
        : TimePickerEntryMode.dial;

TimePickerEntryMode appTimePickerEntryModeFromContext(BuildContext context) =>
    appTimePickerEntryMode(viewportWidth: MediaQuery.sizeOf(context).width);
