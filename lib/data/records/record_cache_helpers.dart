part of '../database_service.dart';

extension RecordCacheProjectionExtension on DatabaseService {
  List<Map<String, dynamic>> _filterCachedRecordsForDate(DateTime date) {
    try {
      final targetDayStr = _timelineDateKeyFromDate(date);
      return _timelineDayIndexRowsForKey(targetDayStr);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _recordsForDate(DateTime date) async {
    if (_cachedFlatRecords.isEmpty &&
        _isInitialized &&
        (currentProfileId?.isNotEmpty ?? false)) {
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
      } catch (_) {}
    }
    return _filterCachedRecordsForDate(date);
  }

  List<Map<String, dynamic>> _withDisplayTimes(
    List<Map<String, dynamic>> filtered,
  ) {
    final list = filtered.map((e) => Map<String, dynamic>.from(e)).toList();
    for (final data in list) {
      final st = data['startTime'] as DateTime?;
      final en = data['endTime'] as DateTime?;
      if (st != null) {
        data['startTimeDisplay'] = _profileWallFromUtc(st);
      }
      if (en != null) {
        data['endTimeDisplay'] = _profileWallFromUtc(en);
      }
    }
    return list;
  }

  /// Fingerprint for [recordsStream] — skips a [timeUpdates] tick when the day’s rows are visually unchanged.
  String _timelineRecordsStreamDistinctSignature(
    List<Map<String, dynamic>> rows,
  ) {
    final b = StringBuffer();
    for (final r in rows) {
      b.write((r['record_id'] ?? '').toString().trim());
      b.write('|');
      b.write((r['status'] ?? '').toString().trim().toLowerCase());
      b.write('|');
      b.write((r['title'] ?? '').toString());
      b.write('|');
      final st = r['startTime'] as DateTime?;
      final en = r['endTime'] as DateTime?;
      if (st != null) {
        final u = st.toUtc();
        b.write(
          '${u.year}-${u.month}-${u.day}T${u.hour}:${u.minute}:${u.second}',
        );
      }
      b.write('|');
      if (en != null) {
        final u = en.toUtc();
        b.write(
          '${u.year}-${u.month}-${u.day}T${u.hour}:${u.minute}:${u.second}',
        );
      }
      // Category-only edits do not change length/times/title — must bust stream dedupe.
      b.write('|');
      final catLocal = r['categoryId'];
      if (catLocal != null) {
        b.write(catLocal.toString());
      } else {
        b.write(
          (r['category_id'] ?? r['categoryKey'] ?? '').toString().trim(),
        );
      }
      b.write(';');
    }
    return b.toString();
  }

  /// @visibleForTesting Stream dedupe fingerprint for a calendar day.
  @visibleForTesting
  String debugTimelineRecordsStreamSignatureForDay(DateTime day) {
    return _timelineRecordsStreamDistinctSignature(peekTimelineRecordsForDate(day));
  }

  /// Per-call **async\*** stream: one subscription per [TimelinePage] (recreated on date change only).
  ///
  /// The stream is intentionally long-lived even when a page subscribes before
  /// database/profile readiness. Startup must never turn that early subscription
  /// into a dead stream that only recovers after navigation. Likewise, transient
  /// projection errors keep the last visible state instead of emitting a fake
  /// empty state/flicker.
  Stream<List<Map<String, dynamic>>> recordsStream(DateTime date) async* {
    bool isReady() =>
        _isInitialized && (currentProfileId?.isNotEmpty ?? false);

    List<Map<String, dynamic>> nextPayload() {
      return peekTimelineRecordsForDate(date);
    }

    String? lastStreamSig;
    var hasEmitted = false;

    Future<List<Map<String, dynamic>>?> payloadWhenReady() async {
      if (!isReady()) return null;
      if (_cachedFlatRecords.isEmpty) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (e, st) {
          DatabaseService._log('recordsStream initial catch-up: $e');
          if (kDebugMode) {
            debugPrint(st.toString());
          }
        }
      }
      if (!isReady()) return null;
      try {
        return nextPayload();
      } catch (e, st) {
        DatabaseService._log('recordsStream nextPayload: $e');
        if (kDebugMode) {
          debugPrint(st.toString());
        }
        return null;
      }
    }

    final first = await payloadWhenReady();
    if (first != null) {
      lastStreamSig = _timelineRecordsStreamDistinctSignature(first);
      hasEmitted = true;
      yield first;
    }

    await for (final _ in timeUpdates) {
      final next = await payloadWhenReady();
      if (next == null) {
        // Keep the existing page state. Never turn a transient startup/network
        // condition into a visible empty-state regression.
        continue;
      }
      final sig = _timelineRecordsStreamDistinctSignature(next);
      if (hasEmitted && lastStreamSig == sig) {
        continue;
      }
      lastStreamSig = sig;
      hasEmitted = true;
      yield next;
    }
  }
}

