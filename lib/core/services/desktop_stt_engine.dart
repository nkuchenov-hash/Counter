import 'package:counter/core/services/desktop_voice_engine.dart';

/// Quality tier for STT engine selection.
enum DesktopSttQualityTier {
  best,
  fast,
  fallback,
}

/// User-facing STT mode (quality ladder).
enum DesktopSttMode {
  /// Highest accuracy — cloud when configured, else best local.
  bestQuality,

  /// Local parakeet / primary ONNX engine.
  fastLocal,

  /// Local-only — no cloud attempt.
  offlineFallback,

  /// Compare all configured engines on one WAV.
  benchmark,
}

/// Context passed to every STT engine for command transcription.
class DesktopSttEngineContext {
  const DesktopSttEngineContext({
    required this.wavPath,
    required this.pcmBytes,
    this.languageHint = 'en-US',
    this.glossaryTerms = const [],
    this.glossaryPrompt = '',
  });

  final String wavPath;
  final List<int> pcmBytes;
  final String languageHint;
  final List<String> glossaryTerms;
  final String glossaryPrompt;
}

/// Result from a single STT engine invocation.
class DesktopSttEngineResult {
  const DesktopSttEngineResult({
    required this.engineId,
    required this.displayName,
    required this.qualityTier,
    this.rawTranscript,
    this.latencyMs = 0,
    this.errorKind,
    this.supportsGlossary = false,
    this.providerModelId,
  });

  final String engineId;
  final String displayName;
  final DesktopSttQualityTier qualityTier;
  final String? rawTranscript;
  final int latencyMs;
  final String? errorKind;
  final bool supportsGlossary;
  final String? providerModelId;

  bool get isSuccess =>
      rawTranscript != null && rawTranscript!.trim().isNotEmpty;
}

/// Pluggable STT backend contract.
abstract class DesktopSttEngine {
  String get id;
  String get displayName;
  DesktopSttQualityTier get qualityTier;
  bool get supportsGlossary;

  Future<bool> isAvailable();

  Future<DesktopSttEngineResult> transcribeCommandWav(
    DesktopSttEngineContext context,
  );
}

/// Maps legacy [DesktopVoiceEngineId] to orchestrator ids.
extension DesktopVoiceEngineIdStt on DesktopVoiceEngineId {
  String get sttEngineId => helperEngineId;
}
