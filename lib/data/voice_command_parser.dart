import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/price_reporter_client_match.dart';

/// Deterministic structured desktop voice command parser.
///
/// Multi-scope: any top-level app category (Price Reporter, Laredo Technical
/// Services, …) becomes a recognisable command scope via its own name /
/// keywords / localized names. Example:
/// - `Price Reporter AGE SOLUTIONS ADD MOD` → client category + task title.
/// - `Laredo TS ADD SIN` → Laredo Technical Services category + `ADD SIN` task.
///
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

/// In-memory index for [parseScopedVoiceCommand]. Multi-scope: each top-level
/// (non-archived) category with a PocketBase id becomes a recognised command
/// scope using its own name + keywords + localized names as alias phrases.
class VoiceCommandCategoryIndex {
  const VoiceCommandCategoryIndex({
    required this.roots,
  });

  /// All recognised top-level scopes (Price Reporter, Laredo Technical
  /// Services, …). Order is not significant; longest-match wins at parse time.
  final List<VoiceCommandCategoryScope> roots;

  /// Back-compat: first scope whose normalised label is the canonical Price
  /// Reporter root (used by [parsePriceReporterVoiceCommand] callers and tests).
  static const String kDefaultRootPhrase = 'price reporter';

  /// Convenience: the Price Reporter scope, or `null` when not present.
  VoiceCommandCategoryScope? get priceReporterScope {
    for (final s in roots) {
      if (s.rootLabelNormalised == kDefaultRootPhrase) return s;
    }
    return null;
  }

  /// Builds index from loaded [CategoryRule] tree (no network). Returns `null`
  /// when no usable top-level scope exists.
  static VoiceCommandCategoryIndex? fromCategoryRules(List<CategoryRule> rules) {
    final scopes = <VoiceCommandCategoryScope>[];
    void collectRoots(List<CategoryRule> nodes) {
      for (final r in nodes) {
        if (r.isArchived) continue;
        final pb = (r.backendRowId ?? '').trim();
        if (pb.isEmpty) {
          // Recurse into wrapper folders without backend id of their own.
          if (r.children != null) collectRoots(r.children!);
          continue;
        }
        final scope = _buildScopeFromRootRule(r);
        if (scope != null) scopes.add(scope);
      }
    }

    collectRoots(rules);
    // Stable order: Price Reporter first (canonical), then alphabetical.
    scopes.sort((a, b) {
      final aIsPr = a.rootLabelNormalised == kDefaultRootPhrase ? 0 : 1;
      final bIsPr = b.rootLabelNormalised == kDefaultRootPhrase ? 0 : 1;
      if (aIsPr != bIsPr) return aIsPr - bIsPr;
      return a.rootLabelNormalised.compareTo(b.rootLabelNormalised);
    });
    if (scopes.isEmpty) return null;
    return VoiceCommandCategoryIndex(roots: scopes);
  }

  static VoiceCommandCategoryScope? _buildScopeFromRootRule(CategoryRule root) {
    final rootPb = (root.backendRowId ?? '').trim();
    if (rootPb.isEmpty) return null;
    final candidates = <VoiceCommandCategoryCandidate>[];

    void collectPhrases(CategoryRule rule, List<String> pathParts, bool isRoot) {
      if (rule.isArchived) return;
      final pb = (rule.backendRowId ?? '').trim();
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
      final nextPath =
          isRoot ? [root.name.trim()] : [...pathParts, rule.name.trim()];
      for (final c in kids) {
        collectPhrases(c, nextPath, false);
      }
    }

    collectPhrases(root, [], true);

    // Root phrase set: name + normalizedId + localized names + keywords + STT
    // aliases from [kCategoryScopeSttAliases] that map to this root name.
    final rootPhrases = <String>{};
    final rootNorm = normalizeCategoryLabel(root.name);
    if (rootNorm.isNotEmpty) rootPhrases.add(rootNorm);
    final rootNormId = (root.normalizedId ?? '').trim();
    if (rootNormId.isNotEmpty) rootPhrases.add(normalizeCategoryLabel(rootNormId));
    if (root.localizedNames != null) {
      for (final v in root.localizedNames!.values) {
        final n = normalizeCategoryLabel(v);
        if (n.isNotEmpty) rootPhrases.add(n);
      }
    }
    if (root.keywords != null) {
      for (final list in root.keywords!.values) {
        for (final kw in list) {
          final n = normalizeCategoryLabel(kw);
          if (n.isNotEmpty) rootPhrases.add(n);
        }
      }
    }
    // Inject the scope name from canonical STT aliases (e.g. "laredo technical
    // services" is the canonical name; "laredo ts" abbreviations repair into it
    // in repairVoiceCommandTranscript, so we don't need them here as separate
    // phrases — they match the repaired name).
    final canonicalForAliases = normalizeCategoryLabel(root.name);
    kCategoryScopeSttAliases.forEach((alias, canonical) {
      if (normalizeCategoryLabel(canonical) == canonicalForAliases) {
        rootPhrases.add(normalizeCategoryLabel(alias));
      }
    });

    final sortedRootPhrases = rootPhrases.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    return VoiceCommandCategoryScope(
      rootRule: root,
      rootLabel: root.name.trim(),
      rootLabelNormalised: rootNorm,
      rootPocketBaseId: rootPb,
      rootLocalCategoryId: root.id,
      rootNormalizedPhrases: sortedRootPhrases,
      candidates: candidates,
    );
  }
}

