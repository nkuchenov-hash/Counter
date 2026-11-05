// Notes visual tokens shared by the production library/editor surfaces.

import 'package:flutter/material.dart';
import 'package:counter/core/app_colors.dart';
import 'package:counter/core/life_color_compat.dart';

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

  /// Notes section visuals derive exclusively from the shared app palette.
  /// A saved category/custom color remains authoritative through fallbackAccent.
  static final NotesSectionPalette all = _fromAccent(kNordicWork[500]!);

  static NotesSectionPalette _fromAccent(Color accent) {
    final pane = Color.alphaBlend(
      accent.withValues(alpha: 0.14),
      AppColors.appBackground,
    );
    return NotesSectionPalette(
      tab: pane,
      pane: pane,
      note: Color.alphaBlend(
        accent.withValues(alpha: 0.035),
        AppNeutralTones.white,
      ),
      accent: accent,
      badge: Color.alphaBlend(
        accent.withValues(alpha: 0.13),
        AppNeutralTones.white,
      ),
    );
  }

  static NotesSectionPalette forCategory(String? name, Color fallbackAccent) {
    final key = (name ?? '').trim().toLowerCase();
    final Color accent = switch (key) {
      'списки' || 'lists' || 'веб' || 'web' || 'работа' || 'work' =>
        kNordicWork[500]!,
      'идеи' || 'ideas' || 'проекты' || 'projects' =>
        kNordicHealth[500]!,
      'книги' || 'books' || 'учёба' || 'учеба' || 'study' =>
        kNordicStudy[500]!,
      'личное' || 'personal' => kNordicPeople[500]!,
      'история' || 'history' => kNordicFood[700]!,
      'игры' || 'games' => kNordicEntertainment[500]!,
      'ремонт' || 'repair' => kCategoryNeutral[600]!,
      _ => fallbackAccent,
    };
    return _fromAccent(accent);
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
