// Part of lib/data/models.dart — PlanningTask, PlanningBulkPatch, SourcePlanLinkSuggestion, AiParsedTaskHint.
// Split per ROADMAP Tier 4.2 (April 2026).
part of '../models.dart';

class AiParsedTaskHint {
  const AiParsedTaskHint({
    this.cleanedTitle,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.rawJson,
  });

  final String? cleanedTitle;
  final int? startHour;
  final int? startMinute;
  final int? endHour;
  final int? endMinute;
  final Map<String, dynamic>? rawJson;

  bool get hasClockStart =>
      startHour != null &&
      startMinute != null &&
      startHour! >= 0 &&
      startHour! <= 23 &&
      startMinute! >= 0 &&
      startMinute! <= 59;
}

class SourcePlanLinkSuggestion {
  const SourcePlanLinkSuggestion({
    required this.planPocketRecordId,
    required this.planTitle,
    required this.similarity,
  });

  final String planPocketRecordId;
  final String planTitle;
  final double similarity;
}

/// Planning task (intent / todo). Stored in plans.
class PlanningTask {
  PlanningTask({
    required this.id,
    this.planRowId,
    this.pocketRecordId,
    required this.title,
    required this.categoryId,
    this.isDone = false,
    required this.dateKey,
    this.order = 0,
    this.startTime,
    DateTime? date,
    this.endDateTime,
    String? endDateKey,
    this.checklist = const [],
    this.notesPlain,
    this.notesDeltaJson,
    this.parentPlanId,
    this.parentPlanPocketId,
    List<int>? subRecordIds,
    List<Tag>? tags,
    this.isSynced = true,
    /// Wall `YYYY-MM-DD`: audit anchor (commitment day). Set on create; preserved when postponing.
    this.initialDateKey,
    this.isPostponed = false,
    this.rrule,
    this.exceptionDates = const [],
    this.reminderOffset,
    this.recurrenceInstanceDateKey,
  })  : date = date ?? _dateFromDateKey(dateKey),
        endDateKey = endDateKey ?? (endDateTime != null ? _dateKeyFromDate(endDateTime) : dateKey),
        subRecordIds = subRecordIds ?? const [],
        tags = tags ?? const [];

  final int id;
  /// Business **plan_id** (UUID) inside Noco `fields` — never use as bulk PATCH outer `id`.
  final String? planRowId;

  /// PocketBase **plans** collection record id (replaces integer Noco id for CRUD).
  final String? pocketRecordId;

  /// Stable id for bulk delete / patch: PocketBase row id, else legacy Noco int as string.
  /// JIT [recurrenceInstanceDateKey] rows use `virt-…` [planRowId] so list merges stay unique.
  String get recordIdForBackend {
    final p = planRowId?.trim() ?? '';
    if (p.startsWith('virt-')) return p;
    final pb = pocketRecordId?.trim() ?? '';
    if (pb.isNotEmpty) return pb;
    if (id > 0) return id.toString();
    return p;
  }

  /// Stable plan row id for PocketBase CRUD (`pocketRecordId`, else legacy int / `planRowId`).
  /// Stays `optimistic-…` for optimistic rows only; `virt-…` for expanded recurrence instances.
  String get planRowIdForBackend {
    final p = planRowId?.trim() ?? '';
    if (p.startsWith('optimistic-')) return p;
    if (p.startsWith('virt-')) return p;
    final pr = pocketRecordId?.trim() ?? '';
    if (pr.isNotEmpty) return pr;
    if (id > 0) return id.toString();
    if (p.isNotEmpty) return p;
    return id.toString();
  }
  final String title;
  final int categoryId;
  final bool isDone;
  final String dateKey;
  final int order;
  final DateTime? startTime;
  final DateTime? date;
  final DateTime? endDateTime;
  final String endDateKey;
  final List<Map<String, dynamic>> checklist;
  /// @DATA_MAP `plans.notes_plain` — searchable plain text (may include `LIFEOS_LINK::` prefix for backlog ideas).
  final String? notesPlain;
  /// JSON-encoded Quill Delta (`Document.toDelta().toJson()`), @DATA_MAP `plans.notes_delta`.
  final String? notesDeltaJson;
  final int? parentPlanId;
  /// PocketBase **plans.parent_plan_id** relation (15-char parent row id).
  final String? parentPlanPocketId;
  final List<int> subRecordIds;
  final List<Tag> tags;
  /// Local-only: false for optimistic / outbox rows until PocketBase confirms.
  final bool isSynced;

  /// PocketBase [plans.initial_date_key] — wall day the task was first planned for.
  final String? initialDateKey;

