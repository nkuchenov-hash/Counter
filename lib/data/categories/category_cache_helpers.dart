part of '../database_service.dart';

extension CategoryCacheExtension on DatabaseService {
  Set<String> _categoryCacheOwnerAliases() {
    final aliases = <String>{};

    void add(dynamic value) {
      final s = (value ?? '').toString().trim();
      if (s.isNotEmpty) aliases.add(s);
    }

    add(currentProfileId);
    add(_userIdForWhere);
    try {
      final rec = _pocketBase?.authStore.record;
      add(rec?.id);
      add(rec?.data['user_id']);
    } catch (_) {}
    return aliases;
  }

  Iterable<String> _categoryCacheCandidateKeys() sync* {
    final base = DatabaseService._cacheCategoriesRawKey;
    final seen = <String>{};
    for (final owner in _categoryCacheOwnerAliases()) {
      final key = '${base}_$owner';
      if (seen.add(key)) yield key;
    }
    final scoped = _scopedDataCacheKey(base);
    if (seen.add(scoped)) yield scoped;
    final anon = '${base}_anon';
    if (seen.add(anon)) yield anon;
    if (seen.add(base)) yield base;
  }

  Future<List<Map<String, dynamic>>?> _readCachedCategoryMaps() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      for (final key in _categoryCacheCandidateKeys()) {
        final raw = prefs.getString(key);
        if (raw == null || raw.trim().isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        final rows = [
          for (final e in decoded)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        // Prefer a known non-empty catalog. An empty cache from a transient
        // auth/owner mismatch must never mask another valid owner alias cache.
        if (rows.isNotEmpty) return rows;
      }

      // Return an actual cached empty list only when no compatible owner alias
      // contains a non-empty catalog.
      for (final key in _categoryCacheCandidateKeys()) {
        final raw = prefs.getString(key);
        if (raw == null || raw.trim().isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return [
            for (final e in decoded)
              if (e is Map) Map<String, dynamic>.from(e),
          ];
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCategoryCacheMaps(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final encoded = jsonEncode(rows);
      for (final key in _categoryCacheCandidateKeys()) {
        if (key.endsWith('_anon') ||
            key == DatabaseService._cacheCategoriesRawKey) {
          continue;
        }
        await prefs.setString(key, encoded);
      }
    } catch (_) {}
  }

  String? _categoryOwnerFilterClauseForRead() {
    // Category rows may still carry the legacy profile `user_id` on older data,
    // while new rows use the PocketBase auth record id. Reads must accept both,
    // just like records reads do, so a migration cannot make the catalog vanish.
    return _pocketBaseOwnerFilterClauseForRecords();
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      await ensurePocketBaseReady();
      final ownerFilter = _categoryOwnerFilterClauseForRead();
      if (_pbHttpBackoffActive || ownerFilter == null || ownerFilter.isEmpty) {
        final cached = await _readCachedCategoryMaps();
        if (cached == null) return [];
        return [
          for (final row in cached)
            if (_categoryFlatRowIsActive(
              CategoryServiceExtension._flattenNocoRecord(
                row,
                allowCategoryIdAsRowPk: true,
              ),
            ))
              row,
        ];
      }
      final list = await _pb
          .collection(PbCollections.categories)
          .getFullList(filter: '$ownerFilter && is_archived = false');
      final out = list.map((r) {
        final m = Map<String, dynamic>.from(r.data);
        m['id'] = r.id;
        m['_pb_record_id'] = r.id;
        return m;
      }).toList();
      if (out.isNotEmpty) {
        await _writeCategoryCacheMaps(out);
      } else {
        // PocketBase list rules can return HTTP 200 + [] during a transient
        // auth/owner mismatch. A passive read is not deletion evidence.
        final cached = await _readCachedCategoryMaps();
        if (cached != null && cached.isNotEmpty) {
          return [
            for (final row in cached)
              if (_categoryFlatRowIsActive(
                CategoryServiceExtension._flattenNocoRecord(
                  row,
                  allowCategoryIdAsRowPk: true,
                ),
              ))
                row,
          ];
        }
      }
      if (kDebugMode) {
        debugPrint(
          '[PB] fetchCategories: ${out.length} rows (owner compatibility filter) @ $kPocketBaseUrl',
        );
      }
      return out;
    } on ClientException catch (e) {
      debugPrint('PB_ERROR_RESPONSE: ${e.response}');
      _maybeOpenPbCircuitFromListFailure(e, 'fetchCategories');
      final cached = await _readCachedCategoryMaps();
      if (cached == null) return [];
      return [
        for (final row in cached)
          if (_categoryFlatRowIsActive(
            CategoryServiceExtension._flattenNocoRecord(
              row,
              allowCategoryIdAsRowPk: true,
            ),
          ))
            row,
      ];
    } catch (e) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchCategories');
      final cached = await _readCachedCategoryMaps();
      if (cached == null) return [];
      return [
        for (final row in cached)
          if (_categoryFlatRowIsActive(
            CategoryServiceExtension._flattenNocoRecord(
              row,
              allowCategoryIdAsRowPk: true,
            ),
          ))
            row,
      ];
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() => fetchCategories();

  /// PocketBase **categories**: every row for the compatible owner identity
  /// (active + archived) for slug reservation / collision checks.
  ///
  /// `null` means the network result is unknown (backoff/error). An empty list
  /// means PocketBase answered with zero visible rows, which is still not
  /// sufficient by itself to destroy a known local category catalog.
  Future<List<Map<String, dynamic>>?> _fetchAllCategoryMapsForUser() async {
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        return null;
      }
      final ownerFilter = _categoryOwnerFilterClauseForRead();
      if (ownerFilter == null || ownerFilter.isEmpty) return null;
      final list = await _pb
          .collection(PbCollections.categories)
          .getFullList(filter: ownerFilter);
      return list.map((r) {
        final m = Map<String, dynamic>.from(r.data);
        m['id'] = r.id;
        m['_pb_record_id'] = r.id;
        return m;
      }).toList();
    } on ClientException catch (e) {
      debugPrint('PB_ERROR_RESPONSE: ${e.response}');
      _maybeOpenPbCircuitFromListFailure(e, 'fetchAllCategories');
      return null;
    } catch (e) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchAllCategories');
      return null;
    }
  }

