import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice no-preparing UI', () {
    test('overlay service redirects showPreparing to showListening', () {
      final src = File('lib/shared/voice/platforms/desktop/desktop_voice_overlay_service.dart')
          .readAsStringSync();
      expect(src.contains('desktop_voice_overlay_stt_warming'), isFalse);
      expect(src.contains("state: 'preparing'"), isFalse);
      expect(
        src.contains('DESKTOP_VOICE_FORBIDDEN_PREPARING_REDIRECTED_TO_LISTENING'),
        isTrue,
      );
      expect(src.contains('return showListening'), isTrue);
    });

    test('widget opens native overlay with showListening not showPreparing', () {
      final src =
          File('lib/shared/voice/platforms/desktop/ui/desktop_voice_widget.dart').readAsStringSync();
      expect(src.contains('showPreparing()'), isFalse);
      expect(src.contains('showListening('), isTrue);
      expect(src.contains('desktop_voice_overlay_stt_warming'), isFalse);
    });

    test('l10n has no forbidden preparing overlay strings', () {
      for (final path in ['lib/l10n/langs/en.dart', 'lib/l10n/langs/ru.dart']) {
        final text = File(path).readAsStringSync();
        expect(text.contains('desktop_voice_overlay_stt_warming'), isFalse);
        expect(text.contains('desktop_voice_overlay_preparing'), isFalse);
        expect(text.contains('Preparing speech recognition'), isFalse);
        expect(text.contains('Подготовка распознавания'), isFalse);
      }
    });
  });
}
