// Notes editor block widgets — visual block rows and add-block chrome.
//
// Receives [NoteBlock] data + callbacks from [NoteEditorPage]. Does not own
// document state, autosave, or DatabaseService calls.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/features/notes/widgets/notes_special_block_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Bridges the fixed primary toolbar to Flutter's active text undo stack.
/// Structural block history remains owned by the document/page coordinator.
abstract final class NotesTextUndoBridge {
  static UndoHistoryController? _active;

  static void attach(UndoHistoryController controller) {
    _active = controller;
  }

  static void detach(UndoHistoryController controller) {
    if (identical(_active, controller)) _active = null;
  }

  static void undo() => _active?.undo();
  static void redo() => _active?.redo();
}

/// Partial update for a single [NoteBlock], applied by the editor page.
class NoteEditorBlockPatch {
  const NoteEditorBlockPatch({
    this.type,
    this.text,
    this.checked,
    this.level,
    this.bold,
    this.italic,
    this.underline,
    this.color = _unset,
    this.imageData = _unset,
    this.drawingData = _unset,
    this.runs,
    this.callout = _unset,
    this.table = _unset,
    this.linkData = _unset,
    this.reference = _unset,
    this.codeLanguage = _unset,
    this.collapsed,
  });

  static const Object _unset = Object();

  final NoteBlockType? type;
  final String? text;
  final bool? checked;
  final int? level;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final Object? color;
  final Object? imageData;
  final Object? drawingData;
  final List<NoteTextRun>? runs;
  final Object? callout;
  final Object? table;
  final Object? linkData;
  final Object? reference;
  final Object? codeLanguage;
  final bool? collapsed;

  NoteBlock applyTo(NoteBlock block) => block.copyWith(
    type: type ?? block.type,
    text: text ?? block.text,
    checked: checked ?? block.checked,
    level: level ?? block.level,
    bold: bold ?? block.bold,
    italic: italic ?? block.italic,
    underline: underline ?? block.underline,
    color: identical(color, _unset) ? block.color : color as String?,
    imageData: identical(imageData, _unset)
        ? block.imageData
        : imageData as String?,
    drawingData: identical(drawingData, _unset)
        ? block.drawingData
        : drawingData as String?,
    runs: runs ?? block.runs,
    callout: identical(callout, _unset)
        ? block.callout
        : callout as NoteCalloutData?,
    table: identical(table, _unset) ? block.table : table as NoteTableData?,
    linkData: identical(linkData, _unset)
        ? block.linkData
        : linkData as NoteLinkData?,
    reference: identical(reference, _unset)
        ? block.reference
        : reference as NoteReferenceData?,
    codeLanguage: identical(codeLanguage, _unset)
        ? block.codeLanguage
        : codeLanguage as String?,
    collapsed: collapsed ?? block.collapsed,
  );
}

/// One note block in the editor scroll body.
class NoteEditorBlockRow extends StatefulWidget {
  const NoteEditorBlockRow({
    super.key,
    required this.block,
    required this.isActive,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onActivate,
    required this.onUpdate,
    required this.onTextChanged,
    required this.onTableChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEditDrawing,
    required this.onEnter,
    required this.loc,
    this.listOrdinal = 1,
  });

  final NoteBlock block;
  final bool isActive;
  final int listOrdinal;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onActivate;
  final void Function(NoteEditorBlockPatch) onUpdate;
  final void Function(NoteEditorBlockPatch) onTextChanged;
  final ValueChanged<NoteTableData> onTableChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEditDrawing;
  final VoidCallback onEnter;
  final String loc;

  @override
  State<NoteEditorBlockRow> createState() => _NoteEditorBlockRowState();
}

class _NoteEditorBlockRowState extends State<NoteEditorBlockRow> {
  late _NoteRichTextController _textController;
  late FocusNode _focusNode;
  late UndoHistoryController _undoController;
  TextSelection _selection = const TextSelection.collapsed(offset: -1);
  String _slashQuery = '';
  late String _editingText;
  late List<NoteTextRun> _editingRuns;

