// Notes library body — grid/list of [NoteCard]s for the Lists tab.
//
// Mobile delegates to the dedicated full-screen editor route. Wide web and
// desktop use a real master-detail workspace: the note list stays in the
// layout and the editor occupies the remaining content area without dialogs,
// overlays, or a nested mobile screen.

import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kNotesEmbeddedWorkspaceBreakpoint = 1100;
const String _kNotesDateSortPref = 'lifeos.notes.dateSort';

bool notesUsesEmbeddedWorkspace(double viewportWidth) {
  return viewportWidth >= kNotesEmbeddedWorkspaceBreakpoint;
}

enum _NotesDateSort { updated, created }

class NotesLibraryBody extends StatefulWidget {
  const NotesLibraryBody({
    super.key,
    required this.tasks,
    required this.view,
    required this.checkboxesOn,
    required this.onTap,
    required this.onLongPress,
    this.onRefresh,
  });

  final List<PlanningTask> tasks;
  final NotesLibraryView view;
  final bool checkboxesOn;
  final void Function(PlanningTask task) onTap;
  final void Function(PlanningTask task) onLongPress;
  final Future<void> Function()? onRefresh;

  @override
  State<NotesLibraryBody> createState() => _NotesLibraryBodyState();
}

class _NotesLibraryBodyState extends State<NotesLibraryBody> {
  PlanningTask? _selectedTask;
  List<String>? _editingOrder;
  _NotesDateSort _dateSort = _NotesDateSort.updated;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDateSort());
    unawaited(_hydrateTimestamps());
  }

  @override
  void didUpdateWidget(covariant NotesLibraryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks.any(
      (task) => task.createdAt == null || task.updatedAt == null,
    )) {
      unawaited(_hydrateTimestamps(force: true));
    }
    final selectedId = _selectedTask?.planRowIdForBackend;
    if (selectedId == null) return;
    PlanningTask? refreshed;
    for (final task in widget.tasks) {
      if (task.planRowIdForBackend == selectedId) {
        refreshed = task;
        break;
      }
    }
    // A background refresh may briefly omit the row while its autosave PATCH is
    // in flight. Never destroy the editor/focus for that transient snapshot.
    if (refreshed != null) _selectedTask = refreshed;
  }

  Future<void> _hydrateTimestamps({bool force = false}) async {
    await DatabaseService.instance.ensureNoteTimestampsHydrated(force: force);
    if (mounted) setState(() {});
  }

  Future<void> _loadDateSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNotesDateSortPref);
      if (!mounted) return;
      setState(() {
        _dateSort = raw == 'created'
            ? _NotesDateSort.created
            : _NotesDateSort.updated;
      });
    } catch (_) {}
  }

  Future<void> _setDateSort(_NotesDateSort value) async {
    if (_dateSort == value) return;
    setState(() {
      _dateSort = value;
      // A manual sort choice is intentional; establish a new stable order for
      // the remainder of this edit session instead of letting autosave reshuffle it.
      if (_selectedTask != null) {
        _editingOrder = null;
        _editingOrder = _sortedTasks()
            .map((task) => task.planRowIdForBackend)
            .toList(growable: false);
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kNotesDateSortPref,
        value == _NotesDateSort.created ? 'created' : 'updated',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _sortedTasks();
    final cards = _buildCards(context, tasks);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The production library is intentionally capped below 1100px.
        // Therefore the embedded-editor decision must use the viewport width,
        // not this inner constrained width, or desktop mode can never activate.
        final wide = notesUsesEmbeddedWorkspace(
          MediaQuery.sizeOf(context).width,
        );
        final selected = wide ? _selectedTask : null;
        if (selected == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSortControl(context),
              const SizedBox(height: 6),
              Expanded(
                child: _withRefresh(
                  _buildCollection(
                    context,
                    cards,
                    view: widget.view,
                    availableWidth: constraints.maxWidth,
                  ),
                ),
              ),
            ],
          );
        }

        final listWidth = (constraints.maxWidth * 0.26)
            .clamp(280.0, 360.0)
            .toDouble();
        final scheme = Theme.of(context).colorScheme;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: listWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSortControl(context),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _withRefresh(
                        _buildCollection(
                          context,
                          cards,
                          view: NotesLibraryView.list,
                          availableWidth: listWidth,
                          selectedId: selected.planRowIdForBackend,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(
                alpha: dark ? 0.88 : 0.65,
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: scheme.surface,
                child: NotesEmbeddedEditorScope(
                  onClose: _closeEmbeddedEditor,
                  child: NoteEditorPage(
                    key: ValueKey<String>(
                      'embedded-note-${selected.planRowIdForBackend}',
                    ),
                    task: selected,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _compareTasks(PlanningTask a, PlanningTask b) {
    final db = DatabaseService.instance;
    if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
    final ap = db.isNotePinned(a);
    final bp = db.isNotePinned(b);
    if (ap != bp) return ap ? -1 : 1;
    final ad = _dateSort == _NotesDateSort.created
        ? (a.createdAt ?? a.updatedAt)
        : (a.updatedAt ?? a.createdAt);
    final bd = _dateSort == _NotesDateSort.created
        ? (b.createdAt ?? b.updatedAt)
        : (b.updatedAt ?? b.createdAt);
    if (ad != null && bd != null) {
      final byDate = bd.compareTo(ad);
      if (byDate != 0) return byDate;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    return a.title.compareTo(b.title);
  }

  List<PlanningTask> _sortedTasks() {
    final out = List<PlanningTask>.from(widget.tasks);
    final editingOrder = _editingOrder;
    if (_selectedTask != null && editingOrder != null) {
      final rank = <String, int>{
        for (var index = 0; index < editingOrder.length; index++)
          editingOrder[index]: index,
      };
      out.sort((a, b) {
        final ar = rank[a.planRowIdForBackend];
        final br = rank[b.planRowIdForBackend];
        if (ar != null && br != null) return ar.compareTo(br);
        if (ar != null) return -1;
        if (br != null) return 1;
        return _compareTasks(a, b);
      });
      return out;
    }
    out.sort(_compareTasks);
    return out;
  }

  Widget _buildSortControl(BuildContext context) {
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final label = _dateSortLabel(locale, _dateSort);
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<_NotesDateSort>(
        tooltip: _sortTooltip(locale),
        initialValue: _dateSort,
        onSelected: (value) => unawaited(_setDateSort(value)),
        itemBuilder: (context) => [
          PopupMenuItem<_NotesDateSort>(
            value: _NotesDateSort.updated,
            child: Row(
              children: [
                const Icon(Icons.update_rounded, size: 18),
                const SizedBox(width: 8),
                Text(_dateSortLabel(locale, _NotesDateSort.updated)),
              ],
            ),
          ),
          PopupMenuItem<_NotesDateSort>(
            value: _NotesDateSort.created,
            child: Row(
              children: [
                const Icon(Icons.event_available_outlined, size: 18),
                const SizedBox(width: 8),
                Text(_dateSortLabel(locale, _NotesDateSort.created)),
              ],
            ),
          ),
        ],
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sort_rounded,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sortTooltip(String locale) {
    switch (locale) {
      case 'ru':
        return 'Сортировка заметок';
      case 'fr':
        return 'Trier les notes';
      case 'de':
        return 'Notizen sortieren';
      case 'es':
        return 'Ordenar notas';
      case 'it':
        return 'Ordina note';
      case 'ko':
        return '노트 정렬';
      case 'zh':
        return '笔记排序';
      case 'ar':
        return 'ترتيب الملاحظات';
      default:
        return 'Sort notes';
    }
  }

  String _dateSortLabel(String locale, _NotesDateSort mode) {
    final created = mode == _NotesDateSort.created;
    switch (locale) {
      case 'ru':
        return created ? 'По дате создания' : 'По последнему изменению';
      case 'fr':
        return created ? 'Date de création' : 'Dernière modification';
      case 'de':
        return created ? 'Erstellungsdatum' : 'Letzte Änderung';
      case 'es':
        return created ? 'Fecha de creación' : 'Última modificación';
      case 'it':
        return created ? 'Data di creazione' : 'Ultima modifica';
      case 'ko':
        return created ? '생성일' : '최근 수정';
      case 'zh':
        return created ? '创建日期' : '最近修改';
      case 'ar':
        return created ? 'تاريخ الإنشاء' : 'آخر تعديل';
      default:
        return created ? 'Created' : 'Last modified';
    }
  }

  List<NoteCardData> _buildCards(
    BuildContext context,
    List<PlanningTask> tasks,
  ) {
    final db = DatabaseService.instance;
    final scheme = Theme.of(context).colorScheme;
    return [
      for (final task in tasks)
        () {
          final doc = db.parseNoteDocument(task);
          final category = db.getCategoryRuleById(task.categoryId);
          return NoteCardData(
            task: task,
            doc: doc,
            stats: doc.computeStats(),
            categoryName: category?.name,
            categoryColor: category?.colorOrDefault ?? scheme.primary,
            categoryIconCodePoint: category?.iconCodePoint,
            pinned: doc.meta.pinned,
          );
        }(),
    ];
  }

  Widget _buildCollection(
    BuildContext context,
    List<NoteCardData> cards, {
    required NotesLibraryView view,
    required double availableWidth,
    String? selectedId,
  }) {
    final db = DatabaseService.instance;
    if (view == NotesLibraryView.grid) {
      final crossAxisCount = availableWidth >= 720 ? 2 : 1;
      return GridView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: crossAxisCount == 2 ? 1.22 : 1.35,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) => _card(
          context,
          cards[index],
          db,
          view: view,
          selected: cards[index].task.planRowIdForBackend == selectedId,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _card(
        context,
        cards[index],
        db,
        view: view,
        selected: cards[index].task.planRowIdForBackend == selectedId,
      ),
    );
  }

  Widget _card(
    BuildContext context,
    NoteCardData data,
    DatabaseService db, {
    required NotesLibraryView view,
    required bool selected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
      ),
      child: NoteCard(
        data: data,
        view: view,
        checkboxesOn: widget.checkboxesOn,
        selected: selected,
        onOpen: () => _openNote(context, data.task),
        onTogglePin: () => db.toggleNotePin(data.task.planRowIdForBackend),
        onToggleDone: () => db.toggleNoteDone(data.task.planRowIdForBackend),
        onLongPress: () => widget.onLongPress(data.task),
      ),
    );
  }

  Widget _withRefresh(Widget child) {
    if (widget.onRefresh == null) return child;
    return RefreshIndicator(onRefresh: _refresh, child: child);
  }

  Future<void> _refresh() async {
    final refresh = widget.onRefresh;
    if (refresh != null) await refresh();
    await DatabaseService.instance.ensureNoteTimestampsHydrated(force: true);
    if (mounted) setState(() {});
  }

  void _openNote(BuildContext context, PlanningTask task) {
    if (!notesUsesEmbeddedWorkspace(MediaQuery.sizeOf(context).width)) {
      widget.onTap(task);
      return;
    }
    final order = _sortedTasks()
        .map((row) => row.planRowIdForBackend)
        .toList(growable: false);
    setState(() {
      _editingOrder = order;
      _selectedTask = task;
    });
  }

  void _closeEmbeddedEditor() {
    if (!mounted) return;
    setState(() {
      _selectedTask = null;
      _editingOrder = null;
    });
    final refresh = widget.onRefresh;
    if (refresh != null) unawaited(_refresh());
  }
}
