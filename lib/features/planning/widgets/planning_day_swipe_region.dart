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
    this.dayKey,
    this.enabled = true,
  });

  final Widget child;
  /// The visible YYYY-MM-DD date. A change triggers one bounded arrival motion.
  final String? dayKey;
  /// -1 = previous day, +1 = next day.
  final ValueChanged<int> onDayChange;
  final bool enabled;

  @override
  State<PlanningDaySwipeRegion> createState() => _PlanningDaySwipeRegionState();
}

class _PlanningDaySwipeRegionState extends State<PlanningDaySwipeRegion>
    with SingleTickerProviderStateMixin {
  // Single short arrival, not the old rubber-band + second slide. Never animate
  // or rebuild the heavy card canvas while the user is dragging.
  static const Duration _arrivalDuration = Duration(milliseconds: 170);
  static const double _arrivalDistancePx = 18;
  late final AnimationController _arrival;
  int _arrivalSign = 1;

  @override
  void initState() {
    super.initState();
    _arrival = AnimationController(
      vsync: this,
      duration: _arrivalDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant PlanningDaySwipeRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDay = oldWidget.dayKey;
    final nextDay = widget.dayKey;
    if (oldDay != null && nextDay != null && nextDay != oldDay) {
      // Newer day enters from right; earlier day enters from left.
      _arrivalSign = nextDay.compareTo(oldDay) > 0 ? 1 : -1;
      _arrival.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

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
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _arrival,
          // The RepaintBoundary-heavy day stays a *child*, not rebuilt by
          // animation ticks. Transform is composited; no opacity saveLayer,
          // neighbor page, data fetch, layout pass, or snap-back on pointer-up.
          child: widget.child,
          builder: (context, dayBody) {
            final t = Curves.easeOutCubic.transform(_arrival.value);
            return Transform.translate(
              offset: Offset(_arrivalSign * _arrivalDistancePx * (1 - t), 0),
              child: dayBody,
            );
          },
        ),
      ),
    );
  }
}
