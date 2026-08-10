import 'dart:async';

import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:counter/shared/categories/picker/create_category_from_picker.dart';
import 'package:counter/shared/categories/tree/category_tree_body.dart';
import 'package:counter/shared/categories/tree/category_tree_filter.dart';
import 'package:counter/shared/categories/visibility/category_visibility_prefs.dart';
import 'package:flutter/material.dart';

export 'package:counter/shared/categories/picker/category_picker_models.dart'
    show
        CategoryTreeSheetAll,
        CategoryTreeSheetPicked,
        CategoryTreeSheetResult,
        categoryPickerAddInsideLabel,
        categoryPickerBottomAddKey,
        categoryPickerCreateListTile,
        categoryPickerFolderAddKey,
        categoryPickerRowAddKey,
        categoryPickerTopAddKey,
        categoryTreeNodeShowsPickerAddChild;
export 'package:counter/shared/categories/tree/category_tree_filter.dart'
    show
        categoryBranchOpacityForSelection,
        filterCategoryRootsForPickerSearch;

String _labelForRule(CategoryRule r) {
  final loc = currentLocale.value;
  final raw =
      (r.localizedNames?[loc] ?? r.localizedNames?['en'] ?? r.name).trim();
  return localizeCategoryDbSegment(raw, loc);
}

Future<CategoryTreeSheetResult?> showCategoryTreeSheet(
  BuildContext context, {
  int? initialCategoryId,
  bool showAllCategoriesRow = false,
  bool showVisibilityControls = false,
}) {
  return showModalBottomSheet<CategoryTreeSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final sheetHeight =
          (MediaQuery.sizeOf(ctx).height * 0.82).clamp(320.0, 720.0);
      return SizedBox(
        height: sheetHeight,
        child: _CategoryTreePickerSheet(
          initialCategoryId: initialCategoryId,
          showAllCategoriesRow: showAllCategoriesRow,
          showVisibilityControls: showVisibilityControls,
        ),
      );
    },
  );
}

class _CategoryTreePickerSheet extends StatefulWidget {
  const _CategoryTreePickerSheet({
    required this.initialCategoryId,
    required this.showAllCategoriesRow,
    required this.showVisibilityControls,
  });

  final int? initialCategoryId;
  final bool showAllCategoriesRow;
  final bool showVisibilityControls;

  @override
  State<_CategoryTreePickerSheet> createState() =>
      _CategoryTreePickerSheetState();
}

