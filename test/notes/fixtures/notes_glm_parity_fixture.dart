// Deterministic GLM reference fixture for visual parity capture (test-only).
// Uses production editor presentation widgets; no PocketBase / Brain writes.

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:flutter/material.dart';

/// Reference viewport from the acceptance spec.
const Size kNotesGlmParityViewport = Size(1156, 821);

/// Key for screenshot capture in parity tests.
const Key kNotesGlmParityCaptureKey = Key('notes_glm_parity_capture');

/// Static [PlanningTask] + [NoteDocument] matching the supplied GLM screenshot.
class NotesGlmParityFixture extends StatelessWidget {
  const NotesGlmParityFixture({super.key});

  static PlanningTask get task => PlanningTask(
        id: 0,
        planRowId: 'parity-fixture',
        title: 'Weekly intentions',
        categoryId: 1,
        isDone: false,
        dateKey: '',
        order: 0,
        tags: const [
          Tag(tagId: 1, name: 'routine', color: '#6366F1'),
        ],
        notesDeltaJson: NoteDocument(
          blocks: [
            NoteBlock(
              id: 'h1',
              type: NoteBlockType.heading,
              text: 'This week',
              level: 1,
            ),
            NoteBlock(
              id: 'p1',
              type: NoteBlockType.paragraph,
              text:
                  'Three deep-work blocks before noon. Protect mornings from meetings. Keep the notes app as the single source of truth for stray thoughts.',
            ),
            NoteBlock(
              id: 'h2a',
              type: NoteBlockType.heading,
              text: 'Focus',
              level: 2,
            ),
            NoteBlock(
              id: 'c1',
              type: NoteBlockType.checklist,
              text: 'Ship the planner redesign',
              checked: true,
            ),
            NoteBlock(
              id: 'c2',
              type: NoteBlockType.checklist,
              text: 'Draft Q3 roadmap',
              checked: false,
            ),
            NoteBlock(
              id: 'c3',
              type: NoteBlockType.checklist,
              text: 'Review PR #482',
              checked: false,
            ),
            NoteBlock(
              id: 'h2b',
              type: NoteBlockType.heading,
              text: 'Wellbeing',
              level: 2,
            ),
            NoteBlock(
              id: 'c4',
              type: NoteBlockType.checklist,
              text: 'Run 3×',
              checked: false,
            ),
            NoteBlock(
              id: 'c5',
              type: NoteBlockType.checklist,
              text: 'Sleep before 11pm',
              checked: true,
            ),
            NoteBlock(
              id: 'q1',
              type: NoteBlockType.paragraph,
              text:
                  '“Condition depth like a muscle. Schedule it. Boredom is the training ground, not the enemy.”',
              italic: true,
              color: '#94A3B8',
            ),
          ],
        ).encode(),
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      );

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: kNotesGlmParityCaptureKey,
      child: SizedBox(
        width: kNotesGlmParityViewport.width,
        height: kNotesGlmParityViewport.height,
        child: Material(
          child: NoteEditorPage(
            task: task,
            parityPreview: true,
          ),
        ),
      ),
    );
  }
}
