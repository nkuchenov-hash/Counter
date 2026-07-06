// Recursive category tree: expand-in-place hierarchy + active-path opacity (Strike 3A).
// UI only — data remains [DatabaseService.rules] / [CategoryRule] tree.

import 'dart:async';

import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/categories/create_category_from_picker.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
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

/// Filters category roots for picker search (label match on node or descendants).
@visibleForTesting
List<CategoryRule> filterCategoryRootsForPickerSearch(
  List<CategoryRule> roots,
  String query,
  String Function(CategoryRule rule) labelFor,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return roots;

  CategoryRule? filterNode(CategoryRule rule) {
    final labelMatch = labelFor(rule).toLowerCase().contains(q);
    final childrenRaw = rule.children ?? const <CategoryRule>[];
    final filteredChildren = <CategoryRule>[
      for (final c in childrenRaw)
        if (filterNode(c) case final filtered?) filtered,
    ];
    if (labelMatch || filteredChildren.isNotEmpty) {
      return rule.copyWith(children: filteredChildren);
    }
    return null;
  }

  return [
    for (final r in roots)
      if (filterNode(r) case final filtered?) filtered,
  ];
}

Future<CategoryTreeSheetResult?> _showCategoryTreeSheet(
  BuildContext context, {
  int? initialCategoryId,
  bool showAllCategoriesRow = false,
}) {
  return showModalBottomSheet<CategoryTreeSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final sheetHeight = (MediaQuery.sizeOf(ctx).height * 0.82).clamp(320.0, 720.0);
      return SizedBox(
        height: sheetHeight,
        child: _CategoryTreePickerSheet(
          initialCategoryId: initialCategoryId,
          showAllCategoriesRow: showAllCategoriesRow,
        ),
      );
    },
  );
}

/// Always-visible picker create row (top / bottom / search miss).
@visibleForTesting
Key get categoryPickerTopAddKey => const ValueKey<String>('category_picker_top_add');

@visibleForTesting
Key get categoryPickerBottomAddKey =>
    const ValueKey<String>('category_picker_bottom_add');

@visibleForTesting
Key categoryPickerFolderAddKey(int categoryId) =>
    ValueKey<String>('category_picker_folder_add_$categoryId');

@visibleForTesting
String categoryPickerAddInsideLabel(String loc, String folderName) {
  return t(loc, 'category_picker_add_inside').replaceFirst('%s', folderName);
}

@visibleForTesting
Key categoryPickerRowAddKey(int categoryId) =>
    ValueKey<String>('category_picker_row_add_$categoryId');

@visibleForTesting
bool categoryTreeNodeShowsPickerAddChild({
  required bool showPickerCreateChrome,
  required void Function(CategoryRule parent)? onPickerAddChild,
}) {
  return showPickerCreateChrome && onPickerAddChild != null;
}

@visibleForTesting
Widget categoryPickerCreateListTile({
  required Key key,
  required String label,
  required VoidCallback? onTap,
  String? subtitle,
}) {
  return ListTile(
    key: key,
    leading: const Icon(Icons.add_rounded),
    title: Text(label),
    subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
    enabled: onTap != null,
    onTap: onTap,
  );
}

class _CategoryTreePickerSheet extends StatefulWidget {
  const _CategoryTreePickerSheet({
    required this.initialCategoryId,
    required this.showAllCategoriesRow,
  });

  final int? initialCategoryId;
  final bool showAllCategoriesRow;

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
    _catSub = DatabaseService.instance.categoryStream.listen((_) {
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
    final rootsRaw = DatabaseService.instance.getChildrenOf(null);
    final roots = [
      for (final r in rootsRaw)
        if (!CategoryVisibilityPrefs.isHiddenOrAncestor(r.id)) r,
    ];
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  _CategoryTreeBody(
                    roots: roots,
                    selectedCategoryId: widget.initialCategoryId,
                    expandSelectionPath: false,
                    onSelect: (id) => Navigator.of(context).pop(
                      CategoryTreeSheetPicked(id),
                    ),
                    showEditChrome: false,
                    showPickerCreateChrome: true,
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
    this.showPickerCreateChrome = false,
    this.onPickerAddChild,
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
  final bool showPickerCreateChrome;
  final void Function(CategoryRule parent)? onPickerAddChild;
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
        return;
      }
      final spine = DatabaseService.instance.categoryPathFromRootToLocalId(id);
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
  final void Function(CategoryRule parent)? onPickerAddChild;
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
    final showRowAdd = categoryTreeNodeShowsPickerAddChild(
      showPickerCreateChrome: showPickerCreateChrome,
      onPickerAddChild: onPickerAddChild,
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
            Expanded(
              child: InkWell(
                onTap: () => onSelect(rule.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(rule.iconOrDefault, color: color, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
