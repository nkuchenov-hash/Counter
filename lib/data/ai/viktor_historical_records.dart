import 'package:counter/data/database_service.dart';
import 'viktor_date_scope.dart';

/// A request to backfill past activities between two EXISTING Timeline records.
/// This is separate from Planning and from starting a running timer.
class ViktorHistoricalRecordIntent {
  const ViktorHistoricalRecordIntent({
    required this.day,
    required this.beforeTitle,
    required this.afterTitle,
    required this.titles,
  });

  final DateTime day;
  final String beforeTitle;
  final String afterTitle;
  final List<String> titles;

  static ViktorHistoricalRecordIntent? parse(
    String input, List<Map<String, String>> history, DateTime today,
  ) {
    final command = input.trim();
    final explicit = _parseStatement(command, today);
    if (explicit != null && RegExp(
        r'добавь|запиши|сохрани|внеси', caseSensitive: false)
        .hasMatch(command)) return explicit;
    if (!RegExp(r'^(?:добавь|запиши|внеси|сохрани)\s+'
        r'(?:эти|их|перечисленные)\s+(?:записи|занятия|дела)'
        r'(?:\s+тоже)?[.!?\s]*$', caseSensitive: false).hasMatch(command)) {
      return null;
    }
    for (final turn in history.reversed) {
      if (turn['role'] != 'user') continue;
      final originalDay = turn['message_day'];
      // Never reinterpret an older "сегодня" as today's date merely because
      // the user refers back to that message after midnight.
      final anchor = originalDay == null ? null : DateTime.tryParse(originalDay);
      if (anchor == null) continue;
      final parsed = _parseStatement(turn['content'] ?? '', anchor);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static ViktorHistoricalRecordIntent? _parseStatement(
      String source, DateTime today) {
    final m = RegExp(
      r'между\s+(.+?)\s+и\s+(.+?)\s+сегодня\s+'
      r'у\s+меня\s+был[аои]?\s+(.+)',
      caseSensitive: false, dotAll: true,
    ).firstMatch(source);
    if (m == null) return null;
    final before = m.group(1)!.trim();
    final after = m.group(2)!.trim();
    var activities = m.group(3)!.trim().replaceFirst(
      RegExp(r'[.!?]\s*(?:добавь|запиши|внеси|сохрани)\b.*$',
          caseSensitive: false, dotAll: true), '',
    ).replaceAll(RegExp(r'[.!?]+\s*$'), '');
    final tokens = activities.split(RegExp(r'\s*,\s*'));
    if (tokens.isEmpty) return null;
    if (tokens.length > 1) {
      final last = tokens.removeLast();
      tokens.addAll(last.split(RegExp(r'\s+и\s+', caseSensitive: false)));
    }
    final titles = tokens.map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if (before.length < 3 || after.length < 3 ||
        before.length > 120 || after.length > 120 ||
        titles.length < 2 || titles.length > 12 ||
        titles.any((x) => x.length < 2 || x.length > 160)) return null;
    return ViktorHistoricalRecordIntent(
      day: today, beforeTitle: before, afterTitle: after, titles: titles);
  }
}

class ViktorHistoricalSlot {
  const ViktorHistoricalSlot(this.title, this.start, this.end,
      {this.alreadyExists = false});
  final String title;
  final DateTime start;
  final DateTime end;
  final bool alreadyExists;
}

class ViktorHistoricalPreview {
  const ViktorHistoricalPreview(this.slots, this.before, this.after);
  final List<ViktorHistoricalSlot> slots;
  final String before;
  final String after;

  String describe(DateTime Function(DateTime) toWall) {
    String clock(DateTime utc) {
      final wall = toWall(utc);
      final h = wall.hour.toString().padLeft(2, '0');
      final m = wall.minute.toString().padLeft(2, '0');
      return h + ':' + m;
    }
    return 'Добавить завершённые записи между «' + before + '» и «' +
        after + '» (время ориентировочное):\n' +
        slots.map((s) => clock(s.start) + '–' + clock(s.end) + '  ' +
          s.title + (s.alreadyExists ? ' (уже есть)' : '')).join('\n') +
        '\nПодтвердите распределение времени. ' +
        'Ничего не будет записано до подтверждения.';
  }
}

/// Builds an explicit, inspectable timeline proposal against actual owned data.
/// Does not infer missing anchors, overlap existing records or invent certainty.
class ViktorHistoricalRecords {
  ViktorHistoricalRecords(this.db);
  final DatabaseService db;

  static String normalized(String value) => value.toLowerCase().trim()
      .replaceAll(RegExp(r'[^a-zа-яё0-9]+', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s+'), ' ').trim();

  static DateTime? recordTime(Map<String, dynamic> r, String key) {
    final raw = r[key] ?? r[key == 'start_time' ? 'startTime' : 'endTime'];
    if (raw is DateTime) return raw.toUtc();
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  static List<ViktorHistoricalSlot> splitGap(
      DateTime start, DateTime end, List<String> titles) {
    final minutes = end.difference(start).inMinutes;
    if (!end.isAfter(start) || titles.isEmpty ||
        minutes < titles.length * 5 || minutes > 720) {
      throw StateError('Между указанными записями недостаточно '
          'свободного времени или границы неверны.');
    }
    final slots = <ViktorHistoricalSlot>[];
    for (var i = 0; i < titles.length; i++) {
      final a = start.add(Duration(minutes: minutes * i ~/ titles.length));
      final b = i == titles.length - 1 ? end
          : start.add(Duration(minutes: minutes * (i + 1) ~/ titles.length));
      slots.add(ViktorHistoricalSlot(titles[i], a, b));
    }
    return slots;
  }

  Map<String, dynamic> _singleAnchor(List<Map<String, dynamic>> rows,
      String fragment, {required bool needEnd}) {
    final target = normalized(fragment);
    final exact = rows.where((r) => normalized((r['title'] ?? '').toString())
        == target).toList();
    final candidates = exact.isNotEmpty ? exact : rows.where((r) {
      final title = normalized((r['title'] ?? '').toString());
      return title.startsWith(target) || target.startsWith(title);
    }).toList();
    final valid = candidates.where((r) =>
        recordTime(r, needEnd ? 'end_time' : 'start_time') != null).toList();
    if (valid.length != 1) {
      throw StateError('Не удалось однозначно определить запись «' +
          fragment + '» и её время на выбранный день.');
    }
    return valid.single;
  }

  Future<ViktorHistoricalPreview> prepare({
    required String wallDay,
    required String beforeTitle,
    required String afterTitle,
    required List<String> titles,
  }) async {
    final day = ViktorDateScope.parseDay(wallDay);
    final raw = await db.getRecords(forceNetwork: true);
    final rows = raw.where((r) {
      final start = recordTime(r, 'start_time');
      if (start == null) return false;
      final wall = db.applyUserOffset(start);
      return ViktorDateScope.key(wall) == ViktorDateScope.key(day);
    }).toList();
    final before = _singleAnchor(rows, beforeTitle, needEnd: true);
    final after = _singleAnchor(rows, afterTitle, needEnd: false);
    final begin = recordTime(before, 'end_time')!;
    final finish = recordTime(after, 'start_time')!;
    final slots = splitGap(begin, finish, titles);
    final allowed = <String>{
      (before['record_id'] ?? '').toString(),
      (after['record_id'] ?? '').toString(),
    };
    final updated = <ViktorHistoricalSlot>[];
    for (final slot in slots) {
      final exact = rows.any((r) {
        return normalized((r['title'] ?? '').toString()) ==
                normalized(slot.title) &&
            recordTime(r, 'start_time') == slot.start &&
            recordTime(r, 'end_time') == slot.end;
      });
      updated.add(ViktorHistoricalSlot(slot.title, slot.start, slot.end,
          alreadyExists: exact));
    }
    for (final row in rows) {
      if (allowed.contains((row['record_id'] ?? '').toString())) continue;
      final start = recordTime(row, 'start_time');
      if (start == null) continue;
      final end = recordTime(row, 'end_time') ?? start;
      if (start.isBefore(finish) && end.isAfter(begin)) {
        final duplicate = updated.any((slot) => slot.alreadyExists &&
          slot.start == start && slot.end == end &&
          normalized(slot.title) ==
              normalized((row['title'] ?? '').toString()));
        if (!duplicate) {
          throw StateError('Между указанными границами уже есть другая '
              'запись «' + (row['title'] ?? '').toString() + '». '
              'Уточните свободный интервал, чтобы не создать пересечение.');
        }
      }
    }
    return ViktorHistoricalPreview(updated, beforeTitle, afterTitle);
  }

  Future<String> save(ViktorHistoricalPreview approved, {
    required String wallDay,
  }) async {
    var created = 0;
    for (final slot in approved.slots) {
      if (slot.alreadyExists) continue;
      final id = await db.writeRecord(
        wallDay, slot.title, explicitStartTime: slot.start,
        explicitEndTime: slot.end,
      );
      if (id == null) {
        throw StateError('Сохранено ' + created.toString() +
            ' записей из ' + approved.slots.length.toString() +
            '. Остальные не созданы. Проверьте записи перед повтором.');
      }
      created++;
    }
    return 'Добавлено записей: ' + created.toString() +
        '. Уже существовали: ' +
        (approved.slots.length - created).toString() +
        '. Изменения поставлены в очередь синхронизации LIFE OS.';
  }
}
