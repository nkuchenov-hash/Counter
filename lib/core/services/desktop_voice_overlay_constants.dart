/// Native overlay size/font contracts (mirrors windows runner C++).
///
/// Hard rule: no Desktop Voice overlay text below 16pt equivalent.
abstract final class DesktopVoiceOverlayConstants {
  static const double minFontPt = 16;
  static const double titleFontPt = 19;
  static const double detailFontPt = 16;

  static const int listeningWidthPx = 340;
  static const int listeningHeightPx = 68;
  static const int processingWidthPx = 340;
  static const int processingHeightPx = 68;
  static const int errorWidthPx = 480;
  static const int errorHeightPx = 136;
  static const int pendingWidthPx = 480;
  static const int pendingHeightPx = 124;
  static const int closeHitPx = 32;

  static const String markerMinFont16 =
      'DESKTOP_VOICE_OVERLAY_MIN_FONT_16PT';
  static const String markerErrorCard =
      'DESKTOP_VOICE_ERROR_CARD_LARGE_READABLE';
  static const String markerPendingCard =
      'DESKTOP_VOICE_PENDING_CARD_LARGE_READABLE';
  static const String markerListeningPill =
      'DESKTOP_VOICE_LISTENING_PILL_READABLE';
  static const String markerNoTinyText =
      'DESKTOP_VOICE_NO_TINY_TEXT_ANYWHERE';
}
