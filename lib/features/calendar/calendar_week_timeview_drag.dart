import 'dart:async';

import 'package:counter/data/models.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:flutter/material.dart';

/// Use the exact Time View pointer/hold gesture recognizer in Calendar Week.
/// No nested Flutter Draggable vs Scrollable gesture-arena competition.
class CalendarWeekTimeViewDrag extends StatefulWidget {
  const CalendarWeekTimeViewDrag({
    super.key,
    required this.tasks,
    required this.canMove,
    required this.height,
    required this.child,
    required this.onTap,
    required this.onDrop,
  });
  final List<PlanningTask> tasks;
  final bool canMove;
  final double height;
  final Widget child;
  final VoidCallback onTap;
  final Future<void> Function(List<PlanningTask>, Offset, double) onDrop;

  @override
  State<CalendarWeekTimeViewDrag> createState() =>
      _CalendarWeekTimeViewDragState();
}

class _CalendarWeekTimeViewDragState extends State<CalendarWeekTimeViewDrag> {
  Offset? _down;
  Offset? _pointer;
  double _grabOffset = 0;
  bool _active = false;
  OverlayEntry? _feedback;

  void _removeFeedback() {
    _feedback?.remove();
    _feedback?.dispose();
    _feedback = null;
    _active = false;
  }

  void _start(double grabOffset) {
    if (!widget.canMove) return;
    _active = true;
    _grabOffset = grabOffset;
    if (_feedback != null) return;
    _feedback = OverlayEntry(builder: (overlayContext) {
      final box = Overlay.of(overlayContext).context.findRenderObject();
      final point = _pointer ?? _down ?? Offset.zero;
      final local = box is RenderBox ? box.globalToLocal(point) : point;
      final primary = widget.tasks.first;
      final st = primary.startTime;
      final time = st == null ? '' : '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')}';
      final count = widget.tasks.length > 1 ? '${widget.tasks.length} × ' : '';
      return Positioned(
        left: local.dx - 34,
        top: local.dy - _grabOffset,
        child: IgnorePointer(
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(7),
            color: Theme.of(overlayContext).colorScheme.surfaceContainerHighest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 210, minHeight: 34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Text('$time  $count${primary.title}',
                  overflow: TextOverflow.ellipsis, maxLines: 2),
              ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_feedback!);
  }

  void _finish() {
    if (!_active) {
      _removeFeedback();
      return;
    }
    final a = _down;
    final b = _pointer;
    _removeFeedback();
    if (a == null || b == null || (b - a).distance < 8) return;
    unawaited(widget.onDrop(widget.tasks, b, _grabOffset));
  }

  @override
  void dispose() {
    _removeFeedback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _down = event.position;
        _pointer = event.position;
      },
      onPointerMove: (event) {
        _pointer = event.position;
        if (_active) _feedback?.markNeedsBuild();
      },
      onPointerUp: (event) => _pointer = event.position,
      onPointerCancel: (_) => _removeFeedback(),
      child: TimelinePlanInteractionBlock(
        canMove: widget.canMove,
        canResize: false,
        bulkSelectMode: false,
        resizeHandlePx: 0,
        blockHeightPx: widget.height,
        isInteracting: _active,
        onBodyTap: widget.onTap,
        onVerticalDragStart: _start,
        onVerticalDragUpdate: (_, __) => _feedback?.markNeedsBuild(),
        onVerticalDragEnd: _finish,
        onVerticalDragCancel: _removeFeedback,
        onMovePointerRelease: _removeFeedback,
        child: widget.child,
      ),
    );
  }
}
