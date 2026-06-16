// Part of lib/data/models.dart — Tag.
// Split per ROADMAP Tier 4.2 (April 2026).
part of '../models.dart';

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
    /// PocketBase `tags.domain`: `plan` | `list`. Legacy rows: treat as plan when empty.
    this.domain = 'plan',
    /// PocketBase `tags.default_plan_duration_minutes` — optional default block length.
    this.defaultPlanDurationMinutes,
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
  /// Isolation scope for Lists vs Planning tag pickers (@DATA_MAP `tags.domain`).
  final String domain;
  /// Minutes for auto-scheduled plan blocks when this tag is on the task (null = none).
  final int? defaultPlanDurationMinutes;

  Tag copyWith({
    int? tagId,
    String? name,
    String? color,
    String? icon,
    int? wrapperRowId,
    String? pbRecordId,
    int? sortOrder,
    bool? isSynced,
    String? domain,
    int? defaultPlanDurationMinutes,
    bool clearDefaultPlanDuration = false,
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
      domain: domain ?? this.domain,
      defaultPlanDurationMinutes: clearDefaultPlanDuration
          ? null
          : (defaultPlanDurationMinutes ?? this.defaultPlanDurationMinutes),
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
      domain: 'plan',
    );
  }

  /// PocketBase **tags** row map (`id`, `tag_id`, `name`, …). Always set [pbRecordId] from the collection row id when present.
  factory Tag.fromPocketJson(Map<String, dynamic> json) {
    final rid = (json['id'] ?? json['recordId'])?.toString().trim();
    final domDyn = json['domain'];
    final domRaw = domDyn == null
        ? ''
        : domDyn.toString().trim().toLowerCase();
    final dom = domRaw == 'list' ? 'list' : 'plan';
    return Tag(
      tagId: _jsonInt(json['tag_id']),
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      wrapperRowId: null,
      pbRecordId: (rid != null && rid.isNotEmpty) ? rid : null,
      sortOrder: _jsonInt(json['sort_order'] ?? json['sortOrder']),
      isSynced: true,
      domain: dom,
      defaultPlanDurationMinutes: _jsonOptionalPositiveInt(
        json['default_plan_duration_minutes'] ??
            json['defaultPlanDurationMinutes'],
      ),
    );
  }

  static int? _jsonOptionalPositiveInt(dynamic raw) {
    if (raw == null) return null;
    final n = raw is int ? raw : int.tryParse(raw.toString().trim());
    if (n == null || n < 1) return null;
    return n;
  }

  @override
  bool operator ==(Object other) =>
      other is Tag && other.tagId == tagId;

  @override
  int get hashCode => tagId.hashCode;
}

