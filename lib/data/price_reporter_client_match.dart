/// Deterministic Price Reporter client resolution for manual export scripts.
///
/// Reuses [normalizeCategoryLabel] and fuzzy scoring from `category_fuzzy_match.dart`.
/// Title-matching phases mirror [CategoryRule] in `models/category.dart` and
/// [DatabaseService.findDeepestMatchForTitle] in `category_service.dart`.
///
/// No Flutter imports — safe for `dart run scripts/manual/...`.
library;

import 'dart:convert';
import 'dart:math' show max;

import 'package:counter/data/category_fuzzy_match.dart';

/// Source-of-truth anchor for diagnostics.
const String kPriceReporterClientMatchSource =
    'lib/data/price_reporter_client_match.dart'
    ' (CategoryRule scoring mirrored from models/category.dart;'
    ' phases aligned with category_service.findDeepestMatchForTitle)';

const Set<String> kPriceReporterGenericTaskTokens = {
  'add',
  'sin',
  'epa',
  'fcp',
  'mas',
  'del',
  'mod',
  'check',
  'task',
  'email',
  'call',
  'os4',
  'tc',
  't&c',
  't c',
};

class PriceReporterAliasEntry {
  const PriceReporterAliasEntry({
    required this.alias,
    required this.canonicalName,
    required this.pbId,
    required this.source,
  });

  final String alias;
  final String canonicalName;
  final String pbId;
  final String source;
}

class PriceReporterClientMatchResult {
  const PriceReporterClientMatchResult({
    required this.client,
    required this.note,
    required this.confidence,
    required this.reason,
    this.matchedKeywordOrAlias,
    this.matchedCategoryPbId,
    this.matchedCategoryName,
    this.allowedClientSetMatch = true,
    this.appRuleResult,
    this.ambiguousMatches = const [],
    this.strippedPrefix = false,
  });

  final String client;
  final String note;
  final String confidence;
  final String reason;
  final String? matchedKeywordOrAlias;
  final String? matchedCategoryPbId;
  final String? matchedCategoryName;
  final bool allowedClientSetMatch;
  final String? appRuleResult;
  final List<String> ambiguousMatches;
  final bool strippedPrefix;
}

/// Lightweight category node — scoring mirrors [CategoryRule] (no Flutter).
class PriceReporterCategoryNode {
  PriceReporterCategoryNode({
    required this.pbId,
    required this.name,
    this.normalizedId,
    this.keywords,
    this.localizedNames,
    this.isArchived = false,
    List<PriceReporterCategoryNode>? children,
  }) : children = children ?? [];

  final String pbId;
  final String name;
  final String? normalizedId;
  final Map<String, List<String>>? keywords;
  final Map<String, String>? localizedNames;
  final bool isArchived;
  final List<PriceReporterCategoryNode> children;

