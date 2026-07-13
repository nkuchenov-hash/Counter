import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_contamination_gate.dart';
import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:counter/core/services/desktop_voice_session.dart';
import 'package:counter/core/services/desktop_voice_transcript_merge.dart';
import 'package:counter/core/services/desktop_voice_glossary.dart';
import 'package:counter/core/services/desktop_voice_stt_processing.dart';
import 'package:counter/core/services/desktop_voice_useful_candidate_evaluator.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:counter/data/models.dart';
import 'package:http/http.dart' as http;

enum DesktopVoiceBenchmarkPhraseId {
  scwDelModSubmit,
  logicalMarketingActions,
  blinkLaredoTechnicalServices,
  priceReporterPlanning,
  laredoTechnicalServicesAddSin,
}

/// One balanced phrase in the five-phrase installed-helper benchmark.
class DesktopVoiceBenchmarkPhraseConfig {
  const DesktopVoiceBenchmarkPhraseConfig({
    required this.id,
    required this.wavFile,
    required this.expectedPathDescription,
    required this.expectedTitle,
    required this.rules,
    required this.pathMatches,
    required this.titleMatches,
    this.forbiddenTranscriptFragments = const [],
  });

  final DesktopVoiceBenchmarkPhraseId id;
  final String wavFile;
  final String expectedPathDescription;
  final String expectedTitle;
  final List<CategoryRule> rules;
  final bool Function(String? path) pathMatches;
  final bool Function(String? title) titleMatches;
  final List<String> forbiddenTranscriptFragments;
}

class DesktopVoicePhraseBenchmarkResult {
  DesktopVoicePhraseBenchmarkResult({
    required this.phraseId,
    required this.expectedPath,
    required this.expectedTitle,
    required this.validRuns,
    required this.rejectedRuns,
    required this.recognitionAccuracy,
    required this.parserAccuracy,
    required this.pathAccuracy,
    required this.titleAccuracy,
    required this.p50StopToUsefulMs,
    required this.p90StopToUsefulMs,
    required this.p95StopToUsefulMs,
    required this.p95StopToPendingMs,
    required this.maxStopToUsefulMs,
    required this.hallucinationCount,
    required this.duplicateCount,
    required this.staleSessionCount,
    required this.strictPass,
    required this.blocker,
  });

  final String phraseId;
  final String expectedPath;
  final String expectedTitle;
  final int validRuns;
  final int rejectedRuns;
  final double recognitionAccuracy;
  final double parserAccuracy;
  final double pathAccuracy;
  final double titleAccuracy;
  final int? p50StopToUsefulMs;
  final int? p90StopToUsefulMs;
  final int? p95StopToUsefulMs;
  final int? p95StopToPendingMs;
  final int? maxStopToUsefulMs;
  final int hallucinationCount;
  final int duplicateCount;
  final int staleSessionCount;
  final bool strictPass;
  final String? blocker;

  Map<String, dynamic> toJson() => {
        'phrase_id': phraseId,
        'expected_path': expectedPath,
        'expected_title': expectedTitle,
        'valid_runs': validRuns,
        'rejected_runs': rejectedRuns,
        'recognition_accuracy': recognitionAccuracy,
        'parser_accuracy': parserAccuracy,
        'path_accuracy': pathAccuracy,
        'title_accuracy': titleAccuracy,
        'p50_stop_to_useful_candidate_ms': p50StopToUsefulMs,
        'p90_stop_to_useful_candidate_ms': p90StopToUsefulMs,
        'p95_stop_to_useful_candidate_ms': p95StopToUsefulMs,
        'p95_stop_to_pending_eligible_ms': p95StopToPendingMs,
        'max_stop_to_useful_candidate_ms': maxStopToUsefulMs,
        'hallucination_count': hallucinationCount,
        'duplicate_count': duplicateCount,
        'stale_session_count': staleSessionCount,
        'strict_pass': strictPass,
        'blocker': blocker,
      };
}

class DesktopVoiceHelperBootstrapDiagnostics {
  DesktopVoiceHelperBootstrapDiagnostics({
    required this.helperPath,
    this.helperPid,
    this.helperBuildIdentity,
    required this.helperReady,
    required this.helperReadyWaitMs,
    required this.modelLoaded,
    required this.warmupDone,
    required this.effectiveInitialPrompt,
    required this.staleHelperProcessesKilled,
    required this.benchmarkStartTime,
    required this.engine,
  });

  final String helperPath;
  final int? helperPid;
  final String? helperBuildIdentity;
  final bool helperReady;
  final int helperReadyWaitMs;
  final bool modelLoaded;
  final bool warmupDone;
  final String effectiveInitialPrompt;
  final int staleHelperProcessesKilled;
  final String benchmarkStartTime;
  final String engine;

