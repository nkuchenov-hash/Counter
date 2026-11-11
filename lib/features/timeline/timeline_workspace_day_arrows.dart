import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Stationary Timeline day controls anchored to the usable desktop workspace.
///
/// The root overlay is necessary because the scrollable day body is clipped.
/// The arrows sit outside the record frame and outside the permanent sidebar,
/// without changing the PageView constraints or taking pointer gestures from it.
/// This widget never owns timeline data, a scroll controller, or a timer.
class TimelineWorkspaceDayArrows extends StatefulWidget {
  const TimelineWorkspaceDayArrows({
    super.key,
    required this.child,
    required this.visible,
    required this.onStep,
  });

  final Widget child;
  final bool visible;
  final ValueChanged<int> onStep;

  @override
  State<TimelineWorkspaceDayArrows> createState() =>
      _TimelineWorkspaceDayArrowsState();
}

class _TimelineWorkspaceDayArrowsState
    extends State<TimelineWorkspaceDayArrows> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlay.show();
    });
  }

  Widget _arrow(BuildContext context, int step) {
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
        onPressed: () => widget.onStep(step),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, size) {
      return OverlayPortal(
        overlayLocation: OverlayChildLocation.rootOverlay,
        controller: _overlay,
        overlayChildBuilder: (overlayContext) => Positioned.fill(
          child: LayoutBuilder(builder: (_, overlaySize) {
            final fullWidth = overlaySize.maxWidth;
            if (!widget.visible ||
                !shellUsesSideNavigation(fullWidth) ||
                size.maxWidth < 600) {
              return const SizedBox.shrink();
            }
            // The record frame is centered INSIDE the shell workspace.
            // Never count the permanent 272px sidebar as an arrow gutter.
            final render = context.findRenderObject();
            if (render is! RenderBox || !render.hasSize) {
              return const SizedBox.shrink();
            }
            final workspaceLeft = render.localToGlobal(Offset.zero).dx;
            final workspaceRight = workspaceLeft + size.maxWidth;
            final navigationRight = kShellSideNavWidth;
            final readableWidth = shellReadableContentMaxWidth(fullWidth)
                .clamp(0.0, size.maxWidth);
            final frameLeft =
                workspaceLeft + (size.maxWidth - readableWidth) / 2;
            final frameRight = frameLeft + readableWidth;
            final leftSpace = frameLeft - navigationRight;
            final rightSpace = fullWidth - frameRight;
            // Reuse Planning's side-gutter convention while keeping a
            // minimum 48px hit target outside record content when possible.
            final leftCenter = leftSpace >= 72
                ? (navigationRight + frameLeft) / 2
                : workspaceLeft + 28;
            final rightCenter = rightSpace >= 72
                ? (frameRight + fullWidth) / 2
                : workspaceRight - 28;
            return Stack(children: [
              Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.centerLeft,
                  followerAnchor: Alignment.center,
                  offset: Offset(leftCenter - workspaceLeft, 0),
                  child: KeyedSubtree(
                    key: const ValueKey('timeline-side-previous-day'),
                    child: _arrow(overlayContext, -1),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.centerRight,
                  followerAnchor: Alignment.center,
                  offset: Offset(rightCenter - workspaceRight, 0),
                  child: KeyedSubtree(
                    key: const ValueKey('timeline-side-next-day'),
                    child: _arrow(overlayContext, 1),
                  ),
                ),
              ),
            ]);
          }),
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: widget.child,
        ),
      );
    });
  }
}
