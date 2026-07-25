// Full-screen Notes block editor — faithful Flutter port of NoteEditor.tsx.
//
// Replaces the Quill-based notes editor as the PRIMARY editing experience.
// Every note is an ordered list of typed blocks (paragraph / checklist /
// heading / image / drawing). Local-first: edits apply to the Brain cache
// immediately and a debounced PATCH is scheduled via [EditSheetAutosaveGate].
//
// Layout (Column, no Expanded swallow):
//   1. Top bar (Done / Pin / Delete / save status)
//   2. Scrollable content (title + metadata + blocks + add-block row)
//   3. Fixed formatting toolbar (always visible, above keyboard)

import 'dart:async';
import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:counter/features/notes/drawing_canvas_page.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart';
import 'package:counter/features/notes/widgets/notes_editor_tools.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the Notes block editor as a full-screen route.
///
/// [task] is the persisted (or optimistic) [PlanningTask] to edit. The editor
/// reads its [NoteDocument] from the Brain, applies local-first edits, and
/// debounces a single PATCH via [DatabaseService.applyNoteEdit].
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

  /// Visual parity harness: skip network tag load; use fixture metadata only.
  final bool parityPreview;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

enum _SaveStatus { editing, saving, saved, offline, error }

class _NoteEditorPageState extends State<NoteEditorPage> {
  late PlanningTask _task;
  late NoteDocument _doc;
  late final TextEditingController _titleController;
  late final EditSheetAutosaveGate _gate;
  String? _activeBlockId;
  bool _showColorPicker = false;
  bool _showCategoryPicker = false;
  bool _showTagPicker = false;
  _SaveStatus _status = _SaveStatus.saved;
  List<Tag> _availableTags = const [];
  bool _tagsLoading = true;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _doc = DatabaseService.instance.parseNoteDocument(_task);
    _titleController = TextEditingController(text: _task.title);
    _gate = EditSheetAutosaveGate();
    if (_doc.blocks.isEmpty) {
      _doc = _doc.copyWith(
        blocks: [
          NoteBlock(
            id: generateNoteBlockId(),
            type: NoteBlockType.paragraph,
            text: '',
          ),
        ],
      );
    }
    _activeBlockId = _doc.blocks.isNotEmpty ? _doc.blocks.first.id : null;
    if (!widget.parityPreview) {
      _loadTags();
    } else {
      _tagsLoading = false;
    }
  }

  @override
  void dispose() {
    if (!widget.parityPreview) {
      _flushSync();
    }
    _gate.dispose();
    _titleController.dispose();
    widget.onClosed?.call();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await DatabaseService.instance.fetchTagsForCurrentUser(
        scope: TagCatalogScope.list,
      );
      if (!mounted) return;
      setState(() {
        _availableTags = tags;
        _tagsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tagsLoading = false);
    }
  }

  // ---- Local-first mutation helpers --------------------------------------

  void _mutate(
    NoteDocument next, {
    String? title,
    int? categoryId,
    List<Tag>? tags,
    bool? isDone,
  }) {
    setState(() {
      _doc = next;
      if (title != null)
        _titleController.value = TextEditingValue(
          text: title,
          selection: TextSelection.collapsed(offset: title.length),
        );
    });
    _status = _SaveStatus.editing;
    _gate.schedule(_syncToBrain);
  }

  void _syncToBrain() {
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
  }

  void _flushSync() {
    _gate.flush(_syncToBrain, force: true);
  }

  NoteBlock? get _activeBlock =>
      _doc.blocks.where((b) => b.id == _activeBlockId).firstOrNull;

  void _addBlock(
    NoteBlockType type, {
    String? afterId,
    String? imageData,
    String? drawingData,
    int? level,
    NoteTableData? table,
    NoteCalloutData? callout,
    NoteLinkData? linkData,
    NoteReferenceData? reference,
    String? codeLanguage,
  }) {
    final base = NoteBlock(
      id: generateNoteBlockId(),
      type: type,
      text: '',
      checked: false,
      level: level ?? 2,
      imageData: imageData,
      drawingData: drawingData,
      table: table,
      callout: callout,
      linkData: linkData,
      reference: reference,
      codeLanguage: codeLanguage,
    );
    final blocks = List<NoteBlock>.from(_doc.blocks);
    var insertIndex = blocks.length;
    if (afterId != null) {
      final index = blocks.indexWhere((block) => block.id == afterId);
      if (index >= 0) insertIndex = index + 1;
    }
    blocks.insert(insertIndex, base);
    _mutate(_doc.copyWith(blocks: blocks));
    setState(() => _activeBlockId = base.id);
  }

  void _insertRequest(NotesInsertRequest request) {
    _addBlock(
      request.type,
      afterId: _activeBlockId,
      table: request.table,
      callout: request.callout,
      linkData: request.linkData,
      codeLanguage: request.codeLanguage,
    );
  }

  void _setBlockType(NoteBlockType type) {
    final block = _activeBlock;
    if (block == null || (!block.hasText && type.isTextual)) return;
    _updateBlock(
      block.id,
      (current) => current.copyWith(
        type: type,
        callout: type == NoteBlockType.callout
            ? current.callout ??
                  const NoteCalloutData(type: NoteCalloutType.idea)
            : null,
        codeLanguage: type == NoteBlockType.codeBlock
            ? current.codeLanguage ?? 'plain'
            : null,
      ),
    );
  }

  void _updateBlock(String id, NoteBlock Function(NoteBlock) patch) {
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

  void _deleteBlock(String id) {
    final blocks = List<NoteBlock>.from(_doc.blocks)
      ..removeWhere((b) => b.id == id);
    _mutate(_doc.copyWith(blocks: blocks));
    if (_activeBlockId == id) {
      _activeBlockId = blocks.isNotEmpty ? blocks.first.id : null;
    }
  }

  void _moveBlock(String id, int dir) {
    final blocks = List<NoteBlock>.from(_doc.blocks);
    final i = blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    final j = i + dir;
    if (j < 0 || j >= blocks.length) return;
    final tmp = blocks[i];
    blocks[i] = blocks[j];
    blocks[j] = tmp;
    _mutate(_doc.copyWith(blocks: blocks));
  }

  int _numberedOrdinalAt(int index) {
    if (_doc.blocks[index].type != NoteBlockType.numberedList) return 1;
    var start = index;
    while (start > 0 &&
        _doc.blocks[start - 1].type == NoteBlockType.numberedList) {
      start--;
    }
    return index - start + 1;
  }

  // ---- Toolbar actions on active block -----------------------------------

  void _toggleFormat(String key) {
    final b = _activeBlock;
    if (b == null || !b.hasText) return;
    _updateBlock(b.id, (x) {
      switch (key) {
        case 'bold':
          return x.copyWith(bold: !x.bold);
        case 'italic':
          return x.copyWith(italic: !x.italic);
        case 'underline':
          return x.copyWith(underline: !x.underline);
        case 'strike':
          final effective = x.effectiveRuns;
          final enabled = effective.any((run) => run.marks.strike);
          return x.copyWith(
            runs: effective
                .map(
                  (run) =>
                      run.copyWith(marks: run.marks.copyWith(strike: !enabled)),
                )
                .toList(growable: false),
          );
        default:
          return x;
      }
    });
  }

  void _setHeading(int level) {
    final b = _activeBlock;
    if (b == null || !b.hasText) return;
    if (b.type == NoteBlockType.heading && b.level == level) {
      _updateBlock(b.id, (x) => x.copyWith(type: NoteBlockType.paragraph));
    } else {
      _updateBlock(
        b.id,
        (x) => x.copyWith(type: NoteBlockType.heading, level: level),
      );
    }
  }

  void _toggleChecklist() {
    final b = _activeBlock;
    if (b == null || !b.hasText) return;
    if (b.type == NoteBlockType.checklist) {
      _updateBlock(b.id, (x) => x.copyWith(type: NoteBlockType.paragraph));
    } else {
      _updateBlock(
        b.id,
        (x) => x.copyWith(type: NoteBlockType.checklist, checked: false),
      );
    }
  }

  void _setColor(String? color) {
    final b = _activeBlock;
    if (b == null || !b.hasText) return;
    _updateBlock(b.id, (x) => x.copyWith(color: color));
    setState(() => _showColorPicker = false);
  }

  // ---- Image / drawing ---------------------------------------------------

  Future<void> _pickImage() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > kLifeOsNotesMaxAssetBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(currentLocale.value, 'notes_v3_editor_image_too_large'),
          ),
        ),
      );
      return;
    }
    final b64 = base64Encode(bytes);
    final mime = file.mimeType ?? 'image/png';
    final dataUrl = 'data:$mime;base64,$b64';
    _addBlock(NoteBlockType.image, afterId: _activeBlockId, imageData: dataUrl);
  }

  void _openDrawing({String? editBlockId}) {
    String? initial;
    if (editBlockId != null) {
      final b = _doc.blocks.where((x) => x.id == editBlockId).firstOrNull;
      initial = b?.drawingData;
    }
    unawaited(
      showDrawingCanvas(
        context: context,
        initialData: initial,
        onSave: (png) {
          if (editBlockId != null) {
            _updateBlock(editBlockId, (x) => x.copyWith(drawingData: png));
          } else {
            _addBlock(
              NoteBlockType.drawing,
              afterId: _activeBlockId,
              drawingData: png,
            );
          }
        },
      ),
    );
  }

  // ---- Pin / done / delete ----------------------------------------------

  void _togglePin() {
    final nextPinned = !_doc.meta.pinned;
    final next = _doc.copyWith(meta: _doc.meta.copyWith(pinned: nextPinned));
    _mutate(next);
    DatabaseService.instance.applyNoteEdit(
      planRowIdForBackend: _task.planRowIdForBackend,
      doc: next,
      title: _titleController.text.trim(),
      categoryId: _task.categoryId,
      tags: _task.tags,
      isDone: _task.isDone,
    );
  }

  void _toggleDone() {
    DatabaseService.instance.toggleNoteDone(_task.planRowIdForBackend);
    final fresh = DatabaseService.instance.getCachedPlanningTaskForEdit(
      _task.planRowIdForBackend,
    );
    setState(() {
      _task = fresh ?? _task.copyWith(isDone: !_task.isDone);
    });
  }

  Future<void> _confirmDelete() async {
    final loc = currentLocale.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(loc, 'notes_v3_editor_delete')),
        content: Text(t(loc, 'notes_v3_editor_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(loc, 'cancel')),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t(loc, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.deleteNote(_task.planRowIdForBackend);
    if (mounted) Navigator.of(context).pop();
  }

  // ---- Category / tags ---------------------------------------------------

  Future<void> _selectCategory(int categoryId) async {
    if (categoryId == _task.categoryId) {
      setState(() => _showCategoryPicker = false);
      return;
    }
    final doc = _doc;
    DatabaseService.instance.applyNoteEdit(
      planRowIdForBackend: _task.planRowIdForBackend,
      doc: doc,
      title: _titleController.text.trim(),
      categoryId: categoryId,
      tags: _task.tags,
      isDone: _task.isDone,
    );
    setState(() {
      _task = _task.copyWith(categoryId: categoryId);
      _showCategoryPicker = false;
    });
  }

  void _toggleCategoryPicker() {
    setState(() => _showCategoryPicker = !_showCategoryPicker);
  }

  Future<void> _openFullCategoryPicker() async {
    final next = await showCategoryTreePicker(
      context,
      initialCategoryId: _task.categoryId,
    );
    if (next == null) return;
    await _selectCategory(next);
  }

  void _toggleTag(Tag tag) {
    final has = _task.tags.any((t) => t.tagId == tag.tagId);
    final next = has
        ? _task.tags.where((t) => t.tagId != tag.tagId).toList()
        : <Tag>[..._task.tags, tag];
    final doc = _doc;
    DatabaseService.instance.applyNoteEdit(
      planRowIdForBackend: _task.planRowIdForBackend,
      doc: doc,
      title: _titleController.text.trim(),
      categoryId: _task.categoryId,
      tags: next,
      isDone: _task.isDone,
    );
    setState(() {
      _task = _task.copyWith(tags: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final cat = widget.parityPreview
        ? CategoryRule(
            id: _task.categoryId,
            name: 'Personal',
            colorValue: scheme.primary.toARGB32(),
          )
        : DatabaseService.instance.getCategoryRuleById(_task.categoryId);
    final catColor = cat?.colorOrDefault ?? scheme.primary;
    final pinned = _doc.meta.pinned;
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final titleSize = wide ? kGlmTitleSizeDesktop : kGlmTitleSizeMobile;

    final editorBody = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        kGlmEditorPadH,
        kGlmEditorPadV,
        kGlmEditorPadH,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1.12,
              letterSpacing: -0.5,
              color: const Color(0xFF0F172A),
            ),
            minLines: 1,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: t(loc, 'notes_v3_editor_title_hint'),
              hintStyle: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                height: 1.12,
                letterSpacing: -0.5,
                color: kGlmMetaColor.withValues(alpha: 0.55),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              _status = _SaveStatus.editing;
              _gate.schedule(_syncToBrain);
            },
          ),
          const SizedBox(height: 4),
          _MetaDataRow(
            task: _task,
            cat: cat,
            catColor: catColor,
            onPickCategory: _toggleCategoryPicker,
            onPickTags: () => setState(() => _showTagPicker = !_showTagPicker),
            loc: loc,
            parityPreview: widget.parityPreview,
          ),
          if (_showCategoryPicker) ...[
            _CategoryPickerSheet(
              currentCategoryId: _task.categoryId,
              onSelect: _selectCategory,
              onOpenFullPicker: widget.parityPreview
                  ? null
                  : _openFullCategoryPicker,
            ),
          ],
          if (_showTagPicker && !widget.parityPreview) ...[
            const SizedBox(height: 8),
            _TagPickerSheet(
              selectedTags: _task.tags,
              availableTags: _availableTags,
              loading: _tagsLoading,
              onToggle: _toggleTag,
              loc: loc,
            ),
          ],
          const SizedBox(height: 16),
          for (int i = 0; i < _doc.blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            NoteEditorBlockRow(
              key: ValueKey(_doc.blocks[i].id),
              block: _doc.blocks[i],
              isActive: _doc.blocks[i].id == _activeBlockId,
              listOrdinal: _numberedOrdinalAt(i),
              canMoveUp: i > 0,
              canMoveDown: i < _doc.blocks.length - 1,
              onActivate: () =>
                  setState(() => _activeBlockId = _doc.blocks[i].id),
              onUpdate: (patch) =>
                  _updateBlock(_doc.blocks[i].id, patch.applyTo),
              onTextChanged: (patch) =>
                  _updateBlockDraft(_doc.blocks[i].id, patch.applyTo),
              onTableChanged: (table) => _updateBlockDraft(
                _doc.blocks[i].id,
                (current) => current.copyWith(table: table),
              ),
              onDelete: () => _deleteBlock(_doc.blocks[i].id),
              onMoveUp: () => _moveBlock(_doc.blocks[i].id, -1),
              onMoveDown: () => _moveBlock(_doc.blocks[i].id, 1),
              onEditDrawing: () => _openDrawing(editBlockId: _doc.blocks[i].id),
              onEnter: () {
                final b = _doc.blocks[i];
                if (b.hasText) {
                  final nextType = switch (b.type) {
                    NoteBlockType.heading => NoteBlockType.paragraph,
                    NoteBlockType.quote => NoteBlockType.paragraph,
                    NoteBlockType.callout => NoteBlockType.paragraph,
                    NoteBlockType.codeBlock => NoteBlockType.codeBlock,
                    NoteBlockType.collapsible => NoteBlockType.paragraph,
                    _ => b.type,
                  };
                  _addBlock(nextType, afterId: b.id);
                }
              },
              loc: loc,
            ),
          ],
          const SizedBox(height: 12),
          NoteEditorAddBlockRow(
            loc: loc,
            onAdd: _addBlock,
            onImage: _pickImage,
            onDraw: () => _openDrawing(),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: NotesGlmEditorFrame(
        keyboardInset: kb,
        topBar: _TopBar(
          status: _status,
          pinned: pinned,
          canDelete:
              !widget.parityPreview && _task.planRowIdForBackend.isNotEmpty,
          onDone: () => Navigator.of(context).pop(),
          onTogglePin: _togglePin,
          onDelete: _confirmDelete,
        ),
        body: editorBody,
        toolbar: NotesEditorToolsDock(
          activeBlock: _activeBlock,
          loc: loc,
          onToggleChecklist: _toggleChecklist,
          onHeading: _setHeading,
          onSetBlockType: _setBlockType,
          onToggleFormat: _toggleFormat,
          onSetColor: _setColor,
          onInsert: _insertRequest,
          onImage: _pickImage,
          onDraw: () => _openDrawing(),
        ),
      ),
    );
  }
}

