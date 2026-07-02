import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Final gate before [DatabaseService.writeRecord] — prefer no record over wrong record.
class DesktopVoiceNormalizedCommand {
  const DesktopVoiceNormalizedCommand({
    required this.rawTranscript,
    required this.matchedRoot,
    required this.matchedClientPath,
    required this.rawTitle,
    required this.normalizedTitle,
    required this.confidence,
    required this.autoStartAllowed,
    required this.effectiveResult,
  });

  final String rawTranscript;
  final String matchedRoot;
  final String? matchedClientPath;
  final String rawTitle;
  final String normalizedTitle;
  final VoiceCommandMatchConfidence confidence;
  final bool autoStartAllowed;
  final VoiceCommandParseResult effectiveResult;
}

/// Planning title near-misses — only repaired inside Price Reporter command scope.
const Set<String> kPriceReporterPlanningNearMissNorm = {
  'plenty',
  'plentie',
  'planing',
  'plaming',
  'plan',
  'play',
  'playing',
  'plane',
  'planning',
};

bool _mustBlockUnnormalizedTitle(String rawTitle, String normalizedTitle) {
  final rawNorm = normalizeCategoryLabel(rawTitle);
  if (rawNorm.isEmpty) return true;
  if (kPriceReporterPlanningNearMissNorm.contains(rawNorm) &&
      normalizedTitle != 'Planning') {
    return true;
  }
  return false;
}

VoiceCommandParseResult _withNormalizedTitle(
  VoiceCommandParseResult parsed,
  String normalizedTitle,
) {
  return VoiceCommandParseResult(
    rootLabel: parsed.rootLabel,
    matchedCategoryPocketBaseId: parsed.matchedCategoryPocketBaseId,
    matchedCategoryDisplayPath: parsed.matchedCategoryDisplayPath,
    matchedLocalCategoryId: parsed.matchedLocalCategoryId,
    recordTitle: normalizedTitle,
    confidence: parsed.confidence,
    originalTranscript: parsed.originalTranscript,
    ambiguityReason: parsed.ambiguityReason,
    ambiguousCandidates: parsed.ambiguousCandidates,
  );
}

/// Applies Price Reporter title repairs and blocks low-confidence / suspicious commands.
DesktopVoiceNormalizedCommand? normalizeDesktopVoiceCommand(
  VoiceCommandParseResult parsed,
) {
  DesktopVoicePipeline.mark('DESKTOP_VOICE_COMMAND_NORMALIZATION_STARTED');

  // Multi-scope: a parsed result is "in scope" when the parser actually matched
  // a known category (any root, not only Price Reporter). The previous Price
  // Reporter-only gate would silently drop Laredo / other valid commands.
  final inScope = parsed.confidence != VoiceCommandMatchConfidence.noMatch ||
      (parsed.matchedCategoryPocketBaseId ?? '').isNotEmpty;
  if (!inScope) {
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COMMAND_BLOCKED_LOW_CONFIDENCE',
      'out_of_scope',
    );
    return null;
  }

  if (parsed.confidence != VoiceCommandMatchConfidence.exact ||
      !parsed.isSafeToStart) {
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COMMAND_BLOCKED_LOW_CONFIDENCE',
      parsed.ambiguityReason ?? parsed.confidence.name,
    );
    return null;
  }

  final rawTitle = parsed.recordTitle.trim();
  final normalizedTitle = repairPriceReporterRecordTitle(rawTitle);

  if (_mustBlockUnnormalizedTitle(rawTitle, normalizedTitle)) {
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COMMAND_BLOCKED_LOW_CONFIDENCE',
      'unmapped_title:$rawTitle',
    );
    return null;
  }

  final effective = normalizedTitle == rawTitle
      ? parsed
      : _withNormalizedTitle(parsed, normalizedTitle);

  if (!effective.isSafeToStart) {
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COMMAND_BLOCKED_LOW_CONFIDENCE',
      'unsafe_after_normalize',
    );
    return null;
  }

  DesktopVoicePipeline.mark(
    'DESKTOP_VOICE_COMMAND_NORMALIZED',
    normalizedTitle,
  );

  return DesktopVoiceNormalizedCommand(
    rawTranscript: parsed.originalTranscript,
    matchedRoot: parsed.rootLabel,
    matchedClientPath: parsed.matchedCategoryDisplayPath,
    rawTitle: rawTitle,
    normalizedTitle: normalizedTitle,
    confidence: parsed.confidence,
    autoStartAllowed: true,
    effectiveResult: effective,
  );
}
