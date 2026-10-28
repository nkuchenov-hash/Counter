import 'package:counter/data/database_service.dart';
import 'viktor_date_scope.dart';
import 'viktor_historical_records.dart';

/// Generic owner-scoped Records tools: inspect actual Timeline entries, then
/// propose explicit completed intervals. Only the authenticated Brain writes.
class ViktorRecordTools {
  ViktorRecordTools(this.db);
  final DatabaseService db;

  static String _key(DateTime wall) => ViktorDateScope.key(wall);
  static String _clock(DateTime wall) =>
      '${wall.hour.toString().padLeft(2, '0')}:'
      '${wall.minute.toString().padLeft(2, '0')}';
  static String _title(Object? value) => value?.toString().trim() ?? '';

  Future<List<Map<String, dynamic>>> _dayRows(String wallDay) async {
    final day = ViktorDateScope.parseDay(wallDay);
    final records = await db.getRecords(forceNetwork: true);
    return records.where((row) {
      final start = ViktorHistoricalRecords.recordTime(row, 'start_time');
      return start != null && _key(db.applyUserOffset(start)) == _key(day);
    }).toList();
  }

  /// Compact observations include actual wall clocks and exact UTC anchors.
  Future<String> listDay(String wallDay) async {
    final rows = await _dayRows(wallDay);
    rows.sort((a, b) =>
        ViktorHistoricalRecords.recordTime(a, 'start_time')!.compareTo(
          ViktorHistoricalRecords.recordTime(b, 'start_time')!));
    if (rows.length > 80) {
      return 'За $wallDay найдено ${rows.length} записей. '
          'Уточните нужный интервал.';
    }
    if (rows.isEmpty) return 'За $wallDay записей нет.';
    final result = <String>[];
    for (final row in rows) {
      final start = ViktorHistoricalRecords.recordTime(row, 'start_time')!;
      final end = ViktorHistoricalRecords.recordTime(row, 'end_time');
      final localStart = db.applyUserOffset(start);
      final localEnd = end == null ? null : db.applyUserOffset(end);
      final title = _title(row['title']);
      result.add(
        'title=${title.length > 160 ? title.substring(0, 160) : title}; '
        'start_local=${_clock(localStart)}; '
        'end_local=${localEnd == null ? "running" : _clock(localEnd)}; '
        'start_utc=${start.toIso8601String()}; '
        'end_utc=${end?.toIso8601String() ?? "running"}',
      );
    }
    return 'Записи за $wallDay (время профиля и UTC для сохранения):\n'
        '${result.join("\n")}';
  }

  static DateTime _parseUtc(Object? raw) {
    if (raw is! String ||
        !RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d{1,6})?)?Z$')
            .hasMatch(raw)) {
      throw const FormatException(
          'Use ISO 8601 UTC timestamps ending with Z');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || !parsed.isUtc) {
      throw const FormatException('Invalid UTC timestamp');
    }
    return parsed;
  }

  /// One generic create interface works for any set of completed activities,
  /// regardless of how the user phrased or sourced their time boundaries.
  Future<ViktorRecordCreatePreview> prepare({
    required String wallDay,
    required List<Map<String, Object?>> records,
  }) async {
    ViktorDateScope.parseDay(wallDay);
    if (records.isEmpty || records.length > 12) {
      throw const FormatException('Expected 1–12 completed records');
    }
    final now = DatabaseService.getPlanetaryNow().toUtc();
    final proposed = <ViktorRecordCreateSlot>[];
    for (final entry in records) {
      final title = _title(entry['title']);
      if (title.length < 2 || title.length > 160) {
        throw const FormatException('Invalid completed record title');
      }
      final start = _parseUtc(entry['start_utc']);
      final end = _parseUtc(entry['end_utc']);
      if (!end.isAfter(start) ||
          end.difference(start) > const Duration(hours: 12) ||
          end.isAfter(now.add(const Duration(minutes: 2)))) {
        throw StateError('Некорректный интервал записи «$title».');
      }
      if (_key(db.applyUserOffset(start)) != wallDay) {
        throw StateError('Начало записи «$title» не относится к $wallDay '
            'в часовом поясе профиля.');
      }
      proposed.add(ViktorRecordCreateSlot(title, start, end));
    }
    proposed.sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < proposed.length; i++) {
      if (proposed[i].start.isBefore(proposed[i - 1].end)) {
        throw StateError('Предложенные записи пересекаются.');
      }
    }
    final current = await _dayRows(wallDay);
    final slots = <ViktorRecordCreateSlot>[];
    for (final item in proposed) {
      var duplicate = false;
      for (final existing in current) {
        final existingStart =
            ViktorHistoricalRecords.recordTime(existing, 'start_time');
        final existingEnd =
            ViktorHistoricalRecords.recordTime(existing, 'end_time');
        if (existingStart == null) continue;
        final same = existingStart == item.start &&
            existingEnd == item.end &&
            ViktorHistoricalRecords.normalized(
                _title(existing['title'])) ==
            ViktorHistoricalRecords.normalized(item.title);
        if (same) {
          duplicate = true;
          break;
        }
        final occupiedEnd = existingEnd ?? now;
        if (existingStart.isBefore(item.end) &&
            occupiedEnd.isAfter(item.start)) {
          throw StateError('«${item.title}» пересекается с записью '
              '«${_title(existing["title"])}». Уточните время.');
        }
      }
      slots.add(item.withExisting(duplicate));
    }
    return ViktorRecordCreatePreview(wallDay, slots);
  }

  Future<String> apply(ViktorRecordCreatePreview preview) async {
    var created = 0;
    for (final slot in preview.slots) {
      if (slot.alreadyExists) continue;
      final id = await db.writeRecord(
        preview.wallDay, slot.title,
        explicitStartTime: slot.start,
        explicitEndTime: slot.end,
      );
      if (id == null) {
        throw StateError('Сохранено $created из '
            '${preview.slots.length} записей. Проверьте результат.');
      }
      created++;
    }
    return 'Добавлено записей: $created. Уже существовали: '
        '${preview.slots.length - created}. Синхронизация LIFE OS.';
  }

  String describe(ViktorRecordCreatePreview preview) {
    final lines = <String>[];
    for (final slot in preview.slots) {
      lines.add(
        '${_clock(db.applyUserOffset(slot.start))}–'
        '${_clock(db.applyUserOffset(slot.end))}  ${slot.title}'
        '${slot.alreadyExists ? " (уже есть)" : ""}',
      );
    }
    return 'Создать завершённые записи за ${preview.wallDay} '
        '(время профиля):\n${lines.join("\n")}\n'
        'Подтвердите интервалы; до подтверждения записи не создаются.';
  }
}

class ViktorRecordCreateSlot {
  const ViktorRecordCreateSlot(this.title, this.start, this.end,
      {this.alreadyExists = false});
  final String title;
  final DateTime start;
  final DateTime end;
  final bool alreadyExists;

  ViktorRecordCreateSlot withExisting(bool value) =>
      ViktorRecordCreateSlot(title, start, end, alreadyExists: value);
}

class ViktorRecordCreatePreview {
  const ViktorRecordCreatePreview(this.wallDay, this.slots);
  final String wallDay;
  final List<ViktorRecordCreateSlot> slots;
}
