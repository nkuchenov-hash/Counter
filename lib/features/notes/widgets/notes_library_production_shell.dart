// Production Lists-tab Notes library shell.
// Visual structure follows LIFE_OS_Notes_MVP_v32_gapfix5.html directly while
// keeping the existing Lists/Brain callbacks as the data and mutation source.

import 'dart:async';
import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kChipModePrefsKey = 'list_chip_mode';
const String _kPinnedIdsPrefsKey = 'list_pinned_ids';

class NotesLibraryProductionShell extends StatelessWidget {
  const NotesLibraryProductionShell({
    super.key,
    required this.header,
    required this.categoryBar,
    this.categoryBarInHeader = false,
    this.tagBar,
    this.inlineAdd,
    required this.content,
    this.topBar,
  });

  final Widget? topBar;
  final Widget header;
  final Widget categoryBar;
  final bool categoryBarInHeader;
  final Widget? tagBar;
  final Widget? inlineAdd;
  final Widget content;

  _NotesCategoryAdapter? _categoryAdapter() {
    dynamic candidate = categoryBar;
    if (candidate is SizedBox && candidate.child != null) {
      candidate = candidate.child;
    }
    try {
      return _NotesCategoryAdapter(
        chipIds: List<int>.from(candidate.chipIds as List),
        chipMode: candidate.chipMode as String,
        filterCategoryId: candidate.filterCategoryId as int?,
        scrollController: candidate.scrollController as ScrollController,
        onFilterChanged: candidate.onFilterChanged as ValueChanged<int?>,
        onManualChipReorder:
            candidate.onManualChipReorder as void Function(int, int),
      );
    } catch (_) {
      return null;
    }
  }

  _NotesHeaderAdapter? _headerAdapter() {
    dynamic candidate = header;
    try {
      return _NotesHeaderAdapter(
        locale: candidate.locale as String,
        searchController: candidate.searchController as TextEditingController,
        searchFocus: candidate.searchFocus as FocusNode,
        searchQuery: candidate.searchQuery as String,
        onSearchChanged: candidate.onSearchChanged as ValueChanged<String>,
        onClearSearch: candidate.onClearSearch as VoidCallback,
        onOpenSettings: candidate.onOpenSettings as VoidCallback,
        notesView: candidate.notesView as NotesLibraryView,
        checkboxesOn: candidate.checkboxesOn as bool,
        onViewChanged: candidate.onViewChanged as ValueChanged<NotesLibraryView>,
        onCheckboxModeChanged:
            candidate.onCheckboxModeChanged as ValueChanged<bool>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final category = _categoryAdapter();
    final headerAdapter = _headerAdapter();
    final sectionPalette = _sectionPaletteFor(category?.filterCategoryId);
    final paneFill = dark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.88)
        : sectionPalette.pane;
    final paneBorder = dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.70)
        : Color.lerp(sectionPalette.tab, const Color(0xFFD8E0E9), 0.52)!;
    final listView = headerAdapter?.notesView == NotesLibraryView.list;

    final tabs = category == null
        ? categoryBar
        : _NotesPhysicalFolderTabs(
            adapter: category,
            onOpenSettings: headerAdapter?.onOpenSettings,
          );

    return NotesGlmLibraryFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBar != null) topBar!,
          if (headerAdapter == null)
            header
          else
            _HtmlNotesHeader(
              adapter: headerAdapter,
              onNewNote: () => unawaited(
                _createNewNote(
                  context,
                  preferredCategoryId: category?.filterCategoryId,
                ),
              ),
            ),
          const SizedBox(height: 11),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 55,
                  child: Container(
                    decoration: BoxDecoration(
                      color: paneFill,
                      border: Border.all(color: paneBorder),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: dark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF3F536C)
                                    .withValues(alpha: 0.045),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    padding:
                        listView ? EdgeInsets.zero : const EdgeInsets.all(28),
                    child: NotesSectionPaletteScope(
                      palette: sectionPalette,
                      child: content,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 56,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: tabs,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewNote(
    BuildContext context, {
    int? preferredCategoryId,
  }) async {
    final db = DatabaseService.instance;
    int? categoryId = preferredCategoryId;
    if (categoryId == null || !db.categoryExists(categoryId)) {
      final defaultId = db.defaultCategoryId;
      if (defaultId != null && db.categoryExists(defaultId)) {
        categoryId = defaultId;
      } else {
        final pairs = db.allCategoryIdPathPairs;
        if (pairs.isNotEmpty) categoryId = pairs.first.id;
      }
    }
    if (categoryId == null || !context.mounted) return;

    final rowId = await db.createEmptyNote(categoryId: categoryId, title: '');
    if (rowId == null || !context.mounted) return;
    final task = db.getCachedPlanningTaskForEdit(rowId);
    if (task == null) return;
    await showNoteEditorPage(
      context: context,
      task: task,
      onClosed: () {
        db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
      },
    );
  }
}

class _NotesHeaderAdapter {
  const _NotesHeaderAdapter({
    required this.locale,
    required this.searchController,
    required this.searchFocus,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenSettings,
    required this.notesView,
    required this.checkboxesOn,
    required this.onViewChanged,
    required this.onCheckboxModeChanged,
  });

  final String locale;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenSettings;
  final NotesLibraryView notesView;
  final bool checkboxesOn;
  final ValueChanged<NotesLibraryView> onViewChanged;
  final ValueChanged<bool> onCheckboxModeChanged;
}

class _HtmlNotesHeader extends StatelessWidget {
  const _HtmlNotesHeader({
    required this.adapter,
    required this.onNewNote,
  });

  final _NotesHeaderAdapter adapter;
  final VoidCallback onNewNote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final mobile = width <= 520;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Row(
            crossAxisAlignment:
                mobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: mobile ? 4 : 0),
                  child: Text(
                    t(adapter.locale, 'notes_v3_title'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: wide ? 30 : 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      height: 1.15,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _ViewSwitch(adapter: adapter),
              const SizedBox(width: 10),
              _CheckboxModeButton(adapter: adapter),
              const SizedBox(width: 10),
              _NewNoteButton(locale: adapter.locale, onPressed: onNewNote),
            ],
          ),
        ),
        const SizedBox(height: 8),
        NotesGlmLibraryInput(
          controller: adapter.searchController,
          focusNode: adapter.searchFocus,
          hintText: t(adapter.locale, 'notes_v3_search_hint'),
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.sentences,
          onChanged: adapter.onSearchChanged,
        ),
      ],
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.adapter});
  final _NotesHeaderAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
            : const Color(0xFFF7F8FA).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? scheme.outlineVariant.withValues(alpha: 0.70)
              : const Color(0xFFDFE3E8).withValues(alpha: 0.72),
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF415269).withValues(alpha: 0.045),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HtmlViewButton(
            icon: Icons.grid_view_rounded,
            selected: adapter.notesView == NotesLibraryView.grid,
            onTap: () => adapter.onViewChanged(NotesLibraryView.grid),
          ),
          const SizedBox(width: 2),
          _HtmlViewButton(
            icon: Icons.view_list_rounded,
            selected: adapter.notesView == NotesLibraryView.list,
            onTap: () => adapter.onViewChanged(NotesLibraryView.list),
          ),
        ],
      ),
    );
  }
}

