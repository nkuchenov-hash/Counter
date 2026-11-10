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
  // Date controls live in the root overlay so they remain tappable outside
  // the constrained Planning canvas, without expanding its hit region.
  final LayerLink _sideArrowsLink = LayerLink();
  final OverlayPortalController _sideArrowsOverlay = OverlayPortalController()..show();

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
    // The root Overlay can be mounted after this region's first frame.
    // Re-issue show once it is attached so the controls never stay hidden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sideArrowsOverlay.show();
    });
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
        onPressed: widget.enabled ? () => animateToAdjacentDay(step) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForDay(_parseDay(widget.dayKey));
    return LayoutBuilder(builder: (context, size) {
      // On desktop, controls belong in the empty *outer gutters*, not at
      // card edges. A sidebar can reduce the pane below 900px; the relevant
      // minimum is the actual 600px Planning pane, not its former breakpoint.
      return OverlayPortal(
        overlayLocation: OverlayChildLocation.rootOverlay,
        controller: _sideArrowsOverlay,
        overlayChildBuilder: (overlayContext) {
          return Positioned.fill(
            child: LayoutBuilder(builder: (overlayContext, overlaySize) {
              // Check the real root overlay width. Test and embedded surfaces
              // may have a MediaQuery width different from their render view.
              final viewportWidth = overlaySize.maxWidth;
              if (viewportWidth < 900 || size.maxWidth < 600) {
                return const SizedBox.shrink();
              }
          // The target's global X position is computed once per layout.
          // CompositedTransformFollower then tracks it in the compositor,
          // with no per-scroll rebuild and no extra active Planning pages.
          final render = context.findRenderObject();
          final leftGutter = render is RenderBox && render.hasSize
              ? render.localToGlobal(Offset.zero).dx.clamp(0.0, viewportWidth)
              : 0.0;
          final rightGutter =
              (viewportWidth - leftGutter - size.maxWidth)
                  .clamp(0.0, viewportWidth);
          // Center each arrow in available whitespace. On constrained panes
          // with no gutter, keep the 48px hit target inside its viewport.
          final leftOffset =
              leftGutter >= 72 ? -leftGutter / 2 : 28.0;
          final rightOffset =
              rightGutter >= 72 ? rightGutter / 2 : -28.0;
          return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: CompositedTransformFollower(
                    link: _sideArrowsLink,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.centerLeft,
                    followerAnchor: Alignment.center,
                    offset: Offset(leftOffset, 0),
                    child: KeyedSubtree(
                      key: const ValueKey('planning-side-previous-day'),
                      child: _sideDayButton(overlayContext, -1),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: CompositedTransformFollower(
                    link: _sideArrowsLink,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.centerRight,
                    followerAnchor: Alignment.center,
                    offset: Offset(rightOffset, 0),
                    child: KeyedSubtree(
                      key: const ValueKey('planning-side-next-day'),
                      child: _sideDayButton(overlayContext, 1),
                    ),
                  ),
                ),
              ],
          );
            }),
          );
        },
        child: CompositedTransformTarget(
          link: _sideArrowsLink,
          child: ScrollConfiguration(
            behavior: const MouseDragScrollBehavior(),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onPagerNotification,
              child: PageView.builder(
                controller: _controller,
                // Native viewport cache prepares both complete neighboring
                // pages while idle; the finger then moves already-rendered
                // PlanCards rather than constructing a whole Time View mid-drag.
                // No second live Planning stream or remote fetch is created.
                allowImplicitScrolling: true,
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
        ),
      );
    });
  }
}
