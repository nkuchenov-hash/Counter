import 'package:sembast_web/sembast_web.dart';

/// Browser-only durable journal. IndexedDB is separate from SharedPreferences
/// (localStorage); a full settings/cache localStorage cannot reject record
/// capture. Sembast transactions serialize writes across multiple open tabs.
///
/// Only call these methods on Flutter Web (kIsWeb); mobile/desktop continue to
/// use their established SharedPreferences outbox.
abstract final class WebRecordJournal {
  static final _store = stringMapStoreFactory.store('record_mutations');
  static final _planStore = stringMapStoreFactory.store('plan_mutations');
  static Future<Database>? _opening;

  static Future<Database> _database() =>
      _opening ??= databaseFactoryWeb.openDatabase('lifeos_record_journal_v1');

  static Future<String?> readRaw() async {
    final db = await _database();
    final row = await _store.record('queue').get(db);
    return row?['raw'] as String?;
  }

  /// Atomic read-modify-write on the full journal. A transaction may replay
  /// under cross-tab contention, so [action] must be free of outside effects.
  static Future<T> transact<T>(
    Future<T> Function(
      String? current,
      bool legacyImported,
      Future<void> Function(String raw, bool legacyImported) put,
    ) action,
  ) async {
    final db = await _database();
    return db.transaction<T>((txn) async {
      final ref = _store.record('queue');
      final row = await ref.get(txn);
      final raw = row?['raw'] as String?;
      final migrated = row?['legacy_imported'] == true;
      Future<void> put(String value, bool imported) async {
        await ref.put(txn, <String, Object?>{
          'raw': value,
          'legacy_imported': imported,
        });
      }
      return action(raw, migrated, put);
    });
  }

  /// Independent durable plan outbox, using the same cross-tab transaction
  /// guarantees as the records journal. Never store plan mutations in web
  /// localStorage, which may be full with cached application data.
  static Future<String?> readPlanRaw() async {
    final db = await _database();
    final row = await _planStore.record('queue').get(db);
    return row?['raw'] as String?;
  }

  static Future<T> transactPlan<T>(
    Future<T> Function(
      String? current,
      bool legacyImported,
      Future<void> Function(String raw, bool legacyImported) put,
    ) action,
  ) async {
    final db = await _database();
    return db.transaction<T>((txn) async {
      final ref = _planStore.record('queue');
      final row = await ref.get(txn);
      final raw = row?['raw'] as String?;
      final migrated = row?['legacy_imported'] == true;
      Future<void> put(String value, bool imported) async {
        await ref.put(txn, <String, Object?>{
          'raw': value,
          'legacy_imported': imported,
        });
      }
      return action(raw, migrated, put);
    });
  }

  /// A separate IndexedDB record, independent of the potentially full
  /// SharedPreferences localStorage. Null deletes the preference for tests or
  /// intentional reset; false is a first-class persisted value.
  static Future<bool?> readPreferenceBool(String key) async {
    final db = await _database();
    final row = await _store.record('preference:$key').get(db);
    return row?['enabled'] as bool?;
  }

  static Future<void> writePreferenceBool(String key, bool? enabled) async {
    final db = await _database();
    await db.transaction<void>((txn) async {
      final ref = _store.record('preference:$key');
      if (enabled == null) {
        await ref.delete(txn);
      } else {
        await ref.put(txn, <String, Object?>{'enabled': enabled});
      }
    });
  }

  static Future<String?> readDraft(String key) async {
    final db = await _database();
    final row = await _store.record('draft:$key').get(db);
    return row?['text'] as String?;
  }

  static Future<bool> writeDraft(String key, String text) async {
    final db = await _database();
    return db.transaction<bool>((txn) async {
      final ref = _store.record('draft:$key');
      if (text.isEmpty) {
        await ref.delete(txn);
      } else {
        await ref.put(txn, <String, Object?>{'text': text});
      }
      return true;
    });
  }
}
