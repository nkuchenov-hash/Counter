// Part of lib/data/models.dart — Category, CategoryNameInputStatus, CategoryRule, tag-rule helpers.
// Split per ROADMAP Tier 4.2 (April 2026).
part of '../models.dart';

class Category {
  const Category({
    required this.id,
    required this.userId,
    this.name,
    this.tag,
    this.parentId,
    this.normalizedId,
    this.colorValue,
    this.iconCodePoint,
    this.defaultPlanTime,
    this.defaultPlanTimezone,
    this.isArchived = false,
  });

  final String id;
  final int userId;

  /// Display name (@DATA_MAP column `name`).
  final String? name;

  /// Legacy display label; prefer [name] when present.
  final String? tag;
  final int? parentId;
  final String? normalizedId;
  final int? colorValue;
  final int? iconCodePoint;
  final String? defaultPlanTime;
  final String? defaultPlanTimezone;
  final bool isArchived;

  factory Category.fromJson(Map<String, dynamic> json) {
    final pid = json['parent_id'];
    final rawId = json['id'] ?? json['category_id'] ?? json['Id'];
    final nameRaw = json['name']?.toString().trim() ?? '';
    final legacyTag = json['tag']?.toString().trim();
    final normRaw = json['normalized_id']?.toString().trim() ?? '';
    final resolvedName = nameRaw.isNotEmpty
        ? nameRaw
        : (legacyTag != null && legacyTag.isNotEmpty)
        ? legacyTag
        : (normRaw.isNotEmpty ? normRaw : null);
    final display =
        resolvedName ??
        (normRaw.isNotEmpty ? normRaw : null) ??
        (legacyTag != null && legacyTag.isNotEmpty ? legacyTag : null);
    final arc = json['is_archived'] ?? json['isArchived'];
    final isArc =
        arc == true ||
        arc == 1 ||
        (arc is String && arc.toLowerCase().trim() == 'true');
    return Category(
      id: (rawId ?? '').toString(),
      userId: _jsonInt(json['user_id']),
      name: resolvedName,
      tag: display ?? 'Untitled',
      parentId: pid == null || pid.toString().isEmpty ? null : _jsonInt(pid),
      normalizedId: json['normalized_id']?.toString(),
      colorValue: json['color_value'] is int
          ? json['color_value'] as int
          : int.tryParse(json['color_value']?.toString() ?? ''),
      iconCodePoint: json['icon_code_point'] is int
          ? json['icon_code_point'] as int
          : int.tryParse(json['icon_code_point']?.toString() ?? ''),
      defaultPlanTime: json['default_plan_time']?.toString().trim(),
      defaultPlanTimezone: json['default_plan_timezone']?.toString().trim(),
      isArchived: isArc,
    );
  }

  /// Subset of PocketBase `categories` columns (@DATA_MAP.md) for diagnostics / cache.
  /// Note: [userId] is a local int hash of `user_id` when the server sends non-numeric ids
  /// ([_jsonInt]); do not use this map as a verbatim POST body for relation fields.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    if (name != null && name!.isNotEmpty) 'name': name,
    if (normalizedId != null && normalizedId!.isNotEmpty)
      'normalized_id': normalizedId,
    if (parentId != null) 'parent_id': parentId,
    if (colorValue != null) 'color_value': colorValue,
    if (iconCodePoint != null) 'icon_code_point': iconCodePoint,
    if (defaultPlanTime != null && defaultPlanTime!.isNotEmpty)
      'default_plan_time': defaultPlanTime,
    if (defaultPlanTimezone != null && defaultPlanTimezone!.isNotEmpty)
      'default_plan_timezone': defaultPlanTimezone,
    'is_archived': isArchived,
  };
}

/// Create-category dialog: name availability vs active tree + archived PB rows.
enum CategoryNameInputKind { empty, available, active, archived }

class CategoryNameInputStatus {
  const CategoryNameInputStatus._({
    required this.kind,
    this.activeLocalId,
    this.archivedPbRowId,
  });

  final CategoryNameInputKind kind;
  final int? activeLocalId;
  final String? archivedPbRowId;

  static const CategoryNameInputStatus empty = CategoryNameInputStatus._(
    kind: CategoryNameInputKind.empty,
  );

