import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_stt_diagnostics.dart';
import 'package:counter/core/services/desktop_voice_audio_capture.dart';
import 'package:counter/core/services/desktop_voice_engine.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/core/services/desktop_win_speech_service.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

/// GOLOS HTTP sidecar + unified desktop voice capture/transcription.
class DesktopSttHelperService {
  DesktopSttHelperService._();

  static final DesktopSttHelperService instance = DesktopSttHelperService._();

  static const _baseUrl = 'http://127.0.0.1:8765';
  static const _port = 8765;
  static const _levelThreshold = 0.008;

  final _capture = DesktopVoiceAudioCapture.instance;

  Process? _process;
  bool _ready = false;
  final Map<String, bool> _engineReady = {};
  String? _lastError;
  String? _engine;
  int _lastCaptureBytes = 0;
  bool _starting = false;
  DesktopSttDiagnostics _lastDiagnostics = const DesktopSttDiagnostics();

  int get lastCaptureBytes => _lastCaptureBytes;
  int get capturedAudioBytes => _capture.capturedBytes;
  bool get audioLevelSeen => _capture.audioLevelSeen;
  double get maxAmplitude => _capture.maxAmplitude;
  double get rmsAmplitude => _capture.rmsAmplitude;
  Stream<double>? get amplitudeStream => _capture.amplitudeStream;
  DesktopSttDiagnostics get lastDiagnostics => _lastDiagnostics;
  String? get lastWavPath => _capture.lastWavPath;

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

  /// Voice-overlay warmup — hard 5s cap; never blocks UI in Preparing forever.
  static const Duration kVoiceOverlayWarmupMax = Duration(seconds: 5);

