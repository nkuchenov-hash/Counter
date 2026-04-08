import 'dart:math' show max;

/// Lowercase, trim, drop punctuation/symbols, collapse to space-separated tokens.
String normalizeCategoryLabel(String input) {
  final s = input.toLowerCase().trim();
  if (s.isEmpty) return '';
  final parts = s.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true));
  return parts.where((p) => p.isNotEmpty).join(' ');
}

int _min3(int a, int b, int c) {
  final m = a < b ? a : b;
  return m < c ? m : c;
}

/// Levenshtein distance over Unicode code points ([runes]); fast and dependency-free.
int levenshteinDistance(String a, String b) {
  final ac = a.runes.toList();
  final bc = b.runes.toList();
  final n = ac.length;
  final m = bc.length;
  if (n == 0) return m;
  if (m == 0) return n;
  var v0 = List<int>.generate(m + 1, (j) => j);
  var v1 = List<int>.filled(m + 1, 0);
  for (var i = 0; i < n; i++) {
    v1[0] = i + 1;
    for (var j = 0; j < m; j++) {
      final cost = ac[i] == bc[j] ? 0 : 1;
      v1[j + 1] = _min3(
        v1[j] + 1,
        v0[j + 1] + 1,
        v0[j] + cost,
      );
    }
    final tmp = v0;
    v0 = v1;
    v1 = tmp;
  }
  return v0[m];
}

/// Similarity in [0,1]: \((len(a)+len(b)-d) / (len(a)+len(b))\).
/// Rejects pairs like "work"/"word" (~0.875) while accepting "carrol"/"carroll" (~0.923).
double levenshteinSimilarityRatio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  final d = levenshteinDistance(a, b);
  final sumLen = a.runes.length + b.runes.length;
  return (sumLen - d) / sumLen;
}

/// `true` when normalized [token] may fuzzy-match a category keyword/name token.
///
/// Gates: edit budget by max length (`&lt;6` → 1 edit, else 2) **and**
/// [levenshteinSimilarityRatio] ≥ [minSimilarity] (default 0.9).
bool fuzzyNormalizedTokensMatch(
  String token,
  String categoryToken, {
  double minSimilarity = 0.9,
}) {
  if (token.runes.length < 2 || categoryToken.runes.length < 2) return false;
  final d = levenshteinDistance(token, categoryToken);
  if (levenshteinSimilarityRatio(token, categoryToken) < minSimilarity) {
    return false;
  }
  final refLen = max(token.runes.length, categoryToken.runes.length);
  final maxEdits = refLen < 6 ? 1 : 2;
  return d <= maxEdits;
}

List<String> _nonEmptyTokens(String normalizedPhrase) =>
    normalizedPhrase.split(' ').where((t) => t.isNotEmpty).toList();

/// Sequential token alignment: each fragment token must fuzzy-match the next title token.
int fuzzySequentialPhraseScore(String normalizedTitle, String normalizedFragment) {
  final titleToks = _nonEmptyTokens(normalizedTitle);
  final fragToks = _nonEmptyTokens(normalizedFragment);
  if (fragToks.isEmpty) return 0;
  if (fragToks.any((t) => t.length < 2)) return 0;
  var best = 0;
  for (var start = 0; start < titleToks.length; start++) {
    var ti = start;
    var fi = 0;
    var sumLen = 0;
    while (fi < fragToks.length && ti < titleToks.length) {
      if (!fuzzyNormalizedTokensMatch(titleToks[ti], fragToks[fi])) {
        break;
      }
      sumLen += fragToks[fi].length;
      ti++;
      fi++;
    }
    if (fi == fragToks.length) {
      best = max(best, sumLen);
    }
  }
  return best;
}

/// Single-token fragment: best fuzzy hit against any title token.
/// Multi-token fragment: [fuzzySequentialPhraseScore].
int fuzzyPhraseScoreAgainstTitle(String normalizedTitle, String normalizedFragment) {
  if (normalizedFragment.length < 2) return 0;
  if (!normalizedFragment.contains(' ')) {
    var best = 0;
    for (final tt in _nonEmptyTokens(normalizedTitle)) {
      if (fuzzyNormalizedTokensMatch(tt, normalizedFragment)) {
        best = max(best, normalizedFragment.length);
      }
    }
    return best;
  }
  return fuzzySequentialPhraseScore(normalizedTitle, normalizedFragment);
}

/// Max fuzzy score from raw fragments (names/keywords) vs an already-normalized title.
int fuzzyMatchScoreForNormalizedTitle(String normalizedTitle, Iterable<String> rawFragments) {
  var best = 0;
  for (final raw in rawFragments) {
    final nf = normalizeCategoryLabel(raw);
    final sc = fuzzyPhraseScoreAgainstTitle(normalizedTitle, nf);
    if (sc > best) best = sc;
  }
  return best;
}