class _HtmlViewButton extends StatelessWidget {
  const _HtmlViewButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? (dark ? scheme.surface : Colors.white)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 38,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? scheme.onSurface
                : scheme.onSurfaceVariant.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }
}

class _CheckboxModeButton extends StatelessWidget {
  const _CheckboxModeButton({required this.adapter});
  final _NotesHeaderAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: adapter.checkboxesOn
          ? (dark ? scheme.surfaceContainerHigh : Colors.white)
          : (dark
              ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
              : const Color(0xFFF7F8FA).withValues(alpha: 0.72)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => adapter.onCheckboxModeChanged(!adapter.checkboxesOn),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: adapter.checkboxesOn
                  ? kNotesAccent.withValues(alpha: 0.22)
                  : kNotesRule.withValues(alpha: 0.76),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            adapter.checkboxesOn
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 20,
            color: adapter.checkboxesOn
                ? kNotesAccent
                : scheme.onSurfaceVariant.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }
}

class _NewNoteButton extends StatelessWidget {
  const _NewNoteButton({required this.locale, required this.onPressed});
  final String locale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 520;
    return Material(
      color: kNotesInk,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                _newNoteLabel(locale),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _newNoteLabel(String locale) {
    switch (locale) {
      case 'ru':
        return 'Новая заметка';
      case 'de':
        return 'Neue Notiz';
      case 'fr':
        return 'Nouvelle note';
      case 'es':
        return 'Nueva nota';
      case 'it':
        return 'Nuova nota';
      default:
        return 'New note';
    }
  }
}

NotesSectionPalette _sectionPaletteFor(int? categoryId) {
  if (categoryId == null) return NotesSectionPalette.all;
  final rule = DatabaseService.instance.getCategoryRuleById(categoryId);
  if (rule == null) return NotesSectionPalette.all;
  return NotesSectionPalette.forCategory(rule.name, rule.colorOrDefault);
}

class _NotesCategoryAdapter {
  const _NotesCategoryAdapter({
    required this.chipIds,
    required this.chipMode,
    required this.filterCategoryId,
    required this.scrollController,
    required this.onFilterChanged,
    required this.onManualChipReorder,
  });

  final List<int> chipIds;
  final String chipMode;
  final int? filterCategoryId;
  final ScrollController scrollController;
  final ValueChanged<int?> onFilterChanged;
  final void Function(int oldIndex, int newIndex) onManualChipReorder;
}

class _NotesPhysicalFolderTabs extends StatefulWidget {
  const _NotesPhysicalFolderTabs({
    required this.adapter,
    this.onOpenSettings,
  });

