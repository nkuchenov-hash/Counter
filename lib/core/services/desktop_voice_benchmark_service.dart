import 'dart:io';

import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_audio_capture.dart';
import 'package:counter/core/services/desktop_voice_engine.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/core/services/pcm_audio_utils.dart';

/// Side-by-side recognizer benchmark on one saved WAV sample.
class DesktopVoiceBenchmarkService {
  DesktopVoiceBenchmarkService._();

  static final DesktopVoiceBenchmarkService instance =
      DesktopVoiceBenchmarkService._();

  static const benchmarkPhrasePlanning = 'Price Reporter Planning';
  static const benchmarkPhraseAddMod = 'Price Reporter AGE SOLUTIONS ADD MOD';

  List<DesktopVoiceEngineBenchmark> _lastResults = const [];
  String? _lastWavPath;
  DesktopVoiceCaptureResult? _lastCapture;

  List<DesktopVoiceEngineBenchmark> get lastResults => _lastResults;
  String? get lastWavPath => _lastWavPath;
  DesktopVoiceCaptureResult? get lastCapture => _lastCapture;

  Future<DesktopVoiceCaptureResult?> captureBenchmarkSample({
    String? deviceId,
    String? deviceLabel,
    Duration maxDuration = const Duration(seconds: 6),
  }) async {
    final stt = DesktopSttHelperService.instance;
    final settings = DesktopVoiceSettings.instance;
    final ok = await stt.startListening(
      deviceId: deviceId ?? settings.selectedMicDeviceId,
      deviceLabel: deviceLabel ?? settings.selectedMicDeviceLabel,
    );
    if (!ok) return null;
    await Future<void>.delayed(maxDuration);
    final capture = await stt.stopCaptureSaveWav(
      fileName: 'benchmark_sample.wav',
    );
    _lastCapture = capture;
    _lastWavPath = capture?.wavPath;
    return capture;
  }

  Future<List<DesktopVoiceEngineBenchmark>> runFullBenchmark({
    String? wavPath,
    List<int>? pcmBytes,
    DesktopVoiceCaptureResult? capture,
  }) async {
    final cap = capture ?? _lastCapture;
    final path = wavPath ?? cap?.wavPath ?? _lastWavPath;
    if (path == null || !File(path).existsSync()) {
      return const [];
    }
    final pcmData = cap?.pcmBytes ?? <int>[];
    if (pcmData.isEmpty) {
      return const [];
    }

    final captureMeta = cap!;
    final stt = DesktopSttHelperService.instance;
    final engines = [
      DesktopVoiceEngineId.parakeet,
      DesktopVoiceEngineId.whisperTiny,
      DesktopVoiceEngineId.windowsSpeech,
    ];

    final results = <DesktopVoiceEngineBenchmark>[];
    for (final engine in engines) {
      var bestScore = 0.0;
      DesktopVoiceEngineBenchmark? bestRow;
      for (final phrase in [
        benchmarkPhrasePlanning,
        benchmarkPhraseAddMod,
      ]) {
        final row = await stt.benchmarkEngine(
          engine: engine,
          wavPath: path,
          pcmBytes: pcmData,
          capture: captureMeta,
          expectedPhrase: phrase,
        );
        if (row.qualityScore > bestScore) {
          bestScore = row.qualityScore;
          bestRow = row;
        }
      }
      if (bestRow != null) results.add(bestRow);
    }

    _lastResults = results;
    final winner = _pickWinner(results);
    if (winner != null) {
      await DesktopVoiceSettings.instance.setProductionEngine(winner.engine);
      final summary = results.expand((r) => [...r.toDiagLines(), '---']).join('\n');
      await DesktopVoiceSettings.instance.setLastBenchmarkSummary(summary);
    }
    return results;
  }

  DesktopVoiceEngineBenchmark? _pickWinner(
    List<DesktopVoiceEngineBenchmark> rows,
  ) {
    DesktopVoiceEngineBenchmark? best;
    for (final row in rows) {
      if (row.transcript == null || row.transcript!.isEmpty) continue;
      if (row.qualityScore <= 0) continue;
      if (best == null || row.qualityScore > best.qualityScore) {
        best = row;
      }
    }
    // Prefer parakeet / windows over whisper-tiny on tie.
    if (best != null) return best;
    for (final row in rows) {
      if (row.transcript != null &&
          row.transcript!.isNotEmpty &&
          row.engine != DesktopVoiceEngineId.whisperTiny) {
        return row;
      }
    }
    return null;
  }

  List<String> allDiagLines() {
    final lines = <String>[];
    final cap = _lastCapture;
    if (cap != null) {
      lines.addAll(cap.captureDiagLines());
    }
    for (final r in _lastResults) {
      lines.addAll(r.toDiagLines());
      lines.add('---');
    }
    return lines;
  }
}
