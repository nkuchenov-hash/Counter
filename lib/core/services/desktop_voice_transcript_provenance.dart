import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Logs transcript fragment provenance for offline failure diagnosis.
abstract final class DesktopVoiceTranscriptProvenance {
  static const markerLogged = 'DESKTOP_VOICE_TRANSCRIPT_PROVENANCE_LOGGED';
  static const markerTechnicalMarketing =
      'DESKTOP_VOICE_TECHNICAL_MARKETING_SOURCE_IDENTIFIED';
  static const markerDuplicateTaxis =
      'DESKTOP_VOICE_DUPLICATE_TAXIS_SOURCE_IDENTIFIED';

  static void logFragment({
    required String fragment,
    required String sourceType,
    String? voiceSessionId,
    String? mergeOperation,
    String? reason,
  }) {
    DesktopVoicePipeline.mark(
      'transcript_fragment',
      '$fragment|source=$sourceType'
      '${voiceSessionId == null ? '' : '|session=$voiceSessionId'}'
      '${mergeOperation == null ? '' : '|merge=$mergeOperation'}'
      '${reason == null ? '' : '|reason=$reason'}',
    );
  }

  static void logAttempt({
    required String? partialText,
    required String? finalText,
    required String? effectiveInitialPrompt,
    required String? postprocessedText,
    required String? parserInput,
    required String? parserTitle,
    required String? selectedPath,
    String? voiceSessionId,
    String? helperSessionId,
  }) {
    DesktopVoicePipeline.mark(markerLogged);
    if (effectiveInitialPrompt != null) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_EFFECTIVE_INITIAL_PROMPT_LOGGED',
        effectiveInitialPrompt,
      );
    }
    if (partialText != null && partialText.trim().isNotEmpty) {
      logFragment(
        fragment: partialText.trim(),
        sourceType: 'partial',
        voiceSessionId: voiceSessionId,
        mergeOperation: 'replace',
      );
    }
    if (finalText != null && finalText.trim().isNotEmpty) {
      logFragment(
        fragment: finalText.trim(),
        sourceType: 'final',
        voiceSessionId: voiceSessionId,
        mergeOperation: 'replace',
        reason: 'authoritative',
      );
    }
    if (postprocessedText != null) {
      logFragment(
        fragment: postprocessedText,
        sourceType: 'postprocess',
        voiceSessionId: voiceSessionId,
      );
    }
    if (parserInput != null) {
      DesktopVoicePipeline.mark('parser_input', parserInput);
    }
    if (parserTitle != null) {
      DesktopVoicePipeline.mark('generated_title', parserTitle);
    }
    if (selectedPath != null) {
      DesktopVoicePipeline.mark('selected_path', selectedPath);
    }
  }

  static void traceCorruptedLogicalMarketing({
    required String finalText,
    String? partialText,
    String? initialPrompt,
  }) {
    final lower = finalText.toLowerCase();
    if (lower.contains('technical marketing')) {
      DesktopVoicePipeline.mark(
        markerTechnicalMarketing,
        initialPrompt == null ? 'whisper_final' : 'prompt_bias_or_whisper',
      );
      logFragment(
        fragment: 'Technical Marketing',
        sourceType: initialPrompt != null &&
                initialPrompt.toLowerCase().contains('technical marketing')
            ? 'initial_prompt'
            : 'final',
        reason: 'unsourced_insertion',
      );
    }
    if (RegExp(r'\btaxis\b').allMatches(lower).length > 1) {
      DesktopVoicePipeline.mark(markerDuplicateTaxis, 'duplicate_in_final');
      logFragment(
        fragment: 'Taxis',
        sourceType: partialText?.toLowerCase().contains('taxis') == true
            ? 'partial'
            : 'final',
        reason: 'duplicate_segment',
      );
    }
  }
}
