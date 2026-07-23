import 'package:counter/core/app_colors.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/shared/categories/visibility/category_visibility_prefs.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

String categoryTileLabel(CategoryRule r) {
  final loc = currentLocale.value;
  final fromMap = r.localizedNames?[loc] ?? r.localizedNames?['en'];
  final s = (fromMap != null && fromMap.trim().isNotEmpty)
      ? fromMap.trim()
      : r.name;
  return localizeCategoryDbSegment(s.trim(), loc);
}

/// Target columns per depth: roots 3, children 4, deeper 5 (drives responsive tile size).
int categoryGridTargetColumns(int depth) {
  if (depth <= 0) return 3;
  if (depth == 1) return 4;
  return 5;
}

const double kCategoryGridGap = 8;
const double kCategoryScrollPeekFraction = 0.17;
const double kCategoryTileWidthClampMin = 48;

/// Cap tile side on large viewports so grids stay compact (@DATA_MAP grid tiers).
double categoryMaxTileSideForViewport(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1100) return 104;
  if (w >= 800) return 112;
  if (w >= 900) return 118;
  if (w >= 700) return 124;
  return 560;
}

/// Grid: exactly [N] full squares per row — `N*w + (N-1)*g == availableWidth`.
double categoryCalculateTileWidthGrid(
  int depth,
  double availableWidth,
  double maxSide,
) {
  final n = categoryGridTargetColumns(depth);
  if (availableWidth <= 0 || n <= 0) return kCategoryTileWidthClampMin;
  final raw = (availableWidth - (n - 1) * kCategoryGridGap) / n;
  return raw.clamp(kCategoryTileWidthClampMin, maxSide);
}

/// Scroll: viewport shows [N] full tiles + [k] of the next — `V = w*(N+k) + (N-1)*g`.
double categoryCalculateTileWidthScroll(
  int depth,
  double availableWidth,
  double maxSide,
) {
  final n = categoryGridTargetColumns(depth);
  if (availableWidth <= 0 || n <= 0) return kCategoryTileWidthClampMin;
  final denom = n + kCategoryScrollPeekFraction;
  final raw = (availableWidth - (n - 1) * kCategoryGridGap) / denom;
  return raw.clamp(kCategoryTileWidthClampMin, maxSide);
}

/// Nominal reference [side] per depth tier (for scaling type/icons when [side] comes from math).
double categoryReferenceTileSideForDepth(int depth) {
  if (depth <= 0) return 120;
  if (depth == 1) return 96;
  return 82;
}

/// Per-depth icon / type / padding; [side] comes from grid math (square tile).
class CategoryDepthLayout {
  const CategoryDepthLayout({
    required this.side,
    required this.iconBrowse,
    required this.iconEdit,
    required this.gearIconSize,
    required this.fontSize,
    required this.fontWeight,
    required this.contentPadding,
    required this.borderRadius,
    required this.elevation,
    required this.addGlyphSize,
  });

  final double side;
  final double iconBrowse;
  final double iconEdit;
  final double gearIconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final double contentPadding;
  final double borderRadius;
  final double elevation;
  final double addGlyphSize;

  static CategoryDepthLayout forDepthAndSide(int depth, double side) {
    final ref = categoryReferenceTileSideForDepth(depth);
    final scale = (side / ref).clamp(0.55, 1.55);
    if (depth <= 0) {
      return CategoryDepthLayout(
        side: side,
        iconBrowse: 36 * scale,
        iconEdit: 30 * scale,
        gearIconSize: 22 * scale,
        fontSize: (15 * scale).clamp(11.0, 20.0),
        fontWeight: FontWeight.bold,
        contentPadding: (8 * scale).clamp(3.0, 12.0),
        borderRadius: (12 * scale).clamp(6.0, 14.0),
        elevation: 0.5,
        addGlyphSize: 28 * scale,
      );
    }
    if (depth == 1) {
      return CategoryDepthLayout(
        side: side,
        iconBrowse: 28 * scale,
        iconEdit: 24 * scale,
        gearIconSize: 20 * scale,
        fontSize: (12 * scale).clamp(9.0, 16.0),
        fontWeight: FontWeight.w600,
        contentPadding: (6 * scale).clamp(3.0, 10.0),
        borderRadius: (10 * scale).clamp(6.0, 12.0),
        elevation: 0.45,
        addGlyphSize: 24 * scale,
      );
    }
    return CategoryDepthLayout(
      side: side,
      iconBrowse: 22 * scale,
      iconEdit: 19 * scale,
      gearIconSize: 18 * scale,
      fontSize: (10.5 * scale).clamp(8.0, 14.0),
      fontWeight: FontWeight.w500,
      contentPadding: (4 * scale).clamp(2.0, 8.0),
      borderRadius: (8 * scale).clamp(5.0, 11.0),
      elevation: 0.4,
      addGlyphSize: 20 * scale,
    );
  }
}

const double kCategoryStaggerIndentPerDepth = 16;
const double kCategoryBandScreenMarginH = 16;
const double kCategoryStripeInnerPadAfterBorder = 10;

