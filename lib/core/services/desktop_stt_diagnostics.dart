/// Last STT / voice capture diagnostic snapshot for Settings display.
class DesktopSttDiagnostics {
  const DesktopSttDiagnostics({
    this.helperPath,
    this.modelPath,
    this.modelExists = false,
    this.modelLoaded = false,
    this.engine,
    this.languageHint = 'en-US',
    this.audioDevice = 'default',
    this.sampleRate = 16000,
    this.channels = 1,
    this.audioBytes = 0,
    this.audioDurationMs = 0,
    this.maxAmplitude = 0,
    this.rmsAmplitude = 0,
    this.audioLevelSeen = false,
    this.audioFile,
    this.transcript,
    this.error,
    this.latencyMs,
  });

  final String? helperPath;
  final String? modelPath;
  final bool modelExists;
  final bool modelLoaded;
  final String? engine;
  final String languageHint;
  final String audioDevice;
  final int sampleRate;
  final int channels;
  final int audioBytes;
  final int audioDurationMs;
  final double maxAmplitude;
  final double rmsAmplitude;
  final bool audioLevelSeen;
  final String? audioFile;
  final String? transcript;
  final String? error;
  final int? latencyMs;

  List<String> toDiagLines() {
    return [
      'STT_HELPER_CHECK',
      'helper_path=${helperPath ?? '—'}',
      'model_path=${modelPath ?? '—'}',
      'model_exists=${modelExists ? 'yes' : 'no'}',
      'model_loaded=${modelLoaded ? 'yes' : 'no'}',
      'engine=${engine ?? '—'}',
      'language_hint=$languageHint',
      'audio_device=$audioDevice',
      'sample_rate=$sampleRate',
      'channels=$channels',
      'audio_bytes=$audioBytes',
      'audio_duration_ms=$audioDurationMs',
      'max_amplitude=${maxAmplitude.toStringAsFixed(3)}',
      'rms_amplitude=${rmsAmplitude.toStringAsFixed(3)}',
      'audio_level_seen=${audioLevelSeen ? 'yes' : 'no'}',
      'audio_file=${audioFile ?? '—'}',
      'transcript=${transcript ?? '—'}',
      if (latencyMs != null) 'latency_ms=$latencyMs',
      if (error != null && error!.isNotEmpty) 'error=$error',
    ];
  }
}
