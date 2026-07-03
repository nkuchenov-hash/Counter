part of 'database_service.dart';

// Record domain extracted from database_service.dart (V5.3).
// Contains: record cache, realtime subscription, fetchRecords,
// record CRUD, optimistic UI, streams, timeline helpers.

bool _recordMutationOutboxFlushInFlight = false;

/// P0U.4 — generation token; bump to cancel in-flight adjacent VM warmup.
int _timelineAdjVmWarmGeneration = 0;


bool _recordMutationRetriableHttpCode(int code) {
  if (code == 401 || code == 403 || code == 404) return false;
  if (code == 400 || code == 422) return false;
  if (code >= 200 && code < 300) return false;
  return true;
}

extension RecordServiceExtension on DatabaseService {
  Map<String, dynamic> _recordMapFromPb(RecordModel r) {
    final d = Map<String, dynamic>.from(r.data);
    d['id'] = r.id;
    d['_pb_record_id'] = r.id;
    dynamic exp = r.get<dynamic>('expand.$kPbRecordCategoryExpand');
    exp ??= r.get<dynamic>('expand.category_id');
    if (exp is RecordModel) {
      final cd = exp.data;
      d['category_id'] = cd['category_id']?.toString() ?? d['category_id'];
      d['_expanded_category'] = <String, dynamic>{...cd, 'id': exp.id};
    } else if (exp is List && exp.isNotEmpty) {
      final first = exp.first;
      if (first is RecordModel) {
        final cd = first.data;
        d['category_id'] = cd['category_id']?.toString() ?? d['category_id'];
        d['_expanded_category'] = <String, dynamic>{...cd, 'id': first.id};
      }
    } else {
      final linkRaw = normalizeLinkScalar(d['category_link']);
      final linkStr = linkRaw?.toString().trim() ?? '';
      if (linkStr.isNotEmpty &&
          DatabaseService._isLikelyPocketBaseRowId(linkStr)) {
        final rule = getCategoryRuleByBackendRowId(linkStr);
        if (rule != null) {
          final biz = _categoryStringPkForApi(rule);
          if (biz != null && biz.isNotEmpty) {
            d['category_id'] = biz;
          }
          d['_expanded_category'] = <String, dynamic>{
            'id': linkStr,
            'category_id': d['category_id'],
          };
        }
      }
    }
    final expTags = r.get<dynamic>('expand.$kPbRecordTagsExpand');
    if (expTags is List) {
      d['_expanded_tags'] = <Map<String, dynamic>>[
        for (final item in expTags)
          if (item is RecordModel)
            <String, dynamic>{...item.data, 'id': item.id}
          else if (item is Map)
            Map<String, dynamic>.from(item),
      ];
    } else if (expTags is RecordModel) {
      d['_expanded_tags'] = <Map<String, dynamic>>[
        <String, dynamic>{...expTags.data, 'id': expTags.id},
      ];
    }
    final uidNorm = normalizeLinkScalar(d['user_id']);
    if (uidNorm != null) {
      d['user_id'] = uidNorm.toString().trim();
    }
    return d;
  }


