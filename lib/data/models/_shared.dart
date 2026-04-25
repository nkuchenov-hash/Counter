// Part of lib/data/models.dart — shared private helpers and CategoryDisplayMode.
// Split per ROADMAP Tier 4.2 (April 2026).
part of '../models.dart';

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