  /// PocketBase [plans.is_postponed] — scheduled day is after [initialDateKey].
  final bool isPostponed;

  /// PocketBase [plans.rrule] — RFC 5545 recurrence; null/empty = non-recurring.
  final String? rrule;

  /// PocketBase [plans.exception_dates] — wall dates (`YYYY-MM-DD`) to skip when expanding [rrule].
  final List<String> exceptionDates;

  /// PocketBase [plans.reminder_offset] — minutes before start for reminders.
  final int? reminderOffset;

  /// JIT expansion only: which wall day this virtual row represents; not stored on PB.
  final String? recurrenceInstanceDateKey;

  /// True when rich notes or legacy plain-only content exists.
  bool get hasNotes {
    final p = notesPlain?.trim() ?? '';
    if (p.isNotEmpty) return true;
    final d = notesDeltaJson?.trim() ?? '';
    return d.isNotEmpty;
  }

  /// @DATA_MAP `plans.checklist`.
  bool get hasChecklist => checklist.isNotEmpty;

  /// Sub-task: @DATA_MAP `plans.parent_plan_id`.
  bool get hasParentPlan =>
      (parentPlanPocketId != null && parentPlanPocketId!.trim().isNotEmpty) ||
      (parentPlanId != null && parentPlanId != 0);

  /// Backlog/list child row linked to a parent plan pocket id.
  bool get isBacklogChildItem =>
      parentPlanPocketId != null && parentPlanPocketId!.trim().isNotEmpty;

  /// Parsed [initialDateKey] (UTC date-only), or `null` if missing / invalid.
  DateTime? get initialDate => _dateFromDateKey(initialDateKey ?? '');

