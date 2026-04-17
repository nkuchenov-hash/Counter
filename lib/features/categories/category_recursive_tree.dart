// Recursive category tree: expand-in-place hierarchy + active-path opacity (Strike 3A).
// UI only — data remains [DatabaseService.rules] / [CategoryRule] tree.

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

const double _kInactiveBranchOpacity = 0.4;
const Duration _kTreeOpacityDuration = Duration(milliseconds: 80);

/// Spine-based opacity: on path to [selectedCategoryId] = 1.0; deeper descendants of leaf = 1.0;
/// siblings off-spine = [_kInactiveBranchOpacity]. No selection → 1.0.
double categoryBranchOpacityForSelection({
  required int? selectedCategoryId,
  required int nodeId,
  required int depth,
}) {
  if (selectedCategoryId == null) return 1.0;
  final db = DatabaseService.instance;
  final spine = db.categoryPathFromRootToLocalId(selectedCategoryId);
  if (spine.isEmpty) return 1.0;
  if (depth < spine.length) {
    return nodeId == spine[depth] ? 1.0 : _kInactiveBranchOpacity;
  }
  final path = db.categoryPathFromRootToLocalId(nodeId);
  if (path.length <= spine.length) return _kInactiveBranchOpacity;
  final anchor = spine.last;
  final idx = path.indexOf(anchor);
  return (idx >= 0 && idx < path.length - 1) ? 1.0 : _kInactiveBranchOpacity;
}

String _labelForRule(CategoryRule r) {
  final loc = currentLocale.value;
  final raw = (r.localizedNames?[loc] ?? r.localizedNames?['en'] ?? r.name).trim();
  return localizeCategoryDbSegment(raw, loc);
}

/// Result of tree sheet: picked id, or "all" for nullable filters, or dismissed.
sealed class CategoryTreeSheetResult {}

class CategoryTreeSheetPicked extends CategoryTreeSheetResult {
  CategoryTreeSheetPicked(this.id);
  final int id;
}

/// Nullable filter: user chose "all categories".
class CategoryTreeSheetAll extends CategoryTreeSheetResult {}

