// ---------------------------------------------------------------------------
// CATEGORY / TAG CHIP — global display modes (profiles.tag_display_mode).
// FEATURE-FIRST shared UI. All package imports.
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/shared/tag_contrast.dart';
import 'package:flutter/material.dart';

/// **Timeline record category** — text-only breadcrumbs, not a tag chip.
///
/// Hierarchical path (`Parent > Child`). Independent of `profiles.tag_display_mode`.
/// Compact stadium-shaped tint ([accentColor] ~13% opacity), full-strength accent text.
class RecordCategoryHeader extends StatelessWidget {
  const RecordCategoryHeader({
    super.key,
    required this.breadcrumbPath,
    required this.accentColor,
  });

  /// e.g. from [DatabaseService.categoryDisplayPathForRecordData] / [DatabaseService.getCategoryPath].
  final String breadcrumbPath;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    var parts = breadcrumbPath
        .split(RegExp(r'\s*>\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      final f = breadcrumbPath.trim();
      parts = f.isEmpty ? <String>['—'] : <String>[f];
    }

    final scheme = Theme.of(context).colorScheme;
    final plate =
        tagRecordCategoryHeaderPlate(accentColor, scheme.surface);
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
  });

  final CategoryDisplayMode mode;
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool compactGlyphLayout;

  /// Square tap target for dot / raw icon / icon-in-circle only.
  static const double _glyphTapExtent = 44;

  double _glyphLayoutSide(CategoryDisplayMode m) {
    return switch (m) {
      CategoryDisplayMode.round => _dotDiameter,
      CategoryDisplayMode.icon => 26,
      CategoryDisplayMode.iconCircle => _iconCircleDiameter,
      _ => _glyphTapExtent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = selected ? scheme.primary : Colors.transparent;

    final child = switch (mode) {
      CategoryDisplayMode.letterChip => _letterChipPlanStyle(context),
      CategoryDisplayMode.chip => _chipPlanStyle(context),
      CategoryDisplayMode.round => _tagRoundDot(),
      CategoryDisplayMode.icon => Center(
          child: Icon(
            icon,
            color: tagGlyphOnCanvas(color),
            size: 26,
          ),
        ),
      CategoryDisplayMode.iconCircle => _iconInCircle(),
    };
    final visual = mode != CategoryDisplayMode.letterChip
        ? Tooltip(message: label, child: child)
        : child;

    final isPillMode =
        mode == CategoryDisplayMode.letterChip || mode == CategoryDisplayMode.chip;
    final glyphCompact =
        compactGlyphLayout && onTap == null && !isPillMode;
    final glyphSide = glyphCompact ? _glyphLayoutSide(mode) : _glyphTapExtent;

    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      alignment: isPillMode ? Alignment.centerLeft : Alignment.center,
      width: isPillMode ? null : glyphSide,
      height: isPillMode ? null : glyphSide,
      padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: selected
          ? BoxDecoration(
              borderRadius: isPillMode
                  ? BorderRadius.circular(10)
                  : BorderRadius.circular(22),
              border: Border.all(color: ring, width: 2),
            )
          : null,
      child: visual,
    );

    final BoxConstraints constraints = isPillMode
        ? const BoxConstraints()
        : BoxConstraints.tightFor(
            width: glyphSide,
            height: glyphSide,
          );

    if (onTap == null) {
      // Pill chips on task cards: loose BoxConstraints() would expand to parent width
      // and [alignment: center] would float the chip in the middle — use tight width.
      if (isPillMode) {
        return inner;
      }
      return ConstrainedBox(
        constraints: constraints,
        child: inner,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            isPillMode ? BorderRadius.circular(10) : BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: constraints,
          child: inner,
        ),
      ),
    );
  }

  /// Fixed outer size for empty pill — approx. typical [labelSmall] text chip (short label, 8+2 padding).
  static const double _emptyChipWidth = 72;
  static const double _emptyChipHeight = 24;

  /// letter_chip: **same widget pattern** as task-card tag in [planning_view] — padded [Text] in tinted [Container] (tight wrap).
  Widget _letterChipPlanStyle(BuildContext context) {
    final displayLabel = label.trim().isNotEmpty ? label.trim() : '?';
    final scheme = Theme.of(context).colorScheme;
    final plate = tagLetterChipPlate(color, scheme.surface);
    final fg = tagVibrantForeground(color);
    final stroke = tagLetterChipBorder(color, scheme.surface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: plate,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stroke),
      ),
      child: Text(
        displayLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: fg,
            ),
      ),
    );
  }

  /// chip: fixed horizontal stadium — **not** intrinsic/flexible; matches a compact text-chip footprint.
  Widget _chipPlanStyle(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: _emptyChipWidth,
      height: _emptyChipHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tagEmptyChipFill(color, surface),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tagEmptyChipBorderColor(color)),
        ),
      ),
    );
  }

  /// Dot: fixed square box so [BoxShape.circle] is never stretched by flex/list layout.
  static const double _dotDiameter = 12;

  Widget _tagRoundDot() {
    return SizedBox(
      width: _dotDiameter,
      height: _dotDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  static const double _iconCircleDiameter = 32;

  /// Filled circle + icon; explicit square [SizedBox] avoids zero/invisible layout in horizontal lists.
  Widget _iconInCircle() {
    return SizedBox(
      width: _iconCircleDiameter,
      height: _iconCircleDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            color: tagIconOnFilledTagColor(color),
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Horizontal tag picker using [CategoryChip] and live [UserSettings.tagDisplayMode].
class TagQuickPickStrip extends StatelessWidget {
  const TagQuickPickStrip({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
    this.fallbackColor,
    /// When set, the strip uses a horizontal [ReorderableListView]; indices match [tags].
    this.onReorder,
  });

  final List<Tag> tags;
  final List<Tag> selected;
  final void Function(Tag tag) onToggle;
  final Color? fallbackColor;
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fb = fallbackColor ?? scheme.primary;

    return StreamBuilder<UserSettings>(
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, snap) {
        final mode = snap.data?.tagDisplayMode ?? CategoryDisplayMode.letterChip;
        final reorder = onReorder;
        if (reorder != null && tags.length >= 2) {
          return ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: tags.length,
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
              final tag = tags[i];
              final c = parseTagHexColor(tag.color) ?? fb;
              final ic = iconForTagKey(tag.icon);
              final isSel = selected.any((x) => x.tagId == tag.tagId);
              final chip = CategoryChip(
                mode: mode,
                label: tag.name,
                color: c,
                icon: ic,
                selected: isSel,
                onTap: () => onToggle(tag),
              );
              return ReorderableDragStartListener(
                key: ValueKey<String>(
                  tag.pbRecordId?.trim().isNotEmpty == true
                      ? 'pb-${tag.pbRecordId}'
                      : 'biz-${tag.tagId}',
                ),
                index: i,
                child: Padding(
                  padding: EdgeInsets.only(right: i < tags.length - 1 ? 8 : 0),
                  child: chip,
                ),
              );
            },
          );
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tags.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final tag = tags[i];
            final c = parseTagHexColor(tag.color) ?? fb;
            final ic = iconForTagKey(tag.icon);
            final isSel = selected.any((x) => x.tagId == tag.tagId);
            return CategoryChip(
              mode: mode,
              label: tag.name,
              color: c,
              icon: ic,
              selected: isSel,
              onTap: () => onToggle(tag),
            );
          },
        );
      },
    );
  }
}
