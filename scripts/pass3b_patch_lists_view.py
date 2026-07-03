#!/usr/bin/env python3
"""Pass 3B — patch lists_view.dart to use extracted modules."""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
LV = ROOT / "lib" / "features" / "lists" / "lists_view.dart"
text = LV.read_text(encoding="utf-8")

# Replace bulk bottom bar method
text = re.sub(
    r"  Widget\? _listsBulkBottomBar\([\s\S]*?^\  \}\n",
    """  Widget? _listsBulkBottomBar(
    BuildContext context,
    ColorScheme scheme,
    List<PlanningTask> display,
  ) {
    if (_selectedListKeys.isEmpty) return null;
    return ListsBulkBottomBar(
      locale: currentLocale.value,
      selectedCount: _selectedListKeys.length,
      onEdit: () => _openListsBulkEditFirst(display),
      onDelete: () => unawaited(_listsBulkDelete(display)),
    );
  }

""",
    text,
    count=1,
    flags=re.MULTILINE,
)

# Remove manual tree + tag chip + settings sheet block, replace with thin wrapper
start = text.index("  /// Manual chip picker:")
end = text.index("  @override\n  void dispose()")
replacement = """  Future<void> _openChipBarSettingsSheet() async {
    await showListsChipBarSettingsSheet(
      context: context,
      locale: currentLocale.value,
      initialChipMode: _chipMode,
      initialPinnedChipIds: _pinnedChipIds,
      filterCategoryId: _filterCategoryId,
      displayFlat: _displayFlat,
      applyCompletionLayout: _listsApplyCompletionLayout,
      sanitizeCategoryIds: _sanitizeIntCategoryIds,
      persistChipMode: _persistChipMode,
      persistPinnedChipIds: _persistPinnedChipIds,
      onSaved: (mode, pinned) {
        setState(() {
          _chipMode = mode;
          if (mode == 'manual') {
            _pinnedChipIds = pinned;
          }
        });
      },
      reload: _reload,
      onFilterChanged: _onFilterChanged,
    );
  }

"""
text = text[:start] + replacement + text[end:]

# Select mode bar in build
text = text.replace(
    """                    if (_listsSelectMode) ...[
                      Material(
                        color: theme.colorScheme.surface,
                        elevation: 0,
                        surfaceTintColor: theme.colorScheme.surfaceTint,
                        child: SizedBox(
                          height: kGlobalCompactHeaderHeight,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _exitListsSelectMode,
                                tooltip: t(loc, 'plan_exit_select'),
                              ),
                              Expanded(
                                child: Text(
                                  t(loc, 'plan_select_mode'),
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (filterId != null && flat.isNotEmpty)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _toggleSelectAllVisibleLists(flat),
                                  child: Text(
                                    _allVisibleListsSelected(flat)
                                        ? t(loc, 'plan_deselect_visible')
                                        : t(loc, 'plan_select_all'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (filterId != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: t(loc, 'lists_export_text'),
                                onPressed: () => unawaited(
                                  exportVisibleListAsText(
                                    context: context,
                                    locale: loc,
                                    visible: forGrouping,
                                  ),
                                ),
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: t(
                                loc,
                                'lists_chip_bar_settings_tooltip',
                              ),
                              onPressed: _openChipBarSettingsSheet,
                              icon: const Icon(Icons.settings_rounded),
                            ),
                          ],
                        ),
                      ),""",
    """                    if (_listsSelectMode)
                      ListsBulkSelectModeBar(
                        locale: loc,
                        filterCategoryId: filterId,
                        visibleFlat: flat,
                        allVisibleSelected: _allVisibleListsSelected(flat),
                        onExitSelectMode: _exitListsSelectMode,
                        onToggleSelectAllVisible: () =>
                            _toggleSelectAllVisibleLists(flat),
                      )
                    else
                      ListsFilterToolbarRow(
                        locale: loc,
                        showExport: filterId != null,
                        onExport: () => unawaited(
                          exportVisibleListAsText(
                            context: context,
                            locale: loc,
                            visible: forGrouping,
                          ),
                        ),
                        onOpenSettings: _openChipBarSettingsSheet,
                      ),""",
)

# Chip bar
text = text.replace(
    """                          SizedBox(
                            height: 48,
                            child: _chipMode == 'manual' && chipIds.length > 1
                                ? ReorderableListView.builder(
                                    scrollController: _chipBarScrollController,
                                    scrollDirection: Axis.horizontal,
                                    buildDefaultDragHandles: false,
                                    shrinkWrap: true,
                                    physics: const ClampingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    itemCount: chipIds.length,
                                    onReorder: (oldI, newI) =>
                                        _onManualChipReorder(
                                          chipIds,
                                          oldI,
                                          newI,
                                        ),
                                    itemBuilder: (ctx, idx) {
                                      final id = chipIds[idx];
                                      return ReorderableDelayedDragStartListener(
                                        key: ValueKey<int>(id),
                                        index: idx,
                                        child: Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                end: 8,
                                              ),
                                          child: ListsQuadraticChip(
                                            label: categoryRawName(id),
                                            categoryColor:
                                                listsCategoryAccentColor(id),
                                            selected: filterId == id,
                                            onTap: () {
                                              if (filterId == id) {
                                                _onFilterChanged(null);
                                              } else {
                                                _onFilterChanged(id);
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : ListView(
                                    controller: _chipBarScrollController,
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    children: [
                                      for (final id in chipIds)
                                        Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                end: 8,
                                              ),
                                          child: ListsQuadraticChip(
                                            label: categoryRawName(id),
                                            categoryColor:
                                                listsCategoryAccentColor(id),
                                            selected: filterId == id,
                                            onTap: () {
                                              if (filterId == id) {
                                                _onFilterChanged(null);
                                              } else {
                                                _onFilterChanged(id);
                                              }
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                          ),""",
    """                          SizedBox(
                            height: 48,
                            child: ListsCategoryChipBar(
                              chipIds: chipIds,
                              chipMode: _chipMode,
                              filterCategoryId: filterId,
                              scrollController: _chipBarScrollController,
                              onFilterChanged: _onFilterChanged,
                              onManualChipReorder: (oldI, newI) =>
                                  _onManualChipReorder(chipIds, oldI, newI),
                            ),
                          ),""",
)

