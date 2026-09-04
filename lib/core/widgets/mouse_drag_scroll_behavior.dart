import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets [PageView] and other scrollables accept **mouse / trackpad** drags on
/// desktop and web (Flutter defaults to touch-only for drag scrolling).
class MouseDragScrollBehavior extends MaterialScrollBehavior {
  const MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

typedef AppReorderItemBuilder =
    Widget Function(BuildContext context, int index, Widget dragHandle);
typedef AppReorderItemKeyBuilder = Key Function(int index);
typedef AppReorderLabelBuilder = String Function(int index);

/// Canonical vertical reorder surface for app-owned ordered collections.
///
/// The feature owns the item surface. This helper owns the discoverable drag
/// handle and Flutter reorder plumbing so drag behavior stays consistent.
/// Callers must apply local order immediately in [onReorder] and persist it
/// asynchronously. Nested lists reuse this same primitive with [shrinkWrap]
/// and non-scrolling physics instead of introducing feature-local drag code.
class AppReorderableList extends StatelessWidget {
  const AppReorderableList({
    super.key,
    required this.itemCount,
    required this.itemKeyBuilder,
    required this.itemBuilder,
    required this.onReorder,
    required this.dragLabelBuilder,
    this.header,
    this.footer,
    this.padding = EdgeInsets.zero,
    this.spacing = 8,
    this.physics,
    this.primary,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final AppReorderItemKeyBuilder itemKeyBuilder;
  final AppReorderItemBuilder itemBuilder;
  final ReorderCallback onReorder;
  final AppReorderLabelBuilder dragLabelBuilder;
  final Widget? header;
  final Widget? footer;
  final EdgeInsets padding;
  final double spacing;
  final ScrollPhysics? physics;
  final bool? primary;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          key: itemKeyBuilder(index),
          padding: EdgeInsets.only(
            bottom: index == itemCount - 1 ? 0 : spacing,
          ),
          child: itemBuilder(
            context,
            index,
            AppReorderHandle(
              index: index,
              tooltip: dragLabelBuilder(index),
            ),
          ),
        );
      },
      onReorder: onReorder,
      buildDefaultDragHandles: false,
      header: header,
      footer: footer,
      padding: padding,
      physics: physics,
      primary: primary,
      shrinkWrap: shrinkWrap,
    );
  }
}

/// Discoverable drag handle used by [AppReorderableList].
class AppReorderHandle extends StatelessWidget {
  const AppReorderHandle({
    super.key,
    required this.index,
    required this.tooltip,
  });

  final int index;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
