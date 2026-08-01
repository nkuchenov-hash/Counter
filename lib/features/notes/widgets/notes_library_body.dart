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
import 'package:flutter/material.dart';

const double kNotesEmbeddedWorkspaceBreakpoint = 1100;

bool notesUsesEmbeddedWorkspace(double viewportWidth) {
  return viewportWidth >= kNotesEmbeddedWorkspaceBreakpoint;
}

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

  @override
  void didUpdateWidget(covariant NotesLibraryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedId = _selectedTask?.planRowIdForBackend;
    if (selectedId == null) return;
    PlanningTask? refreshed;
    for (final task in widget.tasks) {
      if (task.planRowIdForBackend == selectedId) {
        refreshed = task;
        break;
      }
    }
    _selectedTask = refreshed;
  }

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards(context);
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
          return _withRefresh(
            _buildCollection(
              context,
              cards,
              view: widget.view,
              availableWidth: constraints.maxWidth,
            ),
          );
        }

        final listWidth = (constraints.maxWidth * 0.26)
            .clamp(280.0, 360.0)
            .toDouble();
        final scheme = Theme.of(context).colorScheme;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: listWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
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

  List<NoteCardData> _buildCards(BuildContext context) {
    final db = DatabaseService.instance;
    final scheme = Theme.of(context).colorScheme;
    return [
      for (final task in widget.tasks)
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
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: selected
            ? Border.all(color: scheme.primary.withValues(alpha: 0.42))
            : null,
      ),
      child: NoteCard(
        data: data,
        view: view,
        checkboxesOn: widget.checkboxesOn,
        onOpen: () => _openNote(context, data.task),
        onTogglePin: () => db.toggleNotePin(data.task.planRowIdForBackend),
        onToggleDone: () => db.toggleNoteDone(data.task.planRowIdForBackend),
        onLongPress: () => widget.onLongPress(data.task),
      ),
    );
  }

  Widget _withRefresh(Widget child) {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return child;
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }

  void _openNote(BuildContext context, PlanningTask task) {
    if (!notesUsesEmbeddedWorkspace(MediaQuery.sizeOf(context).width)) {
      widget.onTap(task);
      return;
    }
    setState(() => _selectedTask = task);
  }

  void _closeEmbeddedEditor() {
    if (!mounted) return;
    setState(() => _selectedTask = null);
    final refresh = widget.onRefresh;
    if (refresh != null) unawaited(refresh());
  }
}
