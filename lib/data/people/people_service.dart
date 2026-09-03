import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/data/people/people_device_contacts_bridge.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

/// On-demand People data access. Nothing here runs during app startup.
/// External address books are durable source-index rows; they never become a
/// visible Person until the user explicitly links/imports them.
class PeopleService {
  PeopleService._();
  static final PeopleService instance = PeopleService._();

  static const int _birthdayReminderWallHour = 9;

  Future<PocketBase> _readyPocketBase() async {
    final brain = DatabaseService.instance;
    await brain.ensurePocketBaseReady();
    return brain.pocketBase;
  }

  String _ownerIdOrThrow(PocketBase pb) {
    final ownerId = pb.authStore.record?.id.trim() ?? '';
    if (ownerId.isEmpty) {
      throw StateError('People requires an authenticated Life OS profile.');
    }
    return ownerId;
  }

  String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  Map<String, dynamic> _mapRecord(
    RecordModel record, {
    String collection = '',
  }) {
    final map = <String, dynamic>{'id': record.id, ...record.data};
    if (collection == PbCollections.people) {
      final fileName = map['photo']?.toString().trim() ?? '';
      if (fileName.isNotEmpty) {
        map['photo_url'] =
            '$kPocketBaseUrl/api/files/$collection/${record.id}/${Uri.encodeComponent(fileName)}?thumb=240x240';
      }
    }
    return map;
  }

