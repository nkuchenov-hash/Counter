import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Visual interaction phase for a card that behaves like a physical object.
enum AppPhysicalCardPhase { idle, dragging, resizing }

/// Shared spring for card lift, release, resize, and reorder settling.
///
/// The spring is deliberately fast and well damped: cards feel tangible without
/// continuing to move after their exact application position has been resolved.
const SpringDescription kAppPhysicalCardSpring = SpringDescription(
  mass: 1,
  stiffness: 420,
  damping: 32,
);

const double kAppPhysicalCardMaxTiltRadians = 0.012;
const double kAppPhysicalCardVelocityForMaxTilt = 1800;

/// Maps pointer velocity to a restrained card tilt.
///
/// This affects presentation only. Drag geometry and saved positions remain
/// controlled by the owning feature.
double appPhysicalCardTiltForVelocity(double verticalVelocity) {
  if (!verticalVelocity.isFinite) return 0;
  final normalized =
      (verticalVelocity / kAppPhysicalCardVelocityForMaxTilt).clamp(-1.0, 1.0);
  return normalized * kAppPhysicalCardMaxTiltRadians;
}

double appPhysicalCardScaleX(
  AppPhysicalCardPhase phase,
  double progress,
) {
  final p = progress.clamp(0.0, 1.0);
  return switch (phase) {
    AppPhysicalCardPhase.idle => 1,
    AppPhysicalCardPhase.dragging => 1 + (0.018 * p),
    AppPhysicalCardPhase.resizing => 1 - (0.006 * p),
  };
}

double appPhysicalCardScaleY(
  AppPhysicalCardPhase phase,
  double progress,
) {
  final p = progress.clamp(0.0, 1.0);
  return switch (phase) {
    AppPhysicalCardPhase.idle => 1,
    AppPhysicalCardPhase.dragging => 1 + (0.018 * p),
    AppPhysicalCardPhase.resizing => 1 + (0.002 * p),
  };
}

/// Stateless visual transform used by drag proxies and fixed-progress previews.
class AppPhysicalDragVisual extends StatelessWidget {
  const AppPhysicalDragVisual({
    super.key,
    required this.phase,
    required this.progress,
    required this.child,
    this.verticalVelocity = 0,
    this.resizeAlignment = Alignment.center,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final AppPhysicalCardPhase phase;
  final double progress;
  final double verticalVelocity;
  final AlignmentGeometry resizeAlignment;
  final BorderRadiusGeometry borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final p = progress.clamp(0.0, 1.08);
    final effectiveP = reduceMotion ? (p > 0 ? 1.0 : 0.0) : p;
    final alignment = phase == AppPhysicalCardPhase.resizing
        ? resizeAlignment
        : Alignment.center;
    final tilt = reduceMotion || phase != AppPhysicalCardPhase.dragging
        ? 0.0
        : appPhysicalCardTiltForVelocity(verticalVelocity) * effectiveP;
    final scaleX = reduceMotion
        ? 1.0
        : appPhysicalCardScaleX(phase, effectiveP);
    final scaleY = reduceMotion
        ? 1.0
        : appPhysicalCardScaleY(phase, effectiveP);
    final shadowColor = Theme.of(context).shadowColor.withValues(
          alpha: 0.18 * effectiveP.clamp(0.0, 1.0),
        );

    return RepaintBoundary(
      child: Transform.rotate(
        angle: tilt,
        alignment: alignment,
        transformHitTests: false,
        child: Transform.scale(
          scaleX: scaleX,
          scaleY: scaleY,
          alignment: alignment,
          transformHitTests: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: effectiveP <= 0.001
                  ? const []
                  : [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 18 * effectiveP,
                        spreadRadius: -1.5 * effectiveP,
                        offset: Offset(0, 7 * effectiveP),
                      ),
                    ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Spring-driven physical wrapper for a live drag or resize interaction.
///
/// Position remains owned by the caller. This widget only supplies lift,
/// restrained velocity tilt, resize resistance, shadow, and release settling.
class AppPhysicalDragSurface extends StatefulWidget {
  const AppPhysicalDragSurface({
    super.key,
    required this.phase,
    required this.child,
    this.verticalVelocity = 0,
    this.resizeAlignment = Alignment.center,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final AppPhysicalCardPhase phase;
  final double verticalVelocity;
  final AlignmentGeometry resizeAlignment;
  final BorderRadiusGeometry borderRadius;
  final Widget child;

  @override
  State<AppPhysicalDragSurface> createState() =>
      _AppPhysicalDragSurfaceState();
}

class _AppPhysicalDragSurfaceState extends State<AppPhysicalDragSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _liftController;
  late AppPhysicalCardPhase _lastActivePhase;
  late double _lastVelocity;
  late AlignmentGeometry _lastResizeAlignment;

  bool get _isActive => widget.phase != AppPhysicalCardPhase.idle;

  @override
  void initState() {
    super.initState();
    _lastActivePhase = _isActive
        ? widget.phase
        : AppPhysicalCardPhase.dragging;
    _lastVelocity = widget.verticalVelocity;
    _lastResizeAlignment = widget.resizeAlignment;
    _liftController = AnimationController.unbounded(
      vsync: this,
      value: _isActive ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant AppPhysicalDragSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive) {
      _lastActivePhase = widget.phase;
      _lastVelocity = widget.verticalVelocity;
      _lastResizeAlignment = widget.resizeAlignment;
    }
    final wasActive = oldWidget.phase != AppPhysicalCardPhase.idle;
    if (wasActive != _isActive) {
      _animateLiftTo(_isActive ? 1 : 0);
    }
  }

  void _animateLiftTo(double target) {
    _liftController.animateWith(
      SpringSimulation(
        kAppPhysicalCardSpring,
        _liftController.value,
        target,
        0,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _liftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _liftController,
      child: widget.child,
      builder: (context, child) {
        return AppPhysicalDragVisual(
          phase: _lastActivePhase,
          progress: _liftController.value,
          verticalVelocity: _lastVelocity,
          resizeAlignment: _lastResizeAlignment,
          borderRadius: widget.borderRadius,
          child: child!,
        );
      },
    );
  }
}
