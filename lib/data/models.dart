import 'dart:convert';
import 'dart:math' show max;

import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:flutter/material.dart';

/// How profile categories/tags render in Timeline & Planning (`profiles.tag_display_mode`).
enum CategoryDisplayMode {
  letterChip,
  chip,
  round,
  icon,
  iconCircle,
}

/// Values PATCHed to `profiles.tag_display_mode` when the server does not dictate a preserved raw string.
///
/// **Letter / “Text chip”** uses the exact PocketBase value `text chip` (space). Other modes use
/// stable ids below. [categoryDisplayModeFromWire] still accepts legacy reads (`letter_chip`, etc.).
extension CategoryDisplayModeWire on CategoryDisplayMode {
  String get wireValue => switch (this) {
        CategoryDisplayMode.letterChip => 'text chip',
        CategoryDisplayMode.chip => 'chip',
        CategoryDisplayMode.round => 'round',
        CategoryDisplayMode.icon => 'icon',
        CategoryDisplayMode.iconCircle => 'icon_in_circle',
      };
}

CategoryDisplayMode categoryDisplayModeFromWire(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'text chip':
    case 'text_chip':
    case 'textchip':
    case 'letter_chip':
    case 'letterchip':
    case 'text':
      return CategoryDisplayMode.letterChip;
    case 'chip':
    case 'pill':
      return CategoryDisplayMode.chip;
    case 'dot':
    case 'round':
      return CategoryDisplayMode.round;
    case 'icon':
      return CategoryDisplayMode.icon;
    case 'icon_circle':
    case 'iconcircle':
    case 'icon_in_circle':
      return CategoryDisplayMode.iconCircle;
    default:
      return CategoryDisplayMode.letterChip;
  }
}

/// PATCH payload for [profiles.tag_display_mode]. **Text chip** always uses the exact string
/// `text chip`. Other modes may reuse the last server spelling when it maps to the same enum.
String tagDisplayModeWireForPatch(UserSettings s) {
  if (s.tagDisplayMode == CategoryDisplayMode.letterChip) {
    return 'text chip';
  }
  final raw = s.tagDisplayModeWireRaw?.trim();
  if (raw != null &&
      raw.isNotEmpty &&
      categoryDisplayModeFromWire(raw) == s.tagDisplayMode) {
    return raw;
  }
  return s.tagDisplayMode.wireValue;
}

// ---------------------------------------------------------------------------
// DATA DNA — VAULT: lib/data/models.dart (@ARCHITECTURE.md §1, @DATA_MAP.md).
// Pure classes and serialization. No database imports.
// PKs: PocketBase row `id` (string) for REST; `record_id` on records is legacy UUID / passive metadata only.
// Other: `category_id` / `plan_id` where applicable; profiles → user_id (String).
// ---------------------------------------------------------------------------

/// Structured payload from the app backend `POST …/api/ai/parse-task` route (no vendor fields).
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

int _jsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

/// PocketBase relation field: plain id or `{ "id": "..." }` from expand.
String? pbRelationIdFromDynamic(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final s = raw.trim();
    return s.isEmpty ? null : s;
  }
  if (raw is Map) {
    final id = raw['id'];
    if (id == null) return null;
    final s = id.toString().trim();
    return s.isEmpty ? null : s;
  }
  return null;
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

/// PocketBase record row `id` (no hyphens, ~15 chars) — **not** the legacy `record_id` UUID.
bool _isPbRecordsRowIdSegment(String s) {
  final t = s.trim();
  if (t.isEmpty || t.contains('-')) return false;
  if (t.length < 14 || t.length > 17) return false;
  return RegExp(r'^[a-z0-9]+$').hasMatch(t);
}

