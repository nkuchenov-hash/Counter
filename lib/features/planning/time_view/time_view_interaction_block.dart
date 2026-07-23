import 'dart:math' as math;

import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Move and resize gesture zones for proportional timeline plan blocks.
///
/// Moving owns the whole card body. Resizing is available only from the two
/// explicit centered grips so the gestures never compete for the same pointer.
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
  TimelinePointerGesturePhase _gesturePhase = TimelinePointerGesturePhase.idle;
  double _pendingGrabOffsetCanvasPx = 0;
  Offset? _pointerDownGlobal;
  double? _lastVelocityGlobalDy;
  int _lastVelocityMicros = 0;
  double _smoothedVerticalVelocity = 0;

  /// Cached from last [build] — phone-width shell uses APK touch thresholds.
  double _viewportDragThreshold = kPlanTimeDragThresholdTouchPx;
  bool _useImmediatePointerDrag = false;

  double get _resizeHandleHeight {
    final h = widget.blockHeightPx ?? widget.resizeHandlePx * 2;
    final preferred = _useImmediatePointerDrag
        ? math.min(widget.resizeHandlePx, 14.0)
        : math.max(widget.resizeHandlePx, 20.0);
    final maxHeight = math.max(8.0, (h - 8.0) / 2);
    return preferred.clamp(8.0, maxHeight).toDouble();
  }

  double get _resizeHandleWidth =>
      _useImmediatePointerDrag ? 64.0 : 88.0;

  void _resetMoveGesture() {
    _gesturePhase = TimelinePointerGesturePhase.idle;
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

  void _maybeStartDragFromPending() {
    if (_gesturePhase != TimelinePointerGesturePhase.tapCandidate) return;
    if (_bodyDragActive) return;
    _gesturePhase = TimelinePointerGesturePhase.draggingMove;
    _bodyDragActive = true;
    _startVelocityTracking();
    if (kDebugMode) {
      debugPrint('[TIME_VIEW_DRAG_STARTED_AFTER_THRESHOLD]');
    }
    widget.onMovePointerDown?.call();
    widget.onVerticalDragStart?.call(_pendingGrabOffsetCanvasPx);
  }

  void _onPointerMoveUpdate(Offset globalPosition, double deltaDy) {
    if (_gesturePhase == TimelinePointerGesturePhase.tapCandidate) {
      final down = _pointerDownGlobal;
      if (down != null) {
        final moved = (globalPosition - down).distance;
        if (moved >= _viewportDragThreshold) {
          _maybeStartDragFromPending();
        }
      }
    }
    if (!_bodyDragActive) return;
    _trackVerticalVelocity(globalPosition.dy);
    _moveAccumulatedDy += deltaDy;
    widget.onVerticalDragUpdate?.call(
      _moveAccumulatedDy,
      globalPosition.dy,
    );
  }

  void _finishPointerGesture() {
    if (_gesturePhase == TimelinePointerGesturePhase.tapCandidate) {
      if (widget.bulkSelectMode) {
        if (kDebugMode) {
          debugPrint('[TIME_VIEW_BULK_TOGGLE_SELECTION]');
        }
      } else if (kDebugMode) {
        debugPrint('[TIME_VIEW_TAP_OPEN_EDIT]');
      }
      widget.onBodyTap?.call();
      _resetMoveGesture();
      return;
    }
    if (_bodyDragActive) {
      widget.onVerticalDragEnd?.call();
    }
    _resetMoveGesture();
  }

  void _cancelPointerGesture() {
    if (_bodyDragActive) {
      widget.onVerticalDragCancel?.call();
    }
    _resetMoveGesture();
  }

  Widget _moveZone() {
    if (!widget.canMove) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      bottom: 0,
      left: widget.controlsLeftInset,
      right: widget.controlsRightInset,
      child: MouseRegion(
        cursor: _bodyDragActive
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: _useImmediatePointerDrag
            ? Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  _resetMoveGesture();
                  _gesturePhase = TimelinePointerGesturePhase.tapCandidate;
                  _pendingGrabOffsetCanvasPx = event.localPosition.dy;
                  _pointerDownGlobal = event.position;
                  _activePointer = event.pointer;
                },
                onPointerMove: (event) {
                  if (_activePointer != event.pointer) return;
                  _onPointerMoveUpdate(event.position, event.delta.dy);
                },
                onPointerUp: (event) {
                  if (_activePointer != event.pointer) return;
                  _finishPointerGesture();
                },
                onPointerCancel: (event) {
                  if (_activePointer != event.pointer) return;
                  _cancelPointerGesture();
                },
                child: const SizedBox.expand(),
              )
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onBodyTap,
                onLongPressStart: (details) {
                  _resetMoveGesture();
                  _gesturePhase = TimelinePointerGesturePhase.tapCandidate;
                  _pendingGrabOffsetCanvasPx = details.localPosition.dy;
                  _pointerDownGlobal = details.globalPosition;
                },
                onLongPressMoveUpdate: (details) {
                  if (_gesturePhase ==
                      TimelinePointerGesturePhase.tapCandidate) {
                    final down = _pointerDownGlobal;
                    if (down != null &&
                        (details.globalPosition - down).distance >=
                            _viewportDragThreshold) {
                      _maybeStartDragFromPending();
                    }
                  }
                  if (!_bodyDragActive) return;
                  _trackVerticalVelocity(details.globalPosition.dy);
                  widget.onVerticalDragUpdate?.call(
                    details.offsetFromOrigin.dy,
                    details.globalPosition.dy,
                  );
                },
                onLongPressEnd: (_) {
                  if (_bodyDragActive) {
                    widget.onVerticalDragEnd?.call();
                  }
                  _resetMoveGesture();
                },
                onLongPressCancel: _cancelPointerGesture,
                child: const SizedBox.expand(),
              ),
      ),
    );
  }

  Widget _resizeEdge({
    required bool isTop,
    required ColorScheme scheme,
  }) {
    return SizedBox(
      width: _resizeHandleWidth,
      child: TimelineResizeEdgeHandle(
        isTop: isTop,
        height: _resizeHandleHeight,
        active: _resizing,
        onResizeStart: widget.canResize
            ? () {
                setState(() => _resizing = true);
                if (kDebugMode) {
                  debugPrint('[TIME_VIEW_RESIZE_STARTED_FROM_GRIP]');
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canMove && !widget.canResize) return widget.child;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    _viewportDragThreshold =
        planTimeViewDragMovementThresholdForViewport(viewportWidth);
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
            left: widget.controlsLeftInset,
            right: widget.controlsRightInset,
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: _resizeEdge(isTop: true, scheme: scheme),
            ),
          ),
        if (widget.canResize)
          Positioned(
            bottom: 0,
            left: widget.controlsLeftInset,
            right: widget.controlsRightInset,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: _resizeEdge(isTop: false, scheme: scheme),
            ),
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
                duration: const Duration(milliseconds: 90),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: widget.isTop ? 4 : 0,
                  bottom: widget.isTop ? 0 : 4,
                ),
                child: Container(
                  width: 30,
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
