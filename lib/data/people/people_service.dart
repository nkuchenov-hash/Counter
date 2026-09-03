import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:pocketbase/pocketbase.dart';

/// On-demand People data access. Nothing here runs during app startup.
///
/// External address books are intentionally stored in people_source_contacts.
/// A source contact becomes a visible [LifePerson] only after explicit linking
/// or an approved import rule. Ignored / blocked source identities stay hidden.
class PeopleService {
  PeopleService._();
  static final PeopleService instance = PeopleService._();

  static const String _peopleCollection = 'people';
  static const String _circlesCollection = 'people_circles';
  static const String _sourceContactsCollection = 'people_source_contacts';
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

  Map<String, dynamic> _mapRecord(RecordModel record) => <String, dynamic>{
        'id': record.id,
        ...record.data,
      };

  Future<List<PeopleCircle>> fetchCircles() async {
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final records = await pb.collection(_circlesCollection).getFullList(
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
    final records = await pb.collection(_peopleCollection).getFullList(
          filter: 'user_id = "${_escape(ownerId)}" && archived = false',
          sort: 'display_name',
        );
    return records
        .map((record) => LifePerson.fromMap(_mapRecord(record)))
        .where((person) =>
            person.recordId.isNotEmpty && person.displayName.isNotEmpty)
        .toList(growable: false);
  }

  Future<(List<LifePerson>, List<PeopleCircle>)> fetchPeopleHome() async {
    final result = await Future.wait<Object>(<Future<Object>>[
      fetchPeople(),
      fetchCircles(),
    ]);
    return (
      result[0] as List<LifePerson>,
      result[1] as List<PeopleCircle>,
    );
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
    Map<String, dynamic> sourceRefs = const <String, dynamic>{},
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('Person name is required.');
    _validateBirthday(birthdayMonth, birthdayDay, birthdayYear);
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final record = await pb.collection(_peopleCollection).create(
      body: <String, dynamic>{
        'user_id': ownerId,
        'person_id': DatabaseService.newClientUuid(),
        'display_name': name,
        'relationship_status': relationshipStatus.wireValue,
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
    );
    final saved = LifePerson.fromMap(_mapRecord(record));
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
  }) async {
    final id = recordId.trim();
    final name = displayName.trim();
    if (id.isEmpty) throw ArgumentError('Person record id is required.');
    if (name.isEmpty) throw ArgumentError('Person name is required.');
    _validateBirthday(birthdayMonth, birthdayDay, birthdayYear);
    final pb = await _readyPocketBase();
    _ownerIdOrThrow(pb);
    final record = await pb.collection(_peopleCollection).update(
      id,
      body: <String, dynamic>{
        'display_name': name,
        'relationship_status': relationshipStatus.wireValue,
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
      },
    );
    final saved = LifePerson.fromMap(_mapRecord(record));
    unawaited(reconcilePersonBirthdayNotifications(saved));
    return saved;
  }

  Future<void> archivePerson(
    String recordId, {
    String? personStableId,
  }) async {
    final id = recordId.trim();
    if (id.isEmpty) return;
    final pb = await _readyPocketBase();
    _ownerIdOrThrow(pb);
    await pb.collection(_peopleCollection).update(
      id,
      body: const <String, dynamic>{'archived': true},
    );
    final stable = personStableId?.trim() ?? '';
    if (stable.isNotEmpty) {
      unawaited(
        NotificationService.instance.cancelPeopleBirthdayReminders(stable),
      );
    }
  }

  Future<PeopleCircle> createCircle(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Circle name is required.');
    final pb = await _readyPocketBase();
    final ownerId = _ownerIdOrThrow(pb);
    final existing = await fetchCircles();
    final record = await pb.collection(_circlesCollection).create(
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
    final record = await pb.collection(_circlesCollection).update(
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
    await pb.collection(_circlesCollection).update(
      id,
      body: const <String, dynamic>{'archived': true},
    );
  }

  /// Lightweight counts for the Sources tab. It does not download the address
  /// book: each provider/state count asks PocketBase for one row plus totalItems.
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
      final page = await pb.collection(_sourceContactsCollection).getList(
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

  /// Bounded, on-demand reconcile. Called when People is opened and after a
  /// person is changed; it never adds startup work or a global address-book scan.
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
    // Feb 29 is observed on Feb 28 in non-leap years so an annual reminder is
    // never silently lost.
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
      for (final item in raw)
        if (item.trim().isNotEmpty && seen.add(item.trim())) item.trim(),
    ];
  }
}
