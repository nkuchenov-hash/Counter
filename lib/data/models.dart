import 'dart:convert';

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// DATA DNA — VAULT: lib/data/models.dart (@ARCHITECTURE.md §1, @DATA_MAP.md).
// Pure classes and serialization. No database imports.
// PKs: records → wrapper `Id` (int, row URL `.../tableUid/Id`) + `record_id` (UUID, fields); categories → category_id; plans → plan_id;
// profiles → user_id (String). Legacy int fields kept only where UI still expects them.
// ---------------------------------------------------------------------------

int _jsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

/// NocoDB may return booleans as 0/1 or strings.
bool _jsonBool(dynamic v, [bool fallback = false]) {
  if (v == true) return true;
  if (v == false) return false;
  if (v == 1) return true;
  if (v == 0) return false;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return fallback;
}

int? _parseIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString().trim());
}

int _stableStringId(String raw, [int fallback = 0]) {
  final s = raw.trim();
  if (s.isEmpty) return fallback;
  var hash = 2166136261;
  for (final u in s.codeUnits) {
    hash ^= u;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  if (hash == 0) return fallback;
  return hash;
}

/// NocoDB profile row.
class Profile {
  const Profile({
    required this.id,
    required this.userId,
    this.email,
    this.password,
    this.primaryLanguage,
    this.preferredTimezone,
    this.timezoneOffsetHours,
    this.defaultCategoryId,
    this.biometricEnabled,
  });

  final int id;
  final int userId;
  final String? email;
  final String? password;
  final String? primaryLanguage;
  final String? preferredTimezone;
  final int? timezoneOffsetHours;
  final int? defaultCategoryId;
  final bool? biometricEnabled;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: _jsonInt(json['id']),
        userId: _jsonInt(json['user_id']),
        email: json['email']?.toString(),
        password: json['password']?.toString(),
        primaryLanguage: json['primary_language']?.toString() ?? json['primaryLanguage']?.toString(),
        preferredTimezone: json['preferred_timezone']?.toString() ?? json['preferredTimeZone']?.toString(),
        timezoneOffsetHours: json['timezone_offset'] is int
            ? json['timezone_offset'] as int
            : int.tryParse(json['timezone_offset']?.toString() ?? ''),
        defaultCategoryId:
            json['default_category_id'] == null ? null : _jsonInt(json['default_category_id']),
        biometricEnabled: json['biometric_enabled'] as bool? ?? json['biometricEnabled'] as bool?,
      );
}

/// NocoDB user profile. Unique user identifier is always user_id in DB and code.
class UserProfile {
  UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.primaryLanguage,
    this.themeMode,
    this.preferredTimezone,
    this.timezoneOffset,
    this.biometricEnabled = false,
    this.updatedAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? primaryLanguage;
  final String? themeMode;
  final String? preferredTimezone;
  final double? timezoneOffset;
  final bool biometricEnabled;
  final String? updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['user_id'] ?? json['id'] ?? '').toString(),
      email: json['email']?.toString(),
      displayName: json['display_name']?.toString() ?? json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      primaryLanguage: json['primary_language']?.toString() ?? 'ru',
      themeMode: json['theme_mode']?.toString() ?? 'system',
      preferredTimezone: json['preferred_timezone']?.toString(),
      timezoneOffset: (json['timezone_offset'] as num?)?.toDouble(),
      biometricEnabled: json['biometric_enabled'] == true ||
          json['biometric_enabled'] == 'true',
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

/// NocoDB category row (flat). @DATA_MAP.md: [name], [category_id], [normalized_id].
class Category {
  const Category({
    required this.id,
    required this.userId,
    this.name,
    this.tag,
    this.parentId,
    this.normalizedId,
    this.colorValue,
    this.iconCodePoint,
  });

  final String id;
  final int userId;
  /// Display name (@DATA_MAP column `name`).
  final String? name;
  /// Legacy display label; prefer [name] when present.
  final String? tag;
  final int? parentId;
  final String? normalizedId;
  final int? colorValue;
  final int? iconCodePoint;