/// Value allowed as REST path segment for **records** (PB id, legacy int string, or client `optimistic-*` key).
bool _isTimelineRestRowId(String s) {
  final t = s.trim();
  if (t.isEmpty) return false;
  if (_isPbRecordsRowIdSegment(t)) return true;
  if (int.tryParse(t) != null) return true;
  if (t.startsWith('optimistic-')) return true;
  return false;
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

String _twoIso(int n) => n.toString().padLeft(2, '0');

/// UTC ISO-8601 with **second** precision only — avoids client/server sub-second drift in UI compares.
String _iso8601UtcSecondsPrecision(DateTime utc) {
  final u = utc.toUtc();
  final t = DateTime.utc(
    u.year,
    u.month,
    u.day,
    u.hour,
    u.minute,
    u.second,
  );
  return '${t.year.toString().padLeft(4, '0')}-${_twoIso(t.month)}-${_twoIso(t.day)}T'
      '${_twoIso(t.hour)}:${_twoIso(t.minute)}:${_twoIso(t.second)}.000Z';
}

/// Normalize stored record timestamp strings (PocketBase may vary fractional digits).
String? normalizeRecordIsoToUtcSecondPrecision(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) {
    return _iso8601UtcSecondsPrecision(raw);
  }
  var s = raw.toString().trim();
  if (s.isEmpty) return null;
  if (s.contains(' ') && !s.contains('T')) {
    s = s.replaceFirst(' ', 'T');
  }
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return raw.toString();
  return _iso8601UtcSecondsPrecision(parsed);
}

DateTime? _parseToUtcSecondPrecision(dynamic v) {
  if (v == null) return null;
  final dt = v is DateTime
      ? v
      : DateTime.tryParse(v.toString().trim().replaceFirst(' ', 'T'));
  if (dt == null) return null;
  final u = dt.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// Profile row (legacy int shape); prefer [UserProfile] for PocketBase `profiles`.
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

/// Category row (flat). @DATA_MAP.md: PB row `id` (string), [category_id], [name], [normalized_id].
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
    this.isArchived = false,
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
  final bool isArchived;

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
    final arc = json['is_archived'] ?? json['isArchived'];
    final isArc = arc == true ||
        arc == 1 ||
        (arc is String && arc.toLowerCase().trim() == 'true');
    return Category(
      id: (rawId ?? '').toString(),
      userId: _jsonInt(json['user_id']),
      name: resolvedName,
      tag: display ?? 'Untitled',
      parentId: pid == null || pid.toString().isEmpty ? null : _jsonInt(pid),
      normalizedId: json['normalized_id']?.toString(),
      colorValue: json['color_value'] is int ? json['color_value'] as int : int.tryParse(json['color_value']?.toString() ?? ''),
      iconCodePoint: json['icon_code_point'] is int ? json['icon_code_point'] as int : int.tryParse(json['icon_code_point']?.toString() ?? ''),
      isArchived: isArc,
    );
  }

  /// Subset of PocketBase `categories` columns (@DATA_MAP.md) for diagnostics / cache.
  /// Note: [userId] is a local int hash of `user_id` when the server sends non-numeric ids
  /// ([_jsonInt]); do not use this map as a verbatim POST body for relation fields.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        if (name != null && name!.isNotEmpty) 'name': name,
        if (normalizedId != null && normalizedId!.isNotEmpty)
          'normalized_id': normalizedId,
        if (parentId != null) 'parent_id': parentId,
        if (colorValue != null) 'color_value': colorValue,
        if (iconCodePoint != null) 'icon_code_point': iconCodePoint,
        'is_archived': isArchived,
      };
}

/// Create-category dialog: name availability vs active tree + archived PB rows.
enum CategoryNameInputKind { empty, available, active, archived }

class CategoryNameInputStatus {
  const CategoryNameInputStatus._({
    required this.kind,
    this.activeLocalId,
    this.archivedPbRowId,
  });

  final CategoryNameInputKind kind;
  final int? activeLocalId;
  final String? archivedPbRowId;

  static const CategoryNameInputStatus empty =
      CategoryNameInputStatus._(kind: CategoryNameInputKind.empty);

  static const CategoryNameInputStatus available =
      CategoryNameInputStatus._(kind: CategoryNameInputKind.available);

  factory CategoryNameInputStatus.active(int localId) {
    return CategoryNameInputStatus._(
      kind: CategoryNameInputKind.active,
      activeLocalId: localId,
    );
  }

  factory CategoryNameInputStatus.archived(String pbRowId) {
    return CategoryNameInputStatus._(
      kind: CategoryNameInputKind.archived,
      archivedPbRowId: pbRowId,
    );
  }
}