  static bool _isAsciiWordCharAt(String s, int i) {
    if (i < 0 || i >= s.length) return false;
    final c = s.codeUnitAt(i);
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a);
  }

  static int _wordBoundedOccurrenceScore(String hayLower, String needleLower) {
    if (hayLower.isEmpty || needleLower.isEmpty) return 0;
    if (needleLower.length < 2) return 0;
    var found = 0;
    var start = 0;
    while (true) {
      final i = hayLower.indexOf(needleLower, start);
      if (i < 0) break;
      final beforeOk = i == 0 || !_isAsciiWordCharAt(hayLower, i - 1);
      final after = i + needleLower.length;
      final afterOk =
          after >= hayLower.length || !_isAsciiWordCharAt(hayLower, after);
      if (beforeOk && afterOk) found = needleLower.length;
      start = i + 1;
    }
    return found;
  }

  static void _accumulatePairScores(
    String tLower,
    String fragmentLower,
    void Function(int len) onScore,
  ) {
    if (fragmentLower.isEmpty || fragmentLower.length < 2) return;
    final a = _wordBoundedOccurrenceScore(tLower, fragmentLower);
    if (a > 0) onScore(a);
    final b = _wordBoundedOccurrenceScore(fragmentLower, tLower);
    if (b > 0) onScore(b);
  }

  static String _categoryTokenAliasOrSelf(String tok) =>
      kCategoryMatchingTokenAliases[tok] ?? tok;

  static int _consecutiveCategoryTokenScore(
    List<String> titleToks,
    List<String> catToks,
  ) {
    if (catToks.isEmpty) return 0;
    var i = 0;
    var j = 0;
    var sc = 0;
    while (i < titleToks.length && j < catToks.length) {
      final rawTt = titleToks[i];
      if (rawTt.isEmpty) {
        i++;
        continue;
      }
      if (rawTt.length < 2 || RegExp(r'^\d+$').hasMatch(rawTt)) {
        i++;
        continue;
      }
      final tt = _categoryTokenAliasOrSelf(rawTt);
      final ct = catToks[j];
      if (ct.length < 2) {
        j++;
        continue;
      }
      if (tt == ct) {
        sc += 200000 + tt.length * 1000 + ct.length;
        i++;
        j++;
      } else if (ct.startsWith(tt)) {
        sc += 100000 + tt.length * 1000;
        i++;
        j++;
      } else if (tt.startsWith(ct)) {
        sc += 80000 + ct.length * 1000;
        i++;
        j++;
      } else {
        break;
      }
    }
    return sc;
  }

  void _considerFrags(String title, void Function(String raw) considerFrag) {
    considerFrag(name);
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          considerFrag(kw);
        }
      }
    }
  }

  int categoryExactMatchScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    var best = 0;
    void considerFrag(String raw) {
      final k = normalizeCategoryLabel(raw);
      if (k.isNotEmpty) {
        _accumulatePairScores(nt, k, (len) => best = max(best, len));
      }
    }

    _considerFrags(title, considerFrag);
    return best;
  }

  int categoryConsecutiveTokenMatchScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    final titleToks = nt.split(' ').where((t) => t.isNotEmpty).toList();
    if (titleToks.isEmpty) return 0;
    var best = 0;
    void considerFrag(String raw) {
      final frag = normalizeCategoryLabel(raw);
      if (frag.isEmpty) return;
      final catToks = frag.split(' ').where((t) => t.isNotEmpty).toList();
      best = max(best, _consecutiveCategoryTokenScore(titleToks, catToks));
    }

    _considerFrags(title, considerFrag);
    return best;
  }

  int categoryTokenSetOverlapScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    final titleToks = <String>{};
    for (final raw in nt.split(' ').where((x) => x.isNotEmpty)) {
      if (raw.length < 2 || RegExp(r'^\d+$').hasMatch(raw)) continue;
      titleToks.add(_categoryTokenAliasOrSelf(raw));
    }
    if (titleToks.isEmpty) return 0;

    var best = 0;
    void considerFrag(String raw) {
      final frag = normalizeCategoryLabel(raw);
      if (frag.isEmpty) return;
      final catToks = frag
          .split(' ')
          .where((x) => x.isNotEmpty && x.length >= 2)
          .map(_categoryTokenAliasOrSelf)
          .toList();
      if (catToks.isEmpty) return;
      final catSet = catToks.toSet();
      final n = catSet.length;
      final need = ((n * 60) + 99) ~/ 100;
      final inter = titleToks.intersection(catSet);
      if (inter.length < need) return;
      final sc = 30000 + inter.length * 5000 + n * 100 + frag.length;
      best = max(best, sc);
    }

    _considerFrags(title, considerFrag);
    return best;
  }

  int categoryFuzzyMatchScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    final frags = <String>[name];
    if (keywords != null) {
      for (final list in keywords!.values) {
        frags.addAll(list);
      }
    }
    return fuzzyMatchScoreForNormalizedTitle(nt, frags);
  }

  Iterable<String> aliasCandidates() sync* {
    yield name;
    if ((normalizedId ?? '').trim().isNotEmpty) yield normalizedId!.trim();
    if (localizedNames != null) {
      for (final v in localizedNames!.values) {
        if (v.trim().isNotEmpty) yield v.trim();
      }
    }
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          if (kw.trim().isNotEmpty) yield kw.trim();
        }
      }
    }
  }
}

