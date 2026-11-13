import 'dart:convert';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/data/ai/viktor_date_scope.dart';
import 'package:counter/data/ai/viktor_historical_records.dart';
import 'package:http/http.dart' as http;

class ViktorAdjacentRecordIntent {
  const ViktorAdjacentRecordIntent(this.firstTitle, this.secondTitle, this.minutes);
  final String firstTitle, secondTitle;
  final int minutes;

  static ViktorAdjacentRecordIntent? parse(String input) {
    if (!RegExp('сегодня|сегодняшн', caseSensitive: false).hasMatch(input)) {
      return null;
    }
    final match = RegExp(
      r'(?:сократи|уменьши)\s+.{0,65}?запис(?:ь|и)\s+'
      r'(.+?)\s+до\s+(\d{1,3})\s+минут\w*'
      r'.{0,110}?(?:продли|увеличь)\s+'
      r'(?:следующую\s+за\s+ней\s+|следующую\s+)?'
      r'(.+?)\s+до\s+(?:текущего\s+момента|сейчас|настоящего\s+момента)',
      caseSensitive: false, dotAll: true).firstMatch(input.replaceAll('ё', 'е'));
    if (match == null) return null;
    String title(String value) =>
        value.trim().replaceAll(RegExp(r'^[«"„\s]+|[»"“\s]+$'), '');
    final minutes = int.tryParse(match.group(2)!);
    final first = title(match.group(1)!), second = title(match.group(3)!);
    if (minutes == null || minutes < 1 || minutes > 720 ||
        first.length < 2 || second.length < 2) return null;
    return ViktorAdjacentRecordIntent(first, second, minutes);
  }
}

class ViktorAdjacentRecordSnapshot {
  const ViktorAdjacentRecordSnapshot(this.id, this.title, this.start,
      this.end, this.revision, this.status);
  final String id, title, status;
  final DateTime start, revision;
  final DateTime? end;
}

class ViktorAdjacentRecordPreview {
  const ViktorAdjacentRecordPreview(this.day, this.first, this.second,
      this.newFirstEnd, this.newSecondEnd);
  final String day;
  final ViktorAdjacentRecordSnapshot first, second;
  final DateTime newFirstEnd, newSecondEnd;
}

/// No sequential PATCH fallback. Both records must pass the server's atomic
/// ownership, revision, overlap, and immutable-field checks.
class ViktorAdjacentRecordEdit {
  const ViktorAdjacentRecordEdit(this.db);
  final DatabaseService db;
  String _norm(String text) => text.toLowerCase().replaceAll('ё', 'е').trim();
  DateTime? _time(Map<String, dynamic> row, String field) =>
      ViktorHistoricalRecords.recordTime(row, field);
  String _clock(DateTime utc) {
    final wall = db.applyUserOffset(utc);
    return '${wall.hour.toString().padLeft(2, '0')}:'
        '${wall.minute.toString().padLeft(2, '0')}';
  }

  Future<ViktorAdjacentRecordSnapshot> _read(String id) async {
    final owner = db.pocketBase.authStore.record?.id ?? '';
    if (owner.isEmpty) throw StateError('Войдите в LIFE OS.');
    final row = await db.pocketBase.collection(PbCollections.records).getOne(id);
    if (row.data['user_id']?.toString() != owner) {
      throw StateError('Нет доступа к записи.');
    }
    final start = _time(row.data, 'start_time');
    final revision = DateTime.tryParse(
        row.updated.replaceFirst(' ', 'T'))?.toUtc();
    if (start == null || revision == null) {
      throw StateError('Нет точных исходных времён или версии записи.');
    }
    return ViktorAdjacentRecordSnapshot(
      row.id, row.data['title']?.toString() ?? '', start.toUtc(),
      _time(row.data, 'end_time')?.toUtc(), revision,
      row.data['status']?.toString() ?? '',
    );
  }

