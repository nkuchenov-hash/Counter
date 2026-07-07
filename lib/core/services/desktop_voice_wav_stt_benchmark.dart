import 'dart:convert';
import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:http/http.dart' as http;

/// Real WAV → local STT helper benchmark (raw transcript quality, no postprocess).
class DesktopVoiceWavSttBenchmarkCase {
  const DesktopVoiceWavSttBenchmarkCase({
    required this.id,
    required this.wavFileName,
    required this.status,
    required this.expectedTerms,
    required this.baselineTranscript,
    this.forbiddenTerms = const [],
  });

  final String id;
  final String? wavFileName;
  final String status;
  final List<String> expectedTerms;
  final String baselineTranscript;
  final List<String> forbiddenTerms;
}

class DesktopVoiceWavSttBenchmarkResult {
  const DesktopVoiceWavSttBenchmarkResult({
    required this.caseId,
    required this.wavPath,
    required this.durationMs,
    required this.sampleRate,
    required this.rms,
    required this.peak,
    required this.rawTranscript,
    required this.latencyMs,
    required this.baselineTranscript,
    required this.tokenErrorRate,
    required this.domainTermHits,
    required this.domainTermAccuracy,
    required this.improvedVsBaseline,
    required this.improvementPercent,
    required this.passed,
    this.error,
  });

  final String caseId;
  final String wavPath;
  final int durationMs;
  final int sampleRate;
  final double rms;
  final double peak;
  final String rawTranscript;
  final int latencyMs;
  final String baselineTranscript;
  final double tokenErrorRate;
  final Map<String, bool> domainTermHits;
  final double domainTermAccuracy;
  final bool improvedVsBaseline;
  final double improvementPercent;
  final bool passed;
  final String? error;
}

abstract final class DesktopVoiceWavSttBenchmark {
  static const fixtureDir = 'test/fixtures/desktop_voice_wav';
  static const manifestFile = '$fixtureDir/golden_manifest.json';
  static const helperBaseUrl = 'http://127.0.0.1:8765';