  factory Category.fromJson(Map<String, dynamic> json) {
    final pid = json['parent_id'];
    final rawId = json['id'] ?? json['category_id'] ?? json['Id'];
    final nameRaw = json['name']?.toString().trim() ?? '';
    final legacyTag = json['tag']?.toString().trim();
    final normRaw = json['normalized_id']?.toString().trim() ?? '';
    final resolvedName = nameRaw.isNotEmpty
        ? nameRaw
        : (legacyTag != null && legacyTag.isNotEmpty)
            ? legacyTag
            : (normRaw.isNotEmpty ? normRaw : null);
    final display = resolvedName ??
        (normRaw.isNotEmpty ? normRaw : null) ??
        (legacyTag != null && legacyTag.isNotEmpty ? legacyTag : null);
    return Category(
      id: (rawId ?? '').toString(),
      userId: _jsonInt(json['user_id']),
      name: resolvedName,
      tag: display ?? 'Untitled',
      parentId: pid == null || pid.toString().isEmpty ? null : _jsonInt(pid),
      normalizedId: json['normalized_id']?.toString(),
      colorValue: json['color_value'] is int ? json['color_value'] as int : int.tryParse(json['color_value']?.toString() ?? ''),
      iconCodePoint: json['icon_code_point'] is int ? json['icon_code_point'] as int : int.tryParse(json['icon_code_point']?.toString() ?? ''),
    );
  }
}

/// Merge legacy Noco `notes` into singular `note` (migration path).
String? mergeRecordNoteFields(dynamic noteRaw, dynamic notesRaw) {
  final a = noteRaw?.toString().trim() ?? '';
  final b = notesRaw?.toString().trim() ?? '';
  if (a.isEmpty && b.isEmpty) return null;
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  return '$a\n$b';
}

/// NocoDB record row (flat). Keys match table mjchwhned7zsvj0 exactly; all mapping uses data = json['fields'] ?? json.
/// Calendar identity comes from [startTime] only — not from date_key.
class Record {
  const Record({
    this.id,
    required this.recordId,
    required this.userId,
    this.title,
    this.note,
    this.type,
    this.status,
    this.categoryId,
    this.parentId,
    this.startTime,
    this.endTime,
    this.date,
  });

  /// NocoDB **list wrapper** `Id` (integer from JSON root). REST row URL is `.../{tableUid}/{Id}` — **never** [recordId] (UUID), **never** a list index.
  final int? id;
  /// Business UUID from column `record_id`.
  final String recordId;
  final int userId;
  final String? title;
  /// Single description field (replaces legacy `notes`).
  final String? note;
  final String? type;
  final String? status;
  final String? categoryId;
  final int? parentId;
  final String? startTime;
  final String? endTime;
  /// Calendar day from [start_time] UTC date only (no device [.toLocal()]).
  final DateTime? date;

  /// Same as [recordId] (business UUID column).
  String get nocoRecordId => recordId;

  /// Running only when there is no end timestamp and DB status is running.
  bool get isActuallyRunning {
    final e = endTime?.trim();
    if (e != null && e.isNotEmpty) return false;
    return status == 'running';
  }

  factory Record.fromJson(Map<String, dynamic> json) {
    final data = (json['fields'] ?? json) as Map<String, dynamic>;
    final systemId = _parseIntNullable(json['id']) ??
        _parseIntNullable(json['Id']) ??
        _parseIntNullable(json['ID']) ??
        _parseIntNullable(data['nocoSystemId']) ??
        _parseIntNullable(data['id']);
    final bizId = (data['record_id'] ??
            data['Record_id'] ??
            json['record_id'])
        ?.toString()
        .trim() ??
        '';
    final userId = _jsonInt(data['user_id']);
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
    final String? startTimeStr = startRaw is DateTime
        ? startRaw.toUtc().toIso8601String()
        : startRaw?.toString();
    final date = _recordLocalCalendarDate(startRaw);
    final endRaw = data['end_time'] ?? data['endTime'];
    final String? endTimeStr = endRaw is DateTime
        ? endRaw.toUtc().toIso8601String()
        : endRaw?.toString();
    return Record(
      id: systemId,
      recordId: bizId,
      userId: userId,
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
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id != null) 'id': id,
        'record_id': recordId,
        'user_id': userId,
        'title': title,
        if (note != null && note!.isNotEmpty) 'note': note,
        'type': type,
        'status': status,
        'category_id': categoryId,
        'parent_id': parentId,
        'start_time': startTime,
        'end_time': endTime,
        if (date != null)
          'date': '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
      };
}

