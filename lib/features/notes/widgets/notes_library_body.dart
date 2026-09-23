// Notes library body — responsive grid/list plus the existing desktop
// master-detail editor. Data and mutations remain in DatabaseService/ListsPage.

import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kNotesEmbeddedWorkspaceBreakpoint = 1100;
const String _kNotesDateSortPref = 'lifeos.notes.dateSort';

bool notesUsesEmbeddedWorkspace(double viewportWidth) =>
    viewportWidth >= kNotesEmbeddedWorkspaceBreakpoint;

enum _NotesDateSort { updated, created }

class NotesLibraryBody extends StatefulWidget {
  const NotesLibraryBody({
    super.key,
    required this.tasks,
    required this.view,
    required this.checkboxesOn,
    required this.onTap,
    required this.onLongPress,
    this.selectionMode = false,
    this.selectedKeys = const <String>{},
    this.itemKey,
    this.onToggleSelection,
    this.onOpenMenu,
    this.onRefresh,
  });

  final List<PlanningTask> tasks;
  final NotesLibraryView view;
  final bool checkboxesOn;
  final void Function(PlanningTask task) onTap;
  final void Function(PlanningTask task) onLongPress;
  final bool selectionMode;
  final Set<String> selectedKeys;
  final String Function(PlanningTask task)? itemKey;
  final ValueChanged<PlanningTask>? onToggleSelection;
  final void Function(Offset anchorCenter, PlanningTask task)? onOpenMenu;
  final Future<void> Function()? onRefresh;

  @override
  State<NotesLibraryBody> createState() => _NotesLibraryBodyState();
}

class _NotesLibraryBodyState extends State<NotesLibraryBody> {
  PlanningTask? _selectedTask;
  List<String>? _editingOrder;
  _NotesDateSort _dateSort = _NotesDateSort.updated;
  List<String>? _checkboxOrder;

  @override
  void initState() {
    super.initState();
    if (widget.checkboxesOn) _captureCheckboxOrder();
    unawaited(_loadDateSort());
    unawaited(_hydrateTimestamps());
  }

