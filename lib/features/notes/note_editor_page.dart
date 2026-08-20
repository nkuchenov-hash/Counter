// Full-screen structured Notes editor.
//
// The production surface uses the versioned Life OS note document, stable block
// ids, canonical Notes components, and local-first debounced persistence.

import 'dart:async';
import 'dart:convert';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/drawing_canvas_page.dart';
import 'package:counter/features/notes/notes_audio_controller.dart';
import 'package:counter/features/notes/notes_editor_document_controller.dart';
import 'package:counter/features/notes/widgets/notes_editor_screen.dart';
import 'package:counter/features/notes/notes_image_tools.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// In-process structural companion to the platform plain-text clipboard.
///
/// SelectionArea itself only publishes plain text. We keep the matching Notes
/// blocks in memory and only reuse them when the platform clipboard still
/// contains exactly the text produced by that selection. External clipboard
/// content therefore remains safe and falls back to normal/plain parsing.
class _NotesStructuredClipboard {
  static String? plainText;
  static List<NoteBlock> blocks = const <NoteBlock>[];
}

Future<void> showNoteEditorPage({
  required BuildContext context,
  required PlanningTask task,
  VoidCallback? onClosed,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => NoteEditorPage(task: task, onClosed: onClosed),
    ),
  );
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    required this.task,
    this.onClosed,
    this.parityPreview = false,
  });

  final PlanningTask task;
  final VoidCallback? onClosed;
  final bool parityPreview;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late PlanningTask _task;
  late NoteDocument _sourceDocument;
  late final NotesEditorDocumentController _editor;
  late final TextEditingController _titleController;
  late final EditSheetAutosaveGate _gate;

  final Map<String, NotesTextEditingController> _textControllers = {};
  final Map<String, TextEditingController> _captionControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, TextSelection> _lastSelections = {};
  late final NotesAudioPlaybackController _audioPlayback;
  final Set<String> _transcribingAudioIds = <String>{};
  String? _editingBlockId;
  bool _blockSelectionMode = false;
  final Set<String> _selectedBlockIds = <String>{};
  final ScrollController _blockScrollController = ScrollController();
  final Map<String, GlobalKey> _blockItemKeys = <String, GlobalKey>{};
  bool _dirty = false;
  bool _notesEditorSessionRegistered = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _sourceDocument = DatabaseService.instance.parseNoteDocument(_task);
    _editor = NotesEditorDocumentController(_sourceDocument);
    _titleController = TextEditingController(text: _task.title);
    _gate = EditSheetAutosaveGate();
    _audioPlayback = NotesAudioPlaybackController()
      ..addListener(_onAudioPlaybackChanged);
    if (!widget.parityPreview) {
      DatabaseService.instance.beginNotesEditorSession();
      _notesEditorSessionRegistered = true;
    }
    _syncEditorsWithDocument();

    if (_editor.activeBlockId != null &&
        _sourceDocument.blocks.every(
          (block) => !NotesEditorDocumentController.isSupportedProductionBlock(
            block.type,
          ),
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestFocus(
          _editor.activeBlockId!,
          const TextSelection.collapsed(offset: 0),
        );
      });
    }
  }

  @override
  void dispose() {
    if (_dirty && !widget.parityPreview) {
      _gate.flush(_syncToBrain, force: true);
    }
    _gate.dispose();
    _blockScrollController.dispose();
    _audioPlayback
      ..removeListener(_onAudioPlaybackChanged)
      ..dispose();
    _titleController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final controller in _captionControllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    if (_notesEditorSessionRegistered) {
      DatabaseService.instance.endNotesEditorSession();
      _notesEditorSessionRegistered = false;
    }
    widget.onClosed?.call();
    super.dispose();
  }

  void _onAudioPlaybackChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleSave([String? _]) {
    _dirty = true;
    _gate.schedule(_syncToBrain);
  }

  void _syncToBrain() {
    if (!_dirty || widget.parityPreview) return;
    final title = _titleController.text.trim();
    final document = _editor.document;
    DatabaseService.instance.applyNoteEdit(
      planRowIdForBackend: _task.planRowIdForBackend,
      doc: document,
      title: title,
      categoryId: _task.categoryId,
      tags: _task.tags,
      isDone: _task.isDone,
    );
    _sourceDocument = document;
    _task = _task.copyWith(
      title: title,
      notesDeltaJson: document.encode(),
      updatedAt: DateTime.now(),
    );
    _dirty = false;
  }

  void _close() {
    if (_dirty && !widget.parityPreview) {
      _gate.flush(_syncToBrain, force: true);
    }
    Navigator.of(context).pop();
  }

  NotesTextEditingController _textControllerFor(NoteBlock block) {
    return _textControllers.putIfAbsent(block.id, () {
      final controller = NotesTextEditingController(
        text: block.effectiveText,
        runs: block.effectiveRuns,
      );
      _lastSelections[block.id] = controller.selection;
      controller.addListener(() {
        final previous = _lastSelections[block.id];
        final next = controller.selection;
        if (previous == next) return;
        _lastSelections[block.id] = next;
        _editor.updateSelection(block.id, next);
        if (!mounted || _editor.activeBlockId != block.id) return;
        if (previous?.isCollapsed != next.isCollapsed) setState(() {});
      });
      return controller;
    });
  }

  TextEditingController _captionControllerFor(NoteBlock block) {
    return _captionControllers.putIfAbsent(
      block.id,
      () => TextEditingController(text: block.caption ?? ''),
    );
  }

  FocusNode? _focusNodeFor(NoteBlock block) {
    if (block.type == NoteBlockType.quote) return null;
    return _focusNodes.putIfAbsent(block.id, () {
      final node = FocusNode(debugLabel: 'notes-block-${block.id}');
      node.addListener(() {
        if (!mounted) return;
        if (node.hasFocus) {
if (_blockSelectionMode) {
  node.unfocus();
  return;
}
          final selection = _textControllers[block.id]?.selection;
          final activeChanged = _editor.selectBlock(block.id, selection);
          if (_editingBlockId != block.id || activeChanged) {
            setState(() => _editingBlockId = block.id);
          }
          return;
        }
        if (_editingBlockId == block.id) {
          setState(() => _editingBlockId = null);
        }
      });
      return node;
    });
  }

  void _syncEditorsWithDocument() {
    final visibleIds = <String>{};
    final textIds = <String>{};
    final captionIds = <String>{};
    final focusIds = <String>{};
    for (final block in _editor.visibleBlocks) {
      visibleIds.add(block.id);
      if (NotesEditorDocumentController.isEditableText(block.type)) {
        textIds.add(block.id);
        final controller = _textControllerFor(block);
        if (controller.text != block.effectiveText ||
            !_sameRuns(controller.runs, block.effectiveRuns)) {
          controller.syncDocument(
            text: block.effectiveText,
            runs: block.effectiveRuns,
            selection: controller.selection,
          );
        }
        if (block.type != NoteBlockType.quote) {
          focusIds.add(block.id);
          _focusNodeFor(block);
        }
      }
      if (block.type == NoteBlockType.image ||
          block.type == NoteBlockType.drawing) {
        captionIds.add(block.id);
        final controller = _captionControllerFor(block);
        final caption = block.caption ?? '';
        if (controller.text != caption) {
          controller.value = TextEditingValue(
            text: caption,
            selection: TextSelection.collapsed(
              offset: controller.selection.extentOffset
                  .clamp(0, caption.length)
                  .toInt(),
            ),
          );
        }
      }
    }
    _blockItemKeys.removeWhere((id, _) => !visibleIds.contains(id));
    _disposeRemoved(_textControllers, textIds);
    _disposeRemoved(_captionControllers, captionIds);
    _disposeRemoved(_focusNodes, focusIds);
    _lastSelections.removeWhere((id, _) => !textIds.contains(id));
    if (_editingBlockId != null && !textIds.contains(_editingBlockId)) {
      _editingBlockId = null;
    }
  }

  void _disposeRemoved<T extends ChangeNotifier>(
    Map<String, T> values,
    Set<String> retainedIds,
  ) {
    final removed = values.keys
        .where((id) => !retainedIds.contains(id))
        .toList(growable: false);
    for (final id in removed) {
      values.remove(id)?.dispose();
    }
  }

  void _applyMutation(NotesEditorMutation mutation) {
    if (!mutation.changed) return;
    _scheduleSave();
    if (mutation.requiresRebuild) setState(_syncEditorsWithDocument);
    if (mutation.focusBlockId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestFocus(
          mutation.focusBlockId!,
          mutation.selection ?? const TextSelection.collapsed(offset: 0),
        );
      });
    }
  }

  void _requestFocus(String blockId, TextSelection selection) {
    if (_blockSelectionMode) return;
    final block = _editor.blockById(blockId);
    if (block == null ||
        !NotesEditorDocumentController.isEditableText(block.type)) {
      return;
    }
    final controller = _textControllerFor(block);
    controller.selection = TextSelection(
      baseOffset: selection.baseOffset.clamp(0, controller.text.length).toInt(),
      extentOffset: selection.extentOffset
          .clamp(0, controller.text.length)
          .toInt(),
    );
    final changedActive = _editor.selectBlock(blockId, controller.selection);
    if (block.type == NoteBlockType.quote) {
      if (mounted && (_editingBlockId != blockId || changedActive)) {
        setState(() => _editingBlockId = blockId);
      }
      return;
    }

    final node = _focusNodeFor(block);
    if (_editingBlockId != blockId) {
      if (mounted) setState(() => _editingBlockId = blockId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        node?.requestFocus();
      });
      return;
    }
    node?.requestFocus();
    if (changedActive && mounted) setState(() {});
  }

  void _onBlockTextChanged(NoteBlock block, String value) {
    final controller = _textControllerFor(block);
    final mutation = _editor.applyTextInput(
      block.id,
      value,
      controller.selection,
    );
    if (mutation.changed && !mutation.requiresRebuild) {
      final updated = _editor.blockById(block.id);
      if (updated != null) controller.setRuns(updated.effectiveRuns);
    }
    _applyMutation(mutation);
  }

  String _normalizeClipboardStructure(String value) {
    final buffer = StringBuffer();
    var pendingSpace = false;
    for (final rune in value.runes) {
      final whitespace = rune == 9 || rune == 10 || rune == 13 || rune == 32;
      if (whitespace) {
        pendingSpace = buffer.isNotEmpty;
        continue;
      }
      if (pendingSpace) {
        buffer.write(' ');
        pendingSpace = false;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString().trim();
  }

  String _normalizeClipboardMeaning(String value) {
    final normalizedLines = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) {
var cleaned = line.trimLeft();
cleaned = cleaned.replaceFirst(
  RegExp(r'^(?:[-*•]\s+|\d+[.)]\s+|\[(?: |x|X)\]\s+|[☐☑✓✔]\s*)'),
  '',
);
return cleaned;
        })
        .join('\n');
    return _normalizeClipboardStructure(normalizedLines);
  }

  bool _structuredClipboardMatchesSystemText(String plain) {
    final candidate = _NotesStructuredClipboard.plainText;
    final blocks = _NotesStructuredClipboard.blocks;
    if (candidate == null || blocks.isEmpty) return false;

    final normalizedPlain = _normalizeClipboardStructure(plain);
    if (_normalizeClipboardStructure(candidate) == normalizedPlain) return true;

    final blockPlain = blocks.map((block) => block.effectiveText).join('\n');
    if (_normalizeClipboardStructure(blockPlain) == normalizedPlain) return true;

    final meaning = _normalizeClipboardMeaning(plain);
    return _normalizeClipboardMeaning(candidate) == meaning ||
        _normalizeClipboardMeaning(blockPlain) == meaning;
  }

  Future<void> _pasteClipboardIntoBlock(
    NoteBlock block,
    TextSelection selection,
  ) async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final plain = data?.text ?? '';
    if (plain.isEmpty) return;

    final hasMatchingStructure =
        _structuredClipboardMatchesSystemText(plain);

    final mutation = hasMatchingStructure
        ? _editor.pasteBlocks(
  block.id,
  selection,
  _NotesStructuredClipboard.blocks,
)
        : _editor.pastePlainText(block.id, selection, plain);
    if (!mutation.changed) return;

    if (!mutation.requiresRebuild) {
      final updated = _editor.blockById(block.id);
      if (updated != null) {
        final controller = _textControllerFor(updated);
        controller.syncDocument(
          text: updated.effectiveText,
          runs: updated.effectiveRuns,
          selection:
              _editor.activeSelection ??
              TextSelection.collapsed(offset: updated.effectiveText.length),
        );
      }
    }
    _applyMutation(mutation);
  }

  KeyEventResult _onBlockKeyEvent(NoteBlock block, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = _textControllerFor(block);
    final selection = controller.selection;
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyC &&
        (keyboard.isControlPressed || keyboard.isMetaPressed) &&
        selection.isValid &&
        !selection.isCollapsed) {
      final slice = _editor.structuralSliceForSelection(block.id, selection);
      if (slice != null) {
        final start = selection.start.clamp(0, controller.text.length).toInt();
        final end = selection.end.clamp(0, controller.text.length).toInt();
        final plain = controller.text.substring(start, end);
        _NotesStructuredClipboard.plainText = plain;
        _NotesStructuredClipboard.blocks = <NoteBlock>[slice];
        unawaited(Clipboard.setData(ClipboardData(text: plain)));
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      unawaited(_pasteClipboardIntoBlock(block, selection));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final mutation = _editor.handleEnter(block.id, selection);
      if (!mutation.changed) return KeyEventResult.ignored;
      _applyMutation(mutation);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.extentOffset == 0) {
      final mutation = _editor.handleBackspaceAtStart(block.id);
      if (!mutation.changed) return KeyEventResult.ignored;
      _applyMutation(mutation);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// SelectionArea exposes plain text only. Flutter concatenates selected child
  /// contents without inventing a delimiter, so locate that exact substring in
  /// contiguous Notes text blocks and retain the matching block slices.
  void _captureStructuredSelection(SelectedContent? selected) {
    final plain = selected?.plainText ?? '';
    if (plain.isEmpty) return;
    final blocks = _inferStructuredSelectionBlocks(plain);
    if (blocks.isEmpty) return;
    _NotesStructuredClipboard.plainText = plain;
    _NotesStructuredClipboard.blocks = List<NoteBlock>.unmodifiable(blocks);
  }

  List<NoteBlock> _inferStructuredSelectionBlocks(String plain) {
    if (plain.isEmpty) return const <NoteBlock>[];
    final textBlocks = <NoteBlock>[
      for (final block in _editor.visibleBlocks)
        if (NotesEditorDocumentController.isEditableText(block.type) &&
            block.effectiveText.isNotEmpty)
          block,
    ];
    if (textBlocks.isEmpty) return const <NoteBlock>[];

    final normalizedSelection = _normalizeClipboardStructure(plain);
    List<NoteBlock>? wholeBlockBest;
    for (var start = 0; start < textBlocks.length; start++) {
      for (var end = start; end < textBlocks.length; end++) {
        final window = textBlocks.sublist(start, end + 1);
        final candidate = _normalizeClipboardStructure(
window.map((block) => block.effectiveText).join('\n'),
        );
        if (candidate != normalizedSelection) continue;
        final preservesMeaning =
  window.length > 1 || window.single.type != NoteBlockType.paragraph;
        if (!preservesMeaning) continue;
        if (wholeBlockBest == null || window.length < wholeBlockBest.length) {
wholeBlockBest = List<NoteBlock>.from(window);
        }
      }
    }
    if (wholeBlockBest != null) return wholeBlockBest;

    List<NoteBlock>? best;
    var bestWindow = 1 << 30;
    for (var startIndex = 0; startIndex < textBlocks.length; startIndex++) {
      final buffer = StringBuffer();
      final offsets = <int>[0];
      for (
        var endIndex = startIndex;
        endIndex < textBlocks.length;
        endIndex++
      ) {
        buffer.write(textBlocks[endIndex].effectiveText);
        offsets.add(buffer.length);
        if (buffer.length < plain.length) continue;

        final joined = buffer.toString();
        var searchFrom = 0;
        while (searchFrom <= joined.length - plain.length) {
          final foundAt = joined.indexOf(plain, searchFrom);
          if (foundAt < 0) break;
          final selectedEnd = foundAt + plain.length;
          final slices = <NoteBlock>[];
          for (
            var localIndex = 0;
            localIndex <= endIndex - startIndex;
            localIndex++
          ) {
            final source = textBlocks[startIndex + localIndex];
            final blockStart = offsets[localIndex];
            final blockEnd = offsets[localIndex + 1];
            final overlapStart = foundAt > blockStart ? foundAt : blockStart;
            final overlapEnd = selectedEnd < blockEnd ? selectedEnd : blockEnd;
            if (overlapStart >= overlapEnd) continue;
            final localStart = overlapStart - blockStart;
            final localEnd = overlapEnd - blockStart;
            if (localStart == 0 && localEnd == source.effectiveText.length) {
              slices.add(source);
            } else {
              slices.add(
                source.copyWith(
                  text: source.effectiveText.substring(localStart, localEnd),
                  runs: const <NoteTextRun>[],
                ),
              );
            }
          }

          // A single selected text fragment should behave like normal clipboard
          // text. Structure matters once selection crosses a block boundary.
          if (slices.length >= 2) {
            final window = endIndex - startIndex + 1;
            if (window < bestWindow) {
              best = slices;
              bestWindow = window;
            }
          }
          searchFrom = foundAt + 1;
        }
        if (bestWindow == 2) break;
      }
      if (bestWindow == 2) break;
    }
    return best ?? const <NoteBlock>[];
  }

  double? _captureBlockScrollOffset() {
    if (!_blockScrollController.hasClients) return null;
    return _blockScrollController.offset;
  }

  void _restoreBlockScrollOffset(double? offset) {
    if (offset == null) return;
    void restore() {
      if (!mounted || !_blockScrollController.hasClients) return;
      final position = _blockScrollController.position;
      _blockScrollController.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      restore();
      WidgetsBinding.instance.addPostFrameCallback((_) => restore());
    });
  }

  void _toggleBlockSelection(String blockId) {
    if (_editor.blockById(blockId) == null) return;
    final scrollOffset = _captureBlockScrollOffset();
    if (!_blockSelectionMode) {
      FocusManager.instance.primaryFocus?.unfocus();
      for (final node in _focusNodes.values) {
        if (node.hasFocus) node.unfocus();
      }
      _editor.activeSelection = null;
    }
    setState(() {
      _editingBlockId = null;
      _blockSelectionMode = true;
      if (!_selectedBlockIds.add(blockId)) {
        _selectedBlockIds.remove(blockId);
      }
      if (_selectedBlockIds.isEmpty) _blockSelectionMode = false;
    });
    _restoreBlockScrollOffset(scrollOffset);
  }

  void _exitBlockSelectionMode() {
    if (!_blockSelectionMode && _selectedBlockIds.isEmpty) return;
    final scrollOffset = _captureBlockScrollOffset();
    FocusManager.instance.primaryFocus?.unfocus();
    for (final node in _focusNodes.values) {
      if (node.hasFocus) node.unfocus();
    }
    _editor.activeSelection = null;
    setState(() {
      _editingBlockId = null;
      _selectedBlockIds.clear();
      _blockSelectionMode = false;
    });
    _restoreBlockScrollOffset(scrollOffset);
  }

  void _handleBlockTap(String blockId) {
    if (_blockSelectionMode) {
      _toggleBlockSelection(blockId);
      return;
    }
    _selectBlock(blockId);
  }

  void _deleteBlockFromMenu(String blockId) {
    if (_selectedBlockIds.contains(blockId)) {
      setState(() {
        _selectedBlockIds.remove(blockId);
        if (_selectedBlockIds.isEmpty) _blockSelectionMode = false;
      });
    }
    _applyMutation(_editor.deleteBlock(blockId));
  }

  void _showBlockActionMenu(Offset anchorCenter, NoteBlock block) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    void dismiss() => entry.remove();
    entry = OverlayEntry(
      builder: (overlayContext) => _NotesBlockCircularMenuOverlay(
        anchorCenter: anchorCenter,
        selected: _selectedBlockIds.contains(block.id),
        onDismiss: dismiss,
        onSelect: () {
dismiss();
_toggleBlockSelection(block.id);
        },
        onDelete: () {
dismiss();
_deleteBlockFromMenu(block.id);
        },
      ),
    );
    overlay.insert(entry);
  }

  void _selectBlock(String blockId) {
    final block = _editor.blockById(blockId);
    if (block == null) return;
    final controller = NotesEditorDocumentController.isEditableText(block.type)
        ? _textControllerFor(block)
        : null;
    final selection = controller?.selection;
    final safeSelection = selection != null && selection.isValid
        ? selection
        : TextSelection.collapsed(offset: controller?.text.length ?? 0);
    final changed = _editor.selectBlock(blockId, selection);
    if (NotesEditorDocumentController.isEditableText(block.type)) {
      if (mounted) {
        setState(() => _editingBlockId = block.id);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestFocus(block.id, safeSelection);
      });
    } else if (changed && mounted) {
      setState(() {});
    }
  }

  void _convertActive(NotesBlockConversion conversion) {
    if (_selectedBlockIds.isNotEmpty) {
      _applyMutation(_editor.convertBlocks(_selectedBlockIds, conversion));
      return;
    }
    final id = _editor.activeBlockId;
    if (id != null) _applyMutation(_editor.convertBlock(id, conversion));
  }

  void _insertAfter(
    String? anchorId,
    NoteBlockType type, {
    int level = 2,
    NoteTableData? table,
  }) {
    _applyMutation(
      _editor.insertAfter(anchorId, type, level: level, table: table),
    );
  }

  NotesTextBlockStyle? _activeHeadingStyle() {
    final block = _editor.activeBlock;
    if (block?.type == NoteBlockType.paragraph) {
      return NotesTextBlockStyle.body;
    }
    if (block?.type != NoteBlockType.heading) return null;
    if (block!.level == 1) return NotesTextBlockStyle.h1;
    if (block.level == 3) return NotesTextBlockStyle.h3;
    return NotesTextBlockStyle.h2;
  }

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

  Future<void> _editLink(String blockId, TextSelection selection) async {
    final result = await showNotesLinkDialog(
      context: context,
      currentUrl: _editor.linkForSelection(blockId, selection),
    );
    if (!mounted || result == null) return;
    _applyInlineFormat(
      blockId,
      selection,
      NotesInlineFormat.link,
      link: result.url,
    );
  }

  void _applyInlineFormat(
    String blockId,
    TextSelection selection,
    NotesInlineFormat format, {
    String? link,
  }) {
    final mutation = _editor.applyInlineFormat(
      blockId,
      selection,
      format,
      link: link,
    );
    if (!mutation.changed) return;
    final updated = _editor.blockById(blockId);
    if (updated != null) {
      _textControllerFor(updated).setRuns(updated.effectiveRuns);
    }
    _scheduleSave();
    setState(() {});
  }

  void _focusOrInsertParagraphAfter(String blockId) {
    final visible = _editor.visibleBlocks;
    final index = visible.indexWhere((block) => block.id == blockId);
    if (index < 0) return;
    if (index + 1 < visible.length) {
      final next = visible[index + 1];
      if (NotesEditorDocumentController.isEditableText(next.type)) {
        _requestFocus(next.id, const TextSelection.collapsed(offset: 0));
        return;
      }
    }
    _applyMutation(_editor.insertAfter(blockId, NoteBlockType.paragraph));
  }

  void _applyInsertedNonTextWithTrailingParagraph(
    NotesEditorMutation mutation,
  ) {
    if (!mutation.changed) return;
    final insertedId = _editor.activeBlockId;
    _applyMutation(mutation);
    if (insertedId != null) _focusOrInsertParagraphAfter(insertedId);
  }

  GlobalKey _blockItemKeyFor(String blockId) {
    return _blockItemKeys.putIfAbsent(
      blockId,
      () => GlobalKey(debugLabel: 'notes-editor-block-$blockId'),
    );
  }

  Rect? _blockGlobalRect(String blockId) {
    final blockContext = _blockItemKeys[blockId]?.currentContext;
    final render = blockContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    return render.localToGlobal(Offset.zero) & render.size;
  }

  void _clearActiveBlock() {
    if (_blockSelectionMode) return;
    FocusManager.instance.primaryFocus?.unfocus();
    for (final node in _focusNodes.values) {
      if (node.hasFocus) node.unfocus();
    }
    final changed = _editor.activeBlockId != null || _editingBlockId != null;
    _editor.activeBlockId = null;
    _editor.activeSelection = null;
    if (changed && mounted) setState(() => _editingBlockId = null);
  }

  void _handleEditorBackgroundPointer(PointerDownEvent event) {
    if (_blockSelectionMode) return;
    NoteBlock? preceding;
    var nearestBottom = double.negativeInfinity;
    for (final block in _editor.visibleBlocks) {
      final rect = _blockGlobalRect(block.id);
      if (rect == null) continue;
      if (rect.contains(event.position)) return;
      if (rect.bottom <= event.position.dy && rect.bottom > nearestBottom) {
        nearestBottom = rect.bottom;
        preceding = block;
      }
    }
    if (preceding != null &&
        !NotesEditorDocumentController.isEditableText(preceding.type)) {
      _focusOrInsertParagraphAfter(preceding.id);
      return;
    }
    _clearActiveBlock();
  }

  Future<void> _showTablePicker({String? anchorId}) {
    return showNotesTablePicker(
      context: context,
      onSelected: (table) {
        _applyInsertedNonTextWithTrailingParagraph(
_editor.insertAfter(
  anchorId ?? _editor.activeBlockId,
  NoteBlockType.table,
  table: table,
),
        );
      },
    );
  }

  Future<void> _showInsertMenu(String anchorId) {
    return showNotesInsertMenu(
      context: context,
      onHeading: () => _insertAfter(anchorId, NoteBlockType.heading, level: 1),
      onText: () => _insertAfter(anchorId, NoteBlockType.paragraph),
      onQuote: () => _insertAfter(anchorId, NoteBlockType.quote),
      onBulletedList: () => _insertAfter(anchorId, NoteBlockType.bulletedList),
      onNumberedList: () => _insertAfter(anchorId, NoteBlockType.numberedList),
      onChecklist: () => _insertAfter(anchorId, NoteBlockType.checklist),
      onTable: () => _showTablePicker(anchorId: anchorId),
      onDivider: () => _applyInsertedNonTextWithTrailingParagraph(
        _editor.insertAfter(anchorId, NoteBlockType.divider),
      ),
      onDrawing: widget.parityPreview ? null : () => _openDrawing(),
      onImage: widget.parityPreview ? null : () => _pickImage(),
      onAudio: widget.parityPreview ? null : _recordAudio,
    );
  }

  Future<void> _pickImage({String? replaceBlockId}) async {
    if (widget.parityPreview) return;
    try {
      final picked = await pickNotesImage(context: context);
      if (!mounted || picked == null) return;
      if (replaceBlockId == null) {
        _applyInsertedNonTextWithTrailingParagraph(
_editor.insertAfter(
  _editor.activeBlockId,
  NoteBlockType.image,
  imageData: picked.dataUrl,
),
        );
      } else {
        _applyMutation(
_editor.updateMedia(replaceBlockId, imageData: picked.dataUrl),
        );
      }
    } on NotesImageTooLargeException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(currentLocale.value, 'notes_v3_editor_image_too_large'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_v3_editor_load_failed')),
        ),
      );
    }
  }

  Future<void> _cropImage(String blockId) async {
    final dataUrl = _editor.blockById(blockId)?.imageData;
    if (dataUrl == null || dataUrl.isEmpty) return;
    final cropped = await showNotesImageCropper(
      context: context,
      dataUrl: dataUrl,
    );
    if (!mounted || cropped == null) return;
    _applyMutation(_editor.updateMedia(blockId, imageData: cropped));
  }

  Future<void> _editImageCaption(String blockId) async {
    final block = _editor.blockById(blockId);
    if (block == null || block.type != NoteBlockType.image) return;
    final result = await showNotesImageCaptionDialog(
      context: context,
      currentCaption: block.caption,
    );
    if (!mounted || result == null) return;
    _applyMutation(_editor.updateCaption(blockId, result.caption ?? ''));
  }

  Future<void> _copyImage(String blockId) async {
    final dataUrl = _editor.blockById(blockId)?.imageData;
    if (dataUrl == null || dataUrl.isEmpty) return;
    try {
      await copyNotesImage(dataUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'notes_image_copied'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_image_copy_failed')),
        ),
      );
    }
  }

  Future<void> _saveImage(String blockId) async {
    final dataUrl = _editor.blockById(blockId)?.imageData;
    if (dataUrl == null || dataUrl.isEmpty) return;
    try {
      await saveNotesImage(dataUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'notes_image_saved'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_image_save_failed')),
        ),
      );
    }
  }

  Future<void> _openDrawing({String? editBlockId}) {
    final initial = editBlockId == null
        ? null
        : _editor.blockById(editBlockId)?.drawingData;
    return showDrawingCanvas(
      context: context,
      initialData: initial,
      onSave: (dataUrl) {
        if (!mounted) return;
        if (editBlockId != null) {
_applyMutation(
  _editor.updateMedia(editBlockId, drawingData: dataUrl),
);
return;
        }
        _applyInsertedNonTextWithTrailingParagraph(
_editor.insertAfter(
  _editor.activeBlockId,
  NoteBlockType.drawing,
  drawingData: dataUrl,
),
        );
      },
    );
  }

  Future<void> _recordAudio() async {
    if (widget.parityPreview) return;
    final audio = await showNotesAudioRecorder(context: context);
    if (!mounted || audio == null) return;
    final mutation = _editor.insertAfter(
      _editor.activeBlockId,
      NoteBlockType.audio,
      audio: audio,
    );
    final blockId = _editor.activeBlockId;
    _applyInsertedNonTextWithTrailingParagraph(mutation);
    if (blockId != null) unawaited(_transcribeAudio(blockId));
  }

  Future<void> _toggleAudio(String blockId) async {
    final audio = _editor.blockById(blockId)?.audio;
    if (audio == null) return;
    try {
      await _audioPlayback.toggle(blockId, audio);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(currentLocale.value, 'notes_audio_play_failed')),
        ),
      );
    }
  }

  NotesAudioState _audioState(String blockId) {
    if (_transcribingAudioIds.contains(blockId)) {
      return NotesAudioState.transcribing;
    }
    if (_audioPlayback.isPlaying(blockId)) return NotesAudioState.playing;
    final audio = _editor.blockById(blockId)?.audio;
    if (audio?.transcriptStatus == NoteAudioTranscriptStatus.error) {
      return NotesAudioState.transcriptError;
    }
    return NotesAudioState.ready;
  }

  Future<void> _transcribeAudio(String blockId) async {
    final audio = _editor.blockById(blockId)?.audio;
    if (audio == null || _transcribingAudioIds.contains(blockId)) return;
    setState(() => _transcribingAudioIds.add(blockId));
    try {
      final transcript = await DatabaseService.instance.transcribeNoteAudio(
        audio,
      );
      if (!mounted) return;
      _applyMutation(
        _editor.updateAudio(
          blockId,
          audio.copyWith(
            transcript: transcript,
            transcriptStatus: NoteAudioTranscriptStatus.ready,
            transcriptError: null,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _applyMutation(
        _editor.updateAudio(
          blockId,
          audio.copyWith(
            transcriptStatus: NoteAudioTranscriptStatus.error,
            transcriptError: error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _transcribingAudioIds.remove(blockId));
    }
  }

  Future<void> _openAudioTranscript(String blockId) async {
    final audio = _editor.blockById(blockId)?.audio;
    if (audio == null) return;
    await showNotesTranscriptDialog(
      context: context,
      audio: audio,
      playbackState: _audioState(blockId),
      onPlayPause: () => _toggleAudio(blockId),
      onRetry: () {
        Navigator.of(context).pop();
        _transcribeAudio(blockId);
      },
    );
  }

  Future<void> _showActiveBlockOptions() {
    final block = _editor.activeBlock;
    if (block == null) return Future<void>.value();
    return showNotesBlockOptionsMenu(
      context: context,
      block: block,
      onDeleteBlock: () => _applyMutation(_editor.deleteBlock(block.id)),
      onTableCommand: block.type == NoteBlockType.table
          ? (command) => _applyMutation(
              _editor.editTable(block.id, command, row: 0, column: 0),
            )
          : null,
      onEditMedia: switch (block.type) {
        NoteBlockType.image => () => _pickImage(replaceBlockId: block.id),
        NoteBlockType.drawing => () => _openDrawing(editBlockId: block.id),
        _ => null,
      },
      onCropImage: block.type == NoteBlockType.image
          ? () => _cropImage(block.id)
          : null,
      onEditImageCaption: block.type == NoteBlockType.image
          ? () => _editImageCaption(block.id)
          : null,
      onCopyImage: block.type == NoteBlockType.image
          ? () => _copyImage(block.id)
          : null,
      onSaveImage: block.type == NoteBlockType.image
          ? () => _saveImage(block.id)
          : null,
    );
  }

  int _numberedOrdinal(int index) {
    var ordinal = 1;
    for (var cursor = index - 1; cursor >= 0; cursor--) {
      if (_editor.visibleBlocks[cursor].type != NoteBlockType.numberedList)
        break;
      ordinal++;
    }
    return ordinal;
  }

  Widget? _desktopDrawingPreview(BuildContext context, NoteBlock block) {
    if (block.type != NoteBlockType.drawing ||
        MediaQuery.sizeOf(context).width < 768) {
      return null;
    }
    final raw = block.drawingData?.trim() ?? '';
    if (raw.isEmpty) return null;
    final comma = raw.indexOf(',');
    final encoded = raw.startsWith('data:') && comma >= 0
        ? raw.substring(comma + 1)
        : raw;
    try {
      final bytes = base64Decode(encoded);
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          kNotesContentInset,
          0,
          kNotesContentInset,
          kNotesBlockVerticalPadding,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleBlockTap(block.id),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 280,
                child: Image.memory(
                  bytes,
                  width: double.infinity,
                  height: 280,
                  alignment: Alignment.topCenter,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } on FormatException {
      return null;
    }
  }

  Widget _buildBlock(BuildContext context, int index) {
    final block = _editor.visibleBlocks[index];
    final editable = NotesEditorDocumentController.isEditableText(block.type);
    final focusNode = editable ? _focusNodeFor(block) : null;
    final active = !_blockSelectionMode && _editor.activeBlockId == block.id;
    Widget item = NotesEditorBlockItem(
      block: block,
      index: index,
      numberedOrdinal: _numberedOrdinal(index),
      active: active,
      editing: editable && !_blockSelectionMode && _editingBlockId == block.id,
      textController: editable ? _textControllerFor(block) : null,
      focusNode: focusNode,
      captionController:
block.type == NoteBlockType.image ||
    block.type == NoteBlockType.drawing
? _captionControllerFor(block)
: null,
      onTap: () => _handleBlockTap(block.id),
      onKeyEvent: (event) => _onBlockKeyEvent(block, event),
      onTextChanged: editable
? (value) => _onBlockTextChanged(block, value)
: null,
      onCheckedChanged: block.type == NoteBlockType.checklist
? (checked) =>
      _applyMutation(_editor.toggleChecklist(block.id, checked))
: null,
      onTableChanged: block.type == NoteBlockType.table
? (table) => _applyMutation(_editor.updateTable(block.id, table))
: null,
      onCaptionChanged:
block.type == NoteBlockType.image ||
    block.type == NoteBlockType.drawing
? (caption) =>
      _applyMutation(_editor.updateCaption(block.id, caption))
: null,
      onEmptyLongPress: editable && block.effectiveText.isEmpty
? () => _showInsertMenu(block.id)
: null,
      audioState: block.type == NoteBlockType.audio
? _audioState(block.id)
: NotesAudioState.ready,
      onAudioPlayPause: block.type == NoteBlockType.audio
? () => _toggleAudio(block.id)
: null,
      onOpenTranscript: block.type == NoteBlockType.audio
? () => _openAudioTranscript(block.id)
: null,
    );

    final drawingPreview = _desktopDrawingPreview(context, block);
    if (drawingPreview != null) {
      item = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [item, drawingPreview],
      );
    }

    if (widget.parityPreview) return item;

    // Fixed right action rail: activation and selection never change width,
    // wrapping, or vertical metrics of the block.
    final selectedForBulk = _selectedBlockIds.contains(block.id);
    final content = Padding(
      key: ValueKey<String>(block.id),
      padding: const EdgeInsets.only(right: 36),
      child: item,
    );
    return Stack(
      key: _blockItemKeyFor(block.id),
      clipBehavior: Clip.none,
      children: [
        if (selectedForBulk)
Positioned.fill(
  child: IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  ),
),
        content,
        if (selectedForBulk)
Positioned(
  left: -24,
  top: 6,
  child: Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.check_rounded,
      size: 12,
      color: Theme.of(context).colorScheme.onPrimary,
    ),
  ),
),
        if (active)
Positioned(
top: 2,
right: 2,
child: _NotesBlockMoreButton(
  onPressed: (anchorCenter) =>
      _showBlockActionMenu(anchorCenter, block),
),
        ),
      ],
    );
  }

  void _togglePinned() {
    final brain = DatabaseService.instance;
    brain.toggleNotePin(_task.planRowIdForBackend);
    final cached = brain.getCachedPlanningTaskForEdit(
      _task.planRowIdForBackend,
    );
    if (cached != null && mounted) setState(() => _task = cached);
  }

  Future<void> _deleteCurrentNote() async {
    final loc = currentLocale.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t(loc, 'delete')),
        actions: [
AppButton.ghost(
  label: t(loc, 'cancel'),
  size: AppButtonSize.s,
  onPressed: () => Navigator.of(dialogContext).pop(false),
),
AppButton.destructive(
  label: t(loc, 'delete'),
  size: AppButtonSize.s,
  onPressed: () => Navigator.of(dialogContext).pop(true),
),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _gate.flush(() {});
    _dirty = false;
    await DatabaseService.instance.deleteNote(_task.planRowIdForBackend);
    if (!mounted) return;
    final embeddedScope = NotesEmbeddedEditorScope.maybeOf(context);
    if (embeddedScope != null) {
      embeddedScope.onClose();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildReorderableBlockList() {
    return ReorderableListView.builder(
      key: const ValueKey('notes-editor-content'),
      scrollController: _blockScrollController,
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, _, __) => child,
      itemCount: _editor.visibleBlocks.length,
      onReorder: (oldIndex, newIndex) {
        final visible = _editor.visibleBlocks;
        final draggedId = oldIndex >= 0 && oldIndex < visible.length
  ? visible[oldIndex].id
  : null;
        final mutation = draggedId != null &&
      _selectedBlockIds.contains(draggedId)
  ? _editor.reorderVisibleGroup(
      _selectedBlockIds,
      oldIndex,
      newIndex,
    )
  : _editor.reorderVisible(oldIndex, newIndex);
        _applyMutation(mutation);
      },
      itemBuilder: _buildBlock,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final activeType = _editor.activeBlock?.type;
    final category = DatabaseService.instance.getCategoryRuleById(
      _task.categoryId,
    );

    return NotesEditorScreen(
      titleController: _titleController,
      titleHint: t(loc, 'notes_v3_editor_title_hint'),
      onTitleChanged: _scheduleSave,
      onDone: _close,
      pinned: DatabaseService.instance.isNotePinned(_task),
      onTogglePinned: _togglePinned,
      onDelete: _deleteCurrentNote,
      bulkSelectionMode: _blockSelectionMode,
      onExitBulkSelection: _exitBlockSelectionMode,
      categoryLabel: category?.name,
      categoryColor: category?.colorOrDefault,
      tags: [
        for (final tag in _task.tags) NotesEditorMetadataTag(label: tag.name),
      ],
      toolbar: NotesEditorToolbarHost(
        activeBlock: _editor.activeBlock,
        selectionFormats: _selectionFormats(),
        onHeading: _showHeadingMenu,
        onBody: () => _convertActive(NotesBlockConversion.body),
        onFormatting: _showFormattingMenu,
        onQuote: () => _convertActive(NotesBlockConversion.quote),
        onList: () => _convertActive(
activeType == NoteBlockType.bulletedList
    ? NotesBlockConversion.numberedList
    : NotesBlockConversion.bulletedList,
        ),
        onChecklist: () => _convertActive(NotesBlockConversion.checklist),
        onTable: () => _showTablePicker(),
        onDrawing: widget.parityPreview
  ? null
  : () {
      final block = _editor.activeBlock;
      _openDrawing(
        editBlockId: block?.type == NoteBlockType.drawing
            ? block!.id
            : null,
      );
    },
        onAudio: widget.parityPreview ? null : _recordAudio,
        onImage: widget.parityPreview
  ? null
  : () {
      final block = _editor.activeBlock;
      _pickImage(
        replaceBlockId: block?.type == NoteBlockType.image
            ? block!.id
            : null,
      );
    },
        onMore: _showActiveBlockOptions,
      ),
      content: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handleEditorBackgroundPointer,
        child: _blockSelectionMode
  ? _buildReorderableBlockList()
  : SelectionArea(
      onSelectionChanged: _captureStructuredSelection,
      child: _buildReorderableBlockList(),
    ),
      ),
    );
  }
}

class _NotesBlockMoreButton extends StatefulWidget {
  const _NotesBlockMoreButton({required this.onPressed});

  final ValueChanged<Offset> onPressed;

  @override
  State<_NotesBlockMoreButton> createState() => _NotesBlockMoreButtonState();
}

class _NotesBlockMoreButtonState extends State<_NotesBlockMoreButton> {
  final GlobalKey _anchorKey = GlobalKey();

  void _open() {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    widget.onPressed(rect.center);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'More',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
onTap: _open,
borderRadius: BorderRadius.circular(15),
child: SizedBox.square(
  key: _anchorKey,
  dimension: 30,
  child: Icon(
    Icons.more_horiz_rounded,
    size: 18,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
),
        ),
      ),
    );
  }
}

