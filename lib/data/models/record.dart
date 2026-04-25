// Part of lib/data/models.dart — Record, TimelineRecord, Task.
// Split per ROADMAP Tier 4.2 (April 2026).
part of '../models.dart';

class Record {
  const Record({
    this.id,
    required this.recordId,
    required this.userId,
    this.sourcePlanId,
    this.title,
    this.note,
    this.type,
    this.status,
    this.categoryId,
    this.parentId,
    this.startTime,
    this.endTime,
    this.date,
    this.isSynced = true,
    this.checklist = const [],
    this.linkedSubRecordIds = const [],
  });

  /// PocketBase / Noco **row** id for REST (`.../records/{id}`). **Never** use [recordId] (UUID) in the URL.
  final String? id;
  /// Column `record_id` (legacy business UUID). Passive metadata only — not an API path segment.
  final String recordId;
  /// PocketBase `user_id` relation (**profiles.id**, string) or legacy Noco numeric / string.
  final String userId;
  /// Optional `source_plan_id` → **plans** row id (@DATA_MAP).
  final String? sourcePlanId;
  final String? title;
  /// Single description field (replaces legacy `notes`).
  final String? note;
  final String? type;
  final String? status;
  final String? categoryId;
  final int? parentId;
  final String? startTime;
  final String? endTime;
  /// Calendar day from [start_time]: **device-local** date (midnight boundary matches timeline buckets).
  final DateTime? date;

  /// Local-only: false when a row is queued for PocketBase retry (not a PB column).
  final bool isSynced;

  /// @DATA_MAP `records.checklist` — JSON list; empty when absent.
  final List<Map<String, dynamic>> checklist;

  /// Optional nested row ids when present on the row (legacy / expand); drives [hasLinkedSubRecords].
  final List<int> linkedSubRecordIds;

  /// @DATA_MAP `records.note` (merged legacy `notes` in [fromJson]).
  bool get hasNotes => note != null && note!.trim().isNotEmpty;

  bool get hasChecklist => checklist.isNotEmpty;

  /// Child row: @DATA_MAP `records.parent_id` (legacy int in some paths).
  bool get hasParentRecord =>
      parentId != null && parentId != 0;

  /// Parent of nested / parallel child rows when ids are available on the payload.
  bool get hasLinkedSubRecords => linkedSubRecordIds.isNotEmpty;

  /// Running only when there is no end timestamp and DB status is running.
  bool get isActuallyRunning {
    final e = endTime?.trim();
    if (e != null && e.isNotEmpty) return false;
    return status == 'running';
  }