  @override
  void initState() {
    super.initState();
    _editingText = widget.block.effectiveText;
    _editingRuns = List<NoteTextRun>.unmodifiable(widget.block.effectiveRuns);
    _textController = _NoteRichTextController(
      text: _editingText,
      runs: _editingRuns,
    )..addListener(_handleControllerState);
    _undoController = UndoHistoryController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onActivate();
        NotesTextUndoBridge.attach(_undoController);
      } else {
        NotesTextUndoBridge.detach(_undoController);
      }
      if (mounted) setState(() {});
    });
  }

  void _handleControllerState() {
    final selection = _textController.selection;
    final text = _textController.text;
    final slashQuery = text.startsWith('/') ? text.substring(1) : '';
    final hadSelection = _selection.isValid && !_selection.isCollapsed;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final needsRebuild =
        slashQuery != _slashQuery ||
        hadSelection != hasSelection ||
        (hasSelection && selection != _selection);
    _selection = selection;
    _slashQuery = slashQuery;
    if (needsRebuild && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant NoteEditorBlockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.block.effectiveText;
    final nextRuns = widget.block.effectiveRuns;
    final blockChanged = oldWidget.block.id != widget.block.id;
    final contentChanged =
        nextText != _editingText ||
        !_noteRunsEquivalent(nextRuns, _editingRuns);
    if (blockChanged || contentChanged) {
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
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleControllerState)
      ..dispose();
    NotesTextUndoBridge.detach(_undoController);
    _undoController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasTextSelection =>
      _selection.isValid &&
      !_selection.isCollapsed &&
      _selection.start >= 0 &&
      _selection.end <= _textController.text.length;

  List<NoteTextRun> _sourceRuns() {
    if (_editingRuns.map((run) => run.text).join() == _textController.text) {
      return _editingRuns;
    }
    if (_textController.text.isEmpty) return const <NoteTextRun>[];
    return <NoteTextRun>[NoteTextRun(text: _textController.text)];
  }

  List<NoteTextRun> _selectedRuns() {
    if (!_hasTextSelection) return const <NoteTextRun>[];
    final result = <NoteTextRun>[];
    var offset = 0;
    for (final run in _sourceRuns()) {
      final runStart = offset;
      final runEnd = offset + run.text.length;
      final start = _selection.start.clamp(runStart, runEnd).toInt();
      final end = _selection.end.clamp(runStart, runEnd).toInt();
      if (start < end) {
        result.add(
          NoteTextRun(
            text: run.text.substring(start - runStart, end - runStart),
            marks: run.marks,
          ),
        );
      }
      offset = runEnd;
    }
    return result;
  }

  List<NoteTextRun> _transformSelection(
    NoteInlineMarks Function(NoteInlineMarks marks) transform,
  ) {
    if (!_hasTextSelection) return _sourceRuns();
    final result = <NoteTextRun>[];
    var offset = 0;
    for (final run in _sourceRuns()) {
      final runStart = offset;
      final runEnd = offset + run.text.length;
      final selectedStart = _selection.start.clamp(runStart, runEnd).toInt();
      final selectedEnd = _selection.end.clamp(runStart, runEnd).toInt();

      if (selectedStart >= selectedEnd) {
        result.add(run);
      } else {
        final localStart = selectedStart - runStart;
        final localEnd = selectedEnd - runStart;
        if (localStart > 0) {
          result.add(
            NoteTextRun(
              text: run.text.substring(0, localStart),
              marks: run.marks,
            ),
          );
        }
        result.add(
          NoteTextRun(
            text: run.text.substring(localStart, localEnd),
            marks: transform(run.marks),
          ),
        );
        if (localEnd < run.text.length) {
          result.add(
            NoteTextRun(text: run.text.substring(localEnd), marks: run.marks),
          );
        }
      }
      offset = runEnd;
    }
    return _mergeRuns(result);
  }

  void _toggleInlineMark(_InlineMarkAction action) {
    if (!_hasTextSelection) return;
    final selected = _selectedRuns();
    if (selected.isEmpty) return;
    final allEnabled = selected.every(
      (run) => switch (action) {
        _InlineMarkAction.bold => run.marks.bold,
        _InlineMarkAction.italic => run.marks.italic,
        _InlineMarkAction.underline => run.marks.underline,
        _InlineMarkAction.strike => run.marks.strike,
        _InlineMarkAction.highlight => run.marks.highlightColor != null,
      },
    );
    final runs = _transformSelection(
      (marks) => switch (action) {
        _InlineMarkAction.bold => marks.copyWith(bold: !allEnabled),
        _InlineMarkAction.italic => marks.copyWith(italic: !allEnabled),
        _InlineMarkAction.underline => marks.copyWith(underline: !allEnabled),
        _InlineMarkAction.strike => marks.copyWith(strike: !allEnabled),
        _InlineMarkAction.highlight => marks.copyWith(
          highlightColor: allEnabled ? null : '#FFF2A8',
        ),
      },
    );
    _editingRuns = List<NoteTextRun>.unmodifiable(runs);
    _textController.setRuns(_editingRuns);
    widget.onUpdate(
      NoteEditorBlockPatch(text: _textController.text, runs: _editingRuns),
    );
  }

  Future<void> _editInlineLink() async {
    if (!_hasTextSelection) return;
    final current = _selectedRuns()
        .map((run) => run.marks.link)
        .whereType<String>()
        .firstOrNull;
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(widget.loc, 'notes_tools_link_card')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'URL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(t(widget.loc, 'cancel')),
          ),
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: Text(t(widget.loc, 'delete')),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t(widget.loc, 'save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null) return;
    final runs = _transformSelection(
      (marks) => marks.copyWith(link: result.isEmpty ? null : result),
    );
    _editingRuns = List<NoteTextRun>.unmodifiable(runs);
    _textController.setRuns(_editingRuns);
    widget.onUpdate(
      NoteEditorBlockPatch(text: _textController.text, runs: _editingRuns),
    );
  }

  void _createPlanFromSelectionOrBlock() {
    final selection = _textController.selection;
    final text = selection.isValid && !selection.isCollapsed
        ? _textController.text.substring(
            selection.start.clamp(0, _textController.text.length).toInt(),
            selection.end.clamp(0, _textController.text.length).toInt(),
          )
        : _textController.text;
    final title = text.trim();
    if (title.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(widget.loc, 'notes_tools_plan_created'))),
    );
    unawaited(
      DatabaseService.instance.addPlanningTaskFromVoiceText(
        rawText: title,
        wallDay: DateTime.now(),
        isBacklog: true,
      ),
    );
  }

  void _applySlashCommand(_SlashCommand command) {
    setState(() => _slashQuery = '');
    final table = command.type == NoteBlockType.table
        ? NoteTableData.empty(rows: 3, columns: 3)
        : null;
    final callout = command.type == NoteBlockType.callout
        ? const NoteCalloutData(type: NoteCalloutType.idea)
        : null;
    widget.onUpdate(
      NoteEditorBlockPatch(
        type: command.type,
        text: '',
        runs: const <NoteTextRun>[],
        level: command.headingLevel,
        table: table,
        callout: callout,
        codeLanguage: command.type == NoteBlockType.codeBlock ? 'plain' : null,
        collapsed: command.type == NoteBlockType.collapsible ? false : null,
      ),
    );
  }

  void _convertBlock(NoteBlockType type) {
    widget.onUpdate(
      NoteEditorBlockPatch(
        type: type,
        level: type == NoteBlockType.heading ? 2 : null,
        checked: type == NoteBlockType.checklist ? false : null,
        callout: type == NoteBlockType.callout
            ? const NoteCalloutData(type: NoteCalloutType.idea)
            : null,
        codeLanguage: type == NoteBlockType.codeBlock ? 'plain' : null,
        collapsed: type == NoteBlockType.collapsible ? false : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final scheme = Theme.of(context).colorScheme;
    final loc = widget.loc;

    if (block.type == NoteBlockType.image && block.imageData != null) {
      return _NoteEditorImageBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onDelete: widget.onDelete,
      );
    }
    if (block.type == NoteBlockType.drawing && block.drawingData != null) {
      return _NoteEditorDrawingBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onEditDrawing: widget.onEditDrawing,
        onDelete: widget.onDelete,
      );
    }
    if (!block.hasText) {
      return NotesSpecialBlockView(
        block: block,
        isActive: widget.isActive,
        loc: loc,
        onActivate: widget.onActivate,
        onDelete: widget.onDelete,
        onTableChanged: widget.onTableChanged,
      );
    }

    final isChecklist = block.type == NoteBlockType.checklist;
    final isHeading = block.type == NoteBlockType.heading;
    final isBullet = block.type == NoteBlockType.bulletedList;
    final isNumbered = block.type == NoteBlockType.numberedList;
    final isQuote = block.type == NoteBlockType.quote;
    final isCallout = block.type == NoteBlockType.callout;
    final isCode = block.type == NoteBlockType.codeBlock;
    final isCollapsible = block.type == NoteBlockType.collapsible;
    final hasStrike = block.effectiveRuns.any((run) => run.marks.strike);
    final headingSize = block.level == 1
        ? 24.0
        : block.level == 3
        ? 18.0
        : 20.0;
    final headingWeight = block.level == 3 ? FontWeight.w600 : FontWeight.w700;
    final textStyle = TextStyle(
      fontSize: isHeading ? headingSize : kGlmBodySize,
      fontWeight: isHeading
          ? headingWeight
          : (block.bold ? FontWeight.w700 : FontWeight.w400),
      fontStyle: block.italic ? FontStyle.italic : null,
      decoration: hasStrike
          ? TextDecoration.lineThrough
          : block.underline
          ? TextDecoration.underline
          : null,
      color:
          _parseHexColor(block.color) ??
          (isChecklist && block.checked
              ? kGlmMetaColor
              : const Color(0xFF1E293B)),
      height: isHeading ? 1.25 : 1.45,
      fontFamily: isCode ? 'monospace' : null,
    );
    _textController.baseStyle = textStyle;

    final slashCommands = _slashCommands(loc)
        .where(
          (command) =>
              _slashQuery.isEmpty ||
              command.command.contains(_slashQuery.toLowerCase()) ||
              command.label.toLowerCase().contains(_slashQuery.toLowerCase()),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isActive && _hasTextSelection)
          NotesSelectionToolbar(
            selectedRuns: _selectedRuns(),
            onBold: () => _toggleInlineMark(_InlineMarkAction.bold),
            onItalic: () => _toggleInlineMark(_InlineMarkAction.italic),
            onUnderline: () => _toggleInlineMark(_InlineMarkAction.underline),
            onStrike: () => _toggleInlineMark(_InlineMarkAction.strike),
            onHighlight: () => _toggleInlineMark(_InlineMarkAction.highlight),
            onLink: _editInlineLink,
            onCreatePlan: _createPlanFromSelectionOrBlock,
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onActivate,
          child: Container(
            decoration: isQuote
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isChecklist)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      onTap: () => widget.onUpdate(
                        NoteEditorBlockPatch(checked: !block.checked),
                      ),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: kNotesCheckCircleSize,
                        height: kNotesCheckCircleSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: block.checked
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFE2E8F0),
                            width: 2,
                          ),
                          color: block.checked ? const Color(0xFF6366F1) : null,
                        ),
                        child: block.checked
                            ? const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                if (isChecklist) const SizedBox(width: 8),
                if (isBullet ||
                    isNumbered ||
                    isQuote ||
                    isCallout ||
                    isCollapsible)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: isNumbered
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
                  ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    undoController: _undoController,
                    style: textStyle.copyWith(
                      decoration: isChecklist && block.checked
                          ? TextDecoration.lineThrough
                          : textStyle.decoration,
                      color: isChecklist && block.checked
                          ? kGlmMetaColor
                          : textStyle.color,
                    ),
                    decoration: InputDecoration(
                      hintText: isChecklist
                          ? t(loc, 'notes_v3_editor_list_item_hint')
                          : isHeading
                          ? t(loc, 'notes_v3_editor_heading_hint')
                          : t(loc, 'notes_v3_editor_start_writing'),
                      hintStyle: TextStyle(
                        fontSize: isHeading ? headingSize : kNotesBodySize,
                        fontWeight: isHeading ? headingWeight : FontWeight.w400,
                        color: kGlmMetaColor.withValues(alpha: 0.65),
                        height: isHeading ? 1.25 : 1.45,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    onChanged: (value) {
                      final nextRuns = _textController.runs;
                      _editingText = value;
                      _editingRuns = nextRuns;
                      widget.onTextChanged(
                        NoteEditorBlockPatch(text: value, runs: nextRuns),
                      );
                    },
                    onSubmitted: (_) => widget.onEnter(),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: widget.isActive
                      ? _NoteEditorBlockActiveControls(
                          block: block,
                          canMoveUp: widget.canMoveUp,
                          canMoveDown: widget.canMoveDown,
                          onMoveUp: widget.onMoveUp,
                          onMoveDown: widget.onMoveDown,
                          onConvert: _convertBlock,
                          onCreatePlan: _createPlanFromSelectionOrBlock,
                          onDelete: widget.onDelete,
                          loc: loc,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (_focusNode.hasFocus &&
            _textController.text.startsWith('/') &&
            slashCommands.isNotEmpty)
          _SlashCommandMenu(
            commands: slashCommands,
            onSelect: _applySlashCommand,
          ),
      ],
    );
  }
}

