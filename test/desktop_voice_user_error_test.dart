import 'package:counter/shared/voice/recognition/desktop_voice_user_error.dart';
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

    test('empty transcript maps to stt empty message not parser reject', () {
      final err = DesktopVoiceUserError.fromException(
        'Empty transcript',
        stage: DesktopVoiceErrorStage.transcribing,
        localeCode: 'ru',
        kind: DesktopVoiceFailureKind.sttEmptyTranscript,
      );
      expect(err.message, 'Не удалось получить текст');
      expect(err.message, isNot(contains('распознать команду')));
    });

    test('parser stage maps to command not recognized', () {
      final err = DesktopVoiceUserError.fromException(
        '',
        stage: DesktopVoiceErrorStage.parsing,
        localeCode: 'en',
        kind: DesktopVoiceFailureKind.parserRejected,
      );
      expect(err.message, 'Could not recognize the command');
    });
  });
}
