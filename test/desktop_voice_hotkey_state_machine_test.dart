import 'package:counter/core/services/desktop_voice_hotkey.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice hotkey state machine', () {
    test('State A: idle opens overlay', () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: false,
          overlayListening: false,
          overlayPreparing: false,
          overlayProcessing: false,
          hasRunningRecord: false,
        ),
        DesktopVoiceHotkeyAction.openOverlay,
      );
    });

    test('State B: listening finishes on second hotkey', () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: true,
          overlayListening: true,
          overlayPreparing: false,
          overlayProcessing: false,
          hasRunningRecord: false,
        ),
        DesktopVoiceHotkeyAction.finishListening,
      );
    });

    test('State D: running record opens overlay (command-first)', () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: false,
          overlayListening: false,
          overlayPreparing: false,
          overlayProcessing: false,
          hasRunningRecord: true,
        ),
        DesktopVoiceHotkeyAction.openOverlay,
      );
    });

    test('listening takes priority over running record', () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: true,
          overlayListening: true,
          overlayPreparing: false,
          overlayProcessing: false,
          hasRunningRecord: true,
        ),
        DesktopVoiceHotkeyAction.finishListening,
      );
    });

    test('overlay preparing cancels on second hotkey', () {
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

    test('overlay preparing with running record cancels overlay not stop', () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: true,
          overlayListening: false,
          overlayPreparing: true,
          overlayProcessing: false,
          hasRunningRecord: true,
        ),
        DesktopVoiceHotkeyAction.cancelOverlay,
      );
    });

    test('overlay processing cancels on hotkey', () {
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

    test('overlay error state dismisses on hotkey', () {
      expect(
        resolveDesktopVoiceHotkeyAction(
          overlayOpen: true,
          overlayListening: false,
          overlayPreparing: false,
          overlayProcessing: false,
          hasRunningRecord: false,
        ),
        DesktopVoiceHotkeyAction.cancelOverlay,
      );
    });
  });
}