  static const CategoryNameInputStatus available = CategoryNameInputStatus._(
    kind: CategoryNameInputKind.available,
  );

  factory CategoryNameInputStatus.active(int localId) {
    return CategoryNameInputStatus._(
      kind: CategoryNameInputKind.active,
      activeLocalId: localId,
    );
  }

  factory CategoryNameInputStatus.archived(String pbRowId) {
    return CategoryNameInputStatus._(
      kind: CategoryNameInputKind.archived,
      archivedPbRowId: pbRowId,
    );
  }
}

/// Noco `@DATA_MAP` checklist: column may be JSON **String** or decoded List.
List<Map<String, dynamic>>? parseChecklistFromNoco(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) {
    if (raw.isEmpty) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(Map<String, dynamic>.from(e));
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final d = jsonDecode(s);
      if (d is List) {
        final out = <Map<String, dynamic>>[];
        for (final e in d) {
          if (e is Map<String, dynamic>) {
            out.add(Map<String, dynamic>.from(e));
          } else if (e is Map) {
            out.add(Map<String, dynamic>.from(e));
          }
        }
        return out;
      }
    } catch (_) {}
  }
  return null;
}

/// Same as [parseChecklistFromNoco] but never null (empty list default).
List<Map<String, dynamic>> parseChecklistFromNocoList(dynamic raw) =>
    parseChecklistFromNoco(raw) ?? const [];

/// Merge legacy Noco `notes` into singular `note` (migration path).
String? mergeRecordNoteFields(dynamic noteRaw, dynamic notesRaw) {
  final a = noteRaw?.toString().trim() ?? '';
  final b = notesRaw?.toString().trim() ?? '';
  if (a.isEmpty && b.isEmpty) return null;
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  return '$a\n$b';
}

/// NocoDB record row (flat). Keys match table mjchwhned7zsvj0 exactly; all mapping uses data = json['fields'] ?? json.

int _stableStringHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (31 * h + c) & 0x7FFFFFFF;
  }
  return h == 0 ? 1 : h;
}

/// Calendar day from `start_time` using profile [offsetHours] (UTC + offset, no device TZ).
DateTime? _recordLocalCalendarDate(dynamic v, [int offsetHours = 0]) {
  if (v == null) return null;
  DateTime? parsed;
  if (v is DateTime) {
    parsed = v.isUtc ? v : v.toUtc();
  } else {
    var s = v.toString().trim();
    if (s.isEmpty) return null;
    if (s.contains(' ') && !s.contains('T')) {
      s = s.replaceFirst(' ', 'T');
    }
    final hasTz =
        s.endsWith('Z') ||
        s.contains('+') ||
        (s.length > 11 && s.substring(11).contains('-'));
    parsed = DateTime.tryParse(hasTz ? s : '${s}Z');
  }
  if (parsed == null) return null;
  final wall = parsed.toUtc().add(Duration(hours: offsetHours));
  return DateTime(wall.year, wall.month, wall.day);
}

/// Strict hierarchical category. Supports optional keywords per language (MULTILINGUAL_KEYWORDS).
class CategoryRule {
  /// Synthetic id for records whose Noco `category_id` does not match any loaded rule.
  static const int uncategorizedSyntheticId = -1;

  CategoryRule({
    required this.id,
    required this.name,
    this.backendRowId,
    this.normalizedId,
    this.children,
    this.colorValue,
    this.iconCodePoint,
    this.defaultPlanTime,
    this.defaultPlanTimezone,
    this.keywords,
    this.localizedNames,
    this.order = 0,
    this.isArchived = false,
    this.isSynced = true,
  });

  factory CategoryRule.uncategorized() {
    return CategoryRule(
      id: uncategorizedSyntheticId,
      name: 'Uncategorized',
      backendRowId: 'uncategorized',
      normalizedId: 'uncategorized',
      isArchived: false,
      isSynced: true,
    );
  }

  final int id;

  /// @DATA_MAP.md `categories.name` (display name).
  String name;

  /// PocketBase **categories** collection record id (PATCH/DELETE).
  final String? backendRowId;
  final String? normalizedId;

