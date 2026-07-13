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

int _categoryPathDepth(String? path) {
  if (path == null || path.trim().isEmpty) return 0;
  return path.split('>').map((s) => s.trim()).where((s) => s.isNotEmpty).length;
}

bool _transcriptContainsHint(String lowerTranscript, String hint) {
  final h = hint.toLowerCase();
  if (lowerTranscript.contains(h)) return true;
  if (h == 'del mod') {
    return RegExp(r'\b(still|deal|dell|del)\s+mod(el)?\b')
        .hasMatch(lowerTranscript);
  }
  return false;
}

bool _titleResolvesHint(String titleNorm, String hint) {
  final h = normalizeCategoryLabel(hint);
  if (titleNorm.contains(h)) return true;
  if (h == 'delmod' &&
      RegExp(r'delmod|del mod').hasMatch(titleNorm.replaceAll(' ', ''))) {
    return true;
  }
  return false;
}

bool _pathResolvesHint(String? displayPath, String hint) {
  if (displayPath == null || displayPath.trim().isEmpty) return false;
  final h = normalizeCategoryLabel(hint);
  if (h.isEmpty) return false;
  for (final segment in displayPath.split('>')) {
    final segNorm = normalizeCategoryLabel(segment);
    if (segNorm == h || segNorm.contains(h) || h.contains(segNorm)) {
      return true;
    }
  }
  return false;
}

/// Unresolved command tokens in transcript but not in record title → block write.
bool _hasUnresolvedCommandTokens(
  String transcript,
  VoiceCommandParseResult parsed,
) {
  const hints = ['del mod', 'add mod', 'add sin', 'planning', 'submit'];
  final lower = transcript.toLowerCase();
  final titleNorm = normalizeCategoryLabel(parsed.recordTitle);
  for (final hint in hints) {
    if (_transcriptContainsHint(lower, hint) &&
        !_titleResolvesHint(titleNorm, hint) &&
        !_pathResolvesHint(parsed.matchedCategoryDisplayPath, hint)) {
      return true;
    }
  }
  return false;
}

/// Parent-only echo: record title repeats category leaf with no distinct task.
bool _isParentOnlyCategoryEcho(VoiceCommandParseResult parsed) {
  final path = parsed.matchedCategoryDisplayPath?.trim() ?? '';
  if (path.isEmpty) return false;
  final segments =
      path.split('>').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return false;
  final leafNorm = normalizeCategoryLabel(segments.last);
  final titleNorm = normalizeCategoryLabel(parsed.recordTitle);
  if (titleNorm.isEmpty) return false;
  if (titleNorm == leafNorm) return true;
  if (leafNorm.contains(titleNorm) && titleNorm.length >= 10) return true;
  return false;
}

bool _isIntentionalCategoryStart(
  String transcript,
  VoiceCommandParseResult parsed,
) {
  if (!_isParentOnlyCategoryEcho(parsed)) return false;
  final path = parsed.matchedCategoryDisplayPath?.trim() ?? '';
  if (path.isEmpty) return false;
  final segments =
      path.split('>').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return false;
  final leaf = segments.last;
  final leafNorm = normalizeCategoryLabel(leaf);
  if (leafNorm.isEmpty) return false;
  final lower = transcript.toLowerCase();
  final pathLower = path.toLowerCase();

  // Client warehouse echo without a task token is garbage, not navigation.
  if (leafNorm.contains('warehouse') &&
      !RegExp(r'\bdel\s*mod\b|\bdelmod\b|\bsubmit\b', caseSensitive: false)
          .hasMatch(lower)) {
    return false;
  }

  if (pathLower.contains('price reporter')) {
    return leafNorm == 'planning' && lower.contains('planning');
  }
  if (pathLower.contains('blink')) {
    return lower.contains('blink') || lower.contains('laredo');
  }
  if (leafNorm.contains('laredo')) {
    return lower.contains('laredo');
  }

  if (lower.contains(leafNorm)) return true;
  final leafWords = leaf.toLowerCase().split(RegExp(r'\s+'));
  var hits = 0;
  for (final w in leafWords) {
    if (w.length >= 4 && lower.contains(w)) hits++;
  }
  return hits >= 2 || (hits == 1 && leafWords.length == 1);
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

  final transcript = parsed.originalTranscript.trim();
  if (_isParentOnlyCategoryEcho(parsed) &&
      !_isIntentionalCategoryStart(transcript, parsed)) {
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_PARENT_ONLY_RECORD_BLOCKED',
      parsed.matchedCategoryDisplayPath ?? parsed.rootLabel,
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_GARBAGE_RECORD');
    return null;
  }

  if (_hasUnresolvedCommandTokens(transcript, parsed) &&
      _categoryPathDepth(parsed.matchedCategoryDisplayPath) < 4) {
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_PARENT_ONLY_RECORD_BLOCKED_WITH_UNRESOLVED_TOKENS',
      parsed.matchedCategoryDisplayPath ?? parsed.rootLabel,
    );
    DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_GARBAGE_RECORD');
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
