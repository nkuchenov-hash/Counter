import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client for Yandex YDB-backed REST API. NETWORK_SOVEREIGNTY: all data sync via this endpoint.
/// ID_CONTRACT: every request is scoped by user_id; IAM token in Authorization header.
class YdbApiClient {
  YdbApiClient({
    required this.baseUrl,
    required this.getIamToken,
  });

  final String baseUrl;
  final Future<String?> Function() getIamToken;

  Future<Map<String, String>> _headers() async {
    final token = await getIamToken();
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  Future<http.Response> _get(String path, [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    return http.get(uri, headers: await _headers());
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    return http.post(uri, headers: await _headers(), body: jsonEncode(body));
  }

  Future<http.Response> _patch(String path, Map<String, dynamic> body, {required String id, required String userId}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: {'id': id, 'user_id': userId});
    return http.patch(uri, headers: await _headers(), body: jsonEncode(body));
  }

  Future<http.Response> _delete(String path, {required String id, required String userId}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: {'id': id, 'user_id': userId});
    return http.delete(uri, headers: await _headers());
  }

  // ---------- Categories ----------

  Future<List<Map<String, dynamic>>> getCategories(String uid) async {
    final res = await _get('/categories', {'user_id': uid});
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<bool> insertCategory(Map<String, dynamic> row) async {
    final res = await _post('/categories', row);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> updateCategory(String id, String uid, Map<String, dynamic> body) async {
    final res = await _patch('/categories', body, id: id, userId: uid);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> deleteCategory(String id, String uid) async {
    final res = await _delete('/categories', id: id, userId: uid);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  // ---------- Records ----------

  Future<List<Map<String, dynamic>>> getRecords({
    required String uid,
    String parentId = '',
    String? startTimeGte,
    String? startTimeLt,
    bool? endTimeIsNull,
    int limit = 500,
  }) async {
    final params = <String, String>{'user_id': uid, 'parent_id': parentId};
    if (startTimeGte != null) params['start_time_gte'] = startTimeGte;
    if (startTimeLt != null) params['start_time_lt'] = startTimeLt;
    if (endTimeIsNull == true) params['end_time_is_null'] = '1';
    params['limit'] = limit.toString();
    final res = await _get('/records', params);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> getActiveRecord(String uid, {String parentId = ''}) async {
    final params = <String, String>{'user_id': uid, 'parent_id': parentId, 'end_time_is_null': '1', 'limit': '1'};
    final res = await _get('/records', params);
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first;
    return first is Map<String, dynamic> ? Map<String, dynamic>.from(first) : null;
  }

  Future<bool> insertRecord(Map<String, dynamic> row) async {
    final res = await _post('/records', row);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> updateRecord(String id, String uid, Map<String, dynamic> body) async {
    final res = await _patch('/records', body, id: id, userId: uid);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> deleteRecord(String id, String uid) async {
    final res = await _delete('/records', id: id, userId: uid);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> updateRecordsEndTime(String uid, String endTimeIso, {String? parentId}) async {
    final path = '/records/batch_end_time';
    final body = <String, dynamic>{
      'user_id': uid,
      'end_time': endTimeIso,
      'parent_id': ?parentId,
    };
    final res = await _post(path, body);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  // ---------- Profiles ----------

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final res = await _get('/profiles', {'id': uid});
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<bool> upsertProfile(Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl/profiles'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  // ---------- Plans ----------

  Future<List<Map<String, dynamic>>> getPlans({
    required String uid,
    String? startTimeGte,
    String? startTimeLte,
  }) async {
    final params = <String, String>{'user_id': uid};
    if (startTimeGte != null) params['start_time_gte'] = startTimeGte;
    if (startTimeLte != null) params['start_time_lte'] = startTimeLte;
    final res = await _get('/plans', params);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<bool> insertPlan(Map<String, dynamic> row) async {
    final res = await _post('/plans', row);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> updatePlan(String id, String uid, Map<String, dynamic> body) async {
    final res = await _patch('/plans', body, id: id, userId: uid);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> deletePlan(String id, String uid) async {
    final res = await _delete('/plans', id: id, userId: uid);
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}
