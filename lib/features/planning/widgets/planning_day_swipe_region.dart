import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Owns date swipes only inside the Planning day body. The sort controls,
/// quick-entry field and tag strip are deliberately outside this surface.
///
/// Unlike an outer PageView, this does not mount three whole Planning pages or
/// rebuild the tag catalog with every swipe. The surrounding vertical scroll
/// keeps ownership of vertical motion; card hold-to-edit owns long presses.
///
/// Drag accumulation is logic-only: no per-pointer card layout or paint.
/// On date commitment, slide the old and new day canvases a full viewport
/// in 200ms without re-mounting Planning chrome or fetching adjacent days.
class PlanningDaySwipeRegion extends StatefulWidget {
  const PlanningDaySwipeRegion({
    super.key,
    required this.child,
    required this.onDayChange,
    this.dayKey,
    this.keepOutgoingContent = true,
    this.enabled = true,
  });

  final Widget child;
  /// The visible YYYY-MM-DD date. A change triggers a full-width settle slide.
  final String? dayKey;
  /// False for Time mode: never mount two grids on one ScrollController.
  final bool keepOutgoingContent;
  /// -1 = previous day, +1 = next day.
  final ValueChanged<int> onDayChange;
  final bool enabled;

  @override
  State<PlanningDaySwipeRegion> createState() => _PlanningDaySwipeRegionState();
}

class _PlanningDaySwipeRegionState extends State<PlanningDaySwipeRegion>
    with SingleTickerProviderStateMixin {
  // One full-width, two-surface date slide after release. The previous
  // content is kept for only the settling animation; no neighboring Planning
  // streams, page mounts, warmup or network calls during a pointer gesture.
  static const Duration _settleDuration = Duration(milliseconds: 200);
  late final AnimationController _slide;
  Widget? _outgoingBody;
  int _travelSign = 1;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: _settleDuration,
      value: 1,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && _outgoingBody != null &&
          mounted) {
        setState(() => _outgoingBody = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlanningDaySwipeRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDay = oldWidget.dayKey;
    final nextDay = widget.dayKey;
    if (oldDay != null && nextDay != null && nextDay != oldDay) {
      _travelSign = nextDay.compareTo(oldDay) > 0 ? 1 : -1;
      _outgoingBody = oldWidget.keepOutgoingContent
          ? oldWidget.child
          : const SizedBox.expand();
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
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
          animation: _slide,
          // The card canvases are fixed children: only composited fractional
          // translations update for 200ms. Never lay out pages per animation
          // tick; the header, tags and quick entry remain outside this region.
          child: widget.child,
          builder: (context, activeBody) {
            final t = Curves.easeOutCubic.transform(_slide.value);
            final outgoing = _outgoingBody;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (outgoing != null)
                  IgnorePointer(
                    key: const ValueKey('planning-outgoing-slide'),
                    child: TickerMode(
                      enabled: false,
                      child: FractionalTranslation(
                        translation: Offset(-_travelSign * t, 0),
                        child: outgoing,
                      ),
                    ),
                  ),
                // Stable key prevents reparent/remount of the expensive
                // active Time/list content when the outgoing surface exits.
                FractionalTranslation(
                  key: const ValueKey('planning-active-slide'),
                  translation: Offset(
                    outgoing == null ? 0 : _travelSign * (1 - t), 0),
                  child: activeBody,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
