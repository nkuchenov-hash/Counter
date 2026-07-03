part of '../database_service.dart';

extension CategoryLookupExtension on DatabaseService {
  CategoryRule? findDeepestMatchForTitle(String title) {
    CategoryRule? best;
    var bestScore = -1;
    var bestDepth = -1;
    int depthOf(CategoryRule target, List<CategoryRule> roots, int level) {
      if (level > 4) return -1;
      for (final r in roots) {
        if (r.id == target.id) return level;
        final d = depthOf(target, r.children ?? [], level + 1);
        if (d >= 0) return d;
      }
      return -1;
    }

    void considerPhase(int Function(CategoryRule m) scoreOf) {
      for (final root in _rules) {
        final m = root.findDeepestMatch(title, scoreFor: (r, t) => scoreOf(r));
        if (m != null) {
          final d = depthOf(m, _rules, 0);
          final sc = scoreOf(m);
          final mLen = m.name.trim().length;
          if (best == null ||
              sc > bestScore ||
              (sc == bestScore && d > bestDepth) ||
              (sc == bestScore &&
                  d == bestDepth &&
                  mLen > best!.name.trim().length)) {
            best = m;
            bestScore = sc;
            bestDepth = d;
          }
        }
      }
    }

    considerPhase((m) => m.categoryExactMatchScoreForTitle(title));
    if (best != null) return best;

    best = null;
    bestScore = -1;
    bestDepth = -1;
    considerPhase((m) => m.categoryConsecutiveTokenMatchScoreForTitle(title));
    if (best != null) return best;

    best = null;
    bestScore = -1;
    bestDepth = -1;
    considerPhase((m) => m.categoryTokenSetOverlapScoreForTitle(title));
    if (best != null) return best;

    best = null;
    bestScore = -1;
    bestDepth = -1;
    considerPhase((m) => m.categoryFuzzyMatchScoreForTitle(title));
    return best;
  }

  CategoryRule? identifyCategory(String input) =>
      findDeepestMatchForTitle(input);

