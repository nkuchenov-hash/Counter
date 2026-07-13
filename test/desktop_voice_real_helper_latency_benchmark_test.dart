import 'dart:io';

import 'package:counter/core/services/desktop_voice_real_helper_latency_benchmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DESKTOP_VOICE_REAL_HELPER_LATENCY_BENCHMARK', () {
    test('warm P95 useful-candidate latency on installed helper', () async {
      if (Platform.environment['REAL_HELPER_LATENCY_BENCHMARK'] != '1') {
        return;
      }

      final helperPath = Platform.environment['DESKTOP_VOICE_HELPER_PATH'] ??
          DesktopVoiceRealHelperLatencyBenchmark.defaultInstalledHelper;
      final buildSha =
          Platform.environment['EXPECTED_BUILD_SHA'] ?? 'dd1cbe2';
      final warmRuns =
          int.tryParse(Platform.environment['WARM_RUNS'] ?? '20') ?? 20;

      final report = await DesktopVoiceRealHelperLatencyBenchmark.runFullSuite(
        helperPath: helperPath,
        buildSha: buildSha,
        warmIterations: warmRuns,
      );

      await DesktopVoiceRealHelperLatencyBenchmark.writeReportArtifact(report);
      // ignore: avoid_print
      print(report.summary());
      for (final m in report.markers) {
        // ignore: avoid_print
        print('MARKER $m');
      }

      expect(
        report.iterations.length,
        greaterThanOrEqualTo(warmRuns * 5),
        reason: report.blocker ?? 'no_iterations',
      );
      expect(
        report.strictPass,
        isTrue,
        reason: report.summary(),
      );
    }, timeout: const Timeout(Duration(minutes: 90)));
  });
}
