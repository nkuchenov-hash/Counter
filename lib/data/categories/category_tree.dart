part of '../database_service.dart';

extension CategoryTreeExtension on DatabaseService {
  List<int> categoryPathFromRootToLocalId(int leafLocalId) {
    List<int>? found;
    bool walk(CategoryRule node, List<int> prefix) {
      final path = [...prefix, node.id];
      if (node.id == leafLocalId) {
        found = path;
        return true;
      }
      for (final c in node.children ?? []) {
        if (walk(c, path)) return true;
      }
      return false;
    }

    for (final r in _rules) {
      if (walk(r, [])) break;
    }
    return found ?? const [];
  }

  CategoryRule? getCategoryRuleByBackendRowId(String pocketBaseRowId) {
    final t = pocketBaseRowId.trim();
    if (t.isEmpty) return null;
    CategoryRule? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if ((r.backendRowId ?? '').trim() == t) {
          found = r;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  int? findActiveLocalCategoryIdByDisplayName(String displayName) {
    final key = displayName.trim().toLowerCase();
    if (key.isEmpty) return null;
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.isArchived) {
          if (r.children != null) visit(r.children!);
          continue;
        }
        if (r.name.trim().toLowerCase() == key) {
          found = r.id;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }

  CategoryNameInputStatus classifyCategoryDisplayNameInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return CategoryNameInputStatus.empty;
    final activeId = findActiveLocalCategoryIdByDisplayName(trimmed);
    if (activeId != null) {
      return CategoryNameInputStatus.active(activeId);
    }
    final key = trimmed.toLowerCase();
    for (final e in _categoryDialogUniverse) {
      if ((e['nameLower'] as String?) != key) continue;
      if (e['isArchived'] == true) {
        final pb = (e['pbRowId'] ?? '').toString().trim();
        if (pb.isNotEmpty) return CategoryNameInputStatus.archived(pb);
      }
    }
    return CategoryNameInputStatus.available;
  }

  /// Sets `is_archived` false on a PocketBase **categories** row. Returns local id after reload.
  static int _rowInt(dynamic v, [int d = 0]) {
    if (v == null) return d;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? d;
  }

  /// Local [CategoryRule.id] only when Noco wrapper id is non-numeric — **not** for auth/`user_id`.
  static int _hashStringToPositiveIntForCategoryTreeLocalIdOnly(
    String raw, [
    int fallback = 0,
  ]) {
    final s = raw.trim();
    if (s.isEmpty) return fallback;
    var hash = 2166136261;
    for (final u in s.codeUnits) {
      hash ^= u;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    if (hash == 0) return fallback;
    return hash;
  }

  /// `true` if Noco sent an explicit `order` (including `0`); `false` if null / missing / empty string.
  static bool _categoryOrderRawIsExplicit(dynamic orderRaw) {
    if (orderRaw == null) return false;
    if (orderRaw is String && orderRaw.trim().isEmpty) return false;
    return true;
  }

  /// Normalizes flat NocoDB list into hierarchical CategoryRule tree. Re-links parents and children via parent_id; returns only roots.
  ///
  /// Second return: sibling groups that had null/missing `order` — each list shares one `parent_id` (roots use `''` key), renumbered 0..n−1 for persistence (@DATA_MAP §8).
  (List<CategoryRule> roots, List<List<CategoryRule>> orderInitGroups)
  _buildCategoryTreeFromFlat(List<Map<String, dynamic>> flat) {
    final all = <CategoryRule>[];
    final lookup = <String, CategoryRule>{};
    final parentIdsById = <int, String?>{};
    final orderExplicitByLocalId = <int, bool>{};
    for (final row in flat) {
      final fields = (row['fields'] is Map)
          ? Map<String, dynamic>.from(row['fields'] as Map)
          : row;
      final bizCategoryId =
          (fields['category_id'] ?? fields['Category_id'])?.toString().trim() ??
          '';
      final sysObj = row[DatabaseService._nocoSystemRowIdKey];
      final wrapperPk =
          ((sysObj != null && sysObj.toString().trim().isNotEmpty)
              ? sysObj.toString().trim()
              : (row['id'] ?? row['Id'])?.toString().trim()) ??
          '';
      final internalRowStr = wrapperPk;
      String? normalizedForMatching = bizCategoryId.isNotEmpty
          ? bizCategoryId
          : null;
      if (normalizedForMatching == null || normalizedForMatching.isEmpty) {
        final n = fields['normalized_id']?.toString().trim();
        if (n != null && n.isNotEmpty) normalizedForMatching = n;
      }
      final wrapperInt = _rowInt(wrapperPk);
      // Local list id = Noco wrapper **Id** when present (@DATA_MAP); else stable key from business fields only.
      final int nodeLocalId = wrapperInt != 0
          ? wrapperInt
          : _hashStringToPositiveIntForCategoryTreeLocalIdOnly(
              bizCategoryId.isNotEmpty
                  ? bizCategoryId
                  : (normalizedForMatching ??
                        fields['normalized_id']?.toString() ??
                        fields['tag']?.toString() ??
                        fields['name']?.toString() ??
                        'unknown'),
              1,
            );
      final pidRaw = row['parent_id'];
      final pidFlat = normalizeLinkScalar(pidRaw) ?? pidRaw;
      final parentIdStr = pidFlat == null || pidFlat.toString().trim().isEmpty
          ? null
          : pidFlat.toString().trim();
      parentIdsById[nodeLocalId] = parentIdStr;
      Map<String, List<String>>? keywords;
      final rawKw = row['keywords'];
      dynamic kwDecoded = rawKw;
      if (rawKw is String && rawKw.trim().isNotEmpty) {
        try {
          kwDecoded = jsonDecode(rawKw);
        } catch (_) {
          kwDecoded = null;
        }
      }
      if (kwDecoded is Map) {
        keywords = {};
        for (final e in kwDecoded.entries) {
          keywords[e.key.toString()] = e.value is List
              ? (e.value as List).map((x) => x.toString()).toList()
              : <String>[];
        }
      }
      Map<String, String>? loc;
      final rawLoc = row['localized_names'];
      dynamic locDecoded = rawLoc;
      if (rawLoc is String && rawLoc.trim().isNotEmpty) {
        try {
          locDecoded = jsonDecode(rawLoc);
        } catch (_) {
          locDecoded = null;
        }
      }
      if (locDecoded is Map) {
        loc = {};
        for (final e in locDecoded.entries) {
          loc[e.key.toString()] = e.value?.toString() ?? '';
        }
      }
      final orderRaw = row['order'] ?? fields['order'];
      final orderExplicit = _categoryOrderRawIsExplicit(orderRaw);
      orderExplicitByLocalId[nodeLocalId] = orderExplicit;
      final archRaw = row['is_archived'] ?? fields['is_archived'];
      final isArchivedCat = _jsonBoolFromDynamic(archRaw);
      final node = CategoryRule(
        id: nodeLocalId,
        name: CategoryRecordBridgeExtension._categoryDisplayNameFromRow(row),
        backendRowId: internalRowStr.isNotEmpty ? internalRowStr : null,
        normalizedId: normalizedForMatching,
        children: <CategoryRule>[],
        colorValue: _rowInt(row['color_value'], 0) == 0
            ? null
            : _rowInt(row['color_value']),
        iconCodePoint: _rowInt(row['icon_code_point'], 0) == 0
            ? null
            : _rowInt(row['icon_code_point']),
        defaultPlanTime: sanitizeDefaultPlanTime(row['default_plan_time']),
        defaultPlanTimezone: sanitizeDefaultPlanTimezone(
          row['default_plan_timezone'],
        ),
        keywords: keywords,
        localizedNames: loc,
        order: orderExplicit ? _rowInt(orderRaw) : 0,
        isArchived: isArchivedCat,
      );
      all.add(node);
      if (internalRowStr.isNotEmpty) lookup[internalRowStr] = node;
      if (bizCategoryId.isNotEmpty) lookup[bizCategoryId] = node;
      final nk = node.normalizedId?.trim();
      if (nk != null && nk.isNotEmpty) lookup[nk] = node;
      lookup[nodeLocalId.toString()] = node;
      final pbRowKey = (row['_pb_record_id'] ?? row['id'] ?? row['Id'])
          ?.toString()
          .trim();
      if (pbRowKey != null && pbRowKey.isNotEmpty) {
        lookup[pbRowKey] = node;
      }
    }
    var linksCreated = 0;
    for (final node in all) {
      final parentIdStr = parentIdsById[node.id];
      if (parentIdStr == null || parentIdStr.isEmpty) continue;
      final parent = lookup[parentIdStr];
      if (parent != null) {
        parent.children ??= <CategoryRule>[];
        parent.children!.add(node);
        linksCreated++;
      }
      // Missing parent: do not link — node is promoted to root in the pass below (dumb tree, always visible).
    }

    final roots = <CategoryRule>[];
    for (final node in all) {
      final parentIdStr = parentIdsById[node.id];
      if (parentIdStr == null ||
          parentIdStr.isEmpty ||
          lookup[parentIdStr] == null) {
        roots.add(node);
      }
    }

    final buckets = <String, List<CategoryRule>>{};
    for (final n in all) {
      final p = parentIdsById[n.id];
      final key = (p == null || p.isEmpty) ? '' : p;
      buckets.putIfAbsent(key, () => <CategoryRule>[]).add(n);
    }
    final orderInitGroups = <List<CategoryRule>>[];
    for (final bucket in buckets.values) {
      final anyImplicit = bucket.any(
        (n) => orderExplicitByLocalId[n.id] != true,
      );
      if (anyImplicit) {
        for (var i = 0; i < bucket.length; i++) {
          bucket[i].order = i;
        }
        orderInitGroups.add(List<CategoryRule>.from(bucket));
      }
    }

    DatabaseService._log(
      'TREE DEBUG: Total Categories: ${all.length}. Roots: ${roots.length}. Links: $linksCreated. Order init groups: ${orderInitGroups.length}',
    );
    _sortCategoryBranch(roots);
    return (roots, orderInitGroups);
  }

  void _sortCategoryBranch(List<CategoryRule> nodes) {
    nodes.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.id.compareTo(b.id);
    });
    for (final n in nodes) {
      final ch = n.children;
      if (ch != null && ch.isNotEmpty) {
        _sortCategoryBranch(ch);
      }
    }
  }

