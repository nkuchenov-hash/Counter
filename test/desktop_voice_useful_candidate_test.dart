import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_audio_capture.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useful candidate latency gate', () {
    final rules = [
      CategoryRule(
        id: 100,
        name: 'Price Reporter',
        backendRowId: 'prroot123456789',
        children: [
          CategoryRule(
            id: 103,
            name: 'Southern Computer Warehouse',
            backendRowId: 'scwclient123456',
            keywords: {
              'en': ['southern computer warehouse'],
            },
            children: [
              CategoryRule(
                id: 104,
                name: 'DEL MOD',
                backendRowId: 'scwdelmod123456',
              ),
            ],
          ),
        ],
      ),
    ];

    test('garbage partial is not counted as useful candidate', () {
      final helper = DesktopSttHelperService.instance;
      helper.evaluateCommandCandidate = (text) {
        final parsed = parseVoiceCommand(rules: rules, transcript: text);
        return (
          useful: parsed.isSafeToStart,
          parseStatus: parsed.confidence.name,
        );
      };

      final herePartial = helper.evaluateCommandCandidate!('here.');
      expect(herePartial.useful, isFalse);

      // Simulate internal gate via public evaluate callback contract.
      final garbage = helper.evaluateCommandCandidate!(
        'So then, compute theware.',
      );
      expect(garbage.useful, isFalse);

      final good = helper.evaluateCommandCandidate!(
        'Southern Computer Warehouse, DEL MOD, Submit.',
      );
      expect(good.useful, isTrue);
    });
  });

  group('capture no-signal diagnostics', () {
    test('capture exposes stream lifecycle fields', () {
      final cap = DesktopVoiceAudioCapture.instance;
      expect(cap.captureStreamStarted, isA<bool>());
      expect(cap.firstAudioFrameReceived, isA<bool>());
      expect(cap.noSignalDetected, isA<bool>());
      expect(cap.levelStreamConnected, isA<bool>());
      expect(cap.levelSource, isA<String>());
    });

    test('intermittent vs capture-start no-signal reasons differ', () {
      final cap = DesktopVoiceAudioCapture.instance;
      cap.noteCaptureStartFailed('cpal_start_failed');
      expect(cap.noSignalDetected, isTrue);
      expect(cap.noSignalReason, 'capture_start_failed:cpal_start_failed');

      cap.noteIntermittentListeningNoSignal();
      expect(cap.noSignalReason, 'intermittent_no_level_during_listening');
      expect(cap.noSignalDetected, isTrue);
    });
  });
}
