import 'dart:convert';
import 'dart:io';

import 'package:counter/core/services/desktop_voice_stt_processing.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('df696fc live quiet fixture — offline failure repro', () {
    const fixture =
        'test/fixtures/desktop_voice_wav/scw_delmod_submit_df696fc_live_quiet.wav';
    const diag =
        'test/fixtures/desktop_voice_wav/last_attempt_diag_df696fc_live_quiet.txt';

    test('fixtures archived with required markers', () {
      expect(File(fixture).existsSync(), isTrue);
      expect(File(diag).existsSync(), isTrue);
      expect(
        File(
          'test/fixtures/desktop_voice_wav/scw_delmod_submit_df696fc_live_quiet_raw.wav',
        ).existsSync(),
        isTrue,
      );
      final manifest = jsonDecode(
        File('test/fixtures/desktop_voice_wav/golden_manifest.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final markers = (manifest['markers'] as List<dynamic>).cast<String>();
      expect(
        markers,
        contains('DESKTOP_VOICE_DF696FC_LIVE_QUIET_FIXTURE_ARCHIVED'),
      );
      expect(
        markers,
        contains('DESKTOP_VOICE_LIVE_QUIET_FAILURE_REPRODUCED_OFFLINE'),
      );
    });

    test('quiet RMS matches live diag (~0.0135)', () {
      final pcm = extractPcm16FromWav(File(fixture).readAsBytesSync());
      final rms = pcm16RmsLevel(pcm);
      expect(rms, closeTo(0.0135, 0.003));
      expect(pcm16DurationMs(pcm), closeTo(5080, 400));
    });

    test('offline benchmark transcripts missing Southern (blocker)', () {
      for (final entry
          in DesktopVoiceSttProcessingPolicy.offlineBenchmarkTranscripts.entries) {
        expect(
          transcriptRecoversSouthern(entry.value),
          isFalse,
          reason: entry.key,
        );
        expect(entry.value.toLowerCase(), contains('del mod'));
        expect(entry.value.toLowerCase(), contains('submit'));
      }
      expect(
        DesktopVoiceSttProcessingPolicy.applyWhisperProcessingInProduction,
        isFalse,
      );
      expect(
        DesktopVoiceSttProcessingPolicy.offlineBlocker,
        contains('missing_southern'),
      );
    });

    test('Handy baseline is ~4x louder than df696fc live quiet', () {
      final handyPath =
          'test/fixtures/desktop_voice_wav/scw_delmod_submit_handy_2026_07_07.wav';
      if (!File(handyPath).existsSync()) return;
      final handyRms = pcm16RmsLevel(
        extractPcm16FromWav(File(handyPath).readAsBytesSync()),
      );
      final quietRms = pcm16RmsLevel(
        extractPcm16FromWav(File(fixture).readAsBytesSync()),
      );
      expect(handyRms / quietRms, greaterThan(3.0));
    });
  });
}
