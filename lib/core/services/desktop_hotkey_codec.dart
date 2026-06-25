import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Validates and formats desktop global hotkey combinations.
abstract final class DesktopHotkeyCodec {
  static bool isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.capsLock;
  }

  /// At least one modifier and a non-modifier main key.
  static bool isValidCombo({
    required LogicalKeyboardKey logicalKey,
    required bool control,
    required bool shift,
    required bool alt,
    required bool meta,
  }) {
    if (isModifierKey(logicalKey)) return false;
    if (!control && !shift && !alt && !meta) return false;
    return true;
  }

  static String displayLabel({
    required LogicalKeyboardKey logicalKey,
    required bool control,
    required bool shift,
    required bool alt,
    required bool meta,
  }) {
    final parts = <String>[];
    if (control) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');
    if (meta) parts.add('Win');
    final key = mainKeyLabel(logicalKey);
    if (key.isNotEmpty) parts.add(key);
    return parts.join('+');
  }

  static String mainKeyLabel(LogicalKeyboardKey key) {
    if (isModifierKey(key)) return '';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    final label = key.keyLabel;
    if (label.isEmpty) return 'Key';
    if (label.length == 1) return label.toUpperCase();
    return label;
  }

  /// Read modifier flags without duplicate left/right keys in the main slot.
  static ({bool control, bool shift, bool alt, bool meta}) readModifiers() {
    final kb = HardwareKeyboard.instance;
    return (
      control: kb.isControlPressed,
      shift: kb.isShiftPressed,
      alt: kb.isAltPressed,
      meta: kb.isMetaPressed,
    );
  }
}
