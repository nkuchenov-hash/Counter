// Notes library body — v32-gapfix5 grid/list geometry plus the existing
// desktop master-detail editor. Data and mutations remain in ListsPage/Brain.

import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

const double kNotesEmbeddedWorkspaceBreakpoint = 1100;

bool notesUsesEmbeddedWorkspace(double workspaceWidth) =>
    workspaceWidth >= kNotesEmbeddedWorkspaceBreakpoint;

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
  double _lastWorkspaceWidth = 0;

  @override
  void initState() {
    super.initState();
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
    for (final task in widget.tasks) {
      if (task.planRowIdForBackend == selectedId) {
        _selectedTask = task;
        return;
      }
    }
    // Autosave/network refreshes may transiently omit the row. Keep editor
    // focus alive until the stable replacement snapshot arrives.
  }

  Future<void> _hydrateTimestamps({bool force = false}) async {
    await DatabaseService.instance.ensureNoteTimestampsHydrated(force: force);
    if (mounted) setState(() {});
  }

  List<PlanningTask> _orderedTasks() {
    final out = List<PlanningTask>.from(widget.tasks);
    final order = _editingOrder;
    if (_selectedTask == null || order == null) return out;
    final rank = <String, int>{
      for (var i = 0; i < order.length; i++) order[i]: i,
    };
    out.sort((a, b) {
      final ar = rank[a.planRowIdForBackend];
      final br = rank[b.planRowIdForBackend];
      if (ar != null && br != null) return ar.compareTo(br);
      if (ar != null) return -1;
      if (br != null) return 1;
      return 0;
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _orderedTasks();
    final cards = _buildCards(context, tasks);
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastWorkspaceWidth = constraints.maxWidth;
        final wide = notesUsesEmbeddedWorkspace(constraints.maxWidth);
        final selected = wide ? _selectedTask : null;

        if (selected == null) {
          return _withRefresh(
            _buildCollection(
              context,
              cards,
              view: widget.view,
              availableWidth: constraints.maxWidth,
            ),
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

  String _itemKey(PlanningTask task) {
    final custom = widget.itemKey;
    if (custom != null) return custom(task);
    final backend = task.planRowIdForBackend.trim();
    if (backend.isNotEmpty) return backend;
    return 'note-${task.id}-${task.order}-${task.title}';
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
      final count = availableWidth > 1280
          ? 5
          : availableWidth > 1023
              ? 4
              : availableWidth > 520
                  ? 2
                  : 1;
      final mobileSingle = availableWidth <= 520;
      return GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
          mainAxisExtent: mobileSingle ? 170 : null,
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
              physics: const AlwaysScrollableScrollPhysics(),
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
      onOpenMenu: (anchorCenter) =>
          widget.onOpenMenu?.call(anchorCenter, data.task),
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
    if (!notesUsesEmbeddedWorkspace(_lastWorkspaceWidth)) {
      widget.onTap(task);
      return;
    }
    setState(() {
      _editingOrder = [
        for (final row in widget.tasks) row.planRowIdForBackend,
      ];
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 820;
        final mid = constraints.maxWidth <= 1180;
        final gap = mid ? 10.0 : 14.0;
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
              SizedBox(width: gap),
              Expanded(
                flex: mid ? 145 : 160,
                child: Text(_headerNote(loc), style: labelStyle),
              ),
              if (!compact) ...[
                SizedBox(width: gap),
                Expanded(
                  flex: mid ? 100 : 125,
                  child: Text(_headerContent(loc), style: labelStyle),
                ),
              ],
              SizedBox(width: gap),
              SizedBox(
                width: compact ? 80 : (mid ? 90 : 100),
                child: Text(
                  _headerStatus(loc),
                  textAlign: TextAlign.right,
                  style: labelStyle,
                ),
              ),
              const SizedBox(width: 34),
            ],
          ),
        );
      },
    );
  }

  String _headerNote(String loc) => loc == 'ru' ? 'ЗАМЕТКА' : 'NOTE';
  String _headerContent(String loc) => loc == 'ru' ? 'СОДЕРЖАНИЕ' : 'CONTENT';
  String _headerStatus(String loc) => loc == 'ru' ? 'СТАТУС' : 'STATUS';
}