  /// String business key from DB (e.g. slug / UUID). May differ from [name] when resolving archive unique constraints.
  String get categoryKey => (normalizedId ?? '').trim().isNotEmpty
      ? normalizedId!.trim()
      : (backendRowId ?? '').trim().isNotEmpty
      ? backendRowId!.trim()
      : name.trim();
  List<CategoryRule>? children;
  int? colorValue;
  int? iconCodePoint;
  String? defaultPlanTime;
  String? defaultPlanTimezone;

  /// @DATA_MAP.md `categories.order` — sibling sort index (integer); persisted via bulk PATCH.
  int order;

  /// @DATA_MAP `is_archived` — soft-deleted categories stay in DB but off active lists.
  /// Uniqueness checks and “category exists” logic must ignore archived rows (zombie slug conflicts).
  bool isArchived;

  /// Local-only: queued / cache state (not sent to PocketBase as a field).
  bool isSynced;
  Map<String, List<String>>? keywords;
  final Map<String, String>? localizedNames;

  CategoryRule copyWith({
    int? id,
    String? name,
    String? backendRowId,
    String? normalizedId,
    List<CategoryRule>? children,
    int? colorValue,
    int? iconCodePoint,
    String? defaultPlanTime,
    bool clearDefaultPlanTime = false,
    String? defaultPlanTimezone,
    bool clearDefaultPlanTimezone = false,
    Map<String, List<String>>? keywords,
    Map<String, String>? localizedNames,
    int? order,
    bool? isArchived,
    bool? isSynced,
  }) {
    final copiedChildren =
        children ??
        (this.children != null
            ? List<CategoryRule>.from(this.children!)
            : null);
    Map<String, List<String>>? copiedKeywords;
    if (keywords != null) {
      copiedKeywords = {};
      for (final entry in keywords.entries) {
        copiedKeywords[entry.key] = List<String>.from(entry.value);
      }
    } else if (this.keywords != null) {
      copiedKeywords = {};
      for (final entry in this.keywords!.entries) {
        copiedKeywords[entry.key] = List<String>.from(entry.value);
      }
    }
    return CategoryRule(
      id: id ?? this.id,
      name: name ?? this.name,
      backendRowId: backendRowId ?? this.backendRowId,
      normalizedId: normalizedId ?? this.normalizedId,
      children: copiedChildren,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      defaultPlanTime: clearDefaultPlanTime
          ? null
          : (defaultPlanTime ?? this.defaultPlanTime),
      defaultPlanTimezone: clearDefaultPlanTimezone
          ? null
          : (defaultPlanTimezone ?? this.defaultPlanTimezone),
      keywords: copiedKeywords,
      localizedNames: localizedNames ?? this.localizedNames,
      order: order ?? this.order,
      isArchived: isArchived ?? this.isArchived,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  List<String> keywordsFor(String lang) =>
      (keywords != null && keywords!.containsKey(lang))
      ? List<String>.from(keywords![lang]!)
      : [];

  Color get colorOrDefault {
    if (colorValue != null) return Color(colorValue!);
    return Colors.grey;
  }

  IconData get iconOrDefault {
    if (iconCodePoint != null) {
      return IconData(iconCodePoint!, fontFamily: 'MaterialIcons');
    }
    return Icons.folder_rounded;
  }

  static bool _isAsciiWordCharAt(String s, int i) {
    if (i < 0 || i >= s.length) return false;
    final c = s.codeUnitAt(i);
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a);
  }

  /// Longest [needleLower] length if it appears in [hayLower] at word boundaries (not inside a longer token).
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
    if (fragmentLower.isEmpty) return;
    if (fragmentLower.length < 2) return;
    final a = _wordBoundedOccurrenceScore(tLower, fragmentLower);
    if (a > 0) onScore(a);
    final b = _wordBoundedOccurrenceScore(fragmentLower, tLower);
    if (b > 0) onScore(b);
  }

  static String _categoryTokenAliasOrSelf(String tok) =>
      kCategoryMatchingTokenAliases[tok] ?? tok;

  /// Aligns normalized title tokens with a category phrase (name or keyword tokens).
  /// Skips numeric-only title tokens so `laredo 10` can still match `laredo ts`.
  /// Exact token equality scores higher than prefix-of-category-token ([ct.startsWith(tt)]).
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

  /// Case-insensitive token / prefix match (uses [normalizeCategoryLabel]).
  /// Runs after substring [categoryExactMatchScoreForTitle], before fuzzy Levenshtein.
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