/// Semi-transparent category tint over surface (“glass”).
const double kCategoryGlassAlpha = 0.175;
const double kCategoryGlassAlphaSelected = 0.22;
const double kCategoryGroupStripeWidth = 6;

enum CategoryBandLayout {
  /// Horizontal list: tile side from `N` full + 17% peek.
  horizontalPeek,

  /// Multi-row wrap: `N` tiles per row from grid math (strict 8pt gap).
  wrapGrid,
}

/// One band of category tiles at a given tree [depth].
class CategoryRowWidget extends StatelessWidget {
  const CategoryRowWidget({
    super.key,
    required this.items,
    required this.depth,
    required this.immediateParentId,
    required this.selectedId,
    required this.onSelect,
    required this.onFullSettingsTap,
    required this.onAppearanceTap,
    required this.onLongPressOpenEditor,
    this.onReorder,
    this.onAddTap,
    this.showAdd = false,
    this.editMode = false,
    this.layout = CategoryBandLayout.wrapGrid,
    this.onToggleCategoryVisibility,
  });

  final List<CategoryRule> items;
  final int depth;

  /// Local id of the parent category for this band (null for roots) — stripe inherits [color_value].
  final int? immediateParentId;
  final int? selectedId;
  final void Function(int? id) onSelect;
  final void Function(CategoryRule r) onFullSettingsTap;
  final void Function(CategoryRule r) onAppearanceTap;
  final void Function(CategoryRule r) onLongPressOpenEditor;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback? onAddTap;
  final bool showAdd;
  final bool editMode;
  final CategoryBandLayout layout;

  /// Edit mode: eye toggles [CategoryVisibilityPrefs] (client-side quarantine).
  final void Function(int categoryId)? onToggleCategoryVisibility;

