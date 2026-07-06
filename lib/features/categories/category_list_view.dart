import 'dart:async';

import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_appearance_sheet.dart';
import 'package:counter/features/categories/category_editor_sheet.dart';
import 'package:counter/features/categories/category_row_widget.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/categories/create_category_dialog.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

export 'package:counter/features/categories/category_editor_sheet.dart'
    show CategoryEditorSheet;
export 'package:counter/features/categories/category_row_widget.dart'
    show CategoryBandLayout, CategoryRowWidget;
export 'package:counter/features/categories/category_tag_input_field.dart'
    show TagInputField;

// ---------------------------------------------------------------------------
// CATEGORIES FEATURE — UI_ISOLATION (§7). All strings via t() from dictionary.
// No hardcoded UI text. No direct DB writes (use DatabaseService).
// ---------------------------------------------------------------------------

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
    CategoryVisibilityPrefs.hiddenIds.removeListener(
      _categoryVisibilityListener,
    );
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
    final after = List<CategoryRule>.from(
      DatabaseService.instance.getChildrenOf(parentId),
    );
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
        final path = DatabaseService.instance.categoryPathFromRootToLocalId(
          localId,
        );
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
      builder: (ctx) => CategoryAppearanceSheet(
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

  Widget buildTabRow(
    BuildContext context,
    int depth,
    List<CategoryRule> items,
  ) {
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
    final nextItems = hasSelection
        ? _getItemsForDepth(depth + 1)
        : <CategoryRule>[];

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
      builder: (context, _, _) {
        final roots = _getItemsForDepth(0);
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(t(loc, 'categories_title')),
            actions: [
              AppIconButton(
                icon: _useHorizontalScrollLayout
                    ? Icons.grid_view_rounded
                    : Icons.view_week_rounded,
                tooltip: _useHorizontalScrollLayout
                    ? t(loc, 'switch_to_wrap')
                    : t(loc, 'switch_to_scrollable'),
                onPressed: () => setState(
                  () =>
                      _useHorizontalScrollLayout = !_useHorizontalScrollLayout,
                ),
              ),
              AppIconButton(
                tooltip: t(loc, 'add_category'),
                onPressed: () => unawaited(_addRule()),
                icon: Icons.add_rounded,
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
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
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
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