import 'package:counter/core/widgets/day_window.dart';
import 'package:flutter/material.dart';

typedef EagerDayItemBuilder =
    Widget Function(
      BuildContext context,
      DateTime date,
      int index,
      bool isActive,
    );

/// Horizontal strip of eagerly mounted day bodies (Row, not lazy PageView).
class EagerDayContentStripController {
  ScrollController? _scrollController;
  double _viewportWidth = 0;

  void _attach(ScrollController controller, double viewportWidth) {
    _scrollController = controller;
    _viewportWidth = viewportWidth;
  }

  void _detach() {
    _scrollController = null;
    _viewportWidth = 0;
  }

  bool get hasClients => _scrollController?.hasClients ?? false;

  double? get pageFraction {
    final c = _scrollController;
    if (c == null || !c.hasClients || _viewportWidth <= 0) return null;
    return c.offset / _viewportWidth;
  }

  int get settledIndex {
    final c = _scrollController;
    if (c == null || !c.hasClients || _viewportWidth <= 0) return 0;
    return (c.offset / _viewportWidth).round();
  }

  void jumpToIndex(int index) {
    final c = _scrollController;
    if (c == null || !c.hasClients || _viewportWidth <= 0) return;
    c.jumpTo(index * _viewportWidth);
  }

  Future<void> animateToIndex(
    int index, {
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeOut,
  }) async {
    final c = _scrollController;
    if (c == null || !c.hasClients || _viewportWidth <= 0) return;
    await c.animateTo(
      index * _viewportWidth,
      duration: duration,
      curve: curve,
    );
  }

  void shiftByPages(int delta) {
    final c = _scrollController;
    if (c == null || !c.hasClients || _viewportWidth <= 0) return;
    c.jumpTo(c.offset + delta * _viewportWidth);
  }

  void jumpToDate(DateTime date, DayWindow window) {
    jumpToIndex(window.indexOf(date));
  }

  Future<void> animateToDate(
    DateTime date,
    DayWindow window, {
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeOut,
  }) {
    return animateToIndex(window.indexOf(date), duration: duration, curve: curve);
  }
}

class EagerDayContentStrip extends StatefulWidget {
  const EagerDayContentStrip({
    super.key,
    required this.screen,
    required this.dates,
    required this.initialIndex,
    required this.activeIndex,
    required this.itemBuilder,
    required this.onIndexChanged,
    this.controller,
    this.physics = const PageScrollPhysics(),
    this.scrollLocked = false,
    this.onUserDragStart,
    this.onUserDragEnd,
    this.onScrollTick,
    this.canRevealDate,
    this.onRevealBlocked,
  });

  final String screen;
  final List<DateTime> dates;
  final int initialIndex;
  final int activeIndex;
  final EagerDayItemBuilder itemBuilder;
  final void Function(int index, DateTime date) onIndexChanged;
  final EagerDayContentStripController? controller;
  final ScrollPhysics physics;
  final bool scrollLocked;
  final VoidCallback? onUserDragStart;
  final VoidCallback? onUserDragEnd;
  final void Function(double pageFraction)? onScrollTick;
  /// P0T: block settling on dates that are not FULL_READY.
  final bool Function(DateTime date)? canRevealDate;
  final void Function(DateTime date)? onRevealBlocked;

  @override
  State<EagerDayContentStrip> createState() => _EagerDayContentStripState();
}

class _EagerDayContentStripState extends State<EagerDayContentStrip> {
  late ScrollController _scrollController;
  bool _didInitialJump = false;
  int? _lastSettledIndex;
  double _viewportWidth = 0;
  double _lastAttachedWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollTick);
    widget.controller?._attach(_scrollController, 0);
  }

  @override
  void didUpdateWidget(covariant EagerDayContentStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dates.length != widget.dates.length &&
        oldWidget.dates.isNotEmpty &&
        widget.dates.isNotEmpty) {
      final oldFrom = oldWidget.dates.first;
      final newFrom = widget.dates.first;
      final delta = oldFrom.difference(newFrom).inDays;
      if (delta > 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.controller?.shiftByPages(delta);
        });
      }
    }
    if (oldWidget.activeIndex != widget.activeIndex &&
        _scrollController.hasClients) {
      final target = widget.activeIndex * _viewportWidth;
      if ((_scrollController.offset - target).abs() > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.controller?.jumpToIndex(widget.activeIndex);
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollTick);
    widget.controller?._detach();
    _scrollController.dispose();
    super.dispose();
  }

  void _attachControllerIfNeeded(double width) {
    if (width <= 0) return;
    _viewportWidth = width;
    if ((width - _lastAttachedWidth).abs() > 0.5) {
      _lastAttachedWidth = width;
      widget.controller?._attach(_scrollController, width);
    }
  }

  void _onScrollTick() {
    if (!_scrollController.hasClients || _viewportWidth <= 0) return;
    widget.onScrollTick?.call(_scrollController.offset / _viewportWidth);
  }

  void _maybeInitialJump(double width) {
    if (_didInitialJump || width <= 0) return;
    _didInitialJump = true;
    _attachControllerIfNeeded(width);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller?.jumpToIndex(widget.initialIndex);
      _lastSettledIndex = widget.initialIndex;
    });
  }

  int _settledIndexFromOffset() {
    if (!_scrollController.hasClients || _viewportWidth <= 0) {
      return widget.initialIndex;
    }
    return (_scrollController.offset / _viewportWidth).round().clamp(
      0,
      widget.dates.length - 1,
    );
  }

  bool _handleScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      widget.onUserDragStart?.call();
    }
    if (n is ScrollEndNotification) {
      widget.onUserDragEnd?.call();
      if (widget.dates.isEmpty) return false;
      final idx = _settledIndexFromOffset();
      if (idx < 0 || idx >= widget.dates.length) return false;
      final date = widget.dates[idx];
      final canReveal = widget.canRevealDate?.call(date) ?? true;
      if (!canReveal) {
        final revert = _lastSettledIndex ?? widget.activeIndex;
        widget.onRevealBlocked?.call(date);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.controller?.animateToIndex(revert);
        });
        return false;
      }
      if (_lastSettledIndex != idx) {
        _lastSettledIndex = idx;
        widget.onIndexChanged(idx, date);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        _maybeInitialJump(width);
        _attachControllerIfNeeded(width);
        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: widget.scrollLocked
                ? const NeverScrollableScrollPhysics()
                : widget.physics,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.dates.length; i++)
                  SizedBox(
                    width: width,
                    height: height,
                    child: _MountedDaySlot(
                      screen: widget.screen,
                      date: widget.dates[i],
                      child: widget.itemBuilder(
                        context,
                        widget.dates[i],
                        i,
                        i == widget.activeIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MountedDaySlot extends StatefulWidget {
  const _MountedDaySlot({
    required this.screen,
    required this.date,
    required this.child,
  });

  final String screen;
  final DateTime date;
  final Widget child;

  @override
  State<_MountedDaySlot> createState() => _MountedDaySlotState();
}

class _MountedDaySlotState extends State<_MountedDaySlot> {
  @override
  Widget build(BuildContext context) => widget.child;
}
