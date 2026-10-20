import 'package:counter/features/viktor/viktor_chat_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web Russian uses valid BCP-47 and ignores native underscore IDs', () {
    expect(
      viktorSpeechLocaleId(
        language: 'ru',
        isWeb: true,
        availableLocales: const ['ru_RU'],
      ),
      'ru-RU',
    );
  });

  test('web English uses valid BCP-47', () {
    expect(
      viktorSpeechLocaleId(
        language: 'en',
        isWeb: true,
        availableLocales: const [],
      ),
      'en-US',
    );
  });

  test('native prefers exact installed locale spelling', () {
    expect(
      viktorSpeechLocaleId(
        language: 'ru',
        isWeb: false,
        availableLocales: const ['en_US', 'ru_RU', 'ru_UA'],
      ),
      'ru_RU',
    );
  });

  test('native accepts alternate Russian region', () {
    expect(
      viktorSpeechLocaleId(
        language: 'ru',
        isWeb: false,
        availableLocales: const ['en-US', 'ru-UA'],
      ),
      'ru-UA',
    );
  });

  test('native never falls back to an unrelated installed language', () {
    expect(
      viktorSpeechLocaleId(
        language: 'ru',
        isWeb: false,
        availableLocales: const ['en-US', 'es-ES'],
      ),
      isNull,
    );
  });

  test('empty native locale list delegates to recognizer default', () {
    expect(
      viktorSpeechLocaleId(
        language: 'ru',
        isWeb: false,
        availableLocales: const [],
      ),
      isNull,
    );
  });
}
