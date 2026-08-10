// Recursive category tree body: expand-in-place hierarchy + active-path opacity.

import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:counter/shared/categories/picker/category_picker_models.dart';
import 'package:counter/shared/categories/tree/category_tree_filter.dart';
import 'package:counter/shared/categories/visibility/category_visibility_prefs.dart';
import 'package:flutter/material.dart';

const Duration _kTreeOpacityDuration = Duration(milliseconds: 80);

String _labelForRule(CategoryRule r) {
  final loc = currentLocale.value;
  final raw =
      (r.localizedNames?[loc] ?? r.localizedNames?['en'] ?? r.name).trim();
  return localizeCategoryDbSegment(raw, loc);
}

/// Browse / edit tree used on categories settings and inside picker sheet.
class CategoryTreeBody extends StatefulWidget {
  const CategoryTreeBody({
    super.key,
    required this.roots,
    required this.selectedCategoryId,
    this.expandSelectionPath = false,
    required this.onSelect,
    required this.showEditChrome,
    this.showPickerCreateChrome = false,
    this.showVisibilityCheckboxes = false,
    this.filterHiddenCategories = true,
    this.onVisibilityChanged,
    this.onPickerAddChild,
    this.onFullSettingsTap,
    this.onAppearanceTap,
    this.onAddChild,
  });

  final List<CategoryRule> roots;
  final int? selectedCategoryId;

  /// When false, tree opens fully collapsed.
  final bool expandSelectionPath;
  final ValueChanged<int> onSelect;
  final bool showEditChrome;
  final bool showPickerCreateChrome;

  /// When true, hidden nodes stay in the tree and expose a visibility checkbox.
  /// Descendants of a hidden parent are shown unchecked and disabled until the
  /// parent is made visible again, matching [CategoryVisibilityPrefs] semantics.
  final bool showVisibilityCheckboxes;

  /// Whether normal tree rendering should apply device-local category visibility
  /// preferences. Selection pickers pass false: hidden-from-navigation is not
  /// hidden-from-assignment, so the complete category hierarchy remains usable.
  final bool filterHiddenCategories;
  final void Function(CategoryRule rule, bool visible)? onVisibilityChanged;

  final void Function(CategoryRule parent)? onPickerAddChild;
  final void Function(CategoryRule r)? onFullSettingsTap;
  final void Function(CategoryRule r)? onAppearanceTap;
  final void Function(CategoryRule parent)? onAddChild;

  @override
  State<CategoryTreeBody> createState() => _CategoryTreeBodyState();
}

class _CategoryTreeBodyState extends State<CategoryTreeBody> {
  late Set<int> _expandedIds;

  @override
  void initState() {
    super.initState();
    _expandedIds = widget.expandSelectionPath
        ? _initialExpandedForSelection(widget.selectedCategoryId)
        : <int>{};
  }

