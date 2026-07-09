/// Overlay transparency contracts for Desktop Voice native Win32 host.
///
/// The native HWND must be layered with a color-key (or per-pixel alpha) so
/// corners outside the rounded pill are fully transparent — never a black
/// rectangular backdrop / modal dim.
abstract final class DesktopVoiceOverlayTransparency {
  /// Color-key used by the native layered window (must not appear on the card).
  static const int colorKeyRgb = 0x000000;

  /// Card fill — must differ from [colorKeyRgb].
  static const int cardBackgroundRgb = 0x1C1C1E; // RGB(28,28,30)

  static const String backgroundModeTransparent = 'layered_colorkey';
  static const String backgroundModeOpaque = 'opaque_popup';

  static const String markerTransparentBackground =
      'DESKTOP_VOICE_OVERLAY_TRANSPARENT_BACKGROUND';
  static const String markerNoBlackBackdrop =
      'DESKTOP_VOICE_NO_BLACK_OVERLAY_BACKDROP';
  static const String markerNoModalDim =
      'DESKTOP_VOICE_NO_MODAL_DIM_BACKDROP';
  static const String markerNativeAlpha =
      'DESKTOP_VOICE_NATIVE_OVERLAY_ALPHA_ENABLED';
  static const String markerNoClipping =
      'DESKTOP_VOICE_NO_COMMAND_TEXT_CLIPPING';
  static const String markerNoTinyText =
      'DESKTOP_VOICE_NO_TINY_TEXT_ANYWHERE';

  /// True when native flags include layered + color-key (or equivalent alpha).
  static bool isTransparentBackground({
    required bool windowTransparent,
    required String backgroundMode,
    required bool hasBackdrop,
    required bool blackBackdropDetected,
  }) {
    if (hasBackdrop || blackBackdropDetected) return false;
    if (!windowTransparent) return false;
    return backgroundMode == backgroundModeTransparent;
  }

  /// Card color must not equal the transparency color key.
  static bool cardColorSafeForColorKey({
    required int cardRgb,
    required int keyRgb,
  }) =>
      cardRgb != keyRgb;
}