class PriceReporterClientIndex {
  PriceReporterClientIndex({
    required this.parentPbId,
    required this.parentDisplayName,
    required this.allowedClients,
    required this.ruleTreeRoot,
    required this.pbIdToCanonicalName,
    required this.prefixAliases,
    required this.keywordAliasCount,
    required this.ambiguousAliasesSkipped,
  });

  final String parentPbId;
  final String parentDisplayName;
  final Set<String> allowedClients;
  final PriceReporterCategoryNode ruleTreeRoot;
  final Map<String, String> pbIdToCanonicalName;
  final List<PriceReporterAliasEntry> prefixAliases;
  final int keywordAliasCount;
  final int ambiguousAliasesSkipped;

  static String _canonicalDisplayName(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final slug = (data['category_id'] ?? '').toString().trim();
    if (slug.isNotEmpty) return slug;
    final norm = (data['normalized_id'] ?? '').toString().trim();
    if (norm.isNotEmpty) return norm;
    return 'Untitled';
  }

  static Map<String, List<String>>? _parseKeywords(dynamic rawKw) {
    dynamic kwDecoded = rawKw;
    if (rawKw is String && rawKw.trim().isNotEmpty) {
      try {
        kwDecoded = jsonDecode(rawKw);
      } catch (_) {
        kwDecoded = null;
      }
    }
    if (kwDecoded is! Map) return null;
    final keywords = <String, List<String>>{};
    for (final e in kwDecoded.entries) {
      keywords[e.key.toString()] = e.value is List
          ? (e.value as List).map((x) => x.toString()).toList()
          : <String>[];
    }
    return keywords;
  }

  static Map<String, String>? _parseLocalizedNames(dynamic rawLoc) {
    dynamic locDecoded = rawLoc;
    if (rawLoc is String && rawLoc.trim().isNotEmpty) {
      try {
        locDecoded = jsonDecode(rawLoc);
      } catch (_) {
        locDecoded = null;
      }
    }
    if (locDecoded is! Map) return null;
    final loc = <String, String>{};
    for (final e in locDecoded.entries) {
      loc[e.key.toString()] = e.value?.toString() ?? '';
    }
    return loc;
  }

  static PriceReporterCategoryNode _nodeFromPbRow({
    required String pbId,
    required Map<String, dynamic> data,
    required List<PriceReporterCategoryNode> children,
  }) {
    return PriceReporterCategoryNode(
      pbId: pbId,
      name: _canonicalDisplayName(data),
      normalizedId: (data['normalized_id'] ?? '').toString().trim().isEmpty
          ? null
          : (data['normalized_id'] ?? '').toString().trim(),
      keywords: _parseKeywords(data['keywords']),
      localizedNames: _parseLocalizedNames(data['localized_names']),
      isArchived: data['is_archived'] == true,
      children: children,
    );
  }

