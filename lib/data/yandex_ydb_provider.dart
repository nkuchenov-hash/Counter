// ---------------------------------------------------------------------------
// Yandex YDB (Russia) implementation of BaseDatabase.
// CLOUD_AGNOSTICISM: Same interface as Supabase. ID_CONTRACT: user_id and profile id are String (TEXT) only. PLANETARY_TIME: UTC.
// MANDATORY: Backend MUST use YQL-optimized queries (indexes on user_id, start_time, end_time, parent_id).
// ---------------------------------------------------------------------------

import 'package:counter/data/base_database.dart';
import 'package:counter/data/ydb_api_client.dart';

class YandexYdbProvider implements BaseDatabase {
  YandexYdbProvider(this._ydb);

  final YdbApiClient _ydb;

  @override
  Future<List<Map<String, dynamic>>> getCategories(String uid) => _ydb.getCategories(uid);

  @override
  Future<bool> insertCategory(Map<String, dynamic> row) => _ydb.insertCategory(row);

  @override
  Future<bool> updateCategory(String id, String uid, Map<String, dynamic> body) =>
      _ydb.updateCategory(id, uid, body);

  @override
  Future<bool> deleteCategory(String id, String uid) => _ydb.deleteCategory(id, uid);

  @override
  Future<List<Map<String, dynamic>>> getRecords({
    required String uid,
    String parentId = '',
    String? startTimeGte,
    String? startTimeLt,
    bool? endTimeIsNull,
    int limit = 500,
  }) =>
      _ydb.getRecords(
        uid: uid,
        parentId: parentId,
        startTimeGte: startTimeGte,
        startTimeLt: startTimeLt,
        endTimeIsNull: endTimeIsNull,
        limit: limit,
      );

  @override
  Future<Map<String, dynamic>?> getActiveRecord(String uid, {String parentId = ''}) =>
      _ydb.getActiveRecord(uid, parentId: parentId);

  @override
  Future<bool> insertRecord(Map<String, dynamic> row) => _ydb.insertRecord(row);

  @override
  Future<bool> updateRecord(String id, String uid, Map<String, dynamic> body) =>
      _ydb.updateRecord(id, uid, body);

  @override
  Future<bool> deleteRecord(String id, String uid) => _ydb.deleteRecord(id, uid);

  @override
  Future<bool> updateRecordsEndTime(String uid, String endTimeIso, {String? parentId}) =>
      _ydb.updateRecordsEndTime(uid, endTimeIso, parentId: parentId);

  @override
  Future<Map<String, dynamic>?> getProfile(String uid) => _ydb.getProfile(uid);

  @override
  Future<bool> upsertProfile(Map<String, dynamic> body) => _ydb.upsertProfile(body);

  @override
  Future<List<Map<String, dynamic>>> getPlans({
    required String uid,
    String? startTimeGte,
    String? startTimeLte,
  }) =>
      _ydb.getPlans(uid: uid, startTimeGte: startTimeGte, startTimeLte: startTimeLte);

  @override
  Future<bool> insertPlan(Map<String, dynamic> row) => _ydb.insertPlan(row);

  @override
  Future<bool> updatePlan(String id, String uid, Map<String, dynamic> body) =>
      _ydb.updatePlan(id, uid, body);

  @override
  Future<bool> deletePlan(String id, String uid) => _ydb.deletePlan(id, uid);

  /// SEED_CONTRACT: Same as Supabase. Ensures app_sessions row for [uid] if backend exposes /sessions/ensure; else no-op. No category seeds (DATA_SOVEREIGNTY_LAW).
  @override
  Future<void> checkAndSeedCategories(String uid) async {
    // Backend may implement: ensure row in app_sessions for uid when using YDB auth. Optional.
  }
}
