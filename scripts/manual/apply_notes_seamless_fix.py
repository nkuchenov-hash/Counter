from __future__ import annotations

import re
from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one exact match, found {count}\n{old[:160]}")
    file.write_text(text.replace(old, new), encoding="utf-8")


def regex_once(path: str, pattern: str, replacement: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    result, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{path}: expected one regex match, found {count}\n{pattern[:160]}")
    file.write_text(result, encoding="utf-8")


# One continuous sheet instead of floating blocks on the page background.
replace_once(
    "lib/features/notes/notes_glm_surface.dart",
    """            return Center(
              child: SizedBox(
                width: columnWidth,
                height: constraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    topBar,
                    Expanded(child: body),
                    if (keyboardInset > 0) SizedBox(height: keyboardInset),
                    toolbar,
                  ],
                ),
              ),
            );""",
    """            final scheme = Theme.of(context).colorScheme;
            final hasOuterCanvas = constraints.maxWidth > kGlmEditorMaxWidth;
            return Center(
              child: SizedBox(
                width: columnWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: hasOuterCanvas
                        ? Border.symmetric(
                            vertical: BorderSide(
                              color: scheme.outlineVariant.withValues(alpha: 0.45),
                            ),
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      topBar,
                      Expanded(child: body),
                      if (keyboardInset > 0) SizedBox(height: keyboardInset),
                      toolbar,
                    ],
                  ),
                ),
              ),
            );""",
)

# Keep typing local to the active field. The document draft and autosave update
# without rebuilding the entire editor tree on every character.
replace_once(
    "lib/features/notes/note_editor_page.dart",
    """  void _syncToBrain() {
    if (widget.parityPreview) return;
    final title = _titleController.text.trim();
    setState(() => _status = _SaveStatus.saving);
    final doc = _doc;
    DatabaseService.instance.applyNoteEdit(
      planRowIdForBackend: _task.planRowIdForBackend,
      doc: doc,
      title: title,
      categoryId: _task.categoryId,
      tags: _task.tags,
      isDone: _task.isDone,
    );
    setState(() {
      _status = _SaveStatus.saved;
      _task = _task.copyWith(
        title: title,
        notesDeltaJson: doc.encode(),
        updatedAt: DateTime.now(),
      );
    });
  }""",
    """  void _syncToBrain() {
    if (widget.parityPreview) return;
    final title = _titleController.text.trim();
    _status = _SaveStatus.saving;
    final doc = _doc;
    DatabaseService.instance.applyNoteEdit(
      planRowIdForBackend: _task.planRowIdForBackend,
      doc: doc,
      title: title,
      categoryId: _task.categoryId,
      tags: _task.tags,
      isDone: _task.isDone,
    );
    _status = _SaveStatus.saved;
    _task = _task.copyWith(
      title: title,
      notesDeltaJson: doc.encode(),
      updatedAt: DateTime.now(),
    );
  }""",
)

replace_once(
    "lib/features/notes/note_editor_page.dart",
    """  void _updateBlock(String id, NoteBlock Function(NoteBlock) patch) {
    final blocks = List<NoteBlock>.from(_doc.blocks);
    final i = blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    blocks[i] = patch(blocks[i]);
    _mutate(_doc.copyWith(blocks: blocks));
  }
""",
    """  void _updateBlock(String id, NoteBlock Function(NoteBlock) patch) {
    final blocks = List<NoteBlock>.from(_doc.blocks);
    final i = blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    blocks[i] = patch(blocks[i]);
    _mutate(_doc.copyWith(blocks: blocks));
  }

  void _updateBlockDraft(String id, NoteBlock Function(NoteBlock) patch) {
    final blocks = List<NoteBlock>.from(_doc.blocks);
    final i = blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    blocks[i] = patch(blocks[i]);
    _doc = _doc.copyWith(blocks: blocks);
    _status = _SaveStatus.editing;
    _gate.schedule(_syncToBrain);
  }
""",
)

replace_once(
    "lib/features/notes/note_editor_page.dart",
    """  // ---- Toolbar actions on active block -----------------------------------
""",
    """  int _numberedOrdinalAt(int index) {
    if (_doc.blocks[index].type != NoteBlockType.numberedList) return 1;
    var start = index;
    while (start > 0 &&
        _doc.blocks[start - 1].type == NoteBlockType.numberedList) {
      start--;
    }
    return index - start + 1;
  }

  // ---- Toolbar actions on active block -----------------------------------
""",
)

replace_once(
    "lib/features/notes/note_editor_page.dart",
    """            if (i > 0) const SizedBox(height: kNotesBlockGap),
            NoteEditorBlockRow(
              key: ValueKey(_doc.blocks[i].id),
              block: _doc.blocks[i],
              isActive: _doc.blocks[i].id == _activeBlockId,
              canMoveUp: i > 0,
              canMoveDown: i < _doc.blocks.length - 1,
""",
    """            if (i > 0) const SizedBox(height: 2),
            NoteEditorBlockRow(
              key: ValueKey(_doc.blocks[i].id),
              block: _doc.blocks[i],
              isActive: _doc.blocks[i].id == _activeBlockId,
              listOrdinal: _numberedOrdinalAt(i),
              canMoveUp: i > 0,
              canMoveDown: i < _doc.blocks.length - 1,
""",
)

replace_once(
    "lib/features/notes/note_editor_page.dart",
    """              onUpdate: (patch) =>
                  _updateBlock(_doc.blocks[i].id, patch.applyTo),
              onDelete: () => _deleteBlock(_doc.blocks[i].id),
""",
    """              onUpdate: (patch) =>
                  _updateBlock(_doc.blocks[i].id, patch.applyTo),
              onTextChanged: (patch) =>
                  _updateBlockDraft(_doc.blocks[i].id, patch.applyTo),
              onTableChanged: (table) => _updateBlockDraft(
                _doc.blocks[i].id,
                (current) => current.copyWith(table: table),
              ),
              onDelete: () => _deleteBlock(_doc.blocks[i].id),
""",
)

# Stable rich-text controller: derive runs before TextEditingController notifies
# RenderEditable, and avoid row/page setState for every collapsed caret move.
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    required this.onUpdate,
    required this.onDelete,
""",
    """    required this.onUpdate,
    required this.onTextChanged,
    required this.onTableChanged,
    required this.onDelete,
""",
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    required this.loc,
  });

  final NoteBlock block;
  final bool isActive;
""",
    """    required this.loc,
    this.listOrdinal = 1,
  });

  final NoteBlock block;
  final bool isActive;
  final int listOrdinal;
""",
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  final VoidCallback onActivate;
  final void Function(NoteEditorBlockPatch) onUpdate;
  final VoidCallback onDelete;
""",
    """  final VoidCallback onActivate;
  final void Function(NoteEditorBlockPatch) onUpdate;
  final void Function(NoteEditorBlockPatch) onTextChanged;
  final ValueChanged<NoteTableData> onTableChanged;
  final VoidCallback onDelete;
""",
)

replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  void _handleControllerState() {
    final selection = _textController.selection;
    final text = _textController.text;
    final slashQuery = text.startsWith('/') ? text.substring(1) : '';
    if (selection == _selection && slashQuery == _slashQuery) return;
    if (!mounted) return;
    setState(() {
      _selection = selection;
      _slashQuery = slashQuery;
    });
  }""",
    """  void _handleControllerState() {
    final selection = _textController.selection;
    final text = _textController.text;
    final slashQuery = text.startsWith('/') ? text.substring(1) : '';
    final hadSelection = _selection.isValid && !_selection.isCollapsed;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final needsRebuild = slashQuery != _slashQuery ||
        hadSelection != hasSelection ||
        (hasSelection && selection != _selection);
    _selection = selection;
    _slashQuery = slashQuery;
    if (needsRebuild && mounted) setState(() {});
  }""",
)

replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    if (blockChanged || contentChanged) {
      _editingText = nextText;
      _editingRuns = List<NoteTextRun>.unmodifiable(nextRuns);
      _textController.setRuns(_editingRuns);
    }
    if (blockChanged) {
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    } else if (nextText != _textController.text) {
      final offset = _textController.selection.extentOffset
          .clamp(0, nextText.length)
          .toInt();
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
""",
    """    if (blockChanged || contentChanged) {
      _editingText = nextText;
      _editingRuns = List<NoteTextRun>.unmodifiable(nextRuns);
      if (blockChanged || nextText != _textController.text) {
        final offset = blockChanged
            ? nextText.length
            : _textController.selection.extentOffset
                  .clamp(0, nextText.length)
                  .toInt();
        _textController.syncDocument(
          text: nextText,
          runs: _editingRuns,
          selection: TextSelection.collapsed(offset: offset),
        );
      } else {
        _textController.setRuns(_editingRuns);
      }
    }
""",
)

replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """        onTableChanged: (table) =>
            widget.onUpdate(NoteEditorBlockPatch(table: table)),
""",
    """        onTableChanged: widget.onTableChanged,
""",
)

replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """            decoration: widget.isActive
                ? BoxDecoration(
                    color: notesBlockActiveFill(scheme),
                    borderRadius: BorderRadius.circular(8),
                  )
                : isQuote
                ? BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.24),
                    border: Border(
                      left: BorderSide(color: scheme.primary, width: 3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : isCallout
                ? BoxDecoration(
                    color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  )
                : isCode
                ? BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
""",
    """            decoration: isQuote
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: scheme.primary, width: 2),
                    ),
                  )
                : isCallout
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: scheme.tertiary, width: 2),
                    ),
                  )
                : isCode
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: scheme.outlineVariant, width: 2),
                    ),
                  )
                : null,
            padding: EdgeInsets.fromLTRB(
              isQuote || isCallout || isCode ? 10 : 0,
              1,
              0,
              1,
            ),
