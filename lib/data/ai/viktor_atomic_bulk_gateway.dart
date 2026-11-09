import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/data/ai/viktor_schedule_planner.dart';
import 'package:http/http.dart' as http;

/// Commit existing owned plan moves under ONE PocketBase transaction.
/// The server independently validates source row versions, ownership and
/// interval collisions. Never fall back to non-atomic sequential PATCHes.
class ViktorAtomicBulkGateway {
  const ViktorAtomicBulkGateway(this.db);

  final DatabaseService db;

  Future<String> commit({
    required ViktorBulkPreview approved,
    required String requestId,
  }) async {
    final token = db.pocketBase.authStore.token.trim();
    if (token.isEmpty || db.pocketBase.authStore.record == null) {
      throw StateError('Для изменения планов войдите в LIFE OS.');
    }
    final rows = <Map<String, Object?>>[];
    for (final move in approved.moves) {
      final original = move.plan;
      final originalStart = original.startUtcInstant ??
          (original.startTime == null ? null :
              db.viktorProfileWallToUtc(original.startTime!));
      final originalEnd = original.endUtcInstant ??
          (original.endDateTime == null ? null :
              db.viktorProfileWallToUtc(original.endDateTime!));
      if (originalStart == null || originalEnd == null ||
          original.pocketRecordId == null) {
        throw StateError('Нет точных исходных данных плана. '
            'Изменения не сохранены.');
      }
      // Older cached plan projections omitted RecordModel.updated. Recover
      // the revision from an authenticated server read, but never treat a
      // changed start/end/title/status/tag relation as the same approved plan.
      var revision = original.updatedAt;
      if (revision == null) {
        final current = await db.pocketBase
            .collection(PbCollections.plans)
            .getOne(original.pocketRecordId!);
        DateTime? liveUtc(String field) {
          final raw = current.data[field]?.toString().trim() ?? '';
          if (raw.isEmpty) return null;
          return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toUtc();
        }
        bool sameInstant(DateTime? live, DateTime expected) =>
            live != null &&
            live.difference(expected).inMilliseconds.abs() < 1000;
        final rawTags = current.data['tags_link'];
        final liveTagIds = rawTags is List
            ? rawTags.map((tag) => tag.toString()).toSet()
            : <String>{};
        final oldTagIds = original.tags
            .map((tag) => tag.pbRecordId?.trim() ?? '').toSet();
        if (oldTagIds.contains('') ||
            liveTagIds.length != oldTagIds.length ||
            !liveTagIds.containsAll(oldTagIds) ||
            current.data['title']?.toString() != original.title ||
            (current.data['is_done'] == true) != original.isDone ||
            !sameInstant(liveUtc('start_time'), originalStart) ||
            !sameInstant(liveUtc('end_time'), originalEnd)) {
          throw StateError('План изменён на сервере после предпросмотра. '
              'Обновите календарь и проверьте изменения заново.');
        }
        revision = DateTime.tryParse(
            current.updated.replaceFirst(' ', 'T'))?.toUtc();
      }
      if (revision == null) {
        throw StateError('Нет версии записи PocketBase для проверки '
            'конкурентных изменений. Ничего не сохранено.');
      }
      final anchor = db.planningAuditAnchorDateKey(original);
      rows.add({
        'id': original.pocketRecordId,
        'expected_updated': revision.toUtc().toIso8601String(),
        'expected_start': originalStart.toUtc().toIso8601String(),
        'expected_end': originalEnd.toUtc().toIso8601String(),
        'expected_title': original.title,
        'expected_is_done': original.isDone,
        'start_time': db.viktorProfileWallToUtc(move.start).toIso8601String(),
        'end_time': db.viktorProfileWallToUtc(move.end).toIso8601String(),
        if (move.kind == 'move') 'initial_date_key': anchor,
        if (move.kind == 'move')
          'is_postponed': db.planningShouldMarkPostponed(
            anchorKey: anchor, newScheduleKey: move.day),
      });
    }
    final url = '${kPocketBaseUrl.endsWith('/')
        ? kPocketBaseUrl.substring(0, kPocketBaseUrl.length - 1)
        : kPocketBaseUrl}/api/viktor/schedule/commit';
    late final http.Response response;
    try {
      response = await http.post(Uri.parse(url), headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }, body: jsonEncode({
        'request_id': requestId,
        'patches': rows,
      })).timeout(const Duration(seconds: 35));
    } catch (_) {
      throw StateError('Не удалось подтвердить результат сохранения. '
          'Возможен выполненный перенос — обновите календарь, '
          'не отправляйте команду повторно.');
    }
    Map<String, dynamic> body = {};
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic>) body = data;
    } catch (_) {}
    if (response.statusCode != 200 || body['ok'] != true ||
        body['updated'] != rows.length) {
      final reason = (body['error'] ?? 'HTTP ${response.statusCode}')
          .toString();
      throw StateError('Сервер отклонил групповой перенос ($reason). '
          'Транзакция не применена; проверьте актуальное расписание.');
    }
    // Independently re-read all changed rows from the server. A successful
    // HTTP acknowledgement alone is not evidence of the displayed schedule.
    try {
      await db.viktorRefreshPlansAfterCommit();
      for (final row in rows) {
        final actual = await db.pocketBase.collection(PbCollections.plans)
            .getOne(row['id'] as String);
        DateTime readTime(String key) {
          final raw = actual.data[key]?.toString() ?? '';
          return DateTime.parse(raw.replaceFirst(' ', 'T')).toUtc();
        }
        DateTime requested(String key) =>
            DateTime.parse(row[key] as String).toUtc();
        if (readTime('start_time').difference(requested('start_time'))
                    .inMilliseconds.abs() > 999 ||
            readTime('end_time').difference(requested('end_time'))
                    .inMilliseconds.abs() > 999) {
          throw StateError('not_persisted');
        }
      }
    } catch (_) {
      throw StateError('Сервер принял перенос, но проверить конечное '
          'расписание не удалось. Обновите приложение перед повтором.');
    }
    return 'Перенесено и проверено на сервере планов: ${rows.length}.';
  }
}