/// One top-level command scope (e.g. Price Reporter, Laredo Technical Services).
class VoiceCommandCategoryScope {
  const VoiceCommandCategoryScope({
    required this.rootRule,
    required this.rootLabel,
    required this.rootLabelNormalised,
    required this.rootPocketBaseId,
    required this.rootLocalCategoryId,
    required this.rootNormalizedPhrases,
    required this.candidates,
  });

  final CategoryRule rootRule;
  final String rootLabel;
  final String rootLabelNormalised;
  final String rootPocketBaseId;
  final int rootLocalCategoryId;
  final List<String> rootNormalizedPhrases;
  final List<VoiceCommandCategoryCandidate> candidates;
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
///
/// NOTE: scope is also resolved dynamically from the live category tree via
/// [VoiceCommandCategoryIndex] roots (Price Reporter + every other top-level
/// category name/keyword). This list only carries STT mis-hearings that cannot
/// be derived from a category name (e.g. "press reporter" → "price reporter",
/// "laredo ts" abbreviation of "laredo technical services").
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

/// Explicit STT mis-hearings of category names that the dynamic name/keyword
/// match would not catch. Keys are normalized tokens; values are the canonical
/// category name (must match a root rule's normalized name in
/// [VoiceCommandCategoryIndex]). Used by [_extractAfterRootScope] to repair the
/// transcript before scope extraction.
const Map<String, String> kCategoryScopeSttAliases = {
  // Laredo Technical Services — common spoken shortcuts / STT splits.
  'laredo technical': 'laredo technical services',
  'laredo tech': 'laredo technical services',
  'laredo ts': 'laredo technical services',
};

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
    // Laredo Technical Services — STT often collapses / splits the full name.
    // NOTE: "laredo ts" is intentionally NOT rewritten here — it stays as-is
    // so the inner "Laredo TS" client category (whose keyword is "laredo ts")
    // can still be matched by [VoiceCommandCategoryScope.candidates]. Only the
    // collapsed / partial forms that lack a clear trailing word are repaired
    // into the canonical full scope name.
    RegExp(
      r'\blaredo\s+(?:technical\s+services?|technical|tech)\b',
      caseSensitive: false,
    ): 'Laredo Technical Services',
  };
  for (final entry in replacements.entries) {
    t = t.replaceAll(entry.key, entry.value);
  }
  // STT word-level near-misses for task tokens inside any scope.
  t = _repairCommonTaskTokenNearMisses(t);
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Repairs STT near-miss tokens that occur as record-title fragments. Differs
/// from scope repair: these tokens are kept literally on the title but spelled
/// the canonical app way. Example: "scene" → "SIN", "add scene" → "ADD SIN".
String _repairCommonTaskTokenNearMisses(String t) {
  var out = t;
  // Whole-phrase repairs (longest first).
  final phrasePairs = <RegExp, String>{
    RegExp(r'\badd\s+scene\b', caseSensitive: false): 'ADD SIN',
    RegExp(r'\badd\s+seen\b', caseSensitive: false): 'ADD SIN',
    RegExp(r'\bad\s+scene\b', caseSensitive: false): 'ADD SIN',
    RegExp(r'\bad\s+seen\b', caseSensitive: false): 'ADD SIN',
    RegExp(r'\badd\s+sin\b', caseSensitive: false): 'ADD SIN',
    RegExp(r'\bad\s+sin\b', caseSensitive: false): 'ADD SIN',
  };
  for (final e in phrasePairs.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  // Standalone token repairs: "scene" / "seen" / "sim" / "sim." → "SIN".
  // We capture an optional trailing punctuation group explicitly so that "sim."
  // becomes "SIN" (period dropped, not "SIN."). Spaces between tokens are
  // preserved by matching only the token + optional punctuation.
  out = out.replaceAllMapped(
    RegExp(r'\b(scene|seen|sim)([.,])?', caseSensitive: false),
    (m) => 'SIN',
  );
  return out;
}

/// STT mis-hearings for record titles after Price Reporter scope (constrained grammar).
const Map<String, String> kPriceReporterTitleSttAliases = {
  'play': 'Planning',
  'plane': 'Planning',
  'playing': 'Planning',
  'planning': 'Planning',
  'plan': 'Planning',
  'planing': 'Planning',
  'plaming': 'Planning',
  'plenty': 'Planning',
  'plentie': 'Planning',
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

/// True when the repaired transcript mentions any of the recognised scopes'
/// root phrases (Price Reporter, Laredo Technical Services, …) or their known
/// STT aliases. Pre-filter so we never block on out-of-scope transcripts.
bool transcriptMentionsKnownScope(
  String transcript,
  VoiceCommandCategoryIndex index,
) {
  final norm = normalizeCategoryLabel(repairVoiceCommandTranscript(transcript));
  if (norm.isEmpty) return false;
  for (final scope in index.roots) {
    if (scope.rootLabelNormalised == kPriceReporterScopeCanonical) {
      for (final prefix in kPriceReporterScopeNormPrefixes) {
        if (norm == prefix || norm.startsWith('$prefix ')) return true;
      }
    }
    for (final phrase in scope.rootNormalizedPhrases) {
      if (phrase.isEmpty) continue;
      if (norm == phrase || norm.startsWith('$phrase ')) return true;
    }
  }
  return false;
}

const String kPriceReporterScopeCanonical = 'price reporter';

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

/// Generic voice command entry — multi-scope: Price Reporter, Laredo Technical
/// Services, and every other top-level app category. Routes the repaired
/// transcript through [parseScopedVoiceCommand]. Out-of-scope phrases return
/// `unsupported_command` (preserving the pre-existing Price Reporter gate for
/// non-app users / random dictation).
VoiceCommandParseResult parseVoiceCommand({
  required List<CategoryRule> rules,
  required String transcript,
}) {
  final repaired = repairVoiceCommandTranscript(transcript);
  final index = VoiceCommandCategoryIndex.fromCategoryRules(rules);
  if (index == null) {
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
  if (!transcriptMentionsKnownScope(repaired, index)) {
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
  return parseScopedVoiceCommand(index: index, transcript: repaired);
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

/// Strip a normalised category phrase from the START of a raw repaired
/// transcript, returning the remaining raw tokens (e.g. "Laredo TS SIN" with
/// phrase "laredo ts" → "SIN"). Mirrors [_stripNormalizedPrefixTokens] but
/// operates on the raw space-separated transcript while respecting the
/// normalised token alignment.
String _stripScopedCategoryFromRaw(String rawTranscript, String phraseNorm) {
  final rawTokens =
      rawTranscript.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final phraseTokens =
      phraseNorm.split(' ').where((t) => t.isNotEmpty).toList();
  if (rawTokens.isEmpty || phraseTokens.isEmpty) return rawTranscript.trim();
  if (rawTokens.length < phraseTokens.length) return rawTranscript.trim();
  for (var i = 0; i < phraseTokens.length; i++) {
    if (normalizeCategoryLabel(rawTokens[i]) != phraseTokens[i]) {
      return rawTranscript.trim();
    }
  }
  return rawTokens.skip(phraseTokens.length).join(' ').trim();
}

String? _extractAfterRootScope(
  String original,
  VoiceCommandCategoryScope scope,
) {
  final repaired = repairVoiceCommandTranscript(original);
  final normFull = normalizeCategoryLabel(repaired);
  if (normFull.isEmpty) return null;

  final normTokens = normFull.split(' ').where((t) => t.isNotEmpty).toList();
  final rawTokens = repaired.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (normTokens.isEmpty || rawTokens.isEmpty) return null;

  // Scope tokens: Price Reporter keeps its STT-alias prefix list; all other
  // scopes use their own root name + aliases from [scope.rootNormalizedPhrases].
  final scopePrefixes = <List<String>>[];
  if (scope.rootLabelNormalised == kPriceReporterScopeCanonical) {
    scopePrefixes.addAll(
      kPriceReporterScopeNormPrefixes.map(
        (p) => p.split(' ').where((t) => t.isNotEmpty).toList(),
      ),
    );
  }
  for (final phrase in scope.rootNormalizedPhrases) {
    scopePrefixes
        .add(phrase.split(' ').where((t) => t.isNotEmpty).toList());
  }
  scopePrefixes.sort((a, b) => b.length.compareTo(a.length));

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

/// Multi-scope dispatcher: tries every recognised top-level scope and returns
/// the best (exact > ambiguous > noMatch). Disambiguates ties by scope order
/// (Price Reporter first, then alphabetical).
VoiceCommandParseResult parseScopedVoiceCommand({
  required VoiceCommandCategoryIndex index,
  required String transcript,
}) {
  final original = repairVoiceCommandTranscript(transcript).trim();
  VoiceCommandParseResult? bestAmbiguous;
  VoiceCommandParseResult? bestNoMatch;

  for (final scope in index.roots) {
    final r = _parseAgainstScope(scope: scope, transcript: original);
    if (r.confidence == VoiceCommandMatchConfidence.exact) {
      return r;
    }
    if (r.confidence == VoiceCommandMatchConfidence.ambiguous) {
      bestAmbiguous ??= r;
      continue;
    }
    // noMatch: keep only the deepest / most specific non-match so the UI gets
    // the most informative reason.
    if (bestNoMatch == null ||
        _noMatchIsMoreInformative(r, bestNoMatch)) {
      bestNoMatch = r;
    }
  }

  return bestAmbiguous ?? bestNoMatch ?? VoiceCommandParseResult(
      rootLabel: '',
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: original,
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'unsupported_command',
    );
}

/// Back-compat entry: parses a transcript against the full multi-scope index.
/// Legacy callers that hold a [VoiceCommandCategoryIndex] (e.g. the in-app
/// desktop voice panel) keep using this name; it dispatches to all scopes.
VoiceCommandParseResult parsePriceReporterVoiceCommand({
  required VoiceCommandCategoryIndex index,
  required String transcript,
}) {
  return parseScopedVoiceCommand(index: index, transcript: transcript);
}

/// Returns true when [a] is a more informative noMatch than [b]. Precedence:
/// matched-but-invalid > missing client+title > missing root scope > generic.
bool _noMatchIsMoreInformative(VoiceCommandParseResult a, VoiceCommandParseResult b) {
  int rank(String? reason) {
    switch (reason) {
      case 'invalid_category_pb_id':
        return 5;
      case 'missing_client_and_title':
        return 4;
      case 'missing_record_title':
        return 3;
      case 'missing_root_scope':
        return 2;
      default:
        return 1;
    }
  }
  return rank(a.ambiguityReason) > rank(b.ambiguityReason);
}

/// Parses a structured voice command against ONE specific [scope]. Mirrors the
/// original [parsePriceReporterVoiceCommand] logic but is scope-generic.
VoiceCommandParseResult _parseAgainstScope({
  required VoiceCommandCategoryScope scope,
  required String transcript,
}) {
  final original = repairVoiceCommandTranscript(transcript).trim();
  if (original.isEmpty) {
    return VoiceCommandParseResult(
      rootLabel: scope.rootLabel,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: '',
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'empty_transcript',
    );
  }

  // Pre-pass: try matching a CANDIDATE phrase at the very start of the
  // transcript. This lets "Laredo TS SIN" match the inner "Laredo TS" client
  // (whose keyword is "laredo ts") directly as the scope + client, with the
  // remaining text ("SIN") as the record title. Root phrases are tried below
  // for the "Laredo Technical Services <title>" form.
  final normOriginal = normalizeCategoryLabel(original);
  final candidateScopeHits =
      <({VoiceCommandCategoryCandidate c, String phrase})>[];
  for (final candidate in scope.candidates) {
    for (final phrase in candidate.normalizedPhrases) {
      if (phrase.isEmpty) continue;
      if (!normOriginal.startsWith(phrase)) continue;
      if (normOriginal.length > phrase.length &&
          normOriginal[phrase.length] != ' ') {
        continue;
      }
      candidateScopeHits.add((c: candidate, phrase: phrase));
    }
  }
  if (candidateScopeHits.isNotEmpty) {
    candidateScopeHits.sort((a, b) => b.phrase.length.compareTo(a.phrase.length));
    final longestLen = candidateScopeHits.first.phrase.length;
    final atLongest = candidateScopeHits
        .where((h) => h.phrase.length == longestLen)
        .toList(growable: false);
    final clientIds = atLongest.map((h) => h.c.localCategoryId).toSet();
    if (clientIds.length > 1) {
      return VoiceCommandParseResult(
        rootLabel: scope.rootLabel,
        matchedCategoryPocketBaseId: null,
        matchedCategoryDisplayPath: null,
        matchedLocalCategoryId: null,
        recordTitle: original,
        confidence: VoiceCommandMatchConfidence.ambiguous,
        originalTranscript: original,
        ambiguityReason: 'ambiguous_client_prefix',
        ambiguousCandidates:
            atLongest.map((h) => h.c.displayPath).toSet().toList(),
      );
    }
    final winner = atLongest.first;
    final client = winner.c;
    if (!_isLikelyPocketBaseRowId(client.pocketBaseId)) {
      return VoiceCommandParseResult(
        rootLabel: scope.rootLabel,
        matchedCategoryPocketBaseId: null,
        matchedCategoryDisplayPath: client.displayPath,
        matchedLocalCategoryId: null,
        recordTitle: original,
        confidence: VoiceCommandMatchConfidence.noMatch,
        originalTranscript: original,
        ambiguityReason: 'invalid_category_pb_id',
      );
    }
    // Strip the matched scope-phrase from the RAW transcript (preserves any
    // uppercase STT original of the title), then run title repair.
    final rawRemaining =
        _stripScopedCategoryFromRaw(original, winner.phrase).trim();
    var recordTitle =
        repairPriceReporterRecordTitle(rawRemaining);
    if (recordTitle.isEmpty) recordTitle = client.displayName.trim();
    if (recordTitle.isEmpty) {
      return VoiceCommandParseResult(
        rootLabel: scope.rootLabel,
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
      rootLabel: scope.rootLabel,
      matchedCategoryPocketBaseId: client.pocketBaseId,
      matchedCategoryDisplayPath: client.displayPath,
      matchedLocalCategoryId: client.localCategoryId,
      recordTitle: recordTitle,
      confidence: VoiceCommandMatchConfidence.exact,
      originalTranscript: original,
    );
  }

  final afterRoot = _extractAfterRootScope(original, scope);
  if (afterRoot == null) {
    return VoiceCommandParseResult(
      rootLabel: scope.rootLabel,
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
      rootLabel: scope.rootLabel,
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
  for (final candidate in scope.candidates) {
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
        rootLabel: scope.rootLabel,
        matchedCategoryPocketBaseId: null,
        matchedCategoryDisplayPath: null,
        matchedLocalCategoryId: null,
        recordTitle: '',
        confidence: VoiceCommandMatchConfidence.noMatch,
        originalTranscript: original,
        ambiguityReason: 'missing_client_and_title',
      );
    }
    if (!_isLikelyPocketBaseRowId(scope.rootPocketBaseId)) {
      return VoiceCommandParseResult(
        rootLabel: scope.rootLabel,
        matchedCategoryPocketBaseId: null,
        matchedCategoryDisplayPath: scope.rootLabel,
        matchedLocalCategoryId: null,
        recordTitle: title,
        confidence: VoiceCommandMatchConfidence.noMatch,
        originalTranscript: original,
        ambiguityReason: 'invalid_category_pb_id',
      );
    }
    return VoiceCommandParseResult(
      rootLabel: scope.rootLabel,
      matchedCategoryPocketBaseId: scope.rootPocketBaseId,
      matchedCategoryDisplayPath: scope.rootLabel,
      matchedLocalCategoryId: scope.rootLocalCategoryId,
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
      rootLabel: scope.rootLabel,
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
      rootLabel: scope.rootLabel,
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
      rootLabel: scope.rootLabel,
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
    rootLabel: scope.rootLabel,
    matchedCategoryPocketBaseId: client.pocketBaseId,
    matchedCategoryDisplayPath: client.displayPath,
    matchedLocalCategoryId: client.localCategoryId,
    recordTitle: recordTitle,
    confidence: VoiceCommandMatchConfidence.exact,
    originalTranscript: original,
  );
}
