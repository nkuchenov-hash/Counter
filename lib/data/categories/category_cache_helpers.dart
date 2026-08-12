part of '../database_service.dart';

extension CategoryCacheExtension on DatabaseService {
  Future<List<Map<String, dynamic>>?> _readCachedCategoryMaps() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(
        _scopedDataCacheKey(DatabaseService._cacheCategoriesRawKey),
      );
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return null;
    }
  }

  String? _categoryOwnerFilterClauseForRead() {
    // Category rows may still carry the legacy profile `user_id` on older data,
    // while new rows use the PocketBase auth record id. Reads must accept both,
    // just like records reads do, so a migration cannot make the catalog vanish.
    return _pocketBaseOwnerFilterClauseForRecords();
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return [];
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
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
      final ownerFilter = _categoryOwnerFilterClauseForRead();
      if (ownerFilter == null || ownerFilter.isEmpty) return [];
      final list = await _pb
          .collection(PbCollections.categories)
          .getFullList(filter: '$ownerFilter && is_archived = false');
      final out = list.map((r) {
        final m = Map<String, dynamic>.from(r.data);
        m['id'] = r.id;
        m['_pb_record_id'] = r.id;
        return m;
      }).toList();
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

  /// PocketBase **categories**: every row for `user_id` (active + archived) for slug reservation / collision checks.
  ///
  /// `null` means the network result is unknown (backoff/error). An empty list
  /// means PocketBase successfully confirmed that this owner has zero rows.
  Future<List<Map<String, dynamic>>?> _fetchAllCategoryMapsForUser() async {
    if (!(currentProfileId?.isNotEmpty ?? false)) return null;
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
      if (fetched != null) {
        allRows = fetched;
        try {
          final prefs = _prefs ?? await SharedPreferences.getInstance();
          await prefs.setString(
            _scopedDataCacheKey(DatabaseService._cacheCategoriesRawKey),
            jsonEncode(allRows),
          );
        } catch (_) {}
      } else {
        allRows = await _readCachedCategoryMaps();
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
      // Only a successful empty server result (or a real cached empty catalog)
      // may clear the category tree.
      _rules = [];
      _reservedCategorySlugsLower.clear();
      _categoryDialogUniverse = [];
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
