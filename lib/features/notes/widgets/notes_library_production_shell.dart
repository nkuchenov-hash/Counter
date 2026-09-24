// Production Lists-tab Notes library shell.
// The v32 reference is a physical folder workspace: category divider tabs are
// visually attached to one continuous colored pane. Data/actions still stay in
// ListsPage; this file only adapts the existing category-bar callbacks.

import 'dart:async';
import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/features/lists/lists_filters.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _kAllFolderSurface = Color(0xFFE3ECF8);
const String _kChipModePrefsKey = 'list_chip_mode';
const String _kPinnedIdsPrefsKey = 'list_pinned_ids';

/// Full-bleed Notes library workspace.
///
/// The Lists page still supplies [ListsCategoryChipBar] so filtering, persisted
/// category state and the Brain stay unchanged. In Notes presentation we adapt
/// that bar into the physical divider-tabs from LIFE_OS_Notes_MVP_v32_gapfix5.
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
    Widget candidate = categoryBar;
    if (candidate is SizedBox && candidate.child != null) {
      candidate = candidate.child!;
    }
    if (candidate is! ListsCategoryChipBar) return null;
    return _NotesCategoryAdapter(
      chipIds: candidate.chipIds,
      chipMode: candidate.chipMode,
      filterCategoryId: candidate.filterCategoryId,
      scrollController: candidate.scrollController,
      onFilterChanged: candidate.onFilterChanged,
      onManualChipReorder: candidate.onManualChipReorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final adapter = _categoryAdapter();
    final paneFill = dark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.88)
        : _paneColorFor(adapter?.filterCategoryId);
    final paneBorder = dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.70)
        : Color.lerp(paneFill, const Color(0xFFBFCAD8), 0.30)!;

    final tabs = adapter == null
        ? categoryBar
        : _NotesPhysicalFolderTabs(adapter: adapter);

    return NotesGlmLibraryFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBar != null) topBar!,
          header,
          if (!categoryBarInHeader) ...[
            const SizedBox(height: 11),
            SizedBox(
              height: 45,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: tabs,
              ),
            ),
          ],
          Expanded(
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
                          color: const Color(0xFF3F536C).withValues(alpha: 0.045),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              padding: EdgeInsets.fromLTRB(
                mobile ? 12 : 28,
                mobile ? 14 : 22,
                mobile ? 12 : 28,
                mobile ? 10 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (categoryBarInHeader) tabs,
                  if (tagBar != null) ...[
                    if (categoryBarInHeader) const SizedBox(height: 6),
                    tagBar!,
                  ],
                  if (inlineAdd != null) ...[
                    SizedBox(height: tagBar != null ? 8 : 2),
                    inlineAdd!,
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 2),
                  Expanded(child: content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _paneColorFor(int? categoryId) {
  if (categoryId == null) return _kAllFolderSurface;
  final rule = DatabaseService.instance.getCategoryRuleById(categoryId);
  if (rule == null) return _kAllFolderSurface;
  return Color.alphaBlend(
    rule.colorOrDefault.withValues(alpha: 0.16),
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
  const _NotesPhysicalFolderTabs({required this.adapter});

  final _NotesCategoryAdapter adapter;

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
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        controller: widget.adapter.scrollController,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        children: [
          _FolderTab(
            label: _allLabel(currentLocale.value),
            icon: Icons.format_list_bulleted_rounded,
            accent: const Color(0xFF285B99),
            fill: _kAllFolderSurface,
            selected: widget.adapter.filterCategoryId == null,
            onTap: () => widget.adapter.onFilterChanged(null),
          ),
          for (final id in ids) _categoryTab(id),
          _FolderTab(
            label: '',
            icon: Icons.add_rounded,
            accent: Colors.white,
            fill: const Color(0xFF111827),
            selected: false,
            compact: true,
            onTap: () => unawaited(_editSections()),
          ),
        ],
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
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final actualFill = dark
        ? (selected
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer.withValues(alpha: 0.94))
        : fill;
    final actualAccent = dark ? scheme.onSurface : accent;
    final borderColor = dark
        ? scheme.outlineVariant.withValues(alpha: 0.72)
        : Color.lerp(actualFill, const Color(0xFF98A8BA), 0.38)!;

    return Transform.translate(
      offset: Offset(0, selected ? 1 : 0),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Container(
              height: 38,
              constraints: BoxConstraints(minWidth: compact ? 46 : 88),
              padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 16),
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
                    color: selected ? actualFill : borderColor,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 6,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: compact ? 17 : 15, color: actualAccent),
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
      ),
    );
  }
}

/// Existing quick-add contract. This stays intact so creation still goes
/// through DatabaseService.createEmptyNote and opens the real Notes editor.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: NotesGlmLibraryInput(
            controller: controller,
            focusNode: focusNode,
            hintText: t(locale, 'input_placeholder_list'),
            textInputAction: TextInputAction.done,
            showSearchIcon: false,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: kNotesLibraryControlHeight,
          child: Material(
            color: kNotesInk,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSubmit,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      t(locale, 'add'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
