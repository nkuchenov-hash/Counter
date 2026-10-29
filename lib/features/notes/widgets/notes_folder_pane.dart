import 'package:counter/data/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// A single folder-paper surface shared by the active tab and Notes contents.
/// The tab sits flush on top; the 18px inset belongs INSIDE the folder, so the
/// note cards are visually separated without breaking the tab-to-paper seam.
Color notesFolderPaper(BuildContext context, int? categoryId) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (categoryId == null) {
    return dark ? scheme.surfaceContainerLow : const Color(0xFFF2F4F7);
  }
  final accent = DatabaseService.instance.getCategoryRuleById(categoryId)?.colorOrDefault;
  if (accent == null) return scheme.surface;
  // Restrained category tint, same as the selected spine's lower edge.
  return Color.alphaBlend(
    accent.withValues(alpha: dark ? 0.22 : 0.15),
    dark ? scheme.surface : const Color(0xFFF9FAFB),
  );
}

class NotesFolderPane extends StatelessWidget {
  const NotesFolderPane({
    super.key,
    required this.categoryId,
    required this.child,
    this.edgeToEdge = false,
  });

  final int? categoryId;
  final Widget child;
  /// Mobile notes use the folder tint as a full-bleed section background.
  final bool edgeToEdge;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey('notes-folder-paper'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: notesFolderPaper(context, categoryId),
        borderRadius: edgeToEdge
            ? BorderRadius.zero
            : const BorderRadius.only(
                topRight: Radius.circular(15),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: edgeToEdge
          ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
          : const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: child,
    );
  }
}

/// Presentation-only folder tab. Data lookup and persistence remain in Lists.
class NotesFolderTabData {
  const NotesFolderTabData({
    required this.id,
    required this.label,
    required this.icon,
    required this.paper,
    this.accent,
  });

  final int id;
  final String label;
  final IconData icon;
  final Color paper;
  final Color? accent;
}

/// All | horizontally scrollable physical category tabs | add.
/// The two edge controls never participate in category scrolling.
class NotesFolderTabStrip extends StatelessWidget {
  const NotesFolderTabStrip({
    super.key,
    required this.tabs,
    required this.selectedId,
    required this.scrollController,
    required this.allLabel,
    required this.allPaper,
    required this.onSelect,
    required this.onAdd,
    this.onManage,
  });

  static const double height = 38;
  static const double _overlap = 15;

  final List<NotesFolderTabData> tabs;
  final int? selectedId;
  final ScrollController scrollController;
  final String allLabel;
  final Color allPaper;
  final ValueChanged<int?> onSelect;
  final VoidCallback onAdd;
  final VoidCallback? onManage;