  Future<List<PeopleCircle>> fetchCircles() async {
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final records = await pb.collection(PbCollections.peopleCircles).getFullList(
          filter: 'user_id = "${_escape(ownerId)}" && archived = false',
          sort: 'sort_order,name',
        );
    return records
        .map((record) => PeopleCircle.fromMap(_mapRecord(record)))
        .where((circle) => circle.recordId.isNotEmpty && circle.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<LifePerson>> fetchPeople() async {
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final records = await pb.collection(PbCollections.people).getFullList(
          filter: 'user_id = "${_escape(ownerId)}" && archived = false',
          sort: 'display_name',
        );
    return records
        .map(
          (record) => LifePerson.fromMap(
            _mapRecord(record, collection: PbCollections.people),
          ),
        )
        .where((person) =>
            person.recordId.isNotEmpty && person.displayName.isNotEmpty)
        .toList(growable: false);
  }

  Future<(List<LifePerson>, List<PeopleCircle>)> fetchPeopleHome() async {
    final result = await Future.wait<Object>(<Future<Object>>[
      fetchPeople(),
      fetchCircles(),
    ]);
    final people = result[0] as List<LifePerson>;
    unawaited(reconcileBirthdayNotifications(people));
    return (people, result[1] as List<PeopleCircle>);
  }

  Future<LifePerson> createPerson({
    required String displayName,
    required PersonRelationshipStatus relationshipStatus,
    int? birthdayMonth,
    int? birthdayDay,
    int? birthdayYear,
    bool birthdayNotificationsEnabled = false,
    List<int> birthdayReminderDays = const <int>[7, 1, 0],
    List<String> circleRecordIds = const <String>[],
    String notes = '',
    String primaryEmail = '',
    String primaryPhone = '',
    String sourceAvatarUrl = '',
    Map<String, dynamic> sourceRefs = const <String, dynamic>{},
    Uint8List? photoBytes,
    String photoFilename = 'person.jpg',
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('Person name is required.');
    _validateBirthday(birthdayMonth, birthdayDay, birthdayYear);
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final files = <http.MultipartFile>[
      if (photoBytes != null && photoBytes.isNotEmpty)
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: _safePhotoFilename(photoFilename),
        ),
    ];
    final record = await pb.collection(PbCollections.people).create(
      body: <String, dynamic>{
        'user_id': ownerId,
        'person_id': DatabaseService.newClientUuid(),
        'display_name': name,
        'relationship_status': relationshipStatus.wireValue,
        'source_avatar_url': sourceAvatarUrl.trim(),
        'primary_email': primaryEmail.trim(),
        'primary_phone': primaryPhone.trim(),
        if (birthdayMonth != null) 'birthday_month': birthdayMonth,
        if (birthdayDay != null) 'birthday_day': birthdayDay,
        if (birthdayYear != null) 'birthday_year': birthdayYear,
        'birthday_notifications_enabled':
            birthdayMonth != null && birthdayDay != null
                ? birthdayNotificationsEnabled
                : false,
        'birthday_reminder_days': _normalizeReminderDays(birthdayReminderDays),
        'circles_link': _normalizeRecordIds(circleRecordIds),
        'notes': notes.trim(),
        'source_refs': sourceRefs,
        'archived': false,
      },
      files: files,
    );
    final saved = LifePerson.fromMap(
      _mapRecord(record, collection: PbCollections.people),
    );
    unawaited(reconcilePersonBirthdayNotifications(saved));
    return saved;
  }

  Future<LifePerson> updatePerson({
    required String recordId,
    required String displayName,
    required PersonRelationshipStatus relationshipStatus,
    int? birthdayMonth,
    int? birthdayDay,
    int? birthdayYear,
    bool birthdayNotificationsEnabled = false,
    List<int> birthdayReminderDays = const <int>[7, 1, 0],
    List<String> circleRecordIds = const <String>[],
    String notes = '',
    String primaryEmail = '',
    String primaryPhone = '',
    String? sourceAvatarUrl,
    Map<String, dynamic>? sourceRefs,
    Uint8List? photoBytes,
    String photoFilename = 'person.jpg',
    bool removePhoto = false,
  }) async {
    final id = recordId.trim();
    final name = displayName.trim();
    if (id.isEmpty) throw ArgumentError('Person record id is required.');
    if (name.isEmpty) throw ArgumentError('Person name is required.');
    _validateBirthday(birthdayMonth, birthdayDay, birthdayYear);
    final pb = await _readyPocketBase();
    _ownerIdOrThrow(pb);
    final files = <http.MultipartFile>[
      if (photoBytes != null && photoBytes.isNotEmpty)
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: _safePhotoFilename(photoFilename),
        ),
    ];
    final record = await pb.collection(PbCollections.people).update(
      id,
      body: <String, dynamic>{
        'display_name': name,
        'relationship_status': relationshipStatus.wireValue,
        'primary_email': primaryEmail.trim(),
        'primary_phone': primaryPhone.trim(),
        if (sourceAvatarUrl != null)
          'source_avatar_url': sourceAvatarUrl.trim(),
        'birthday_month': birthdayMonth,
        'birthday_day': birthdayDay,
        'birthday_year': birthdayYear,
        'birthday_notifications_enabled':
            birthdayMonth != null && birthdayDay != null
                ? birthdayNotificationsEnabled
                : false,
        'birthday_reminder_days': _normalizeReminderDays(birthdayReminderDays),
        'circles_link': _normalizeRecordIds(circleRecordIds),
        'notes': notes.trim(),
        if (sourceRefs != null) 'source_refs': sourceRefs,
        if (removePhoto) 'photo': '',
      },
      files: files,
    );
    final saved = LifePerson.fromMap(
      _mapRecord(record, collection: PbCollections.people),
    );
    unawaited(reconcilePersonBirthdayNotifications(saved));
    return saved;
  }

  Future<void> archivePerson(String recordId) async {
    final id = recordId.trim();
    if (id.isEmpty) return;
    final pb = await _readyPocketBase();
    _ownerIdOrThrow(pb);
    var stableId = '';
    try {
      final existing = await pb.collection(PbCollections.people).getOne(id);
      stableId = existing.data['person_id']?.toString().trim() ?? '';
    } catch (_) {}
    await pb.collection(PbCollections.people).update(
      id,
      body: const <String, dynamic>{'archived': true},
    );
    if (stableId.isNotEmpty) {
      unawaited(
        NotificationService.instance.cancelPeopleBirthdayReminders(stableId),
      );
    }
  }

  Future<PeopleCircle> createCircle(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Circle name is required.');
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final existing = await fetchCircles();
    final record = await pb.collection(PbCollections.peopleCircles).create(
      body: <String, dynamic>{
        'user_id': ownerId,
        'circle_id': DatabaseService.newClientUuid(),
        'name': clean,
        'sort_order': existing.length,
        'archived': false,
      },
    );
    return PeopleCircle.fromMap(_mapRecord(record));
  }

  Future<PeopleCircle> renameCircle({
    required String recordId,
    required String name,
  }) async {
    final id = recordId.trim();
    final clean = name.trim();
    if (id.isEmpty || clean.isEmpty) throw ArgumentError('Circle is invalid.');
    final pb = await _readyPocketBase();
    _ownerIdOrThrow(pb);
    final record = await pb.collection(PbCollections.peopleCircles).update(
      id,
      body: <String, dynamic>{'name': clean},
    );
    return PeopleCircle.fromMap(_mapRecord(record));
  }

  Future<void> archiveCircle(String recordId) async {
    final id = recordId.trim();
    if (id.isEmpty) return;
    final pb = await _readyPocketBase();
    _ownerIdOrThrow(pb);
    await pb.collection(PbCollections.peopleCircles).update(
      id,
      body: const <String, dynamic>{'archived': true},
    );
  }

  Future<List<PeopleSourceStats>> fetchSourceStats() async {
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final providers = PeopleSourceProvider.values
        .where((provider) => provider != PeopleSourceProvider.manual)
        .toList(growable: false);

    Future<int> count(
      PeopleSourceProvider provider, {
      PeopleSourceImportState? state,
    }) async {
      final filters = <String>[
        'user_id = "${_escape(ownerId)}"',
        'provider = "${provider.wireValue}"',
        'archived = false',
        if (state != null) 'import_state = "${state.wireValue}"',
      ];
      final page = await pb.collection(PbCollections.peopleSourceContacts).getList(
            page: 1,
            perPage: 1,
            filter: filters.join(' && '),
          );
      return page.totalItems;
    }

    return Future.wait<PeopleSourceStats>([
      for (final provider in providers)
        () async {
          final counts = await Future.wait<int>([
            count(provider),
            count(provider, state: PeopleSourceImportState.candidate),
            count(provider, state: PeopleSourceImportState.linked),
            count(provider, state: PeopleSourceImportState.ignored),
            count(provider, state: PeopleSourceImportState.blocked),
          ]);
          return PeopleSourceStats(
            provider: provider,
            total: counts[0],
            candidates: counts[1],
            linked: counts[2],
            ignored: counts[3],
            blocked: counts[4],
          );
        }(),
    ]);
  }

  Future<List<PeopleSourceContact>> fetchSourceContacts(
    PeopleSourceProvider provider, {
    Set<PeopleSourceImportState> states = const <PeopleSourceImportState>{
      PeopleSourceImportState.candidate,
      PeopleSourceImportState.linked,
    },
  }) async {
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final filters = <String>[
      'user_id = "${_escape(ownerId)}"',
      'provider = "${provider.wireValue}"',
      'archived = false',
      if (states.isNotEmpty)
        '(${states.map((state) => 'import_state = "${state.wireValue}"').join(' || ')})',
    ];
    final records = await pb.collection(PbCollections.peopleSourceContacts).getFullList(
          filter: filters.join(' && '),
          sort: 'display_name',
        );
    return records
        .map((record) => PeopleSourceContact.fromMap(_mapRecord(record)))
        .where((contact) => contact.externalId.isNotEmpty)
        .toList(growable: false);
  }

  Future<int> syncDeviceContacts() async {
    final rows = await PeopleDeviceContactsBridge.instance.readContacts();
    return _upsertSourceRows(PeopleSourceProvider.deviceContacts, rows);
  }

  Future<int> importTelegramExport(String jsonText) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const FormatException('telegram_export_invalid_json');
    }
    final rows = <Map<String, dynamic>>[];
    void addContact(Map<dynamic, dynamic> raw, int index) {
      final first = raw['first_name']?.toString().trim() ?? '';
      final last = raw['last_name']?.toString().trim() ?? '';
      final direct = raw['name']?.toString().trim() ?? '';
      final phone = (raw['phone_number'] ?? raw['phone'])?.toString().trim() ?? '';
      final id = (raw['id'] ?? raw['user_id'] ?? raw['contact_id'])
              ?.toString()
              .trim() ??
          '';
      final name = direct.isNotEmpty
          ? direct
          : <String>[first, last].where((part) => part.isNotEmpty).join(' ');
      if (name.isEmpty && phone.isEmpty) return;
      rows.add(<String, dynamic>{
        'external_id': id.isNotEmpty ? id : 'telegram-export:$index:$phone:$name',
        'display_name': name.isNotEmpty ? name : phone,
        'primary_phone': phone,
        'raw_meta': Map<String, dynamic>.from(raw),
      });
    }

