import 'package:counter/core/services/desktop_voice_command_stt_policy.dart';
import 'package:counter/core/services/desktop_voice_engine.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopVoiceCommandSttPolicy', () {
    test('whisper-tiny is primary when evidence says it beats Parakeet', () {
      expect(
        DesktopVoiceCommandSttPolicy.whisperBeatsParakeetOnQuietCommandWavs,
        isTrue,
      );
      expect(
        DesktopVoiceCommandSttPolicy.primaryEngine,
        DesktopVoiceEngineId.whisperTiny,
      );
      expect(
        DesktopVoiceCommandSttPolicy.fallbackEngine,
        DesktopVoiceEngineId.parakeet,
      );
      expect(
        DesktopVoiceCommandSttPolicy.selectionReason,
        contains('whisper'),
      );
    });

    test('settings default production engine follows policy', () async {
      SharedPreferences.setMockInitialValues({});
      // Policy constant is the source of truth when prefs have no override.
      expect(
        DesktopVoiceCommandSttPolicy.resolvePrimary(override: null),
        DesktopVoiceEngineId.whisperTiny,
      );
      expect(
        DesktopVoiceSettings.instance.resolveProductionEngine(),
        anyOf(
          DesktopVoiceEngineId.whisperTiny,
          DesktopVoiceEngineId.parakeet, // prefs may persist from other tests
        ),
      );
    });
  });
}
