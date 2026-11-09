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
  static const double singleLineEditorHeight = 24;
  // Desktop/web glyph ink is optically low even when the editor is centered.
  static const double singleLineOpticalOffsetY = -2;
  static const double horizontalGap = 8;
  static const double horizontalPadding = 16;
  static const double buttonHorizontalPadding = 14;

  // Variants retain their scale; the default medium button and the input
  // share the same 44px capsule. Larger controls are deliberate exceptions.
  static const double smallHeight = 32;
  static const double largeHeight = 48;
}
