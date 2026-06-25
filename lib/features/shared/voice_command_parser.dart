import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/price_reporter_client_match.dart';

/// Deterministic structured desktop voice command parser (Price Reporter MVP).
///
/// Example: `Price Reporter AGE SOLUTIONS ADD MOD` → client category + task title.
/// Does not call AI or create categories.
enum VoiceCommandMatchConfidence {
  exact,
  ambiguous,
  noMatch,
}

class VoiceCommandParseResult {
  const VoiceCommandParseResult({
    required this.rootLabel,
    required this.matchedCategoryPocketBaseId,
    required this.matchedCategoryDisplayPath,
    required this.matchedLocalCategoryId,
    required this.recordTitle,
    required this.confidence,
    required this.originalTranscript,
    this.ambiguityReason,
    this.ambiguousCandidates = const [],
  });

  final String rootLabel;
  final String? matchedCategoryPocketBaseId;
  final String? matchedCategoryDisplayPath;
  final int? matchedLocalCategoryId;
  final String recordTitle;
  final VoiceCommandMatchConfidence confidence;
  final String originalTranscript;
  final String? ambiguityReason;
  final List<String> ambiguousCandidates;

  bool get isSafeToStart =>
      confidence == VoiceCommandMatchConfidence.exact &&
      (matchedLocalCategoryId ?? 0) > 0 &&
      (matchedCategoryPocketBaseId ?? '').trim().isNotEmpty &&
      recordTitle.trim().isNotEmpty;
}

/// One matchable client row under the Price Reporter root.
class VoiceCommandCategoryCandidate {
  const VoiceCommandCategoryCandidate({
    required this.localCategoryId,
    required this.pocketBaseId,
    required this.displayName,
    required this.displayPath,
    required this.normalizedPhrases,
  });

  final int localCategoryId;
  final String pocketBaseId;
  final String displayName;
  final String displayPath;

  /// Longest-first prefix aliases (normalized tokens, space-separated).
  final List<String> normalizedPhrases;
}

/// In-memory index for [parsePriceReporterVoiceCommand].
class VoiceCommandCategoryIndex {
  const VoiceCommandCategoryIndex({
    required this.rootLabel,
    required this.rootPocketBaseId,
    required this.rootLocalCategoryId,
    required this.candidates,
  });

  final String rootLabel;
  final String rootPocketBaseId;
  final int rootLocalCategoryId;
  final List<VoiceCommandCategoryCandidate> candidates;

  static const String kDefaultRootPhrase = 'price reporter';

  /// Builds index from loaded [CategoryRule] tree (no network).
  static VoiceCommandCategoryIndex? fromCategoryRules(List<CategoryRule> rules) {
    CategoryRule? root;
    void findRoot(List<CategoryRule> nodes) {
      for (final r in nodes) {
        if (r.isArchived) continue;
        if (normalizeCategoryLabel(r.name) == kDefaultRootPhrase) {
          root = r;
          return;
        }
        if (r.children != null) findRoot(r.children!);
        if (root != null) return;
      }
    }

    findRoot(rules);
    final rootRule = root;
    if (rootRule == null) return null;
    final rootPb = (rootRule.backendRowId ?? '').trim();
    if (rootPb.isEmpty) return null;

    final candidates = <VoiceCommandCategoryCandidate>[];

    void collectPhrases(CategoryRule rule, List<String> pathParts) {
      if (rule.isArchived) return;
      final pb = (rule.backendRowId ?? '').trim();
      final isRoot = rule.id == rootRule.id;
      if (!isRoot && pb.isNotEmpty) {
        final phrases = <String>{};
        void addPhrase(String raw) {
          final n = normalizeCategoryLabel(raw);
          if (n.isEmpty) return;
          if (kPriceReporterGenericTaskTokens.contains(n) &&
              n != normalizeCategoryLabel(rule.name)) {
            return;
          }
          phrases.add(n);
        }

        addPhrase(rule.name);
        final normId = (rule.normalizedId ?? '').trim();
        if (normId.isNotEmpty) addPhrase(normId);
        if (rule.localizedNames != null) {
          for (final v in rule.localizedNames!.values) {
            addPhrase(v);
          }
        }
        if (rule.keywords != null) {
          for (final list in rule.keywords!.values) {
            for (final kw in list) {
              addPhrase(kw);
            }
          }
        }
        final path = [...pathParts, rule.name.trim()].join(' > ');
        final sortedPhrases = phrases.toList()
          ..sort((a, b) => b.length.compareTo(a.length));
        candidates.add(
          VoiceCommandCategoryCandidate(
            localCategoryId: rule.id,
            pocketBaseId: pb,
            displayName: rule.name.trim(),
            displayPath: path,
            normalizedPhrases: sortedPhrases,
          ),
        );
      }
      final kids = rule.children;
      if (kids == null) return;
      final nextPath = isRoot
          ? [rootRule.name.trim()]
          : [...pathParts, rule.name.trim()];
      for (final c in kids) {
        collectPhrases(c, nextPath);
      }
    }

    collectPhrases(rootRule, []);
    return VoiceCommandCategoryIndex(
      rootLabel: rootRule.name.trim(),
      rootPocketBaseId: rootPb,
      rootLocalCategoryId: rootRule.id,
      candidates: candidates,
    );
  }
}

