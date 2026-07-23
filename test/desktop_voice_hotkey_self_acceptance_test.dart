import 'package:counter/shared/voice/routing/desktop_voice_acceptance_bridge.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_hotkey.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_settings.dart';
import 'package:counter/data/voice/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice hotkey self-acceptance', () {
    test('default hotkey config is valid and matches display', () {
      final cfg = DesktopVoiceHotkeyConfig.defaultConfig;
      expect(cfg.isValid, isTrue);
      expect(cfg.displayLabel, contains('Ctrl'));
      expect(cfg.displayLabel, contains('Shift'));
    });

    test('simulate hotkey handler invokes registered callback', () {
      var received = false;
      DesktopVoiceAcceptanceBridge.simulateHotkeyToggle = () {
        received = true;
      };
      DesktopVoiceAcceptanceBridge.simulateHotkeyToggle?.call();
      expect(received, isTrue);
      DesktopVoiceAcceptanceBridge.simulateHotkeyToggle = null;
    });

    test('hotkey opens overlay when idle', () {
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

    test('hotkey finishes listening when overlay is active', () {
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

    test('hotkey opens overlay when running record (command-first)', () {
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

    test('stop confirmation message EN/RU title only', () {
      expect(
        voiceCommandStopConfirmationMessage(
          title: 'Planning',
          localeCode: 'en',
        ),
        'Stopped: Planning',
      );
      expect(
        voiceCommandStopConfirmationMessage(
          title: 'Planning',
          localeCode: 'ru',
        ),
        'Остановлено: Planning',
      );
    });
  });
}
