// Full-screen structured Notes editor.
//
// The production surface uses the versioned Life OS note document, stable block
// ids, canonical Notes components, and local-first debounced persistence.

import 'dart:async';
import 'package:counter/core/widgets/notes/notes_context_row.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/drawing_canvas_page.dart';
import 'package:counter/features/notes/notes_audio_controller.dart';
import 'package:counter/features/notes/notes_editor_document_controller.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_image_tools.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _dirty = false;

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
        if (!node.hasFocus || !mounted) return;
        if (_editor.selectBlock(
          block.id,
          _textControllers[block.id]?.selection,
        )) {
          setState(() {});
        }
      });
      return node;
    });
  }

  void _syncEditorsWithDocument() {
    final textIds = <String>{};
    final captionIds = <String>{};
    final focusIds = <String>{};
    for (final block in _editor.visibleBlocks) {
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
    _disposeRemoved(_textControllers, textIds);
    _disposeRemoved(_captionControllers, captionIds);
    _disposeRemoved(_focusNodes, focusIds);
    _lastSelections.removeWhere((id, _) => !textIds.contains(id));
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
    if (block.type != NoteBlockType.quote) {
      _focusNodeFor(block)?.requestFocus();
    }
    if (_editor.selectBlock(blockId, controller.selection) && mounted) {
      setState(() {});
    }
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

  KeyEventResult _onBlockKeyEvent(NoteBlock block, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = _textControllerFor(block);
    final selection = controller.selection;
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

  void _selectBlock(String blockId) {
    if (_editor.selectBlock(blockId, _textControllers[blockId]?.selection)) {
      setState(() {});
    }
  }

  void _convertActive(NotesBlockConversion conversion) {
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

  Future<void> _showTablePicker({String? anchorId}) {
    return showNotesTablePicker(
      context: context,
      onSelected: (table) => _insertAfter(
        anchorId ?? _editor.activeBlockId,
        NoteBlockType.table,
        table: table,
      ),
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
      onDivider: () => _insertAfter(anchorId, NoteBlockType.divider),
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
      final mutation = replaceBlockId == null
          ? _editor.insertAfter(
              _editor.activeBlockId,
              NoteBlockType.image,
              imageData: picked.dataUrl,
            )
          : _editor.updateMedia(replaceBlockId, imageData: picked.dataUrl);
      _applyMutation(mutation);
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
        final mutation = editBlockId == null
            ? _editor.insertAfter(
                _editor.activeBlockId,
                NoteBlockType.drawing,
                drawingData: dataUrl,
              )
            : _editor.updateMedia(editBlockId, drawingData: dataUrl);
        _applyMutation(mutation);
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
    _applyMutation(mutation);
    final blockId = _editor.activeBlockId;
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

  Widget _buildBlock(BuildContext context, int index) {
    final block = _editor.visibleBlocks[index];
    final editable = NotesEditorDocumentController.isEditableText(block.type);
    return NotesEditorBlockItem(
      block: block,
      index: index,
      numberedOrdinal: _numberedOrdinal(index),
      active: _editor.activeBlockId == block.id,
      textController: editable ? _textControllerFor(block) : null,
      focusNode: editable ? _focusNodeFor(block) : null,
      captionController:
          block.type == NoteBlockType.image ||
              block.type == NoteBlockType.drawing
          ? _captionControllerFor(block)
          : null,
      onTap: () => _selectBlock(block.id),
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
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final activeType = _editor.activeBlock?.type;
    final category = DatabaseService.instance.getCategoryRuleById(
      _task.categoryId,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: Align(
        heightFactor: 1,
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kGlmEditorMaxWidth),
          child: NotesEditorToolbarHost(
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
        ),
      ),
      body: NotesGlmBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kGlmEditorMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: kGlmTopBarHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _close,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: Text(t(loc, 'notes_v3_editor_done')),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, kGlmTopBarHeight),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 20,
                      8,
                      wide ? 24 : 20,
                      0,
                    ),
                    child: TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: _scheduleSave,
                      style: TextStyle(
                        fontSize: wide
                            ? kGlmTitleSizeDesktop
                            : kGlmTitleSizeMobile,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: t(loc, 'notes_v3_editor_title_hint'),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  AppNotesContextRow(
                    showStatus: false,
                    data: AppNotesContextRowData(
                      categoryLabel: category?.name,
                      categoryColor: category?.colorOrDefault,
                      tags: [
                        for (final tag in _task.tags)
                          AppNotesContextTag(label: tag.name),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, _, __) => child,
                      itemCount: _editor.visibleBlocks.length,
                      onReorder: (oldIndex, newIndex) => _applyMutation(
                        _editor.reorderVisible(oldIndex, newIndex),
                      ),
                      itemBuilder: _buildBlock,
                    ),
                  ),
                ],
              ),
            ),
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
