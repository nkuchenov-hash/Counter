// Full-screen Notes editor — intentionally text-only.
//
// The experimental formatting, block, media, drawing, table, slash-command,
// selection and insertion systems are not part of the production editor.
// Existing non-text payloads remain preserved as opaque legacy data, but the
// editing surface exposes only a title and one continuous plain-text body.

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

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
  late final String _bodyBlockId;
  late final List<NoteBlock> _retainedLegacyBlocks;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final EditSheetAutosaveGate _gate;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _sourceDocument = DatabaseService.instance.parseNoteDocument(_task);
    final textualBlocks = _sourceDocument.blocks
        .where((block) => block.hasText)
        .toList(growable: false);
    _bodyBlockId = textualBlocks.isNotEmpty
        ? textualBlocks.first.id
        : generateNoteBlockId();
    _retainedLegacyBlocks = _sourceDocument.blocks
        .where((block) => !block.hasText)
        .toList(growable: false);
    _titleController = TextEditingController(text: _task.title);
    _bodyController = TextEditingController(
      text: textualBlocks
          .map((block) => block.effectiveText.trimRight())
          .where((text) => text.trim().isNotEmpty)
          .join('\n\n'),
    );
    _gate = EditSheetAutosaveGate();
  }

  @override
  void dispose() {
    if (_dirty && !widget.parityPreview) {
      _gate.flush(_syncToBrain, force: true);
    }
    _gate.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    widget.onClosed?.call();
    super.dispose();
  }

  NoteDocument _currentDocument() {
    final blocks = <NoteBlock>[];
    final body = _bodyController.text;
    if (body.isNotEmpty || _retainedLegacyBlocks.isEmpty) {
      blocks.add(
        NoteBlock(
          id: _bodyBlockId,
          type: NoteBlockType.paragraph,
          text: body,
        ),
      );
    }
    blocks.addAll(_retainedLegacyBlocks);
    return NoteDocument(meta: _sourceDocument.meta, blocks: blocks);
  }

  void _scheduleSave(String _) {
    _dirty = true;
    _gate.schedule(_syncToBrain);
  }

  void _syncToBrain() {
    if (!_dirty || widget.parityPreview) return;
    final title = _titleController.text.trim();
    final document = _currentDocument();
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

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: NotesGlmBackground(
        child: SafeArea(
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
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 24 : 20,
                        8,
                        wide ? 24 : 20,
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
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
                          const SizedBox(height: 18),
                          Expanded(
                            child: TextField(
                              controller: _bodyController,
                              autofocus: false,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              textAlignVertical: TextAlignVertical.top,
                              onChanged: _scheduleSave,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: t(
                                  loc,
                                  'notes_v3_editor_start_writing',
                                ),
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  height: 1.55,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
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