    dynamic contactsNode = decoded;
    if (decoded is Map) {
      contactsNode = decoded['contacts'] ?? decoded['contact_list'] ?? decoded;
      if (contactsNode is Map) {
        contactsNode = contactsNode['list'] ?? contactsNode['contacts'] ?? contactsNode;
      }
    }
    if (contactsNode is List) {
      for (var i = 0; i < contactsNode.length; i++) {
        final item = contactsNode[i];
        if (item is Map) addContact(item, i);
      }
    }
    if (rows.isEmpty) {
      throw const FormatException('telegram_export_no_contacts');
    }
    return _upsertSourceRows(PeopleSourceProvider.telegram, rows);
  }

  Future<int> _upsertSourceRows(
    PeopleSourceProvider provider,
    List<Map<String, dynamic>> rows,
  ) async {
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final existingRecords = await pb.collection(PbCollections.peopleSourceContacts).getFullList(
          filter:
              'user_id = "${_escape(ownerId)}" && provider = "${provider.wireValue}"',
        );
    final existingByExternal = <String, RecordModel>{
      for (final record in existingRecords)
        if ((record.data['external_id']?.toString().trim() ?? '').isNotEmpty)
          record.data['external_id'].toString().trim(): record,
    };
    var changed = 0;
    final now = DateTime.now().toUtc().toIso8601String();
    for (var i = 0; i < rows.length; i++) {
      final raw = rows[i];
      final externalId = (raw['external_id'] ?? raw['id'])?.toString().trim() ?? '';
      if (externalId.isEmpty) continue;
      final existing = existingByExternal[externalId];
      final existingState = existing == null
          ? PeopleSourceImportState.unknown
          : PeopleSourceImportState.fromWire(existing.data['import_state']);
      final body = <String, dynamic>{
        'user_id': ownerId,
        'provider': provider.wireValue,
        'external_id': externalId,
        'display_name': raw['display_name']?.toString().trim() ?? '',
        'avatar_url': raw['avatar_url']?.toString().trim() ?? '',
        'avatar_data_uri': raw['avatar_data_uri']?.toString().trim() ?? '',
        'primary_email': raw['primary_email']?.toString().trim() ?? '',
        'primary_phone': raw['primary_phone']?.toString().trim() ?? '',
        'birthday_month': _asInt(raw['birthday_month']),
        'birthday_day': _asInt(raw['birthday_day']),
        'birthday_year': _asInt(raw['birthday_year']),
        'source_group': raw['source_group']?.toString().trim() ?? '',
        'raw_meta': raw['raw_meta'] is Map
            ? Map<String, dynamic>.from(raw['raw_meta'] as Map)
            : raw,
        'last_seen_at': now,
        'archived': false,
        if (existing == null)
          'import_state': PeopleSourceImportState.candidate.wireValue,
        if (existing != null && existingState == PeopleSourceImportState.unknown)
          'import_state': PeopleSourceImportState.candidate.wireValue,
      };
      if (existing == null) {
        await pb.collection(PbCollections.peopleSourceContacts).create(body: body);
      } else {
        await pb.collection(PbCollections.peopleSourceContacts).update(
              existing.id,
              body: body,
            );
      }
      changed++;
    }
    return changed;
  }

  Future<void> setSourceState(
    PeopleSourceContact source,
    PeopleSourceImportState state,
  ) async {
    if (source.recordId.isEmpty) return;
    final pb = await _readyPocketBase();
    _ownerIdOrThrow(pb);
    await pb.collection(PbCollections.peopleSourceContacts).update(
      source.recordId,
      body: <String, dynamic>{
        'import_state': state.wireValue,
        if (state != PeopleSourceImportState.linked) 'person_link': '',
      },
    );
  }

  Future<LifePerson> linkSourceContact(
    PeopleSourceContact source, {
    LifePerson? existingPerson,
  }) async {
    if (source.recordId.isEmpty || source.displayName.trim().isEmpty) {
      throw ArgumentError('Source contact is invalid.');
    }
    final mergedRefs = <String, dynamic>{
      ...?existingPerson?.sourceRefs,
      source.provider.wireValue: <String, dynamic>{
        'source_record_id': source.recordId,
        'external_id': source.externalId,
      },
    };
    final avatarBytes = existingPerson == null || existingPerson.avatarUrl.isEmpty
        ? _dataUriBytes(source.avatarDataUri)
        : null;
    final sourceAvatar = avatarBytes == null ? source.avatarUrl : '';

    final saved = existingPerson == null
        ? await createPerson(
            displayName: source.displayName,
            relationshipStatus: PersonRelationshipStatus.known,
            birthdayMonth: source.birthdayMonth,
            birthdayDay: source.birthdayDay,
            birthdayYear: source.birthdayYear,
            primaryEmail: source.primaryEmail,
            primaryPhone: source.primaryPhone,
            sourceAvatarUrl: sourceAvatar,
            sourceRefs: mergedRefs,
            photoBytes: avatarBytes,
            photoFilename: '${source.provider.wireValue}-${source.externalId}.jpg',
          )
        : await updatePerson(
            recordId: existingPerson.recordId,
            displayName: existingPerson.displayName,
            relationshipStatus: existingPerson.relationshipStatus,
            birthdayMonth:
                existingPerson.birthdayMonth ?? source.birthdayMonth,
            birthdayDay: existingPerson.birthdayDay ?? source.birthdayDay,
            birthdayYear: existingPerson.birthdayYear ?? source.birthdayYear,
            birthdayNotificationsEnabled:
                existingPerson.birthdayNotificationsEnabled,
            birthdayReminderDays: existingPerson.birthdayReminderDays,
            circleRecordIds: existingPerson.circleRecordIds,
            notes: existingPerson.notes,
            primaryEmail: existingPerson.primaryEmail.isNotEmpty
                ? existingPerson.primaryEmail
                : source.primaryEmail,
            primaryPhone: existingPerson.primaryPhone.isNotEmpty
                ? existingPerson.primaryPhone
                : source.primaryPhone,
            sourceAvatarUrl: existingPerson.sourceAvatarUrl.isNotEmpty
                ? existingPerson.sourceAvatarUrl
                : sourceAvatar,
            sourceRefs: mergedRefs,
            photoBytes: avatarBytes,
            photoFilename: '${source.provider.wireValue}-${source.externalId}.jpg',
          );

    final pb = await _readyPocketBase();
    await pb.collection(PbCollections.peopleSourceContacts).update(
      source.recordId,
      body: <String, dynamic>{
        'import_state': PeopleSourceImportState.linked.wireValue,
        'person_link': saved.recordId,
      },
    );
    return saved;
  }

  Future<void> reconcileBirthdayNotifications(List<LifePerson> people) async {
    for (final person in people) {
      await reconcilePersonBirthdayNotifications(person);
    }
  }

  Future<void> reconcilePersonBirthdayNotifications(LifePerson person) async {
    final stableId = person.personId.trim();
    if (stableId.isEmpty) return;
    final notifications = NotificationService.instance;
    await notifications.cancelPeopleBirthdayReminders(stableId);

    if (person.archived ||
        !person.birthdayNotificationsEnabled ||
        !person.hasBirthday ||
        person.relationshipStatus == PersonRelationshipStatus.ignored ||
        person.relationshipStatus == PersonRelationshipStatus.blocked) {
      return;
    }

    final brain = DatabaseService.instance;
    final today = brain.getTimelineDeviceLocalToday();
    final settings = brain.settings;
    final nowUtc = DateTime.now().toUtc();
    var targetYear = today.year;
    var birthdayWall = _birthdayWallDate(
      targetYear,
      person.birthdayMonth!,
      person.birthdayDay!,
    );
    var birthdayUtc = wall_clock.wallClockToUtcForLabel(
      birthdayWall,
      settings.timezoneOffsetHours,
      settings.preferredTimeZone,
    );
    if (!birthdayUtc.isAfter(nowUtc)) {
      targetYear++;
      birthdayWall = _birthdayWallDate(
        targetYear,
        person.birthdayMonth!,
        person.birthdayDay!,
      );
    }

    final locale = currentLocale.value.toLowerCase();
    final reminders = _normalizeReminderDays(person.birthdayReminderDays);
    for (final daysBefore in reminders) {
      final reminderDay = birthdayWall.subtract(Duration(days: daysBefore));
      final reminderWall = DateTime(
        reminderDay.year,
        reminderDay.month,
        reminderDay.day,
        _birthdayReminderWallHour,
      );
      final fireUtc = wall_clock.wallClockToUtcForLabel(
        reminderWall,
        settings.timezoneOffsetHours,
        settings.preferredTimeZone,
      );
      if (!fireUtc.isAfter(nowUtc)) continue;

      final key = 'people:birthday:$stableId:${birthdayWall.year}:$daysBefore';
      final title = '🎂 ${person.displayName}';
      final body = _birthdayNotificationBody(
        person.displayName,
        daysBefore,
        locale,
      );
      await notifications.schedulePeopleBirthdayReminder(
        notificationId: planAlarmNotificationIdFromStableKey(key),
        personStableId: stableId,
        fireUtc: fireUtc,
        title: title,
        body: body,
        occurrenceKey: '${birthdayWall.year}:$daysBefore',
      );
    }
  }

  DateTime _birthdayWallDate(int year, int month, int day) {
    if (month == DateTime.february && day == 29 && !_isLeapYear(year)) {
      return DateTime(year, DateTime.february, 28, _birthdayReminderWallHour);
    }
    return DateTime(year, month, day, _birthdayReminderWallHour);
  }

  bool _isLeapYear(int year) =>
      year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);

  String _birthdayNotificationBody(
    String displayName,
    int daysBefore,
    String locale,
  ) {
    final ru = locale.startsWith('ru');
    if (daysBefore == 0) {
      return ru
          ? 'Сегодня день рождения у $displayName.'
          : "It's $displayName's birthday today.";
    }
    if (daysBefore == 1) {
      return ru
          ? 'Завтра день рождения у $displayName.'
          : "$displayName's birthday is tomorrow.";
    }
    return ru
        ? 'День рождения у $displayName через $daysBefore дн.'
        : "$displayName's birthday is in $daysBefore days.";
  }

  void _validateBirthday(int? month, int? day, int? year) {
    if ((month == null) != (day == null)) {
      throw ArgumentError('Birthday requires both month and day.');
    }
    if (month != null && (month < 1 || month > 12)) {
      throw ArgumentError('Birthday month is invalid.');
    }
    if (day != null && (day < 1 || day > 31)) {
      throw ArgumentError('Birthday day is invalid.');
    }
    if (year != null && (year < 1 || year > 9999)) {
      throw ArgumentError('Birthday year is invalid.');
    }
    if (month != null && day != null) {
      final validationYear = year ?? 2000;
      final candidate = DateTime(validationYear, month, day);
      if (candidate.month != month || candidate.day != day) {
        throw ArgumentError('Birthday date is invalid.');
      }
    }
  }

  List<int> _normalizeReminderDays(List<int> raw) {
    final out = raw.where((value) => value >= 0 && value <= 365).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return out.isEmpty ? const <int>[7, 1, 0] : out;
  }

  List<String> _normalizeRecordIds(List<String> raw) {
    final seen = <String>{};
    return <String>[
      for (final value in raw)
        if (value.trim().isNotEmpty && seen.add(value.trim())) value.trim(),
    ];
  }

  int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString().trim() ?? '');
  }

  Uint8List? _dataUriBytes(String raw) {
    final value = raw.trim();
    if (!value.startsWith('data:image/') || !value.contains(';base64,')) {
      return null;
    }
    try {
      return base64Decode(value.substring(value.indexOf(';base64,') + 8));
    } catch (_) {
      return null;
    }
  }

  String _safePhotoFilename(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (clean.isEmpty) return 'person.jpg';
    return clean.length > 120 ? clean.substring(clean.length - 120) : clean;
  }
}
