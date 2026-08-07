import 'dart:async';

import 'package:counter/features/notes/notes_glm_surface.dart';

import 'package:counter/core/tag_contrast.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:counter/shared/categories/visibility/category_visibility_prefs.dart';
import 'package:counter/features/lists/lists_card.dart';
import 'package:counter/features/lists/lists_export.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

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
class ListsCategoryChipBar extends StatelessWidget {
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

  Future<void> _openCategoryPicker(BuildContext context) async {
    final result = await showCategoryTreeSheet(
      context,
      initialCategoryId: filterCategoryId,
      showAllCategoriesRow: false,
    );
    if (result is CategoryTreeSheetPicked) {
      onFilterChanged(result.id);
    }
  }

  Widget _addCategoryButton(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_openCategoryPicker(context)),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          key: const ValueKey<String>('notes-category-quick-add'),
          height: glmPresentation ? 34 : 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: dark
                ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
                : const Color(0xFFFFFFFF).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: dark
                  ? scheme.outlineVariant.withValues(alpha: 0.70)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                t(currentLocale.value, 'add'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (chipMode == 'manual' && chipIds.length > 1) {
      return Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: glmPresentation ? 0 : 12,
                vertical: glmPresentation ? 2 : 4,
              ),
              itemCount: chipIds.length,
              onReorder: onManualChipReorder,
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
                      selected: filterCategoryId == id,
                      glmPresentation: glmPresentation,
                      onTap: () {
                        onFilterChanged(filterCategoryId == id ? null : id);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          _addCategoryButton(context),
        ],
      );
    }
    return ListView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: glmPresentation ? 0 : 12,
        vertical: glmPresentation ? 2 : 8,
      ),
      children: [
        for (final id in chipIds)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ListsQuadraticChip(
              label: categoryRawName(id),
              categoryColor: listsCategoryAccentColor(id),
              selected: filterCategoryId == id,
              glmPresentation: glmPresentation,
              onTap: () {
                onFilterChanged(filterCategoryId == id ? null : id);
              },
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: _addCategoryButton(context),
        ),
      ],
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
}) {
  if (CategoryVisibilityPrefs.isHiddenOrAncestor(r.id)) {
    return const SizedBox.shrink();
  }
  final rawKids = r.children ?? const <CategoryRule>[];
  final kids = rawKids
      .where((c) => !CategoryVisibilityPrefs.isHiddenOrAncestor(c.id))
      .toList();
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

  if (kids.isEmpty) {
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
        for (final c in kids)
          buildListsManualCategoryTreeTile(
            c,
            sel,
            expandedIds,
            onToggleExpand,
            setModal,
            depth: depth + 1,
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
