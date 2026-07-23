import 'package:counter/core/widgets/app_physical_drag_surface.dart';
import 'package:flutter/material.dart';

/// Shared physical proxy for Planning reorderable lists.
Widget planningReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, proxyChild) {
      final progress = Curves.easeOutCubic.transform(animation.value);
      return AppPhysicalDragVisual(
        phase: AppPhysicalCardPhase.dragging,
        progress: progress,
        child: proxyChild!,
      );
    },
  );
}