  factory PriceReporterClientIndex.fromPbSubtree({
    required String parentPbId,
    required Map<String, dynamic> parentData,
    required List<({String id, Map<String, dynamic> data})> subtreeRows,
  }) {
    final parentDisplayName = _canonicalDisplayName(parentData);
    final byId = <String, Map<String, dynamic>>{
      parentPbId: parentData,
      for (final r in subtreeRows) r.id: r.data,
    };
    final childrenByParent = <String, List<String>>{};
    for (final id in byId.keys) {
      final parent = (byId[id]!['parent_id'] ?? '').toString().trim();
      if (parent.isNotEmpty) {
        childrenByParent.putIfAbsent(parent, () => []).add(id);
      }
    }

    PriceReporterCategoryNode buildNode(String id) {
      final kids = childrenByParent[id] ?? const <String>[];
      final childRules = kids.map(buildNode).toList();
      return _nodeFromPbRow(pbId: id, data: byId[id]!, children: childRules);
    }

    final root = buildNode(parentPbId);
    final allowed = <String>{parentDisplayName};
    final pbIdToCanonical = <String, String>{parentPbId: parentDisplayName};
    final aliasBuckets = <String, Set<String>>{};
    final aliasSources = <String, Set<String>>{};
    var keywordAliasCount = 0;
    var ambiguousAliasesSkipped = 0;

    void collectAliases(String pbId, Map<String, dynamic> data) {
      final canonical = _canonicalDisplayName(data);
      allowed.add(canonical);
      pbIdToCanonical[pbId] = canonical;
      if (pbId == parentPbId) return;

      void addAlias(String raw, String source) {
        final alias = raw.trim();
        if (alias.isEmpty) return;
        final norm = normalizeCategoryLabel(alias);
        if (norm.isEmpty) return;
        if (kPriceReporterGenericTaskTokens.contains(norm) &&
            norm != normalizeCategoryLabel(canonical)) {
          return;
        }
        keywordAliasCount++;
        aliasBuckets.putIfAbsent(norm, () => {}).add(canonical);
        aliasSources.putIfAbsent(norm, () => {}).add(source);
      }

      addAlias(canonical, 'name');
      addAlias((data['category_id'] ?? '').toString(), 'category_id');
      addAlias((data['normalized_id'] ?? '').toString(), 'normalized_id');
      final loc = _parseLocalizedNames(data['localized_names']);
      if (loc != null) {
        for (final v in loc.values) {
          addAlias(v, 'localized_names');
        }
      }
      final kw = _parseKeywords(data['keywords']);
      if (kw != null) {
        for (final list in kw.values) {
          for (final item in list) {
            addAlias(item, 'keywords');
          }
        }
      }
    }

    for (final entry in byId.entries) {
      collectAliases(entry.key, entry.value);
    }

    final prefixAliases = <PriceReporterAliasEntry>[];
    for (final entry in aliasBuckets.entries) {
      final canonicals = entry.value;
      if (canonicals.length > 1) {
        ambiguousAliasesSkipped++;
        continue;
      }
      final canonical = canonicals.first;
      if (canonical == parentDisplayName) continue;
      final sources = aliasSources[entry.key] ?? const {};
      final sourceLabel = sources.contains('keywords')
          ? 'keywords'
          : sources.contains('name')
          ? 'name'
          : (sources.isEmpty ? 'dictionary' : sources.first);
      prefixAliases.add(
        PriceReporterAliasEntry(
          alias: entry.key,
          canonicalName: canonical,
          pbId: pbIdToCanonical.entries
              .firstWhere((e) => e.value == canonical)
              .key,
          source: sourceLabel,
        ),
      );
    }

    prefixAliases.sort((a, b) => b.alias.length.compareTo(a.alias.length));

    return PriceReporterClientIndex(
      parentPbId: parentPbId,
      parentDisplayName: parentDisplayName,
      allowedClients: allowed,
      ruleTreeRoot: root,
      pbIdToCanonicalName: pbIdToCanonical,
      prefixAliases: prefixAliases,
      keywordAliasCount: keywordAliasCount,
      ambiguousAliasesSkipped: ambiguousAliasesSkipped,
    );
  }
}

List<PriceReporterCategoryNode> _phaseWinners(
  PriceReporterCategoryNode root,
  String title,
  int Function(PriceReporterCategoryNode rule) scoreOf,
) {
  final scored =
      <PriceReporterCategoryNode, ({int sc, int depth, int nameLen})>{};

  void walk(PriceReporterCategoryNode r, int depth) {
    if (depth > 4) return;
    if (!r.isArchived) {
      final sc = scoreOf(r);
      if (sc > 0) {
        scored[r] = (sc: sc, depth: depth, nameLen: r.name.trim().length);
      }
    }
    for (final c in r.children) {
      walk(c, depth + 1);
    }
  }

  walk(root, 0);
  if (scored.isEmpty) return const [];

  var bestSc = -1;
  var bestDepth = -1;
  var bestLen = -1;
  for (final v in scored.values) {
    if (v.sc > bestSc ||
        (v.sc == bestSc && v.depth > bestDepth) ||
        (v.sc == bestSc && v.depth == bestDepth && v.nameLen > bestLen)) {
      bestSc = v.sc;
      bestDepth = v.depth;
      bestLen = v.nameLen;
    }
  }

  return scored.entries
      .where(
        (e) =>
            e.value.sc == bestSc &&
            e.value.depth == bestDepth &&
            e.value.nameLen == bestLen,
      )
      .map((e) => e.key)
      .toList();
}

