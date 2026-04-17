import 'dart:async';

import 'package:counter/core/category_color_palette.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/categories/create_category_dialog.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// CATEGORIES FEATURE — UI_ISOLATION (§7). All strings via t() from dictionary.
// No hardcoded UI text. No direct DB writes (use DatabaseService).
// ---------------------------------------------------------------------------

String _categoryTileLabel(CategoryRule r) {
  final loc = currentLocale.value;
  final fromMap = r.localizedNames?[loc] ?? r.localizedNames?['en'];
  final s =
      (fromMap != null && fromMap.trim().isNotEmpty) ? fromMap.trim() : r.name;
  return localizeCategoryDbSegment(s.trim(), loc);
}

/// Target columns per depth: roots 3, children 4, deeper 5 (drives responsive tile size).
int _gridTargetColumns(int depth) {
  if (depth <= 0) return 3;
  if (depth == 1) return 4;
  return 5;
}

const double _kCategoryGridGap = 8;
const double _kScrollPeekFraction = 0.17;
const double _kTileWidthClampMin = 48;

/// Cap tile side on large viewports (desktop web) so grids stay compact (@DATA_MAP grid tiers).
double _maxTileSideForViewport(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (kIsWeb && w >= 1100) return 104;
  if (kIsWeb && w >= 800) return 112;
  if (w >= 900) return 118;
  if (w >= 700) return 124;
  return 560;
}

/// Grid: exactly [N] full squares per row — `N*w + (N-1)*g == availableWidth`.
double _calculateTileWidthGrid(
  int depth,
  double availableWidth,
  double maxSide,
) {
  final n = _gridTargetColumns(depth);
  if (availableWidth <= 0 || n <= 0) return _kTileWidthClampMin;
  final raw =
      (availableWidth - (n - 1) * _kCategoryGridGap) / n;
  return raw.clamp(_kTileWidthClampMin, maxSide);
}

/// Scroll: viewport shows [N] full tiles + [k] of the next — `V = w*(N+k) + (N-1)*g`.
double _calculateTileWidthScroll(
  int depth,
  double availableWidth,
  double maxSide,
) {
  final n = _gridTargetColumns(depth);
  if (availableWidth <= 0 || n <= 0) return _kTileWidthClampMin;
  final denom = n + _kScrollPeekFraction;
  final raw = (availableWidth - (n - 1) * _kCategoryGridGap) / denom;
  return raw.clamp(_kTileWidthClampMin, maxSide);
}

/// Nominal reference [side] per depth tier (for scaling type/icons when [side] comes from math).
double _referenceTileSideForDepth(int depth) {
  if (depth <= 0) return 120;
  if (depth == 1) return 96;
  return 82;
}

