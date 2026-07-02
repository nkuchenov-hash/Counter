import 'dart:math' as math;import 'package:counter/features/planning/plan_time_gesture_contract.dart';import 'package:counter/features/planning/time_view/time_view_drag_state.dart';import 'package:flutter/foundation.dart';import 'package:flutter/material.dart';import 'package:flutter/services.dart';/// Invisible move/resize gesture zones for proportional timeline plan blocks.
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

  bool get _immediateBodyDrag =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  double get _dragThresholdPx => planTimeViewDragMovementThresholdPx();

  double get _resizeZoneInset {
    final h = widget.blockHeightPx ?? widget.resizeHandlePx * 2;
    if (h < 48) {
      return math.max(6.0, (h - 6) / 2);
    }
    return widget.resizeHandlePx;
  }

  void _resetMoveGesture() {
    _gesturePhase = TimelinePointerGesturePhase.idle;
    _bodyDragActive = false;
    _moveAccumulatedDy = 0;
    _pointerDownGlobal = null;
    _activePointer = null;
  }

  void _maybeStartDragFromPending() {
    if (_gesturePhase != TimelinePointerGesturePhase.tapCandidate) return;
    if (_bodyDragActive) return;
    _gesturePhase = TimelinePointerGesturePhase.draggingMove;
    _bodyDragActive = true;
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
        if (moved >= _dragThresholdPx) {
          _maybeStartDragFromPending();
        }
      }
    }
    if (!_bodyDragActive) return;
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
    final inset = widget.canResize ? _resizeZoneInset : 0.0;
    final zone = Positioned(
      top: inset,
      bottom: inset,
      left: widget.controlsLeftInset,
      right: widget.controlsRightInset,
      child: MouseRegion(
        cursor: _bodyDragActive
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: _immediateBodyDrag
            ? Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  _resetMoveGesture();
                  _gesturePhase = TimelinePointerGesturePhase.tapCandidate;
                  _pendingGrabOffsetCanvasPx = inset + e.localPosition.dy;
                  _pointerDownGlobal = e.position;
                  _activePointer = e.pointer;
                },
                onPointerMove: (e) {
                  if (_activePointer != e.pointer) return;
                  _onPointerMoveUpdate(e.position, e.delta.dy);
                },
                onPointerUp: (e) {
                  if (_activePointer != e.pointer) return;
                  _finishPointerGesture();
                },
                onPointerCancel: (e) {
                  if (_activePointer != e.pointer) return;
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
                  _pendingGrabOffsetCanvasPx =
                      inset + details.localPosition.dy;
                  _pointerDownGlobal = details.globalPosition;
                },
                onLongPressMoveUpdate: (details) {
                  if (_gesturePhase == TimelinePointerGesturePhase.tapCandidate) {
                    final down = _pointerDownGlobal;
                    if (down != null &&
                        (details.globalPosition - down).distance >=
                            _dragThresholdPx) {
                      _maybeStartDragFromPending();
                    }
                  }
                  if (!_bodyDragActive) return;
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
                onLongPressCancel: () {
                  _cancelPointerGesture();
                },
                child: const SizedBox.expand(),
              ),
      ),
    );
    return zone;
  }

  Widget _resizeEdge({
    required bool isTop,
    required ColorScheme scheme,
  }) {
    return TimelineResizeEdgeHandle(
      isTop: isTop,
      height: _resizeZoneInset,
      active: _resizing || widget.isInteracting,
      onResizeStart: widget.canResize
          ? () {
              setState(() {
                _resizing = true;
              });
              if (kDebugMode) {
                debugPrint('[TIME_VIEW_RESIZE_STARTED_FROM_ZONE]');
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
            child: _resizeEdge(isTop: true, scheme: scheme),
          ),
        if (widget.canResize)
          Positioned(
            bottom: 0,
            left: widget.controlsLeftInset,
            right: widget.controlsRightInset,
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
  double _accumulatedDy = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final showHairline = _hover || _dragging;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) {
          _accumulatedDy = 0;
          setState(() => _dragging = true);
          widget.onResizeStart?.call();
        },
        onVerticalDragUpdate: (details) {
          _accumulatedDy += details.delta.dy;
          widget.onResizeUpdate?.call(
            _accumulatedDy,
            details.globalPosition.dy,
          );
        },
        onVerticalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onResizeEnd?.call();
        },
        onVerticalDragCancel: () {
          setState(() => _dragging = false);
          widget.onResizeCancel?.call();
        },
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: showHairline
              ? Stack(
                  alignment: widget.isTop
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  children: [
                    Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: widget.isTop ? 4 : 0,
                        bottom: widget.isTop ? 0 : 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}
