// Notes visual tokens shared by the production library/editor surfaces.

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

class NotesSectionPalette {
  const NotesSectionPalette({
    required this.tab,
    required this.pane,
    required this.note,
    required this.accent,
    required this.badge,
  });

  final Color tab;
  final Color pane;
  final Color note;
  final Color accent;
  final Color badge;

  /// "All" is the only non-category section, so it keeps the neutral blue
  /// reference palette from the v32 mockup.
  static const NotesSectionPalette all = NotesSectionPalette(
    tab: Color(0xFFE3ECF8),
    pane: Color(0xFFE3ECF8),
    note: Color(0xFFFCFDFE),
    accent: Color(0xFF285B99),
    badge: Color(0xFFE3ECF8),
  );

  /// Category color is the source of truth. The v32 design is reproduced by
  /// deriving the physical-folder surface, note paper and badge tints from the
  /// stored LIFE OS category color instead of assigning colors by category name.
  static NotesSectionPalette forCategory(String? _, Color categoryColor) {
    final accent = categoryColor;
    const paper = Color(0xFFF7F8FA);

    final tab = Color.alphaBlend(
      accent.withValues(alpha: 0.16),
      paper,
    );
    final pane = Color.alphaBlend(
      accent.withValues(alpha: 0.14),
      paper,
    );
    final note = Color.alphaBlend(
      accent.withValues(alpha: 0.025),
      Colors.white,
    );
    final badge = Color.alphaBlend(
      accent.withValues(alpha: 0.12),
      Colors.white,
    );

    return NotesSectionPalette(
      tab: tab,
      pane: pane,
      note: note,
      accent: accent,
      badge: badge,
    );
  }
}

class NotesSectionPaletteScope extends InheritedWidget {
  const NotesSectionPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final NotesSectionPalette palette;

  static NotesSectionPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotesSectionPaletteScope>()
          ?.palette ??
      NotesSectionPalette.all;

  @override
  bool updateShouldNotify(NotesSectionPaletteScope oldWidget) =>
      oldWidget.palette.tab != palette.tab ||
      oldWidget.palette.pane != palette.pane ||
      oldWidget.palette.note != palette.note ||
      oldWidget.palette.accent != palette.accent ||
      oldWidget.palette.badge != palette.badge;
}

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