    considerFrag(name);
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          considerFrag(kw);
        }
      }
    }
    return best;
  }

  /// ≥60% of unique category tokens (whole words, [normalizeCategoryLabel]) appear in [title].
  /// Score band below consecutive-token matches; use when strict ordering misses (e.g. missing "Services").
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

    considerFrag(name);
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          considerFrag(kw);
        }
      }
    }
    return best;
  }

  /// Highest word-bounded match length for [name] / **keywords** vs [title]
  /// using [normalizeCategoryLabel] for both sides (exact substring at token boundaries).
  /// Longer matches win over shorter ones (e.g. "NIS SOLUTIONS" beats "CRM" in the same title).
  int categoryExactMatchScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    var best = 0;
    final selfName = normalizeCategoryLabel(name);
    if (selfName.isNotEmpty) {
      _accumulatePairScores(nt, selfName, (len) => best = max(best, len));
    }
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          final k = normalizeCategoryLabel(kw);
          if (k.isNotEmpty) {
            _accumulatePairScores(nt, k, (len) => best = max(best, len));
          }
        }
      }
    }
    return best;
  }

  /// Fuzzy (Levenshtein-gated) score when [categoryExactMatchScoreForTitle] is zero.
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

  /// True when substring, consecutive-token, token-set majority, or fuzzy match applies.
  bool matchesTitleWholeWordKeywords(String title) =>
      categoryExactMatchScoreForTitle(title) > 0 ||
      categoryConsecutiveTokenMatchScoreForTitle(title) > 0 ||
      categoryTokenSetOverlapScoreForTitle(title) > 0 ||
      categoryFuzzyMatchScoreForTitle(title) > 0;

  CategoryRule? findDeepestMatch(
    String title, {
    required int Function(CategoryRule rule, String title) scoreFor,
  }) {
    if (title.trim().isEmpty) return null;
    CategoryRule? best;
    var bestScore = -1;
    var bestDepth = -1;
    var bestNameLen = -1;

    void visit(CategoryRule r, int depth) {
      if (depth > 4) return;
      if (!r.isArchived) {
        final sc = scoreFor(r, title);
        if (sc > 0) {
          final nameLen = r.name.trim().length;
          if (best == null ||
              sc > bestScore ||
              (sc == bestScore && depth > bestDepth) ||
              (sc == bestScore &&
                  depth == bestDepth &&
                  nameLen > bestNameLen)) {
            best = r;
            bestScore = sc;
            bestDepth = depth;
            bestNameLen = nameLen;
          }
        }
      }
      for (final c in r.children ?? []) {
        visit(c, depth + 1);
      }
    }

    visit(this, 0);
    return best;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (backendRowId != null && backendRowId!.isNotEmpty)
      'backendRowId': backendRowId,
    if (normalizedId != null && normalizedId!.isNotEmpty)
      'normalizedId': normalizedId,
    if (children != null && children!.isNotEmpty)
      'children': children!.map((c) => c.toJson()).toList(),
    if (colorValue != null) 'colorValue': colorValue,
    if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
    if (keywords != null && keywords!.isNotEmpty)
      'keywords': keywords!.map((k, v) => MapEntry(k, v)),
    if (localizedNames != null && localizedNames!.isNotEmpty)
      'localizedNames': localizedNames,
    'order': order,
    'isArchived': isArchived,
  };

  factory CategoryRule.fromJson(Map<String, dynamic> json) {
    final data = (json['fields'] ?? json) as Map<String, dynamic>;
    final rawId =
        (json['id'] ??
                json['category_id'] ??
                data['id'] ??
                data['category_id'] ??
                '')
            .toString();
    final nameStr = (data['name'] ?? json['name'])?.toString().trim() ?? '';
    final tagStr = (data['tag'] ?? json['tag'])?.toString().trim() ?? '';
    final normStr =
        (data['normalized_id'] ?? data['normalizedId'])?.toString().trim() ??
        '';
    final safeTag = nameStr.isNotEmpty
        ? nameStr
        : (tagStr.isNotEmpty
              ? tagStr
              : (normStr.isNotEmpty ? normStr : 'Untitled'));
    final rawChildren = data['children'];
    final List<CategoryRule> children = rawChildren is List
        ? (rawChildren)
              .whereType<Map<String, dynamic>>()
              .map(CategoryRule.fromJson)
              .toList()
        : [];
    final rawKeywords = data['keywords'];
    Map<String, List<String>>? keywords;
    if (rawKeywords is Map) {
      keywords = {};
      for (final e in rawKeywords.entries) {
        if (e.key is! String) continue;
        final list = e.value;
        if (list is List) {
          keywords[e.key as String] = list
              .map((x) => x?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          keywords[e.key as String] = [];
        }
      }
      if (keywords.isEmpty) keywords = null;
    }
    Map<String, String>? localizedNames;
    final rawNames = data['localized_names'] ?? data['localizedNames'];
    if (rawNames is Map) {
      final map = <String, String>{};
      for (final entry in rawNames.entries) {
        final k = entry.key?.toString();
        final v = entry.value?.toString();
        if (k != null && k.isNotEmpty && v != null && v.isNotEmpty) {
          map[k] = v;
        }
      }
      if (map.isNotEmpty) {
        localizedNames = Map<String, String>.from(map);
      }
    }
    final colorRaw = data['color_value'] ?? data['colorValue'];
    final iconRaw = data['icon_code_point'] ?? data['iconCodePoint'];
    final orderRaw = data['order'];
    final orderVal = orderRaw is int
        ? orderRaw
        : int.tryParse(orderRaw?.toString() ?? '') ?? 0;
    final archivedRaw = data['is_archived'] ?? data['isArchived'];
    final isArc =
        archivedRaw == true ||
        archivedRaw == 1 ||
        (archivedRaw is String && archivedRaw.toLowerCase().trim() == 'true');
    return CategoryRule(
      id: int.tryParse(rawId) ?? _stableStringHash(rawId),
      name: safeTag,
      backendRowId: rawId,
      normalizedId:
          (data['category_id'] ??
                  data['id1'] ??
                  data['normalized_id'] ??
                  data['normalizedId'])
              ?.toString(),
      children: children.isEmpty ? null : children,
      colorValue: colorRaw is int
          ? colorRaw
          : (colorRaw != null ? int.tryParse(colorRaw.toString()) : null),
      iconCodePoint: iconRaw is int
          ? iconRaw
          : (iconRaw != null ? int.tryParse(iconRaw.toString()) : null),
      keywords: keywords,
      localizedNames: localizedNames,
      order: orderVal,
      isArchived: isArc,
      isSynced: _jsonBool(data['isSynced'] ?? json['isSynced'], true),
    );
  }
}

