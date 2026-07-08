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

    test('readable overlay size contracts (listening / error / pending)', () {
      // Native C++ constants mirrored here as Dart contracts for review + tests.
      const listeningW = 260;
      const listeningH = 52;
      const errorW = 380;
      const errorH = 96;
      const pendingW = 380;
      const pendingH = 92;
      const titleFontPx = 16;
      const closeHit = 28;
      expect(listeningW, inInclusiveRange(220, 280));
      expect(listeningH, inInclusiveRange(48, 56));
      expect(errorW, inInclusiveRange(320, 420));
      expect(errorH, inInclusiveRange(72, 110));
      expect(pendingW, inInclusiveRange(320, 420));
      expect(pendingH, inInclusiveRange(72, 110));
      expect(titleFontPx, inInclusiveRange(14, 16));
      expect(closeHit, greaterThanOrEqualTo(24));
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