({
  PriceReporterCategoryNode? winner,
  List<PriceReporterCategoryNode> ties,
  String? phase,
}) appCategoryRuleMatch(
  PriceReporterCategoryNode root,
  String title,
) {
  final phases = <String, int Function(PriceReporterCategoryNode)>{
    'exact': (r) => r.categoryExactMatchScoreForTitle(title),
    'consecutive': (r) => r.categoryConsecutiveTokenMatchScoreForTitle(title),
    'token_set': (r) => r.categoryTokenSetOverlapScoreForTitle(title),
    'fuzzy': (r) => r.categoryFuzzyMatchScoreForTitle(title),
  };

  for (final entry in phases.entries) {
    final winners = _phaseWinners(root, title, entry.value);
    if (winners.isEmpty) continue;
    final childWinners =
        winners.where((r) => r.pbId != root.pbId).toList();
    if (childWinners.isEmpty) continue;
    final names = childWinners.map((r) => r.name.trim()).toSet();
    if (names.length > 1) {
      return (winner: null, ties: childWinners, phase: entry.key);
    }
    return (winner: childWinners.first, ties: const [], phase: entry.key);
  }
  return (winner: null, ties: const [], phase: null);
}

String? _leadingPrefixAliasForNode(String rawText, PriceReporterCategoryNode node) {
  var best = '';
  for (final raw in node.aliasCandidates()) {
    final alias = raw.trim();
    if (alias.isEmpty) continue;
    if (rawText.length < alias.length) continue;
    if (!rawText.toLowerCase().startsWith(alias.toLowerCase())) continue;
    final after = alias.length;
    if (after < rawText.length) {
      final c = rawText[after];
      if (c != ' ' &&
          c != '-' &&
          c != '–' &&
          c != '—' &&
          c != ':' &&
          c != '|') {
        continue;
      }
    }
    if (alias.length > best.length) best = alias;
  }
  return best.isEmpty ? null : best;
}

String _stripRawPrefix(String raw, String prefix) {
  var rest = raw.trim();
  if (prefix.isEmpty) return rest;
  if (!rest.toLowerCase().startsWith(prefix.toLowerCase())) return rest;
  rest = rest.substring(prefix.length);
  rest = rest.replaceFirst(RegExp(r'^[\s\-–—:|]+'), '');
  return rest.trim();
}

String _stripNormalizedPrefix(String raw, String normalizedAlias) {
  final aliasTokens =
      normalizedAlias.split(' ').where((t) => t.isNotEmpty).toList();
  if (aliasTokens.isEmpty) return raw.trim();
  final rawTokens =
      raw.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (rawTokens.length < aliasTokens.length) return raw.trim();
  for (var i = 0; i < aliasTokens.length; i++) {
    if (normalizeCategoryLabel(rawTokens[i]) != aliasTokens[i]) {
      return raw.trim();
    }
  }
  var rest = rawTokens.skip(aliasTokens.length).join(' ');
  rest = rest.replaceFirst(RegExp(r'^[\s\-–—:|]+'), '');
  return rest.trim();
}

({
  PriceReporterAliasEntry? hit,
  List<PriceReporterAliasEntry> ties,
}) prefixAliasMatch(
  String rawText,
  List<PriceReporterAliasEntry> aliases,
) {
  final raw = rawText.trim();
  if (raw.isEmpty) return (hit: null, ties: const []);

  final normRaw = normalizeCategoryLabel(raw);
  final hits = <PriceReporterAliasEntry>[];
  for (final entry in aliases) {
    final alias = entry.alias;
    if (alias.isEmpty) continue;
    if (!normRaw.startsWith(alias)) continue;
    final afterLen = alias.length;
    if (afterLen < normRaw.length && normRaw[afterLen] != ' ') continue;
    hits.add(entry);
  }
  if (hits.isEmpty) return (hit: null, ties: const []);

  hits.sort((a, b) => b.alias.length.compareTo(a.alias.length));
  final longest = hits.first.alias.length;
  final atLongest = hits.where((h) => h.alias.length == longest).toList();
  final names = atLongest.map((h) => h.canonicalName).toSet();
  if (names.length > 1) {
    return (hit: null, ties: atLongest);
  }
  return (hit: atLongest.first, ties: const []);
}

