import 'package:counter/shared/voice/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_recognizer.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/core/services/desktop_voice_user_error.dart';
import 'package:counter/l10n/dictionary.dart';

Future<DesktopVoiceRecognizer> createDesktopVoiceRecognizer() async {
  return DesktopVoiceRecognizerGolosHelper();
}

/// Production desktop recognizer — GOLOS parakeet / Windows Speech / benchmark winner.
class DesktopVoiceRecognizerGolosHelper implements DesktopVoiceRecognizer {
  final _helper = DesktopSttHelperService.instance;

  @override
  Future<bool> prepare() async {
    _helper.prewarmRecognizerInBackground();
    return true;
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
      DesktopVoiceLog.instance.mark('stt', line);
    }
    if (result == null) {
      final loc = currentLocale.value;
      final kind = DesktopVoiceUserError.classifySttFailure(
        audioLevelSeen: diag.audioLevelSeen,
        errorText: _helper.lastError,
        transcribeErrorKind: diag.transcribeErrorKind,
        helperExists: diag.helperExists,
        modelExists: diag.modelExists,
        helperReady: diag.helperReady,
        finalTranscribeReady: diag.finalTranscribeReady,
        pendingWavAfterStop: diag.pendingWavAfterStop,
        helperReadyAfterRecording: diag.helperReadyAfterRecording,
        delayedTranscribeCalled: diag.delayedTranscribeCalled,
      );
      final friendly = DesktopVoiceUserError.fromException(
        _helper.lastError,
        stage: DesktopVoiceErrorStage.transcribing,
        localeCode: loc,
        kind: kind,
      );
      return DesktopVoiceRecognitionResult(
        transcript: '',
        engineLabel: diag.engine ?? engine.helperEngineId,
        error: friendly.message,
        audioBytes: _helper.lastCaptureBytes,
        failureKind: kind,
      );
    }
    return DesktopVoiceRecognitionResult(
      transcript: result.finalCommandText ?? result.text,
      engineLabel: result.engine ?? diag.engine ?? engine.helperEngineId,
      audioBytes: _helper.lastCaptureBytes,
      rawModelText: result.rawModelText,
      postprocessedText: result.postprocessedText,
      finalCommandText: result.finalCommandText,
      sttEngine: result.engine,
      sttEngineLatencyMs: result.sttEngineLatencyMs,
    );
  }

  @override
  Future<void> cancelCapture() => _helper.cancelListening();

  @override
  void dispose() {}
}
