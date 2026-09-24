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

  static const NotesSectionPalette all = NotesSectionPalette(
    tab: Color(0xFFE3ECF8),
    pane: Color(0xFFE3ECF8),
    note: Color(0xFFFCFDFE),
    accent: Color(0xFF285B99),
    badge: Color(0xFFE3ECF8),
  );

  static NotesSectionPalette forCategory(String? name, Color fallbackAccent) {
    final key = (name ?? '').trim().toLowerCase();
    switch (key) {
      case 'списки':
      case 'lists':
        return const NotesSectionPalette(
          tab: Color(0xFFDCE9F9),
          pane: Color(0xFFDCE9F9),
          note: Color(0xFFF8FBFF),
          accent: Color(0xFF285B99),
          badge: Color(0xFFE3ECF8),
        );
      case 'идеи':
      case 'ideas':
        return const NotesSectionPalette(
          tab: Color(0xFFDFF2EC),
          pane: Color(0xFFDFF2EC),
          note: Color(0xFFF9FDFB),
          accent: Color(0xFF15766A),
          badge: Color(0xFFDDF1EB),
        );
      case 'книги':
      case 'books':
        return const NotesSectionPalette(
          tab: Color(0xFFECE7F8),
          pane: Color(0xFFECE7F8),
          note: Color(0xFFFCFAFF),
          accent: Color(0xFF6756A8),
          badge: Color(0xFFECE8F7),
        );
      case 'работа':
      case 'work':
        return const NotesSectionPalette(
          tab: Color(0xFFF6E8D6),
          pane: Color(0xFFF6E8D6),
          note: Color(0xFFFFFCF7),
          accent: Color(0xFF8A651D),
          badge: Color(0xFFF5EBD7),
        );
      case 'личное':
      case 'personal':
        return const NotesSectionPalette(
          tab: Color(0xFFF7E4E8),
          pane: Color(0xFFF7E4E8),
          note: Color(0xFFFFFAFB),
          accent: Color(0xFFA8435A),
          badge: Color(0xFFF6E3E8),
        );
      case 'учёба':
      case 'учеба':
      case 'study':
        return const NotesSectionPalette(
          tab: Color(0xFFE8E4F5),
          pane: Color(0xFFE8E4F5),
          note: Color(0xFFFCFBFF),
          accent: Color(0xFF6756A8),
          badge: Color(0xFFECE8F7),
        );
      case 'проекты':
      case 'projects':
        return const NotesSectionPalette(
          tab: Color(0xFFDFF1EA),
          pane: Color(0xFFDFF1EA),
          note: Color(0xFFF9FDFB),
          accent: Color(0xFF15766A),
          badge: Color(0xFFDDF1EB),
        );
      case 'веб':
      case 'web':
        return const NotesSectionPalette(
          tab: Color(0xFFE2ECF9),
          pane: Color(0xFFE2ECF9),
          note: Color(0xFFF9FCFF),
          accent: Color(0xFF285B99),
          badge: Color(0xFFE3ECF8),
        );
      case 'история':
      case 'history':
        return const NotesSectionPalette(
          tab: Color(0xFFF4EBD6),
          pane: Color(0xFFF4EBD6),
          note: Color(0xFFFFFDF8),
          accent: Color(0xFF8A651D),
          badge: Color(0xFFF5EBD7),
        );
      case 'игры':
      case 'games':
        return const NotesSectionPalette(
          tab: Color(0xFFE9E4F4),
          pane: Color(0xFFE9E4F4),
          note: Color(0xFFFCFBFF),
          accent: Color(0xFF6756A8),
          badge: Color(0xFFECE8F7),
        );
      case 'ремонт':
      case 'repair':
        return const NotesSectionPalette(
          tab: Color(0xFFE8EDF2),
          pane: Color(0xFFE8EDF2),
          note: Color(0xFFFBFCFD),
          accent: Color(0xFF58697C),
          badge: Color(0xFFE8EDF2),
        );
    }

    final pane = Color.alphaBlend(
      fallbackAccent.withValues(alpha: 0.14),
      const Color(0xFFF7F8FA),
    );
    return NotesSectionPalette(
      tab: pane,
      pane: pane,
      note: Color.lerp(Colors.white, pane, 0.12)!,
      accent: fallbackAccent,
      badge: Color.alphaBlend(
        fallbackAccent.withValues(alpha: 0.13),
        Colors.white,
      ),
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
