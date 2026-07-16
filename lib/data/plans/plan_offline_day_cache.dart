part of '../database_service.dart';

/// Serializes and hydrates profile-scoped per-day plan snapshots for offline use.
extension PlanOfflineDayCacheExtension on DatabaseService {
  /// Plans and Lists share the `plans.tags_link` relation but isolate chips by `tags.domain`.
  /// Use the full cached catalog when hydrating plan/list rows so plain `tags_link` ids
  /// can resolve whether the row is a dated plan (`plan`) or an undated list item (`list`).

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
