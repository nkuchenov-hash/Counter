import 'dart:math' as math;

import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

/// Canonical Notes components shared by mobile, desktop, and web.
///
/// Width, overlay placement, and table range may change through constraints or
/// parameters. Component identity must not branch by platform.

enum NotesBlockState { defaultState, active }

enum NotesTextBlockStyle { body, h1, h2, h3 }

enum NotesListStyle { bulleted, numbered }

enum NotesMediaKind { image, drawing }

enum NotesAudioState { ready, playing, transcribing, transcriptError }

enum NotesToolbarTool {
  heading,
  text,
  quote,
  list,
  checklist,
  table,
  drawing,
  image,
  audio,
}

enum NotesInlineFormat { bold, italic, underline, strike, highlight, link }

const double kNotesContentInset = 20;
const double kNotesBlockVerticalPadding = 12;
const double kNotesLeadingSize = 20;
const double kNotesLeadingGap = 10;
const double kNotesToolbarButtonSize = 40;
const double kNotesMenuRadius = 16;

class NotesTextEditingController extends TextEditingController {
  NotesTextEditingController({
    String? text,
    List<NoteTextRun> runs = const <NoteTextRun>[],
  }) : _runs = List<NoteTextRun>.unmodifiable(runs),
       super(text: text ?? runs.map((run) => run.text).join());

  List<NoteTextRun> _runs;
  Color? linkColor;

  List<NoteTextRun> get runs => _runs;

  void setRuns(List<NoteTextRun> runs) {
    _runs = List<NoteTextRun>.unmodifiable(runs);
    notifyListeners();
  }

  void syncDocument({
    required String text,
    required List<NoteTextRun> runs,
    TextSelection? selection,
  }) {
    _runs = List<NoteTextRun>.unmodifiable(runs);
    final nextSelection = selection ??
        TextSelection.collapsed(
          offset: value.selection.extentOffset.clamp(0, text.length).toInt(),
        );
    value = TextEditingValue(
      text: text,
      selection: nextSelection,
      composing: TextRange.empty,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (_runs.isEmpty || _runs.map((run) => run.text).join() != text) {
      return TextSpan(style: baseStyle, text: text);
    }
    return TextSpan(
      style: baseStyle,
      children: [
        for (final run in _runs)
          TextSpan(text: run.text, style: _styleForMarks(baseStyle, run.marks)),
      ],
    );
  }

  TextStyle _styleForMarks(TextStyle base, NoteInlineMarks marks) {
    final decorations = <TextDecoration>[];
    if (marks.underline) decorations.add(TextDecoration.underline);
    if (marks.strike) decorations.add(TextDecoration.lineThrough);
    return base.copyWith(
      fontWeight: marks.bold ? FontWeight.w700 : base.fontWeight,
      fontStyle: marks.italic ? FontStyle.italic : base.fontStyle,
      decoration: decorations.isEmpty
          ? base.decoration
          : TextDecoration.combine(decorations),
      color: _notesColor(marks.textColor) ??
          (marks.link != null ? linkColor : base.color),
      backgroundColor:
          _notesColor(marks.highlightColor) ?? base.backgroundColor,
    );
  }
}

class NotesTextBlock extends StatelessWidget {
  const NotesTextBlock({
    super.key,
    required this.controller,
    this.style = NotesTextBlockStyle.body,
    this.state = NotesBlockState.defaultState,
    this.focusNode,
    this.hintText,
    this.semanticLabel,
    this.autofocus = false,
    this.readOnly = false,
    this.onChanged,
    this.onTap,
    this.textFieldKey,
  });

  final TextEditingController controller;
  final NotesTextBlockStyle style;
  final NotesBlockState state;
  final FocusNode? focusNode;
  final String? hintText;
  final String? semanticLabel;
  final bool autofocus;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Key? textFieldKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (controller is NotesTextEditingController) {
      (controller as NotesTextEditingController).linkColor = scheme.primary;
    }
    final textField = TextField(
      key: textFieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      minLines: 1,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
      onTap: onTap,
      style: _notesTextStyle(context, style),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: _notesTextStyle(context, style).copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kNotesContentInset,
          vertical: kNotesBlockVerticalPadding,
        ),
      ),
    );
    return _NotesActiveIndicatorFrame(
      state: state,
      topInset: style == NotesTextBlockStyle.h1 ? 20 : 12,
      child: semanticLabel == null
          ? textField
          : Semantics(label: semanticLabel, textField: true, child: textField),
    );
  }
}

