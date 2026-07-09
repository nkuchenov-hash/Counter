/// Capture-ready cue + pre-roll / start-trim contracts for Desktop Voice.
///
/// Recording starts before the cue. The cue only signals that capture is ready.
/// Cue timing is never counted as STT useful-candidate latency.
abstract final class DesktopVoiceCaptureReadyPolicy {
  /// Delay after first audio callback before playing the ready cue.
  static const int readyCueDelayAfterFirstAudioMs = 150;

  /// Short click duration (ms). Must stay well under 100ms.
  static const int readyCueDurationMs = 45;

  /// Soft click frequency (Hz) for console beep on Windows.
  static const int readyCueFrequencyHz = 1400;

  /// Pre-roll / leading pad kept in the STT copy before expected speech.
  static const int preRollMs = 250;

  /// Extra leading silence prepended to STT PCM for model context.
  static const int sttLeadingPadMs = 200;

  /// Minimum leading audio that must remain after start trim (ms).
  static const int startTrimGuardMinLeadingMs = 150;

  /// Diagnostic-phase default: ready cue ON.
  static const bool readyCueDefaultEnabled = true;

  static const String markerCaptureReadyBeforeCue =
      'DESKTOP_VOICE_CAPTURE_READY_BEFORE_CUE';
  static const String markerFirstAudioBeforeCue =
      'DESKTOP_VOICE_FIRST_AUDIO_CALLBACK_BEFORE_CUE';
  static const String markerCueAfterCaptureReady =
      'DESKTOP_VOICE_READY_CUE_PLAYED_AFTER_CAPTURE_READY';
  static const String markerLeadingAudioPreserved =
      'DESKTOP_VOICE_LEADING_AUDIO_PRESERVED';
  static const String markerCueShort = 'DESKTOP_VOICE_READY_CUE_SHORT';
  static const String markerNoLongBeep = 'DESKTOP_VOICE_NO_LONG_START_BEEP';
  static const String markerCueNonBlocking =
      'DESKTOP_VOICE_READY_CUE_NON_BLOCKING';
  static const String markerCueNotSpeech =
      'DESKTOP_VOICE_READY_CUE_NOT_COUNTED_AS_SPEECH';
  static const String markerPreRoll =
      'DESKTOP_VOICE_PRE_ROLL_BUFFER_ENABLED';
  static const String markerStartTrimGuard =
      'DESKTOP_VOICE_START_TRIM_GUARD_ENABLED';
  static const String markerFirstPhonemeNotTrimmed =
      'DESKTOP_VOICE_FIRST_PHONEME_NOT_TRIMMED';
  static const String markerCueNotLatency =
      'DESKTOP_VOICE_READY_CUE_NOT_USED_AS_LATENCY_PASS';

  /// Cue may play only after capture stream started AND first audio callback.
  static bool mayPlayReadyCue({
    required bool captureStreamStarted,
    required bool firstAudioCallbackReceived,
    required bool cueAlreadyPlayed,
    required bool cueEnabled,
  }) {
    if (!cueEnabled || cueAlreadyPlayed) return false;
    return captureStreamStarted && firstAudioCallbackReceived;
  }

  /// Recording must already be active before the cue.
  static bool recordingStartedBeforeCue({
    required int? captureStreamStartedMs,
    required int? readyCuePlayedMs,
  }) {
    if (captureStreamStartedMs == null || readyCuePlayedMs == null) {
      return false;
    }
    return captureStreamStartedMs <= readyCuePlayedMs;
  }

  /// First audio callback must precede the cue.
  static bool firstAudioBeforeCue({
    required int? firstAudioCallbackMs,
    required int? readyCuePlayedMs,
  }) {
    if (firstAudioCallbackMs == null || readyCuePlayedMs == null) {
      return false;
    }
    return firstAudioCallbackMs <= readyCuePlayedMs;
  }

  /// Cue duration must stay short (no 1s beep).
  static bool isShortCue(int durationMs) =>
      durationMs >= 30 && durationMs <= 60;

  /// Start-trim must not cut into the first [startTrimGuardMinLeadingMs].
  ///
  /// [firstSpeechSample] is the first sample index above threshold.
  /// Returns the earliest allowed trim start sample index.
  static int guardedTrimStartSample({
    required int firstSpeechSample,
    required int sampleRate,
    int prePadMs = preRollMs,
    int guardMs = startTrimGuardMinLeadingMs,
  }) {
    final pre = (sampleRate * prePadMs) ~/ 1000;
    final guard = (sampleRate * guardMs) ~/ 1000;
    final natural = (firstSpeechSample - pre).clamp(0, firstSpeechSample);
    // Never trim past the guard window from the buffer start when speech
    // begins early — preserves first phonemes ("Southern").
    if (firstSpeechSample <= guard + pre) {
      return 0;
    }
    return natural;
  }

  /// Prepend [padMs] of PCM16 silence for STT context (raw WAV unchanged).
  static List<int> prependLeadingSilencePcm16(
    List<int> pcm16, {
    int sampleRate = 16000,
    int padMs = sttLeadingPadMs,
  }) {
    if (pcm16.isEmpty || padMs <= 0) return pcm16;
    final padSamples = (sampleRate * padMs) ~/ 1000;
    if (padSamples <= 0) return pcm16;
    final out = List<int>.filled(padSamples * 2 + pcm16.length, 0);
    for (var i = 0; i < pcm16.length; i++) {
      out[padSamples * 2 + i] = pcm16[i];
    }
    return out;
  }

  /// Cue energy must not count as user speech for latency / speech-detect.
  static bool isCueCountedAsSpeech() => false;

  /// Cue timing must never satisfy the useful-candidate <500ms gate.
  static bool isCueCountedAsLatencyPass() => false;
}