class _CategoryTreePickerSheetState extends State<_CategoryTreePickerSheet> {
  late final TextEditingController _searchController;
  StreamSubscription<List<CategoryRule>>? _catSub;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
    unawaited(
      CategoryVisibilityPrefs.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }),
    );
    _catSub = CategoryTreeSource.watchCategories().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryRule> get _visibleRoots {
    // Assignment/edit pickers always expose the complete active category tree.
    // Local visibility preferences only control navigation/presentation.
    final roots = CategoryTreeSource.childrenOf(null);
    return filterCategoryRootsForPickerSearch(roots, _query, _labelForRule);
  }

  bool get _hasSearchMatch => _visibleRoots.isNotEmpty;

  bool get _canCreate => categoryCreateFromPickerAllowed();

  String? get _offlineCreateHint {
    if (_canCreate) return null;
    return t(currentLocale.value, 'category_create_requires_connection');
  }

  Future<void> _createCategory({
    String? initialName,
    required CategoryPickerCreateTarget target,
  }) async {
    final id = await showCreateCategoryFromPickerDialog(
      context,
      initialName: initialName,
      target: target,
    );
    if (!mounted || id == null) return;
    Navigator.of(context).pop(CategoryTreeSheetPicked(id));
  }

  void _onRootAddCategory() {
    unawaited(_createCategory(target: const CategoryPickerCreateTarget.root()));
  }

  void _onPickerAddChild(CategoryRule parent) {
    unawaited(
      _createCategory(
        target: CategoryPickerCreateTarget.child(
          parentLocalId: parent.id,
          parentDisplayName: _labelForRule(parent),
        ),
      ),
    );
  }

  Future<void> _setCategoryVisible(CategoryRule rule, bool visible) async {
    await CategoryVisibilityPrefs.ensureLoaded();
    final directlyHidden = CategoryVisibilityPrefs.hiddenIds.value.contains(
      rule.id,
    );
    if ((visible && directlyHidden) || (!visible && !directlyHidden)) {
      await CategoryVisibilityPrefs.toggle(rule.id);
    }
    if (mounted) setState(() {});
  }

  void _selectCategory(int id) {
    if (widget.showVisibilityControls &&
        CategoryVisibilityPrefs.isHiddenOrAncestor(id)) {
      return;
    }
    Navigator.of(context).pop(CategoryTreeSheetPicked(id));
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final roots = _visibleRoots;
    final trimmedQuery = _query.trim();
    final showNamedCreate = trimmedQuery.isNotEmpty && !_hasSearchMatch;
    final offlineHint = _offlineCreateHint;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              t(loc, 'category_label'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: t(loc, 'category_label'),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          categoryPickerCreateListTile(
            key: categoryPickerTopAddKey,
            label: t(loc, 'category_picker_add_root'),
            subtitle: offlineHint,
            onTap: _canCreate ? _onRootAddCategory : null,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              children: [
                if (widget.showAllCategoriesRow)
                  ListTile(
                    title: Text(t(loc, 'lists_filter_all')),
                    leading: const Icon(Icons.filter_alt_off_rounded),
                    onTap: () =>
                        Navigator.of(context).pop(CategoryTreeSheetAll()),
                  ),
                if (showNamedCreate)
                  categoryPickerCreateListTile(
                    key: const ValueKey<String>('category_picker_named_create'),
                    label: t(loc, 'category_picker_create_named')
                        .replaceFirst('%s', trimmedQuery),
                    subtitle: offlineHint,
                    onTap: _canCreate
                        ? () => unawaited(
                              _createCategory(
                                initialName: trimmedQuery,
                                target: const CategoryPickerCreateTarget.root(),
                              ),
                            )
                        : null,
                  ),
                if (roots.isEmpty && !showNamedCreate)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      t(loc, 'category_picker_empty_hint'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  CategoryTreeBody(
                    roots: roots,
                    selectedCategoryId: widget.initialCategoryId,
                    expandSelectionPath: false,
                    onSelect: _selectCategory,
                    showEditChrome: false,
                    showPickerCreateChrome: true,
                    showVisibilityCheckboxes: widget.showVisibilityControls,
                    filterHiddenCategories: false,
                    onVisibilityChanged: widget.showVisibilityControls
                        ? (rule, visible) =>
                              unawaited(_setCategoryVisible(rule, visible))
                        : null,
                    onPickerAddChild: _canCreate ? _onPickerAddChild : null,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          categoryPickerCreateListTile(
            key: categoryPickerBottomAddKey,
            label: t(loc, 'category_picker_add_root'),
            subtitle: offlineHint,
            onTap: _canCreate ? _onRootAddCategory : null,
          ),
        ],
      ),
    );
  }
}

/// Picker sheet: returns chosen category id, or null if dismissed unchanged.
Future<int?> showCategoryTreePicker(
  BuildContext context, {
  int? initialCategoryId,
}) async {
  final r = await showCategoryTreeSheet(
    context,
    initialCategoryId: initialCategoryId,
    showAllCategoriesRow: false,
  );
  if (r is CategoryTreeSheetPicked) return r.id;
  return null;
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
    final pathText = value != null && CategoryTreeSource.exists(value!)
        ? CategoryTreeSource.pathLabel(value!)
        : null;

    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final r = await showCategoryTreeSheet(
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
