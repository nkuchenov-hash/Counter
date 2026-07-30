// Full-screen structured Notes editor.
//
// The production surface uses the versioned Life OS note document, stable block
// ids, canonical Notes components, and local-first debounced persistence.

import 'package:counter/core/widgets/notes/notes_context_row.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
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
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _sourceDocument = DatabaseService.instance.parseNoteDocument(_task);
    _editor = NotesEditorDocumentController(_sourceDocument);
    _titleController = TextEditingController(text: _task.title);
    _gate = EditSheetAutosaveGate();
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
        if (previous?.isCollapsed != next.isCollapsed) {
          setState(() {});
        }
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
    if (mutation.requiresRebuild) {
      setState(_syncEditorsWithDocument);
    }
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
    final current = _editor.linkForSelection(blockId, selection);
    final result = await showNotesLinkDialog(
      context: context,
      currentUrl: current,
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
      onHeading: () =>
          _insertAfter(anchorId, NoteBlockType.heading, level: 1),
      onText: () => _insertAfter(anchorId, NoteBlockType.paragraph),
      onQuote: () => _insertAfter(anchorId, NoteBlockType.quote),
      onBulletedList: () =>
          _insertAfter(anchorId, NoteBlockType.bulletedList),
      onNumberedList: () =>
          _insertAfter(anchorId, NoteBlockType.numberedList),
      onChecklist: () => _insertAfter(anchorId, NoteBlockType.checklist),
      onTable: () => _showTablePicker(anchorId: anchorId),
      onDivider: () => _insertAfter(anchorId, NoteBlockType.divider),
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
    );
  }

  int _numberedOrdinal(int index) {
    var ordinal = 1;
    for (var cursor = index - 1; cursor >= 0; cursor--) {
      if (_editor.visibleBlocks[cursor].type != NoteBlockType.numberedList) break;
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
          block.type == NoteBlockType.image || block.type == NoteBlockType.drawing
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
          block.type == NoteBlockType.image || block.type == NoteBlockType.drawing
          ? (caption) =>
                _applyMutation(_editor.updateCaption(block.id, caption))
          : null,
      onEmptyLongPress: editable && block.effectiveText.isEmpty
          ? () => _showInsertMenu(block.id)
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
            onChecklist: () =>
                _convertActive(NotesBlockConversion.checklist),
            onTable: () => _showTablePicker(),
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
    _document = _document.copyWith(blocks: nextBlocks);

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
    while (previousIndex >= 0 &&
        !isEditableText(blocks[previousIndex].type)) {
      previousIndex--;
    }
    if (previousIndex < 0) return const NotesEditorMutation();

    final previous = blocks[previousIndex];
    final previousLength = previous.effectiveText.length;
    final nextBlocks = List<NoteBlock>.from(blocks)
      ..[previousIndex] = previous.copyWith(
        text: '${previous.effectiveText}${block.effectiveText}',
        runs: _mergeRuns([
          ...previous.effectiveRuns,
          ...block.effectiveRuns,
        ]),
      )
      ..removeAt(index);
    _document = _document.copyWith(blocks: nextBlocks);
    activeBlockId = previous.id;
    activeSelection = TextSelection.collapsed(offset: previousLength);
    return _focusMutation(previous.id, activeSelection!);
  }

  NotesEditorMutation convertBlock(
    String id,
    NotesBlockConversion conversion,
  ) {
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
  }) {
    final anchorIndex = anchorId == null ? -1 : _indexOf(anchorId);
    final block = NoteBlock(
      id: generateNoteBlockId(),
      type: type,
      level: level,
      table: type == NoteBlockType.table ? table ?? NoteTableData.empty() : null,
    );
    final insertAt = anchorIndex >= 0
        ? anchorIndex + 1
        : _indexAfterLastVisibleBlock();
    final nextBlocks = List<NoteBlock>.from(blocks)..insert(insertAt, block);
    _document = _document.copyWith(blocks: nextBlocks);
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

  NotesEditorMutation deleteBlock(String id) {
    final index = _indexOf(id);
    if (index < 0 || !isSupportedProductionBlock(blocks[index].type)) {
      return const NotesEditorMutation();
    }
    final nextBlocks = List<NoteBlock>.from(blocks)..removeAt(index);
    final visible = nextBlocks
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
      focusId = replacement.id;
      selection = const TextSelection.collapsed(offset: 0);
    } else {
      final candidate = visible[index.clamp(0, visible.length - 1).toInt()];
      focusId = isEditableText(candidate.type) ? candidate.id : null;
      selection = focusId == null
          ? null
          : TextSelection.collapsed(offset: candidate.effectiveText.length);
    }
    _document = _document.copyWith(blocks: nextBlocks);
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
    return const NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
    );
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
        cells.insert(safeRow, List<String>.filled(cells.first.length, ''));
        changed = true;
        break;
      case NotesTableEditCommand.addRowBelow:
        cells.insert(safeRow + 1, List<String>.filled(cells.first.length, ''));
        changed = true;
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
    return const NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
    );
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
    _document = _document.copyWith(blocks: nextBlocks);
    activeBlockId = moving.id;
    return const NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
    );
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
        NotesInlineFormat.link => marks.copyWith(
            link: link,
          ),
      },
    );
    _replaceBlock(block.copyWith(text: block.effectiveText, runs: runs));
    activeBlockId = id;
    activeSelection = selection;
    return const NotesEditorMutation(changed: true);
  }

  NotesEditorMutation _focusMutation(
    String blockId,
    TextSelection? selection,
  ) {
    return NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
      focusBlockId: blockId,
      selection: selection,
    );
  }

  void _replaceBlock(NoteBlock replacement) {
    final index = _indexOf(replacement.id);
    if (index < 0) return;
    final nextBlocks = List<NoteBlock>.from(blocks)..[index] = replacement;
    _document = _document.copyWith(blocks: nextBlocks);
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
        type == NoteBlockType.drawing;
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
        NoteTextRun(
          text: run.text.substring(0, localStart),
          marks: run.marks,
        ),
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
        NoteTextRun(
          text: run.text.substring(localEnd),
          marks: run.marks,
        ),
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
        result.last.marks.toJson().toString() == run.marks.toJson().toString()) {
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
