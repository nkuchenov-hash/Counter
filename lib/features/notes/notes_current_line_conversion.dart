part of 'notes_editor_document_controller.dart';

/// A single style change isolates only the caret line and retains previous
/// multiline Body content (and its EditableText identity).
NotesEditorMutation _convertNotesCurrentLine(
  NotesEditorDocumentController editor,
  String id,
  TextSelection selection,
  NotesBlockConversion conversion,
) {
    final block = editor.blockById(id);
    if (block == null || !NotesEditorDocumentController.isEditableText(block.type)) {
      return const NotesEditorMutation();
    }
    final text = block.effectiveText;
    if (block.type != NoteBlockType.paragraph || !text.contains('\n')) {
      return editor.convertBlock(id, conversion);
    }
    final caret = (selection.isValid ? selection.extentOffset : text.length)
        .clamp(0, text.length).toInt();
    final lineStart = (caret == 0 ? -1 : text.lastIndexOf('\n', caret - 1)) + 1;
    final breakAfter = text.indexOf('\n', caret);
    final lineEnd = breakAfter < 0 ? text.length : breakAfter;
    final lineText = text.substring(lineStart, lineEnd);
    final target = switch (conversion) {
      NotesBlockConversion.body => (NoteBlockType.paragraph, 2),
      NotesBlockConversion.h1 => (NoteBlockType.heading, 1),
      NotesBlockConversion.h2 => (NoteBlockType.heading, 2),
      NotesBlockConversion.h3 => (NoteBlockType.heading, 3),
      NotesBlockConversion.quote => (NoteBlockType.quote, 2),
      NotesBlockConversion.bulletedList => (NoteBlockType.bulletedList, 2),
      NotesBlockConversion.numberedList => (NoteBlockType.numberedList, 2),
      NotesBlockConversion.checklist => (NoteBlockType.checklist, 2),
    };
    if (target.$1 == NoteBlockType.paragraph) {
      return const NotesEditorMutation();
    }
    final styled = lineStart == 0
        ? block.copyWith(
            type: target.$1,
            level: target.$2,
            checked: false,
            text: lineText,
            runs: _sliceRuns(block.effectiveRuns, lineStart, lineEnd),
          )
        : NoteBlock(
            id: generateNoteBlockId(),
            type: target.$1,
            level: target.$2,
            text: lineText,
            runs: _sliceRuns(block.effectiveRuns, lineStart, lineEnd),
            indent: block.indent,
            alignment: block.alignment,
          );
    // Only one delimiter is consumed by the newly styled line. Previously
    // typed blank lines survive in the original TextField without creating
    // separately padded Flutter widgets or extra blank list items.
    final prefix = lineStart == 0 ? '' : text.substring(0, lineStart - 1);
    final replacement = <NoteBlock>[
      if (lineStart > 0)
        block.copyWith(
          text: prefix,
          runs: _sliceRuns(block.effectiveRuns, 0, lineStart - 1),
        ),
      styled,
      if (breakAfter >= 0)
        NoteBlock(
          id: generateNoteBlockId(),
          type: NoteBlockType.paragraph,
          text: text.substring(lineEnd + 1),
          runs: _sliceRuns(block.effectiveRuns, lineEnd + 1, text.length),
          indent: block.indent,
          alignment: block.alignment,
        ),
    ];
    final index = editor._indexOf(id);
    if (index < 0) return const NotesEditorMutation();
    final updated = List<NoteBlock>.from(editor.blocks)
      ..removeAt(index)
      ..insertAll(index, replacement);
    editor._commitDocument(editor._document.copyWith(blocks: updated));
    editor.activeBlockId = styled.id;
    editor.activeSelection = TextSelection.collapsed(
      offset: (caret - lineStart).clamp(0, lineText.length).toInt(),
    );
    return editor._focusMutation(styled.id, editor.activeSelection);
}

// Private cache operations live in this controller library, not the Brain.
// Keep the hot-path class small while preserving immutable document revisions.
void _commitNoteDocument(
  NotesEditorDocumentController editor,
  NoteDocument next, {
  bool preserveBlockIndices = false,
}) {
  editor._undoStack.add(editor._document);
  if (editor._undoStack.length > 100) editor._undoStack.removeAt(0);
  editor._document = next;
  editor._visibleBlocksCache = null;
  // Replacing text does not change block order or ids.
  if (!preserveBlockIndices) editor._blockIndices = null;
}

void _replaceNoteBlock(
  NotesEditorDocumentController editor,
  NoteBlock replacement,
) {
  final index = editor._indexOf(replacement.id);
  if (index < 0) return;
  final nextBlocks = List<NoteBlock>.from(editor.blocks)..[index] = replacement;
  editor._commitDocument(
    editor._document.copyWith(blocks: nextBlocks),
    preserveBlockIndices: true,
  );
}

int _indexOfNoteBlock(NotesEditorDocumentController editor, String id) {
  final indices = editor._blockIndices ??= <String, int>{
    for (var i = 0; i < editor.blocks.length; i++) editor.blocks[i].id: i,
  };
  return indices[id] ?? -1;
}