/// UTC calendar date from stored timestamp (@ARCHITECTURE.md Planetary Time — no [.toLocal()]).
DateTime? _recordLocalCalendarDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) {
    final u = v.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }
  var s = v.toString().trim();
  if (s.isEmpty) return null;
  if (s.contains(' ') && !s.contains('T')) {
    s = s.replaceFirst(' ', 'T');
  }
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  final u = parsed.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

DateTime? _parseFlexibleDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  // NocoDB sometimes returns without timezone; treat as UTC by app contract.
  final hasTz = s.endsWith('Z') || s.contains('+') || (s.length > 11 && s.substring(11).contains('-'));
  final parsed = DateTime.tryParse(hasTz ? s : '${s}Z');
  return parsed?.toUtc();
}

/// NocoDB plan row (flat).
class Plan {
  const Plan({
    required this.id,
    required this.planId,
    required this.userId,
    this.title,
    this.categoryId,
    this.dateKey,
    this.startTime,
    this.endTime,
    this.isDone,
  });

  final int id;
  /// String identifier for this plan row (NocoDB column: plan_id).
  final String planId;
  final int userId;
  final String? title;
  final String? categoryId;
  final String? dateKey;
  final String? startTime;
  final String? endTime;
  final bool? isDone;

  factory Plan.fromJson(Map<String, dynamic> json) {
    final data = (json['fields'] ?? json) as Map<String, dynamic>;
    final id = _jsonInt(json['id'] ?? data['id']);
    final planId = (data['plan_id'] ?? data['id'] ?? id).toString();
    return Plan(
      id: id,
      planId: planId,
      userId: _jsonInt(data['user_id']),
      title: data['title']?.toString(),
      categoryId: data['category_id']?.toString(),
      dateKey: data['date_key']?.toString(),
      startTime: data['start_time']?.toString(),
      endTime: data['end_time']?.toString(),
      isDone: data['is_done'] as bool?,
    );
  }
}

/// Strict hierarchical category. Supports optional keywords per language (MULTILINGUAL_KEYWORDS).
class CategoryRule {
  /// Synthetic id for records whose Noco `category_id` does not match any loaded rule.
  static const int uncategorizedSyntheticId = -1;

  CategoryRule({
    required this.id,
    required this.name,
    this.nocoId,
    this.normalizedId,
    this.children,
    this.colorValue,
    this.iconCodePoint,
    this.keywords,
    this.localizedNames,
    this.order = 0,
  });

  factory CategoryRule.uncategorized() {
    return CategoryRule(
      id: uncategorizedSyntheticId,
      name: 'Uncategorized',
      nocoId: 'uncategorized',
      normalizedId: 'uncategorized',
    );
  }

  final int id;
  /// @DATA_MAP.md `categories.name` (display name).
  String name;
  final String? nocoId;
  final String? normalizedId;
  /// String business key from DB (e.g. "astra", "life", UUID).
  String get categoryKey =>
      (nocoId ?? '').trim().isNotEmpty
          ? nocoId!.trim()
          : (normalizedId ?? '').trim().isNotEmpty
              ? normalizedId!.trim()
              : name.trim();
  List<CategoryRule>? children;
  int? colorValue;
  int? iconCodePoint;
  /// @DATA_MAP.md `categories.order` — sibling sort index (integer); persisted via bulk PATCH.
  int order;
  Map<String, List<String>>? keywords;
  final Map<String, String>? localizedNames;

