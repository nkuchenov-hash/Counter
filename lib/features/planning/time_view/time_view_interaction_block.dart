import 'dart:math' as math;

import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pointer routing for proportional Time View cards.
///
/// The top and bottom edge strips own duration resize across the full card
/// width. The center body captures the pointer immediately, but the visible
/// drag state starts only on the first real movement. A release without any
/// movement remains a short click and never flashes a drag preview.
class TimelinePlanInteractionBlock extends StatefulWidget {
  const TimelinePlanInteractionBlock({
    required this.canMove,
    required this.canResize,
    required this.bulkSelectMode,
    required this.resizeHandlePx,
    required this.child,
    required this.isInteracting,
    this.blockHeightPx,
    this.controlsLeftInset = 0,
    this.controlsRightInset = 0,
    this.onBodyTap,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragVelocityChanged,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onMovePointerDown,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
  });

  final bool canMove;
  final bool canResize;
  final bool bulkSelectMode;
  final double resizeHandlePx;
  final bool isInteracting;
  final double? blockHeightPx;
  final Widget child;
  final double controlsLeftInset;
  final double controlsRightInset;
  final VoidCallback? onBodyTap;
  final void Function(double fingerGrabOffsetCanvasPx)? onVerticalDragStart;
  final void Function(double deltaPx, double globalDy)? onVerticalDragUpdate;
  final ValueChanged<double>? onVerticalDragVelocityChanged;
  final VoidCallback? onVerticalDragEnd;
  final VoidCallback? onVerticalDragCancel;
  final VoidCallback? onMovePointerDown;
  final void Function(TimelineResizeEdge edge)? onResizeStart;
  final void Function(double deltaPx, double globalDy)? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResizeCancel;

  @override
  State<TimelinePlanInteractionBlock> createState() =>
      TimelinePlanInteractionBlockState();
}

class TimelinePlanInteractionBlockState
    extends State<TimelinePlanInteractionBlock> {
  double _moveAccumulatedDy = 0;
  bool _resizing = false;
  bool _bodyDragActive = false;
  int? _activePointer;
  double _pendingGrabOffsetCanvasPx = 0;
  Offset? _pointerDownGlobal;
  double? _lastVelocityGlobalDy;
  int _lastVelocityMicros = 0;
  double _smoothedVerticalVelocity = 0;

  bool _useImmediatePointerDrag = false;

  double get _resizeHandleHeight {
    final h = widget.blockHeightPx ?? widget.resizeHandlePx * 2;
    final preferred = _useImmediatePointerDrag
        ? math.min(widget.resizeHandlePx, 12.0)
        : math.max(widget.resizeHandlePx, 20.0);
    final maxHeight = math.max(8.0, (h - 8.0) / 2);
    return preferred.clamp(8.0, maxHeight).toDouble();
  }

  void _resetMoveGesture() {
    _bodyDragActive = false;
    _moveAccumulatedDy = 0;
    _pointerDownGlobal = null;
    _activePointer = null;
    _lastVelocityGlobalDy = null;
    _lastVelocityMicros = 0;
    _smoothedVerticalVelocity = 0;
  }

  void _startVelocityTracking() {
    _lastVelocityGlobalDy = _pointerDownGlobal?.dy;
    _lastVelocityMicros = DateTime.now().microsecondsSinceEpoch;
    _smoothedVerticalVelocity = 0;
    widget.onVerticalDragVelocityChanged?.call(0);
  }

  void _trackVerticalVelocity(double globalDy) {
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final previousDy = _lastVelocityGlobalDy;
    final previousMicros = _lastVelocityMicros;
    _lastVelocityGlobalDy = globalDy;
    _lastVelocityMicros = nowMicros;
    if (previousDy == null || previousMicros == 0) return;
    final dtSeconds = (nowMicros - previousMicros) / 1000000.0;
    if (dtSeconds <= 0 || dtSeconds > 0.2) return;
    final instantVelocity = (globalDy - previousDy) / dtSeconds;
    _smoothedVerticalVelocity = _smoothedVerticalVelocity == 0
        ? instantVelocity
        : (_smoothedVerticalVelocity * 0.68) + (instantVelocity * 0.32);
    widget.onVerticalDragVelocityChanged?.call(_smoothedVerticalVelocity);
  }

  void _captureMovePointer(PointerDownEvent event, double resizeInset) {
    if (_activePointer != null) return;
    _resetMoveGesture();
    _activePointer = event.pointer;
    _pendingGrabOffsetCanvasPx = event.localPosition.dy + resizeInset;
    _pointerDownGlobal = event.position;
    if (kDebugMode) {
      debugPrint('[TIME_VIEW_POINTER_CAPTURED_WITHOUT_VISUAL_JUMP]');
    }
    widget.onMovePointerDown?.call();
  }

  void _startVisibleMove() {
    if (_bodyDragActive) return;
    _bodyDragActive = true;
    _startVelocityTracking();
    if (kDebugMode) {
      debugPrint('[TIME_VIEW_DRAG_STARTED_ON_FIRST_MOVEMENT]');
    }
    widget.onVerticalDragStart?.call(_pendingGrabOffsetCanvasPx);
  }

  void _updateMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    final down = _pointerDownGlobal;
    if (down == null) return;
    final totalDelta = event.position - down;
    if (!_bodyDragActive) {
      if (totalDelta.distanceSquared == 0) return;
      _startVisibleMove();
    }
    _trackVerticalVelocity(event.position.dy);
    _moveAccumulatedDy = totalDelta.dy;
    widget.onVerticalDragUpdate?.call(
      _moveAccumulatedDy,
      event.position.dy,
    );
  }

  void _finishMove(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    if (_bodyDragActive) {
      widget.onVerticalDragEnd?.call();
    } else {
      widget.onVerticalDragCancel?.call();
      if (kDebugMode) {
        debugPrint(
          widget.bulkSelectMode
              ? '[TIME_VIEW_SHORT_CLICK_TOGGLE_SELECTION]'
              : '[TIME_VIEW_SHORT_CLICK_OPEN_EDIT]',
        );
      }
      widget.onBodyTap?.call();
    }
    _resetMoveGesture();
  }

  void _cancelMove(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    widget.onVerticalDragCancel?.call();
    _resetMoveGesture();
  }

  Widget _moveZone() {
    if (!widget.canMove) return const SizedBox.shrink();
    final resizeInset = widget.canResize ? _resizeHandleHeight : 0.0;
    return Positioned(
      top: resizeInset,
      bottom: resizeInset,
      left: widget.controlsLeftInset,
      right: widget.controlsRightInset,
      child: MouseRegion(
        cursor: _bodyDragActive
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _captureMovePointer(event, resizeInset),
          onPointerMove: _updateMove,
          onPointerUp: _finishMove,
          onPointerCancel: _cancelMove,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _resizeEdge({
    required bool isTop,
    required ColorScheme scheme,
  }) {
    return TimelineResizeEdgeHandle(
      isTop: isTop,
      height: _resizeHandleHeight,
      active: _resizing,
      onResizeStart: widget.canResize
          ? () {
              setState(() => _resizing = true);
              if (kDebugMode) {
                debugPrint('[TIME_VIEW_RESIZE_STARTED_FROM_FULL_EDGE]');
              }
              widget.onResizeStart?.call(
                isTop ? TimelineResizeEdge.top : TimelineResizeEdge.bottom,
              );
            }
          : null,
      onResizeUpdate: widget.canResize
          ? (delta, globalDy) {
              widget.onResizeUpdate?.call(delta, globalDy);
            }
          : null,
      onResizeEnd: widget.canResize
          ? () {
              setState(() => _resizing = false);
              widget.onResizeEnd?.call();
            }
          : null,
      onResizeCancel: widget.canResize
          ? () {
              setState(() => _resizing = false);
              widget.onResizeCancel?.call();
            }
          : null,
      scheme: scheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canMove && !widget.canResize) return widget.child;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    _useImmediatePointerDrag =
        planTimeViewUsesImmediatePointerDrag(viewportWidth);
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        _moveZone(),
        if (widget.canResize)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _resizeEdge(isTop: true, scheme: scheme),
          ),
        if (widget.canResize)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _resizeEdge(isTop: false, scheme: scheme),
          ),
      ],
    );
  }
}

