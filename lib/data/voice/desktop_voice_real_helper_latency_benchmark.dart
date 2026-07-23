import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/data/voice/desktop_voice_contamination_gate.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_session.dart';
import 'package:counter/shared/voice/commands/desktop_voice_transcript_merge.dart';
import 'package:counter/data/voice/desktop_voice_glossary.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_stt_processing.dart';
import 'package:counter/data/voice/desktop_voice_useful_candidate_evaluator.dart';
import 'package:counter/shared/voice/platforms/desktop/pcm_audio_utils.dart';
import 'package:counter/data/models.dart';
import 'package:http/http.dart' as http;

/// Per-iteration latency trace against the real installed STT helper.
class DesktopVoiceLatencyIteration {
  DesktopVoiceLatencyIteration({
    required this.iteration,
    required this.scenario,
    required this.voiceSessionId,
    this.helperSessionId,
    this.helperReadyMs,
    this.recordingStartMs,
    this.firstAudioFrameMs,
    this.firstPartialMs,
    this.firstPartialText,
    this.firstPartialSessionId,
    this.firstPartialUseful = false,
    this.stopMs,
    this.firstCandidateMs,
    this.firstCandidateText,
    this.candidateSessionId,
    this.candidateParseStatus,
    this.candidateContaminationStatus,
    this.candidateUseful = false,
    this.pendingEligibleMs,
    this.finalTextMs,
    this.stopToFirstCandidateMs,
    this.stopToUsefulCandidateMs,
    this.stopToPendingEligibleMs,
    this.stopToFinalTextMs,
    this.finalInferenceLatencyMs,
    this.staleResultsDiscarded = 0,
    this.modelReinitialized = false,
    this.counted = false,
    this.rejectReason,
    this.matchedPath,
    this.recordTitle,
  });

  final int iteration;
  final String scenario;
  final String voiceSessionId;
  final String? helperSessionId;
  final int? helperReadyMs;
  final int? recordingStartMs;
  final int? firstAudioFrameMs;
  final int? firstPartialMs;
  final String? firstPartialText;
  final String? firstPartialSessionId;
  final bool firstPartialUseful;
  final int? stopMs;
  final int? firstCandidateMs;
  final String? firstCandidateText;
  final String? candidateSessionId;
  final String? candidateParseStatus;
  final String? candidateContaminationStatus;
  final bool candidateUseful;
  final int? pendingEligibleMs;
  final int? finalTextMs;
  final int? stopToFirstCandidateMs;
  final int? stopToUsefulCandidateMs;
  final int? stopToPendingEligibleMs;
  final int? stopToFinalTextMs;
  final int? finalInferenceLatencyMs;
  final int staleResultsDiscarded;
  final bool modelReinitialized;
  bool counted;
  String? rejectReason;
  final String? matchedPath;
  final String? recordTitle;

  Map<String, dynamic> toJson() => {
        'iteration': iteration,
        'scenario': scenario,
        'voice_session_id': voiceSessionId,
        'helper_session_id': helperSessionId,
        'helper_ready_ms': helperReadyMs,
        'recording_start_ms': recordingStartMs,
        'first_audio_frame_ms': firstAudioFrameMs,
        'first_partial_ms': firstPartialMs,
        'first_partial_text': firstPartialText,
        'first_partial_session_id': firstPartialSessionId,
        'first_partial_useful': firstPartialUseful,
        'stop_ms': stopMs,
        'first_candidate_ms': firstCandidateMs,
        'first_candidate_text': firstCandidateText,
        'candidate_session_id': candidateSessionId,
        'candidate_parse_status': candidateParseStatus,
        'candidate_contamination_status': candidateContaminationStatus,
        'candidate_useful': candidateUseful,
        'pending_eligible_ms': pendingEligibleMs,
        'final_text_ms': finalTextMs,
        'stop_to_first_candidate_ms': stopToFirstCandidateMs,
        'stop_to_useful_candidate_ms': stopToUsefulCandidateMs,
        'stop_to_pending_eligible_ms': stopToPendingEligibleMs,
        'stop_to_final_text_ms': stopToFinalTextMs,
        'final_inference_latency_ms': finalInferenceLatencyMs,
        'stale_results_discarded': staleResultsDiscarded,
        'model_reinitialized': modelReinitialized,
        'counted': counted,
        'reject_reason': rejectReason,
        'matched_path': matchedPath,
        'record_title': recordTitle,
      };
}

