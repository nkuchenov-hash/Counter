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
  /// Stable business **plan_id** (UUID) for merge/dedupe — not PocketBase system id.
  String? _planBusinessUuidFromTask(PlanningTask task) {
    final row = task.planRowId?.trim() ?? '';
    if (row.isNotEmpty) {
      if (row.startsWith('optimistic-')) {
        final id = row.substring('optimistic-'.length).trim();
        return id.isEmpty ? null : id;
      }
      if (!row.startsWith('virt-')) return row;
    }
    final pr = task.pocketRecordId?.trim() ?? '';
    if (pr.startsWith('optimistic-')) {
      final id = pr.substring('optimistic-'.length).trim();
      return id.isEmpty ? null : id;
    }
    return null;
  }

  bool _isOptimisticPlanningTask(PlanningTask task) {
    final pr = task.pocketRecordId?.trim() ?? '';
    if (pr.startsWith('optimistic-')) return true;
    final row = task.planRowId?.trim() ?? '';
    return row.startsWith('optimistic-');
  }

  void _purgeOptimisticPlanRowsFromUserCache(String businessPlanId) {
    final biz = businessPlanId.trim();
    if (biz.isEmpty) return;
    _allPlansUserCache = [
      for (final t in _allPlansUserCache)
        if (!(_isOptimisticPlanningTask(t) &&
            _planBusinessUuidFromTask(t) == biz))
          t,
    ];
  }

  void _upsertPlanInUserCache(PlanningTask task) {
    final pid = task.planRowIdForBackend.trim();
    if (pid.isEmpty) return;
    if (_isJitVirtualPlanningTask(task)) {
      if (!kReleaseMode) {
        planDupTrace(
          'source=cache event=skipVirtUpsert key=$pid title=${task.title.trim()}',
        );
      }
      return;
    }
    final bizId = _planBusinessUuidFromTask(task);
    var i = -1;
    for (var j = 0; j < _allPlansUserCache.length; j++) {
      final t = _allPlansUserCache[j];
      final tPid = t.planRowIdForBackend.trim();
      if (tPid == pid) {
        i = j;
        break;
      }
      if (bizId != null &&
          bizId.isNotEmpty &&
          _planBusinessUuidFromTask(t) == bizId) {
        i = j;
        break;
      }
    }
    if (i >= 0) {
      _allPlansUserCache[i] = task;
    } else {
      _allPlansUserCache.add(task);
    }
    if (bizId != null && bizId.isNotEmpty && !_isOptimisticPlanningTask(task)) {
      _purgeOptimisticPlanRowsFromUserCache(bizId);
    }
  }

  void _removePlanFromUserCache(String planRowId) {
    final p = planRowId.trim();
    if (p.isEmpty) return;
    _allPlansUserCache = [
      for (final t in _allPlansUserCache)
        if (t.planRowIdForBackend.trim() != p) t,
    ];
  }

  List<PlanningTask> _filterBacklogFromAll(
    List<PlanningTask> all, {
    int? categoryId,
    bool includeCompleted = false,
  }) {
    final out = <PlanningTask>[];
    for (final t in all) {
      final pid = t.planRowIdForBackend.trim();
      if (pid.startsWith('optimistic-') || pid.startsWith('virt-')) continue;
      if (!includeCompleted && t.isDone) continue;
      if (t.startTime != null) continue;
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) continue;
      if (t.isBacklogChildItem) continue;
      final dk = t.dateKey.trim();
      if (dk.length >= 10) continue;
      if (categoryId != null && t.categoryId != categoryId) continue;
      out.add(t);
    }
    out.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return a.title.compareTo(b.title);
    });
    return out;
  }

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

  // --- Offline Planning day-cache codec + SharedPreferences persistence ---

  Map<String, dynamic> _planningTaskToDayCacheMap(PlanningTask t) {
    return <String, dynamic>{
      'pocketRecordId': t.pocketRecordId,
      'plan_row_id': t.planRowId,
      'id': t.id,
      'title': t.title,
      'categoryId': t.categoryId,
      'category_id': t.categoryId,
      'is_done': t.isDone,
      'isDone': t.isDone,
      'dateKey': t.dateKey,
      'endDateKey': t.endDateKey,
      'order': t.order,
      if (t.startUtcInstant != null) ...<String, dynamic>{
        'start_utc': t.startUtcInstant!.toUtc().toIso8601String(),
        'start_time': t.startUtcInstant!.toUtc().toIso8601String(),
      },
      if (t.endUtcInstant != null)
        'end_utc': t.endUtcInstant!.toUtc().toIso8601String(),
      if (t.startTime != null)
        'start_wall': <int>[
          t.startTime!.year,
          t.startTime!.month,
          t.startTime!.day,
          t.startTime!.hour,
          t.startTime!.minute,
          t.startTime!.second,
        ],
      if (t.endDateTime != null)
        'end_wall': <int>[
          t.endDateTime!.year,
          t.endDateTime!.month,
          t.endDateTime!.day,
          t.endDateTime!.hour,
          t.endDateTime!.minute,
          t.endDateTime!.second,
        ],
      'checklist': t.checklist,
      'notes_plain': t.notesPlain,
      'notes_delta': t.notesDeltaJson,
      if (t.parentPlanPocketId != null &&
          t.parentPlanPocketId!.trim().isNotEmpty)
        'parent_plan_pocket_id': t.parentPlanPocketId!.trim(),
      if (t.parentPlanId != null) 'parent_plan_id': t.parentPlanId,
      'isSynced': t.isSynced,
      if (t.initialDateKey != null && t.initialDateKey!.trim().length >= 10)
        'initial_date_key': t.initialDateKey!.trim().substring(0, 10),
      'is_postponed': t.isPostponed,
      if (t.rrule != null && t.rrule!.trim().isNotEmpty) 'rrule': t.rrule,
      if (t.exceptionDates.isNotEmpty) 'exception_dates': t.exceptionDates,
      if (t.reminderOffset != null) 'reminder_offset': t.reminderOffset,
      if (t.recurrenceInstanceDateKey != null &&
          t.recurrenceInstanceDateKey!.trim().length >= 10)
        'recurrence_instance_date_key': t.recurrenceInstanceDateKey!
            .trim()
            .substring(0, 10),
      'tags': <Map<String, dynamic>>[
        for (final g in t.tags)
          <String, dynamic>{
            'tag_id': g.tagId,
            'name': g.name,
            'pocket_id': g.pbRecordId,
            'sort_order': g.sortOrder,
            'domain': g.domain,
          },
      ],
    };
  }

  PlanningTask _planningTaskFromOfflineDayMap(Map<String, dynamic> m) {
    DateTime? wallFromList(dynamic raw) {
      if (raw is! List || raw.length < 5) return null;
      return DateTime(
        (raw[0] as num).toInt(),
        (raw[1] as num).toInt(),
        (raw[2] as num).toInt(),
        (raw[3] as num).toInt(),
        (raw[4] as num).toInt(),
        raw.length > 5 ? (raw[5] as num).toInt() : 0,
      );
    }

    var tags = const <Tag>[];
    final tr = m['tags'];
    if (tr is List) {
      tags = [
        for (final e in tr)
          if (e is Map)
            Tag(
              tagId: int.tryParse((e['tag_id'] ?? '').toString()) ?? 0,
              name: (e['name'] ?? '').toString(),
              pbRecordId: e['pocket_id']?.toString(),
              sortOrder: int.tryParse((e['sort_order'] ?? '0').toString()) ?? 0,
              domain: e['domain']?.toString().trim().toLowerCase() == 'list'
                  ? 'list'
                  : 'plan',
            ),
      ];
    }
    final deltaRaw = m['notes_delta'];
    String? deltaJsonStr;
    if (deltaRaw != null) {
      if (deltaRaw is String) {
        final s = deltaRaw.trim();
        deltaJsonStr = s.isEmpty ? null : s;
      } else {
        try {
          deltaJsonStr = jsonEncode(deltaRaw);
        } catch (_) {
          deltaJsonStr = null;
        }
      }
    }
    final startUtcRaw = m['start_utc']?.toString();
    final endUtcRaw = m['end_utc']?.toString();
    var startUtc = startUtcRaw != null && startUtcRaw.trim().isNotEmpty
        ? DateTime.tryParse(startUtcRaw.trim())?.toUtc()
        : null;
    if (startUtc == null) {
      final startTimeIso = m['start_time']?.toString().trim();
      if (startTimeIso != null && startTimeIso.isNotEmpty) {
        startUtc = DateTime.tryParse(startTimeIso)?.toUtc();
      }
    }
    final endUtc = endUtcRaw != null && endUtcRaw.trim().isNotEmpty
        ? DateTime.tryParse(endUtcRaw.trim())?.toUtc()
        : null;
    var task = PlanningTask(
      id: int.tryParse((m['id'] ?? '').toString()) ?? 0,
      planRowId: m['plan_row_id']?.toString(),
      pocketRecordId: m['pocketRecordId']?.toString(),
      title: (m['title'] ?? '').toString(),
      categoryId:
          int.tryParse(
            (m['category_id'] ?? m['categoryId'] ?? '0').toString(),
          ) ??
          0,
      isDone: _jsonBoolFromDynamic(m['is_done'] ?? m['isDone']),
      dateKey: (m['dateKey'] ?? '').toString(),
      order: int.tryParse((m['order'] ?? '0').toString()) ?? 0,
      startTime: wallFromList(m['start_wall']),
      endDateTime: wallFromList(m['end_wall']),
      endDateKey: (m['endDateKey'] ?? m['dateKey'] ?? '').toString(),
      checklist: parseChecklistFromNocoList(m['checklist']),
      notesPlain: m['notes_plain']?.toString() ?? m['note']?.toString(),
      notesDeltaJson: deltaJsonStr,
      parentPlanPocketId: (m['parent_plan_pocket_id'] ?? m['parent_plan_id'])
          ?.toString()
          .trim(),
      parentPlanId: m['parent_plan_id'] == null
          ? null
          : int.tryParse(m['parent_plan_id'].toString()),
      tags: tags,
      isSynced: _jsonBoolFromDynamic(m['isSynced'] ?? true),
      initialDateKey: _normPlanInitialDateKey(
        m['initial_date_key'] ?? m['initialDateKey'],
      ),
      isPostponed: _jsonBoolFromDynamic(
        m['is_postponed'] ?? m['isPostponed'] ?? false,
      ),
      rrule: () {
        final s = (m['rrule'] ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }(),
      exceptionDates: _parsePlanExceptionDatesForOffline(m['exception_dates']),
      reminderOffset: int.tryParse((m['reminder_offset'] ?? '').toString()),
      recurrenceInstanceDateKey: _normPlanRecurrenceInstanceKey(
        m['recurrence_instance_date_key'] ?? m['recurrenceInstanceDateKey'],
      ),
      startUtcInstant: startUtc,
      endUtcInstant: endUtc,
    );
    if (startUtc != null) {
      task = _reprojectPlanningTaskWallTimes(task);
    }
    return task;
  }

  Future<void> _persistPlanningTasksDayCache(
    String targetDayStr,
    List<PlanningTask> plans,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final scrubbed = scrubPlanningTasksForLocalCache(plans);
      final payload = scrubbed
          .map(_planningTaskToDayCacheMap)
          .toList(growable: false);
      await prefs.setString(
        '${_scopedDataCacheKey('cache_plans_day_v1')}_$targetDayStr',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<List<PlanningTask>> _loadPlanningTasksDayCache(
    String targetDayStr,
  ) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(
        '${_scopedDataCacheKey('cache_plans_day_v1')}_$targetDayStr',
      );
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <PlanningTask>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        out.add(_planningTaskFromOfflineDayMap(Map<String, dynamic>.from(e)));
      }
      return scrubPlanningTasksForLocalCache(out);
    } catch (_) {
      return [];
    }
  }
}
