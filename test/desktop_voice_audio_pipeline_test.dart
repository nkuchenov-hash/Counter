import 'dart:convert';
import 'dart:io';

import 'package:counter/core/services/desktop_stt_quality_evaluation.dart';
import 'package:counter/core/services/desktop_voice_wav_stt_benchmark.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop Voice raw STT quality evaluation flags', () {
    test('raw mode excludes alias/postprocess from quality proof', () {
      expect(
        DesktopSttQualityEvaluation.sttQualityMode,
        'raw_transcript_evaluation',
      );
      expect(
        DesktopSttQualityEvaluation.aliasPostprocessUsedForQuality,
        isFalse,
      );
    });
  });

  group('Desktop Voice real WAV fixture manifest', () {
    test('golden manifest stores GOLOS-equivalent ceiling transcript', () {
      final file = File(DesktopVoiceWavSttBenchmark.manifestFile);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        json['golos_equivalent_raw_transcript'],
        'Solvan Computer Warehouse, Delmore, Submit.',
      );
      expect(json['strict_domain_pass'], isFalse);
    });

    test('SCW real WAV fixture exists with PCM payload', () {
      const path =
          'test/fixtures/desktop_voice_wav/scw_delmod_submit_real_2026_07_07.wav';
      expect(File(path).existsSync(), isTrue);
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, greaterThan(44));
      final pcm = bytes.sublist(44);
      expect(pcm16DurationMs(pcm), greaterThan(500));
    });

    test('token error rate improves when transcript matches expected phrase', () {
      const baseline = 'Solvent computer warehouse still model submit';
      const expected = 'Southern Computer Warehouse DEL MOD submit';
      const improved = 'Southern Computer Warehouse DEL MOD submit';
      final baselineTer = DesktopVoiceWavSttBenchmark.tokenErrorRate(
        baseline,
        expected,
      );
      final newTer = DesktopVoiceWavSttBenchmark.tokenErrorRate(
        improved,
        expected,
      );
      expect(newTer, lessThan(baselineTer));
      expect(
        DesktopVoiceWavSttBenchmark.improvementPercent(
          baselineTer: baselineTer,
          newTer: newTer,
        ),
        greaterThan(0),
      );
    });

    test('domain term hits require raw STT tokens not alias repair', () {
      final hits = DesktopVoiceWavSttBenchmark.domainTermHits(
        'Southern Computer Warehouse DEL MOD submit',
        const ['Southern Computer Warehouse', 'DEL MOD', 'Submit'],
      );
      expect(hits['Southern Computer Warehouse'], isTrue);
      expect(hits['DEL MOD'], isTrue);
      expect(hits['Submit'], isTrue);
      final bad = DesktopVoiceWavSttBenchmark.domainTermHits(
        'Solvent computer warehouse still model submit',
        const ['Southern Computer Warehouse', 'DEL MOD', 'Submit'],
      );
      expect(bad['Southern Computer Warehouse'], isFalse);
      expect(bad['DEL MOD'], isFalse);
    });
  });

  group('Desktop Voice real WAV helper benchmark', () {
    test('replay SCW WAV through local helper when available', () async {
      final cases = DesktopVoiceWavSttBenchmark.loadManifestCases();
      final scw = cases.firstWhere((c) => c.id == 'scw_delmod_submit_real');
      if (!DesktopVoiceWavSttBenchmark.helperLikelyAvailable()) {
        return;
      }
      final result = await DesktopVoiceWavSttBenchmark.runCase(
        caseDef: scw,
        helperUrl: 'http://127.0.0.1:8766',
      );
      expect(result, isNotNull);
      if (result!.error != null) {
        // ignore: avoid_print
        print('SCW helper replay skipped: ${result.error}');
        return;
      }
      // ignore: avoid_print
      print(
        'SCW raw="${result.rawTranscript}" ter=${result.tokenErrorRate} '
        'domain=${result.domainTermAccuracy} improved=${result.improvedVsBaseline}',
      );
      expect(result.improvedVsBaseline, isTrue);
      expect(
        result.rawTranscript.trim().toLowerCase(),
        'solvan computer warehouse, delmore, submit.',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