  /// Single category cell: glass fill; fixed [layout.side]×[layout.side] square (no stretch).
  static Widget _buildCategoryTile({
    required BuildContext context,
    required CategoryRule r,
    required int depth,
    required bool isSelected,
    required bool editMode,
    required CategoryDepthLayout layout,
    required void Function(int? id) onSelect,
    required void Function(CategoryRule r) onLongPressOpenEditor,
    required void Function(CategoryRule r) onFullSettingsTap,
    required void Function(CategoryRule r) onAppearanceTap,
    VoidCallback? onVisibilityToggle,
    bool isQuarantined = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = r.colorOrDefault;
    final label = categoryTileLabel(r);
    final isDefault = r.id == DatabaseService.instance.defaultCategoryId;
    final loc = currentLocale.value;
    final glassAlpha = isSelected
        ? kCategoryGlassAlphaSelected
        : kCategoryGlassAlpha;
    final fill = Color.alphaBlend(
      color.withValues(alpha: glassAlpha),
      scheme.surface,
    );

    final minTap = (layout.side * 0.42).clamp(
      32.0,
      44.0,
    ); // scales down on 70px tiles

    final labelStyle = textTheme.titleSmall?.copyWith(
      fontSize: layout.fontSize,
      fontWeight: layout.fontWeight,
      height: 1.15,
      color: textTheme.bodyLarge?.color,
      decoration: (editMode && isQuarantined)
          ? TextDecoration.lineThrough
          : null,
      decorationColor: scheme.onSurfaceVariant,
    );

    final iconWidget = Icon(
      r.iconOrDefault,
      size: editMode ? layout.iconEdit : layout.iconBrowse,
      color: color,
    );

    final iconHitTarget = editMode
        ? InkWell(
            onTap: () => onAppearanceTap(r),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: minTap,
              height: minTap,
              child: Center(child: iconWidget),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: iconWidget,
          );

    final gear = editMode
        ? IconButton(
            icon: const Icon(Icons.settings_rounded),
            iconSize: layout.gearIconSize,
            style: IconButton.styleFrom(
              minimumSize: Size(minTap, minTap),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => onFullSettingsTap(r),
            tooltip: t(loc, 'edit_keywords'),
          )
        : null;

    final visibilityBtn = editMode && onVisibilityToggle != null
        ? IconButton(
            icon: Icon(
              isQuarantined
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            iconSize: layout.gearIconSize,
            style: IconButton.styleFrom(
              minimumSize: Size(minTap, minTap),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
            onPressed: onVisibilityToggle,
            tooltip: t(loc, 'category_visibility_toggle'),
          )
        : null;

    final radius = layout.borderRadius;

    Widget tileCore = SizedBox(
      width: layout.side,
      height: layout.side,
      child: Material(
        elevation: layout.elevation,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: color.withValues(alpha: isSelected ? 0.45 : 0.28),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(isSelected ? null : r.id),
          onLongPress: () => onLongPressOpenEditor(r),
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: EdgeInsets.all(layout.contentPadding),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (editMode && gear != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          iconHitTarget,
                          ?visibilityBtn,
                          gear,
                        ],
                      ),
                    )
                  else
                    iconHitTarget,
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                  if (isDefault && editMode)
                    Text(
                      t(loc, 'default_label'),
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: (layout.fontSize * 0.65).clamp(8.0, 11.0),
                        color: scheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (editMode && onVisibilityToggle != null && isQuarantined) {
      tileCore = Opacity(opacity: 0.55, child: tileCore);
    }
    return tileCore;
  }

  Widget _addTile(BuildContext context, CategoryDepthLayout layout) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final neutral = scheme.outline.withValues(alpha: 0.35);
    final fill = Color.alphaBlend(
      neutral.withValues(alpha: 0.12),
      scheme.surface,
    );
    final tileLabelStyle = textTheme.titleSmall?.copyWith(
      fontSize: layout.fontSize,
      fontWeight: layout.fontWeight,
      color: scheme.onSurfaceVariant,
    );
    final r = layout.borderRadius;

    return SizedBox(
      width: layout.side,
      height: layout.side,
      child: Material(
        elevation: layout.elevation * 0.5,
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: BorderSide(color: neutral.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAddTap,
          borderRadius: BorderRadius.circular(r),
          child: Padding(
            padding: EdgeInsets.all(layout.contentPadding),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: layout.addGlyphSize,
                    color: scheme.outline,
                  ),
                  Text(
                    t(currentLocale.value, 'add'),
                    style: tileLabelStyle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bandGap = kCategoryGridGap;

    /// LayoutBuilder [maxWidth] is the band’s content width **after** stripe + standard L/R margin.
    final bandMath = Padding(
      padding: const EdgeInsets.fromLTRB(
        kCategoryBandScreenMarginH,
        6,
        kCategoryBandScreenMarginH,
        6,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final avail = c.maxWidth;
          final maxSide = categoryMaxTileSideForViewport(context);
          final side = layout == CategoryBandLayout.horizontalPeek
              ? categoryCalculateTileWidthScroll(depth, avail, maxSide)
              : categoryCalculateTileWidthGrid(depth, avail, maxSide);
          final dLayout = CategoryDepthLayout.forDepthAndSide(depth, side);

          Widget cell(CategoryRule r) {
            final isSelected = selectedId == r.id;
            final quarantined = CategoryVisibilityPrefs.isHiddenOrAncestor(
              r.id,
            );
            return _buildCategoryTile(
              context: context,
              r: r,
              depth: depth,
              isSelected: isSelected,
              editMode: editMode,
              layout: dLayout,
              onSelect: onSelect,
              onLongPressOpenEditor: onLongPressOpenEditor,
              onFullSettingsTap: onFullSettingsTap,
              onAppearanceTap: onAppearanceTap,
              onVisibilityToggle: onToggleCategoryVisibility != null
                  ? () => onToggleCategoryVisibility!(r.id)
                  : null,
              isQuarantined: quarantined,
            );
          }

          /// Edit mode: same wrap grid as browse; long-press drag to reorder (ReorderableListView API).
          Widget reorderMovable(int index, Widget child) {
            if (!editMode || onReorder == null) return child;
            return DragTarget<int>(
              onAcceptWithDetails: (details) {
                final from = details.data;
                final to = index;
                if (from == to) return;
                // Match ReorderableListView: moving down uses insertion index after target row.
                if (from < to) {
                  onReorder!(from, to + 1);
                } else {
                  onReorder!(from, to);
                }
              },
              builder: (context, candidate, rejected) {
                final highlighted = candidate.isNotEmpty;
                return LongPressDraggable<int>(
                  data: index,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: dLayout.side,
                      height: dLayout.side,
                      child: Opacity(opacity: 0.92, child: child),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: child),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: highlighted
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : Border.all(color: Colors.transparent, width: 2),
                      borderRadius: BorderRadius.circular(
                        dLayout.borderRadius + 2,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
            );
          }

          if (layout == CategoryBandLayout.horizontalPeek) {
            var count = items.length;
            if (showAdd && onAddTap != null) count += 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                height: dLayout.side,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: count,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: kCategoryGridGap),
                  itemBuilder: (ctx, i) {
                    if (i < items.length) {
                      return SizedBox(
                        width: dLayout.side,
                        height: dLayout.side,
                        child: reorderMovable(i, cell(items[i])),
                      );
                    }
                    return SizedBox(
                      width: dLayout.side,
                      height: dLayout.side,
                      child: _addTile(context, dLayout),
                    );
                  },
                ),
              ),
            );
          }

          final squareChips = <Widget>[
            for (var i = 0; i < items.length; i++)
              reorderMovable(i, cell(items[i])),
            if (showAdd && onAddTap != null) _addTile(context, dLayout),
          ];

          return Wrap(
            spacing: bandGap,
            runSpacing: bandGap,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: squareChips,
          );
        },
      ),
    );

    Widget inner = bandMath;
    if (depth >= 1) {
      final pid = immediateParentId;
      if (pid != null) {
        final parent = DatabaseService.instance.getCategoryRuleById(pid);
        final stripeColor =
            parent?.colorOrDefault ?? Theme.of(context).colorScheme.primary;
        inner = DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: stripeColor,
                width: kCategoryGroupStripeWidth,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: kCategoryStripeInnerPadAfterBorder,
            ),
            child: bandMath,
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * kCategoryStaggerIndentPerDepth),
      child: inner,
    );
  }
}