  factory Record.fromJson(Map<String, dynamic> json) {
    final data = (json['fields'] ?? json) as Map<String, dynamic>;
    String? systemIdStr;
    for (final key in <String>['id', 'Id', 'ID']) {
      final raw = json[key];
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.isNotEmpty) {
        systemIdStr = s;
        break;
      }
    }
    if (systemIdStr == null || systemIdStr.isEmpty) {
      final inner = data['id'];
      if (inner != null) {
        final s = inner.toString().trim();
        if (s.isNotEmpty) systemIdStr = s;
      }
    }
    if (systemIdStr == null || systemIdStr.isEmpty) {
      final ni = _parseIntNullable(data['backendNumericId']) ??
          _parseIntNullable(data['nocoSystemId']) ??
          _parseIntNullable(data['id']);
      if (ni != null) systemIdStr = ni.toString();
    }
    final bizId = (data['record_id'] ??
            data['Record_id'] ??
            json['record_id'])
        ?.toString()
        .trim() ??
        '';
    final uidRel = pbRelationIdFromDynamic(data['user_id']);
    final userId = uidRel ??
        () {
          final n = _jsonInt(data['user_id']);
          return n == 0 ? '' : n.toString();
        }();
    final srcPlan = pbRelationIdFromDynamic(
      data['source_plan_id'] ?? data['sourcePlanId'],
    );
    // Noco: category_id may be Link (Map / List of {id: ...}) or scalar int/string slug.
    dynamic catRaw = data['category_id'] ?? data['categoryId'];
    if (catRaw is Map) {
      catRaw = catRaw['id'] ?? catRaw['Id'] ?? catRaw['ID'];
    } else if (catRaw is List && catRaw.isNotEmpty) {
      final f = catRaw.first;
      catRaw = f is Map ? (f['id'] ?? f['Id'] ?? f['ID']) : f;
    }
    final String? categoryId = catRaw == null
        ? null
        : catRaw is String
            ? (catRaw.trim().isEmpty ? null : catRaw.trim())
            : catRaw.toString().trim().isEmpty
                ? null
                : catRaw.toString().trim();
    final startRaw = data['start_time'] ?? data['startTime'];
    final String? startTimeStr = normalizeRecordIsoToUtcSecondPrecision(startRaw);
    final date = _recordLocalCalendarDate(startRaw);
    final endRaw = data['end_time'] ?? data['endTime'];
    final String? endTimeStr = normalizeRecordIsoToUtcSecondPrecision(endRaw);
    List<int> parseLinkedSubIds(dynamic raw) {
      if (raw == null) return const [];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (_jsonInt(e) != 0) _jsonInt(e),
      ];
    }

    return Record(
      id: systemIdStr,
      recordId: bizId,
      userId: userId,
      sourcePlanId: srcPlan,
      title: data['title']?.toString(),
      note: mergeRecordNoteFields(data['note'], data['notes']),
      type: data['type']?.toString(),
      status: data['status']?.toString(),
      categoryId: categoryId,
      parentId: () {
        final pid = data['parent_id'] ?? data['parentId'];
        return pid == null ? null : _jsonInt(pid);
      }(),
      startTime: startTimeStr,
      endTime: endTimeStr,
      date: date,
      isSynced: _jsonBool(data['isSynced'] ?? data['is_synced'], true),
      checklist: parseChecklistFromNocoList(data['checklist']),
      linkedSubRecordIds: parseLinkedSubIds(
        data['sub_record_ids'] ?? data['subRecordIds'],
      ),
    );
  }

  /// Merged timeline row from [DatabaseService] / [timeline_view] (no async).
  factory Record.forTimelineCard(Map<String, dynamic> data) {
    int? parentFrom(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw == 0 ? null : raw;
      final s = raw.toString().trim();
      if (s.isEmpty || s == '0') return null;
      return int.tryParse(s);
    }

    List<int> linkedIds(dynamic raw) {
      if (raw == null) return const [];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (_jsonInt(e) != 0) _jsonInt(e),
      ];
    }

    final cat = data['categoryId'];
    return Record(
      id: data['id']?.toString(),
      recordId: (data['record_id'] ?? '').toString(),
      userId: (data['user_id'] ?? '').toString(),
      sourcePlanId: data['source_plan_id']?.toString(),
      title: data['title']?.toString(),
      note: data['note']?.toString(),
      type: data['type']?.toString(),
      status: data['status']?.toString(),
      categoryId: cat?.toString(),
      parentId: parentFrom(data['parentId'] ?? data['parent_id']),
      startTime: null,
      endTime: null,
      date: null,
      checklist: parseChecklistFromNocoList(data['checklist']),
      linkedSubRecordIds: linkedIds(
        data['subRecordIds'] ?? data['sub_record_ids'],
      ),
    );
  }

  /// API-facing JSON: **only** [id] identifies the row to the server ([recordId] is omitted here).
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id != null && id!.trim().isNotEmpty) 'id': id,
        if (userId.isNotEmpty) 'user_id': userId,
        if (sourcePlanId != null && sourcePlanId!.trim().isNotEmpty)
          'source_plan_id': sourcePlanId,
        'title': title,
        if (note != null && note!.isNotEmpty) 'note': note,
        'type': type,
        'status': status,
        'category_id': categoryId,
        'parent_id': parentId,
        'start_time': startTime,
        'end_time': endTime,
        if (checklist.isNotEmpty) 'checklist': checklist,
        if (linkedSubRecordIds.isNotEmpty) 'sub_record_ids': linkedSubRecordIds,
        if (date != null)
          'date': '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
      };

  /// Same field shape as [toJson] (API / cache maps).
  Map<String, dynamic> toMap() => toJson();
}

/// Deterministic cross-platform hash for string category IDs (replaces Dart's randomized hashCode).

class TimelineRecord {
  TimelineRecord({
    required this.id,
    this.recordId,
    this.userId,
    this.sourcePlanId,
    required this.title,
    this.categoryId,
    this.type = 'record',
    this.status = 'completed',
    this.startTime,
    this.endTime,
    this.duration,
    this.durationSeconds,
    this.checklist,
    this.note,
    this.subRecordIds,
    this.parentId,
    this.timezoneOffsetHours = 0,
  });

  /// PocketBase **records** row id — **only** value used for REST paths and stop/delete/patch dispatch.
  final String id;
  /// Column `record_id` (legacy UUID). Passive metadata; do **not** use for `/records/...` URLs.
  final String? recordId;
  /// Owner: `user_id` → **profiles.id** (string).
  final String? userId;
  /// Optional `source_plan_id` → **plans** row id.
  final String? sourcePlanId;
  String title;
  int? categoryId;
  final String type;
  String status;
  DateTime? startTime;
  DateTime? endTime;
  int? duration;
  final int? durationSeconds;
  final List<Map<String, dynamic>>? checklist;
  final String? note;
  final List<int>? subRecordIds;
  final int? parentId;
  /// Profile wall-clock offset (profiles.timezone_offset). Drives [dateKey] day bucket — no device TZ.
  final int timezoneOffsetHours;