  Future<bool> ensureStarted({
    DesktopVoiceEngineId? engine,
    Duration maxWait = const Duration(seconds: 15),
    bool allowRestart = true,
  }) async {
    final target = engine ?? resolveProductionEngine();
    if (target == DesktopVoiceEngineId.windowsSpeech) return true;

    final key = target.helperEngineId;
    if (_ready && _engineReady[key] == true) return true;

    final deadline = DateTime.now().add(maxWait);
    bool pastDeadline() => !DateTime.now().isBefore(deadline);

    if (_starting) {
      while (!pastDeadline()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (_ready && _engineReady[key] == true) return true;
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
      if (exe == null) {
        _lastError = 'STT helper not found';
        return false;
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_PROCESS_START');
      try {
        _process = await Process.start(
          exe,
          ['--port', '$_port'],
          workingDirectory: File(exe).parent.path,
        );
        _process?.stdout.transform(utf8.decoder).listen((_) {});
        _process?.stderr.transform(utf8.decoder).listen((_) {});
      } catch (e) {
        _lastError = 'Failed to start STT helper: $e';
        return false;
      }
      while (!pastDeadline()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
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
    if (!ok) {
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
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _configureAndWaitReady(
    DesktopVoiceEngineId engine,
    DateTime deadline,
  ) async {
    bool pastDeadline() => !DateTime.now().isBefore(deadline);

    final modelDir = modelPathFor(engine);
    if (modelDir == null || !Directory(modelDir).existsSync()) {
      _lastError = 'Model not found: ${engine.helperEngineId}';
      _engineReady[engine.helperEngineId] = false;
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

  Future<bool> _refreshRemoteStatus(DesktopVoiceEngineId engine) async {
    try {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_REQUEST', 'status');
      final r = await http
          .get(Uri.parse('$_baseUrl/status'))
          .timeout(const Duration(seconds: 2));
      if (r.statusCode != 200) return false;
      final body = jsonDecode(r.body);
      if (body is! Map<String, dynamic>) return false;
      final active = body['engine'] ?? body['model'];
      final ready = body['ready'] == true;
      if (active is String && active.isNotEmpty) _engine = active;
      if (ready && active == engine.helperEngineId) {
        _engineReady[engine.helperEngineId] = true;
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<List<InputDevice>> listInputDevices() =>
      _capture.listInputDevices();

  Future<bool> startListening({String? deviceId, String? deviceLabel}) async {
    final engine = resolveProductionEngine();
    if (engine != DesktopVoiceEngineId.windowsSpeech) {
      if (!await ensureStarted(engine: engine)) return false;
    }
    final ok = await _capture.start(deviceId: deviceId, deviceLabel: deviceLabel);
    if (!ok) {
      _lastError = _capture.lastError;
      return false;
    }
    if (engine != DesktopVoiceEngineId.windowsSpeech) {
      _capture.attachPartialTimer((bytes) {
        unawaited(_sendPartialAudio(bytes));
      });
    }
    return true;
  }

  Future<void> _sendPartialAudio(List<int> bytes) async {
    if (bytes.length < 3200 || !_ready) return;
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/transcribe/partial_audio'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'audio_base64': base64Encode(bytes)}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<DesktopSttTranscript?> stopAndTranscribe() async {
    final capture = await _capture.stopAndSaveWav();
    if (capture == null) {
      _lastError = _capture.lastError ?? 'Not enough audio';
      await _updateDiagnostics(error: _lastError);
      return null;
    }

    _lastCaptureBytes = capture.pcmBytes.length;

    if (!capture.audioLevelSeen ||
        capture.maxAmplitude < _levelThreshold) {
      _lastError = 'Not enough audio';
      await _updateDiagnostics(capture: capture, error: _lastError);
      return null;
    }

    final engine = resolveProductionEngine();
    final t0 = DateTime.now();
    String? text;
    String? error;

    if (engine == DesktopVoiceEngineId.windowsSpeech) {
      text = await DesktopWinSpeechService.instance.transcribeWav(capture.wavPath);
      error = DesktopWinSpeechService.instance.lastError;
    } else {
      if (!await ensureStarted(engine: engine)) {
        await _updateDiagnostics(capture: capture, error: _lastError);
        return null;
      }
      final r = await _transcribePcm(engine, capture.pcmBytes);
      text = r?.text;
      error = r == null ? _lastError : null;
    }

    final latencyMs = DateTime.now().difference(t0).inMilliseconds;

    if (text == null || text.trim().isEmpty) {
      _lastError = error ?? 'Empty transcript';
      await _updateDiagnostics(capture: capture, error: _lastError);
      return null;
    }

    _lastError = null;
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

  Future<DesktopSttTranscript?> _transcribePcm(
    DesktopVoiceEngineId engine,
    List<int> pcm,
  ) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_baseUrl/transcribe/stop'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'audio_base64': base64Encode(pcm)}),
          )
          .timeout(const Duration(seconds: 180));
      if (r.statusCode != 200) {
        _lastError = 'STT HTTP ${r.statusCode}';
        return null;
      }
      final body = jsonDecode(r.body);
      if (body is! Map<String, dynamic>) {
        _lastError = 'Invalid STT response';
        return null;
      }
      final err = body['error'];
      if (err is String && err.isNotEmpty) {
        _lastError = err;
        return null;
      }
      final text = (body['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        _lastError = 'Empty transcript';
        return null;
      }
      final duration = (body['duration'] as num?)?.toDouble() ?? 0;
      return DesktopSttTranscript(
        text: text,
        durationSec: duration,
        engine: engine.helperEngineId,
      );
    } catch (e) {
      _lastError = e.toString();
      return null;
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

  Future<void> _updateDiagnostics({
    DesktopVoiceCaptureResult? capture,
    DesktopVoiceEngineId? engine,
    String? transcript,
    String? error,
    int? latencyMs,
  }) async {
    final e = engine ?? resolveProductionEngine();
    final model = modelPathFor(e);
    _lastDiagnostics = DesktopSttDiagnostics(
      helperPath: helperPath,
      modelPath: model,
      modelExists: model != null && Directory(model).existsSync(),
      modelLoaded: e == DesktopVoiceEngineId.windowsSpeech || modelLoaded,
      engine: e.helperEngineId,
      languageHint: e == DesktopVoiceEngineId.windowsSpeech ? 'en-US' : 'en',
      audioDevice: capture?.deviceLabel ?? 'default',
      sampleRate: capture?.sampleRate ?? kVoiceSampleRate,
      channels: capture?.channels ?? kVoiceChannels,
      audioBytes: capture?.pcmBytes.length ?? _lastCaptureBytes,
      audioDurationMs: capture?.durationMs ?? 0,
      maxAmplitude: capture?.maxAmplitude ?? _capture.maxAmplitude,
      rmsAmplitude: capture?.rmsAmplitude ?? _capture.rmsAmplitude,
      audioLevelSeen: capture?.audioLevelSeen ?? _capture.audioLevelSeen,
      audioFile: capture?.wavPath ?? _capture.lastWavPath,
      transcript: transcript,
      error: error ?? _lastError,
      latencyMs: latencyMs,
    );
  }

  Future<DesktopSttDiagnostics> fetchDiagnostics({
    String? transcript,
    String? error,
  }) async {
    final e = resolveProductionEngine();
    if (e != DesktopVoiceEngineId.windowsSpeech) {
      await ensureStarted(engine: e);
    }
    await _updateDiagnostics(transcript: transcript, error: error);
    return _lastDiagnostics;
  }

  Future<void> cancelListening() => _capture.cancel();

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
  });

  final String text;
  final double durationSec;
  final String? engine;
}
