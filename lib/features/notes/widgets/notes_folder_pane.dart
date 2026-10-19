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
    return dark
        ? Color.alphaBlend(const Color(0xFF285B99).withValues(alpha: 0.25), scheme.surface)
        : const Color(0xFFE3ECF8);
  }
  final accent = DatabaseService.instance.getCategoryRuleById(categoryId)?.colorOrDefault;
  if (accent == null) return scheme.surface;
  // Real folder paper: the selected spine and the page use one saturated
  // category surface, not a nearly-white tint that hides the active color.
  return Color.alphaBlend(
    accent.withValues(alpha: dark ? 0.68 : 0.82),
    dark ? scheme.surface : Colors.white,
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
  });

  final int id;
  final String label;
  final IconData icon;
  final Color paper;
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

  static const double height = 50;
  static const double _overlap = 30;

  final List<NotesFolderTabData> tabs;
  final int? selectedId;
  final ScrollController scrollController;
  final String allLabel;
  final Color allPaper;
  final ValueChanged<int?> onSelect;
  final VoidCallback onAdd;
  final VoidCallback? onManage;

  static double tabWidth(String label) =>
      (label.runes.length * 9.0 + 92).clamp(132.0, 248.0).toDouble();

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
      selected: selectedId == null,
      width: 114,
      onTap: () => onSelect(null),
    );
    final addTab = _PhysicalNotesTab(
      key: const ValueKey('notes-tab-add'),
      label: '',
      icon: Icons.add_rounded,
      paper: dark ? const Color(0xFF34363C) : const Color(0xFF17191D),
      selected: false,
      width: 58,
      compact: true,
      onTap: onAdd,
      onLongPress: onManage,
    );

    // Selected tab is painted last so its leading edge stays in front of
    // neighboring folder tabs, matching the real overlapping folder silhouette.
    final offsets = <double>[];
    var trackWidth = 0.0;
    for (final tab in tabs) {
      offsets.add(trackWidth);
      trackWidth += tabWidth(tab.label) - _overlap;
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
          selected: tab.id == selectedId,
          width: tabWidth(tab.label),
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
    final slope = (rect.width * 0.32).clamp(19.0, 43.0).toDouble();
    return Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top + 13)
      ..quadraticBezierTo(left, top, left + 14, top)
      ..lineTo(right - slope - 7, top)
      ..cubicTo(
        right - slope + 5, top,
        right - slope + 11, top + 11,
        right - slope + 17, top + 23,
      )
      ..quadraticBezierTo(right - 8, bottom, right, bottom)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55FFFFFF),
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
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color paper;
  final bool selected;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = compact
        ? paper
        : (selected ? paper : Color.lerp(paper, scheme.surface, dark ? 0.20 : 0.12)!);
    final foreground = compact
        ? Colors.white
        : ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
            ? Colors.white
            : const Color(0xFF171717);
    return SizedBox(
      width: width,
      height: NotesFolderTabStrip.height,
      child: Material(
        color: Colors.transparent,
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
              left: compact ? 12 : 12,
              right: compact ? 20 : 36,
            ),
            decoration: BoxDecoration(color: fill),
            child: compact
                ? Icon(icon, color: foreground, size: 21)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: foreground),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.0,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: foreground,
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
