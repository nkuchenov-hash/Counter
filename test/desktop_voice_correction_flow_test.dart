import 'package:counter/shared/voice/commands/desktop_voice_correction_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopVoiceCorrectionFlow', () {
    test('blocks duplicate open while already open', () {
      expect(
        DesktopVoiceCorrectionFlow.mayOpenCorrection(
          pendingVisible: true,
          correctionAlreadyOpen: true,
          sessionCancelled: false,
        ),
        isFalse,
      );
    });

    test('allows single open when pending visible', () {
      expect(
        DesktopVoiceCorrectionFlow.mayOpenCorrection(
          pendingVisible: true,
          correctionAlreadyOpen: false,
          sessionCancelled: false,
        ),
        isTrue,
      );
    });

    test('session is single-instance and blocks second begin', () {
      final s = DesktopVoiceCorrectionSession(pendingCommandId: 'p1');
      expect(s.tryBeginOpen(), isTrue);
      expect(s.panelCount, 1);
      expect(s.tryBeginOpen(), isFalse);
      expect(s.duplicateBlocked, isTrue);
      expect(s.panelCount, 1);
    });

    test('overlay hidden while correcting; cancel does not write', () {
      expect(
        DesktopVoiceCorrectionFlow.shouldHideOverlayForCorrection(
          correctionOpenRequested: true,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceCorrectionFlow.cancelRequestsWrite(cancelled: true),
        isFalse,
      );
    });

    test('confirm no-op detected when unsafe or write skipped', () {
      expect(
        DesktopVoiceCorrectionFlow.confirmIsNoOp(
          confirmed: true,
          parseSafeToStart: false,
          writeRequested: false,
        ),
        isTrue,
      );
      expect(
        DesktopVoiceCorrectionFlow.confirmIsNoOp(
          confirmed: true,
          parseSafeToStart: true,
          writeRequested: true,
        ),
        isFalse,
      );
    });

    test('required markers are stable', () {
      expect(
        DesktopVoiceCorrectionFlow.markerSingleInstance,
        'DESKTOP_VOICE_CORRECTION_SINGLE_INSTANCE',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerOpensInFront,
        'DESKTOP_VOICE_CORRECTION_OPENS_IN_FRONT',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerOverlayHidden,
        'DESKTOP_VOICE_OVERLAY_HIDDEN_WHILE_CORRECTING',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerNoXRequired,
        'DESKTOP_VOICE_CORRECTION_NO_X_REQUIRED',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerDuplicateBlocked,
        'DESKTOP_VOICE_CORRECTION_DUPLICATE_OPEN_BLOCKED',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerReparsed,
        'DESKTOP_VOICE_CORRECTED_COMMAND_REPARSED',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerWritesAfterConfirm,
        'DESKTOP_VOICE_CORRECTED_COMMAND_WRITES_AFTER_CONFIRM',
      );
      expect(
        DesktopVoiceCorrectionFlow.markerCancelNoWrite,
        'DESKTOP_VOICE_CORRECTION_CANCEL_NO_WRITE',
      );
    });
  });
}