enum _InlineMarkAction { bold, italic, underline, strike, highlight }

class NotesSelectionToolbar extends StatelessWidget {
  const NotesSelectionToolbar({
    required this.selectedRuns,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrike,
    required this.onHighlight,
    required this.onLink,
    required this.onCreatePlan,
  });

  final List<NoteTextRun> selectedRuns;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrike;
  final VoidCallback onHighlight;
  final VoidCallback onLink;
  final VoidCallback onCreatePlan;

  bool _all(bool Function(NoteInlineMarks marks) test) =>
      selectedRuns.isNotEmpty && selectedRuns.every((run) => test(run.marks));

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SelectionToolButton(
              icon: Icons.format_bold_rounded,
              selected: _all((marks) => marks.bold),
              onTap: onBold,
            ),
            _SelectionToolButton(
              icon: Icons.format_italic_rounded,
              selected: _all((marks) => marks.italic),
              onTap: onItalic,
            ),
            _SelectionToolButton(
              icon: Icons.format_underlined_rounded,
              selected: _all((marks) => marks.underline),
              onTap: onUnderline,
            ),
            _SelectionToolButton(
              icon: Icons.format_strikethrough_rounded,
              selected: _all((marks) => marks.strike),
              onTap: onStrike,
            ),
            _SelectionToolButton(
              icon: Icons.format_color_fill_rounded,
              selected: _all((marks) => marks.highlightColor != null),
              onTap: onHighlight,
            ),
            _SelectionToolButton(
              icon: Icons.link_rounded,
              selected: _all((marks) => marks.link != null),
              onTap: onLink,
            ),
            _SelectionToolButton(
              icon: Icons.event_note_outlined,
              selected: false,
              onTap: onCreatePlan,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionToolButton extends StatelessWidget {
  const _SelectionToolButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: 17,
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SlashCommand {
  const _SlashCommand({
    required this.command,
    required this.label,
    required this.icon,
    required this.type,
    this.headingLevel,
  });

  final String command;
  final String label;
  final IconData icon;
  final NoteBlockType type;
  final int? headingLevel;
}

List<_SlashCommand> _slashCommands(String loc) => <_SlashCommand>[
  _SlashCommand(
    command: 'text',
    label: t(loc, 'notes_tools_body'),
    icon: Icons.text_fields_rounded,
    type: NoteBlockType.paragraph,
  ),
  const _SlashCommand(
    command: 'heading',
    label: 'H2',
    icon: Icons.title_rounded,
    type: NoteBlockType.heading,
    headingLevel: 2,
  ),
  _SlashCommand(
    command: 'checklist',
    label: t(loc, 'notes_v3_editor_add_checklist'),
    icon: Icons.checklist_rounded,
    type: NoteBlockType.checklist,
  ),
  _SlashCommand(
    command: 'bullets',
    label: t(loc, 'notes_tools_bullets'),
    icon: Icons.format_list_bulleted_rounded,
    type: NoteBlockType.bulletedList,
  ),
  _SlashCommand(
    command: 'numbers',
    label: t(loc, 'notes_tools_numbers'),
    icon: Icons.format_list_numbered_rounded,
    type: NoteBlockType.numberedList,
  ),
  _SlashCommand(
    command: 'quote',
    label: t(loc, 'notes_tools_quote'),
    icon: Icons.format_quote_rounded,
    type: NoteBlockType.quote,
  ),
  _SlashCommand(
    command: 'callout',
    label: t(loc, 'notes_tools_callout'),
    icon: Icons.lightbulb_outline_rounded,
    type: NoteBlockType.callout,
  ),
  _SlashCommand(
    command: 'table',
    label: t(loc, 'notes_tools_table'),
    icon: Icons.table_chart_outlined,
    type: NoteBlockType.table,
  ),
  _SlashCommand(
    command: 'code',
    label: t(loc, 'notes_tools_code_block'),
    icon: Icons.code_rounded,
    type: NoteBlockType.codeBlock,
  ),
  _SlashCommand(
    command: 'collapse',
    label: t(loc, 'notes_tools_collapsible'),
    icon: Icons.expand_more_rounded,
    type: NoteBlockType.collapsible,
  ),
  _SlashCommand(
    command: 'divider',
    label: t(loc, 'notes_tools_divider'),
    icon: Icons.horizontal_rule_rounded,
    type: NoteBlockType.divider,
  ),
];

class _SlashCommandMenu extends StatelessWidget {
  const _SlashCommandMenu({required this.commands, required this.onSelect});

  final List<_SlashCommand> commands;
  final ValueChanged<_SlashCommand> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: commands.length,
        itemBuilder: (context, index) {
          final command = commands[index];
          return ListTile(
            dense: true,
            leading: Icon(command.icon, size: 18),
            title: Text(
              command.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              '/${command.command}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            onTap: () => onSelect(command),
          );
        },
      ),
    );
  }
}

class _NoteEditorBlockActiveControls extends StatelessWidget {
  const _NoteEditorBlockActiveControls({
    required this.block,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onConvert,
    required this.onCreatePlan,
    required this.onDelete,
    required this.loc,
  });