  /// True when [after] only advances REST/metadata (e.g. PocketBase `id`) but timeline-visible
  /// fields match [before] — skip [timeUpdates] to avoid ID-swap list blink.
  static bool _flatTimelineVisuallyEquivalent(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    String ns(dynamic v) {
      if (v == null) return '';
      final x = normalizeLinkScalar(v);
      return (x ?? v).toString().trim();
    }

    bool sameTime(dynamic a, dynamic b) {
      final da = CategoryServiceExtension._parseDateTimeUtc(a);
      final db = CategoryServiceExtension._parseDateTimeUtc(b);
      if (da != null && db != null) {
        final ua = da.toUtc();
        final ub = db.toUtc();
        final aSec = DateTime.utc(
          ua.year,
          ua.month,
          ua.day,
          ua.hour,
          ua.minute,
          ua.second,
        );
        final bSec = DateTime.utc(
          ub.year,
          ub.month,
          ub.day,
          ub.hour,
          ub.minute,
          ub.second,
        );
        return aSec == bSec;
      }
      final sa = normalizeRecordIsoToUtcSecondPrecision(a);
      final sb = normalizeRecordIsoToUtcSecondPrecision(b);
      if ((sa ?? '').isNotEmpty || (sb ?? '').isNotEmpty) {
        return sa == sb;
      }
      return ns(a) == ns(b);
    }

    if (ns(before['status']).toLowerCase() !=
        ns(after['status']).toLowerCase()) {
      return false;
    }
    if (ns(before['title']) != ns(after['title'])) return false;
    if (ns(before['record_id']) != ns(after['record_id'])) return false;
    if (!sameTime(before['start_time'], after['start_time'])) return false;
    if (!sameTime(before['end_time'], after['end_time'])) return false;
    if (ns(before['type']) != ns(after['type'])) return false;
    if (ns(before['parent_id']) != ns(after['parent_id'])) return false;
    if (ns(before['tags']) != ns(after['tags'])) return false;
    if (ns(before['category_id']) != ns(after['category_id'])) return false;
    if (ns(before['note']) != ns(after['note']) ||
        ns(before['notes']) != ns(after['notes'])) {
      return false;
    }
    try {
      final ea = jsonEncode(before['checklist'] ?? <dynamic>[]);
      final eb = jsonEncode(after['checklist'] ?? <dynamic>[]);
      if (ea != eb) return false;
    } catch (_) {
      if (ns(before['checklist']) != ns(after['checklist'])) return false;
    }
    return true;
  }

  /// Merge one PocketBase **records** row into [_cachedFlatRecords] without refetching the full list.
  void _upsertFlatRecordFromPbModel(
    RecordModel r, {
    bool preserveExpand = true,
    bool suppressTimelineNotify = false,
    bool logSuccessLine = true,
  }) {
    try {
      final m = _recordMapFromPb(r);
      final pk = CategoryServiceExtension.recordsTablePk(m);
      if (pk.isEmpty) return;
      final biz = (m['record_id'] ?? '').toString().trim();
      final next = List<Map<String, dynamic>>.from(_cachedFlatRecords);
      for (var i = 0; i < next.length; i++) {
        final row = next[i];
        final rpk = CategoryServiceExtension.recordsTablePk(row);
        final rbiz = (row['record_id'] ?? '').toString().trim();
        final same =
            rpk == pk || (biz.isNotEmpty && (rbiz == biz || rpk == biz));
        if (same) {
          if (preserveExpand) {
            if (m['_expanded_category'] == null &&
                row['_expanded_category'] != null) {
              m['_expanded_category'] = row['_expanded_category'];
            }
            final priorLocal = categoryIdFromRecordRow(row);
            final mergedLocal = categoryIdFromRecordRow(m);
            if (_planLocalCategoryIdIsConcrete(priorLocal) &&
                (!_planLocalCategoryIdIsConcrete(mergedLocal) ||
                    mergedLocal != priorLocal)) {
              m['category_id'] = row['category_id'];
              if (row['category_link'] != null) {
                m['category_link'] = row['category_link'];
              }
              if (row['_expanded_category'] != null) {
                m['_expanded_category'] = row['_expanded_category'];
              }
            }
          }
          final silent =
              rbiz.isNotEmpty &&
              biz.isNotEmpty &&
              rbiz == biz &&
              _flatTimelineVisuallyEquivalent(row, m);
          next[i] = m;
          _cachedFlatRecords = next;
          if (!suppressTimelineNotify && !silent) {
            _notifyTimelineAfterRecordCacheMutation();
          }
          return;
        }
      }
      next.add(m);
      _cachedFlatRecords = next;
      if (!suppressTimelineNotify) {
        _notifyTimelineAfterRecordCacheMutation();
      }
    } catch (e, st) {
      DatabaseService._log('_upsertFlatRecordFromPbModel failed: $e');
      DatabaseService._log(st.toString());
    }
  }

