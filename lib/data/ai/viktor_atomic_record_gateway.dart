import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:http/http.dart' as http;
import 'viktor_record_tools.dart';

/// Sends two owned Record edits as ONE authenticated PocketBase transaction.
/// Never retry with independent PATCHes: that could shorten the first Record
/// without extending the second. The server revalidates every field.
class ViktorAtomicRecordGateway {
  const ViktorAtomicRecordGateway(this.db);
  final DatabaseService db;

  static String _required(Map<String, dynamic> row, String key) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw StateError('Отсутствует $key исходной записи.');
    }
    return value;
  }

  static String _revision(Map<String, dynamic> row) {
    final raw = _required(row, 'updated');
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) {
      throw StateError('Нельзя проверить версию исходной записи.');
    }
    return parsed.toUtc().toIso8601String();
  }

  Future<String> commit({
    required ViktorAdjacentResizePreview approved,
    required String requestId,
  }) async {
    final token = db.pocketBase.authStore.token.trim();
    if (token.isEmpty || db.pocketBase.authStore.record == null) {
      throw StateError('Войдите в LIFE OS, чтобы изменить записи.');
    }
    String utc(DateTime time) => time.toUtc().toIso8601String();
    final firstId = _required(approved.first, 'id');
    final secondId = _required(approved.second, 'id');
    final body = {
      'request_id': requestId,
      'first': {
        'id': firstId,
        'expected_title': _required(approved.first, 'title'),
        'expected_status': _required(approved.first, 'status'),
        'expected_updated': _revision(approved.first),
        'expected_start': utc(approved.firstStart),
        'expected_end': utc(approved.firstEnd),
        'new_end': utc(approved.newBoundary),
      },
      'second': {
        'id': secondId,
        'expected_title': _required(approved.second, 'title'),
        'expected_status': _required(approved.second, 'status'),
        'expected_updated': _revision(approved.second),
        'expected_start': utc(approved.secondStart),
        'expected_end': approved.secondEnd == null
            ? null : utc(approved.secondEnd!),
        'new_start': utc(approved.newBoundary),
      },
    };
    final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
    late final http.Response reply;
    try {
      reply = await http.post(Uri.parse('$base/api/viktor/records/resize-adjacent'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 35));
    } catch (_) {
      throw StateError('Ответ сервера не получен. Операция могла '
          'выполниться: проверьте обе записи перед повтором.');
    }
    Map<String, dynamic> payload = {};
    try {
      final decoded = jsonDecode(utf8.decode(reply.bodyBytes));
      if (decoded is Map<String, dynamic>) payload = decoded;
    } catch (_) {}
    if (reply.statusCode != 200 || payload['ok'] != true ||
        payload['updated'] != 2) {
      final reason = (payload['error'] ?? 'HTTP ${reply.statusCode}').toString();
      throw StateError('Сервер отклонил изменение записей ($reason). '
          'Обе записи сохранены без изменений.');
    }
    try {
      final rows = await db.getRecords(forceNetwork: true);
      Map<String, dynamic> exact(String id) => rows.singleWhere(
          (r) => r['id'] == id);
      final first = exact(firstId);
      final second = exact(secondId);
      DateTime? instant(Map<String, dynamic> row, String key) {
        final raw = row[key]?.toString().trim() ?? '';
        return raw.isEmpty ? null :
            DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toUtc();
      }
      bool same(DateTime? a, DateTime? b) =>
          a == null && b == null ||
          a != null && b != null &&
          a.difference(b).inMilliseconds.abs() < 1000;
      if (!same(instant(first, 'start_time'), approved.firstStart) ||
          !same(instant(first, 'end_time'), approved.newBoundary) ||
          !same(instant(second, 'start_time'), approved.newBoundary) ||
          !same(instant(second, 'end_time'), approved.secondEnd)) {
        throw StateError('unexpected persisted boundaries');
      }
    } catch (_) {
      throw StateError('Сервер принял изменение, но проверить актуальные '
          'записи не удалось. Обновите Timeline перед повтором.');
    }
    return 'Обе записи изменены и проверены на сервере. '
        'Первая сокращена; вторая начинается с освободившегося времени.';
  }
}
