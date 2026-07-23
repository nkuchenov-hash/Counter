import 'package:counter/core/widgets/life_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// One-shot spring settle when a card is allowed to move to its new order.
class PlanCardReorderSettle extends StatefulWidget {
  const PlanCardReorderSettle({
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<PlanCardReorderSettle> createState() => PlanCardReorderSettleState();
}

class PlanCardReorderSettleState extends State<PlanCardReorderSettle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _wasAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1);
    if (widget.animate) {
      _wasAnimating = true;
      _startSettle();
    }
  }

  @override
  void didUpdateWidget(covariant PlanCardReorderSettle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.animate && widget.animate) {
      _wasAnimating = true;
      _startSettle();
    }
  }

  void _startSettle() {
    _controller.value = 0;
    _controller.animateWith(
      SpringSimulation(
        kAppPhysicalCardSpring,
        0,
        1,
        0,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_wasAnimating && !widget.animate) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value.clamp(0.0, 1.0).toDouble();
        final remaining = 1 - progress;
        return Transform.translate(
          offset: Offset(0, -4 * remaining),
          transformHitTests: false,
          child: Transform.scale(
            scale: 1 + (0.008 * remaining),
            transformHitTests: false,
            child: child,
          ),
        );
      },
    );
  }
}
