import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

/// Supplies [UserSettings.tagDisplayMode] to canonical tag chips without Brain imports in chip widgets.
class TagDisplayModeScope extends InheritedWidget {
  const TagDisplayModeScope({
    super.key,
    required this.mode,
    required super.child,
  });

  final CategoryDisplayMode mode;

  static CategoryDisplayMode of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TagDisplayModeScope>();
    return scope?.mode ?? CategoryDisplayMode.letterChip;
  }

  @override
  bool updateShouldNotify(TagDisplayModeScope oldWidget) =>
      oldWidget.mode != mode;
}
