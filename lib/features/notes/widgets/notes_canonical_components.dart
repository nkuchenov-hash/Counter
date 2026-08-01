import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_figma_tokens.dart';
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

const double kNotesContentInset = NotesFigmaTokens.editorContentInset;
const double kNotesBlockVerticalPadding = 12;
const double kNotesLeadingSize = 20;
const double kNotesLeadingGap = 10;
const double kNotesToolbarButtonSize = NotesFigmaTokens.toolbarButtonSize;
const double kNotesMenuRadius = NotesFigmaTokens.floatingMenuRadius;

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
    final baseTheme = Theme.of(context);
    final transparentEditorTheme = baseTheme.copyWith(
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: false,
        fillColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
    );

    return Theme(
      data: transparentEditorTheme,
      child: Stack(
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
                  color: NotesFigmaTokens.borderSubtle(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

TextStyle _notesTextStyle(
  BuildContext context,
  NotesTextBlockStyle style,
) {
  final color = NotesFigmaTokens.textPrimary(context);
  return switch (style) {
    NotesTextBlockStyle.body => TextStyle(
        fontSize: NotesFigmaTokens.bodySize,
        height:
            NotesFigmaTokens.bodyLineHeight / NotesFigmaTokens.bodySize,
        fontWeight: FontWeight.w400,
        color: color,
      ),
    NotesTextBlockStyle.h1 => TextStyle(
        fontSize: NotesFigmaTokens.h1Size,
        height: NotesFigmaTokens.h1LineHeight / NotesFigmaTokens.h1Size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: color,
      ),
    NotesTextBlockStyle.h2 => TextStyle(
        fontSize: NotesFigmaTokens.h2Size,
        height: NotesFigmaTokens.h2LineHeight / NotesFigmaTokens.h2Size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: color,
      ),
    NotesTextBlockStyle.h3 => TextStyle(
        fontSize: NotesFigmaTokens.h3Size,
        height: NotesFigmaTokens.h3LineHeight / NotesFigmaTokens.h3Size,
        fontWeight: FontWeight.w600,
        color: color,
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