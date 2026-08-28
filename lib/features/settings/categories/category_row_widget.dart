import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
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

int categoryGridTargetColumns(int depth) {
  if (depth <= 0) return 3;
  if (depth == 1) return 4;
  return 5;
}

const double kCategoryGridGap = 8;
const double kCategoryScrollPeekFraction = 0.17;
const double kCategoryTileWidthClampMin = 48;

double categoryMaxTileSideForViewport(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1100) return 104;
  if (w >= 800) return 112;
  if (w >= 900) return 118;
  if (w >= 700) return 124;
  return 560;
}

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

double categoryReferenceTileSideForDepth(int depth) {
  if (depth <= 0) return 120;
  if (depth == 1) return 96;
  return 82;
}

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
const double kCategoryGlassAlpha = 0.175;
const double kCategoryGlassAlphaSelected = 0.22;
const double kCategoryGroupStripeWidth = 6;

class CategoryDragData {
  const CategoryDragData({
    required this.categoryId,
    required this.sourceParentId,
    required this.sourceIndex,
  });

  final int categoryId;
  final int? sourceParentId;
  final int sourceIndex;
}

enum CategoryBandLayout { horizontalPeek, wrapGrid }

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
    this.canMoveToParent,
    this.onMoveToParent,
    this.onAddTap,
    this.showAdd = false,
    this.editMode = false,
    this.layout = CategoryBandLayout.wrapGrid,
  });

  final List<CategoryRule> items;
  final int depth;
  final int? immediateParentId;
  final int? selectedId;
  final void Function(int? id) onSelect;
  final void Function(CategoryRule r) onFullSettingsTap;
  final void Function(CategoryRule r) onAppearanceTap;
  final void Function(CategoryRule r) onLongPressOpenEditor;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final bool Function(CategoryDragData data, int? newParentId)? canMoveToParent;
  final void Function(CategoryDragData data, int? newParentId)? onMoveToParent;
  final VoidCallback? onAddTap;
  final bool showAdd;
  final bool editMode;
  final CategoryBandLayout layout;

  static Widget _buildCategoryTile({
    required BuildContext context,
    required CategoryRule r,
    required bool isSelected,
    required bool editMode,
    required CategoryDepthLayout layout,
    required void Function(int? id) onSelect,
    required void Function(CategoryRule r) onLongPressOpenEditor,
    required void Function(CategoryRule r) onFullSettingsTap,
    required void Function(CategoryRule r) onAppearanceTap,
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
    final minTap = (layout.side * 0.42).clamp(32.0, 44.0);
    final labelStyle = textTheme.titleSmall?.copyWith(
      fontSize: layout.fontSize,
      fontWeight: layout.fontWeight,
      height: 1.15,
      color: textTheme.bodyLarge?.color,
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
    final radius = layout.borderRadius;

    return SizedBox(
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
                        children: [iconHitTarget, gear],
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
  }

  Widget _addTile(BuildContext context, CategoryDepthLayout layout) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final neutral = scheme.outline.withValues(alpha: 0.35);
    final fill = Color.alphaBlend(
      neutral.withValues(alpha: 0.12),
      scheme.surface,
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
                    style: textTheme.titleSmall?.copyWith(
                      fontSize: layout.fontSize,
                      fontWeight: layout.fontWeight,
                      color: scheme.onSurfaceVariant,
                    ),
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

          Widget cell(CategoryRule r) => _buildCategoryTile(
                context: context,
                r: r,
                isSelected: selectedId == r.id,
                editMode: editMode,
                layout: dLayout,
                onSelect: onSelect,
                onLongPressOpenEditor: onLongPressOpenEditor,
                onFullSettingsTap: onFullSettingsTap,
                onAppearanceTap: onAppearanceTap,
              );

          bool isCenterDrop(GlobalKey key, Offset globalOffset) {
            final box = key.currentContext?.findRenderObject();
            if (box is! RenderBox || !box.hasSize) return true;
            final local = box.globalToLocal(globalOffset);
            final x = local.dx / box.size.width;
            final y = local.dy / box.size.height;
            return x >= 0.22 && x <= 0.78 && y >= 0.22 && y <= 0.78;
          }

          Widget dragMovable(int index, Widget child) {
            if (!editMode || onReorder == null || onMoveToParent == null) {
              return child;
            }
            final item = items[index];
            final dropKey = GlobalKey();
            final payload = CategoryDragData(
              categoryId: item.id,
              sourceParentId: immediateParentId,
              sourceIndex: index,
            );

            bool canAccept(CategoryDragData data, Offset offset) {
              if (data.categoryId == item.id) return false;
              if (isCenterDrop(dropKey, offset)) {
                return canMoveToParent?.call(data, item.id) ?? true;
              }
              return data.sourceParentId == immediateParentId;
            }

            return KeyedSubtree(
              key: dropKey,
              child: DragTarget<CategoryDragData>(
                onWillAcceptWithDetails: (details) =>
                    canAccept(details.data, details.offset),
                onAcceptWithDetails: (details) {
                  final data = details.data;
                  if (isCenterDrop(dropKey, details.offset)) {
                    if (canMoveToParent?.call(data, item.id) ?? true) {
                      onMoveToParent!(data, item.id);
                    }
                    return;
                  }
                  if (data.sourceParentId != immediateParentId) return;
                  final from = data.sourceIndex;
                  final to = index;
                  if (from == to) return;
                  if (from < to) {
                    onReorder!(from, to + 1);
                  } else {
                    onReorder!(from, to);
                  }
                },
                builder: (context, candidate, rejected) {
                  final highlighted = candidate.isNotEmpty;
                  return LongPressDraggable<CategoryDragData>(
                    data: payload,
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
                        border: Border.all(
                          color: highlighted
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(
                          dLayout.borderRadius + 2,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
              ),
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
                        child: dragMovable(i, cell(items[i])),
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

          return Wrap(
            spacing: kCategoryGridGap,
            runSpacing: kCategoryGridGap,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                dragMovable(i, cell(items[i])),
              if (showAdd && onAddTap != null) _addTile(context, dLayout),
            ],
          );
        },
      ),
    );

    Widget inner = bandMath;
    if (depth >= 1 && immediateParentId != null) {
      final parent = DatabaseService.instance.getCategoryRuleById(
        immediateParentId!,
      );
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

    if (editMode && onMoveToParent != null) {
      final bandParentId = immediateParentId;
      final bandChild = inner;
      inner = DragTarget<CategoryDragData>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          if (data.sourceParentId == bandParentId) return false;
          return canMoveToParent?.call(data, bandParentId) ?? true;
        },
        onAcceptWithDetails: (details) {
          final data = details.data;
          if (data.sourceParentId == bandParentId) return;
          if (canMoveToParent?.call(data, bandParentId) ?? true) {
            onMoveToParent!(data, bandParentId);
          }
        },
        builder: (context, candidate, rejected) => DecoratedBox(
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: bandChild,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * kCategoryStaggerIndentPerDepth),
      child: inner,
    );
  }
}
