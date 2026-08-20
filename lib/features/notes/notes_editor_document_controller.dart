import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:flutter/material.dart';

enum NotesBlockConversion {
  body,
  h1,
  h2,
  h3,
  quote,
  bulletedList,
  numberedList,
  checklist,
}

class NotesEditorMutation {
  const NotesEditorMutation({
    this.changed = false,
    this.requiresRebuild = false,
    this.focusBlockId,
    this.selection,
  });

  final bool changed;
  final bool requiresRebuild;
  final String? focusBlockId;
  final TextSelection? selection;
}

class NotesEditorDocumentController {
  NotesEditorDocumentController(NoteDocument source) : _document = source {
    final visible = source.blocks.where(
      (block) => isSupportedProductionBlock(block.type),
    );
    if (visible.isEmpty) {
      final first = NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.heading,
        level: 1,
      );
      _document = source.copyWith(blocks: [first, ...source.blocks]);
      activeBlockId = first.id;
    } else {
      activeBlockId = visible.first.id;
    }
  }

  NoteDocument _document;
  final List<NoteDocument> _undoStack = <NoteDocument>[];
  String? activeBlockId;
  TextSelection? activeSelection;

  NoteDocument get document => _document;
  List<NoteBlock> get blocks => _document.blocks;
  List<NoteBlock> get visibleBlocks => blocks
      .where((block) => isSupportedProductionBlock(block.type))
      .toList(growable: false);
  NoteBlock? get activeBlock => blockById(activeBlockId);

  NoteBlock? blockById(String? id) {
    if (id == null) return null;
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  bool selectBlock(String id, TextSelection? selection) {
    final changed = activeBlockId != id;
    activeBlockId = id;
    activeSelection = selection;
    return changed;
  }

  void updateSelection(String id, TextSelection selection) {
    if (activeBlockId != id) return;
    activeSelection = selection;
  }

  NotesEditorMutation applyTextInput(
    String id,
    String newText,
    TextSelection selection,
  ) {
    final block = blockById(id);
    if (block == null || !isEditableText(block.type)) {
      return const NotesEditorMutation();
    }
    activeBlockId = id;
    activeSelection = selection;
    if (newText.contains('\n')) {
      return _replaceWithSplitLines(block, newText, selection);
    }
    if (newText == block.effectiveText) {
      return const NotesEditorMutation();
    }
    _replaceBlock(
      block.copyWith(
        text: newText,
        runs: applyNoteTextEditToRuns(
          oldText: block.effectiveText,
          oldRuns: block.effectiveRuns,
          newText: newText,
        ),
      ),
    );
    return const NotesEditorMutation(changed: true);
  }

  NotesEditorMutation handleEnter(String id, TextSelection selection) {
    final block = blockById(id);
    if (block == null || !isEditableText(block.type) || !selection.isValid) {
      return const NotesEditorMutation();
    }
    final start = selection.start.clamp(0, block.effectiveText.length).toInt();
    final end = selection.end.clamp(0, block.effectiveText.length).toInt();
    return _replaceWithSplitLines(
      block,
      block.effectiveText.replaceRange(start, end, '\n'),
      TextSelection.collapsed(offset: start + 1),
    );
  }

  NoteBlock? structuralSliceForSelection(
  String id,
  TextSelection selection,
) {
  final block = blockById(id);
  if (block == null || !isEditableText(block.type) ||
      !selection.isValid || selection.isCollapsed) {
    return null;
  }
  final start = selection.start.clamp(0, block.effectiveText.length).toInt();
  final end = selection.end.clamp(0, block.effectiveText.length).toInt();
  if (start >= end) return null;
  return block.copyWith(
    text: block.effectiveText.substring(start, end),
    runs: _sliceRuns(block.effectiveRuns, start, end),
  );
}

/// Paste a system clipboard string. Normal text keeps the existing editor
  /// semantics; recognizable Markdown/native checkbox lines become real Notes
  /// blocks instead of being flattened into one paragraph.
  NotesEditorMutation pastePlainText(
    String id,
    TextSelection selection,
    String plainText,
  ) {
    final block = blockById(id);
    if (block == null || !isEditableText(block.type)) {
      return const NotesEditorMutation();
    }
    final normalized = plainText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (normalized.isEmpty) return const NotesEditorMutation();

    final structured = _parseStructuredClipboardText(normalized);
    if (structured != null && structured.isNotEmpty) {
      return pasteBlocks(id, selection, structured);
    }

    final safe = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: block.effectiveText.length);
    final start = safe.start.clamp(0, block.effectiveText.length).toInt();
    final end = safe.end.clamp(0, block.effectiveText.length).toInt();
    final nextText = block.effectiveText.replaceRange(start, end, normalized);
    return applyTextInput(
      id,
      nextText,
      TextSelection.collapsed(offset: start + normalized.length),
    );
  }

  /// Inserts structured text blocks at the current caret/selection. Block type,
  /// checklist state, heading level and inline runs are preserved for internal
  /// Notes clipboard payloads. New ids are always generated for pasted blocks.
  NotesEditorMutation pasteBlocks(
    String id,
    TextSelection selection,
    List<NoteBlock> sourceBlocks,
  ) {
    final target = blockById(id);
    if (target == null || !isEditableText(target.type)) {
      return const NotesEditorMutation();
    }
    final insertable = <NoteBlock>[
      for (final source in sourceBlocks)
        if (isEditableText(source.type)) source,
    ];
    if (insertable.isEmpty) return const NotesEditorMutation();

    final safe = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: target.effectiveText.length);
    final start = safe.start.clamp(0, target.effectiveText.length).toInt();
    final end = safe.end.clamp(0, target.effectiveText.length).toInt();
    final prefixText = target.effectiveText.substring(0, start);
    final suffixText = target.effectiveText.substring(end);
    final prefixRuns = _sliceRuns(target.effectiveRuns, 0, start);
    final suffixRuns = _sliceRuns(
      target.effectiveRuns,
      end,
      target.effectiveText.length,
    );

    final replacement = <NoteBlock>[];
    if (prefixText.isNotEmpty) {
      replacement.add(target.copyWith(text: prefixText, runs: prefixRuns));
    }

    final pasted = <NoteBlock>[
      for (final source in insertable) _cloneNoteBlockWithNewId(source),
    ];
    replacement.addAll(pasted);

    NoteBlock? suffixBlock;
    if (suffixText.isNotEmpty) {
      final slicedTarget = target.copyWith(text: suffixText, runs: suffixRuns);
      suffixBlock = prefixText.isEmpty
          ? slicedTarget
          : _cloneNoteBlockWithNewId(slicedTarget);
      replacement.add(suffixBlock);
    }

    final index = _indexOf(target.id);
    if (index < 0) return const NotesEditorMutation();
    final nextBlocks = List<NoteBlock>.from(blocks)
      ..removeAt(index)
      ..insertAll(index, replacement);
    _commitDocument(_document.copyWith(blocks: nextBlocks));

    if (suffixBlock != null) {
      activeBlockId = suffixBlock.id;
      activeSelection = const TextSelection.collapsed(offset: 0);
    } else {
      final focus = pasted.lastWhere(
        (candidate) => isEditableText(candidate.type),
        orElse: () => pasted.last,
      );
      activeBlockId = focus.id;
      activeSelection = TextSelection.collapsed(
        offset: focus.effectiveText.length,
      );
    }
    return _focusMutation(activeBlockId!, activeSelection);
  }

  NotesEditorMutation _replaceWithSplitLines(
    NoteBlock block,
    String newText,
    TextSelection selection,
  ) {
    final oldText = block.effectiveText;
    if (_isListLike(block.type) && oldText.isEmpty && newText == '\n') {
      final converted = block.copyWith(
        type: NoteBlockType.paragraph,
        text: '',
        runs: const <NoteTextRun>[],
        checked: false,
      );
      _replaceBlock(converted);
      activeBlockId = converted.id;
      activeSelection = const TextSelection.collapsed(offset: 0);
      return _focusMutation(converted.id, activeSelection!);
    }

    final updatedRuns = applyNoteTextEditToRuns(
      oldText: oldText,
      oldRuns: block.effectiveRuns,
      newText: newText,
    );
    final parts = newText.split('\n');
    final replacement = <NoteBlock>[];
    var offset = 0;
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      final runs = _sliceRuns(updatedRuns, offset, offset + part.length);
      if (index == 0) {
        replacement.add(block.copyWith(text: part, runs: runs));
      } else {
        final type = _typeAfterEnter(block.type);
        replacement.add(
          NoteBlock(
            id: generateNoteBlockId(),
            type: type,
            text: part,
            runs: runs,
            indent: block.indent,
            alignment: block.alignment,
          ),
        );
      }
      offset += part.length + 1;
    }

    final index = _indexOf(block.id);
    final nextBlocks = List<NoteBlock>.from(blocks)
      ..removeAt(index)
      ..insertAll(index, replacement);
    _commitDocument(_document.copyWith(blocks: nextBlocks));

    final focus = _focusForSplit(parts, selection.extentOffset);
    final focusBlock = replacement[focus.$1];
    activeBlockId = focusBlock.id;
    activeSelection = TextSelection.collapsed(offset: focus.$2);
    return _focusMutation(focusBlock.id, activeSelection!);
  }

  NotesEditorMutation handleBackspaceAtStart(String id) {
    final index = _indexOf(id);
    if (index < 0) return const NotesEditorMutation();
    final block = blocks[index];
    if (!isEditableText(block.type)) return const NotesEditorMutation();

    if (block.type != NoteBlockType.paragraph) {
      final converted = block.copyWith(
        type: NoteBlockType.paragraph,
        checked: false,
        level: 2,
      );
      _replaceBlock(converted);
      activeBlockId = converted.id;
      activeSelection = const TextSelection.collapsed(offset: 0);
      return _focusMutation(converted.id, activeSelection!);
    }

    var previousIndex = index - 1;
    while (previousIndex >= 0 && !isEditableText(blocks[previousIndex].type)) {
      previousIndex--;
    }
    if (previousIndex < 0) return const NotesEditorMutation();

    final previous = blocks[previousIndex];
    final previousLength = previous.effectiveText.length;
    final nextBlocks = List<NoteBlock>.from(blocks)
      ..[previousIndex] = previous.copyWith(
        text: '${previous.effectiveText}${block.effectiveText}',
        runs: _mergeRuns([...previous.effectiveRuns, ...block.effectiveRuns]),
      )
      ..removeAt(index);
    _commitDocument(_document.copyWith(blocks: nextBlocks));
    activeBlockId = previous.id;
    activeSelection = TextSelection.collapsed(offset: previousLength);
    return _focusMutation(previous.id, activeSelection!);
  }

  NotesEditorMutation convertBlock(String id, NotesBlockConversion conversion) {
    final block = blockById(id);
    if (block == null || !isEditableText(block.type)) {
      return const NotesEditorMutation();
    }
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
    final type = target.$1;
    final level = target.$2;
    if (block.type == type &&
        (type != NoteBlockType.heading || block.level == level)) {
      return const NotesEditorMutation();
    }
    _replaceBlock(
      block.copyWith(
        type: type,
        level: level,
        checked: type == NoteBlockType.checklist ? block.checked : false,
      ),
    );
    activeBlockId = id;
    return _focusMutation(id, activeSelection);
  }

  NotesEditorMutation insertAfter(
    String? anchorId,
    NoteBlockType type, {
    int level = 2,
    NoteTableData? table,
    String? imageData,
    String? drawingData,
    NoteAudioData? audio,
    String? caption,
  }) {
    final anchorIndex = anchorId == null ? -1 : _indexOf(anchorId);
    final block = NoteBlock(
      id: generateNoteBlockId(),
      type: type,
      level: level,
      table: type == NoteBlockType.table
          ? table ?? NoteTableData.empty()
          : null,
      imageData: type == NoteBlockType.image ? imageData : null,
      drawingData: type == NoteBlockType.drawing ? drawingData : null,
      audio: type == NoteBlockType.audio ? audio : null,
      caption: caption,
    );
    final insertAt = anchorIndex >= 0
        ? anchorIndex + 1
        : _indexAfterLastVisibleBlock();
    final nextBlocks = List<NoteBlock>.from(blocks)..insert(insertAt, block);
    _commitDocument(_document.copyWith(blocks: nextBlocks));
    activeBlockId = block.id;
    activeSelection = isEditableText(type)
        ? const TextSelection.collapsed(offset: 0)
        : null;
    return NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
      focusBlockId: isEditableText(type) ? block.id : null,
      selection: activeSelection,
    );
  }

  NotesEditorMutation updateMedia(
    String id, {
    String? imageData,
    String? drawingData,
  }) {
    final block = blockById(id);
    if (block == null ||
        (block.type != NoteBlockType.image &&
            block.type != NoteBlockType.drawing)) {
      return const NotesEditorMutation();
    }
    final replacement = block.type == NoteBlockType.image
        ? block.copyWith(imageData: imageData)
        : block.copyWith(drawingData: drawingData);
    _replaceBlock(replacement);
    activeBlockId = id;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  NotesEditorMutation updateAudio(String id, NoteAudioData audio) {
    final block = blockById(id);
    if (block == null || block.type != NoteBlockType.audio) {
      return const NotesEditorMutation();
    }
    _replaceBlock(block.copyWith(audio: audio));
    activeBlockId = id;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  NotesEditorMutation deleteBlock(String id) {
    final index = _indexOf(id);
    if (index < 0 || !isSupportedProductionBlock(blocks[index].type)) {
      return const NotesEditorMutation();
    }
    final nextBlocks = List<NoteBlock>.from(blocks)..removeAt(index);
    var visible = nextBlocks
        .where((block) => isSupportedProductionBlock(block.type))
        .toList(growable: false);
    String? focusId;
    TextSelection? selection;
    if (visible.isEmpty) {
      final replacement = NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.paragraph,
      );
      nextBlocks.insert(index.clamp(0, nextBlocks.length).toInt(), replacement);
      visible = [replacement];
      focusId = replacement.id;
      selection = const TextSelection.collapsed(offset: 0);
    } else {
      final candidate = visible[index.clamp(0, visible.length - 1).toInt()];
      focusId = isEditableText(candidate.type) ? candidate.id : null;
      selection = focusId == null
          ? null
          : TextSelection.collapsed(offset: candidate.effectiveText.length);
    }
    _commitDocument(_document.copyWith(blocks: nextBlocks));
    activeBlockId = focusId ?? visible.first.id;
    activeSelection = selection;
    return NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
      focusBlockId: focusId,
      selection: selection,
    );
  }

  NotesEditorMutation toggleChecklist(String id, bool checked) {
    final block = blockById(id);
    if (block == null || block.type != NoteBlockType.checklist) {
      return const NotesEditorMutation();
    }
    if (block.checked == checked) return const NotesEditorMutation();
    _replaceBlock(block.copyWith(checked: checked));
    activeBlockId = id;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  NotesEditorMutation updateTable(String id, NoteTableData table) {
    final block = blockById(id);
    if (block == null || block.type != NoteBlockType.table) {
      return const NotesEditorMutation();
    }
    _replaceBlock(block.copyWith(table: table));
    activeBlockId = id;
    return const NotesEditorMutation(changed: true);
  }

  NotesEditorMutation editTable(
    String id,
    NotesTableEditCommand command, {
    required int row,
    required int column,
  }) {
    final block = blockById(id);
    if (block == null || block.type != NoteBlockType.table) {
      return const NotesEditorMutation();
    }
    final data = block.table ?? NoteTableData.empty();
    final cells = _normalizedTableCells(data);
    var changed = false;
    final safeRow = row.clamp(0, cells.length - 1).toInt();
    final safeColumn = column.clamp(0, cells.first.length - 1).toInt();
    switch (command) {
      case NotesTableEditCommand.addRowAbove:
        if (cells.length < 20) {
          cells.insert(safeRow, List<String>.filled(cells.first.length, ''));
          changed = true;
        }
        break;
      case NotesTableEditCommand.addRowBelow:
        if (cells.length < 20) {
          cells.insert(
            safeRow + 1,
            List<String>.filled(cells.first.length, ''),
          );
          changed = true;
        }
        break;
      case NotesTableEditCommand.addColumnLeft:
        if (cells.first.length < 6) {
          for (final sourceRow in cells) {
            sourceRow.insert(safeColumn, '');
          }
          changed = true;
        }
        break;
      case NotesTableEditCommand.addColumnRight:
        if (cells.first.length < 6) {
          for (final sourceRow in cells) {
            sourceRow.insert(safeColumn + 1, '');
          }
          changed = true;
        }
        break;
      case NotesTableEditCommand.deleteRow:
        if (cells.length > 1) {
          cells.removeAt(safeRow);
          changed = true;
        }
        break;
      case NotesTableEditCommand.deleteColumn:
        if (cells.first.length > 1) {
          for (final sourceRow in cells) {
            sourceRow.removeAt(safeColumn);
          }
          changed = true;
        }
        break;
    }
    if (!changed) return const NotesEditorMutation();
    _replaceBlock(block.copyWith(table: data.copyWith(cells: cells)));
    activeBlockId = id;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  NotesEditorMutation updateCaption(String id, String caption) {
    final block = blockById(id);
    if (block == null ||
        (block.type != NoteBlockType.image &&
            block.type != NoteBlockType.drawing)) {
      return const NotesEditorMutation();
    }
    if ((block.caption ?? '') == caption) {
      return const NotesEditorMutation();
    }
    _replaceBlock(
      block.copyWith(caption: caption.trim().isEmpty ? null : caption),
    );
    activeBlockId = id;
    return const NotesEditorMutation(changed: true);
  }

  NotesEditorMutation convertBlocks(
    Set<String> ids,
    NotesBlockConversion conversion,
  ) {
    if (ids.isEmpty) return const NotesEditorMutation();
    var changed = false;
    String? firstChangedId;
    for (final block in List<NoteBlock>.from(visibleBlocks)) {
      if (!ids.contains(block.id) || !isEditableText(block.type)) continue;
      final mutation = convertBlock(block.id, conversion);
      if (!mutation.changed) continue;
      changed = true;
      firstChangedId ??= block.id;
    }
    if (!changed) return const NotesEditorMutation();
    activeBlockId = firstChangedId ?? activeBlockId;
    activeSelection = null;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  NotesEditorMutation reorderVisibleGroup(
    Set<String> ids,
    int oldIndex,
    int newIndex,
  ) {
    final visible = List<NoteBlock>.from(visibleBlocks);
    if (oldIndex < 0 || oldIndex >= visible.length) {
      return const NotesEditorMutation();
    }
    if (!ids.contains(visible[oldIndex].id)) {
      return reorderVisible(oldIndex, newIndex);
    }
    final moving = <NoteBlock>[
      for (final block in visible)
        if (ids.contains(block.id)) block,
    ];
    if (moving.isEmpty) return const NotesEditorMutation();
    final remaining = <NoteBlock>[
      for (final block in visible)
        if (!ids.contains(block.id)) block,
    ];
    final boundedTarget = newIndex.clamp(0, visible.length).toInt();
    var insertAt = 0;
    for (var index = 0; index < boundedTarget; index++) {
      if (!ids.contains(visible[index].id)) insertAt++;
    }
    insertAt = insertAt.clamp(0, remaining.length).toInt();
    remaining.insertAll(insertAt, moving);

    var cursor = 0;
    final nextBlocks = <NoteBlock>[];
    for (final block in blocks) {
      if (isSupportedProductionBlock(block.type)) {
        nextBlocks.add(remaining[cursor++]);
      } else {
        nextBlocks.add(block);
      }
    }
    _commitDocument(_document.copyWith(blocks: nextBlocks));
    activeBlockId = moving.first.id;
    activeSelection = null;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  NotesEditorMutation reorderVisible(int oldIndex, int newIndex) {
    final visible = List<NoteBlock>.from(visibleBlocks);
    if (oldIndex < 0 || oldIndex >= visible.length) {
      return const NotesEditorMutation();
    }
    var target = newIndex;
    if (oldIndex < target) target--;
    target = target.clamp(0, visible.length - 1).toInt();
    if (oldIndex == target) return const NotesEditorMutation();
    final moving = visible.removeAt(oldIndex);
    visible.insert(target, moving);
    var cursor = 0;
    final nextBlocks = <NoteBlock>[];
    for (final block in blocks) {
      if (isSupportedProductionBlock(block.type)) {
        nextBlocks.add(visible[cursor++]);
      } else {
        nextBlocks.add(block);
      }
    }
    _commitDocument(_document.copyWith(blocks: nextBlocks));
    activeBlockId = moving.id;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  Set<NotesInlineFormat> formatsForSelection(
    String id,
    TextSelection selection,
  ) {
    final block = blockById(id);
    if (block == null || !isEditableText(block.type)) {
      return const <NotesInlineFormat>{};
    }
    final marks = _marksForSelection(block, selection);
    if (marks.isEmpty) return const <NotesInlineFormat>{};
    final selected = <NotesInlineFormat>{};
    if (marks.every((item) => item.bold)) selected.add(NotesInlineFormat.bold);
    if (marks.every((item) => item.italic)) {
      selected.add(NotesInlineFormat.italic);
    }
    if (marks.every((item) => item.underline)) {
      selected.add(NotesInlineFormat.underline);
    }
    if (marks.every((item) => item.strike)) {
      selected.add(NotesInlineFormat.strike);
    }
    if (marks.every((item) => item.highlightColor != null)) {
      selected.add(NotesInlineFormat.highlight);
    }
    if (marks.every((item) => item.link != null)) {
      selected.add(NotesInlineFormat.link);
    }
    return selected;
  }

  String? linkForSelection(String id, TextSelection selection) {
    final block = blockById(id);
    if (block == null || !isEditableText(block.type)) return null;
    final marks = _marksForSelection(block, selection);
    if (marks.isEmpty) return null;
    final first = marks.first.link;
    if (first == null) return null;
    return marks.every((item) => item.link == first) ? first : null;
  }

  NotesEditorMutation applyInlineFormat(
    String id,
    TextSelection selection,
    NotesInlineFormat format, {
    String? link,
  }) {
    final block = blockById(id);
    if (block == null || !isEditableText(block.type) || !selection.isValid) {
      return const NotesEditorMutation();
    }
    final start = selection.start.clamp(0, block.effectiveText.length).toInt();
    final end = selection.end.clamp(0, block.effectiveText.length).toInt();
    if (start == end) return const NotesEditorMutation();
    final selectedFormats = formatsForSelection(id, selection);
    final remove = selectedFormats.contains(format);
    final runs = _transformRuns(
      block.effectiveRuns,
      start,
      end,
      (marks) => switch (format) {
        NotesInlineFormat.bold => marks.copyWith(bold: !remove),
        NotesInlineFormat.italic => marks.copyWith(italic: !remove),
        NotesInlineFormat.underline => marks.copyWith(underline: !remove),
        NotesInlineFormat.strike => marks.copyWith(strike: !remove),
        NotesInlineFormat.highlight => marks.copyWith(
          highlightColor: remove ? null : '#FFF59D',
        ),
        NotesInlineFormat.link => marks.copyWith(link: link),
      },
    );
    _replaceBlock(block.copyWith(text: block.effectiveText, runs: runs));
    activeBlockId = id;
    activeSelection = selection;
    return const NotesEditorMutation(changed: true);
  }

  NotesEditorMutation _focusMutation(String blockId, TextSelection? selection) {
    return NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
      focusBlockId: blockId,
      selection: selection,
    );
  }

  bool get canUndo => _undoStack.isNotEmpty;

  NotesEditorMutation undo() {
    if (_undoStack.isEmpty) return const NotesEditorMutation();
    _document = _undoStack.removeLast();
    final visible = visibleBlocks;
    if (visible.isEmpty) {
      activeBlockId = null;
      activeSelection = null;
      return const NotesEditorMutation(changed: true, requiresRebuild: true);
    }
    final previousActiveId = activeBlockId;
    final restoredId = previousActiveId != null && blockById(previousActiveId) != null
        ? previousActiveId
        : visible.last.id;
    activeBlockId = restoredId;
    final restored = blockById(restoredId);
    if (restored != null && isEditableText(restored.type)) {
      final offset = (activeSelection?.extentOffset ?? restored.effectiveText.length)
.clamp(0, restored.effectiveText.length)
.toInt();
      activeSelection = TextSelection.collapsed(offset: offset);
      return NotesEditorMutation(
        changed: true,
        requiresRebuild: true,
        focusBlockId: restoredId,
        selection: activeSelection,
      );
    }
    activeSelection = null;
    return const NotesEditorMutation(changed: true, requiresRebuild: true);
  }

  void _commitDocument(NoteDocument next) {
    _undoStack.add(_document);
    if (_undoStack.length > 100) _undoStack.removeAt(0);
    _document = next;
  }

  void _replaceBlock(NoteBlock replacement) {
    final index = _indexOf(replacement.id);
    if (index < 0) return;
    final nextBlocks = List<NoteBlock>.from(blocks)..[index] = replacement;
    _commitDocument(_document.copyWith(blocks: nextBlocks));
  }

  int _indexOf(String id) => blocks.indexWhere((block) => block.id == id);

  int _indexAfterLastVisibleBlock() {
    for (var index = blocks.length - 1; index >= 0; index--) {
      if (isSupportedProductionBlock(blocks[index].type)) return index + 1;
    }
    return 0;
  }

  static bool isSupportedProductionBlock(NoteBlockType type) {
    return isEditableText(type) ||
        type == NoteBlockType.divider ||
        type == NoteBlockType.table ||
        type == NoteBlockType.image ||
        type == NoteBlockType.drawing ||
        type == NoteBlockType.audio;
  }

  static bool isEditableText(NoteBlockType type) {
    return type == NoteBlockType.paragraph ||
        type == NoteBlockType.heading ||
        type == NoteBlockType.bulletedList ||
        type == NoteBlockType.numberedList ||
        type == NoteBlockType.checklist ||
        type == NoteBlockType.quote;
  }

  static bool _isListLike(NoteBlockType type) {
    return type == NoteBlockType.bulletedList ||
        type == NoteBlockType.numberedList ||
        type == NoteBlockType.checklist;
  }

  static NoteBlockType _typeAfterEnter(NoteBlockType type) {
    if (type == NoteBlockType.heading || type == NoteBlockType.quote) {
      return NoteBlockType.paragraph;
    }
    return type;
  }
}

(int, int) _focusForSplit(List<String> parts, int rawOffset) {
  final fullLength = parts.fold<int>(
    parts.isEmpty ? 0 : parts.length - 1,
    (sum, part) => sum + part.length,
  );
  final offset = rawOffset.clamp(0, fullLength).toInt();
  var cursor = 0;
  for (var index = 0; index < parts.length; index++) {
    final end = cursor + parts[index].length;
    if (offset <= end) return (index, offset - cursor);
    cursor = end + 1;
  }
  return (parts.length - 1, parts.last.length);
}

List<NoteTextRun> _sliceRuns(List<NoteTextRun> runs, int start, int end) {
  if (start >= end) return const <NoteTextRun>[];
  final result = <NoteTextRun>[];
  var offset = 0;
  for (final run in runs) {
    final runStart = offset;
    final runEnd = offset + run.text.length;
    final sliceStart = start.clamp(runStart, runEnd).toInt();
    final sliceEnd = end.clamp(runStart, runEnd).toInt();
    if (sliceStart < sliceEnd) {
      result.add(
        NoteTextRun(
          text: run.text.substring(sliceStart - runStart, sliceEnd - runStart),
          marks: run.marks,
        ),
      );
    }
    offset = runEnd;
  }
  return _mergeRuns(result);
}

List<NoteTextRun> _transformRuns(
  List<NoteTextRun> source,
  int start,
  int end,
  NoteInlineMarks Function(NoteInlineMarks marks) transform,
) {
  final result = <NoteTextRun>[];
  var offset = 0;
  for (final run in source) {
    final runStart = offset;
    final runEnd = offset + run.text.length;
    if (runEnd <= start || runStart >= end) {
      result.add(run);
      offset = runEnd;
      continue;
    }
    final localStart = (start - runStart).clamp(0, run.text.length).toInt();
    final localEnd = (end - runStart).clamp(0, run.text.length).toInt();
    if (localStart > 0) {
      result.add(
        NoteTextRun(text: run.text.substring(0, localStart), marks: run.marks),
      );
    }
    if (localStart < localEnd) {
      result.add(
        NoteTextRun(
          text: run.text.substring(localStart, localEnd),
          marks: transform(run.marks),
        ),
      );
    }
    if (localEnd < run.text.length) {
      result.add(
        NoteTextRun(text: run.text.substring(localEnd), marks: run.marks),
      );
    }
    offset = runEnd;
  }
  return _mergeRuns(result);
}

List<NoteInlineMarks> _marksForSelection(
  NoteBlock block,
  TextSelection selection,
) {
  final runs = block.effectiveRuns;
  if (runs.isEmpty) return const <NoteInlineMarks>[];
  final textLength = block.effectiveText.length;
  var start = selection.start.clamp(0, textLength).toInt();
  var end = selection.end.clamp(0, textLength).toInt();
  if (start == end) {
    if (textLength == 0) return const <NoteInlineMarks>[];
    start = start == textLength ? start - 1 : start;
    end = start + 1;
  }
  final result = <NoteInlineMarks>[];
  var offset = 0;
  for (final run in runs) {
    final runEnd = offset + run.text.length;
    if (runEnd > start && offset < end) result.add(run.marks);
    offset = runEnd;
  }
  return result;
}

List<List<String>> _normalizedTableCells(NoteTableData data) {
  final cells = data.cells.isEmpty ? NoteTableData.empty().cells : data.cells;
  final columns = cells.isEmpty || cells.first.isEmpty
      ? 2
      : cells.first.length.clamp(1, 6).toInt();
  return [
    for (final row in cells)
      [
        ...row.take(columns),
        if (row.length < columns)
          ...List<String>.filled(columns - row.length, ''),
      ],
  ];
}

List<NoteTextRun> _mergeRuns(List<NoteTextRun> runs) {
  final result = <NoteTextRun>[];
  for (final run in runs.where((item) => item.text.isNotEmpty)) {
    if (result.isNotEmpty &&
        result.last.marks.toJson().toString() ==
            run.marks.toJson().toString()) {
      final previous = result.removeLast();
      result.add(
        NoteTextRun(text: '${previous.text}${run.text}', marks: run.marks),
      );
    } else {
      result.add(run);
    }
  }
  return List<NoteTextRun>.unmodifiable(result);
}

NoteBlock _cloneNoteBlockWithNewId(NoteBlock source) {
  final json = Map<String, dynamic>.from(source.toJson());
  json['id'] = generateNoteBlockId();
  return NoteBlock.fromJson(json);
}

List<NoteBlock>? _parseStructuredClipboardText(String plainText) {
  final lines = plainText.split('\n');
  if (lines.isEmpty) return null;
  final parsed = <NoteBlock>[];
  var structuredCount = 0;
  for (final line in lines) {
    final result = _parseClipboardLine(line);
    parsed.add(result.$1);
    if (result.$2) structuredCount++;
  }
  if (structuredCount == 0) return null;
  return parsed;
}

(NoteBlock, bool) _parseClipboardLine(String rawLine) {
  final line = rawLine.replaceAll('\t', '  ');

  final checklist = RegExp(r'^\s*(?:[-*]\s+)?\[( |x|X)\]\s*(.*)$')
      .firstMatch(line);
  if (checklist != null) {
    return (
      NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.checklist,
        text: checklist.group(2) ?? '',
        checked: (checklist.group(1) ?? '').toLowerCase() == 'x',
      ),
      true,
    );
  }

  final unicodeChecklist = RegExp(r'^\s*([☐☑☒□])\s*(.*)$').firstMatch(line);
  if (unicodeChecklist != null) {
    final marker = unicodeChecklist.group(1) ?? '';
    return (
      NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.checklist,
        text: unicodeChecklist.group(2) ?? '',
        checked: marker == '☑' || marker == '☒',
      ),
      true,
    );
  }

  final heading = RegExp(r'^\s*(#{1,3})\s+(.*)$').firstMatch(line);
  if (heading != null) {
    return (
      NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.heading,
        level: (heading.group(1) ?? '#').length,
        text: heading.group(2) ?? '',
      ),
      true,
    );
  }

  final quote = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
  if (quote != null) {
    return (
      NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.quote,
        text: quote.group(1) ?? '',
      ),
      true,
    );
  }

  final numbered = RegExp(r'^\s*\d+[.)]\s+(.*)$').firstMatch(line);
  if (numbered != null) {
    return (
      NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.numberedList,
        text: numbered.group(1) ?? '',
      ),
      true,
    );
  }

  final bullet = RegExp(r'^\s*[-*•]\s+(.*)$').firstMatch(line);
  if (bullet != null) {
    return (
      NoteBlock(
        id: generateNoteBlockId(),
        type: NoteBlockType.bulletedList,
        text: bullet.group(1) ?? '',
      ),
      true,
    );
  }

  return (
    NoteBlock(
      id: generateNoteBlockId(),
      type: NoteBlockType.paragraph,
      text: line,
    ),
    false,
  );
}
