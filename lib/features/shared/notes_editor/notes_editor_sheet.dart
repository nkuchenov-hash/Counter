// Notes editor sheet — Apple-Notes-style composition over the canonical
// notes widgets, wired to the existing Brain plan mutation paths.
//
// Design intent:
//   - One large comfortable editor surface for a plan/list note.
//   - Compact context row: category chip + tags + subtle save status.
//   - Single-row formatting toolbar (bold/italic/underline/strike/lists/checklist)
//     plus inline link, divider, copy-as-markdown, paste-from-markdown.
//   - Debounced autosave via the existing EditSheetAutosaveGate (~800ms).
//   - On close: flush pending draft immediately; never lose the latest text.
//   - Never blocks typing on network I/O.
//
// Scope: this sheet intentionally does NOT replace the existing
// PlanningTaskEditSheet (which owns the checklist tab + schedule + recurrence
// + parallel panels). It is a focused Notes experience reachable from Lists
// for users who want a calmer editor.

import 'dart:async';
import 'dart:convert';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/notes/notes.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
/// Lifecycle status surfaced by [NotesEditorSheet] to the canonical
/// [AppNotesSaveStatus] chip.
enum _NotesStatus { idle, editing, saving, saved, offlinePending, error }

class NotesEditorSheet extends StatefulWidget {
  const NotesEditorSheet({
    super.key,
    required this.task,
    required this.scrollController,
    this.onSaved,
    this.onDeleted,
  });

  /// Existing plan/list row to edit. Must already be persisted to PocketBase.
  final PlanningTask task;

  final ScrollController scrollController;

  /// Optional callback invoked after a successful background sync OR explicit
  /// Save with the latest draft.
  final void Function(PlanningTask updated)? onSaved;

  /// Optional callback invoked when the user taps the destructive action.
  final void Function(PlanningTask task)? onDeleted;

  @override
  State<NotesEditorSheet> createState() => _NotesEditorSheetState();
}

