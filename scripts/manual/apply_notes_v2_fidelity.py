from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Expected snippet not found in {path}: {old[:180]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


# Pure run-preserving text edit helper.
replace(
    "lib/data/models/note_rich_types.dart",
    """const Object _noteRichUnset = Object();
""",
    """/// Applies a plain-text insertion/deletion/replacement while preserving
/// unaffected inline marks. Inserted text inherits the marks at the edit point.
List<NoteTextRun> applyNoteTextEditToRuns({
  required String oldText,
  required List<NoteTextRun> oldRuns,
  required String newText,
}) {
  if (oldText == newText) return List<NoteTextRun>.unmodifiable(oldRuns);
  if (newText.isEmpty) return const <NoteTextRun>[];

  final normalizedRuns = oldRuns.isNotEmpty &&
          oldRuns.map((run) => run.text).join() == oldText
      ? oldRuns
      : oldText.isEmpty
          ? const <NoteTextRun>[]
          : <NoteTextRun>[NoteTextRun(text: oldText)];

  var prefix = 0;
  final sharedLength = math.min(oldText.length, newText.length);
  while (prefix < sharedLength && oldText[prefix] == newText[prefix]) {
    prefix++;
  }

  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      suffix < newText.length - prefix &&
      oldText[oldText.length - 1 - suffix] ==
          newText[newText.length - 1 - suffix]) {
    suffix++;
  }

  final oldEditEnd = oldText.length - suffix;
  final newEditEnd = newText.length - suffix;
  final inserted = newText.substring(prefix, newEditEnd);
  final result = <NoteTextRun>[
    ..._sliceNoteRuns(normalizedRuns, 0, prefix),
  ];

  if (inserted.isNotEmpty) {
    final inheritedOffset = oldEditEnd > prefix
        ? prefix
        : prefix > 0
            ? prefix - 1
            : oldEditEnd < oldText.length
                ? oldEditEnd
                : -1;
    result.add(
      NoteTextRun(
        text: inserted,
        marks: _noteMarksAt(normalizedRuns, inheritedOffset),
      ),
    );
  }

  result.addAll(_sliceNoteRuns(normalizedRuns, oldEditEnd, oldText.length));
  return List<NoteTextRun>.unmodifiable(_mergeNoteRuns(result));
}

List<NoteTextRun> _sliceNoteRuns(
  List<NoteTextRun> runs,
  int start,
  int end,
) {
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
  return result;
}

NoteInlineMarks _noteMarksAt(List<NoteTextRun> runs, int offset) {
  if (offset < 0) return const NoteInlineMarks();
  var cursor = 0;
  for (final run in runs) {
    final end = cursor + run.text.length;
    if (offset >= cursor && offset < end) return run.marks;
    cursor = end;
  }
  return runs.isEmpty ? const NoteInlineMarks() : runs.last.marks;
}

List<NoteTextRun> _mergeNoteRuns(List<NoteTextRun> runs) {
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
  return result;
}

const Object _noteRichUnset = Object();
""",
)

# Keep editor-local runs in sync so ordinary typing does not flatten marks.
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  TextSelection _selection = const TextSelection.collapsed(offset: -1);
  String _slashQuery = '';
""",
    """  TextSelection _selection = const TextSelection.collapsed(offset: -1);
  String _slashQuery = '';
  late String _editingText;
  late List<NoteTextRun> _editingRuns;
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    _textController = _NoteRichTextController(
      text: widget.block.effectiveText,
      runs: widget.block.effectiveRuns,
    )..addListener(_handleControllerState);
""",
    """    _editingText = widget.block.effectiveText;
    _editingRuns = List<NoteTextRun>.unmodifiable(widget.block.effectiveRuns);
    _textController = _NoteRichTextController(
      text: _editingText,
      runs: _editingRuns,
    )..addListener(_handleControllerState);
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    final nextText = widget.block.effectiveText;
    final oldText = oldWidget.block.effectiveText;
    _textController.setRuns(widget.block.effectiveRuns);
    if (oldWidget.block.id != widget.block.id) {
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    } else if (nextText != _textController.text && nextText != oldText) {
      final offset = _textController.selection.extentOffset
          .clamp(0, nextText.length)
          .toInt();
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
""",
    """    final nextText = widget.block.effectiveText;
    final nextRuns = widget.block.effectiveRuns;
    final blockChanged = oldWidget.block.id != widget.block.id;
    final contentChanged = nextText != _editingText ||
        !_noteRunsEquivalent(nextRuns, _editingRuns);
    if (blockChanged || contentChanged) {
      _editingText = nextText;
      _editingRuns = List<NoteTextRun>.unmodifiable(nextRuns);
      _textController.setRuns(_editingRuns);
    }
    if (blockChanged) {
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    } else if (nextText != _textController.text) {
      final offset = _textController.selection.extentOffset
          .clamp(0, nextText.length)
          .toInt();
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """  List<NoteTextRun> _sourceRuns() {
    final runs = widget.block.effectiveRuns;
    if (runs.isNotEmpty &&
        runs.map((run) => run.text).join() == _textController.text) {
      return runs;
    }
    if (_textController.text.isEmpty) return const <NoteTextRun>[];
    return <NoteTextRun>[NoteTextRun(text: _textController.text)];
  }
""",
    """  List<NoteTextRun> _sourceRuns() {
    if (_editingRuns.map((run) => run.text).join() == _textController.text) {
      return _editingRuns;
    }
    if (_textController.text.isEmpty) return const <NoteTextRun>[];
    return <NoteTextRun>[NoteTextRun(text: _textController.text)];
  }
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    widget.onUpdate(
      NoteEditorBlockPatch(text: _textController.text, runs: runs),
    );
  }

  Future<void> _editInlineLink() async {
""",
    """    _editingRuns = List<NoteTextRun>.unmodifiable(runs);
    _textController.setRuns(_editingRuns);
    widget.onUpdate(
      NoteEditorBlockPatch(text: _textController.text, runs: _editingRuns),
    );
  }

  Future<void> _editInlineLink() async {
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """    widget.onUpdate(
      NoteEditorBlockPatch(text: _textController.text, runs: runs),
    );
  }

  void _createPlanFromSelectionOrBlock() {
""",
    """    _editingRuns = List<NoteTextRun>.unmodifiable(runs);
    _textController.setRuns(_editingRuns);
    widget.onUpdate(
      NoteEditorBlockPatch(text: _textController.text, runs: _editingRuns),
    );
  }

  void _createPlanFromSelectionOrBlock() {
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """                    onChanged: (value) => widget.onUpdate(
                      NoteEditorBlockPatch(
                        text: value,
                        runs: const <NoteTextRun>[],
                      ),
                    ),
""",
    """                    onChanged: (value) {
                      final nextRuns = applyNoteTextEditToRuns(
                        oldText: _editingText,
                        oldRuns: _editingRuns,
                        newText: value,
                      );
                      _editingText = value;
                      _editingRuns = nextRuns;
                      _textController.setRuns(nextRuns);
                      widget.onUpdate(
                        NoteEditorBlockPatch(text: value, runs: nextRuns),
                      );
                    },
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
""",
    """class NotesSelectionToolbar extends StatelessWidget {
  const NotesSelectionToolbar({
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """          _SelectionToolbar(
""",
    """          NotesSelectionToolbar(
""",
)
replace(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    """List<NoteTextRun> _mergeRuns(List<NoteTextRun> source) {
""",
    """bool _noteRunsEquivalent(List<NoteTextRun> a, List<NoteTextRun> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index].text != b[index].text ||
        a[index].marks.toJson().toString() !=
            b[index].marks.toJson().toString()) {
      return false;
    }
  }
  return true;
}

List<NoteTextRun> _mergeRuns(List<NoteTextRun> source) {
""",
)

# Test-only deterministic initial panel support, still a useful public preview API.
replace(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    """    this.onUndo,
    this.onRedo,
  });
""",
    """    this.onUndo,
    this.onRedo,
    this.initialPanel = NotesToolsPanel.none,
  });