""",
)

replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """                          shape: BoxShape.circle,
                          border: Border.all(
""",
    """                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
""",
)

replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """                    child: isNumbered
                        ? Text(
                            '1.',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : InkWell(
                            onTap: isCollapsible
                                ? () => widget.onUpdate(
                                    NoteEditorBlockPatch(
                                      collapsed: !block.collapsed,
                                    ),
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Icon(
                              isBullet
                                  ? Icons.circle
                                  : isQuote
                                  ? Icons.format_quote_rounded
                                  : isCallout
                                  ? Icons.lightbulb_outline_rounded
                                  : block.collapsed
                                  ? Icons.chevron_right_rounded
                                  : Icons.expand_more_rounded,
                              size: isBullet ? 7 : 16,
                              color: isCallout
                                  ? scheme.tertiary
                                  : scheme.primary,
                            ),
                          ),
""",
    """                    child: isNumbered
                        ? Text(
                            '${widget.listOrdinal}.',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : isBullet
                        ? Text(
                            '•',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 18,
                              height: 1,
                            ),
                          )
                        : InkWell(
                            onTap: isCollapsible
                                ? () => widget.onUpdate(
                                    NoteEditorBlockPatch(
                                      collapsed: !block.collapsed,
                                    ),
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Icon(
                              isQuote
                                  ? Icons.format_quote_rounded
                                  : isCallout
                                  ? Icons.lightbulb_outline_rounded
                                  : block.collapsed
                                  ? Icons.chevron_right_rounded
                                  : Icons.expand_more_rounded,
                              size: 16,
                              color: isCallout
                                  ? scheme.tertiary
                                  : scheme.primary,
                            ),
                          ),
""",
)

replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """                    onChanged: (value) {
                      final nextRuns = applyNoteTextEditToRuns(
                        oldText: _editingText,
                        oldRuns: _editingRuns,
                        newText: value,
                      );
                      _editingText = value;
                      _editingRuns = nextRuns;
                      _textController.setRuns(nextRuns);
                      widget.onUpdate(
                        NoteEditorBlockPatch(text: value, runs: nextRuns),
                      );
                    },
""",
    """                    onChanged: (value) {
                      final nextRuns = _textController.runs;
                      _editingText = value;
                      _editingRuns = nextRuns;
                      widget.onTextChanged(
                        NoteEditorBlockPatch(text: value, runs: nextRuns),
                      );
                    },
""",
)

# Remove decorative media cards. The image/drawing itself is the document content.
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _bytesFromDataUrl(block.imageData)!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: scheme.errorContainer.withValues(alpha: 0.3),
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: scheme.error),
                ),
              ),
            ),
""",
    """            Image.memory(
              _bytesFromDataUrl(block.imageData)!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(
                height: 80,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: scheme.error),
                ),
              ),
            ),
""",
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.white,
                child: Image.memory(
                  _bytesFromDataUrl(block.drawingData)!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: scheme.errorContainer.withValues(alpha: 0.3),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.error,
                    ),
                  ),
                ),
              ),
            ),
