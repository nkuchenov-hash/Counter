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

/// Resolve a plain SelectionArea selection without rebuilding every possible
/// contiguous document window. Keep shortest-window / earliest-match semantics.
List<NoteBlock> inferNotesClipboardSelection(
  List<NoteBlock> textBlocks,
  String plain,
  String Function(String) normalize,
) {
  if (plain.isEmpty || textBlocks.isEmpty) return const <NoteBlock>[];
  final normalizedSelection = normalize(plain);
  List<NoteBlock>? wholeBlockBest;
  for (var start = 0; start < textBlocks.length; start++) {
    final buffer = StringBuffer();
    for (var end = start; end < textBlocks.length; end++) {
      final count = end - start + 1;
      if (wholeBlockBest != null && count >= wholeBlockBest.length) break;
      if (end > start) buffer.write('\n');
      buffer.write(textBlocks[end].effectiveText);
      final candidate = normalize(buffer.toString());
      // Extending the raw window cannot remove any existing normalized
      // non-trailing text. A non-prefix can never become an exact match.
      if (!normalizedSelection.startsWith(candidate)) break;
      if (candidate != normalizedSelection) continue;
      if (count > 1 || textBlocks[start].type != NoteBlockType.paragraph) {
        wholeBlockBest = textBlocks.sublist(start, end + 1);
        break;
      }
    }
  }
  if (wholeBlockBest != null) return wholeBlockBest;

  final buffer = StringBuffer();
  final offsets = <int>[0];
  for (final block in textBlocks) {
    buffer.write(block.effectiveText);
    offsets.add(buffer.length);
  }
  final joined = buffer.toString();
  int blockAt(int offset) {
    var lo = 0;
    var hi = textBlocks.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (offsets[mid + 1] <= offset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  var bestStart = -1;
  var bestEnd = -1;
  var bestOffset = -1;
  var bestWindow = textBlocks.length + 1;
  var searchFrom = 0;
  while (searchFrom <= joined.length - plain.length) {
    final found = joined.indexOf(plain, searchFrom);
    if (found < 0) break;
    final start = blockAt(found);
    final end = blockAt(found + plain.length - 1);
    final count = end - start + 1;
    if (count >= 2 && count < bestWindow) {
      bestStart = start;
      bestEnd = end;
      bestOffset = found;
      bestWindow = count;
      if (count == 2) break;
    }
    searchFrom = found + 1;
  }
  if (bestStart < 0) return const <NoteBlock>[];
  final selectedEnd = bestOffset + plain.length;
  final slices = <NoteBlock>[];
  for (var i = bestStart; i <= bestEnd; i++) {
    final source = textBlocks[i];
    final localStart = bestOffset > offsets[i] ? bestOffset - offsets[i] : 0;
    final localEnd = selectedEnd < offsets[i + 1]
        ? selectedEnd - offsets[i]
        : source.effectiveText.length;
    if (localStart == 0 && localEnd == source.effectiveText.length) {
      slices.add(source);
    } else {
      slices.add(source.copyWith(
        text: source.effectiveText.substring(localStart, localEnd),
        runs: const <NoteTextRun>[],
      ));
    }
  }
  return slices;
}