bool _isLikelyPocketBaseRowId(String id) {
  final t = id.trim();
  return t.length == 15 && RegExp(r'^[a-z0-9]+$').hasMatch(t);
}

String _stripNormalizedPrefixTokens(String raw, String normalizedPhrase) {
  final phraseTokens =
      normalizedPhrase.split(' ').where((t) => t.isNotEmpty).toList();
  if (phraseTokens.isEmpty) return raw.trim();
  final rawTokens =
      raw.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (rawTokens.length < phraseTokens.length) return raw.trim();
  for (var i = 0; i < phraseTokens.length; i++) {
    if (normalizeCategoryLabel(rawTokens[i]) != phraseTokens[i]) {
      return raw.trim();
    }
  }
  return rawTokens.skip(phraseTokens.length).join(' ').trim();
}

/// Normalized command-scope prefixes (longest match wins in [_extractAfterRootScope]).
const List<String> kPriceReporterScopeNormPrefixes = [
  'price reporter',
  'price report',
  'press reporter',
  'prize reporter',
  'price rep',
  'right reporter',
  'rice reporter',
  'райс репортер',
  'прайс репортер',
  'райсфер',
  'присрепорт',
];

/// Repairs common local-STT mis-hearings before deterministic parsing.
String repairVoiceCommandTranscript(String transcript) {
  var t = transcript.trim();
  if (t.isEmpty) return t;
  final replacements = <RegExp, String>{
    RegExp(r'\bprice\s+reporters?\b', caseSensitive: false): 'Price Reporter',
    RegExp(r'\bprice\s+report\b', caseSensitive: false): 'Price Reporter',
    RegExp(r'\bpress\s+reporter\b', caseSensitive: false): 'Price Reporter',
    RegExp(r'\bprize\s+reporter\b', caseSensitive: false): 'Price Reporter',
    RegExp(r'\bright\s+reporter\b', caseSensitive: false): 'Price Reporter',
    RegExp(r'\brice\s+reporter\b', caseSensitive: false): 'Price Reporter',
    RegExp(r'\bprice\s+rep\b', caseSensitive: false): 'Price Reporter',
    RegExp(r'\bрайс\s*репорт\w*\b', caseSensitive: false, unicode: true):
        'Price Reporter',
    RegExp(r'\bпрайс\s*репорт\w*\b', caseSensitive: false, unicode: true):
        'Price Reporter',
    RegExp(r'\bрайсфер\b', caseSensitive: false, unicode: true): 'Price Reporter',
    RegExp(
      r'\bприсрепорт\b',
      caseSensitive: false,
      unicode: true,
    ): 'Price Reporter',
  };
  for (final entry in replacements.entries) {
    t = t.replaceAll(entry.key, entry.value);
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// STT mis-hearings for record titles after Price Reporter scope (constrained grammar).
const Map<String, String> kPriceReporterTitleSttAliases = {
  'play': 'Planning',
  'plane': 'Planning',
  'playing': 'Planning',
  'planning': 'Planning',
};

String repairPriceReporterRecordTitle(String rawTitle) {
  var title = rawTitle.trim();
  if (title.isEmpty) return title;
  title = title.replaceAll(RegExp(r'[.,!?;:]+$'), '').trim();
  final norm = normalizeCategoryLabel(title);
  final alias = kPriceReporterTitleSttAliases[norm];
  if (alias != null) return alias;
  return title;
}

/// True when transcript likely targets the Price Reporter command route.
bool transcriptMentionsPriceReporter(String transcript) {
  final norm = normalizeCategoryLabel(repairVoiceCommandTranscript(transcript));
  if (norm.isEmpty) return false;
  for (final prefix in kPriceReporterScopeNormPrefixes) {
    if (norm == prefix || norm.startsWith('$prefix ')) return true;
  }
  return false;
}

/// User-facing confirmation after a voice-started record (EN/RU templates).
String voiceCommandStartConfirmationMessage(
  VoiceCommandParseResult result, {
  required String localeCode,
}) {
  final path =
      (result.matchedCategoryDisplayPath ?? result.rootLabel).trim();
  final title = result.recordTitle.trim();
  if (localeCode == 'ru') {
    return 'Запущено: $path — $title';
  }
  return 'Started: $path — $title';
}

/// User-facing confirmation after hotkey stop of a running record (EN/RU templates).
String voiceCommandStopConfirmationMessage({
  String? path,
  required String title,
  required String localeCode,
}) {
  final titleTrim = title.trim();
  if (localeCode == 'ru') {
    return titleTrim.isEmpty ? 'Остановлено' : 'Остановлено: $titleTrim';
  }
  return titleTrim.isEmpty ? 'Stopped' : 'Stopped: $titleTrim';
}

/// Generic voice command entry — Price Reporter route when scope detected.
VoiceCommandParseResult parseVoiceCommand({
  required List<CategoryRule> rules,
  required String transcript,
}) {
  final repaired = repairVoiceCommandTranscript(transcript);
  if (!transcriptMentionsPriceReporter(repaired)) {
    return VoiceCommandParseResult(
      rootLabel: '',
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: repaired,
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: transcript.trim(),
      ambiguityReason: 'unsupported_command',
    );
  }
  final index = VoiceCommandCategoryIndex.fromCategoryRules(rules);
  if (index == null) {
    return VoiceCommandParseResult(
      rootLabel: VoiceCommandCategoryIndex.kDefaultRootPhrase,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: repaired,
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: transcript.trim(),
      ambiguityReason: 'price_reporter_root_not_found',
    );
  }
  return parsePriceReporterVoiceCommand(index: index, transcript: repaired);
}

/// Maps internal parser reason codes to l10n keys (never show raw codes in UI).
String voiceCommandReasonL10nKey(String? reason) {
  switch (reason) {
    case 'missing_root_scope':
      return 'desktop_voice_reason_no_root';
    case 'no_client_match':
      return 'desktop_voice_reason_no_client';
    case 'ambiguous_client_prefix':
      return 'desktop_voice_reason_ambiguous_client';
    case 'missing_record_title':
      return 'desktop_voice_reason_no_title';
    case 'missing_client_and_title':
      return 'desktop_voice_reason_no_client_title';
    case 'empty_transcript':
      return 'desktop_voice_no_speech';
    case 'invalid_category_pb_id':
      return 'desktop_voice_reason_invalid_category';
    case 'price_reporter_root_not_found':
      return 'desktop_voice_no_price_reporter';
    case 'unsupported_command':
      return 'desktop_voice_reason_unsupported';
    default:
      return 'desktop_voice_no_match';
  }
}

bool _normTokenSequenceMatchesAt(
  List<String> normTokens,
  int start,
  List<String> wantTokens,
) {
  if (start + wantTokens.length > normTokens.length) return false;
  for (var j = 0; j < wantTokens.length; j++) {
    final got = normTokens[start + j];
    final want = wantTokens[j];
    if (got == want) continue;
    // Allow STT truncation on last scope token (report vs reporter).
    if (j == wantTokens.length - 1 && want.startsWith(got) && got.length >= 4) {
      continue;
    }
    return false;
  }
  return true;
}

String? _extractAfterRootScope(String original, VoiceCommandCategoryIndex index) {
  final repaired = repairVoiceCommandTranscript(original);
  final normFull = normalizeCategoryLabel(repaired);
  if (normFull.isEmpty) return null;

  final normTokens = normFull.split(' ').where((t) => t.isNotEmpty).toList();
  final rawTokens = repaired.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (normTokens.isEmpty || rawTokens.isEmpty) return null;

  final scopePrefixes = <List<String>>[
  ...kPriceReporterScopeNormPrefixes.map(
    (p) => p.split(' ').where((t) => t.isNotEmpty).toList(),
  ),
    normalizeCategoryLabel(index.rootLabel)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList(),
  ]..sort((a, b) => b.length.compareTo(a.length));

  for (final prefixTokens in scopePrefixes) {
    if (prefixTokens.isEmpty) continue;
    if (normTokens.length < prefixTokens.length) continue;
    for (var i = 0; i <= normTokens.length - prefixTokens.length; i++) {
      if (!_normTokenSequenceMatchesAt(normTokens, i, prefixTokens)) continue;
      final skip = i + prefixTokens.length;
      if (skip >= rawTokens.length) return '';
      return rawTokens.skip(skip).join(' ').trim();
    }
  }
  return null;
}

/// Parses a structured Price Reporter voice command against [index].
VoiceCommandParseResult parsePriceReporterVoiceCommand({
  required VoiceCommandCategoryIndex index,
  required String transcript,
}) {
  final original = repairVoiceCommandTranscript(transcript).trim();
  if (original.isEmpty) {
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: '',
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'empty_transcript',
    );
  }

  final afterRoot = _extractAfterRootScope(original, index);
  if (afterRoot == null) {
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: original,
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'missing_root_scope',
    );
  }

  if (afterRoot.isEmpty) {
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: '',
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'missing_client_and_title',
    );
  }

  final normAfter = normalizeCategoryLabel(afterRoot);
  final hits = <({VoiceCommandCategoryCandidate c, String phrase})>[];
  for (final candidate in index.candidates) {
    for (final phrase in candidate.normalizedPhrases) {
      if (phrase.isEmpty) continue;
      if (!normAfter.startsWith(phrase)) continue;
      if (normAfter.length > phrase.length && normAfter[phrase.length] != ' ') {
        continue;
      }
      hits.add((c: candidate, phrase: phrase));
    }
  }

  if (hits.isEmpty) {
    final title = repairPriceReporterRecordTitle(afterRoot.trim());
    if (title.isEmpty) {
      return VoiceCommandParseResult(
        rootLabel: index.rootLabel,
        matchedCategoryPocketBaseId: null,
        matchedCategoryDisplayPath: null,
        matchedLocalCategoryId: null,
        recordTitle: '',
        confidence: VoiceCommandMatchConfidence.noMatch,
        originalTranscript: original,
        ambiguityReason: 'missing_client_and_title',
      );
    }
    if (!_isLikelyPocketBaseRowId(index.rootPocketBaseId)) {
      return VoiceCommandParseResult(
        rootLabel: index.rootLabel,
        matchedCategoryPocketBaseId: null,
        matchedCategoryDisplayPath: index.rootLabel,
        matchedLocalCategoryId: null,
        recordTitle: title,
        confidence: VoiceCommandMatchConfidence.noMatch,
        originalTranscript: original,
        ambiguityReason: 'invalid_category_pb_id',
      );
    }
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: index.rootPocketBaseId,
      matchedCategoryDisplayPath: index.rootLabel,
      matchedLocalCategoryId: index.rootLocalCategoryId,
      recordTitle: title,
      confidence: VoiceCommandMatchConfidence.exact,
      originalTranscript: original,
    );
  }

  hits.sort((a, b) => b.phrase.length.compareTo(a.phrase.length));
  final longest = hits.first.phrase.length;
  final atLongest =
      hits.where((h) => h.phrase.length == longest).toList(growable: false);
  final clientIds = atLongest.map((h) => h.c.localCategoryId).toSet();
  if (clientIds.length > 1) {
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: afterRoot,
      confidence: VoiceCommandMatchConfidence.ambiguous,
      originalTranscript: original,
      ambiguityReason: 'ambiguous_client_prefix',
      ambiguousCandidates: atLongest.map((h) => h.c.displayPath).toSet().toList(),
    );
  }

  final winner = atLongest.first;
  final client = winner.c;
  if (!_isLikelyPocketBaseRowId(client.pocketBaseId)) {
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: client.displayPath,
      matchedLocalCategoryId: null,
      recordTitle: afterRoot,
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'invalid_category_pb_id',
    );
  }

  var recordTitle =
      repairPriceReporterRecordTitle(_stripNormalizedPrefixTokens(afterRoot, winner.phrase).trim());
  if (recordTitle.isEmpty) {
    recordTitle = client.displayName.trim();
  }
  if (recordTitle.isEmpty) {
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: client.pocketBaseId,
      matchedCategoryDisplayPath: client.displayPath,
      matchedLocalCategoryId: client.localCategoryId,
      recordTitle: '',
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'missing_record_title',
    );
  }

  return VoiceCommandParseResult(
    rootLabel: index.rootLabel,
    matchedCategoryPocketBaseId: client.pocketBaseId,
    matchedCategoryDisplayPath: client.displayPath,
    matchedLocalCategoryId: client.localCategoryId,
    recordTitle: recordTitle,
    confidence: VoiceCommandMatchConfidence.exact,
    originalTranscript: original,
  );
}
