import 'dart:io';

import 'package:counter/shared/voice/platforms/desktop/desktop_stt_helper_service.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_installed_identity.dart';
import 'package:counter/shared/voice/recognition/desktop_voice_user_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop voice installed identity', () {
    test('expected installed paths are well-formed on Windows', () {
      if (!Platform.isWindows) return;
      expect(DesktopVoiceInstalledIdentity.expectedInstalledExe, isNotEmpty);
      expect(DesktopVoiceInstalledIdentity.expectedHelperPath, isNotEmpty);
      expect(
        DesktopVoiceInstalledIdentity.expectedInstalledExe.toLowerCase(),
        contains('programs${Platform.pathSeparator}counter${Platform.pathSeparator}counter.exe'),
      );
    });

    test('diagnostic map includes build and path fields', () {
      final map = DesktopVoiceInstalledIdentity.toDiagnosticMap();
      expect(map.containsKey('running_exe_path'), isTrue);
      expect(map.containsKey('build_sha'), isTrue);
      expect(map.containsKey('build_time'), isTrue);
      expect(map.containsKey('is_installed_app'), isTrue);
      expect(map.containsKey('helper_expected_path'), isTrue);
    });
  });

  group('STT failure classification', () {
    test('empty transcript is not parser rejected', () {
      final kind = DesktopVoiceUserError.classifySttFailure(
        audioLevelSeen: true,
        errorText: 'Empty transcript',
        transcribeErrorKind: 'empty_transcript',
        helperExists: true,
        modelExists: true,
        helperReady: true,
      );
      expect(kind, DesktopVoiceFailureKind.sttEmptyTranscript);
    });

    test('mic no signal when no audio level seen', () {
      final kind = DesktopVoiceUserError.classifySttFailure(
        audioLevelSeen: false,
        errorText: 'Not enough audio',
      );
      expect(kind, DesktopVoiceFailureKind.micNoSignal);
    });

    test('helper missing maps to recognizer unavailable', () {
      final kind = DesktopVoiceUserError.classifySttFailure(
        audioLevelSeen: true,
        errorText: 'STT helper not found',
        helperExists: false,
        modelExists: false,
        helperReady: false,
      );
      expect(kind, DesktopVoiceFailureKind.recognizerUnavailable);
    });
  });

  group('Mic bar preservation markers', () {
    test('stt service exposes overlay level event hook', () {
      expect(
        DesktopSttHelperService.instance.noteOverlayLevelEvent,
        isNotNull,
      );
    });
  });
}
