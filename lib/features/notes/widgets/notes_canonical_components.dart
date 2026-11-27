import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:counter/core/app_colors.dart';
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
double notesContentHorizontalInset(BuildContext context) =>
    MediaQuery.widthOf(context) >= 760 ? NotesFigmaTokens.editorDesktopContentInset : kNotesContentInset;

double notesTextBlockPadding(BuildContext context, {bool list = false}) {
  if (!NotesFigmaTokens.nativeNotesLayout(context)) {
    return list ? 2.5 : 4;
  }
  return list
      ? NotesFigmaTokens.nativeListVerticalPadding
      : NotesFigmaTokens.nativeParagraphVerticalPadding;
}

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
  // Cached rendered text avoids concatenating every rich-text run on each
  // EditableText paint/layout pass while typing or moving the cursor.
  late String _runsText = _runs.map((run) => run.text).join();
  Color? linkColor;

  List<NoteTextRun> get runs => _runs;

  void setRuns(List<NoteTextRun> runs, {bool notify = true}) {
    _runs = List<NoteTextRun>.unmodifiable(runs);
    _runsText = _runs.map((run) => run.text).join();
    // onChanged already originates from TextEditingController notifying the
    // EditableText. Do not emit another notification for the rich-text runs
    // of the very same keystroke: Android IME composition can flicker/reset.
    if (notify) notifyListeners();
  }

  void syncDocument({
    required String text,
    required List<NoteTextRun> runs,
    TextSelection? selection,
  }) {
    _runs = List<NoteTextRun>.unmodifiable(runs);
    _runsText = _runs.map((run) => run.text).join();
    // Structural Enter shortens the original block while the IME still has
    // the old caret position. Clamp both endpoints before updating EditableText
    // so neither Android nor Flutter receives an out-of-bounds selection.
    final currentSelection = selection ?? value.selection;
    final nextSelection = currentSelection.isValid
        ? TextSelection(
            baseOffset: currentSelection.baseOffset.clamp(0, text.length).toInt(),
            extentOffset: currentSelection.extentOffset.clamp(0, text.length).toInt(),
            affinity: currentSelection.affinity,
            isDirectional: currentSelection.isDirectional,
          )
        : TextSelection.collapsed(offset: text.length);
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
    if (_runs.isEmpty || _runsText != text) {
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
    this.topInset = 14,
    this.indicatorHeight = NotesFigmaTokens.bodySize,
  });

  final NotesBlockState state;
  final Widget child;
  final double topInset;
  final double indicatorHeight;

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
            height: indicatorHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NotesFigmaTokens.borderSubtle(context),
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
  final color = NotesFigmaTokens.textPrimary(context);
  return switch (style) {
    NotesTextBlockStyle.body => TextStyle(
        fontSize: NotesFigmaTokens.bodySize,
        height:
            NotesFigmaTokens.bodyLineHeight / NotesFigmaTokens.bodySize,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
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
        letterSpacing: 0,
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