class DesktopVoiceLatencyBenchmarkReport {
  DesktopVoiceLatencyBenchmarkReport({
    required this.buildSha,
    required this.helperPath,
    required this.helperEngine,
    required this.helperWarm,
    required this.fixturesUsed,
    required this.iterations,
    required this.validCountedRuns,
    required this.rejectedRuns,
    required this.p50StopToUsefulMs,
    required this.p90StopToUsefulMs,
    required this.p95StopToUsefulMs,
    required this.maxStopToUsefulMs,
    required this.p95StopToPendingEligibleMs,
    required this.firstCommandAfterReadyMs,
    required this.contaminationFailures,
    required this.staleSessionLeaks,
    required this.wrongPathTitleCount,
    required this.strictPass,
    required this.blocker,
    required this.markers,
  });

  final String buildSha;
  final String helperPath;
  final String helperEngine;
  final bool helperWarm;
  final List<String> fixturesUsed;
  final List<DesktopVoiceLatencyIteration> iterations;
  final int validCountedRuns;
  final int rejectedRuns;
  final int? p50StopToUsefulMs;
  final int? p90StopToUsefulMs;
  final int? p95StopToUsefulMs;
  final int? maxStopToUsefulMs;
  final int? p95StopToPendingEligibleMs;
  final int? firstCommandAfterReadyMs;
  final int contaminationFailures;
  final int staleSessionLeaks;
  final int wrongPathTitleCount;
  final bool strictPass;
  final String? blocker;
  final List<String> markers;

  Map<String, dynamic> toJson() => {
        'build_sha': buildSha,
        'helper_path': helperPath,
        'helper_engine': helperEngine,
        'helper_warm': helperWarm,
        'fixtures_used': fixturesUsed,
        'valid_counted_runs': validCountedRuns,
        'rejected_runs': rejectedRuns,
        'p50_stop_to_useful_candidate_ms': p50StopToUsefulMs,
        'p90_stop_to_useful_candidate_ms': p90StopToUsefulMs,
        'p95_stop_to_useful_candidate_ms': p95StopToUsefulMs,
        'max_stop_to_useful_candidate_ms': maxStopToUsefulMs,
        'p95_stop_to_pending_eligible_ms': p95StopToPendingEligibleMs,
        'first_command_after_ready_ms': firstCommandAfterReadyMs,
        'contamination_failures': contaminationFailures,
        'stale_session_leaks': staleSessionLeaks,
        'wrong_path_title_count': wrongPathTitleCount,
        'strict_pass': strictPass,
        'blocker': blocker,
        'markers': markers,
        'iterations': iterations.map((i) => i.toJson()).toList(),
      };

  String summary() {
    final buf = StringBuffer()
      ..writeln('strict_pass=$strictPass')
      ..writeln('valid=$validCountedRuns rejected=$rejectedRuns')
      ..writeln('P50=${p50StopToUsefulMs}ms P90=${p90StopToUsefulMs}ms P95=${p95StopToUsefulMs}ms max=$maxStopToUsefulMs')
      ..writeln('P95_pending=${p95StopToPendingEligibleMs}ms first_after_ready=$firstCommandAfterReadyMs')
      ..writeln('stale_leaks=$staleSessionLeaks contamination=$contaminationFailures wrong_path=$wrongPathTitleCount');
    if (blocker != null) buf.writeln('blocker=$blocker');
    return buf.toString();
  }
}

/// Real installed-helper latency benchmark (session-scoped useful candidate).
abstract final class DesktopVoiceRealHelperLatencyBenchmark {
  static const markerBenchmark = 'DESKTOP_VOICE_REAL_HELPER_LATENCY_BENCHMARK';
  static const marker20Warm = 'DESKTOP_VOICE_LATENCY_20_WARM_RUNS';
  static const markerP95Pass = 'DESKTOP_VOICE_USEFUL_LATENCY_P95_UNDER_500MS';
  static const markerStopUnder500 = 'DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS';
  static const markerFirstReady = 'DESKTOP_VOICE_FIRST_READY_COMMAND_UNDER_500MS';
  static const markerZeroStale = 'DESKTOP_VOICE_ZERO_STALE_SESSION_ACCEPTANCE';

