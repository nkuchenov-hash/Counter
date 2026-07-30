from __future__ import annotations

from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one anchor, found {count}: {old[:140]!r}")
    write(path, content.replace(old, new, 1))


write(
    "lib/features/dev/component_lab_notes_demo.dart",
    dedent(
        r'''part of 'component_lab_view.dart';

class ComponentLabNotesDemo extends StatefulWidget {
  const ComponentLabNotesDemo({super.key});

  @override
  State<ComponentLabNotesDemo> createState() => _ComponentLabNotesDemoState();
}

class _ComponentLabNotesDemoState extends State<ComponentLabNotesDemo> {
  final _h1 = TextEditingController(text: 'Quarterly planning');
  final _h2 = TextEditingController(text: 'Priority outcomes');
  final _h3 = TextEditingController(text: 'Operating notes');
  final _body = NotesTextEditingController(
    runs: const [
      NoteTextRun(
        text: 'Shared responsive block with ',
        marks: NoteInlineMarks(),
      ),
      NoteTextRun(
        text: 'inline formatting',
        marks: NoteInlineMarks(bold: true, highlightColor: '#FFF3B0'),
      ),
      NoteTextRun(text: ' and stable IDs.', marks: NoteInlineMarks()),
    ],
  );
  final _list = TextEditingController(
    text: 'One list component wraps consistently on narrow and wide layouts.',
  );
  final _checklist = TextEditingController(text: 'Review the final note flow');
  final _quote = TextEditingController(
    text: 'The editor should feel like one continuous sheet.',
  );
  final _caption = TextEditingController(text: 'Caption remains outside selection');

  bool _checked = false;
  NoteTableData _table = NoteTableData.empty(rows: 2, columns: 3);
  NotesAudioState _audioState = NotesAudioState.ready;
  NotesRecorderState _recorderState = NotesRecorderState.ready;
  NotesDrawingTool _drawingTool = NotesDrawingTool.pen;
  Color _drawingColor = const Color(0xFF0F172A);
  double _strokeWidth = 4;
  Set<NotesInlineFormat> _formats = const {NotesInlineFormat.bold};

  @override
  void dispose() {
    _h1.dispose();
    _h2.dispose();
    _h3.dispose();
    _body.dispose();
    _list.dispose();
    _checklist.dispose();
    _quote.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Production canonical Notes components. The same widgets are used on mobile, web, and desktop; only constraints change.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _LabExample(
              title: 'Notes / Continuous document',
              flutterMapping: 'NotesTextBlock + NotesListBlock + NotesChecklistBlock',
              variant: 'shared responsive',
              state: 'active / default',
              fullWidth: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NotesTextBlock(
                      controller: _h1,
                      style: NotesTextBlockStyle.h1,
                      state: NotesBlockState.active,
                    ),
                    NotesTextBlock(
                      controller: _h2,
                      style: NotesTextBlockStyle.h2,
                    ),
                    NotesTextBlock(
                      controller: _h3,
                      style: NotesTextBlockStyle.h3,
                    ),
                    NotesTextBlock(controller: _body),
                    NotesListBlock(
                      controller: _list,
                      listStyle: NotesListStyle.numbered,
                      ordinal: 2,
                    ),
                    NotesChecklistBlock(
                      controller: _checklist,
                      checked: _checked,
                      onCheckedChanged: (value) =>
                          setState(() => _checked = value),
                    ),
                  ],
                ),
              ),
            ),
            _LabExample(
              title: 'Notes / Structural blocks',
              flutterMapping: 'NotesQuoteBlock + NotesDividerBlock + NotesTableBlock',
              variant: 'quote / divider / editable table',
              fullWidth: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NotesQuoteBlock(
                    textController: _quote,
                    state: NotesBlockState.active,
                  ),
                  const NotesDividerBlock(),
                  NotesTableBlock(
                    data: _table,
                    state: NotesBlockState.active,
                    onChanged: (value) => setState(() => _table = value),
                  ),
                ],
              ),
            ),
            _LabExample(
              title: 'Notes / Image and audio states',
              flutterMapping: 'NotesMediaBlock + NotesAudioBlock',
              variant: 'frame-only selection / persisted audio',
              fullWidth: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NotesMediaBlock(
                    kind: NotesMediaKind.image,
                    state: NotesBlockState.active,
                    captionController: _caption,
                    media: SizedBox(
                      height: 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primaryContainer,
                              scheme.tertiaryContainer,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_rounded,
                            size: 52,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                  NotesAudioBlock(
                    state: _audioState,
                    title: 'Voice note',
                    statusLabel: switch (_audioState) {
                      NotesAudioState.ready => 'Transcript ready',
                      NotesAudioState.playing => 'Playing',
                      NotesAudioState.transcribing => 'Transcribing…',
                      NotesAudioState.transcriptError =>
                        'Transcript failed · audio preserved',
                    },
                    playTooltip: 'Play',
                    pauseTooltip: 'Pause',
                    transcriptTooltip: 'Open transcript',
                    durationLabel: '01:24',
                    onPlayPause: () => setState(() {
                      _audioState = _audioState == NotesAudioState.playing
                          ? NotesAudioState.ready
                          : NotesAudioState.playing;
                    }),
                    onOpenTranscript: _mockAction,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final state in NotesAudioState.values)
                        AppButton.secondary(
                          label: state.name,
                          size: AppButtonSize.s,
                          onPressed: () => setState(() => _audioState = state),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _LabExample(
              title: 'Notes / Drawing controls',
              flutterMapping: 'NotesDrawingControls',
              variant: 'pen / highlighter / eraser / lasso',
              fullWidth: true,
              child: NotesDrawingControls(
                selectedTool: _drawingTool,
                onToolSelected: (value) =>
                    setState(() => _drawingTool = value),
                selectedColor: _drawingColor,
                colors: const [
                  NotesDrawingColorOption(
                    color: Color(0xFF0F172A),
                    label: 'Black',
                  ),
                  NotesDrawingColorOption(
                    color: Color(0xFFEF4444),
                    label: 'Red',
                  ),
                  NotesDrawingColorOption(
                    color: Color(0xFF6366F1),
                    label: 'Indigo',
                  ),
                ],
                onColorSelected: (value) =>
                    setState(() => _drawingColor = value),
                strokeWidth: _strokeWidth,
                onStrokeWidthChanged: (value) =>
                    setState(() => _strokeWidth = value),
                penTooltip: 'Pen',
                highlighterTooltip: 'Highlighter',
                eraserTooltip: 'Eraser',
                lassoTooltip: 'Lasso',
                undoTooltip: 'Undo',
                redoTooltip: 'Redo',
                strokeWidthLabel: 'Stroke width',
                canUndo: true,
                canRedo: true,
                onUndo: _mockAction,
                onRedo: _mockAction,
              ),
            ),
            _LabExample(
              title: 'Notes / Recorder states',
              flutterMapping: 'NotesRecorderControls',
              variant: 'ready / recording / paused / permission blocked',
              fullWidth: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NotesRecorderControls(
                    state: _recorderState,
                    statusLabel: switch (_recorderState) {
                      NotesRecorderState.ready => 'Ready',
                      NotesRecorderState.recording => 'Recording…',
                      NotesRecorderState.paused => 'Paused',
                      NotesRecorderState.permissionBlocked =>
                        'Microphone permission blocked',
                    },
                    startLabel: 'Start',
                    pauseLabel: 'Pause',
                    resumeLabel: 'Resume',
                    stopLabel: 'Stop',
                    discardLabel: 'Discard',
                    openSettingsLabel: 'Open settings',
                    durationLabel: '00:18',
                    levelIndicator: const LinearProgressIndicator(value: 0.62),
                    onStart: () => setState(
                      () => _recorderState = NotesRecorderState.recording,
                    ),
                    onPause: () => setState(
                      () => _recorderState = NotesRecorderState.paused,
                    ),
                    onResume: () => setState(
                      () => _recorderState = NotesRecorderState.recording,
                    ),
                    onStop: () => setState(
                      () => _recorderState = NotesRecorderState.ready,
                    ),
                    onDiscard: () => setState(
                      () => _recorderState = NotesRecorderState.ready,
                    ),
                    onOpenSettings: _mockAction,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final state in NotesRecorderState.values)
                        AppButton.secondary(
                          label: state.name,
                          size: AppButtonSize.s,
                          onPressed: () =>
                              setState(() => _recorderState = state),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _LabExample(
              title: 'Notes / Toolbar and menus',
              flutterMapping:
                  'NotesEditorToolbar + NotesHeadingStylesMenu + NotesTextFormattingMenu',
              variant: 'same controls across widths',
              fullWidth: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NotesEditorToolbar(
                    actions: [
                      for (final tool in NotesToolbarTool.values)
                        NotesToolbarAction(
                          tool: tool,
                          icon: _notesLabIcon(tool),
                          tooltip: tool.name,
                          selected: tool == NotesToolbarTool.text,
                          onPressed: _mockAction,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      NotesHeadingStylesMenu(
                        selected: NotesTextBlockStyle.h2,
                        onSelected: (_) {},
                      ),
                      NotesTextFormattingMenu(
                        selected: _formats,
                        onSelected: (format) => setState(() {
                          final next = Set<NotesInlineFormat>.from(_formats);
                          next.contains(format)
                              ? next.remove(format)
                              : next.add(format);
                          _formats = next;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

IconData _notesLabIcon(NotesToolbarTool tool) => switch (tool) {
  NotesToolbarTool.heading => Icons.title_rounded,
  NotesToolbarTool.text => Icons.text_fields_rounded,
  NotesToolbarTool.quote => Icons.format_quote_rounded,
  NotesToolbarTool.list => Icons.format_list_bulleted_rounded,
  NotesToolbarTool.checklist => Icons.checklist_rounded,
  NotesToolbarTool.table => Icons.table_chart_rounded,
  NotesToolbarTool.drawing => Icons.draw_rounded,
  NotesToolbarTool.image => Icons.image_rounded,
  NotesToolbarTool.audio => Icons.mic_rounded,
};
'''
    ),
)

