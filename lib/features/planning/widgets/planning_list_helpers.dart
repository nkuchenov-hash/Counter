import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Shared elevation proxy for Planning reorderable lists.
Widget planningReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, c) {
      final v = Curves.easeInOut.transform(animation.value);
      return Material(
        elevation: lerpDouble(0, 10, v) ?? 0,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: c,
      );
    },
    child: child,
  );
}
