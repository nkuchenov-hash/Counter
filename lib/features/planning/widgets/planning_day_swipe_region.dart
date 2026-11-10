import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/l10n/dictionary.dart';
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
  bool _dayCommitQueued = false;
  int? _pendingDayIndex;

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
    _pendingDayIndex = null;
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

  /// Commit from the native PageView's page-center transition, rather than
  /// keeping the new day in an IgnorePointer preview until animation ends.
  /// Updating the shell after this frame makes the winning day interactive
  /// immediately, using its already-cached Planning snapshot.
  void _queueLiveDayCommit(int index) {
    _pendingDayIndex = index;
    if (_dayCommitQueued) return;
    _dayCommitQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dayCommitQueued = false;
      if (!mounted || !_controller.hasClients) return;
      final next = _pendingDayIndex;
      _pendingDayIndex = null;
      if (next == null || next == _committedPage) return;
      // A fast swipe can cross and reverse within the same frame; commit the
      // actual page selected by PageView, not an obsolete target.
      final physical = _controller.page?.round() ?? next;
      if (physical != next) {
        _queueLiveDayCommit(physical);
        return;
      }
      final delta = next - _committedPage;
      _committedPage = next;
      widget.onDayChange(delta);
    });
  }

  bool _onPagerNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) return false;
    if (notification is ScrollEndNotification) {
      // Fallback for tiny velocity-driven gestures that settle to a new page
      // without delivering an intermediate onPageChanged frame.
      _queueLiveDayCommit(_controller.page?.round() ?? _committedPage);
    }
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _sideDayButton(BuildContext context, int step) {
    final scheme = Theme.of(context).colorScheme;
    final previous = step < 0;
    return Material(
      color: scheme.surface,
      elevation: 1,
      shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: AppIconButton(
        icon: previous
            ? Icons.chevron_left_rounded
            : Icons.chevron_right_rounded,
        tooltip: t(
          currentLocale.value,
          previous ? 'date_previous_day' : 'date_next_day',
        ),
        size: AppIconButtonSize.l,
        onPressed: () => animateToAdjacentDay(step),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForDay(_parseDay(widget.dayKey));
    return LayoutBuilder(builder: (context, size) {
      // The arrows are stationary at the outer edges of the day body.
      // Overlay them rather than shrinking cards or moving them into chrome.
      final showSideArrows = widget.enabled && size.maxWidth >= 900;
      final arrowTop = (size.maxHeight - 48).clamp(0.0, double.infinity) / 2;
      return Stack(
        fit: StackFit.expand,
        children: [
          ScrollConfiguration(
            behavior: const MouseDragScrollBehavior(),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onPagerNotification,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: _queueLiveDayCommit,
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
                  return IgnorePointer(
                    child: TickerMode(
                      enabled: false,
                      child: RepaintBoundary(
                        key: ValueKey('planning-cache-preview-$index'),
                        child: widget.adjacentDayBuilder?.call(
                              context, _dayForPage(index),
                            ) ??
                            const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (showSideArrows) ...[
            Positioned(
              key: const ValueKey('planning-side-previous-day'),
              left: 4,
              top: arrowTop,
              child: _sideDayButton(context, -1),
            ),
            Positioned(
              key: const ValueKey('planning-side-next-day'),
              right: 4,
              top: arrowTop,
              child: _sideDayButton(context, 1),
            ),
          ],
        ],
      );
    });
  }
}
