part of '../database_service.dart';

/// Records per yield chunk during adjacent row-VM warmup.
const int _kTimelineAdjVmWarmChunkSize = 4;

/// Skip warmup when a single adjacent day exceeds this (safety cap).
const int _kTimelineAdjVmWarmMaxRecords = 120;

extension RecordTimelineVmExtension on DatabaseService {
  String _timelineDateKeyFromDate(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static const int _kTimelineIndexMaxSyncRecords = 480;

  void _markTimelineDayIndexDirty() {
    _timelineDayIndexDirty = true;
    _timelineLazyRowVmByDay.clear();
  }

  void _ensureTimelineDayIndex() {
    if (!_timelineDayIndexDirty &&
        _timelineDayIndexBuiltAtRecordCount == _cachedFlatRecords.length) {
      return;
    }
    if (_cachedFlatRecords.length <= _kTimelineIndexMaxSyncRecords) {
      _buildTimelineDayIndexImpl();
      return;
    }
    if (_timelineDayIndexBuildInFlight) return;
    _timelineDayIndexBuildInFlight = true;
    Future<void>.delayed(Duration.zero, () {
      try {
        if (!_timelineDayIndexDirty &&
            _timelineDayIndexBuiltAtRecordCount ==
                _cachedFlatRecords.length) {
          return;
        }
        _buildTimelineDayIndexImpl();
      } finally {
        _timelineDayIndexBuildInFlight = false;
      }
    });
  }

  void _buildTimelineDayIndexImpl() {
    final sw = Stopwatch()..start();
    final buckets = <String, List<Map<String, dynamic>>>{};
    final ownerIds = _recordRowOwnerIdMatchSet();
  try {
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        if (_optimisticRowDeletedRaw(row)) continue;
        final rowUid = (row['user_id'] ?? '').toString().trim().toLowerCase();
        if (ownerIds.isEmpty) continue;
        if (rowUid.isEmpty || !ownerIds.contains(rowUid)) continue;
        final stUtc = CategoryServiceExtension._parseDateTimeUtc(
          row['start_time'],
        );
        if (stUtc == null) continue;
        final recordDayStr = _timelineDeviceLocalDayKeyFromUtc(stUtc);
        try {
          final map = _mergeOptimisticIntoRecordMap(_rowToRecordMap(row));
          buckets.putIfAbsent(recordDayStr, () => <Map<String, dynamic>>[]).add(
            map,
          );
        } catch (e, st) {
          final rowData =
              '${CategoryServiceExtension.recordsTablePk(row)} ${(row['record_id'] ?? '').toString().trim()} data=$row';
          DatabaseService._log('TIMELINE_ROW_MAP: $e | $rowData');
          DatabaseService._log(st.toString());
        }
      }
      for (final entry in buckets.entries) {
        entry.value.sort((a, b) {
          final as = a['startTime'] as DateTime?;
          final bs = b['startTime'] as DateTime?;
          if (as == null && bs == null) return 0;
          if (as == null) return 1;
          if (bs == null) return -1;
          return bs.compareTo(as);
        });
        final seenBiz = <String>{};
        final collapsed = <Map<String, dynamic>>[];
        for (final e in entry.value) {
          final biz = (e['record_id'] ?? '').toString().trim();
          if (biz.isNotEmpty) {
            if (seenBiz.contains(biz)) continue;
            seenBiz.add(biz);
          }
          collapsed.add(e);
        }
        entry.value
          ..clear()
          ..addAll(collapsed);
      }
    } catch (_) {
      buckets.clear();
    }
    sw.stop();
    if (kRebuildMetricsEnabled) {
      RebuildMetrics.instance.logTimelineHistoryScan(
        count: _cachedFlatRecords.length,
        ms: sw.elapsedMilliseconds,
        dayBuckets: buckets.length,
      );
    }
    _timelineRecordsDayIndex = buckets;
    _timelineDayIndexDirty = false;
    _timelineDayIndexBuiltAtRecordCount = _cachedFlatRecords.length;
    _timelineDayViewCache.clear();
    _timelineDayVmCache.clear();
    _timelineLazyRowVmByDay.clear();
  }

