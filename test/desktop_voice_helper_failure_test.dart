import 'package:counter/shared/voice/platforms/desktop/desktop_voice_hotkey.dart';
import 'package:counter/shared/voice/recognition/desktop_voice_user_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;

void main() {
  group('Helper failure isolation contracts', () {
    test('hotkey with running record opens overlay (mic not blocked by helper)', () {
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

    test('STT failure message is never raw ClientException', () {
      final friendly = DesktopVoiceUserError.fromException(
        ClientException('Connection closed before full header was received'),
        stage: DesktopVoiceErrorStage.transcribing,
        localeCode: 'en',
      );
      expect(friendly.message.toLowerCase(), isNot(contains('clientexception')));
      expect(friendly.message.toLowerCase(), isNot(contains('connection closed')));
      expect(friendly.message.toLowerCase(), isNot(contains('127.0.0.1')));
    });

    test('parsing stage uses could not recognize message', () {
      final friendly = DesktopVoiceUserError.fromException(
        'no_match',
        stage: DesktopVoiceErrorStage.parsing,
        localeCode: 'en',
      );
      expect(friendly.message, 'Could not recognize the command');
    });
  });
}