/// In-memory representation of a timeline record. Hierarchy: parentId + [id].

const List<double> _pathOpacities = [1.0, 0.8, 0.6, 0.4];

CategoryRule? _findRuleForTag(List<CategoryRule> rules, String tag) {
  final t = tag.trim().toLowerCase();
  for (final r in rules) {
    if (r.name.trim().toLowerCase() == t) return r;
    if (r.children != null) {
      final found = _findRuleForTag(r.children!, tag);
      if (found != null) return found;
    }
  }
  return null;
}

int _tagDepth(List<CategoryRule> rules, String tag, int depth) {
  if (depth > 4) return -1;
  final t = tag.trim().toLowerCase();
  for (final r in rules) {
    if (r.name.trim().toLowerCase() == t) return depth;
    if (r.children != null) {
      final d = _tagDepth(r.children!, tag, depth + 1);
      if (d >= 0) return d;
    }
  }
  return -1;
}

String getTagPath(
  List<CategoryRule> rules,
  String tag, [
  List<String> path = const [],
]) {
  final t = tag.trim().toLowerCase();
  if (t.isEmpty) return tag;
  for (final r in rules) {
    final tagName = r.name.trim();
    if (tagName.toLowerCase() == t) return [...path, tagName].join(' > ');
    if (r.children != null) {
      final found = getTagPath(r.children!, tag, [...path, tagName]);
      if (found != tag) return found;
    }
  }
  return tag;
}

Color getTagColorWithOpacity(List<CategoryRule> rules, String tag) {
  final depth = _tagDepth(rules, tag, 1);
  final level = (depth >= 1 && depth <= 4) ? depth : 1;
  final opacity = _pathOpacities[level - 1];
  final rule = _findRuleForTag(rules, tag);
  return (rule?.colorOrDefault ?? Colors.grey).withValues(alpha: opacity);
}
