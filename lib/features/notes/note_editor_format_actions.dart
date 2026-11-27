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

// Cached across a document revision. Lists of hundreds of numbered blocks
// must not trigger a backwards scan for every row on an IME-driven rebuild.
int _notesOrdinalFor(_NoteEditorPageState state, int index) {
  final document = state._editor.document;
  if (!identical(state._ordinalDocument, document)) {
    final blocks = state._editor.visibleBlocks;
    final ordinals = List<int>.filled(blocks.length, 1);
    var ordinal = 0;
    for (var i = 0; i < blocks.length; i++) {
      ordinal = blocks[i].type == NoteBlockType.numberedList
          ? ordinal + 1
          : 0;
      ordinals[i] = ordinal == 0 ? 1 : ordinal;
    }
    state._ordinalCache = ordinals;
    state._ordinalDocument = document;
  }
  return index >= 0 && index < state._ordinalCache.length
      ? state._ordinalCache[index]
      : 1;
}

/// Presentation-only formatting menu actions, sharing the existing editor state.
extension _NotesFormattingMenus on _NoteEditorPageState {
  NotesTextBlockStyle? _activeHeadingStyle() =>
      _notesHeadingStyleFor(this);
  Set<NotesInlineFormat> _selectionFormats() {
    final block = _editor.activeBlock;
    if (block == null ||
        !NotesEditorDocumentController.isEditableText(block.type)) {
      return const <NotesInlineFormat>{};
    }
    final selection = _textControllers[block.id]?.selection;
    if (selection == null) return const <NotesInlineFormat>{};
    return _editor.formatsForSelection(block.id, selection);
  }
  Future<void> _showHeadingMenu() {
    return showNotesHeadingStylesMenu(
      context: context,
      selected: _activeHeadingStyle(),
      onSelected: (style) {
        final conversion = switch (style) {
          NotesTextBlockStyle.body => NotesBlockConversion.body,
          NotesTextBlockStyle.h1 => NotesBlockConversion.h1,
          NotesTextBlockStyle.h2 => NotesBlockConversion.h2,
          NotesTextBlockStyle.h3 => NotesBlockConversion.h3,
        };
        _convertActive(conversion);
      },
    );
  }
  Future<void> _showFormattingMenu() {
    final block = _editor.activeBlock;
    if (block == null ||
        !NotesEditorDocumentController.isEditableText(block.type)) {
      return Future<void>.value();
    }
    final selection = _textControllerFor(block).selection;
    return showNotesTextFormattingMenu(
      context: context,
      selected: _editor.formatsForSelection(block.id, selection),
      onSelected: (format) {
        if (format == NotesInlineFormat.link) {
          _editLink(block.id, selection);
          return;
        }
        _applyInlineFormat(block.id, selection, format);
      },
    );
  }
}