  final _NotesCategoryAdapter adapter;
  final VoidCallback? onOpenSettings;

  @override
  State<_NotesPhysicalFolderTabs> createState() =>
      _NotesPhysicalFolderTabsState();
}

class _NotesPhysicalFolderTabsState extends State<_NotesPhysicalFolderTabs> {
  List<int>? _localChipIds;

  List<int> get _ids => _localChipIds ?? widget.adapter.chipIds;

  @override
  void didUpdateWidget(covariant _NotesPhysicalFolderTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final local = _localChipIds;
    if (local == null) return;
    if (_sameIds(local, widget.adapter.chipIds)) {
      _localChipIds = null;
    }
  }

  bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _editSections() async {
    final current = _ids;
    final picked = await showCategoryTreeMultiPicker(
      context,
      initialCategoryIds: Set<int>.from(current),
    );
    if (!mounted || picked == null) return;

    final selected = Set<int>.from(picked);
    final next = <int>[
      for (final id in current)
        if (selected.remove(id)) id,
      ...selected,
    ];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kChipModePrefsKey, 'manual');
    await prefs.setString(_kPinnedIdsPrefsKey, jsonEncode(next));
    if (!mounted) return;

    setState(() => _localChipIds = next);
    final active = widget.adapter.filterCategoryId;
    if (active != null && !next.contains(active)) {
      widget.adapter.onFilterChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    final allPalette = NotesSectionPalette.all;
    return SizedBox(
      height: 56,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView(
          controller: widget.adapter.scrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(right: 12),
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: _FolderTab(
                label: _allLabel(currentLocale.value),
                icon: Icons.format_list_bulleted_rounded,
                accent: allPalette.accent,
                fill: allPalette.tab,
                selected: widget.adapter.filterCategoryId == null,
                onTap: () => widget.adapter.onFilterChanged(null),
              ),
            ),
            for (final id in ids)
              Align(alignment: Alignment.bottomLeft, child: _categoryTab(id)),
            Align(
              alignment: Alignment.bottomLeft,
              child: _FolderTab(
                label: '',
                icon: Icons.add_rounded,
                accent: Colors.white,
                fill: kNotesInk,
                selected: false,
                compact: true,
                onTap: () => unawaited(_editSections()),
                onLongPress: widget.onOpenSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTab(int id) {
    final rule = DatabaseService.instance.getCategoryRuleById(id);
    if (rule == null) return const SizedBox.shrink();
    final palette =
        NotesSectionPalette.forCategory(rule.name, rule.colorOrDefault);
    final icon = rule.iconCodePoint == null
        ? Icons.folder_outlined
        : IconData(rule.iconCodePoint!, fontFamily: 'MaterialIcons');
    return _FolderTab(
      label: rule.name.trim().isEmpty ? '—' : rule.name.trim(),
      icon: icon,
      accent: palette.accent,
      fill: palette.tab,
      selected: widget.adapter.filterCategoryId == id,
      onTap: () => widget.adapter.onFilterChanged(id),
    );
  }

  String _allLabel(String locale) {
    switch (locale) {
      case 'ru':
        return 'Все';
      case 'de':
        return 'Alle';
      case 'fr':
        return 'Tous';
      case 'es':
        return 'Todo';
      case 'it':
        return 'Tutte';
      default:
        return 'All';
    }
  }
}

class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.label,
    required this.icon,
    required this.accent,
    required this.fill,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.onLongPress,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final mobile = MediaQuery.sizeOf(context).width <= 520;
    final actualFill = dark
        ? (selected
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer.withValues(alpha: 0.94))
        : fill;
    final actualAccent = dark ? scheme.onSurface : accent;
    final borderColor = dark
        ? scheme.outlineVariant.withValues(alpha: 0.72)
        : Color.lerp(actualFill, const Color(0xFFBFCAD8), 0.55)!;

    return Transform.translate(
      offset: Offset(0, selected ? 1 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: Container(
            height: 38,
            constraints: BoxConstraints(
              minWidth: compact ? 46 : (mobile ? 88 : 96),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : (mobile ? 14 : 18),
            ),
            decoration: BoxDecoration(
              color: actualFill,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                top: BorderSide(color: borderColor),
                left: BorderSide(color: borderColor),
                right: BorderSide(color: borderColor),
                bottom: BorderSide(
                  color: selected ? actualFill : Colors.transparent,
                  width: selected ? 0 : 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: dark ? 0.04 : 0.22),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: compact ? 16 : 15, color: actualAccent),
                if (!compact) ...[
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: actualAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Retained for compatibility with ListsPage. The production shell deliberately
/// does not render this row because the HTML uses a single New Note action.
class NotesGlmInlineAddRow extends StatelessWidget {
  const NotesGlmInlineAddRow({
    super.key,
    required this.locale,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final String locale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
