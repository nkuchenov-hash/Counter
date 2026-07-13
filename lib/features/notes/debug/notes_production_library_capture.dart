// Production-library visual capture using the live Lists-tab shell widgets.

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/debug/notes_glm_parity_fixture.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/features/notes/widgets/notes_library_production_shell.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

const Key kNotesProductionLibraryCaptureKey =
    Key('notes_production_library_capture');

/// Renders the same shell + card widgets as the live Lists tab.
class NotesProductionLibraryCapture extends StatelessWidget {
  const NotesProductionLibraryCapture({super.key});

  static NoteCardData cardFor({
    required String title,
    required String categoryName,
    required Color categoryColor,
    required IconData icon,
    required NoteDocument doc,
    bool pinned = false,
  }) {
    return NoteCardData(
      task: PlanningTask(
        id: 0,
        planRowId: 'capture-$title',
        title: title,
        categoryId: 1,
        isDone: false,
        dateKey: '',
        order: 0,
        notesDeltaJson: doc.encode(),
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      doc: doc,
      stats: doc.computeStats(),
      categoryName: categoryName,
      categoryColor: categoryColor,
      categoryIconCodePoint: icon.codePoint,
      pinned: pinned,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final brokenLinks = cardFor(
      title: 'Broken links on the website',
      categoryName: 'Website',
      categoryColor: const Color(0xFF6366F1),
      icon: Icons.language,
      doc: NoteDocument(
        blocks: [
          NoteBlock(
            id: 'p1',
            type: NoteBlockType.paragraph,
            text: 'Audit footer links and fix 404s on the marketing site.',
          ),
          NoteBlock(
            id: 'c1',
            type: NoteBlockType.checklist,
            text: 'Homepage CTA',
            checked: true,
          ),
          NoteBlock(
            id: 'c2',
            type: NoteBlockType.checklist,
            text: 'Pricing page',
            checked: false,
          ),
        ],
      ),
    );
    final weekly = cardFor(
      title: NotesGlmParityFixture.task.title,
      categoryName: 'Personal',
      categoryColor: const Color(0xFF22C55E),
      icon: Icons.person_outline,
      doc: NoteDocument.tryParse(
        notesDeltaJson: NotesGlmParityFixture.task.notesDeltaJson,
      ),
      pinned: true,
    );
    final q3 = cardFor(
      title: 'Q3 planning notes',
      categoryName: 'Work',
      categoryColor: const Color(0xFF3B82F6),
      icon: Icons.work_outline,
      doc: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'p1',
            type: NoteBlockType.paragraph,
            text: 'Align roadmap with capacity. Ship notes library refresh first.',
          ),
        ],
      ),
    );

    return RepaintBoundary(
      key: kNotesProductionLibraryCaptureKey,
      child: SizedBox(
        width: kNotesGlmParityViewport.width,
        height: kNotesGlmParityViewport.height,
        child: Material(
          child: NotesLibraryProductionShell(
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t(loc, 'notes_v3_subtitle'),
                  style: const TextStyle(fontSize: 14, color: kGlmMetaColor),
                ),
                Text(
                  t(loc, 'notes_v3_title'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: false,
                  decoration: notesGlmSearchDecoration(
                    hintText: t(loc, 'notes_v3_search_hint'),
                  ),
                ),
              ],
            ),
            categoryBar: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _pill('All', const Color(0xFF6366F1), selected: true),
                  _pill('Personal', const Color(0xFF22C55E)),
                  _pill('Work', const Color(0xFF3B82F6)),
                  _pill('Website', const Color(0xFF8B5CF6)),
                ],
              ),
            ),
            content: GridView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.22,
              ),
              children: [
                NoteCard(
                  data: brokenLinks,
                  view: NotesLibraryView.grid,
                  checkboxesOn: false,
                  onOpen: () {},
                  onTogglePin: () {},
                  onToggleDone: () {},
                  onLongPress: () {},
                ),
                NoteCard(
                  data: weekly,
                  view: NotesLibraryView.grid,
                  checkboxesOn: false,
                  onOpen: () {},
                  onTogglePin: () {},
                  onToggleDone: () {},
                  onLongPress: () {},
                ),
                NoteCard(
                  data: q3,
                  view: NotesLibraryView.grid,
                  checkboxesOn: false,
                  onOpen: () {},
                  onTogglePin: () {},
                  onToggleDone: () {},
                  onLongPress: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.65)
                : color.withValues(alpha: 0.28),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? color : kGlmPillTextColor,
          ),
        ),
      ),
    );
  }
}
