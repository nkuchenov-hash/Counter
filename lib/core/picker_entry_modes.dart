import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web: keyboard-friendly Material pickers. Native: calendar / dial.
DatePickerEntryMode appDatePickerEntryMode() =>
    kIsWeb ? DatePickerEntryMode.input : DatePickerEntryMode.calendar;

TimePickerEntryMode appTimePickerEntryMode() =>
    kIsWeb ? TimePickerEntryMode.input : TimePickerEntryMode.dial;
