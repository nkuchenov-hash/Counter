/// Policy for Desktop Voice delayed transcription after helper cold-start.
///
/// Recording is local-first and must never wait on the helper. When the user
/// stops while Parakeet is still loading, the saved STT WAV is pending and
/// must be transcribed once [final_transcribe_ready] becomes true — without
/// forcing the user to re-speak, and without a false "Recognizer unavailable".
abstract final class DesktopVoiceDelayedTranscribe {
  /// Cold-start budget after stop when a valid WAV is already on disk.
  /// Parakeet first-load on Windows commonly exceeds the short 10s HTTP budget.
  static const Duration coldStartMaxWait = Duration(seconds: 45);

  /// Post-stop HTTP budget when the helper was already final-ready at stop.
  static const Duration readyHelperMaxWait = Duration(seconds: 10);

  static bool hasValidPendingWav({
    required bool wavExists,
    required int pcmByteLength,
    required bool audioLevelSeen,
  }) {
    return wavExists && pcmByteLength >= 3200 && audioLevelSeen;
  }

  static bool shouldQueuePendingWav({
    required bool hasValidPendingWav,
    required bool helperFinalReadyAtStop,
  }) {
    return hasValidPendingWav && !helperFinalReadyAtStop;
  }

  static Duration waitBudget({required bool pendingWavQueued}) {
    return pendingWavQueued ? coldStartMaxWait : readyHelperMaxWait;
  }

  /// Do not classify as recognizer-unavailable when a valid WAV exists and the
  /// helper became ready — delayed transcribe must be attempted instead.
  static bool suppressFalseRecognizerUnavailable({
    required bool hasValidPendingWav,
    required bool helperReadyAfterRecording,
  }) {
    return hasValidPendingWav && helperReadyAfterRecording;
  }
}
