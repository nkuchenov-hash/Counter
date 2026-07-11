import 'package:counter/core/services/desktop_voice_command_normalize.dart';
import 'package:counter/core/services/desktop_voice_contamination_gate.dart';
import 'package:counter/core/services/desktop_voice_glossary.dart';
import 'package:counter/core/services/desktop_voice_recognition_postprocess.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Shared useful-candidate evaluation for widget, helper service, and benchmarks.
class DesktopVoiceUsefulCandidateEvaluation {
  const DesktopVoiceUsefulCandidateEvaluation({
    required this.transcript,
    required this.useful,
    required this.parseStatus,
    required this.contaminationDetected,
    this.contaminationReason,
    this.parseResult,
    this.normalizedTitle,
    this.matchedPath,
    this.pendingEligible = false,
  });

  final String transcript;
  final bool useful;
  final String parseStatus;
  final bool contaminationDetected;
  final String? contaminationReason;
  final VoiceCommandParseResult? parseResult;
  final String? normalizedTitle;
  final String? matchedPath;
  final bool pendingEligible;

  static DesktopVoiceUsefulCandidateEvaluation evaluate({
    required String transcript,
    required List<CategoryRule> categoryRules,
    List<String> taskTitleHints = const [],
    DesktopVoiceGlossaryPack? glossary,
  }) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return const DesktopVoiceUsefulCandidateEvaluation(
        transcript: '',
        useful: false,
        parseStatus: 'empty',
        contaminationDetected: false,
      );
    }

    final pack =
        glossary ?? DesktopVoiceGlossaryPack.buildFromCategoryRules(categoryRules);
    final hints = taskTitleHints.isNotEmpty ? taskTitleHints : pack.taskTitles;

    final post = DesktopVoiceRecognitionPostprocess.apply(
      rawModelText: trimmed,
      glossary: pack,
    );
    final commandText = post.finalCommandText.trim().isNotEmpty
        ? post.finalCommandText.trim()
        : trimmed;

    final gate = DesktopVoiceContaminationGate.evaluate(
      transcript: commandText,
      categoryRules: categoryRules,
    );
    if (gate.detected) {
      return DesktopVoiceUsefulCandidateEvaluation(
        transcript: gate.canonicalTranscript,
        useful: false,
        parseStatus: 'contaminated',
        contaminationDetected: true,
        contaminationReason: gate.reason,
      );
    }

    final canonical = gate.canonicalTranscript;
    final parsed = parseVoiceCommand(
      rules: categoryRules,
      transcript: canonical,
      taskTitleHints: hints,
    );
    final parseStatus =
        '${parsed.confidence.name}${parsed.ambiguityReason == null ? '' : ':${parsed.ambiguityReason}'}';

    final useful = DesktopVoiceContaminationGate.isUsefulCandidate(
      transcript: canonical,
      categoryRules: categoryRules,
      parsed: parsed,
    );

    if (!useful) {
      return DesktopVoiceUsefulCandidateEvaluation(
        transcript: canonical,
        useful: false,
        parseStatus: parseStatus,
        contaminationDetected: false,
        parseResult: parsed,
      );
    }

    final norm = normalizeDesktopVoiceCommand(parsed);
    final pendingEligible =
        norm != null &&
        norm.autoStartAllowed &&
        norm.effectiveResult.confidence == VoiceCommandMatchConfidence.exact &&
        norm.effectiveResult.isSafeToStart;

    return DesktopVoiceUsefulCandidateEvaluation(
      transcript: canonical,
      useful: true,
      parseStatus: parseStatus,
      contaminationDetected: false,
      parseResult: norm?.effectiveResult ?? parsed,
      normalizedTitle: norm?.normalizedTitle ?? parsed.recordTitle,
      matchedPath: parsed.matchedCategoryDisplayPath,
      pendingEligible: pendingEligible,
    );
  }
}

/// Normalized path comparison for SCW DEL MOD benchmark acceptance.
bool desktopVoicePathMatchesScwDelMod(String? path) {
  if (path == null || path.isEmpty) return false;
  final lower = path.toLowerCase();
  return lower.contains('price reporter') &&
      lower.contains('southern') &&
      lower.contains('warehouse') &&
      lower.contains('del mod');
}

bool desktopVoiceTitleIsSubmit(String? title) {
  if (title == null) return false;
  return title.trim().toLowerCase() == 'submit';
}