  void _rebuildReservedCategorySlugsFromRows(List<Map<String, dynamic>> rows) {
    final set = <String>{};
    for (final row in rows) {
      final flat = CategoryServiceExtension._flattenNocoRecord(
        row,
        allowCategoryIdAsRowPk: true,
      );
      void add(dynamic v) {
        final s = (v ?? '').toString().trim().toLowerCase();
        if (s.isNotEmpty) set.add(s);
      }

      add(flat['category_id'] ?? flat['Category_id']);
      add(flat['normalized_id'] ?? flat['normalizedId']);
    }
    _reservedCategorySlugsLower = set;
  }

  void _rebuildCategoryDialogUniverse(List<Map<String, dynamic>> allRawRows) {
    final list = <Map<String, dynamic>>[];
    for (final row in allRawRows) {
      final flat = CategoryServiceExtension._flattenNocoRecord(
        row,
        allowCategoryIdAsRowPk: true,
      );
      final name =
          CategoryRecordBridgeExtension._categoryDisplayNameFromRow(flat);
      final archRaw = flat['is_archived'] ?? flat['isArchived'];
      var isArc = _jsonBoolFromDynamic(archRaw);
      final st = (flat['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'archived' || st == 'deleted') isArc = true;
      final pb = (row['id'] ?? row['_pb_record_id'] ?? flat['id'] ?? '')
          .toString()
          .trim();
      list.add({
        'name': name,
        'nameLower': name.trim().toLowerCase(),
        'isArchived': isArc,
        'pbRowId': pb,
      });
    }
    _categoryDialogUniverse = list;
  }

  Future<void> _loadRulesFromNoco() async {
    List<Map<String, dynamic>>? allRows;
    try {
      final fetched = await _fetchAllCategoryMapsForUser();
      if (fetched == null) {
        allRows = await _readCachedCategoryMaps();
      } else if (fetched.isNotEmpty) {
        allRows = fetched;
        await _writeCategoryCacheMaps(fetched);
      } else {
        // CRITICAL INVARIANT: a passive protected-list read returning [] is not
        // proof that the user deleted every category. PocketBase may return a
        // successful empty list while auth/owner visibility is temporarily
        // unresolved. Never overwrite a known-good catalog with that response.
        final cached = await _readCachedCategoryMaps();
        if (cached != null && cached.isNotEmpty) {
          allRows = cached;
          _scheduleAppOpenSyncRetry();
        } else if (_rules.isNotEmpty) {
          _categoryController.add(List.from(_rules));
          _scheduleAppOpenSyncRetry();
          return;
        } else {
          allRows = fetched;
        }
      }
    } catch (e) {
      DatabaseService._log('CATEGORY_FETCH: $e');
      allRows = await _readCachedCategoryMaps();
    }

    if (allRows == null) {
      // Unknown network state is not evidence that categories were deleted.
      // Preserve the last in-memory catalog and keep pickers usable.
      _categoryController.add(List.from(_rules));
      return;
    }
    if (allRows.isEmpty) {
      // A genuinely new account may have no categories. Existing known
      // categories are never cleared by passive bootstrap/sync; explicit CRUD
      // is responsible for updating the in-memory catalog after real deletion.
      if (_rules.isNotEmpty) {
        _categoryController.add(List.from(_rules));
        _scheduleAppOpenSyncRetry();
        return;
      }
      _categoryController.add(List.from(_rules));
      return;
    }
    try {
      _rebuildReservedCategorySlugsFromRows(allRows);
      _rebuildCategoryDialogUniverse(allRows);
      final flat = allRows
          .map(
            (e) => CategoryServiceExtension._flattenNocoRecord(
              e,
              allowCategoryIdAsRowPk: true,
            ),
          )
          .where(_categoryFlatRowIsActive)
          .toList();
      if (flat.isEmpty && _rules.isNotEmpty) {
        // Same invariant after flattening/archive interpretation: malformed or
        // temporarily invisible rows may not erase the last valid tree.
        _categoryController.add(List.from(_rules));
        _scheduleAppOpenSyncRetry();
        return;
      }
      final built = flat.isEmpty
          ? (<CategoryRule>[], <List<CategoryRule>>[])
          : _buildCategoryTreeFromFlat(flat);
      _rules = built.$1;
      _categoryController.add(List.from(_rules));
      for (final g in built.$2) {
        unawaited(
          _persistCategoryOrdersBulkForce(g, contextLabel: 'nullOrderInit'),
        );
      }
      DatabaseService._log('Successfully loaded ${_rules.length} categories');
    } catch (e, s) {
      DatabaseService._log('CATEGORY_CRASH: $e');
      DatabaseService._log(s);
      // Parsing failure is not evidence of a legitimately empty catalog.
      // Keep the last valid in-memory tree instead of blanking the UI.
      _categoryController.add(List.from(_rules));
    }
  }

  /// Reload categories (active + archived metadata) from PocketBase into [_rules] and dialog universe.
}
