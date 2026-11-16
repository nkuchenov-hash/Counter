part of 'note_editor_page.dart';

/// Formatting actions stay in one stable editor host. The live caret remains
/// valid through a toolbar tap; the document changes once after the IME frame.
void _convertNotesBlockSelection(
  _NoteEditorPageState state,
  NotesBlockConversion conversion,
) {
  if (state._selectedBlockIds.isNotEmpty) {
    state._applyMutation(
      state._editor.convertBlocks(state._selectedBlockIds, conversion),
    );
    return;
  }
  final id = state._editor.activeBlockId;
  if (id == null) return;
  final live = state._textControllers[id]?.selection;
  final remembered = state._lastSelections[id];
  final selection = live != null && live.isValid
      ? live
      : remembered != null && remembered.isValid
          ? remembered
          : state._editor.activeSelection ??
              TextSelection.collapsed(
                offset: state._editor.blockById(id)?.effectiveText.length ?? 0,
              );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted || state._editor.blockById(id) == null) return;
    state._applyMutation(
      state._editor.convertCurrentLine(id, selection, conversion),
    );
  });
}

NotesTextBlockStyle? _notesHeadingStyleFor(_NoteEditorPageState state) {
  final block = state._editor.activeBlock;
  if (block?.type == NoteBlockType.paragraph) {
    return NotesTextBlockStyle.body;
  }
  if (block?.type != NoteBlockType.heading) return null;
  if (block!.level == 1) return NotesTextBlockStyle.h1;
  if (block.level == 3) return NotesTextBlockStyle.h3;
  return NotesTextBlockStyle.h2;
}