class NotesListBlock extends StatelessWidget {
  const NotesListBlock({
    super.key,
    required this.controller,
    required this.listStyle,
    this.ordinal = 1,
    this.state = NotesBlockState.defaultState,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onTap,
    this.textFieldKey,
  });

  final TextEditingController controller;
  final NotesListStyle listStyle;
  final int ordinal;
  final NotesBlockState state;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Key? textFieldKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marker = listStyle == NotesListStyle.bulleted
        ? Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.onSurface,
              shape: BoxShape.circle,
            ),
          )
        : Text(
            '$ordinal.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.45,
              color: scheme.onSurface,
            ),
          );
    return _NotesActiveIndicatorFrame(
      state: state,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kNotesContentInset,
          kNotesBlockVerticalPadding,
          kNotesContentInset,
          kNotesBlockVerticalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: kNotesLeadingSize,
              height: 24,
              child: Center(child: marker),
            ),
            const SizedBox(width: kNotesLeadingGap),
            Expanded(
              child: TextField(
                key: textFieldKey,
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: onChanged,
                onTap: onTap,
                style: _notesTextStyle(context, NotesTextBlockStyle.body),
                decoration: InputDecoration(
                  hintText: hintText,
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
    );
  }
}

class NotesChecklistBlock extends StatelessWidget {
  const NotesChecklistBlock({
    super.key,
    required this.controller,
    required this.checked,
    required this.onCheckedChanged,
    this.state = NotesBlockState.defaultState,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onTap,
    this.textFieldKey,
  });

  final TextEditingController controller;
  final bool checked;
  final ValueChanged<bool> onCheckedChanged;
  final NotesBlockState state;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Key? textFieldKey;

