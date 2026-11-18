import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_editor_document_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Notes keeps one visible-block projection per document revision', () {
    final source = NoteDocument(
      blocks: List<NoteBlock>.generate(
        300,
        (i) => NoteBlock(
          id: 'block-$i',
          type: NoteBlockType.paragraph,
          text: 'Line $i',
        ),
      ),
    );
    final editor = NotesEditorDocumentController(source);
    final initial = editor.visibleBlocks;
    expect(initial, hasLength(300));
    expect(identical(initial, editor.visibleBlocks), isTrue);

    final change = editor.applyTextInput(
      'block-0',
      'Updated',
      const TextSelection.collapsed(offset: 7),
      preserveLineBreaks: true,
    );
    expect(change.changed, isTrue);
    final changed = editor.visibleBlocks;
    expect(identical(changed, initial), isFalse);
    expect(identical(changed, editor.visibleBlocks), isTrue);
    expect(changed.first.effectiveText, 'Updated');

    final undo = editor.undo();
    expect(undo.changed, isTrue);
    expect(editor.visibleBlocks.first.effectiveText, 'Line 0');
    expect(identical(changed, editor.visibleBlocks), isFalse);
    expect(identical(editor.visibleBlocks, editor.visibleBlocks), isTrue);
  });

  test('Large Notes plain-text projection preserves title and all lines', () {
    final lines = List<String>.generate(400, (i) => 'Line $i');
    final document = NoteDocument(
      blocks: <NoteBlock>[
        for (var i = 0; i < lines.length; i++)
          NoteBlock(
            id: 'line-$i',
            type: NoteBlockType.paragraph,
            text: lines[i],
          ),
      ],
    );

    expect(document.toPlainText(title: 'Capture'),
        'Capture\n${lines.join('\n')}');
    expect(document.toPlainText(), lines.join('\n'));
  });
}