  /// Smart link: best exact [CategoryRule.categoryExactMatchScoreForTitle], else fuzzy
  /// [CategoryRule.categoryFuzzyMatchScoreForTitle]; then longest [CategoryRule.name] tie-break;
  /// requires valid PocketBase **categories** row id.
  String? _findBestCategoryMatch(String title) {
    if (title.trim().isEmpty) return null;
    final candidates = <CategoryRule>[];
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) continue;
        candidates.add(r);
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    CategoryRule? bestRule;
    var bestScore = -1;
    for (final r in candidates) {
      final sc = r.categoryExactMatchScoreForTitle(title);
      if (sc <= 0) continue;
      final pb = _categoryBackendRowIdStrict(r);
      if (pb == null ||
          pb.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(pb)) {
        continue;
      }
      if (bestRule == null ||
          sc > bestScore ||
          (sc == bestScore &&
              r.name.trim().length > bestRule.name.trim().length)) {
        bestRule = r;
        bestScore = sc;
      }
    }
    if (bestRule == null) {
      bestScore = -1;
      for (final r in candidates) {
        final sc = r.categoryConsecutiveTokenMatchScoreForTitle(title);
        if (sc <= 0) continue;
        final pb = _categoryBackendRowIdStrict(r);
        if (pb == null ||
            pb.isEmpty ||
            !DatabaseService._isLikelyPocketBaseRowId(pb)) {
          continue;
        }
        if (bestRule == null ||
            sc > bestScore ||
            (sc == bestScore &&
                r.name.trim().length > bestRule.name.trim().length)) {
          bestRule = r;
          bestScore = sc;
        }
      }
    }
    if (bestRule == null) {
      bestScore = -1;
      for (final r in candidates) {
        final sc = r.categoryTokenSetOverlapScoreForTitle(title);
        if (sc <= 0) continue;
        final pb = _categoryBackendRowIdStrict(r);
        if (pb == null ||
            pb.isEmpty ||
            !DatabaseService._isLikelyPocketBaseRowId(pb)) {
          continue;
        }
        if (bestRule == null ||
            sc > bestScore ||
            (sc == bestScore &&
                r.name.trim().length > bestRule.name.trim().length)) {
          bestRule = r;
          bestScore = sc;
        }
      }
    }
    if (bestRule == null) {
      bestScore = -1;
      for (final r in candidates) {
        final sc = r.categoryFuzzyMatchScoreForTitle(title);
        if (sc <= 0) continue;
        final pb = _categoryBackendRowIdStrict(r);
        if (pb == null ||
            pb.isEmpty ||
            !DatabaseService._isLikelyPocketBaseRowId(pb)) {
          continue;
        }
        if (bestRule == null ||
            sc > bestScore ||
            (sc == bestScore &&
                r.name.trim().length > bestRule.name.trim().length)) {
          bestRule = r;
          bestScore = sc;
        }
      }
    }
    if (bestRule != null) {
      final pb = _categoryBackendRowIdStrict(bestRule);
      if (pb != null && pb.isNotEmpty) {
        return pb;
      }
    }
    return null;
  }

  /// When [cid] is null or zero, fill from [_findBestCategoryMatch] so POST/optimistic body agree.
  int? _resolveRecordCategoryIdWithSmartLink(String title, int? cid) {
    if (cid != null && cid != 0) return cid;
    final pb = _findBestCategoryMatch(title);
    if (pb == null) return cid;
    return getCategoryRuleByBackendRowId(pb)?.id ?? cid;
  }

  /// Dropped from title/category tokens when scoring overlap ([_smartInferCategoryId]).
  static const Set<String> _smartInferNoiseWords = {
    'services',
    'call',
    'task',
    'app',
    'work',
    'project',
    'add',
    'sin',
  };

  static final RegExp _smartInferNonWordOrUnderscore = RegExp(
    r'[\W_]+',
    unicode: true,
  );

  static final RegExp _smartInferWhitespaceRun = RegExp(r'\s+');

  Set<String> _smartInferMeaningfulTokens(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.isEmpty) return {};
    s = s.replaceAll(_smartInferNonWordOrUnderscore, ' ');
    s = s.replaceAll(_smartInferWhitespaceRun, ' ').trim();
    if (s.isEmpty) return {};
    return {
      for (final w in s.split(' '))
        if (w.isNotEmpty && !_smartInferNoiseWords.contains(w)) w,
    };
  }

  String _smartInferCollapsedLower(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(_smartInferNonWordOrUnderscore, ' ');
    return s.replaceAll(_smartInferWhitespaceRun, ' ').trim();
  }

  /// Word-overlap + substring heuristic on cached [_rules] only (no AI / network).
  ///
  /// Normalizes text, tokenizes, ignores [_smartInferNoiseWords], then:
  /// - Match if meaningful token intersection size ≥ 2, OR
  /// - collapsed category name (length ≥ 3) is a substring of collapsed title.
  /// Tie-break: larger intersection, then substring bonus, then longer category name.
  int? _smartInferCategoryId(String title) {
    final t = title.trim();
    if (t.isEmpty) return null;
    final titleTokens = _smartInferMeaningfulTokens(t);
    final normTitle = _smartInferCollapsedLower(t);
    if (normTitle.isEmpty) return null;

    CategoryRule? best;
    var bestOverlap = -1;
    var bestSubstrBonus = 0;
    var bestNameLen = -1;

    void consider(CategoryRule r) {
      if (r.isArchived) return;
      if (r.id == CategoryRule.uncategorizedSyntheticId) return;
      final pb = _categoryBackendRowIdStrict(r);
      if (pb == null ||
          pb.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(pb)) {
        return;
      }
      final name = r.name.trim();
      if (name.isEmpty) return;
      final catTokens = _smartInferMeaningfulTokens(name);
      var overlap = 0;
      for (final w in catTokens) {
        if (titleTokens.contains(w)) overlap++;
      }
      final normCat = _smartInferCollapsedLower(name);
      final substr = normCat.length >= 3 && normTitle.contains(normCat);
      final isMatch = overlap >= 2 || substr;
      if (!isMatch) return;
      final subBonus = substr ? 1 : 0;
      if (overlap > bestOverlap ||
          (overlap == bestOverlap && subBonus > bestSubstrBonus) ||
          (overlap == bestOverlap &&
              subBonus == bestSubstrBonus &&
              name.length > bestNameLen)) {
        best = r;
        bestOverlap = overlap;
        bestSubstrBonus = subBonus;
        bestNameLen = name.length;
      }
    }

    void walk(List<CategoryRule> nodes) {
      for (final r in nodes) {
        consider(r);
        if (r.children != null) walk(r.children!);
      }
    }

    walk(_rules);
    return best?.id;
  }

  /// Voice / quick map: deepest category match + path label.
  ({int id, String path})? findCategoryByFuzzyMatch(String title) {
    final r = identifyCategory(title);
    if (r == null) return null;
    return (id: r.id, path: getCategoryPath(r.id));
  }

  int? _resolveCategoryIdForEditedTitle({
    required String? newTitle,
    required String? oldTitle,
    required int? currentCategoryId,
    required bool manualCategoryChanged,
  }) {
    if (manualCategoryChanged) return null;
    final t = newTitle?.trim() ?? '';
    if (t.isEmpty) return null;
    final old = oldTitle?.trim() ?? '';
    if (old.isNotEmpty && old == t) return null;
    final match = identifyCategory(t);
    if (match == null || match.isArchived) return null;
    if (match.id == CategoryRule.uncategorizedSyntheticId) return null;
    if (currentCategoryId != null && match.id == currentCategoryId) return null;
    final pb = _categoryBackendRowIdStrict(match);
    if (pb == null ||
        pb.isEmpty ||
        !DatabaseService._isLikelyPocketBaseRowId(pb)) {
      return null;
    }
    return match.id;
  }

  String? _categoryRelationIdForPlanPatch(int? localCategoryId) {
    if (!_planLocalCategoryIdIsConcrete(localCategoryId)) return null;
    final rule = getCategoryRuleById(localCategoryId!);
    if (rule == null || rule.isArchived) return null;
    final pb = _categoryBackendRowIdStrict(rule);
    if (pb != null &&
        pb.isNotEmpty &&
        DatabaseService._isLikelyPocketBaseRowId(pb)) {
      return pb;
    }
    return null;
  }

  List<({int id, String path})> get allCategoryIdPathPairs {
    final out = <({int id, String path})>[];
    void visit(List<CategoryRule> rules, List<String> soFar) {
      for (final r in rules) {
        if (r.isArchived) continue;
        final path = [...soFar, r.name].join(' > ');
        out.add((id: r.id, path: path));
        if (r.children != null) visit(r.children!, [...soFar, r.name]);
      }
    }

    visit(_rules, []);
    return out;
  }

  bool categoryExists(int categoryId) {
    bool found = false;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == categoryId) found = true;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  String getCategoryPath(int categoryId) {
    final parts = <String>[];
    void collect(List<CategoryRule> rules, List<String> soFar) {
      for (final r in rules) {
        final next = [...soFar, r.name];
        if (r.id == categoryId) {
          parts.addAll(next);
          return;
        }
        if (r.children != null) collect(r.children!, next);
      }
    }

    collect(_rules, []);
    return parts.isEmpty ? 'Life' : parts.join(' > ');
  }

  /// Full breadcrumb paths for Smart Plan AI (cached [_rules] only — no network).
  List<String> smartPlanAllowedCategoryLabels() {
    final out = <String>[];
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        out.add(getCategoryPath(r.id));
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    out.sort();
    return out;
  }

  /// Maps a Smart Plan [category] string from the LLM to a local category id
  /// (trimmed, case-insensitive path match, then unique leaf [CategoryRule.name]).
  int? resolveCategoryIdFromSmartPlanLabel(String? rawLabel) {
    if (rawLabel == null) return null;
    final t = rawLabel.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    if (lower == 'uncategorized' || lower == 'null' || lower == 'none') {
      return null;
    }

    final normLabel = normalizeCategoryLabel(t);

    int? foundId;
    void matchPath(List<CategoryRule> rules) {
      if (foundId != null) return;
      for (final r in rules) {
        if (foundId != null) return;
        if (r.isArchived) {
          if (r.children != null) matchPath(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) matchPath(r.children!);
          continue;
        }
        final path = getCategoryPath(r.id);
        if (normalizeCategoryLabel(path) == normLabel) {
          foundId = r.id;
          return;
        }
        if (r.children != null) matchPath(r.children!);
      }
    }

    matchPath(_rules);
    if (foundId != null) return foundId;

    CategoryRule? hit;
    var ambiguous = false;
    void matchLeaf(List<CategoryRule> rules) {
      if (ambiguous) return;
      for (final r in rules) {
        if (ambiguous) return;
        if (r.isArchived) {
          if (r.children != null) matchLeaf(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) matchLeaf(r.children!);
          continue;
        }
        if (normalizeCategoryLabel(r.name) == normLabel) {
          if (hit != null && hit!.id != r.id) ambiguous = true;
          hit = r;
        }
        if (r.children != null) matchLeaf(r.children!);
      }
    }

    matchLeaf(_rules);
    if (!ambiguous && hit != null) return hit!.id;

    final atBest = <CategoryRule>[];
    var bestFuzzy = -1;
    void matchLeafFuzzy(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) matchLeafFuzzy(r.children!);
          continue;
        }
        if (r.id == CategoryRule.uncategorizedSyntheticId) {
          if (r.children != null) matchLeafFuzzy(r.children!);
          continue;
        }
        final sc = fuzzyPhraseScoreAgainstTitle(
          normLabel,
          normalizeCategoryLabel(r.name),
        );
        if (sc <= 0) continue;
        if (sc > bestFuzzy) {
          bestFuzzy = sc;
          atBest
            ..clear()
            ..add(r);
        } else if (sc == bestFuzzy) {
          atBest.add(r);
        }
        if (r.children != null) matchLeafFuzzy(r.children!);
      }
    }

    matchLeafFuzzy(_rules);
    if (bestFuzzy > 0 && atBest.length == 1) return atBest.first.id;
    return null;
  }

  int? resolvedCategoryIdForRecord(Map<String, dynamic> rec) {
    final cid = rec['categoryId'];
    if (cid == null) return null;
    if (cid is int) return cid;
    final parsed = int.tryParse(cid.toString());
    if (parsed != null) return parsed;
    final key = rec['categoryKey']?.toString();
    if (key != null && key.trim().isNotEmpty) {
      return findCategoryIdForStoredCategoryKey(key);
    }
    return findCategoryIdForStoredCategoryKey(cid.toString());
  }

  String resolvedCategoryPathForRecord(Map<String, dynamic> rec) {
    final resolved = resolvedCategoryIdForRecord(rec);
    if (resolved != null) return getCategoryPath(resolved);
    return 'Life';
  }

  int? findCategoryIdByNormalizedTag(String tag) {
    final t = tag.toLowerCase().replaceAll(' ', '');
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        final n = (r.normalizedId ?? r.name).toLowerCase().replaceAll(' ', '');
        if (n == t) found = r.id;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  int? findCategoryIdByTag(String tag) {
    final t = tag.trim().toLowerCase();
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.name.trim().toLowerCase() == t) found = r.id;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }
}
