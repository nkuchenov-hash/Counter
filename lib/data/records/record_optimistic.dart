part of '../database_service.dart';

extension RecordOptimisticExtension on DatabaseService {
  Map<String, dynamic> _mergeOptimisticIntoRecordMap(
    Map<String, dynamic> data,
  ) {
    final rid = (data['record_id'] ?? '').toString().trim();
    final nid =
        (data['id'] ??
                data['backendRestPathId'] ??
                data['nocoRestPathId'] ??
                '')
            .toString()
            .trim();
    _OptimisticEndPatch? p;
    for (final k in [rid, nid]) {
      if (k.isNotEmpty && _optimisticEndByKey.containsKey(k)) {
        p = _optimisticEndByKey[k];
        break;
      }
    }
    if (p == null) return data;
    final m = Map<String, dynamic>.from(data);
    m['endTime'] = p.endUtc;
    m['status'] = 'completed';
    return m;
  }

  void _applyOptimisticStopUiSnapshot(String recordId) {
    try {
      final keys = _collectRecordKeysFromCache(recordId);
      final now = DatabaseService.getPlanetaryNow();
      for (final k in keys) {
        if (k.isNotEmpty) _optimisticEndByKey[k] = _OptimisticEndPatch(now);
      }
      _notifyTimelineAfterRecordCacheMutation();
    } catch (e, st) {
      DatabaseService._log('applyOptimisticStopUiSnapshot failed: $e');
      DatabaseService._log(st.toString());
    }
  }

  void _clearOptimisticStopKeysForRecord(String recordId) {
    try {
      final keys = _collectRecordKeysFromCache(recordId);
      for (final k in keys) {
        _optimisticEndByKey.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
    } catch (e, st) {
      DatabaseService._log('clearOptimisticStopKeysForRecord failed: $e');
      DatabaseService._log(st.toString());
    }
  }

  /// Clears optimistic overlay for timeline + active row (call after failed write or server sync).
  void clearOptimisticTimelineUi({bool notifyTimeline = true}) {
    try {
      _optimisticEndByKey.clear();
      _optimisticDeletedKeys.clear();
      _optimisticPendingStartRecordMap = null;
      if (notifyTimeline) {
        _notifyTimelineAfterRecordCacheMutation();
      }
    } catch (e, st) {
      DatabaseService._log('clearOptimisticTimelineUi failed: $e');
      DatabaseService._log(st.toString());
    }
  }

  Map<String, dynamic> _buildOptimisticPendingStartRecordMap({
    required String clientRecordId,
    required String title,
    required DateTime startUtc,
    int? categoryId,
  }) {
    final calendarDayStr = _timelineDeviceLocalDayKeyFromUtc(startUtc);
    final biz = clientRecordId.trim();
    // REST map `id` must be a timeline rest key (PB / int / optimistic-*), never a bare UUID —
    // otherwise TimelineRecord.fromMap drops id → empty → edit Save falsely took create path.
    final restKey = biz.startsWith('optimistic-') ? biz : 'optimistic-$biz';
    return <String, dynamic>{
      'id': restKey,
      'backendRestPathId': restKey,
      'record_id': biz,
      'backendNumericId': null,
      'docId': 0,
      'title': title,
      'type': 'record',
      'status': 'running',
      'startTime': startUtc,
      'endTime': null,
      'categoryId': categoryId,
      'calendarDayStr': calendarDayStr,
      'parentId': null,
      '_optimisticPending': true,
    };
  }

  /// Stops all running primaries in the cache **visually** (Sacred Law) + inserts a pending running row.
  void applyOptimisticSacredHandoffForNewStart({
    required String clientRecordId,
    required String title,
    required DateTime startUtc,
    int? categoryId,
  }) {
    try {
      final now = DatabaseService.getPlanetaryNow();
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        if (!CategoryServiceExtension._isNocoRowSacredStopTarget(row)) continue;
        final pk = CategoryServiceExtension.recordsTablePk(row);
        final biz = (row['record_id'] ?? '').toString().trim();
        for (final k in [pk, biz]) {
          if (k.isNotEmpty) _optimisticEndByKey[k] = _OptimisticEndPatch(now);
        }
      }
      _optimisticPendingStartRecordMap = _buildOptimisticPendingStartRecordMap(
        clientRecordId: clientRecordId,
        title: title,
        startUtc: startUtc,
        categoryId: categoryId,
      );
      _notifyTimelineAfterRecordCacheMutation();
    } catch (e, st) {
      DatabaseService._log(
        'applyOptimisticSacredHandoffForNewStart failed: $e',
      );
      DatabaseService._log(st.toString());
    }
  }

  bool _pendingStartRecordMatchesKey(
    Map<String, dynamic> pending,
    String originalInput,
    String resolved,
  ) {
    final o = originalInput.trim();
    final r = resolved.trim();
    if (o.isEmpty && r.isEmpty) return false;
    final biz = (pending['record_id'] ?? '').toString().trim();
    final id =
        (pending['id'] ?? pending['backendRestPathId'] ?? '').toString().trim();
    final keys = <String>[
      if (biz.isNotEmpty) biz,
      if (id.isNotEmpty) id,
      if (biz.isNotEmpty) 'optimistic-$biz',
    ];
    if (o.isNotEmpty && keys.any((k) => k == o)) return true;
    if (r.isNotEmpty && r != o && keys.any((k) => k == r)) return true;
    return false;
  }

  /// Timeline VM row shape (pending start overlay) — uses camelCase categoryId.
  bool _applyTimelineRecordMapCategory(
    Map<String, dynamic> row,
    int categoryId,
  ) {
    final pair = _recordCategoryDualityForLocalId(categoryId);
    if (pair == null) return false;
    row['categoryId'] = categoryId;
    row['categoryKey'] = pair.relationId;
    row['_expanded_category'] = <String, dynamic>{
      'id': pair.relationId,
      'category_id': pair.businessId,
      'name': getCategoryRuleById(categoryId)?.name,
    };
    return true;
  }
}