  @override
  void didUpdateWidget(covariant CategoryTreeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId ||
        oldWidget.expandSelectionPath != widget.expandSelectionPath ||
        oldWidget.filterHiddenCategories != widget.filterHiddenCategories) {
      setState(() {
        _expandedIds = widget.expandSelectionPath
            ? _initialExpandedForSelection(widget.selectedCategoryId)
            : <int>{};
      });
    }
  }

  Set<int> _allExpandableIds(List<CategoryRule> roots) {
    final out = <int>{};
    void visit(List<CategoryRule> nodes) {
      for (final node in nodes) {
        final children = node.children ?? const <CategoryRule>[];
        if (children.isEmpty) continue;
        out.add(node.id);
        visit(children);
      }
    }

    visit(roots);
    return out;
  }

  Set<int> _initialExpandedForSelection(int? selectedCategoryId) {
    // Assignment/edit pickers disable local hidden-category filtering. In that
    // mode expose the complete hierarchy immediately instead of presenting only
    // root folders behind small chevrons. This behavior is shared by every app
    // platform because the picker itself is shared.
    if (!widget.filterHiddenCategories) {
      return _allExpandableIds(widget.roots);
    }
    if (selectedCategoryId == null) return {};
    final spine = CategoryTreeSource.pathFromRoot(selectedCategoryId);
    if (spine.length <= 1) return {};
    return spine.take(spine.length - 1).toSet();
  }

  void _toggle(int id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
        return;
      }
      final spine = CategoryTreeSource.pathFromRoot(id);
      final ancestors =
          spine.length > 1 ? spine.take(spine.length - 1).toSet() : <int>{};
      _expandedIds = {...ancestors, id};
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
            showPickerCreateChrome: widget.showPickerCreateChrome,
            showVisibilityCheckboxes: widget.showVisibilityCheckboxes,
            filterHiddenCategories: widget.filterHiddenCategories,
            onVisibilityChanged: widget.onVisibilityChanged,
            onPickerAddChild: widget.onPickerAddChild,
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
    this.showPickerCreateChrome = false,
    this.showVisibilityCheckboxes = false,
    this.filterHiddenCategories = true,
    this.onVisibilityChanged,
    this.onPickerAddChild,
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
  final bool showPickerCreateChrome;
  final bool showVisibilityCheckboxes;
  final bool filterHiddenCategories;
  final void Function(CategoryRule rule, bool visible)? onVisibilityChanged;
  final void Function(CategoryRule parent)? onPickerAddChild;
  final void Function(CategoryRule r)? onFullSettingsTap;
  final void Function(CategoryRule r)? onAppearanceTap;
  final void Function(CategoryRule parent)? onAddChild;

  bool _hasHiddenAncestor() {
    final hidden = CategoryVisibilityPrefs.hiddenIds.value.toSet();
    if (hidden.isEmpty) return false;
    final path = CategoryTreeSource.pathFromRoot(rule.id);
    if (path.length <= 1) return false;
    return path.take(path.length - 1).any(hidden.contains);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final childrenRaw = rule.children ?? const <CategoryRule>[];
    final children = showVisibilityCheckboxes || !filterHiddenCategories
        ? childrenRaw
        : [
            for (final c in childrenRaw)
              if (!CategoryVisibilityPrefs.isHiddenOrAncestor(c.id)) c,
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
    final showRowAdd = categoryTreeNodeShowsPickerAddChild(
      showPickerCreateChrome: showPickerCreateChrome,
      onPickerAddChild: onPickerAddChild,
    );
    final hiddenByAncestor = showVisibilityCheckboxes && _hasHiddenAncestor();
    final effectivelyVisible = !CategoryVisibilityPrefs.isHiddenOrAncestor(
      rule.id,
    );

    final row = AnimatedOpacity(
      duration: _kTreeOpacityDuration,
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
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
            if (showVisibilityCheckboxes)
              Checkbox(
                key: ValueKey<String>('category-visibility-${rule.id}'),
                value: effectivelyVisible,
                onChanged: hiddenByAncestor || onVisibilityChanged == null
                    ? null
                    : (value) {
                        if (value == null) return;
                        onVisibilityChanged!(rule, value);
                      },
              ),
            Expanded(
              child: InkWell(
                onTap: () => onSelect(rule.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(rule.iconOrDefault, color: color, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected ? scheme.primary : color,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showRowAdd)
              AppIconButton(
                key: categoryPickerRowAddKey(rule.id),
                icon: Icons.add_rounded,
                tooltip: t(loc, 'add_subcategory'),
                size: AppIconButtonSize.s,
                variant: AppIconButtonVariant.subtle,
                onPressed: () => onPickerAddChild!(rule),
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
    );

    Widget? folderScopedAddRow;
    if (showRowAdd && expanded) {
      folderScopedAddRow = Padding(
        padding: EdgeInsetsDirectional.only(start: 20 + depth * 12.0),
        child: categoryPickerCreateListTile(
          key: categoryPickerFolderAddKey(rule.id),
          label: categoryPickerAddInsideLabel(loc, label),
          onTap: () => onPickerAddChild!(rule),
        ),
      );
    }

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
                    showPickerCreateChrome: showPickerCreateChrome,
                    showVisibilityCheckboxes: showVisibilityCheckboxes,
                    filterHiddenCategories: filterHiddenCategories,
                    onVisibilityChanged: onVisibilityChanged,
                    onPickerAddChild: onPickerAddChild,
                    onFullSettingsTap: onFullSettingsTap,
                    onAppearanceTap: onAppearanceTap,
                    onAddChild: onAddChild,
                  ),
                if (folderScopedAddRow != null) folderScopedAddRow,
              ],
            ),
          ),
      ],
    );
  }
}
