import 'package:counter/core/services/desktop_voice_engine.dart';

/// Evidence-based Desktop Voice command STT engine selection.
///
/// Offline local-engine bench (2026-07-08, build 4f9c984 WAVs):
/// - latest CPAL quiet WAV: Parakeet → "Tell them computer warehouse download
///   submit." ; whisper-tiny → "Southern Computer Warehouse, DEL MOD, Submit."
/// - old Counter / Handy: whisper-tiny retains Southern + DEL MOD; Parakeet
///   only matches Handy on the loud Handy WAV.
/// - Windows Speech unavailable on this host (no en-US recognizer culture).
///
/// Therefore command primary = whisper-tiny. Parakeet is secondary fallback
/// only (not used to block first candidate).
abstract final class DesktopVoiceCommandSttPolicy {
  static const DesktopVoiceEngineId primaryEngine =
      DesktopVoiceEngineId.whisperTiny;

  static const DesktopVoiceEngineId fallbackEngine =
      DesktopVoiceEngineId.parakeet;

  static const String selectionReason =
      'offline_bench_whisper_recovers_SCW_DEL_MOD_on_quiet_cpal_where_parakeet_fails';

  /// Hot whisper-tiny `/transcribe/stop` on ~4–5s command WAV ≈1.5s on this
  /// machine via helper HTTP. First-candidate &lt;500ms needs streaming
  /// partials or aggressive clip; trim alone is insufficient.
  static const int measuredHotWhisperMs = 1500;
  static const int measuredHotParakeetMs = 1050;
  static const int measuredHotParakeetReplayDirectMs = 270;

  static const bool whisperBeatsParakeetOnQuietCommandWavs = true;

  static DesktopVoiceEngineId resolvePrimary({
    DesktopVoiceEngineId? override,
  }) {
    if (override != null && override != DesktopVoiceEngineId.windowsSpeech) {
      return override;
    }
    return primaryEngine;
  }
}
