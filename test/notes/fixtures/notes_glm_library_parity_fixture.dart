// Deterministic GLM library layout fixture for visual capture (test-only).

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/widgets/note_card.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

import 'notes_glm_parity_fixture.dart';

const Key kNotesGlmLibraryParityCaptureKey =
    Key('notes_glm_library_parity_capture');

/// Centered library workspace at the acceptance viewport width.
class NotesGlmLibraryParityFixture extends StatelessWidget {
  const NotesGlmLibraryParityFixture({super.key});

  static NoteCardData get sampleCard {
    final doc = NoteDocument(
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
    );
    return NoteCardData(
      task: PlanningTask(
        id: 0,
        planRowId: 'library-parity',
        title: 'Broken links on the website',
        categoryId: 1,
        isDone: false,
        dateKey: '',
        order: 0,
        notesDeltaJson: doc.encode(),
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      doc: doc,
      stats: doc.computeStats(),
      categoryName: 'Website',
      categoryColor: const Color(0xFF6366F1),
      categoryIconCodePoint: Icons.language.codePoint,
      pinned: false,
    );
  }

  static NoteCardData get weeklyCard {
    final task = NotesGlmParityFixture.task;
    final doc = NoteDocument.tryParse(notesDeltaJson: task.notesDeltaJson);
    return NoteCardData(
      task: task,
      doc: doc,
      stats: doc.computeStats(),
      categoryName: 'Personal',
      categoryColor: const Color(0xFF22C55E),
      categoryIconCodePoint: Icons.person_outline.codePoint,
      pinned: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      key: kNotesGlmLibraryParityCaptureKey,
      child: SizedBox(
        width: kNotesGlmParityViewport.width,
        height: kNotesGlmParityViewport.height,
        child: Material(
          child: NotesGlmLibraryFrame(
            child: Column(
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
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          size: 18, color: kGlmMetaColor),
                      const SizedBox(width: 8),
                      Text(
                        t(loc, 'notes_v3_search_hint'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: kGlmMetaColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('All', scheme.primary),
                      _chip('Personal', const Color(0xFF22C55E)),
                      _chip('Work', const Color(0xFF3B82F6)),
                      _chip('Website', const Color(0xFF6366F1)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      NoteCard(
                        data: sampleCard,
                        view: NotesLibraryView.list,
                        checkboxesOn: false,
                        onOpen: () {},
                        onTogglePin: () {},
                        onToggleDone: () {},
                        onLongPress: () {},
                        onOpenMenu: (_) {},
                      ),
                      const SizedBox(height: 8),
                      NoteCard(
                        data: weeklyCard,
                        view: NotesLibraryView.list,
                        checkboxesOn: false,
                        onOpen: () {},
                        onTogglePin: () {},
                        onToggleDone: () {},
                        onLongPress: () {},
                        onOpenMenu: (_) {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
