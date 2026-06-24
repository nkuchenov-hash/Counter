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
      final nextPath = isRoot ? <String>[] : [...pathParts, rule.name.trim()];
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

/// Parses a structured Price Reporter voice command against [index].
VoiceCommandParseResult parsePriceReporterVoiceCommand({
  required VoiceCommandCategoryIndex index,
  required String transcript,
}) {
  final original = transcript.trim();
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

  final normFull = normalizeCategoryLabel(original);
  final rootNorm = normalizeCategoryLabel(index.rootLabel);
  if (rootNorm.isEmpty ||
      !normFull.startsWith(rootNorm) ||
      (normFull.length > rootNorm.length && normFull[rootNorm.length] != ' ')) {
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

  var afterRoot = original;
  final rootWords = index.rootLabel.trim().split(RegExp(r'\s+'));
  if (rootWords.isNotEmpty &&
      afterRoot.toLowerCase().startsWith(index.rootLabel.toLowerCase())) {
    afterRoot = afterRoot.substring(index.rootLabel.length);
    afterRoot = afterRoot.replaceFirst(RegExp(r'^[\s\-–—:|]+'), '');
  } else {
    final tokens = original.split(RegExp(r'\s+'));
    afterRoot = tokens.skip(rootWords.length).join(' ');
  }
  afterRoot = afterRoot.trim();
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
    return VoiceCommandParseResult(
      rootLabel: index.rootLabel,
      matchedCategoryPocketBaseId: null,
      matchedCategoryDisplayPath: null,
      matchedLocalCategoryId: null,
      recordTitle: afterRoot,
      confidence: VoiceCommandMatchConfidence.noMatch,
      originalTranscript: original,
      ambiguityReason: 'no_client_match',
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

  final recordTitle = _stripNormalizedPrefixTokens(afterRoot, winner.phrase);
  if (recordTitle.trim().isEmpty) {
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
    recordTitle: recordTitle.trim(),
    confidence: VoiceCommandMatchConfidence.exact,
    originalTranscript: original,
  );
}
