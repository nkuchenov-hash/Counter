import 'dart:typed_data';

import 'package:counter/data/ai/viktor_voice_recorder.dart';
import 'package:counter/features/viktor/viktor_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Viktor WAV is a complete mono 16kHz PCM16 recording', () {
    final pcm = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
    final wav = buildViktorWav(pcm);
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(data.getUint32(4, Endian.little), 42);
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 16000);
    expect(data.getUint16(34, Endian.little), 16);
    expect(data.getUint32(40, Endian.little), 6);
    expect(wav.sublist(44), pcm);
  });

  test('Viktor rejects invalid unaligned PCM chunks', () {
    expect(() => buildViktorWav(Uint8List(0)), throwsArgumentError);
    expect(() => buildViktorWav(Uint8List(3)), throwsArgumentError);
  });

  SharedPreferences.setMockInitialValues(<String, Object>{});

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

  for (final width in <double>[320, 390, 768]) {
    testWidgets('Viktor composer never overflows at width $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: ViktorChatPage(wallDay: DateTime(2026, 10, 17)),
      ));
      await tester.pump();
      expect(find.text('Виктор'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      final editor = tester.getRect(find.byType(TextField).first);
      expect(editor.left, greaterThanOrEqualTo(0));
      expect(editor.right, lessThanOrEqualTo(width));
    });
  }
}
