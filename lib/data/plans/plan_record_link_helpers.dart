part of '../database_service.dart';

/// Plan-to-record source linkage, actual-time aggregation, and plan-vs-fact day stats.

const String _recordLinkSuggestionsEnabledPref =
    'plans_record_link_suggestions_enabled';
const String _recordLinkSuggestionModePref =
    'plans_record_link_suggestion_mode';
const String _recordLinkSuggestionDismissedPref =
    'plans_record_link_suggestion_dismissed_record_ids';
const String _recordLinkSuggestionModeAsk = 'ask';
const String _recordLinkSuggestionModeAuto = 'auto';

extension PlanRecordLinkExtension on DatabaseService {
  /// One pass over [_cachedFlatRecords]: seconds tracked per plan PocketBase id on [wallCalendarDay]
  /// (same day bucketing as timeline). Includes optimistic end overlay; running rows use [getPlanetaryNow].
  Map<String, int> aggregateSourcePlanActualSecondsForWallCalendarDay(
    DateTime wallCalendarDay,
  ) {
    final out = <String, int>{};
    try {
      if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
        return out;
      }
      final targetDayStr =
          '${wallCalendarDay.year}-${_two(wallCalendarDay.month)}-${_two(wallCalendarDay.day)}';
      final ownerIds = _recordRowOwnerIdMatchSet();
      if (ownerIds.isEmpty) return out;

      void addFromMerged(Map<String, dynamic> merged) {
        final planId = DatabaseService.pocketRelationIdOrNull(
          merged['source_plan_id']?.toString(),
        );
        if (planId == null) return;
        final st = merged['startTime'] as DateTime?;
        if (st == null) return;
        var en = merged['endTime'] as DateTime?;
        if (en == null) {
          final stStr = merged['status']?.toString() ?? '';
          if (stStr == 'running') {
            en = DatabaseService.getPlanetaryNow();
          } else {
            return;
          }
        }
        final sec = en.difference(st).inSeconds;
        if (sec <= 0) return;
        out[planId] = (out[planId] ?? 0) + sec;
      }

      for (final row in _cachedFlatRecords) {
        if (_rowHasNonEmptyParent(row['parent_id'])) continue;
        if (_optimisticRowDeletedRaw(row)) continue;
        final rowUid = (row['user_id'] ?? '').toString().trim().toLowerCase();
        if (rowUid.isEmpty || !ownerIds.contains(rowUid)) continue;
        final stUtc = CategoryServiceExtension._parseDateTimeUtc(
          row['start_time'],
        );
        if (stUtc == null) continue;
        final recordDayStr = _timelineDeviceLocalDayKeyFromUtc(stUtc);
        if (recordDayStr != targetDayStr) continue;
        try {
          addFromMerged(_mergeOptimisticIntoRecordMap(_rowToRecordMap(row)));
        } catch (_) {}
      }
      final pend = _optimisticPendingStartRecordMap;
      if (pend != null) {
        final pDay = (pend['calendarDayStr'] ?? '').toString().trim();
        if (pDay == targetDayStr) {
          addFromMerged(Map<String, dynamic>.from(pend));
        }
      }
    } catch (_) {}
    return out;
  }

  /// Basic plan vs fact for [wallDate]: tasks **scheduled** that day vs records that day.
  ///
  /// [recordsForDay]: same list as the Stats timeline tab (duration within day + category rollups).
  Future<BasicDayStats> getBasicDayStats(
    DateTime wallDate, {
    required List<Map<String, dynamic>> recordsForDay,
  }) async {
    final dk = '${wallDate.year}-${_two(wallDate.month)}-${_two(wallDate.day)}';
    final all = await _fetchAllPlanningTasksForCurrentUser();
    final dayPlans = <PlanningTask>[];
    for (final t in all) {
      if (t.planRowIdForBackend.startsWith('optimistic-')) continue;
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
      if (t.startTime == null) continue;
      final taskDk =
          '${t.startTime!.year}-${_two(t.startTime!.month)}-${_two(t.startTime!.day)}';
      if (taskDk != dk) continue;
      dayPlans.add(t);
    }
    dayPlans.addAll(expandRecurringPlans(all, wallDate, wallDate));

    var planTimeSec = 0;
    final plannedSecByCat = <int, int>{};
    for (final t in dayPlans) {
      final sec = planningWallEstimateSeconds(t);
      if (sec != null && sec > 0) {
        planTimeSec += sec;
        plannedSecByCat[t.categoryId] =
            (plannedSecByCat[t.categoryId] ?? 0) + sec;
      }
    }

    final actualSecByCat = <int, int>{};
    var factTimeSec = 0;
    final linkedPlanIds = <String>{};
    final offset = settings.timezoneOffsetHours;
    final tz = settings.preferredTimeZone;
    for (final rec in recordsForDay) {
      final sec =
          CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
            rec,
            wallDate,
            offset,
            tz,
          );
      if (sec <= 0) continue;
      factTimeSec += sec;
      final cid =
          resolvedCategoryIdForRecord(rec) ??
          CategoryRule.uncategorizedSyntheticId;
      actualSecByCat[cid] = (actualSecByCat[cid] ?? 0) + sec;
      final sp = DatabaseService.pocketRelationIdOrNull(
        rec['source_plan_id']?.toString(),
      );
      if (sp != null && sp.isNotEmpty) {
        linkedPlanIds.add(sp);
      }
    }

    return BasicDayStats(
      planTaskCount: dayPlans.length,
      factDistinctPlansFromRecords: linkedPlanIds.length,
      planTimeSeconds: planTimeSec,
      factTimeSeconds: factTimeSec,
      plannedSecByCategory: plannedSecByCat,
      actualSecByCategory: actualSecByCat,
      plansScheduledThisDay: dayPlans,
    );
  }

  Future<SharedPreferences> _recordLinkSuggestionPrefs() =>
      SharedPreferences.getInstance();

  Future<bool> recordLinkSuggestionsEnabled() async {
    final prefs = await _recordLinkSuggestionPrefs();
    return prefs.getBool(_recordLinkSuggestionsEnabledPref) ?? true;
  }

  Future<String> recordLinkSuggestionMode() async {
    final prefs = await _recordLinkSuggestionPrefs();
    final raw = prefs.getString(_recordLinkSuggestionModePref);
    return raw == _recordLinkSuggestionModeAuto
        ? _recordLinkSuggestionModeAuto
        : _recordLinkSuggestionModeAsk;
  }

  Future<bool> recordLinkSuggestionDismissed(String recordBusinessId) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return true;
    final prefs = await _recordLinkSuggestionPrefs();
    return (prefs.getStringList(_recordLinkSuggestionDismissedPref) ??
            const <String>[])
        .contains(rid);
  }

  Future<void> dismissSourcePlanLinkSuggestion(String recordBusinessId) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return;
    final prefs = await _recordLinkSuggestionPrefs();
    final existing =
        prefs.getStringList(_recordLinkSuggestionDismissedPref) ?? <String>[];
    if (existing.contains(rid)) return;
    existing.add(rid);
    if (existing.length > 300) {
      existing.removeRange(0, existing.length - 300);
    }
    await prefs.setStringList(_recordLinkSuggestionDismissedPref, existing);
  }

  Future<void> disableSourcePlanLinkSuggestions() async {
    final prefs = await _recordLinkSuggestionPrefs();
    await prefs.setBool(_recordLinkSuggestionsEnabledPref, false);
  }

  /// Applies a suggestion after the primary record create has left its critical
  /// path. Dismissal is recorded before the PATCH, matching the historical UI
  /// behavior and preventing repeated prompts if a retry is needed later.
  Future<bool> acceptSourcePlanLinkSuggestion({
    required String recordBusinessId,
    required String planPocketRecordId,
  }) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return false;
    await dismissSourcePlanLinkSuggestion(rid);
    try {
      await primaryRecordWriteNetworkChain;
    } catch (_) {}
    return patchRecordSourcePlanLink(
      recordId: rid,
      sourcePlanPocketRecordId: planPocketRecordId,
    );
  }

  /// Owns enable/dismiss/mode thresholds and auto-link policy. A non-null
  /// result means the UI should ask the user; auto mode is resolved here.
  Future<SourcePlanLinkSuggestion?> prepareSourcePlanLinkSuggestionForFreeStart({
    required String recordTitle,
    required String wallDateKey,
    required String recordBusinessId,
  }) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return null;
    if (!await recordLinkSuggestionsEnabled()) return null;
    if (await recordLinkSuggestionDismissed(rid)) return null;

    final mode = await recordLinkSuggestionMode();
    final suggestion = await suggestSourcePlanForFreeStart(
      recordTitle: recordTitle,
      wallDateKey: wallDateKey,
      minSimilarity: mode == _recordLinkSuggestionModeAuto ? 0.92 : 0.72,
    );
    if (suggestion == null) return null;
    if (mode == _recordLinkSuggestionModeAuto) {
      await acceptSourcePlanLinkSuggestion(
        recordBusinessId: rid,
        planPocketRecordId: suggestion.planPocketRecordId,
      );
      return null;
    }
    return suggestion;
  }

  DateTime? _wallDateKeyToLocalDate(String dateKey) {
    if (dateKey.length < 10) return null;
    final y = int.tryParse(dateKey.substring(0, 4));
    final m = int.tryParse(dateKey.substring(5, 7));
    final d = int.tryParse(dateKey.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Heuristic: open plan on [wallDateKey] whose title matches [recordTitle] (word overlap + fuzzy).
  Future<SourcePlanLinkSuggestion?> suggestSourcePlanForFreeStart({
    required String recordTitle,
    required String wallDateKey,
    double minSimilarity = 0.42,
  }) async {
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    final parsed = getCleanTitleAndTags(recordTitle);
    final title = parsed.title.trim();
    if (title.isEmpty) return null;
    final day = _wallDateKeyToLocalDate(wallDateKey);
    if (day == null) return null;
    final plans = await _fetchPlanningTasksForDate(day);
    SourcePlanLinkSuggestion? best;
    var bestScore = 0.0;
    for (final p in plans) {
      if (p.isDone) continue;
      final pid = DatabaseService.pocketRelationIdOrNull(p.pocketRecordId);
      if (pid == null) continue;
      final score = titlePlanLinkScore(title, p.title);
      if (score > bestScore) {
        bestScore = score;
        best = SourcePlanLinkSuggestion(
          planPocketRecordId: pid,
          planTitle: p.title,
          similarity: score,
        );
      }
    }
    if (best == null || bestScore < minSimilarity) return null;
    return best;
  }

  /// True when [id] is a real category (not uncategorized / unset / create placeholder `-1`).
  bool _planLocalCategoryIdIsConcrete(int? id) {
    if (id == null) return false;
    if (id == 0) return false;
    if (id == CategoryRule.uncategorizedSyntheticId) return false;
    return true;
  }

  /// Cached plans only — for instant UI cache rows and Play/start-from-plan.
  int? _tryResolveCategoryIdFromSourcePlanPbIdSync(
    String planPbId, {
    String? planBusinessId,
  }) {
    final want = planPbId.trim();
    if (want.isEmpty) return null;
    final fromEdit = _findCachedPlanningTaskForEdit(
      want,
      planBusinessId: planBusinessId,
    );
    if (fromEdit != null &&
        _planLocalCategoryIdIsConcrete(fromEdit.categoryId)) {
      return fromEdit.categoryId;
    }
    for (final t in _tasksCache) {
      if (DatabaseService.pocketRelationIdOrNull(t.pocketRecordId) == want) {
        return _planLocalCategoryIdIsConcrete(t.categoryId)
            ? t.categoryId
            : null;
      }
    }
    for (final t in _allPlansUserCache) {
      if (DatabaseService.pocketRelationIdOrNull(t.pocketRecordId) == want) {
        return _planLocalCategoryIdIsConcrete(t.categoryId)
            ? t.categoryId
            : null;
      }
    }
    for (final m in _planningOptimisticByDateKey.values) {
      for (final t in m.values) {
        if (DatabaseService.pocketRelationIdOrNull(t.pocketRecordId) == want) {
          return _planLocalCategoryIdIsConcrete(t.categoryId)
              ? t.categoryId
              : null;
        }
      }
    }
    return null;
  }

  /// Fresh plan category for record create (Play). Brain cache wins over stale UI.
  int? resolveCurrentPlanCategoryForRecordStart({
    String? sourcePlanPocketRecordId,
    String? planBusinessId,
    int? uiCategoryId,
  }) {
    final planId = DatabaseService.pocketRelationIdOrNull(
      sourcePlanPocketRecordId,
    );
    if (planId == null) {
      return _planLocalCategoryIdIsConcrete(uiCategoryId) ? uiCategoryId : null;
    }
    final cached = _tryResolveCategoryIdFromSourcePlanPbIdSync(
      planId,
      planBusinessId: planBusinessId,
    );
    if (_planLocalCategoryIdIsConcrete(cached)) {
      if (uiCategoryId != null &&
          _planLocalCategoryIdIsConcrete(uiCategoryId) &&
          uiCategoryId != cached) {
        debugPrint(
          '[PLAN_START_CATEGORY_SYNC] stale UI category replaced with current plan category',
        );
      }
      return cached;
    }
    return _planLocalCategoryIdIsConcrete(uiCategoryId) ? uiCategoryId : null;
  }

  /// PocketBase **plans** row id → local [CategoryRule.id] for `records.category_id` inheritance.
  Future<int?> _resolveCategoryIdFromSourcePlanPbId(String? planPbIdRaw) async {
    final want = DatabaseService.pocketRelationIdOrNull(planPbIdRaw);
    if (want == null) return null;
    final cached = _tryResolveCategoryIdFromSourcePlanPbIdSync(
      want,
      planBusinessId: null,
    );
    if (cached != null) return cached;
    if (!_isInitialized || !_hasAuthenticatedUserId) return null;
    try {
      await ensurePocketBaseReady();
      if (_pbHttpBackoffActive) return null;
      final r = await _pb.collection(PbCollections.plans).getOne(want);
      final d = r.data;
      final cid = categoryIdFromRecordRow(<String, dynamic>{
        'category_id': d['category_id'],
      });
      return _planLocalCategoryIdIsConcrete(cid) ? cid : null;
    } catch (_) {
      return null;
    }
  }
}
