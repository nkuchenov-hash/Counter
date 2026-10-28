import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:http/http.dart' as http;

/// A separate opt-in collaboration transport. Never queries on app startup,
/// never touches the personal plan/record outboxes, and never reads profiles.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final brain = DatabaseService.instance;
    await brain.ensurePocketBaseReady();
    final token = brain.pocketBase.authStore.token.trim();
    if (token.isEmpty) {
      throw const ShareApiException(401, 'auth_required');
    }
    final headers = <String, String>{
      'Authorization': token,
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$kPocketBaseUrl$path');
    late http.Response response;
    final client = http.Client();
    try {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await client.send(request)
          .timeout(const Duration(seconds: 20));
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ShareApiException(0, 'network_unavailable');
    } finally {
      client.close();
    }
    Map<String, dynamic> payload;
    try {
      final raw = jsonDecode(response.body);
      payload = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
    } catch (_) {
      payload = <String, dynamic>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ShareApiException(
        response.statusCode,
        (payload['error'] ?? 'share_request_failed').toString(),
      );
    }
    return payload;
  }

  Future<SharedObject> createDay({
    required String wallDay,
    required List<String> planIds,
    required String title,
  }) async {
    final result = await _request('POST', PbAppApiRoutes.shares, body: {
      'kind': 'plan_day',
      'wall_day': wallDay,
      'plan_ids': planIds,
      'title': title,
    });
    return SharedObject.fromJson(result['share'], content: result['content']);
  }

  Future<List<SharedObject>> list() async {
    final result = await _request('GET', PbAppApiRoutes.shares);
    final raw = result['shares'];
    return raw is List
        ? raw.map((e) => SharedObject.fromJson(e)).toList(growable: false)
        : const <SharedObject>[];
  }

  Future<List<SharedObject>> listForDay(String wallDay) async {
    final result = await _request('POST', '${PbAppApiRoutes.shares}/day',
        body: {'wall_day': wallDay});
    final raw = result['shares'];
    return raw is List
        ? raw.map((e) {
            final map = _map(e);
            return SharedObject.fromJson(map, content: map['content']);
          }).toList(growable: false)
        : const <SharedObject>[];
  }

  Future<ShareDetail> detail(String id) async {
    final result = await _request('GET', '${PbAppApiRoutes.shares}/$id');
    return ShareDetail.fromJson(result);
  }

  Future<void> inviteFromPeople({
    required String shareId,
    required String personRecordId,
  }) async {
    await _request('POST', '${PbAppApiRoutes.shares}/$shareId/invite',
        body: {'person_record_id': personRecordId});
  }

  Future<void> respond(String shareId, {required bool accept}) async {
    await _request('POST', '${PbAppApiRoutes.shares}/$shareId/respond',
        body: {'accept': accept});
  }

  Future<void> revokeMember(String shareId, String memberUserId) async {
    await _request('POST',
        '${PbAppApiRoutes.shares}/$shareId/members/$memberUserId/revoke');
  }

  Future<void> leave(String shareId) async {
    await _request('POST', '${PbAppApiRoutes.shares}/$shareId/leave');
  }

  Future<void> setMyCompletion({
    required String shareId,
    required String planId,
    required bool completed,
  }) async {
    await _request('POST', '${PbAppApiRoutes.shares}/$shareId/completion',
        body: {'plan_id': planId, 'completed': completed});
  }

  Future<void> comment(String shareId, String message) async {
    await _request('POST', '${PbAppApiRoutes.shares}/$shareId/messages',
        body: {'kind': 'comment', 'body': message});
  }

  Future<void> propose(
    String shareId, {
    required int revision,
    required String sourcePlanId,
    String? title,
    String? startTime,
    String? endTime,
    String comment = '',
  }) async {
    await _request('POST', '${PbAppApiRoutes.shares}/$shareId/messages',
        body: {
          'kind': 'proposal',
          'base_revision': revision,
          'body': comment,
          'patch': {
            'plan_id': sourcePlanId,
            if (title != null) 'title': title,
            if (startTime != null) 'start_time': startTime,
            if (endTime != null) 'end_time': endTime,
          },
        });
  }

  Future<void> decide(
    String shareId,
    String messageId, {
    required bool accept,
  }) async {
    await _request(
        'POST', '${PbAppApiRoutes.shares}/$shareId/proposals/$messageId/decide',
        body: {'accept': accept});
  }
}

class ShareApiException implements Exception {
  const ShareApiException(this.statusCode, this.code);
  final int statusCode;
  final String code;
  @override
  String toString() => code;
}

Map<String, dynamic> _map(dynamic raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

Map<String, bool> _boolMap(dynamic raw) {
  if (raw is! Map) return const <String, bool>{};
  return <String, bool>{
    for (final entry in raw.entries)
      if (entry.value is bool) entry.key.toString(): entry.value as bool,
  };
}

class SharedObject {
  const SharedObject({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.wallDay,
    required this.revision,
    required this.status,
    required this.items,
    this.myCompleted = const <String, bool>{},
  });
  final String id;
  final String title;
  final String ownerId;
  final String wallDay;
  final int revision;
  final String status;
  final List<SharedPlanItem> items;
  final Map<String, bool> myCompleted;

  factory SharedObject.fromJson(dynamic json, {dynamic content}) {
    final data = _map(json);
    final raw = _map(content)['items'];
    return SharedObject(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      ownerId: (data['owner_id'] ?? '').toString(),
      wallDay: (data['wall_day'] ?? '').toString(),
      revision: (data['revision'] as num?)?.toInt() ?? 0,
      status: (data['my_status'] ?? 'accepted').toString(),
      myCompleted: _boolMap(data['my_completed']),
      items: raw is List
          ? raw.map((e) => SharedPlanItem.fromJson(e)).toList(growable: false)
          : const <SharedPlanItem>[],
    );
  }
}

class SharedPlanItem {
  const SharedPlanItem({
    required this.planId,
    required this.title,
    required this.startTime,
    required this.endTime,
  });
  final String planId;
  final String title;
  final String startTime;
  final String endTime;
  factory SharedPlanItem.fromJson(dynamic json) {
    final data = _map(json);
    return SharedPlanItem(
      planId: (data['plan_id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      startTime: (data['start_time'] ?? '').toString(),
      endTime: (data['end_time'] ?? '').toString(),
    );
  }
}

class ShareMessage {
  const ShareMessage({
    required this.id,
    required this.authorId,
    required this.body,
    required this.kind,
    required this.status,
    required this.patch,
  });
  final String id;
  final String authorId;
  final String body;
  final String kind;
  final String status;
  final Map<String, dynamic> patch;
  factory ShareMessage.fromJson(dynamic json) {
    final data = _map(json);
    return ShareMessage(
      id: (data['id'] ?? '').toString(),
      authorId: (data['author_id'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      kind: (data['kind'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      patch: _map(data['patch']),
    );
  }
}

class ShareDetail {
  const ShareDetail({
    required this.share,
    required this.messages,
    required this.members,
    required this.myCompleted,
  });
  final SharedObject share;
  final Map<String, bool> myCompleted;
  final List<ShareMessage> messages;
  final List<Map<String, dynamic>> members;

  factory ShareDetail.fromJson(Map<String, dynamic> json) => ShareDetail(
        share: SharedObject.fromJson(json['share'], content: json['content']),
        myCompleted: _boolMap(json['my_completed']),
        messages: (json['messages'] as List? ?? [])
            .map((m) => ShareMessage.fromJson(m))
            .toList(growable: false),
        members: (json['members'] as List? ?? [])
            .map(_map)
            .toList(growable: false),
      );
}
