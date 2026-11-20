import 'package:sembast_web/sembast_web.dart';

/// Durable browser settings independent of SharedPreferences/localStorage.
/// The latter may be at quota from historical LIFE OS app caches.
abstract final class WebTimezoneQuickStore {
  static final _store = stringMapStoreFactory.store('timezone_quick');
  static Future<Database>? _opening;

  static Future<Database> _database() =>
      _opening ??= databaseFactoryWeb.openDatabase('lifeos_timezone_quick_v1');

  static Future<Map<String, Object?>?> read(String profileId) async {
    final db = await _database();
    final value = await _store.record(profileId).get(db);
    if (value == null) return null;
    return Map<String, Object?>.from(value);
  }

  /// Only the first read migrates an older localStorage preference. A second
  /// tab must never overwrite a newer IndexedDB selection with stale legacy.
  static Future<void> migrateIfAbsent(
    String profileId, {
    required List<String> favorites,
    required bool automatic,
  }) async {
    final db = await _database();
    await db.transaction<void>((txn) async {
      final row = _store.record(profileId);
      if (await row.get(txn) != null) return;
      await row.put(txn, <String, Object?>{
        'favorites': favorites,
        'automatic': automatic,
      });
    });
  }

  static Future<void> writeFavorites(
    String profileId, List<String> favorites,
  ) async {
    final db = await _database();
    await db.transaction<void>((txn) async {
      final row = _store.record(profileId);
      final previous = await row.get(txn) ?? <String, Object?>{};
      await row.put(txn, <String, Object?>{
        ...previous,
        'favorites': favorites,
      });
    });
  }

  static Future<void> writeAutomatic(
    String profileId, bool automatic,
  ) async {
    final db = await _database();
    await db.transaction<void>((txn) async {
      final row = _store.record(profileId);
      final previous = await row.get(txn) ?? <String, Object?>{};
      await row.put(txn, <String, Object?>{
        ...previous,
        'automatic': automatic,
      });
    });
  }
}
