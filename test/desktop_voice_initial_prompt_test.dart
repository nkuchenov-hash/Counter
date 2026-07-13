import 'package:counter/core/services/desktop_voice_initial_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('helper build script injects neutral initial_prompt', () {
    final script = File('installer/windows/build_stt_helper_en.ps1');
    expect(script.existsSync(), isTrue);
    final content = script.readAsStringSync();
    expect(content, contains(DesktopVoiceInitialPrompt.effectivePrompt));
    expect(content, isNot(contains('Southern Computer Warehouse')));
    expect(content, isNot(contains('BLINK')));
    expect(content, isNot(contains('Laredo')));
  });
}
