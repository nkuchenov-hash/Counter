// Notes library body — grid/list of [NoteCard]s for the Lists tab.
//
// Parses each [PlanningTask]'s [NoteDocument] once per build and renders
// the GLM v3 card layout. Used by [ListsPage] when not in bulk-select mode.

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:flutter/material.dart';

class NotesLibraryBody extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final scheme = Theme.of(context).colorScheme;
    final cards = <NoteCardData>[];
    for (final t in tasks) {
      final doc = db.parseNoteDocument(t);
      final stats = doc.computeStats();
      final cat = db.getCategoryRuleById(t.categoryId);
      cards.add(
        NoteCardData(
          task: t,
          doc: doc,
          stats: stats,
          categoryName: cat?.name,
          categoryColor: cat?.colorOrDefault ?? scheme.primary,
          categoryIconCodePoint: cat?.iconCodePoint,
          pinned: doc.meta.pinned,
        ),
      );
    }

    Widget body;
    final crossAxisCount = MediaQuery.sizeOf(context).width >= 720 ? 2 : 1;
    if (view == NotesLibraryView.grid) {
      body = GridView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: crossAxisCount == 2 ? 1.22 : 1.35,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _card(cards[i], db),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _card(cards[i], db),
      );
    }

    if (onRefresh == null) return body;
    return RefreshIndicator(onRefresh: onRefresh!, child: body);
  }

  Widget _card(NoteCardData data, DatabaseService db) {
    return NoteCard(
      data: data,
      view: view,
      checkboxesOn: checkboxesOn,
      onOpen: () => onTap(data.task),
      onTogglePin: () => db.toggleNotePin(data.task.planRowIdForBackend),
      onToggleDone: () => db.toggleNoteDone(data.task.planRowIdForBackend),
      onLongPress: () => onLongPress(data.task),
    );
  }
}
