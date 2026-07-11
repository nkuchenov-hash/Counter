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
import 'dart:typed_data';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/notes/drawing_canvas_page.dart';
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
  const NoteEditorPage({super.key, required this.task, this.onClosed});

  final PlanningTask task;
  final VoidCallback? onClosed;

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
    _loadTags();
  }

  @override
  void dispose() {
    _flushSync();
    _gate.dispose();
    _titleController.dispose();
    widget.onClosed?.call();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final tags =
          await DatabaseService.instance.fetchTagsForCurrentUser(
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

  void _mutate(NoteDocument next, {String? title, int? categoryId, List<Tag>? tags, bool? isDone}) {
    setState(() {
      _doc = next;
      if (title != null) _titleController.value = TextEditingValue(
        text: title,
        selection: TextSelection.collapsed(offset: title.length),
      );
    });
    _status = _SaveStatus.editing;
    _gate.schedule(_syncToBrain);
  }

  void _syncToBrain() {
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
  }

  void _flushSync() {
    _gate.flush(_syncToBrain, force: true);
  }

  NoteBlock? get _activeBlock =>
      _doc.blocks.where((b) => b.id == _activeBlockId).firstOrNull;

  void _addBlock(NoteBlockType type, {String? afterId, String? imageData, String? drawingData, int? level}) {
    final base = NoteBlock(
      id: generateNoteBlockId(),
      type: type,
      text: '',
      checked: type == NoteBlockType.checklist ? false : false,
      level: level ?? (type == NoteBlockType.heading ? 2 : 2),
      imageData: imageData,
      drawingData: drawingData,
    );
    final blocks = List<NoteBlock>.from(_doc.blocks);
    int insertIdx = blocks.length;
    if (afterId != null) {
      final i = blocks.indexWhere((b) => b.id == afterId);
      if (i >= 0) insertIdx = i + 1;
    }
    blocks.insert(insertIdx, base);
    _mutate(_doc.copyWith(blocks: blocks));
    setState(() => _activeBlockId = base.id);
  }

  void _updateBlock(String id, NoteBlock Function(NoteBlock) patch) {
    final blocks = List<NoteBlock>.from(_doc.blocks);
    final i = blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    blocks[i] = patch(blocks[i]);
    _mutate(_doc.copyWith(blocks: blocks));
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
      _updateBlock(b.id, (x) => x.copyWith(type: NoteBlockType.heading, level: level));
    }
  }

  void _toggleChecklist() {
    final b = _activeBlock;
    if (b == null || !b.hasText) return;
    if (b.type == NoteBlockType.checklist) {
      _updateBlock(b.id, (x) => x.copyWith(type: NoteBlockType.paragraph));
    } else {
      _updateBlock(b.id, (x) => x.copyWith(type: NoteBlockType.checklist, checked: false));
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
        SnackBar(content: Text(t(currentLocale.value, 'notes_v3_editor_image_too_large'))),
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
    unawaited(showDrawingCanvas(
      context: context,
      initialData: initial,
      onSave: (png) {
        if (editBlockId != null) {
          _updateBlock(editBlockId, (x) => x.copyWith(drawingData: png));
        } else {
          _addBlock(NoteBlockType.drawing, afterId: _activeBlockId, drawingData: png);
        }
      },
    ));
  }

  // ---- Pin / done / delete ----------------------------------------------

  void _togglePin() {
    final nextPinned = !_doc.meta.pinned;
    final next = _doc.copyWith(
      meta: _doc.meta.copyWith(pinned: nextPinned),
    );
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

  Future<void> _pickCategory() async {
    final next = await showCategoryTreePicker(context, initialCategoryId: _task.categoryId);
    if (next == null) return;
    final doc = _doc;
    DatabaseService.instance.applyNoteEdit(
      planRowIdForBackend: _task.planRowIdForBackend,
      doc: doc,
      title: _titleController.text.trim(),
      categoryId: next,
      tags: _task.tags,
      isDone: _task.isDone,
    );
    setState(() {
      _task = _task.copyWith(categoryId: next);
      _showCategoryPicker = false;
    });
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = currentLocale.value;
    final cat = DatabaseService.instance.getCategoryRuleById(_task.categoryId);
    final catColor = cat?.colorOrDefault ?? scheme.primary;
    final pinned = _doc.meta.pinned;
    final kb = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              status: _status,
              pinned: pinned,
              canDelete: _task.planRowIdForBackend.isNotEmpty,
              onDone: () => Navigator.of(context).pop(),
              onTogglePin: _togglePin,
              onDelete: _confirmDelete,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 80),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          style: (theme.textTheme.headlineSmall ??
                                  const TextStyle())
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: t(loc, 'notes_v3_editor_title_hint'),
                            hintStyle: (theme.textTheme.headlineSmall ??
                                    const TextStyle())
                                .copyWith(
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.32),
                                  fontWeight: FontWeight.w600,
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
                        // Metadata row
                        _MetaDataRow(
                          task: _task,
                          cat: cat,
                          catColor: catColor,
                          onPickCategory: _pickCategory,
                          onPickTags: () => setState(
                              () => _showTagPicker = !_showTagPicker),
                          loc: loc,
                        ),
                        if (_showCategoryPicker) ...[
                          const SizedBox(height: 8),
                          _CategoryPickerSheet(
                            currentCategoryId: _task.categoryId,
                          ),
                        ],
                        if (_showTagPicker) ...[
                          const SizedBox(height: 8),
                          _TagPickerSheet(
                            selectedTags: _task.tags,
                            availableTags: _availableTags,
                            loading: _tagsLoading,
                            onToggle: _toggleTag,
                            loc: loc,
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Blocks
                        for (int i = 0; i < _doc.blocks.length; i++)
                          _BlockRow(
                            key: ValueKey(_doc.blocks[i].id),
                            block: _doc.blocks[i],
                            isActive: _doc.blocks[i].id == _activeBlockId,
                            canMoveUp: i > 0,
                            canMoveDown: i < _doc.blocks.length - 1,
                            onActivate: () => setState(
                                () => _activeBlockId = _doc.blocks[i].id),
                            onUpdate: (patch) => _updateBlock(
                                _doc.blocks[i].id, (b) => b.copyWith(
                                      type: patch.type ?? b.type,
                                      text: patch.text ?? b.text,
                                      checked: patch.checked ?? b.checked,
                                      level: patch.level ?? b.level,
                                      bold: patch.bold ?? b.bold,
                                      italic: patch.italic ?? b.italic,
                                      underline: patch.underline ?? b.underline,
                                      color: identical(patch.color, _sentinel)
                                          ? b.color
                                          : patch.color as String?,
                                      imageData: identical(patch.imageData, _sentinel)
                                          ? b.imageData
                                          : patch.imageData as String?,
                                      drawingData:
                                          identical(patch.drawingData, _sentinel)
                                              ? b.drawingData
                                              : patch.drawingData as String?,
                                    )),
                            onDelete: () => _deleteBlock(_doc.blocks[i].id),
                            onMoveUp: () => _moveBlock(_doc.blocks[i].id, -1),
                            onMoveDown: () => _moveBlock(_doc.blocks[i].id, 1),
                            onEditDrawing: () =>
                                _openDrawing(editBlockId: _doc.blocks[i].id),
                            onEnter: () {
                              final b = _doc.blocks[i];
                              if (b.type == NoteBlockType.checklist ||
                                  b.type == NoteBlockType.paragraph) {
                                _addBlock(
                                  b.type == NoteBlockType.checklist
                                      ? NoteBlockType.checklist
                                      : NoteBlockType.paragraph,
                                  afterId: b.id,
                                );
                              }
                            },
                            loc: loc,
                          ),
                        const SizedBox(height: 12),
                        // Add-block row
                        _AddBlockRow(loc: loc, onAdd: _addBlock, onImage: _pickImage, onDraw: () => _openDrawing()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Fixed formatting toolbar (always visible)
            _EditorToolbar(
              activeBlock: _activeBlock,
              showColorPicker: _showColorPicker,
              onToggleChecklist: _toggleChecklist,
              onHeading: _setHeading,
              onToggleFormat: _toggleFormat,
              onToggleColorPicker: () => setState(
                  () => _showColorPicker = !_showColorPicker),
              onSetColor: _setColor,
              onImage: _pickImage,
              onDraw: () => _openDrawing(),
              loc: loc,
            ),
            if (kb > 0) SizedBox(height: kb),
          ],
        ),
      ),
    );
  }
}

