import 'dart:async';
import 'dart:convert';

import 'package:counter/features/notes/notes_glm_surface.dart';

import 'package:counter/core/tag_contrast.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/lists/lists_card.dart';
import 'package:counter/features/lists/lists_export.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tag filter chip in the Lists horizontal tag bar.
class ListsTagFilterChip extends StatelessWidget {
  const ListsTagFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.glmPresentation = false,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool glmPresentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    if (glmPresentation) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: dark ? 0.22 : 0.16)
                  : dark
                  ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
                  : const Color(0xFFFFFFFF).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: dark ? 0.80 : 0.55)
                    : dark
                    ? scheme.outlineVariant.withValues(alpha: 0.70)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? (dark ? scheme.onSurface : color)
                    : notesGlmPillTextColor(context),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.42)
                : color.withValues(alpha: 0.22),
            border: Border.all(
              color: selected ? scheme.primary : color,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Category chip bar (manual reorder or horizontal scroll).
class ListsCategoryChipBar extends StatefulWidget {
  const ListsCategoryChipBar({
    super.key,
    required this.chipIds,
    required this.chipMode,
    required this.filterCategoryId,
    required this.scrollController,
    required this.onFilterChanged,
    required this.onManualChipReorder,
    this.glmPresentation = false,
  });

  final List<int> chipIds;
  final String chipMode;
  final int? filterCategoryId;
  final ScrollController scrollController;
  final ValueChanged<int?> onFilterChanged;
  final void Function(int oldIndex, int newIndex) onManualChipReorder;
  final bool glmPresentation;

  @override
  State<ListsCategoryChipBar> createState() => _ListsCategoryChipBarState();
}

class _ListsCategoryChipBarState extends State<ListsCategoryChipBar> {
  static const String _chipModePrefsKey = 'list_chip_mode';
  static const String _pinnedIdsPrefsKey = 'list_pinned_ids';

  List<int>? _quickChipIds;
  bool _quickManualMode = false;

  List<int> get _displayChipIds => _quickChipIds ?? widget.chipIds;

  bool get _manualMode => _quickManualMode || widget.chipMode == 'manual';

  @override
  void didUpdateWidget(covariant ListsCategoryChipBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chipMode != widget.chipMode) {
      _quickChipIds = null;
      _quickManualMode = false;
    }
  }

  List<int> _sanitizeQuickChipIds(Iterable<int> ids) {
    final db = DatabaseService.instance;
    final out = <int>[];
    final seen = <int>{};
    for (final id in ids) {
      if (!seen.add(id)) continue;
      if (!db.categoryExists(id)) continue;
      out.add(id);
    }
    return out;
  }

  Future<void> _persistQuickChipIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chipModePrefsKey, 'manual');
    await prefs.setString(_pinnedIdsPrefsKey, jsonEncode(ids));
  }

  void _applyQuickChipIds(Iterable<int> ids) {
    final next = _sanitizeQuickChipIds(ids);
    setState(() {
      _quickManualMode = true;
      _quickChipIds = next;
    });
    final active = widget.filterCategoryId;
    if (active != null && !next.contains(active)) {
      widget.onFilterChanged(null);
    }
    unawaited(_persistQuickChipIds(next));
  }

  List<CategoryRule> _flattenCategoryRules(Iterable<CategoryRule> roots) {
    final out = <CategoryRule>[];
    void visit(Iterable<CategoryRule> rules) {
      for (final rule in rules) {
        if (rule.isArchived) continue;
        out.add(rule);
        final children = rule.children;
        if (children != null && children.isNotEmpty) visit(children);
      }
    }

    visit(roots);
    return out;
  }

  Future<void> _openCategoryPicker(BuildContext context) async {
  final picked = await showCategoryTreeMultiPicker(
    context,
    initialCategoryIds: Set<int>.from(_displayChipIds),
  );
  if (!mounted || picked == null) return;
  _applyQuickChipIds(picked);
}