PriceReporterClientMatchResult resolvePriceReporterClient({
  required PriceReporterClientIndex index,
  required String rawText,
  required String recordCategoryPbId,
}) {
  final raw = rawText.trim();
  final parentName = index.parentDisplayName;
  final ambiguous = <String>[];

  final app = appCategoryRuleMatch(index.ruleTreeRoot, raw);
  if (app.ties.isNotEmpty) {
    ambiguous.addAll(app.ties.map((r) => r.name.trim()));
    return PriceReporterClientMatchResult(
      client: parentName,
      note: raw,
      confidence: 'ambiguous',
      reason: 'ambiguous_existing_category_match',
      allowedClientSetMatch: true,
      appRuleResult: app.phase,
      ambiguousMatches: ambiguous,
    );
  }

  if (app.winner != null) {
    final node = app.winner!;
    final client = node.name.trim();
    final prefix = _leadingPrefixAliasForNode(raw, node);
    final note = prefix != null ? _stripRawPrefix(raw, prefix) : raw;
    return PriceReporterClientMatchResult(
      client: client,
      note: note,
      confidence: 'high',
      reason:
          prefix != null ? 'app_category_rules_prefix' : 'app_category_rules',
      matchedKeywordOrAlias: prefix ?? node.name.trim(),
      matchedCategoryPbId: node.pbId,
      matchedCategoryName: client,
      allowedClientSetMatch: index.allowedClients.contains(client),
      appRuleResult: app.phase,
      strippedPrefix: prefix != null,
    );
  }

  final prefix = prefixAliasMatch(raw, index.prefixAliases);
  if (prefix.ties.isNotEmpty) {
    ambiguous.addAll(prefix.ties.map((t) => t.canonicalName));
    return PriceReporterClientMatchResult(
      client: parentName,
      note: raw,
      confidence: 'ambiguous',
      reason: 'ambiguous_existing_category_match',
      allowedClientSetMatch: true,
      ambiguousMatches: ambiguous,
    );
  }
  if (prefix.hit != null) {
    final hit = prefix.hit!;
    final note = _stripNormalizedPrefix(raw, hit.alias);
    return PriceReporterClientMatchResult(
      client: hit.canonicalName,
      note: note,
      confidence: 'high',
      reason: hit.source == 'keywords'
          ? 'category_keyword_prefix'
          : 'category_alias_prefix',
      matchedKeywordOrAlias: hit.alias,
      matchedCategoryPbId: hit.pbId,
      matchedCategoryName: hit.canonicalName,
      allowedClientSetMatch: index.allowedClients.contains(hit.canonicalName),
      strippedPrefix: true,
    );
  }

  if (recordCategoryPbId != index.parentPbId) {
    final canonical = index.pbIdToCanonicalName[recordCategoryPbId];
    if (canonical != null && index.allowedClients.contains(canonical)) {
      return PriceReporterClientMatchResult(
        client: canonical,
        note: raw,
        confidence: 'high',
        reason: 'category_name_fallback',
        matchedCategoryPbId: recordCategoryPbId,
        matchedCategoryName: canonical,
        allowedClientSetMatch: true,
      );
    }
  }

  return PriceReporterClientMatchResult(
    client: parentName,
    note: raw,
    confidence: 'low',
    reason: 'price_reporter_fallback',
    allowedClientSetMatch: true,
  );
}

String clientBeforeTextRules({
  required PriceReporterClientIndex index,
  required String recordCategoryPbId,
}) {
  if (recordCategoryPbId != index.parentPbId) {
    final canonical = index.pbIdToCanonicalName[recordCategoryPbId];
    if (canonical != null) return canonical;
  }
  return index.parentDisplayName;
}
