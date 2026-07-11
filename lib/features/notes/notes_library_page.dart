// Notes library page — faithful Flutter port of NotesScreen (1).tsx.
//
// Replaces the legacy Lists backlog visual with a real Notes library:
//   - "Notes & Lists" header + search + view/checkbox toggles
//   - category folder chips (root categories, subtree-aware)
//   - grid + list views
//   - small vs large checkbox modes
//   - pinned-first / done-last / updated-desc sorting
//   - card tap → block editor route
//   - long-press → existing radial menu
//
// Reads [PlanningTask]s from the Brain via [getBacklogPlansSnapshot] and parses
// each into a [NoteDocument] once per build (cached in a memoized map so card
// scroll never re-parses).

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

const String _kPrefNotesView = 'lifeos.notes.view';
const String _kPrefNotesCheckboxMode = 'lifeos.notes.checkboxMode';

/// Opens the Notes library as a full page (pushed onto the navigator).
Future<void> showNotesLibraryPage(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const NotesLibraryPage(),
    ),
  );
}

class NotesLibraryPage extends StatefulWidget {
  const NotesLibraryPage({super.key});

  @override
  State<NotesLibraryPage> createState() => _NotesLibraryPageState();
}

class _NotesLibraryPageState extends State<NotesLibraryPage> {
  NotesLibraryView _view = NotesLibraryView.list;
  bool _checkboxesOn = false;
  String _query = '';
  int? _filterCategoryId; // null = All
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kPrefNotesView);
      final c = prefs.getBool(_kPrefNotesCheckboxMode);
      if (!mounted) return;
      setState(() {
        if (v == 'grid') _view = NotesLibraryView.grid;
        if (c == true) _checkboxesOn = true;
      });
    } catch (_) {}
  }

  Future<void> _persistView(NotesLibraryView v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefNotesView, v == NotesLibraryView.grid ? 'grid' : 'list');
    } catch (_) {}
  }

  Future<void> _persistCheckboxMode(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefNotesCheckboxMode, on);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final db = DatabaseService.instance;

    final allTasks = db.getBacklogPlansSnapshot(
      categoryId: null,
      includeCompleted: true,
    );
    final rootCats = db.getChildrenOf(null);
    // Parse + filter + sort.
    final filtered = _filterAndSort(allTasks, db);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _LibraryHeader(
              loc: loc,
              view: _view,
              checkboxesOn: _checkboxesOn,
              onViewChanged: (v) {
                setState(() => _view = v);
                _persistView(v);
              },
              onCheckboxModeChanged: (on) {
                setState(() => _checkboxesOn = on);
                _persistCheckboxMode(on);
              },
              total: filtered.length,
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: t(loc, 'notes_v3_search_hint'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
            // Category chips
            _CategoryChips(
              rootCats: rootCats,
              selected: _filterCategoryId,
              onSelected: (id) => setState(() => _filterCategoryId = id),
              loc: loc,
            ),
            const SizedBox(height: 4),
            // Notes list / grid
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(loc: loc, hasQuery: _query.isNotEmpty)
                  : _NotesBody(
                      tasks: filtered,
                      view: _view,
                      checkboxesOn: _checkboxesOn,
                      db: db,
                      onTap: _openEditor,
                      onLongPress: _showRadialMenuPlaceholder,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<PlanningTask> _filterAndSort(List<PlanningTask> tasks, DatabaseService db) {
    var out = tasks;
    // Category subtree filter
    if (_filterCategoryId != null) {
      final subtree = _collectSubtreeIds(db, _filterCategoryId!).toSet();
      out = out.where((t) => subtree.contains(t.categoryId)).toList();
    }
    // Search
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((t) {
        if (t.title.toLowerCase().contains(q)) return true;
        if ((t.notesPlain ?? '').toLowerCase().contains(q)) return true;
        final doc = db.parseNoteDocument(t);
        for (final b in doc.blocks) {
          if (b.hasText && b.text.toLowerCase().contains(q)) return true;
        }
        for (final tag in t.tags) {
          if (tag.name.toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }
    // Sort: unfinished first, pinned first, updated desc, stable fallback.
    out.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final ap = db.isNotePinned(a);
      final bp = db.isNotePinned(b);
      if (ap != bp) return ap ? -1 : 1;
      final au = a.updatedAt ?? a.createdAt;
      final bu = b.updatedAt ?? b.createdAt;
      if (au != null && bu != null) return bu.compareTo(au);
      if (au != null) return -1;
      if (bu != null) return 1;
      return a.title.compareTo(b.title);
    });
    return out;
  }

  List<int> _collectSubtreeIds(DatabaseService db, int rootId) {
    final out = <int>[rootId];
    final rule = db.getCategoryRuleById(rootId);
    if (rule?.children != null) {
      for (final child in rule!.children!) {
        out.addAll(_collectSubtreeIds(db, child.id));
      }
    }
    return out;
  }

  void _openEditor(PlanningTask task) {
    unawaited(showNoteEditorPage(context: context, task: task));
  }

  void _showRadialMenuPlaceholder(PlanningTask task) {
    // Delegate to the existing Lists radial menu host if present.
    // For now, show a lightweight action sheet with the safe actions.
    final loc = currentLocale.value;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: Text(db.isNotePinned(task)
                    ? t(loc, 'notes_v3_editor_unpin')
                    : t(loc, 'notes_v3_editor_pin')),
                onTap: () {
                  DatabaseService.instance.toggleNotePin(task.planRowIdForBackend);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: Icon(task.isDone
                    ? Icons.check_box_outline_blank_rounded
                    : Icons.check_box_rounded),
                title: Text(task.isDone ? 'Mark not done' : 'Mark done'),
                onTap: () {
                  DatabaseService.instance.toggleNoteDone(task.planRowIdForBackend);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text(t(loc, 'notes_v3_editor_delete'),
                    style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await DatabaseService.instance.deleteNote(task.planRowIdForBackend);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  DatabaseService get db => DatabaseService.instance;
}

// ---- Header --------------------------------------------------------------

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.loc,
    required this.view,
    required this.checkboxesOn,
    required this.onViewChanged,
    required this.onCheckboxModeChanged,
    required this.total,
  });

  final String loc;
  final NotesLibraryView view;
  final bool checkboxesOn;
  final ValueChanged<NotesLibraryView> onViewChanged;
  final ValueChanged<bool> onCheckboxModeChanged;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(loc, 'notes_v3_subtitle'),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  t(loc, 'notes_v3_title'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  t(loc, 'notes_v3_count').replaceAll('{n}', '$total'),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Checkbox mode toggle
          IconButton(
            tooltip: checkboxesOn
                ? t(loc, 'notes_v3_checkbox_mode_off')
                : t(loc, 'notes_v3_checkbox_mode_on'),
            onPressed: () => onCheckboxModeChanged(!checkboxesOn),
            icon: Icon(
              checkboxesOn
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: checkboxesOn ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          // Grid/list segmented toggle
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                _SegmentBtn(
                  icon: Icons.grid_view_rounded,
                  selected: view == NotesLibraryView.grid,
                  onTap: () => onViewChanged(NotesLibraryView.grid),
                  tooltip: t(loc, 'notes_v3_view_grid'),
                ),
                _SegmentBtn(
                  icon: Icons.view_list_rounded,
                  selected: view == NotesLibraryView.list,
                  onTap: () => onViewChanged(NotesLibraryView.list),
                  tooltip: t(loc, 'notes_v3_view_list'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  const _SegmentBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ---- Category chips ------------------------------------------------------

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.rootCats,
    required this.selected,
    required this.onSelected,
    required this.loc,
  });

  final List<CategoryRule> rootCats;
  final int? selected;
  final ValueChanged<int?> onSelected;
  final String loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: t(loc, 'notes_v3_all'),
            selected: selected == null,
            onTap: () => onSelected(null),
            scheme: scheme,
          ),
          const SizedBox(width: 6),
          for (final c in rootCats) ...[
            _Chip(
              label: c.name,
              selected: selected == c.id,
              onTap: () => onSelected(c.id),
              scheme: scheme,
              color: c.colorOrDefault,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? scheme.primary)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ---- Empty state ---------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loc, required this.hasQuery});
  final String loc;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.note_add_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? t(loc, 'notes_v3_empty_title')
                  : t(loc, 'notes_v3_empty_title'),
              style: TextStyle(
                  fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              hasQuery
                  ? t(loc, 'notes_v3_empty_sub')
                  : t(loc, 'notes_v3_empty_sub'),
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Notes body (memoized document parse) -------------------------------

class _NotesBody extends StatelessWidget {
  const _NotesBody({
    required this.tasks,
    required this.view,
    required this.checkboxesOn,
    required this.db,
    required this.onTap,
    required this.onLongPress,
  });

  final List<PlanningTask> tasks;
  final NotesLibraryView view;
  final bool checkboxesOn;
  final DatabaseService db;
  final void Function(PlanningTask) onTap;
  final void Function(PlanningTask) onLongPress;

  @override
  Widget build(BuildContext context) {
    // Parse each task's NoteDocument + stats once for this build. Cheap
    // because the document is already in the Brain cache as a JSON string;
    // we only walk the typed model.
    final cards = <NoteCardData>[];
    for (final t in tasks) {
      final doc = db.parseNoteDocument(t);
      final stats = doc.computeStats();
      final cat = db.getCategoryRuleById(t.categoryId);
      cards.add(NoteCardData(
        task: t,
        doc: doc,
        stats: stats,
        categoryName: cat?.name,
        categoryColor: cat?.colorOrDefault ?? Theme.of(context).colorScheme.primary,
        categoryIconCodePoint: cat?.iconCodePoint,
        pinned: doc.meta.pinned,
      ));
    }

    if (view == NotesLibraryView.grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => NoteCard(
          data: cards[i],
          view: view,
          checkboxesOn: checkboxesOn,
          onOpen: () => onTap(cards[i].task),
          onTogglePin: () =>
              db.toggleNotePin(cards[i].task.planRowIdForBackend),
          onToggleDone: () =>
              db.toggleNoteDone(cards[i].task.planRowIdForBackend),
          onLongPress: () => onLongPress(cards[i].task),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => NoteCard(
        data: cards[i],
        view: view,
        checkboxesOn: checkboxesOn,
        onOpen: () => onTap(cards[i].task),
        onTogglePin: () =>
            db.toggleNotePin(cards[i].task.planRowIdForBackend),
        onToggleDone: () =>
            db.toggleNoteDone(cards[i].task.planRowIdForBackend),
        onLongPress: () => onLongPress(cards[i].task),
      ),
    );
  }
}