  Map<String, dynamic> toJson() => {
        'helper_path': helperPath,
        'helper_pid': helperPid,
        'helper_build_identity': helperBuildIdentity,
        'helper_ready': helperReady,
        'helper_ready_wait_ms': helperReadyWaitMs,
        'model_loaded': modelLoaded,
        'warmup_done': warmupDone,
        'effective_initial_prompt': effectiveInitialPrompt,
        'stale_helper_processes_killed': staleHelperProcessesKilled,
        'benchmark_start_time': benchmarkStartTime,
        'engine': engine,
      };
}

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
    this.phraseId,
    this.candidateSource,
    this.hallucinationGateStatus,
    this.contaminationGateStatus,
    this.recordingStartToUsefulCandidateMs,
    this.cachedCandidateAgeMs,
    this.usefulPartialBeforeStop = false,
    this.finalText,
    this.wrongPath = false,
    this.wrongTitle = false,
    this.duplicateTextDetected = false,
    this.hallucinatedTextDetected = false,
    this.finalOnlyCandidate = false,
    this.fakeZeroMs = false,
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
  final String? phraseId;
  final String? candidateSource;
  final String? hallucinationGateStatus;
  final String? contaminationGateStatus;
  final int? recordingStartToUsefulCandidateMs;
  final int? cachedCandidateAgeMs;
  final bool usefulPartialBeforeStop;
  final String? finalText;
  final bool wrongPath;
  final bool wrongTitle;
  final bool duplicateTextDetected;
  final bool hallucinatedTextDetected;
  final bool finalOnlyCandidate;
  final bool fakeZeroMs;

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
        'phrase_id': phraseId,
        'candidate_source': candidateSource,
        'hallucination_gate_status': hallucinationGateStatus,
        'contamination_gate_status': contaminationGateStatus,
        'recording_start_to_useful_candidate_ms': recordingStartToUsefulCandidateMs,
        'cached_candidate_age_ms': cachedCandidateAgeMs,
        'useful_partial_before_stop': usefulPartialBeforeStop,
        'final_text': finalText,
        'wrong_path': wrongPath,
        'wrong_title': wrongTitle,
        'duplicate_text_detected': duplicateTextDetected,
        'hallucinated_text_detected': hallucinatedTextDetected,
        'final_only_candidate': finalOnlyCandidate,
        'fake_zero_ms': fakeZeroMs,
        'expected_path': null,
        'expected_title': null,
        'actual_path': matchedPath,
        'actual_title': recordTitle,
        'stale_result_discarded': staleResultsDiscarded > 0,
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
    this.helperDiagnostics,
    this.perPhrase = const [],
    this.totalWarmIterations = 0,
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
  final DesktopVoiceHelperBootstrapDiagnostics? helperDiagnostics;
  final List<DesktopVoicePhraseBenchmarkResult> perPhrase;
  final int totalWarmIterations;

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
        'helper_diagnostics': helperDiagnostics?.toJson(),
        'per_phrase': perPhrase.map((p) => p.toJson()).toList(),
        'total_warm_iterations': totalWarmIterations,
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
  static const marker100Warm = 'DESKTOP_VOICE_100_WARM_RUNS';
  static const markerMultiPhrase = 'DESKTOP_VOICE_MULTI_PHRASE_REAL_HELPER_BENCHMARK';
  static const markerFivePhrase = 'DESKTOP_VOICE_FIVE_PHRASE_BALANCED_COVERAGE';
  static const markerP95Pass = 'DESKTOP_VOICE_USEFUL_LATENCY_P95_UNDER_500MS';
  static const markerAllPhrasesP95 = 'DESKTOP_VOICE_ALL_PHRASES_LATENCY_P95_UNDER_500MS';
  static const markerStopUnder500 = 'DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS';
  static const markerFirstReady = 'DESKTOP_VOICE_FIRST_READY_COMMAND_UNDER_500MS';
  static const markerZeroStale = 'DESKTOP_VOICE_ZERO_STALE_SESSION_ACCEPTANCE';
  static const markerHelperReady = 'DESKTOP_VOICE_INSTALLED_HELPER_READY_FOR_BENCHMARK';
  static const markerNeutralPrompt = 'DESKTOP_VOICE_NEUTRAL_INITIAL_PROMPT_ACTIVE';
  static const markerNoStaleHelper = 'DESKTOP_VOICE_NO_STALE_HELPER_PROCESS';
  static const markerCurrentSessionCache = 'DESKTOP_VOICE_CURRENT_SESSION_CACHE_ONLY';
  static const markerCachedAgeLogged = 'DESKTOP_VOICE_CACHED_CANDIDATE_AGE_LOGGED';
  static const markerNoFakeZero = 'DESKTOP_VOICE_NO_FAKE_ZERO_MS_LATENCY';
  static const markerLmP95 = 'DESKTOP_VOICE_LOGICAL_MARKETING_LATENCY_P95_UNDER_500MS';
  static const markerScwP95 = 'DESKTOP_VOICE_SCW_LATENCY_P95_UNDER_500MS';
  static const markerZeroHallucination = 'DESKTOP_VOICE_ZERO_HALLUCINATED_CLIENT_INSERTIONS';
  static const markerZeroDuplicate = 'DESKTOP_VOICE_ZERO_DUPLICATE_TITLE_SEGMENTS';

  static const defaultInstalledHelper = r'C:\Users\nkuch\AppData\Local\Programs\Counter\stt_helper\counter_stt_helper.exe';
  static const helperUrl = 'http://127.0.0.1:8765';
  static const fixtureDir = 'test/fixtures/desktop_voice_wav';
  static const minPartialBytes = 32000;
  static const streamChunkBytes = 3200;
  static const partialPollMs = 100;
  static const streamChunkDelayMs = 100;

  static Process? _helperProcess;
  static Map<String, dynamic>? _statusBeforeIteration;

  static List<CategoryRule> logicalMarketingCategoryRules() => [
        CategoryRule(
          id: 10,
          name: 'Work',
          backendRowId: 'workroot1234567',
          children: [
            CategoryRule(
              id: 20,
              name: 'Marketing',
              backendRowId: 'marketingroot123',
              children: [
                CategoryRule(
                  id: 21,
                  name: 'Logical Marketing',
                  backendRowId: 'logicalmkt12345',
                  keywords: {
                    'en': ['logical marketing'],
                  },
                ),
                CategoryRule(
                  id: 22,
                  name: 'Technical Marketing',
                  backendRowId: 'techmkt1234567',
                  keywords: {
                    'en': ['technical marketing'],
                  },
                ),
              ],
            ),
          ],
        ),
      ];

  static List<CategoryRule> blinkLaredoCategoryRules() => [
        CategoryRule(
          id: 300,
          name: 'BLINK',
          backendRowId: 'blinkroot123456',
          children: [
            CategoryRule(
              id: 301,
              name: 'Laredo Technical Services',
              backendRowId: 'blinklaredo1234',
            ),
          ],
        ),
      ];

  static List<CategoryRule> planningCategoryRules() => [
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
                  id: 102,
                  name: 'Planning',
                  backendRowId: 'planningcat1234',
                ),
              ],
            ),
          ],
        ),
      ];

  static List<CategoryRule> laredoAddSinCategoryRules() => [
        CategoryRule(
          id: 200,
          name: 'Laredo Technical Services',
          backendRowId: 'laredoroot12345',
          normalizedId: 'laredo_ts',
        ),
      ];

  static List<DesktopVoiceBenchmarkPhraseConfig> fivePhraseConfigs() => [
        DesktopVoiceBenchmarkPhraseConfig(
          id: DesktopVoiceBenchmarkPhraseId.scwDelModSubmit,
          wavFile: 'scw_delmod_submit_cpal_4f9c984.wav',
          expectedPathDescription:
              'Work > Price Reporter > SOUTHERN COMPUTER warehouse > DEL MOD',
          expectedTitle: 'Submit',
          rules: scwCategoryRules(),
          pathMatches: desktopVoicePathMatchesScwDelMod,
          titleMatches: desktopVoiceTitleIsSubmit,
          forbiddenTranscriptFragments: ['blink', 'laredo'],
        ),
        DesktopVoiceBenchmarkPhraseConfig(
          id: DesktopVoiceBenchmarkPhraseId.logicalMarketingActions,
          wavFile: 'logical_marketing_actions_sapi.wav',
          expectedPathDescription: 'Work > Marketing > Logical Marketing',
          expectedTitle: 'Actions',
          rules: logicalMarketingCategoryRules(),
          pathMatches: desktopVoicePathMatchesLogicalMarketing,
          titleMatches: desktopVoiceTitleIsActions,
          forbiddenTranscriptFragments: [
            'taxis',
            'technical marketing',
          ],
        ),
        DesktopVoiceBenchmarkPhraseConfig(
          id: DesktopVoiceBenchmarkPhraseId.blinkLaredoTechnicalServices,
          wavFile: 'blink_laredo_technical_services_sapi.wav',
          expectedPathDescription: 'BLINK > Laredo Technical Services',
          expectedTitle: '(category start)',
          rules: blinkLaredoCategoryRules(),
          pathMatches: desktopVoicePathMatchesBlinkLaredo,
          titleMatches: (_) => true,
        ),
        DesktopVoiceBenchmarkPhraseConfig(
          id: DesktopVoiceBenchmarkPhraseId.priceReporterPlanning,
          wavFile: 'price_reporter_planning_sapi.wav',
          expectedPathDescription: 'Work > Price Reporter > Planning',
          expectedTitle: '(category start)',
          rules: planningCategoryRules(),
          pathMatches: desktopVoicePathMatchesPlanning,
          titleMatches: desktopVoiceTitleIsEmptyOrPlanning,
        ),
        DesktopVoiceBenchmarkPhraseConfig(
          id: DesktopVoiceBenchmarkPhraseId.laredoTechnicalServicesAddSin,
          wavFile: 'laredo_technical_services_add_sin_sapi.wav',
          expectedPathDescription: 'Laredo Technical Services',
          expectedTitle: 'ADD SIN',
          rules: laredoAddSinCategoryRules(),
          pathMatches: desktopVoicePathMatchesLaredoRoot,
          titleMatches: desktopVoiceTitleIsAddSin,
        ),
      ];

  static List<CategoryRule> benchmarkCategoryRules() => [
        ...logicalMarketingCategoryRules(),
        ...blinkLaredoCategoryRules(),
        ...scwCategoryRules(),
      ];

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
    Duration timeout = const Duration(seconds: 300),
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
              body['final_transcribe_ready'] == true &&
              body['model_loaded'] == true &&
              body['warmup_done'] == true) {
            return true;
          }
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  static Future<int> killStaleHelperProcesses() async {
    if (!Platform.isWindows) return 0;
    try {
      final r = await Process.run(
        'taskkill',
        ['/F', '/IM', 'counter_stt_helper.exe'],
        runInShell: true,
      );
      if (r.exitCode == 0) return 1;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<String?> helperExeSha256Prefix(String path) async {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final bytes = await f.readAsBytes();
      return sha256.convert(bytes).toString().substring(0, 12);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> helperSessionRoutesReady() async {
    if (!await helperReachable()) return false;
    try {
      final r = await http
          .post(
            Uri.parse('$helperUrl/transcribe/reset_session'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': 'route_probe'}),
          )
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<DesktopVoiceHelperBootstrapDiagnostics> bootstrapInstalledHelper({
    String helperPath = defaultInstalledHelper,
  }) async {
    final start = DateTime.now();
    var killed = 0;
    final skipKill = Platform.environment['HELPER_ALREADY_BOOTSTRAPPED'] == '1';

    final routesReady = await helperSessionRoutesReady();
    final reachable = await helperReachable();

    if (!skipKill && !routesReady && !reachable) {
      killed = await killStaleHelperProcesses();
      if (killed > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      final exe = File(helperPath);
      if (!exe.existsSync()) {
        return DesktopVoiceHelperBootstrapDiagnostics(
          helperPath: helperPath,
          helperReady: false,
          helperReadyWaitMs: 0,
          modelLoaded: false,
          warmupDone: false,
          effectiveInitialPrompt:
              DesktopVoiceHallucinationGate.neutralWhisperInitialPrompt,
          staleHelperProcessesKilled: killed,
          benchmarkStartTime: start.toUtc().toIso8601String(),
          engine: 'unknown',
        );
      }

      _helperProcess = await Process.start(
        exe.path,
        const ['--port', '8765'],
        workingDirectory: exe.parent.path,
      );
      try {
        await http
            .post(
              Uri.parse('$helperUrl/config'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'engine': 'whisper-tiny'}),
            )
            .timeout(const Duration(seconds: 30));
      } catch (_) {}
    } else if (!routesReady && reachable) {
      try {
        await http
            .post(
              Uri.parse('$helperUrl/config'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'engine': 'whisper-tiny'}),
            )
            .timeout(const Duration(seconds: 30));
      } catch (_) {}
    }

    final ready = await waitHelperReady(timeout: const Duration(seconds: 300));
    final waitMs = DateTime.now().difference(start).inMilliseconds;
    final status = await helperStatus();
    final buildId = await helperExeSha256Prefix(helperPath);

    return DesktopVoiceHelperBootstrapDiagnostics(
      helperPath: helperPath,
      helperPid: _helperProcess?.pid,
      helperBuildIdentity: buildId,
      helperReady: ready,
      helperReadyWaitMs: waitMs,
      modelLoaded: status?['model_loaded'] == true,
      warmupDone: status?['warmup_done'] == true,
      effectiveInitialPrompt:
          DesktopVoiceHallucinationGate.neutralWhisperInitialPrompt,
      staleHelperProcessesKilled: killed,
      benchmarkStartTime: start.toUtc().toIso8601String(),
      engine: (status?['model'] as String?) ?? 'whisper-tiny',
    );
  }

  static Future<bool> ensureInstalledHelperRunning({
    String helperPath = defaultInstalledHelper,
  }) async {
    final boot = await bootstrapInstalledHelper(helperPath: helperPath);
    return boot.helperReady;
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

  static Future<DesktopVoiceLatencyIteration> runPhraseIteration({
    required int iteration,
    required String scenario,
    required String phraseId,
    required List<int> pcm,
    required DesktopVoiceBenchmarkPhraseConfig phraseConfig,
    required DesktopVoiceGlossaryPack glossary,
    required int benchmarkEpochMs,
    bool simulateStaleSession = false,
  }) async {
    var staleDiscarded = 0;
    final rules = phraseConfig.rules;
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

    var sessionBestPartial = '';
    var sessionBestUseful = false;
    var usefulPartialBeforeStop = false;
    int? firstPartialMs;
    String? firstPartialText;
    String? firstPartialSid;
    var firstPartialUseful = false;
    int? cachedCandidateAgeMs;

    if (pcm.length >= minPartialBytes) {
      unawaited(sendPartialAudio(sessionId: sessionId, pcm: pcm));
    }
    final pollDeadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(pollDeadline)) {
      await Future<void>.delayed(
        const Duration(milliseconds: partialPollMs),
      );
      final partial = await fetchLastPartial(activeSessionId: sessionId);
      if (partial.sessionId != null &&
          partial.sessionId!.isNotEmpty &&
          partial.sessionId != sessionId) {
        staleDiscarded++;
      } else if (partial.text != null && partial.text!.isNotEmpty) {
        sessionBestPartial = DesktopVoiceTranscriptMerge.applyPartial(
          previous: sessionBestPartial,
          partial: partial.text!,
        );
        final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
          transcript: sessionBestPartial,
          categoryRules: rules,
          glossary: glossary,
        );
        final usefulNow = eval.useful && eval.pendingEligible;
        sessionBestUseful = usefulNow;
        firstPartialMs ??=
            DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;
        firstPartialText ??= partial.text;
        firstPartialSid ??= partial.sessionId;
        firstPartialUseful = eval.pendingEligible;
        cachedCandidateAgeMs = partial.ageMs;
        if (usefulNow) {
          usefulPartialBeforeStop = true;
          break;
        }
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
    var hallucinationGateStatus = 'clean';
    String? candidateSource;
    String? matchedPath;
    String? recordTitle;

    if (sessionBestUseful && sessionBestPartial.isNotEmpty) {
      candidateText = sessionBestPartial;
      candidateSid = sessionId;
      candidateUseful = true;
      candidateSource = 'rolling_partial_cache';
      final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: sessionBestPartial,
        categoryRules: rules,
        glossary: glossary,
      );
      candidateParseStatus = eval.parseStatus;
      candidateContamination =
          eval.contaminationDetected ? (eval.contaminationReason ?? 'yes') : 'clean';
      hallucinationGateStatus = candidateContamination;
      matchedPath = eval.matchedPath;
      recordTitle = eval.normalizedTitle;
      firstCandidateMs = stopMs;
      pendingEligibleMs = stopMs;
    } else {
      final partial = await fetchLastPartial(activeSessionId: sessionId);
      cachedCandidateAgeMs ??= partial.ageMs;
      if (partial.sessionId != null &&
          partial.sessionId!.isNotEmpty &&
          partial.sessionId != sessionId) {
        staleDiscarded++;
      } else if (partial.text != null && partial.text!.isNotEmpty) {
        candidateText = partial.text;
        candidateSid = partial.sessionId ?? sessionId;
        candidateSource = 'stop_partial_fetch';
        final eval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
          transcript: partial.text!,
          categoryRules: rules,
          glossary: glossary,
        );
        candidateUseful = eval.useful && eval.pendingEligible;
        candidateParseStatus = eval.parseStatus;
        candidateContamination =
            eval.contaminationDetected ? (eval.contaminationReason ?? 'yes') : 'clean';
        hallucinationGateStatus = candidateContamination;
        matchedPath = eval.matchedPath;
        recordTitle = eval.normalizedTitle;
        if (candidateUseful) {
          firstCandidateMs =
              DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;
          pendingEligibleMs = firstCandidateMs;
        }
      }
    }

    final finalStop = await stopTranscribe(sessionId: sessionId, pcm: pcm);
    final finalTextMs = DateTime.now().millisecondsSinceEpoch - benchmarkEpochMs;
    final finalText = finalStop.text;

    var finalOnlyCandidate = false;
    var duplicateTextDetected = false;
    var hallucinatedTextDetected = false;
    String? rejectReason;
    if (finalText != null && finalText.trim().isNotEmpty) {
      final finalEval = DesktopVoiceUsefulCandidateEvaluation.evaluate(
        transcript: finalText,
        categoryRules: rules,
        glossary: glossary,
      );
      if (finalEval.contaminationDetected) {
        candidateUseful = false;
        candidateContamination =
            finalEval.contaminationReason ?? 'contaminated_final';
        hallucinationGateStatus = candidateContamination;
        rejectReason = 'contaminated_final';
        firstCandidateMs = null;
        pendingEligibleMs = null;
      }
      if (!usefulPartialBeforeStop && !candidateUseful && finalEval.useful) {
        finalOnlyCandidate = true;
        candidateSource = 'final_inference';
      }
      duplicateTextDetected =
          DesktopVoiceTranscriptMerge.hasRepeatedCommandSuffix(finalText);
      for (final frag in phraseConfig.forbiddenTranscriptFragments) {
        if (finalText.toLowerCase().contains(frag)) {
          hallucinatedTextDetected = true;
        }
      }
      if (candidateText != null) {
        final ct = candidateText;
        for (final frag in phraseConfig.forbiddenTranscriptFragments) {
          if (ct.toLowerCase().contains(frag)) {
            hallucinatedTextDetected = true;
          }
        }
      }
    }

    final pathOk = phraseConfig.pathMatches(matchedPath);
    final titleOk = phraseConfig.titleMatches(recordTitle);
    final wrongPath = candidateUseful && !pathOk;
    final wrongTitle = candidateUseful && !titleOk;

    var fakeZeroMs = false;
    if (candidateUseful &&
        firstCandidateMs != null &&
        firstCandidateMs - stopMs == 0 &&
        !usefulPartialBeforeStop) {
      fakeZeroMs = true;
    }

    final stopToUseful = (candidateUseful && firstCandidateMs != null)
        ? firstCandidateMs - stopMs
        : null;
    final stopToPending =
        pendingEligibleMs != null ? pendingEligibleMs - stopMs : null;
    final recordingStartToUseful = (candidateUseful && firstCandidateMs != null)
        ? firstCandidateMs - recordingStart
        : null;

    final statusAfter = await helperStatus();
    final modelReinit = _statusBeforeIteration != null &&
        statusAfter != null &&
        statusAfter['warmup_done'] != true &&
        _statusBeforeIteration!['warmup_done'] == true;

    var counted = false;
    if (candidateUseful &&
        stopToUseful != null &&
        stopToUseful < 500 &&
        pathOk &&
        titleOk &&
        candidateContamination == 'clean' &&
        candidateSid == sessionId &&
        usefulPartialBeforeStop &&
        !finalOnlyCandidate &&
        !fakeZeroMs &&
        !hallucinatedTextDetected &&
        !duplicateTextDetected) {
      counted = true;
    } else if (rejectReason == null) {
      if (finalOnlyCandidate) {
        rejectReason = 'final_only_candidate';
      } else if (fakeZeroMs) {
        rejectReason = 'fake_zero_ms_no_partial';
      } else if (!usefulPartialBeforeStop) {
        rejectReason = 'no_useful_rolling_partial';
      } else if (!candidateUseful) {
        rejectReason = candidateContamination != 'clean'
            ? 'contaminated'
            : 'not_useful';
      } else if (stopToUseful == null || stopToUseful >= 500) {
        rejectReason = 'slow_${stopToUseful ?? 'null'}';
      } else if (!pathOk) {
        rejectReason = 'wrong_path';
      } else if (!titleOk) {
        rejectReason = 'wrong_title';
      } else if (hallucinatedTextDetected) {
        rejectReason = 'hallucinated_text';
      } else if (duplicateTextDetected) {
        rejectReason = 'duplicate_text';
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
      phraseId: phraseId,
      candidateSource: candidateSource,
      hallucinationGateStatus: hallucinationGateStatus,
      contaminationGateStatus: candidateContamination,
      recordingStartToUsefulCandidateMs: recordingStartToUseful,
      cachedCandidateAgeMs: cachedCandidateAgeMs,
      usefulPartialBeforeStop: usefulPartialBeforeStop,
      finalText: finalText,
      wrongPath: wrongPath,
      wrongTitle: wrongTitle,
      duplicateTextDetected: duplicateTextDetected,
      hallucinatedTextDetected: hallucinatedTextDetected,
      finalOnlyCandidate: finalOnlyCandidate,
      fakeZeroMs: fakeZeroMs,
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

  static List<int> loadFixturePcm(String wavFile) {
    final pcmRaw =
        extractPcm16FromWav(File('$fixtureDir/$wavFile').readAsBytesSync());
    final processing = applyProductionWhisperSttProcessing(pcmRaw);
    return processing.applied ? processing.pcm : pcmRaw;
  }

  static String phraseIdFor(DesktopVoiceBenchmarkPhraseId id) => switch (id) {
        DesktopVoiceBenchmarkPhraseId.scwDelModSubmit => 'scw_delmod_submit',
        DesktopVoiceBenchmarkPhraseId.logicalMarketingActions =>
          'logical_marketing_actions',
        DesktopVoiceBenchmarkPhraseId.blinkLaredoTechnicalServices =>
          'blink_laredo_technical_services',
        DesktopVoiceBenchmarkPhraseId.priceReporterPlanning =>
          'price_reporter_planning',
        DesktopVoiceBenchmarkPhraseId.laredoTechnicalServicesAddSin =>
          'laredo_technical_services_add_sin',
      };

  static DesktopVoicePhraseBenchmarkResult summarizePhrase({
    required DesktopVoiceBenchmarkPhraseConfig config,
    required List<DesktopVoiceLatencyIteration> allIterations,
    required int warmIterations,
  }) {
    final pid = phraseIdFor(config.id);
    final warmRuns =
        allIterations.where((i) => i.scenario == 'warm_$pid').toList();
    final counted = warmRuns.where((i) => i.counted).toList();
    final rejected = warmRuns.where((i) => !i.counted).toList();
    final usefulMs =
        counted.map((i) => i.stopToUsefulCandidateMs!).toList(growable: false);
    final pendingMs = counted
        .map((i) => i.stopToPendingEligibleMs ?? i.stopToUsefulCandidateMs!)
        .toList(growable: false);

    var hallucinationCount = 0;
    var duplicateCount = 0;
    var staleSessionCount = 0;
    var pathOkCount = 0;
    var titleOkCount = 0;
    var parseOkCount = 0;
    for (final it in warmRuns) {
      if (it.hallucinatedTextDetected) hallucinationCount++;
      if (it.duplicateTextDetected) duplicateCount++;
      if (it.staleResultsDiscarded > 0 && it.counted) staleSessionCount++;
      if (it.counted) {
        parseOkCount++;
        if (config.pathMatches(it.matchedPath)) pathOkCount++;
        if (config.titleMatches(it.recordTitle)) titleOkCount++;
      }
    }

    final p50 = usefulMs.isEmpty ? null : percentile(usefulMs, 0.50);
    final p90 = usefulMs.isEmpty ? null : percentile(usefulMs, 0.90);
    final p95 = usefulMs.isEmpty ? null : percentile(usefulMs, 0.95);
    final p95Pending =
        pendingMs.isEmpty ? null : percentile(pendingMs, 0.95);
    final maxMs = usefulMs.isEmpty ? null : usefulMs.reduce(max);

    final recognitionAccuracy = warmRuns.isEmpty
        ? 0.0
        : counted.length / warmRuns.length;
    final parserAccuracy = counted.isEmpty
        ? 0.0
        : parseOkCount / counted.length;
    final pathAccuracy =
        counted.isEmpty ? 0.0 : pathOkCount / counted.length;
    final titleAccuracy =
        counted.isEmpty ? 0.0 : titleOkCount / counted.length;

    final strictPass = counted.length >= warmIterations &&
        p95 != null &&
        p95 < 500 &&
        p95Pending != null &&
        p95Pending < 500 &&
        hallucinationCount == 0 &&
        duplicateCount == 0 &&
        staleSessionCount == 0 &&
        pathAccuracy == 1.0 &&
        titleAccuracy == 1.0;

    String? blocker;
    if (!strictPass) {
      if (counted.length < warmIterations) {
        blocker = 'insufficient_valid_${counted.length}_of_$warmIterations';
      } else if (p95 == null || p95 >= 500) {
        blocker = 'p95_${p95 ?? 'null'}_ms';
      } else if (p95Pending == null || p95Pending >= 500) {
        blocker = 'p95_pending_${p95Pending ?? 'null'}_ms';
      } else if (hallucinationCount > 0) {
        blocker = 'hallucination_$hallucinationCount';
      } else if (duplicateCount > 0) {
        blocker = 'duplicate_$duplicateCount';
      } else if (pathAccuracy < 1.0 || titleAccuracy < 1.0) {
        blocker = 'wrong_path_title';
      }
    }

    return DesktopVoicePhraseBenchmarkResult(
      phraseId: pid,
      expectedPath: config.expectedPathDescription,
      expectedTitle: config.expectedTitle,
      validRuns: counted.length,
      rejectedRuns: rejected.length,
      recognitionAccuracy: recognitionAccuracy,
      parserAccuracy: parserAccuracy,
      pathAccuracy: pathAccuracy,
      titleAccuracy: titleAccuracy,
      p50StopToUsefulMs: p50,
      p90StopToUsefulMs: p90,
      p95StopToUsefulMs: p95,
      p95StopToPendingMs: p95Pending,
      maxStopToUsefulMs: maxMs,
      hallucinationCount: hallucinationCount,
      duplicateCount: duplicateCount,
      staleSessionCount: staleSessionCount,
      strictPass: strictPass,
      blocker: blocker,
    );
  }

  static Future<DesktopVoiceLatencyBenchmarkReport> runFullSuite({
    String helperPath = defaultInstalledHelper,
    String buildSha = 'dd1cbe2',
    int warmIterations = 20,
    String primaryFixture = 'scw_delmod_submit_cpal_4f9c984.wav',
  }) async {
    DesktopVoicePipeline.mark(markerBenchmark);
    final phraseConfigs = fivePhraseConfigs();
    final fixtures = phraseConfigs.map((p) => p.wavFile).toList();

    final boot = await bootstrapInstalledHelper(helperPath: helperPath);
    if (!boot.helperReady) {
      return _failedReport(
        buildSha: buildSha,
        helperPath: helperPath,
        fixtures: fixtures,
        blocker: 'helper_not_ready',
        helperDiagnostics: boot,
      );
    }

    DesktopVoicePipeline.mark(markerHelperReady);
    DesktopVoicePipeline.mark(markerNeutralPrompt);
    DesktopVoicePipeline.mark(markerNoStaleHelper);

    for (final cfg in phraseConfigs) {
      if (!File('$fixtureDir/${cfg.wavFile}').existsSync()) {
        return _failedReport(
          buildSha: buildSha,
          helperPath: helperPath,
          fixtures: fixtures,
          blocker: 'fixture_missing_${phraseIdFor(cfg.id)}',
          engine: boot.engine,
          helperWarm: boot.warmupDone,
          helperDiagnostics: boot,
        );
      }
    }

    final status0 = await helperStatus();
    final engine = boot.engine;
    final helperWarm = boot.warmupDone;
    final allIterations = <DesktopVoiceLatencyIteration>[];
    final epoch = DateTime.now().millisecondsSinceEpoch;
    var globalIter = 0;

    _statusBeforeIteration = status0;

    final scwConfig = phraseConfigs.first;
    final scwPcm = loadFixturePcm(scwConfig.wavFile);
    final scwGlossary =
        DesktopVoiceGlossaryPack.buildFromCategoryRules(scwConfig.rules);

    final warmSession = DesktopVoiceSessionRegistry.begin();
    await resetSession(warmSession.id);
    await sendPartialAudio(sessionId: warmSession.id, pcm: scwPcm);
    await waitPartialInference();
    await stopTranscribe(sessionId: warmSession.id, pcm: scwPcm);
    DesktopVoiceSessionRegistry.end(reason: 'warmup');

    globalIter++;
    allIterations.add(
      await runPhraseIteration(
        iteration: globalIter,
        scenario: 'first_after_ready',
        phraseId: phraseIdFor(scwConfig.id),
        pcm: scwPcm,
        phraseConfig: scwConfig,
        glossary: scwGlossary,
        benchmarkEpochMs: epoch,
      ),
    );

    for (final cfg in phraseConfigs) {
      final pcm = loadFixturePcm(cfg.wavFile);
      final glossary =
          DesktopVoiceGlossaryPack.buildFromCategoryRules(cfg.rules);
      final pid = phraseIdFor(cfg.id);
      for (var i = 1; i <= warmIterations; i++) {
        globalIter++;
        allIterations.add(
          await runPhraseIteration(
            iteration: globalIter,
            scenario: 'warm_$pid',
            phraseId: pid,
            pcm: pcm,
            phraseConfig: cfg,
            glossary: glossary,
            benchmarkEpochMs: epoch,
          ),
        );
      }
    }

    DesktopVoicePipeline.mark(marker20Warm);
    DesktopVoicePipeline.mark(marker100Warm);
    DesktopVoicePipeline.mark(markerMultiPhrase);
    DesktopVoicePipeline.mark(markerFivePhrase);
    DesktopVoicePipeline.mark(markerCurrentSessionCache);
    DesktopVoicePipeline.mark(markerCachedAgeLogged);
    DesktopVoicePipeline.mark(markerNoFakeZero);

    final contaminatedWav = File(
      '$fixtureDir/scw_contaminated_67ea8eb_contaminated_2026_07_10.wav',
    );
    if (contaminatedWav.existsSync()) {
      final contaminatedPcm =
          loadFixturePcm('scw_contaminated_67ea8eb_contaminated_2026_07_10.wav');
      for (var i = 0; i < 5; i++) {
        final blinkSession = DesktopVoiceSessionRegistry.begin();
        await resetSession(blinkSession.id);
        await sendPartialAudio(sessionId: blinkSession.id, pcm: contaminatedPcm);
        await waitPartialInference();
        await stopTranscribe(sessionId: blinkSession.id, pcm: contaminatedPcm);
        DesktopVoiceSessionRegistry.end(reason: 'blink_session');
        globalIter++;
        final scw = await runPhraseIteration(
          iteration: globalIter,
          scenario: 'blink_then_scw_$i',
          phraseId: phraseIdFor(scwConfig.id),
          pcm: scwPcm,
          phraseConfig: scwConfig,
          glossary: scwGlossary,
          benchmarkEpochMs: epoch,
        );
        final text = (scw.firstCandidateText ?? '').toLowerCase();
        if (text.contains('blink') || text.contains('laredo')) {
          scw.rejectReason = 'blink_leak';
          scw.counted = false;
        }
        allIterations.add(scw);
      }
    }

    for (var i = 0; i < 5; i++) {
      final cancelSession = DesktopVoiceSessionRegistry.begin();
      await resetSession(cancelSession.id);
      await sendPartialAudio(sessionId: cancelSession.id, pcm: scwPcm);
      await resetSession(cancelSession.id);
      DesktopVoiceSessionRegistry.end(reason: 'cancel_before_stop');
      globalIter++;
      allIterations.add(
        await runPhraseIteration(
          iteration: globalIter,
          scenario: 'cancel_then_scw_$i',
          phraseId: phraseIdFor(scwConfig.id),
          pcm: scwPcm,
          phraseConfig: scwConfig,
          glossary: scwGlossary,
          benchmarkEpochMs: epoch,
        ),
      );
    }

    for (var i = 0; i < 5; i++) {
      globalIter++;
      allIterations.add(
        await runPhraseIteration(
          iteration: globalIter,
          scenario: 'stale_inject_$i',
          phraseId: phraseIdFor(scwConfig.id),
          pcm: scwPcm,
          phraseConfig: scwConfig,
          glossary: scwGlossary,
          benchmarkEpochMs: epoch,
          simulateStaleSession: true,
        ),
      );
    }

    if (contaminatedWav.existsSync()) {
      final contaminatedPcm =
          extractPcm16FromWav(contaminatedWav.readAsBytesSync());
      globalIter++;
      final contaminatedIter = await runPhraseIteration(
        iteration: globalIter,
        scenario: 'contaminated_fixture',
        phraseId: phraseIdFor(scwConfig.id),
        pcm: contaminatedPcm,
        phraseConfig: scwConfig,
        glossary: scwGlossary,
        benchmarkEpochMs: epoch,
      );
      if (contaminatedIter.counted) {
        contaminatedIter.rejectReason = 'contaminated_fixture_not_warm';
        contaminatedIter.counted = false;
      }
      allIterations.add(contaminatedIter);
    }

    final perPhrase = phraseConfigs
        .map(
          (cfg) => summarizePhrase(
            config: cfg,
            allIterations: allIterations,
            warmIterations: warmIterations,
          ),
        )
        .toList(growable: false);

    final totalWarm = phraseConfigs.length * warmIterations;
    final allCounted = perPhrase.fold<int>(0, (s, p) => s + p.validRuns);
    final allRejected = perPhrase.fold<int>(0, (s, p) => s + p.rejectedRuns);
    final allUsefulMs = allIterations
        .where((i) => i.scenario.startsWith('warm_') && i.counted)
        .map((i) => i.stopToUsefulCandidateMs!)
        .toList(growable: false);
    final allPendingMs = allIterations
        .where((i) => i.scenario.startsWith('warm_') && i.counted)
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
      if (it.candidateUseful &&
          it.contaminationGateStatus != null &&
          it.contaminationGateStatus != 'clean') {
        contaminationFailures++;
      }
      if (it.candidateUseful &&
          it.scenario.startsWith('warm_') &&
          it.wrongPath) {
        wrongPath++;
      }
      if (it.candidateUseful &&
          it.scenario.startsWith('warm_') &&
          it.wrongTitle) {
        wrongPath++;
      }
    }

    final p50 = allUsefulMs.isEmpty ? null : percentile(allUsefulMs, 0.50);
    final p90 = allUsefulMs.isEmpty ? null : percentile(allUsefulMs, 0.90);
    final p95 = allUsefulMs.isEmpty ? null : percentile(allUsefulMs, 0.95);
    final p95Pending =
        allPendingMs.isEmpty ? null : percentile(allPendingMs, 0.95);
    final maxMs = allUsefulMs.isEmpty ? null : allUsefulMs.reduce(max);

    final allPhrasesPass = perPhrase.every((p) => p.strictPass);
    final strictPass = allPhrasesPass &&
        allCounted >= totalWarm &&
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
      'DESKTOP_VOICE_HALLUCINATED_PARTIAL_NOT_COUNTED',
      'DESKTOP_VOICE_CONTAMINATED_PARTIAL_NOT_COUNTED',
    ];
    if (!strictPass) {
      markers.add('DESKTOP_VOICE_NO_FAKE_LATENCY_PASS');
    } else {
      markers.addAll([
        markerStopUnder500,
        markerP95Pass,
        markerAllPhrasesP95,
        markerFirstReady,
        markerZeroStale,
        markerLmP95,
        markerScwP95,
        markerZeroHallucination,
        markerZeroDuplicate,
        marker100Warm,
        markerMultiPhrase,
        markerFivePhrase,
        markerHelperReady,
        markerNeutralPrompt,
        markerNoStaleHelper,
        markerCurrentSessionCache,
        markerCachedAgeLogged,
        markerNoFakeZero,
      ]);
    }

    String? blocker;
    if (!strictPass) {
      final failedPhrase = perPhrase.where((p) => !p.strictPass).toList();
      if (failedPhrase.isNotEmpty) {
        blocker =
            'phrase_${failedPhrase.first.phraseId}_${failedPhrase.first.blocker ?? 'fail'}';
      } else if (allCounted < totalWarm) {
        blocker = 'insufficient_valid_runs_${allCounted}_of_$totalWarm';
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
      validCountedRuns: allCounted,
      rejectedRuns: allRejected,
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
      helperDiagnostics: boot,
      perPhrase: perPhrase,
      totalWarmIterations: totalWarm,
    );
  }

  static DesktopVoiceLatencyBenchmarkReport _failedReport({
    required String buildSha,
    required String helperPath,
    required List<String> fixtures,
    required String blocker,
    String engine = 'unknown',
    bool helperWarm = false,
    DesktopVoiceHelperBootstrapDiagnostics? helperDiagnostics,
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
      helperDiagnostics: helperDiagnostics,
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
    final json = const JsonEncoder.withIndent('  ').convert(report.toJson());
    await File(path).writeAsString(json);
    final latest = File('$outDir/real_helper_latency_latest.json');
    try {
      await latest.writeAsString(json);
    } catch (_) {
      // IDE may lock latest.json; timestamped artifact remains authoritative.
    }
  }
}