/// Noco `@DATA_MAP` checklist: column may be JSON **String** or decoded List.
List<Map<String, dynamic>>? parseChecklistFromNoco(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) {
    if (raw.isEmpty) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(Map<String, dynamic>.from(e));
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final d = jsonDecode(s);
      if (d is List) {
        final out = <Map<String, dynamic>>[];
        for (final e in d) {
          if (e is Map<String, dynamic>) {
            out.add(Map<String, dynamic>.from(e));
          } else if (e is Map) {
            out.add(Map<String, dynamic>.from(e));
          }
        }
        return out;
      }
    } catch (_) {}
  }
  return null;
}

/// Same as [parseChecklistFromNoco] but never null (empty list default).
List<Map<String, dynamic>> parseChecklistFromNocoList(dynamic raw) =>
    parseChecklistFromNoco(raw) ?? const [];

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
        if (date != null)
          'date': '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
      };

  /// Same field shape as [toJson] (API / cache maps).
  Map<String, dynamic> toMap() => toJson();
}

/// DNA helper: naive calendar day from `start_time` (UTC→device [DateTime.toLocal]). **Timeline buckets** use profile wall-clock in `DatabaseService` only ([DATA_MAP] records §8 / `wall_clock.dart`).
DateTime? _recordLocalCalendarDate(dynamic v) {
  if (v == null) return null;
  DateTime? parsed;
  if (v is DateTime) {
    parsed = v.isUtc ? v : v.toUtc();
  } else {
    var s = v.toString().trim();
    if (s.isEmpty) return null;
    if (s.contains(' ') && !s.contains('T')) {
      s = s.replaceFirst(' ', 'T');
    }
    final hasTz = s.endsWith('Z') ||
        s.contains('+') ||
        (s.length > 11 && s.substring(11).contains('-'));
    parsed = DateTime.tryParse(hasTz ? s : '${s}Z');
  }
  if (parsed == null) return null;
  final loc = parsed.toUtc().toLocal();
  return DateTime(loc.year, loc.month, loc.day);
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

/// Strict hierarchical category. Supports optional keywords per language (MULTILINGUAL_KEYWORDS).
class CategoryRule {
  /// Synthetic id for records whose Noco `category_id` does not match any loaded rule.
  static const int uncategorizedSyntheticId = -1;

  CategoryRule({
    required this.id,
    required this.name,
    this.backendRowId,
    this.normalizedId,
    this.children,
    this.colorValue,
    this.iconCodePoint,
    this.keywords,
    this.localizedNames,
    this.order = 0,
    this.isArchived = false,
    this.isSynced = true,
  });

  factory CategoryRule.uncategorized() {
    return CategoryRule(
      id: uncategorizedSyntheticId,
      name: 'Uncategorized',
      backendRowId: 'uncategorized',
      normalizedId: 'uncategorized',
      isArchived: false,
      isSynced: true,
    );
  }

  final int id;
  /// @DATA_MAP.md `categories.name` (display name).
  String name;
  /// PocketBase **categories** collection record id (PATCH/DELETE).
  final String? backendRowId;
  final String? normalizedId;
  /// String business key from DB (e.g. slug / UUID). May differ from [name] when resolving archive unique constraints.
  String get categoryKey =>
      (normalizedId ?? '').trim().isNotEmpty
          ? normalizedId!.trim()
          : (backendRowId ?? '').trim().isNotEmpty
              ? backendRowId!.trim()
              : name.trim();
  List<CategoryRule>? children;
  int? colorValue;
  int? iconCodePoint;
  /// @DATA_MAP.md `categories.order` — sibling sort index (integer); persisted via bulk PATCH.
  int order;
  /// @DATA_MAP `is_archived` — soft-deleted categories stay in DB but off active lists.
  /// Uniqueness checks and “category exists” logic must ignore archived rows (zombie slug conflicts).
  bool isArchived;
  /// Local-only: queued / cache state (not sent to PocketBase as a field).
  bool isSynced;
  Map<String, List<String>>? keywords;
  final Map<String, String>? localizedNames;

  CategoryRule copyWith({
    int? id,
    String? name,
    String? backendRowId,
    String? normalizedId,
    List<CategoryRule>? children,
    int? colorValue,
    int? iconCodePoint,
    Map<String, List<String>>? keywords,
    Map<String, String>? localizedNames,
    int? order,
    bool? isArchived,
    bool? isSynced,
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
      backendRowId: backendRowId ?? this.backendRowId,
      normalizedId: normalizedId ?? this.normalizedId,
      children: copiedChildren,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      keywords: copiedKeywords,
      localizedNames: localizedNames ?? this.localizedNames,
      order: order ?? this.order,
      isArchived: isArchived ?? this.isArchived,
      isSynced: isSynced ?? this.isSynced,
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

  static bool _isAsciiWordCharAt(String s, int i) {
    if (i < 0 || i >= s.length) return false;
    final c = s.codeUnitAt(i);
    return (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a);
  }

  /// Longest [needleLower] length if it appears in [hayLower] at word boundaries (not inside a longer token).
  static int _wordBoundedOccurrenceScore(String hayLower, String needleLower) {
    if (hayLower.isEmpty || needleLower.isEmpty) return 0;
    if (needleLower.length < 2) return 0;
    var found = 0;
    var start = 0;
    while (true) {
      final i = hayLower.indexOf(needleLower, start);
      if (i < 0) break;
      final beforeOk = i == 0 || !_isAsciiWordCharAt(hayLower, i - 1);
      final after = i + needleLower.length;
      final afterOk =
          after >= hayLower.length || !_isAsciiWordCharAt(hayLower, after);
      if (beforeOk && afterOk) found = needleLower.length;
      start = i + 1;
    }
    return found;
  }

  static void _accumulatePairScores(
    String tLower,
    String fragmentLower,
    void Function(int len) onScore,
  ) {
    if (fragmentLower.isEmpty) return;
    if (fragmentLower.length < 2) return;
    final a = _wordBoundedOccurrenceScore(tLower, fragmentLower);
    if (a > 0) onScore(a);
    final b = _wordBoundedOccurrenceScore(fragmentLower, tLower);
    if (b > 0) onScore(b);
  }

  static String _categoryTokenAliasOrSelf(String tok) =>
      kCategoryMatchingTokenAliases[tok] ?? tok;

  /// Aligns normalized title tokens with a category phrase (name or keyword tokens).
  /// Skips numeric-only title tokens so `laredo 10` can still match `laredo ts`.
  /// Exact token equality scores higher than prefix-of-category-token ([ct.startsWith(tt)]).
  static int _consecutiveCategoryTokenScore(
    List<String> titleToks,
    List<String> catToks,
  ) {
    if (catToks.isEmpty) return 0;
    var i = 0;
    var j = 0;
    var sc = 0;
    while (i < titleToks.length && j < catToks.length) {
      final rawTt = titleToks[i];
      if (rawTt.isEmpty) {
        i++;
        continue;
      }
      if (rawTt.length < 2 || RegExp(r'^\d+$').hasMatch(rawTt)) {
        i++;
        continue;
      }
      final tt = _categoryTokenAliasOrSelf(rawTt);
      final ct = catToks[j];
      if (ct.length < 2) {
        j++;
        continue;
      }
      if (tt == ct) {
        sc += 200000 + tt.length * 1000 + ct.length;
        i++;
        j++;
      } else if (ct.startsWith(tt)) {
        sc += 100000 + tt.length * 1000;
        i++;
        j++;
      } else if (tt.startsWith(ct)) {
        sc += 80000 + ct.length * 1000;
        i++;
        j++;
      } else {
        break;
      }
    }
    return sc;
  }

  /// Case-insensitive token / prefix match (uses [normalizeCategoryLabel]).
  /// Runs after substring [categoryExactMatchScoreForTitle], before fuzzy Levenshtein.
  int categoryConsecutiveTokenMatchScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    final titleToks = nt.split(' ').where((t) => t.isNotEmpty).toList();
    if (titleToks.isEmpty) return 0;
    var best = 0;
    void considerFrag(String raw) {
      final frag = normalizeCategoryLabel(raw);
      if (frag.isEmpty) return;
      final catToks = frag.split(' ').where((t) => t.isNotEmpty).toList();
      best = max(best, _consecutiveCategoryTokenScore(titleToks, catToks));
    }

    considerFrag(name);
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          considerFrag(kw);
        }
      }
    }
    return best;
  }

  /// ≥60% of unique category tokens (whole words, [normalizeCategoryLabel]) appear in [title].
  /// Score band below consecutive-token matches; use when strict ordering misses (e.g. missing "Services").
  int categoryTokenSetOverlapScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    final titleToks = <String>{};
    for (final raw in nt.split(' ').where((x) => x.isNotEmpty)) {
      if (raw.length < 2 || RegExp(r'^\d+$').hasMatch(raw)) continue;
      titleToks.add(_categoryTokenAliasOrSelf(raw));
    }
    if (titleToks.isEmpty) return 0;

    var best = 0;
    void considerFrag(String raw) {
      final frag = normalizeCategoryLabel(raw);
      if (frag.isEmpty) return;
      final catToks = frag
          .split(' ')
          .where((x) => x.isNotEmpty && x.length >= 2)
          .map(_categoryTokenAliasOrSelf)
          .toList();
      if (catToks.isEmpty) return;
      final catSet = catToks.toSet();
      final n = catSet.length;
      final need = ((n * 60) + 99) ~/ 100;
      final inter = titleToks.intersection(catSet);
      if (inter.length < need) return;
      final sc = 30000 + inter.length * 5000 + n * 100 + frag.length;
      best = max(best, sc);
    }

    considerFrag(name);
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          considerFrag(kw);
        }
      }
    }
    return best;
  }

  /// Highest word-bounded match length for [name] / **keywords** vs [title]
  /// using [normalizeCategoryLabel] for both sides (exact substring at token boundaries).
  /// Longer matches win over shorter ones (e.g. "NIS SOLUTIONS" beats "CRM" in the same title).
  int categoryExactMatchScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    var best = 0;
    final selfName = normalizeCategoryLabel(name);
    if (selfName.isNotEmpty) {
      _accumulatePairScores(nt, selfName, (len) => best = max(best, len));
    }
    if (keywords != null) {
      for (final list in keywords!.values) {
        for (final kw in list) {
          final k = normalizeCategoryLabel(kw);
          if (k.isNotEmpty) {
            _accumulatePairScores(nt, k, (len) => best = max(best, len));
          }
        }
      }
    }
    return best;
  }

  /// Fuzzy (Levenshtein-gated) score when [categoryExactMatchScoreForTitle] is zero.
  int categoryFuzzyMatchScoreForTitle(String title) {
    final nt = normalizeCategoryLabel(title);
    if (nt.isEmpty) return 0;
    final frags = <String>[name];
    if (keywords != null) {
      for (final list in keywords!.values) {
        frags.addAll(list);
      }
    }
    return fuzzyMatchScoreForNormalizedTitle(nt, frags);
  }

  /// True when substring, consecutive-token, token-set majority, or fuzzy match applies.
  bool matchesTitleWholeWordKeywords(String title) =>
      categoryExactMatchScoreForTitle(title) > 0 ||
      categoryConsecutiveTokenMatchScoreForTitle(title) > 0 ||
      categoryTokenSetOverlapScoreForTitle(title) > 0 ||
      categoryFuzzyMatchScoreForTitle(title) > 0;

  CategoryRule? findDeepestMatch(
    String title, {
    required int Function(CategoryRule rule, String title) scoreFor,
  }) {
    if (title.trim().isEmpty) return null;
    CategoryRule? best;
    var bestScore = -1;
    var bestDepth = -1;
    var bestNameLen = -1;

    void visit(CategoryRule r, int depth) {
      if (depth > 4) return;
      if (!r.isArchived) {
        final sc = scoreFor(r, title);
        if (sc > 0) {
          final nameLen = r.name.trim().length;
          if (best == null ||
              sc > bestScore ||
              (sc == bestScore && depth > bestDepth) ||
              (sc == bestScore &&
                  depth == bestDepth &&
                  nameLen > bestNameLen)) {
            best = r;
            bestScore = sc;
            bestDepth = depth;
            bestNameLen = nameLen;
          }
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
        if (backendRowId != null && backendRowId!.isNotEmpty) 'backendRowId': backendRowId,
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
        'isArchived': isArchived,
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
    final archivedRaw = data['is_archived'] ?? data['isArchived'];
    final isArc = archivedRaw == true ||
        archivedRaw == 1 ||
        (archivedRaw is String &&
            archivedRaw.toLowerCase().trim() == 'true');
    return CategoryRule(
      id: int.tryParse(rawId) ?? rawId.hashCode,
      name: safeTag,
      backendRowId: rawId,
      normalizedId: (data['category_id'] ?? data['id1'] ?? data['normalized_id'] ?? data['normalizedId'])?.toString(),
      children: children.isEmpty ? null : children,
      colorValue: colorRaw is int ? colorRaw : (colorRaw != null ? int.tryParse(colorRaw.toString()) : null),
      iconCodePoint: iconRaw is int ? iconRaw : (iconRaw != null ? int.tryParse(iconRaw.toString()) : null),
      keywords: keywords,
      localizedNames: localizedNames,
      order: orderVal,
      isArchived: isArc,
      isSynced: _jsonBool(data['isSynced'] ?? json['isSynced'], true),
    );
  }
}

/// In-memory representation of a timeline record. Hierarchy: parentId + [id].
/// Calendar day for UI is derived from [startTime] using **device-local** date, not UTC prefix.
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

  /// ISO `YYYY-MM-DD` from [startTime] in **device-local** calendar (matches timeline list buckets).
  String get dateKey {
    final st = startTime;
    if (st == null) return '';
    final loc = st.toUtc().toLocal();
    return '${loc.year}-${loc.month.toString().padLeft(2, '0')}-${loc.day.toString().padLeft(2, '0')}';
  }

  /// Basta: [endTime] set ⇒ not running, regardless of [status] string.
  bool get isActuallyRunning =>
      endTime == null && status == 'running';

  static dynamic _get(Map<String, dynamic> data, String camel, String snake) =>
      data[camel] ?? data[snake];

  factory TimelineRecord.fromMap(Map<String, dynamic> data, {String? systemId}) {
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

/// Profile PATCH body (snake_case) for PocketBase — no `user_id` (owner is the auth record).
class ProfileUpdate {
  ProfileUpdate.fromSettings(UserSettings s)
      : preferredTimeZone = s.preferredTimeZone,
        timezoneOffsetHours = s.timezoneOffsetHours,
        themeMode = s.themeMode,
        displayName = s.displayName,
        primaryLanguage =
            s.primaryLanguage.isNotEmpty ? s.primaryLanguage : s.language,
        tagDisplayMode = tagDisplayModeWireForPatch(s);
  final String preferredTimeZone;
  final int timezoneOffsetHours;
  final String themeMode;
  final String? displayName;
  final String primaryLanguage;
  final String tagDisplayMode;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'preferred_timezone': preferredTimeZone,
        'timezone_offset': timezoneOffsetHours,
        'theme_mode': themeMode,
        'primary_language': primaryLanguage,
        'active_languages': <String>[
          resolvedUiLanguageCode(primaryLanguage),
        ],
        'tag_display_mode': tagDisplayMode,
        if (displayName != null && displayName!.trim().isNotEmpty)
          'display_name': displayName!.trim(),
      };
}

/// User preferences. [userId] = PocketBase auth record id / `user_id` on child rows (string).
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
    this.tagDisplayMode = CategoryDisplayMode.letterChip,
    this.tagDisplayModeWireRaw,
  });

  final String userId;
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
  /// Minimalist chip style for categories/tags (Timeline, Planning). `profiles.tag_display_mode`.
  final CategoryDisplayMode tagDisplayMode;
  /// Exact string last read from PocketBase for [tagDisplayMode] (Select option spelling).
  final String? tagDisplayModeWireRaw;

  /// Single UI language: derived from [primaryLanguage] / [language] (multi-active UI removed).
  List<String> get effectiveActiveLanguages => <String>[
        resolvedUiLanguageCode(
          primaryLanguage.trim().isNotEmpty ? primaryLanguage : language,
        ),
      ];

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
        'tagDisplayMode': tagDisplayMode.wireValue,
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
    final tagWire = json['tag_display_mode'] ?? json['tagDisplayMode'];
    final tagWireStr = tagWire?.toString().trim();
    return UserSettings(
      userId: (json['user_id'] ?? json['userId'])?.toString() ?? '',
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
      tagDisplayMode: categoryDisplayModeFromWire(tagWireStr),
      tagDisplayModeWireRaw:
          (tagWireStr != null && tagWireStr.isNotEmpty) ? tagWireStr : null,
    );
  }

  UserSettings copyWith({
    String? userId,
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
    CategoryDisplayMode? tagDisplayMode,
    String? tagDisplayModeWireRaw,
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
      tagDisplayMode: tagDisplayMode ?? this.tagDisplayMode,
      tagDisplayModeWireRaw: tagDisplayMode != null
          ? null
          : (tagDisplayModeWireRaw ?? this.tagDisplayModeWireRaw),
    );
  }
}