  /// ISO `YYYY-MM-DD` from [startTime] in profile wall-clock calendar ([timezoneOffsetHours], not device TZ).
  String get dateKey {
    final st = startTime;
    if (st == null) return '';
    final wall = st.toUtc().add(Duration(hours: timezoneOffsetHours));
    return '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
  }

  /// Basta: [endTime] set ⇒ not running, regardless of [status] string.
  bool get isActuallyRunning =>
      endTime == null && status == 'running';

  bool get hasNotes => note != null && note!.trim().isNotEmpty;

  bool get hasChecklist => (checklist?.isNotEmpty ?? false);

  bool get hasParentRecord =>
      parentId != null && parentId != 0;

  /// When [subRecordIds] is populated on the row / map.
  bool get hasLinkedSubRecords =>
      subRecordIds != null && subRecordIds!.isNotEmpty;

  static dynamic _get(Map<String, dynamic> data, String camel, String snake) =>
      data[camel] ?? data[snake];

  factory TimelineRecord.fromMap(Map<String, dynamic> data, {String? systemId, int timezoneOffsetHours = 0}) {
    String? passiveBiz;
    for (final k in <String>['record_id', 'recordId']) {
      final v = data[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) {
        passiveBiz = s;
        break;
      }
    }
    final restId = () {
      if (systemId != null && systemId.trim().isNotEmpty) {
        return systemId.trim();
      }
      for (final k in <String>[
        'backendRestPathId',
        'nocoRestPathId',
        'id',
        'Id',
      ]) {
        final v = data[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty && _isTimelineRestRowId(s)) return s;
      }
      final sys = data['backendNumericId'] ?? data['nocoSystemId'];
      if (sys is int && sys != 0) return sys.toString();
      if (sys != null) {
        final p = int.tryParse(sys.toString());
        if (p != null && p != 0) return p.toString();
      }
      return '';
    }();
    if (passiveBiz != null &&
        passiveBiz.isNotEmpty &&
        passiveBiz == restId &&
        !_isPbRecordsRowIdSegment(passiveBiz) &&
        int.tryParse(passiveBiz) == null) {
      passiveBiz = null;
    }
    final start = _get(data, 'startTime', 'start_time');
    final end = _get(data, 'endTime', 'end_time');
    final startDt = _parseToUtcSecondPrecision(start);
    final endDt = _parseToUtcSecondPrecision(end);
    final note = mergeRecordNoteFields(data['note'], data['notes']);
    final checklist = parseChecklistFromNoco(data['checklist']);
    final rawSubIds = _get(data, 'subRecordIds', 'sub_record_ids');
    List<int>? subRecordIds;
    if (rawSubIds is List) {
      subRecordIds = rawSubIds.map((e) => _jsonInt(e)).where((n) => n != 0).toList();
      if (subRecordIds.isEmpty) subRecordIds = null;
    }
    final pid = _get(data, 'parentId', 'parent_id');
    final int? parentId = pid == null || pid.toString().isEmpty ? null : _jsonInt(pid);
    final uidMap = _get(data, 'userId', 'user_id');
    final userIdStr = pbRelationIdFromDynamic(uidMap) ??
        () {
          final s = uidMap?.toString().trim();
          if (s == null || s.isEmpty) return null;
          return s;
        }();
    final planLink = _get(data, 'sourcePlanId', 'source_plan_id');
    final sourcePlanStr = pbRelationIdFromDynamic(planLink) ??
        () {
          final s = planLink?.toString().trim();
          if (s == null || s.isEmpty) return null;
          return s;
        }();

    return TimelineRecord(
      id: restId,
      recordId: passiveBiz,
      userId: userIdStr,
      sourcePlanId: sourcePlanStr,
      title: (data['title'] as String?) ?? '',
      categoryId: () {
        final c = _get(data, 'categoryId', 'category_id');
        return c == null ? null : _jsonInt(c);
      }(),
      type: data['type'] as String? ?? 'record',
      status: () {
        final s = data['status'] as String? ?? 'completed';
        if (endDt != null) return 'completed';
        return s;
      }(),
      startTime: startDt,
      endTime: endDt,
      duration: data['duration'] as int?,
      durationSeconds: (_get(data, 'durationSeconds', 'duration_seconds') as int?) ?? data['duration'] as int?,
      checklist: checklist,
      note: note,
      subRecordIds: subRecordIds,
      parentId: parentId,
      timezoneOffsetHours: timezoneOffsetHours,
    );
  }

