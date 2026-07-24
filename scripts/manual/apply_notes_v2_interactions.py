from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Expected snippet not found in {path}: {old[:140]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def append_map_entries(path: str, entries: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if "'notes_tools_create_plan'" in text:
        return
    index = text.rfind("};")
    if index < 0:
        raise RuntimeError(f"Map end not found in {path}")
    file.write_text(text[:index] + entries + "\n" + text[index:], encoding="utf-8")


# History state and local-first undo/redo.
replace(
    "lib/features/notes/note_editor_page.dart",
    """  List<Tag> _availableTags = const [];
  bool _tagsLoading = true;
""",
    """  List<Tag> _availableTags = const [];
  bool _tagsLoading = true;
  final List<NoteDocument> _undoStack = <NoteDocument>[];
  final List<NoteDocument> _redoStack = <NoteDocument>[];
  DateTime? _lastHistoryPushAt;
  bool _replayingHistory = false;
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """  }) {
    setState(() {
      _doc = next;
""",
    """  }) {
    if (!_replayingHistory && !identical(next, _doc)) {
      final now = DateTime.now();
      final structuralChange = next.blocks.length != _doc.blocks.length ||
          _hasBlockStructureChanged(_doc, next);
      if (structuralChange ||
          _lastHistoryPushAt == null ||
          now.difference(_lastHistoryPushAt!) > const Duration(milliseconds: 700)) {
        _undoStack.add(_doc);
        if (_undoStack.length > 80) _undoStack.removeAt(0);
        _redoStack.clear();
        _lastHistoryPushAt = now;
      }
    }
    setState(() {
      _doc = next;
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """  void _syncToBrain() {
""",
    """  bool _hasBlockStructureChanged(NoteDocument before, NoteDocument after) {
    if (before.blocks.length != after.blocks.length) return true;
    for (var index = 0; index < before.blocks.length; index++) {
      final a = before.blocks[index];
      final b = after.blocks[index];
      if (a.id != b.id || a.type != b.type || a.level != b.level) return true;
    }
    return false;
  }

  void _replayHistory(NoteDocument target, List<NoteDocument> destination) {
    destination.add(_doc);
    _replayingHistory = true;
    setState(() {
      _doc = target;
      if (!_doc.blocks.any((block) => block.id == _activeBlockId)) {
        _activeBlockId = _doc.blocks.firstOrNull?.id;
      }
      _status = _SaveStatus.editing;
    });
    _replayingHistory = false;
    _gate.schedule(_syncToBrain);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _replayHistory(_undoStack.removeLast(), _redoStack);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _replayHistory(_redoStack.removeLast(), _undoStack);
  }

  void _syncToBrain() {
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """  void _moveBlock(String id, int dir) {
""",
    """  void _duplicateBlock(String id) {
    final blocks = List<NoteBlock>.from(_doc.blocks);
    final index = blocks.indexWhere((block) => block.id == id);
    if (index < 0) return;
    final source = blocks[index];
    final copy = NoteBlock.fromJson({
      ...source.toJson(),
      'id': generateNoteBlockId(),
    });
    blocks.insert(index + 1, copy);
    _mutate(_doc.copyWith(blocks: blocks));
    setState(() => _activeBlockId = copy.id);
  }

  void _createPlanFromText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(currentLocale.value, 'notes_tools_plan_created'))),
    );
    unawaited(
      DatabaseService.instance.addPlanningTaskFromVoiceText(
        rawText: text,
        wallDay: DateTime.now(),
        categoryIdHint: _task.categoryId,
        isBacklog: true,
      ),
    );
  }

  void _moveBlock(String id, int dir) {
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """                  onMoveDown: () => _moveBlock(b.id, 1),
                  onEditDrawing: () => _openDrawing(editBlockId: b.id),
                  onEnter: () {
""",
    """                  onMoveDown: () => _moveBlock(b.id, 1),
                  onDuplicate: () => _duplicateBlock(b.id),
                  onCreatePlanFromText: _createPlanFromText,
                  onAddImage: _pickImage,
                  onAddDrawing: () => _openDrawing(),
                  onEditDrawing: () => _openDrawing(editBlockId: b.id),
                  onEnter: () {
""",
)
replace(
    "lib/features/notes/note_editor_page.dart",
    """          onImage: _pickImage,
          onDraw: () => _openDrawing(),
        ),
""",
    """          onImage: _pickImage,
          onDraw: () => _openDrawing(),
          onUndo: _undoStack.isEmpty ? null : _undo,
          onRedo: _redoStack.isEmpty ? null : _redo,
        ),
""",
)

# Block row API and slash command palette.
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    required this.onMoveDown,
    required this.onEditDrawing,
    required this.onEnter,
""",
    """    required this.onMoveDown,
    required this.onDuplicate,
    required this.onCreatePlanFromText,
    required this.onAddImage,
    required this.onAddDrawing,
    required this.onEditDrawing,
    required this.onEnter,
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  final VoidCallback onMoveDown;
  final VoidCallback onEditDrawing;
  final VoidCallback onEnter;
""",
    """  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final ValueChanged<String> onCreatePlanFromText;
  final VoidCallback onAddImage;
  final VoidCallback onAddDrawing;
  final VoidCallback onEditDrawing;
  final VoidCallback onEnter;
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  late FocusNode _focusNode;
""",
    """  late FocusNode _focusNode;
  String _slashQuery = '';
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onActivate,
      child: Container(
""",
    """    final slashCommands = _filteredSlashCommands(_slashQuery, loc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onActivate,
          child: Container(
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """                onChanged: (v) =>
                    widget.onUpdate(NoteEditorBlockPatch(text: v)),
""",
    """                onChanged: (value) {
                  final slash = value.startsWith('/') ? value.substring(1) : '';
                  if (_slashQuery != slash) setState(() => _slashQuery = slash);
                  widget.onUpdate(NoteEditorBlockPatch(text: value));
                },
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """                onMoveDown: widget.onMoveDown,
                onDelete: widget.onDelete,
                loc: loc,
""",
    """                onMoveDown: widget.onMoveDown,
                onDuplicate: widget.onDuplicate,
                onCreatePlan: () {
                  final selection = _textController.selection;
                  final text = selection.isValid && !selection.isCollapsed
                      ? _textController.text.substring(
                          selection.start.clamp(0, _textController.text.length),
                          selection.end.clamp(0, _textController.text.length),
                        )
                      : _textController.text;
                  widget.onCreatePlanFromText(text);
                },
                onDelete: widget.onDelete,
                loc: loc,
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """          ],
        ),
      ),
    );
  }
}

class _NoteEditorBlockActiveControls extends StatelessWidget {
""",
    """          ],
        ),
      ),
        if (_textController.text.startsWith('/') && slashCommands.isNotEmpty)
          _NotesSlashCommandMenu(
            commands: slashCommands,
            onSelect: (command) {
              setState(() => _slashQuery = '');
              if (command.type == NoteBlockType.image) {
                widget.onUpdate(const NoteEditorBlockPatch(text: ''));
                widget.onAddImage();
                return;
              }
              if (command.type == NoteBlockType.drawing) {
                widget.onUpdate(const NoteEditorBlockPatch(text: ''));
                widget.onAddDrawing();
                return;
              }
              widget.onUpdate(
                NoteEditorBlockPatch(
                  type: command.type,
                  text: '',
                  level: command.headingLevel,
                  table: command.type == NoteBlockType.table
                      ? NoteTableData.empty(rows: 3, columns: 3)
                      : NoteEditorBlockPatch._unset,
                  callout: command.type == NoteBlockType.callout
                      ? const NoteCalloutData(type: NoteCalloutType.idea)
                      : NoteEditorBlockPatch._unset,
                  codeLanguage: command.type == NoteBlockType.codeBlock
                      ? 'plain'
                      : NoteEditorBlockPatch._unset,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _NoteEditorBlockActiveControls extends StatelessWidget {
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    required this.onMoveDown,
    required this.onDelete,
    required this.loc,
""",
    """    required this.onMoveDown,
    required this.onDuplicate,
    required this.onCreatePlan,
    required this.onDelete,
    required this.loc,
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final String loc;
""",
    """  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onCreatePlan;
  final VoidCallback onDelete;
  final String loc;
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """        if (canMoveDown)
          _NoteEditorBlockControlBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: t(loc, 'notes_v3_editor_move_down'),
            onTap: onMoveDown,
          ),
        _NoteEditorBlockControlBtn(
""",
    """        if (canMoveDown)
          _NoteEditorBlockControlBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: t(loc, 'notes_v3_editor_move_down'),
            onTap: onMoveDown,
          ),
        _NoteEditorBlockControlBtn(
          icon: Icons.copy_rounded,
          tooltip: t(loc, 'notes_tools_duplicate'),
          onTap: onDuplicate,
        ),
        _NoteEditorBlockControlBtn(
          icon: Icons.event_note_outlined,
          tooltip: t(loc, 'notes_tools_create_plan'),
          onTap: onCreatePlan,
        ),
        _NoteEditorBlockControlBtn(
""",
)

# Append slash menu types/widgets before active controls.
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """class _NoteEditorBlockActiveControls extends StatelessWidget {
""",
    """class _NotesSlashCommand {
  const _NotesSlashCommand({
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

List<_NotesSlashCommand> _filteredSlashCommands(String query, String loc) {
  final commands = <_NotesSlashCommand>[
    _NotesSlashCommand(command: 'text', label: t(loc, 'notes_tools_body'), icon: Icons.text_fields_rounded, type: NoteBlockType.paragraph),
    _NotesSlashCommand(command: 'heading', label: 'H2', icon: Icons.title_rounded, type: NoteBlockType.heading, headingLevel: 2),
    _NotesSlashCommand(command: 'checklist', label: t(loc, 'notes_v3_editor_add_checklist'), icon: Icons.checklist_rounded, type: NoteBlockType.checklist),
    _NotesSlashCommand(command: 'bullets', label: t(loc, 'notes_tools_bullets'), icon: Icons.format_list_bulleted_rounded, type: NoteBlockType.bulletedList),
    _NotesSlashCommand(command: 'numbers', label: t(loc, 'notes_tools_numbers'), icon: Icons.format_list_numbered_rounded, type: NoteBlockType.numberedList),
    _NotesSlashCommand(command: 'quote', label: t(loc, 'notes_tools_quote'), icon: Icons.format_quote_rounded, type: NoteBlockType.quote),
    _NotesSlashCommand(command: 'callout', label: t(loc, 'notes_tools_callout'), icon: Icons.lightbulb_outline_rounded, type: NoteBlockType.callout),
    _NotesSlashCommand(command: 'table', label: t(loc, 'notes_tools_table'), icon: Icons.table_chart_outlined, type: NoteBlockType.table),
    _NotesSlashCommand(command: 'image', label: t(loc, 'notes_v3_editor_add_image'), icon: Icons.image_outlined, type: NoteBlockType.image),
    _NotesSlashCommand(command: 'draw', label: t(loc, 'notes_v3_editor_add_draw'), icon: Icons.draw_outlined, type: NoteBlockType.drawing),
    _NotesSlashCommand(command: 'code', label: t(loc, 'notes_tools_code_block'), icon: Icons.code_rounded, type: NoteBlockType.codeBlock),
    _NotesSlashCommand(command: 'collapse', label: t(loc, 'notes_tools_collapsible'), icon: Icons.expand_more_rounded, type: NoteBlockType.collapsible),
    _NotesSlashCommand(command: 'divider', label: t(loc, 'notes_tools_divider'), icon: Icons.horizontal_rule_rounded, type: NoteBlockType.divider),
  ];
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return commands;
  return commands
      .where((item) => item.command.contains(normalized) || item.label.toLowerCase().contains(normalized))
      .toList(growable: false);
}

class _NotesSlashCommandMenu extends StatelessWidget {
  const _NotesSlashCommandMenu({required this.commands, required this.onSelect});
  final List<_NotesSlashCommand> commands;
  final ValueChanged<_NotesSlashCommand> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8, left: 24, right: 24),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 18, offset: Offset(0, 8))],
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
            title: Text(command.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: Text('/${command.command}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            onTap: () => onSelect(command),
          );
        },
      ),
    );
  }
}

class _NoteEditorBlockActiveControls extends StatelessWidget {
""",
)

# Localized interaction labels.
append_map_entries(
    "lib/l10n/langs/en.dart",
    """
    'notes_tools_duplicate': 'Duplicate block',
    'notes_tools_create_plan': 'Create plan from selection',
    'notes_tools_plan_created': 'Plan added to Lists',
""",
)
append_map_entries(
    "lib/l10n/langs/ru.dart",
    """
    'notes_tools_duplicate': 'Дублировать блок',
    'notes_tools_create_plan': 'Создать план из выделения',
    'notes_tools_plan_created': 'План добавлен в Списки',
""",
)

print('Notes v2 interaction patch applied')