  CategoryRule copyWith({
    int? id,
    String? name,
    String? nocoId,
    String? normalizedId,
    List<CategoryRule>? children,
    int? colorValue,
    int? iconCodePoint,
    Map<String, List<String>>? keywords,
    Map<String, String>? localizedNames,
    int? order,
  }) {
    final copiedChildren = children ??
        (this.children != null ? List<CategoryRule>.from(this.children!) : null);
    Map<String, List<String>>? copiedKeywords;
    if (keywords != null) {
      copiedKeywords = {};
      for (final entry in keywords.entries) {
        copiedKeywords[entry.key] = List<String>.from(entry.value);
      }
    } else if (this.keywords != null) {
      copiedKeywords = {};
      for (final entry in this.keywords!.entries) {
        copiedKeywords[entry.key] = List<String>.from(entry.value);
      }
    }
    return CategoryRule(
      id: id ?? this.id,
      name: name ?? this.name,
      nocoId: nocoId ?? this.nocoId,
      normalizedId: normalizedId ?? this.normalizedId,
      children: copiedChildren,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      keywords: copiedKeywords,
      localizedNames: localizedNames ?? this.localizedNames,
      order: order ?? this.order,
    );
  }

  List<String> keywordsFor(String lang) =>
      (keywords != null && keywords!.containsKey(lang)) ? List<String>.from(keywords![lang]!) : [];

  Color get colorOrDefault {
    if (colorValue != null) return Color(colorValue!);
    return Colors.grey;
  }

  IconData get iconOrDefault {
    if (iconCodePoint != null) return IconData(iconCodePoint!, fontFamily: 'MaterialIcons');
    return Icons.folder_rounded;
  }

  CategoryRule? findDeepestMatch(String title) {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return null;
    CategoryRule? best;
    int bestDepth = -1;

    void visit(CategoryRule r, int depth) {
      if (depth > 4) return;
      final tagLower = r.name.trim().toLowerCase();
      if (tagLower.isNotEmpty && t.contains(tagLower)) {
        if (depth >= bestDepth) {
          best = r;
          bestDepth = depth;
        }
      }
      for (final c in r.children ?? []) {
        visit(c, depth + 1);
      }
    }

    visit(this, 0);
    return best;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (nocoId != null && nocoId!.isNotEmpty) 'nocoId': nocoId,
        if (normalizedId != null && normalizedId!.isNotEmpty) 'normalizedId': normalizedId,
        if (children != null && children!.isNotEmpty)
          'children': children!.map((c) => c.toJson()).toList(),
        if (colorValue != null) 'colorValue': colorValue,
        if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
        if (keywords != null && keywords!.isNotEmpty)
          'keywords': keywords!.map((k, v) => MapEntry(k, v)),
        if (localizedNames != null && localizedNames!.isNotEmpty)
          'localizedNames': localizedNames,
        'order': order,
      };

  factory CategoryRule.fromJson(Map<String, dynamic> json) {
    final data = (json['fields'] ?? json) as Map<String, dynamic>;
    final rawId =
        (json['id'] ?? json['category_id'] ?? data['id'] ?? data['category_id'] ?? '')
            .toString();
    final nameStr = (data['name'] ?? json['name'])?.toString().trim() ?? '';
    final tagStr = (data['tag'] ?? json['tag'])?.toString().trim() ?? '';
    final normStr =
        (data['normalized_id'] ?? data['normalizedId'])?.toString().trim() ?? '';
    final safeTag = nameStr.isNotEmpty
        ? nameStr
        : (tagStr.isNotEmpty
            ? tagStr
            : (normStr.isNotEmpty ? normStr : 'Untitled'));
    final rawChildren = data['children'];
    final List<CategoryRule> children = rawChildren is List
        ? (rawChildren)
            .whereType<Map<String, dynamic>>()
            .map(CategoryRule.fromJson)
            .toList()
        : [];
    final rawKeywords = data['keywords'];
    Map<String, List<String>>? keywords;
    if (rawKeywords is Map) {
      keywords = {};
      for (final e in rawKeywords.entries) {
        if (e.key is! String) continue;
        final list = e.value;
        if (list is List) {
          keywords[e.key as String] = list.map((x) => x?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        } else {
          keywords[e.key as String] = [];
        }
      }
      if (keywords.isEmpty) keywords = null;
    }
    Map<String, String>? localizedNames;
    final rawNames = data['localized_names'] ?? data['localizedNames'];
    if (rawNames is Map) {
      final map = <String, String>{};
      for (final entry in rawNames.entries) {
        final k = entry.key?.toString();
        final v = entry.value?.toString();
        if (k != null && k.isNotEmpty && v != null && v.isNotEmpty) {
          map[k] = v;
        }
      }
      if (map.isNotEmpty) {
        localizedNames = Map<String, String>.from(map);
      }
    }
    final colorRaw = data['color_value'] ?? data['colorValue'];
    final iconRaw = data['icon_code_point'] ?? data['iconCodePoint'];
    final orderRaw = data['order'];
    final orderVal = orderRaw is int
        ? orderRaw
        : int.tryParse(orderRaw?.toString() ?? '') ?? 0;
    return CategoryRule(
      id: int.tryParse(rawId) ?? rawId.hashCode,
      name: safeTag,
      nocoId: rawId,
      normalizedId: (data['category_id'] ?? data['id1'] ?? data['normalized_id'] ?? data['normalizedId'])?.toString(),
      children: children.isEmpty ? null : children,
      colorValue: colorRaw is int ? colorRaw : (colorRaw != null ? int.tryParse(colorRaw.toString()) : null),
      iconCodePoint: iconRaw is int ? iconRaw : (iconRaw != null ? int.tryParse(iconRaw.toString()) : null),
      keywords: keywords,
      localizedNames: localizedNames,
      order: orderVal,
    );
  }
}

/// In-memory representation of a timeline record. Hierarchy: parentId + [recordId].
/// Calendar day for UI is always derived from [startTime] (UTC date), not from date_key.
class TimelineRecord {
  TimelineRecord({
    required this.recordId,
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
  });