  static DateTime? _dateFromDateKey(String key) {
    if (key.length < 10) return null;
    final y = int.tryParse(key.substring(0, 4));
    final m = int.tryParse(key.substring(5, 7));
    final d = int.tryParse(key.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  static String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'category_id': categoryId,
        'is_done': isDone,
        'isSynced': isSynced,
        if (parentPlanPocketId != null && parentPlanPocketId!.trim().isNotEmpty)
          'parent_plan_id': parentPlanPocketId!.trim()
        else if (parentPlanId != null)
          'parent_plan_id': parentPlanId.toString(),
        if (notesPlain != null && notesPlain!.isNotEmpty) 'notes_plain': notesPlain,
        if (notesDeltaJson != null && notesDeltaJson!.trim().isNotEmpty)
          'notes_delta': notesDeltaJson,
        if (checklist.isNotEmpty) 'checklist': checklist,
        if (startTime != null) 'start_time': startTime!.toUtc().toIso8601String(),
        if (endDateTime != null) 'end_time': endDateTime!.toUtc().toIso8601String(),
        if (rrule != null && rrule!.trim().isNotEmpty) 'rrule': rrule!.trim(),
        if (exceptionDates.isNotEmpty) 'exception_dates': exceptionDates,
        if (reminderOffset != null) 'reminder_offset': reminderOffset,
        if (recurrenceInstanceDateKey != null &&
            recurrenceInstanceDateKey!.trim().length >= 10)
          'recurrence_instance_date_key':
              recurrenceInstanceDateKey!.trim().substring(0, 10),
      };

  /// Same as [fromJson]; use when the source is a Noco row `fields` map / REST object.
  factory PlanningTask.fromMap(Map<String, dynamic> map) =>
      PlanningTask.fromJson(map);

  /// PocketBase-only: when `expand` is missing, [pocketTagCatalog] resolves plain `tags_link` id list to [Tag]s.
  factory PlanningTask.fromJson(
    Map<String, dynamic> json, {
    List<Tag>? pocketTagCatalog,
  }) {
    dynamic g(String camel, String snake) => json[camel] ?? json[snake];
    final st = g('startTime', 'start_time');
    final DateTime? startTime = st is DateTime ? st : (st is String ? DateTime.tryParse(st) : null);
    final rawDate = g('date', 'date');
    DateTime? date;
    if (rawDate is DateTime) {
      date = DateTime.utc(rawDate.year, rawDate.month, rawDate.day);
    }
    final dateKey = (g('dateKey', 'date_key') as String?) ?? '';
    if (date == null && dateKey.length >= 10) date = _dateFromDateKey(dateKey);
    final rawEnd = g('endDateTime', 'end_time');
    DateTime? endDateTime;
    if (rawEnd is DateTime) {
      endDateTime = rawEnd;
    } else if (rawEnd is String) {
      endDateTime = DateTime.tryParse(rawEnd);
    }
    final endDateKey = (g('endDateKey', 'end_date_key') as String?) ?? (endDateTime != null ? _dateKeyFromDate(endDateTime) : dateKey);
    final checklist = parseChecklistFromNocoList(json['checklist']);
    final notesPlain =
        json['notes_plain']?.toString() ??
        json['note']?.toString() ??
        json['notes']?.toString();
    final notesDeltaJson = _notesDeltaJsonFromPb(json['notes_delta']);
    final pp = g('parentPlanId', 'parent_plan_id');
    String? parentPlanPocketId;
    int? parentPlanId;
    if (pp != null && pp.toString().trim().isNotEmpty) {
      if (pp is Map) {
        final id = (pp['id'] ?? pp['recordId'])?.toString().trim() ?? '';
        if (id.isNotEmpty) parentPlanPocketId = id;
      } else {
        final s = pp.toString().trim();
        if (s.length >= 15 && !s.contains('-')) {
          parentPlanPocketId = s;
        } else {
          parentPlanId = _jsonInt(pp);
          if (parentPlanId == 0) parentPlanId = null;
        }
      }
    }
    final rawSubIds = g('subRecordIds', 'sub_record_ids');
    List<int> subRecordIds = const [];
    if (rawSubIds is List) {
      subRecordIds = rawSubIds.map((e) => _jsonInt(e)).where((n) => n != 0).toList();
    }
    final planPk =
        (json['plan_row_id'] ?? json['plan_id'] ?? json['planId'])?.toString().trim();
    // @DATA_MAP `plans.tags` is a read-only **Count** (int). M2M edge rows use link column `cnmo43ed26h293n` (top-level list row, inside `fields`, or nested expand).
    Map<String, dynamic>? fieldsBag;
    if (json['fields'] is Map) {
      fieldsBag = Map<String, dynamic>.from(json['fields'] as Map);
    }
    dynamic rawLinkCol =
        json['cnmo43ed26h293n'] ?? fieldsBag?['cnmo43ed26h293n'];
    if (rawLinkCol is Map) {
      rawLinkCol = rawLinkCol['list'] ?? rawLinkCol['records'] ?? rawLinkCol;
    }
    final rawPlanTags = json['tags'] ?? json['Tags'];
    final rawPbLinkField = json['tags_link'];

    List<Tag> tagList = [];

    // —— PocketBase: expanded documents live under json['expand']['tags_link'] ——
    final expandBag = json['expand'];
    if (expandBag is Map) {
      final em = Map<String, dynamic>.from(expandBag);
      tagList = _tagsFromPbExpandField(em['tags_link']);
    }

    // Plain tags_link: full maps (no expand) or id list only.
    if (tagList.isEmpty && rawPbLinkField is List && rawPbLinkField.isNotEmpty) {
      final head = rawPbLinkField.first;
      if (head is Map) {
        tagList = _tagsFromPbExpandField(rawPbLinkField);
      } else if (pocketTagCatalog != null && pocketTagCatalog.isNotEmpty) {
        tagList = _tagsFromPbPlainLinkIds(rawPbLinkField, pocketTagCatalog);
      }
    }
    if (tagList.isEmpty &&
        rawPbLinkField is String &&
        pocketTagCatalog != null &&
        pocketTagCatalog.isNotEmpty &&
        rawPbLinkField.trim().isNotEmpty) {
      tagList = _tagsFromPbPlainLinkIds(<dynamic>[rawPbLinkField], pocketTagCatalog);
    }

    // —— Legacy Noco ——
    if (tagList.isEmpty) {
      if (rawPlanTags is int) {
        tagList =
            rawLinkCol is List ? _parseTagsJson(rawLinkCol) : const <Tag>[];
      } else if (rawLinkCol is List) {
        tagList = _parseTagsJson(rawLinkCol);
      } else {
        tagList = _parseTagsJson(rawPlanTags);
      }
    }
    return PlanningTask(
      id: _jsonInt(json['id']),
      planRowId: (planPk != null && planPk.isNotEmpty) ? planPk : null,
      pocketRecordId: json['pocketRecordId']?.toString(),
      title: json['title'] as String? ?? '',
      categoryId: _jsonInt(g('categoryId', 'category_id')),
      isDone: _jsonBool(g('isDone', 'is_done')),
      dateKey: dateKey,
      order: (json['order'] as int?) ?? 0,
      startTime: startTime,
      date: date,
      endDateTime: endDateTime,
      endDateKey: endDateKey,
      checklist: checklist,
      notesPlain: notesPlain,
      notesDeltaJson: notesDeltaJson,
      parentPlanId: parentPlanId,
      parentPlanPocketId: parentPlanPocketId,
      subRecordIds: subRecordIds,
      tags: tagList,
      isSynced: _jsonBool(g('isSynced', 'is_synced'), true),
      initialDateKey: _normInitialDateKey(
        g('initialDateKey', 'initial_date_key')?.toString(),
      ),
      isPostponed: _jsonBool(g('isPostponed', 'is_postponed'), false),
      rrule: _normRruleField(g('rrule', 'rrule')?.toString()),
      exceptionDates: _parsePlanningExceptionDates(g('exceptionDates', 'exception_dates')),
      reminderOffset: _jsonIntNullable(g('reminderOffset', 'reminder_offset')),
      recurrenceInstanceDateKey: _normRecurrenceInstanceKey(
        g('recurrenceInstanceDateKey', 'recurrence_instance_date_key')?.toString(),
      ),
    );
  }

  static String? _normRruleField(String? raw) {
    final s = raw?.trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static String? _normRecurrenceInstanceKey(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.length >= 10) return s.substring(0, 10);
    return null;
  }

  static List<String> _parsePlanningExceptionDates(dynamic raw) {
    if (raw == null) return const [];
    Iterable<dynamic> items;
    if (raw is List) {
      items = raw;
    } else if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return const [];
      try {
        final d = jsonDecode(t);
        if (d is List) {
          items = d;
        } else {
          return const [];
        }
      } catch (_) {
        return const [];
      }
    } else {
      return const [];
    }
    final out = <String>[];
    for (final e in items) {
      final s = e?.toString().trim() ?? '';
      if (s.length >= 10) {
        out.add(s.substring(0, 10));
      }
    }
    return out;
  }

