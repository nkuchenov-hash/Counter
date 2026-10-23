import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
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

/// Manage categories without opening a modal for every selection on desktop.
/// Sibling and cross-parent drag use the same 300 ms hold/reorder surface as
/// Planning and Notes. No category-specific drag button or recognizer.
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
  int? _dropInsideCategoryId;
  bool _nestDropHandled = false;

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
      if (_selectedId == r.id && _expanded.contains(r.id)) {
        _expanded.remove(r.id);
      } else {
        _selectedId = r.id;
        _expanded.add(r.id);
      }
    });
  }

  void _beginCategoryDrag(int index, List<_CategoryTreeRow> rows) {
    if (index < 0 || index >= rows.length) return;
    setState(() {
      _draggedCategoryId = rows[index].rule.id;
      _dropInsideCategoryId = null;
      _nestDropHandled = false;
    });
  }

  void _trackCategoryDrop(Offset globalPosition, List<_CategoryTreeRow> rows) {
    final source = _draggedCategoryId;
    if (source == null || _moving) return;
    final invalidIds = DatabaseService.instance.getRecordIdsInSubtree(source);
    int? targetId;
    for (final item in rows) {
      if (invalidIds.contains(item.rule.id)) continue;
      final object = _rowAnchors[item.rule.id]?.currentContext?.findRenderObject();
      if (object is! RenderBox || !object.hasSize) continue;
      final point = object.globalToLocal(globalPosition);
      final size = object.size;
      if (point.dx < 0 || point.dx > size.width ||
          point.dy < 0 || point.dy > size.height) continue;
      // Middle 60% nests into the row. Its top/bottom 20% keeps the
      // ordinary shared ReorderableListView before/after insertion.
      if (point.dy >= size.height * 0.20 &&
          point.dy <= size.height * 0.80) {
        targetId = item.rule.id;
      }
      break;
    }
    if (targetId != _dropInsideCategoryId && mounted) {
      setState(() => _dropInsideCategoryId = targetId);
    }
  }

  void _finishCategoryDrag() {
    final source = _draggedCategoryId;
    final target = _dropInsideCategoryId;
    if (!_nestDropHandled && source != null && target != null) {
      _nestDropHandled = true;
      unawaited(_nestCategory(source, target));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _draggedCategoryId = null;
        _dropInsideCategoryId = null;
      });
    });
  }

  Future<void> _nestCategory(int categoryId, int targetParentId) async {
    if (_moving) return;
    final db = DatabaseService.instance;
    if (db.getRecordIdsInSubtree(categoryId).contains(targetParentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'category_move_invalid'))),
      );
      return;
    }
    final previousParent = db.getParentId(categoryId);
    if (previousParent == targetParentId) {
      setState(() => _expanded.add(targetParentId));
      return;
    }
    final previousOrder = db.getChildrenOf(previousParent)
        .map((rule) => rule.id).toList();
    setState(() {
      _moving = true;
      _expanded.add(targetParentId);
    });
    final saved = await db.updateCategoryParent(categoryId, targetParentId);
    if (!mounted) return;
    setState(() => _moving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
      );
      return;
    }
    unawaited(widget.onChanged());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(currentLocale.value, 'category_moved')),
        action: SnackBarAction(
          label: t(currentLocale.value, 'undo'),
          onPressed: () => unawaited(
            _undoParentMove(categoryId, previousParent, previousOrder),
          ),
        ),
      ),
    );
  }

  // AppReorderableList is also used in Paths and Planning. Its flat insertion
  // index picks the receiving sibling group, including expanded child groups.
  // The Brain retains ownership of the parent relation and order persistence.
  Future<void> _onReorder(
    int oldIndex,
    int newIndex,
    List<_CategoryTreeRow> visible,
  ) async {
    if (_moving || oldIndex < 0 || oldIndex >= visible.length) return;
    final moved = visible[oldIndex];
    // A center drop changes the parent, even when Flutter reports no
    // positional reorder. The end callback is a fallback for that case.
    if (_nestDropHandled && _draggedCategoryId == moved.rule.id) return;
    final nestedTarget = _dropInsideCategoryId;
    if (_draggedCategoryId == moved.rule.id && nestedTarget != null) {
      _nestDropHandled = true;
      await _nestCategory(moved.rule.id, nestedTarget);
      return;
    }
    var targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final remaining = List<_CategoryTreeRow>.of(visible)..removeAt(oldIndex);
    targetIndex = targetIndex.clamp(0, remaining.length).toInt();
    if (targetIndex == oldIndex) return;
    final target = targetIndex < remaining.length
        ? remaining[targetIndex]
        : (remaining.isEmpty ? null : remaining.last);
    // The end of the whole tree is a root-level drop, never an implicit
    // move inside the final visible nested branch.
    final destinationParent =
        targetIndex == remaining.length ? null : target?.parentId;
    final db = DatabaseService.instance;

    // A category cannot be its own parent, nor be nested below a descendant.
    final subtree = db.getRecordIdsInSubtree(moved.rule.id).toSet();
    if (destinationParent == moved.rule.id ||
        (destinationParent != null && subtree.contains(destinationParent))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'category_move_invalid')),
        ),
      );
      return;
    }

    final oldParent = db.getParentId(moved.rule.id);
    final originalOrder = db.getChildrenOf(oldParent).map((r) => r.id).toList();
    final before = db.getChildrenOf(destinationParent);
    final siblings = List<CategoryRule>.from(before)
      ..removeWhere((r) => r.id == moved.rule.id);
    int insertAt;
    if (targetIndex == remaining.length || target == null) {
      insertAt = siblings.length;
    } else {
      final targetSiblingIndex =
          siblings.indexWhere((r) => r.id == target.rule.id);
      insertAt = targetSiblingIndex < 0
          ? siblings.length
          : targetSiblingIndex;
    }
    siblings.insert(insertAt, moved.rule);

    if (oldParent == destinationParent) {
      db.applyLocalCategorySiblingOrder(destinationParent, siblings);
      _redraw();
      unawaited(db.persistCategorySiblingOrder(
        destinationParent,
        siblings,
        baselineBeforeReorder: before,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'category_moved')),
          action: SnackBarAction(
            label: t(currentLocale.value, 'undo'),
            onPressed: () {
              db.applyLocalCategorySiblingOrder(destinationParent, before);
              _redraw();
              unawaited(db.persistCategorySiblingOrder(
                destinationParent,
                before,
                baselineBeforeReorder: siblings,
              ));
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _moving = true;
      if (destinationParent != null) _expanded.add(destinationParent);
    });
    // The Brain applies the parent change synchronously to its optimistic
    // cache before the first await; reordering the new siblings immediately
    // also feeds its post-parent-move order persistence.
    final moving = db.updateCategoryParent(moved.rule.id, destinationParent);
    db.applyLocalCategorySiblingOrder(destinationParent, siblings);
    _redraw();
    final ok = await moving;
    if (!mounted) return;
    setState(() => _moving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'category_moved')),
          action: SnackBarAction(
            label: t(currentLocale.value, 'undo'),
            onPressed: () => unawaited(_undoParentMove(
              moved.rule.id,
              oldParent,
              originalOrder,
            )),
          ),
        ),
      );
    }
    unawaited(widget.onChanged());
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
    return AppHoldToReorderListener(
      index: index,
      child: Material(
        key: _rowAnchors.putIfAbsent(r.id, () => GlobalKey()),
        color: _dropInsideCategoryId == r.id
            ? tint.withValues(alpha: 0.19)
            : (selected ? tint.withValues(alpha: 0.07) : scheme.surface),
        elevation: _dropInsideCategoryId == r.id ? 2 : 0,
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
                  : Listener(
                      onPointerMove: (event) =>
                          _trackCategoryDrop(event.position, visible),
                      onPointerUp: (event) =>
                          _trackCategoryDrop(event.position, visible),
                      child: AppReorderableList(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      spacing: 4,
                      itemCount: visible.length,
                      onReorderStart: (index) =>
                          _beginCategoryDrag(index, visible),
                      onReorderEnd: (_) => _finishCategoryDrag(),
                      itemKeyBuilder: (index) =>
                          ValueKey('category-tree-${visible[index].rule.id}'),
                      dragLabelBuilder: (index) =>
                          t(loc, 'category_reorder'),
                      // Deliberately no drag affordance; holding the row
                      // starts the same reorder gesture as Plans and Notes.
                      dragHandleBuilder: (_, _) => const SizedBox.shrink(),
                      onReorder: (oldIndex, newIndex) =>
                          unawaited(_onReorder(oldIndex, newIndex, visible)),
                      itemBuilder: (context, index, _) =>
                          _row(context, visible[index], index, wide),
                      ),
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
