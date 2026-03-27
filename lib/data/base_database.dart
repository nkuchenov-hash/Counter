// ---------------------------------------------------------------------------
// CLOUD_AGNOSTICISM: The UI must not know which cloud holds the data.
// ID_CONTRACT: All user_id and profile id are String (TEXT). No UUID. ARCHITECTURE §2.
// PLANETARY_TIME: All timestamps are UTC in both clouds.
// ---------------------------------------------------------------------------

/// Abstract database interface for Supabase (Global) and YDB (Russia).
/// Implementations: [SupabaseProvider], [YandexYdbProvider].
abstract class BaseDatabase {
  // ---------- Categories ----------
  Future<List<Map<String, dynamic>>> getCategories(String uid);
  Future<bool> insertCategory(Map<String, dynamic> row);
  Future<bool> updateCategory(String id, String uid, Map<String, dynamic> body);
  Future<bool> deleteCategory(String id, String uid);

  // ---------- Records ----------
  Future<List<Map<String, dynamic>>> getRecords({
    required String uid,
    String parentId = '',
    String? startTimeGte,
    String? startTimeLt,
    bool? endTimeIsNull,
    int limit = 500,
  });
  Future<Map<String, dynamic>?> getActiveRecord(String uid, {String parentId = ''});
  Future<bool> insertRecord(Map<String, dynamic> row);
  Future<bool> updateRecord(String id, String uid, Map<String, dynamic> body);
  Future<bool> deleteRecord(String id, String uid);
  Future<bool> updateRecordsEndTime(String uid, String endTimeIso, {String? parentId});

  // ---------- Profiles ----------
  Future<Map<String, dynamic>?> getProfile(String uid);
  Future<bool> upsertProfile(Map<String, dynamic> body);

  // ---------- Plans ----------
  Future<List<Map<String, dynamic>>> getPlans({
    required String uid,
    String? startTimeGte,
    String? startTimeLte,
  });
  Future<bool> insertPlan(Map<String, dynamic> row);
  Future<bool> updatePlan(String id, String uid, Map<String, dynamic> body);
  Future<bool> deletePlan(String id, String uid);

  /// SEED_CONTRACT: Same behavior in both clouds. Ensures minimal structure (e.g. profile row, app_sessions row for YDB). Does NOT seed default categories (DATA_SOVEREIGNTY_LAW).
  Future<void> checkAndSeedCategories(String uid);
}
