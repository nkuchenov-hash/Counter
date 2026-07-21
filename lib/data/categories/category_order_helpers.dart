part of '../database_service.dart';

/// Category sibling optimistic reorder, baseline tracking, debounced PocketBase order sync.

extension CategoryOrderSyncExtension on DatabaseService {
  void _cancelCategoryOrderDebounceTimer() {
    _categoryOrderDebounceTimer?.cancel();
    _categoryOrderDebounceTimer = null;
  }

  void _ensureCategoryOrderBaseline(List<CategoryRule> listBeforeFirstDrag) {
    if (_categoryReorderBaselineByLocalId != null) return;
    final m = <int, int>{};
    for (var i = 0; i < listBeforeFirstDrag.length; i++) {
      m[listBeforeFirstDrag[i].id] = i;
    }
    _categoryReorderBaselineByLocalId = m;
  }

  /// Optimistic sibling order: sets [order] to 0..n-1 and replaces the sibling list in memory.
  void applyLocalCategorySiblingOrder(
    int? parentId,
    List<CategoryRule> ordered,
  ) {
    final next = List<CategoryRule>.from(ordered);
    for (var i = 0; i < next.length; i++) {
      next[i].order = i;
    }
    if (parentId == null) {
      _rules = next;
    } else {
      final parent = getCategoryRuleById(parentId);
      if (parent == null) return;
      parent.children = next;
    }
    _categoryController.add(List.from(_rules));
  }

  int _nextCategoryOrderAmongSiblings(int? parentId) {
    final sibs = getChildrenOf(parentId);
    var m = -1;
    for (final r in sibs) {
      if (r.id == -1) continue;
      if (r.order > m) m = r.order;
    }
    return m + 1;
  }

  /// Bulk PATCH `order` for **every** row (no baseline skip). Used for null-order init and post–parent-move sibling sync.
  Future<void> _persistCategoryOrdersBulkForce(
    List<CategoryRule> ordered, {
    String contextLabel = 'categoryOrderForce',
  }) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;

    var n = 0;
    try {
      await ensurePocketBaseReady();
      for (final r in ordered) {
        if (r.id == -1) continue;
        final pbId = _categoryBackendRowIdStrict(r);
        if (pbId == null) continue;
        final biz = _categoryStringPkForApi(r);
        final body = _nocoFieldsForPatch(
          _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
            'user_id': _pidForPbFilter,
            if (biz != null && biz.isNotEmpty) 'category_id': biz,
            'order': r.order,
          }),
        );
        await _pb.collection(PbCollections.categories).update(pbId, body: body);
        n++;
      }
    } catch (e, st) {
      DatabaseService._log('$contextLabel: PB order sync exception $e');
      DatabaseService._log(st.toString());
    }
    DatabaseService._log('$contextLabel: PocketBase order ok ($n row(s))');
  }

  Future<void> _persistCategoryOrdersBulkNow(List<CategoryRule> ordered) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;

    var n = 0;
    try {
      await ensurePocketBaseReady();
      for (var i = 0; i < ordered.length; i++) {
        final r = ordered[i];
        if (r.id == -1) continue;
        final pbId = _categoryBackendRowIdStrict(r);
        if (pbId == null) continue;
        final base = _categoryReorderBaselineByLocalId?[r.id];
        if (base != null && base == i) continue;

        final biz = _categoryStringPkForApi(r);
        final body = _nocoFieldsForPatch(
          _categoryPatchFieldsWithJsonLongText(<String, dynamic>{
            'user_id': _pidForPbFilter,
            if (biz != null && biz.isNotEmpty) 'category_id': biz,
            'order': i,
          }),
        );
        await _pb.collection(PbCollections.categories).update(pbId, body: body);
        n++;
      }
    } catch (e, st) {
      DatabaseService._log('CATEGORY_ORDER_SYNC: chunk exception $e');
      DatabaseService._log(st.toString());
      try {
        final msg = t(currentLocale.value, 'sync_failed');
        if (!_notify.isClosed) _notify.add(msg);
      } catch (_) {}
      return;
    }

    if (n == 0) {
      DatabaseService._log(
        'CATEGORY_ORDER_SYNC: skip — every index matches baseline (${ordered.length} row(s))',
      );
    } else {
      DatabaseService._log('CATEGORY_ORDER_SYNC: PocketBase ok ($n row(s))');
    }
    _categoryReorderBaselineByLocalId = null;
  }

  /// Debounced bulk PATCH: [order] + [user_id] (@DATA_MAP.md `categories`).
  ///
  /// Pass [baselineBeforeReorder] as the sibling list **before** the drag; only the first non-null
  /// list seeds [_categoryReorderBaselineByLocalId] until a successful sync clears it.
  Future<void> persistCategorySiblingOrder(
    int? parentId,
    List<CategoryRule> ordered, {
    List<CategoryRule>? baselineBeforeReorder,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (parentId != null && getCategoryRuleById(parentId) == null) {
      return;
    }
    if (baselineBeforeReorder != null) {
      _ensureCategoryOrderBaseline(baselineBeforeReorder);
    }
    _pendingCategoryOrderSyncList = List<CategoryRule>.from(ordered);
    _cancelCategoryOrderDebounceTimer();
    DatabaseService._log(
      'CATEGORY_ORDER_SYNC: debounce arm ${ordered.length} row(s) parent=$parentId — fire in ${DatabaseService._categoryOrderDebounce.inSeconds}s',
    );
    _categoryOrderDebounceTimer = Timer(
      DatabaseService._categoryOrderDebounce,
      () {
        _categoryOrderDebounceTimer = null;
        final pending = _pendingCategoryOrderSyncList;
        _pendingCategoryOrderSyncList = null;
        if (pending == null || pending.isEmpty) return;
        DatabaseService._log(
          'CATEGORY_ORDER_SYNC: debounce elapsed — syncing ${pending.length} row(s)',
        );
        unawaited(_persistCategoryOrdersBulkNow(pending));
      },
    );
  }

  Future<void> flushCategoryOrderSyncNow() async {
    _cancelCategoryOrderDebounceTimer();
    final pending = _pendingCategoryOrderSyncList;
    _pendingCategoryOrderSyncList = null;
    DatabaseService._log(
      'CATEGORY_ORDER_SYNC: immediate flush (${pending?.length ?? 0} pending row(s))',
    );
    if (pending == null || pending.isEmpty) return;
    await _persistCategoryOrdersBulkNow(pending);
  }
}
