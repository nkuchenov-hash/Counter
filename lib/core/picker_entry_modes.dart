import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Omni-Picker Law (see ARCHITECTURE.md §8.1): whenever **both** date and time
/// are required, use a single unified dialog (`showAppDateTimePicker` →
/// `showOmniDateTimePickerDialog` on keyboard-friendly surfaces). Never chain
/// `showDatePicker` then `showTimePicker` in one user flow.
///
/// Web / desktop (Windows, macOS, Linux): keyboard-friendly Material pickers.
/// Mobile (iOS, Android, Fuchsia): calendar / dial.
bool _keyboardFriendlyPickerSurfaces() {
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

/// Web and desktop native: use [appDatePickerEntryMode] / [appTimePickerEntryMode].
/// Android / iOS / Fuchsia: touch-oriented calendar / dial.
bool useKeyboardFriendlyMaterialPickers() => _keyboardFriendlyPickerSurfaces();

DatePickerEntryMode appDatePickerEntryMode() => _keyboardFriendlyPickerSurfaces()
    ? DatePickerEntryMode.input
    : DatePickerEntryMode.calendar;

TimePickerEntryMode appTimePickerEntryMode() => _keyboardFriendlyPickerSurfaces()
    ? TimePickerEntryMode.input
    : TimePickerEntryMode.dial;
