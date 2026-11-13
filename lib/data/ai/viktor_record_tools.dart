import 'package:counter/data/database_service.dart';
import 'viktor_date_scope.dart';
import 'viktor_historical_records.dart';
import 'viktor_atomic_record_gateway.dart';

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

  /// Resolve two consecutive real Timeline records, never plans. The
  /// requested duration is applied to the first record; the following
  /// record starts exactly at the new boundary and keeps its original end.
  /// This is a preview only; no writes happen until user approval.
  Future<ViktorAdjacentResizePreview> prepareAdjacent(
      Map<String, Object?> args) async {
    final wallDay = args['wall_day'] as String;
    final firstId = args['first_record_id'] as String;
    final secondId = args['second_record_id'] as String;
    final minutes = args['first_duration_minutes'] as int;
    final rows = await _dayRows(wallDay);
    rows.sort((a, b) =>
        ViktorHistoricalRecords.recordTime(a, 'start_time')!.compareTo(
        ViktorHistoricalRecords.recordTime(b, 'start_time')!));
    final firstIndex = rows.indexWhere((r) => r['id'] == firstId);
    final secondIndex = rows.indexWhere((r) => r['id'] == secondId);
    if (firstIndex < 0 || secondIndex != firstIndex + 1) {
      throw StateError('Записи не найдены подряд за $wallDay. '
          'Ничего не изменено.');
    }
    final first = rows[firstIndex];
    final second = rows[secondIndex];
    if ((first['parent_id']?.toString().trim().isNotEmpty ?? false) ||
        (second['parent_id']?.toString().trim().isNotEmpty ?? false)) {
      throw StateError('Нельзя менять вложенные записи этим действием.');
    }
    final firstStart = ViktorHistoricalRecords.recordTime(
        first, 'start_time')!;
    final firstEnd = ViktorHistoricalRecords.recordTime(first, 'end_time');
    final secondStart = ViktorHistoricalRecords.recordTime(
        second, 'start_time')!;
    final secondEnd = ViktorHistoricalRecords.recordTime(second, 'end_time');
    if (firstEnd == null || !firstEnd.isAfter(firstStart) ||
        secondStart.isBefore(firstEnd) ||
        (secondEnd != null && !secondEnd.isAfter(secondStart))) {
      throw StateError('У соседних записей некорректные границы. '
          'Ничего не изменено.');
    }
    final boundary = firstStart.add(Duration(minutes: minutes));
    if (!boundary.isAfter(firstStart) ||
        !boundary.isBefore(firstEnd) ||
        !boundary.isBefore(secondStart) ||
        (secondEnd != null && !boundary.isBefore(secondEnd))) {
      throw StateError('Невозможно сократить первую запись до $minutes мин. '
          'и безопасно продлить следующую.');
    }
    // The server repeats a global owner-scoped conflict check transactionally.
    // Local preview checks the day immediately for comprehensible feedback.
    final now = DatabaseService.getPlanetaryNow().toUtc();
    for (final row in rows) {
      if (row['id'] == firstId || row['id'] == secondId ||
          (row['parent_id']?.toString().trim().isNotEmpty ?? false)) {
        continue;
      }
      final start = ViktorHistoricalRecords.recordTime(row, 'start_time');
      final end = ViktorHistoricalRecords.recordTime(row, 'end_time') ?? now;
      if (start != null && start.isBefore(secondEnd ?? now) &&
          end.isAfter(firstStart)) {
        throw StateError('В освободившееся время попадает другая запись '
            '«${_title(row["title"])}». Ничего не изменено.');
      }
    }
    return ViktorAdjacentResizePreview(
      wallDay: wallDay, first: first, second: second,
      firstStart: firstStart, firstEnd: firstEnd,
      secondStart: secondStart, secondEnd: secondEnd,
      newBoundary: boundary,
    );
  }

  String describeAdjacent(ViktorAdjacentResizePreview p) {
    String format(DateTime time) => _clock(db.applyUserOffset(time));
    final end = p.secondEnd == null ? 'идёт'
        : format(p.secondEnd!);
    return 'Изменить две последовательные записи за ${p.wallDay}:\\n'
        '1. «${_title(p.first["title"])}»: '
        '${format(p.firstStart)}–${format(p.firstEnd)} → '
        '${format(p.firstStart)}–${format(p.newBoundary)}.\\n'
        '2. «${_title(p.second["title"])}»: '
        '${format(p.secondStart)}–$end → '
        '${format(p.newBoundary)}–$end.\\n'
        'Остальные записи и окончание второй записи не меняются. '
        'Сохранить оба изменения одной транзакцией?';
  }

  Future<String> commitAdjacent(ViktorAdjacentResizePreview approved,
      {required String requestId}) =>
      ViktorAtomicRecordGateway(db).commit(
          approved: approved, requestId: requestId);

  static DateTime parseUtc(Object? raw) {
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
      final start = parseUtc(entry['start_utc']);
      final end = parseUtc(entry['end_utc']);
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

/// Immutable pre-write snapshot used to compare server revisions and to
/// display exactly which boundaries will change before user confirmation.
class ViktorAdjacentResizePreview {
  const ViktorAdjacentResizePreview({
    required this.wallDay,
    required this.first,
    required this.second,
    required this.firstStart,
    required this.firstEnd,
    required this.secondStart,
    required this.secondEnd,
    required this.newBoundary,
  });
  final String wallDay;
  final Map<String, dynamic> first;
  final Map<String, dynamic> second;
  final DateTime firstStart;
  final DateTime firstEnd;
  final DateTime secondStart;
  final DateTime? secondEnd;
  final DateTime newBoundary;
}