class TimelineResizeEdgeHandle extends StatefulWidget {
  const TimelineResizeEdgeHandle({
    required this.isTop,
    required this.height,
    required this.active,
    required this.scheme,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
  });

  final bool isTop;
  final double height;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback? onResizeStart;
  final void Function(double deltaPx, double globalDy)? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResizeCancel;

  @override
  State<TimelineResizeEdgeHandle> createState() =>
      TimelineResizeEdgeHandleState();
}

class TimelineResizeEdgeHandleState extends State<TimelineResizeEdgeHandle> {
  bool _hover = false;
  bool _dragging = false;
  int? _activePointer;
  double _startGlobalDy = 0;

  void _beginResize(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _startGlobalDy = event.position.dy;
    setState(() => _dragging = true);
    widget.onResizeStart?.call();
  }

  void _updateResize(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    widget.onResizeUpdate?.call(
      event.position.dy - _startGlobalDy,
      event.position.dy,
    );
  }

  void _endResize(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    setState(() => _dragging = false);
    widget.onResizeEnd?.call();
  }

  void _cancelResize(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    setState(() => _dragging = false);
    widget.onResizeCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final emphasized = _hover || _dragging || widget.active;
    final gripAlpha = emphasized ? 0.82 : 0.34;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.resizeUpDown,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _beginResize,
        onPointerMove: _updateResize,
        onPointerUp: _endResize,
        onPointerCancel: _cancelResize,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            alignment:
                widget.isTop ? Alignment.topCenter : Alignment.bottomCenter,
            children: [
              AnimatedOpacity(
                opacity: emphasized ? 1 : 0,
                duration: const Duration(milliseconds: 80),
                child: Container(
                  height: 2,
                  width: double.infinity,
                  color: scheme.primary.withValues(alpha: 0.38),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: widget.isTop ? 3 : 0,
                  bottom: widget.isTop ? 0 : 3,
                ),
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: gripAlpha),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
