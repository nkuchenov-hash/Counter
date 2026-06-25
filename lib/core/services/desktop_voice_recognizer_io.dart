import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/diagnostics/desktop_voice_diag.dart';
import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_recognizer.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';

Future<DesktopVoiceRecognizer> createDesktopVoiceRecognizer() async {
  return DesktopVoiceRecognizerGolosHelper();
}

/// Production desktop recognizer — GOLOS parakeet / Windows Speech / benchmark winner.
class DesktopVoiceRecognizerGolosHelper implements DesktopVoiceRecognizer {
  final _helper = DesktopSttHelperService.instance;

  @override
  Future<bool> prepare() {
    if (kDesktopVoiceForcePrepareTimeout) {
      return Future<bool>.value(false);
    }
    return _helper.ensureStarted(
      maxWait: DesktopSttHelperService.kVoiceOverlayWarmupMax,
      allowRestart: true,
    );
  }

  @override
  Future<bool> startCapture() {
    final s = DesktopVoiceSettings.instance;
    return _helper.startListening(
      deviceId: s.selectedMicDeviceId,
      deviceLabel: s.selectedMicDeviceLabel,
    );
  }

  @override
  Stream<double>? get amplitudeStream => _helper.amplitudeStream;

  @override
  int get capturedAudioBytes => _helper.capturedAudioBytes;

  @override
  bool get audioLevelSeen => _helper.audioLevelSeen;

  @override
  Future<DesktopVoiceRecognitionResult> finishCapture() async {
    final engine = DesktopVoiceSettings.instance.resolveProductionEngine();
    final result = await _helper.stopAndTranscribe();
    final diag = _helper.lastDiagnostics;
    for (final line in diag.toDiagLines()) {
      DesktopVoiceDiag.instance.mark('stt', line);
    }
    if (result == null) {
      return DesktopVoiceRecognitionResult(
        transcript: '',
        engineLabel: diag.engine ?? engine.helperEngineId,
        error: _helper.lastError ?? 'Recognition failed',
        audioBytes: _helper.lastCaptureBytes,
      );
    }
    return DesktopVoiceRecognitionResult(
      transcript: result.text,
      engineLabel: result.engine ?? diag.engine ?? engine.helperEngineId,
      audioBytes: _helper.lastCaptureBytes,
    );
  }

  @override
  Future<void> cancelCapture() => _helper.cancelListening();

  @override
  void dispose() {}
}