  /// Brain uses **wrapper `Id`** as decimal string for row URL (`.../mjchwhned7zsvj0/{Id}`); never a list index.
  final String recordId;
  String get id => recordId;
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

  /// ISO `YYYY-MM-DD` from [startTime] in UTC (matches Noco start_time date prefix).
  String get dateKey {
    final st = startTime;
    if (st == null) return '';
    final u = st.toUtc();
    return '${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
  }

  /// Basta: [endTime] set ⇒ not running, regardless of [status] string.
  bool get isActuallyRunning =>
      endTime == null && status == 'running';

  static dynamic _get(Map<String, dynamic> data, String camel, String snake) =>
      data[camel] ?? data[snake];

  factory TimelineRecord.fromMap(Map<String, dynamic> data, {String? recordId}) {
    final rid = () {
      if (recordId != null && recordId.trim().isNotEmpty) {
        return recordId.trim();
      }
      final sys = data['nocoSystemId'];
      if (sys is int) return sys.toString();
      // Prefer Noco **system** id (digits) for Brain REST URLs — never UUID alone.
      for (final k in <String>['id', 'Id', 'nocoRestPathId']) {
        final v = data[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty && int.tryParse(s) != null) return s;
      }
      for (final k in <String>['record_id', 'recordId']) {
        final v = data[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }();
    final start = _get(data, 'startTime', 'start_time');
    final end = _get(data, 'endTime', 'end_time');
    final startDt = start is DateTime ? start : (start is String ? DateTime.tryParse(start) : null);
    final endDt = end is DateTime ? end : (end is String ? DateTime.tryParse(end) : null);
    final note = mergeRecordNoteFields(data['note'], data['notes']);
    final rawChecklist = data['checklist'];
    List<Map<String, dynamic>>? checklist;
    if (rawChecklist is List) {
      checklist = rawChecklist
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final rawSubIds = _get(data, 'subRecordIds', 'sub_record_ids');
    List<int>? subRecordIds;
    if (rawSubIds is List) {
      subRecordIds = rawSubIds.map((e) => _jsonInt(e)).where((n) => n != 0).toList();
      if (subRecordIds.isEmpty) subRecordIds = null;
    }
    final pid = _get(data, 'parentId', 'parent_id');
    final int? parentId = pid == null || pid.toString().isEmpty ? null : _jsonInt(pid);

    return TimelineRecord(
      recordId: rid,
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
    );
  }

  Map<String, dynamic> toMap() {
    final sys = int.tryParse(recordId);
    return <String, dynamic>{
        'record_id': recordId,
        'id': recordId,
        if (sys != null) 'nocoSystemId': sys,
        'title': title,
        'category_id': categoryId,
        'type': type,
        'status': status,
        'start_time': startTime?.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
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
    final sys = json['nocoSystemId'];
    final rid = (sys is int
            ? sys.toString()
            : (json['recordId'] ??
                json['nocoRestPathId'] ??
                json['id'] ??
                json['Id'] ??
                json['record_id'] ??
                json['docId']))
        ?.toString()
        .trim() ??
        '';
    return TimelineRecord.fromMap(Map<String, dynamic>.from(json),
        recordId: rid.isNotEmpty ? rid : null);
  }

  TimelineRecord copyWith({
    String? recordId,
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
  }) {
    return TimelineRecord(
      recordId: recordId ?? this.recordId,
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
  });

  final String title;
  final DateTime startTime;
  DateTime? endTime;
  final List<String> tags;
  bool isActive;

  bool get isRunning => isActive && endTime == null;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    final d = end.difference(startTime);
    return d.isNegative ? Duration.zero : d;
  }

  /// Optional: set when sending to NocoDB so payload includes user_id.
  int? userId;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'tags': tags,
        'isActive': isActive,
        if (userId != null) 'user_id': userId,
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
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) => Task.fromMap(json);
}

/// NocoDB profile row payload (snake_case). Use for bulk POST upsert.
class ProfileUpdate {
  ProfileUpdate.fromSettings(UserSettings s)
      : preferredTimeZone = s.preferredTimeZone,
        timezoneOffsetHours = s.timezoneOffsetHours,
        userId = s.userId,
        themeMode = s.themeMode,
        displayName = s.displayName,
        primaryLanguage =
            s.primaryLanguage.isNotEmpty ? s.primaryLanguage : s.language;
  final String preferredTimeZone;
  final int timezoneOffsetHours;
  final int userId;
  final String themeMode;
  final String? displayName;
  final String primaryLanguage;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'preferred_timezone': preferredTimeZone,
        'timezone_offset': timezoneOffsetHours,
        'theme_mode': themeMode,
        'primary_language': primaryLanguage,
        if (displayName != null && displayName!.trim().isNotEmpty)
          'display_name': displayName!.trim(),
      };
}

/// User preferences. userId = profile id (int).
class UserSettings {
  UserSettings({
    required this.userId,
    this.language = 'en',
    this.preferredTimeZone = 'UTC',
    this.timezoneOffsetHours = 0,
    this.activeLanguages,
    this.primaryLanguage = 'en',
    this.defaultCategoryId,
    this.hasSeeded = false,
    this.themeMode = 'system',
    this.dataRegion,
    this.biometricEnabled = false,
    this.displayName,
  });

