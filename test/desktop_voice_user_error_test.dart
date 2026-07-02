import 'package:counter/core/services/desktop_voice_user_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;

void main() {
  group('DesktopVoiceUserError', () {
    test('ClientException connection closed maps to recognizer unavailable', () {
      final err = DesktopVoiceUserError.fromException(
        ClientException('Connection closed before full header was received'),
        stage: DesktopVoiceErrorStage.transcribing,
        localeCode: 'en',
      );
      expect(err.message, 'Recognizer is unavailable');
      expect(DesktopVoiceUserError.looksTechnical(err.technicalDetail), isTrue);
      expect(err.message.contains('ClientException'), isFalse);
    });

    test('RU transcribing failure uses friendly RU message', () {
      final err = DesktopVoiceUserError.fromException(
        ClientException('Connection closed before full header was received'),
        stage: DesktopVoiceErrorStage.transcribing,
        localeCode: 'ru',
      );
      expect(err.message, 'Распознаватель недоступен');
    });

    test('looksTechnical blocks raw exception text in overlay', () {
      expect(
        DesktopVoiceUserError.looksTechnical(
          'ClientException: Connection closed before full header was received, uri=http://127.0.0.1:8765/transcribe',
        ),
        isTrue,
      );
      expect(
        DesktopVoiceUserError.looksTechnical('Could not recognize the command'),
        isFalse,
      );
    });

    test('resolve keeps user-safe message unchanged', () {
      final err = DesktopVoiceUserError.resolve(
        message: 'Try again',
        error: ClientException('boom'),
        stage: DesktopVoiceErrorStage.listening,
        localeCode: 'en',
      );
      expect(err.message, 'Try again');
    });

    test('no mic signal stage', () {
      final err = DesktopVoiceUserError.fromException(
        'Not enough audio',
        stage: DesktopVoiceErrorStage.listening,
        localeCode: 'en',
      );
      expect(err.message, 'No microphone signal');
    });
  });
}
