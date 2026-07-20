import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_stt_diagnostics.dart';
import 'package:counter/core/services/desktop_voice_audio_capture.dart';
import 'package:counter/core/services/desktop_voice_audio_presentation.dart';
import 'package:counter/core/services/desktop_voice_delayed_transcribe.dart';
import 'package:counter/core/services/desktop_stt_orchestrator.dart';
import 'package:counter/core/services/desktop_voice_engine.dart';
import 'package:counter/core/services/desktop_voice_glossary.dart';
import 'package:counter/core/services/desktop_voice_last_attempt_store.dart';
import 'package:counter/core/services/desktop_voice_overlay_service.dart';
import 'package:counter/core/services/desktop_voice_capture_endpoint.dart';
import 'package:counter/core/services/desktop_voice_capture_ready_policy.dart';
import 'package:counter/core/services/desktop_voice_native_overlay.dart';
import 'package:counter/core/services/desktop_voice_stt_processing.dart';
import 'package:counter/core/services/desktop_voice_ready_cue.dart';
import 'package:counter/core/services/desktop_voice_session.dart';
import 'package:counter/core/services/desktop_voice_transcript_merge.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/core/services/desktop_win_speech_service.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

part 'desktop_stt_helper_diagnostics_builder.dart';

/// GOLOS HTTP sidecar + unified desktop voice capture/transcription.
class DesktopSttHelperService {
  DesktopSttHelperService._();

  static final DesktopSttHelperService instance = DesktopSttHelperService._();

  static const _baseUrl = 'http://127.0.0.1:8765';
  static const _port = 8765;
  static const _levelThreshold = 0.008;
  static const _statusUrl = '$_baseUrl/status';
  static const _transcribeStopEndpoint = '/transcribe/stop';

  final _capture = DesktopVoiceAudioCapture.instance;

  Process? _process;
  bool _ready = false;
  final Map<String, bool> _engineReady = {};
  bool _finalTranscribeReady = false;
  bool _helperModelLoaded = false;
  bool _helperWarmupDone = false;
  String _reasonIfNotReady = '';
  String? _finalTranscriptSource;
  String? _partialText;
  String? _finalText;
  bool _usedPartialAsFinal = false;
  String? _stopReturnReason;
  int? _finalInferenceLatencyMs;
  String? _primarySttEngine;
  String? _primarySttResult;
  bool _fallbackSttAttempted = false;
  String? _fallbackSttEngine;
  String? _fallbackSttResult;
  String? _lastError;
  String? _engine;
  int _lastCaptureBytes = 0;
  bool _starting = false;
  bool _spawnAttempted = false;
  int? _helperExitCodeObserved;
  String? _lastStatusHttpResult;
  String? _lastStatusBody;
  String? _lastTranscribeHttpResult;
  String? _lastTranscribeErrorKind;
  String? _lastTranscribeErrorDetail;
  String _lastTranscribeResponseBodyTail = '';
  bool _transcribeCalled = false;
  bool _pendingWavAfterStop = false;
  bool _helperReadyAfterRecording = false;
  bool _delayedTranscribeCalled = false;
  String? _delayedTranscribeResult;
  String? _failureReason;
  int _overlayLevelEventsCount = 0;
  DateTime? _tRecordingStopped;
  DateTime? _tWavWritten;
  DateTime? _tTranscribeRequest;
  DateTime? _tFirstCandidateVisible;
  DateTime? _tFinalTranscriptReady;
  int? _stopToFirstCandidateMs;
  int? _stopToFinalTextMs;
  int? _audioDurationMsUsedForInference;
  String _sttGainMode = 'none';
  double _sttGainDb = 0;
  double _targetRms = DesktopVoiceSttGain.handyTargetRms;
  double _rawRmsBeforeGain = 0;
  double _rawPeakBeforeGain = 0;
  double _processedRmsAfterGain = 0;
  double _processedPeakAfterGain = 0;
  int _clippedSamplesAfterGain = 0;
  String? _sttTranscriptWithoutGain;
  String? _sttTranscriptWithGain;
  String? _sttGainRejectedReason;
  String? _engineUsedForFirstCandidate;
  String? _engineUsedForFinalText;
  int? _stopToPendingConfirmationMs;
  String? _candidateText;
  String? _candidateParseStatus;
  bool _candidateUseful = false;
  bool _candidateVisibleToUser = false;
  int? _stopToUsefulCandidateMs;
  /// When set, gates first-candidate latency metrics to parseable commands only.
  ({bool useful, String parseStatus}) Function(String text)?
      evaluateCommandCandidate;
  void Function(String text, String engineId)? onFirstCandidate;
  DesktopSttDiagnostics _lastDiagnostics = const DesktopSttDiagnostics();
  DesktopVoiceGlossaryPack? _transcribeGlossary;
  String? _activeVoiceSessionId;
  String? _sessionBestPartial;
  Timer? _sessionPartialPollTimer;
  bool _sessionBestPartialUseful = false;

  String? get activeVoiceSessionId => _activeVoiceSessionId;