  static int? _jsonIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _notesDeltaJsonFromPb(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }
    try {
      return jsonEncode(raw);
    } catch (_) {
      return null;
    }
  }

  static String? _normInitialDateKey(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.length >= 10) return s.substring(0, 10);
    return null;
  }

  /// `expand.tags_link` or a list of PocketBase **tags** row maps (`id`, `tag_id`, …).
  static List<Tag> _tagsFromPbExpandField(dynamic tl) {
    if (tl == null) return [];
    if (tl is List) {
      final out = <Tag>[];
      for (final e in tl) {
        if (e is Map<String, dynamic>) {
          out.add(Tag.fromPocketJson(e));
        } else if (e is Map) {
          out.add(Tag.fromPocketJson(Map<String, dynamic>.from(e)));
        }
      }
      return out;
    }
    if (tl is Map) {
      return [Tag.fromPocketJson(Map<String, dynamic>.from(tl))];
    }
    return [];
  }

  /// `tags_link` when expand is off: list of **collection record id** strings — match catalog [Tag.pbRecordId] or [Tag.tagId].
  static List<Tag> _tagsFromPbPlainLinkIds(List<dynamic> raw, List<Tag> catalog) {
    final byPb = <String, Tag>{};
    final byBiz = <int, Tag>{};
    for (final t in catalog) {
      final pid = t.pbRecordId?.trim() ?? '';
      if (pid.isNotEmpty) byPb[pid] = t;
      if (t.tagId != 0) byBiz[t.tagId] = t;
    }
    final out = <Tag>[];
    final seenBearer = <String>{};
    for (final e in raw) {
      if (e is Map) {
        final tag = Tag.fromPocketJson(Map<String, dynamic>.from(e));
        final id = tag.pbRecordId?.trim() ?? '';
        if (id.isNotEmpty && seenBearer.add(id)) {
          out.add(tag);
        }
        continue;
      }
      final id = e?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      var tag = byPb[id];
      if (tag == null) {
        final n = int.tryParse(id);
        if (n != null) tag = byBiz[n];
      }
      if (tag == null) continue;
      final seenKey = tag.pbRecordId?.trim() ?? 'biz:${tag.tagId}';
      if (seenBearer.add(seenKey)) {
        out.add(tag);
      }
    }
    return out;
  }

  /// Noco list item or nested `{ "fields": {…} }` from M2M / read API → flat map for [Tag.fromNocoJson].
  static Map<String, dynamic> _unwrapLinkedTagRow(dynamic e) {
    if (e is! Map) return {};
    final m = Map<String, dynamic>.from(e);
    if (m['fields'] is Map) {
      final f = Map<String, dynamic>.from(m['fields'] as Map);
      final topId = m['id'] ?? m['Id'];
      if (topId != null) {
        f['id'] ??= topId;
      }
      return f;
    }
    return m;
  }

  /// Noco linked records: `tags` is typically a JSON array of row objects (`id` / `fields` / nested maps).
  /// A bare [int] is treated as empty (e.g. plans rollup count — not a tag id list).
  static List<Tag> _parseTagsJson(dynamic raw) {
    if (raw == null) return const [];
    if (raw is int) return const [];
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return const [];
      final out = <Tag>[];
      for (final part in s.split(',')) {
        final n = part.trim();
        if (n.isNotEmpty) {
          out.add(Tag(tagId: 0, name: n));
        }
      }
      return out;
    }
    if (raw is! List) return const [];
    final out = <Tag>[];
    for (final e in raw) {
      if (e is int) {
        if (e != 0) out.add(Tag(tagId: e, name: ''));
        continue;
      }
      if (e is! Map) continue;
      final flat = _unwrapLinkedTagRow(e);
      if (flat.isEmpty) continue;
      final tag = Tag.fromNocoJson(flat);
      final hasLink = tag.wrapperRowId != null && tag.wrapperRowId! > 0;
      if (tag.tagId != 0 || hasLink || tag.name.isNotEmpty) {
        out.add(tag);
      }
    }
    return out;
  }

  PlanningTask copyWith({
    int? id,
    String? planRowId,
    String? pocketRecordId,
    String? title,
    int? categoryId,
    bool? isDone,
    String? dateKey,
    int? order,
    DateTime? startTime,
    DateTime? date,
    DateTime? endDateTime,
    String? endDateKey,
    bool clearEnd = false,
    List<Map<String, dynamic>>? checklist,
    String? notesPlain,
    String? notesDeltaJson,
    bool clearNotes = false,
    int? parentPlanId,
    String? parentPlanPocketId,
    List<int>? subRecordIds,
    List<Tag>? tags,
    bool? isSynced,
    String? initialDateKey,
    bool? isPostponed,
    String? rrule,
    List<String>? exceptionDates,
    int? reminderOffset,
    String? recurrenceInstanceDateKey,
    bool clearRrule = false,
    bool clearReminderOffset = false,
  }) {
    final eDt = clearEnd ? null : (endDateTime ?? this.endDateTime);
    final eDk = endDateKey ?? (eDt != null ? _dateKeyFromDate(eDt) : (clearEnd ? (dateKey ?? this.dateKey) : this.endDateKey));
    return PlanningTask(
      id: id ?? this.id,
      planRowId: planRowId ?? this.planRowId,
      pocketRecordId: pocketRecordId ?? this.pocketRecordId,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      isDone: isDone ?? this.isDone,
      dateKey: dateKey ?? this.dateKey,
      order: order ?? this.order,
      startTime: startTime ?? this.startTime,
      date: date ?? this.date,
      endDateTime: eDt,
      endDateKey: eDk,
      checklist: checklist ?? this.checklist,
      notesPlain: clearNotes ? null : (notesPlain ?? this.notesPlain),
      notesDeltaJson: clearNotes ? null : (notesDeltaJson ?? this.notesDeltaJson),
      parentPlanId: parentPlanId ?? this.parentPlanId,
      parentPlanPocketId: parentPlanPocketId ?? this.parentPlanPocketId,
      subRecordIds: subRecordIds ?? this.subRecordIds,
      tags: tags ?? this.tags,
      isSynced: isSynced ?? this.isSynced,
      initialDateKey: initialDateKey ?? this.initialDateKey,
      isPostponed: isPostponed ?? this.isPostponed,
      rrule: clearRrule ? null : (rrule ?? this.rrule),
      exceptionDates: exceptionDates ??
          (clearRrule ? const <String>[] : this.exceptionDates),
      reminderOffset:
          clearReminderOffset ? null : (reminderOffset ?? this.reminderOffset),
      recurrenceInstanceDateKey:
          recurrenceInstanceDateKey ?? this.recurrenceInstanceDateKey,
    );
  }
}


class PlanningBulkPatch {
  const PlanningBulkPatch({
    required this.planRowId,
    this.planBusinessId,
    this.startTimeDisplay,
    this.endDateTimeDisplay,
    this.clearEnd = false,
    this.initialDateKey,
    this.isPostponed,
  });

  final String planRowId;
  final String? planBusinessId;
  final DateTime? startTimeDisplay;
  final DateTime? endDateTimeDisplay;
  final bool clearEnd;
  /// Sets [plans.initial_date_key] when non-null (audit anchor).
  final String? initialDateKey;
  /// Sets [plans.is_postponed] when non-null.
  final bool? isPostponed;
}

// --- Stats tree (HIERARCHICAL STATS §8). Pure data. ---

