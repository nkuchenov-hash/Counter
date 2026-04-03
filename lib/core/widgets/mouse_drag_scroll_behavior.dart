import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets [PageView] and other scrollables accept **mouse / trackpad** drags on
/// desktop and web (Flutter defaults to touch-only for drag scrolling).
class MouseDragScrollBehavior extends MaterialScrollBehavior {
  const MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