  static List<DesktopVoiceWavSttBenchmarkCase> loadManifestCases() {
    final file = File(manifestFile);
    if (!file.existsSync()) return const [];
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final cases = json['cases'] as List<dynamic>? ?? const [];
    return cases.map((raw) {
      final m = raw as Map<String, dynamic>;
      return DesktopVoiceWavSttBenchmarkCase(
        id: m['id'] as String? ?? '',
        wavFileName: m['wav'] as String?,
        status: m['status'] as String? ?? 'missing',
        expectedTerms: (m['expected_terms'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        baselineTranscript:
            (m['baseline_transcript'] as String?) ??
            (json['baseline_transcript'] as String? ?? ''),
        forbiddenTerms: (m['forbidden_terms'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );
    }).toList(growable: false);
  }

  static String? baselineTranscriptFromManifest() {
    final file = File(manifestFile);
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return json['baseline_transcript'] as String?;
  }

  static String? _golosEquivalentFromManifest() {
    final file = File(manifestFile);
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return json['golos_equivalent_raw_transcript'] as String?;
  }

  static bool strictDomainPassFromManifest() {
    final file = File(manifestFile);
    if (!file.existsSync()) return false;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return json['strict_domain_pass'] == true;
  }

  /// Simple token error rate vs expected phrase (case-insensitive).
  static double tokenErrorRate(String hypothesis, String reference) {
    final hyp = _tokens(hypothesis);
    final ref = _tokens(reference);
    if (ref.isEmpty) return hyp.isEmpty ? 0 : 1;
    var hits = 0;
    for (final t in ref) {
      if (hyp.contains(t)) hits++;
    }
    return 1 - (hits / ref.length);
  }

  static Map<String, bool> domainTermHits(
    String transcript,
    List<String> terms,
  ) {
    final lower = transcript.toLowerCase();
    return {
      for (final term in terms)
        term: _containsDomainTerm(lower, term),
    };
  }

  static bool _containsDomainTerm(String lowerTranscript, String term) {
    final norm = term.toLowerCase().trim();
    if (norm.isEmpty) return true;
    if (lowerTranscript.contains(norm)) return true;
    if (norm == 'del mod') {
      return RegExp(r'\bdel\s+mod\b|delmod|delmore|del\s+more').hasMatch(
        lowerTranscript,
      );
    }
    if (norm == 'southern computer warehouse') {
      return lowerTranscript.contains('southern') &&
          lowerTranscript.contains('computer') &&
          lowerTranscript.contains('warehouse');
    }
    return false;
  }

  static List<String> _tokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }

  static double improvementPercent({
    required double baselineTer,
    required double newTer,
  }) {
    if (baselineTer <= 0) return newTer <= 0 ? 0 : -100;
    return ((baselineTer - newTer) / baselineTer) * 100;
  }

  static Future<DesktopVoiceWavSttBenchmarkResult?> runCase({
    required DesktopVoiceWavSttBenchmarkCase caseDef,
    String expectedPhrase =
        'Southern Computer Warehouse DEL MOD submit',
    String helperUrl = helperBaseUrl,
    String engine = 'parakeet',
  }) async {
    if (caseDef.status != 'present' || caseDef.wavFileName == null) {
      return null;
    }
    final wavPath = '$fixtureDir/${caseDef.wavFileName}';
    final wavFile = File(wavPath);
    if (!wavFile.existsSync()) return null;

    DesktopVoicePipeline.mark('DESKTOP_VOICE_SAME_WAV_COMPARISON_READY', wavPath);

    final bytes = await wavFile.readAsBytes();
    if (bytes.length < 44) {
      return DesktopVoiceWavSttBenchmarkResult(
        caseId: caseDef.id,
        wavPath: wavPath,
        durationMs: 0,
        sampleRate: kVoiceSampleRate,
        rms: 0,
        peak: 0,
        rawTranscript: '',
        latencyMs: 0,
        baselineTranscript: caseDef.baselineTranscript,
        tokenErrorRate: 1,
        domainTermHits: {},
        domainTermAccuracy: 0,
        improvedVsBaseline: false,
        improvementPercent: 0,
        passed: false,
        error: 'wav_too_small',
      );
    }

    final pcm = bytes.sublist(44);
    final rms = pcm16RmsLevel(pcm);
    final peak = pcm16PeakLevel(pcm);
    final durationMs = pcm16DurationMs(pcm);

    final t0 = DateTime.now();
    String? rawText;
    String? error;
    try {
      final status = await http
          .get(Uri.parse('$helperUrl/status'))
          .timeout(const Duration(seconds: 3));
      if (status.statusCode != 200) {
        error = 'helper_status_${status.statusCode}';
      } else {
        await http
            .post(
              Uri.parse('$helperUrl/config'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'engine': engine}),
            )
            .timeout(const Duration(seconds: 30));
        // Wait for model load.
        final loadDeadline = DateTime.now().add(const Duration(seconds: 90));
        while (DateTime.now().isBefore(loadDeadline)) {
          final st = await http
              .get(Uri.parse('$helperUrl/status'))
              .timeout(const Duration(seconds: 3));
          if (st.statusCode == 200) {
            final body = jsonDecode(st.body) as Map<String, dynamic>;
            if (body['final_transcribe_ready'] == true) break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        final resp = await http
            .post(
              Uri.parse('$helperUrl/transcribe/stop'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'audio_base64': base64Encode(pcm)}),
            )
            .timeout(const Duration(seconds: 120));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          rawText = (body['text'] as String?)?.trim();
        } else {
          error = 'transcribe_${resp.statusCode}';
        }
      }
    } catch (e) {
      error = e.toString();
    }
    final latencyMs = DateTime.now().difference(t0).inMilliseconds;

    if (rawText == null || rawText.isEmpty) {
      return DesktopVoiceWavSttBenchmarkResult(
        caseId: caseDef.id,
        wavPath: wavPath,
        durationMs: durationMs,
        sampleRate: kVoiceSampleRate,
        rms: rms,
        peak: peak,
        rawTranscript: rawText ?? '',
        latencyMs: latencyMs,
        baselineTranscript: caseDef.baselineTranscript,
        tokenErrorRate: 1,
        domainTermHits: {},
        domainTermAccuracy: 0,
        improvedVsBaseline: false,
        improvementPercent: 0,
        passed: false,
        error: error ?? 'empty_transcript',
      );
    }

    DesktopVoicePipeline.mark('DESKTOP_VOICE_COUNTER_RAW_TRANSCRIPT_RECORDED', rawText);

    final baselineTer =
        tokenErrorRate(caseDef.baselineTranscript, expectedPhrase);
    final newTer = tokenErrorRate(rawText, expectedPhrase);
    final hits = domainTermHits(rawText, caseDef.expectedTerms);
    final baselineHits =
        domainTermHits(caseDef.baselineTranscript, caseDef.expectedTerms);
    final accuracy = caseDef.expectedTerms.isEmpty
        ? 1.0
        : hits.values.where((v) => v).length / caseDef.expectedTerms.length;
    final baselineAccuracy = caseDef.expectedTerms.isEmpty
        ? 0.0
        : baselineHits.values.where((v) => v).length /
            caseDef.expectedTerms.length;
    final improved = newTer < baselineTer || accuracy > baselineAccuracy;
    final improvement = improvementPercent(
      baselineTer: baselineTer,
      newTer: newTer,
    );

    final forbiddenHit = caseDef.forbiddenTerms.any(
      (f) => rawText!.toLowerCase().contains(f.toLowerCase()),
    );
    final golosTarget = baselineTranscriptFromManifest() == null
        ? null
        : _golosEquivalentFromManifest();
    final matchesGolosEquivalent = golosTarget != null &&
        rawText.trim().toLowerCase() == golosTarget.trim().toLowerCase();
    // Parity pass = match GOLOS-equivalent raw on same WAV (not alias/postprocess).
    final passed = matchesGolosEquivalent && !forbiddenHit;

    if (passed) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_REGRESSION_IMPROVED');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_COUNTER_PIPELINE_MATCHED_TO_GOLOS');
    }

    return DesktopVoiceWavSttBenchmarkResult(
      caseId: caseDef.id,
      wavPath: wavPath,
      durationMs: durationMs,
      sampleRate: kVoiceSampleRate,
      rms: rms,
      peak: peak,
      rawTranscript: rawText,
      latencyMs: latencyMs,
      baselineTranscript: caseDef.baselineTranscript,
      tokenErrorRate: newTer,
      domainTermHits: hits,
      domainTermAccuracy: accuracy,
      improvedVsBaseline: improved,
      improvementPercent: improvement,
      passed: passed,
    );
  }

  static bool helperLikelyAvailable() {
    final env = Platform.environment['COUNTER_DESKTOP_VOICE_WAV_STT'];
    if (env == '1') return true;
    final helper = File(
      'installer/windows/stt_helper_build/counter_stt_helper.exe',
    );
    return helper.existsSync();
  }
}
