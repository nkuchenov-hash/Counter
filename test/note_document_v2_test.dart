import 'dart:convert';

import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteDocument v2', () {
    test('migrates v1 to v2 without losing text or whole-block marks', () {
      final v1 = jsonEncode({
        'format': 'lifeos_notes_blocks_v1',
        'version': 1,
        'meta': {'pinned': true},
        'blocks': [
          {
            'id': 'legacy-a',
            'type': 'paragraph',
            'text': 'Legacy formatted text',
            'bold': true,
            'italic': true,
            'color': '#EF4444',
          },
          {
            'id': 'legacy-b',
            'type': 'checklist',
            'text': 'Legacy task',
            'checked': true,
          },
        ],
      });

      final migrated = NoteDocument.tryParse(notesDeltaJson: v1);
      final reparsed = NoteDocument.tryParse(notesDeltaJson: migrated.encode());

      expect(migrated.format, kLifeOsNotesBlocksFormat);
      expect(migrated.version, kLifeOsNotesBlocksVersion);
      expect(reparsed.meta.pinned, isTrue);
      expect(reparsed.blocks.map((b) => b.id), ['legacy-a', 'legacy-b']);
      expect(reparsed.blocks.first.effectiveText, 'Legacy formatted text');
      expect(reparsed.blocks.first.effectiveRuns.single.marks.bold, isTrue);
      expect(reparsed.blocks.first.effectiveRuns.single.marks.italic, isTrue);
      expect(
        reparsed.blocks.first.effectiveRuns.single.marks.textColor,
        '#EF4444',
      );
      expect(reparsed.blocks.last.checked, isTrue);
      expect(reparsed.toPlainText(), contains('Legacy formatted text'));
    });

    test('round-trips inline marks and structural block conversion', () {
      final document = NoteDocument(
        blocks: [
          NoteBlock(
            id: 'rich-text',
            type: NoteBlockType.quote,
            text: 'Read the source',
            runs: const [
              NoteTextRun(text: 'Read ', marks: NoteInlineMarks(bold: true)),
              NoteTextRun(
                text: 'the source',
                marks: NoteInlineMarks(
                  underline: true,
                  link: 'https://example.com',
                  highlightColor: '#FFF2A8',
                ),
              ),
            ],
          ),
        ],
      );

      final parsed = NoteDocument.tryParse(notesDeltaJson: document.encode());
      final block = parsed.blocks.single;

      expect(block.type, NoteBlockType.quote);
      expect(block.effectiveText, 'Read the source');
      expect(block.runs.length, 2);
      expect(block.runs.first.marks.bold, isTrue);
      expect(block.runs.last.marks.underline, isTrue);
      expect(block.runs.last.marks.link, 'https://example.com');
      expect(block.runs.last.marks.highlightColor, '#FFF2A8');
    });

    test('persists table, callout, link, and Life OS references', () {
      final document = NoteDocument(
        blocks: [
          NoteBlock(
            id: 'callout',
            type: NoteBlockType.callout,
            text: 'Protect the morning',
            callout: const NoteCalloutData(
              type: NoteCalloutType.idea,
              icon: 'lightbulb',
            ),
          ),
          NoteBlock(
            id: 'table',
            type: NoteBlockType.table,
            table: const NoteTableData(
              hasHeader: true,
              cells: [
                ['Day', 'Focus'],
                ['Monday', 'Deep work'],
              ],
            ),
          ),
          NoteBlock(
            id: 'link',
            type: NoteBlockType.linkCard,
            linkData: const NoteLinkData(
              url: 'https://example.com/article',
              title: 'Useful article',
            ),
          ),
          NoteBlock(
            id: 'plan-ref',
            type: NoteBlockType.planReference,
            reference: const NoteReferenceData(
              targetId: 'pbplan123456789',
              label: 'Ship Notes v2',
            ),
          ),
        ],
      );

      final parsed = NoteDocument.tryParse(notesDeltaJson: document.encode());

      expect(parsed.blocks[0].callout?.type, NoteCalloutType.idea);
      expect(parsed.blocks[1].table?.cells[1][1], 'Deep work');
      expect(parsed.blocks[2].linkData?.title, 'Useful article');
      expect(parsed.blocks[3].reference?.targetId, 'pbplan123456789');
      expect(parsed.toPlainText(), contains('Protect the morning'));
      expect(parsed.toPlainText(), contains('Monday | Deep work'));
      expect(parsed.toPlainText(), contains('Useful article'));
      expect(parsed.toPlainText(), contains('Ship Notes v2'));
    });
  });
}