  DateTime _profileWallFromUtc(DateTime utc) => wall_clock.toWallClockForLabel(
    utc.toUtc(),
    _settings.timezoneOffsetHours,
    _settings.preferredTimeZone,
  );

  DateTime _profileUtcFromWall(DateTime naive) =>
      wall_clock.wallClockToUtcForLabel(
        naive,
        _settings.timezoneOffsetHours,
        _settings.preferredTimeZone,
      );

  List<CategoryRule> getChildrenOf(int? parentId) {
    if (parentId == null) return List.from(_rules);
    CategoryRule? target;
    void find(List<CategoryRule> list) {
      for (final r in list) {
        if (r.id == parentId) {
          target = r;
          return;
        }
        if (r.children != null) find(r.children!);
      }
    }

    find(_rules);
    return List.from(target?.children ?? []);
  }
  int? getParentId(int categoryId) {
    int? parentId;
    void visit(List<CategoryRule> rules, int? parent) {
      for (final r in rules) {
        if (r.id == categoryId) parentId = parent;
        if (r.children != null) visit(r.children!, r.id);
      }
    }

    visit(_rules, null);
    return parentId;
  }

  CategoryRule? getCategoryRuleById(int id) {
    CategoryRule? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == id) found = r;
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    return found;
  }
  Set<int> getRecordIdsInSubtree(int categoryId) {
    final out = <int>{};
    void collect(List<CategoryRule> rules) {
      for (final r in rules) {
        out.add(r.id);
        if (r.children != null) collect(r.children!);
      }
    }

    CategoryRule? target;
    void find(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == categoryId) {
          target = r;
          return;
        }
        if (r.children != null) find(r.children!);
      }
    }

    find(_rules);
    final t = target;
    if (t == null) return {categoryId};
    out.clear();
    out.add(t.id);
    if (t.children != null) collect(t.children!);
    return out;
  }
}
