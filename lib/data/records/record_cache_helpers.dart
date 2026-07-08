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
      b.write(';');
    }
    return b.toString();
  }

  /// Per-call **async\*** stream: one subscription per [TimelinePage] (recreated on date change only).
  /// Mutations update [_cachedFlatRecords] then [_timeUpdateController]; this stream **awaits** that
  /// broadcast and yields [nextPayload] — no intentional empty “reset” event before the new list.
  /// Do not tie this to [fetchRecords] re-entry in a way that completes the stream between ticks.
  Stream<List<Map<String, dynamic>>> recordsStream(DateTime date) async* {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      yield [];
      return;
    }
    if (_cachedFlatRecords.isEmpty) {
      unawaited(_fetchRecordsIntoCache(forceNetwork: true));
    }

    List<Map<String, dynamic>> nextPayload() {
      try {
        return peekTimelineRecordsForDate(date);
      } catch (e, st) {
        DatabaseService._log('recordsStream nextPayload: $e');
        if (kDebugMode) {
          debugPrint(st.toString());
        }
        return <Map<String, dynamic>>[];
      }
    }

    String? lastStreamSig;
    try {
      final first = nextPayload();
      lastStreamSig = _timelineRecordsStreamDistinctSignature(first);
      yield first;
    } catch (_) {
      yield <Map<String, dynamic>>[];
    }
    await for (final _ in timeUpdates) {
      try {
        final next = nextPayload();
        final sig = _timelineRecordsStreamDistinctSignature(next);
        if (lastStreamSig == sig) {
          continue;
        }
        lastStreamSig = sig;
        yield next;
      } catch (_) {
        yield <Map<String, dynamic>>[];
      }
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
