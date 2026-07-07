import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Raw STT quality evaluation — postprocess/alias must not count as recognition quality.
abstract final class DesktopSttQualityEvaluation {
  static const sttQualityMode = 'raw_transcript_evaluation';
  static const aliasPostprocessUsedForQuality = false;

  static void markRawEvaluationStarted() {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_STT_QUALITY_EVALUATION');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_POSTPROCESS_NOT_COUNTED_AS_STT_QUALITY');
  }

  static void logRawFinalSttText(String rawFinalText) {
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_RAW_FINAL_STT_TEXT_LOGGED',
      rawFinalText,
    );
  }

  static void logPostprocessDelta({
    required String rawModelText,
    required String postprocessedText,
  }) {
    if (rawModelText.trim().toLowerCase() ==
        postprocessedText.trim().toLowerCase()) {
      return;
    }
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_POSTPROCESS_CHANGED_TEXT',
      'raw="$rawModelText" post="$postprocessedText"',
    );
  }
}