/// @visibleForTesting Brain harness for record category edit integration tests.
extension RecordBrainTestBridge on DatabaseService {
  @visibleForTesting
  void debugResetRecordBrainTestHarness() {
    DatabaseService.debugAuthUserIdForTests = null;
    _cachedFlatRecords = [];
    _optimisticPendingStartRecordMap = null;
    _timelineDayIndexDirty = true;
    _timelineDayViewCache.clear();
    _timelineLazyRowVmByDay.clear();
    _timelineRecordsDayIndex.clear();
    _rules = [];
    _isInitialized = false;
    currentProfileId = null;
  }

  @visibleForTesting
  void debugActivateRecordBrainTestHarness({
    required String userId,
    required List<CategoryRule> categories,
  }) {
    DatabaseService.debugAuthUserIdForTests = userId;
    currentProfileId = userId;
    _isInitialized = true;
    _rules = List<CategoryRule>.from(categories);
    _categoryController.add(List.from(_rules));
  }

  /// Simulates a successful picker create POST (category now in tree with PB id).
  @visibleForTesting
  void debugAddCategoryRuleForTest(CategoryRule rule) {
    _rules = [..._rules, rule];
    _categoryController.add(List.from(_rules));
  }

  @visibleForTesting
  void debugSeedFlatRecordRowForTest(Map<String, dynamic> row) {
    _cachedFlatRecords = [..._cachedFlatRecords, Map<String, dynamic>.from(row)];
    _markTimelineDayIndexDirty();
  }

  @visibleForTesting
  void debugSeedPendingStartRecordForTest(Map<String, dynamic> timelineRow) {
    _optimisticPendingStartRecordMap = Map<String, dynamic>.from(timelineRow);
  }

  @visibleForTesting
  void debugNotifyTimelineForTest() {
    _notifyTimelineAfterRecordCacheMutation();
  }

  @visibleForTesting
  Map<String, dynamic>? debugFlatRecordRowForTestKey(String recordKey) {
    final key = recordKey.trim();
    if (key.isEmpty) return null;
    final resolved = _tryResolveRecordIdFromCacheOnly(key) ?? key;
    final idx = _indexOfCachedRecordRow(resolved, key);
    if (idx < 0) return null;
    return Map<String, dynamic>.from(_cachedFlatRecords[idx]);
  }

  @visibleForTesting
  Map<String, dynamic>? debugPendingStartRecordForTest() {
    final p = _optimisticPendingStartRecordMap;
    if (p == null) return null;
    return Map<String, dynamic>.from(p);
  }

  @visibleForTesting
  String categoryDisplayPathForRecordKeyOnDay({
    required String recordKey,
    required DateTime day,
  }) {
    final rows = peekTimelineRecordsForDate(day);
    final key = recordKey.trim();
    for (final row in rows) {
      final biz = (row['record_id'] ?? '').toString().trim();
      final id = (row['id'] ?? '').toString().trim();
      if (biz == key || id == key || 'optimistic-$biz' == key) {
        return categoryDisplayPathForRecordData(row);
      }
    }
    return '';
  }

  @visibleForTesting
  Future<Map<String, dynamic>> debugRecordPatchUpdatesForCategory({
    required int localCategoryId,
    String title = 'test',
  }) async {
    return _buildRecordPatchUpdates(
      title: title,
      categoryId: localCategoryId,
    );
  }
}
