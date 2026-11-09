/// Life OS form-control geometry tokens. All standard single-line inputs,
/// search fields and adjacent action buttons resolve to this source.
abstract final class AppControlTokens {
  // One compact capsule for text input, search and adjacent primary action.
  // This is the *painted* control height; do not increase the text input to
  // match a taller button. 44 logical px improves the touch target.
  static const double height = 44;
  static const double radius = height / 2;
  static const double fontSize = 16;
  // The borderless editor must have its own intrinsic line box, rather
  // than expanding to the capsule height and leaving glyphs at the top.
  static const double singleLineEditorHeight = 21;
  // Real deployed Onest on Flutter Web (DPR 1.5) paints both native hint
  // and typed glyphs ~4 physical px below the capsule center despite a
  // geometrically centered 21px editable box. Shift the WHOLE inner TextField
  // (hint + typed ink + caret + selection), never one state independently.
  static const double webSingleLineInkCorrectionY = -8 / 3;
  static const double horizontalGap = 8;
  static const double horizontalPadding = 16;
  static const double buttonHorizontalPadding = 14;

  // Variants retain their scale; the default medium button and the input
  // share the same 44px capsule. Larger controls are deliberate exceptions.
  static const double smallHeight = 32;
  static const double largeHeight = 48;
}