  final NoteBlock block;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<NoteBlockType> onConvert;
  final VoidCallback onCreatePlan;
  final VoidCallback onDelete;
  final String loc;

  PopupMenuItem<void> _item({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    bool danger = false,
  }) {
    return PopupMenuItem<void>(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Icon(icon, size: 17, color: danger ? const Color(0xFFDC2626) : null),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: danger ? const Color(0xFFDC2626) : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<void>(
        tooltip: t(loc, 'notes_editor_more_tooltip'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 210),
        icon: const Icon(Icons.more_horiz_rounded, size: 18),
        itemBuilder: (context) => <PopupMenuEntry<void>>[
          if (canMoveUp)
            _item(
              icon: Icons.keyboard_arrow_up_rounded,
              label: t(loc, 'notes_v3_editor_move_up'),
              onTap: onMoveUp,
            ),
          if (canMoveDown)
            _item(
              icon: Icons.keyboard_arrow_down_rounded,
              label: t(loc, 'notes_v3_editor_move_down'),
              onTap: onMoveDown,
            ),
          if (canMoveUp || canMoveDown) const PopupMenuDivider(),
          _item(
            icon: Icons.text_fields_rounded,
            label: t(loc, 'notes_tools_body'),
            enabled: block.type != NoteBlockType.paragraph,
            onTap: () => onConvert(NoteBlockType.paragraph),
          ),
          _item(
            icon: Icons.title_rounded,
            label: 'H2',
            enabled: block.type != NoteBlockType.heading,
            onTap: () => onConvert(NoteBlockType.heading),
          ),
          _item(
            icon: Icons.checklist_rounded,
            label: t(loc, 'notes_v3_editor_add_checklist'),
            enabled: block.type != NoteBlockType.checklist,
            onTap: () => onConvert(NoteBlockType.checklist),
          ),
          _item(
            icon: Icons.format_list_bulleted_rounded,
            label: t(loc, 'notes_tools_bullets'),
            enabled: block.type != NoteBlockType.bulletedList,
            onTap: () => onConvert(NoteBlockType.bulletedList),
          ),
          _item(
            icon: Icons.format_list_numbered_rounded,
            label: t(loc, 'notes_tools_numbers'),
            enabled: block.type != NoteBlockType.numberedList,
            onTap: () => onConvert(NoteBlockType.numberedList),
          ),
          _item(
            icon: Icons.format_quote_rounded,
            label: t(loc, 'notes_tools_quote'),
            enabled: block.type != NoteBlockType.quote,
            onTap: () => onConvert(NoteBlockType.quote),
          ),
          _item(
            icon: Icons.lightbulb_outline_rounded,
            label: t(loc, 'notes_tools_callout'),
            enabled: block.type != NoteBlockType.callout,
            onTap: () => onConvert(NoteBlockType.callout),
          ),
          const PopupMenuDivider(),
          _item(
            icon: Icons.event_note_outlined,
            label: t(loc, 'notes_tools_create_plan'),
            onTap: onCreatePlan,
          ),
          _item(
            icon: Icons.delete_outline_rounded,
            label: t(loc, 'notes_v3_editor_delete_block'),
            onTap: onDelete,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _NoteEditorImageBlock extends StatelessWidget {
  const _NoteEditorImageBlock({
    required this.block,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  final NoteBlock block;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onActivate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          children: [
            Image.memory(
              _bytesFromDataUrl(block.imageData)!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(
                height: 80,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: scheme.error),
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: _NoteEditorMediaOverlayBtn(
                  icon: Icons.close_rounded,
                  onTap: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditorDrawingBlock extends StatelessWidget {
  const _NoteEditorDrawingBlock({
    required this.block,
    required this.isActive,
    required this.onActivate,
    required this.onEditDrawing,
    required this.onDelete,
  });

  final NoteBlock block;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onEditDrawing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onActivate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          children: [
            Image.memory(
              _bytesFromDataUrl(block.drawingData)!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(
                height: 80,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: scheme.error),
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NoteEditorMediaOverlayBtn(
                      icon: Icons.edit_rounded,
                      onTap: onEditDrawing,
                    ),
                    const SizedBox(width: 4),
                    _NoteEditorMediaOverlayBtn(
                      icon: Icons.close_rounded,
                      onTap: onDelete,
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

class _NoteEditorMediaOverlayBtn extends StatelessWidget {
  const _NoteEditorMediaOverlayBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _NoteRichTextController extends TextEditingController {
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

TextStyle _styleForMarks(TextStyle base, NoteInlineMarks marks) {
  final decorations = <TextDecoration>[];
  if (marks.underline || marks.link != null) {
    decorations.add(TextDecoration.underline);
  }
  if (marks.strike) decorations.add(TextDecoration.lineThrough);
  return base.copyWith(
    fontWeight: marks.bold ? FontWeight.w700 : null,
    fontStyle: marks.italic ? FontStyle.italic : null,
    fontFamily: marks.inlineCode ? 'monospace' : base.fontFamily,
    color: marks.link != null
        ? const Color(0xFF4F46E5)
        : _parseHexColor(marks.textColor) ?? base.color,
    backgroundColor: _parseHexColor(marks.highlightColor),
    decoration: decorations.isEmpty
        ? base.decoration
        : TextDecoration.combine(decorations),
  );
}

bool _noteRunsEquivalent(List<NoteTextRun> a, List<NoteTextRun> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index].text != b[index].text ||
        a[index].marks.toJson().toString() !=
            b[index].marks.toJson().toString()) {
      return false;
    }
  }
  return true;
}

List<NoteTextRun> _mergeRuns(List<NoteTextRun> source) {
  final result = <NoteTextRun>[];
  for (final run in source.where((item) => item.text.isNotEmpty)) {
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
  return result;
}

Uint8List? _bytesFromDataUrl(String? dataUrl) {
  if (dataUrl == null) return null;
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Add Text / Checklist / Heading / Image / Drawing row under the block list.
class NoteEditorAddBlockRow extends StatelessWidget {
  const NoteEditorAddBlockRow({
    super.key,
    required this.loc,
    required this.onAdd,
    required this.onImage,
    required this.onDraw,
  });

  final String loc;
  final void Function(NoteBlockType) onAdd;
  final VoidCallback onImage;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _NoteEditorAddButton(
          icon: Icons.add_rounded,
          label: t(loc, 'notes_v3_editor_add_text'),
          onTap: () => onAdd(NoteBlockType.paragraph),
        ),
        _NoteEditorAddButton(
          icon: Icons.checklist_rounded,
          label: t(loc, 'notes_v3_editor_add_checklist'),
          onTap: () => onAdd(NoteBlockType.checklist),
        ),
        _NoteEditorAddButton(
          icon: Icons.title_rounded,
          label: t(loc, 'notes_v3_editor_add_heading'),
          onTap: () => onAdd(NoteBlockType.heading),
        ),
        _NoteEditorAddButton(
          icon: Icons.image_outlined,
          label: t(loc, 'notes_v3_editor_add_image'),
          onTap: onImage,
        ),
        _NoteEditorAddButton(
          icon: Icons.draw_outlined,
          label: t(loc, 'notes_v3_editor_add_draw'),
          onTap: onDraw,
        ),
      ],
    );
  }
}

class _NoteEditorAddButton extends StatelessWidget {
  const _NoteEditorAddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = kGlmPillTextColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: notesGlmGlassPillDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