  final int userId;
  final String language;
  final String preferredTimeZone;
  final int timezoneOffsetHours;
  final List<String>? activeLanguages;
  final String primaryLanguage;
  final int? defaultCategoryId;
  final bool hasSeeded;
  final String themeMode;
  final String? dataRegion;
  /// Shown in Profile / shell; persisted as profiles.display_name (@DATA_MAP.md).
  final String? displayName;
  /// Local biometric lock on app launch. Stored in profiles; never stored in cloud as biometric data.
  final bool biometricEnabled;

  List<String> get effectiveActiveLanguages => activeLanguages ?? ['en', 'ru'];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'language': language,
        'preferredTimeZone': preferredTimeZone.isEmpty ? 'UTC' : preferredTimeZone,
        'timezoneOffsetHours': timezoneOffsetHours,
        if (activeLanguages != null && activeLanguages!.isNotEmpty) 'activeLanguages': activeLanguages,
        if (primaryLanguage.isNotEmpty) 'primaryLanguage': primaryLanguage,
        if (defaultCategoryId != null) 'defaultCategoryId': defaultCategoryId,
        'hasSeeded': hasSeeded,
        'themeMode': themeMode,
        if (dataRegion != null && dataRegion!.isNotEmpty) 'dataRegion': dataRegion,
        if (displayName != null && displayName!.trim().isNotEmpty)
          'displayName': displayName!.trim(),
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final tz = json['preferredTimeZone'] as String?;
    final preferredTimeZone = (tz == null || tz.trim().isEmpty) ? 'UTC' : tz;
    final offsetRaw = json['timezoneOffsetHours'];
    final offset = offsetRaw is int ? offsetRaw : int.tryParse(offsetRaw?.toString() ?? '') ?? 0;
    final raw = json['activeLanguages'];
    List<String>? activeLanguages;
    if (raw is List) {
      activeLanguages = raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      if (activeLanguages.isEmpty) activeLanguages = null;
    }
    return UserSettings(
      userId: _jsonInt(json['user_id'] ?? json['userId']),
      language: json['language'] as String? ?? 'en',
      preferredTimeZone: preferredTimeZone,
      timezoneOffsetHours: offset,
      activeLanguages: activeLanguages,
      primaryLanguage: json['primaryLanguage'] as String? ?? 'en',
      defaultCategoryId: json['defaultCategoryId'] == null ? null : _jsonInt(json['defaultCategoryId']),
      hasSeeded: json['hasSeeded'] as bool? ?? false,
      themeMode: json['themeMode'] as String? ?? 'system',
      dataRegion: json['dataRegion'] as String?,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      displayName: json['displayName'] as String? ?? json['display_name'] as String?,
    );
  }