""",
)
replace(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    """  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
""",
    """  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final NotesToolsPanel initialPanel;
""",
)
replace(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    """class _NotesEditorToolsDockState extends State<NotesEditorToolsDock> {
  NotesToolsPanel _panel = NotesToolsPanel.none;
""",
    """class _NotesEditorToolsDockState extends State<NotesEditorToolsDock> {
  late NotesToolsPanel _panel;

  @override
  void initState() {
    super.initState();
    _panel = widget.initialPanel;
  }
""",
)

# Extend the existing second focused model test rather than adding another
# logic test.
replace(
    "test/note_document_v2_test.dart",
    """      expect(block.runs.last.marks.highlightColor, '#FFF2A8');
    });
""",
    """      expect(block.runs.last.marks.highlightColor, '#FFF2A8');

      final editedRuns = applyNoteTextEditToRuns(
        oldText: block.effectiveText,
        oldRuns: block.runs,
        newText: 'Read the verified source',
      );
      expect(editedRuns.map((run) => run.text).join(), 'Read the verified source');
      expect(editedRuns.first.marks.bold, isTrue);
      expect(editedRuns.last.marks.underline, isTrue);
      expect(editedRuns.last.marks.link, 'https://example.com');
    });
""",
)

print("Notes v2 rich-text fidelity patch applied")