Future<CategoryTreeSheetResult?> _showCategoryTreeSheet(
  BuildContext context, {
  int? initialCategoryId,
  bool showAllCategoriesRow = false,
}) async {
  final loc = currentLocale.value;
  final rootsRaw = DatabaseService.instance.getChildrenOf(null);
  final roots = [
    for (final r in rootsRaw)
      if (!CategoryVisibilityPrefs.isHiddenOrAncestor(r.id)) r
  ];
  if (roots.isEmpty) return null;

  return showModalBottomSheet<CategoryTreeSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  t(loc, 'category_label'),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showAllCategoriesRow)
                        ListTile(
                          title: Text(t(loc, 'lists_filter_all')),
                          leading: const Icon(Icons.filter_alt_off_rounded),
                          onTap: () =>
                              Navigator.of(ctx).pop(CategoryTreeSheetAll()),
                        ),
                      _CategoryTreeBody(
                        roots: roots,
                        selectedCategoryId: initialCategoryId,
                        expandSelectionPath: false,
                        onSelect: (id) => Navigator.of(ctx).pop(
                          CategoryTreeSheetPicked(id),
                        ),
                        showEditChrome: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Picker sheet: returns chosen category id, or null if dismissed unchanged.
Future<int?> showCategoryTreePicker(
  BuildContext context, {
  int? initialCategoryId,
}) async {
  final r = await _showCategoryTreeSheet(
    context,
    initialCategoryId: initialCategoryId,
    showAllCategoriesRow: false,
  );
  if (r is CategoryTreeSheetPicked) return r.id;
  return null;
}

/// Lists filter: nullable category; includes "All categories" row in the tree sheet.
class CategoryFilterTreeField extends StatelessWidget {
  const CategoryFilterTreeField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final loc = currentLocale.value;
    final pathText = value == null
        ? t(loc, 'lists_filter_all')
        : db.getCategoryPath(value!);

    return InkWell(
      onTap: () async {
        final r = await _showCategoryTreeSheet(
          context,
          initialCategoryId: value,
          showAllCategoriesRow: true,
        );
        if (r is CategoryTreeSheetAll) {
          onChanged(null);
        } else if (r is CategoryTreeSheetPicked) {
          onChanged(r.id);
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: decoration,
        isEmpty: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                pathText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Form field: tap opens tree sheet; displays breadcrumb path text.
class CategoryTreeFormField extends StatelessWidget {
  const CategoryTreeFormField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.enabled = true,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final InputDecoration decoration;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final pairs = db.allCategoryIdPathPairs;
    final pathText = value != null && pairs.any((p) => p.id == value)
        ? db.getCategoryPath(value!)
        : null;

    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final r = await _showCategoryTreeSheet(
                context,
                initialCategoryId: value,
                showAllCategoriesRow: false,
              );
              if (r is CategoryTreeSheetPicked) {
                onChanged(r.id);
              }
            },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: decoration,
        isEmpty: pathText == null || pathText.isEmpty,
        child: Row(
          children: [
            Expanded(
              child: Text(
                pathText ?? decoration.hintText ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: pathText == null
                          ? Theme.of(context).hintColor
                          : null,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Browse / edit tree used on [CategoriesPage] and inside picker sheet.
class _CategoryTreeBody extends StatefulWidget {
  const _CategoryTreeBody({
    required this.roots,
    required this.selectedCategoryId,
    this.expandSelectionPath = true,
    required this.onSelect,
    required this.showEditChrome,
    this.onFullSettingsTap,
    this.onAppearanceTap,
    this.onAddChild,
  });

  final List<CategoryRule> roots;
  final int? selectedCategoryId;
  /// When false (picker / [CategoryTreeFormField]), tree opens fully collapsed.
  final bool expandSelectionPath;
  final ValueChanged<int> onSelect;
  final bool showEditChrome;
  final void Function(CategoryRule r)? onFullSettingsTap;
  final void Function(CategoryRule r)? onAppearanceTap;
  final void Function(CategoryRule parent)? onAddChild;

  @override
  State<_CategoryTreeBody> createState() => _CategoryTreeBodyState();
}

class _CategoryTreeBodyState extends State<_CategoryTreeBody> {
  late Set<int> _expandedIds;

  @override
  void initState() {
    super.initState();
    _expandedIds = widget.expandSelectionPath
        ? _initialExpandedForSelection(widget.selectedCategoryId)
        : <int>{};
  }

  @override
  void didUpdateWidget(covariant _CategoryTreeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId ||
        oldWidget.expandSelectionPath != widget.expandSelectionPath) {
      setState(() {
        _expandedIds = widget.expandSelectionPath
            ? _initialExpandedForSelection(widget.selectedCategoryId)
            : <int>{};
      });
    }
  }

  Set<int> _initialExpandedForSelection(int? selectedCategoryId) {
    if (selectedCategoryId == null) return {};
    final spine = DatabaseService.instance
        .categoryPathFromRootToLocalId(selectedCategoryId);
    if (spine.length <= 1) return {};
    return spine.take(spine.length - 1).toSet();
  }

  void _toggle(int id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds = {..._expandedIds, id};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in widget.roots)
          _CategoryTreeNode(
            rule: r,
            depth: 0,
            selectedCategoryId: widget.selectedCategoryId,
            expandedIds: _expandedIds,
            onToggleExpand: _toggle,
            onSelect: widget.onSelect,
            showEditChrome: widget.showEditChrome,
            onFullSettingsTap: widget.onFullSettingsTap,
            onAppearanceTap: widget.onAppearanceTap,
            onAddChild: widget.onAddChild,
          ),
      ],
    );
  }
}

class _CategoryTreeNode extends StatelessWidget {
  const _CategoryTreeNode({
    required this.rule,
    required this.depth,
    required this.selectedCategoryId,
    required this.expandedIds,
    required this.onToggleExpand,
    required this.onSelect,
    required this.showEditChrome,
    this.onFullSettingsTap,
    this.onAppearanceTap,
    this.onAddChild,
  });

  final CategoryRule rule;
  final int depth;
  final int? selectedCategoryId;
  final Set<int> expandedIds;
  final void Function(int id) onToggleExpand;
  final ValueChanged<int> onSelect;
  final bool showEditChrome;
  final void Function(CategoryRule r)? onFullSettingsTap;
  final void Function(CategoryRule r)? onAppearanceTap;
  final void Function(CategoryRule parent)? onAddChild;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final childrenRaw = rule.children ?? const <CategoryRule>[];
    final children = [
      for (final c in childrenRaw)
        if (!CategoryVisibilityPrefs.isHiddenOrAncestor(c.id)) c
    ];
    final hasChildren = children.isNotEmpty;
    final expanded = expandedIds.contains(rule.id);
    final opacity = categoryBranchOpacityForSelection(
      selectedCategoryId: selectedCategoryId,
      nodeId: rule.id,
      depth: depth,
    );
    final label = _labelForRule(rule);
    final color = rule.colorOrDefault;
    final isSelected = selectedCategoryId == rule.id;
    final loc = currentLocale.value;

    final row = AnimatedOpacity(
      duration: _kTreeOpacityDuration,
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(rule.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasChildren)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        expanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: () => onToggleExpand(rule.id),
                    ),
                  )
                else
                  const SizedBox(width: 12),
                Icon(rule.iconOrDefault, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? scheme.primary : color,
                        ),
                  ),
                ),
                if (showEditChrome && onAddChild != null && depth < 4)
                  IconButton(
                    iconSize: 20,
                    tooltip: t(loc, 'add_subcategory'),
                    onPressed: () => onAddChild!(rule),
                    icon: const Icon(Icons.add_rounded),
                  ),
                if (showEditChrome && onAppearanceTap != null)
                  IconButton(
                    iconSize: 20,
                    tooltip: t(loc, 'category_section_appearance'),
                    onPressed: () => onAppearanceTap!(rule),
                    icon: const Icon(Icons.palette_outlined),
                  ),
                if (showEditChrome && onFullSettingsTap != null)
                  IconButton(
                    iconSize: 20,
                    tooltip: t(loc, 'edit_keywords'),
                    onPressed: () => onFullSettingsTap!(rule),
                    icon: const Icon(Icons.settings_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (hasChildren && expanded)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in children)
                  _CategoryTreeNode(
                    rule: c,
                    depth: depth + 1,
                    selectedCategoryId: selectedCategoryId,
                    expandedIds: expandedIds,
                    onToggleExpand: onToggleExpand,
                    onSelect: onSelect,
                    showEditChrome: showEditChrome,
                    onFullSettingsTap: onFullSettingsTap,
                    onAppearanceTap: onAppearanceTap,
                    onAddChild: onAddChild,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Full categories browser: roots only until expanded; active-path opacity.
class CategoryRecursiveBrowsePanel extends StatelessWidget {
  const CategoryRecursiveBrowsePanel({
    super.key,
    required this.selectedCategoryId,
    required this.onSelect,
    required this.onFullSettingsTap,
    required this.onAppearanceTap,
    required this.onAddChild,
    this.editMode = false,
  });

  final int? selectedCategoryId;
  final ValueChanged<int> onSelect;
  final void Function(CategoryRule r) onFullSettingsTap;
  final void Function(CategoryRule r) onAppearanceTap;
  final void Function(CategoryRule parent) onAddChild;
  final bool editMode;

  @override
  Widget build(BuildContext context) {
    final roots = DatabaseService.instance.getChildrenOf(null);
    if (roots.isEmpty) {
      return const SizedBox.shrink();
    }
    return _CategoryTreeBody(
      roots: roots,
      selectedCategoryId: selectedCategoryId,
      expandSelectionPath: true,
      onSelect: onSelect,
      showEditChrome: editMode,
      onFullSettingsTap: onFullSettingsTap,
      onAppearanceTap: onAppearanceTap,
      onAddChild: onAddChild,
    );
  }
}