  UserSettings copyWith({
    int? userId,
    String? language,
    String? preferredTimeZone,
    int? timezoneOffsetHours,
    List<String>? activeLanguages,
    String? primaryLanguage,
    int? defaultCategoryId,
    bool? hasSeeded,
    String? themeMode,
    String? dataRegion,
    bool? biometricEnabled,
    String? displayName,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      language: language ?? this.language,
      preferredTimeZone: preferredTimeZone ?? this.preferredTimeZone,
      timezoneOffsetHours: timezoneOffsetHours ?? this.timezoneOffsetHours,
      activeLanguages: activeLanguages ?? this.activeLanguages,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
      hasSeeded: hasSeeded ?? this.hasSeeded,
      themeMode: themeMode ?? this.themeMode,
      dataRegion: dataRegion ?? this.dataRegion,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      displayName: displayName ?? this.displayName,
    );
  }
}

/// Planning task (intent / todo). Stored in plans.
class PlanningTask {
  PlanningTask({
    required this.id,
    this.planRowId,
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
    this.notes,
    this.parentPlanId,
    List<int>? subRecordIds,
  })  : date = date ?? _dateFromDateKey(dateKey),
        endDateKey = endDateKey ?? (endDateTime != null ? _dateKeyFromDate(endDateTime) : dateKey),
        subRecordIds = subRecordIds ?? const [];

  final int id;
  /// Noco **plan_id** for PATCH/DELETE (@DATA_MAP.md). When null, Brain falls back to [id].toString().
  final String? planRowId;

  String get planRowIdForNoco {
    final p = planRowId?.trim() ?? '';
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
  final String? notes;
  final int? parentPlanId;
  final List<int> subRecordIds;

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
        if (parentPlanId != null) 'parent_plan_id': parentPlanId.toString(),
        if (notes != null && notes!.isNotEmpty) 'note': notes,
        if (checklist.isNotEmpty) 'checklist': checklist,
        if (startTime != null) 'start_time': startTime!.toUtc().toIso8601String(),
        if (endDateTime != null) 'end_time': endDateTime!.toUtc().toIso8601String(),
      };

  factory PlanningTask.fromJson(Map<String, dynamic> json) {
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
    final rawChecklist = json['checklist'];
    List<Map<String, dynamic>> checklist = const [];
    if (rawChecklist is List) {
      checklist = rawChecklist.whereType<Map>().map<Map<String, dynamic>>((e) {
        final map = <String, dynamic>{};
        (e).forEach((key, value) {
          map[key.toString()] = value;
        });
        return map;
      }).toList();
    }
    final notes =
        json['note']?.toString() ?? json['notes']?.toString();
    final pp = g('parentPlanId', 'parent_plan_id');
    final int? parentPlanId = pp == null || pp.toString().isEmpty ? null : _jsonInt(pp);
    final rawSubIds = g('subRecordIds', 'sub_record_ids');
    List<int> subRecordIds = const [];
    if (rawSubIds is List) {
      subRecordIds = rawSubIds.map((e) => _jsonInt(e)).where((n) => n != 0).toList();
    }
    final planPk =
        (json['plan_row_id'] ?? json['plan_id'] ?? json['planId'])?.toString().trim();
    return PlanningTask(
      id: _jsonInt(json['id']),
      planRowId: (planPk != null && planPk.isNotEmpty) ? planPk : null,
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
      notes: notes,
      parentPlanId: parentPlanId,
      subRecordIds: subRecordIds,
    );
  }

