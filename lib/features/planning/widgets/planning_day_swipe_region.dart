import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Owns date swipes only inside the Planning day body. The sort controls,
/// quick-entry field and tag strip are deliberately outside this surface.
///
/// Unlike an outer PageView, this does not mount three whole Planning pages or
/// rebuild the tag catalog with every swipe. The surrounding vertical scroll
/// keeps ownership of vertical motion; card hold-to-edit owns long presses.
///
/// Never visually translate a heavy day during drag: without a mounted adjacent
/// page that creates a fake 60px rubber-band snap and forces GPU repaints on
/// every pointer update. The selected day changes once, on release.
class PlanningDaySwipeRegion extends StatefulWidget {
  const PlanningDaySwipeRegion({
    super.key,
    required this.child,
    required this.onDayChange,
    this.enabled = true,
  });

  final Widget child;
  /// -1 = previous day, +1 = next day.
  final ValueChanged<int> onDayChange;
  final bool enabled;

  @override
  State<PlanningDaySwipeRegion> createState() => _PlanningDaySwipeRegionState();
}

class _PlanningDaySwipeRegionState extends State<PlanningDaySwipeRegion> {
  static const double _commitDistancePx = 12;
  static const double _commitVelocityPxPerSecond = 140;
  double _dragDx = 0;

  void _reset() {
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    // No setState, notifier, layout or paint updates while the finger moves.
    _dragDx += details.primaryDelta ?? details.delta.dx;
  }

  void _onDragEnd(DragEndDetails details) {
    final dx = _dragDx;
    final velocity = details.primaryVelocity ?? 0;
    _reset();
    if (!widget.enabled) return;
    if (dx.abs() < _commitDistancePx &&
        velocity.abs() < _commitVelocityPxPerSecond) {
      return;
    }
    final direction = dx.abs() >= _commitDistancePx ? dx : velocity;
    widget.onDayChange(direction < 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: widget.enabled ? (_) => _reset() : null,
      onHorizontalDragUpdate: widget.enabled ? _onDragUpdate : null,
      onHorizontalDragEnd: widget.enabled ? _onDragEnd : null,
      onHorizontalDragCancel: widget.enabled ? _reset : null,
      child: widget.child,
    );
  }
}
