part of 'database_service.dart';

// Record domain extracted from database_service.dart (V5.3).
// Contains: record cache, realtime subscription, fetchRecords,
// record CRUD, optimistic UI, streams, timeline helpers.

bool _recordMutationOutboxFlushInFlight = false;

/// P0U.4 — generation token; bump to cancel in-flight adjacent VM warmup.
int _timelineAdjVmWarmGeneration = 0;

/// Records per yield chunk during adjacent row-VM warmup.
const int _kTimelineAdjVmWarmChunkSize = 4;

/// Skip warmup when a single adjacent day exceeds this (safety cap).
const int _kTimelineAdjVmWarmMaxRecords = 120;

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

  Map<int, Map<String, dynamic>> _snapshotRunningRowsForHighlanderRollback() {
    final m = <int, Map<String, dynamic>>{};
    for (var i = 0; i < _cachedFlatRecords.length; i++) {
      final r = _cachedFlatRecords[i];
      final st = (r['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'running') {
        m[i] = Map<String, dynamic>.from(r);
      }
    }
    return m;
  }

  void _restoreHighlanderRollbackToken(_HighlanderRollbackToken? token) {
    if (token == null) return;
    if (token.appendedPendingRow && _cachedFlatRecords.isNotEmpty) {
      _cachedFlatRecords.removeLast();
    }
    for (final e in token.runningSnapshotsByIndex.entries) {
      final i = e.key;
      if (i < _cachedFlatRecords.length) {
        _cachedFlatRecords[i] = Map<String, dynamic>.from(e.value);
      }
    }
  }

  /// Verification: at most one `running` row should exist after local Highlander apply.
  void _printAtomicCheckRunningCount() {}

  /// **Highlander** — local-only phase: every `status == running` row is forced to `stopped`
  /// with [end_time]; then the new primary running row is appended. Single notifier happens
  /// in the surrounding [_runBatchedRecordCacheTimelineNotify] after this returns.
  ///
  /// **startAtomicTaskSequence** (steps 1–3): memory stop-all-running → append pending POST row.
  void _startAtomicTaskSequenceApplyLocalPrimary({
    required Map<String, dynamic> createBody,
    required List<Map<String, String>> patchTargetsOut,
  }) {
    patchTargetsOut.clear();
    final nowIso = DatabaseService.getPlanetaryNow().toUtc().toIso8601String();
    final next = <Map<String, dynamic>>[];
    for (final row in _cachedFlatRecords) {
      final copy = Map<String, dynamic>.from(row);
      final st = (copy['status'] ?? '').toString().trim().toLowerCase();
      if (st == 'running') {
        final pk = CategoryServiceExtension.recordsTablePk(copy);
        final biz = (copy['record_id'] ?? '').toString().trim();
        if (pk.isNotEmpty) {
          patchTargetsOut.add(<String, String>{
            'rid': pk,
            'oq': biz.isNotEmpty ? biz : pk,
          });
        }
        copy['status'] = 'stopped';
        copy['end_time'] = nowIso;
      }
      next.add(copy);
    }
    final pending = Map<String, dynamic>.from(createBody);
    final bizId = (pending['record_id'] ?? '').toString().trim();
    if (bizId.isEmpty) {
      DatabaseService._log(
        'HIGHLANDER: createBody missing record_id — aborting local append',
      );
      _cachedFlatRecords = next;
      return;
    }
    pending['id'] = bizId;
    pending['_pb_record_id'] = '';
    pending['status'] = 'running';
    pending['end_time'] = null;
    pending['_highlanderPendingPost'] = true;
    next.add(pending);
    _cachedFlatRecords = next;
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

  void _onPbRecordsSubscriptionEvent(RecordSubscriptionEvent e) {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    final action = e.action.toLowerCase().trim();
    if (action == 'delete') {
      final id = e.record?.id.trim() ?? '';
      if (id.isNotEmpty) {
        _removeCachedFlatRecordByPk(id);
      }
      return;
    }
    final rec = e.record;
    if (rec == null) return;
    try {
      _upsertFlatRecordFromPbModel(
        rec,
        preserveExpand: true,
        suppressTimelineNotify: false,
        logSuccessLine: false,
      );
    } catch (_) {}
  }

  Future<void> _cancelRecordsRealtimeSubscription() async {
    final unsub = _recordsRealtimeUnsubscribe;
    _recordsRealtimeUnsubscribe = null;
    if (unsub != null) {
      try {
        await unsub();
      } catch (_) {}
    }
    try {
      await _pb.collection(PbCollections.records).unsubscribe();
    } catch (_) {}
  }

  Future<void> _startRecordsRealtimeSubscription() async {
    final existing = _recordsRealtimeSubscribeFuture;
    if (existing != null) {
      return existing;
    }
    final f = _startRecordsRealtimeSubscriptionBody();
    _recordsRealtimeSubscribeFuture = f;
    try {
      await f;
    } finally {
      _recordsRealtimeSubscribeFuture = null;
    }
  }

  Future<void> _startRecordsRealtimeSubscriptionBody() async {
    await _cancelRecordsRealtimeSubscription();
    if (!_hasAuthenticatedUserId) return;
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) {
        _logRecordsRealtimeSubscribeQuiet('pb_http_backoff_active');
        _scheduleRecordsRealtimeReconnectAfterFailure();
        return;
      }
      final filter = _pocketBaseOwnerFilterClauseForRecords();
      if (filter == null || filter.isEmpty) return;
      Future<void> Function()? unsub;
      try {
        unsub = await _pb
            .collection(PbCollections.records)
            .subscribe(
              '*',
              _onPbRecordsSubscriptionEvent,
              filter: filter,
              expand: '$kPbRecordCategoryExpand,$kPbRecordTagsExpand',
            );
      } on ClientException catch (_) {
        unsub = await _pb
            .collection(PbCollections.records)
            .subscribe(
              '*',
              _onPbRecordsSubscriptionEvent,
              filter: filter,
              expand: kPbRecordCategoryExpand,
            );
      } catch (_) {
        unsub = await _pb
            .collection(PbCollections.records)
            .subscribe('*', _onPbRecordsSubscriptionEvent, filter: filter);
      }
      _recordsRealtimeUnsubscribe = unsub;
      _recordsRealtimeFailureStreak = 0;
      _recordsRealtimeReconnectTimer?.cancel();
      _recordsRealtimeReconnectTimer = null;
    } catch (e) {
      _logRecordsRealtimeSubscribeQuiet(e);
      _scheduleRecordsRealtimeReconnectAfterFailure();
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
      if (kPerfDiagnosisEnabled) {
        PerfDiag.instance.logPbTimelineQuery(
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
        P0NPerfDiag.timelineCacheRefreshMerge(
          before: _cachedFlatRecords.length,
          after: 0,
          keptLocal: true,
        );
        P0OWarmDiag.timelineRefreshMerge(
          before: _cachedFlatRecords.length,
          after: 0,
          keptLocal: true,
        );
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

  void _pruneRecord404DeadletterUsingCache() {
    if (_recordRestDefinitive404Keys.isEmpty) return;
    final alive = <String>{};
    for (final r in _cachedFlatRecords) {
      final pk = CategoryServiceExtension.recordsTablePk(r).trim();
      final biz = (r['record_id'] ?? '').toString().trim();
      if (pk.isNotEmpty) alive.add(pk);
      if (biz.isNotEmpty) alive.add(biz);
    }
    final before = _recordRestDefinitive404Keys.length;
    _recordRestDefinitive404Keys.removeWhere((k) => alive.contains(k));
    if (before != _recordRestDefinitive404Keys.length) {
      DatabaseService._log(
        'RECORDS_404_DEADLETTER: dropped key(s) that match live server rows again (before=$before after=${_recordRestDefinitive404Keys.length})',
      );
    }
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
  Map<String, dynamic>? _canonicalPrimaryRunningFlatRow() {
    final pend = _optimisticPendingStartRecordMap;
    if (pend != null &&
        pend['endTime'] == null &&
        CategoryServiceExtension.isRecordMapActuallyRunning(pend)) {
      return Map<String, dynamic>.from(pend);
    }
    Map<String, dynamic>? winner;
    DateTime? bestStart;
    for (final r in _cachedFlatRecords) {
      if (_rowHasNonEmptyParent(r['parent_id'])) continue;
      final merged = _mergeOptimisticIntoRecordMap(_rowToRecordMap(r));
      if (!CategoryServiceExtension.isRecordMapActuallyRunning(merged)) {
        continue;
      }
      final st = CategoryServiceExtension.startTimeFromRecord(merged);
      if (winner == null ||
          (st != null && (bestStart == null || st.isAfter(bestStart)))) {
        winner = merged;
        bestStart = st;
      }
    }
    return winner;
  }

  String? _businessIdFromCanonicalRunningRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final biz = (row['record_id'] ?? '').toString().trim();
    if (biz.isNotEmpty) return biz;
    final sys = (row['id'] ?? '').toString().trim();
    return sys.isEmpty ? null : sys;
  }

  /// One scan of [_cachedFlatRecords] for the newest primary running row id.
  String? resolveCanonicalPrimaryRunningBusinessId() {
    if (!_canonicalRunningBusinessIdCacheDirty) {
      return _cachedCanonicalRunningBusinessId;
    }
    _syncCanonicalRunningBusinessIdCache('resolve');
    return _cachedCanonicalRunningBusinessId;
  }

  String? get canonicalPrimaryRunningBusinessId =>
      resolveCanonicalPrimaryRunningBusinessId();

  void _resetCanonicalRunningBusinessIdCache({String reason = 'reset'}) {
    _canonicalRunningBusinessIdCacheDirty = true;
    _cachedCanonicalRunningBusinessId = null;
  }

  /// Recompute running business id once (outside per-row VM loop).
  void _syncCanonicalRunningBusinessIdCache(String reason) {
    _cachedCanonicalRunningBusinessId =
        _businessIdFromCanonicalRunningRow(_canonicalPrimaryRunningFlatRow());
    _canonicalRunningBusinessIdCacheDirty = false;
  }

  /// Sacred singleton: if multiple primaries are open, keep newest and stop older rows.
  Future<void> _reconcileDuplicatePrimaryRunningRecords() async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) return;
    final primaries = <Map<String, dynamic>>[];
    for (final row in _cachedFlatRecords) {
      if (_rowHasNonEmptyParent(row['parent_id'])) continue;
      if (!CategoryServiceExtension._isNocoRowActiveRunning(row)) continue;
      primaries.add(row);
    }
    if (primaries.length <= 1) return;

    primaries.sort((a, b) {
      final ast = CategoryServiceExtension._parseDateTimeUtc(a['start_time']);
      final bst = CategoryServiceExtension._parseDateTimeUtc(b['start_time']);
      if (ast == null && bst == null) return 0;
      if (ast == null) return 1;
      if (bst == null) return -1;
      return bst.compareTo(ast);
    });

    final now = DatabaseService.getPlanetaryNow();
    for (var i = 1; i < primaries.length; i++) {
      final loser = primaries[i];
      final pk = CategoryServiceExtension.recordsTablePk(loser);
      final biz = (loser['record_id'] ?? '').toString().trim();
      for (final k in [pk, biz]) {
        if (k.isNotEmpty) {
          _optimisticEndByKey[k] = _OptimisticEndPatch(now);
        }
      }
      if (pk.isNotEmpty) {
        unawaited(stopRecordByDocId(pk));
      }
    }
    _notifyTimelineAfterRecordCacheMutation();
  }

  /// Merge [end_time] for rows the user just stopped (PATCH in flight).
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
    final rid = clientRecordId.trim();
    return <String, dynamic>{
      'id': rid,
      'backendRestPathId': rid,
      'record_id': rid,
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
    if (kPerfDiagnosisEnabled) {
      PerfDiag.instance.logTimelineHistoryScan(
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
          P0DateNavDiag.crashGuard(
            'timeline_scan_skip record_id=$rid day=$targetDayStr $e',
          );
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
    P0NPerfDiag.timelineCacheRestore(
      flatRecords: _cachedFlatRecords.length,
      ms: sw.elapsedMilliseconds,
      source: 'prefs',
    );
    if (_cachedFlatRecords.isEmpty) return;
    final indexSw = Stopwatch()..start();
    if (_cachedFlatRecords.length <= _kTimelineIndexMaxSyncRecords) {
      _buildTimelineDayIndexImpl();
    } else {
      _markTimelineDayIndexDirty();
    }
    indexSw.stop();
    P0NPerfDiag.timelineDayIndexReady(
      days: _timelineRecordsDayIndex.length,
      records: _cachedFlatRecords.length,
      ms: indexSw.elapsedMilliseconds,
    );
    P0OWarmDiag.timelineIndexReady(
      days: _timelineRecordsDayIndex.length,
      records: _cachedFlatRecords.length,
      ms: indexSw.elapsedMilliseconds,
    );
    _syncCanonicalRunningBusinessIdCache('bootRestore');
    if (criticalOnly) return;
    ensureTimelineWarmWindow(getTimelineDeviceLocalToday());
    prebuildTimelineCriticalBodiesSync(getTimelineDeviceLocalToday());
    P0RPrebuildDiag.diskRestore(
      screen: 'Timeline',
      snapshots: _timelineWarm.cachedDayCount,
      ms: sw.elapsedMilliseconds + indexSw.elapsedMilliseconds,
    );
    P0OWarmDiag.bootTimelineCache(
      flatRecords: _cachedFlatRecords.length,
      days: _timelineWarmWindow?.cachedDayCount ?? 0,
      ms: sw.elapsedMilliseconds + indexSw.elapsedMilliseconds,
    );
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

  void _logTimelineWarmMemory() {
    var records = 0;
    var approxKb = 0;
    for (final s in _timelineWarm.snapshots) {
      records += s.records.length;
      approxKb += s.records.length * 512 ~/ 1024;
    }
    P0OWarmDiag.memory(
      screen: 'Timeline',
      cachedDays: _timelineWarm.cachedDayCount,
      items: records,
      approxKb: approxKb,
    );
  }

  void ensureTimelineWarmWindow(DateTime center) {
    final sw = Stopwatch()..start();
    _timelineWarm.ensureInitialWindow(center, _buildTimelineDaySnapshot);
    sw.stop();
    P0OWarmDiag.timelineWindow(
      center: _timelineDateKeyFromDate(center),
      from: _timelineWarm.windowFrom != null
          ? _timelineDateKeyFromDate(_timelineWarm.windowFrom!)
          : '—',
      to: _timelineWarm.windowTo != null
          ? _timelineDateKeyFromDate(_timelineWarm.windowTo!)
          : '—',
      cachedDays: _timelineWarm.cachedDayCount,
    );
    _logTimelineWarmMemory();
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
    final window = MountedDayWindow(center: center);
    for (final d in window.dates) {
      timelineWarmSnapshotForDate(d);
      timelineBodyEntryForDate(d, allowEmergencyBuild: true);
      buildTimelineDayRenderSnapshot(d);
    }
  }

  void scheduleTimelineMountedWindowBootBackground(DateTime center) {
    unawaited(Future.microtask(() {
      prepareTimelineMountedWindowBoot(center);
      P0tDiag.memory(
        screen: 'Timeline',
        mountedBodies: MountedDayWindow(center: center).length,
        renderSnapshots: P0tRenderSnapshotCache.instance.timelineCount,
        approxKb: P0tRenderSnapshotCache.instance.timelineCount * 40,
      );
    }));
  }

  TimelineDayRenderSnapshot? timelineRenderSnapshotForDate(DateTime wallDay) {
    return P0tRenderSnapshotCache.instance.peekTimeline(p0tDateKey(wallDay));
  }

  bool isTimelineDateFullyReady(DateTime wallDay) {
    final key = p0tDateKey(wallDay);
    final snap = P0tRenderSnapshotCache.instance.peekTimeline(key);
    if (snap != null && snap.ready) {
      P0tDiag.readyCheck(
        screen: 'Timeline',
        date: key,
        ready: true,
        cards: snap.cards.length,
      );
      return true;
    }
    final missing = snap?.missing ?? 'records';
    P0tDiag.readyCheck(
      screen: 'Timeline',
      date: key,
      ready: false,
      missing: missing,
    );
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
    P0tDiag.criticalReadyStart(
      screen: 'Timeline',
      dates: 'yesterday,today,tomorrow',
    );
    final sw = Stopwatch()..start();
    var ready = 0;
    for (final offset in [-1, 0, 1]) {
      final day = DateTime(center.year, center.month, center.day)
          .add(Duration(days: offset));
      buildTimelineDayRenderSnapshot(day);
      if (isTimelineDateFullyReady(day)) ready++;
    }
    sw.stop();
    P0tDiag.criticalReadyDone(
      screen: 'Timeline',
      ready: ready,
      total: 3,
      ms: sw.elapsedMilliseconds,
    );
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
      P0SMountDiag.diskRestore(
        screen: 'Timeline',
        snapshots: count,
        ms: sw.elapsedMilliseconds,
      );
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
        P0SMountDiag.diskSave(
          screen: 'Timeline',
          snapshots: out.length,
          ms: sw.elapsedMilliseconds,
        );
      } catch (_) {}
    }());
  }

  void extendTimelineWarmWindowIfNeeded(DateTime center) {
    final sw = Stopwatch()..start();
    final beforeCount = _timelineWarm.cachedDayCount;
    final direction = _timelineWarm.extendIfNeeded(center, _buildTimelineDaySnapshot);
    sw.stop();
    if (direction != null && _timelineWarm.cachedDayCount >= beforeCount) {
      P0OWarmDiag.timelineExtend(
        direction: direction,
        from: _timelineWarm.windowFrom != null
            ? _timelineDateKeyFromDate(_timelineWarm.windowFrom!)
            : '—',
        to: _timelineWarm.windowTo != null
            ? _timelineDateKeyFromDate(_timelineWarm.windowTo!)
            : '—',
        ms: sw.elapsedMilliseconds,
      );
      _logTimelineWarmMemory();
    }
  }

  /// Sync warm snapshot for one day; builds emergency snapshot if missing.
  TimelineDaySnapshot timelineWarmSnapshotForDate(DateTime date) {
    final lookupSw = Stopwatch()..start();
    final key = _timelineDateKeyFromDate(date);
    final sig = _cachedFlatRecords.length;
    final existing = _timelineWarm.peek(key);
    if (existing != null && existing.cacheSignature == sig) {
      lookupSw.stop();
      P0OWarmDiag.timelineSnapshot(
        date: key,
        state: existing.knownEmpty ? 'empty' : 'hit',
        count: existing.records.length,
        ms: lookupSw.elapsedMilliseconds,
      );
      return existing;
    }
    final built = _buildTimelineDaySnapshot(date);
    _timelineWarm.put(key, built);
    lookupSw.stop();
    P0OWarmDiag.timelineSnapshot(
      date: key,
      state: existing == null ? 'miss' : 'refresh',
      count: built.records.length,
      ms: lookupSw.elapsedMilliseconds,
    );
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
      P0RPrebuildDiag.bodyCacheHit(
        screen: 'Timeline',
        date: key,
        source: existing.source,
      );
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
    P0RPrebuildDiag.bodyCacheMiss(
      screen: 'Timeline',
      date: key,
      insideWarmRange: inside,
      reason: inside ? 'notPrebuiltYet' : 'outsideWindow',
    );
    final sw = Stopwatch()..start();
    final built = _buildTimelineBodyEntry(day, source: 'emergencySyncBuild');
    sw.stop();
    cache.put(key, built);
    P0RPrebuildDiag.emergencySyncBuild(
      screen: 'Timeline',
      date: key,
      ms: sw.elapsedMilliseconds,
    );
    return built;
  }

  void prebuildTimelineCriticalBodiesSync(DateTime center) {
    final cache = timelineDayBodyCache;
    final centerKey = _timelineDateKeyFromDate(center);
    cache.setCenter(centerKey);
    P0RPrebuildDiag.criticalStart(
      screen: 'Timeline',
      dates: 'yesterday,today,tomorrow',
    );
    final sw = Stopwatch()..start();
    for (final offset in [-1, 0, 1]) {
      final day = DateTime(center.year, center.month, center.day)
          .add(Duration(days: offset));
      final entry = _buildTimelineBodyEntry(day, source: 'criticalPrebuild');
      cache.put(entry.dateKey, entry);
      P0RPrebuildDiag.prebuildBody(
        screen: 'Timeline',
        date: entry.dateKey,
        priority: offset,
        ms: 0,
      );
    }
    sw.stop();
    P0RPrebuildDiag.criticalDone(
      screen: 'Timeline',
      count: 3,
      totalMs: sw.elapsedMilliseconds,
    );
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
      P0RPrebuildDiag.bootAdjacentReady(
        screen: 'Timeline',
        date: label,
        dataReady: cache.isDataReady(key) ||
            timelineWarmSnapshotForDate(day).records.isNotEmpty ||
            timelineWarmSnapshotForDate(day).knownEmpty,
        bodyReady: cache.isBodyReady(key),
      );
    }
  }

  void scheduleTimelineWindowBodyPrebuild(DateTime center) {
    if (_timelineWindowBodyPrebuildInFlight) return;
    _timelineWindowBodyPrebuildInFlight = true;
    final gen = ++_timelineBodyPrebuildGeneration;
    final centerKey = _timelineDateKeyFromDate(center);
    timelineDayBodyCache.setCenter(centerKey);
    unawaited(() async {
      P0RPrebuildDiag.windowStart(
        screen: 'Timeline',
        center: centerKey,
        radius: RenderedDayBodyConstants.radius,
      );
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
        P0RPrebuildDiag.prebuildBody(
          screen: 'Timeline',
          date: key,
          priority: offset,
          ms: bodySw.elapsedMilliseconds,
        );
        if (ready % 4 == 0 || ready == total) {
          P0RPrebuildDiag.windowProgress(
            screen: 'Timeline',
            ready: ready,
            total: total,
          );
        }
      }
      sw.stop();
      P0RPrebuildDiag.windowDone(
        screen: 'Timeline',
        ready: ready,
        totalMs: sw.elapsedMilliseconds,
      );
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
        if (kPerfDiagnosisEnabled) {
          PerfDiag.instance.logTimelineCacheHit(
            date: targetDayStr,
            itemCount: cachedView.length,
          );
        }
        return List<Map<String, dynamic>>.from(cachedView);
      }
    }
    if (kPerfDiagnosisEnabled) {
      PerfDiag.instance.logTimelineCacheMiss(date: targetDayStr);
    }
    final grouped = PerfDiag.instance.perfBlock(
      'Timeline.groupRecords',
      () => _timelineDayIndexRowsForKey(targetDayStr),
      meta: {'date': targetDayStr},
    );
    final rendered = PerfDiag.instance.perfBlock(
      'Timeline.renderModel',
      () => _withDisplayTimes(grouped),
      meta: {'date': targetDayStr, 'items': grouped.length},
    );
    _timelineDayViewCache[targetDayStr] = List<Map<String, dynamic>>.from(
      rendered,
    );
    lookupSw.stop();
    final state = rendered.isEmpty ? 'empty' : 'hit';
    P0NPerfDiag.timelineDayLookup(
      date: targetDayStr,
      state: state,
      count: rendered.length,
      ms: lookupSw.elapsedMilliseconds,
    );
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
      P0DateNavDiag.crashGuard('timeline_vm_skip record_id=$rid $e');
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
    if (kPerfDiagnosisEnabled) {
      PerfDiag.instance.logTimelineViewCacheRebuild(
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
    P0uDiag.logAdjVmWarmDisabledIfNeeded();
    if (!kTimelineAdjacentRowVmWarmup || kUseP0tMountedStrip) return;
    final captured = DateTime(center.year, center.month, center.day);
    final gen = ++_timelineAdjVmWarmGeneration;
    P0uStartupDiag.scheduleAfterFirstFrame('timelineAdjVmWarm', () async {
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
    P0uDiag.logAdjVmWarmDisabledIfNeeded();
    if (!kTimelineAdjacentRowVmWarmup || kUseP0tMountedStrip) return;
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
      if (kPerfDiagnosisEnabled) {
        PerfDiag.instance.logTimelineViewCacheHit(
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
    if (kPerfDiagnosisEnabled && reason != null) {
      PerfDiag.instance.logTimelineViewCacheInvalidate(
        date: dateKey,
        reason: reason,
      );
    }
  }

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
    if (kPerfDiagnosisEnabled) {
      PerfDiag.instance.logTimelinePrefetchStart(dates: pending);
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
          if (kPerfDiagnosisEnabled) {
            PerfDiag.instance.logTimelinePrefetchEnd(
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

  Future<List<Map<String, dynamic>>> getRecordsForDate(DateTime date) =>
      _recordsForDate(date);

  Future<bool> checkOverlapWithExistingRecords(
    DateTime start,
    DateTime end, {
    String? excludeRecordId,
    bool bypassConflictCheck = false,
  }) async {
    if (bypassConflictCheck) return false;
    final c = await findFirstOverlappingRecord(
      start,
      end,
      excludeRecordId: excludeRecordId,
    );
    return c != null;
  }

  /// Keys that identify the same record row as [excludeRecordId] (UUID, REST id, system id).
  Set<String> _excludeOverlapIdentityKeys(String excludeRecordId) {
    final q = excludeRecordId.trim();
    final out = <String>{};
    if (q.isEmpty) return out;
    out.add(q);
    try {
      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        final data = _rowToRecordMap(row);
        final biz = (data['record_id'] ?? '').toString().trim();
        final pk = (data['id'] ?? '').toString().trim();
        final path = (data['backendRestPathId'] ?? data['nocoRestPathId'] ?? '')
            .toString()
            .trim();
        final sys =
            (data['backendNumericId'] ?? data['nocoSystemId'])
                ?.toString()
                .trim() ??
            '';
        final matches =
            q == biz ||
            q == pk ||
            (path.isNotEmpty && q == path) ||
            (sys.isNotEmpty && q == sys);
        if (matches) {
          if (biz.isNotEmpty) out.add(biz);
          if (pk.isNotEmpty) out.add(pk);
          if (path.isNotEmpty) out.add(path);
          if (sys.isNotEmpty) out.add(sys);
        }
      }
    } catch (_) {}
    return out.where((s) => s.isNotEmpty).toSet();
  }

  bool _recordMapOverlapsExcludeKeys(
    Map<String, dynamic> data,
    Set<String> excludeKeys,
  ) {
    if (excludeKeys.isEmpty) return false;
    final candidates = <String>{
      (data['record_id'] ?? '').toString().trim(),
      (data['id'] ?? '').toString().trim(),
      (data['backendRestPathId'] ?? data['nocoRestPathId'] ?? '')
          .toString()
          .trim(),
      if (data['backendNumericId'] != null)
        data['backendNumericId'].toString().trim(),
      if (data['nocoSystemId'] != null) data['nocoSystemId'].toString().trim(),
      if (data['docId'] != null && data['docId'] != 0)
        data['docId'].toString().trim(),
    }.where((s) => s.isNotEmpty).toSet();
    for (final c in candidates) {
      if (excludeKeys.contains(c)) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> findFirstOverlappingRecord(
    DateTime start,
    DateTime end, {
    String? excludeRecordId,
  }) async {
    try {
      final rows = await getRecords();
      final now = DatabaseService.getPlanetaryNow();
      final excludeKeys =
          excludeRecordId == null || excludeRecordId.trim().isEmpty
          ? <String>{}
          : _excludeOverlapIdentityKeys(excludeRecordId);
      for (final row in rows) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        final data = _rowToRecordMap(row);
        if (_recordMapOverlapsExcludeKeys(data, excludeKeys)) continue;
        final otherStart = CategoryServiceExtension.startTimeFromRecord(data);
        if (otherStart == null) continue;
        final otherEnd =
            CategoryServiceExtension.endTimeFromRecord(data) ?? now;
        if (_rangesOverlap(start, end, otherStart, otherEnd)) return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _rangesOverlap(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
    final a = _truncateToMinuteUtc(a1);
    final b = _truncateToMinuteUtc(a2);
    final c = _truncateToMinuteUtc(b1);
    final d = _truncateToMinuteUtc(b2);
    return a.isBefore(d) && c.isBefore(b);
  }

  static DateTime _truncateToMinuteUtc(DateTime d) {
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute);
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
    if (pInt != null && CategoryServiceExtension._rowInt(raw) == pInt)
      return true;
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

  Future<bool> stopAllRunningRecords() async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    try {
      final nowIso = DatabaseService.getPlanetaryNow()
          .toUtc()
          .toIso8601String();
      final byPk = <String, Map<String, dynamic>>{};
      var serverOk = false;

      try {
        final serverRows = await _fetchRunningRecordsFromNoco();
        serverOk = true;
        for (final r in serverRows) {
          if (_rowHasNonEmptyParent(r['parent_id'])) continue;
          if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r)) continue;
          if (!_rowStartWallDayIsProjectedToday(r)) continue;
          final id = CategoryServiceExtension.recordsTablePk(r);
          if (id.isEmpty) continue;
          byPk[id] = r;
        }
        final todayOnly = byPk.length;
        _mergeSacredStaleOpenCandidates(serverRows, byPk);
        if (serverRows.isNotEmpty) {
          DatabaseService._log(
            'SACRED_LAW: server running=${serverRows.length} -> today=$todayOnly total_stop_candidates=${byPk.length}',
          );
        }
      } catch (e) {
        DatabaseService._log(
          'SACRED_LAW: server running-query failed ($e); using cache merge',
        );
      }

      if (!serverOk) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
          final local = _cachedFlatRecords;
          for (final r in local) {
            if (_rowHasNonEmptyParent(r['parent_id'])) continue;
            if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r))
              continue;
            if (!_rowStartWallDayIsProjectedToday(r)) continue;
            final id = CategoryServiceExtension.recordsTablePk(r);
            if (id.isEmpty) continue;
            byPk[id] = r;
          }
          _mergeSacredStaleOpenCandidates(local, byPk);
        } catch (e) {
          DatabaseService._log('SACRED_LAW: cache merge failed ($e)');
        }
      }

      DatabaseService._log(
        'SACRED_LAW: PocketBase per-row stop ${byPk.length} record(s)',
      );
      for (final id in byPk.keys) {
        final row = byPk[id];
        if (row == null) continue;
        DatabaseService._log('PATCH_ID_TRACE: stopAllRunningRecords pb id=$id');
        final fields = _nocoFieldsForPatch(<String, dynamic>{
          'end_time': nowIso,
          'status': 'stopped',
        });
        final biz = (row['record_id'] ?? '').toString().trim();
        final originalOid = biz.isNotEmpty ? biz : id;
        final code = await _patchRecordsRowWith404Recovery(
          originalQueryId: originalOid,
          restId: id,
          fields: fields,
        );
        if (code == 404) {
          _purgeGhostRecordById(id);
          continue;
        }
        if (code < 200 || code >= 300) {
          DatabaseService._log(
            'STOP_SWITCH_ABORT: failed to stop record id=$id status=$code',
          );
          return false;
        }
      }
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (_) {
      return false;
    }
  }

  String get _todayKey => getTimelineDeviceLocalTodayDateKey();

  Future<bool> writeCompletedRecord(
    String title,
    DateTime startTime,
    DateTime endTime, {
    int? categoryId,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    if (_writeRecordMutationInFlight) return false;
    _writeRecordMutationInFlight = true;
    try {
      final parsed = getCleanTitleAndTags(title);
      var cid = categoryId ?? defaultCategoryId;
      cid = identifyCategory(parsed.title)?.id ?? cid;
      cid = _resolveRecordCategoryIdWithSmartLink(parsed.title, cid);
      cid = _resolveColdStartRecordCategoryId(cid);
      if (!_categoryIdResolvableForPbRecordPost(cid)) {
        DatabaseService._log('writeCompletedRecord: no resolvable category_id');
        AppSnack.failed();
        return false;
      }
      final newId = await _createRecordPb(<String, dynamic>{
        'user_id': _pidForPbFilter,
        'record_id': DatabaseService._newClientRecordUuid(),
        'status': 'completed',
        'title': parsed.title,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'category_id': _recordCategoryBusinessPkForApi(cid),
        'type': 'record',
        'parent_id': null,
        'checklist': <Map<String, dynamic>>[],
        if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
      });
      if (newId == null) {
        DatabaseService._log('writeCompletedRecord PocketBase create failed');
        return false;
      }
      await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (e, st) {
      DatabaseService._log('writeCompletedRecord failed: $e');
      DatabaseService._log(st);
      return false;
    } finally {
      _writeRecordMutationInFlight = false;
    }
  }

  Future<void> _enqueueHighlanderStartMutation(
    Map<String, dynamic> runningFields, {
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized =
          jsonDecode(jsonEncode(runningFields)) as Map<String, dynamic>;
      final businessId = (normalized['record_id'] ?? '').toString().trim();
      if (businessId.isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newHighlanderStartItem(
          businessId: businessId,
          runningFields: normalized,
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE highlander: $e');
    }
  }

  Future<void> _enqueueStopPatchMutation({
    required String originalInput,
    required String pocketBaseId,
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final businessId = _outboxBusinessIdForRecord(originalInput);
      if (businessId.isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newStopPatchItem(
          businessId: businessId,
          pocketBaseId: pocketBaseId.trim(),
          originalQueryId: originalInput.trim(),
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE stop: $e');
    }
  }

  String _outboxBusinessIdForRecord(String originalInput) {
    final id = originalInput.trim();
    if (id.isEmpty) return id;
    for (final row in _cachedFlatRecords) {
      final pk = CategoryServiceExtension.recordsTablePk(row);
      final biz = (row['record_id'] ?? '').toString().trim();
      if (pk == id || biz == id) {
        if (biz.isNotEmpty) return biz;
        return id;
      }
    }
    return id;
  }

  TimelineRecord? _timelineRecordFromCacheInput(String originalInput) {
    final idx = _indexOfCachedRecordRow(originalInput, originalInput);
    if (idx < 0) return null;
    final row = _cachedFlatRecords[idx];
    final sysId = CategoryServiceExtension.recordsTablePk(row);
    return TimelineRecord.fromMap(
      _rowToRecordMap(row),
      systemId: sysId.isNotEmpty ? sysId : originalInput,
      timezoneOffsetHours: _settings.timezoneOffsetHours,
    );
  }

  Future<void> _enqueueRecordUpdateMutation({
    required String originalInput,
    required String businessId,
    required Map<String, dynamic> patchFields,
    String? pocketBaseId,
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final normalized =
          jsonDecode(jsonEncode(patchFields)) as Map<String, dynamic>;
      if (businessId.trim().isEmpty || normalized.isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newRecordUpdateItem(
          businessId: businessId.trim(),
          patchFields: normalized,
          pocketBaseId: pocketBaseId?.trim(),
          originalQueryId: originalInput.trim(),
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE update: $e');
    }
  }

  Future<void> _enqueueRecordDeleteMutation({
    required String originalInput,
    required String businessId,
    String? pocketBaseId,
    Object? error,
    String syncStatus = RecordMutationOutbox.syncStatusPending,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (businessId.trim().isEmpty) return;
      await RecordMutationOutbox.enqueue(
        prefs,
        RecordMutationOutbox.newRecordDeleteItem(
          businessId: businessId.trim(),
          pocketBaseId: pocketBaseId?.trim(),
          originalQueryId: originalInput.trim(),
          error: error,
          syncStatus: syncStatus,
        ),
      );
      unawaited(offlineSync.refreshPendingCount());
    } catch (e) {
      DatabaseService._log('RECORD_OUTBOX_ENQUEUE delete: $e');
    }
  }

  Future<String?> _resolveRecordPbIdForOutboxReplay({
    required String businessId,
    String? pocketBaseId,
  }) async {
    final stored = pocketBaseId?.trim();
    if (stored != null &&
        stored.isNotEmpty &&
        DatabaseService._isLikelyPocketBaseRowId(stored)) {
      return stored;
    }
    final cached = _tryResolveRecordIdFromCacheOnly(businessId);
    if (cached != null &&
        cached.isNotEmpty &&
        DatabaseService._isLikelyPocketBaseRowId(cached)) {
      return cached;
    }
    try {
      final resolved = await _resolveRecordIdForStopOrDelete(businessId);
      if (DatabaseService._isLikelyPocketBaseRowId(resolved)) return resolved;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> _buildRecordPatchUpdates({
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    String? tags,
    List<Map<String, dynamic>>? checklist,
    bool syncSourcePlan = false,
    bool clearSourcePlan = false,
    String? sourcePlanPocketRecordId,
  }) async {
    var categoryForPatch = categoryId;
    var shouldPatchCategory = categoryId != null;
    if (syncSourcePlan && !clearSourcePlan) {
      final sp0 = DatabaseService.pocketRelationIdOrNull(
        sourcePlanPocketRecordId,
      );
      if (sp0 != null) {
        final pc = await _resolveCategoryIdFromSourcePlanPbId(sp0);
        if (_planLocalCategoryIdIsConcrete(pc)) {
          categoryForPatch = pc;
          shouldPatchCategory = true;
        }
      }
    }
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (endTime != null) {
      updates['end_time'] = endTime.toUtc().toIso8601String();
      updates['status'] = 'stopped';
    }
    if (startTime != null) {
      updates['start_time'] = startTime.toUtc().toIso8601String();
      if (endTime == null && !updates.containsKey('status')) {
        updates['status'] = 'running';
      }
    }
    if (shouldPatchCategory && categoryForPatch != null) {
      updates['category_id'] = _recordCategoryBusinessPkForApi(
        categoryForPatch,
      );
    }
    if (note != null) updates['note'] = note;
    if (tags != null) {
      final t = tags.trim();
      if (t.isNotEmpty) updates['tags'] = t;
    }
    if (checklist != null) updates['checklist'] = checklist;
    if (syncSourcePlan) {
      if (clearSourcePlan) {
        updates['source_plan_id'] = null;
      } else {
        final sp = DatabaseService.pocketRelationIdOrNull(
          sourcePlanPocketRecordId,
        );
        if (sp != null) updates['source_plan_id'] = sp;
      }
    }
    return updates;
  }

  Future<bool> _patchRecordUpdateNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
    required Map<String, dynamic> updates,
    Map<String, dynamic>? rollbackRow,
    int rollbackIndex = -1,
  }) async {
    DatabaseService._log('PATCH_ID_TRACE: record update pb id=$resolvedPbId');
    final patchCode = await _patchRecordsRowWith404Recovery(
      originalQueryId: originalInput,
      restId: resolvedPbId,
      fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
    );
    if (patchCode == 404) {
      if (rollbackRow != null && rollbackIndex >= 0) {
        _cachedFlatRecords[rollbackIndex] = rollbackRow;
        _notifyTimelineAfterRecordCacheMutation();
      }
      _purgeGhostRecordById(resolvedPbId);
      await _fetchRecordsIntoCache(forceNetwork: true);
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.failed();
      return false;
    }
    if (patchCode >= 200 && patchCode < 300) {
      _notifyTimelineAfterRecordCacheMutation();
      unawaited(offlineSync.refreshPendingCount());
      return true;
    }
    if (patchCode == 401 || patchCode == 403) {
      await _enqueueRecordUpdateMutation(
        originalInput: originalInput,
        businessId: businessId,
        patchFields: updates,
        pocketBaseId: resolvedPbId,
        error: patchCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $patchCode');
      final loc = currentLocale.value;
      final msg = patchCode == 401
          ? t(loc, 'error_record_create_unauthorized')
          : t(loc, 'error_record_create_forbidden');
      _brainSnackError(msg);
      return true;
    }
    if (_recordMutationRetriableHttpCode(patchCode)) {
      await _enqueueRecordUpdateMutation(
        originalInput: originalInput,
        businessId: businessId,
        patchFields: updates,
        pocketBaseId: resolvedPbId,
        error: patchCode,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    }
    if (rollbackRow != null && rollbackIndex >= 0) {
      _cachedFlatRecords[rollbackIndex] = rollbackRow;
      _notifyTimelineAfterRecordCacheMutation();
    }
    AppSnack.failed();
    return false;
  }

  Future<bool> _deleteRecordNetworkPhase({
    required String originalInput,
    required String resolvedPbId,
    required String businessId,
    required Set<String> delKeys,
  }) async {
    DatabaseService._log('DELETE_ID_TRACE: deleteRecord pb id=$resolvedPbId');
    final delCode = await _deleteRecordsRowWithFallback(
      originalQueryId: originalInput,
      restId: resolvedPbId,
    );
    if (delCode == 404) {
      _purgeGhostRecordById(resolvedPbId);
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    }
    final ok = delCode >= 200 && delCode < 300;
    if (ok) {
      try {
        await _fetchRecordsIntoCache(forceNetwork: true);
      } catch (_) {}
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.deleted();
      unawaited(offlineSync.refreshPendingCount());
      return true;
    }
    if (delCode == 401 || delCode == 403) {
      await _enqueueRecordDeleteMutation(
        originalInput: originalInput,
        businessId: businessId,
        pocketBaseId: resolvedPbId,
        error: delCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $delCode');
      _snackDeleteHttpFailure(delCode);
      return true;
    }
    if (_recordMutationRetriableHttpCode(delCode)) {
      await _enqueueRecordDeleteMutation(
        originalInput: originalInput,
        businessId: businessId,
        pocketBaseId: resolvedPbId,
        error: delCode,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    }
    for (final k in delKeys) {
      _optimisticDeletedKeys.remove(k);
    }
    _notifyTimelineAfterRecordCacheMutation();
    _snackDeleteHttpFailure(delCode);
    return false;
  }

  /// Drains queued PocketBase **records** mutations (offline outbox). Safe to call from [SyncManager].
  Future<void> flushPendingRecordMutations() async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    if (_recordMutationOutboxFlushInFlight) return;
    if (offlineSync.authPaused) return;
    _recordMutationOutboxFlushInFlight = true;
    offlineSync.setSyncing(true);
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return;
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final q = await RecordMutationOutbox.load(prefs);
      if (q.isEmpty) return;
      var pendingTail = const <Map<String, dynamic>>[];
      var i = 0;
      for (; i < q.length; i++) {
        final item = Map<String, dynamic>.from(q[i]);
        final ok = await _flushOneRecordOutboxEntry(item);
        if (!ok) {
          item['retryCount'] = ((item['retryCount'] as num?)?.toInt() ?? 0) + 1;
          item['lastError'] = offlineSync.lastError ?? 'sync_failed';
          pendingTail = [item, ...q.sublist(i + 1)];
          break;
        }
      }
      if (pendingTail.isEmpty && i >= q.length) {
        await RecordMutationOutbox.replaceAll(prefs, []);
        offlineSync.clearErrors();
      } else if (pendingTail.isNotEmpty) {
        await RecordMutationOutbox.replaceAll(prefs, pendingTail);
      } else {
        await RecordMutationOutbox.replaceAll(prefs, q.sublist(i));
      }
    } finally {
      offlineSync.setSyncing(false);
      unawaited(offlineSync.refreshPendingCount());
      _recordMutationOutboxFlushInFlight = false;
    }
  }

  Future<bool> _flushOneRecordOutboxEntry(Map<String, dynamic> item) async {
    final kind = (item['kind'] ?? '').toString();
    if (kind == RecordMutationOutbox.kindHighlanderStart) {
      final wrapped = item['payload'];
      if (wrapped is! Map) return true;
      final payload = Map<String, dynamic>.from(wrapped);
      final businessId = (item['businessId'] ?? payload['record_id'] ?? '')
          .toString()
          .trim();
      // ignore: avoid_print
      print(
        'RECORD_OUTBOX_CREATE_PAYLOAD op=highlander_start '
        'businessId=${businessId.isEmpty ? '-' : businessId} '
        'category_id=${payload['category_id']} category_link=${payload['category_link']} '
        'source_plan_id=${payload['source_plan_id']}',
      );
      if (!_normalizeRecordCategoryFieldsForPbApi(
        payload,
        logBusinessId: businessId.isEmpty ? null : businessId,
      )) {
        // ignore: avoid_print
        print(
          'RECORD_OUTBOX_DROPPED_INVALID_CATEGORY '
          'businessId=${businessId.isEmpty ? '-' : businessId} '
          'reason=category_relation_not_resolved',
        );
        return true;
      }
      final failureCode = await _runHighlanderStartServerPhase(payload);
      if (failureCode == null) {
        clearOptimisticTimelineUi(notifyTimeline: false);
        return true;
      }
      if (failureCode == 401 || failureCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $failureCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(failureCode)) {
        offlineSync.setLastError('HTTP $failureCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindHighlanderStart,
          businessId: businessId,
          pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
          httpStatus: failureCode,
        );
        return false;
      }
      DatabaseService.logSyncFlushFailure(
        collection: PbCollections.records,
        operation: RecordMutationOutbox.kindHighlanderStart,
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
        httpStatus: failureCode,
      );
      return true;
    }
    if (kind == RecordMutationOutbox.kindStopPatch) {
      final originalInput =
          (item['originalQueryId'] ?? item['businessId'] ?? '')
              .toString()
              .trim();
      final pbId = (item['pocketBaseId'] ?? '').toString().trim();
      if (originalInput.isEmpty || pbId.isEmpty) return true;
      final nowIso = DatabaseService.getPlanetaryNow()
          .toUtc()
          .toIso8601String();
      final stopFields = _nocoFieldsForPatch(<String, dynamic>{
        'end_time': nowIso,
        'status': 'stopped',
      });
      final stopCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: pbId,
        fields: stopFields,
      );
      if (stopCode == 404) {
        _purgeGhostRecordById(pbId);
        _clearOptimisticStopKeysForRecord(originalInput);
        return true;
      }
      if (stopCode >= 200 && stopCode < 300) {
        _clearOptimisticStopKeysForRecord(originalInput);
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return true;
      }
      if (stopCode == 401 || stopCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $stopCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(stopCode)) {
        offlineSync.setLastError('HTTP $stopCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindStopPatch,
          businessId: originalInput,
          pocketBaseId: pbId,
          httpStatus: stopCode,
        );
        return false;
      }
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    }
    if (kind == RecordMutationOutbox.kindRecordUpdate) {
      final wrapped = item['payload'];
      if (wrapped is! Map) return true;
      final updates = Map<String, dynamic>.from(wrapped);
      if (updates.isEmpty) return true;
      final businessId = _bizKey(item);
      final originalInput = (item['originalQueryId'] ?? businessId)
          .toString()
          .trim();
      final pbId = await _resolveRecordPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
      );
      if (pbId == null || pbId.isEmpty) {
        final cached = _tryResolveRecordIdFromCacheOnly(businessId);
        if (cached == null || cached.isEmpty) {
          DatabaseService.logSyncFlushFailure(
            collection: PbCollections.records,
            operation: RecordMutationOutbox.kindRecordUpdate,
            businessId: businessId,
            message: 'dropped_stale_no_cache',
          );
          return true;
        }
        offlineSync.setLastError('resolve_failed:records/update');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindRecordUpdate,
          businessId: businessId,
          message: 'unresolved_pb_id',
        );
        return false;
      }
      final patchCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: pbId,
        fields: _nocoFieldsForPatch(updates),
      );
      if (patchCode == 404) {
        _purgeGhostRecordById(pbId);
        return true;
      }
      if (patchCode >= 200 && patchCode < 300) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return true;
      }
      if (patchCode == 401 || patchCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $patchCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(patchCode)) {
        offlineSync.setLastError('HTTP $patchCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindRecordUpdate,
          businessId: businessId,
          pocketBaseId: pbId,
          httpStatus: patchCode,
        );
        return false;
      }
      return true;
    }
    if (kind == RecordMutationOutbox.kindRecordDelete) {
      final businessId = _bizKey(item);
      final originalInput = (item['originalQueryId'] ?? businessId)
          .toString()
          .trim();
      final pbId = await _resolveRecordPbIdForOutboxReplay(
        businessId: businessId,
        pocketBaseId: (item['pocketBaseId'] ?? '').toString(),
      );
      if (pbId == null || pbId.isEmpty) {
        return true;
      }
      final delCode = await _deleteRecordsRowWithFallback(
        originalQueryId: originalInput,
        restId: pbId,
      );
      if (delCode == 404) {
        _purgeGhostRecordById(pbId);
        return true;
      }
      if (delCode >= 200 && delCode < 300) {
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return true;
      }
      if (delCode == 401 || delCode == 403) {
        offlineSync.setAuthPaused(true, message: 'HTTP $delCode');
        return false;
      }
      if (_recordMutationRetriableHttpCode(delCode)) {
        offlineSync.setLastError('HTTP $delCode');
        DatabaseService.logSyncFlushFailure(
          collection: PbCollections.records,
          operation: RecordMutationOutbox.kindRecordDelete,
          businessId: businessId,
          pocketBaseId: pbId,
          httpStatus: delCode,
        );
        return false;
      }
      return true;
    }
    return true;
  }

  String _bizKey(Map<String, dynamic> item) =>
      (item['businessId'] ?? '').toString().trim();

  /// Highlander server phase (PATCH old + POST new). Returns **null** on success, HTTP/synthetic code on failure.
  Future<int?> _runHighlanderStartServerPhase(
    Map<String, dynamic> runningFields,
  ) async {
    try {
      final sp = runningFields['source_plan_id'];
      if (sp != null) {
        final planId =
            DatabaseService.pocketRelationIdOrNull(sp.toString()) ??
            sp.toString().trim();
        if (planId.isNotEmpty) {
          final pc = await _resolveCategoryIdFromSourcePlanPbId(planId);
          if (_planLocalCategoryIdIsConcrete(pc)) {
            final resolved = _resolveColdStartRecordCategoryId(pc);
            if (_categoryIdResolvableForPbRecordPost(resolved)) {
              final pair = _recordCategoryDualityForLocalId(resolved);
              if (pair != null) {
                runningFields['category_id'] = pair.relationId;
                runningFields['category_link'] = pair.relationId;
              }
            }
          }
        }
      }
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return 0;

      _recordCacheTimelineNotifyBatchDepth++;
      try {
        final handoffIso = (runningFields['start_time'] ?? '')
            .toString()
            .trim();
        if (handoffIso.isEmpty) {
          return 500;
        }
        final serverPrimaries =
            await _fetchServerRunningSacredPrimariesByPbId();
        if (serverPrimaries.isEmpty) {
          DatabaseService._log(
            'SACRED_PREFLIGHT: no running primaries on server (POST new only)',
          );
        } else {
          DatabaseService._log(
            'SACRED_PREFLIGHT: server running primaries=${serverPrimaries.length} (PATCH to handoff start)',
          );
        }
        for (final e in serverPrimaries.entries) {
          final rid = e.key;
          final row = e.value;
          final oq = (row['record_id'] ?? '').toString().trim();
          final stopIso = _highlanderStopIsoForServerRow(
            handoffIsoUtc: handoffIso,
            serverRow: row,
          );
          final stopFields = _nocoFieldsForPatch(<String, dynamic>{
            'end_time': stopIso,
            'status': 'stopped',
          });
          final code = await _patchRecordsRowWith404Recovery(
            originalQueryId: oq.isNotEmpty ? oq : rid,
            restId: rid,
            fields: stopFields,
          );
          if (code == 404) {
            _purgeGhostRecordById(rid);
            continue;
          }
          if (code < 200 || code >= 300) {
            return code;
          }
        }
        final createdId = await _createRecordPb(runningFields);
        if (createdId == null || createdId.trim().isEmpty) {
          if (!_pb.authStore.isValid) return 401;
          final last = _lastRecordCreateFailureHttpCode;
          if (last > 0) return last;
          return 500;
        }
        await _finalizeRecordCreateHandshake(pocketCreatedRecordId: createdId);
        try {
          await _fetchRecordsIntoCache(forceNetwork: true);
        } catch (_) {}
        _notifyTimelineAfterRecordCacheMutation();
        return null;
      } finally {
        _recordCacheTimelineNotifyBatchDepth--;
      }
    } on ClientException catch (e) {
      return e.statusCode;
    } catch (e) {
      DatabaseService._log('HIGHLANDER server phase failed: $e');
      return 0;
    }
  }

  /// Highlander server phase (PATCH old + POST new). Runs **after** local shadow; may log [DISPATCH].
  Future<void> _highlanderPrimaryServerSync({
    required _HighlanderRollbackToken? rollbackToken,
    required Map<String, dynamic> runningFields,
  }) async {
    final failureCode = await _runHighlanderStartServerPhase(runningFields);
    if (failureCode == null) {
      clearOptimisticTimelineUi(notifyTimeline: false);
      unawaited(offlineSync.refreshPendingCount());
      return;
    }
    if (failureCode == 401 || failureCode == 403) {
      await _enqueueHighlanderStartMutation(
        runningFields,
        error: failureCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $failureCode');
      final loc = currentLocale.value;
      final msg = failureCode == 401
          ? t(loc, 'error_record_create_unauthorized')
          : t(loc, 'error_record_create_forbidden');
      _brainSnackError(msg);
      return;
    }
    if (_recordMutationRetriableHttpCode(failureCode)) {
      await _enqueueHighlanderStartMutation(runningFields, error: failureCode);
      offlineSync.setConnectivityOffline(true);
      return;
    }
    DatabaseService._log('HIGHLANDER server phase failed: HTTP $failureCode');
    await _runBatchedRecordCacheTimelineNotify(() async {
      _restoreHighlanderRollbackToken(rollbackToken);
      clearOptimisticTimelineUi();
      _printAtomicCheckRunningCount();
    });
    AppSnack.failed();
  }

  Future<String?> writeRecord(
    String dateKey,
    String taskText, {
    int? categoryId,
    DateTime? explicitStartTime,
    int? parentId,
    String? parentRecordId,
    String? sourcePlanPocketRecordId,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    if (_writeRecordMutationInFlight) return null;
    _writeRecordMutationInFlight = true;
    var deferWriteRecordMutationRelease = false;
    try {
      final parsed = getCleanTitleAndTags(taskText);
      final sourcePlanForPayloadEarly = !((parentRecordId?.trim().isNotEmpty ?? false) || parentId != null)
          ? DatabaseService.pocketRelationIdOrNull(sourcePlanPocketRecordId)
          : null;
      int? cid = categoryId;
      if (sourcePlanForPayloadEarly != null) {
        final planCat = resolveCurrentPlanCategoryForRecordStart(
          sourcePlanPocketRecordId: sourcePlanForPayloadEarly,
          uiCategoryId: categoryId,
        );
        if (_planLocalCategoryIdIsConcrete(planCat)) {
          cid = planCat;
        }
      }
      if (sourcePlanForPayloadEarly == null ||
          !_planLocalCategoryIdIsConcrete(cid)) {
        cid = identifyCategory(parsed.title)?.id ?? cid;
        cid = _resolveRecordCategoryIdWithSmartLink(parsed.title, cid);
        if (!_planLocalCategoryIdIsConcrete(cid)) {
          final inferred = _smartInferCategoryId(parsed.title);
          if (_planLocalCategoryIdIsConcrete(inferred)) {
            cid = inferred;
          }
        }
      }
      cid = _resolveColdStartRecordCategoryId(cid);
      if (!_categoryIdResolvableForPbRecordPost(cid)) {
        DatabaseService._log(
          'writeRecord: cold-start could not resolve category_id',
        );
        AppSnack.failed();
        return null;
      }
      final now = DatabaseService.getPlanetaryNow();
      final start = explicitStartTime ?? now;
      final isStartingNow = explicitStartTime != null;
      final status = isStartingNow
          ? 'running'
          : (dateKey == _todayKey ? 'running' : 'completed');
      DateTime? endTime = isStartingNow
          ? null
          : (dateKey == _todayKey ? null : start);
      final startIso = start.toUtc().toIso8601String();
      final pr = parentRecordId?.trim();
      final hasParent = (pr != null && pr.isNotEmpty) || parentId != null;
      final sourcePlanForPayload = !hasParent
          ? DatabaseService.pocketRelationIdOrNull(sourcePlanPocketRecordId)
          : null;
      // Plan category from PocketBase must not run before primary Highlander shadow (§9 main thread).
      if (status == 'running') {
        final isPrimary = !hasParent;
        late final String runningRecordBizId;
        if (isPrimary) {
          runningRecordBizId = DatabaseService._newClientRecordUuid();
          final runningFields = _nocoFieldsForPatch(<String, dynamic>{
            'user_id': _pidForPbFilter,
            'record_id': runningRecordBizId,
            'status': 'running',
            'title': parsed.title,
            'start_time': startIso,
            'end_time': null,
            'category_id': _recordCategoryBusinessPkForApi(cid),
            'type': 'record',
            'checklist': <Map<String, dynamic>>[],
            if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
            if (sourcePlanForPayload != null)
              'source_plan_id': sourcePlanForPayload,
          });
          if (pr != null && pr.isNotEmpty) {
            runningFields['parent_id'] = pr;
          } else if (parentId != null) {
            runningFields['parent_id'] = parentId.toString();
          }
          final patchTargets = <Map<String, String>>[];
          _HighlanderRollbackToken? rollbackToken;
          final prevNet = _primaryHighlanderNetworkChain;
          final netDone = Completer<void>();
          _primaryHighlanderNetworkChain = prevNet.then((_) => netDone.future);
          try {
            final shadowPerf = Stopwatch()..start();
            var msSnap = 0;
            var msApply = 0;
            try {
              _runBatchedRecordCacheTimelineNotifySync(() {
                final tSnap = Stopwatch()..start();
                final beforeLen = _cachedFlatRecords.length;
                final runningSnapshots =
                    _snapshotRunningRowsForHighlanderRollback();
                msSnap = tSnap.elapsedMilliseconds;
                final tApply = Stopwatch()..start();
                clearOptimisticTimelineUi();
                _startAtomicTaskSequenceApplyLocalPrimary(
                  createBody: runningFields,
                  patchTargetsOut: patchTargets,
                );
                final appended = _cachedFlatRecords.length > beforeLen;
                rollbackToken = _HighlanderRollbackToken(
                  runningSnapshotsByIndex: runningSnapshots,
                  appendedPendingRow: appended,
                );
                _printAtomicCheckRunningCount();
                msApply = tApply.elapsedMilliseconds;
              });
            } finally {
              if (kDebugMode) {
                debugPrint(
                  '[SHADOW_PERF] cache+notify=${shadowPerf.elapsedMilliseconds}ms '
                  '(snapshot_running=${msSnap}ms local_apply=${msApply}ms; '
                  'bottleneck=${msSnap >= msApply ? "_snapshotRunningRowsForHighlanderRollback" : "clearOptimistic+_startAtomicTaskSequenceApplyLocalPrimary+_printAtomicCheckRunningCount"})',
                );
              }
            }
            deferWriteRecordMutationRelease = true;
            unawaited(() async {
              try {
                await prevNet;
                await _highlanderPrimaryServerSync(
                  rollbackToken: rollbackToken,
                  runningFields: runningFields,
                );
              } finally {
                if (!netDone.isCompleted) netDone.complete();
                _writeRecordMutationInFlight = false;
              }
            }());
            return runningRecordBizId;
          } catch (e, st) {
            DatabaseService._log(
              'writeRecord primary Highlander local phase: $e',
            );
            DatabaseService._log(st.toString());
            clearOptimisticTimelineUi();
            if (!netDone.isCompleted) netDone.complete();
            rethrow;
          }
        }
        runningRecordBizId = DatabaseService._newClientRecordUuid();
        final rows = List<Map<String, dynamic>>.from(_cachedFlatRecords);
        for (final r in rows) {
          var sameParent = false;
          if (pr != null && pr.isNotEmpty) {
            sameParent = _parentFieldEqualsRecordId(r, pr);
          } else if (parentId != null) {
            sameParent =
                CategoryServiceExtension._rowInt(r['parent_id']) == parentId;
          }
          if (!sameParent) continue;
          if (!CategoryServiceExtension._isNocoRowSacredStopTarget(r)) continue;
          final id = CategoryServiceExtension.recordsTablePk(r);
          if (id.isEmpty) continue;
          DatabaseService._log('PATCH_ID_TRACE: child-stop pb id=$id');
          final childFields = _nocoFieldsForPatch(<String, dynamic>{
            'end_time': startIso,
            'status': 'stopped',
          });
          final biz = (r['record_id'] ?? '').toString().trim();
          final cr = await _patchRecordsRowWith404Recovery(
            originalQueryId: biz.isNotEmpty ? biz : id,
            restId: id,
            fields: childFields,
          );
          if (cr == 404) {
            _purgeGhostRecordById(id);
          }
        }
        final runningFields = _nocoFieldsForPatch(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'record_id': runningRecordBizId,
          'status': 'running',
          'title': parsed.title,
          'start_time': startIso,
          'end_time': null,
          'category_id': _recordCategoryBusinessPkForApi(cid),
          'type': 'record',
          'checklist': <Map<String, dynamic>>[],
          if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
          if (sourcePlanForPayload != null)
            'source_plan_id': sourcePlanForPayload,
        });
        if (pr != null && pr.isNotEmpty) {
          runningFields['parent_id'] = pr;
        } else if (parentId != null) {
          runningFields['parent_id'] = parentId.toString();
        }
        final newId = await _createRecordPb(runningFields);
        if (newId == null) {
          DatabaseService._log('writeRecord PocketBase create failed');
          return null;
        }
        await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
        _notifyTimelineAfterRecordCacheMutation();
        return newId;
      } else {
        var cidForCompleted = cid;
        if (sourcePlanForPayload != null) {
          final pc = await _resolveCategoryIdFromSourcePlanPbId(
            sourcePlanForPayload,
          );
          if (_planLocalCategoryIdIsConcrete(pc)) {
            cidForCompleted = pc;
          }
        }
        cidForCompleted = _resolveColdStartRecordCategoryId(cidForCompleted);
        if (!_categoryIdResolvableForPbRecordPost(cidForCompleted)) {
          DatabaseService._log(
            'writeRecord completed branch: cold-start could not resolve category_id',
          );
          AppSnack.failed();
          return null;
        }
        final completedFields = _nocoFieldsForPatch(<String, dynamic>{
          'user_id': _pidForPbFilter,
          'record_id': DatabaseService._newClientRecordUuid(),
          'status': 'completed',
          'title': parsed.title,
          'start_time': startIso,
          'end_time': endTime?.toUtc().toIso8601String(),
          'category_id': _recordCategoryBusinessPkForApi(cidForCompleted),
          'type': 'record',
          'checklist': <Map<String, dynamic>>[],
          if (parsed.tags.isNotEmpty) 'tags': parsed.tags.join(','),
          if (sourcePlanForPayload != null)
            'source_plan_id': sourcePlanForPayload,
        });
        if (pr != null && pr.isNotEmpty) {
          completedFields['parent_id'] = pr;
        } else if (parentId != null) {
          completedFields['parent_id'] = parentId.toString();
        }
        final newId = await _createRecordPb(completedFields);
        if (newId == null) {
          DatabaseService._log(
            'writeRecord PocketBase create failed (completed branch)',
          );
          return null;
        }
        await _finalizeRecordCreateHandshake(pocketCreatedRecordId: newId);
        _notifyTimelineAfterRecordCacheMutation();
        return newId;
      }
    } catch (e, st) {
      DatabaseService._log('writeRecord failed: $e');
      DatabaseService._log(st);
      final isChildPost =
          (parentRecordId?.trim().isNotEmpty ?? false) || parentId != null;
      if (!isChildPost) {
        clearOptimisticTimelineUi();
      }
      return null;
    } finally {
      if (!deferWriteRecordMutationRelease) {
        _writeRecordMutationInFlight = false;
      }
    }
  }

  /// In-memory cache patch so timeline UI can refresh immediately when the record sheet closes.
  void applyOptimisticRecordRowEdit({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    String? tags,
    List<Map<String, dynamic>>? checklist,
    bool syncSourcePlan = false,
    bool clearSourcePlan = false,
    String? sourcePlanPocketRecordId,
  }) {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    var rid = recordId.trim();
    if (rid.isEmpty) return;
    final originalInput = rid;
    final idx = _indexOfCachedRecordRow(rid, originalInput);
    if (idx < 0) return;
    final row = _cachedFlatRecords[idx];
    if (title != null) row['title'] = title;
    if (startTime != null) {
      row['start_time'] = startTime.toUtc().toIso8601String();
      if (endTime == null) row['status'] = 'running';
    }
    if (endTime != null) {
      row['end_time'] = endTime.toUtc().toIso8601String();
      row['status'] = 'stopped';
    }
    var resolvedCategoryId = categoryId;
    var shouldWriteCategory = categoryId != null;
    if (syncSourcePlan && !clearSourcePlan) {
      final sp = DatabaseService.pocketRelationIdOrNull(
        sourcePlanPocketRecordId,
      );
      if (sp != null) {
        final ic = _tryResolveCategoryIdFromSourcePlanPbIdSync(sp);
        if (_planLocalCategoryIdIsConcrete(ic)) {
          resolvedCategoryId = ic;
          shouldWriteCategory = true;
        }
      }
    }
    if (shouldWriteCategory && resolvedCategoryId != null) {
      _applyLocalRecordCategoryDualityToRow(row, resolvedCategoryId);
    }
    if (note != null) row['note'] = note;
    if (tags != null) {
      final t = tags.trim();
      if (t.isNotEmpty) row['tags'] = t;
    }
    if (checklist != null) row['checklist'] = checklist;
    if (syncSourcePlan) {
      if (clearSourcePlan) {
        row['source_plan_id'] = null;
      } else {
        final sp = DatabaseService.pocketRelationIdOrNull(
          sourcePlanPocketRecordId,
        );
        if (sp != null) row['source_plan_id'] = sp;
      }
    }
    _notifyTimelineAfterRecordCacheMutation();
  }

  String? _cachedRecordSourcePlanId(Map<String, dynamic> row) {
    final raw =
        normalizeLinkScalar(row['source_plan_id']) ?? row['source_plan_id'];
    return DatabaseService.pocketRelationIdOrNull(raw?.toString());
  }

  void _applyLocalRecordCategoryDualityToRow(
    Map<String, dynamic> row,
    int categoryId,
  ) {
    final pair = _recordCategoryDualityForLocalId(categoryId);
    if (pair == null) {
      row.remove('category_id');
      row.remove('category_link');
      row.remove('_expanded_category');
      return;
    }
    row['category_id'] = pair.businessId;
    row['category_link'] = pair.relationId;
    row['_expanded_category'] = <String, dynamic>{
      'id': pair.relationId,
      'category_id': pair.businessId,
    };
  }

  void _applyCachedRecordCategoryAt(int index, int categoryId) {
    if (index < 0 || index >= _cachedFlatRecords.length) return;
    _applyLocalRecordCategoryDualityToRow(_cachedFlatRecords[index], categoryId);
  }

  void _propagatePlanAutoCategoryToLoadedLinkedRecords({
    required String planPocketId,
    required int oldCategoryId,
    required int newCategoryId,
  }) {
    final planId = DatabaseService.pocketRelationIdOrNull(planPocketId);
    if (planId == null) return;
    if (!_planLocalCategoryIdIsConcrete(oldCategoryId) ||
        !_planLocalCategoryIdIsConcrete(newCategoryId) ||
        oldCategoryId == newCategoryId) {
      return;
    }
    final targets =
        <
          ({
            int index,
            String originalInput,
            String businessId,
            String? pbId,
            Map<String, dynamic> rollback,
          })
        >[];
    for (var i = 0; i < _cachedFlatRecords.length; i++) {
      final row = _cachedFlatRecords[i];
      if (_cachedRecordSourcePlanId(row) != planId) continue;
      final current = categoryIdFromRecordRow(row);
      if (current != oldCategoryId) continue;
      final pbId = _pbSystemIdFromCachedRecordRow(row);
      final biz = (row['record_id'] ?? '').toString().trim();
      final original = (pbId != null && pbId.isNotEmpty) ? pbId : biz;
      if (original.isEmpty || biz.isEmpty) continue;
      targets.add((
        index: i,
        originalInput: original,
        businessId: biz,
        pbId: pbId,
        rollback: Map<String, dynamic>.from(row),
      ));
    }
    if (targets.isEmpty) return;
    for (final t in targets) {
      _applyCachedRecordCategoryAt(t.index, newCategoryId);
    }
    _notifyTimelineAfterRecordCacheMutation();
    for (final t in targets) {
      unawaited(
        _patchLoadedLinkedRecordCategory(
          originalInput: t.originalInput,
          businessId: t.businessId,
          pocketBaseId: t.pbId,
          rollbackIndex: t.index,
          rollbackRow: t.rollback,
          newCategoryId: newCategoryId,
        ),
      );
    }
  }

  Future<void> _patchLoadedLinkedRecordCategory({
    required String originalInput,
    required String businessId,
    required String? pocketBaseId,
    required int rollbackIndex,
    required Map<String, dynamic> rollbackRow,
    required int newCategoryId,
  }) async {
    final updates = <String, dynamic>{
      'category_id': _recordCategoryBusinessPkForApi(newCategoryId),
    };
    try {
      var rid = pocketBaseId?.trim();
      if (rid == null ||
          rid.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(rid)) {
        rid = await _resolveRecordPbIdForOutboxReplay(
          businessId: businessId,
          pocketBaseId: pocketBaseId,
        );
      }
      if (rid == null ||
          rid.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(rid)) {
        await _enqueueRecordUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: updates,
          error: 'unresolved_pb_id',
        );
        offlineSync.setConnectivityOffline(true);
        return;
      }
      final code = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
      );
      if (code >= 200 && code < 300) {
        unawaited(offlineSync.refreshPendingCount());
        return;
      }
      if (code == 401 || code == 403) {
        await _enqueueRecordUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: updates,
          pocketBaseId: rid,
          error: code,
          syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        return;
      }
      if (_recordMutationRetriableHttpCode(code)) {
        await _enqueueRecordUpdateMutation(
          originalInput: originalInput,
          businessId: businessId,
          patchFields: updates,
          pocketBaseId: rid,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return;
      }
      if (rollbackIndex >= 0 && rollbackIndex < _cachedFlatRecords.length) {
        _cachedFlatRecords[rollbackIndex] = rollbackRow;
        _notifyTimelineAfterRecordCacheMutation();
      }
    } catch (e, st) {
      DatabaseService._log('AUTO_RECAT_RECORD_LINKED: $e');
      DatabaseService._log(st.toString());
      await _enqueueRecordUpdateMutation(
        originalInput: originalInput,
        businessId: businessId,
        patchFields: updates,
        pocketBaseId: pocketBaseId,
        error: e,
      );
      offlineSync.setConnectivityOffline(true);
    }
  }

  Future<TimelineRecord?> updateRecord({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,

    /// Comma-separated tag **names** (@DATA_MAP `records.tags` string). Omitted when null or blank.
    String? tags,
    List<Map<String, dynamic>>? checklist,
    bool syncSourcePlan = false,
    bool clearSourcePlan = false,
    String? sourcePlanPocketRecordId,
    bool bypassConflictCheck = false,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return null;
    final businessId = _outboxBusinessIdForRecord(originalInput);
    try {
      final cacheRid =
          _tryResolveRecordIdFromCacheOnly(originalInput) ?? originalInput;
      final existingIndex = _indexOfCachedRecordRow(cacheRid, originalInput);
      final existingRow = existingIndex >= 0
          ? _cachedFlatRecords[existingIndex]
          : null;
      final oldCategoryId = existingRow != null
          ? categoryIdFromRecordRow(existingRow)
          : null;
      final autoCategoryId = _resolveCategoryIdForEditedTitle(
        newTitle: title,
        oldTitle: existingRow?['title']?.toString(),
        currentCategoryId: oldCategoryId,
        manualCategoryChanged: categoryId != null || syncSourcePlan,
      );
      final effectiveCategoryId = categoryId ?? autoCategoryId;
      final updates = await _buildRecordPatchUpdates(
        title: title,
        startTime: startTime,
        endTime: endTime,
        categoryId: effectiveCategoryId,
        note: note,
        tags: tags,
        checklist: checklist,
        syncSourcePlan: syncSourcePlan,
        clearSourcePlan: clearSourcePlan,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (updates.isEmpty) {
        return _timelineRecordFromCacheInput(originalInput);
      }
      Map<String, dynamic>? rollbackRow;
      var rollbackIndex = -1;
      rollbackIndex = existingIndex;
      if (rollbackIndex >= 0) {
        rollbackRow = Map<String, dynamic>.from(
          _cachedFlatRecords[rollbackIndex],
        );
      }
      applyOptimisticRecordRowEdit(
        recordId: originalInput,
        title: title,
        startTime: startTime,
        endTime: endTime,
        categoryId: effectiveCategoryId,
        note: note,
        tags: tags,
        checklist: checklist,
        syncSourcePlan: syncSourcePlan,
        clearSourcePlan: clearSourcePlan,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (autoCategoryId != null &&
          oldCategoryId != null &&
          oldCategoryId != autoCategoryId &&
          existingRow != null) {
        final sourcePlanId = _cachedRecordSourcePlanId(existingRow);
        if (sourcePlanId != null) {
          unawaited(
            _propagateRecordAutoCategoryToLinkedPlan(
              planPocketId: sourcePlanId,
              oldCategoryId: oldCategoryId,
              newCategoryId: autoCategoryId,
            ),
          );
        }
      }
      final optimistic = _timelineRecordFromCacheInput(originalInput);
      final shadowRid = _tryResolveRecordIdFromCacheOnly(originalInput);
      if (shadowRid != null &&
          DatabaseService._isLikelyPocketBaseRowId(shadowRid)) {
        final rb = rollbackRow;
        final ri = rollbackIndex;
        unawaited(
          _patchRecordUpdateNetworkPhase(
            originalInput: originalInput,
            resolvedPbId: shadowRid,
            businessId: businessId,
            updates: updates,
            rollbackRow: rb,
            rollbackIndex: ri,
          ).catchError((Object e, StackTrace st) async {
            DatabaseService._log('updateRecord shadow async: $e');
            DatabaseService._log(st.toString());
            if (e is ClientException) {
              final code = e.statusCode;
              if (code == 401 || code == 403) {
                await _enqueueRecordUpdateMutation(
                  originalInput: originalInput,
                  businessId: businessId,
                  patchFields: updates,
                  pocketBaseId: shadowRid,
                  error: code,
                  syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
                );
                offlineSync.setAuthPaused(true, message: 'HTTP $code');
                return true;
              }
              if (_recordMutationRetriableHttpCode(code)) {
                await _enqueueRecordUpdateMutation(
                  originalInput: originalInput,
                  businessId: businessId,
                  patchFields: updates,
                  pocketBaseId: shadowRid,
                  error: code,
                );
                offlineSync.setConnectivityOffline(true);
                return true;
              }
            } else if (_recordMutationRetriableHttpCode(0)) {
              await _enqueueRecordUpdateMutation(
                originalInput: originalInput,
                businessId: businessId,
                patchFields: updates,
                pocketBaseId: shadowRid,
                error: e,
              );
              offlineSync.setConnectivityOffline(true);
              return true;
            }
            if (rb != null && ri >= 0 && ri < _cachedFlatRecords.length) {
              _cachedFlatRecords[ri] = rb;
              _notifyTimelineAfterRecordCacheMutation();
            }
            AppSnack.failed();
            return false;
          }),
        );
        return optimistic;
      }
      unawaited(() async {
        try {
          final rid = await _resolveRecordIdForRestUrl(originalInput);
          if (!DatabaseService._isLikelyPocketBaseRowId(rid)) {
            await _enqueueRecordUpdateMutation(
              originalInput: originalInput,
              businessId: businessId,
              patchFields: updates,
              error: 'unresolved_pb_id',
            );
            offlineSync.setConnectivityOffline(true);
            return;
          }
          await _patchRecordUpdateNetworkPhase(
            originalInput: originalInput,
            resolvedPbId: rid,
            businessId: businessId,
            updates: updates,
            rollbackRow: rollbackRow,
            rollbackIndex: rollbackIndex,
          );
        } catch (e, st) {
          DatabaseService._log('updateRecord resolve async: $e');
          DatabaseService._log(st.toString());
          if (_recordMutationRetriableHttpCode(0)) {
            await _enqueueRecordUpdateMutation(
              originalInput: originalInput,
              businessId: businessId,
              patchFields: updates,
              error: e,
            );
            offlineSync.setConnectivityOffline(true);
          }
        }
      }());
      return optimistic;
    } catch (_) {
      AppSnack.failed();
      return _timelineRecordFromCacheInput(originalInput);
    }
  }

  /// Links `source_plan_id` after the Start tap (plan suggestion moved off the critical path).
  /// Does not run a full records refresh on success — local cache + one PATCH only.
  Future<bool> patchRecordSourcePlanLink({
    required String recordId,
    required String sourcePlanPocketRecordId,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return false;
    final sp = DatabaseService.pocketRelationIdOrNull(sourcePlanPocketRecordId);
    if (sp == null || sp.isEmpty) return false;
    Map<String, dynamic>? rollbackRow;
    var rollbackIndex = -1;
    try {
      var rid = _tryResolveRecordIdFromCacheOnly(originalInput);
      if (rid == null ||
          rid.isEmpty ||
          !DatabaseService._isLikelyPocketBaseRowId(rid)) {
        final resolved = await _resolveRecordIdForRestUrl(originalInput);
        rid = DatabaseService._isLikelyPocketBaseRowId(resolved)
            ? resolved
            : null;
      }
      if (rid == null || rid.isEmpty) {
        DatabaseService._log(
          'patchRecordSourcePlanLink: no PocketBase id yet for recordId=$originalInput',
        );
        return false;
      }
      DatabaseService._log(
        'PATCH_ID_TRACE: patchRecordSourcePlanLink pb id=$rid',
      );
      final pc = await _resolveCategoryIdFromSourcePlanPbId(sp);
      final shouldPatchCategory = _planLocalCategoryIdIsConcrete(pc);
      final updates = <String, dynamic>{'source_plan_id': sp};
      if (shouldPatchCategory && pc != null) {
        updates['category_id'] = _recordCategoryBusinessPkForApi(pc);
      }
      rollbackIndex = _indexOfCachedRecordRow(rid, originalInput);
      if (rollbackIndex >= 0) {
        rollbackRow = Map<String, dynamic>.from(
          _cachedFlatRecords[rollbackIndex],
        );
        final row = _cachedFlatRecords[rollbackIndex];
        row['source_plan_id'] = sp;
        if (shouldPatchCategory && pc != null) {
          row['category_id'] = updates['category_id'];
        }
        _notifyTimelineAfterRecordCacheMutation();
      }
      final patchCode = await _patchRecordsRowWith404Recovery(
        originalQueryId: originalInput,
        restId: rid,
        fields: _nocoFieldsForPatch(Map<String, dynamic>.from(updates)),
      );
      if (patchCode == 404) {
        if (rollbackRow != null && rollbackIndex >= 0) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
        _purgeGhostRecordById(rid);
        return false;
      }
      if (patchCode < 200 || patchCode >= 300) {
        if (rollbackRow != null && rollbackIndex >= 0) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
        AppSnack.failed();
        return false;
      }
      _notifyTimelineAfterRecordCacheMutation();
      return true;
    } catch (e, st) {
      DatabaseService._log('patchRecordSourcePlanLink failed: $e');
      DatabaseService._log(st.toString());
      if (rollbackRow != null && rollbackIndex >= 0) {
        if (rollbackIndex < _cachedFlatRecords.length) {
          _cachedFlatRecords[rollbackIndex] = rollbackRow;
          _notifyTimelineAfterRecordCacheMutation();
        }
      }
      AppSnack.failed();
      return false;
    }
  }

  /// Alias for [updateRecord] (PocketBase row PATCH by record id).
  Future<TimelineRecord?> patchRecord({
    required String recordId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? categoryId,
    String? note,
    String? tags,
    List<Map<String, dynamic>>? checklist,
    bool syncSourcePlan = false,
    bool clearSourcePlan = false,
    String? sourcePlanPocketRecordId,
    bool bypassConflictCheck = false,
  }) => updateRecord(
    recordId: recordId,
    title: title,
    startTime: startTime,
    endTime: endTime,
    categoryId: categoryId,
    note: note,
    tags: tags,
    checklist: checklist,
    syncSourcePlan: syncSourcePlan,
    clearSourcePlan: clearSourcePlan,
    sourcePlanPocketRecordId: sourcePlanPocketRecordId,
    bypassConflictCheck: bypassConflictCheck,
  );

  Future<bool> deleteRecordByDocId(String recordId) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return false;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return false;
    final businessId = _outboxBusinessIdForRecord(originalInput);
    final delKeys = _collectRecordKeysFromCache(originalInput);
    for (final k in delKeys) {
      if (k.isNotEmpty) _optimisticDeletedKeys.add(k);
    }
    _notifyTimelineAfterRecordCacheMutation();

    final shadowRid = _tryResolveRecordIdFromCacheOnly(originalInput);
    if (shadowRid != null &&
        DatabaseService._isLikelyPocketBaseRowId(shadowRid)) {
      unawaited(
        _deleteRecordNetworkPhase(
          originalInput: originalInput,
          resolvedPbId: shadowRid,
          businessId: businessId,
          delKeys: delKeys,
        ).catchError((Object e, StackTrace st) async {
          DatabaseService._log('deleteRecordByDocId shadow async: $e');
          DatabaseService._log(st.toString());
          if (e is ClientException) {
            final code = e.statusCode;
            if (code == 401 || code == 403) {
              await _enqueueRecordDeleteMutation(
                originalInput: originalInput,
                businessId: businessId,
                pocketBaseId: shadowRid,
                error: code,
                syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
              );
              offlineSync.setAuthPaused(true, message: 'HTTP $code');
              return true;
            }
            if (_recordMutationRetriableHttpCode(code)) {
              await _enqueueRecordDeleteMutation(
                originalInput: originalInput,
                businessId: businessId,
                pocketBaseId: shadowRid,
                error: code,
              );
              offlineSync.setConnectivityOffline(true);
              return true;
            }
          } else if (_recordMutationRetriableHttpCode(0)) {
            await _enqueueRecordDeleteMutation(
              originalInput: originalInput,
              businessId: businessId,
              pocketBaseId: shadowRid,
              error: e,
            );
            offlineSync.setConnectivityOffline(true);
            return true;
          }
          for (final k in delKeys) {
            _optimisticDeletedKeys.remove(k);
          }
          _notifyTimelineAfterRecordCacheMutation();
          if (e is ClientException) {
            _snackDeleteHttpFailure(e.statusCode);
          } else {
            AppSnack.show(
              t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
              error: true,
            );
          }
          return false;
        }),
      );
      return true;
    }

    try {
      final rid = await _resolveRecordIdForStopOrDelete(originalInput);
      return await _deleteRecordNetworkPhase(
        originalInput: originalInput,
        resolvedPbId: rid,
        businessId: businessId,
        delKeys: delKeys,
      );
    } on LegacyIdResolutionException catch (e, st) {
      DatabaseService._log('deleteRecordByDocId: $e');
      DatabaseService._log(st.toString());
      await _enqueueRecordDeleteMutation(
        originalInput: originalInput,
        businessId: businessId,
        error: e,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    } on ClientException catch (e, st) {
      DatabaseService._log('deleteRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        await _enqueueRecordDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          error: code,
          syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        _snackDeleteHttpFailure(code);
        return true;
      }
      if (_recordMutationRetriableHttpCode(code)) {
        await _enqueueRecordDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      _snackDeleteHttpFailure(code);
      return false;
    } catch (e, st) {
      DatabaseService._log('deleteRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      if (_recordMutationRetriableHttpCode(0)) {
        await _enqueueRecordDeleteMutation(
          originalInput: originalInput,
          businessId: businessId,
          error: e,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      for (final k in delKeys) {
        _optimisticDeletedKeys.remove(k);
      }
      _notifyTimelineAfterRecordCacheMutation();
      AppSnack.show(
        t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
        error: true,
      );
      return false;
    }
  }

  Future<void> deleteRecord(String recordId) async {
    await deleteRecordByDocId(recordId);
  }

  /// PocketBase PATCH stop after [resolvedPbId] is known (shadow or awaited resolve).
  Future<bool> _patchStopRecordNetworkPhase(
    String originalInput,
    String resolvedPbId,
  ) async {
    final nowIso = DatabaseService.getPlanetaryNow().toUtc().toIso8601String();
    DatabaseService._log(
      'PATCH_ID_TRACE: stopRecordByDocId pb id=$resolvedPbId',
    );
    final stopFields = _nocoFieldsForPatch(<String, dynamic>{
      'end_time': nowIso,
      'status': 'stopped',
    });
    final stopCode = await _patchRecordsRowWith404Recovery(
      originalQueryId: originalInput,
      restId: resolvedPbId,
      fields: stopFields,
      debugPbClientException: true,
    );
    if (stopCode == 404) {
      _purgeGhostRecordById(resolvedPbId);
      _clearOptimisticStopKeysForRecord(originalInput);
      if (_lastRecordsPatchSkippedDeadLetter) {
        _brainSnackError(t(currentLocale.value, 'error_stop_dead_letter_skip'));
      } else {
        _snackStopHttpFailure(404);
      }
      return false;
    }
    final ok = stopCode >= 200 && stopCode < 300;
    if (ok) {
      _clearOptimisticStopKeysForRecord(originalInput);
      AppSnack.updated();
      unawaited(offlineSync.refreshPendingCount());
      return true;
    }
    if (stopCode == 401 || stopCode == 403) {
      await _enqueueStopPatchMutation(
        originalInput: originalInput,
        pocketBaseId: resolvedPbId,
        error: stopCode,
        syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
      );
      offlineSync.setAuthPaused(true, message: 'HTTP $stopCode');
      _snackStopHttpFailure(stopCode);
      return true;
    }
    if (_recordMutationRetriableHttpCode(stopCode)) {
      await _enqueueStopPatchMutation(
        originalInput: originalInput,
        pocketBaseId: resolvedPbId,
        error: stopCode,
      );
      offlineSync.setConnectivityOffline(true);
      return true;
    }
    _clearOptimisticStopKeysForRecord(originalInput);
    _notifyTimelineAfterRecordCacheMutation();
    _snackStopHttpFailure(stopCode);
    return false;
  }

  /// Stops a record via PocketBase `records` PATCH — the argument must resolve to PB row **`id`** (15-char).
  /// Legacy column `record_id` (UUID) is mapped internally but must not be passed from UI as the primary key.
  /// Returns **`true` only** for **2xx** (not 404). Optimistic UI reverts when the request fails.
  Future<bool> stopRecordByDocId(String recordId) async {
    if (!_isInitialized) {
      debugPrint(
        '[ABORT_REASON] Exiting early because: !_isInitialized (_isInitialized=$_isInitialized). No PATCH.',
      );
      _brainSnackError(t(currentLocale.value, 'error_stop_brain_not_ready'));
      return false;
    }
    if (!_hasAuthenticatedUserId) {
      debugPrint(
        '[ABORT_REASON] Exiting early because: PocketBase auth record id is missing (_isInitialized=$_isInitialized, currentProfileId=$currentProfileId). No PATCH.',
      );
      _brainSnackError(t(currentLocale.value, 'error_stop_brain_not_ready'));
      return false;
    }
    var rid = recordId.trim();
    if (rid.isEmpty) {
      debugPrint(
        '[ABORT_REASON] Exiting early because: trimmed recordId is empty. No PATCH.',
      );
      _brainSnackError(t(currentLocale.value, 'error_stop_empty_doc_id'));
      return false;
    }
    if (_stopRecordInFlightKeys.contains(rid)) {
      return false;
    }
    _stopRecordInFlightKeys.add(rid);
    final originalInput = rid;
    _applyOptimisticStopUiSnapshot(originalInput);

    final shadowRid = _tryResolveRecordIdFromCacheOnly(originalInput);
    if (shadowRid != null &&
        DatabaseService._isLikelyPocketBaseRowId(shadowRid)) {
      unawaited(
        _patchStopRecordNetworkPhase(originalInput, shadowRid)
            .catchError((Object e, StackTrace st) async {
              DatabaseService._log('stopRecordByDocId shadow async: $e');
              DatabaseService._log(st.toString());
              if (e is ClientException) {
                final code = e.statusCode;
                if (code == 401 || code == 403) {
                  await _enqueueStopPatchMutation(
                    originalInput: originalInput,
                    pocketBaseId: shadowRid,
                    error: code,
                    syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
                  );
                  offlineSync.setAuthPaused(true, message: 'HTTP $code');
                  _snackStopHttpFailure(code);
                  return true;
                }
                if (_recordMutationRetriableHttpCode(code)) {
                  await _enqueueStopPatchMutation(
                    originalInput: originalInput,
                    pocketBaseId: shadowRid,
                    error: code,
                  );
                  offlineSync.setConnectivityOffline(true);
                  return true;
                }
              } else if (_recordMutationRetriableHttpCode(0)) {
                await _enqueueStopPatchMutation(
                  originalInput: originalInput,
                  pocketBaseId: shadowRid,
                  error: e,
                );
                offlineSync.setConnectivityOffline(true);
                return true;
              }
              _clearOptimisticStopKeysForRecord(originalInput);
              _notifyTimelineAfterRecordCacheMutation();
              if (e is ClientException) {
                _snackStopHttpFailure(e.statusCode);
              } else {
                _brainSnackError(
                  t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
                );
              }
              return false;
            })
            .whenComplete(() {
              _stopRecordInFlightKeys.remove(originalInput);
            }),
      );
      return true;
    }

    try {
      rid = await _resolveRecordIdForStopOrDelete(rid);
      if (!DatabaseService._isLikelyPocketBaseRowId(rid)) {
        debugPrint(
          '[ABORT_REASON] After resolve, rid="$rid" is not a PocketBase row id segment (fails _isLikelyPocketBaseRowId). Throwing LegacyIdResolutionException.',
        );
        throw LegacyIdResolutionException(originalInput);
      }
      return await _patchStopRecordNetworkPhase(originalInput, rid);
    } on LegacyIdResolutionException catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint(
        '[ABORT_REASON] LegacyIdResolutionException — could not map input to PB row id: $e',
      );
      DatabaseService._log('stopRecordByDocId: $e');
      DatabaseService._log(st.toString());
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _brainSnackError(t(currentLocale.value, 'error_stop_id_unresolved'));
      return false;
    } on ClientException catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint(
        '[ABORT_REASON] stopRecordByDocId: PocketBase ClientException status=${e.statusCode} $e',
      );
      DatabaseService._log('stopRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        await _enqueueStopPatchMutation(
          originalInput: originalInput,
          pocketBaseId: rid,
          error: code,
          syncStatus: RecordMutationOutbox.syncStatusPausedAuth,
        );
        offlineSync.setAuthPaused(true, message: 'HTTP $code');
        _snackStopHttpFailure(code);
        return true;
      }
      if (_recordMutationRetriableHttpCode(code)) {
        await _enqueueStopPatchMutation(
          originalInput: originalInput,
          pocketBaseId: rid,
          error: code,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _snackStopHttpFailure(code);
      return false;
    } catch (e, st) {
      debugPrint('UI ERROR: $e');
      debugPrint(
        '[ABORT_REASON] stopRecordByDocId: unexpected exception before/after PATCH: $e',
      );
      DatabaseService._log('stopRecordByDocId failed: $e');
      DatabaseService._log(st.toString());
      if (_recordMutationRetriableHttpCode(0)) {
        await _enqueueStopPatchMutation(
          originalInput: originalInput,
          pocketBaseId: rid,
          error: e,
        );
        offlineSync.setConnectivityOffline(true);
        return true;
      }
      _clearOptimisticStopKeysForRecord(originalInput);
      _notifyTimelineAfterRecordCacheMutation();
      _brainSnackError(
        t(currentLocale.value, 'error_prefix').replaceAll('%s', '$e'),
      );
      return false;
    } finally {
      _stopRecordInFlightKeys.remove(originalInput);
    }
  }

  /// Alias for [stopRecordByDocId] (Sacred Law / singleton stop).
  Future<bool> stopRecord(String recordId) async => stopRecordByDocId(recordId);

  Future<void> updateRecordChecklist(
    String recordId,
    List<Map<String, dynamic>> checklist,
  ) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return;
    final originalInput = recordId.trim();
    if (originalInput.isEmpty) return;
    unawaited(updateRecord(recordId: originalInput, checklist: checklist));
  }
}
