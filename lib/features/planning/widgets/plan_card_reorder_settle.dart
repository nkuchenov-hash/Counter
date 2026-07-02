import 'package:flutter/material.dart';/// One-shot slide settle when a completed card is allowed to reorder.
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
  late final Animation<Offset> _slide;
  bool _wasAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.animate) {
      _wasAnimating = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PlanCardReorderSettle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.animate && widget.animate) {
      _wasAnimating = true;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_wasAnimating && !widget.animate) return widget.child;
    return SlideTransition(position: _slide, child: widget.child);
  }
}
