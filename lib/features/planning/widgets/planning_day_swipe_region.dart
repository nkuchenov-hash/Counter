import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:flutter/material.dart';

/// A real, finger-following horizontal PageView for the Planning day **body**.
///
/// The parent owns the sort bar, tags and quick entry, so they never move.
/// Only the selected day is live. Adjacent pages use read-only cache snapshots;
/// no extra PlanningPage, StreamBuilder or Time View ScrollController is mounted.
class PlanningDaySwipeRegion extends StatefulWidget {
  const PlanningDaySwipeRegion({
    super.key,
    required this.child,
    required this.onDayChange,
    this.adjacentDayBuilder,
    this.dayKey,
    this.enabled = true,
  });

  final Widget child;
  final String? dayKey;
  final bool enabled;
  final ValueChanged<int> onDayChange;
  final Widget Function(BuildContext context, DateTime day)? adjacentDayBuilder;

  @override
  State<PlanningDaySwipeRegion> createState() => PlanningDaySwipeRegionState();
}

class PlanningDaySwipeRegionState extends State<PlanningDaySwipeRegion> {
  static const int _initialPage = 50000;
  static const int _pageCount = 100000;
  static const Duration _programmaticDuration = Duration(milliseconds: 200);
  late final DateTime _anchorDay;
  late final PageController _controller;
  int _committedPage = _initialPage;
  bool _settleCallbackQueued = false;

  DateTime _parseDay(String? key) {
    final parsed = key == null ? null : DateTime.tryParse(key);
    return parsed == null ? DateTime(2026, 11, 10) :
        DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime _dayForPage(int index) =>
      DateTime(_anchorDay.year, _anchorDay.month,
          _anchorDay.day + index - _initialPage);

  int _indexForDay(DateTime day) =>
      (_initialPage +
          DateTime.utc(day.year, day.month, day.day)
              .difference(DateTime.utc(
                  _anchorDay.year, _anchorDay.month, _anchorDay.day))
              .inDays).clamp(0, _pageCount - 1).toInt();

  @override
  void initState() {
    super.initState();
    _anchorDay = _parseDay(widget.dayKey);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant PlanningDaySwipeRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayKey == widget.dayKey) return;
    final target = _indexForDay(_parseDay(widget.dayKey));
    if (target == _committedPage) return;
    // Calendar date picker or external shell navigation. Arrow buttons route
    // through animateToAdjacentDay, so the old live page remains in place
    // during their movement instead of swapping content at animation start.
    _committedPage = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpToPage(target);
    });
  }

  /// Stationary previous/next buttons use the same native pager animation.
  void animateToAdjacentDay(int delta) {
    if (!widget.enabled || !_controller.hasClients || delta == 0) return;
    if (_controller.position.isScrollingNotifier.value) return;
    final from = _controller.page?.round() ?? _committedPage;
    final target = (from + (delta < 0 ? -1 : 1)).clamp(0, _pageCount - 1);
    if (target == from) return;
    _controller.animateToPage(
      target,
      duration: _programmaticDuration,
      curve: Curves.easeOut,
    );
  }

  bool _onPagerNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) return false;
    if (notification is ScrollEndNotification && !_settleCallbackQueued) {
      _settleCallbackQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _settleCallbackQueued = false;
        if (!mounted || !_controller.hasClients) return;
        final next = _controller.page?.round() ?? _committedPage;
        if (next == _committedPage) return;
        final delta = next - _committedPage;
        _committedPage = next;
        // Parent changes only after the physical pager settles. Its active
        // body is never swapped halfway through the user's finger motion.
        widget.onDayChange(delta);
      });
    }
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForDay(_parseDay(widget.dayKey));
    return ScrollConfiguration(
      behavior: const MouseDragScrollBehavior(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onPagerNotification,
        child: PageView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: widget.enabled
              ? const FeatherDateSwipePhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: _pageCount,
          itemBuilder: (context, index) {
            if (index == selectedIndex) {
              return RepaintBoundary(
                key: ValueKey('planning-live-page-$index'),
                child: widget.child,
              );
            }
            return RepaintBoundary(
              key: ValueKey('planning-cache-preview-$index'),
              child: widget.adjacentDayBuilder?.call(
                    context, _dayForPage(index),
                  ) ??
                  const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}