// ignore: unused_element
Future<void> _openLegacyCategoryPicker(BuildContext context) async {
    final db = DatabaseService.instance;
    final selected = Set<int>.from(_displayChipIds);
    final expandedIds = <int>{};
    final searchController = TextEditingController();
    var searchQuery = '';
    var creatingCategory = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (ctx) {
          final sheetHeight =
              (MediaQuery.sizeOf(ctx).height * 0.82).clamp(320.0, 720.0);
          return SizedBox(
            height: sheetHeight,
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                void applyPickerMutation(void Function() mutation) {
                  setModal(mutation);
                  _applyQuickChipIds(selected);
                }

                Future<String?> promptCategoryName(CategoryRule? parent) async {
                  final controller = TextEditingController();
                  try {
                    return await showDialog<String>(
                      context: ctx,
                      builder: (dialogCtx) {
                        void submit() {
                          final value = controller.text.trim();
                          if (value.isEmpty) return;
                          Navigator.of(dialogCtx).pop(value);
                        }

                        return AlertDialog(
                          title: Text(
                            parent == null
                                ? t(currentLocale.value, 'category_label')
                                : categoryRawName(parent.id),
                          ),
                          content: TextField(
                            key: ValueKey<String>(
                              parent == null
                                  ? 'notes-category-create-root-input'
                                  : 'notes-category-create-child-input-${parent.id}',
                            ),
                            controller: controller,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: t(
                                currentLocale.value,
                                'category_label',
                              ),
                            ),
                            onSubmitted: (_) => submit(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              child: Text(t(currentLocale.value, 'cancel')),
                            ),
                            FilledButton(
                              onPressed: submit,
                              child: Text(t(currentLocale.value, 'add')),
                            ),
                          ],
                        );
                      },
                    );
                  } finally {
                    controller.dispose();
                  }
                }

                Future<void> createCategoryUnder(
                  CategoryRule? parent, {
                  String? explicitName,
                }) async {
                  if (creatingCategory) return;
                  final name = (explicitName ?? await promptCategoryName(parent))
                      ?.trim();
                  if (name == null || name.isEmpty || !ctx.mounted) return;

                  setModal(() {
                    creatingCategory = true;
                    if (parent != null) expandedIds.add(parent.id);
                  });

                  final createFuture = db.addNestedCategory(
                    parent?.id,
                    CategoryRule(id: 0, name: name),
                  );
                  // addNestedCategory mutates the Brain tree optimistically before
                  // its first network await; rebuild the open branch immediately.
                  if (ctx.mounted) {
                    setModal(() {
                      if (parent != null) expandedIds.add(parent.id);
                    });
                  }

                  final createdId = await createFuture;
                  if (!mounted || !ctx.mounted) return;
                  if (createdId == null) {
                    setModal(() => creatingCategory = false);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(t(currentLocale.value, 'toast_error')),
                      ),
                    );
                    return;
                  }

                  selected.add(createdId);
                  _applyQuickChipIds(selected);
                  setModal(() {
                    creatingCategory = false;
                    if (parent != null) expandedIds.add(parent.id);
                  });
                }

                final allRules = widget.glmPresentation
                    ? _flattenCategoryRules(db.rules)
                    : const <CategoryRule>[];
                final normalizedQuery = searchQuery.trim().toLowerCase();
                final matchingRules = normalizedQuery.isEmpty
                    ? const <CategoryRule>[]
                    : allRules
                          .where(
                            (rule) => categoryRawName(
                              rule.id,
                            ).trim().toLowerCase().contains(normalizedQuery),
                          )
                          .toList(growable: false);
                final exactMatchExists = normalizedQuery.isNotEmpty &&
                    allRules.any(
                      (rule) =>
                          categoryRawName(rule.id).trim().toLowerCase() ==
                          normalizedQuery,
                    );

                final pickerChildren = <Widget>[];
                if (widget.glmPresentation && normalizedQuery.isNotEmpty) {
                  if (!exactMatchExists) {
                    pickerChildren.add(
                      ListTile(
                        key: const ValueKey<String>(
                          'notes-category-create-from-search',
                        ),
                        leading: creatingCategory
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline_rounded),
                        title: Text(
                          '${t(currentLocale.value, 'add')} “${searchQuery.trim()}”',
                        ),
                        enabled: !creatingCategory,
                        onTap: creatingCategory
                            ? null
                            : () => unawaited(
                                createCategoryUnder(
                                  null,
                                  explicitName: searchQuery,
                                ),
                              ),
                      ),
                    );
                  }
                  for (final rule in matchingRules) {
                    pickerChildren.add(
                      CheckboxListTile(
                        key: ValueKey<int>(rule.id),
                        value: selected.contains(rule.id),
                        onChanged: (checked) {
                          applyPickerMutation(() {
                            if (checked == true) {
                              selected.add(rule.id);
                            } else {
                              selected.remove(rule.id);
                            }
                          });
                        },
                        title: Text(categoryRawName(rule.id)),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    );
                  }
                } else {
                  if (widget.glmPresentation) {
                    pickerChildren.add(
                      ListTile(
                        key: const ValueKey<String>(
                          'notes-category-create-root',
                        ),
                        leading: const Icon(Icons.create_new_folder_outlined),
                        title: Text(t(currentLocale.value, 'add')),
                        enabled: !creatingCategory,
                        onTap: creatingCategory
                            ? null
                            : () => unawaited(createCategoryUnder(null)),
                      ),
                    );
                  }
                  for (final rule in db.rules) {
                    pickerChildren.add(
                      buildListsManualCategoryTreeTile(
                        rule,
                        selected,
                        expandedIds,
                        (id) => toggleListsManualTreeExpand(
                          id,
                          setModal,
                          expandedIds,
                        ),
                        applyPickerMutation,
                        onCreateChild: widget.glmPresentation
                            ? (parent) => unawaited(
                                createCategoryUnder(parent),
                              )
                            : null,
                      ),
                    );
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        t(currentLocale.value, 'category_label'),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    if (widget.glmPresentation)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: TextField(
                          key: const ValueKey<String>(
                            'notes-category-search-field',
                          ),
                          controller: searchController,
                          autofocus: false,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '${t(currentLocale.value, 'category_label')}…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: normalizedQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: t(currentLocale.value, 'close'),
                                    onPressed: () {
                                      searchController.clear();
                                      setModal(() => searchQuery = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) =>
                              setModal(() => searchQuery = value),
                          onSubmitted: (_) {
                            if (!exactMatchExists &&
                                normalizedQuery.isNotEmpty &&
                                !creatingCategory) {
                              unawaited(
                                createCategoryUnder(
                                  null,
                                  explicitName: searchQuery,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: pickerChildren,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  Widget _addCategoryButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.glmPresentation) {
      return ListsQuadraticChip(
        label: '+',
        categoryColor: scheme.primary,
        selected: false,
        glmPresentation: true,
        onTap: () => unawaited(_openCategoryPicker(context)),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_openCategoryPicker(context)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          key: const ValueKey<String>('notes-category-quick-add'),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            '+',
            style: TextStyle(
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _withDesktopHorizontalScroll(Widget child) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      child: Listener(
        onPointerSignal: (signal) {
          if (signal is! PointerScrollEvent) return;
          if (!widget.scrollController.hasClients) return;
          if (signal.scrollDelta.dy.abs() <= signal.scrollDelta.dx.abs()) {
            return;
          }
          final position = widget.scrollController.position;
          final target = (position.pixels + signal.scrollDelta.dy).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          if (target != position.pixels) {
            widget.scrollController.jumpTo(target.toDouble());
          }
        },
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chipIds = _displayChipIds;
    if (_manualMode && chipIds.length > 1) {
      return Row(
        children: [
          Expanded(
            child: _withDesktopHorizontalScroll(
              ReorderableListView.builder(
                scrollController: widget.scrollController,
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.glmPresentation ? 0 : 12,
                  vertical: widget.glmPresentation ? 2 : 4,
                ),
                itemCount: chipIds.length,
                onReorder: widget.onManualChipReorder,
                itemBuilder: (ctx, idx) {
                  final id = chipIds[idx];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey<int>(id),
                    index: idx,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ListsQuadraticChip(
                        label: categoryRawName(id),
                        categoryColor: listsCategoryAccentColor(id),
                        selected: widget.filterCategoryId == id,
                        glmPresentation: widget.glmPresentation,
                        onTap: () {
                          widget.onFilterChanged(
                            widget.filterCategoryId == id ? null : id,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          _addCategoryButton(context),
        ],
      );
    }
    return _withDesktopHorizontalScroll(
      ListView(
        controller: widget.scrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: widget.glmPresentation ? 0 : 12,
          vertical: widget.glmPresentation ? 2 : 8,
        ),
        children: [
          for (final id in chipIds)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ListsQuadraticChip(
                label: categoryRawName(id),
                categoryColor: listsCategoryAccentColor(id),
                selected: widget.filterCategoryId == id,
                glmPresentation: widget.glmPresentation,
                onTap: () {
                  widget.onFilterChanged(
                    widget.filterCategoryId == id ? null : id,
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: _addCategoryButton(context),
          ),
        ],
      ),
    );
  }
}

/// Horizontal tag filter strip under the category chip bar.
class ListsTagFilterBar extends StatelessWidget {
  const ListsTagFilterBar({
    super.key,
    required this.locale,
    required this.tags,
    required this.filterTagPbId,
    required this.hasActiveTagFilter,
    required this.scrollController,
    required this.onTagFilterChanged,
    this.glmPresentation = false,
  });

  final String locale;
  final List<Tag> tags;
  final String? filterTagPbId;
  final bool hasActiveTagFilter;
  final ScrollController scrollController;
  final ValueChanged<String?> onTagFilterChanged;
  final bool glmPresentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: glmPresentation ? 36 : 44,
      child: ListView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: glmPresentation ? 0 : 12,
          vertical: glmPresentation ? 2 : 4,
        ),
        children: [
          if (!hasActiveTagFilter)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ListsTagFilterChip(
                label: t(locale, 'lists_filter_tag_all'),
                selected: filterTagPbId == null,
                color: theme.colorScheme.outline,
                glmPresentation: glmPresentation,
                onTap: () => onTagFilterChanged(null),
              ),
            ),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ListsTagFilterChip(
                label: tag.name.trim().isNotEmpty
                    ? tag.name.trim()
                    : '#${tag.tagId}',
                selected:
                    (filterTagPbId ?? '') == (tag.pbRecordId ?? '').trim(),
                color: parseTagHexColor(tag.color) ?? theme.colorScheme.primary,
                glmPresentation: glmPresentation,
                onTap: () {
                  final id = (tag.pbRecordId ?? '').trim();
                  if (id.isEmpty) return;
                  onTagFilterChanged(filterTagPbId == id ? null : id);
                },
              ),
            ),
          if (hasActiveTagFilter)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ListsTagFilterChip(
                label: t(locale, 'lists_filter_tag_all'),
                selected: filterTagPbId == null,
                color: theme.colorScheme.outline,
                glmPresentation: glmPresentation,
                onTap: () => onTagFilterChanged(null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Export + chip-bar settings icon row (non-select mode).
class ListsFilterToolbarRow extends StatelessWidget {
  const ListsFilterToolbarRow({
    super.key,
    required this.locale,
    required this.showExport,
    required this.onExport,
    required this.onOpenSettings,
  });

  final String locale;
  final bool showExport;
  final VoidCallback onExport;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showExport)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: t(locale, 'lists_export_text'),
              onPressed: onExport,
              icon: const Icon(Icons.copy_rounded),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: t(locale, 'lists_chip_bar_settings_tooltip'),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
    );
  }
}

/// Manual chip picker: tree of [CategoryRule] — accordion (one branch open per level).
Widget buildListsManualCategoryTreeTile(
  CategoryRule r,
  Set<int> sel,
  Set<int> expandedIds,
  void Function(int id) onToggleExpand,
  void Function(void Function()) setModal, {
  int depth = 0,
  void Function(CategoryRule parent)? onCreateChild,
}) {
  final kids = r.children ?? const <CategoryRule>[];
  final titleName = categoryRawName(r.id);
  final depthPad = EdgeInsetsDirectional.only(start: depth * 20.0);
  void toggleSel(bool? v) {
    setModal(() {
      if (v == true) {
        sel.add(r.id);
      } else {
        sel.remove(r.id);
      }
    });
  }

  // Outside the Notes picker, preserve the old compact leaf behavior.
  if (kids.isEmpty && onCreateChild == null) {
    return Padding(
      padding: depthPad,
      child: CheckboxListTile(
        value: sel.contains(r.id),
        onChanged: toggleSel,
        title: Text(titleName),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }

  final expanded = expandedIds.contains(r.id);
  return Padding(
    padding: depthPad,
    child: ExpansionTile(
      key: ValueKey<int>(r.id),
      initiallyExpanded: expanded,
      onExpansionChanged: (open) {
        if (open) {
          onToggleExpand(r.id);
        } else {
          setModal(() => expandedIds.remove(r.id));
        }
      },
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Row(
        children: [
          Checkbox(value: sel.contains(r.id), onChanged: toggleSel),
          Expanded(
            child: Text(titleName),
          ),
        ],
      ),
      children: [
        if (onCreateChild != null)
          ListTile(
            key: ValueKey<String>('notes-category-create-child-${r.id}'),
            contentPadding: const EdgeInsetsDirectional.only(
              start: 28,
              end: 8,
            ),
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(t(currentLocale.value, 'add')),
            dense: true,
            onTap: () => onCreateChild(r),
          ),
        for (final c in kids)
          buildListsManualCategoryTreeTile(
            c,
            sel,
            expandedIds,
            onToggleExpand,
            setModal,
            depth: depth + 1,
            onCreateChild: onCreateChild,
          ),
      ],
    ),
  );
}

void toggleListsManualTreeExpand(
  int id,
  void Function(void Function()) setModal,
  Set<int> expandedIds,
) {
  setModal(() {
    if (expandedIds.contains(id)) {
      expandedIds.remove(id);
      return;
    }
    final spine = DatabaseService.instance.categoryPathFromRootToLocalId(id);
    final ancestors = spine.length > 1
        ? spine.take(spine.length - 1).toSet()
        : <int>{};
    expandedIds
      ..clear()
      ..addAll({...ancestors, id});
  });
}

/// Opens chip-bar settings sheet. Caller supplies persistence callbacks.
Future<void> showListsChipBarSettingsSheet({
  required BuildContext context,
  required String locale,
  required String initialChipMode,
  required List<int> initialPinnedChipIds,
  required int? filterCategoryId,
  required List<PlanningTask> displayFlat,
  required List<PlanningTask> Function(List<PlanningTask>, String)
  applyCompletionLayout,
  required List<int> Function(List<int>) sanitizeCategoryIds,
  required Future<void> Function(String mode) persistChipMode,
  required Future<void> Function(List<int> ids) persistPinnedChipIds,
  required void Function(String mode, List<int> pinnedIds) onSaved,
  required Future<void> Function() reload,
  required void Function(int? categoryId) onFilterChanged,
}) async {
  final db = DatabaseService.instance;
  var mode = initialChipMode;
  final sel = Set<int>.from(initialPinnedChipIds);
  final expandedManualTreeIds = <int>{};
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          var completionDraft = db.settings.listCompletionBehavior
              .trim()
              .toLowerCase();
          if (completionDraft != 'stay' &&
              completionDraft != 'bottom' &&
              completionDraft != 'hide' &&
              completionDraft != 'archive') {
            completionDraft = 'hide';
          }
          var showTagsDraft = db.settings.showListTagsOnCards;
          final manualListHeight = (MediaQuery.sizeOf(ctx).height * 0.45).clamp(
            200.0,
            520.0,
          );
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      t(locale, 'lists_chip_bar_sheet_title'),
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment<String>(
                          value: 'frequent',
                          label: Text(t(locale, 'lists_chip_mode_frequent')),
                        ),
                        ButtonSegment<String>(
                          value: 'manual',
                          label: Text(t(locale, 'lists_chip_mode_manual')),
                        ),
                      ],
                      emptySelectionAllowed: false,
                      showSelectedIcon: false,
                      selected: {mode},
                      onSelectionChanged: (Set<String> next) {
                        if (next.isEmpty) return;
                        setModal(() => mode = next.first);
                      },
                    ),
                  ),
                  if (mode == 'manual')
                    SizedBox(
                      height: manualListHeight,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final r in db.rules)
                            buildListsManualCategoryTreeTile(
                              r,
                              sel,
                              expandedManualTreeIds,
                              (id) => toggleListsManualTreeExpand(
                                id,
                                setModal,
                                expandedManualTreeIds,
                              ),
                              setModal,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: completionDraft,
                      decoration: InputDecoration(
                        labelText: t(locale, 'lists_completion_title'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'stay',
                          child: Text(t(locale, 'lists_completion_stay')),
                        ),
                        DropdownMenuItem(
                          value: 'bottom',
                          child: Text(t(locale, 'lists_completion_bottom')),
                        ),
                        DropdownMenuItem(
                          value: 'hide',
                          child: Text(t(locale, 'lists_completion_hide')),
                        ),
                        DropdownMenuItem(
                          value: 'archive',
                          child: Text(t(locale, 'lists_completion_archive')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() => completionDraft = v);
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: Text(t(locale, 'lists_show_list_tags')),
                    value: showTagsDraft,
                    onChanged: (v) => setModal(() => showTagsDraft = v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy_rounded),
                    title: Text(t(locale, 'lists_export_text')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      final flat = applyCompletionLayout(
                        displayFlat,
                        completionDraft,
                      );
                      unawaited(
                        exportVisibleListAsText(
                          context: context,
                          locale: locale,
                          visible: flat,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.label_outline_rounded),
                    title: Text(t(locale, 'lists_manage_tags')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      unawaited(
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (c) => Scaffold(
                              appBar: AppBar(
                                title: Text(t(locale, 'lists_manage_tags')),
                              ),
                              body: const TagManagerPage(
                                pocketTagDomain: 'list',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        final nextPinned = sanitizeCategoryIds(sel.toList());
                        onSaved(mode, nextPinned);
                        unawaited(persistChipMode(mode));
                        unawaited(
                          db.persistShowListTagsOnCards(showTagsDraft),
                        );
                        unawaited(
                          db.saveSettings(
                            db.settings.copyWith(
                              listCompletionBehavior: completionDraft,
                            ),
                          ),
                        );
                        if (mode == 'manual') {
                          unawaited(persistPinnedChipIds(nextPinned));
                          if (filterCategoryId != null &&
                              !nextPinned.contains(filterCategoryId)) {
                            onFilterChanged(null);
                          }
                        }
                        unawaited(reload());
                      },
                      child: Text(t(locale, 'save')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}