  /// Binds helper partial cache to [sessionId] and clears Dart-side transcript state.
  Future<void> beginVoiceSession(String sessionId) async {
    _sessionPartialPollTimer?.cancel();
    _sessionPartialPollTimer = null;
    _activeVoiceSessionId = sessionId;
    _sessionBestPartial = null;
    _sessionBestPartialUseful = false;
    _partialText = null;
    _finalText = null;
    _candidateText = null;
    _candidateUseful = false;
    _candidateVisibleToUser = false;
    DesktopVoicePipeline.mark('voice_session_id', sessionId);
    DesktopVoicePipeline.mark('active_session_id', sessionId);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_BUFFER_RESET_AT_START');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_PARTIAL_CACHE_RESET_AT_START');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_PENDING_COMMAND_RESET_AT_START');
    await _resetHelperSessionState(sessionId);
    _sessionPartialPollTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(_pollSessionPartial()),
    );
  }

  void endVoiceSession() {
    _sessionPartialPollTimer?.cancel();
    _sessionPartialPollTimer = null;
    _activeVoiceSessionId = null;
    _sessionBestPartial = null;
  }

  Future<void> _resetHelperSessionState(String sessionId) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/transcribe/reset_session'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': sessionId}),
          )
          .timeout(const Duration(seconds: 2));
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_SESSION_RESET', sessionId);
    } catch (_) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HELPER_SESSION_RESET',
        'offline_or_unavailable',
      );
    }
  }

  Future<void> _pollSessionPartial() async {
    if (_activeVoiceSessionId == null) return;
    final hint = await _fetchLastPartialHint(requireSessionMatch: true);
    if (hint == null || hint.isEmpty) return;
    _sessionBestPartial = DesktopVoiceTranscriptMerge.applyPartial(
      previous: _sessionBestPartial,
      partial: hint,
    );
    _partialText = _sessionBestPartial;
    final eval = evaluateCommandCandidate?.call(_sessionBestPartial!);
    _sessionBestPartialUseful = eval?.useful ?? false;
    if (_tRecordingStopped == null) {
      // Mid-recording: do not count latency yet; still surface parseable preview.
      return;
    }
    _emitFirstCandidate(
      _sessionBestPartial!,
      resolveProductionEngine().helperEngineId,
    );
  }

  void setTranscribeGlossary(DesktopVoiceGlossaryPack? pack) {
    _transcribeGlossary = pack;
  }

  int get lastCaptureBytes => _lastCaptureBytes;
  int get capturedAudioBytes => _capture.capturedBytes;
  bool get audioLevelSeen => _capture.audioLevelSeen;
  void noteCaptureStartFailed([String? detail]) =>
      _capture.noteCaptureStartFailed(detail);
  void noteIntermittentListeningNoSignal() =>
      _capture.noteIntermittentListeningNoSignal();
  double get maxAmplitude => _capture.maxAmplitude;
  double get rmsAmplitude => _capture.rmsAmplitude;
  Stream<double>? get amplitudeStream => _capture.amplitudeStream;
  DesktopSttDiagnostics get lastDiagnostics => _lastDiagnostics;
  String? get lastWavPath => _capture.lastWavPath;

  void noteOverlayLevelEvent() {
    _overlayLevelEventsCount++;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_LEVEL_EVENT');
  }

  /// Replay the latest saved WAV through the STT helper (diagnostics / smoke).
  Future<DesktopSttTranscript?> replayLatestSavedWav() async {
    final path = _capture.lastWavPath;
    if (path == null || !File(path).existsSync()) {
      _lastError = 'No saved WAV to replay';
      return null;
    }
    final bytes = await File(path).readAsBytes();
    if (bytes.length < 44) {
      _lastError = 'Saved WAV too small';
      return null;
    }
    final pcm = bytes.sublist(44);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_USING_SAVED_WAV', path);
    final engine = resolveProductionEngine();
    if (engine == DesktopVoiceEngineId.windowsSpeech) {
      final text = await DesktopWinSpeechService.instance.transcribeWav(path);
      if (text == null || text.trim().isEmpty) return null;
      return DesktopSttTranscript(
        text: text.trim(),
        durationSec: pcm16DurationMs(pcm) / 1000.0,
        engine: engine.helperEngineId,
      );
    }
    if (!await ensureStarted(
      engine: engine,
      maxWait: kVoiceProcessingMaxWait,
      allowRestart: true,
    )) {
      return null;
    }
    final deadline = DateTime.now().add(kVoiceProcessingMaxWait);
    await _waitForFinalTranscribeReady(engine, deadline);
    var r = await _transcribePcm(engine, pcm);
    if (r == null && _isNotLoadedTranscribeError()) {
      await _waitForFinalTranscribeReady(engine, deadline);
      r = await _transcribePcm(engine, pcm);
    }
    if (r != null) return r;
    final fb = await _attemptWindowsFallbackStt(path);
    if (fb == null) return null;
    return DesktopSttTranscript(
      text: fb,
      durationSec: pcm16DurationMs(pcm) / 1000.0,
      engine: 'windows_speech',
    );
  }

  bool get isReady => _ready;
  bool get modelLoaded => _engineReady[resolveProductionEngine().helperEngineId] == true;
  String? get lastError => _lastError;
  String? get engine => _engine;

  String? get helperPath => _resolveHelperExe();

  String? modelPathFor(DesktopVoiceEngineId engine) {
    final exe = helperPath;
    if (exe == null) return null;
    return '${File(exe).parent.path}${Platform.pathSeparator}models'
        '${Platform.pathSeparator}${engine.helperEngineId}';
  }

  DesktopVoiceEngineId resolveProductionEngine() {
    return DesktopVoiceSettings.instance.resolveProductionEngine();
  }

  /// Voice-overlay warmup — hard 5s cap; never blocks mic capture.
  static const Duration kVoiceOverlayWarmupMax = Duration(seconds: 5);

  /// Max wait for STT HTTP after recording finishes when helper is already ready.
  static const Duration kVoiceProcessingMaxWait =
      DesktopVoiceDelayedTranscribe.readyHelperMaxWait;

  /// Cold-start budget after stop when a valid WAV is already saved.
  static const Duration kVoiceColdStartMaxWait =
      DesktopVoiceDelayedTranscribe.coldStartMaxWait;

  bool _restartAttemptedThisTranscribe = false;
  final List<String> _helperStdoutTail = [];
  final List<String> _helperStderrTail = [];

  void prewarmRecognizerInBackground() {
    final engine = resolveProductionEngine();
    if (engine == DesktopVoiceEngineId.windowsSpeech) return;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_ENGINE_PREWARMED', engine.helperEngineId);
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COMMAND_STT_PRIMARY_SELECTED',
      engine.helperEngineId,
    );
    if (engine == DesktopVoiceEngineId.whisperTiny) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_WHISPER_TINY_PRIMARY_IF_BEST');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_PARAKEET_NOT_PRIMARY_IF_WORSE');
    }
    unawaited(
      ensureStarted(
        engine: engine,
        maxWait: kVoiceOverlayWarmupMax,
        allowRestart: true,
      ).then((ok) {
        if (ok && _finalTranscribeReady) {
          DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_COLD_START_ON_FIRST_COMMAND');
        }
        if (ok) unawaited(fetchCaptureEndpointDiagnostics());
      }),
    );
  }

  /// GET `/capture/device_diag` — proves endpoint volume/id are not stubbed.
  Future<bool> fetchCaptureEndpointDiagnostics() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/capture/device_diag'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return false;
      final body = jsonDecode(r.body);
      if (body is! Map || body['ok'] != true) return false;
      final report = body['report'];
      if (report is Map) {
        DesktopVoiceCaptureEndpointPolicy.logFromHelperJson(
          Map<String, dynamic>.from(report),
        );
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HANDY_ENDPOINT_CONFIG_INSPECTED');
      return true;
    } catch (_) {
      return false;
    }
  }

  int? get helperPid => _process?.pid;

  bool _helperProcessAlive() {
    // Synchronous best-effort probe: Process.exitCode returns a Future that only
    // completes when the process exits. There is no synchronous liveness API,
    // so this call uses the cached exit code observed by the async probe in
    // [_helperExitCodeIfAnyLive]. Returns true only if we have a process and
    // have not observed it exit yet.
    return _process != null && _helperExitCodeObserved == null;
  }

  /// Authoritative asynchronous liveness check used by diagnostics callsites.
  /// Returns the exit code if the process has exited, otherwise null (alive).
  Future<int?> _helperExitCodeIfAnyLive() async {
    final p = _process;
    if (p == null) return null;
    try {
      return await p.exitCode.timeout(const Duration(milliseconds: 50));
    } catch (_) {
      // Timeout → process still running.
      return null;
    }
  }

  void _appendStderrTail(String chunk) {
    for (final line in chunk.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty) continue;
      _helperStderrTail.add(t);
      if (_helperStderrTail.length > 12) {
        _helperStderrTail.removeAt(0);
      }
    }
  }

  void _appendStdoutTail(String chunk) {
    // GOLOS emits status lines like "[parakeet] loaded OK", "inference error:
    // parakeet not loaded" on STDOUT. Without this capture the user has no
    // visibility into why a transcribe returned HTTP 500 between model loads.
    for (final line in chunk.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty) continue;
      _helperStdoutTail.add(t);
      if (_helperStdoutTail.length > 12) {
        _helperStdoutTail.removeAt(0);
      }
    }
  }

  String get _helperStdoutTailJoined =>
      _helperStdoutTail.isEmpty ? '' : _helperStdoutTail.join(' | ');

  String get _helperStderrTailJoined =>
      _helperStderrTail.isEmpty ? '' : _helperStderrTail.join(' | ');

  String? get helperSettingsPath {
    final exe = helperPath;
    if (exe == null) return null;
    return '${File(exe).parent.path}${Platform.pathSeparator}settings.json';
  }

  /// Models the expected file count of a valid engine model dir so the
  /// diagnostics can flag a half-installed model even when the directory
  /// itself exists. parakeet = 6 files, whisper-tiny = 2 files.
  int _expectedModelFilesCount(String engineId) {
    switch (engineId) {
      case 'parakeet':
        return 6;
      case 'whisper-tiny':
        return 2;
      default:
        return 0;
    }
  }

  Future<bool> ensureStarted({
    DesktopVoiceEngineId? engine,
    Duration maxWait = const Duration(seconds: 15),
    bool allowRestart = true,
  }) async {
    final target = engine ?? resolveProductionEngine();
    if (target == DesktopVoiceEngineId.windowsSpeech) return true;

    final key = target.helperEngineId;
    if (_ready && _engineReady[key] == true && _finalTranscribeReady) {
      return true;
    }

    final deadline = DateTime.now().add(maxWait);
    bool pastDeadline() => !DateTime.now().isBefore(deadline);

    if (_starting) {
      while (!pastDeadline()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (_ready && _engineReady[key] == true && _finalTranscribeReady) {
          return true;
        }
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_TIMEOUT', 'wait_starting');
      return false;
    }

    _starting = true;
    try {
      var ok = await _ensureHelperRunning(deadline, target);
      if (!ok && allowRestart && !pastDeadline()) {
        ok = await _restartHelper(deadline, target);
      }
      return ok;
    } finally {
      _starting = false;
    }
  }

  Future<bool> _ensureHelperRunning(
    DateTime deadline,
    DesktopVoiceEngineId target,
  ) async {
    bool pastDeadline() => !DateTime.now().isBefore(deadline);

    if (!await _ping(markStatus: true)) {
      final exe = _resolveHelperExe();
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HELPER_PATH_CHECK',
        exe ?? 'not_found',
      );
      if (exe == null) {
        _lastError = 'STT helper not found';
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_SPAWN_FAILED', 'not_found');
        return false;
      }
      final workingDir = File(exe).parent.path;
      _spawnAttempted = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_SPAWN_ATTEMPT', workingDir);
      try {
        _process = await Process.start(
          exe,
          ['--port', '$_port'],
          workingDirectory: workingDir,
        );
        _process?.stdout.transform(utf8.decoder).listen(_appendStdoutTail);
        _process?.stderr.transform(utf8.decoder).listen(_appendStderrTail);
        // Watch the process so [_helperProcessAlive] can update without a
        // synchronous blocking probe.
        unawaited(_process!.exitCode.then((c) {
          _helperExitCodeObserved = c;
        }));
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HELPER_SPAWN_SUCCESS',
          'pid=${_process?.pid}',
        );
      } catch (e) {
        _lastError = 'Failed to start STT helper: $e';
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HELPER_SPAWN_FAILED',
          'exception $e',
        );
        return false;
      }
      while (!pastDeadline()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final exitCode = await _helperExitCodeIfAnyLive();
        if (exitCode != null) {
          _lastError = 'STT helper exited (code=$exitCode) before responding';
          DesktopVoicePipeline.mark(
            'DESKTOP_VOICE_HELPER_SPAWN_FAILED',
            'process_crashed exit=$exitCode',
          );
          return false;
        }
        if (await _ping(markStatus: true)) {
          _ready = true;
          break;
        }
      }
      if (!_ready) {
        _lastError = 'STT helper did not respond';
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_TIMEOUT', 'ping');
        return false;
      }
    } else {
      _ready = true;
    }

    return _configureAndWaitReady(target, deadline);
  }

  Future<bool> _restartHelper(
    DateTime deadline,
    DesktopVoiceEngineId target,
  ) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_RESTART_ATTEMPT');
    _killHelperProcess();
    _ready = false;
    _engineReady.clear();
    final ok = await _ensureHelperRunning(deadline, target);
    if (ok) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_RESTART_SUCCESS');
    } else {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_RESTART_FAILED');
    }
    return ok;
  }

  void _killHelperProcess() {
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
    _ready = false;
    _helperExitCodeObserved = null;
  }

  String? _resolveHelperExe() {
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 6; i++) {
        final candidate = File(
          '${dir.path}${Platform.pathSeparator}stt_helper'
          '${Platform.pathSeparator}counter_stt_helper.exe',
        );
        if (candidate.existsSync()) return candidate.path;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _ping({bool markStatus = false}) async {
    if (markStatus) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_REQUEST', 'ping');
    }
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/ping'))
          .timeout(const Duration(seconds: 2));
      _lastStatusHttpResult = 'ping HTTP ${r.statusCode}';
      return r.statusCode == 200;
    } catch (e) {
      _lastStatusHttpResult = 'ping error $e';
      return false;
    }
  }

  Future<bool> _configureAndWaitReady(
    DesktopVoiceEngineId engine,
    DateTime deadline,
  ) async {
    bool pastDeadline() => !DateTime.now().isBefore(deadline);

    final modelDir = modelPathFor(engine);
    final modelExistsOnDisk =
        modelDir != null && Directory(modelDir).existsSync();
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_HELPER_MODEL_CHECK',
      '${engine.helperEngineId} exists=${modelExistsOnDisk ? 'yes' : 'no'}'
      ' dir=${modelDir ?? '—'}',
    );
    if (!modelExistsOnDisk) {
      _lastError = 'Model not found: ${engine.helperEngineId}';
      _engineReady[engine.helperEngineId] = false;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HELPER_STATUS_FAILED',
        'model_missing ${engine.helperEngineId}',
      );
      return false;
    }
    try {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_REQUEST', 'config');
      await http
          .post(
            Uri.parse('$_baseUrl/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'engine': engine.helperEngineId}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    while (!pastDeadline()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final loaded = await _refreshRemoteStatus(engine);
      if (loaded) {
        _engine = engine.helperEngineId;
        _engineReady[engine.helperEngineId] = true;
        _lastError = null;
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_READY', engine.helperEngineId);
        return true;
      }
    }
    _lastError = 'STT model not loaded: ${engine.helperEngineId}';
    _engineReady[engine.helperEngineId] = false;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_TIMEOUT', 'model_ready');
    return false;
  }

  bool _parseFinalTranscribeReady(Map<String, dynamic> body) {
    if (body.containsKey('final_transcribe_ready')) {
      return body['final_transcribe_ready'] == true;
    }
    return body['ready'] == true && body['model_loaded'] == true;
  }

  Future<bool> _refreshRemoteStatus(DesktopVoiceEngineId engine) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_REQUEST', 'status');
    try {
      final r = await http
          .get(Uri.parse(_statusUrl))
          .timeout(const Duration(seconds: 2));
      _lastStatusHttpResult = 'HTTP ${r.statusCode}';
      _lastStatusBody = r.body.length > 400 ? '${r.body.substring(0, 400)}…' : r.body;
      if (r.statusCode != 200) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HELPER_STATUS_FAILED',
          '${r.statusCode}',
        );
        return false;
      }
      final body = jsonDecode(r.body);
      if (body is! Map<String, dynamic>) return false;
      final active = body['engine'] ?? body['model'];
      _helperModelLoaded = body['model_loaded'] == true;
      _helperWarmupDone = body['warmup_done'] == true;
      _finalTranscribeReady = _parseFinalTranscribeReady(body);
      final reason = body['reason_if_not_ready'];
      _reasonIfNotReady = reason is String ? reason : '';
      if (active is String && active.isNotEmpty) _engine = active;
      if (_reasonIfNotReady.isNotEmpty && !_finalTranscribeReady) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HELPER_STATUS_NOT_READY_REASON',
          _reasonIfNotReady,
        );
      }
      if (_finalTranscribeReady && active == engine.helperEngineId) {
        _engineReady[engine.helperEngineId] = true;
        if (_helperModelLoaded) {
          DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_MODEL_LOADED');
        }
        if (_helperWarmupDone) {
          DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_WARMUP_DONE');
        }
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_FINAL_READY');
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HELPER_STATUS_READY',
          engine.helperEngineId,
        );
        return true;
      }
      _engineReady[engine.helperEngineId] = false;
    } catch (e) {
      _lastStatusHttpResult = 'error $e';
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HELPER_STATUS_FAILED',
        'exception $e',
      );
    }
    return false;
  }

  Future<bool> _waitForFinalTranscribeReady(
    DesktopVoiceEngineId engine,
    DateTime deadline,
  ) async {
    while (DateTime.now().isBefore(deadline)) {
      if (await _refreshRemoteStatus(engine) && _finalTranscribeReady) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_WAITED_FOR_REAL_READY');
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return _finalTranscribeReady;
  }

  bool _isNotLoadedTranscribeError() {
    final detail = (_lastTranscribeErrorDetail ?? '').toLowerCase();
    final err = (_lastError ?? '').toLowerCase();
    return detail.contains('not loaded') || err.contains('not loaded');
  }

  Future<String?> _attemptWindowsFallbackStt(String wavPath) async {
    _fallbackSttAttempted = true;
    _fallbackSttEngine = 'windows_speech';
    DesktopVoicePipeline.mark('DESKTOP_VOICE_FALLBACK_STT_ATTEMPTED');
    final fb = await DesktopWinSpeechService.instance.transcribeWav(wavPath);
    if (fb != null && fb.trim().isNotEmpty) {
      _fallbackSttResult = 'success';
      _finalTranscriptSource = 'windows_speech';
      DesktopVoicePipeline.mark('DESKTOP_VOICE_FALLBACK_STT_SUCCESS');
      DesktopVoicePipeline.mark('DESKTOP_VOICE_FINAL_TRANSCRIPT_SOURCE', 'windows_speech');
      return fb.trim();
    }
    _fallbackSttResult = 'failed';
    DesktopVoicePipeline.mark('DESKTOP_VOICE_FALLBACK_STT_FAILED');
    return null;
  }

  Future<List<InputDevice>> listInputDevices() =>
      _capture.listInputDevices();

  /// Spawns the helper HTTP server if needed (for CPAL `/capture/*`) without
  /// waiting for Parakeet model load — model prewarm stays background.
  Future<bool> ensureHelperHttpReady({
    Duration maxWait = const Duration(seconds: 4),
  }) async {
    final engine = resolveProductionEngine();
    if (engine == DesktopVoiceEngineId.windowsSpeech) return true;
    if (await _ping()) {
      _ready = true;
      return true;
    }
    final deadline = DateTime.now().add(maxWait);
    final ok = await _ensureHelperRunning(deadline, engine);
    return ok || await _ping();
  }

  Future<bool> startListening({String? deviceId, String? deviceLabel}) async {
    // CPAL capture lives in the helper — bring HTTP up first (do not wait on
    // model load). Mic UI must still appear quickly; spawn is local.
    final engine = resolveProductionEngine();
    if (engine != DesktopVoiceEngineId.windowsSpeech) {
      await ensureHelperHttpReady();
      prewarmRecognizerInBackground();
    }

    final ok = await _capture.start(deviceId: deviceId, deviceLabel: deviceLabel);
    if (!ok) {
      _lastError = _capture.lastError;
      return false;
    }
    DesktopVoicePipeline.mark('DESKTOP_VOICE_LOCAL_AUDIO_CAPTURE_STARTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_BUFFER_STARTED');
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_CAPTURE_BACKEND_ACTIVE',
      _capture.captureBackend,
    );

    if (Platform.environment['COUNTER_DESKTOP_VOICE_SMOKE'] == '1') {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          _capture.injectSmokeLevelBurst();
        }),
      );
    }

    if (engine != DesktopVoiceEngineId.windowsSpeech) {
      // Mid-listen partials for command STT so stop can surface a warm
      // partial_hint as the first candidate (<500ms when already cached).
      if (_capture.captureBackend.startsWith('cpal')) {
        _capture.attachCpalPartialPoll((bytes) {
          if (_finalTranscribeReady) unawaited(_sendPartialAudio(bytes));
        });
      } else {
        _capture.attachPartialTimer((bytes) {
          if (_finalTranscribeReady) unawaited(_sendPartialAudio(bytes));
        });
      }
    }
    return true;
  }

  Future<void> _sendPartialAudio(List<int> bytes) async {
    if (bytes.length < 48000 || !_ready) return;
    final sessionId = _activeVoiceSessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    final rms = pcm16RmsLevel(bytes);
    if (rms < 0.012) return;
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/transcribe/partial_audio'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_base64': base64Encode(bytes),
              'session_id': sessionId,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Instant first-candidate read from mid-listen cache (no full WAV wait).
  Future<String?> _fetchLastPartialHint({bool requireSessionMatch = true}) async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/transcribe/last_partial'))
          .timeout(const Duration(milliseconds: 400));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body);
      if (body is! Map) return null;
      final respSessionId = (body['session_id'] as String?)?.trim();
      if (requireSessionMatch &&
          !DesktopVoiceSessionRegistry.acceptForActive(
            resultSessionId: respSessionId ?? _activeVoiceSessionId,
            source: 'last_partial',
          )) {
        return null;
      }
      final text = (body['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return null;
      final age = (body['age_ms'] as num?)?.toInt();
      // Stale partial (>4s) is ignored — prefer fresh mid-listen.
      if (age != null && age > 4000) return null;
      return text;
    } catch (_) {
      return null;
    }
  }

  void _emitFirstCandidate(String text, String engineId) {
    if (text.trim().isEmpty) return;
    if (_activeVoiceSessionId != null &&
        !DesktopVoiceSessionRegistry.acceptForActive(
          resultSessionId: _activeVoiceSessionId,
          source: 'first_candidate',
        )) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_CROSS_SESSION_WRITE');
      return;
    }
    final trimmed = DesktopVoiceTranscriptMerge.dedupeCommaSegments(text.trim());
    _candidateText = trimmed;
    DesktopVoicePipeline.mark('candidate_session_id', _activeVoiceSessionId ?? '—');
    final eval = evaluateCommandCandidate?.call(trimmed);
    _candidateParseStatus = eval?.parseStatus ?? 'not_evaluated';
    _candidateUseful = eval?.useful ?? false;
    DesktopVoicePipeline.mark('candidate_text', trimmed);
    DesktopVoicePipeline.mark(
      'candidate_parse_status',
      _candidateParseStatus ?? '—',
    );
    DesktopVoicePipeline.mark(
      'candidate_useful',
      _candidateUseful ? 'yes' : 'no',
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_USEFUL_CANDIDATE_METRIC_ENFORCED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_USEFUL_CANDIDATE_METRIC_ADDED');

    if (!_candidateUseful) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_BAD_PARTIAL_NOT_COUNTED_AS_SUCCESS',
        trimmed,
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_FAKE_LATENCY_PASS');
      return;
    }

    if (_tFirstCandidateVisible != null) return;
    _tFirstCandidateVisible = DateTime.now();
    _candidateVisibleToUser = true;
    _engineUsedForFirstCandidate = engineId;
    DesktopVoicePipeline.mark('candidate_visible_to_user', 'yes');
    DesktopVoicePipeline.mark(
      't_first_candidate_visible',
      '${_tFirstCandidateVisible!.millisecondsSinceEpoch}',
    );
    DesktopVoicePipeline.mark('engine_used_for_first_candidate', engineId);
    if (_tRecordingStopped != null) {
      _stopToFirstCandidateMs = _tFirstCandidateVisible!
          .difference(_tRecordingStopped!)
          .inMilliseconds;
      _stopToUsefulCandidateMs = _stopToFirstCandidateMs;
      DesktopVoicePipeline.mark(
        'stop_to_first_candidate_ms',
        '$_stopToFirstCandidateMs',
      );
      DesktopVoicePipeline.mark(
        'stop_to_useful_candidate_ms',
        '$_stopToUsefulCandidateMs',
      );
      final ms = _stopToUsefulCandidateMs ?? 9999;
      if (_candidateUseful && ms < 500) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_STOP_TO_FIRST_CANDIDATE_UNDER_500MS',
        );
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS',
        );
        DesktopVoicePipeline.mark('useful_latency_pass', 'yes');
      } else if (_candidateUseful) {
        DesktopVoicePipeline.mark('useful_latency_pass', 'no');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_FAKE_LATENCY_PASS');
      }
    }
    onFirstCandidate?.call(trimmed, engineId);
  }

  /// Zero-await stop path: emit mid-recording partial already validated for session.
  void _tryEmitCachedUsefulCandidateOnStop() {
    final cached = _sessionBestPartial?.trim();
    if (cached == null || cached.isEmpty) return;
    if (!_sessionBestPartialUseful) {
      final eval = evaluateCommandCandidate?.call(cached);
      _sessionBestPartialUseful = eval?.useful ?? false;
    }
    if (!_sessionBestPartialUseful) return;
    if (_tFirstCandidateVisible != null) return;
    _partialText = cached;
    _emitFirstCandidate(cached, resolveProductionEngine().helperEngineId);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STOP_USED_CACHED_SESSION_PARTIAL');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_IMMEDIATE_STOP_CANDIDATE');
  }

  Future<DesktopSttTranscript?> stopAndTranscribe() async {
    _restartAttemptedThisTranscribe = false;
    // Reset stale transcribe-side diagnostics before this attempt.
    _lastTranscribeHttpResult = null;
    _lastTranscribeErrorKind = null;
    _lastTranscribeErrorDetail = null;
    _lastTranscribeResponseBodyTail = '';
    _transcribeCalled = false;
    _pendingWavAfterStop = false;
    _helperReadyAfterRecording = false;
    _delayedTranscribeCalled = false;
    _delayedTranscribeResult = null;
    _failureReason = null;
    _partialText = null;
    _finalText = null;
    _usedPartialAsFinal = false;
    _stopReturnReason = null;
    _finalInferenceLatencyMs = null;
    _finalTranscriptSource = null;
    _tRecordingStopped = null;
    _tWavWritten = null;
    _tTranscribeRequest = null;
    _tFirstCandidateVisible = null;
    _tFinalTranscriptReady = null;
    _stopToFirstCandidateMs = null;
    _stopToFinalTextMs = null;
    _audioDurationMsUsedForInference = null;
    _sttGainMode = 'none';
    _sttGainDb = 0;
    _sttGainRejectedReason = null;
    _sttTranscriptWithoutGain = null;
    _sttTranscriptWithGain = null;
    _engineUsedForFirstCandidate = null;
    _engineUsedForFinalText = null;
    _stopToPendingConfirmationMs = null;
    _candidateText = null;
    _candidateParseStatus = null;
    _candidateUseful = false;
    _candidateVisibleToUser = false;
    _stopToUsefulCandidateMs = null;

    // Mark stop + grab mid-listen partial immediately (do not wait for WAV finalize).
    _tRecordingStopped = DateTime.now();
    DesktopVoicePipeline.mark(
      't_recording_stopped',
      '${_tRecordingStopped!.millisecondsSinceEpoch}',
    );
    _tryEmitCachedUsefulCandidateOnStop();
    final earlyPartialFuture = _fetchLastPartialHint(requireSessionMatch: true);
    final captureFuture = _capture.stopAndSaveWav();

    final earlyPartial = await earlyPartialFuture;
    if (earlyPartial != null && earlyPartial.isNotEmpty) {
      _partialText = DesktopVoiceTranscriptMerge.applyPartial(
        previous: _sessionBestPartial,
        partial: earlyPartial,
      );
      _sessionBestPartial = _partialText;
      _emitFirstCandidate(
        _partialText!,
        resolveProductionEngine().helperEngineId,
      );
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_FIRST_CANDIDATE_FROM_MID_LISTEN_PARTIAL',
        earlyPartial,
      );
    }

    final captureOrNull = await captureFuture;
    if (captureOrNull == null) {
      _lastError = _capture.lastError ?? 'Not enough audio';
      _failureReason = 'not_enough_audio';
      await _updateDiagnostics(error: _lastError);
      return null;
    }
    var capture = captureOrNull;
    _tWavWritten = DateTime.now();
    DesktopVoicePipeline.mark(
      't_wav_written',
      '${_tWavWritten!.millisecondsSinceEpoch}',
    );

    // Command endpointing: trim idle silence with start-trim guard.
    var pcmForStt =
        DesktopVoiceCommandEndpoint.trimSilencePcm16(capture.pcmBytes);
    if (pcmForStt.length != capture.pcmBytes.length) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_COMMAND_ENDPOINT_TRIM',
        '${capture.pcmBytes.length}->${pcmForStt.length}',
      );
    }
    // Leading silence pad for STT context (raw WAV unchanged).
    final beforePad = pcmForStt.length;
    pcmForStt = DesktopVoiceCaptureReadyPolicy.prependLeadingSilencePcm16(
      pcmForStt,
    );
    if (pcmForStt.length != beforePad) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_STT_LEADING_PAD_MS',
        '${DesktopVoiceCaptureReadyPolicy.sttLeadingPadMs}',
      );
      DesktopVoicePipeline.mark(
        DesktopVoiceCaptureReadyPolicy.markerLeadingAudioPreserved,
      );
    }
    if (pcmForStt.length != capture.pcmBytes.length) {
      capture = DesktopVoiceCaptureResult(
        wavPath: capture.wavPath,
        pcmBytes: pcmForStt,
        sampleRate: capture.sampleRate,
        channels: capture.channels,
        durationMs: pcm16DurationMs(pcmForStt),
        maxAmplitude: capture.maxAmplitude,
        rmsAmplitude: capture.rmsAmplitude,
        audioLevelSeen: capture.audioLevelSeen,
        deviceLabel: capture.deviceLabel,
        deviceId: capture.deviceId,
        rawWavPath: capture.rawWavPath,
        captureBackend: capture.captureBackend,
        captureApi: capture.captureApi,
        rawCaptureFormat: capture.rawCaptureFormat,
        rawSampleRate: capture.rawSampleRate,
        rawChannels: capture.rawChannels,
        rawDurationMs: capture.rawDurationMs,
        rawRms: capture.rawRms,
        rawPeak: capture.rawPeak,
        processedWavRms: capture.processedWavRms,
        processedWavPeak: capture.processedWavPeak,
        sessionVolume: capture.sessionVolume,
        endpointVolume: capture.endpointVolume,
        resamplerUsed: capture.resamplerUsed,
        downmixUsed: capture.downmixUsed,
      );
    }
    _audioDurationMsUsedForInference = pcm16DurationMs(pcmForStt);

    // Whisper-tiny STT-only processing (raw WAV untouched). Parakeet gain remains off.
    var sttPcm = pcmForStt;
    final processing = applyProductionWhisperSttProcessing(pcmForStt);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_LIVE_QUIET_AUDIO_BENCHMARK_RUN');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_WHISPER_GAIN_BENCHMARK_RUN');
    if (processing.compressorEnabled || processing.agcEnabled) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_AGC_BENCHMARK_RUN');
    }
    DesktopVoicePipeline.mark('stt_processing_variant', processing.variant.name);
    DesktopVoicePipeline.mark('input_rms', processing.inputRms.toStringAsFixed(4));
    DesktopVoicePipeline.mark('input_peak', processing.inputPeak.toStringAsFixed(4));
    DesktopVoicePipeline.mark('output_rms', processing.outputRms.toStringAsFixed(4));
    DesktopVoicePipeline.mark('output_peak', processing.outputPeak.toStringAsFixed(4));
    DesktopVoicePipeline.mark('gain_db', processing.gainDb.toStringAsFixed(2));
    DesktopVoicePipeline.mark(
      'compressor_enabled',
      processing.compressorEnabled ? 'yes' : 'no',
    );
    DesktopVoicePipeline.mark(
      'agc_enabled',
      processing.agcEnabled ? 'yes' : 'no',
    );
    DesktopVoicePipeline.mark(
      'clipped_samples',
      '${processing.clippedSamples}',
    );
    if (processing.applied) {
      sttPcm = processing.pcm;
      DesktopVoicePipeline.mark(
        'selected_processing_variant',
        processing.variant.name,
      );
      DesktopVoicePipeline.mark(
        'selected_reason',
        'offline_whisper_bench_improved_transcript',
      );
      capture = DesktopVoiceCaptureResult(
        wavPath: capture.wavPath,
        pcmBytes: sttPcm,
        sampleRate: capture.sampleRate,
        channels: capture.channels,
        durationMs: pcm16DurationMs(sttPcm),
        maxAmplitude: capture.maxAmplitude,
        rmsAmplitude: processing.outputRms,
        audioLevelSeen: capture.audioLevelSeen,
        deviceLabel: capture.deviceLabel,
        deviceId: capture.deviceId,
        rawWavPath: capture.rawWavPath,
        captureBackend: capture.captureBackend,
        captureApi: capture.captureApi,
        rawCaptureFormat: capture.rawCaptureFormat,
        rawSampleRate: capture.rawSampleRate,
        rawChannels: capture.rawChannels,
        rawDurationMs: capture.rawDurationMs,
        rawRms: capture.rawRms,
        rawPeak: capture.rawPeak,
        processedWavRms: processing.outputRms,
        processedWavPeak: processing.outputPeak,
        sessionVolume: capture.sessionVolume,
        endpointVolume: capture.endpointVolume,
        resamplerUsed: capture.resamplerUsed,
        downmixUsed: capture.downmixUsed,
      );
    } else {
      DesktopVoicePipeline.mark('selected_processing_variant', 'current');
      DesktopVoicePipeline.mark(
        'selected_reason',
        DesktopVoiceSttProcessingPolicy.productionSelectionReason,
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_HARMFUL_PEAK_NORMALIZATION');
    }

    // Calibrated RMS gain is OFF for Parakeet after offline replay proved
    // identical transcript. Whisper path uses [applyProductionWhisperSttProcessing].
    _sttGainMode = processing.applied ? processing.variant.name : 'rejected';
    _sttGainRejectedReason = processing.applied
        ? null
        : DesktopVoiceSttGain.whisperGainRejectedReason;
    _rawRmsBeforeGain = processing.inputRms;
    _rawPeakBeforeGain = processing.inputPeak;
    _processedRmsAfterGain = processing.outputRms;
    _processedPeakAfterGain = processing.outputPeak;
    _clippedSamplesAfterGain = processing.clippedSamples;
    _sttGainDb = processing.gainDb;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_GAIN_BENCHMARK_RUN');
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_STT_GAIN_REJECTED_REASON',
      _sttGainRejectedReason ?? '—',
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_HARMFUL_PEAK_NORMALIZATION');

    _logCaptureInstalledProof(capture);

    DesktopVoicePipeline.mark('DESKTOP_VOICE_RECORDING_FINISHED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_AUDIO_SAMPLE_SAVED', capture.wavPath);
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_AUDIO_SAMPLE_READY_FOR_STT',
      '${capture.pcmBytes.length} bytes · ${capture.durationMs}ms',
    );
    for (final line in capture.captureDiagLines()) {
      DesktopVoiceLog.instance.mark('capture', line);
    }

    _lastCaptureBytes = capture.pcmBytes.length;

    final wavExists = File(capture.wavPath).existsSync();
    final hasValidPending = DesktopVoiceDelayedTranscribe.hasValidPendingWav(
      wavExists: wavExists,
      pcmByteLength: capture.pcmBytes.length,
      audioLevelSeen: capture.audioLevelSeen &&
          capture.maxAmplitude >= _levelThreshold,
    );

    if (!hasValidPending) {
      _lastError = 'Not enough audio';
      _failureReason = 'not_enough_audio';
      await _updateDiagnostics(capture: capture, error: _lastError);
      return null;
    }

    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_USING_SAVED_WAV', capture.wavPath);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_HTTP_REQUEST_STARTED_AFTER_RECORDING');

    if (_transcribeGlossary != null) {
      final glossary = _transcribeGlossary!;
      _transcribeGlossary = null;
      final t0 = DateTime.now();
      final pipeline = await DesktopSttOrchestrator.transcribeCommand(
        capture: capture,
        glossary: glossary,
      );
      final latencyMs = DateTime.now().difference(t0).inMilliseconds;
      if (pipeline == null) {
        _lastError = _lastError ?? 'Recognition pipeline failed';
        _failureReason = 'pipeline_failed';
        await _updateDiagnostics(capture: capture, error: _lastError);
        DesktopVoicePipeline.mark('DESKTOP_VOICE_RECOGNIZER_FAILED_NO_RECORD_CHANGE');
        return null;
      }
      _lastError = null;
      _finalText = pipeline.finalCommandText;
      _finalTranscriptSource = pipeline.finalCommandSource;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIPT_TEXT',
        pipeline.finalCommandText,
      );
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_FINAL_TRANSCRIPT_SOURCE',
        pipeline.finalCommandSource,
      );
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIBE_SUCCESS',
        pipeline.finalCommandText,
      );
      await _updateDiagnostics(
        capture: capture,
        engine: DesktopVoiceEngineId.tryParse(pipeline.sttEngine) ??
            resolveProductionEngine(),
        transcript: pipeline.finalCommandText,
        latencyMs: latencyMs,
      );
      return DesktopSttTranscript(
        text: pipeline.finalCommandText,
        durationSec: capture.durationMs / 1000.0,
        engine: pipeline.sttEngine,
        rawModelText: pipeline.rawModelText,
        postprocessedText: pipeline.postprocessedText,
        finalCommandText: pipeline.finalCommandText,
        finalCommandSource: pipeline.finalCommandSource,
        sttEngineLatencyMs: pipeline.sttEngineLatencyMs,
      );
    }

    final engine = resolveProductionEngine();
    final t0 = DateTime.now();
    String? text;
    String? error;

    if (engine == DesktopVoiceEngineId.windowsSpeech) {
      text = await DesktopWinSpeechService.instance.transcribeWav(capture.wavPath);
      error = DesktopWinSpeechService.instance.lastError;
      if (text != null && text.trim().isNotEmpty) {
        _finalTranscriptSource = 'windows_speech';
        _finalText = text.trim();
      }
    } else {
      _primarySttEngine = engine.helperEngineId;
      _finalTranscriptSource = engine.helperEngineId;
      _fallbackSttAttempted = false;
      _fallbackSttEngine = null;
      _fallbackSttResult = null;
      _primarySttResult = null;

      final helperReadyAtStop = _ready && _finalTranscribeReady;
      _pendingWavAfterStop =
          DesktopVoiceDelayedTranscribe.shouldQueuePendingWav(
        hasValidPendingWav: hasValidPending,
        helperFinalReadyAtStop: helperReadyAtStop,
      );
      if (_pendingWavAfterStop) {
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_PENDING_WAV_QUEUED_WHILE_HELPER_LOADING',
          capture.wavPath,
        );
      }

      final waitBudget = DesktopVoiceDelayedTranscribe.waitBudget(
        pendingWavQueued: _pendingWavAfterStop,
      );
      final deadline = DateTime.now().add(waitBudget);

      // Keep waiting through cold-start; never abandon a valid saved WAV early.
      final started = await ensureStarted(
        engine: engine,
        maxWait: waitBudget,
        allowRestart: true,
      );
      final ready = started
          ? await _waitForFinalTranscribeReady(engine, deadline)
          : false;
      _helperReadyAfterRecording = ready && _finalTranscribeReady;
      if (_helperReadyAfterRecording) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_READY_AFTER_RECORDING');
      }

      if (!_helperReadyAfterRecording) {
        _failureReason = started
            ? 'helper_not_final_ready_after_wait'
            : 'helper_ensure_started_failed';
        // Valid WAV exists but helper never became ready within cold-start.
        await _noteSttFriendlyFailure(
          capture: capture,
          stage: _pendingWavAfterStop
              ? 'pending_wav_helper_cold_start_timeout'
              : 'ensure_started',
          endpoint: '/status',
        );
        return null;
      }

      final delayedPath = _pendingWavAfterStop;
      if (delayedPath) {
        _delayedTranscribeCalled = true;
        DesktopVoicePipeline.mark('DESKTOP_VOICE_DELAYED_TRANSCRIBE_CALLED');
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_REPLAYING_SAVED_WAV_AFTER_READY',
          capture.wavPath,
        );
      }

      var r = await _transcribePcm(engine, pcmForStt);
      if (r == null && _isNotLoadedTranscribeError()) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_PARAEET_NOT_LOADED_RETRY');
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_READINESS_RACE');
        await _waitForFinalTranscribeReady(engine, deadline);
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_REPLAYING_SAVED_WAV_AFTER_READY',
          capture.wavPath,
        );
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_USING_SAVED_WAV', capture.wavPath);
        if (delayedPath || _pendingWavAfterStop) {
          _delayedTranscribeCalled = true;
          DesktopVoicePipeline.mark('DESKTOP_VOICE_DELAYED_TRANSCRIBE_CALLED');
        }
        r = await _transcribePcm(engine, pcmForStt);
        if (r != null) {
          DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_RETRY_SUCCESS');
        } else {
          DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_RETRY_FAILED');
        }
      }

      if (r != null) {
        _primarySttResult = 'success';
        text = r.text;
        error = null;
        if (delayedPath) {
          _delayedTranscribeResult = 'success';
          DesktopVoicePipeline.mark('DESKTOP_VOICE_DELAYED_TRANSCRIBE_SUCCESS');
          DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_FALSE_RECOGNIZER_UNAVAILABLE');
        }
      } else {
        _primarySttResult = 'failed';
        if (delayedPath) {
          _delayedTranscribeResult = 'failed';
        }
        final fb = await _attemptWindowsFallbackStt(capture.wavPath);
        if (fb != null) {
          text = fb;
          error = null;
          if (delayedPath) {
            _delayedTranscribeResult = 'fallback_success';
            DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_FALSE_RECOGNIZER_UNAVAILABLE');
          }
        } else {
          error = _lastError ?? DesktopWinSpeechService.instance.lastError;
          if (DesktopVoiceDelayedTranscribe.suppressFalseRecognizerUnavailable(
                hasValidPendingWav: hasValidPending,
                helperReadyAfterRecording: _helperReadyAfterRecording,
              ) &&
              delayedPath) {
            // Helper was ready and WAV valid — surface empty/failed transcript,
            // never a false cold-start "recognizer unavailable".
            DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_FALSE_RECOGNIZER_UNAVAILABLE');
            _failureReason = 'transcribe_failed_after_ready';
          }
        }
      }
    }

    final latencyMs = DateTime.now().difference(t0).inMilliseconds;

    if (text == null || text.trim().isEmpty) {
      _lastError = error ?? 'Empty transcript';
      _lastTranscribeErrorKind ??= 'empty_transcript';
      _lastTranscribeErrorDetail ??= 'stt_empty_transcript';
      _failureReason ??= 'empty_transcript';
      await _updateDiagnostics(capture: capture, error: _lastError);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_EMPTY', _lastTranscribeResponseBodyTail);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_RECOGNIZER_FAILED_NO_RECORD_CHANGE');
      return null;
    }

    _lastError = null;
    _failureReason = null;
    _finalText = text.trim();
    _engineUsedForFinalText = engine.helperEngineId;
    DesktopVoicePipeline.mark('engine_used_for_final_text', engine.helperEngineId);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_TEXT', text.trim());
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_FINAL_TRANSCRIPT_SOURCE',
      _finalTranscriptSource ?? engine.helperEngineId,
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_SUCCESS', text.trim());
    _emitFirstCandidate(text.trim(), engine.helperEngineId);
    _logLatencyBlockerIfNeeded(capture);
    await _updateDiagnostics(
      capture: capture,
      engine: engine,
      transcript: text.trim(),
      latencyMs: latencyMs,
    );
    return DesktopSttTranscript(
      text: text.trim(),
      durationSec: capture.durationMs / 1000.0,
      engine: engine.helperEngineId,
    );
  }

  void _logLatencyBlockerIfNeeded(DesktopVoiceCaptureResult capture) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_USEFUL_CANDIDATE_METRIC_ENFORCED');
    if (_candidateUseful &&
        (_stopToUsefulCandidateMs ?? 9999) <= 500) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS',
      );
      return;
    }
    final inference = _finalInferenceLatencyMs ?? 0;
    final blocker =
        'no_useful_candidate;whisper_final_inference_ms=$inference;'
        'capture_rms=${capture.rawRms.toStringAsFixed(4)};'
        'partial=${_partialText ?? '—'}';
    DesktopVoicePipeline.mark('DESKTOP_VOICE_LATENCY_ROOT_CAUSE_LOGGED', blocker);
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_STOP_TO_USEFUL_CANDIDATE_UNDER_500MS_OR_BLOCKER',
      blocker,
    );
  }

  void _logCaptureInstalledProof(DesktopVoiceCaptureResult capture) {
    final rawPath = capture.rawWavPath;
    final rawExists =
        rawPath != null && rawPath.isNotEmpty && File(rawPath).existsSync();
    final processedExists = File(capture.wavPath).existsSync();
    if (rawExists) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_RAW_CAPTURE_WAV_SAVED_INSTALLED',
        rawPath,
      );
    }
    if (processedExists) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_PROCESSED_STT_WAV_SAVED_INSTALLED',
        capture.wavPath,
      );
    }
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_NATIVE_CAPTURE_DIAGNOSTICS_LOGGED',
      'raw_sr=${capture.rawSampleRate} raw_ch=${capture.rawChannels} '
      'stt_sr=${capture.sampleRate} stt_ch=${capture.channels} '
      'raw_exists=${rawExists ? 'yes' : 'no'}',
    );
  }

  Future<void> _noteSttFriendlyFailure({
    DesktopVoiceCaptureResult? capture,
    required String stage,
    required String endpoint,
  }) async {
    final err = (_lastError ?? '').trim();
    _failureReason ??= stage;
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_RAW_EXCEPTION_SUPPRESSED',
      err.isEmpty ? stage : err,
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_REQUEST_FAILED_FRIENDLY', stage);
    DesktopVoiceLog.instance.mark('helper_path', helperPath ?? '');
    DesktopVoiceLog.instance.mark('helper_pid', '${helperPid ?? ''}');
    DesktopVoiceLog.instance.mark('endpoint', endpoint);
    DesktopVoiceLog.instance.mark('stage', stage);
    DesktopVoiceLog.instance.mark(
      'helper_stderr_tail',
      _helperStderrTailJoined,
    );
    await _updateDiagnostics(capture: capture, error: _lastError);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_RECOGNIZER_FAILED_NO_RECORD_CHANGE');
  }

  Future<DesktopSttTranscript?> _transcribePcm(
    DesktopVoiceEngineId engine,
    List<int> pcm,
  ) async {
    const endpoint = _transcribeStopEndpoint;
    _lastTranscribeHttpResult = null;
    _lastTranscribeErrorKind = null;
    _lastTranscribeErrorDetail = null;
    _lastTranscribeResponseBodyTail = '';
    _transcribeCalled = true;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_REQUEST', endpoint);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_HTTP_REQUEST_STARTED', endpoint);
    final exitBefore = await _helperExitCodeIfAnyLive();
    final aliveBefore = exitBefore == null;
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_HELPER_HEALTH_CHECK',
      'before alive=$aliveBefore pid=${helperPid ?? ''} exit=$exitBefore',
    );

    DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_CALLED', endpoint);
    _transcribeCalled = true;
    _tTranscribeRequest = DateTime.now();
    DesktopVoicePipeline.mark(
      't_transcribe_request',
      '${_tTranscribeRequest!.millisecondsSinceEpoch}',
    );
    // GOLOS parity: no STT peak normalization — same-WAV replay proved peak norm
    // degrades Parakeet output (Solvan→Solvent on SCW fixture).
    try {
      final r = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_base64': base64Encode(pcm),
              'session_id': _activeVoiceSessionId,
            }),
          )
          .timeout(kVoiceProcessingMaxWait);
      _lastTranscribeHttpResult = 'HTTP ${r.statusCode}';
      final bodyTail = r.body.length > 200
          ? r.body.substring(r.body.length - 200)
          : r.body;
      _lastTranscribeResponseBodyTail = bodyTail;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIBE_RESPONSE',
        'HTTP ${r.statusCode} tail=$bodyTail',
      );
      if (r.statusCode != 200) {
        _lastError = 'STT HTTP ${r.statusCode}';
        _lastTranscribeErrorKind = 'http_status';
        _lastTranscribeErrorDetail = '${r.statusCode} ${r.body}';
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_TRANSCRIBE_FAILED',
          '$endpoint HTTP ${r.statusCode}',
        );
        await _handleSttHttpFailure(
          endpoint: endpoint,
          stage: 'http_status',
          aliveBefore: aliveBefore,
        );
        return null;
      }
      final body = jsonDecode(r.body);
      if (body is! Map<String, dynamic>) {
        _lastError = 'Invalid STT response';
        _lastTranscribeErrorKind = 'invalid_response';
        _lastTranscribeErrorDetail = 'non-map body';
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_TRANSCRIBE_FAILED',
          '$endpoint invalid_response',
        );
        await _handleSttHttpFailure(
          endpoint: endpoint,
          stage: 'invalid_json',
          aliveBefore: aliveBefore,
        );
        return null;
      }
      final err = body['error'];
      if (err is String && err.isNotEmpty) {
        _lastError = err;
        _lastTranscribeErrorKind = 'helper_error';
        _lastTranscribeErrorDetail = err;
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_TRANSCRIBE_FAILED',
          '$endpoint helper_error $err',
        );
        await _handleSttHttpFailure(
          endpoint: endpoint,
          stage: 'helper_error',
          aliveBefore: aliveBefore,
        );
        return null;
      }
      final text = (body['text'] as String?)?.trim() ?? '';
      final partialHint = (body['partial_hint'] as String?)?.trim() ?? '';
      final finalTextField = (body['final_text'] as String?)?.trim();
      final usedPartial = body['used_partial_as_final'] == true;
      final stopReason = (body['stop_return_reason'] as String?)?.trim() ?? '';
      final inferenceLatencyMs = (body['final_inference_latency_ms'] as num?)?.toInt();

      _partialText = partialHint.isEmpty ? null : partialHint;
      var authoritativeRaw = (finalTextField ?? text).trim();
      authoritativeRaw = DesktopVoiceTranscriptMerge.applyFinal(
        partial: _partialText,
        finalText: authoritativeRaw,
      );
      authoritativeRaw =
          DesktopVoiceTranscriptMerge.dedupeCommaSegments(authoritativeRaw);
      DesktopVoicePipeline.mark(
        DesktopVoiceTranscriptMerge.markerFinalReplacesPartial,
      );
      DesktopVoicePipeline.mark(
        DesktopVoiceTranscriptMerge.markerNoConcat,
      );
      _finalText = authoritativeRaw.isEmpty ? null : authoritativeRaw;
      _usedPartialAsFinal = usedPartial;
      _stopReturnReason = stopReason.isEmpty ? null : stopReason;
      _finalInferenceLatencyMs = inferenceLatencyMs;

      if (usedPartial) {
        _finalTranscriptSource = 'partial_fallback';
        DesktopVoicePipeline.mark('DESKTOP_VOICE_PARTIAL_FALLBACK_USED');
      } else {
        _finalTranscriptSource = resolveProductionEngine().helperEngineId;
        DesktopVoicePipeline.mark('DESKTOP_VOICE_PARTIAL_NOT_USED_AS_FINAL');
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STOP_FINAL_INFERENCE_USED');
      DesktopVoicePipeline.mark(
        'final_transcript_source',
        _finalTranscriptSource ?? '—',
      );
      if (partialHint.isNotEmpty &&
          DesktopVoiceSessionRegistry.acceptForActive(
            resultSessionId: _activeVoiceSessionId,
            source: 'partial_hint',
          )) {
        DesktopVoicePipeline.mark('partial_text', partialHint);
        if (!_candidateUseful) {
          _emitFirstCandidate(
            partialHint,
            resolveProductionEngine().helperEngineId,
          );
        }
      }
      if (_finalText != null) {
        DesktopVoicePipeline.mark('final_text', _finalText!);
      }
      if (stopReason.isNotEmpty) {
        DesktopVoicePipeline.mark('stop_return_reason', stopReason);
      }

      final authoritativeText = _finalText ?? authoritativeRaw;
      if (authoritativeText.isEmpty) {
        _lastError = 'Empty transcript';
        _lastTranscribeErrorKind = 'empty_transcript';
        _lastTranscribeErrorDetail = '200 OK but text=""';
        DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_EMPTY', _lastTranscribeResponseBodyTail);
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_TRANSCRIBE_FAILED',
          '$endpoint empty_transcript',
        );
        await _handleSttHttpFailure(
          endpoint: endpoint,
          stage: 'empty_transcript',
          aliveBefore: aliveBefore,
        );
        return null;
      }
      _tFinalTranscriptReady = DateTime.now();
      _engineUsedForFinalText = resolveProductionEngine().helperEngineId;
      DesktopVoicePipeline.mark(
        't_final_transcript_ready',
        '${_tFinalTranscriptReady!.millisecondsSinceEpoch}',
      );
      DesktopVoicePipeline.mark(
        'engine_used_for_final_text',
        _engineUsedForFinalText!,
      );
      if (!_candidateUseful || _candidateText != authoritativeText) {
        _emitFirstCandidate(
          authoritativeText,
          resolveProductionEngine().helperEngineId,
        );
      }
      if (_tRecordingStopped != null && _tFinalTranscriptReady != null) {
        _stopToFinalTextMs = _tFinalTranscriptReady!
            .difference(_tRecordingStopped!)
            .inMilliseconds;
        DesktopVoicePipeline.mark(
          'stop_to_final_text_ms',
          '$_stopToFinalTextMs',
        );
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_LATENCY_TRACE_WRITTEN');
      if ((_finalInferenceLatencyMs ?? 9999) < 1500) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_FINAL_INFERENCE_LATENCY_REDUCED');
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_LONG_BLOCKING_RECOGNITION');
      final duration = (body['duration'] as num?)?.toDouble() ?? 0;
      // Success marker is also emitted by stopAndTranscribe for end-to-end
      // tracing; repeat here so a single _transcribePcm call is self-contained.
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_TEXT', authoritativeText);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_SUCCESS', authoritativeText);
      return DesktopSttTranscript(
        text: authoritativeText,
        durationSec: duration,
        engine: engine.helperEngineId,
        partialHint: partialHint.isEmpty ? null : partialHint,
        finalTranscriptSource: _finalTranscriptSource,
        usedPartialAsFinal: usedPartial,
        stopReturnReason: stopReason.isEmpty ? null : stopReason,
        finalInferenceLatencyMs: inferenceLatencyMs,
      );
    } on TimeoutException {
      _lastError = 'STT HTTP timeout';
      _lastTranscribeErrorKind = 'transcribe_timeout';
      _lastTranscribeErrorDetail = endpoint;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_HTTP_TIMEOUT', endpoint);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIBE_FAILED', '$endpoint timeout');
      await _handleSttHttpFailure(
        endpoint: endpoint,
        stage: 'timeout',
        aliveBefore: aliveBefore,
      );
      return null;
    } on http.ClientException catch (e) {
      final msg = e.message;
      if (msg.contains('Connection closed before full header')) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_HTTP_CONNECTION_CLOSED', endpoint);
      }
      _lastError = msg;
      _lastTranscribeErrorKind = 'transcribe_connection_closed';
      _lastTranscribeErrorDetail = msg;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIBE_FAILED',
        '$endpoint client_exception $msg',
      );
      await _handleSttHttpFailure(
        endpoint: endpoint,
        stage: 'client_exception',
        aliveBefore: aliveBefore,
        exitCode: await _helperExitCodeIfAnyLive(),
      );
      return null;
    } on SocketException catch (e) {
      _lastError = e.message;
      _lastTranscribeErrorKind = 'transcribe_connection_closed';
      _lastTranscribeErrorDetail = e.message;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_HELPER_UNAVAILABLE', endpoint);
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIBE_FAILED',
        '$endpoint socket_exception ${e.message}',
      );
      await _handleSttHttpFailure(
        endpoint: endpoint,
        stage: 'socket',
        aliveBefore: aliveBefore,
      );
      return null;
    } on HttpException catch (e) {
      _lastError = e.message;
      _lastTranscribeErrorKind = 'http_exception';
      _lastTranscribeErrorDetail = e.message;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIBE_FAILED',
        '$endpoint http_exception ${e.message}',
      );
      await _handleSttHttpFailure(
        endpoint: endpoint,
        stage: 'http_exception',
        aliveBefore: aliveBefore,
      );
      return null;
    } on FormatException catch (e) {
      _lastError = e.message;
      _lastTranscribeErrorKind = 'invalid_response';
      _lastTranscribeErrorDetail = e.message;
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIBE_FAILED',
        '$endpoint format_exception ${e.message}',
      );
      await _handleSttHttpFailure(
        endpoint: endpoint,
        stage: 'format',
        aliveBefore: aliveBefore,
      );
      return null;
    } catch (e) {
      _lastError = e.toString();
      _lastTranscribeErrorKind = 'unknown';
      _lastTranscribeErrorDetail = e.toString();
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_TRANSCRIBE_FAILED',
        '$endpoint unknown $e',
      );
      await _handleSttHttpFailure(
        endpoint: endpoint,
        stage: 'unknown',
        aliveBefore: aliveBefore,
      );
      return null;
    }
  }


  Future<void> _handleSttHttpFailure({
    required String endpoint,
    required String stage,
    required bool aliveBefore,
    int? exitCode,
  }) async {
    final aliveAfter = _helperProcessAlive();
    if (!aliveBefore && !aliveAfter) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_HELPER_PROCESS_EXITED', '$exitCode');
    }
    DesktopVoiceLog.instance.mark('helper_path', helperPath ?? '');
    DesktopVoiceLog.instance.mark('helper_pid', '${helperPid ?? ''}');
    DesktopVoiceLog.instance.mark(
      'helper_alive_before_request',
      aliveBefore ? 'yes' : 'no',
    );
    DesktopVoiceLog.instance.mark(
      'helper_alive_after_failure',
      aliveAfter ? 'yes' : 'no',
    );
    if (exitCode != null) {
      DesktopVoiceLog.instance.mark('helper_exit_code', '$exitCode');
    }
    DesktopVoiceLog.instance.mark('helper_stderr_tail', _helperStderrTailJoined);
    DesktopVoiceLog.instance.mark('endpoint', endpoint);
    DesktopVoiceLog.instance.mark('stage', stage);
    final err = (_lastError ?? '').trim();
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_RAW_EXCEPTION_SUPPRESSED',
      err.isEmpty ? stage : err,
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_REQUEST_FAILED_FRIENDLY', stage);

    if (!aliveAfter && !_restartAttemptedThisTranscribe) {
      _restartAttemptedThisTranscribe = true;
      final engine = resolveProductionEngine();
      unawaited(
        ensureStarted(
          engine: engine,
          maxWait: const Duration(seconds: 8),
          allowRestart: true,
        ),
      );
    }
  }

  /// Benchmark one engine on a saved WAV/PCM sample.
  Future<DesktopVoiceEngineBenchmark> benchmarkEngine({
    required DesktopVoiceEngineId engine,
    required String wavPath,
    required List<int> pcmBytes,
    required DesktopVoiceCaptureResult capture,
    String expectedPhrase = 'Price Reporter Planning',
  }) async {
    final t0 = DateTime.now();
    final modelPath = modelPathFor(engine);
    final modelExists =
        engine == DesktopVoiceEngineId.windowsSpeech ||
        (modelPath != null && Directory(modelPath).existsSync());

    String? transcript;
    String? error;
    var loaded = engine == DesktopVoiceEngineId.windowsSpeech;

    if (engine == DesktopVoiceEngineId.windowsSpeech) {
      transcript = await DesktopWinSpeechService.instance.transcribeWav(wavPath);
      error = transcript == null ? DesktopWinSpeechService.instance.lastError : null;
    } else {
      loaded = await ensureStarted(engine: engine);
      if (!loaded) {
        error = _lastError ?? 'model not loaded';
      } else {
        await _configureAndWaitReady(
          engine,
          DateTime.now().add(const Duration(seconds: 30)),
        );
        final r = await _transcribePcm(engine, pcmBytes);
        transcript = r?.text;
        error = r == null ? _lastError : null;
      }
    }

    final latencyMs = DateTime.now().difference(t0).inMilliseconds;
    final quality = transcript == null
        ? 0.0
        : scoreTranscriptQuality(transcript, expectedPhrase);

    return DesktopVoiceEngineBenchmark(
      engine: engine,
      model: engine.helperEngineId,
      modelPath: modelPath,
      modelLoaded: loaded,
      languageHint:
          engine == DesktopVoiceEngineId.windowsSpeech ? 'en-US' : 'en',
      audioFile: wavPath,
      audioDurationMs: capture.durationMs,
      audioBytes: pcmBytes.length,
      maxAmplitude: capture.maxAmplitude,
      rmsAmplitude: capture.rmsAmplitude,
      transcript: transcript,
      latencyMs: latencyMs,
      error: error,
      qualityScore: quality,
    );
  }

  Future<void> cancelListening() => _capture.cancel();

  /// Replay the latest saved WAV through the STT helper (installed self-test).
  Future<DesktopSttTranscript?> replayLatestWav() async {
    final wavPath = _capture.lastWavPath ?? _lastDiagnostics.latestWavPath;
    if (wavPath == null || !File(wavPath).existsSync()) {
      _lastError = 'No saved WAV to replay';
      return null;
    }
    final bytes = await File(wavPath).readAsBytes();
    final pcm = extractPcm16FromWav(bytes);
    if (pcm.isEmpty) {
      _lastError = 'Saved WAV has no PCM payload';
      return null;
    }
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_USING_SAVED_WAV', wavPath);
    final engine = resolveProductionEngine();
    if (engine == DesktopVoiceEngineId.windowsSpeech) {
      final text = await DesktopWinSpeechService.instance.transcribeWav(wavPath);
      if (text == null || text.trim().isEmpty) {
        _lastError = 'Empty transcript';
        DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_EMPTY');
        return null;
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_TEXT', text.trim());
      return DesktopSttTranscript(text: text.trim(), durationSec: 0, engine: engine.helperEngineId);
    }
    if (!await ensureStarted(engine: engine, allowRestart: true)) {
      return null;
    }
    final deadline = DateTime.now().add(kVoiceProcessingMaxWait);
    await _waitForFinalTranscribeReady(engine, deadline);
    var r = await _transcribePcm(engine, pcm);
    if (r == null && _isNotLoadedTranscribeError()) {
      await _waitForFinalTranscribeReady(engine, deadline);
      r = await _transcribePcm(engine, pcm);
    }
    if (r == null) {
      final fb = await _attemptWindowsFallbackStt(wavPath);
      if (fb == null) return null;
      return DesktopSttTranscript(text: fb, durationSec: 0, engine: 'windows_speech');
    }
    DesktopVoicePipeline.mark('DESKTOP_VOICE_TRANSCRIPT_TEXT', r.text);
    return r;
  }

  /// Orchestrator-local parakeet transcribe (no full stopAndTranscribe side effects).
  Future<DesktopSttTranscript?> transcribeCaptureForOrchestrator({
    required DesktopVoiceEngineId engine,
    required List<int> pcmBytes,
    required String wavPath,
  }) async {
    if (engine == DesktopVoiceEngineId.windowsSpeech) {
      final text = await DesktopWinSpeechService.instance.transcribeWav(wavPath);
      if (text == null || text.trim().isEmpty) return null;
      return DesktopSttTranscript(
        text: text.trim(),
        durationSec: pcm16DurationMs(pcmBytes) / 1000.0,
        engine: engine.helperEngineId,
      );
    }
    final deadline = DateTime.now().add(kVoiceProcessingMaxWait);
    if (!await ensureStarted(
      engine: engine,
      maxWait: kVoiceProcessingMaxWait,
      allowRestart: true,
    )) {
      return null;
    }
    await _waitForFinalTranscribeReady(engine, deadline);
    var r = await _transcribePcm(engine, pcmBytes);
    if (r == null && _isNotLoadedTranscribeError()) {
      await _waitForFinalTranscribeReady(engine, deadline);
      r = await _transcribePcm(engine, pcmBytes);
    }
    return r;
  }

  /// Stop capture and save WAV without running STT (benchmark / diagnostics).
  Future<DesktopVoiceCaptureResult?> stopCaptureSaveWav({String? fileName}) =>
      _capture.stopAndSaveWav(fileName: fileName);

  void dispose() {
    unawaited(_capture.cancel());
    _killHelperProcess();
    _engineReady.clear();
  }
}

class DesktopSttTranscript {
  const DesktopSttTranscript({
    required this.text,
    required this.durationSec,
    this.engine,
    this.partialHint,
    this.finalTranscriptSource,
    this.usedPartialAsFinal = false,
    this.stopReturnReason,
    this.finalInferenceLatencyMs,
    this.rawModelText,
    this.postprocessedText,
    this.finalCommandText,
    this.finalCommandSource,
    this.sttEngineLatencyMs,
  });

  final String text;
  final double durationSec;
  final String? engine;
  final String? partialHint;
  final String? finalTranscriptSource;
  final bool usedPartialAsFinal;
  final String? stopReturnReason;
  final int? finalInferenceLatencyMs;
  final String? rawModelText;
  final String? postprocessedText;
  final String? finalCommandText;
  final String? finalCommandSource;
  final int? sttEngineLatencyMs;
}