""",
    """            Image.memory(
              _bytesFromDataUrl(block.drawingData)!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(
                height: 80,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.error,
                  ),
                ),
              ),
            ),
""",
)

regex_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    r"class _NoteRichTextController extends TextEditingController \{.*?\n\}\n\nTextStyle _styleForMarks",
    """class _NoteRichTextController extends TextEditingController {
  _NoteRichTextController({
    required String text,
    required List<NoteTextRun> runs,
  }) : _runs = List<NoteTextRun>.unmodifiable(runs),
       super(text: text);

  List<NoteTextRun> _runs;
  bool _syncingDocument = false;
  TextStyle? baseStyle;

  List<NoteTextRun> get runs => List<NoteTextRun>.unmodifiable(_runs);

  void setRuns(List<NoteTextRun> runs) {
    _runs = List<NoteTextRun>.unmodifiable(runs);
  }

  void syncDocument({
    required String text,
    required List<NoteTextRun> runs,
    required TextSelection selection,
  }) {
    _syncingDocument = true;
    _runs = List<NoteTextRun>.unmodifiable(runs);
    super.value = TextEditingValue(text: text, selection: selection);
    _syncingDocument = false;
  }

  @override
  set value(TextEditingValue newValue) {
    if (!_syncingDocument && newValue.text != text) {
      _runs = List<NoteTextRun>.unmodifiable(
        applyNoteTextEditToRuns(
          oldText: text,
          oldRuns: _runs,
          newText: newValue.text,
        ),
      );
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = baseStyle ?? style ?? const TextStyle();
    if (_runs.isEmpty || _runs.map((run) => run.text).join() != text) {
      return TextSpan(style: effectiveStyle, text: text);
    }
    return TextSpan(
      style: effectiveStyle,
      children: [
        for (final run in _runs)
          TextSpan(
            text: run.text,
            style: _styleForMarks(effectiveStyle, run.marks),
          ),
      ],
    );
  }
}

TextStyle _styleForMarks""",
)

# Seamless special blocks. Table owns its in-progress cell state so typing a
# cell does not rebuild/recreate the entire editor page.
table_replacement = r'''class _TableBlock extends StatefulWidget {
  const _TableBlock({
    required this.data,
    required this.isActive,
    required this.loc,
    required this.onActivate,
    required this.onDelete,
    required this.onChanged,
  });

  final NoteTableData data;
  final bool isActive;
  final String loc;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final ValueChanged<NoteTableData> onChanged;

  @override
  State<_TableBlock> createState() => _TableBlockState();
}

class _TableBlockState extends State<_TableBlock> {
  late NoteTableData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  @override
  void didUpdateWidget(covariant _TableBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) _data = widget.data;
  }

  void _emit(NoteTableData next, {bool rebuild = true}) {
    if (rebuild) {
      setState(() => _data = next);
    } else {
      _data = next;
    }
    widget.onChanged(next);
  }

  void _changeCell(int row, int column, String value) {
    final cells = _data.cells.map((item) => List<String>.from(item)).toList();
    if (row >= cells.length || column >= cells[row].length) return;
    cells[row][column] = value;
    _emit(_data.copyWith(cells: cells), rebuild: false);
  }

  void _addRow() {
    final columns = _data.columnCount.clamp(1, 6).toInt();
    if (_data.rowCount >= 20) return;
    _emit(
      _data.copyWith(
        cells: [
          ..._data.cells.map((row) => List<String>.from(row)),
          List<String>.filled(columns, ''),
        ],
      ),
    );
  }

  void _addColumn() {
    if (_data.columnCount >= 6) return;
    final source = _data.cells.isEmpty
        ? NoteTableData.empty().cells
        : _data.cells;
    _emit(
      _data.copyWith(
        cells: source
            .map((row) => <String>[...row, ''])
            .toList(growable: false),
      ),
    );
  }

  void _removeRow() {
    if (_data.rowCount <= 1) return;
    _emit(
      _data.copyWith(
        cells: _data.cells
            .take(_data.rowCount - 1)
            .map((row) => List<String>.from(row))
            .toList(),
      ),
    );
  }

  void _removeColumn() {
    if (_data.columnCount <= 1) return;
    _emit(
      _data.copyWith(
        cells: _data.cells
            .map((row) => row.take(row.length - 1).toList())
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cells = _data.cells.isEmpty
        ? NoteTableData.empty().cells
        : _data.cells;
    return GestureDetector(
      onTap: widget.onActivate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(142),
                border: TableBorder.all(
                  color: widget.isActive
                      ? scheme.primary.withValues(alpha: 0.65)
                      : scheme.outlineVariant,
                  width: widget.isActive ? 1.1 : 0.8,
                ),
                children: [
                  for (var row = 0; row < cells.length; row++)
                    TableRow(
                      children: [
                        for (var column = 0;
                            column < cells[row].length;
                            column++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: TextFormField(
                              key: ValueKey('table-${row}_$column'),
                              initialValue: cells[row][column],
                              maxLines: null,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _data.hasHeader && row == 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 7),
                              ),
                              onTap: widget.onActivate,
                              onChanged: (value) =>
                                  _changeCell(row, column, value),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (widget.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _TableAction(
                      icon: Icons.add_rounded,
                      label: t(widget.loc, 'notes_tools_add_row'),
                      onTap: _addRow,
                    ),
                    _TableAction(
                      icon: Icons.view_column_outlined,
                      label: t(widget.loc, 'notes_tools_add_column'),
                      onTap: _addColumn,
                    ),
                    _TableAction(
                      icon: _data.hasHeader
                          ? Icons.table_rows_rounded
                          : Icons.table_rows_outlined,
                      label: t(widget.loc, 'notes_tools_header_row'),
                      onTap: () =>
                          _emit(_data.copyWith(hasHeader: !_data.hasHeader)),
                    ),
                    _TableAction(
                      icon: Icons.remove_rounded,
                      label: t(widget.loc, 'notes_tools_remove_row'),
                      onTap: _data.rowCount > 1 ? _removeRow : null,
                    ),
                    _TableAction(
                      icon: Icons.view_column_rounded,
                      label: t(widget.loc, 'notes_tools_remove_column'),
                      onTap: _data.columnCount > 1 ? _removeColumn : null,
                    ),
                    _TableAction(
                      icon: Icons.delete_outline_rounded,
                      label: t(widget.loc, 'notes_v3_editor_delete_block'),
                      danger: true,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkCardBlock'''
regex_once(
    "lib/features/notes/widgets/notes_special_block_widgets.dart",
    r"class _TableBlock extends StatelessWidget \{.*?\n\}\n\nclass _LinkCardBlock",
    table_replacement,
)

replace_once(
    "lib/features/notes/widgets/notes_special_block_widgets.dart",
    """      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
""",
    """      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
""",
)
replace_once(
    "lib/features/notes/widgets/notes_special_block_widgets.dart",
    """            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.link_rounded, color: scheme.primary),
            ),
""",
    """            Icon(Icons.link_rounded, size: 20, color: scheme.primary),
""",
)
replace_once(
    "lib/features/notes/widgets/notes_special_block_widgets.dart",
    """      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: scheme.primaryContainer.withValues(alpha: 0.34),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
""",
    """      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
""",
)

print("Applied seamless Notes editor fix")