  @override
  Widget build(BuildContext context) {
    final baseStyle = _notesTextStyle(context, NotesTextBlockStyle.body);
    return _NotesActiveIndicatorFrame(
      state: state,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kNotesContentInset,
          kNotesBlockVerticalPadding,
          kNotesContentInset,
          kNotesBlockVerticalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: kNotesLeadingSize,
              height: 24,
              child: Checkbox(
                value: checked,
                onChanged: (value) => onCheckedChanged(value ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: kNotesLeadingGap),
            Expanded(
              child: TextField(
                key: textFieldKey,
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: onChanged,
                onTap: onTap,
                style: checked
                    ? baseStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      )
                    : baseStyle,
                decoration: InputDecoration(
                  hintText: hintText,
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
    );
  }
}

class NotesQuoteBlock extends StatelessWidget {
  const NotesQuoteBlock({
    super.key,
    required this.textController,
    this.attributionController,
    this.state = NotesBlockState.defaultState,
    this.onTextChanged,
    this.onAttributionChanged,
    this.textHint,
    this.attributionHint,
  });

  final TextEditingController textController;
  final TextEditingController? attributionController;
  final NotesBlockState state;
  final ValueChanged<String>? onTextChanged;
  final ValueChanged<String>? onAttributionChanged;
  final String? textHint;
  final String? attributionHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = state == NotesBlockState.active;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: DecoratedBox(
        key: const ValueKey('notes-quote-surface'),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? scheme.outline : scheme.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: textController,
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onChanged: onTextChanged,
                style: _notesTextStyle(context, NotesTextBlockStyle.body)
                    .copyWith(fontStyle: FontStyle.italic),
                decoration: InputDecoration(
                  hintText: textHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (attributionController != null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: attributionController,
                  minLines: 1,
                  maxLines: 2,
                  onChanged: onAttributionChanged,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  decoration: InputDecoration(
                    hintText: attributionHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NotesDividerBlock extends StatelessWidget {
  const NotesDividerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: Divider(height: 1),
    );
  }
}

class NotesTableBlock extends StatefulWidget {
  const NotesTableBlock({
    super.key,
    required this.data,
    required this.onChanged,
    this.state = NotesBlockState.defaultState,
    this.onOptionsRequested,
  });

  final NoteTableData data;
  final ValueChanged<NoteTableData> onChanged;
  final NotesBlockState state;
  final VoidCallback? onOptionsRequested;

  @override
  State<NotesTableBlock> createState() => _NotesTableBlockState();
}

class _NotesTableBlockState extends State<NotesTableBlock> {
  late List<List<TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers(_normalizedCells(widget.data));
  }

  @override
  void didUpdateWidget(covariant NotesTableBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _normalizedCells(widget.data);
    final shapeChanged = _controllers.length != next.length ||
        _controllers.first.length != next.first.length;
    if (shapeChanged) {
      _disposeControllers();
      _controllers = _buildControllers(next);
      return;
    }
    for (var row = 0; row < next.length; row++) {
      for (var column = 0; column < next[row].length; column++) {
        final controller = _controllers[row][column];
        final nextText = next[row][column];
        if (controller.text == nextText) continue;
        controller.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(
            offset: controller.selection.extentOffset
                .clamp(0, nextText.length)
                .toInt(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  List<List<TextEditingController>> _buildControllers(
    List<List<String>> cells,
  ) => [
    for (final row in cells)
      [for (final cell in row) TextEditingController(text: cell)],
  ];

  void _disposeControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
  }

  void _updateCell(int row, int column, String text) {
    final cells = [
      for (final sourceRow in _normalizedCells(widget.data))
        List<String>.from(sourceRow),
    ];
    cells[row][column] = text;
    widget.onChanged(
      widget.data.copyWith(cells: cells),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.state == NotesBlockState.active;
    final cells = _normalizedCells(widget.data);
    final columnCount = cells.first.length;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = math.max(96.0, constraints.maxWidth / columnCount);
          return DecoratedBox(
            key: const ValueKey('notes-table-surface'),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? scheme.outline : scheme.outlineVariant,
                width: active ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: GestureDetector(
                onLongPress: widget.onOptionsRequested,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var row = 0; row < cells.length; row++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var column = 0;
                                column < columnCount;
                                column++)
                              SizedBox(
                                width: cellWidth,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: widget.data.hasHeader && row == 0
                                        ? scheme.surfaceContainerHighest
                                        : scheme.surface,
                                    border: Border(
                                      right: column == columnCount - 1
                                          ? BorderSide.none
                                          : BorderSide(
                                              color: scheme.outlineVariant,
                                            ),
                                      bottom: row == cells.length - 1
                                          ? BorderSide.none
                                          : BorderSide(
                                              color: scheme.outlineVariant,
                                            ),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controllers[row][column],
                                    minLines: 1,
                                    maxLines: null,
                                    onChanged: (value) =>
                                        _updateCell(row, column, value),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontSize: 16, height: 1.35),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.all(10),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NotesTableSizePicker extends StatefulWidget {
  const NotesTableSizePicker({
    super.key,
    required this.onSelected,
    this.maxRows = 5,
    this.maxColumns = 5,
    this.cellSize = 28,
  });

  final ValueChanged<NoteTableData> onSelected;
  final int maxRows;
  final int maxColumns;
  final double cellSize;

  @override
  State<NotesTableSizePicker> createState() => _NotesTableSizePickerState();
}

class _NotesTableSizePickerState extends State<NotesTableSizePicker> {
  int _rows = 1;
  int _columns = 1;

  void _select(int row, int column) {
    setState(() {
      _rows = row + 1;
      _columns = column + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = widget.maxRows.clamp(1, 20);
    final columns = widget.maxColumns.clamp(1, 12);
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_rows × $_columns',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: columns * widget.cellSize,
            height: rows * widget.cellSize,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
              ),
              itemCount: rows * columns,
              itemBuilder: (context, index) {
                final row = index ~/ columns;
                final column = index % columns;
                final selected = row < _rows && column < _columns;
                return MouseRegion(
                  onEnter: (_) => _select(row, column),
                  child: GestureDetector(
                    key: ValueKey('notes-table-size-${row + 1}-${column + 1}'),
                    onTap: () => widget.onSelected(
                      NoteTableData.empty(rows: row + 1, columns: column + 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primaryContainer
                              : scheme.surface,
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NotesMediaBlock extends StatelessWidget {
  const NotesMediaBlock({
    super.key,
    required this.kind,
    required this.media,
    this.state = NotesBlockState.defaultState,
    this.captionController,
    this.captionHint,
    this.onCaptionChanged,
    this.onTap,
  });

  final NotesMediaKind kind;
  final Widget media;
  final NotesBlockState state;
  final TextEditingController? captionController;
  final String? captionHint;
  final ValueChanged<String>? onCaptionChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = state == NotesBlockState.active;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTap,
            child: DecoratedBox(
              key: const ValueKey('notes-media-frame'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? scheme.outline : scheme.outlineVariant,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: media,
              ),
            ),
          ),
          if (captionController != null) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('notes-media-caption'),
              controller: captionController,
              minLines: 1,
              maxLines: null,
              onChanged: onCaptionChanged,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                hintText: captionHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NotesAudioBlock extends StatelessWidget {
  const NotesAudioBlock({
    super.key,
    required this.state,
    required this.title,
    required this.statusLabel,
    this.durationLabel,
    this.onPlayPause,
    this.onOpenTranscript,
  });

  final NotesAudioState state;
  final String title;
  final String statusLabel;
  final String? durationLabel;
  final VoidCallback? onPlayPause;
  final VoidCallback? onOpenTranscript;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = state == NotesAudioState.transcribing;
    final playing = state == NotesAudioState.playing;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                onPressed: onPlayPause,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: state == NotesAudioState.transcriptError
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (durationLabel != null)
                Text(
                  durationLabel!,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              if (onOpenTranscript != null)
                IconButton(
                  tooltip: 'Transcript',
                  onPressed: onOpenTranscript,
                  icon: const Icon(Icons.notes_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotesToolbarAction {
  const NotesToolbarAction({
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
  });

  final NotesToolbarTool tool;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;
}

class NotesToolbarButton extends StatelessWidget {
  const NotesToolbarButton({
    super.key,
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
  });

  final NotesToolbarTool tool;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onInverseSurface
        : enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.35);
    final background = selected ? scheme.inverseSurface : Colors.transparent;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey('notes-toolbar-${tool.name}'),
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: kNotesToolbarButtonSize,
              child: Icon(icon, size: 22, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class NotesEditorToolbar extends StatelessWidget {
  const NotesEditorToolbar({super.key, required this.actions});

  final List<NotesToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                NotesToolbarButton(
                  tool: actions[index].tool,
                  icon: actions[index].icon,
                  tooltip: actions[index].tooltip,
                  onPressed: actions[index].onPressed,
                  selected: actions[index].selected,
                  enabled: actions[index].enabled,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NotesFloatingMenuSurface extends StatelessWidget {
  const NotesFloatingMenuSurface({
    super.key,
    required this.child,
    this.maxWidth = 320,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: scheme.surface,
        elevation: 10,
        shadowColor: scheme.shadow.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kNotesMenuRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class NotesHeadingStylesMenu extends StatelessWidget {
  const NotesHeadingStylesMenu({
    super.key,
    required this.onSelected,
    this.selected,
  });

  final ValueChanged<NotesTextBlockStyle> onSelected;
  final NotesTextBlockStyle? selected;

  @override
  Widget build(BuildContext context) {
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final style in NotesTextBlockStyle.values)
            _NotesMenuRow(
              label: switch (style) {
                NotesTextBlockStyle.body => 'Body',
                NotesTextBlockStyle.h1 => 'Heading 1',
                NotesTextBlockStyle.h2 => 'Heading 2',
                NotesTextBlockStyle.h3 => 'Heading 3',
              },
              previewStyle: _notesTextStyle(context, style),
              selected: selected == style,
              onTap: () => onSelected(style),
            ),
        ],
      ),
    );
  }
}

class NotesTextFormattingMenu extends StatelessWidget {
  const NotesTextFormattingMenu({
    super.key,
    required this.onSelected,
    this.selected = const <NotesInlineFormat>{},
  });

  final ValueChanged<NotesInlineFormat> onSelected;
  final Set<NotesInlineFormat> selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final format in NotesInlineFormat.values)
            _NotesMenuRow(
              label: switch (format) {
                NotesInlineFormat.bold => 'Bold',
                NotesInlineFormat.italic => 'Italic',
                NotesInlineFormat.underline => 'Underline',
                NotesInlineFormat.strike => 'Strikethrough',
                NotesInlineFormat.highlight => 'Highlight',
                NotesInlineFormat.link => 'Link',
              },
              previewStyle: TextStyle(
                fontSize: 16,
                fontWeight: format == NotesInlineFormat.bold
                    ? FontWeight.w700
                    : FontWeight.w400,
                fontStyle: format == NotesInlineFormat.italic
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration: switch (format) {
                  NotesInlineFormat.underline => TextDecoration.underline,
                  NotesInlineFormat.strike => TextDecoration.lineThrough,
                  NotesInlineFormat.link => TextDecoration.underline,
                  _ => TextDecoration.none,
                },
                color: format == NotesInlineFormat.link
                    ? scheme.primary
                    : scheme.onSurface,
                backgroundColor: format == NotesInlineFormat.highlight
                    ? scheme.tertiaryContainer
                    : null,
              ),
              selected: selected.contains(format),
              onTap: () => onSelected(format),
            ),
        ],
      ),
    );
  }
}

class NotesInsertMenuAction {
  const NotesInsertMenuAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class NotesInsertMenu extends StatelessWidget {
  const NotesInsertMenu({super.key, required this.actions});

  final List<NotesInsertMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return NotesFloatingMenuSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(action.icon, size: 20),
              title: Text(action.label),
              onTap: action.onPressed,
            ),
        ],
      ),
    );
  }
}

class _NotesActiveIndicatorFrame extends StatelessWidget {
  const _NotesActiveIndicatorFrame({
    required this.state,
    required this.child,
    this.topInset = 12,
  });

  final NotesBlockState state;
  final Widget child;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (state == NotesBlockState.active)
          Positioned(
            key: const ValueKey('notes-active-indicator'),
            left: 8,
            top: topInset,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const SizedBox(width: 2),
            ),
          ),
      ],
    );
  }
}

class _NotesMenuRow extends StatelessWidget {
  const _NotesMenuRow({
    required this.label,
    required this.previewStyle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final TextStyle previewStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: previewStyle)),
              if (selected) Icon(Icons.check_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _notesTextStyle(
  BuildContext context,
  NotesTextBlockStyle style,
) {
  final scheme = Theme.of(context).colorScheme;
  return switch (style) {
    NotesTextBlockStyle.body => TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
    NotesTextBlockStyle.h1 => TextStyle(
        fontSize: 30,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
    NotesTextBlockStyle.h2 => TextStyle(
        fontSize: 24,
        height: 1.24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: scheme.onSurface,
      ),
    NotesTextBlockStyle.h3 => TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
  };
}

List<List<String>> _normalizedCells(NoteTableData data) {
  if (data.cells.isEmpty || data.columnCount == 0) {
    return NoteTableData.empty().cells;
  }
  final columns = data.columnCount;
  return [
    for (final row in data.cells)
      [
        ...row.take(columns),
        if (row.length < columns)
          ...List<String>.filled(columns - row.length, ''),
      ],
  ];
}

Color? _notesColor(String? raw) {
  final value = raw?.trim().replaceFirst('#', '') ?? '';
  if (value.isEmpty) return null;
  try {
    if (value.length == 6) return Color(int.parse('FF$value', radix: 16));
    if (value.length == 8) return Color(int.parse(value, radix: 16));
  } on FormatException {
    return null;
  }
  return null;
}
