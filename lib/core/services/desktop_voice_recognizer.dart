/// Desktop one-shot voice recognition result.
class DesktopVoiceRecognitionResult {
  const DesktopVoiceRecognitionResult({
    required this.transcript,
    required this.engineLabel,
    this.error,
    this.audioBytes,
  });

  final String transcript;
  final String engineLabel;
  final String? error;
  final int? audioBytes;

  bool get isSuccess => transcript.isNotEmpty && error == null;
}

/// Abstraction for Windows desktop command recognition (not mobile/web STT sheet).
abstract class DesktopVoiceRecognizer {
  Future<bool> prepare();

  Future<bool> startCapture();

  Stream<double>? get amplitudeStream;

  /// PCM bytes captured so far during active recording.
  int get capturedAudioBytes;

  /// Whether any non-silent amplitude was observed during capture.
  bool get audioLevelSeen;

  Future<DesktopVoiceRecognitionResult> finishCapture();

  Future<void> cancelCapture();

  void dispose();
}
