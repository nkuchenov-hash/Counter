// ---------------------------------------------------------------------------
// CATEGORY / TAG CHIP — global display modes (profiles.tag_display_mode).
// FEATURE-FIRST shared UI. All package imports.
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/shared/tag_contrast.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// **Timeline record category** — text-only breadcrumbs, not a tag chip.
///
/// Hierarchical path (`Parent > Child`). Independent of `profiles.tag_display_mode`.
/// Compact stadium-shaped tint ([accentColor] ~13% opacity), full-strength accent text.
class CategoryBreadcrumb extends StatelessWidget {
  const CategoryBreadcrumb({
    super.key,
    required this.breadcrumbPath,
    required this.accentColor,
  });

  /// e.g. from [DatabaseService.categoryDisplayPathForRecordData] / [DatabaseService.getCategoryPath].
  final String breadcrumbPath;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final localizedPath = localizeCategoryBreadcrumbPath(breadcrumbPath, loc);
    var parts = localizedPath
        .split(RegExp(r'\s*>\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      final f = localizedPath.trim();
      parts = f.isEmpty ? <String>['—'] : <String>[f];
    }

    final scheme = Theme.of(context).colorScheme;
    final plate = tagCategoryBreadcrumbPlate(accentColor, scheme.surface);
    final fg = tagVibrantForeground(accentColor);
    final sepStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: fg.withValues(alpha: 0.58),
      fontWeight: FontWeight.w700,
      fontSize: 11,
      height: 1.15,
    );
    final segStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: fg,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.15,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: plate,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 0,
          runSpacing: 2,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text('>', style: sepStyle),
                ),
              Text(parts[i], style: segStyle),
            ],
          ],
        ),
      ),
    );
  }
}