  PlanningTask copyWith({
    int? id,
    String? planRowId,
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
    String? notes,
    int? parentPlanId,
    List<int>? subRecordIds,
  }) {
    final eDt = clearEnd ? null : (endDateTime ?? this.endDateTime);
    final eDk = endDateKey ?? (eDt != null ? _dateKeyFromDate(eDt) : (clearEnd ? (dateKey ?? this.dateKey) : this.endDateKey));
    return PlanningTask(
      id: id ?? this.id,
      planRowId: planRowId ?? this.planRowId,
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
      notes: notes ?? this.notes,
      parentPlanId: parentPlanId ?? this.parentPlanId,
      subRecordIds: subRecordIds ?? this.subRecordIds,
    );
  }
}

// --- Stats tree (HIERARCHICAL STATS §8). Pure data. ---

/// One node in the hierarchical stats tree.
class StatsTreeNode {
  const StatsTreeNode({
    required this.label,
    required this.totalSeconds,
    this.children = const [],
    this.records = const [],
    this.categoryId,
  });

  final String label;
  final int totalSeconds;
  final List<StatsTreeNode> children;
  final List<Map<String, dynamic>> records;
  final int? categoryId;

  Duration get total => Duration(seconds: totalSeconds);
}

/// Records grouped by normalized title at a leaf category.
class SessionGroup {
  const SessionGroup({
    required this.label,
    required this.totalSeconds,
    required this.records,
    required this.actualTitles,
  });
  final String label;
  final int totalSeconds;
  final List<Map<String, dynamic>> records;
  final Set<String> actualTitles;
  Duration get total => Duration(seconds: totalSeconds);
}

/// Recursive stats node: full category path, with children and session groups.
class StatsNode {
  const StatsNode({
    required this.label,
    required this.totalSeconds,
    this.children = const [],
    this.sessionGroups = const [],
  });

  final String label;
  final int totalSeconds;
  final List<StatsNode> children;
  final List<SessionGroup> sessionGroups;

  Duration get total => Duration(seconds: totalSeconds);

  bool get isLeaf => children.isEmpty;
}

// --- Helpers (tag path, opacity). Pure logic on CategoryRule. ---

const List<double> _pathOpacities = [1.0, 0.8, 0.6, 0.4];

CategoryRule? _findRuleForTag(List<CategoryRule> rules, String tag) {
  final t = tag.trim().toLowerCase();
  for (final r in rules) {
    if (r.name.trim().toLowerCase() == t) return r;
    if (r.children != null) {
      final found = _findRuleForTag(r.children!, tag);
      if (found != null) return found;
    }
  }
  return null;
}

int _tagDepth(List<CategoryRule> rules, String tag, int depth) {
  if (depth > 4) return -1;
  final t = tag.trim().toLowerCase();
  for (final r in rules) {
    if (r.name.trim().toLowerCase() == t) return depth;
    if (r.children != null) {
      final d = _tagDepth(r.children!, tag, depth + 1);
      if (d >= 0) return d;
    }
  }
  return -1;
}

String getTagPath(List<CategoryRule> rules, String tag, [List<String> path = const []]) {
  final t = tag.trim().toLowerCase();
  if (t.isEmpty) return tag;
  for (final r in rules) {
    final tagName = r.name.trim();
    if (tagName.toLowerCase() == t) return [...path, tagName].join(' > ');
    if (r.children != null) {
      final found = getTagPath(r.children!, tag, [...path, tagName]);
      if (found != tag) return found;
    }
  }
  return tag;
}

Color getTagColorWithOpacity(List<CategoryRule> rules, String tag) {
  final depth = _tagDepth(rules, tag, 1);
  final level = (depth >= 1 && depth <= 4) ? depth : 1;
  final opacity = _pathOpacities[level - 1];
  final rule = _findRuleForTag(rules, tag);
  return (rule?.colorOrDefault ?? Colors.grey).withOpacity(opacity);
}
