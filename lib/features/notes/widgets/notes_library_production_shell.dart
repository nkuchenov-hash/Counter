// Production Lists-tab Notes library shell.
// Visual structure follows LIFE_OS_Notes_MVP_v32_gapfix5.html directly while
// keeping the existing Lists/Brain callbacks as the data and mutation source.

import 'dart:async';
import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _kAllFolderSurface = Color(0xFFE3ECF8);
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
    final category = _categoryAdapter();
    final headerAdapter = _headerAdapter();
    final mobile = MediaQuery.sizeOf(context).width <= 520;
    final tabs = category == null
        ? categoryBar
        : _NotesPhysicalFolderTabs(
            adapter: category,
            onOpenSettings: headerAdapter?.onOpenSettings,
          );

    final newNote = () => unawaited(
          _createNewNote(
            context,
            preferredCategoryId: category?.filterCategoryId,
          ),
        );

    if (mobile && headerAdapter != null && category != null) {
      return NotesGlmLibraryFrame(
        child: _MobileNotesLibrary(
          header: headerAdapter,
          category: category,
          content: content,
          onNewNote: newNote,
        ),
      );
    }

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
              onNewNote: newNote,
            ),
          const SizedBox(height: 12),
          SizedBox(height: 42, child: tabs),
          Expanded(child: content),
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


class _MobileNotesLibrary extends StatelessWidget {
  const _MobileNotesLibrary({
    required this.header,
    required this.category,
    required this.content,
    required this.onNewNote,
  });

  final _NotesHeaderAdapter header;
  final _NotesCategoryAdapter category;
  final Widget content;
  final VoidCallback onNewNote;

  String _activeTitle() {
    final id = category.filterCategoryId;
    if (id == null) {
      switch (header.locale) {
        case 'ru':
          return 'Все заметки';
        default:
          return 'All notes';
      }
    }
    final rule = DatabaseService.instance.getCategoryRuleById(id);
    final name = rule?.name.trim() ?? '';
    return name.isEmpty ? '—' : name;
  }