  void _removeCachedFlatRecordByPk(String pocketBaseRowId) {
    final id = pocketBaseRowId.trim();
    if (id.isEmpty) return;
    final before = _cachedFlatRecords.length;
    _cachedFlatRecords = [
      for (final row in _cachedFlatRecords)
        if (CategoryServiceExtension.recordsTablePk(row) != id) row,
    ];
    if (_cachedFlatRecords.length != before) {
      _notifyTimelineAfterRecordCacheMutation();
    }
  }


  /// PocketBase: **records** for the current user with category + tags expands (@POCKETBASE_MANIFEST).
  /// Updates [_cachedFlatRecords] for timeline filtering without repeated GETs.
  ///
  /// When [forceNetwork] is false (default), returns **cached** rows for [\DatabaseService._kMinGapRecordsNetworkFetch]
  /// after a successful sync — kills VPS spam from UI/timer loops. Use **true** after mutations / pull-to-refresh.
  Future<List<Map<String, dynamic>>> fetchRecords({
    bool forceNetwork = false,
  }) async {
    final pid = currentProfileId;
    if (pid == null || pid.isEmpty) {
      _cachedFlatRecords = [];
      _resetCanonicalRunningBusinessIdCache();
      return [];
    }
    final now = DateTime.now();
    if (!forceNetwork &&
        _lastSuccessfulRecordsNetworkFetchAt != null &&
        now.difference(_lastSuccessfulRecordsNetworkFetchAt!) <
            DatabaseService._kMinGapRecordsNetworkFetch &&
        _cachedFlatRecords.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_cachedFlatRecords);
    }
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        return List<Map<String, dynamic>>.from(_cachedFlatRecords);
      }
      final filterClause = _pocketBaseOwnerFilterClauseForRecords();
      if (filterClause == null || filterClause.isEmpty) {
        _cachedFlatRecords = [];
        _resetCanonicalRunningBusinessIdCache();
        return [];
      }
      final expandRel = '$kPbRecordCategoryExpand,$kPbRecordTagsExpand';
      List<RecordModel> list;
      final pbSw = Stopwatch()..start();
      try {
        list = await _pb
            .collection(PbCollections.records)
            .getFullList(filter: filterClause, expand: expandRel);
      } on ClientException catch (_) {
        list = await _pb
            .collection(PbCollections.records)
            .getFullList(filter: filterClause, expand: kPbRecordCategoryExpand);
        if (kDebugMode) {
          debugPrint(
            '[PB] fetchRecords: retry without $kPbRecordTagsExpand (schema?)',
          );
        }
      }
      pbSw.stop();
      if (kRebuildMetricsEnabled) {
        RebuildMetrics.instance.logPbTimelineQuery(
          date: 'broad',
          filter: filterClause,
          returned: list.length,
          ms: pbSw.elapsedMilliseconds,
          broad: true,
          reason: 'getFullList_user_records',
        );
      }
      await Future<void>.delayed(Duration.zero);
      final kept = <Map<String, dynamic>>[];
      try {
        for (final r in list) {
          try {
            final m = _recordMapFromPb(r);
            final pk = CategoryServiceExtension.recordsTablePk(m);
            if (pk.isEmpty) {
              DatabaseService._log(
                'GHOST_ROW_SKIPPED: PB record missing PK (keys=${m.keys.map((k) => k.toString()).take(12).join(",")})',
              );
              continue;
            }
            kept.add(Map<String, dynamic>.from(m));
          } catch (e, st) {
            final rowData = '${r.id} data=${r.data}';
            DatabaseService._log('RECORD_PARSE_ROW: $e | $rowData');
            DatabaseService._log(st.toString());
          }
        }
      } catch (e, st) {
        DatabaseService._log('fetchRecords: mapping loop failed: $e');
        DatabaseService._log(st.toString());
      }
      if (kept.isEmpty && _cachedFlatRecords.isNotEmpty) {
        return List<Map<String, dynamic>>.from(_cachedFlatRecords);
      }
      final beforeCount = _cachedFlatRecords.length;
      _cachedFlatRecords = kept;
      _markTimelineDayIndexDirty();
      _pruneRecord404DeadletterUsingCache();
      _lastSuccessfulRecordsNetworkFetchAt = DateTime.now();
      if (kDebugMode && forceNetwork) {
        debugPrint(
          '[PB] fetchRecords: ${kept.length} rows (expand $expandRel) @ $kPocketBaseUrl',
        );
      }
      if (forceNetwork && _isInitialized) {
        _notifyTimelineAfterRecordCacheMutation();
      } else if (_isInitialized) {
        _syncCanonicalRunningBusinessIdCache('fetchRecords');
        _refreshTimelineWarmSnapshotsAfterCacheMutation();
      }
      final cacheKey = _scopedDataCacheKey(
        DatabaseService._cacheRecordsFlatKey,
      );
      final keptJson = await compute(_encodeRecordsFlatForPrefs, kept);
      unawaited(() async {
        try {
          final prefs = _prefs ?? await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, keptJson);
        } catch (_) {}
      }());
      return _cachedFlatRecords;
    } catch (e) {
      _maybeOpenPbCircuitFromListFailure(e, 'fetchRecords');
      await _hydrateRecordsCacheFromPrefsIfEmpty();
      return List<Map<String, dynamic>>.from(_cachedFlatRecords);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRecordsIntoCache({
    bool forceNetwork = false,
  }) => fetchRecords(forceNetwork: forceNetwork);

  Future<List<Map<String, dynamic>>> getRecords({bool forceNetwork = false}) =>
      fetchRecords(forceNetwork: forceNetwork);

  // --- Record CRUD, optimistic UI, streams ---

  Future<String?> _finalizeRecordCreateHandshake({
    required String pocketCreatedRecordId,
  }) async {
    final id = pocketCreatedRecordId.trim();
    if (id.isEmpty) return null;
    DatabaseService._log('WRITE_RECORD_PK_OK: server_id=$id');
    return id;
  }

  /// True when [parent_id] points to a parent row (int PK, UUID string, or Link object).
  bool _rowHasNonEmptyParent(dynamic parentField) {
    if (parentField == null) return false;
    final flat = normalizeLinkScalar(parentField);
    final s = (flat ?? parentField).toString().trim();
    if (s.isEmpty || s == '0') return false;
    return true;
  }

  /// Resolves stored category key (int, slug, UUID, display id) to app [CategoryRule.id].
  int? findCategoryIdForStoredCategoryKey(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final asInt = int.tryParse(s);
    if (asInt != null && asInt != 0) return asInt;
    final t = s.toLowerCase();
    int? found;
    void visit(List<CategoryRule> rules) {
      for (final r in rules) {
        final tag = r.name.trim().toLowerCase();
        final noco = (r.backendRowId ?? '').trim().toLowerCase();
        if (r.id.toString() == s) {
          found = r.id;
          return;
        }
        if (noco.isNotEmpty && noco == t) {
          found = r.id;
          return;
        }
        final n = (r.normalizedId ?? '').toString().trim().toLowerCase();
        if (n.isNotEmpty && n == t) {
          found = r.id;
          return;
        }
        if (tag.isNotEmpty && tag == t) {
          found = r.id;
          return;
        }
        if (r.children != null) visit(r.children!);
      }
    }

    visit(_rules);
    if (found != null) return found;
    return findCategoryIdByNormalizedTag(s) ?? findCategoryIdByTag(s);
  }

  /// Maps stored `category_id` (number, slug, UUID, link expand) to [CategoryRule.id].
  int? categoryIdFromRecordRow(Map<String, dynamic> row) {
    try {
      dynamic v = row['category_id'] ?? row['Category_id'] ?? row['categoryId'];
      v = normalizeLinkScalar(v);
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) {
          final asInt = CategoryServiceExtension._rowInt(v);
          if (asInt != 0) return asInt;
          final fromKey = findCategoryIdForStoredCategoryKey(s);
          if (fromKey != null) return fromKey;
        }
      }
      final exp = row['_expanded_category'];
      if (exp is Map) {
        final pid = (exp['id'] ?? exp['Id'] ?? '').toString().trim();
        if (pid.isNotEmpty) {
          int? byBackend;
          void visit(List<CategoryRule> rules) {
            for (final rule in rules) {
              final b = (rule.backendRowId ?? '').trim();
              if (b.isNotEmpty && b == pid) {
                byBackend = rule.id;
                return;
              }
              if (rule.children != null) visit(rule.children!);
            }
          }

          visit(_rules);
          if (byBackend != null) return byBackend;
          return CategoryRule.uncategorizedSyntheticId;
        }
      }
      final linkFlat = normalizeLinkScalar(
        row['category_link'] ?? row['categoryLink'],
      );
      if (linkFlat != null && linkFlat.toString().trim().isNotEmpty) {
        final linkStr = linkFlat.toString().trim();
        if (DatabaseService._isLikelyPocketBaseRowId(linkStr)) {
          final fromLink = getCategoryRuleByBackendRowId(linkStr)?.id;
          if (fromLink != null) return fromLink;
        }
        final fromKey = findCategoryIdForStoredCategoryKey(linkStr);
        if (fromKey != null) return fromKey;
      }
      if (v != null && v.toString().trim().isNotEmpty) {
        return CategoryRule.uncategorizedSyntheticId;
      }
      return null;
    } catch (_) {
      return CategoryRule.uncategorizedSyntheticId;
    }
  }

  Map<String, dynamic> _rowToRecordMap(Map<String, dynamic> row) {
    final start = CategoryServiceExtension._parseDateTimeUtc(row['start_time']);
    final end = CategoryServiceExtension._parseDateTimeUtc(row['end_time']);
    final pidRaw = row['parent_id'];
    final pidFlat = normalizeLinkScalar(pidRaw) ?? pidRaw;
    final pidStr = pidFlat?.toString().trim() ?? '';
    int? parentInt;
    if (pidStr.isNotEmpty && pidStr != '0') {
      parentInt = int.tryParse(pidStr);
      if (parentInt == null || parentInt == 0) {
        final ri = CategoryServiceExtension._rowInt(pidRaw);
        parentInt = ri == 0 ? null : ri;
      }
    }
    final categoryRaw = normalizeLinkScalar(
      row['category_id'] ?? row['Category_id'] ?? row['categoryId'],
    );
    final catInt = categoryIdFromRecordRow(row);
    final statusFromRow = row['status']?.toString();
    // Basta: any row with end_time is closed — never surface as running in app maps.
    final String status;
    if (end != null) {
      status = 'completed';
    } else if (statusFromRow != null && statusFromRow.isNotEmpty) {
      status = statusFromRow;
    } else {
      status = 'running';
    }
    final restPk = CategoryServiceExtension.recordsTablePk(row);
    final bizRid = (row['record_id'] ?? '').toString().trim();
    final sysObj = row[DatabaseService._nocoSystemRowIdKey];
    final int? sysInt = sysObj is int
        ? sysObj
        : int.tryParse(restPk.isNotEmpty ? restPk : '');
    // Calendar day for timeline bucket: profile wall Y-M-D ([DATA_MAP] records §8; [wall_clock]).
    String calendarDayStr;
    if (start != null) {
      calendarDayStr = _timelineDeviceLocalDayKeyFromUtc(start);
    } else {
      final stFallback = CategoryServiceExtension._parseDateTimeUtc(
        row['start_time'],
      );
      calendarDayStr = stFallback != null
          ? _timelineDeviceLocalDayKeyFromUtc(stFallback)
          : '';
    }
    final ownerUid = normalizeLinkScalar(row['user_id'])?.toString().trim();
    final srcPlanRaw =
        normalizeLinkScalar(row['source_plan_id'])?.toString() ??
        row['source_plan_id']?.toString().trim();
    final srcPlan = srcPlanRaw != null && srcPlanRaw.isNotEmpty
        ? srcPlanRaw
        : null;
    return <String, dynamic>{
      'id': restPk,
      'backendRestPathId': restPk,
      'backendNumericId': sysInt,
      'record_id': bizRid,
      // Legacy: numeric Noco system id only; business UUID is [record_id].
      'docId': int.tryParse(restPk) ?? 0,
      'title': row['title'] as String? ?? '',
      'type': row['type'] as String? ?? 'record',
      'status': status,
      'startTime': start,
      'endTime': end,
      'categoryId': catInt,
      if (categoryRaw != null) 'categoryKey': categoryRaw.toString(),
      'parentId': parentInt,
      if (ownerUid != null && ownerUid.isNotEmpty) 'user_id': ownerUid,
      if (srcPlan != null && srcPlan.isNotEmpty) 'source_plan_id': srcPlan,
      'calendarDayStr': calendarDayStr,
      'tags': row['tags'] is List ? row['tags'] : null,
      'note': mergeRecordNoteFields(row['note'], row['notes']),
      'checklist': _parseRecordChecklistField(row['checklist']),
      if (row['_expanded_category'] != null)
        '_expanded_category': row['_expanded_category'],
    };
  }

  List<Map<String, dynamic>>? _parseRecordChecklistField(dynamic raw) =>
      parseChecklistFromNoco(raw);

  Set<String> _collectRecordKeysFromCache(String recordId) {
    final id = recordId.trim();
    final out = <String>{};
    if (id.isNotEmpty) out.add(id);
    for (final row in _cachedFlatRecords) {
      final pk = CategoryServiceExtension.recordsTablePk(row);
      final biz = (row['record_id'] ?? '').toString().trim();
      if (pk == id || biz == id) {
        if (pk.isNotEmpty) out.add(pk);
        if (biz.isNotEmpty) out.add(biz);
        break;
      }
    }
    return out;
  }


  bool _optimisticRowDeletedRaw(Map<String, dynamic> row) {
    final pk = CategoryServiceExtension.recordsTablePk(row);
    final biz = (row['record_id'] ?? '').toString().trim();
    for (final k in [pk, biz]) {
      if (k.isNotEmpty && _optimisticDeletedKeys.contains(k)) return true;
    }
    return false;
  }

  /// Newest primary running row in cache (after optimistic overlays), or null.

  /// Merge [end_time] for rows the user just stopped (PATCH in flight).


  /// Warms neighbor day caches after settle — never blocks swipe (fire-and-forget).
  void prefetchTimelineDayNeighbors(DateTime center) {
    final centerKey = _timelineDateKeyFromDate(center);
    _timelinePrefetchCenterKey = centerKey;
    final dates = <DateTime>[
      center.subtract(const Duration(days: 2)),
      center.subtract(const Duration(days: 1)),
      center,
      center.add(const Duration(days: 1)),
    ];
    final keys = dates.map(_timelineDateKeyFromDate).toList();
    final pending = keys.where((k) => !_timelinePrefetchInFlight.contains(k)).toList();
    if (pending.isEmpty) return;
    _timelinePrefetchInFlight.addAll(pending);
    if (kRebuildMetricsEnabled) {
      RebuildMetrics.instance.logTimelinePrefetchStart(dates: pending);
    }
    unawaited(() async {
      final sw = Stopwatch()..start();
      final capturedCenter = centerKey;
      try {
        if (_cachedFlatRecords.isEmpty &&
            _isInitialized &&
            (currentProfileId?.isNotEmpty ?? false)) {
          await _fetchRecordsIntoCache(forceNetwork: false);
        }
        for (final key in pending) {
          if (_timelinePrefetchCenterKey != capturedCenter) return;
          final parts = key.split('-');
          if (parts.length != 3) continue;
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y == null || m == null || d == null) continue;
          final day = DateTime(y, m, d);
          final rows = peekTimelineRecordsForDate(day);
          if (kRebuildMetricsEnabled) {
            RebuildMetrics.instance.logTimelinePrefetchEnd(
              date: key,
              ms: sw.elapsedMilliseconds,
              itemCount: rows.length,
            );
          }
        }
      } catch (_) {
      } finally {
        _timelinePrefetchInFlight.removeAll(pending);
      }
    }());
  }


  Future<List<Map<String, dynamic>>> getRecordsForDate(DateTime date) =>
      _recordsForDate(date);

  Future<bool> checkOverlapWithExistingRecords(
    DateTime start,
    DateTime end, {
    String? excludeRecordId,
    bool bypassConflictCheck = false,
  }) async {
    if (bypassConflictCheck) return false;
    if (findFirstOverlappingRecordInCache(
          start,
          end,
          excludeRecordId: excludeRecordId,
        ) !=
        null) {
      return true;
    }
    final c = await findFirstOverlappingRecord(
      start,
      end,
      excludeRecordId: excludeRecordId,
    );
    return c != null;
  }


  Stream<Map<String, dynamic>?> get activeRecordStream async* {
    while (true) {
      try {
        final pend = _optimisticPendingStartRecordMap;
        if (pend != null &&
            pend['endTime'] == null &&
            CategoryServiceExtension.isRecordMapActuallyRunning(pend)) {
          final data = Map<String, dynamic>.from(pend);
          final st = data['startTime'] as DateTime?;
          final en = data['endTime'] as DateTime?;
          if (st != null) {
            data['startTimeDisplay'] = _profileWallFromUtc(st);
          }
          if (en != null) {
            data['endTimeDisplay'] = _profileWallFromUtc(en);
          }
          yield data;
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        if (_cachedFlatRecords.isEmpty &&
            _isInitialized &&
            (currentProfileId?.isNotEmpty ?? false)) {
          try {
            await _fetchRecordsIntoCache(forceNetwork: true);
          } catch (_) {}
        }
        final canonical = _canonicalPrimaryRunningFlatRow();
        if (canonical == null) {
          yield null;
        } else {
          final data = Map<String, dynamic>.from(canonical);
          if (data['endTime'] != null ||
              !CategoryServiceExtension.isRecordMapActuallyRunning(data)) {
            yield null;
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          final st = data['startTime'] as DateTime?;
          final en = data['endTime'] as DateTime?;
          if (st != null) {
            data['startTimeDisplay'] = _profileWallFromUtc(st);
          }
          if (en != null) {
            data['endTimeDisplay'] = _profileWallFromUtc(en);
          }
          yield data;
        }
      } catch (_) {
        yield null;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  bool _parentFieldEqualsRecordId(
    Map<String, dynamic> childRow,
    String parentRecordId,
  ) {
    if (parentRecordId.isEmpty) return false;
    final raw = childRow['parent_id'];
    final u =
        normalizeLinkScalar(raw)?.toString().trim() ??
        raw?.toString().trim() ??
        '';
    if (u == parentRecordId) return true;
    final pInt = int.tryParse(parentRecordId);
    if (pInt != null && CategoryServiceExtension._rowInt(raw) == pInt) {
      return true;
    }
    return false;
  }

  /// Value to store in `parent_id` for child rows — prefers Noco `record_id` (UUID) when present.
  String resolveParentLinkForChildren(String recordIdOrPk) {
    final q = recordIdOrPk.trim();
    if (q.isEmpty) return q;
    try {
      for (final row in _cachedFlatRecords) {
        final pk = CategoryServiceExtension.recordsTablePk(row);
        final biz = (row['record_id'] ?? '').toString().trim();
        if (pk == q || biz == q) {
          if (biz.isNotEmpty) return biz;
          if (pk.isNotEmpty) return pk;
          break;
        }
      }
    } catch (_) {}
    return q;
  }

  /// Subtasks still running; [parentRecordId] is Noco row PK string (UUID or int string).
  Stream<List<TimelineRecord>> runningChildrenStream(String parentRecordId) {
    return _streamFromPolling(() async {
      try {
        final pid = parentRecordId.trim();
        if (pid.isEmpty) return <TimelineRecord>[];
        final rows = await getRecords();
        final list = rows
            .where((r) => _parentFieldEqualsRecordId(r, pid))
            .where(CategoryServiceExtension._isNocoRowActiveRunning)
            .toList();
        list.sort((a, b) {
          final at = a['start_time']?.toString() ?? '';
          final bt = b['start_time']?.toString() ?? '';
          return bt.compareTo(at);
        });
        final out = <TimelineRecord>[];
        for (final row in list) {
          try {
            out.add(
              TimelineRecord.fromMap(
                _rowToRecordMap(row),
                systemId: CategoryServiceExtension.recordsTablePk(row),
                timezoneOffsetHours: _settings.timezoneOffsetHours,
              ),
            );
          } catch (e, st) {
            final rid = CategoryServiceExtension.recordsTablePk(row);
            debugPrint('[CHILD_RECORD_PARSE] $e row=$rid data=${row.keys}');
            debugPrint(st.toString());
            DatabaseService._log('CHILD_RECORD_PARSE: $e | $rid');
          }
        }
        return out;
      } catch (_) {
        return <TimelineRecord>[];
      }
    });
  }

  Stream<List<TimelineRecord>> completedChildrenStream(String parentRecordId) {
    return _streamFromPolling(() async {
      try {
        final pid = parentRecordId.trim();
        if (pid.isEmpty) return <TimelineRecord>[];
        final rows = await getRecords();
        final list = rows
            .where((r) => _parentFieldEqualsRecordId(r, pid))
            .where(
              (r) =>
                  r['end_time'] != null && r['end_time'].toString().isNotEmpty,
            )
            .toList();
        list.sort((a, b) {
          final at = a['start_time']?.toString() ?? '';
          final bt = b['start_time']?.toString() ?? '';
          return bt.compareTo(at);
        });
        final out = <TimelineRecord>[];
        for (final row in list.take(50)) {
          try {
            out.add(
              TimelineRecord.fromMap(
                _rowToRecordMap(row),
                systemId: CategoryServiceExtension.recordsTablePk(row),
                timezoneOffsetHours: _settings.timezoneOffsetHours,
              ),
            );
          } catch (e, st) {
            final rid = CategoryServiceExtension.recordsTablePk(row);
            debugPrint('[CHILD_RECORD_PARSE] $e row=$rid');
            debugPrint(st.toString());
            DatabaseService._log('CHILD_RECORD_PARSE: $e | $rid');
          }
        }
        return out;
      } catch (_) {
        return <TimelineRecord>[];
      }
    });
  }

  /// Throttled polling (default **60s**) — uses [getRecords] cache path when [DatabaseService] fetch throttle applies.
  static Stream<T> _streamFromPolling<T>(
    Future<T> Function() fetch, {
    Duration period = const Duration(seconds: 60),
  }) async* {
    yield await fetch();
    await for (final _ in Stream.periodic(period)) {
      yield await fetch();
    }
  }

  Future<void> forceRefreshFromServer() async {
    try {
      await _loadRulesFromNoco();
      await _loadSettingsFromNoco();
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
      } catch (_) {}
      _settingsController.add(_settings);
      _notifyTimelineAfterRecordCacheMutation();
    } catch (_) {}
  }

  Future<void> stopAnyRunningRecordsForDate(String dateKey) async {
    await stopAllRunningRecords();
  }

  Future<String?> startTimerWithCategory(
    String title, {
    int? categoryId,
    String? dateKey,
    String? sourcePlanPocketRecordId,
    String? sourcePlanBusinessId,
  }) async {
    final now = DatabaseService.getPlanetaryNow();
    final trimmed = dateKey?.trim() ?? '';
    final key = trimmed.length >= 10
        ? trimmed.substring(0, 10)
        : getTimelineDeviceLocalTodayDateKey();
    final resolvedCategory = resolveCurrentPlanCategoryForRecordStart(
      sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      planBusinessId: sourcePlanBusinessId,
      uiCategoryId: categoryId,
    );
    return writeRecord(
      key,
      title,
      categoryId: resolvedCategory,
      explicitStartTime: now,
      sourcePlanPocketRecordId: sourcePlanPocketRecordId,
    );
  }

  /// One-tap start from a backlog row ([PlanningTask.startTime] may be null). Uses “now” on the server record.
  Future<String?> startRecordFromPlanTask(PlanningTask plan) {
    final planPb = DatabaseService.pocketRelationIdOrNull(plan.pocketRecordId);
    return startTimerWithCategory(
      plan.title,
      categoryId: plan.categoryId,
      dateKey: plan.dateKey,
      sourcePlanPocketRecordId: planPb,
      sourcePlanBusinessId: plan.planRowIdForBackend,
    );
  }

  Future<String?> startTimer(String title) async {
    return startTimerWithCategory(title);
  }
}