/// Tag row. Business PK is [tagId] (`tag_id`); [wrapperRowId] optional legacy table row id.
/// **PocketBase:** [pbRecordId] is the only id safe for `plans.tags_link` / relation writes.
class Tag {
  const Tag({
    required this.tagId,
    required this.name,
    this.color,
    this.icon,
    this.wrapperRowId,
    this.pbRecordId,
    this.sortOrder = 0,
    this.isSynced = true,
  });

  final int tagId;
  final String name;
  final String? color;
  final String? icon;
  /// Legacy numeric wrapper id (non–PocketBase hosts).
  final int? wrapperRowId;
  /// PocketBase **tags** collection record id.
  final String? pbRecordId;
  /// Display / grouping order in Planning (`tags.sort_order`); lower = first.
  final int sortOrder;
  /// Local-only sync flag (not a PocketBase column).
  final bool isSynced;

  Tag copyWith({
    int? tagId,
    String? name,
    String? color,
    String? icon,
    int? wrapperRowId,
    String? pbRecordId,
    int? sortOrder,
    bool? isSynced,
  }) {
    return Tag(
      tagId: tagId ?? this.tagId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      wrapperRowId: wrapperRowId ?? this.wrapperRowId,
      pbRecordId: pbRecordId ?? this.pbRecordId,
      sortOrder: sortOrder ?? this.sortOrder,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Whether a planning (or similar) chip should render — excludes junk rows from incomplete Noco M2M parse.
  bool get rendersAsChip =>
      tagId != 0 ||
      name.trim().isNotEmpty ||
      (wrapperRowId ?? 0) > 0 ||
      (pbRecordId != null && pbRecordId!.trim().isNotEmpty);

  factory Tag.fromNocoJson(Map<String, dynamic> json) {
    // Brain `_flattenNocoRecord` may stamp wrapper int as `id` or `_noco_system_row_id` (@DATA_MAP tags `Id`).
    final wrap = _jsonInt(
      json['id'] ?? json['Id'] ?? json['ID'] ?? json['_noco_system_row_id'],
    );
    final hasBizTagIdKey = json.containsKey('tag_id') ||
        json.containsKey('Tag_id') ||
        json.containsKey('tagId');
    var tid = _jsonInt(
      json['tag_id'] ?? json['Tag_id'] ?? json['tagId'],
    );
    // Never treat wrapper Id as business `tag_id` when `tag_id` is present (even if 0 = bad row).
    if (!hasBizTagIdKey && tid == 0 && wrap > 0) tid = wrap;
    return Tag(
      tagId: tid,
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      wrapperRowId: wrap > 0 ? wrap : null,
      pbRecordId: json['pocket_id']?.toString(),
      sortOrder: _jsonInt(json['sort_order'] ?? json['sortOrder']),
      isSynced: _jsonBool(json['isSynced'] ?? json['is_synced'], true),
    );
  }

  /// PocketBase **tags** row map (`id`, `tag_id`, `name`, …). Always set [pbRecordId] from the collection row id when present.
  factory Tag.fromPocketJson(Map<String, dynamic> json) {
    final rid = (json['id'] ?? json['recordId'])?.toString().trim();
    return Tag(
      tagId: _jsonInt(json['tag_id']),
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      wrapperRowId: null,
      pbRecordId: (rid != null && rid.isNotEmpty) ? rid : null,
      sortOrder: _jsonInt(json['sort_order'] ?? json['sortOrder']),
      isSynced: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Tag && other.tagId == tagId;

  @override
  int get hashCode => tagId.hashCode;
}

/// Brain suggestion when a free-running record may match today’s open plan (@DATA_MAP `source_plan_id`).
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
    this.notes,
    this.parentPlanId,
    List<int>? subRecordIds,
    List<Tag>? tags,
    this.isSynced = true,
    /// Wall `YYYY-MM-DD`: audit anchor (commitment day). Set on create; preserved when postponing.
    this.initialDateKey,
    this.isPostponed = false,
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
  String get recordIdForBackend {
    final pb = pocketRecordId?.trim() ?? '';
    if (pb.isNotEmpty) return pb;
    if (id > 0) return id.toString();
    final p = planRowId?.trim() ?? '';
    return p;
  }

  /// Stable plan row id for PocketBase CRUD (`pocketRecordId`, else legacy int / `planRowId`).
  /// Stays `optimistic-…` for optimistic rows only.
  String get planRowIdForBackend {
    final p = planRowId?.trim() ?? '';
    if (p.startsWith('optimistic-')) return p;
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
  final String? notes;
  final int? parentPlanId;
  final List<int> subRecordIds;
  final List<Tag> tags;
  /// Local-only: false for optimistic / outbox rows until PocketBase confirms.
  final bool isSynced;

  /// PocketBase [plans.initial_date_key] — wall day the task was first planned for.
  final String? initialDateKey;

  /// PocketBase [plans.is_postponed] — scheduled day is after [initialDateKey].
  final bool isPostponed;

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
        if (parentPlanId != null) 'parent_plan_id': parentPlanId.toString(),
        if (notes != null && notes!.isNotEmpty) 'note': notes,
        if (checklist.isNotEmpty) 'checklist': checklist,
        if (startTime != null) 'start_time': startTime!.toUtc().toIso8601String(),
        if (endDateTime != null) 'end_time': endDateTime!.toUtc().toIso8601String(),
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
      notes: notes,
      parentPlanId: parentPlanId,
      subRecordIds: subRecordIds,
      tags: tagList,
      isSynced: _jsonBool(g('isSynced', 'is_synced'), true),
      initialDateKey: _normInitialDateKey(
        g('initialDateKey', 'initial_date_key')?.toString(),
      ),
      isPostponed: _jsonBool(g('isPostponed', 'is_postponed'), false),
    );
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
    String? notes,
    int? parentPlanId,
    List<int>? subRecordIds,
    List<Tag>? tags,
    bool? isSynced,
    String? initialDateKey,
    bool? isPostponed,
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
      notes: notes ?? this.notes,
      parentPlanId: parentPlanId ?? this.parentPlanId,
      subRecordIds: subRecordIds ?? this.subRecordIds,
      tags: tags ?? this.tags,
      isSynced: isSynced ?? this.isSynced,
      initialDateKey: initialDateKey ?? this.initialDateKey,
      isPostponed: isPostponed ?? this.isPostponed,
    );
  }
}

/// One scalar PATCH for [`DatabaseService.bulkUpdatePlans`] — no tag sync; PB row id via [planRowId].
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

/// Simple plan vs fact rollups for one wall day: current schedule vs records that day.
class BasicDayStats {
  const BasicDayStats({
    required this.planTaskCount,
    required this.factDistinctPlansFromRecords,
    required this.planTimeSeconds,
    required this.factTimeSeconds,
    required this.plannedSecByCategory,
    required this.actualSecByCategory,
    required this.plansScheduledThisDay,
  });

  /// All planning rows whose [planningWallScheduleDateKey] is this day.
  final int planTaskCount;

  /// Distinct plan PocketBase ids appearing as [records.source_plan_id] on this wall day (with logged time).
  final int factDistinctPlansFromRecords;

  /// Sum of plan start→end durations for rows on this day (omits open-ended plans).
  final int planTimeSeconds;

  /// Sum of record durations attributed to this wall day.
  final int factTimeSeconds;

  final Map<int, int> plannedSecByCategory;
  final Map<int, int> actualSecByCategory;

  /// Plans scheduled on this day (for optional “no time logged” hints in UI).
  final List<PlanningTask> plansScheduledThisDay;
}

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
