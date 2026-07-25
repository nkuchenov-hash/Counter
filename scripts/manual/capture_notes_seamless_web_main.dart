import 'package:counter/data/models.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:flutter/material.dart';

void main() {
  final task = PlanningTask(
    id: 0,
    planRowId: 'seamless-capture',
    title: 'Weekly intentions',
    categoryId: 1,
    isDone: false,
    dateKey: '',
    order: 0,
    tags: const <Tag>[
      Tag(tagId: 1, name: 'routine', color: '#6366F1'),
    ],
    notesDeltaJson: NoteDocument(
      blocks: <NoteBlock>[
        const NoteBlock(
          id: 'heading',
          type: NoteBlockType.heading,
          text: 'A single continuous note',
          level: 1,
        ),
        const NoteBlock(
          id: 'paragraph',
          type: NoteBlockType.paragraph,
          text:
              'Text, lists, drawings, tables and references belong to one document flow. They should not look like a pile of independent cards.',
        ),
        const NoteBlock(
          id: 'bullet-1',
          type: NoteBlockType.bulletedList,
          text: 'Protect mornings from meetings',
        ),
        const NoteBlock(
          id: 'bullet-2',
          type: NoteBlockType.bulletedList,
          text: 'Keep one source of truth',
        ),
        const NoteBlock(
          id: 'number-1',
          type: NoteBlockType.numberedList,
          text: 'Collect the material',
        ),
        const NoteBlock(
          id: 'number-2',
          type: NoteBlockType.numberedList,
          text: 'Edit the structure',
        ),
        const NoteBlock(
          id: 'check-1',
          type: NoteBlockType.checklist,
          text: 'Review the final note',
          checked: true,
        ),
        const NoteBlock(
          id: 'quote',
          type: NoteBlockType.quote,
          text: 'The document should read as one sheet, not as a dashboard.',
          italic: true,
        ),
        const NoteBlock(
          id: 'callout',
          type: NoteBlockType.callout,
          text: 'Callouts use a restrained accent line, not a separate card.',
          callout: NoteCalloutData(type: NoteCalloutType.idea),
        ),
        const NoteBlock(id: 'divider', type: NoteBlockType.divider),
        const NoteBlock(
          id: 'table',
          type: NoteBlockType.table,
          table: NoteTableData(
            hasHeader: true,
            cells: <List<String>>[
              <String>['Day', 'Focus', 'Status'],
              <String>['Monday', 'Deep work', 'Done'],
              <String>['Tuesday', 'Roadmap', 'Next'],
            ],
          ),
        ),
      ],
    ).encode(),
    updatedAt: DateTime(2026, 7, 25, 12),
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
      ),
      home: NoteEditorPage(task: task, parityPreview: true),
    ),
  );
}
