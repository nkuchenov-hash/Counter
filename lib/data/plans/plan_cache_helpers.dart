part of '../database_service.dart';

double titleSimilarityForPlanLink(String a, String b) {
    final na = a.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final nb = b.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;
    final dist = DatabaseService._levenshteinDistance(na, nb);
    final denom = max(na.length, nb.length);
    if (denom <= 0) return 0;
    return 1.0 - dist / denom;
  }

Set<String> _planLinkTokenSet(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return {};
    return t
        .split(RegExp(r'[\s,.;:!?\-–—/\\]+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 2)
        .toSet();
  }

  /// Shared significant words / min(|A|,|B|) — good for "Уборка квартиры" vs "Уборка дома".
double planLinkWordOverlapRatio(String a, String b) {
    final ta = _planLinkTokenSet(a);
    final tb = _planLinkTokenSet(b);
    if (ta.isEmpty || tb.isEmpty) return 0;
    var inter = 0;
    for (final w in ta) {
      if (tb.contains(w)) inter++;
    }
    if (inter == 0) return 0;
    return inter / min(ta.length, tb.length);
  }

  /// Softer than pure Levenshtein: words + substring hint + legacy ratio.
double titlePlanLinkScore(String a, String b) {
    final lev = titleSimilarityForPlanLink(a, b);
    final word = planLinkWordOverlapRatio(a, b);
    final na = a.trim().toLowerCase();
    final nb = b.trim().toLowerCase();
    var contain = 0.0;
    if (na.isNotEmpty && nb.isNotEmpty) {
      if (na.contains(nb) || nb.contains(na)) contain = 0.72;
    }
    return max(lev, max(word, contain));
  }

extension PlanCacheProjectionExtension on DatabaseService {
  PlanningTask _preferConfirmedPlanningTask(PlanningTask a, PlanningTask b) {
    final aOpt = _isOptimisticPlanningTask(a);
    final bOpt = _isOptimisticPlanningTask(b);
    if (aOpt && !bOpt) return b;
    if (bOpt && !aOpt) return a;
    final aPb = (a.pocketRecordId?.trim() ?? '').length == 15;
    final bPb = (b.pocketRecordId?.trim() ?? '').length == 15;
    if (aPb && !bPb) return a;
    if (bPb && !aPb) return b;
    return b;
  }

  List<PlanningTask> _dedupePlanningTasksByBusinessId(
    List<PlanningTask> tasks,
  ) {
    final byBiz = <String, PlanningTask>{};
    final noBiz = <PlanningTask>[];
    for (final t in tasks) {
      final biz = _planBusinessUuidFromTask(t);
      if (biz == null || biz.isEmpty) {
        noBiz.add(t);
        continue;
      }
      final existing = byBiz[biz];
      byBiz[biz] = existing == null
          ? t
          : _preferConfirmedPlanningTask(existing, t);
    }
    return [...byBiz.values, ...noBiz];
  }
  String planningStableIdentityKey(PlanningTask task) {
    final backend = task.planRowIdForBackend.trim();
    if (backend.startsWith('virt-')) return backend;
    if (backend.startsWith('optimistic-')) return backend;
    final pb = task.pocketRecordId?.trim() ?? '';
    if (DatabaseService._isLikelyPocketBaseRowId(pb)) return 'pb:$pb';
    final biz = _planBusinessUuidFromTask(task);
    if (biz != null && biz.isNotEmpty) return 'plan:$biz';
    if (backend.isNotEmpty) return 'row:$backend';
    return 'legacy:${task.id}';
  }
  void _scrubJitVirtualRowsFromUserCache() {
    final before = _allPlansUserCache.length;
    _allPlansUserCache = [
      for (final t in _allPlansUserCache)
        if (!_isJitVirtualPlanningTask(t)) t,
    ];
    final removed = before - _allPlansUserCache.length;
    if (removed > 0 && !kReleaseMode) {
      planDupTrace('source=cache event=scrubVirt removed=$removed');
    }
  }

  void _logPlanDupTraceLayer({
    required String source,
    required List<PlanningTask> tasks,
    String? dayKey,
  }) {
    if (kReleaseMode) return;
    final systemIds = tasks.map((t) => t.planRowIdForBackend).toSet();
    final planIds = <String>{};
    for (final t in tasks) {
      final biz = _planBusinessUuidFromTask(t);
      if (biz != null && biz.isNotEmpty) planIds.add(biz);
      final pb = t.pocketRecordId?.trim();
      if (pb != null && pb.isNotEmpty) planIds.add(pb);
    }
    final dayPart = dayKey != null ? ' day=$dayKey' : '';
    planDupTrace(
      'source=$source$dayPart count=${tasks.length} '
      'uniqueSystemIds=${systemIds.length} uniquePlanIds=${planIds.length}',
    );
    final byKey = <String, List<PlanningTask>>{};
    for (final t in tasks) {
      final k = planningStableIdentityKey(t);
      byKey.putIfAbsent(k, () => []).add(t);
    }
    for (final e in byKey.entries) {
      if (e.value.length < 2) continue;
      final titles = e.value.map((t) => t.title.trim()).toSet().join('|');
      final times = e.value
          .map((t) {
            final s = t.startTime;
            final en = t.endDateTime;
            if (s == null) return 'open';
            final sh =
                '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
            final eh = en != null
                ? '${en.hour.toString().padLeft(2, '0')}:${en.minute.toString().padLeft(2, '0')}'
                : 'open';
            return '$sh-$eh';
          })
          .join('|');
      final origins = e.value.map((t) => t.planRowIdForBackend).join('|');
      planDupTrace(
        'duplicate key=${e.key} titles=$titles times=$times origins=$origins',
      );
    }
  }

  void scrubJitVirtualPlansFromUserCache() {
    _scrubJitVirtualRowsFromUserCache();
    _allPlansUserCache = scrubPlanningTasksForLocalCache(_allPlansUserCache);
  }

  /// Remove `virt-*` rows and collapse duplicate stable identities (local cache only).
  List<PlanningTask> scrubPlanningTasksForLocalCache(List<PlanningTask> tasks) {
    if (tasks.isEmpty) return tasks;
    final noVirt = [
      for (final t in tasks)
        if (!_isJitVirtualPlanningTask(t)) t,
    ];
    return dedupePlanningTasksForDisplay(noVirt, traceSource: 'cacheScrub');
  }

  Future<void> scrubPersistedPlanningDayCachesOnRestore() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final prefix = '${_scopedDataCacheKey('cache_plans_day_v1')}_';
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keys) {
        final dayKey = key.substring(prefix.length);
        if (dayKey.length < 10) continue;
        final raw = prefs.getString(key);
        if (raw == null || raw.trim().isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        final tasks = <PlanningTask>[];
        for (final e in decoded) {
          if (e is! Map) continue;
          try {
            tasks.add(
              _planningTaskFromOfflineDayMap(Map<String, dynamic>.from(e)),
            );
          } catch (_) {}
        }
        final scrubbed = scrubPlanningTasksForLocalCache(tasks);
        if (scrubbed.length == tasks.length) continue;
        await prefs.setString(
          key,
          jsonEncode(
            scrubbed.map(_planningTaskToDayCacheMap).toList(growable: false),
          ),
        );
        if (!kReleaseMode) {
          planDupTrace(
            'source=dayCacheRestore day=$dayKey '
            'removed=${tasks.length - scrubbed.length}',
          );
        }
      }
    } catch (_) {}
  }

  /// Defensive de-dupe for Planning list modes (Tags/Category/Custom/Time).
  List<PlanningTask> dedupePlanningTasksForDisplay(
    List<PlanningTask> tasks, {
    String? traceSource,
    String? dayKey,
  }) {
    if (tasks.length < 2) return tasks;

    final materializedInstanceKeys = <String>{};
    for (final t in tasks) {
      _collectMaterializedRecurrenceSuppressionKeys(
        t,
        materializedInstanceKeys,
      );
    }

    final byKey = <String, PlanningTask>{};
    var deduped = 0;
    for (final t in tasks) {
      if (_isJitVirtualPlanningTask(t)) {
        final row = t.planRowId?.trim() ?? t.planRowIdForBackend;
        final m = RegExp(r'^virt-(.+)-(\d{4}-\d{2}-\d{2})$').firstMatch(row);
        if (m != null) {
          final parent = m.group(1)?.trim() ?? '';
          final dk = m.group(2)?.trim() ?? '';
          if (parent.isNotEmpty &&
              dk.isNotEmpty &&
              (materializedInstanceKeys.contains('$parent|$dk') ||
                  materializedInstanceKeys.contains('biz:$parent|$dk'))) {
            deduped++;
            continue;
          }
        }
      }
      final key = planningStableIdentityKey(t);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = t;
      } else {
        deduped++;
        byKey[key] = _preferConfirmedPlanningTask(existing, t);
      }
    }
    final out = _dedupePlanningTasksByBusinessId(byKey.values.toList());
    out.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      final at = a.startTime;
      final bt = b.startTime;
      if (at != bt) {
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      }
      return a.title.compareTo(b.title);
    });
    if (deduped > 0 && traceSource != null) {
      planDupTrace(
        'source=$traceSource event=dedupe removed=$deduped '
        'before=${tasks.length} after=${out.length}',
      );
    }
    if (traceSource != null) {
      _logPlanDupTraceLayer(source: traceSource, tasks: out, dayKey: dayKey);
    }
    return out;
  }
}
