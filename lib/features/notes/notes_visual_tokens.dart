// GLM Notes v3 visual tokens — extracted from NoteEditor.tsx / NotesScreen (1).tsx.

import 'package:flutter/material.dart';

const double kNotesEditorMaxWidth = 768;
const double kNotesEditorPadH = 20;
const double kNotesEditorPadV = 20;
const double kNotesTitleSize = 28;
const double kNotesTitleSizeWide = 30;
const double kNotesBodySize = 16;
const double kNotesMetaSize = 12;
const double kNotesBadgeSize = 10;
const double kNotesBlockGap = 4;
const double kNotesToolBtnSize = 36;
const double kNotesIconBtnSize = 36;
const double kNotesLargeCheckSize = 36;
const double kNotesCheckCircleSize = 20;

Color notesMutedColor(ColorScheme scheme) =>
    scheme.onSurface.withValues(alpha: 0.55);

BoxDecoration notesGlassDecoration(
  ColorScheme scheme, {
  double radius = 12,
  double fillAlpha = 0.45,
  double borderAlpha = 0.35,
}) {
  return BoxDecoration(
    color: scheme.surfaceContainerHighest.withValues(alpha: fillAlpha),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: scheme.outlineVariant.withValues(alpha: borderAlpha),
    ),
  );
}

BoxDecoration notesPillDecoration(ColorScheme scheme) {
  return BoxDecoration(
    color: scheme.surfaceContainerHighest.withValues(alpha: 0.38),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.32),
    ),
  );
}

Color notesBlockActiveFill(ColorScheme scheme) =>
    scheme.onSurface.withValues(alpha: 0.05);

Color notesTintBackground(Color color) => color.withValues(alpha: 0.13);
