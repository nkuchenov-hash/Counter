part of '../database_service.dart';

extension CategoryCrudExtension on DatabaseService {
  Future<int?> restoreArchivedCategory(String pbRowId) async {
    final rid = pbRowId.trim();
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return null;
    }
    if (rid.isEmpty || !DatabaseService._isLikelyPocketBaseRowId(rid)) {
      return null;
    }
    try {
      await ensurePocketBaseReady();
      final rec = await _pb.collection(PbCollections.categories).getOne(rid);
      final m = Map<String, dynamic>.from(rec.data);
      final biz = DatabaseService._sanitizePkString(
        m['category_id']?.toString(),
      );
      final ordRaw = m['order'];
      final ord = ordRaw is int
          ? ordRaw
          : int.tryParse(ordRaw?.toString() ?? '') ?? 0;
      final patchBody = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'is_archived': false,
          'order': ord,
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
        }),
      );
      await _pb
          .collection(PbCollections.categories)
          .update(rid, body: patchBody);
      await _loadRulesFromNoco();
      return getCategoryRuleByBackendRowId(rid)?.id;
    } on ClientException catch (e) {
      DatabaseService._log('RESTORE_CATEGORY: $e');
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      return null;
    } catch (e) {
      DatabaseService._log('RESTORE_CATEGORY: $e');
      return null;
    }
  }

  /// NocoDB v3 returns { id, fields: { ... } }; flatten so callers see one map.
  ///
  /// **Critical:** For the **records** (and plans) tables, never use [category_id] as the row PK.
  /// If the API omits top-level [id], falling back to category_id produces ghosts like
  /// `PATCH .../records/361` where 361 is a category — server returns 404, timers never stop.
  ///
  /// Stamps [DatabaseService._nocoEnvelopePkKey] from the **wrapper** only (never from fields alone) so REST
  /// always uses the real list-item PK when Noco sends it.
  ///
  /// For **categories** only, pass [allowCategoryIdAsRowPk] = true so string PKs like `astra`
  /// still resolve when they live under `category_id`.
  /// PocketBase **categories** row id — from [CategoryRule.backendRowId] only.
  String? _categoryBackendRowIdStrict(CategoryRule? rule) {
    if (rule == null) return null;
    if (rule.id == -1) return null;
    final s = (rule.backendRowId ?? '').trim();
    if (s.isNotEmpty && s != 'uncategorized') return s;
    return null;
  }

  /// Noco `category_id` string for **`fields`** and parent FK only (@DATA_MAP §2).
  String? _categoryStringPkForApi(CategoryRule? rule) {
    if (rule == null) return null;
    final s = DatabaseService._sanitizePkString(rule.normalizedId);
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  /// Records/plans **`category_id`** (@DATA_MAP): always the category row’s string PK, never a local int.
  String _recordCategoryBusinessPkForApi(int? localCategoryId) {
    final rule = categoryRuleForRecordCategoryId(localCategoryId);
    final s = _categoryStringPkForApi(rule);
    if (s != null && s.isNotEmpty) return s;
    final slug = _slugifyCategoryDisplayName(rule.name);
    if (slug.isNotEmpty) return slug;
    return 'uncategorized';
  }

  /// PocketBase **`categories.parent_id`** (self relation): must be the parent row’s **system `id`**
  /// (15-char), not the business slug in [CategoryRule.normalizedId].
  String? _parentCategoryIdStringForApi(int? parentLocalId) {
    if (parentLocalId == null) return null;
    return _categoryBackendRowIdStrict(getCategoryRuleById(parentLocalId));
  }

  /// Strip system-managed / read-only keys from payloads for any table (@DATA_MAP).
  static const Set<String> _nocoPatchStripFieldKeysLower = {
    'createdat',
    'updatedat',
    'created_at',
    'updated_at',
  };

  Map<String, dynamic> _nocoFieldsForPatch(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    for (final e in raw.entries) {
      if (_nocoPatchStripFieldKeysLower.contains(e.key.toLowerCase())) {
        continue;
      }
      out[e.key] = e.value;
    }
    return out;
  }

  /// @DATA_MAP `categories`: **keywords** and **localized_names** are stored as JSON **String** (LongText).
  /// Encode Maps for PATCH/POST so the HTTP body has string values Noco accepts.
  Map<String, dynamic> _categoryPatchFieldsWithJsonLongText(
    Map<String, dynamic> fields,
  ) {
    const jsonColumnKeys = <String>{'keywords', 'localized_names'};
    final out = Map<String, dynamic>.from(fields);
    for (final k in jsonColumnKeys) {
      if (!out.containsKey(k)) continue;
      final v = out[k];
      if (v == null) {
        out.remove(k);
        continue;
      }
      if (v is String) {
        continue;
      }
      try {
        // @DATA_MAP `categories`: LongText JSON — empty Map → "{}" so clears server column.
        out[k] = jsonEncode(v);
      } catch (e) {
        DatabaseService._log('CATEGORY_JSON_ENCODE_FAIL key=$k error=$e');
        out.remove(k);
      }
    }
    return out;
  }

  /// @DATA_MAP `records` and `plans`: **checklist** is stored as **JSON String** (LongText/CSV) — [jsonEncode] for API.
  Map<String, dynamic> _recordsPatchFieldsJsonStrings(
    Map<String, dynamic> fields,
  ) {
    final out = Map<String, dynamic>.from(fields);
    if (!out.containsKey('checklist')) return out;
    final v = out['checklist'];
    if (v == null) {
      out.remove('checklist');
      return out;
    }
    if (v is String) return out;
    try {
      out['checklist'] = jsonEncode(v);
    } catch (e) {
      DatabaseService._log('RECORD_CHECKLIST_JSON_ENCODE_FAIL error=$e');
      out.remove('checklist');
    }
    return out;
  }

  String _slugifyCategoryDisplayName(String displayName) {
    final t = displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return t.isEmpty ? 'untitled' : t;
  }

  String _categoryNormalizedIdForPersist(CategoryRule r) {
    final s = DatabaseService._sanitizePkString(r.normalizedId);
    if (s != null && s.isNotEmpty) return s;
    return _slugifyCategoryDisplayName(r.name);
  }

  /// Unique string PK for new category rows ([fields.category_id]).
  String _newCategoryIdString() => DatabaseService._newClientRecordUuid();

  String _randomCategoryKeySuffix() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final r = Random.secure();
    return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _randomCategoryRecoverySuffix3() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final r = Random.secure();
    return List.generate(3, (_) => chars[r.nextInt(chars.length)]).join();
  }

  bool _rulesTreeClaimsCategorySlug(String slug) {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return false;
    bool visit(List<CategoryRule> rules) {
      for (final r in rules) {
        final nid = (r.normalizedId ?? '').trim().toLowerCase();
        if (nid.isNotEmpty && nid == s) return true;
        if (r.children != null && visit(r.children!)) return true;
      }
      return false;
    }

    return visit(_rules);
  }

  /// Reserved slugs include **archived** rows ([_reservedCategorySlugsLower]) + in-memory tree (placeholders).
  bool _categoryBusinessSlugReservedOrInRules(String slug) {
    final s = slug.trim().toLowerCase();
    if (s.isEmpty) return true;
    if (_reservedCategorySlugsLower.contains(s)) return true;
    if (_rulesTreeClaimsCategorySlug(s)) return true;
    return false;
  }

  String _slugWithRandomSuffixUntaken(String base) {
    final trimmed = base.trim();
    final b = trimmed.isEmpty ? 'cat' : trimmed;
    for (var i = 0; i < 24; i++) {
      final candidate = '${b}_${_randomCategoryKeySuffix()}';
      if (!_categoryBusinessSlugReservedOrInRules(candidate)) {
        return candidate;
      }
    }
    final ts = DateTime.now().millisecondsSinceEpoch % 100000;
    final tsSlug = '${b}_$ts';
    if (!_categoryBusinessSlugReservedOrInRules(tsSlug)) return tsSlug;
    return _newCategoryIdString();
  }

  /// PocketBase [category_id] / [normalized_id]: always `base_xxxx` ([_randomCategoryKeySuffix])
  /// so POST avoids unique collisions; [base] from [normalizedId] or slugified [name].
  String _pickNewCategoryBusinessKey(CategoryRule child) {
    final explicit = DatabaseService._sanitizePkString(child.normalizedId);
    final baseRaw = (explicit != null && explicit.isNotEmpty)
        ? explicit
        : _slugifyCategoryDisplayName(child.name);
    final base = baseRaw.isEmpty ? 'cat' : baseRaw;
    return _slugWithRandomSuffixUntaken(base);
  }

  bool _pbErrorLooksLikeUniqueCategoryCollision(ClientException e) {
    final code = e.statusCode;
    if (code != 400 && code != 409) return false;
    final blob = '${e.response} $e'.toLowerCase();
    return blob.contains('unique') ||
        blob.contains('already exists') ||
        blob.contains('duplicate') ||
        blob.contains('validation_not_unique') ||
        blob.contains('failed unique') ||
        blob.contains('autoincrement');
  }

  void _patchPlaceholderCategoryBizId(
    int? parentId,
    String displayName,
    String newCategoryId,
  ) {
    final wantTag = displayName.trim();
    void patchIn(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        if (r.id == -1 && r.name.trim() == wantTag) {
          rules[i] = r.copyWith(normalizedId: newCategoryId);
          return;
        }
        if (r.children != null) patchIn(r.children!);
      }
    }

    if (parentId == null) {
      patchIn(_rules);
    } else {
      void findParent(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == parentId) {
            if (r.children != null) patchIn(r.children!);
            return;
          }
          if (r.children != null) findParent(r.children!);
        }
      }

      findParent(_rules);
    }
  }

  void _removeFailedPlaceholderCategory(int? parentId, String tag) {
    final wantTag = tag.trim();
    bool removeFrom(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        final r = rules[i];
        if (r.id == -1 && r.name.trim() == wantTag) {
          rules.removeAt(i);
          return true;
        }
        if (r.children != null && removeFrom(r.children!)) {
          if (r.children!.isEmpty) r.children = null;
          return true;
        }
      }
      return false;
    }

    if (parentId == null) {
      removeFrom(_rules);
    } else {
      void findParent(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == parentId) {
            if (r.children != null) {
              removeFrom(r.children!);
            }
            return;
          }
          if (r.children != null) findParent(r.children!);
        }
      }

      findParent(_rules);
    }
    _categoryController.add(List.from(_rules));
  }

  /// Resolves Noco [categoryId] to a [CategoryRule], or a synthetic "Uncategorized" rule.
  CategoryRule categoryRuleForRecordCategoryId(int? categoryId) {
    if (categoryId != null) {
      final r = getCategoryRuleById(categoryId);
      if (r != null) return r;
    }
    return CategoryRule.uncategorized();
  }

  String categoryDisplayPathForTimeline(int? categoryId) {
    final r = categoryRuleForRecordCategoryId(categoryId);
    if (r.id == CategoryRule.uncategorizedSyntheticId) return r.name;
    return getCategoryPath(categoryId!);
  }

  Color categoryDisplayColorForTimeline(int? categoryId) {
    return categoryRuleForRecordCategoryId(categoryId).colorOrDefault;
  }

  /// Timeline card color: active [CategoryRule] if present, else expanded category (archived OK).
  Color categoryDisplayColorForRecordData(Map<String, dynamic> data) {
    final rid = resolvedCategoryIdForRecord(data);
    final rule = categoryRuleForRecordCategoryId(rid);
    if (rule.id != CategoryRule.uncategorizedSyntheticId) {
      return rule.colorOrDefault;
    }
    final exp = data['_expanded_category'];
    if (exp is Map) {
      final cv = exp['color_value'] ?? exp['colorValue'];
      if (cv != null) {
        final n = cv is int ? cv : int.tryParse(cv.toString());
        if (n != null && n != 0) return Color(n);
      }
    }
    return Colors.grey;
  }

  /// Timeline category path: active tree, else single name from expand (archived OK).
  String categoryDisplayPathForRecordData(Map<String, dynamic> data) {
    final rid = resolvedCategoryIdForRecord(data);
    final rule = categoryRuleForRecordCategoryId(rid);
    if (rule.id != CategoryRule.uncategorizedSyntheticId) {
      return categoryDisplayPathForTimeline(rule.id);
    }
    final exp = data['_expanded_category'];
    if (exp is Map) {
      final n = exp['name']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
      final biz = exp['category_id']?.toString().trim();
      if (biz != null && biz.isNotEmpty) return biz;
    }
    return 'Life';
  }

  /// Glyph for timeline / chip UI: active rule, else expanded category metadata.
  IconData categoryDisplayIconForRecordData(Map<String, dynamic> data) {
    final rid = resolvedCategoryIdForRecord(data);
    final rule = categoryRuleForRecordCategoryId(rid);
    if (rule.id != CategoryRule.uncategorizedSyntheticId) {
      return rule.iconOrDefault;
    }
    final exp = data['_expanded_category'];
    if (exp is Map) {
      final icp = exp['icon_code_point'] ?? exp['iconCodePoint'];
      if (icp != null) {
        final n = icp is int ? icp : int.tryParse(icp.toString());
        if (n != null && n != 0) {
          return IconData(n, fontFamily: 'MaterialIcons');
        }
      }
    }
    return Icons.folder_rounded;
  }

  Color getCategoryColor(int categoryId) {
    return getCategoryRuleById(categoryId)?.colorOrDefault ?? Colors.grey;
  }

  int? getCategoryIdByParentAndTag(int? parentId, String tag) {
    final children = getChildrenOf(parentId);
    final t = tag.trim().toLowerCase();
    for (final c in children) {
      if (c.isArchived) continue;
      if (c.name.trim().toLowerCase() == t) return c.id;
    }
    return null;
  }

  bool siblingHasTag(int? parentId, String tag, {int? excludeId}) {
    final children = getChildrenOf(parentId);
    final t = tag.trim().toLowerCase();
    for (final c in children) {
      if (c.isArchived) continue;
      if (excludeId != null && c.id == excludeId) continue;
      if (c.name.trim().toLowerCase() == t) return true;
    }
    return false;
  }

  Future<({bool ok, String? errorDetail})> updateCategory(
    int targetId,
    String newName,
  ) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return (ok: false, errorDetail: 'not_initialized');
    }
    if (siblingHasTag(getParentId(targetId), newName, excludeId: targetId)) {
      return (ok: false, errorDetail: null);
    }
    final existing = getCategoryRuleById(targetId);
    if (existing == null) {
      return (ok: false, errorDetail: 'category_not_found');
    }

    final pbId = _categoryBackendRowIdStrict(existing);
    if (pbId == null) {
      return (ok: false, errorDetail: 'missing_backend_row_id');
    }
    final biz = _categoryStringPkForApi(existing);
    try {
      await ensurePocketBaseReady();
      final body = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'name': newName,
          'normalized_id': _slugifyCategoryDisplayName(newName),
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
          'order': existing.order,
        }),
      );
      await _pb.collection(PbCollections.categories).update(pbId, body: body);
      await _loadRulesFromNoco();
      return (ok: true, errorDetail: null);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      return (ok: false, errorDetail: e.toString());
    } catch (e) {
      DatabaseService._log('UPDATE_CATEGORY: $e');
      return (ok: false, errorDetail: e.toString());
    }
  }

  Future<({bool ok, String? errorDetail})> patchCategoryDelta(
    int targetId,
    Map<String, dynamic> fields,
  ) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return (ok: false, errorDetail: 'not_initialized');
    }
    if (fields.isEmpty) {
      return (ok: true, errorDetail: null);
    }
    final existing = getCategoryRuleById(targetId);
    if (existing == null) {
      return (ok: false, errorDetail: 'category_not_found');
    }
    final pbId = _categoryBackendRowIdStrict(existing);
    if (pbId == null) {
      return (ok: false, errorDetail: 'missing_backend_row_id');
    }
    final biz = _categoryStringPkForApi(existing);
    final mergedFields = Map<String, dynamic>.from(fields);
    if (!mergedFields.containsKey('order')) {
      mergedFields['order'] = existing.order;
    }
    try {
      final prepared = _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
        'user_id': _pidForPbFilter,
        if (biz != null && biz.isNotEmpty) 'category_id': biz,
        ...mergedFields,
      });
      final merged = _nocoFieldsForPatch(prepared);
      await ensurePocketBaseReady();
      await _pb.collection(PbCollections.categories).update(pbId, body: merged);
      await _loadRulesFromNoco();
      return (ok: true, errorDetail: null);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      return (ok: false, errorDetail: e.toString());
    } catch (e) {
      DatabaseService._log('PATCH_CATEGORY_DELTA: $e');
      return (ok: false, errorDetail: e.toString());
    }
  }

  /// After [updateNestedCategory] (or similar) mutates memory, push this row with one PATCH.
  Future<({bool ok, String? errorDetail})> saveCategoryRowToServer(
    int targetId,
  ) async {
    final r = getCategoryRuleById(targetId);
    if (r == null) return (ok: false, errorDetail: 'category_not_found');
    if (siblingHasTag(getParentId(targetId), r.name, excludeId: targetId)) {
      return (ok: false, errorDetail: 'duplicate_name');
    }
    return patchCategoryDelta(targetId, <String, dynamic>{
      'name': r.name,
      'normalized_id': _categoryNormalizedIdForPersist(r),
      'color_value': r.colorValue ?? 0,
      'icon_code_point': r.iconCodePoint ?? 0,
      'order': r.order,
      if (r.keywords != null) 'keywords': r.keywords,
      if (r.localizedNames != null) 'localized_names': r.localizedNames,
    });
  }

  /// UI-first: move category in _rules, push; then PocketBase PATCH `parent_id`.
  Future<bool> updateCategoryParent(int categoryId, int? newParentId) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }

    final oldParentId = getParentId(categoryId);
    if (!_moveCategoryInRules(categoryId, newParentId)) return false;

    void renumberLocal(int? parentKey) {
      applyLocalCategorySiblingOrder(
        parentKey,
        List<CategoryRule>.from(getChildrenOf(parentKey)),
      );
    }

    renumberLocal(oldParentId);
    renumberLocal(newParentId);
    _categoryController.add(List.from(_rules));

    try {
      final existing = getCategoryRuleById(categoryId);
      final pbId = _categoryBackendRowIdStrict(existing);
      if (pbId == null) {
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
        return false;
      }
      final newParentKey = newParentId == null
          ? null
          : _parentCategoryIdStringForApi(newParentId);
      if (newParentId != null &&
          (newParentKey == null || newParentKey.isEmpty)) {
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
        return false;
      }
      final rowBiz = _categoryStringPkForApi(existing);
      final movedOrder = existing?.order ?? 0;
      await ensurePocketBaseReady();
      final body = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          if (rowBiz != null && rowBiz.isNotEmpty) 'category_id': rowBiz,
          'parent_id': newParentKey,
          'order': movedOrder,
        }),
      );
      await _pb.collection(PbCollections.categories).update(pbId, body: body);
      await _persistCategoryOrdersBulkForce(
        List<CategoryRule>.from(getChildrenOf(oldParentId)),
        contextLabel: 'parentMoveOldSiblings',
      );
      await _persistCategoryOrdersBulkForce(
        List<CategoryRule>.from(getChildrenOf(newParentId)),
        contextLabel: 'parentMoveNewSiblings',
      );
      await _loadRulesFromNoco();
      return true;
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      await _loadRulesFromNoco();
      _categoryController.add(List.from(_rules));
      return false;
    } catch (e) {
      DatabaseService._log('UPDATE_CATEGORY_PARENT: $e');
      try {
        await _loadRulesFromNoco();
        _categoryController.add(List.from(_rules));
      } catch (_) {}
      return false;
    }
  }

  /// Returns true if moved. Removes node from current parent and adds to new parent (or root).
  bool _moveCategoryInRules(int categoryId, int? newParentId) {
    CategoryRule? node;
    CategoryRule? oldParent;
    void find(List<CategoryRule> rules, CategoryRule? parent) {
      for (final r in rules) {
        if (r.id == categoryId) {
          node = r;
          oldParent = parent;
          return;
        }
        if (r.children != null) find(r.children!, r);
      }
    }

    find(_rules, null);
    if (node == null) return false;
    final nodeVal = node!;
    final op = oldParent;
    if (op != null && op.children != null) {
      final ch = op.children!;
      ch.removeWhere((c) => c.id == categoryId);
      if (ch.isEmpty) op.children = null;
    } else if (op == null) {
      _rules.removeWhere((r) => r.id == categoryId);
    }
    if (newParentId == null) {
      _rules.add(nodeVal);
    } else {
      void addTo(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == newParentId) {
            (r.children ??= []).add(nodeVal);
            return;
          }
          if (r.children != null) addTo(r.children!);
        }
      }

      addTo(_rules);
    }
    return true;
  }

  Future<bool> deleteCategory(int id) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }

    final rule = getCategoryRuleById(id);
    if (rule == null || rule.id == -1) {
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    if (_categoryBackendRowIdStrict(rule) == null) {
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    final delId = await _resolveCategoryRowIdForPb(rule);
    if (delId.isEmpty || !DatabaseService._isLikelyPocketBaseRowId(delId)) {
      _emitCategorySyncNotice('category_sync_not_found');
      return false;
    }

    try {
      await ensurePocketBaseReady();
      final biz = _categoryStringPkForApi(rule);
      final patchBody = _nocoFieldsForPatch(
        _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'is_archived': true,
          'order': rule.order,
          if (biz != null && biz.isNotEmpty) 'category_id': biz,
        }),
      );
      await _pb
          .collection(PbCollections.categories)
          .update(delId, body: patchBody);
      _removeCategoryFromRules(id);
      _categoryController.add(List.from(_rules));
      return true;
    } on ClientException catch (e) {
      final deleteFallbackUrl = () {
        try {
          final b = (_pocketBase?.baseURL ?? '').trim();
          if (b.isEmpty) return '(unknown URL)';
          final bt = b.replaceAll(RegExp(r'/$'), '');
          return '$bt/api/collections/${PbCollections.categories}/records/$delId';
        } catch (_) {
          return '(unknown URL)';
        }
      }();
      _debugPrintPocketBaseClientException(
        operation: 'categories soft-delete PATCH',
        e: e,
        payload: <String, dynamic>{'is_archived': true},
        fallbackUrl: deleteFallbackUrl,
      );
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      DatabaseService._log('SOFT_DELETE_CATEGORY: $e');
      return false;
    } catch (e) {
      DatabaseService._log('SOFT_DELETE_CATEGORY: $e');
      return false;
    }
  }

  /// Optimistic delete only — removes the subtree with this local id from [_rules].
  void _removeCategoryFromRules(int id) {
    bool removeFrom(List<CategoryRule> rules) {
      for (var i = 0; i < rules.length; i++) {
        if (rules[i].id == id) {
          rules.removeAt(i);
          return true;
        }
        if (rules[i].children != null && removeFrom(rules[i].children!)) {
          if (rules[i].children?.isEmpty ?? false) rules[i].children = null;
          return true;
        }
      }
      return false;
    }

    removeFrom(_rules);
  }

  /// Same id derivation as [_buildCategoryTreeFromFlat] so the local node matches the next reload.
  int _categoryDisplayIdFromServerPk(
    String rawPk, {
    required String tagFallback,
  }) {
    final trimmed = rawPk.trim();
    if (trimmed.isEmpty) {
      return CategoryTreeExtension._hashStringToPositiveIntForCategoryTreeLocalIdOnly(
        tagFallback.trim(),
        1,
      );
    }
    final asInt = CategoryTreeExtension._rowInt(trimmed);
    if (asInt != 0) return asInt;
    final h = CategoryTreeExtension._hashStringToPositiveIntForCategoryTreeLocalIdOnly(
      trimmed,
      0,
    );
    if (h != 0) return h;
    return CategoryTreeExtension._hashStringToPositiveIntForCategoryTreeLocalIdOnly(
      tagFallback.trim(),
      1,
    );
  }

  void _applyCategoryCreateResponseToPlaceholderPb({
    required int? parentId,
    required String displayName,
    required RecordModel created,
  }) {
    try {
      final rowId = created.id.trim();
      if (rowId.isEmpty) return;
      final wantTag = displayName.trim();
      final biz = created.data['category_id']?.toString();
      final newId = _categoryDisplayIdFromServerPk(rowId, tagFallback: wantTag);
      CategoryRule upgraded(CategoryRule old) {
        return CategoryRule(
          id: newId,
          name: old.name,
          backendRowId: rowId,
          normalizedId: (biz != null && biz.isNotEmpty)
              ? biz
              : old.normalizedId,
          children: old.children,
          colorValue: old.colorValue,
          iconCodePoint: old.iconCodePoint,
          keywords: old.keywords,
          localizedNames: old.localizedNames,
          order: old.order,
          isArchived: false,
        );
      }

      if (parentId == null) {
        for (var i = 0; i < _rules.length; i++) {
          final r = _rules[i];
          if (r.id == -1 && r.name.trim() == wantTag) {
            _rules[i] = upgraded(r);
            return;
          }
        }
        return;
      }

      bool walk(List<CategoryRule> rules) {
        for (var i = 0; i < rules.length; i++) {
          if (rules[i].id == parentId) {
            final ch = rules[i].children;
            if (ch == null) return false;
            for (var j = 0; j < ch.length; j++) {
              final c = ch[j];
              if (c.id == -1 && c.name.trim() == wantTag) {
                ch[j] = upgraded(c);
                return true;
              }
            }
            return false;
          }
          if (rules[i].children != null && walk(rules[i].children!)) {
            return true;
          }
        }
        return false;
      }

      walk(_rules);
    } catch (_) {}
  }

  /// UI-first: add child to _rules (temp id -1), push; then PocketBase create.
  Future<bool> addNestedCategory(int? parentId, CategoryRule child) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return false;
    }

    final ownerPbId = _userIdForWhere;
    if (ownerPbId == null || ownerPbId.isEmpty) {
      DatabaseService._log(
        'ADD_CATEGORY: missing auth record id for user_id relation',
      );
      return false;
    }

    if (siblingHasTag(parentId, child.name)) {
      return false;
    }

    final parentKey = _parentCategoryIdStringForApi(parentId);
    if (parentId != null && (parentKey == null || parentKey.isEmpty)) {
      DatabaseService._log(
        'ADD_CATEGORY: parent missing PocketBase row id (backendRowId) localParent=$parentId',
      );
      return false;
    }

    var categoryId = _pickNewCategoryBusinessKey(child);

    final nextOrder = _nextCategoryOrderAmongSiblings(parentId);

    final placeholder = CategoryRule(
      id: -1,
      name: child.name,
      normalizedId: categoryId,
      children: null,
      colorValue: child.colorValue,
      iconCodePoint: child.iconCodePoint,
      keywords: child.keywords,
      localizedNames: child.localizedNames,
      order: nextOrder,
      isArchived: false,
    );
    if (parentId == null) {
      _rules.add(placeholder);
    } else {
      void addTo(List<CategoryRule> rules) {
        for (final r in rules) {
          if (r.id == parentId) {
            (r.children ??= []).add(placeholder);
            return;
          }
          if (r.children != null) addTo(r.children!);
        }
      }

      addTo(_rules);
    }
    _categoryController.add(List.from(_rules));

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final fieldsRaw = <String, dynamic>{
          'user_id': ownerPbId,
          'category_id': categoryId,
          'name': child.name,
          if (parentKey != null && parentKey.isNotEmpty) 'parent_id': parentKey,
          'color_value': child.colorValue ?? 0,
          'icon_code_point': child.iconCodePoint ?? 0,
          'order': nextOrder,
          if (child.keywords != null) 'keywords': child.keywords,
          if (child.localizedNames != null)
            'localized_names': child.localizedNames,
          'normalized_id': categoryId,
          'is_archived': false,
        };
        final fields = _nocoFieldsForPatch(
          _categoryPatchFieldsWithJsonLongText(fieldsRaw),
        );
        final postedPk = (fields['category_id'] ?? '').toString().trim();
        if (postedPk.isEmpty) {
          DatabaseService._log(
            'ADD_CATEGORY: POST blocked — category_id missing in fields map',
          );
          _removeFailedPlaceholderCategory(parentId, child.name);
          return false;
        }
        await ensurePocketBaseReady();
        final created = await _pb
            .collection(PbCollections.categories)
            .create(body: fields);
        _applyCategoryCreateResponseToPlaceholderPb(
          parentId: parentId,
          displayName: child.name,
          created: created,
        );
        _categoryController.add(List.from(_rules));
        unawaited(_loadRulesFromNoco());
        return true;
      } on ClientException catch (e) {
        debugPrint('[SERVER_ERROR_BODY] ${e.response}');
        if (attempt == 0 && _pbErrorLooksLikeUniqueCategoryCollision(e)) {
          final baseForRetry = categoryId.trim().isEmpty
              ? 'cat'
              : categoryId.trim();
          var newSlug = '${baseForRetry}_${_randomCategoryRecoverySuffix3()}';
          for (var k = 0; k < 12; k++) {
            if (!_categoryBusinessSlugReservedOrInRules(newSlug)) break;
            newSlug = '${baseForRetry}_${_randomCategoryRecoverySuffix3()}';
          }
          debugPrint(
            '[CATEGORY_RECOVERY] Retrying creation with unique slug: $newSlug',
          );
          categoryId = newSlug;
          _patchPlaceholderCategoryBizId(parentId, child.name, categoryId);
          _categoryController.add(List.from(_rules));
          continue;
        }
        DatabaseService._log('ADD_CATEGORY: $e');
        break;
      } catch (e) {
        DatabaseService._log('ADD_CATEGORY: $e');
        break;
      }
    }
    _removeFailedPlaceholderCategory(parentId, child.name);
    return false;
  }

  Future<bool> removeNestedCategory(int? parentId, int childId) async {
    return deleteCategory(childId);
  }

  bool updateNestedCategory(
    int id, {
    String? name,
    int? colorValue,
    int? iconCodePoint,
  }) {
    CategoryRule? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        if (r.id == id) {
          found = r;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    final f = found;
    if (f == null) return false;
    if (name != null) {
      if (siblingHasTag(getParentId(id), name, excludeId: id)) return false;
      f.name = name;
    }
    if (colorValue != null) f.colorValue = colorValue;
    if (iconCodePoint != null) f.iconCodePoint = iconCodePoint;
    return true;
  }
}