/// Per-depth icon / type / padding; [side] comes from grid math (square tile).
class _CategoryDepthLayout {
  const _CategoryDepthLayout({
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

  static _CategoryDepthLayout forDepthAndSide(int depth, double side) {
    final ref = _referenceTileSideForDepth(depth);
    final scale = (side / ref).clamp(0.55, 1.55);
    if (depth <= 0) {
      return _CategoryDepthLayout(
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
      return _CategoryDepthLayout(
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
    return _CategoryDepthLayout(
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

const double _kStaggerIndentPerDepth = 16;
const double _kBandScreenMarginH = 16;
const double _kStripeInnerPadAfterBorder = 10;

/// Semi-transparent category tint over surface (“glass”).
const double _kCategoryGlassAlpha = 0.175;
const double _kCategoryGlassAlphaSelected = 0.22;
const double _kGroupStripeWidth = 6;

enum CategoryBandLayout {
  /// Horizontal list: tile side from `N` full + 17% peek (`_calculateTileWidthScroll`).
  horizontalPeek,
  /// Multi-row wrap: `N` tiles per row from `_calculateTileWidthGrid` (strict 8pt gap).
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
    required _CategoryDepthLayout layout,
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
    final label = _categoryTileLabel(r);
    final isDefault = r.id == DatabaseService.instance.defaultCategoryId;
    final loc = currentLocale.value;
    final glassAlpha =
        isSelected ? _kCategoryGlassAlphaSelected : _kCategoryGlassAlpha;
    final fill = Color.alphaBlend(
      color.withValues(alpha: glassAlpha),
      scheme.surface,
    );

    final minTap =
        (layout.side * 0.42).clamp(32.0, 44.0); // scales down on 70px tiles

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
                          if (visibilityBtn != null) visibilityBtn,
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

  Widget _addTile(
    BuildContext context,
    _CategoryDepthLayout layout,
  ) {
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
                  Icon(Icons.add_rounded,
                      size: layout.addGlyphSize, color: scheme.outline),
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
    final bandGap = _kCategoryGridGap;

    /// LayoutBuilder [maxWidth] is the band’s content width **after** stripe + standard L/R margin.
    final bandMath = Padding(
      padding: const EdgeInsets.fromLTRB(
        _kBandScreenMarginH,
        6,
        _kBandScreenMarginH,
        6,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final avail = c.maxWidth;
          final maxSide = _maxTileSideForViewport(context);
          final side = layout == CategoryBandLayout.horizontalPeek
              ? _calculateTileWidthScroll(depth, avail, maxSide)
              : _calculateTileWidthGrid(depth, avail, maxSide);
          final dLayout = _CategoryDepthLayout.forDepthAndSide(depth, side);

          Widget cell(CategoryRule r) {
            final isSelected = selectedId == r.id;
            final quarantined =
                CategoryVisibilityPrefs.isHiddenOrAncestor(r.id);
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
                      child: Opacity(
                        opacity: 0.92,
                        child: child,
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: highlighted
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : Border.all(color: Colors.transparent, width: 2),
                      borderRadius:
                          BorderRadius.circular(dLayout.borderRadius + 2),
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
                      const SizedBox(width: _kCategoryGridGap),
                  itemBuilder: (ctx, i) {
                    if (i < items.length) {
                      return SizedBox(
                        width: dLayout.side,
                        height: dLayout.side,
                        child: reorderMovable(
                          i,
                          cell(items[i]),
                        ),
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
        final stripeColor = parent?.colorOrDefault ??
            Theme.of(context).colorScheme.primary;
        inner = DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: stripeColor,
                width: _kGroupStripeWidth,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: _kStripeInnerPadAfterBorder),
            child: bandMath,
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * _kStaggerIndentPerDepth),
      child: inner,
    );
  }
}

/// Input field that commits a tag on Space, Comma, or Enter.
class TagInputField extends StatefulWidget {
  const TagInputField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.decoration,
    this.chipBackgroundColor,
    this.chipLabelColor,
    this.onTagAdded,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final InputDecoration? decoration;
  final Color? chipBackgroundColor;
  final Color? chipLabelColor;
  final void Function(String tag)? onTagAdded;

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final last = text.length - 1;
    if (last < 0) return;
    final ch = text[last];
    if (ch == ' ' || ch == ',') {
      final before = text.substring(0, last).trim().toLowerCase();
      _controller.removeListener(_onTextChanged);
      _controller.text = '';
      _controller.addListener(_onTextChanged);
      if (before.isNotEmpty) {
        final next = List<String>.from(widget.tags);
        if (!next.contains(before)) {
          next.add(before);
          widget.onChanged(next);
          widget.onTagAdded?.call(before);
        }
      }
    }
  }

  void _commitCurrent() {
    final trimmed = _controller.text.trim().toLowerCase();
    _controller.clear();
    if (trimmed.isEmpty) return;
    final next = List<String>.from(widget.tags);
    if (!next.contains(trimmed)) {
      next.add(trimmed);
      widget.onChanged(next);
      widget.onTagAdded?.call(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.chipBackgroundColor ?? Theme.of(context).chipTheme.backgroundColor ?? Colors.grey.shade300;
    final fg = widget.chipLabelColor ?? Theme.of(context).chipTheme.labelStyle?.color ?? Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag, style: TextStyle(color: fg)),
                backgroundColor: bg,
                onDeleted: () {
                  final next = List<String>.from(widget.tags)..remove(tag);
                  widget.onChanged(next);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: widget.decoration ?? InputDecoration(labelText: t(currentLocale.value, 'add_keyword_hint')),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _commitCurrent(),
        ),
      ],
    );
  }
}

const List<IconData> _kCategoryIconChoices = <IconData>[
  Icons.folder_rounded,
  Icons.work_rounded,
  Icons.home_rounded,
  Icons.fitness_center_rounded,
  Icons.book_rounded,
  Icons.local_cafe_rounded,
  Icons.school_rounded,
  Icons.music_note_rounded,
  Icons.restaurant_rounded,
  Icons.directions_car_rounded,
  Icons.flight_rounded,
  Icons.child_care_rounded,
  Icons.pets_rounded,
  Icons.code_rounded,
  Icons.eco_rounded,
];

/// Quick color + icon picker (edit mode: tap category icon). Uses same PATCH path as full editor.
class _CategoryAppearanceSheet extends StatefulWidget {
  const _CategoryAppearanceSheet({
    required this.category,
    required this.onSaved,
  });

  final CategoryRule category;
  final VoidCallback onSaved;

  @override
  State<_CategoryAppearanceSheet> createState() => _CategoryAppearanceSheetState();
}

class _CategoryAppearanceSheetState extends State<_CategoryAppearanceSheet> {
  late int? _colorValue;
  late int _iconCodePoint;
  MaterialColor? _selectedPrimary;
  int? _selectedShadeValue;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _colorValue = widget.category.colorValue;
    _iconCodePoint =
        widget.category.iconCodePoint ?? Icons.folder_rounded.codePoint;
  }

  MaterialColor _primaryForValue(int? v) =>
      categoryMaterialPrimaryForValue(v);

  Future<void> _apply() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.category.id;
    final cv = _colorValue ?? 0;
    DatabaseService.instance.updateNestedCategory(
      id,
      colorValue: cv,
      iconCodePoint: _iconCodePoint,
    );
    if (mounted) {
      widget.onSaved();
      Navigator.of(context).pop();
    }
    try {
      final patch = await DatabaseService.instance.patchCategoryDelta(
        id,
        <String, dynamic>{
          'color_value': cv,
          'icon_code_point': _iconCodePoint,
        },
      );
      if (!patch.ok && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    _selectedPrimary ??= _primaryForValue(_colorValue);
    _selectedShadeValue ??=
        (_colorValue != null &&
                categoryMaterialShadeValues(_selectedPrimary!)
                    .contains(_colorValue))
            ? _colorValue
            : _selectedPrimary![500]!.value;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(loc, 'category_section_appearance'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(t(loc, 'category_color'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryPickerMaterialColors.map((p) {
                final sel = _selectedPrimary == p;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPrimary = p;
                      _selectedShadeValue = p[500]!.value;
                      _colorValue = _selectedShadeValue;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: sel ? 3 : 0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
                  .map((tone) {
                final c = _selectedPrimary![tone]!;
                final v = c.value;
                final sel = _selectedShadeValue == v;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedShadeValue = v;
                      _colorValue = v;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: sel ? 3 : 0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(t(loc, 'category_choose_icon'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kCategoryIconChoices.map((ic) {
                final cp = ic.codePoint;
                final sel = _iconCodePoint == cp;
                return InkWell(
                  onTap: () {
                    setState(() => _iconCodePoint = cp);
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Icon(ic,
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _apply,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t(loc, 'category_appearance_apply')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified category editor: names, parent, color, icon, keywords, default, delete.
class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({
    super.key,
    required this.category,
    required this.onSaved,
    this.onCategoryDeleted,
  });

  final CategoryRule category;
  final VoidCallback onSaved;
  final VoidCallback? onCategoryDeleted;

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  final Map<String, List<String>> _keywordsByLang = {};
  bool _saving = false;
  int? _parentId;
  int? _selectedColorValue;
  MaterialColor? _selectedPrimary;
  int? _selectedShadeValue;
  late int _iconCodePoint;
  late final TextEditingController _primaryNameController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameRuController;

  @override
  void initState() {
    super.initState();
    final langs = DatabaseService.instance.settings.effectiveActiveLanguages;
    for (final lang in langs) {
      _keywordsByLang[lang] =
          List<String>.from(widget.category.keywordsFor(lang));
    }
    _parentId = DatabaseService.instance.getParentId(widget.category.id);
    _selectedColorValue = widget.category.colorValue;
    _iconCodePoint =
        widget.category.iconCodePoint ?? Icons.folder_rounded.codePoint;
    final names = widget.category.localizedNames ?? const {};
    _primaryNameController =
        TextEditingController(text: widget.category.name.trim());
    _nameEnController = TextEditingController(text: names['en'] ?? '');
    _nameRuController = TextEditingController(text: names['ru'] ?? '');
  }

  @override
  void dispose() {
    _primaryNameController.dispose();
    _nameEnController.dispose();
    _nameRuController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final cid = widget.category.id;
    final currentColor = widget.category.colorValue;
    final colorChanged =
        _selectedColorValue != null && _selectedColorValue != currentColor;
    final iconChanged = _iconCodePoint !=
        (widget.category.iconCodePoint ?? Icons.folder_rounded.codePoint);
    if (colorChanged) {
      DatabaseService.instance.updateNestedCategory(
        cid,
        colorValue: _selectedColorValue,
      );
    }
    if (iconChanged) {
      DatabaseService.instance.updateNestedCategory(
        cid,
        iconCodePoint: _iconCodePoint,
      );
    }
    final newNames = <String, String>{};
    final enName = _nameEnController.text.trim();
    final ruName = _nameRuController.text.trim();
    if (enName.isNotEmpty) newNames['en'] = enName;
    if (ruName.isNotEmpty) newNames['ru'] = ruName;
    final bool namesChanged = newNames.isNotEmpty;
    final Map<String, List<String>> keywords = {};
    for (final e in _keywordsByLang.entries) {
      final parts = e.value
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) keywords[e.key] = parts;
    }
    final currentParent = DatabaseService.instance.getParentId(cid);
    final newParent = _parentId;
    final currentEffective = currentParent;
    final primaryNew = _primaryNameController.text.trim();
    final primaryChanged =
        primaryNew.isNotEmpty && primaryNew != widget.category.name.trim();
    if (mounted) {
      widget.onSaved();
      Navigator.of(context).pop();
    }
    unawaited(() async {
      try {
        if (primaryChanged) {
          final res =
              await DatabaseService.instance.updateCategory(cid, primaryNew);
          if (!res.ok && mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
            );
          }
        }
        final delta = <String, dynamic>{
          'keywords': keywords,
        };
        if (namesChanged) {
          DatabaseService.instance.updateCategoryLocalizedNames(
            cid,
            newNames,
          );
          delta['localized_names'] = newNames;
        }
        if (colorChanged) {
          DatabaseService.instance.updateNestedCategory(
            cid,
            colorValue: _selectedColorValue,
          );
          delta['color_value'] = _selectedColorValue;
        }
        if (iconChanged) {
          delta['icon_code_point'] = _iconCodePoint;
        }
        final patch =
            await DatabaseService.instance.patchCategoryDelta(cid, delta);
        if (!patch.ok) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
            );
          }
          return;
        }
        if (currentEffective != newParent) {
          await DatabaseService.instance.updateCategoryParent(
            cid,
            newParent,
          );
        }
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
        );
      }
      if (mounted) setState(() => _saving = false);
    }());
  }

  Future<void> _confirmDelete() async {
    final loc = currentLocale.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t(loc, 'delete_category_confirm')),
        content: Text(t(loc, 'delete_subcategories_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(t(loc, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(loc, 'delete')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final idToDelete = widget.category.id;
    widget.onCategoryDeleted?.call();
    widget.onSaved();
    Navigator.of(context).pop();
    final ok = await DatabaseService.instance.deleteCategory(idToDelete);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(t(loc, 'category_removed'))),
      );
    }
  }

  void _setAsDefault() {
    unawaited(() async {
      try {
        await DatabaseService.instance.saveSettings(
          DatabaseService.instance.settings
              .copyWith(defaultCategoryId: widget.category.id),
        );
      } on AuthenticatedUserIdRequiredException {
        // Auth store empty — cannot PATCH profile; ignore silently here.
      } catch (_) {}
    }());
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'en':
        return t(currentLocale.value, 'keywords_english');
      case 'ru':
        return t(currentLocale.value, 'keywords_russian');
      default:
        return t(currentLocale.value, 'keywords_lang').replaceFirst('%s', code);
    }
  }

  Color _chipBackgroundColor(String code, BuildContext context) {
    switch (code) {
      case 'en':
        return Colors.blue.shade100;
      case 'ru':
        return Colors.red.shade100;
      default:
        return Theme.of(context).chipTheme.backgroundColor ?? Colors.grey.shade300;
    }
  }

  Color _chipTextColor(String code, BuildContext context) {
    switch (code) {
      case 'en':
        return Colors.blue.shade900;
      case 'ru':
        return Colors.red.shade900;
      default:
        return Theme.of(context).chipTheme.labelStyle?.color ?? Colors.black87;
    }
  }

  void _onTagsChanged(String langCode, List<String> newTags) {
    setState(() => _keywordsByLang[langCode] = newTags);
  }

  Widget _buildParentPicker(BuildContext context) {
    final db = DatabaseService.instance;
    final forbidden = {widget.category.id, ...db.getRecordIdsInSubtree(widget.category.id)};
    final pairs = db.allCategoryIdPathPairs.where((p) => !forbidden.contains(p.id)).toList();
    return DropdownButtonFormField<int?>(
      initialValue: _parentId,
      decoration: InputDecoration(labelText: t(currentLocale.value, 'parent_category')),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(t(currentLocale.value, 'root_top_level'))),
        ...pairs.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.path, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) => setState(() => _parentId = v),
    );
  }

  Future<void> _translateAndAddRuIfNeeded(String langCode, String trimmed) async {
    final settings = DatabaseService.instance.settings;
    final langs = settings.effectiveActiveLanguages;
    if (langCode != 'en' || !langs.contains('ru')) return;
    try {
      final translated = await DatabaseService.instance.translateKeyword(
        trimmed,
        fromLang: 'en',
        toLang: 'ru',
      );
      if (!mounted) return;
      if (translated != null && translated.isNotEmpty) {
        setState(() {
          final ruList = _keywordsByLang.putIfAbsent('ru', () => <String>[]);
          if (!ruList.contains(translated)) ruList.add(translated);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final langs = DatabaseService.instance.settings.effectiveActiveLanguages;
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;

    _selectedPrimary ??=
        categoryMaterialPrimaryForValue(_selectedColorValue);
    _selectedShadeValue ??= (_selectedColorValue != null &&
            categoryMaterialShadeValues(_selectedPrimary!)
                .contains(_selectedColorValue))
        ? _selectedColorValue
        : _selectedPrimary![500]!.value;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(locale, 'edit_category_tag')
                  .replaceFirst('%s', widget.category.name),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              t(locale, 'category_primary_tag_name'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextField(
              controller: _primaryNameController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text(t(locale, 'name_en')),
            TextField(
              controller: _nameEnController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Text(t(locale, 'name_ru')),
            TextField(
              controller: _nameRuController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            _buildParentPicker(context),
            const SizedBox(height: 24),
            Text(
              t(locale, 'category_section_appearance'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(t(locale, 'category_color'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryPickerMaterialColors.map((p) {
                final sel = _selectedPrimary == p;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPrimary = p;
                      _selectedShadeValue = p[500]!.value;
                      _selectedColorValue = _selectedShadeValue;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: p,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? scheme.primary : Colors.transparent,
                        width: sel ? 3 : 0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
                  .map((tone) {
                final c = _selectedPrimary![tone]!;
                final v = c.value;
                final sel = _selectedShadeValue == v;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedShadeValue = v;
                      _selectedColorValue = v;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? scheme.primary : Colors.transparent,
                        width: sel ? 3 : 0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(t(locale, 'category_choose_icon'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kCategoryIconChoices.map((ic) {
                final cp = ic.codePoint;
                final sel = _iconCodePoint == cp;
                return InkWell(
                  onTap: () {
                    setState(() => _iconCodePoint = cp);
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? scheme.primary : scheme.outlineVariant,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      ic,
                      color: sel ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              t(locale, 'category_section_keywords'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...langs.map((lang) {
              final keywords = _keywordsByLang[lang] ?? const <String>[];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_languageLabel(lang),
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    TagInputField(
                      tags: keywords,
                      onChanged: (newTags) => _onTagsChanged(lang, newTags),
                      onTagAdded: (tag) =>
                          _translateAndAddRuIfNeeded(lang, tag),
                      decoration: InputDecoration(
                        labelText: t(locale, 'add_keyword_label'),
                        hintText: t(locale, 'hint_keyword_add'),
                      ),
                      chipBackgroundColor: _chipBackgroundColor(lang, context),
                      chipLabelColor: _chipTextColor(lang, context),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              t(locale, 'category_section_more'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _setAsDefault,
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: Text(
                DatabaseService.instance.defaultCategoryId == widget.category.id
                    ? t(locale, 'default_category')
                    : t(locale, 'set_as_default'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(locale, 'delete_subcategories_warning'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _confirmDelete,
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              child: Text(t(locale, 'delete')),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t(locale, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Categories tab: folder / band layout (drill-down rows) + CategoryEditorSheet.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    required this.rules,
    required this.onChanged,
  });

  final List<CategoryRule> rules;
  final Future<void> Function() onChanged;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final List<int?> _selectedPath = [null, null, null, null];
  bool _categoryEditMode = false;
  bool _useHorizontalScrollLayout = false;
  static const int _maxDepth = 4;

  void _categoryVisibilityListener() {
    if (!mounted) return;
    var changed = false;
    for (var d = 0; d < _maxDepth; d++) {
      final id = _selectedPath[d];
      if (id != null && CategoryVisibilityPrefs.isHiddenOrAncestor(id)) {
        for (var j = d; j < _maxDepth; j++) {
          _selectedPath[j] = null;
        }
        changed = true;
        break;
      }
    }
    if (changed) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    unawaited(CategoryVisibilityPrefs.ensureLoaded());
    CategoryVisibilityPrefs.hiddenIds.addListener(_categoryVisibilityListener);
  }

  @override
  void dispose() {
    CategoryVisibilityPrefs.hiddenIds.removeListener(_categoryVisibilityListener);
    unawaited(DatabaseService.instance.flushCategoryOrderSyncNow());
    super.dispose();
  }

  void _onCategoryBandReorder(int depth, int oldIndex, int newIndex) {
    if (!_categoryEditMode) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final parentId = depth == 0 ? null : _selectedPath[depth - 1];
    final baselineBefore = List<CategoryRule>.from(_getItemsForDepth(depth));
    if (oldIndex < 0 ||
        oldIndex >= baselineBefore.length ||
        newIndex < 0 ||
        newIndex > baselineBefore.length) {
      return;
    }
    final items = List<CategoryRule>.from(baselineBefore);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    setState(() {
      DatabaseService.instance.applyLocalCategorySiblingOrder(parentId, items);
    });
    final after =
        List<CategoryRule>.from(DatabaseService.instance.getChildrenOf(parentId));
    unawaited(
      DatabaseService.instance.persistCategorySiblingOrder(
        parentId,
        after,
        baselineBeforeReorder: baselineBefore,
      ),
    );
  }

  Future<void> _notifyChanged() async {
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  List<CategoryRule> _getItemsForDepth(int depth) {
    final List<CategoryRule> raw;
    if (depth == 0) {
      raw = DatabaseService.instance.getChildrenOf(null);
    } else {
      final parentId = _selectedPath[depth - 1];
      if (parentId == null) return [];
      raw = DatabaseService.instance.getChildrenOf(parentId);
    }
    if (_categoryEditMode) return raw;
    return raw
        .where((r) => !CategoryVisibilityPrefs.isHiddenOrAncestor(r.id))
        .toList();
  }

  void _selectAtDepth(int depth, int? id) {
    setState(() {
      _selectedPath[depth] = id;
      for (var i = depth + 1; i < _maxDepth; i++) {
        _selectedPath[i] = null;
      }
    });
  }

  void _navigateToCategoryPath(List<int> path) {
    setState(() {
      for (var d = 0; d < _maxDepth; d++) {
        _selectedPath[d] = d < path.length ? path[d] : null;
      }
    });
  }

  Future<void> _showAddCategoryDialog({required int? parentId}) async {
    await showCreateCategoryDialog(
      context: context,
      parentId: parentId,
      onGoToActiveCategory: (localId) {
        final path =
            DatabaseService.instance.categoryPathFromRootToLocalId(localId);
        if (path.isEmpty) return;
        _navigateToCategoryPath(path);
      },
      onDone: _notifyChanged,
    );
  }

  void _clearSelectionIfDeleted(int deletedId) {
    for (var i = 0; i < _maxDepth; i++) {
      if (_selectedPath[i] == deletedId) {
        setState(() {
          for (var j = i; j < _maxDepth; j++) {
            _selectedPath[j] = null;
          }
        });
        return;
      }
    }
  }

  void _showCategoryEditorSheet(BuildContext context, CategoryRule r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => CategoryEditorSheet(
        category: r,
        onSaved: () => unawaited(_notifyChanged()),
        onCategoryDeleted: () => _clearSelectionIfDeleted(r.id),
      ),
    );
  }

  void _showCategoryAppearanceSheet(BuildContext context, CategoryRule r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CategoryAppearanceSheet(
        category: r,
        onSaved: () => unawaited(_notifyChanged()),
      ),
    );
  }

  Future<void> _addRule() async {
    await _showAddCategoryDialog(parentId: null);
  }

  Future<void> _addSubcategoryAtDepth(int depth) async {
    final parentId = depth == 0 ? null : _selectedPath[depth - 1];
    await _showAddCategoryDialog(parentId: parentId);
  }

  Widget buildTabRow(BuildContext context, int depth, List<CategoryRule> items) {
    final selectedId = depth < _maxDepth ? _selectedPath[depth] : null;
    final canAddAtThisLevel =
        depth < _maxDepth && (depth == 0 || _selectedPath[depth - 1] != null);

    final band = CategoryRowWidget(
      depth: depth,
      items: items,
      immediateParentId: depth == 0 ? null : _selectedPath[depth - 1],
      selectedId: selectedId,
      onSelect: (id) => _selectAtDepth(depth, id),
      onFullSettingsTap: (r) => _showCategoryEditorSheet(context, r),
      onAppearanceTap: (r) => _showCategoryAppearanceSheet(context, r),
      onLongPressOpenEditor: (r) => _showCategoryEditorSheet(context, r),
      onReorder: _categoryEditMode
          ? (oldI, newI) => _onCategoryBandReorder(depth, oldI, newI)
          : null,
      layout: _useHorizontalScrollLayout
          ? CategoryBandLayout.horizontalPeek
          : CategoryBandLayout.wrapGrid,
      showAdd: canAddAtThisLevel,
      onAddTap: () => unawaited(_addSubcategoryAtDepth(depth)),
      editMode: _categoryEditMode,
      onToggleCategoryVisibility: _categoryEditMode
          ? (id) => unawaited(CategoryVisibilityPrefs.toggle(id))
          : null,
    );

    final hasSelection = depth < _maxDepth && selectedId != null;
    final nextItems =
        hasSelection ? _getItemsForDepth(depth + 1) : <CategoryRule>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        band,
        if (hasSelection && depth + 1 < _maxDepth)
          buildTabRow(context, depth + 1, nextItems),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final loc = currentLocale.value;

    return ValueListenableBuilder<List<int>>(
      valueListenable: CategoryVisibilityPrefs.hiddenIds,
      builder: (context, _, __) {
        final roots = _getItemsForDepth(0);
        return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(t(loc, 'categories_title')),
        actions: [
          IconButton(
            icon: Icon(_useHorizontalScrollLayout
                ? Icons.grid_view_rounded
                : Icons.view_week_rounded),
            tooltip: _useHorizontalScrollLayout
                ? t(loc, 'switch_to_wrap')
                : t(loc, 'switch_to_scrollable'),
            onPressed: () => setState(
                () => _useHorizontalScrollLayout = !_useHorizontalScrollLayout),
          ),
          IconButton(
            tooltip: t(loc, 'add_category'),
            onPressed: () => unawaited(_addRule()),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              title: Text(
                t(loc, 'category_edit_mode'),
                style: textTheme.titleSmall,
              ),
              subtitle: Text(
                t(loc, 'category_edit_mode_subtitle'),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              value: _categoryEditMode,
              onChanged: (v) => setState(() => _categoryEditMode = v),
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            Expanded(
              child: roots.isEmpty
                  ? EmptyStatePlaceholder(
                      icon: Icons.folder_outlined,
                      titleL10nKey: 'empty_categories_title',
                      subtitleL10nKey: 'empty_categories_subtitle',
                      actionLabelL10nKey: 'add_category',
                      onAction: () => unawaited(_addRule()),
                      useFilledAction: true,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: buildTabRow(context, 0, roots),
                    ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