/// **Planning / task tags only** — follows profile [UserSettings.tagDisplayMode].
///
/// Pill modes ([letterChip], [chip]) size like task-card tags: intrinsic width/height
/// only — **no** forced 44×44 (avoids empty giant tiles in horizontal lists).
/// Glyph modes keep a square tap region so circles/icons stay round.
enum CategoryChipVariant { compactCard, largePicker }

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.mode,
    required this.label,
    required this.color,
    required this.icon,
    this.selected = false,
    this.onTap,

    /// When [onTap] is null (e.g. task card), use true so dot/icon/circle chips
    /// layout at their **visual** size (not 44×44), keeping the glyph left-aligned
    /// with adjacent title text. Tappable strips should leave this false.
    this.compactGlyphLayout = false,
    this.variant = CategoryChipVariant.compactCard,

    /// Edit-sheet pickers keep 44px touch targets but use less tiny visuals.
    this.prominentVisuals = false,

    /// Synthetic “No Tags” strip id ([Tag.tagId] == -1): solid B/W + inverted text.
    /// All other tags (even #000000) use translucent letter-chip styling.
    this.syntheticNoTagsMonochrome = false,
  });

  final CategoryDisplayMode mode;
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool compactGlyphLayout;
  final CategoryChipVariant variant;
  final bool prominentVisuals;
  final bool syntheticNoTagsMonochrome;

  /// Square tap target for dot / raw icon / icon-in-circle only.
  static const double _glyphTapExtent = 44;

  double _glyphLayoutSide(CategoryDisplayMode m) {
    final large =
        variant == CategoryChipVariant.largePicker || prominentVisuals;
    return switch (m) {
      CategoryDisplayMode.round => large ? 22 : _dotDiameter,
      CategoryDisplayMode.icon => large ? 34 : 26,
      CategoryDisplayMode.iconCircle => large ? 42 : _iconCircleDiameter,
      _ => _glyphTapExtent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final large =
        variant == CategoryChipVariant.largePicker || prominentVisuals;
    final displayLabel = localizeCategoryBreadcrumbPath(
      label,
      currentLocale.value,
    );

    final child = switch (mode) {
      CategoryDisplayMode.letterChip => _letterChipPlanStyle(
        context,
        displayLabel,
        syntheticNoTagsMonochrome: syntheticNoTagsMonochrome,
      ),
      CategoryDisplayMode.chip => _chipPlanStyle(context),
      CategoryDisplayMode.round => _tagRoundDot(),
      CategoryDisplayMode.icon => Center(
        child: Icon(
          icon,
          color: selected ? scheme.primary : tagGlyphOnCanvas(color),
          size: large ? 34 : 26,
        ),
      ),
      CategoryDisplayMode.iconCircle => _iconInCircle(),
    };
    final visual = mode != CategoryDisplayMode.letterChip
        ? Tooltip(message: displayLabel, child: child)
        : child;

    final isPillMode =
        mode == CategoryDisplayMode.letterChip ||
        mode == CategoryDisplayMode.chip;
    final glyphSide = _glyphLayoutSide(mode);

    final inner = isPillMode
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                alignment: Alignment.center,
                child: visual,
              ),
            ],
          )
        : AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            alignment: Alignment.center,
            width: glyphSide,
            height: glyphSide,
            child: visual,
          );

    if (onTap == null) {
      // Pill chips on task cards: loose BoxConstraints() would expand to parent width
      // and [alignment: center] would float the chip in the middle — use tight width.
      if (isPillMode) {
        return inner;
      }
      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: glyphSide,
          height: glyphSide,
        ),
        child: inner,
      );
    }

    final tapRadius = isPillMode ? 100.0 : glyphSide / 2;
    final selectedPill = isPillMode && selected
        ? _TagSelectionRing(selected: true, child: inner)
        : inner;
    final tappableChild = isPillMode
        ? selectedPill
        : SizedBox(width: glyphSide, height: glyphSide, child: inner);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tapRadius),
        child: tappableChild,
      ),
    );
  }

  /// Compact card pill footprint (letter_chip on task/list cards).
  static const double compactChipHeight = 22;

  /// Interactive picker pill footprint (edit sheets / menus).
  static const double interactiveChipHeight = 31;

  static const double _compactChipHeight = compactChipHeight;
  static const double _interactiveChipHeight = interactiveChipHeight;

  static const StrutStyle _pillLabelStrut = StrutStyle(
    forceStrutHeight: true,
    height: 1.0,
    leading: 0,
  );

  static const TextHeightBehavior _pillLabelHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  TextStyle? _pillLabelTextStyle(BuildContext context, {required Color color}) {
    final large =
        variant == CategoryChipVariant.largePicker || prominentVisuals;
    return (large
            ? Theme.of(context).textTheme.labelMedium
            : Theme.of(context).textTheme.labelSmall)
        ?.copyWith(fontWeight: FontWeight.w600, height: 1.0, color: color);
  }

  Widget _letterChipPillShell({
    required BuildContext context,
    required String displayLabel,
    required BoxDecoration decoration,
    required Color textColor,
  }) {
    final large =
        variant == CategoryChipVariant.largePicker || prominentVisuals;
    return Container(
      height: large ? _interactiveChipHeight : _compactChipHeight,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 6),
      alignment: Alignment.center,
      decoration: decoration,
      child: Text(
        displayLabel,
        textAlign: TextAlign.center,
        strutStyle: _pillLabelStrut,
        textHeightBehavior: _pillLabelHeightBehavior,
        style: _pillLabelTextStyle(context, color: textColor),
      ),
    );
  }

  /// letter_chip: **same widget pattern** as task-card tag in [planning_view] — padded [Text] in tinted [Container] (tight wrap).
  Widget _letterChipPlanStyle(
    BuildContext context,
    String resolvedLabel, {
    required bool syntheticNoTagsMonochrome,
  }) {
    final displayLabel = resolvedLabel.trim().isNotEmpty
        ? resolvedLabel.trim()
        : '?';
    final scheme = Theme.of(context).colorScheme;
    final rgb = color.toARGB32() & 0xFFFFFF;
    final stadium = BorderRadius.circular(100);
    if (syntheticNoTagsMonochrome && rgb == 0x000000) {
      return _letterChipPillShell(
        context: context,
        displayLabel: displayLabel,
        textColor: Colors.white,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: stadium,
          border: Border.all(color: Colors.black),
        ),
      );
    }
    if (syntheticNoTagsMonochrome && rgb == 0xFFFFFF) {
      return _letterChipPillShell(
        context: context,
        displayLabel: displayLabel,
        textColor: Colors.black,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: stadium,
          border: Border.all(color: Colors.grey.shade400),
        ),
      );
    }
    final plate = tagLetterChipPlate(color, scheme.surface);
    final fg = tagVibrantForeground(color);
    final stroke = tagLetterChipBorder(color, scheme.surface);
    return _letterChipPillShell(
      context: context,
      displayLabel: displayLabel,
      textColor: fg,
      decoration: BoxDecoration(
        color: plate,
        borderRadius: stadium,
        border: Border.all(color: stroke),
      ),
    );
  }

  /// chip: stadium pill; compact on cards, larger in pickers.
  Widget _chipPlanStyle(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final large =
        variant == CategoryChipVariant.largePicker || prominentVisuals;
    return Container(
      height: large ? _interactiveChipHeight : _compactChipHeight,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tagEmptyChipFill(color, surface),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: tagEmptyChipBorderColor(color)),
      ),
    );
  }

  /// Dot: fixed square box so [BoxShape.circle] is never stretched by flex/list layout.
  static const double _dotDiameter = 12;

  Widget _tagRoundDot() {
    final large =
        variant == CategoryChipVariant.largePicker || prominentVisuals;
    return SizedBox(
      width: large ? 22 : _dotDiameter,
      height: large ? 22 : _dotDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: tagVibrantForeground(color), width: 2)
              : null,
        ),
      ),
    );
  }

  static const double _iconCircleDiameter = 32;

  /// Filled circle + icon; explicit square [SizedBox] avoids zero/invisible layout in horizontal lists.
  Widget _iconInCircle() {
    final large =
        variant == CategoryChipVariant.largePicker || prominentVisuals;
    return SizedBox(
      width: large ? 42 : _iconCircleDiameter,
      height: large ? 42 : _iconCircleDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: tagVibrantForeground(color), width: 2)
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            color: tagIconOnFilledTagColor(
              color,
              syntheticNoTags: syntheticNoTagsMonochrome,
            ),
            size: large ? 24 : 18,
          ),
        ),
      ),
    );
  }
}

