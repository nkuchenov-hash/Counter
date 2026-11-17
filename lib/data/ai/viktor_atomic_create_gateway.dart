import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// All-or-nothing create of multiple TIMED owned plans. Each business UUID
/// derives from owner/request/index; retries cannot duplicate prior writes.
/// Never fall back to individual Brain POSTs after an ambiguous response.
class ViktorAtomicCreateGateway {
  const ViktorAtomicCreateGateway(this.db);
  final DatabaseService db;

  Future<String> commit({
    required List<Map<String, Object?>> rows,
    required String requestId,
  }) async {
    final token = db.pocketBase.authStore.token.trim();
    final owner = db.pocketBase.authStore.record?.id ?? '';
    if (token.isEmpty || owner.isEmpty) {
      throw StateError('Для создания планов войдите в LIFE OS.');
    }
    if (rows.length < 2 || rows.length > 12) {
      throw StateError('Для группового сохранения нужно 2–12 планов.');
    }
    final creates = <Map<String, Object?>>[
      for (var index = 0; index < rows.length; index++)
        {
          ...rows[index],
          'plan_id': const Uuid().v5(
              Uuid.NAMESPACE_URL, 'lifeos:viktor:$owner:$requestId:$index'),
        },
    ];
    final base = kPocketBaseUrl.replaceFirst(RegExp(r'/$'), '');
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse('$base/api/viktor/schedule/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'request_id': requestId, 'creates': creates}),
      ).timeout(const Duration(seconds: 35));
    } catch (_) {
      throw StateError('Результат атомарного создания пока неизвестен. '
          'Повторная отправка запрещена до проверки серверных планов.');
    }
    Map<String, dynamic> body = {};
    try {
      final parsed = jsonDecode(utf8.decode(response.bodyBytes));
      if (parsed is Map) body = Map<String, dynamic>.from(parsed);
    } catch (_) {}
    if (response.statusCode != 200 || body['ok'] != true ||
        body['count'] != creates.length) {
      throw StateError('Групповое создание не применено: '
          '${body['error'] ?? 'HTTP ${response.statusCode}'}.');
    }
    final ids = body['ids'];
    if (ids is! List || ids.length != creates.length ||
        ids.any((id) => id is! String || id.length != 15)) {
      throw StateError('Сервер вернул непроверяемый результат создания.');
    }
    try {
      for (var i = 0; i < ids.length; i++) {
        final actual = await db.pocketBase
            .collection(PbCollections.plans).getOne(ids[i] as String);
        DateTime utc(String key) => DateTime.parse(
            actual.data[key].toString().replaceFirst(' ', 'T')).toUtc();
        final expected = creates[i];
        if (actual.data['user_id']?.toString() != owner ||
            actual.data['plan_id']?.toString() != expected['plan_id'] ||
            actual.data['title']?.toString() != expected['title'] ||
            utc('start_time').difference(
                DateTime.parse(expected['start_time'] as String))
                .inMilliseconds.abs() > 999 ||
            utc('end_time').difference(
                DateTime.parse(expected['end_time'] as String))
                .inMilliseconds.abs() > 999) {
          throw StateError('Server snapshot differs from approved batch');
        }
      }
      await db.viktorRefreshPlansAfterCommit();
    } catch (_) {
      throw StateError('Транзакция принята, но проверить все новые планы '
          'не удалось. Обновите расписание перед повтором.');
    }
    return 'Создано и проверено на сервере планов: ${creates.length}.';
  }
}