class _NotesEditorSheetState extends State<NotesEditorSheet> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocus;
  late final quill.QuillController _quillController;
  late final FocusNode _quillFocus;
  late final ScrollController _quillScroll;

  late int _categoryId;
  late final List<Tag> _selectedTags;
  late final List<Tag> _availableTags;
  bool _tagsLoading = true;

  final EditSheetAutosaveGate _gate =
      EditSheetAutosaveGate(debounce: const Duration(milliseconds: 800));

  _NotesStatus _status = _NotesStatus.idle;
  String? _lastSavedLabel;
  Timer? _savedFlashTimer;

  StreamSubscription<quill.DocChange>? _quillSub;

  bool get _isPersisted =>
      widget.task.planRowIdForBackend.trim().isNotEmpty &&
      !widget.task.planRowIdForBackend.startsWith('optimistic-');

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _titleFocus = FocusNode();
    _quillController = quill.QuillController(
      document: _documentFromTask(widget.task),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillFocus = FocusNode();
    _quillScroll = ScrollController();
    _categoryId = widget.task.categoryId;
    _selectedTags = List<Tag>.from(widget.task.tags);
    _availableTags = const [];

    _quillSub = _quillController.document.changes.listen((_) {
      if (!mounted) return;
      _onFieldChanged();
    });

    unawaited(_loadTags());
  }

  Future<void> _loadTags() async {
    final scope = (widget.task.startTime == null &&
            widget.task.dateKey.trim().length < 10)
        ? TagCatalogScope.list
        : TagCatalogScope.plan;
    final tags =
        await DatabaseService.instance.fetchTagsForCurrentUser(scope: scope);
    if (!mounted) return;
    setState(() {
      _availableTags = tags;
      _tagsLoading = false;
    });
  }

  quill.Document _documentFromTask(PlanningTask task) {
    final deltaRaw = task.notesDeltaJson?.trim() ?? '';
    if (deltaRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(deltaRaw);
        if (decoded is List) {
          return quill.Document.fromJson(decoded);
        }
      } catch (_) {}
    }
    final plain = task.notesPlain?.trim() ?? '';
    if (plain.isNotEmpty) {
      return quill.Document.fromJson([
        <String, dynamic>{'insert': '$plain\n'},
      ]);
    }
    return quill.Document();
  }

  @override
  void dispose() {
    // Flush any pending draft before tearing down controllers so closing the
    // sheet never loses the latest text. This mirrors the existing
    // PlanningTaskEditSheet dispose contract.
    if (_isPersisted) {
      _gate.flush(
        () {
          final latest = _buildDraftTask();
          if (latest != null) {
            unawaited(_syncDraftToBrain(latest));
          }
        },
        force: _gate.isDirty,
      );
    }
    unawaited(_quillSub?.cancel());
    _savedFlashTimer?.cancel();
    _gate.dispose();
    _titleController.dispose();
    _titleFocus.dispose();
    _quillController.dispose();
    _quillFocus.dispose();
    _quillScroll.dispose();
    super.dispose();
  }

  void _setStatus(_NotesStatus next, {String? savedLabel}) {
    if (!mounted) return;
    setState(() {
      _status = next;
      if (savedLabel != null) {
        _lastSavedLabel = savedLabel;
      }
    });
  }

  PlanningTask? _buildDraftTask() {
    final title = _titleController.text.trim();
    // We do not block autosave on empty title, but we DO block sync to network
    // for an empty title (validation). Caller must keep latest local text.
    final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());
    final plain = _quillController.document
        .toPlainText()
        .replaceAll('\u200b', '')
        .trim();
    final String? notesPlainOut = plain.isEmpty ? null : plain;
    final String? notesDeltaOut = plain.isEmpty ? null : deltaJson;
    final shouldClear = notesPlainOut == null && _isTrivialDelta(deltaJson, plain);
    return widget.task.copyWith(
      title: title.isEmpty ? widget.task.title : title,
      categoryId: _categoryId,
      notesPlain: shouldClear ? null : notesPlainOut,
      notesDeltaJson: shouldClear ? null : notesDeltaOut,
      clearNotes: shouldClear,
      tags: List<Tag>.from(_selectedTags),
    );
  }

  bool _isTrivialDelta(String deltaJson, String plainTrimmed) {
    if (plainTrimmed.isNotEmpty) return false;
    try {
      final d = jsonDecode(deltaJson);
      if (d is! List) return true;
      if (d.isEmpty) return true;
      if (d.length == 1 && d[0] is Map) {
        final m = Map<String, dynamic>.from(d[0] as Map);
        if (m['insert'] == '\n' && m['attributes'] == null) return true;
      }
    } catch (_) {}
    return false;
  }

  void _onFieldChanged() {
    if (!_isPersisted) return;
    final draft = _buildDraftTask();
    if (draft == null) return;
    DatabaseService.instance.applyOptimisticPlanningTask(draft);
    DatabaseService.instance.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _setStatus(_NotesStatus.editing);
    _gate.markDirty();

    void syncLatest() {
      final latest = _buildDraftTask();
      if (latest != null) {
        unawaited(_syncDraftToBrain(latest));
      }
    }

    _gate.schedule(syncLatest);
  }

  Future<void> _syncDraftToBrain(PlanningTask draft) async {
    if (!_isPersisted) return;
    _setStatus(_NotesStatus.saving);
    final ok = await DatabaseService.instance.updatePlanningTask(
      draft.planRowIdForBackend,
      planBusinessId: draft.planRowId,
      title: draft.title,
      categoryId: draft.categoryId,
      notesPlain: draft.notesPlain,
      notesDeltaJson: draft.notesDeltaJson,
      tags: draft.tags,
      suppressAppSnack: true,
    );
    if (!mounted) return;
    if (ok) {
      _gate.markClean();
      _setStatus(_NotesStatus.saved, savedLabel: _formatSavedNow());
      _scheduleSavedToIdle();
    } else {
      // Retriable failure path: keep optimistic local state, surface pending
      // through the status chip. The existing plan mutation outbox will
      // re-attempt on connectivity / resume.
      _setStatus(_NotesStatus.offlinePending);
    }
  }

  void _scheduleSavedToIdle() {
    _savedFlashTimer?.cancel();
    _savedFlashTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_status == _NotesStatus.saved) {
        _setStatus(_NotesStatus.idle);
      }
    });
  }

  String _formatSavedNow() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final prefix = t(currentLocale.value, 'notes_editor_status_saved');
    return '$prefix · ${two(now.hour)}:${two(now.minute)}';
  }

  // ---- Editor action handlers -------------------------------------------

  Future<void> _insertLink() async {
    final urlController = TextEditingController();
    final textController = TextEditingController();
    final selection = _quillController.selection;
    final selectedText = _selectedPlainText();
    textController.text = selectedText;

    final result = await showDialog<({String url, String text})?>(
      context: context,
      builder: (ctx) {
        final loc = currentLocale.value;
        return AlertDialog(
          title: Text(t(loc, 'notes_editor_link_dialog_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: t(loc, 'notes_editor_link_text_label'),
                  hintText: t(loc, 'notes_editor_link_text_label'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: t(loc, 'notes_editor_link_url_label'),
                  hintText: 'https://example.com',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(t(loc, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isEmpty) return;
                Navigator.of(ctx).pop((url: url, text: textController.text));
              },
              child: Text(t(loc, 'save')),
            ),
          ],
        );
      },
    );
    urlController.dispose();
    final textFinal = textController.text;
    textController.dispose();
    if (result == null) return;
    final url = result.url;
    if (url.isEmpty) return;

    final textValue = textFinal.trim().isEmpty ? url : textFinal.trim();
    final docLen = _quillController.document.length;
    final selStart = selection.start;
    final selEnd = selection.end;
    final replaceStart = selStart.isFinite && selStart >= 0
        ? selStart.clamp(0, docLen)
        : docLen;
    final replaceLen = (selEnd.isFinite && selEnd > selStart)
        ? (selEnd - selStart).clamp(0, docLen - replaceStart)
        : 0;

    _quillController.replaceText(
      replaceStart,
      replaceLen,
      textValue,
      TextSelection.collapsed(
        offset: (replaceStart + textValue.length).clamp(0, docLen + textValue.length),
      ),
    );
    _quillController.formatText(
      replaceStart,
      textValue.length,
      quill.LinkAttribute(url),
    );
    _onFieldChanged();
  }

  String _selectedPlainText() {
    try {
      final sel = _quillController.selection;
      if (sel.start < 0 || sel.end <= sel.start) return '';
      return _quillController.document
          .toPlainText()
          .substring(sel.start, sel.end);
    } catch (_) {
      return '';
    }
  }

  void _insertDivider() {
    final docLen = _quillController.document.length;
    final sel = _quillController.selection;
    final baseOffset = sel.baseOffset;
    final offset = (baseOffset.isFinite && baseOffset >= 0)
        ? baseOffset.clamp(0, docLen)
        : docLen;
    // Insert a newline + divider image embed.
    _quillController.replaceText(
      offset,
      0,
      '\n',
      TextSelection.collapsed(offset: offset + 1),
    );
    _quillController.document.insert(offset + 1, dividerDeltaOp());
    _onFieldChanged();
  }

  Future<void> _copyAsMarkdown() async {
    final delta = jsonEncode(_quillController.document.toDelta().toJson());
    final md = quillDeltaJsonToMarkdown(delta);
    if (md.isEmpty) {
      AppSnack.warning(t(currentLocale.value, 'notes_editor_nothing_to_copy'));
      return;
    }
    await Clipboard.setData(ClipboardData(text: md));
    if (!mounted) return;
    AppSnack.changesSaved();
  }

  Future<void> _pasteFromMarkdown() async {
    final text = await readClipboardTextSafely();
    if (text.isEmpty) {
      AppSnack.warning(t(currentLocale.value, 'notes_editor_clipboard_empty'));
      return;
    }
    final deltaJson = markdownToQuillDeltaJson(text);
    if (deltaJson == null) {
      AppSnack.warning(t(currentLocale.value, 'notes_editor_no_markdown'));
      return;
    }
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is! List) {
        AppSnack.warning(t(currentLocale.value, 'notes_editor_no_markdown'));
        return;
      }
      final docLen = _quillController.document.length;
      final sel = _quillController.selection;
      final baseOffset = sel.baseOffset;
      final offset = (baseOffset.isFinite && baseOffset >= 0)
          ? baseOffset.clamp(0, docLen)
          : docLen;
      // Insert parsed delta directly at the caret. The Document.insert API
      // accepts a List of ops and preserves inline + block attributes.
      _quillController.document.insert(offset, decoded);
      _quillController.updateSelection(
        TextSelection.collapsed(offset: offset + docLen),
        quill.ChangeSource.local,
      );
      _onFieldChanged();
    } catch (_) {
      AppSnack.warning(t(currentLocale.value, 'notes_editor_parse_failed'));
    }
  }

  // ---- Category picker ---------------------------------------------------

  Future<void> _pickCategory() async {
    final next = await showCategoryTreePicker(
      context,
      initialCategoryId: _categoryId,
    );
    if (next == null) return;
    setState(() => _categoryId = next);
    _onFieldChanged();
  }

  void _toggleTag(Tag tag) {
    setState(() {
      final i = _selectedTags.indexWhere((t) => t.tagId == tag.tagId);
      if (i >= 0) {
        _selectedTags.removeAt(i);
      } else {
        _selectedTags.add(tag);
      }
    });
    _onFieldChanged();
  }

  // ---- Build -------------------------------------------------------------

  AppNotesContextRowData _buildContextRowData() {
    final db = DatabaseService.instance;
    final rule = db.getCategoryRuleById(_categoryId);
    final rawPath = db.getCategoryPath(_categoryId);
    final catLabel =
        localizeCategoryBreadcrumbPath(rawPath, currentLocale.value);
    final catColor = rule?.colorOrDefault ?? Colors.grey;

    final saveKind = _mapStatus(_status);
    final loc = currentLocale.value;
    String? labelFor(NotesSaveStatusKind k) {
      switch (k) {
        case NotesSaveStatusKind.saving:
          return t(loc, 'notes_editor_status_saving');
        case NotesSaveStatusKind.saved:
          return _lastSavedLabel ?? t(loc, 'notes_editor_status_saved');
        case NotesSaveStatusKind.offlinePending:
          return t(loc, 'notes_editor_status_offline');
        case NotesSaveStatusKind.error:
          return t(loc, 'notes_editor_status_error');
        case NotesSaveStatusKind.idle:
        case NotesSaveStatusKind.editing:
          return _lastSavedLabel;
      }
    }

    final saveData = AppNotesSaveStatusData(
      kind: saveKind,
      lastSavedLabel: labelFor(saveKind),
      errorLabel: saveKind == NotesSaveStatusKind.error
          ? t(loc, 'notes_editor_status_error')
          : null,
      retryLabel: saveKind == NotesSaveStatusKind.error
          ? t(loc, 'notes_editor_retry')
          : null,
    );

    final tagChips = <AppNotesContextTag>[
      for (final t in _selectedTags.take(3))
        AppNotesContextTag(
          label: t.name.trim().isNotEmpty
              ? t.name.trim()
              : '#${t.tagId != 0 ? t.tagId : t.wrapperRowId}',
          color: _parseTagColor(t.color),
        ),
    ];

    return AppNotesContextRowData(
      categoryLabel: catLabel,
      categoryColor: catColor,
      tags: tagChips,
      saveStatus: saveData,
    );
  }

  NotesSaveStatusKind _mapStatus(_NotesStatus s) {
    switch (s) {
      case _NotesStatus.idle:
        return NotesSaveStatusKind.idle;
      case _NotesStatus.editing:
        return NotesSaveStatusKind.editing;
      case _NotesStatus.saving:
        return NotesSaveStatusKind.saving;
      case _NotesStatus.saved:
        return NotesSaveStatusKind.saved;
      case _NotesStatus.offlinePending:
        return NotesSaveStatusKind.offlinePending;
      case _NotesStatus.error:
        return NotesSaveStatusKind.error;
    }
  }

  Color? _parseTagColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  void _commitSave() {
    final updated = _buildDraftTask();
    if (updated == null) return;
    DatabaseService.instance.applyOptimisticPlanningTask(updated);
    DatabaseService.instance.notifyPlanningRefresh(scheduleNetworkRefresh: false);
    if (_isPersisted) {
      _gate.flush(() => unawaited(_syncDraftToBrain(updated)), force: true);
    }
    AppSnack.changesSaved();
    widget.onSaved?.call(updated);
    Navigator.of(context).pop<PlanningTask?>(updated);
  }

  void _close() {
    // Closing always flushes the latest draft so we never lose text.
    if (_isPersisted && _gate.isDirty) {
      _gate.flush(
        () {
          final latest = _buildDraftTask();
          if (latest != null) {
            unawaited(_syncDraftToBrain(latest));
          }
        },
        force: true,
      );
    }
    Navigator.of(context).pop<PlanningTask?>(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = currentLocale.value;
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    final body = SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: t(loc, 'cancel'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _close,
                ),
                const Spacer(),
                if (_tagsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_availableTags.isNotEmpty)
                  PopupMenuButton<Tag>(
                    tooltip: t(loc, 'notes_editor_tags_tooltip'),
                    icon: const Icon(Icons.label_outline_rounded),
                    onSelected: _toggleTag,
                    itemBuilder: (_) => [
                      for (final tag in _availableTags)
                        PopupMenuItem<Tag>(
                          value: tag,
                          child: Row(
                            children: [
                              Icon(
                                _selectedTags.any(
                                        (t) => t.tagId == tag.tagId)
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(tag.name.trim().isEmpty
                                  ? '#${tag.tagId}'
                                  : tag.name.trim()),
                            ],
                          ),
                        ),
                    ],
                  ),
                FilledButton.tonalIcon(
                  onPressed: _commitSave,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t(loc, 'save')),
                ),
              ],
            ),
          ),
          Expanded(
            child: AppNotesEditorSurface(
              titleController: _titleController,
              titleFocusNode: _titleFocus,
              quillController: _quillController,
              quillFocusNode: _quillFocus,
              quillScrollController: _quillScroll,
              contextRowData: _buildContextRowData(),
              onContextRowTap: _pickCategory,
              fallbackCategoryLabel: t(loc, 'notes_editor_uncategorized'),
              placeholder: (_) => t(loc, 'notes_hint_flat'),
              titleHint: t(loc, 'title_label'),
              autofocusTitle: false,
              toolbarActions: AppNotesToolbarActions(
                onInsertLink: _insertLink,
                onInsertDivider: _insertDivider,
                onCopyAsMarkdown: _copyAsMarkdown,
                onPasteFromMarkdown: _pasteFromMarkdown,
                tooltips: AppNotesToolbarTooltips(
                  insertLink: t(loc, 'notes_editor_insert_link_tooltip'),
                  insertDivider: t(loc, 'notes_editor_divider_tooltip'),
                  copyAsMarkdown: t(loc, 'notes_editor_copy_md_tooltip'),
                  pasteFromMarkdown: t(loc, 'notes_editor_paste_md_tooltip'),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      // Center the editor in a column on tablet / desktop / wide web.
      return Material(
        color: theme.colorScheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: body,
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      child: body,
    );
  }
}
