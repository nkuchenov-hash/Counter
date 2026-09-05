library;

enum PersonRelationshipStatus {
  important('important'),
  known('known'),
  reference('reference'),
  ignored('ignored'),
  blocked('blocked');

  const PersonRelationshipStatus(this.wireValue);
  final String wireValue;

  static PersonRelationshipStatus fromWire(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => PersonRelationshipStatus.known,
    );
  }
}

enum PeopleSourceProvider {
  deviceContacts('device_contacts'),
  googleContacts('google_contacts'),
  microsoft('microsoft'),
  vk('vk'),
  telegram('telegram'),
  facebook('facebook'),
  manual('manual');

  const PeopleSourceProvider(this.wireValue);
  final String wireValue;

  bool get usesServerOAuth => switch (this) {
        PeopleSourceProvider.googleContacts ||
        PeopleSourceProvider.microsoft ||
        PeopleSourceProvider.vk ||
        PeopleSourceProvider.facebook => true,
        _ => false,
      };

  static PeopleSourceProvider? fromWire(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }
}

enum PeopleSourceImportState {
  unknown('unknown'),
  candidate('candidate'),
  linked('linked'),
  ignored('ignored'),
  blocked('blocked');

  const PeopleSourceImportState(this.wireValue);
  final String wireValue;

  static PeopleSourceImportState fromWire(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => PeopleSourceImportState.unknown,
    );
  }
}

class PeopleCircle {
  const PeopleCircle({
    required this.recordId,
    required this.circleId,
    required this.name,
    required this.sortOrder,
    required this.archived,
  });

  final String recordId;
  final String circleId;
  final String name;
  final int sortOrder;
  final bool archived;

  factory PeopleCircle.fromMap(Map<String, dynamic> map) => PeopleCircle(
        recordId: map['id']?.toString().trim() ?? '',
        circleId: map['circle_id']?.toString().trim() ?? '',
        name: map['name']?.toString().trim() ?? '',
        sortOrder: _intValue(map['sort_order']) ?? 0,
        archived: _boolValue(map['archived']),
      );
}

class LifePerson {
  const LifePerson({
    required this.recordId,
    required this.personId,
    required this.displayName,
    required this.relationshipStatus,
    required this.circleRecordIds,
    required this.birthdayNotificationsEnabled,
    required this.birthdayReminderDays,
    required this.archived,
    this.photoFileName = '',
    this.photoUrl = '',
    this.sourceAvatarUrl = '',
    this.primaryEmail = '',
    this.primaryPhone = '',
    this.birthdayMonth,
    this.birthdayDay,
    this.birthdayYear,
    this.notes = '',
    this.sourceRefs = const <String, dynamic>{},
  });

  final String recordId;
  final String personId;
  final String displayName;
  final String photoFileName;
  final String photoUrl;
  final String sourceAvatarUrl;
  final String primaryEmail;
  final String primaryPhone;
  final PersonRelationshipStatus relationshipStatus;
  final List<String> circleRecordIds;
  final int? birthdayMonth;
  final int? birthdayDay;
  final int? birthdayYear;
  final bool birthdayNotificationsEnabled;
  final List<int> birthdayReminderDays;
  final String notes;
  final Map<String, dynamic> sourceRefs;
  final bool archived;

  bool get hasBirthday => birthdayMonth != null && birthdayDay != null;
  String get avatarUrl => photoUrl.trim().isNotEmpty
      ? photoUrl.trim()
      : sourceAvatarUrl.trim();

  factory LifePerson.fromMap(Map<String, dynamic> map) {
    final sourceRaw = map['source_refs'];
    final remindersRaw = map['birthday_reminder_days'];
    final circlesRaw = map['circles_link'];
    return LifePerson(
      recordId: map['id']?.toString().trim() ?? '',
      personId: map['person_id']?.toString().trim() ?? '',
      displayName: map['display_name']?.toString().trim() ?? '',
      photoFileName: map['photo']?.toString().trim() ?? '',
      photoUrl: map['photo_url']?.toString().trim() ?? '',
      sourceAvatarUrl: map['source_avatar_url']?.toString().trim() ?? '',
      primaryEmail: map['primary_email']?.toString().trim() ?? '',
      primaryPhone: map['primary_phone']?.toString().trim() ?? '',
      relationshipStatus:
          PersonRelationshipStatus.fromWire(map['relationship_status']),
      birthdayMonth: _validMonth(_intValue(map['birthday_month'])),
      birthdayDay: _validDay(_intValue(map['birthday_day'])),
      birthdayYear: _validYear(_intValue(map['birthday_year'])),
      birthdayNotificationsEnabled:
          _boolValue(map['birthday_notifications_enabled']),
      birthdayReminderDays: _intList(remindersRaw).isEmpty
          ? const <int>[7, 1, 0]
          : _intList(remindersRaw),
      circleRecordIds: _stringList(circlesRaw),
      notes: map['notes']?.toString() ?? '',
      sourceRefs: sourceRaw is Map
          ? Map<String, dynamic>.from(sourceRaw)
          : const <String, dynamic>{},
      archived: _boolValue(map['archived']),
    );
  }
}

