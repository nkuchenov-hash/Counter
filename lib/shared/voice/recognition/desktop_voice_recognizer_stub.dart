import 'package:counter/shared/voice/recognition/desktop_voice_recognizer.dart';

Future<DesktopVoiceRecognizer> createDesktopVoiceRecognizer() async {
  return _DesktopVoiceRecognizerUnsupported();
}

class _DesktopVoiceRecognizerUnsupported implements DesktopVoiceRecognizer {
  @override
  Future<bool> prepare() async => false;

  @override
  Future<bool> startCapture() async => false;

  @override
  Stream<double>? get amplitudeStream => null;

  @override
  int get capturedAudioBytes => 0;

  @override
  bool get audioLevelSeen => false;

  @override
  Future<DesktopVoiceRecognitionResult> finishCapture() async {
    return const DesktopVoiceRecognitionResult(
      transcript: '',
      engineLabel: 'unsupported',
      error: 'Desktop voice not supported on this platform',
    );
  }

  @override
  Future<void> cancelCapture() async {}

  @override
  void dispose() {}
}