  Map<String, dynamic> toMap() {
    final sys = int.tryParse(id);
    return <String, dynamic>{
        'id': id,
        'backendRestPathId': id,
        if (recordId != null && recordId!.trim().isNotEmpty)
          'record_id': recordId,
        if (userId != null && userId!.trim().isNotEmpty) 'user_id': userId,
        if (sourcePlanId != null && sourcePlanId!.trim().isNotEmpty)
          'source_plan_id': sourcePlanId,
        'backendNumericId': sys,
        'docId': sys ?? 0,
        'title': title,
        'category_id': categoryId,
        'type': type,
        'status': status,
        'start_time': startTime != null
            ? _iso8601UtcSecondsPrecision(startTime!)
            : null,
        'end_time': endTime != null
            ? _iso8601UtcSecondsPrecision(endTime!)
            : null,
        'duration': duration,
        'duration_seconds': durationSeconds,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (checklist != null && checklist!.isNotEmpty) 'checklist': checklist,
        if (subRecordIds != null && subRecordIds!.isNotEmpty) 'sub_record_ids': subRecordIds,
        if (parentId != null) 'parent_id': parentId,
      };
  }

  String toJson() => jsonEncode(toMap());

  factory TimelineRecord.fromJson(Map<String, dynamic> json) {
    final sid = (json['backendRestPathId'] ??
            json['nocoRestPathId'] ??
            json['id'] ??
            json['Id'])
        ?.toString()
        .trim();
    final sys = json['backendNumericId'] ?? json['nocoSystemId'];
    final fromNum = sys is int
        ? sys.toString()
        : int.tryParse(sys?.toString() ?? '')?.toString();
    final chosen = (sid != null && sid.isNotEmpty)
        ? sid
        : (fromNum != null && fromNum != '0' ? fromNum : '');
    return TimelineRecord.fromMap(
      Map<String, dynamic>.from(json),
      systemId: chosen.isNotEmpty ? chosen : null,
    );
  }

  TimelineRecord copyWith({
    String? id,
    String? recordId,
    String? userId,
    String? sourcePlanId,
    String? title,
    int? categoryId,
    String? type,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    int? durationSeconds,
    List<Map<String, dynamic>>? checklist,
    String? note,
    List<int>? subRecordIds,
    int? parentId,
    int? timezoneOffsetHours,
  }) {
    return TimelineRecord(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      userId: userId ?? this.userId,
      sourcePlanId: sourcePlanId ?? this.sourcePlanId,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      checklist: checklist ?? this.checklist,
      note: note ?? this.note,
      subRecordIds: subRecordIds ?? this.subRecordIds,
      parentId: parentId ?? this.parentId,
      timezoneOffsetHours: timezoneOffsetHours ?? this.timezoneOffsetHours,
    );
  }
}

class Task {
  Task({
    required this.title,
    required this.startTime,
    this.endTime,
    required this.tags,
    required this.isActive,
    this.isSynced = true,
  });

  final String title;
  final DateTime startTime;
  DateTime? endTime;
  final List<String> tags;
  bool isActive;
  /// Local-only client sync flag (not a PocketBase column).
  final bool isSynced;

  bool get isRunning => isActive && endTime == null;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    final d = end.difference(startTime);
    return d.isNegative ? Duration.zero : d;
  }

  /// Optional: set when sending to the backend so payload includes `user_id` (PocketBase auth record id).
  String? userId;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'tags': tags,
        'isActive': isActive,
        'isSynced': isSynced,
        if (userId != null && userId!.trim().isNotEmpty) 'user_id': userId,
      };

  String toJson() => jsonEncode(toMap());

  factory Task.fromMap(Map<String, dynamic> json) {
    final data = (json['fields'] ?? json) as Map<String, dynamic>;
    final rawTags = data['tags'];
    final parsedTags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is String && t.trim().isNotEmpty) parsedTags.add(t.trim());
      }
    } else {
      final legacy = (data['category'] as String?)?.trim();
      if (legacy != null && legacy.isNotEmpty) parsedTags.add(legacy);
    }
    if (parsedTags.isEmpty) parsedTags.add('Life');

    final startStr = data['start_time'] as String? ?? data['startTime'] as String?;
    final endStr = data['end_time'] as String? ?? data['endTime'] as String?;
    return Task(
      title: data['title'] as String? ?? '',
      startTime: startStr != null && startStr.isNotEmpty ? DateTime.parse(startStr) : DateTime.now(),
      endTime: endStr != null && endStr.isNotEmpty ? DateTime.parse(endStr) : null,
      tags: parsedTags,
      isActive: data['is_active'] as bool? ?? data['isActive'] as bool? ?? false,
      isSynced: _jsonBool(data['isSynced'] ?? data['is_synced'], true),
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) => Task.fromMap(json);
}