  // Folder rail alone uses compact typography: filenames should remain readable,
  // not truncated to a few letters to pack more tabs into the viewport.
  static const TextStyle labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.05,
  );

  /// Measure the actual displayed glyph widths. Cyrillic and Latin letters
  /// have different advances, so a rune-count formula clips real category names.
  /// Unusually long labels receive the full title in a hover/hold tooltip.
  static double tabWidth(
    String label, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final contentWidth = painter.width;
    painter.dispose();
    // 56px for icon + padding + shoulder; an extra 10px prevents narrow
    // fallback fonts / fractional glyph rounding from cutting the last letter.
    // The maximum is only a safety bound for exceptionally long titles.
    return (contentWidth + 66).clamp(90.0, 460.0).toDouble();
  }

  void _scrollWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !scrollController.hasClients) return;
    // Horizontal trackpads already scroll natively. Map a normal mouse wheel
    // to the horizontal middle rail, never to the page or fixed end tabs.
    if (event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()) return;
    final position = scrollController.position;
    final next = (position.pixels + event.scrollDelta.dy)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (next != position.pixels) scrollController.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final allTab = _PhysicalNotesTab(
      key: const ValueKey('notes-tab-all'),
      label: allLabel,
      icon: null,
      paper: allPaper,
      accent: const Color(0xFF8591A3),
      selected: selectedId == null,
      width: 68,
      onTap: () => onSelect(null),
    );
    final addTab = _PhysicalNotesTab(
      key: const ValueKey('notes-tab-add'),
      label: '',
      icon: Icons.add_rounded,
      paper: const Color(0xFF111827),
      accent: Colors.white,
      selected: false,
      width: 46,
      compact: true,
      onTap: onAdd,
      onLongPress: onManage,
    );

    // Keep the underlying order stable; the selected folder paints above
    // its neighbors instead of disappearing under the previous spine.
    final textScaler = MediaQuery.textScalerOf(context);
    final widths = [
      for (final tab in tabs) tabWidth(tab.label, textScaler: textScaler),
    ];
    final offsets = <double>[];
    var trackWidth = 0.0;
    for (final width in widths) {
      offsets.add(trackWidth);
      trackWidth += width - _overlap;
    }
    if (tabs.isNotEmpty) trackWidth += _overlap;

    Widget categoryAt(int index) {
      final tab = tabs[index];
      return Positioned(
        left: offsets[index],
        bottom: 0,
        child: _PhysicalNotesTab(
          key: ValueKey('notes-tab-${tab.id}'),
          label: tab.label,
          icon: tab.icon,
          paper: tab.paper,
          accent: tab.accent,
          selected: tab.id == selectedId,
          width: widths[index],
          onTap: () => onSelect(tab.id),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(label: allLabel, button: true, child: allTab),
          Expanded(
            child: ClipRect(
              child: Listener(
                onPointerSignal: _scrollWheel,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    scrollbars: false,
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('notes-category-scroller'),
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      height: height,
                      width: trackWidth,
                      child: Stack(
                        key: const ValueKey('notes-layered-tab-stack'),
                        clipBehavior: Clip.none,
                        children: [
                          // Inactive folders preserve right-to-left overlap.
                          // Paint the active tab LAST so both its shoulders
                          // cover neighboring spines without reordering data.
                          for (var i = tabs.length - 1; i >= 0; i--)
                            if (tabs[i].id != selectedId) categoryAt(i),
                          for (var i = 0; i < tabs.length; i++)
                            if (tabs[i].id == selectedId) categoryAt(i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: 'Add folder',
            button: true,
            child: SizedBox(
              width: 34,
              height: height,
              child: OverflowBox(
                minWidth: 46,
                maxWidth: 46,
                minHeight: 35,
                maxHeight: 35,
                alignment: Alignment.bottomRight,
                // The fixed + tab is the ONE exception to the normal folder
                // z-order: painted last and overlapping the scrolling rail.
                child: addTab,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folder spine: rounded top-left shoulder, long top edge and a curved
/// diagonal right side that widens toward the paper below. Not a pill.
class NotesPhysicalFolderShape extends ShapeBorder {
  const NotesPhysicalFolderShape();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;
    // Short, softly sloped trailing shoulder, not a broad trapezoid.
    final slope = (rect.width * 0.14).clamp(14.0, 21.0).toDouble();
    return Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top + 9)
      ..quadraticBezierTo(left, top, left + 9, top)
      ..lineTo(right - slope - 5, top)
      ..cubicTo(
        right - slope + 2, top,
        right - slope + 5, top + 5,
        right - slope + 8, top + 12,
      )
      ..quadraticBezierTo(right - 5, bottom, right, bottom)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final slope = (rect.width * 0.14).clamp(14.0, 21.0).toDouble();
    // No painted white leading/top glint: it reads as a disconnected stripe
    // on mobile. The overlapping shoulder carries the folder depth instead.
    // Fine contact seam STARTS BELOW the upper corner; the preceding folder
    // overlaps this tab and casts a little paper-edge shade down the curve.
    final trailingEdge = Path()
      ..moveTo(rect.right - slope + 8, rect.top + 11)
      ..quadraticBezierTo(
        rect.right - 6, rect.bottom - 5,
        rect.right - 1, rect.bottom - 1,
      );
    canvas.drawPath(
      trailingEdge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0x220E2034)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
    canvas.drawPath(
      trailingEdge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x260E2034),
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// A real hover state is available on every tab: All, categories and Add.
class _PhysicalNotesTab extends StatefulWidget {
  const _PhysicalNotesTab({
    super.key,
    required this.label,
    required this.icon,
    required this.paper,
    required this.selected,
    required this.width,
    this.accent,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color paper;
  final Color? accent;
  final bool selected;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  State<_PhysicalNotesTab> createState() => _PhysicalNotesTabState();
}

class _PhysicalNotesTabState extends State<_PhysicalNotesTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.accent ?? scheme.onSurfaceVariant;
    final baseFill = widget.compact
        ? widget.paper
        : (widget.selected
            ? widget.paper
            : Color.lerp(
                widget.paper, accentColor, dark ? 0.22 : 0.17,
              )!);
    // All tab types respond to hover, including the selected and fixed tabs.
    // Keep the selected color anchored to the folder paper when idle.
    final fill = _hovered
        ? Color.lerp(baseFill, dark ? Colors.white : scheme.onSurface,
            dark ? 0.12 : 0.075)!
        : baseFill;
    final topFill = widget.compact
        ? fill
        : Color.lerp(fill, Colors.white, dark ? 0.04 : 0.07)!;
    final foreground = ThemeData.estimateBrightnessForColor(fill) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF202630);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: SizedBox(
        width: widget.width,
        height: widget.selected
            ? NotesFolderTabStrip.height
            : NotesFolderTabStrip.height - (_hovered ? 1 : 3),
        child: Material(
          color: Colors.transparent,
          elevation: _hovered ? 0.46 : (widget.selected ? 0.35 : 0.15),
          shadowColor: Colors.black.withValues(
            alpha: dark ? 0.10 : (widget.selected ? 0.14 : 0.05),
          ),
          shape: const NotesPhysicalFolderShape(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            customBorder: const NotesPhysicalFolderShape(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(
                left: widget.compact ? 11 : 10,
                right: widget.compact ? 14 : 23,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topFill, fill],
                ),
              ),
              child: widget.compact
                  ? Icon(widget.icon!, color: foreground, size: 21)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon!, size: 16,
                              color: foreground.withValues(alpha: 0.82)),
                          const SizedBox(width: 7),
                        ],
                        Expanded(
                          child: Tooltip(
                            message: widget.label,
                            waitDuration: const Duration(milliseconds: 450),
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: NotesFolderTabStrip.labelStyle.copyWith(
                                fontWeight: widget.selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: foreground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
