import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Logs fragment provenance for offline corruption diagnosis.
class DesktopVoiceTranscriptProvenanceEntry {
  const DesktopVoiceTranscriptProvenanceEntry({
    required this.fragment,
    required this.sourceType,
    this.voiceSessionId,
    this.mergeOperation,
    this.reason,
  });

  final String fragment;
  final String sourceType;
  final String? voiceSessionId;
  final String? mergeOperation;
  final String? reason;
}

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
      'provenance_fragment',
      '$sourceType:$fragment',
    );
    if (voiceSessionId != null) {
      DesktopVoicePipeline.mark('provenance_session_id', voiceSessionId);
    }
    if (mergeOperation != null) {
      DesktopVoicePipeline.mark('provenance_merge_op', mergeOperation);
    }
    if (reason != null) {
      DesktopVoicePipeline.mark('provenance_reason', reason);
    }
  }

  static void logAttemptSummary({
    required String? partialText,
    required String? finalText,
    required String? cachedCandidate,
    required String? effectiveInitialPrompt,
    required String? postprocessedText,
    required String? parserInput,
    required String? parserPath,
    required String? parserTitle,
    required String? voiceSessionId,
  }) {
    DesktopVoicePipeline.mark(markerLogged);
    if (effectiveInitialPrompt != null) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_EFFECTIVE_INITIAL_PROMPT_LOGGED',
      );
      DesktopVoicePipeline.mark('effective_initial_prompt', effectiveInitialPrompt);
    }
    if (partialText != null && partialText.trim().isNotEmpty) {
      logFragment(
        fragment: partialText,
        sourceType: 'partial',
        voiceSessionId: voiceSessionId,
        mergeOperation: 'replace',
      );
    }
    if (finalText != null && finalText.trim().isNotEmpty) {
      logFragment(
        fragment: finalText,
        sourceType: 'final',
        voiceSessionId: voiceSessionId,
        mergeOperation: 'replace',
        reason: 'authoritative',
      );
    }
    if (cachedCandidate != null && cachedCandidate.trim().isNotEmpty) {
      logFragment(
        fragment: cachedCandidate,
        sourceType: 'cached_useful_candidate',
        voiceSessionId: voiceSessionId,
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
    if (parserPath != null) {
      DesktopVoicePipeline.mark('parser_path', parserPath);
    }
    if (parserTitle != null) {
      DesktopVoicePipeline.mark('generated_title', parserTitle);
    }
    final lower = (finalText ?? partialText ?? '').toLowerCase();
    if (lower.contains('technical marketing')) {
      DesktopVoicePipeline.mark(markerTechnicalMarketing, 'final_or_partial');
    }
    if (RegExp(r'\btaxis\b').allMatches(lower).length > 1) {
      DesktopVoicePipeline.mark(markerDuplicateTaxis, 'transcript');
    }
  }
}
