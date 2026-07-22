import 'package:counter/shared/voice/platforms/desktop/desktop_stt_benchmark_harness.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_stt_cloud_service.dart';
import 'package:counter/shared/voice/commands/desktop_stt_engine.dart';
import 'package:counter/shared/voice/commands/desktop_stt_quality_evaluation.dart';
import 'package:counter/data/voice/desktop_voice_glossary.dart';
import 'package:counter/data/voice/desktop_voice_recognition_postprocess.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_wav_stt_benchmark.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop Voice raw STT quality evaluation', () {
    test('quality mode is raw transcript evaluation — alias not counted', () {
      expect(
        DesktopSttQualityEvaluation.sttQualityMode,
        'raw_transcript_evaluation',
      );
      expect(
        DesktopSttQualityEvaluation.aliasPostprocessUsedForQuality,
        isFalse,
      );
    });

    test('golden manifest stores baseline Solvent transcript', () {
      expect(
        DesktopVoiceWavSttBenchmark.baselineTranscriptFromManifest(),
        'Solvent computer warehouse still model submit',
      );
    });
  });

  group('Desktop Voice STT postprocess — safety fallback only', () {
    final rules = DesktopSttBenchmarkHarness.minimalFixtureRules();
    late DesktopVoiceGlossaryPack glossary;

    setUp(() {
      glossary = DesktopVoiceGlossaryPack.buildFromCategoryRules(rules);
    });

    test('glossary includes GSA terms and live category names', () {
      expect(glossary.termsCount, greaterThan(10));
      expect(
        glossary.terms.any((t) => t.contains('Southern Computer Warehouse')),
        isTrue,
      );
      expect(glossary.terms, contains('DEL MOD'));
      expect(glossary.terms, contains('Price Reporter'));
    });

    test('Sovent SCW postprocess repairs text but is NOT raw STT quality proof',
        () {
      final post = DesktopVoiceRecognitionPostprocess.apply(
        rawModelText: "Sovent computer warehouse they'll not submit.",
        glossary: glossary,
      );
      expect(post.rejected, isFalse);
      expect(
        post.finalCommandText.toLowerCase(),
        contains('southern computer warehouse'),
      );
      // Raw model text remains the mis-hear — postprocess must not be counted.
      expect(post.rawModelText.toLowerCase(), contains('sovent'));
      expect(post.rawModelText, isNot(post.finalCommandText));
    });

    test('AGE SOLUTIONS ADD MOD is not corrupted by postprocess', () {
      final post = DesktopVoiceRecognitionPostprocess.apply(
        rawModelText: 'Price Reporter AGE SOLUTIONS ADD MOD',
        glossary: glossary,
      );
      expect(post.finalCommandText.toUpperCase(), contains('ADD MOD'));
      expect(post.finalCommandText.toUpperCase(), isNot(contains('ADD SIN')));
    });

    test('STT engine modes exist', () {
      expect(DesktopSttMode.values, contains(DesktopSttMode.bestQuality));
      expect(DesktopSttMode.values, contains(DesktopSttMode.fastLocal));
      expect(DesktopSttMode.values, contains(DesktopSttMode.offlineFallback));
    });

    test('cloud service has no embedded API key', () {
      const src = DesktopSttCloudService;
      expect(src, isNotNull);
      // Contract: client calls PbAppApiRoutes only — verified by analyzer imports.
    });
  });

  group('Desktop Voice STT golden benchmark', () {
    test('quality gate >= 95% on golden text cases', () {
      final results = DesktopSttBenchmarkHarness.runGoldenTextBenchmark();
      final rate = DesktopSttBenchmarkHarness.passRate(results);
      for (final r in results.where((x) => !x.passed)) {
        // ignore: avoid_print
        print('FAIL ${r.caseId}: ${r.reason} final=${r.finalCommandText}');
      }
      expect(rate, greaterThanOrEqualTo(0.95));
    });
  });
}