  Future<ViktorAdjacentRecordPreview> prepare({
    required String day, required String firstTitle,
    required String secondTitle, required int firstMinutes,
    required DateTime targetNow,
  }) async {
    ViktorDateScope.parseDay(day);
    if (firstMinutes < 1 || firstMinutes > 720) {
      throw StateError('Некорректная длительность.');
    }
    final rows = await db.getRecords(forceNetwork: true);
    final sameDay = rows.where((row) {
      final t = _time(row, 'start_time');
      return t != null &&
          ViktorDateScope.key(db.applyUserOffset(t)) == day;
    }).toList()
      ..sort((a, b) => _time(a, 'start_time')!
          .compareTo(_time(b, 'start_time')!));
    if (sameDay.length > 100) {
      throw StateError('Слишком много записей за день.');
    }
    final matches = sameDay.where((row) =>
        _norm(row['title']?.toString() ?? '') == _norm(firstTitle)).toList();
    if (matches.length != 1) {
      throw StateError(matches.isEmpty
          ? 'Не найдена запись «$firstTitle».'
          : 'Несколько записей «$firstTitle»; требуется уточнить время.');
    }
    final index = sameDay.indexOf(matches.single);
    if (index + 1 >= sameDay.length ||
        _norm(sameDay[index + 1]['title']?.toString() ?? '') !=
            _norm(secondTitle)) {
      throw StateError('Сразу после «$firstTitle» нет записи «$secondTitle».');
    }
    String id(Map<String, dynamic> row) =>
        (row['_pb_record_id'] ?? row['id'] ?? '').toString();
    final first = await _read(id(matches.single));
    final second = await _read(id(sameDay[index + 1]));
    if (_norm(first.title) != _norm(firstTitle) ||
        _norm(second.title) != _norm(secondTitle) ||
        first.end == null || !first.start.isBefore(second.start) ||
        second.start.isBefore(first.end!)) {
      throw StateError('Записи изменились или пересекаются.');
    }
    final firstEnd = first.start.add(Duration(minutes: firstMinutes));
    final now = targetNow.toUtc();
    if (!firstEnd.isBefore(first.end!) ||
        firstEnd.isAfter(second.start) ||
        !now.isAfter(second.start) ||
        (second.end != null && !now.isAfter(second.end!)) ||
        now.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 2))) ||
        now.difference(firstEnd) > const Duration(hours: 24) ||
        ViktorDateScope.key(db.applyUserOffset(now)) != day) {
      throw StateError('Не удалось безопасно пересчитать эти интервалы.');
    }
    for (final row in rows) {
      if (id(row) == first.id || id(row) == second.id) continue;
      final start = _time(row, 'start_time');
      if (start == null) continue;
      final end = _time(row, 'end_time') ?? now;
      if (start.isBefore(now) && end.isAfter(firstEnd)) {
        throw StateError('Новый интервал пересекается с «${row['title']}».');
      }
    }
    return ViktorAdjacentRecordPreview(day, first, second, firstEnd, now);
  }

  String describe(ViktorAdjacentRecordPreview p) =>
      'Две записи за ${p.day} (время профиля):\n'
      '«${p.first.title}»: ${_clock(p.first.start)}–${_clock(p.first.end!)}'
      ' → ${_clock(p.first.start)}–${_clock(p.newFirstEnd)}'
      ' (${p.newFirstEnd.difference(p.first.start).inMinutes} мин.)\n'
      '«${p.second.title}»: ${_clock(p.second.start)}–'
      '${p.second.end == null ? "идёт" : _clock(p.second.end!)}'
      ' → ${_clock(p.newFirstEnd)}–${_clock(p.newSecondEnd)}\n'
      'Другие записи не изменятся. Подтвердите обе правки.';

  Future<String> apply(ViktorAdjacentRecordPreview p, String requestId) async {
    final token = db.pocketBase.authStore.token.trim();
    if (token.isEmpty) throw StateError('Нужна авторизация.');
    final first = await _read(p.first.id), second = await _read(p.second.id);
    bool same(ViktorAdjacentRecordSnapshot a, ViktorAdjacentRecordSnapshot b) =>
        a.title == b.title && a.start == b.start &&
        a.end == b.end && a.revision == b.revision && a.status == b.status;
    if (!same(first, p.first) || !same(second, p.second)) {
      throw StateError('Записи изменились после предпросмотра.');
    }
    Map<String, Object?> patch(ViktorAdjacentRecordSnapshot row,
        DateTime start, DateTime end) => {
      'id': row.id, 'expected_title': row.title,
      'expected_updated': row.revision.toIso8601String(),
      'expected_start': row.start.toIso8601String(),
      'expected_end': row.end?.toIso8601String(),
      'expected_status': row.status,
      'start_time': start.toIso8601String(), 'end_time': end.toIso8601String(),
    };
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$kPocketBaseUrl/api/viktor/records/adjust-adjacent'),
        headers: {'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'},
        body: jsonEncode({'request_id': requestId,
          'first': patch(first, first.start, p.newFirstEnd),
          'second': patch(second, p.newFirstEnd, p.newSecondEnd),
        }),
      ).timeout(const Duration(seconds: 35));
    } catch (_) {
      throw StateError('Итог сохранения неизвестен. '
          'Проверьте Timeline, прежде чем повторять.');
    }
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    if (response.statusCode != 200 || body['ok'] != true) {
      throw StateError('Транзакция отклонена: '
          '${body['error'] ?? response.statusCode}. Ничего не изменено.');
    }
    try {
      final savedFirst = await _read(first.id);
      final savedSecond = await _read(second.id);
      bool sameInstant(DateTime? actual, DateTime expected) =>
          actual != null &&
          actual.difference(expected).inMilliseconds.abs() < 1000;
      if (!sameInstant(savedFirst.start, first.start) ||
          !sameInstant(savedFirst.end, p.newFirstEnd) ||
          !sameInstant(savedSecond.start, p.newFirstEnd) ||
          !sameInstant(savedSecond.end, p.newSecondEnd)) {
        throw StateError('readback_mismatch');
      }
      await db.getRecords(forceNetwork: true);
    } catch (_) {
      throw StateError('Сервер принял правки, но прочитать результат '
          'не удалось. Обновите Timeline.');
    }
    return 'Обе записи сохранены и проверены на сервере.';
  }
}
