import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/shared/voice/commands/desktop_stt_engine.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_stt_helper_service.dart';
import 'package:counter/shared/voice/commands/desktop_stt_quality_evaluation.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_audio_capture.dart';
import 'package:counter/shared/voice/commands/desktop_voice_command_stt_policy.dart';
import 'package:counter/shared/voice/commands/desktop_voice_engine.dart';
import 'package:counter/data/voice/desktop_voice_glossary.dart';
import 'package:counter/data/voice/desktop_voice_recognition_postprocess.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_settings.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_win_speech_service.dart';

/// Full recognition pipeline result after STT + postprocess.
class DesktopRecognitionPipelineResult {
  const DesktopRecognitionPipelineResult({
    required this.rawModelText,
    required this.postprocessedText,
    required this.finalCommandText,
    required this.sttEngine,
    required this.sttEngineLatencyMs,
    required this.finalCommandSource,
    this.postprocessRejected = false,
    this.postprocessRejectReason,
    this.appliedPostprocessRules = const [],
  });

  final String rawModelText;
  final String postprocessedText;
  final String finalCommandText;
  final String sttEngine;
  final int sttEngineLatencyMs;
  final String finalCommandSource;
  final bool postprocessRejected;
  final String? postprocessRejectReason;
  final List<String> appliedPostprocessRules;
}

/// STT quality ladder — selects engine, transcribes, postprocesses.
abstract final class DesktopSttOrchestrator {
  static Future<DesktopRecognitionPipelineResult?> transcribeCommand({
    required DesktopVoiceCaptureResult capture,
    required DesktopVoiceGlossaryPack glossary,
    DesktopSttMode? mode,
  }) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_ENGINE_ABSTRACTION');
    final selectedMode =
        mode ?? DesktopVoiceSettings.instance.resolveSttMode();

    switch (selectedMode) {
      case DesktopSttMode.bestQuality:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_MODE_BEST_QUALITY');
      case DesktopSttMode.fastLocal:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_MODE_FAST_LOCAL');
      case DesktopSttMode.offlineFallback:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_STT_MODE_OFFLINE_FALLBACK');
      case DesktopSttMode.benchmark:
        break;
    }

    final ctx = DesktopSttEngineContext(
      wavPath: capture.wavPath,
      pcmBytes: capture.pcmBytes,
      glossaryTerms: glossary.terms,
      glossaryPrompt: glossary.toSttPrompt(),
    );

    // Command STT primary = evidence-selected engine (whisper-tiny).
    DesktopSttEngineResult? engineResult;
    if (selectedMode == DesktopSttMode.offlineFallback) {
      engineResult = await _tryPrimaryCommandEngine(ctx) ??
          await _tryWindowsSpeech(ctx);
    } else {
      engineResult = await _tryPrimaryCommandEngine(ctx) ??
          await _tryFallbackParakeet(ctx) ??
          await _tryWindowsSpeech(ctx);
    }

    if (engineResult == null || !engineResult.isSuccess) {
      return null;
    }

    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_STT_ENGINE_SELECTED',
      engineResult.engineId,
    );

    final rawText = engineResult.rawTranscript!.trim();
    DesktopSttQualityEvaluation.markRawEvaluationStarted();
    DesktopSttQualityEvaluation.logRawFinalSttText(rawText);

    // Safety-only postprocess — logged but NOT used as STT quality or command text.
    final post = DesktopVoiceRecognitionPostprocess.apply(
      rawModelText: rawText,
      glossary: glossary,
    );
    DesktopSttQualityEvaluation.logPostprocessDelta(
      rawModelText: rawText,
      postprocessedText: post.postprocessedText,
    );

    DesktopVoicePipeline.mark('DESKTOP_VOICE_LOCAL_STT_PIPELINE_FIXED');
    return DesktopRecognitionPipelineResult(
      rawModelText: rawText,
      postprocessedText: post.postprocessedText,
      finalCommandText: rawText,
      sttEngine: engineResult.engineId,
      sttEngineLatencyMs: engineResult.latencyMs,
      finalCommandSource: engineResult.engineId,
      postprocessRejected: post.rejected,
      postprocessRejectReason: post.rejectReason,
      appliedPostprocessRules: post.appliedRules,
    );
  }

  static Future<DesktopSttEngineResult?> _tryPrimaryCommandEngine(
    DesktopSttEngineContext ctx,
  ) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_LOCAL_ENGINE_QUALITY_AUDIT');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_COMMAND_STT_PRIMARY_SELECTED');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_WHISPER_TINY_PRIMARY_IF_BEST');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_PARAKEET_NOT_PRIMARY_IF_WORSE');
    final helper = DesktopSttHelperService.instance;
    final engine = DesktopVoiceCommandSttPolicy.primaryEngine;
    final t0 = DateTime.now();
    final r = await helper.transcribeCaptureForOrchestrator(
      engine: engine,
      pcmBytes: ctx.pcmBytes,
      wavPath: ctx.wavPath,
    );
    if (r == null || r.text.trim().isEmpty) return null;
    return DesktopSttEngineResult(
      engineId: engine.helperEngineId,
      displayName: 'Local Whisper-tiny (command primary)',
      qualityTier: DesktopSttQualityTier.fast,
      rawTranscript: r.text.trim(),
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      supportsGlossary: false,
    );
  }

  static Future<DesktopSttEngineResult?> _tryFallbackParakeet(
    DesktopSttEngineContext ctx,
  ) async {
    final helper = DesktopSttHelperService.instance;
    final engine = DesktopVoiceCommandSttPolicy.fallbackEngine;
    final t0 = DateTime.now();
    final r = await helper.transcribeCaptureForOrchestrator(
      engine: engine,
      pcmBytes: ctx.pcmBytes,
      wavPath: ctx.wavPath,
    );
    if (r == null || r.text.trim().isEmpty) return null;
    return DesktopSttEngineResult(
      engineId: engine.helperEngineId,
      displayName: 'Local Parakeet (fallback)',
      qualityTier: DesktopSttQualityTier.fallback,
      rawTranscript: r.text.trim(),
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      supportsGlossary: false,
    );
  }

  static Future<DesktopSttEngineResult?> _tryWindowsSpeech(
    DesktopSttEngineContext ctx,
  ) async {
    final t0 = DateTime.now();
    final text =
        await DesktopWinSpeechService.instance.transcribeWav(ctx.wavPath);
    if (text == null || text.trim().isEmpty) return null;
    return DesktopSttEngineResult(
      engineId: 'windows_speech',
      displayName: 'Windows Speech Fallback',
      qualityTier: DesktopSttQualityTier.fallback,
      rawTranscript: text.trim(),
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      supportsGlossary: false,
    );
  }
}
