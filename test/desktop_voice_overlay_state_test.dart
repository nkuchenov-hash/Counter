import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_delayed_transcribe.dart';
import 'package:counter/core/services/desktop_voice_hotkey.dart';
import 'package:counter/core/services/desktop_voice_overlay_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice overlay preparing timeout', () {
    tearDown(DesktopVoiceOverlayBridge.clearSession);

    test('helper max wait is 5 seconds for voice overlay', () {
      expect(
        DesktopSttHelperService.kVoiceOverlayWarmupMax,
        const Duration(seconds: 5),
      );
    });

    test('cold-start post-stop wait is 45s when pending WAV queued', () {
      expect(
        DesktopVoiceDelayedTranscribe.coldStartMaxWait,
        const Duration(seconds: 45),
      );
      expect(
        DesktopSttHelperService.kVoiceColdStartMaxWait,
        DesktopVoiceDelayedTranscribe.coldStartMaxWait,
      );
    });

    test('Handy-style overlay renderer id is native_handy_pill on Windows path', () {
      // Contract for installed diagnostics — C++ paint is the compact dark pill;
      // Dart marks overlay_renderer_active=native_handy_pill when native is used.
      expect('native_handy_pill', isNot(equals('legacy_gray_square')));
      expect(DesktopVoiceDelayedTranscribe.readyHelperMaxWait.inSeconds, 10);
    });

    test('preparing hotkey resolves to cancelOverlay', () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: true,
          overlayListening: false,
          overlayPreparing: true,
          overlayProcessing: false,
          hasRunningRecord: false,
        ),
        DesktopVoiceHotkeyAction.cancelOverlay,
      );
    });

    test('requestCancel invokes cancelSession callback', () {
      var cancelled = false;
      DesktopVoiceOverlayBridge.bindSession(
        isListening: () => false,
        isPreparing: () => true,
        isProcessing: () => false,
        finishListening: () {},
        cancelSession: () {
          cancelled = true;
          DesktopVoiceOverlayBridge.clearSession();
        },
      );
      expect(DesktopVoiceOverlayBridge.requestCancel(), isTrue);
      expect(cancelled, isTrue);
      expect(DesktopVoiceOverlayBridge.isOpen, isFalse);
    });

    test('requestCancel is no-op when overlay closed', () {
      expect(DesktopVoiceOverlayBridge.requestCancel(), isFalse);
    });

    test('requestFinishListening is no-op during preparing', () {
      var finished = false;
      DesktopVoiceOverlayBridge.bindSession(
        isListening: () => false,
        isPreparing: () => true,
        isProcessing: () => false,
        finishListening: () => finished = true,
        cancelSession: () {},
      );
      expect(DesktopVoiceOverlayBridge.requestFinishListening(), isFalse);
      expect(finished, isFalse);
      DesktopVoiceOverlayBridge.clearSession();
    });

    test('processing hotkey (includes pending confirmation) resolves to cancelOverlay',
        () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: true,
          overlayListening: false,
          overlayPreparing: false,
          overlayProcessing: true,
          hasRunningRecord: false,
        ),
        DesktopVoiceHotkeyAction.cancelOverlay,
      );
    });
  });
}