  @override
  void didUpdateWidget(covariant NotesLibraryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checkboxesOn) {
      _reconcileCheckboxOrder(reset: !oldWidget.checkboxesOn);
    } else if (oldWidget.checkboxesOn) {
      _checkboxOrder = null;
    }
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
    // Autosave/network refreshes may transiently omit the row. Do not tear down
    // the editor or keyboard focus until a stable replacement is available.
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
        final wide = notesUsesEmbeddedWorkspace(MediaQuery.sizeOf(context).width);
        final selected = wide ? _selectedTask : null;
        if (selected == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSortControl(context),
              const SizedBox(height: 7),
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

        final listWidth = (constraints.maxWidth * 0.27)
            .clamp(300.0, 380.0)
            .toDouble();
        final scheme = Theme.of(context).colorScheme;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: listWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSortControl(context),
                    const SizedBox(height: 7),
                    Expanded(
                      child: _withRefresh(
                        _buildCollection(
                          context,
                          cards,
                          view: NotesLibraryView.list,
                          availableWidth: listWidth,
                          selectedId: selected.planRowIdForBackend,
                          compactList: true,
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
              color: scheme.outlineVariant.withValues(alpha: 0.65),
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

  String _itemKey(PlanningTask task) {
    final custom = widget.itemKey;
    if (custom != null) return custom(task);
    final backend = task.planRowIdForBackend.trim();
    if (backend.isNotEmpty) return backend;
    return 'note-${task.id}-${task.order}-${task.title}';
  }

  void _captureCheckboxOrder() {
    final ordered = List<PlanningTask>.from(widget.tasks)..sort(_compareTasks);
    _checkboxOrder = [for (final task in ordered) _itemKey(task)];
  }

  void _reconcileCheckboxOrder({bool reset = false}) {
    if (reset || _checkboxOrder == null) {
      _captureCheckboxOrder();
      return;
    }
    final current = <String>{for (final task in widget.tasks) _itemKey(task)};
    _checkboxOrder!.removeWhere((id) => !current.contains(id));
    final known = _checkboxOrder!.toSet();
    final additions = List<PlanningTask>.from(widget.tasks)..sort(_compareTasks);
    for (final task in additions) {
      final id = _itemKey(task);
      if (known.add(id)) _checkboxOrder!.add(id);
    }
  }

  List<PlanningTask> _sortedTasks() {
    final out = List<PlanningTask>.from(widget.tasks);
    if (widget.checkboxesOn) {
      _reconcileCheckboxOrder();
      final rank = <String, int>{
        for (var i = 0; i < (_checkboxOrder?.length ?? 0); i++)
          _checkboxOrder![i]: i,
      };
      out.sort((a, b) {
        final ar = rank[_itemKey(a)] ?? (1 << 30);
        final br = rank[_itemKey(b)] ?? (1 << 30);
        return ar.compareTo(br);
      });
      return out;
    }

    final editingOrder = _editingOrder;
    if (_selectedTask != null && editingOrder != null) {
      final rank = <String, int>{
        for (var i = 0; i < editingOrder.length; i++) editingOrder[i]: i,
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
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<_NotesDateSort>(
        tooltip: _sortTooltip(locale),
        initialValue: _dateSort,
        onSelected: (value) => unawaited(_setDateSort(value)),
        itemBuilder: (context) => [
          PopupMenuItem<_NotesDateSort>(
            value: _NotesDateSort.updated,
            child: Text(_dateSortLabel(locale, _NotesDateSort.updated)),
          ),
          PopupMenuItem<_NotesDateSort>(
            value: _NotesDateSort.created,
            child: Text(_dateSortLabel(locale, _NotesDateSort.created)),
          ),
        ],
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                _dateSortLabel(locale, _dateSort),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sortTooltip(String locale) {
    switch (locale) {
      case 'ru': return 'Сортировка заметок';
      case 'de': return 'Notizen sortieren';
      case 'fr': return 'Trier les notes';
      case 'es': return 'Ordenar notas';
      case 'it': return 'Ordina note';
      default: return 'Sort notes';
    }
  }

  String _dateSortLabel(String locale, _NotesDateSort mode) {
    final created = mode == _NotesDateSort.created;
    switch (locale) {
      case 'ru': return created ? 'По дате создания' : 'По изменению';
      case 'de': return created ? 'Erstellungsdatum' : 'Letzte Änderung';
      case 'fr': return created ? 'Date de création' : 'Dernière modification';
      case 'es': return created ? 'Fecha de creación' : 'Última modificación';
      case 'it': return created ? 'Data di creazione' : 'Ultima modifica';
      default: return created ? 'Created' : 'Last modified';
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
    bool compactList = false,
  }) {
    final db = DatabaseService.instance;
    if (view == NotesLibraryView.grid) {
      final count = availableWidth >= 1180
          ? 5
          : availableWidth >= 900
              ? 4
              : availableWidth >= 640
                  ? 3
                  : availableWidth >= 400
                      ? 2
                      : 1;
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: count == 1 ? 1.65 : 1,
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

    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.42)
            : Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark
              ? scheme.outlineVariant.withValues(alpha: 0.68)
              : const Color(0xFFD8E0E9),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (!compactList) const _NotesListHeader(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: cards.length,
              itemBuilder: (context, index) => _card(
                context,
                cards[index],
                db,
                view: view,
                selected: cards[index].task.planRowIdForBackend == selectedId,
              ),
            ),
          ),
        ],
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
    final selectionKey = _itemKey(data.task);
    final bulkSelected =
        widget.selectionMode && widget.selectedKeys.contains(selectionKey);
    return NoteCard(
      data: data,
      view: view,
      checkboxesOn: widget.checkboxesOn,
      selected: selected || bulkSelected,
      onOpen: () {
        if (widget.selectionMode) {
          widget.onToggleSelection?.call(data.task);
          return;
        }
        _openNote(context, data.task);
      },
      onTogglePin: () => db.toggleNotePin(data.task.planRowIdForBackend),
      onToggleDone: () => db.toggleNoteDone(data.task.planRowIdForBackend),
      onLongPress: () => widget.onLongPress(data.task),
      onOpenMenu: (anchorCenter) => widget.onOpenMenu?.call(anchorCenter, data.task),
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

class _NotesListHeader extends StatelessWidget {
  const _NotesListHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
    );
    final loc = currentLocale.value;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: dark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.72)
            : kNotesFolderPane,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.62),
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 46),
          const SizedBox(width: 14),
          Expanded(flex: 16, child: Text(_headerNote(loc), style: labelStyle)),
          const SizedBox(width: 14),
          Expanded(flex: 12, child: Text(_headerContent(loc), style: labelStyle)),
          const SizedBox(width: 14),
          SizedBox(
            width: 100,
            child: Text(_headerStatus(loc), textAlign: TextAlign.right, style: labelStyle),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  String _headerNote(String loc) => loc == 'ru' ? 'ЗАМЕТКА' : 'NOTE';
  String _headerContent(String loc) => loc == 'ru' ? 'СОДЕРЖАНИЕ' : 'CONTENT';
  String _headerStatus(String loc) => loc == 'ru' ? 'СТАТУС' : 'STATUS';
}
