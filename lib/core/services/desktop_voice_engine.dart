/// Recognizer engines available for desktop voice command capture.
enum DesktopVoiceEngineId {
  /// GOLOS production ONNX recognizer (primary when model bundled).
  parakeet('parakeet'),

  /// Legacy whisper — debug/benchmark only; not production default.
  whisperTiny('whisper-tiny'),

  /// Windows System.Speech en-US WAV transcription (benchmark + fallback).
  windowsSpeech('windows-speech');

  const DesktopVoiceEngineId(this.helperEngineId);
  final String helperEngineId;

  static DesktopVoiceEngineId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final e in DesktopVoiceEngineId.values) {
      if (e.helperEngineId == raw || e.name == raw) return e;
    }
    return null;
  }
}

/// Single ENGINE_BENCHMARK result row.
class DesktopVoiceEngineBenchmark {
  const DesktopVoiceEngineBenchmark({
    required this.engine,
    this.model,
    this.modelPath,
    this.modelLoaded = false,
    this.languageHint = 'en-US',
    this.audioFile,
    this.audioDurationMs = 0,
    this.audioBytes = 0,
    this.maxAmplitude = 0,
    this.rmsAmplitude = 0,
    this.transcript,
    this.latencyMs = 0,
    this.error,
    this.qualityScore = 0,
  });

  final DesktopVoiceEngineId engine;
  final String? model;
  final String? modelPath;
  final bool modelLoaded;
  final String languageHint;
  final String? audioFile;
  final int audioDurationMs;
  final int audioBytes;
  final double maxAmplitude;
  final double rmsAmplitude;
  final String? transcript;
  final int latencyMs;
  final String? error;
  final double qualityScore;

  List<String> toDiagLines() {
    return [
      'ENGINE_BENCHMARK',
      'engine=${engine.helperEngineId}',
      'model=${model ?? engine.helperEngineId}',
      'model_path=${modelPath ?? '—'}',
      'model_loaded=${modelLoaded ? 'yes' : 'no'}',
      'language_hint=$languageHint',
      'audio_file=${audioFile ?? '—'}',
      'audio_duration_ms=$audioDurationMs',
      'audio_bytes=$audioBytes',
      'max_amplitude=${maxAmplitude.toStringAsFixed(3)}',
      'rms_amplitude=${rmsAmplitude.toStringAsFixed(3)}',
      'transcript=${transcript ?? '—'}',
      'latency_ms=$latencyMs',
      if (error != null && error!.isNotEmpty) 'error=$error',
      'quality_score=${qualityScore.toStringAsFixed(2)}',
    ];
  }
}

/// Heuristic transcript quality vs expected English command phrase.
double scoreTranscriptQuality(String transcript, String expectedPhrase) {
  final t = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  final e = expectedPhrase.toLowerCase();
  final expectedWords =
      e.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (expectedWords.isEmpty) return 0;
  var hits = 0;
  for (final w in expectedWords) {
    if (t.contains(w)) hits++;
  }
  return hits / expectedWords.length;
}