class _NotesBlockCircularMenuOverlay extends StatelessWidget {
  const _NotesBlockCircularMenuOverlay({
    required this.anchorCenter,
    required this.selected,
    required this.onDismiss,
    required this.onSelect,
    required this.onDelete,
  });

  final Offset anchorCenter;
  final bool selected;
  final VoidCallback onDismiss;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  double _left(double centerX, double width) =>
      (centerX - 21).clamp(8.0, width - 50).toDouble();

  double _top(double centerY, double height) =>
      (centerY - 21).clamp(8.0, height - 50).toDouble();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final selectCenter = anchorCenter + const Offset(-48, -42);
    final deleteCenter = anchorCenter + const Offset(-64, 14);
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
Positioned.fill(
  child: GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: onDismiss,
    child: const SizedBox.expand(),
  ),
),
Positioned(
  left: _left(selectCenter.dx, size.width),
  top: _top(selectCenter.dy, size.height),
  child: _NotesBlockRadialAction(
    tooltip: selected ? 'Deselect' : 'Select',
    icon: selected
        ? Icons.remove_done_rounded
        : Icons.check_circle_outline_rounded,
    onPressed: onSelect,
  ),
),
Positioned(
  left: _left(deleteCenter.dx, size.width),
  top: _top(deleteCenter.dy, size.height),
  child: _NotesBlockRadialAction(
    tooltip: 'Delete',
    icon: Icons.delete_outline_rounded,
    destructive: true,
    onPressed: onDelete,
  ),
),
        ],
      ),
    );
  }
}

class _NotesBlockRadialAction extends StatelessWidget {
  const _NotesBlockRadialAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        color: scheme.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
onTap: onPressed,
child: SizedBox.square(
  dimension: 42,
  child: Icon(icon, size: 20, color: foreground),
),
        ),
      ),
    );
  }
}

bool _sameRuns(List<NoteTextRun> left, List<NoteTextRun> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].text != right[index].text ||
        left[index].marks.toJson().toString() !=
            right[index].marks.toJson().toString()) {
      return false;
    }
  }
  return true;
}
