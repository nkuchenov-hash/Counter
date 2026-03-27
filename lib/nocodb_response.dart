// NocoDB v3 response/request helpers. IDs: int or String UUID; relations → scalars.

/// Unwraps NocoDB Link / BelongsTo payloads to a single id value.
/// - [Map] → `id` / `Id` / `ID` / `category_id` (first non-null)
/// - [List] of maps → same on first element
/// - [List] of scalars → first element
/// - Otherwise → returned as-is
dynamic normalizeNocoLinkField(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    final v = m['id'] ?? m['Id'] ?? m['ID'] ?? m['category_id'];
    if (v != null) return v;
    return raw;
  }
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is Map) {
      return normalizeNocoLinkField(first);
    }
    return first;
  }
  return raw;
}

void _injectTopLevelIdsIntoFields(
  Map<String, dynamic> fields,
  Map<String, dynamic> record,
) {
  final topId = record['id'] ??
      record['Id'] ??
      record['ID'] ??
      record['record_id'] ??
      record['Record_id'];
  final topIdStr = topId?.toString().trim() ?? '';
  final existingId = fields['id'];
  final existingIdStr = existingId?.toString().trim() ?? '';
  final idMissing = existingIdStr.isEmpty;
  // Authoritative PK always comes from top-level server row when present.
  if (topIdStr.isNotEmpty) {
    fields['id'] = topId;
  } else if (idMissing) {
    // Never use category_id as row PK here — same RECORD_PK_GUARD as Brain flatten.
    final fromFields = fields['record_id'] ??
        fields['Record_id'] ??
        fields['id'] ??
        fields['Id'] ??
        fields['ID'];
    if (fromFields != null && fromFields.toString().trim().isNotEmpty) {
      fields['id'] = fromFields;
    }
  }
  final topRid = record['record_id'] ?? record['Record_id'];
  if (topRid != null &&
      (!fields.containsKey('record_id') ||
          fields['record_id'] == null ||
          fields['record_id'].toString().trim().isEmpty)) {
    fields['record_id'] = topRid;
  }
}

/// If value looks like a Noco relation object/list, flatten to scalar id.
void _normalizeCommonRelationKeys(Map<String, dynamic> fields) {
  const keys = <String>[
    'category_id',
    'Category_id',
    'parent_id',
    'user_id',
    'parent_plan_id',
  ];
  for (final k in keys) {
    if (!fields.containsKey(k)) continue;
    final v = fields[k];
    if (v is Map || (v is List && v.isNotEmpty)) {
      fields[k] = normalizeNocoLinkField(v);
    }
  }
}

/// Drills `records[]` → `fields`, merges top-level `id`/`Id`/`ID`/`record_id`, normalizes link columns.
class NocoDbResponse {
  final List<Map<String, dynamic>> records;

  NocoDbResponse({required this.records});

  factory NocoDbResponse.fromJson(Map<String, dynamic> json) {
    final rawList = (json['records'] ?? json['list']) as List?;

    if (rawList == null) return NocoDbResponse(records: []);

    return NocoDbResponse(
      records: rawList.map((item) {
        final record = Map<String, dynamic>.from(item as Map);
        final fields = Map<String, dynamic>.from(record['fields'] ?? record);
        _injectTopLevelIdsIntoFields(fields, record);
        _normalizeCommonRelationKeys(fields);
        return fields;
      }).toList(),
    );
  }

  bool get isEmpty => records.isEmpty;
  Map<String, dynamic>? get first => records.isNotEmpty ? records.first : null;
}

/// Wrapper for NocoDB v3 bulk POST/PATCH. Nests payload under "fields".
/// Use: `jsonEncode([nocoRequest.toJson()])` for bulk array.
///
/// [id] must be the real Noco row primary key: **int** (legacy) or **String** (UUID).
/// Do not use [int] in the type — that forced UUID flows to break or default to 0.
class NocoRequest {
  NocoRequest({required this.id, required this.fields});

  /// Row PK as returned by Noco (`int` or `String` UUID).
  final Object id;
  final Map<String, dynamic> fields;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'fields': fields};

  /// Single object payload: {"id": ..., "fields": {...}}
  static Map<String, dynamic> single({
    Object? id,
    required Map<String, dynamic> fields,
  }) {
    final out = <String, dynamic>{'fields': fields};
    if (id != null) out['id'] = id;
    return out;
  }

  /// Bulk payload (recommended by NocoDB v3): [{"id": ..., "fields": {...}}]
  static List<Map<String, dynamic>> bulk(List<NocoRequest> requests) {
    return requests.map((r) => r.toJson()).toList();
  }
}
