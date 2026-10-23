import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_editor_sheet.dart';
import 'package:counter/features/settings/categories/category_helpers.dart';
import 'package:counter/features/settings/categories/category_row_widget.dart';
import 'package:counter/features/settings/categories/create_category_dialog.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

export 'package:counter/features/settings/categories/category_editor_sheet.dart'
    show CategoryEditorSheet;
export 'package:counter/features/settings/categories/category_row_widget.dart'
    show CategoryBandLayout, CategoryRowWidget;
export 'package:counter/features/settings/categories/category_tag_input_field.dart'
    show TagInputField;

/// One visible category row; the tree itself remains owned by the Brain.
class _CategoryTreeRow {
  const _CategoryTreeRow(this.rule, this.parentId, this.depth);
  final CategoryRule rule;
  final int? parentId;
  final int depth;
}

/// Stable categories drag model: the target does not move before drop.
enum CategoryDropPosition { before, inside, after }

CategoryDropPosition categoryDropPositionFor(double y, double height) {
  if (height <= 0) return CategoryDropPosition.inside;
  final fraction = y / height;
  if (fraction < 0.22) return CategoryDropPosition.before;
  if (fraction > 0.78) return CategoryDropPosition.after;
  return CategoryDropPosition.inside;
}

/// Manage categories with stationary long-press drop targets.
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
  final TextEditingController _search = TextEditingController();
  final Set<int> _expanded = <int>{};
  StreamSubscription<List<CategoryRule>>? _categoriesSubscription;
  int? _selectedId;
  bool _moving = false;
  final Map<int, GlobalKey> _rowAnchors = <int, GlobalKey>{};
  int? _draggedCategoryId;
  int? _dropTargetCategoryId;
  CategoryDropPosition? _dropPosition;

  @override
  void initState() {
    super.initState();
    _search.addListener(_redraw);
    _categoriesSubscription = DatabaseService.instance.categoryStream.listen(
      (_) => _redraw(),
    );
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    _search.removeListener(_redraw);
    _search.dispose();
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  Future<void> _notifyChanged() async {
    if (!mounted) return;
    setState(() {});
    unawaited(widget.onChanged());
  }

  List<_CategoryTreeRow> _visibleRows() {
    final query = _search.text.trim().toLowerCase();
    final result = <_CategoryTreeRow>[];

    bool matches(CategoryRule r) {
      if (categoryTileLabel(r).toLowerCase().contains(query) ||
          r.name.toLowerCase().contains(query)) {
        return true;
      }
      return (r.children ?? <CategoryRule>[]).any(matches);
    }

    void collect(CategoryRule rule, int? parentId, int depth) {
      if (rule.id == -1) return;
      if (query.isNotEmpty && !matches(rule)) return;
      result.add(_CategoryTreeRow(rule, parentId, depth));
      if (query.isNotEmpty || _expanded.contains(rule.id)) {
        for (final child in rule.children ?? <CategoryRule>[]) {
          collect(child, rule.id, depth + 1);
        }
      }
    }

    for (final root in DatabaseService.instance.getChildrenOf(null)) {
      collect(root, null, 0);
    }
    return result;
  }

  Future<void> _create({int? parentId}) async {
    await showCreateCategoryDialog(
      context: context,
      parentId: parentId,
      onGoToActiveCategory: (id) {
        final path = DatabaseService.instance.categoryPathFromRootToLocalId(id);
        if (!mounted) return;
        setState(() {
          _expanded.addAll(path);
          _selectedId = id;
        });
      },
      onDone: _notifyChanged,
    );
    if (parentId != null && mounted) {
      setState(() => _expanded.add(parentId));
    }
  }

  void _deleted(int id) {
    if (!mounted) return;
    setState(() {
      if (_selectedId == id) _selectedId = null;
      _expanded.remove(id);
      _rowAnchors.remove(id);
    });
  }

  Future<void> _moveCategoryWithPicker(CategoryRule rule) async {
    final result = await showCategoryTreeSheet(context, showAllCategoriesRow: true);
    if (!mounted || result == null) return;
    final destination = switch (result) {
      CategoryTreeSheetPicked(:final id) => id,
      CategoryTreeSheetAll() => null,
    };
    final db = DatabaseService.instance;
    if (destination != null &&
        db.getRecordIdsInSubtree(rule.id).contains(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'category_move_invalid'))),
      );
      return;
    }
    final previous = db.getParentId(rule.id);
    if (previous == destination) return;
    final ok = await db.updateCategoryParent(rule.id, destination);
    if (!mounted) return;
    if (ok) {
      if (destination != null) setState(() => _expanded.add(destination));
      unawaited(_notifyChanged());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'category_moved')),
          action: SnackBarAction(
            label: t(currentLocale.value, 'undo'),
            onPressed: () => unawaited(db.updateCategoryParent(rule.id, previous)),
          )),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
      );
    }
  }

  Future<void> _deleteCategory(CategoryRule rule) async {
    final locale = currentLocale.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(locale, 'delete_category_confirm')),
        content: Text(t(locale, 'delete_subcategories_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(locale, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t(locale, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await DatabaseService.instance.deleteCategory(rule.id);
    if (!mounted) return;
    if (ok) {
      _deleted(rule.id);
      unawaited(_notifyChanged());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(locale, 'category_removed'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(locale, 'sync_failed'))),
      );
    }
  }

  void _editOnPhone(CategoryRule rule) {
    setState(() => _selectedId = rule.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.94,
        child: CategoryEditorSheet(
          key: ValueKey('category-editor-mobile-${rule.id}'),
          category: rule,
          onSaved: () => unawaited(_notifyChanged()),
          onCategoryDeleted: () => _deleted(rule.id),
        ),
      ),
    );
  }

  void _toggleAllCategories() {
    setState(() {
      if (_expanded.isNotEmpty || _search.text.trim().isNotEmpty) {
        _expanded.clear();
        if (_search.text.isNotEmpty) _search.clear();
      } else {
        void visit(List<CategoryRule> rows) {
          for (final rule in rows) {
            if ((rule.children ?? <CategoryRule>[]).isNotEmpty) {
              _expanded.add(rule.id);
              visit(rule.children!);
            }
          }
        }
        visit(DatabaseService.instance.getChildrenOf(null));
      }
    });
  }

  void _toggle(int id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  void _select(CategoryRule r, bool wide) {
    if (!wide) {
      if ((r.children ?? <CategoryRule>[]).isNotEmpty) {
        setState(() {
          _selectedId = r.id;
          if (!_expanded.remove(r.id)) _expanded.add(r.id);
        });
      } else {
        _editOnPhone(r);
      }
      return;
    }
    setState(() {
      final hasChildren = (r.children ?? <CategoryRule>[]).isNotEmpty;
      if (hasChildren &&
          _selectedId == r.id &&
          _expanded.contains(r.id)) {
        _expanded.remove(r.id);
      } else {
        _selectedId = r.id;
        if (hasChildren) _expanded.add(r.id);
      }
    });
  }

  void _startCategoryDrag(int sourceId) {
    if (!mounted || _moving) return;
    setState(() {
      _draggedCategoryId = sourceId;
      _dropTargetCategoryId = null;
      _dropPosition = null;
    });
  }

  void _endCategoryDrag() {
    if (!mounted) return;
    if (_draggedCategoryId == null && _dropTargetCategoryId == null) return;
    setState(() {
      _draggedCategoryId = null;
      _dropTargetCategoryId = null;
      _dropPosition = null;
    });
  }

  CategoryDropPosition? _positionForDrop(int targetId, Offset global) {
    final object = _rowAnchors[targetId]?.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    final local = object.globalToLocal(global);
    if (local.dx < 0 || local.dx > object.size.width ||
        local.dy < 0 || local.dy > object.size.height) return null;
    return categoryDropPositionFor(local.dy, object.size.height);
  }

  bool _canDropOn(int sourceId, int targetId) {
    if (_moving || sourceId == targetId) return false;
    final db = DatabaseService.instance;
    return db.getCategoryRuleById(sourceId) != null &&
        db.getCategoryRuleById(targetId) != null &&
        !db.getRecordIdsInSubtree(sourceId).contains(targetId);
  }

  // Read the real finger/mouse position against the original, stationary
  // render boxes. No Flutter reorder placeholder or DragTarget event race.
  void _trackDropPointer(int source, Offset global) {
    if (!mounted || _moving) return;
    int? target;
    CategoryDropPosition? position;
    for (final row in _visibleRows()) {
      if (!_canDropOn(source, row.rule.id)) continue;
      final candidate = _positionForDrop(row.rule.id, global);
      if (candidate == null) continue;
      target = row.rule.id;
      position = candidate;
      break;
    }
    if (_dropTargetCategoryId == target && _dropPosition == position) return;
    setState(() {
      _dropTargetCategoryId = target;
      _dropPosition = position;
    });
  }

  void _completeCategoryDrag(int source) {
    final target = _dropTargetCategoryId;
    final position = _dropPosition;
    _endCategoryDrag();
    if (target == null || position == null || !_canDropOn(source, target)) {
      return;
    }
    unawaited(_commitDrop(source, target, position));
  }

  Future<void> _commitDrop(
    int source,
    int target,
    CategoryDropPosition position,
  ) async {
    if (!_canDropOn(source, target)) return;
    final db = DatabaseService.instance;
    final oldParent = db.getParentId(source);
    final newParent = position == CategoryDropPosition.inside
        ? target : db.getParentId(target);
    if (newParent != null &&
        db.getRecordIdsInSubtree(source).contains(newParent)) return;
    if (oldParent == newParent && position == CategoryDropPosition.inside) {
      setState(() => _expanded.add(target));
      return;
    }

    final previousOrder = db.getChildrenOf(oldParent).map((r) => r.id).toList();
    final before = db.getChildrenOf(newParent);
    if (oldParent == newParent) {
      final ordered = List<CategoryRule>.from(before)
        ..removeWhere((r) => r.id == source);
      final index = ordered.indexWhere((r) => r.id == target);
      if (index < 0) return;
      ordered.insert(index + (position == CategoryDropPosition.after ? 1 : 0),
          db.getCategoryRuleById(source)!);
      if (ordered.map((r) => r.id).join(',') ==
          before.map((r) => r.id).join(',')) return;
      db.applyLocalCategorySiblingOrder(newParent, ordered);
      _redraw();
      unawaited(db.persistCategorySiblingOrder(
        newParent, ordered, baselineBeforeReorder: before,
      ));
      _showDropUndo(source, oldParent, previousOrder);
      return;
    }

    setState(() {
      _moving = true;
      if (newParent != null) _expanded.add(newParent);
    });
    // updateCategoryParent mutates the Brain cache synchronously, before I/O.
    final moving = db.updateCategoryParent(source, newParent);
    if (position != CategoryDropPosition.inside) {
      final ordered = List<CategoryRule>.from(db.getChildrenOf(newParent))
        ..removeWhere((r) => r.id == source);
      final index = ordered.indexWhere((r) => r.id == target);
      if (index >= 0) {
        ordered.insert(index + (position == CategoryDropPosition.after ? 1 : 0),
            db.getCategoryRuleById(source)!);
        db.applyLocalCategorySiblingOrder(newParent, ordered);
      }
    }
    final ok = await moving;
    if (!mounted) return;
    setState(() => _moving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))));
      return;
    }
    unawaited(widget.onChanged());
    _showDropUndo(source, oldParent, previousOrder);
  }

  void _showDropUndo(int source, int? originalParent, List<int> order) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(currentLocale.value, 'category_moved')),
        action: SnackBarAction(
          label: t(currentLocale.value, 'undo'),
          onPressed: () => unawaited(
            _undoParentMove(source, originalParent, order),
          ),
        ),
      ),
    );
  }

  Future<void> _undoParentMove(
    int categoryId,
    int? previousParent,
    List<int> originalOrder,
  ) async {
    if (_moving) return;
    final db = DatabaseService.instance;
    setState(() => _moving = true);
    final rollback = db.updateCategoryParent(categoryId, previousParent);
    final siblings = db.getChildrenOf(previousParent);
    final restored = List<CategoryRule>.from(siblings)
      ..sort((a, b) {
        final left = originalOrder.indexOf(a.id);
        final right = originalOrder.indexOf(b.id);
        return (left < 0 ? originalOrder.length : left)
            .compareTo(right < 0 ? originalOrder.length : right);
      });
    db.applyLocalCategorySiblingOrder(previousParent, restored);
    _redraw();
    final ok = await rollback;
    if (!mounted) return;
    setState(() => _moving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
      );
    }
    unawaited(widget.onChanged());
  }

  Widget _row(
    BuildContext context,
    _CategoryTreeRow item,
    int index,
    bool wide,
  ) {
    final r = item.rule;
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedId == r.id;
    final hasChildren = (r.children ?? <CategoryRule>[]).isNotEmpty;
    final tint = r.colorOrDefault;
    final loc = currentLocale.value;
    final dropPosition = _dropTargetCategoryId == r.id ? _dropPosition : null;
    final tile = Material(
        key: _rowAnchors.putIfAbsent(r.id, () => GlobalKey()),
        color: dropPosition == CategoryDropPosition.inside
            ? tint.withValues(alpha: 0.15)
            : (selected ? tint.withValues(alpha: 0.07) : scheme.surface),
        elevation: 0,
        shadowColor: tint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _select(r, wide),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: EdgeInsets.only(
                left: 10 + item.depth * 16.0,
                right: 4,
              ),
              child: Row(
                children: [
                   Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(categoryManagerIconFor(r), color: tint, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryTileLabel(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hasChildren)
                    AppIconButton(
                      icon: _expanded.contains(r.id) || _search.text.isNotEmpty
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      tooltip: t(loc, 'category_expand_children'),
                      onPressed: () => _toggle(r.id),
                    ),
                  PopupMenuButton<String>(
                    tooltip: t(loc, 'category_actions'),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                    onSelected: (action) {
                      if (action == 'add') {
                        unawaited(_create(parentId: r.id));
                      } else if (action == 'edit') {
                        if (wide) {
                          _select(r, true);
                        } else {
                          _editOnPhone(r);
                        }
                      } else if (action == 'move') {
                        unawaited(_moveCategoryWithPicker(r));
                      } else if (action == 'delete') {
                        unawaited(_deleteCategory(r));
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(t(loc, 'edit_category')),
                      ),
                      PopupMenuItem(
                        value: 'add',
                        child: Text(t(loc, 'add_subcategory')),
                      ),
                      PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(t(loc, 'category_move_to')),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                              size: 20, color: scheme.error),
                            const SizedBox(width: 8),
                            Text(t(loc, 'delete_category'),
                              style: TextStyle(color: scheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    );
    return LongPressDraggable<int>(
        key: ValueKey('category-drag-source-${r.id}'),
        data: r.id,
        delay: const Duration(milliseconds: 300),
        maxSimultaneousDrags: _moving ? 0 : 1,
        onDragStarted: () => _startCategoryDrag(r.id),
        onDragUpdate: (details) =>
            _trackDropPointer(r.id, details.globalPosition),
        onDragEnd: (_) => _completeCategoryDrag(r.id),
        feedback: Material(
          color: scheme.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 260,
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tint, width: 2),
            ),
            child: Row(children: [
              Icon(categoryManagerIconFor(r), color: tint),
              const SizedBox(width: 12),
              Expanded(child: Text(
                categoryTileLabel(r),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              )),
            ]),
          ),
        ),
        child: Stack(
          children: [
            Opacity(
              opacity: _draggedCategoryId == r.id ? .35 : 1,
              child: tile,
            ),
            if (dropPosition != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: dropPosition == CategoryDropPosition.inside
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tint, width: 2.5),
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 60),
                              child: Icon(Icons.subdirectory_arrow_right_rounded,
                                  color: tint),
                            ),
                          ),
                        )
                      : Align(
                          alignment: dropPosition == CategoryDropPosition.before
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: tint,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
    );
  }

  Widget _treePanel(bool wide) {
    final loc = currentLocale.value;
    final visible = _visibleRows();
    final allEmpty = DatabaseService.instance.getChildrenOf(null).isEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t(loc, 'category_search'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: t(loc, 'clear'),
                            onPressed: _search.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: t(loc, _expanded.isEmpty && _search.text.isEmpty
                    ? 'category_expand_all' : 'category_collapse_all'),
                icon: Icon(
                  _expanded.isEmpty && _search.text.isEmpty
                      ? Icons.unfold_more_rounded
                      : Icons.unfold_less_rounded,
                ),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                onPressed: _toggleAllCategories,
              ),
            ],
          ),
        ),
        Expanded(
          child: allEmpty
              ? EmptyStatePlaceholder(
                  icon: Icons.folder_outlined,
                  titleL10nKey: 'empty_categories_title',
                  subtitleL10nKey: 'empty_categories_subtitle',
                  actionLabelL10nKey: 'add_category',
                  onAction: () => unawaited(_create()),
                  useFilledAction: true,
                )
              : visible.isEmpty
                  ? Center(child: Text(t(loc, 'category_search_empty')))
                  : ListView.separated(
                      key: const ValueKey('category-stationary-tree'),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) =>
                          _row(context, visible[index], index, wide),
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = shellUsesSideNavigation(width);
    final loc = currentLocale.value;
    final selected = _selectedId == null
        ? null
        : DatabaseService.instance.getCategoryRuleById(_selectedId!);
    final controls = AppIconButton(
      tooltip: t(loc, 'add_category'),
      icon: Icons.add_rounded,
      onPressed: () => unawaited(_create()),
    );

    return Scaffold(
      appBar: wide ? null : AppBar(
        title: Text(t(loc, 'categories_title')),
        actions: [controls, const SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: !wide,
        child: Column(
          children: [
            if (wide) ...[
              AppDesktopSectionControlRow(
                title: t(loc, 'categories_title'),
                controls: AppIconButton(
                  tooltip: t(loc, 'add_category'),
                  icon: Icons.add_rounded,
                  onPressed: () => unawaited(_create()),
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: wide
                  ? LayoutBuilder(builder: (context, constraints) {
                      final leftWidth =
                          (constraints.maxWidth * 0.37).clamp(300.0, 430.0);
                      return Row(
                        children: [
                          SizedBox(
                            width: leftWidth,
                            child: _treePanel(true),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: selected == null
                                ? Center(
                                    child: Text(
                                      t(loc, 'category_select_to_edit'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                  )
                                : CategoryEditorSheet(
                                    key: ValueKey(
                                      'category-editor-desktop-${selected.id}',
                                    ),
                                    category: selected,
                                    inline: true,
                                    onCancel: () => setState(() => _selectedId = null),
                                    onSaved: () =>
                                        unawaited(_notifyChanged()),
                                    onCategoryDeleted: () =>
                                        _deleted(selected.id),
                                  ),
                          ),
                        ],
                      );
                    })
                  : _treePanel(false),
            ),
          ],
        ),
      ),
    );
  }
}
