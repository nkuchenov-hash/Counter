import 'package:counter/shared/voice/platforms/desktop/desktop_stt_helper_service.dart';
import 'package:counter/shared/voice/commands/desktop_voice_delayed_transcribe.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_hotkey.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_overlay_bridge.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_overlay_constants.dart';
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
      // Mirrors windows/runner/desktop_voice_native_overlay.cpp + Dart constants.
      expect(
        DesktopVoiceOverlayConstants.minFontPt,
        greaterThanOrEqualTo(16),
      );
      expect(
        DesktopVoiceOverlayConstants.titleFontPt,
        inInclusiveRange(16, 18),
      );
      expect(
        DesktopVoiceOverlayConstants.detailFontPt,
        greaterThanOrEqualTo(16),
      );
      expect(
        DesktopVoiceOverlayConstants.listeningWidthPx,
        inInclusiveRange(300, 360),
      );
      expect(
        DesktopVoiceOverlayConstants.listeningHeightPx,
        inInclusiveRange(64, 72),
      );
      expect(
        DesktopVoiceOverlayConstants.errorWidthPx,
        inInclusiveRange(520, 680),
      );
      expect(
        DesktopVoiceOverlayConstants.errorMinHeightPx,
        inInclusiveRange(120, 200),
      );
      expect(
        DesktopVoiceOverlayConstants.pendingWidthPx,
        inInclusiveRange(520, 680),
      );
      expect(
        DesktopVoiceOverlayConstants.pendingMinHeightPx,
        inInclusiveRange(110, 200),
      );
      expect(
        DesktopVoiceOverlayConstants.closeHitPx,
        greaterThanOrEqualTo(32),
      );
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