replace_once(
    "lib/features/dev/component_lab_view.dart",
    "import 'package:counter/core/widgets/plan_card.dart';",
    "import 'package:counter/core/widgets/plan_card.dart';\nimport 'package:counter/features/notes/widgets/notes_canonical_components.dart';",
)
replace_once(
    "lib/features/dev/component_lab_view.dart",
    "part 'component_lab_cards_demo.dart';",
    "part 'component_lab_cards_demo.dart';\npart 'component_lab_notes_demo.dart';",
)
replace_once(
    "lib/features/dev/component_lab_view.dart",
    "          _LabSection(title: 'Cards', child: ComponentLabPlanCardsDemo()),",
    "          _LabSection(title: 'Cards', child: ComponentLabPlanCardsDemo()),\n          _LabSection(\n            title: 'Notes Editor V3',\n            child: ComponentLabNotesDemo(),\n          ),",
)
replace_once(
    "docs/APP_STRUCTURE.md",
    "| `dev/` | `component_lab_view.dart`, `component_lab_cards_demo.dart` | Admin-only Component Lab |",
    "| `dev/` | `component_lab_view.dart`, `component_lab_cards_demo.dart`, `component_lab_notes_demo.dart` | Admin-only Component Lab including canonical Notes block/media/tool states |",
)
replace_once(
    "pubspec.yaml",
    "  # https://flutter.dev/to/font/from-fonts\n\n  # To add custom fonts",
    "  # https://flutter.dev/to/asset-from-package\n\n  # To add custom fonts",
)
replace_once(
    "pubspec.yaml",
    "  # see https://flutter.dev/to/font/from-fonts",
    "  # see https://flutter.dev/to/font-from-package",
)

print('Notes Component Lab scenarios patched successfully.')
