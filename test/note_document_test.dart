import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteDocument', () {
    test('round-trip serialization', () {
      final doc = NoteDocument(
        meta: const NoteDocumentMeta(pinned: true),
        blocks: [
          NoteBlock(
            id: 'b1',
            type: NoteBlockType.paragraph,
            text: 'Hello',
            bold: true,
          ),
          NoteBlock(
            id: 'b2',
            type: NoteBlockType.checklist,
            text: 'Buy milk',
            checked: true,
          ),
          NoteBlock(
            id: 'b3',
            type: NoteBlockType.heading,
            text: 'Section',
            level: 2,
          ),
        ],
      );
      final parsed = NoteDocument.tryParse(notesDeltaJson: doc.encode());
      expect(parsed.meta.pinned, isTrue);
      expect(parsed.blocks.length, 3);
      expect(parsed.blocks[0].text, 'Hello');
      expect(parsed.blocks[0].bold, isTrue);
      expect(parsed.blocks[1].type, NoteBlockType.checklist);
      expect(parsed.blocks[1].checked, isTrue);
      expect(parsed.blocks[2].level, 2);
    });

    test('legacy notes_plain creates paragraph blocks', () {
      final doc = NoteDocument.tryParse(notesPlain: 'Line one\nLine two');
      expect(doc.blocks.length, 2);
      expect(doc.blocks[0].type, NoteBlockType.paragraph);
      expect(doc.blocks[0].text, 'Line one');
      expect(doc.blocks[1].text, 'Line two');
    });

    test('legacy checklist imported', () {
      final doc = NoteDocument.tryParse(
        checklist: [
          {'text': 'Task A', 'done': true},
          {'text': 'Task B', 'done': false},
        ],
      );
      expect(doc.blocks.length, 2);
      expect(doc.blocks[0].type, NoteBlockType.checklist);
      expect(doc.blocks[0].checked, isTrue);
      expect(doc.blocks[1].checked, isFalse);
    });

    test('legacy Quill delta converts paragraphs and lists', () {
      final delta = '''
[{"insert":"Bold line","attributes":{"bold":true}},{"insert":"\\n"},
{"insert":"Item","attributes":{"list":"bullet"}},{"insert":"\\n"}]
''';
      final doc = NoteDocument.tryParse(notesDeltaJson: delta);
      expect(doc.blocks.isNotEmpty, isTrue);
      expect(
        doc.blocks.any((b) => b.type == NoteBlockType.paragraph),
        isTrue,
      );
    });

    test('toPlainText projection', () {
      final doc = NoteDocument(
        blocks: [
          NoteBlock(
            id: 'a',
            type: NoteBlockType.paragraph,
            text: 'Body line',
          ),
          NoteBlock(
            id: 'b',
            type: NoteBlockType.checklist,
            text: 'Check item',
            checked: false,
          ),
        ],
      );
      final plain = doc.toPlainText(title: 'My Title');
      expect(plain, contains('My Title'));
      expect(plain, contains('Body line'));
      expect(plain, contains('Check item'));
    });

    test('checklist compatibility projection', () {
      final doc = NoteDocument(
        blocks: [
          NoteBlock(
            id: 'a',
            type: NoteBlockType.checklist,
            text: 'Done item',
            checked: true,
          ),
        ],
      );
      final proj = doc.toChecklistProjection();
      expect(proj.length, 1);
      expect(proj[0]['text'], 'Done item');
      expect(proj[0]['done'], isTrue);
    });

    test('malformed JSON falls back to empty document', () {
      final doc = NoteDocument.tryParse(notesDeltaJson: '{not valid json');
      expect(doc.blocks, isEmpty);
    });

    test('pinned metadata round-trip', () {
      final doc = NoteDocument(
        meta: const NoteDocumentMeta(pinned: true),
        blocks: [
          NoteBlock(
            id: 'x',
            type: NoteBlockType.paragraph,
            text: 'x',
          ),
        ],
      );
      final parsed = NoteDocument.tryParse(notesDeltaJson: doc.encode());
      expect(parsed.meta.pinned, isTrue);
    });
  });
}