// ---- Top bar -------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.status,
    required this.pinned,
    required this.canDelete,
    required this.onDone,
    required this.onTogglePin,
    required this.onDelete,
  });

  final _SaveStatus status;
  final bool pinned;
  final bool canDelete;
  final VoidCallback onDone;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    String statusText;
    Color statusColor;
    switch (status) {
      case _SaveStatus.editing:
        statusText = t(loc, 'notes_v3_editor_status_editing');
        statusColor = scheme.onSurfaceVariant;
        break;
      case _SaveStatus.saving:
        statusText = t(loc, 'notes_v3_editor_status_saving');
        statusColor = scheme.primary;
        break;
      case _SaveStatus.saved:
        statusText = t(loc, 'notes_v3_editor_status_saved');
        statusColor = scheme.onSurfaceVariant;
        break;
      case _SaveStatus.offline:
        statusText = t(loc, 'notes_v3_editor_status_offline');
        statusColor = scheme.tertiary;
        break;
      case _SaveStatus.error:
        statusText = t(loc, 'notes_v3_editor_status_error');
        statusColor = scheme.error;
        break;
    }
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        height: kGlmTopBarHeight,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFE8ECF4).withValues(alpha: 0.9),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            TextButton(
              onPressed: onDone,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(t(loc, 'notes_v3_editor_done')),
                ],
              ),
            ),
            if (status != _SaveStatus.saved) ...[
              const SizedBox(width: 8),
              if (status == _SaveStatus.saving)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: scheme.primary.withValues(alpha: 0.7),
                  ),
                )
              else
                Icon(
                  status == _SaveStatus.error
                      ? Icons.error_outline_rounded
                      : Icons.cloud_off_outlined,
                  size: 12,
                  color: statusColor.withValues(alpha: 0.75),
                ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor.withValues(alpha: 0.75),
                ),
              ),
            ],
            const Spacer(),
            _RoundIconBtn(
              tooltip: pinned
                  ? t(loc, 'notes_v3_editor_unpin')
                  : t(loc, 'notes_v3_editor_pin'),
              icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: pinned ? scheme.primary : kGlmMetaColor,
              onTap: onTogglePin,
            ),
            if (canDelete) ...[
              const SizedBox(width: 4),
              _RoundIconBtn(
                tooltip: t(loc, 'notes_v3_editor_delete'),
                icon: Icons.delete_outline_rounded,
                color: kGlmMetaColor,
                hoverDanger: true,
                onTap: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
    this.hoverDanger = false,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool hoverDanger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: hoverDanger
              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
              : const Color(0xFF6366F1).withValues(alpha: 0.08),
          child: SizedBox(
            width: kNotesIconBtnSize,
            height: kNotesIconBtnSize,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

// ---- Metadata row --------------------------------------------------------

class _MetaDataRow extends StatelessWidget {
  const _MetaDataRow({
    required this.task,
    required this.cat,
    required this.catColor,
    required this.onPickCategory,
    required this.onPickTags,
    required this.loc,
    this.parityPreview = false,
  });

  final PlanningTask task;
  final CategoryRule? cat;
  final Color catColor;
  final VoidCallback onPickCategory;
  final VoidCallback onPickTags;
  final String loc;
  final bool parityPreview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = task.updatedAt ?? task.createdAt;
    final when = updated != null ? _formatRelative(updated) : '';
    final tags = parityPreview
        ? [const Tag(tagId: 1, name: 'routine', color: '#6366F1')]
        : task.tags;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (when.isNotEmpty)
          Text(
            parityPreview
                ? 'Edited $when'
                : t(loc, 'notes_v3_edited').replaceAll('{when}', when),
            style: const TextStyle(
              fontSize: kGlmMetaSize,
              color: kGlmMetaColor,
              height: 1.3,
            ),
          ),
        if (when.isNotEmpty)
          const Text(
            '·',
            style: TextStyle(fontSize: kGlmMetaSize, color: kGlmMetaColor),
          ),
        InkWell(
          onTap: onPickCategory,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: notesTintBackground(catColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cat?.iconCodePoint != null)
                  Icon(
                    IconData(cat!.iconCodePoint!, fontFamily: 'MaterialIcons'),
                    size: 10,
                    color: catColor,
                  ),
                if (cat?.iconCodePoint != null) const SizedBox(width: 4),
                Text(
                  cat?.name ?? '',
                  style: TextStyle(
                    fontSize: kNotesBadgeSize,
                    fontWeight: FontWeight.w500,
                    color: catColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tags.isNotEmpty) ...[
          const Text(
            '·',
            style: TextStyle(fontSize: kGlmMetaSize, color: kGlmMetaColor),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (final tag in tags.take(3))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: notesTintBackground(
                      _parseHexColor(tag.color) ?? scheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      fontSize: kNotesBadgeSize,
                      fontWeight: FontWeight.w500,
                      color: _parseHexColor(tag.color) ?? scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ] else if (!parityPreview) ...[
          const Text(
            '·',
            style: TextStyle(fontSize: kGlmMetaSize, color: kGlmMetaColor),
          ),
          InkWell(
            onTap: onPickTags,
            child: Text(
              t(loc, 'notes_editor_tags_tooltip'),
              style: TextStyle(
                fontSize: kGlmMetaSize,
                color: scheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim();
  if (h.isEmpty) return null;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

String _formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  final loc = currentLocale.value;
  final min = diff.inMinutes;
  if (min < 1) return t(loc, 'notes_v3_just_now');
  if (min < 60) return t(loc, 'notes_v3_min_ago').replaceAll('{n}', '$min');
  final hr = diff.inHours;
  if (hr < 24) return t(loc, 'notes_v3_hr_ago').replaceAll('{n}', '$hr');
  final day = diff.inDays;
  if (day < 7) return t(loc, 'notes_v3_day_ago').replaceAll('{n}', '$day');
  return '${dt.month}/${dt.day}';
}

// ---- Category / tag picker sheets ---------------------------------------

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.currentCategoryId,
    required this.onSelect,
    this.onOpenFullPicker,
  });

  final int currentCategoryId;
  final ValueChanged<int> onSelect;
  final VoidCallback? onOpenFullPicker;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final rules = DatabaseService.instance.rules
        .where((r) => !r.isArchived)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: notesGlmGlassCardDecoration(radius: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final rule in rules)
            _CategoryPickerPill(
              rule: rule,
              selected: rule.id == currentCategoryId,
              onTap: () => onSelect(rule.id),
            ),
          if (onOpenFullPicker != null)
            _CategoryPickerPill(
              label: t(loc, 'notes_editor_more_tooltip'),
              color: kGlmMetaColor,
              selected: false,
              onTap: onOpenFullPicker!,
            ),
        ],
      ),
    );
  }
}

class _CategoryPickerPill extends StatelessWidget {
  const _CategoryPickerPill({
    this.rule,
    this.label,
    this.color,
    required this.selected,
    required this.onTap,
  }) : assert(rule != null || label != null);

  final CategoryRule? rule;
  final String? label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = rule?.colorOrDefault ?? color ?? kGlmMetaColor;
    final text = label ?? rule?.name ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? c
                : const Color(0xFFFFFFFF).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? c : const Color(0xFFE2E8F0)),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kGlmPillTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPickerSheet extends StatelessWidget {
  const _TagPickerSheet({
    required this.selectedTags,
    required this.availableTags,
    required this.loading,
    required this.onToggle,
    required this.loc,
  });

  final List<Tag> selectedTags;
  final List<Tag> availableTags;
  final bool loading;
  final void Function(Tag) onToggle;
  final String loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      );
    }
    if (availableTags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '—',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final tag in availableTags)
            FilterChip(
              label: Text(tag.name, style: const TextStyle(fontSize: 11)),
              selected: selectedTags.any((t) => t.tagId == tag.tagId),
              onSelected: (_) => onToggle(tag),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// ---- Editor formatting toolbar ------------------------------------------

const List<String> _kTextColors = <String>[
  '#0F172A',
  '#EF4444',
  '#F59E0B',
  '#10B981',
  '#06B6D4',
  '#6366F1',
  '#EC4899',
  '#94A3B8',
];

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.activeBlock,
    required this.showColorPicker,
    required this.onToggleChecklist,
    required this.onHeading,
    required this.onToggleFormat,
    required this.onToggleColorPicker,
    required this.onSetColor,
    required this.onImage,
    required this.onDraw,
    required this.loc,
  });

  final NoteBlock? activeBlock;
  final bool showColorPicker;
  final VoidCallback onToggleChecklist;
  final void Function(int) onHeading;
  final void Function(String) onToggleFormat;
  final VoidCallback onToggleColorPicker;
  final void Function(String?) onSetColor;
  final VoidCallback onImage;
  final VoidCallback onDraw;
  final String loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: kGlmToolbarHeight,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFE8ECF4).withValues(alpha: 0.95),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ToolBtn(
                    icon: Icons.checklist_rounded,
                    label: t(loc, 'notes_v3_editor_checklist_toggle'),
                    active: activeBlock?.type == NoteBlockType.checklist,
                    onTap: onToggleChecklist,
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.title_rounded,
                    label: t(loc, 'notes_v3_editor_h1'),
                    active:
                        activeBlock?.type == NoteBlockType.heading &&
                        activeBlock?.level == 1,
                    onTap: () => onHeading(1),
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.text_fields_rounded,
                    label: t(loc, 'notes_v3_editor_h2'),
                    active:
                        activeBlock?.type == NoteBlockType.heading &&
                        activeBlock?.level == 2,
                    onTap: () => onHeading(2),
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.format_size_rounded,
                    label: t(loc, 'notes_v3_editor_h3'),
                    active:
                        activeBlock?.type == NoteBlockType.heading &&
                        activeBlock?.level == 3,
                    onTap: () => onHeading(3),
                    scheme: scheme,
                  ),
                  _Divider(scheme: scheme),
                  _ToolBtn(
                    icon: Icons.format_bold_rounded,
                    label: t(loc, 'notes_v3_editor_bold'),
                    active: activeBlock?.bold == true,
                    onTap: () => onToggleFormat('bold'),
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.format_italic_rounded,
                    label: t(loc, 'notes_v3_editor_italic'),
                    active: activeBlock?.italic == true,
                    onTap: () => onToggleFormat('italic'),
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.format_underlined_rounded,
                    label: t(loc, 'notes_v3_editor_underline'),
                    active: activeBlock?.underline == true,
                    onTap: () => onToggleFormat('underline'),
                    scheme: scheme,
                  ),
                  _Divider(scheme: scheme),
                  _ToolBtn(
                    icon: Icons.palette_outlined,
                    label: t(loc, 'notes_v3_editor_color'),
                    customChild: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _parseHexColor(activeBlock?.color) ??
                            const Color(0xFF0F172A),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                    ),
                    onTap: onToggleColorPicker,
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.image_outlined,
                    label: t(loc, 'notes_v3_editor_add_image'),
                    onTap: onImage,
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.draw_outlined,
                    label: t(loc, 'notes_v3_editor_add_draw'),
                    onTap: onDraw,
                    scheme: scheme,
                  ),
                ],
              ),
            ),
          ),
          if (showColorPicker)
            Positioned(
              bottom: kGlmToolbarHeight + 8,
              left: 0,
              right: 0,
              child: Center(
                child: _ColorPickerPopover(onSetColor: onSetColor, loc: loc),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorPickerPopover extends StatelessWidget {
  const _ColorPickerPopover({required this.onSetColor, required this.loc});

  final void Function(String?) onSetColor;
  final String loc;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: notesGlmGlassCardDecoration(radius: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in _kTextColors) ...[
              GestureDetector(
                onTap: () => onSetColor(c == '#0F172A' ? null : c),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _parseHexColor(c),
                    border: c == '#0F172A'
                        ? Border.all(color: const Color(0xFFE2E8F0))
                        : null,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSetColor(null),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: notesGlmGlassPillDecoration(),
                  child: Text(
                    t(loc, 'notes_v3_editor_color_auto'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: kGlmPillTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
    this.active = false,
    this.customChild,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool active;
  final Widget? customChild;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: kNotesToolBtnSize,
              minHeight: kNotesToolBtnSize,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF6366F1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child:
                customChild ??
                Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.white : kGlmPillTextColor,
                ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: scheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}