class PeopleSourceContact {
  const PeopleSourceContact({
    required this.recordId,
    required this.provider,
    required this.externalId,
    required this.displayName,
    required this.importState,
    required this.archived,
    this.avatarUrl = '',
    this.avatarDataUri = '',
    this.primaryEmail = '',
    this.primaryPhone = '',
    this.birthdayMonth,
    this.birthdayDay,
    this.birthdayYear,
    this.sourceGroup = '',
    this.personRecordId = '',
    this.rawMeta = const <String, dynamic>{},
    this.lastSeenAt,
  });

  final String recordId;
  final PeopleSourceProvider provider;
  final String externalId;
  final String displayName;
  final String avatarUrl;
  final String avatarDataUri;
  final String primaryEmail;
  final String primaryPhone;
  final int? birthdayMonth;
  final int? birthdayDay;
  final int? birthdayYear;
  final String sourceGroup;
  final PeopleSourceImportState importState;
  final String personRecordId;
  final Map<String, dynamic> rawMeta;
  final DateTime? lastSeenAt;
  final bool archived;

  bool get hasBirthday => birthdayMonth != null && birthdayDay != null;
  String get effectiveAvatar => avatarDataUri.trim().isNotEmpty
      ? avatarDataUri.trim()
      : avatarUrl.trim();

  factory PeopleSourceContact.fromMap(Map<String, dynamic> map) {
    final provider = PeopleSourceProvider.fromWire(map['provider']);
    final raw = map['raw_meta'];
    return PeopleSourceContact(
      recordId: map['id']?.toString().trim() ?? '',
      provider: provider ?? PeopleSourceProvider.manual,
      externalId: map['external_id']?.toString().trim() ?? '',
      displayName: map['display_name']?.toString().trim() ?? '',
      avatarUrl: map['avatar_url']?.toString().trim() ?? '',
      avatarDataUri: map['avatar_data_uri']?.toString().trim() ?? '',
      primaryEmail: map['primary_email']?.toString().trim() ?? '',
      primaryPhone: map['primary_phone']?.toString().trim() ?? '',
      birthdayMonth: _validMonth(_intValue(map['birthday_month'])),
      birthdayDay: _validDay(_intValue(map['birthday_day'])),
      birthdayYear: _validYear(_intValue(map['birthday_year'])),
      sourceGroup: map['source_group']?.toString().trim() ?? '',
      importState: PeopleSourceImportState.fromWire(map['import_state']),
      personRecordId: _firstString(map['person_link']),
      rawMeta: raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{},
      lastSeenAt: DateTime.tryParse(map['last_seen_at']?.toString() ?? '')
          ?.toUtc(),
      archived: _boolValue(map['archived']),
    );
  }
}

class PeopleSourceStats {
  const PeopleSourceStats({
    required this.provider,
    required this.total,
    required this.candidates,
    required this.linked,
    required this.ignored,
    required this.blocked,
  });

  final PeopleSourceProvider provider;
  final int total;
  final int candidates;
  final int linked;
  final int ignored;
  final int blocked;
}

class PeopleIntegrationConnection {
  const PeopleIntegrationConnection({
    required this.provider,
    required this.configured,
    required this.serverConfigured,
    required this.status,
    this.accountLabel,
    this.lastSyncAt,
    this.lastError,
  });

  final PeopleSourceProvider provider;
  final bool configured;
  final bool serverConfigured;
  final String status;
  final String? accountLabel;
  final DateTime? lastSyncAt;
  final String? lastError;

  factory PeopleIntegrationConnection.fromJson(Map<String, dynamic> json) {
    final provider = PeopleSourceProvider.fromWire(json['provider']);
    if (provider == null) {
      throw const FormatException('Unknown People provider');
    }
    final lastSync = json['last_sync_at']?.toString().trim() ?? '';
    final account = json['account_label']?.toString().trim() ?? '';
    final error = json['last_error']?.toString().trim() ?? '';
    return PeopleIntegrationConnection(
      provider: provider,
      configured: json['configured'] == true,
      serverConfigured: json['server_configured'] == true,
      status: json['status']?.toString().trim() ?? 'disconnected',
      accountLabel: account.isEmpty ? null : account,
      lastSyncAt:
          lastSync.isEmpty ? null : DateTime.tryParse(lastSync)?.toUtc(),
      lastError: error.isEmpty ? null : error,
    );
  }
}

int? _intValue(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString().trim() ?? '');
}

bool _boolValue(Object? raw) {
  if (raw == true) return true;
  if (raw is num) return raw != 0;
  final value = raw?.toString().trim().toLowerCase() ?? '';
  return value == 'true' || value == '1' || value == 'yes';
}

String _firstString(Object? raw) {
  if (raw is List && raw.isNotEmpty) return raw.first?.toString().trim() ?? '';
  return raw?.toString().trim() ?? '';
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return <String>[
    for (final item in raw)
      if ((item?.toString().trim() ?? '').isNotEmpty) item.toString().trim(),
  ];
}

List<int> _intList(Object? raw) {
  if (raw is! List) return const <int>[];
  final values = <int>{};
  for (final item in raw) {
    final value = _intValue(item);
    if (value != null && value >= 0 && value <= 365) values.add(value);
  }
  final out = values.toList()..sort((a, b) => b.compareTo(a));
  return out;
}

int? _validMonth(int? value) =>
    value != null && value >= 1 && value <= 12 ? value : null;
int? _validDay(int? value) =>
    value != null && value >= 1 && value <= 31 ? value : null;
int? _validYear(int? value) =>
    value != null && value >= 1 && value <= 9999 ? value : null;
