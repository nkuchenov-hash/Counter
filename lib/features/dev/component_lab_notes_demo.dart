part of 'component_lab_view.dart';

class ComponentLabNotesDemo extends StatefulWidget {
  const ComponentLabNotesDemo({super.key});

  @override
  State<ComponentLabNotesDemo> createState() => _ComponentLabNotesDemoState();
}

class _ComponentLabNotesDemoState extends State<ComponentLabNotesDemo> {
  late final NotesTextEditingController _bodyController;
  late final TextEditingController _h1Controller;
  late final TextEditingController _h2Controller;
  late final TextEditingController _h3Controller;
  late final TextEditingController _listController;
  late final TextEditingController _checklistController;
  late final TextEditingController _quoteController;
  late final TextEditingController _attributionController;
  late final TextEditingController _captionController;

  bool _checked = false;
  NotesDrawingTool _drawingTool = NotesDrawingTool.pen;
  Color _drawingColor = const Color(0xFF111111);
  double _strokeWidth = 4;
  NotesRecorderState _recorderState = NotesRecorderState.ready;
  NotesAudioState _audioState = NotesAudioState.ready;

  @override
  void initState() {
    super.initState();
    _bodyController = NotesTextEditingController(
      runs: const [
        NoteTextRun(text: 'Rich body text with '),
        NoteTextRun(
          text: 'bold',
          marks: NoteInlineMarks(bold: true),
        ),
        NoteTextRun(text: ', '),
        NoteTextRun(
          text: 'highlight',
          marks: NoteInlineMarks(highlightColor: '#FFF59D'),
        ),
        NoteTextRun(text: ', and '),
        NoteTextRun(
          text: 'a link',
          marks: NoteInlineMarks(
            underline: true,
            link: 'https://example.com',
          ),
        ),
        NoteTextRun(text: '.'),
      ],
    );
    _h1Controller = TextEditingController(text: 'A multiline note heading');
    _h2Controller = TextEditingController(text: 'Section heading');
    _h3Controller = TextEditingController(text: 'Subsection heading');
    _listController = TextEditingController(
      text: 'Wrapped list text stays aligned with the content line.',
    );
    _checklistController = TextEditingController(
      text: 'Checklist text uses the same leading geometry.',
    );
    _quoteController = TextEditingController(
      text: 'A quote hugs its content instead of reserving empty height.',
    );
    _attributionController = TextEditingController(text: 'Life OS notes');
    _captionController = TextEditingController(text: 'Caption outside selection');
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _h1Controller.dispose();
    _h2Controller.dispose();
    _h3Controller.dispose();
    _listController.dispose();
    _checklistController.dispose();
    _quoteController.dispose();
    _attributionController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabExample(
          title: 'Notes / Text blocks / Responsive shared component',
          flutterMapping: 'NotesTextBlock(style: ..., state: ...)',
          variant: 'Body + H1 + H2 + H3',
          state: 'default / active',
          fullWidth: true,
          note:
              'Transparent text blocks own 20px horizontal and 12px vertical padding. Active indicator follows content height.',
          child: Column(
            children: [
              NotesTextBlock(
                controller: _h1Controller,
                style: NotesTextBlockStyle.h1,
                state: NotesBlockState.active,
              ),
              NotesTextBlock(
                controller: _h2Controller,
                style: NotesTextBlockStyle.h2,
              ),
              NotesTextBlock(
                controller: _h3Controller,
                style: NotesTextBlockStyle.h3,
              ),
              NotesTextBlock(controller: _bodyController),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / List and checklist / Shared leading geometry',
          flutterMapping: 'NotesListBlock + NotesChecklistBlock',
          variant: 'numbered + checklist',
          state: _checked ? 'checked' : 'unchecked',
          fullWidth: true,
          child: Column(
            children: [
              NotesListBlock(
                controller: _listController,
                listStyle: NotesListStyle.numbered,
                ordinal: 3,
                state: NotesBlockState.active,
              ),
              NotesChecklistBlock(
                controller: _checklistController,
                checked: _checked,
                onCheckedChanged: (value) => setState(() => _checked = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / Quote, divider, table',
          flutterMapping:
              'NotesQuoteBlock + NotesDividerBlock + NotesTableBlock',
          variant: 'structural blocks',
          state: 'active surfaces',
          fullWidth: true,
          child: Column(
            children: [
              NotesQuoteBlock(
                textController: _quoteController,
                attributionController: _attributionController,
                state: NotesBlockState.active,
              ),
              const NotesDividerBlock(),
              NotesTableBlock(
                data: NoteTableData.empty(rows: 3, columns: 3).copyWith(
                  hasHeader: true,
                  cells: const [
                    ['Task', 'Owner', 'State'],
                    ['Audit', 'Nick', 'Done'],
                    ['Editor', 'Team', 'Active'],
                  ],
                ),
                state: NotesBlockState.active,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / Table size picker / Compact and extended',
          flutterMapping:
              'NotesTableSizePicker(maxRows: ..., maxColumns: ...)',
          variant: 'same component, parameterized range',
          state: '5×5 compact / 8×6 extended',
          fullWidth: true,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              NotesTableSizePicker(onSelected: (_) {}),
              NotesTableSizePicker(
                maxRows: 8,
                maxColumns: 6,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / Media and audio blocks',
          flutterMapping: 'NotesMediaBlock + NotesAudioBlock',
          variant: 'image + audio states',
          state: _audioState.name,
          fullWidth: true,
          child: Column(
            children: [
              NotesMediaBlock(
                kind: NotesMediaKind.image,
                state: NotesBlockState.active,
                captionController: _captionController,
                media: Container(
                  height: 180,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_rounded, size: 52),
                ),
              ),
              NotesAudioBlock(
                state: _audioState,
                title: 'Interview recording',
                statusLabel: switch (_audioState) {
                  NotesAudioState.ready => 'Ready',
                  NotesAudioState.playing => 'Playing',
                  NotesAudioState.transcribing => 'Transcribing',
                  NotesAudioState.transcriptError =>
                    'Transcript failed; audio remains available',
                },
                playTooltip: 'Play',
                pauseTooltip: 'Pause',
                transcriptTooltip: 'Open transcript',
                durationLabel: '03:24',
                onPlayPause: () => setState(() {
                  _audioState = _audioState == NotesAudioState.playing
                      ? NotesAudioState.ready
                      : NotesAudioState.playing;
                }),
                onOpenTranscript: _mockAction,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final state in NotesAudioState.values)
                    AppButton.ghost(
                      label: state.name,
                      size: AppButtonSize.s,
                      onPressed: () => setState(() => _audioState = state),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / Main toolbar and menus',
          flutterMapping:
              'NotesEditorToolbar + NotesHeadingStylesMenu + NotesTextFormattingMenu + NotesInsertMenu',
          variant: 'responsive shared controls',
          state: 'Text selected; Link only in formatting menu',
          fullWidth: true,
          child: Column(
            children: [
              NotesEditorToolbar(
                actions: [
                  for (final tool in NotesToolbarTool.values)
                    NotesToolbarAction(
                      tool: tool,
                      icon: _notesLabIconFor(tool),
                      tooltip: tool.name,
                      selected: tool == NotesToolbarTool.text,
                      onPressed: _mockAction,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  NotesHeadingStylesMenu(
                    selected: NotesTextBlockStyle.h2,
                    onSelected: (_) {},
                  ),
                  NotesTextFormattingMenu(
                    selected: const {
                      NotesInlineFormat.bold,
                      NotesInlineFormat.link,
                    },
                    onSelected: (_) {},
                  ),
                  NotesInsertMenu(
                    actions: [
                      NotesInsertMenuAction(
                        icon: Icons.title_rounded,
                        label: 'Heading',
                        onPressed: _mockAction,
                      ),
                      NotesInsertMenuAction(
                        icon: Icons.image_rounded,
                        label: 'Image',
                        onPressed: _mockAction,
                      ),
                      NotesInsertMenuAction(
                        icon: Icons.table_chart_rounded,
                        label: 'Table',
                        onPressed: _mockAction,
                      ),
                      NotesInsertMenuAction(
                        icon: Icons.horizontal_rule_rounded,
                        label: 'Divider',
                        onPressed: _mockAction,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / Drawing controls',
          flutterMapping: 'NotesDrawingControls',
          variant: 'pen / highlighter / eraser / lasso',
          state: _drawingTool.name,
          fullWidth: true,
          child: NotesDrawingControls(
            selectedTool: _drawingTool,
            onToolSelected: (tool) => setState(() => _drawingTool = tool),
            selectedColor: _drawingColor,
            colors: const [
              NotesDrawingColorOption(
                color: Color(0xFF111111),
                label: 'Black',
              ),
              NotesDrawingColorOption(
                color: Color(0xFFE53935),
                label: 'Red',
              ),
              NotesDrawingColorOption(
                color: Color(0xFF1E88E5),
                label: 'Blue',
              ),
              NotesDrawingColorOption(
                color: Color(0xFF43A047),
                label: 'Green',
              ),
            ],
            onColorSelected: (color) => setState(() => _drawingColor = color),
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
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / Recorder controls',
          flutterMapping: 'NotesRecorderControls(state: ...)',
          variant: 'ready / recording / paused / permission blocked',
          state: _recorderState.name,
          fullWidth: true,
          child: Column(
            children: [
              NotesRecorderControls(
                state: _recorderState,
                statusLabel: switch (_recorderState) {
                  NotesRecorderState.ready => 'Ready to record',
                  NotesRecorderState.recording => 'Recording',
                  NotesRecorderState.paused => 'Paused',
                  NotesRecorderState.permissionBlocked =>
                    'Microphone permission required',
                },
                startLabel: 'Start',
                pauseLabel: 'Pause',
                resumeLabel: 'Resume',
                stopLabel: 'Stop',
                discardLabel: 'Discard',
                openSettingsLabel: 'Open settings',
                durationLabel: _recorderState == NotesRecorderState.ready
                    ? null
                    : '00:18',
                levelIndicator: _recorderState == NotesRecorderState.recording
                    ? LinearProgressIndicator(
                        value: 0.62,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(999),
                      )
                    : null,
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
                children: [
                  for (final state in NotesRecorderState.values)
                    AppButton.ghost(
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
        const SizedBox(height: 12),
        _LabExample(
          title: 'Notes / Transcript surface',
          flutterMapping: 'NotesTranscriptSurface',
          variant: 'fixed header + scrollable body + actions',
          state: 'populated',
          fullWidth: true,
          child: SizedBox(
            height: 430,
            child: NotesTranscriptSurface(
              title: 'Transcript',
              transcript:
                  'The transcript body remains scrollable while the title and actions stay available. This mock content demonstrates the same responsive component used by mobile and desktop surfaces.',
              copyLabel: 'Copy transcript',
              doneLabel: 'Done',
              onCopy: _mockAction,
              onDone: _mockAction,
              playbackContext: NotesAudioBlock(
                state: NotesAudioState.ready,
                title: 'Interview recording',
                statusLabel: 'Ready',
                playTooltip: 'Play',
                pauseTooltip: 'Pause',
                transcriptTooltip: 'Transcript',
                durationLabel: '03:24',
                onPlayPause: _mockAction,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

IconData _notesLabIconFor(NotesToolbarTool tool) {
  return switch (tool) {
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
}