  List<Map<String, dynamic>> _scanSingleDayFromFlat(String targetDayStr) {
    final out = <Map<String, dynamic>>[];
    final ownerIds = _recordRowOwnerIdMatchSet();
    try {
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        if (_optimisticRowDeletedRaw(row)) continue;
        final rowUid = (row['user_id'] ?? '').toString().trim().toLowerCase();
        if (ownerIds.isEmpty) continue;
        if (rowUid.isEmpty || !ownerIds.contains(rowUid)) continue;
        final stUtc = CategoryServiceExtension._parseDateTimeUtc(
          row['start_time'],
        );
        if (stUtc == null) continue;
        final recordDayStr = _timelineDeviceLocalDayKeyFromUtc(stUtc);
        if (recordDayStr != targetDayStr) continue;
        try {
          out.add(_mergeOptimisticIntoRecordMap(_rowToRecordMap(row)));
        } catch (e) {
          final rid = (row['record_id'] ?? '').toString().trim();
        }
      }
      out.sort((a, b) {
        final as = a['startTime'] as DateTime?;
        final bs = b['startTime'] as DateTime?;
        if (as == null && bs == null) return 0;
        if (as == null) return 1;
        if (bs == null) return -1;
        return bs.compareTo(as);
      });
      final seenBiz = <String>{};
      final collapsed = <Map<String, dynamic>>[];
      for (final e in out) {
        final biz = (e['record_id'] ?? '').toString().trim();
        if (biz.isNotEmpty) {
          if (seenBiz.contains(biz)) continue;
          seenBiz.add(biz);
        }
        collapsed.add(e);
      }
      return collapsed;
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _timelineDayIndexRowsForKey(String targetDayStr) {
    _ensureTimelineDayIndex();
    final indexReady = !_timelineDayIndexDirty &&
        _timelineDayIndexBuiltAtRecordCount == _cachedFlatRecords.length;
    final base = indexReady
        ? List<Map<String, dynamic>>.from(
            _timelineRecordsDayIndex[targetDayStr] ?? const [],
          )
        : _scanSingleDayFromFlat(targetDayStr);
    final pend = _optimisticPendingStartRecordMap;
    if (pend != null) {
      final pRid = (pend['record_id'] ?? '').toString().trim();
      final cacheAlreadyHasPendId =
          pRid.isNotEmpty &&
          base.any((e) => (e['record_id'] ?? '').toString().trim() == pRid);
      if (!cacheAlreadyHasPendId) {
        final pDay = (pend['calendarDayStr'] ?? '').toString().trim();
        if (pDay == targetDayStr) {
          base.insert(0, Map<String, dynamic>.from(pend));
        }
      }
    }
    return base;
  }

  /// Boot-only: hydrate flat records + day index from prefs before network fetch.
  Future<void> bootstrapTimelineRecordsCacheFromPrefsAtBoot({
    bool criticalOnly = false,
  }) async {
    final sw = Stopwatch()..start();
    await _hydrateRecordsCacheFromPrefsIfEmpty();
    sw.stop();
    if (_cachedFlatRecords.isEmpty) return;
    final indexSw = Stopwatch()..start();
    if (_cachedFlatRecords.length <= _kTimelineIndexMaxSyncRecords) {
      _buildTimelineDayIndexImpl();
    } else {
      _markTimelineDayIndexDirty();
    }
    indexSw.stop();
    _syncCanonicalRunningBusinessIdCache('bootRestore');
    if (criticalOnly) return;
    ensureTimelineWarmWindow(getTimelineDeviceLocalToday());
    prebuildTimelineCriticalBodiesSync(getTimelineDeviceLocalToday());
  }

  WarmSnapshotWindow<TimelineDaySnapshot> get _timelineWarm =>
      _timelineWarmWindow ??= WarmSnapshotWindow(
        dateKeyOf: _timelineDateKeyFromDate,
      );

  TimelineDaySnapshot _buildTimelineDaySnapshot(DateTime date) {
    final records = peekTimelineRecordsForDate(date);
    return TimelineDaySnapshot(
      dateKey: _timelineDateKeyFromDate(date),
      knownEmpty: records.isEmpty,
      records: List<Map<String, dynamic>>.from(records),
      cacheSignature: _cachedFlatRecords.length,
    );
  }

  void ensureTimelineWarmWindow(DateTime center) {
    _timelineWarm.ensureInitialWindow(center, _buildTimelineDaySnapshot);
  }

  /// P0T: critical ±1 sync at boot; full mounted window in background.
  void prepareTimelineMountedWindowBoot(
    DateTime center, {
    bool criticalOnly = false,
  }) {
    ensureTimelineWarmWindow(center);
    if (criticalOnly) {
      for (final offset in [-1, 0, 1]) {
        final d = DateTime(center.year, center.month, center.day)
            .add(Duration(days: offset));
        timelineWarmSnapshotForDate(d);
        timelineBodyEntryForDate(d, allowEmergencyBuild: true);
        buildTimelineDayRenderSnapshot(d);
      }
      return;
    }
    final window = DayWindow(center: center);
    for (final d in window.dates) {
      timelineWarmSnapshotForDate(d);
      timelineBodyEntryForDate(d, allowEmergencyBuild: true);
      buildTimelineDayRenderSnapshot(d);
    }
  }

  void scheduleTimelineMountedWindowBootBackground(DateTime center) {
    unawaited(Future.microtask(() {
      prepareTimelineMountedWindowBoot(center);
    }));
  }

  TimelineDayRenderSnapshot? timelineRenderSnapshotForDate(DateTime wallDay) {
    return P0tRenderSnapshotCache.instance.peekTimeline(p0tDateKey(wallDay));
  }

  bool isTimelineDateFullyReady(DateTime wallDay) {
    final key = p0tDateKey(wallDay);
    final snap = P0tRenderSnapshotCache.instance.peekTimeline(key);
    if (snap != null && snap.ready) {
      return true;
    }
    final missing = snap?.missing ?? 'records';
    return false;
  }

  TimelineDayRenderSnapshot buildTimelineDayRenderSnapshot(DateTime wallDay) {
    final key = p0tDateKey(wallDay);
    final body = timelineBodyEntryForDate(wallDay);
    final cards = <TimelineCardRenderDto>[];
    var missing = 'none';

    for (final rec in body.records) {
      final title = (rec['title'] as String?)?.trim() ?? '';
      final catRaw = rec['category_id'];
      final catId = catRaw is int
          ? catRaw
          : int.tryParse(catRaw?.toString() ?? '') ?? 0;
      final categoryReady =
          catId == 0 || getCategoryRuleById(catId) != null;
      if (!categoryReady) missing = 'category';
      cards.add(
        TimelineCardRenderDto(
          recordMap: rec,
          title: title,
          categoryReady: categoryReady,
          tagsReady: true,
        ),
      );
    }

    final ready = missing == 'none' && body.bodyReady;
    final snap = TimelineDayRenderSnapshot(
      dateKey: key,
      knownEmpty: body.knownEmpty,
      cards: cards,
      cacheSignature: body.records.length,
      ready: ready,
      missing: ready ? 'none' : missing,
    );
    P0tRenderSnapshotCache.instance.putTimeline(snap);
    return snap;
  }

  void prepareTimelineCriticalRenderReady(DateTime center) {
    final sw = Stopwatch()..start();
    var ready = 0;
    for (final offset in [-1, 0, 1]) {
      final day = DateTime(center.year, center.month, center.day)
          .add(Duration(days: offset));
      buildTimelineDayRenderSnapshot(day);
      if (isTimelineDateFullyReady(day)) ready++;
    }
    sw.stop();
  }

  int get timelineWarmWindowRecordEstimate {
    var n = 0;
    for (final key in _timelineWarm.dateKeys) {
      n += _timelineWarm.peek(key)?.records.length ?? 0;
    }
    return n;
  }

  Future<void> restoreTimelineWarmSnapshotsFromDiskAtBoot() async {
    final sw = Stopwatch()..start();
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(
        _scopedDataCacheKey(DatabaseService._cacheTimelineWarmSnapshotsKey),
      );
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      var count = 0;
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final v = entry.value;
        if (v is! Map) continue;
        final recordsRaw = v['records'];
        if (recordsRaw is! List) continue;
        final records = <Map<String, dynamic>>[];
        for (final r in recordsRaw) {
          if (r is Map) {
            records.add(Map<String, dynamic>.from(r));
          }
        }
        final knownEmpty = v['knownEmpty'] == true;
        final sig = v['cacheSignature'] is int ? v['cacheSignature'] as int : 0;
        _timelineWarm.put(
          key,
          TimelineDaySnapshot(
            dateKey: key,
            knownEmpty: knownEmpty,
            records: records,
            cacheSignature: sig,
          ),
        );
        timelineDayBodyCache.put(
          key,
          TimelineDayBodyEntry(
            dateKey: key,
            records: List<Map<String, dynamic>>.from(records),
            knownEmpty: knownEmpty,
            bodyReady: true,
            source: 'diskRestore',
          ),
        );
        count++;
      }
      sw.stop();
    } catch (_) {}
  }

  void persistTimelineWarmSnapshotsToDisk() {
    unawaited(() async {
      final sw = Stopwatch()..start();
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        final out = <String, dynamic>{};
        for (final key in _timelineWarm.dateKeys) {
          final snap = _timelineWarm.peek(key);
          if (snap == null) continue;
          out[key] = {
            'knownEmpty': snap.knownEmpty,
            'cacheSignature': snap.cacheSignature,
            'records': snap.records,
          };
        }
        await prefs.setString(
          _scopedDataCacheKey(DatabaseService._cacheTimelineWarmSnapshotsKey),
          jsonEncode(out),
        );
        sw.stop();
      } catch (_) {}
    }());
  }

  void extendTimelineWarmWindowIfNeeded(DateTime center) {
    _timelineWarm.extendIfNeeded(center, _buildTimelineDaySnapshot);
  }

  /// Sync warm snapshot for one day; builds emergency snapshot if missing.
  TimelineDaySnapshot timelineWarmSnapshotForDate(DateTime date) {
    final lookupSw = Stopwatch()..start();
    final key = _timelineDateKeyFromDate(date);
    final sig = _cachedFlatRecords.length;
    final existing = _timelineWarm.peek(key);
    if (existing != null && existing.cacheSignature == sig) {
      lookupSw.stop();
      return existing;
    }
    final built = _buildTimelineDaySnapshot(date);
    _timelineWarm.put(key, built);
    lookupSw.stop();
    return built;
  }

  void _refreshTimelineWarmSnapshotsAfterCacheMutation() {
    if (_timelineWarm.center == null) return;
    final sig = _cachedFlatRecords.length;
    for (final key in _timelineWarm.dateKeys.toList()) {
      final snap = _timelineWarm.peek(key);
      if (snap == null || snap.cacheSignature == sig) continue;
      final day = WarmSnapshotWindow.parseDateKey(key);
      _timelineWarm.put(key, _buildTimelineDaySnapshot(day));
    }
  }

  DayBodyCache<TimelineDayBodyEntry> get timelineDayBodyCache =>
      _timelineBodyCache ??= DayBodyCache<TimelineDayBodyEntry>(
        screen: 'Timeline',
      );

  TimelineDayBodyEntry _buildTimelineBodyEntry(
    DateTime day, {
    required String source,
  }) {
    final snap = timelineWarmSnapshotForDate(day);
    return TimelineDayBodyEntry(
      dateKey: _timelineDateKeyFromDate(day),
      records: List<Map<String, dynamic>>.from(snap.records),
      knownEmpty: snap.knownEmpty,
      bodyReady: true,
      source: source,
    );
  }

  TimelineDayBodyEntry timelineBodyEntryForDate(
    DateTime day, {
    bool allowEmergencyBuild = true,
  }) {
    final key = _timelineDateKeyFromDate(day);
    final cache = timelineDayBodyCache;
    final existing = cache.peek(key);
    if (existing != null && existing.bodyReady) {
      return existing;
    }
    if (!allowEmergencyBuild) {
      return TimelineDayBodyEntry(
        dateKey: key,
        records: const [],
        knownEmpty: true,
        bodyReady: false,
        source: 'pending',
      );
    }
    final inside = cache.isInsideWarmRange(key);
    final sw = Stopwatch()..start();
    final built = _buildTimelineBodyEntry(day, source: 'emergencySyncBuild');
    sw.stop();
    cache.put(key, built);
    return built;
  }

  void prebuildTimelineCriticalBodiesSync(DateTime center) {
    final cache = timelineDayBodyCache;
    final centerKey = _timelineDateKeyFromDate(center);
    cache.setCenter(centerKey);
    final sw = Stopwatch()..start();
    for (final offset in [-1, 0, 1]) {
      final day = DateTime(center.year, center.month, center.day)
          .add(Duration(days: offset));
      final entry = _buildTimelineBodyEntry(day, source: 'criticalPrebuild');
      cache.put(entry.dateKey, entry);
    }
    sw.stop();
    logTimelineBootAdjacentReady(center);
  }

  void logTimelineBootAdjacentReady(DateTime center) {
    for (final label in ['yesterday', 'today', 'tomorrow']) {
      final offset = label == 'yesterday'
          ? -1
          : label == 'tomorrow'
          ? 1
          : 0;
      final day = DateTime(center.year, center.month, center.day)
          .add(Duration(days: offset));
      final key = _timelineDateKeyFromDate(day);
      final cache = timelineDayBodyCache;
    }
  }

  void scheduleTimelineWindowBodyPrebuild(DateTime center) {
    if (_timelineWindowBodyPrebuildInFlight) return;
    _timelineWindowBodyPrebuildInFlight = true;
    final gen = ++_timelineBodyPrebuildGeneration;
    final centerKey = _timelineDateKeyFromDate(center);
    timelineDayBodyCache.setCenter(centerKey);
    unawaited(() async {
      final sw = Stopwatch()..start();
      final total = RenderedDayBodyConstants.radius * 2 + 1;
      var ready = 0;
      for (final offset in DayBodyCache.prioritizedOffsets(
        RenderedDayBodyConstants.radius,
      )) {
        if (gen != _timelineBodyPrebuildGeneration) return;
        await Future<void>.delayed(Duration.zero);
        final day = DateTime(center.year, center.month, center.day)
            .add(Duration(days: offset));
        final key = _timelineDateKeyFromDate(day);
        final cache = timelineDayBodyCache;
        if (cache.isBodyReady(key)) {
          ready++;
          continue;
        }
        final bodySw = Stopwatch()..start();
        final entry = _buildTimelineBodyEntry(day, source: 'windowPrebuild');
        cache.put(key, entry);
        bodySw.stop();
        ready++;
        if (ready % 4 == 0 || ready == total) {
        }
      }
      sw.stop();
      timelineDayBodyCache.logMemory(
        snapshotCount: _timelineWarm.cachedDayCount,
        itemCount: _cachedFlatRecords.length,
      );
      _timelineWindowBodyPrebuildInFlight = false;
    }());
  }

  void extendTimelineRenderedBodiesIfNeeded(DateTime center) {
    extendTimelineWarmWindowIfNeeded(center);
    scheduleTimelineWindowBodyPrebuild(center);
  }

  void ensureTimelineRenderedBodiesWarm(DateTime center) {
    prebuildTimelineCriticalBodiesSync(center);
    scheduleTimelineWindowBodyPrebuild(center);
  }

  void markTimelineDayBodyRendered(String dateKey, int buildMs) {
    final existing = timelineDayBodyCache.peek(dateKey);
    if (existing != null && existing.bodyReady) return;
    if (existing != null) {
      timelineDayBodyCache.put(
        dateKey,
        TimelineDayBodyEntry(
          dateKey: dateKey,
          records: existing.records,
          knownEmpty: existing.knownEmpty,
          bodyReady: true,
          source: existing.source,
        ),
      );
    }
  }

  /// Synchronous per-day timeline rows (filtered, sorted, display times). Used by UI + prefetch.
  List<Map<String, dynamic>> peekTimelineRecordsForDate(DateTime date) {
    final lookupSw = Stopwatch()..start();
    final targetDayStr = _timelineDateKeyFromDate(date);
    if (!_timelineDayIndexDirty) {
      final cachedView = _timelineDayViewCache[targetDayStr];
      if (cachedView != null) {
        if (kRebuildMetricsEnabled) {
          RebuildMetrics.instance.logTimelineCacheHit(
            date: targetDayStr,
            itemCount: cachedView.length,
          );
        }
        return List<Map<String, dynamic>>.from(cachedView);
      }
    }
    if (kRebuildMetricsEnabled) {
      RebuildMetrics.instance.logTimelineCacheMiss(date: targetDayStr);
    }
    final grouped = RebuildMetrics.instance.perfBlock(
      'Timeline.groupRecords',
      () => _timelineDayIndexRowsForKey(targetDayStr),
      meta: {'date': targetDayStr},
    );
    final rendered = RebuildMetrics.instance.perfBlock(
      'Timeline.renderModel',
      () => _withDisplayTimes(grouped),
      meta: {'date': targetDayStr, 'items': grouped.length},
    );
    _timelineDayViewCache[targetDayStr] = List<Map<String, dynamic>>.from(
      rendered,
    );
    lookupSw.stop();
    final state = rendered.isEmpty ? 'empty' : 'hit';
    return List<Map<String, dynamic>>.from(rendered);
  }

  String _timelineSubtitleForRecordMap(
    Map<String, dynamic> data, {
    String? canonicalRunningBiz,
  }) {
    final type = data['type'] as String? ?? 'record';
    if (type == 'planned') {
      return 'planned';
    }
    final rowBiz = (data['record_id'] ?? '').toString().trim();
    final canonicalBiz =
        canonicalRunningBiz ?? resolveCanonicalPrimaryRunningBusinessId();
    final isRunning = type == 'record' &&
        CategoryServiceExtension.isRecordMapActuallyRunning(data) &&
        canonicalBiz != null &&
        canonicalBiz.isNotEmpty &&
        rowBiz == canonicalBiz;
    final startTimeUtc = CategoryServiceExtension.startTimeFromRecord(data);
    final endTimeUtc = CategoryServiceExtension.endTimeFromRecord(data);
    if (isRunning) {
      if (startTimeUtc != null) {
        final start =
            _timelineFormatTimeOfDay(_profileWallFromUtc(startTimeUtc));
        final duration =
            DatabaseService.getPlanetaryNow().difference(startTimeUtc);
        return '$start — ... (${_timelineFormatDuration(duration)})';
      }
      return 'running';
    }
    if (startTimeUtc != null) {
      final start =
          _timelineFormatTimeOfDay(_profileWallFromUtc(startTimeUtc));
      final end = endTimeUtc != null
          ? _timelineFormatTimeOfDay(_profileWallFromUtc(endTimeUtc))
          : '...';
      final endOrNow = endTimeUtc ?? DatabaseService.getPlanetaryNow();
      final duration = endOrNow.difference(startTimeUtc);
      return '$start — $end (${_timelineFormatDuration(duration)})';
    }
    return '–';
  }

  String _timelineFormatTimeOfDay(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _timelineFormatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${d.inSeconds}s';
  }

  TimelineRecordRowVm? _timelineRowVmFromMapOrNull(
    Map<String, dynamic> data, {
    String? canonicalRunningBiz,
  }) {
    try {
      return _timelineRowVmFromMap(
        data,
        canonicalRunningBiz: canonicalRunningBiz,
      );
    } catch (e) {
      final rid = (data['record_id'] ?? data['id'] ?? '').toString().trim();
      return null;
    }
  }

  TimelineRecordRowVm _timelineFallbackRowVm(Map<String, dynamic> data) {
    final systemRowId = (data['id'] ?? data['backendNumericId'] ?? '')
        .toString()
        .trim();
    final businessRecordId = (data['record_id'] ?? '').toString().trim();
    return TimelineRecordRowVm(
      systemRowId: systemRowId,
      businessRecordId: businessRecordId,
      rawData: data,
      title: data['title']?.toString() ?? '…',
      subtitle: '–',
      categoryPath: '',
      categoryColorArgb: 0xFF9E9E9E,
      isPlanned: false,
      isCanonicalRunning: false,
      showNotesIcon: false,
      showChecklistIcon: false,
      showParentIcon: false,
      showLinkedSubsIcon: false,
    );
  }

  /// Lazy row VM for list virtualization — builds one row at a time with per-day cache.
  TimelineRecordRowVm timelineRowVmForRecordMapOrNull(
    String dateKey,
    Map<String, dynamic> data,
  ) {
    final biz = (data['record_id'] ?? '').toString().trim();
    final sys = (data['id'] ?? data['backendNumericId'] ?? '').toString().trim();
    final cacheKey = biz.isNotEmpty ? biz : (sys.isNotEmpty ? sys : data.hashCode.toString());
    final dayCache = _timelineLazyRowVmByDay.putIfAbsent(dateKey, () => {});
    final hit = dayCache[cacheKey];
    if (hit != null) return hit;
    final built = _timelineRowVmFromMapOrNull(data) ?? _timelineFallbackRowVm(data);
    dayCache[cacheKey] = built;
    return built;
  }

  TimelineRecordRowVm _timelineRowVmFromMap(
    Map<String, dynamic> data, {
    String? canonicalRunningBiz,
  }) {
    final systemRowId =
        (data['id'] ?? data['backendNumericId'] ?? '').toString().trim();
    final businessRecordId = (data['record_id'] ?? '').toString().trim();
    final title =
        data['title'] as String? ??
        (systemRowId.isNotEmpty ? systemRowId : '?');
    final type = data['type'] as String? ?? 'record';
    final canonicalBiz =
        canonicalRunningBiz ?? resolveCanonicalPrimaryRunningBusinessId();
    final isPlanned = type == 'planned';
    final isCanonicalRunning = type == 'record' &&
        CategoryServiceExtension.isRecordMapActuallyRunning(data) &&
        canonicalBiz != null &&
        canonicalBiz.isNotEmpty &&
        businessRecordId == canonicalBiz;
    final rec = Record.forTimelineCard(data);
    final color = categoryDisplayColorForRecordData(data);
    final categoryPath = categoryDisplayPathForRecordData(data);
    final subtitle = _timelineSubtitleForRecordMap(
      data,
      canonicalRunningBiz: canonicalBiz,
    );
    final showNotes = rec.hasNotes;
    final showChecklist = rec.hasChecklist;
    final showParent = rec.hasParentRecord;
    final showLinkedSubs = rec.hasLinkedSubRecords;
    final colorArgb = color.toARGB32();
    return TimelineRecordRowVm(
      systemRowId: systemRowId,
      businessRecordId: businessRecordId,
      rawData: data,
      title: title,
      subtitle: subtitle,
      categoryPath: categoryPath,
      categoryColorArgb: colorArgb,
      isPlanned: isPlanned,
      isCanonicalRunning: isCanonicalRunning,
      showNotesIcon: showNotes,
      showChecklistIcon: showChecklist,
      showParentIcon: showParent,
      showLinkedSubsIcon: showLinkedSubs,
    );
  }

  void _pinTimelineRowVmInLazyCache(
    String dateKey,
    Map<String, dynamic> data,
    TimelineRecordRowVm vm,
  ) {
    final biz = (data['record_id'] ?? '').toString().trim();
    final sys = (data['id'] ?? data['backendNumericId'] ?? '').toString().trim();
    final cacheKey = biz.isNotEmpty
        ? biz
        : (sys.isNotEmpty ? sys : data.hashCode.toString());
    final dayCache = _timelineLazyRowVmByDay.putIfAbsent(dateKey, () => {});
    dayCache[cacheKey] = vm;
  }

  List<TimelineRecordRowVm> _buildTimelineRowVmsForDate(
    String dateKey,
    DateTime date,
  ) {
    final sw = Stopwatch()..start();
    final maps = peekTimelineRecordsForDate(date);
    final canonicalRunningBiz = resolveCanonicalPrimaryRunningBusinessId();
    final vms = <TimelineRecordRowVm>[];
    for (final m in maps) {
      final vm = _timelineRowVmFromMapOrNull(
        m,
        canonicalRunningBiz: canonicalRunningBiz,
      );
      if (vm != null) {
        vms.add(vm);
        _pinTimelineRowVmInLazyCache(dateKey, m, vm);
      }
    }
    sw.stop();
    if (kRebuildMetricsEnabled) {
      RebuildMetrics.instance.logTimelineViewCacheRebuild(
        date: dateKey,
        records: maps.length,
        ms: sw.elapsedMilliseconds,
      );
    }
    return vms;
  }

  /// P0U.4 — queue ±1 day row-VM warmup after first rendered frame.
  void scheduleTimelineAdjacentRowVmWarmup(
    DateTime center, {
    required bool Function() timelineTabActive,
    required bool Function() centerDateUnchanged,
  }) {
    RuntimeLog.logAdjVmWarmDisabledIfNeeded();
    if (!kTimelineAdjacentRowVmWarmup || kUseMountedDayStrip) return;
    final captured = DateTime(center.year, center.month, center.day);
    final gen = ++_timelineAdjVmWarmGeneration;
    StartupLog.scheduleAfterFirstFrame('timelineAdjVmWarm', () async {
      await _warmTimelineAdjacentRowVms(
        generation: gen,
        center: captured,
        timelineTabActive: timelineTabActive,
        centerDateUnchanged: centerDateUnchanged,
      );
    });
  }

  /// P0U.4 — re-warm ±1 after page settle (post-firstFrame).
  void ensureTimelineAdjacentRowVmWarmup(
    DateTime center, {
    required bool Function() timelineTabActive,
    required bool Function() centerDateUnchanged,
  }) {
    RuntimeLog.logAdjVmWarmDisabledIfNeeded();
    if (!kTimelineAdjacentRowVmWarmup || kUseMountedDayStrip) return;
    final captured = DateTime(center.year, center.month, center.day);
    final gen = ++_timelineAdjVmWarmGeneration;
    unawaited(
      _warmTimelineAdjacentRowVms(
        generation: gen,
        center: captured,
        timelineTabActive: timelineTabActive,
        centerDateUnchanged: centerDateUnchanged,
      ),
    );
  }

  Future<List<TimelineRecordRowVm>?> _buildTimelineRowVmsChunked({
    required int generation,
    required String dateKey,
    required List<Map<String, dynamic>> maps,
    required bool Function() timelineTabActive,
    required bool Function() centerDateUnchanged,
  }) async {
    if (maps.length > _kTimelineAdjVmWarmMaxRecords) {
      return const [];
    }
    final canonicalRunningBiz = resolveCanonicalPrimaryRunningBusinessId();
    final vms = <TimelineRecordRowVm>[];
    var i = 0;
    while (i < maps.length) {
      if (generation != _timelineAdjVmWarmGeneration) return null;
      if (!timelineTabActive()) return null;
      if (!centerDateUnchanged()) return null;
      final end = min(i + _kTimelineAdjVmWarmChunkSize, maps.length);
      for (; i < end; i++) {
        final m = maps[i];
        final vm = _timelineRowVmFromMapOrNull(
          m,
          canonicalRunningBiz: canonicalRunningBiz,
        );
        if (vm != null) {
          vms.add(vm);
          _pinTimelineRowVmInLazyCache(dateKey, m, vm);
        }
      }
      if (i < maps.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return vms;
  }

  Future<void> _warmTimelineAdjacentRowVms({
    required int generation,
    required DateTime center,
    required bool Function() timelineTabActive,
    required bool Function() centerDateUnchanged,
  }) async {
    if (!timelineTabActive()) {
      return;
    }
    if (!centerDateUnchanged()) {
      return;
    }
    final prev = center.subtract(const Duration(days: 1));
    final next = center.add(const Duration(days: 1));
    for (final day in [prev, next]) {
      if (generation != _timelineAdjVmWarmGeneration) return;
      if (!timelineTabActive()) {
        return;
      }
      if (!centerDateUnchanged()) {
        return;
      }
      final key = _timelineDateKeyFromDate(day);
      if (_timelineDayVmCache.containsKey(key)) {
        continue;
      }
      final maps = peekTimelineRecordsForDate(day);
      final built = await _buildTimelineRowVmsChunked(
        generation: generation,
        dateKey: key,
        maps: maps,
        timelineTabActive: timelineTabActive,
        centerDateUnchanged: centerDateUnchanged,
      );
      if (built == null) return;
      _timelineDayVmCache[key] = built;
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Render-ready row VMs for a calendar day (cached; no UI-side grouping/formatting).
  List<TimelineRecordRowVm> peekTimelineRowVmsForDate(DateTime date) {
    final targetDayStr = _timelineDateKeyFromDate(date);
    final cached = _timelineDayVmCache[targetDayStr];
    if (cached != null) {
      if (kRebuildMetricsEnabled) {
        RebuildMetrics.instance.logTimelineViewCacheHit(
          date: targetDayStr,
          items: cached.length,
        );
      }
      return cached;
    }
    final built = _buildTimelineRowVmsForDate(targetDayStr, date);
    _timelineDayVmCache[targetDayStr] = built;
    return built;
  }

  void invalidateTimelineDayCachesForDateKey(String dateKey, {String? reason}) {
    _timelineDayViewCache.remove(dateKey);
    _timelineDayVmCache.remove(dateKey);
    _timelineLazyRowVmByDay.remove(dateKey);
    if (kRebuildMetricsEnabled && reason != null) {
      RebuildMetrics.instance.logTimelineViewCacheInvalidate(
        date: dateKey,
        reason: reason,
      );
    }
  }
}