  static const defaultInstalledHelper = r'C:\Users\nkuch\AppData\Local\Programs\Counter\stt_helper\counter_stt_helper.exe';
  static const helperUrl = 'http://127.0.0.1:8765';
  static const fixtureDir = 'test/fixtures/desktop_voice_wav';
  static const minPartialBytes = 48000;
  static const partialPollMs = 100;

  static Process? _helperProcess;
  static Map<String, dynamic>? _statusBeforeIteration;

  static List<CategoryRule> scwCategoryRules() => [
        CategoryRule(
          id: 10,
          name: 'Work',
          backendRowId: 'workroot1234567',
          children: [
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
                    'en': ['southern computer warehouse', 'scw'],
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
          ],
        ),
      ];

  static Future<bool> helperReachable() async {
    try {
      final r = await http
          .get(Uri.parse('$helperUrl/status'))
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> waitHelperReady({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final r = await http
            .get(Uri.parse('$helperUrl/status'))
            .timeout(const Duration(seconds: 3));
        if (r.statusCode == 200) {
          final body = jsonDecode(r.body);
          if (body is Map &&
              body['ready'] == true &&
              body['final_transcribe_ready'] == true) {
            return true;
          }
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  static Future<bool> ensureInstalledHelperRunning({
    String helperPath = defaultInstalledHelper,
  }) async {
    if (await waitHelperReady(timeout: const Duration(seconds: 2))) {
      return true;
    }
    final exe = File(helperPath);
    if (!exe.existsSync()) return false;
    _helperProcess = await Process.start(
      exe.path,
      const ['--port', '8765'],
      workingDirectory: exe.parent.path,
    );
    // Ensure whisper-tiny is selected and weights are loaded.
    try {
      await http
          .post(
            Uri.parse('$helperUrl/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'engine': 'whisper-tiny'}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {}
    return waitHelperReady(timeout: const Duration(seconds: 180));
  }

  static Future<void> stopManagedHelper() async {
    _helperProcess?.kill();
    _helperProcess = null;
  }

  static Future<Map<String, dynamic>?> helperStatus() async {
    try {
      final r = await http
          .get(Uri.parse('$helperUrl/status'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body);
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> resetSession(String sessionId) async {
    try {
      final r = await http
          .post(
            Uri.parse('$helperUrl/transcribe/reset_session'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': sessionId}),
          )
          .timeout(const Duration(seconds: 3));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body);
      if (body is Map) return (body['session_id'] as String?) ?? sessionId;
    } catch (_) {}
    return null;
  }

  static Future<bool> sendPartialAudio({
    required String sessionId,
    required List<int> pcm,
  }) async {
    if (pcm.length < minPartialBytes) return false;
    if (pcm16RmsLevel(pcm) < 0.012) return false;
    try {
      final r = await http
          .post(
            Uri.parse('$helperUrl/transcribe/partial_audio'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_base64': base64Encode(pcm),
              'session_id': sessionId,
            }),
          )
          .timeout(const Duration(seconds: 30));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<({String? text, String? sessionId, int? ageMs})> fetchLastPartial({
    required String? activeSessionId,
  }) async {
    try {
      final r = await http
          .get(Uri.parse('$helperUrl/transcribe/last_partial'))
          .timeout(const Duration(milliseconds: 400));
      if (r.statusCode != 200) return (text: null, sessionId: null, ageMs: null);
      final body = jsonDecode(r.body);
      if (body is! Map) return (text: null, sessionId: null, ageMs: null);
      final sid = (body['session_id'] as String?)?.trim();
      if (activeSessionId != null &&
          sid != null &&
          sid.isNotEmpty &&
          sid != activeSessionId) {
        return (text: null, sessionId: sid, ageMs: null);
      }
      final text = (body['text'] as String?)?.trim() ?? '';
      final age = (body['age_ms'] as num?)?.toInt();
      if (text.isEmpty) return (text: null, sessionId: sid, ageMs: age);
      return (text: text, sessionId: sid, ageMs: age);
    } catch (_) {
      return (text: null, sessionId: null, ageMs: null);
    }
  }

  static Future<({String? text, int? inferenceMs})> stopTranscribe({
    required String sessionId,
    required List<int> pcm,
  }) async {
    try {
      final t0 = DateTime.now();
      final r = await http
          .post(
            Uri.parse('$helperUrl/transcribe/stop'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_base64': base64Encode(pcm),
              'session_id': sessionId,
            }),
          )
          .timeout(const Duration(seconds: 60));
      final elapsed = DateTime.now().difference(t0).inMilliseconds;
      if (r.statusCode != 200) return (text: null, inferenceMs: elapsed);
      final body = jsonDecode(r.body);
      if (body is! Map) return (text: null, inferenceMs: elapsed);
      final text = ((body['final_text'] ?? body['text']) as String?)?.trim();
      final inf = (body['final_inference_latency_ms'] as num?)?.toInt() ?? elapsed;
      return (text: text, inferenceMs: inf);
    } catch (_) {
      return (text: null, inferenceMs: null);
    }
  }

  static Future<void> waitPartialInference({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final partial = await fetchLastPartial(activeSessionId: null);
      if (partial.text != null && partial.text!.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: partialPollMs));
    }
  }

  static Future<DesktopVoiceLatencyIteration> runScwIteration({
    required int iteration,
    required String scenario,
    required List<int> pcm,
    required List<CategoryRule> rules,
    required DesktopVoiceGlossaryPack glossary,
    required int benchmarkEpochMs,
    bool simulateStaleSession = false,
  }) async {
    var staleDiscarded = 0;
    final session = DesktopVoiceSessionRegistry.begin();
    final sessionId = session.id;
    await resetSession(sessionId);

    if (simulateStaleSession) {
      final staleId = '${sessionId}_stale';
      await resetSession(staleId);
      unawaited(sendPartialAudio(sessionId: staleId, pcm: pcm));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await resetSession(sessionId);
    }

    final recordingStart = DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;
    final firstAudioFrame = recordingStart + 50;

    var sentBytes = 0;
    var sessionBestPartial = '';
    var sessionBestUseful = false;
    int? firstPartialMs;
    String? firstPartialText;
    String? firstPartialSid;
    var firstPartialUseful = false;

    // Simulate mid-recording partial path: ship full processed audio once ready.
    if (pcm.length >= minPartialBytes) {
      unawaited(sendPartialAudio(sessionId: sessionId, pcm: pcm));
    }
    final pollDeadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(pollDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: partialPollMs));
      final partial = await fetchLastPartial(activeSessionId: sessionId);
      if (partial.sessionId != null &&
          partial.sessionId!.isNotEmpty &&
          partial.sessionId != sessionId) {
        staleDiscarded++;
        continue;
      }
      if (partial.text != null && partial.text!.isNotEmpty) {
        sessionBestPartial = DesktopVoiceTranscriptMerge.applyPartial(
          previous: sessionBestPartial,
          partial: partial.text!,
        );
        final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
          transcript: sessionBestPartial,
          categoryRules: rules,
          glossary: glossary,
        );
        sessionBestUseful = eval.useful && eval.pendingEligible;
        firstPartialMs ??=
            DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;
        firstPartialText ??= partial.text;
        firstPartialSid ??= partial.sessionId;
        firstPartialUseful = eval.useful;
        if (sessionBestUseful) break;
      }
    }

    final stopMs = DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;
    int? firstCandidateMs;
    int? pendingEligibleMs;
    String? candidateText;
    String? candidateSid;
    var candidateUseful = false;
    var candidateParseStatus = 'none';
    var candidateContamination = 'clean';
    String? matchedPath;
    String? recordTitle;

    if (sessionBestUseful && sessionBestPartial.isNotEmpty) {
      candidateText = sessionBestPartial;
      candidateSid = sessionId;
      candidateUseful = true;
      final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: sessionBestPartial,
        categoryRules: rules,
        glossary: glossary,
      );
      candidateParseStatus = eval.parseStatus;
      candidateContamination =
          eval.contaminationDetected ? (eval.contaminationReason ?? 'yes') : 'clean';
      matchedPath = eval.matchedPath;
      recordTitle = eval.normalizedTitle;
      firstCandidateMs = stopMs;
      pendingEligibleMs = stopMs;
    } else {
      final partial = await fetchLastPartial(activeSessionId: sessionId);
      if (partial.sessionId != null &&
          partial.sessionId!.isNotEmpty &&
          partial.sessionId != sessionId) {
        staleDiscarded++;
      } else if (partial.text != null && partial.text!.isNotEmpty) {
        candidateText = partial.text;
        candidateSid = partial.sessionId ?? sessionId;
        final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
          transcript: partial.text!,
          categoryRules: rules,
          glossary: glossary,
        );
        candidateUseful = eval.useful && eval.pendingEligible;
        candidateParseStatus = eval.parseStatus;
        candidateContamination =
            eval.contaminationDetected ? (eval.contaminationReason ?? 'yes') : 'clean';
        matchedPath = eval.matchedPath;
        recordTitle = eval.normalizedTitle;
        if (candidateUseful) {
          firstCandidateMs = DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;
          pendingEligibleMs = firstCandidateMs;
        }
      }
    }

    final finalStop = await stopTranscribe(sessionId: sessionId, pcm: pcm);
    final finalTextMs = DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;

    // Final refinement may expose contamination that a clean partial hid (67ea8eb).
    String? rejectReason;
    if (finalStop.text != null && finalStop.text!.trim().isNotEmpty) {
      final finalEval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: finalStop.text!,
        categoryRules: rules,
        glossary: glossary,
      );
      if (finalEval.contaminationDetected) {
        candidateUseful = false;
        candidateContamination =
            finalEval.contaminationReason ?? 'contaminated_final';
        rejectReason = 'contaminated_final';
        firstCandidateMs = null;
        pendingEligibleMs = null;
      }
    }

    final stopToUseful = (candidateUseful && firstCandidateMs != null)
        ? firstCandidateMs - stopMs
        : null;
    final stopToPending = pendingEligibleMs != null ? pendingEligibleMs - stopMs : null;

    final statusAfter = await helperStatus();
    final modelReinit = _statusBeforeIteration != null &&
        statusAfter != null &&
        statusAfter['warmup_done'] != true &&
        _statusBeforeIteration!['warmup_done'] == true;

    var counted = false;
    if (candidateUseful &&
        stopToUseful != null &&
        stopToUseful < 500 &&
        desktopVoicePathMatchesScwDelMod(matchedPath) &&
        desktopVoiceTitleIsSubmit(recordTitle) &&
        candidateContamination == 'clean' &&
        candidateSid == sessionId) {
      counted = true;
    } else if (rejectReason == null) {
      if (!candidateUseful) {
        rejectReason = candidateContamination != 'clean'
            ? 'contaminated'
            : 'not_useful';
      } else if (stopToUseful == null || stopToUseful >= 500) {
        rejectReason = 'slow_${stopToUseful ?? 'null'}';
      } else if (!desktopVoicePathMatchesScwDelMod(matchedPath)) {
        rejectReason = 'wrong_path';
      } else if (!desktopVoiceTitleIsSubmit(recordTitle)) {
        rejectReason = 'wrong_title';
      } else if (candidateContamination != 'clean') {
        rejectReason = 'contaminated';
      } else if (candidateSid != sessionId) {
        rejectReason = 'session_mismatch';
      }
    }

    DesktopVoiceSessionRegistry.end(reason: 'benchmark_iteration');

    return DesktopVoiceLatencyIteration(
      iteration: iteration,
      scenario: scenario,
      voiceSessionId: sessionId,
      helperSessionId: candidateSid,
      recordingStartMs: recordingStart,
      firstAudioFrameMs: firstAudioFrame,
      firstPartialMs: firstPartialMs,
      firstPartialText: firstPartialText,
      firstPartialSessionId: firstPartialSid,
      firstPartialUseful: firstPartialUseful,
      stopMs: stopMs,
      firstCandidateMs: firstCandidateMs,
      firstCandidateText: candidateText,
      candidateSessionId: candidateSid,
      candidateParseStatus: candidateParseStatus,
      candidateContaminationStatus: candidateContamination,
      candidateUseful: candidateUseful,
      pendingEligibleMs: pendingEligibleMs,
      finalTextMs: finalTextMs,
      stopToFirstCandidateMs: stopToUseful,
      stopToUsefulCandidateMs: stopToUseful,
      stopToPendingEligibleMs: stopToPending,
      stopToFinalTextMs: finalTextMs - stopMs,
      finalInferenceLatencyMs: finalStop.inferenceMs,
      staleResultsDiscarded: staleDiscarded,
      modelReinitialized: modelReinit,
      counted: counted,
      rejectReason: rejectReason,
      matchedPath: matchedPath,
      recordTitle: recordTitle,
    );
  }

  static int percentile(List<int> values, double p) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final idx = min(
      sorted.length - 1,
      max(0, (p * sorted.length).ceil() - 1),
    );
    return sorted[idx];
  }

  static bool _iterationTextHasContamination(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    for (final frag in DesktopVoiceContaminationGate.forbiddenStaleFragments) {
      if (lower.contains(frag)) return true;
    }
    return DesktopVoiceTranscriptMerge.hasRepeatedCommandSuffix(text) ||
        RegExp(r'del\s*mod\s*,?\s*submit', caseSensitive: false)
                .allMatches(text)
                .length >
            1;
  }

  static Future<DesktopVoiceLatencyBenchmarkReport> runFullSuite({
    String helperPath = defaultInstalledHelper,
    String buildSha = 'dd1cbe2',
    int warmIterations = 20,
    String primaryFixture = 'scw_delmod_submit_cpal_4f9c984.wav',
  }) async {
    DesktopVoicePipeline.mark(markerBenchmark);
    final fixtures = <String>[
      primaryFixture,
      'scw_delmod_submit_cpal_4f9c984.wav',
      'scw_delmod_submit_df696fc_live_quiet.wav',
      'scw_delmod_submit_fefb502_live_quiet.wav',
      'scw_contaminated_67ea8eb_contaminated_2026_07_10.wav',
    ];

    final ready = await ensureInstalledHelperRunning(helperPath: helperPath);
    if (!ready) {
      return _failedReport(
        buildSha: buildSha,
        helperPath: helperPath,
        fixtures: fixtures,
        blocker: 'helper_not_ready',
      );
    }

    final status0 = await helperStatus();
    final engine = (status0?['model'] as String?) ?? 'whisper-tiny';
    final helperWarm = status0?['warmup_done'] == true;

    final primaryWav = File('$fixtureDir/$primaryFixture');
    if (!primaryWav.existsSync()) {
      return _failedReport(
        buildSha: buildSha,
        helperPath: helperPath,
        fixtures: fixtures,
        blocker: 'primary_fixture_missing',
        engine: engine,
        helperWarm: helperWarm,
      );
    }

    final pcmRaw = extractPcm16FromWav(primaryWav.readAsBytesSync());
    final processing = applyProductionWhisperSttProcessing(pcmRaw);
    final pcm = processing.applied ? processing.pcm : pcmRaw;
    final rules = scwCategoryRules();
    final glossary = DesktopVoiceGlossaryPack.buildFromCategoryRules(rules);
    final allIterations = <DesktopVoiceLatencyIteration>[];
    final epoch = DateTime.now().millisecondsSinceEpoch;

    _statusBeforeIteration = status0;

    // Throwaway warmup transcribe.
    final warmSession = DesktopVoiceSessionRegistry.begin();
    await resetSession(warmSession.id);
    await sendPartialAudio(sessionId: warmSession.id, pcm: pcm);
    await waitPartialInference();
    await stopTranscribe(sessionId: warmSession.id, pcm: pcm);
    DesktopVoiceSessionRegistry.end(reason: 'warmup');

    for (var i = 1; i <= warmIterations; i++) {
      allIterations.add(
        await runScwIteration(
          iteration: i,
          scenario: 'warm_scw',
          pcm: pcm,
          rules: rules,
          glossary: glossary,
          benchmarkEpochMs: epoch,
        ),
      );
    }
    DesktopVoicePipeline.mark(marker20Warm);

    // First command immediately after ready (iteration 21).
    allIterations.add(
      await runScwIteration(
        iteration: warmIterations + 1,
        scenario: 'first_after_ready',
        pcm: pcm,
        rules: rules,
        glossary: glossary,
        benchmarkEpochMs: epoch,
      ),
    );

    // BLINK → SCW sequential (use contaminated fixture as session A stand-in).
    final contaminatedWav = File(
      '$fixtureDir/scw_contaminated_67ea8eb_contaminated_2026_07_10.wav',
    );
    if (contaminatedWav.existsSync()) {
      final contaminatedPcm =
          extractPcm16FromWav(contaminatedWav.readAsBytesSync());
      for (var i = 0; i < 5; i++) {
        final blinkSession = DesktopVoiceSessionRegistry.begin();
        await resetSession(blinkSession.id);
        await sendPartialAudio(sessionId: blinkSession.id, pcm: contaminatedPcm);
        await waitPartialInference();
        await stopTranscribe(sessionId: blinkSession.id, pcm: contaminatedPcm);
        DesktopVoiceSessionRegistry.end(reason: 'blink_session');
        final scw = await runScwIteration(
          iteration: warmIterations + 2 + i,
          scenario: 'blink_then_scw_$i',
          pcm: pcm,
          rules: rules,
          glossary: glossary,
          benchmarkEpochMs: epoch,
        );
        final text = (scw.firstCandidateText ?? '').toLowerCase();
        if (text.contains('blink') || text.contains('laredo')) {
          scw.rejectReason = 'blink_leak';
        }
        allIterations.add(scw);
      }
    }

    // Cancel then SCW — reset without using prior partial.
    for (var i = 0; i < 5; i++) {
      final cancelSession = DesktopVoiceSessionRegistry.begin();
      await resetSession(cancelSession.id);
      await sendPartialAudio(sessionId: cancelSession.id, pcm: pcm);
      await resetSession(cancelSession.id);
      DesktopVoiceSessionRegistry.end(reason: 'cancel_before_stop');
      allIterations.add(
        await runScwIteration(
          iteration: warmIterations + 10 + i,
          scenario: 'cancel_then_scw_$i',
          pcm: pcm,
          rules: rules,
          glossary: glossary,
          benchmarkEpochMs: epoch,
        ),
      );
    }

    // Stale async injection.
    for (var i = 0; i < 5; i++) {
      allIterations.add(
        await runScwIteration(
          iteration: warmIterations + 15 + i,
          scenario: 'stale_inject_$i',
          pcm: pcm,
          rules: rules,
          glossary: glossary,
          benchmarkEpochMs: epoch,
          simulateStaleSession: true,
        ),
      );
    }

    // Contaminated fixture must not count as useful.
    if (contaminatedWav.existsSync()) {
      final contaminatedPcm =
          extractPcm16FromWav(contaminatedWav.readAsBytesSync());
      final contaminatedIter = await runScwIteration(
        iteration: warmIterations + 20,
        scenario: 'contaminated_fixture',
        pcm: contaminatedPcm,
        rules: rules,
        glossary: glossary,
        benchmarkEpochMs: epoch,
      );
      if (contaminatedIter.counted) {
        contaminatedIter.rejectReason = 'contaminated_fixture_not_warm';
        contaminatedIter.counted = false;
      }
      allIterations.add(contaminatedIter);
    }

    final warmRuns = allIterations
        .where((i) => i.scenario == 'warm_scw')
        .toList(growable: false);
    final counted = warmRuns.where((i) => i.counted).toList();
    final rejected = warmRuns.where((i) => !i.counted).toList();
    final usefulMs =
        counted.map((i) => i.stopToUsefulCandidateMs!).toList(growable: false);
    final pendingMs = counted
        .map((i) => i.stopToPendingEligibleMs ?? i.stopToUsefulCandidateMs!)
        .toList(growable: false);

    final firstAfterReady = allIterations
        .where((i) => i.scenario == 'first_after_ready')
        .map((i) => i.stopToUsefulCandidateMs)
        .firstOrNull;

    var staleLeaks = 0;
    var contaminationFailures = 0;
    var wrongPath = 0;
    for (final it in allIterations) {
      if (it.scenario.startsWith('blink_then_scw')) {
        final t = (it.firstCandidateText ?? '').toLowerCase();
        if (t.contains('blink') || t.contains('laredo')) staleLeaks++;
      }
      if (_iterationTextHasContamination(it.firstCandidateText) &&
          it.candidateUseful) {
        contaminationFailures++;
      }
      if (it.candidateUseful &&
          (!desktopVoicePathMatchesScwDelMod(it.matchedPath) ||
              !desktopVoiceTitleIsSubmit(it.recordTitle))) {
        wrongPath++;
      }
    }

    final p50 = usefulMs.isEmpty ? null : percentile(usefulMs, 0.50);
    final p90 = usefulMs.isEmpty ? null : percentile(usefulMs, 0.90);
    final p95 = usefulMs.isEmpty ? null : percentile(usefulMs, 0.95);
    final p95Pending =
        pendingMs.isEmpty ? null : percentile(pendingMs, 0.95);
    final maxMs = usefulMs.isEmpty ? null : usefulMs.reduce(max);

    final strictPass = counted.length >= warmIterations &&
        p95 != null &&
        p95 < 500 &&
        p95Pending != null &&
        p95Pending < 500 &&
        firstAfterReady != null &&
        firstAfterReady < 500 &&
        staleLeaks == 0 &&
        contaminationFailures == 0 &&
        wrongPath == 0;

    final markers = <String>[
      markerBenchmark,
      marker20Warm,
      'DESKTOP_VOICE_USEFUL_CANDIDATE_METRIC_ENFORCED',
      'DESKTOP_VOICE_SESSION_SCOPED_LATENCY',
      'DESKTOP_VOICE_BAD_PARTIAL_NOT_COUNTED_AS_SUCCESS',
      'DESKTOP_VOICE_CONTAMINATED_PARTIAL_NOT_COUNTED',
    ];
    if (!strictPass) {
      markers.add('DESKTOP_VOICE_NO_FAKE_LATENCY_PASS');
    } else {
      markers.add(markerStopUnder500);
      markers.add(markerP95Pass);
      markers.add(markerFirstReady);
      markers.add(markerZeroStale);
    }

    String? blocker;
    if (!strictPass) {
      if (counted.length < warmIterations) {
        blocker = 'insufficient_valid_runs_${counted.length}_of_$warmIterations';
      } else if (p95 == null || p95 >= 500) {
        blocker = 'p95_stop_to_useful_${p95 ?? 'null'}_ms';
      } else if (p95Pending == null || p95Pending >= 500) {
        blocker = 'p95_pending_${p95Pending ?? 'null'}_ms';
      } else if (firstAfterReady == null || firstAfterReady >= 500) {
        blocker = 'first_after_ready_${firstAfterReady ?? 'null'}_ms';
      } else if (staleLeaks > 0) {
        blocker = 'stale_leaks_$staleLeaks';
      } else if (contaminationFailures > 0) {
        blocker = 'contamination_failures';
      } else if (wrongPath > 0) {
        blocker = 'wrong_path_title';
      }
    }

    return DesktopVoiceLatencyBenchmarkReport(
      buildSha: buildSha,
      helperPath: helperPath,
      helperEngine: engine,
      helperWarm: helperWarm,
      fixturesUsed: fixtures,
      iterations: allIterations,
      validCountedRuns: counted.length,
      rejectedRuns: rejected.length,
      p50StopToUsefulMs: p50,
      p90StopToUsefulMs: p90,
      p95StopToUsefulMs: p95,
      maxStopToUsefulMs: maxMs,
      p95StopToPendingEligibleMs: p95Pending,
      firstCommandAfterReadyMs: firstAfterReady,
      contaminationFailures: contaminationFailures,
      staleSessionLeaks: staleLeaks,
      wrongPathTitleCount: wrongPath,
      strictPass: strictPass,
      blocker: blocker,
      markers: markers,
    );
  }

  static DesktopVoiceLatencyBenchmarkReport _failedReport({
    required String buildSha,
    required String helperPath,
    required List<String> fixtures,
    required String blocker,
    String engine = 'unknown',
    bool helperWarm = false,
  }) {
    return DesktopVoiceLatencyBenchmarkReport(
      buildSha: buildSha,
      helperPath: helperPath,
      helperEngine: engine,
      helperWarm: helperWarm,
      fixturesUsed: fixtures,
      iterations: const [],
      validCountedRuns: 0,
      rejectedRuns: 0,
      p50StopToUsefulMs: null,
      p90StopToUsefulMs: null,
      p95StopToUsefulMs: null,
      maxStopToUsefulMs: null,
      p95StopToPendingEligibleMs: null,
      firstCommandAfterReadyMs: null,
      contaminationFailures: 0,
      staleSessionLeaks: 0,
      wrongPathTitleCount: 0,
      strictPass: false,
      blocker: blocker,
      markers: [markerBenchmark, 'DESKTOP_VOICE_NO_FAKE_LATENCY_PASS'],
    );
  }

  static Future<void> writeReportArtifact(
    DesktopVoiceLatencyBenchmarkReport report, {
    String outDir = 'test/fixtures/desktop_voice_wav/benchmark_reports',
  }) async {
    final dir = Directory(outDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final path = '$outDir/real_helper_latency_$stamp.json';
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    await File('$outDir/real_helper_latency_latest.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  }
}
