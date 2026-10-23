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
  });

  final int? categoryId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey('notes-folder-paper'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: notesFolderPaper(context, categoryId),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
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
      icon: Icons.format_list_bulleted_rounded,
      paper: allPaper,
      accent: const Color(0xFF8591A3),
      selected: selectedId == null,
      width: 90,
      onTap: () => onSelect(null),
    );
    final addTab = _PhysicalNotesTab(
      key: const ValueKey('notes-tab-add'),
      label: '',
      icon: Icons.add_rounded,
      paper: dark ? const Color(0xFF34373D) : const Color(0xFFF0F2F5),
      accent: const Color(0xFF748092),
      selected: false,
      width: 46,
      compact: true,
      onTap: onAdd,
      onLongPress: onManage,
    );

    // Selected tab is painted last so its leading edge stays in front of
    // neighboring folder tabs, matching the real overlapping folder silhouette.
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

    final selectedIndex = tabs.indexWhere((tab) => tab.id == selectedId);
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
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            if (i != selectedIndex) categoryAt(i),
                          if (selectedIndex >= 0) categoryAt(selectedIndex),
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
            child: addTab,
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
    // Highlights on the raised lip, plus a restrained contact shadow where
    // the right shoulder tucks under the next index divider.
    final width = rect.width;
    final slope = (width * 0.14).clamp(14.0, 21.0).toDouble();
    final outer = getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..color = const Color(0x7AFFFFFF),
    );
    final shoulder = Path()
      ..moveTo(rect.right - slope - 5, rect.top + 1)
      ..cubicTo(
        rect.right - slope + 4, rect.top + 2,
        rect.right - slope + 9, rect.top + 14,
        rect.right - 1, rect.bottom - 1,
      );
    canvas.drawPath(
      shoulder,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x380D233E),
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}

class _PhysicalNotesTab extends StatelessWidget {
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
  final IconData icon;
  final Color paper;
  final Color? accent;
  final bool selected;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = accent ?? scheme.onSurfaceVariant;
    final fill = compact
        ? paper
        : (selected ? paper
            : Color.lerp(paper, accentColor, dark ? 0.22 : 0.17)!);
    // Fine bevel at the top, same paper at the selected spine's bottom.
    final topFill = compact ? fill
        : Color.lerp(fill, accentColor, selected ? 0.17 : 0.08)!;
    final foreground = ThemeData.estimateBrightnessForColor(fill) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF202630);
    return SizedBox(
      width: width,
      height: selected ? NotesFolderTabStrip.height : NotesFolderTabStrip.height - 3,
      child: Material(
        color: Colors.transparent,
        elevation: selected ? 3.0 : 1.8,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.28 : 0.22),
        shape: const NotesPhysicalFolderShape(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: const NotesPhysicalFolderShape(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(
              left: compact ? 11 : 10,
              right: compact ? 14 : 23,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topFill, fill],
              ),
            ),
            child: compact
                ? Icon(icon, color: foreground, size: 21)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: foreground.withValues(alpha: 0.82)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Tooltip(
                          message: label,
                          waitDuration: const Duration(milliseconds: 450),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: NotesFolderTabStrip.labelStyle.copyWith(
                              fontWeight: selected
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
    );
  }
}
