import 'dart:math' as math;

import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

part 'notes_component_text_blocks.dart';
part 'notes_component_structural_blocks.dart';
part 'notes_component_media_blocks.dart';
part 'notes_component_tools.dart';

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

/// Text controller that renders the existing v2 inline runs before the editable
/// receives a changed value. This keeps rich text from flashing as plain text.
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
