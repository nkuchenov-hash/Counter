from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Expected snippet not found in {path}: {old[:160]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def append_map_entries(path: str, marker: str, entries: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if marker in text:
        return
    index = text.rfind("};")
    if index < 0:
        raise RuntimeError(f"Locale map end not found in {path}")
    file.write_text(text[:index] + entries + "\n" + text[index:], encoding="utf-8")


block_file = "lib/features/notes/widgets/note_editor_block_widgets.dart"
tools_file = "lib/features/notes/widgets/notes_editor_tools.dart"

replace(
    block_file,
    "import 'dart:convert';\n",
    "import 'dart:async';\nimport 'dart:convert';\n",
)
replace(
    block_file,
    "import 'package:counter/data/models.dart';\n",
    "import 'package:counter/data/database_service.dart';\nimport 'package:counter/data/models.dart';\n",
)
replace(
    block_file,
    """/// Partial update for a single [NoteBlock], applied by the editor page.
class NoteEditorBlockPatch {
""",
    """/// Bridges the fixed primary toolbar to Flutter's active text undo stack.
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
""",
)
replace(
    block_file,
    """  late _NoteRichTextController _textController;
  late FocusNode _focusNode;
""",
    """  late _NoteRichTextController _textController;
  late FocusNode _focusNode;
  late UndoHistoryController _undoController;
""",
)
replace(
    block_file,
    """    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) widget.onActivate();
      if (mounted) setState(() {});
    });
""",
    """    _undoController = UndoHistoryController();
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
""",
)
replace(
    block_file,
    """    _focusNode.dispose();
    super.dispose();
""",
    """    NotesTextUndoBridge.detach(_undoController);
    _undoController.dispose();
    _focusNode.dispose();
    super.dispose();
""",
)
replace(
    block_file,
    """  void _applySlashCommand(_SlashCommand command) {
""",
    """  void _createPlanFromSelectionOrBlock() {
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
""",
)
replace(
    block_file,
    """            onHighlight: () =>
                _toggleInlineMark(_InlineMarkAction.highlight),
            onLink: _editInlineLink,
          ),
""",
    """            onHighlight: () =>
                _toggleInlineMark(_InlineMarkAction.highlight),
            onLink: _editInlineLink,
            onCreatePlan: _createPlanFromSelectionOrBlock,
          ),
""",
)
replace(
    block_file,
    """                    textCapitalization: TextCapitalization.sentences,
                    style: textStyle.copyWith(
""",
    """                    textCapitalization: TextCapitalization.sentences,
                    undoController: _undoController,
                    style: textStyle.copyWith(
""",
)
replace(
    block_file,
    """                    onConvert: _convertBlock,
                    onDelete: widget.onDelete,
""",
    """                    onConvert: _convertBlock,
                    onCreatePlan: _createPlanFromSelectionOrBlock,
                    onDelete: widget.onDelete,
""",
)
replace(
    block_file,
    """    required this.onHighlight,
    required this.onLink,
  });
""",
    """    required this.onHighlight,
    required this.onLink,
    required this.onCreatePlan,
  });
""",
)
replace(
    block_file,
    """  final VoidCallback onHighlight;
  final VoidCallback onLink;
""",
    """  final VoidCallback onHighlight;
  final VoidCallback onLink;
  final VoidCallback onCreatePlan;
""",
)
replace(
    block_file,
    """            _SelectionToolButton(
              icon: Icons.link_rounded,
              selected: _all((marks) => marks.link != null),
              onTap: onLink,
            ),
""",
    """            _SelectionToolButton(
              icon: Icons.link_rounded,
              selected: _all((marks) => marks.link != null),
              onTap: onLink,
            ),
            _SelectionToolButton(
              icon: Icons.event_note_outlined,
              selected: false,
              onTap: onCreatePlan,
            ),
""",
)
replace(
    block_file,
    """    required this.onConvert,
    required this.onDelete,
""",
    """    required this.onConvert,
    required this.onCreatePlan,
    required this.onDelete,
""",
)
replace(
    block_file,
    """  final ValueChanged<NoteBlockType> onConvert;
  final VoidCallback onDelete;
""",
    """  final ValueChanged<NoteBlockType> onConvert;
  final VoidCallback onCreatePlan;
  final VoidCallback onDelete;
""",
)
replace(
    block_file,
    """        _NoteEditorBlockControlBtn(
          icon: Icons.delete_outline_rounded,
""",
    """        _NoteEditorBlockControlBtn(
          icon: Icons.event_note_outlined,
          tooltip: t(loc, 'notes_tools_create_plan'),
          onTap: onCreatePlan,
        ),
        _NoteEditorBlockControlBtn(
          icon: Icons.delete_outline_rounded,
""",
)

replace(
    tools_file,
    "import 'package:counter/features/notes/notes_visual_tokens.dart';\n",
    """import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/features/notes/widgets/note_editor_block_widgets.dart'
    show NotesTextUndoBridge;
""",
)
replace(
    tools_file,
    """                    onTap: widget.onUndo,
""",
    """                    onTap: widget.onUndo ?? NotesTextUndoBridge.undo,
""",
)
replace(
    tools_file,
    """                    onTap: widget.onRedo,
""",
    """                    onTap: widget.onRedo ?? NotesTextUndoBridge.redo,
""",
)

append_map_entries(
    "lib/l10n/langs/en.dart",
    "'notes_tools_create_plan'",
    """
    'notes_tools_create_plan': 'Create plan from selection',
    'notes_tools_plan_created': 'Plan added to Lists',
""",
)
append_map_entries(
    "lib/l10n/langs/ru.dart",
    "'notes_tools_create_plan'",
    """
    'notes_tools_create_plan': 'Создать план из выделения',
    'notes_tools_plan_created': 'План добавлен в Списки',
""",
)

print("Final Notes v2 actions applied")
