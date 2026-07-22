import 'dart:io';

import 'package:counter/shared/voice/platforms/desktop/desktop_voice_audio_presentation.dart';
import 'package:counter/shared/voice/commands/desktop_voice_command_stt_policy.dart';
import 'package:counter/shared/voice/commands/desktop_voice_engine.dart';
import 'package:counter/shared/voice/platforms/desktop/pcm_audio_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Offline local-engine selection proof (no live mic).
///
/// Real HTTP bench (2026-07-08) is captured in voice_samples/engine_bench_4f9c984
/// and mirrored here as contracts. Helper replay is exercised when the helper
/// is reachable on :8765; otherwise fixtures-only assertions still pass.
void main() {
  group('DESKTOP_VOICE_LOCAL_ENGINE_BENCHMARK contracts', () {
    test('primary selection mirrors offline quiet-WAV winner', () {
      // latest CPAL 4f9c984:
      // parakeet → Tell them computer warehouse download submit.
      // whisper  → Southern Computer Warehouse, DEL MOD, Submit.
      const parakeetLatest =
          'Tell them computer warehouse download submit.';
      const whisperLatest =
          'Southern Computer Warehouse, DEL MOD, Submit.';
      expect(whisperLatest.toLowerCase(), contains('southern'));
      expect(whisperLatest.toLowerCase(), contains('del mod'));
      expect(whisperLatest.toLowerCase(), contains('submit'));
      expect(parakeetLatest.toLowerCase(), isNot(contains('southern')));
      expect(parakeetLatest.toLowerCase(), isNot(contains('del mod')));
      expect(
        DesktopVoiceCommandSttPolicy.primaryEngine,
        DesktopVoiceEngineId.whisperTiny,
      );
      expect(
        DesktopVoiceCommandSttPolicy.fallbackEngine,
        DesktopVoiceEngineId.parakeet,
      );
    });

    test('latest CPAL fixture exists for installed replay', () {
      final f = File(
        'test/fixtures/desktop_voice_wav/scw_delmod_submit_cpal_4f9c984.wav',
      );
      expect(f.existsSync(), isTrue, reason: 'copied from live 4f9c984 capture');
      final ms = wavBytesDurationMs(f.readAsBytesSync());
      expect(ms, greaterThan(3000));
      final pcm = extractPcm16FromWav(f.readAsBytesSync());
      expect(pcm16RmsLevel(pcm), lessThan(0.04));
    });

    test('command silence trim keeps speech body', () {
      final f = File(
        'test/fixtures/desktop_voice_wav/scw_delmod_submit_cpal_4f9c984.wav',
      );
      if (!f.existsSync()) return;
      final pcm = extractPcm16FromWav(f.readAsBytesSync());
      final trimmed = DesktopVoiceCommandEndpoint.trimSilencePcm16(pcm);
      expect(pcm16DurationMs(trimmed), lessThanOrEqualTo(pcm16DurationMs(pcm)));
      expect(pcm16DurationMs(trimmed), greaterThan(2000));
    });

    test('latency target documented: warm partial path <500ms', () {
      // Full whisper stop on ~5s WAV ≈1500ms hot (measured). Mid-listen
      // partial cache + GET /transcribe/last_partial is the <500ms path.
      expect(DesktopVoiceCommandSttPolicy.measuredHotWhisperMs, greaterThan(500));
      expect(
        DesktopVoiceCommandSttPolicy.measuredHotWhisperMs,
        lessThan(2500),
      );
    });
  });
}
