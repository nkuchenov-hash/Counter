import 'package:counter/data/database_service.dart';
import 'package:pocketbase/pocketbase.dart';

class PersonEntry {
  const PersonEntry({
    required this.id,
    required this.name,
    required this.group,
    this.birthday,
    this.notes = '',
    this.source = 'manual',
  });

  final String id;
  final String name;
  final String group;
  final DateTime? birthday;
  final String notes;
  final String source;

  factory PersonEntry.fromRecord(RecordModel record) {
    final rawBirthday = record.data['birthday']?.toString().trim() ?? '';
    DateTime? birthday;
    if (rawBirthday.isNotEmpty) {
      birthday = DateTime.tryParse(rawBirthday);
    }
    return PersonEntry(
      id: record.id,
      name: record.data['name']?.toString().trim() ?? '',
      group: record.data['group']?.toString().trim().isNotEmpty == true
          ? record.data['group'].toString().trim()
          : 'other',
      birthday: birthday,
      notes: record.data['notes']?.toString().trim() ?? '',
      source: record.data['source']?.toString().trim().isNotEmpty == true
          ? record.data['source'].toString().trim()
          : 'manual',
    );
  }
}

class PeopleRepository {
  PeopleRepository._();
  static final PeopleRepository instance = PeopleRepository._();

  Future<PocketBase> _client() async {
    final db = DatabaseService.instance;
    await db.ensurePocketBaseReady();
    return db.pocketBase;
  }

  Future<String> _userId() async {
    final pb = await _client();
    final id = pb.authStore.record?.id.trim() ?? '';
    if (id.isEmpty) {
      throw StateError('Authenticated user is required for People');
    }
    return id;
  }

  Future<List<PersonEntry>> list() async {
    final pb = await _client();
    final userId = await _userId();
    final rows = await pb.collection('people').getFullList(
      sort: 'name',
      filter: 'user_id = "$userId" && archived = false',
    );
    return rows.map(PersonEntry.fromRecord).toList(growable: false);
  }

  Future<PersonEntry> create({
    required String name,
    required String group,
    DateTime? birthday,
    String notes = '',
  }) async {
    final pb = await _client();
    final userId = await _userId();
    final row = await pb.collection('people').create(body: {
      'user_id': userId,
      'name': name.trim(),
      'group': group,
      'birthday': birthday == null ? '' : _dateOnly(birthday),
      'notes': notes.trim(),
      'source': 'manual',
      'source_id': '',
      'archived': false,
    });
    return PersonEntry.fromRecord(row);
  }

  Future<PersonEntry> update(
    PersonEntry person, {
    required String name,
    required String group,
    DateTime? birthday,
    String notes = '',
  }) async {
    final pb = await _client();
    final row = await pb.collection('people').update(person.id, body: {
      'name': name.trim(),
      'group': group,
      'birthday': birthday == null ? '' : _dateOnly(birthday),
      'notes': notes.trim(),
    });
    return PersonEntry.fromRecord(row);
  }

  Future<void> delete(String id) async {
    final pb = await _client();
    await pb.collection('people').delete(id);
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
