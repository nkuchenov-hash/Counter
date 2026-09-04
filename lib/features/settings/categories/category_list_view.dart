import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_editor_sheet.dart';
import 'package:counter/features/settings/categories/category_row_widget.dart';
import 'package:counter/features/settings/categories/create_category_dialog.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

export 'package:counter/features/settings/categories/category_editor_sheet.dart'
    show CategoryEditorSheet;
export 'package:counter/features/settings/categories/category_row_widget.dart'
    show CategoryBandLayout, CategoryRowWidget;
export 'package:counter/features/settings/categories/category_tag_input_field.dart'
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
  bool _useHorizontalScrollLayout = false;
  static const int _maxDepth = 4;

  Future<void> _notifyChanged() async {
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  List<CategoryRule> _getItemsForDepth(int depth) {
    if (depth == 0) {
      return DatabaseService.instance.getChildrenOf(null);
    }
    final parentId = _selectedPath[depth - 1];
    if (parentId == null) return [];
    return DatabaseService.instance.getChildrenOf(parentId);
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
      onLongPressOpenEditor: (r) => _showCategoryEditorSheet(context, r),
      layout: _useHorizontalScrollLayout
          ? CategoryBandLayout.horizontalPeek
          : CategoryBandLayout.wrapGrid,
      showAdd: canAddAtThisLevel,
      onAddTap: () => unawaited(_addSubcategoryAtDepth(depth)),
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
    final loc = currentLocale.value;
    final roots = _getItemsForDepth(0);
    final desktopShell = shellUsesSideNavigation(
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: desktopShell
          ? null
          : AppBar(
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
                    () => _useHorizontalScrollLayout =
                        !_useHorizontalScrollLayout,
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
        top: !desktopShell,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (desktopShell)
              AppDesktopSectionControlRow(
                title: t(loc, 'categories_title'),
                controls: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton(
                      icon: _useHorizontalScrollLayout
                          ? Icons.grid_view_rounded
                          : Icons.view_week_rounded,
                      tooltip: _useHorizontalScrollLayout
                          ? t(loc, 'switch_to_wrap')
                          : t(loc, 'switch_to_scrollable'),
                      onPressed: () => setState(
                        () => _useHorizontalScrollLayout =
                            !_useHorizontalScrollLayout,
                      ),
                    ),
                    AppIconButton(
                      tooltip: t(loc, 'add_category'),
                      onPressed: () => unawaited(_addRule()),
                      icon: Icons.add_rounded,
                    ),
                  ],
                ),
              ),
            if (desktopShell) const Divider(height: 1),
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
  }
}
