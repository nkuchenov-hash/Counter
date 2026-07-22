import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_engine.dart';
import 'package:counter/core/services/desktop_voice_glossary.dart';
import 'package:counter/core/services/desktop_voice_recognition_postprocess.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Golden text case for STT quality gate (postprocess + parser, no mic).
class DesktopVoiceSttGoldenCase {
  const DesktopVoiceSttGoldenCase({
    required this.id,
    required this.rawStt,
    required this.expectedFinalContains,
    required this.expectedSafeStart,
    this.expectedCategoryPath,
  });

  final String id;
  final String rawStt;
  final List<String> expectedFinalContains;
  final bool expectedSafeStart;
  final String? expectedCategoryPath;
}

/// Benchmark scoring for golden command phrases.
class DesktopVoiceSttBenchmarkResult {
  const DesktopVoiceSttBenchmarkResult({
    required this.caseId,
    required this.passed,
    required this.rawStt,
    required this.finalCommandText,
    required this.parserSafe,
    this.categoryPath,
    this.reason,
  });

  final String caseId;
  final bool passed;
  final String rawStt;
  final String finalCommandText;
  final bool parserSafe;
  final String? categoryPath;
  final String? reason;
}

abstract final class DesktopSttBenchmarkHarness {
  static const qualityGateThreshold = 0.95;

  static const goldenCases = [
    DesktopVoiceSttGoldenCase(
      id: 'scw_del_mod_submit',
      rawStt: "Sovent computer warehouse they'll not submit.",
      expectedFinalContains: ['Southern Computer Warehouse', 'DEL MOD', 'Submit'],
      expectedSafeStart: true,
    ),
    DesktopVoiceSttGoldenCase(
      id: 'scw_abbrev',
      rawStt: 'SCW DEL MOD Submit',
      expectedFinalContains: ['Southern Computer Warehouse', 'DEL MOD'],
      expectedSafeStart: true,
    ),
    DesktopVoiceSttGoldenCase(
      id: 'price_reporter_planning',
      rawStt: 'Rice reporter planning',
      expectedFinalContains: ['Planning'],
      expectedSafeStart: true,
      expectedCategoryPath: 'Price Reporter',
    ),
    DesktopVoiceSttGoldenCase(
      id: 'porter_plenty',
      rawStt: 'Porter Plenty',
      expectedFinalContains: ['Planning'],
      expectedSafeStart: true,
    ),
    DesktopVoiceSttGoldenCase(
      id: 'age_add_mod',
      rawStt: 'Price Reporter AGE SOLUTIONS ADD MOD',
      expectedFinalContains: ['ADD MOD'],
      expectedSafeStart: true,
    ),
    DesktopVoiceSttGoldenCase(
      id: 'blink_submit',
      rawStt: 'BLINK Submit',
      expectedFinalContains: ['BLINK', 'Submit'],
      expectedSafeStart: true,
    ),
    DesktopVoiceSttGoldenCase(
      id: 'laredo_sin',
      rawStt: 'Laredo Technical Services add scene',
      expectedFinalContains: ['Laredo', 'ADD SIN'],
      expectedSafeStart: true,
    ),
  ];

  static List<CategoryRule> minimalFixtureRules() {
    return [
      CategoryRule(
        id: 100,
        name: 'Price Reporter',
        backendRowId: 'prroot123456789',
        children: [
          CategoryRule(
            id: 101,
            name: 'Southern Computer Warehouse',
            backendRowId: 'scwclient123456',
            keywords: {'en': ['scw', 'southern computer warehouse']},
          ),
          CategoryRule(
            id: 102,
            name: 'AGE SOLUTIONS',
            backendRowId: 'ageclient123456',
            keywords: {'en': ['age solutions']},
          ),
      CategoryRule(
        id: 103,
        name: 'BLINK',
        backendRowId: 'blinkcat1234567',
        children: [
          CategoryRule(
            id: 104,
            name: 'DEL MOD',
            backendRowId: 'blinkdelmod1234',
          ),
        ],
      ),
        ],
      ),
      CategoryRule(
        id: 200,
        name: 'Laredo Technical Services',
        backendRowId: 'laredoroot12345',
        keywords: {'en': ['laredo ts', 'laredo technical services']},
      ),
    ];
  }

  static List<DesktopVoiceSttBenchmarkResult> runGoldenTextBenchmark({
    List<CategoryRule>? rules,
  }) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_BENCHMARK_READY');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_BENCHMARK_RUN');

    final r = rules ?? minimalFixtureRules();
    final glossary = DesktopVoiceGlossaryPack.buildFromCategoryRules(r);
    final results = <DesktopVoiceSttBenchmarkResult>[];

    for (final c in goldenCases) {
      final post = DesktopVoiceRecognitionPostprocess.apply(
        rawModelText: c.rawStt,
        glossary: glossary,
      );
      final finalText = post.finalCommandText;
      final parsed = parseVoiceCommand(
        rules: r,
        transcript: finalText,
        taskTitleHints: glossary.taskTitles,
      );

      var passed = true;
      String? reason;
      final lower = finalText.toLowerCase();
      for (final needle in c.expectedFinalContains) {
        if (!lower.contains(needle.toLowerCase())) {
          passed = false;
          reason = 'missing:$needle';
          break;
        }
      }
      if (passed && c.expectedSafeStart != parsed.isSafeToStart) {
        passed = false;
        reason = 'parser_safe=${parsed.isSafeToStart}';
      }
      if (passed &&
          c.expectedCategoryPath != null &&
          !(parsed.matchedCategoryDisplayPath ?? '')
              .contains(c.expectedCategoryPath!)) {
        passed = false;
        reason = 'path=${parsed.matchedCategoryDisplayPath}';
      }

      results.add(
        DesktopVoiceSttBenchmarkResult(
          caseId: c.id,
          passed: passed,
          rawStt: c.rawStt,
          finalCommandText: finalText,
          parserSafe: parsed.isSafeToStart,
          categoryPath: parsed.matchedCategoryDisplayPath,
          reason: reason,
        ),
      );
    }

    final passRate = results.isEmpty
        ? 0.0
        : results.where((r) => r.passed).length / results.length;
    if (passRate >= qualityGateThreshold) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_QUALITY_GATE_PASS');
    }
    final winner = passRate >= qualityGateThreshold ? 'postprocess+parser' : 'none';
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_BENCHMARK_WINNER', winner);

    return results;
  }

  static double passRate(List<DesktopVoiceSttBenchmarkResult> results) {
    if (results.isEmpty) return 0;
    return results.where((r) => r.passed).length / results.length;
  }
}