# Tag filter bar
text = text.replace(
    """                          if (filterId != null &&
                              _tagsForFilterBar().isNotEmpty)
                            SizedBox(
                              height: 44,
                              child: ListView(
                                controller: _tagFilterScrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                children: [
                                  if (!hasActiveTagFilter)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: _buildListTagFilterChip(
                                        label: t(loc, 'lists_filter_tag_all'),
                                        selected: _filterTagPbId == null,
                                        color: theme.colorScheme.outline,
                                        onTap: () => _onTagFilterChanged(null),
                                      ),
                                    ),
                                  for (final tag in _tagsForFilterBar())
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: _buildListTagFilterChip(
                                        label: tag.name.trim().isNotEmpty
                                            ? tag.name.trim()
                                            : '#${tag.tagId}',
                                        selected:
                                            (_filterTagPbId ?? '') ==
                                            (tag.pbRecordId ?? '').trim(),
                                        color:
                                            parseTagHexColor(tag.color) ??
                                            theme.colorScheme.primary,
                                        onTap: () {
                                          final id = (tag.pbRecordId ?? '')
                                              .trim();
                                          if (id.isEmpty) return;
                                          if (_filterTagPbId == id) {
                                            _onTagFilterChanged(null);
                                          } else {
                                            _onTagFilterChanged(id);
                                          }
                                        },
                                      ),
                                    ),
                                  if (hasActiveTagFilter)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: _buildListTagFilterChip(
                                        label: t(loc, 'lists_filter_tag_all'),
                                        selected: _filterTagPbId == null,
                                        color: theme.colorScheme.outline,
                                        onTap: () => _onTagFilterChanged(null),
                                      ),
                                    ),
                                ],
                              ),
                            ),""",
    """                          if (filterId != null &&
                              _tagsForFilterBar().isNotEmpty)
                            ListsTagFilterBar(
                              locale: loc,
                              tags: _tagsForFilterBar(),
                              filterTagPbId: _filterTagPbId,
                              hasActiveTagFilter: hasActiveTagFilter,
                              scrollController: _tagFilterScrollController,
                              onTagFilterChanged: _onTagFilterChanged,
                            ),""",
)

# Inline add
text = text.replace(
    """                          if (filterId != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _inlineController,
                                      focusNode: _inlineFocus,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        hintText: t(
                                          loc,
                                          'input_placeholder_list',
                                        ),
                                        isDense: true,
                                        border: InputBorder.none,
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      onSubmitted: (_) => _submitInline(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: _submitInline,
                                    icon: const Icon(Icons.add_rounded),
                                    label: Text(t(loc, 'add')),
                                  ),
                                ],
                              ),
                            ),""",
    """                          if (filterId != null)
                            ListsInlineAddRow(
                              locale: loc,
                              controller: _inlineController,
                              focusNode: _inlineFocus,
                              onSubmit: _submitInline,
                            ),""",
)

# Empty states
text = text.replace(
    """                            child: filterId == null
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height:
                                            MediaQuery.sizeOf(context).height *
                                            0.25,
                                      ),
                                      AppEmptyState(
                                        message: t(
                                          loc,
                                          'lists_no_category_chosen',
                                        ),
                                        icon: Icons.category_outlined,
                                      ),
                                    ],
                                  )
                                : _loading
                                ? const AppLoading()
                                : RefreshIndicator(
                                    onRefresh: _reload,
                                    child: listBodyEmpty
                                        ? ListView(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            children: [
                                              SizedBox(
                                                height:
                                                    MediaQuery.sizeOf(
                                                      context,
                                                    ).height *
                                                    0.25,
                                              ),
                                              AppEmptyState(
                                                message: t(loc, 'lists_empty'),
                                                icon: Icons.inbox_outlined,
                                              ),
                                            ],
                                          )""",
    """                            child: filterId == null
                                ? ListsNoCategoryEmptyPanel(locale: loc)
                                : _loading
                                ? const ListsLoadingPanel()
                                : RefreshIndicator(
                                    onRefresh: _reload,
                                    child: listBodyEmpty
                                        ? ListsFilteredEmptyPanel(
                                            locale: loc,
                                          )""",
)

LV.write_text(text, encoding="utf-8")
print("lists_view lines:", len(text.splitlines()))