const Object _sentinel = Object();

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
      color: scheme.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: Text(t(loc, 'notes_v3_editor_done')),
            ),
            const SizedBox(width: 4),
            if (status == _SaveStatus.saving)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.4,
                  color: statusColor,
                ),
              )
            else
              Icon(Icons.check_rounded, size: 14, color: statusColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                statusText,
                style: TextStyle(fontSize: 12, color: statusColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: pinned
                  ? t(loc, 'notes_v3_editor_unpin')
                  : t(loc, 'notes_v3_editor_pin'),
              icon: Icon(
                pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                size: 20,
                color: pinned ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: onTogglePin,
            ),
            if (canDelete)
              IconButton(
                tooltip: t(loc, 'notes_v3_editor_delete'),
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20, color: scheme.error),
                onPressed: onDelete,
              ),
          ],
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
  });

  final PlanningTask task;
  final CategoryRule? cat;
  final Color catColor;
  final VoidCallback onPickCategory;
  final VoidCallback onPickTags;
  final String loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = task.updatedAt ?? task.createdAt;
    final when = updated != null ? _formatRelative(updated) : '';
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (when.isNotEmpty)
          Text(
            t(loc, 'notes_v3_edited').replaceAll('{when}', when),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        InkWell(
          onTap: onPickCategory,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cat?.iconCodePoint != null)
                  Icon(
                    IconData(
                      cat!.iconCodePoint!,
                      fontFamily: 'MaterialIcons',
                    ),
                    size: 11,
                    color: catColor,
                  ),
                if (cat?.iconCodePoint != null) const SizedBox(width: 3),
                Text(
                  cat?.name ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: catColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (task.tags.isNotEmpty)
          InkWell(
            onTap: onPickTags,
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final tag in task.tags.take(3))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_parseHexColor(tag.color) ?? scheme.primary)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _parseHexColor(tag.color) ?? scheme.primary,
                      ),
                    ),
                  ),
                if (task.tags.length > 3)
                  Text(
                    '+${task.tags.length - 3}',
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          )
        else
          TextButton.icon(
            onPressed: onPickTags,
            icon: const Icon(Icons.label_outline_rounded, size: 14),
            label: Text(
              t(loc, 'notes_v3_editor_open_note'),
              style: const TextStyle(fontSize: 11),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
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
  });

  final int currentCategoryId;

  @override
  Widget build(BuildContext context) {
    // The real category picker is a modal sheet opened via
    // showCategoryTreePicker in _pickCategory(). This placeholder is kept
    // empty so the inline expansion slot does not render stray UI.
    return const SizedBox.shrink();
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

// ---- Block row -----------------------------------------------------------

class _BlockRow extends StatefulWidget {
  const _BlockRow({
    super.key,
    required this.block,
    required this.isActive,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onActivate,
    required this.onUpdate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEditDrawing,
    required this.onEnter,
    required this.loc,
  });

  final NoteBlock block;
  final bool isActive;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onActivate;
  final void Function(_BlockPatch) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEditDrawing;
  final VoidCallback onEnter;
  final String loc;

  @override
  State<_BlockRow> createState() => _BlockRowState();
}

class _BlockRowState extends State<_BlockRow> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.block.text);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) widget.onActivate();
    });
  }

  @override
  void didUpdateWidget(covariant _BlockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _textController.text = widget.block.text;
    } else if (widget.block.text != _textController.text &&
        widget.block.text != oldWidget.block.text) {
      _textController.text = widget.block.text;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final loc = widget.loc;

    if (block.type == NoteBlockType.image && block.imageData != null) {
      return _ImageBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onDelete: widget.onDelete,
      );
    }
    if (block.type == NoteBlockType.drawing && block.drawingData != null) {
      return _DrawingBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onEditDrawing: widget.onEditDrawing,
        onDelete: widget.onDelete,
      );
    }

    final isChecklist = block.type == NoteBlockType.checklist;
    final isHeading = block.type == NoteBlockType.heading;
    final textStyle = (isHeading
            ? (block.level == 1
                ? tt.headlineSmall
                : block.level == 3
                    ? tt.titleMedium
                    : tt.titleLarge)
            : tt.bodyLarge)
        ?.copyWith(
          fontWeight:
              isHeading ? FontWeight.w700 : (block.bold ? FontWeight.w700 : null),
          fontStyle: block.italic ? FontStyle.italic : null,
          decoration: block.underline ? TextDecoration.underline : null,
          color: _parseHexColor(block.color) ?? scheme.onSurface,
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onActivate,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isActive
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isChecklist)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: InkWell(
                  onTap: () =>
                      widget.onUpdate(_BlockPatch(checked: !block.checked)),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: block.checked
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: 2,
                      ),
                      color: block.checked ? scheme.primary : null,
                    ),
                    child: block.checked
                        ? const Icon(Icons.check_rounded,
                            size: 12, color: Colors.white)
                        : null,
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
                style: textStyle,
                decoration: InputDecoration(
                  hintText: isChecklist
                      ? t(loc, 'notes_v3_editor_list_item_hint')
                      : isHeading
                          ? t(loc, 'notes_v3_editor_heading_hint')
                          : t(loc, 'notes_v3_editor_start_writing'),
                  hintStyle: (textStyle ?? tt.bodyMedium)?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.32),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  filled: false,
                ),
                onChanged: (v) => widget.onUpdate(_BlockPatch(text: v)),
                onSubmitted: (_) => widget.onEnter(),
              ),
            ),
            if (widget.isActive)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
                tooltip: t(loc, 'notes_v3_editor_block_menu'),
                itemBuilder: (ctx) => [
                  if (widget.canMoveUp)
                    PopupMenuItem(
                      value: 'up',
                      child: Text(t(loc, 'notes_v3_editor_move_up')),
                    ),
                  if (widget.canMoveDown)
                    PopupMenuItem(
                      value: 'down',
                      child: Text(t(loc, 'notes_v3_editor_move_down')),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(t(loc, 'notes_v3_editor_delete_block')),
                  ),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'up':
                      widget.onMoveUp();
                      break;
                    case 'down':
                      widget.onMoveDown();
                      break;
                    case 'delete':
                      widget.onDelete();
                      break;
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BlockPatch {
  const _BlockPatch({
    this.type,
    this.text,
    this.checked,
    this.level,
    this.bold,
    this.italic,
    this.underline,
    this.color = _sentinel,
    this.imageData = _sentinel,
    this.drawingData = _sentinel,
  });

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
}

// ---- Image / drawing blocks ---------------------------------------------

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({
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
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _bytesFromDataUrl(block.imageData)!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 80,
                color: scheme.errorContainer.withValues(alpha: 0.3),
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined,
                    color: scheme.error),
              ),
            ),
          ),
          if (isActive)
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.white),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawingBlock extends StatelessWidget {
  const _DrawingBlock({
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
      child: Stack(
        children: [
          ClipRRect(
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
                  child: Icon(Icons.broken_image_outlined,
                      color: scheme.error),
                ),
              ),
            ),
          ),
          if (isActive) ...[
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      size: 14, color: Colors.white),
                  padding: EdgeInsets.zero,
                  onPressed: onEditDrawing,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 40,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.white),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
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

// ---- Add-block row -------------------------------------------------------

class _AddBlockRow extends StatelessWidget {
  const _AddBlockRow({
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
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _AddButton(
          icon: Icons.add_rounded,
          label: t(loc, 'notes_v3_editor_add_text'),
          onTap: () => onAdd(NoteBlockType.paragraph),
          scheme: scheme,
        ),
        _AddButton(
          icon: Icons.checklist_rounded,
          label: t(loc, 'notes_v3_editor_add_checklist'),
          onTap: () => onAdd(NoteBlockType.checklist),
          scheme: scheme,
        ),
        _AddButton(
          icon: Icons.title_rounded,
          label: t(loc, 'notes_v3_editor_add_heading'),
          onTap: () => onAdd(NoteBlockType.heading),
          scheme: scheme,
        ),
        _AddButton(
          icon: Icons.image_outlined,
          label: t(loc, 'notes_v3_editor_add_image'),
          onTap: onImage,
          scheme: scheme,
        ),
        _AddButton(
          icon: Icons.draw_outlined,
          label: t(loc, 'notes_v3_editor_add_draw'),
          onTap: onDraw,
          scheme: scheme,
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}

// ---- Editor formatting toolbar ------------------------------------------

const List<String> _kTextColors = <String>[
  '#000000',
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
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                    active: activeBlock?.type == NoteBlockType.heading &&
                        activeBlock?.level == 1,
                    onTap: () => onHeading(1),
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.text_fields_rounded,
                    label: t(loc, 'notes_v3_editor_h2'),
                    active: activeBlock?.type == NoteBlockType.heading &&
                        activeBlock?.level == 2,
                    onTap: () => onHeading(2),
                    scheme: scheme,
                  ),
                  _ToolBtn(
                    icon: Icons.format_size_rounded,
                    label: t(loc, 'notes_v3_editor_h3'),
                    active: activeBlock?.type == NoteBlockType.heading &&
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
                        color: _parseHexColor(activeBlock?.color) ??
                            scheme.onSurface,
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
          if (showColorPicker) _ColorPickerRow(onSetColor: onSetColor, scheme: scheme, loc: loc),
        ],
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.onSetColor,
    required this.scheme,
    required this.loc,
  });

  final void Function(String?) onSetColor;
  final ColorScheme scheme;
  final String loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          for (final c in _kTextColors) ...[
            GestureDetector(
              onTap: () => onSetColor(c),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _parseHexColor(c),
                  border: c == '#FFFFFF'
                      ? Border.all(color: scheme.outlineVariant)
                      : null,
                ),
              ),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () => onSetColor(null),
            child: Text(t(loc, 'notes_v3_editor_color_auto')),
          ),
        ],
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: customChild ??
              Icon(
                icon,
                size: 20,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
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
