// Notes library body — grid/list of [NoteCard]s for the Lists tab.
//
// Mobile delegates to the dedicated full-screen editor route. Wide web and
// desktop keep the surrounding app shell and library visible while opening the
// editor in a finite right-side workspace pane.

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
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
    for (final task in tasks) {
      final doc = db.parseNoteDocument(task);
      final stats = doc.computeStats();
      final category = db.getCategoryRuleById(task.categoryId);
      cards.add(
        NoteCardData(
          task: task,
          doc: doc,
          stats: stats,
          categoryName: category?.name,
          categoryColor: category?.colorOrDefault ?? scheme.primary,
          categoryIconCodePoint: category?.iconCodePoint,
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
        itemBuilder: (context, index) => _card(context, cards[index], db),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) => _card(context, cards[index], db),
      );
    }

    if (onRefresh == null) return body;
    return RefreshIndicator(onRefresh: onRefresh!, child: body);
  }

  Widget _card(BuildContext context, NoteCardData data, DatabaseService db) {
    return NoteCard(
      data: data,
      view: view,
      checkboxesOn: checkboxesOn,
      onOpen: () => _openNote(context, data.task),
      onTogglePin: () => db.toggleNotePin(data.task.planRowIdForBackend),
      onToggleDone: () => db.toggleNoteDone(data.task.planRowIdForBackend),
      onLongPress: () => onLongPress(data.task),
    );
  }

  void _openNote(BuildContext context, PlanningTask task) {
    if (MediaQuery.sizeOf(context).width < 900) {
      onTap(task);
      return;
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) {
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth = (constraints.maxWidth - 360)
                  .clamp(620.0, 960.0)
                  .toDouble();
              final panelHeight = (constraints.maxHeight - 24)
                  .clamp(0.0, constraints.maxHeight)
                  .toDouble();
              return Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: panelWidth,
                    height: panelHeight,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                      clipBehavior: Clip.antiAlias,
                      child: NoteEditorPage(task: task),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }
}
