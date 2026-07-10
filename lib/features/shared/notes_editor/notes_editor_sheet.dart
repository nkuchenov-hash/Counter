// Notes editor sheet — Apple-Notes-style composition over the canonical
// notes widgets, wired to the existing Brain plan mutation paths.
//
// Design intent:
//   - One large comfortable editor surface for a plan/list note.
//   - Compact top bar: back + calm save status + More (...) menu.
//   - Compact context row: category chip + tags + save status.
//   - Single-row formatting toolbar (B/I/U/strike/lists/checklist/link native)
//     plus trailing divider, copy-as-markdown, paste-from-markdown, More.
//   - Debounced autosave via the existing EditSheetAutosaveGate (~800ms).
//   - On close: flush pending draft immediately; never lose the latest text.
//   - Never blocks typing on network I/O.
//
// Scope: this sheet is the PRIMARY editing experience for Lists/Notes. The
// legacy PlanningTaskEditSheet remains reachable as "Edit details" via the
// More menu and via the Lists `...` radial menu.

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
    this.onEditDetails,
  });

  /// Existing plan/list row to edit. Must already be persisted to PocketBase.
  final PlanningTask task;

  final ScrollController scrollController;

  /// Optional callback invoked after a successful background sync OR explicit
  /// Save with the latest draft.
  final void Function(PlanningTask updated)? onSaved;

  /// Optional callback invoked when the user taps the destructive action.
  final void Function(PlanningTask task)? onDeleted;

  /// Optional callback invoked when the user picks "Edit details" from the
  /// More menu. When null, the menu item is hidden (the host may not have a
  /// legacy edit sheet wired). The sheet closes itself before invoking this so
  /// only one modal is open at a time.
  final Future<void> Function(PlanningTask task)? onEditDetails;

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

  void _insertDivider() {
    final docLen = _quillController.document.length;
    final sel = _quillController.selection;
    final baseOffset = sel.baseOffset;
    final offset = (baseOffset.isFinite && baseOffset >= 0)
        ? baseOffset.clamp(0, docLen)
        : docLen;
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

  // ---- More menu --------------------------------------------------------

  Future<void> _openMoreMenu() async {
    final loc = currentLocale.value;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MoreSectionHeader(text: t(loc, 'notes_editor_group_format')),
              ListTile(
                leading: const Icon(Icons.content_copy_rounded),
                title: Text(t(loc, 'notes_editor_action_copy_md')),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  unawaited(_copyAsMarkdown());
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: Text(t(loc, 'notes_editor_action_paste_md')),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  unawaited(_pasteFromMarkdown());
                },
              ),
              ListTile(
                leading: const Icon(Icons.horizontal_rule_rounded),
                title: Text(t(loc, 'notes_editor_action_insert_divider')),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _insertDivider();
                },
              ),
              if (_isPersisted && widget.onDeleted != null) ...[
                _MoreSectionHeader(text: t(loc, 'notes_editor_group_danger')),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(sheetCtx).colorScheme.error,
                  ),
                  title: Text(
                    t(loc, 'notes_editor_action_delete'),
                    style: TextStyle(
                      color: Theme.of(sheetCtx).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _confirmDelete();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    if (!_isPersisted) return;
    final loc = currentLocale.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(loc, 'notes_editor_action_delete')),
        content: Text(widget.task.title.trim().isEmpty
            ? t(loc, 'delete')
            : widget.task.title.trim()),
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
    final task = widget.task;
    widget.onDeleted?.call(task);
    if (mounted) Navigator.of(context).pop();
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
          return _lastSavedLabel ?? t(loc, 'notes_editor_status_idle');
        case NotesSaveStatusKind.editing:
          return t(loc, 'notes_editor_status_editing');
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
    final scheme = theme.colorScheme;

    // Compact top bar: back + center status + More (...).
    final topBar = Material(
      color: scheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: t(loc, 'notes_editor_back_tooltip'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _close,
                ),
                // Tags quick-access (compact). Hidden while loading.
                if (!_tagsLoading && _availableTags.isNotEmpty)
                  IconButton(
                    tooltip: t(loc, 'notes_editor_tags_tooltip'),
                    icon: const Icon(Icons.label_outline_rounded),
                    onPressed: _openTagsPicker,
                  ),
                const Spacer(),
                // Calm center save status — no unexplained spinner.
                AppNotesSaveStatus(
                  data: _buildContextRowData().saveStatus,
                  onRetry: () =>
                      _buildDraftTask() != null && _isPersisted
                          ? unawaited(
                              _syncDraftToBrain(_buildDraftTask()!),
                            )
                          : null,
                ),
                const Spacer(),
                // More (...) menu.
                IconButton(
                  tooltip: t(loc, 'notes_editor_more_tooltip'),
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: _openMoreMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final body = Column(
      children: [
        topBar,
        Expanded(
          child: AppNotesEditorSurface(
            titleController: _titleController,
            titleFocusNode: _titleFocus,
            quillController: _quillController,
            quillFocusNode: _quillFocus,
            quillScrollController: _quillScroll,
            contextRowData: _buildContextRowData(),
            onContextRowTap: _pickCategory,
            placeholder: (_) => t(loc, 'notes_editor_placeholder_empty'),
            titleHint: t(loc, 'notes_editor_title_hint'),
            autofocusTitle: false,
            toolbarActions: AppNotesToolbarActions(
              onInsertDivider: _insertDivider,
              onCopyAsMarkdown: _copyAsMarkdown,
              onPasteFromMarkdown: _pasteFromMarkdown,
              onOpenMore: _openMoreMenu,
              tooltips: AppNotesToolbarTooltips(
                insertDivider: t(loc, 'notes_editor_divider_tooltip'),
                copyAsMarkdown: t(loc, 'notes_editor_copy_md_tooltip'),
                pasteFromMarkdown: t(loc, 'notes_editor_paste_md_tooltip'),
                more: t(loc, 'notes_editor_more_tooltip'),
              ),
            ),
          ),
        ),
      ],
    );

    // The sheet does NOT center or constrain itself — the route host owns
    // layout (full screen on mobile; centered max-width column with a bounded
    // height on wide screens). Re-wrapping here caused nested
    // Center/ConstrainedBox + Expanded constraint conflicts that collapsed the
    // toolbar below the visible viewport on web.
    return Material(color: scheme.surface, child: body);
  }

  // ---- Tags picker (compact sheet) --------------------------------------

  Future<void> _openTagsPicker() async {
    final loc = currentLocale.value;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    t(loc, 'notes_editor_tags_tooltip'),
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                ..._availableTags.map(
                  (tag) {
                    final selected =
                        _selectedTags.any((t) => t.tagId == tag.tagId);
                    return CheckboxListTile(
                      value: selected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(tag.name.trim().isEmpty
                          ? '#${tag.tagId}'
                          : tag.name.trim()),
                      onChanged: (_) => _toggleTag(tag),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---- More-menu helper widgets -------------------------------------------

class _MoreSectionHeader extends StatelessWidget {
  const _MoreSectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