  Future<void> _openFolders(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileNotesFoldersSheet(
        adapter: category,
        locale: header.locale,
        onOpenSettings: header.onOpenSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _MobileRoundAction(
                  icon: Icons.space_dashboard_outlined,
                  onTap: () => unawaited(_openFolders(context)),
                ),
                const Spacer(),
                _MobileNotesModePill(locale: header.locale),
                const Spacer(),
                _MobileNotesViewMenu(adapter: header),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _activeTitle(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 34,
                height: 1.02,
                letterSpacing: -0.9,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 86),
                child: content,
              ),
            ),
          ],
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 12,
          child: Row(
            children: [
              Expanded(
                child: NotesGlmLibraryInput(
                  controller: header.searchController,
                  focusNode: header.searchFocus,
                  hintText: t(header.locale, 'notes_v3_search_hint'),
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: header.onSearchChanged,
                  suffixIcon: header.searchQuery.trim().isNotEmpty
                      ? IconButton(
                          onPressed: header.onClearSearch,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              _MobileRoundAction(
                icon: Icons.edit_outlined,
                size: 58,
                onTap: onNewNote,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileNotesModePill extends StatelessWidget {
  const _MobileNotesModePill({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        t(locale, 'notes_v3_title'),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _MobileRoundAction extends StatelessWidget {
  const _MobileRoundAction({
    required this.icon,
    required this.onTap,
    this.size = 54,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: _MobileRoundActionVisual(icon: icon, size: size),
      ),
    );
  }
}

class _MobileRoundActionVisual extends StatelessWidget {
  const _MobileRoundActionVisual({
    required this.icon,
    required this.size,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 26, color: scheme.onSurface),
    );
  }
}

enum _MobileNotesViewAction { list, grid, checkboxes }

class _MobileNotesViewMenu extends StatelessWidget {
  const _MobileNotesViewMenu({required this.adapter});

  final _NotesHeaderAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_MobileNotesViewAction>(
      tooltip: t(adapter.locale, 'notes_editor_more_tooltip'),
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _MobileNotesViewAction.list:
            adapter.onViewChanged(NotesLibraryView.list);
          case _MobileNotesViewAction.grid:
            adapter.onViewChanged(NotesLibraryView.grid);
          case _MobileNotesViewAction.checkboxes:
            adapter.onCheckboxModeChanged(!adapter.checkboxesOn);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MobileNotesViewAction.list,
          child: Row(
            children: [
              Icon(
                Icons.view_list_rounded,
                color: adapter.notesView == NotesLibraryView.list
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(t(adapter.locale, 'notes_v3_view_list')),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MobileNotesViewAction.grid,
          child: Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: adapter.notesView == NotesLibraryView.grid
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(t(adapter.locale, 'notes_v3_view_grid')),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MobileNotesViewAction.checkboxes,
          child: Row(
            children: [
              Icon(
                adapter.checkboxesOn
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
              ),
              const SizedBox(width: 12),
              Text(
                adapter.checkboxesOn
                    ? t(adapter.locale, 'notes_v3_checkbox_mode_off')
                    : t(adapter.locale, 'notes_v3_checkbox_mode_on'),
              ),
            ],
          ),
        ),
      ],
      child: _MobileRoundActionVisual(
        icon: adapter.notesView == NotesLibraryView.grid
            ? Icons.grid_view_rounded
            : Icons.view_list_rounded,
        size: 54,
      ),
    );
  }
}

class _MobileNotesFoldersSheet extends StatelessWidget {
  const _MobileNotesFoldersSheet({
    required this.adapter,
    required this.locale,
    required this.onOpenSettings,
  });

  final _NotesCategoryAdapter adapter;
  final String locale;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      locale == 'ru' ? 'Папки' : 'Folders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenSettings();
                    },
                    child: Text(locale == 'ru' ? 'Настроить' : 'Manage'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                children: [
                  _MobileFolderRow(
                    icon: Icons.all_inbox_rounded,
                    label: locale == 'ru' ? 'Все заметки' : 'All notes',
                    selected: adapter.filterCategoryId == null,
                    onTap: () {
                      adapter.onFilterChanged(null);
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final id in adapter.chipIds)
                    _MobileCategoryFolderRow(
                      id: id,
                      selected: adapter.filterCategoryId == id,
                      onTap: () {
                        adapter.onFilterChanged(id);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCategoryFolderRow extends StatelessWidget {
  const _MobileCategoryFolderRow({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final int id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rule = DatabaseService.instance.getCategoryRuleById(id);
    if (rule == null) return const SizedBox.shrink();
    final icon = rule.iconCodePoint == null
        ? Icons.folder_outlined
        : IconData(rule.iconCodePoint!, fontFamily: 'MaterialIcons');
    return _MobileFolderRow(
      icon: icon,
      label: rule.name.trim().isEmpty ? '—' : rule.name.trim(),
      selected: selected,
      accent: rule.colorOrDefault,
      onTap: onTap,
    );
  }
}

class _MobileFolderRow extends StatelessWidget {
  const _MobileFolderRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = accent ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? tone.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 24, color: selected ? tone : scheme.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
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
        if (mobile) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  t(adapter.locale, 'notes_v3_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _NewNoteButton(locale: adapter.locale, onPressed: onNewNote),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ViewSwitch(adapter: adapter),
              const SizedBox(width: 8),
              _CheckboxModeButton(adapter: adapter),
            ],
          ),
        ] else
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    t(adapter.locale, 'notes_v3_title'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: wide ? 30 : 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                      color: scheme.onSurface,
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
        const SizedBox(height: 10),
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

Color _paneColorFor(int? categoryId) {
  if (categoryId == null) return _kAllFolderSurface;
  final rule = DatabaseService.instance.getCategoryRuleById(categoryId);
  if (rule == null) return _kAllFolderSurface;
  return Color.alphaBlend(
    rule.colorOrDefault.withValues(alpha: 0.12),
    const Color(0xFFF7F8FA),
  );
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
    return SizedBox(
      height: 42,
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
                accent: const Color(0xFF285B99),
                fill: _kAllFolderSurface,
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
    final accent = rule.colorOrDefault;
    final icon = rule.iconCodePoint == null
        ? Icons.folder_outlined
        : IconData(rule.iconCodePoint!, fontFamily: 'MaterialIcons');
    return _FolderTab(
      label: rule.name.trim().isEmpty ? '—' : rule.name.trim(),
      icon: icon,
      accent: accent,
      fill: _paneColorFor(id),
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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final mobile = MediaQuery.sizeOf(context).width <= 520;

    final selectedFill = dark
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.16),
            scheme.surfaceContainerHigh,
          )
        : Color.alphaBlend(
            accent.withValues(alpha: 0.13),
            const Color(0xFFFCFDFE),
          );
    final foreground = dark
        ? Color.lerp(accent, Colors.white, 0.22)!
        : Color.lerp(accent, const Color(0xFF111827), 0.08)!;
    final idleForeground = selected
        ? foreground
        : Color.lerp(
            foreground,
            scheme.onSurfaceVariant,
            dark ? 0.40 : 0.52,
          )!;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(compact ? 12 : 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 38,
            constraints: BoxConstraints(
              minWidth: compact ? 42 : (mobile ? 82 : 92),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : (mobile ? 12 : 14),
            ),
            decoration: BoxDecoration(
              color: compact
                  ? kNotesInk
                  : (selected ? selectedFill : Colors.transparent),
              borderRadius: BorderRadius.circular(compact ? 12 : 10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: compact ? 17 : 15,
                      color: compact ? Colors.white : idleForeground,
                    ),
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
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: idleForeground,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (selected && !compact)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: foreground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
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
