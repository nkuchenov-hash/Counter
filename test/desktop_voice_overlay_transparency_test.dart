import 'package:counter/core/services/desktop_voice_overlay_transparency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopVoiceOverlayTransparency', () {
    test('transparent when layered colorkey and no backdrop', () {
      expect(
        DesktopVoiceOverlayTransparency.isTransparentBackground(
          windowTransparent: true,
          backgroundMode:
              DesktopVoiceOverlayTransparency.backgroundModeTransparent,
          hasBackdrop: false,
          blackBackdropDetected: false,
        ),
        isTrue,
      );
    });

    test('rejects black backdrop / opaque popup', () {
      expect(
        DesktopVoiceOverlayTransparency.isTransparentBackground(
          windowTransparent: false,
          backgroundMode:
              DesktopVoiceOverlayTransparency.backgroundModeOpaque,
          hasBackdrop: true,
          blackBackdropDetected: true,
        ),
        isFalse,
      );
      expect(
        DesktopVoiceOverlayTransparency.isTransparentBackground(
          windowTransparent: true,
          backgroundMode:
              DesktopVoiceOverlayTransparency.backgroundModeTransparent,
          hasBackdrop: false,
          blackBackdropDetected: true,
        ),
        isFalse,
      );
    });

    test('card color must differ from color key', () {
      expect(
        DesktopVoiceOverlayTransparency.cardColorSafeForColorKey(
          cardRgb: DesktopVoiceOverlayTransparency.cardBackgroundRgb,
          keyRgb: DesktopVoiceOverlayTransparency.colorKeyRgb,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceOverlayTransparency.cardColorSafeForColorKey(
          cardRgb: 0x000000,
          keyRgb: 0x000000,
        ),
        isFalse,
      );
    });

    test('required markers are stable', () {
      expect(
        DesktopVoiceOverlayTransparency.markerTransparentBackground,
        'DESKTOP_VOICE_OVERLAY_TRANSPARENT_BACKGROUND',
      );
      expect(
        DesktopVoiceOverlayTransparency.markerNoBlackBackdrop,
        'DESKTOP_VOICE_NO_BLACK_OVERLAY_BACKDROP',
      );
      expect(
        DesktopVoiceOverlayTransparency.markerNoModalDim,
        'DESKTOP_VOICE_NO_MODAL_DIM_BACKDROP',
      );
      expect(
        DesktopVoiceOverlayTransparency.markerNativeAlpha,
        'DESKTOP_VOICE_NATIVE_OVERLAY_ALPHA_ENABLED',
      );
    });
  });
}