/// Mouse / trackpad / touch drag for horizontal tag strips (edit sheets, web).
class _TagStripScrollBehavior extends MaterialScrollBehavior {
  const _TagStripScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

/// Horizontal tag picker using [CategoryChip] and live [UserSettings.tagDisplayMode].
class TagQuickPickStrip extends StatefulWidget {
  const TagQuickPickStrip({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
    this.fallbackColor,
    this.variant = CategoryChipVariant.compactCard,
    this.prominentVisuals = false,
    this.externalSelectionRing = false,

    /// When set, the strip uses a horizontal [ReorderableListView]; indices match [tags].
    this.onReorder,

    /// Long-press on a chip (only when [onReorder] is null — avoids clashing with drag).
    this.onTagLongPress,
  });

  final List<Tag> tags;
  final List<Tag> selected;
  final void Function(Tag tag) onToggle;
  final Color? fallbackColor;
  final CategoryChipVariant variant;
  final bool prominentVisuals;
  final bool externalSelectionRing;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(Tag tag)? onTagLongPress;

  @override
  State<TagQuickPickStrip> createState() => _TagQuickPickStripState();
}

class _TagQuickPickStripState extends State<TagQuickPickStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_scrollController.hasClients) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;
    final pos = _scrollController.position;
    if (delta > 0 && pos.pixels >= pos.maxScrollExtent) return;
    if (delta < 0 && pos.pixels <= pos.minScrollExtent) return;
    final next = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (next != pos.pixels) {
      _scrollController.jumpTo(next);
    }
  }

  Widget _wrapScrollSurface(Widget child) {
    return ScrollConfiguration(
      behavior: const _TagStripScrollBehavior(),
      child: Listener(onPointerSignal: _onPointerSignal, child: child),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required CategoryDisplayMode mode,
    required Tag tag,
    required Color fb,
    required bool isSel,
    void Function(Tag tag)? onLongPress,
  }) {
    final c = parseTagHexColor(tag.color) ?? fb;
    final ic = iconForTagKey(tag.icon);
    final baseChip = CategoryChip(
      mode: mode,
      label: tag.name,
      color: c,
      icon: ic,
      selected: widget.externalSelectionRing ? false : isSel,
      variant: widget.variant,
      prominentVisuals: widget.prominentVisuals,
      syntheticNoTagsMonochrome: tag.tagId == -1,
      onTap: () => widget.onToggle(tag),
    );
    Widget chip = widget.externalSelectionRing
        ? _TagSelectionRing(selected: isSel, child: baseChip)
        : baseChip;
    final lp = onLongPress;
    if (lp != null) {
      chip = GestureDetector(
        onLongPress: () => lp(tag),
        behavior: HitTestBehavior.opaque,
        child: chip,
      );
    }
    return Align(alignment: Alignment.center, child: chip);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fb = widget.fallbackColor ?? scheme.primary;

    return StreamBuilder<UserSettings>(
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, snap) {
        final mode =
            snap.data?.tagDisplayMode ?? CategoryDisplayMode.letterChip;
        final reorder = widget.onReorder;
        if (reorder != null && widget.tags.length >= 2) {
          return _wrapScrollSurface(
            ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              scrollController: _scrollController,
              buildDefaultDragHandles: false,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              itemCount: widget.tags.length,
              onReorder: reorder,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final v = Curves.easeInOut.transform(animation.value);
                    return Material(
                      elevation: 6 * v,
                      shadowColor: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (ctx, i) {
                final tag = widget.tags[i];
                final isSel = widget.selected.any((x) => x.tagId == tag.tagId);
                final chip = _buildChip(
                  context,
                  mode: mode,
                  tag: tag,
                  fb: fb,
                  isSel: isSel,
                );
                return ReorderableDelayedDragStartListener(
                  key: ValueKey<String>(
                    tag.pbRecordId?.trim().isNotEmpty == true
                        ? 'pb-${tag.pbRecordId}'
                        : 'biz-${tag.tagId}',
                  ),
                  index: i,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      chip,
                      if (i < widget.tags.length - 1) const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          );
        }
        return _wrapScrollSurface(
          ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            clipBehavior: Clip.hardEdge,
            itemCount: widget.tags.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final tag = widget.tags[i];
              final isSel = widget.selected.any((x) => x.tagId == tag.tagId);
              return _buildChip(
                context,
                mode: mode,
                tag: tag,
                fb: fb,
                isSel: isSel,
                onLongPress: widget.onTagLongPress,
              );
            },
          ),
        );
      },
    );
  }
}

class _TagSelectionRing extends StatelessWidget {
  const _TagSelectionRing({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) return child;
    final ring = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: ring, width: 2),
          ),
          child: Padding(padding: const EdgeInsets.all(4), child: child),
        ),
      ],
    );
  }
}
