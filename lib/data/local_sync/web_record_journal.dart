import 'package:sembast_web/sembast_web.dart';

/// Browser-only durable journal. IndexedDB is separate from SharedPreferences
/// (localStorage); a full settings/cache localStorage cannot reject record
/// capture. Sembast transactions serialize writes across multiple open tabs.
///
/// Only call these methods on Flutter Web (kIsWeb); mobile/desktop continue to
/// use their established SharedPreferences outbox.
abstract final class WebRecordJournal {
  static final _store = stringMapStoreFactory.store('record_mutations');
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
