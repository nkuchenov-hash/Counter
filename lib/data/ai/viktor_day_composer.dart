import 'package:counter/data/models.dart';
import 'viktor_action_contract.dart';
import 'viktor_schedule_planner.dart';

/// An immutable, combined preview. No writes occur while composing it.
class ViktorProposedMeeting {
  const ViktorProposedMeeting({
    required this.title,
    required this.start,
    required this.end,
    required this.alreadyExists,
  });
  final String title;
  final DateTime start;
  final DateTime end;
  final bool alreadyExists;
}

class ViktorComposedDay {
  const ViktorComposedDay({
    required this.moves,
    required this.meetings,
    required this.signature,
    required this.urgentCount,
  });

  final List<ViktorBulkMove> moves;
  final List<ViktorProposedMeeting> meetings;
  final String signature;
  final int urgentCount;

  String describe() {
    String hm(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    final dates = moves.isEmpty ? '' : ' ${moves.first.day}';
    return [
      'Единый предварительный план$dates:',
      'Перенести невыполненных планов: ${moves.length}'
          ' (с пометкой срочности: $urgentCount).',
      for (final m in moves)
        '${hm(m.start)}–${hm(m.end)}  ${m.plan.title}',
      '',
      'Встречи:',
      for (final m in meetings)
        '${hm(m.start)}–${hm(m.end)}  ${m.title}'
          '${m.alreadyExists ? ' (уже существует)' : ' (добавить)'}',
      '',
      'Встречи и существующие планы не пересекаются с переносимыми задачами.',
      'Перед применением состояние обоих дней будет проверено повторно.',
      'Сохранение нескольких записей не атомарно: при сетевой ошибке '
        'проверьте результат перед повторным запросом.',
    ].join('\n');
  }
}

class ViktorDayComposer {
  const ViktorDayComposer();

  static String _day(DateTime d) => ViktorBulkPlanner.key(d);

  static bool _overlap(DateTime s1, DateTime e1, DateTime s2, DateTime e2) =>
      s1.isBefore(e2) && e1.isAfter(s2);

  /// Safe calendar composition: approved meetings are immovable reservations,
  /// and tasks are fitted in remaining gaps in stable urgency/time order.
  /// Existing target plans are never moved without explicit authorization.
  ViktorComposedDay calculate({
    required ViktorAction action,
    required List<PlanningTask> source,
    required List<PlanningTask> target,
    required bool Function(PlanningTask) sourceMatches,
    required bool Function(PlanningTask) urgent,
    required bool Function(PlanningTask) fixedTime,
    required DateTime Function(String, String, String) wallTime,
  }) {
    if (action.name != 'compose_day') {
      throw const FormatException('Expected compose_day');
    }
    final a = action.arguments;
    final sourceDay = a['source_day'] as String;
    final targetDay = a['target_day'] as String;
    final zone = a['timezone'] as String;
    if (source.length + target.length > 160) {
      throw StateError('Слишком много планов для безопасного пересчёта.');
    }
    final sourceGroup = source.where(sourceMatches).toList();
    if (sourceGroup.isEmpty) {
      throw StateError('Нет задач для фильтра «${a['source_filter']}» '
          'в $sourceDay. Категорию/тег нужно уточнить.');
    }
    final chosen = ViktorBulkPlanner.sorted(
        sourceGroup.where((p) => !p.isDone));
    if (a['urgent_first'] == true) {
      chosen.sort((left, right) {
        final a = urgent(left);
        final b = urgent(right);
        return a == b ? 0 : (a ? -1 : 1);
      });
    }
    for (final p in chosen) {
      if (p.dateKey != sourceDay ||
          p.pocketRecordId == null ||
          !p.isSynced ||
          (p.rrule ?? '').isNotEmpty ||
          (p.recurrenceInstanceDateKey ?? '').isNotEmpty ||
          p.recordIdForBackend.startsWith('virt-') ||
          p.recordIdForBackend.startsWith('optimistic-') ||
          fixedTime(p) || p.startTime == null || p.endDateTime == null ||
          p.endDateTime!.difference(p.startTime!).inMinutes < 10) {
        throw StateError('«${p.title}»: нельзя безопасно переносить '
            'несохранённую, закреплённую или повторяющуюся задачу.');
      }
    }

    final reservations = <({DateTime start, DateTime end, String title})>[
      for (final p in target)
        if (p.startTime != null && p.endDateTime != null)
          (start: p.startTime!, end: p.endDateTime!, title: p.title),
    ];

    final meetings = <ViktorProposedMeeting>[];
    for (final raw in a['meetings'] as List) {
      final info = Map<String, Object?>.from(raw as Map);
      final title = info['title'] as String;
      final start = wallTime(targetDay, info['start_time'] as String, zone);
      final end = start.add(Duration(minutes: info['duration_minutes'] as int));
      if (_day(start) != targetDay || _day(end) != targetDay) {
        throw StateError('Встреча «$title» выходит за границы '
            'выбранного дня. Проверьте часовой пояс.');
      }
      final identical = target.any((p) =>
          p.title.trim().toLowerCase() == title.trim().toLowerCase() &&
          p.startTime == start && p.endDateTime == end);
      // If an identical appointment already exists, it is reserved by the
      // existing target plan; do not create a duplicate during a retry.
      if (!identical) {
        for (final r in reservations) {
          if (_overlap(start, end, r.start, r.end)) {
            throw StateError('Встреча «$title» пересекается с «${r.title}». '
                'Никаких изменений не внесено.');
          }
        }
        reservations.add((start: start, end: end, title: title));
      }
      meetings.add(ViktorProposedMeeting(
        title: title, start: start, end: end, alreadyExists: identical));
    }
    reservations.sort((a, b) => a.start.compareTo(b.start));

    var cursor = wallTime(targetDay, a['start_time'] as String, zone);
    if (_day(cursor) != targetDay) {
      throw StateError('Начало переноса вне целевого дня: $targetDay.');
    }
    final moves = <ViktorBulkMove>[];
    for (final p in chosen) {
      final length = p.endDateTime!.difference(p.startTime!);
      var finish = cursor.add(length);
      // A single existing appointment cannot be moved. Search for the next
      // free interval that can fit this task entirely without splitting it.
      for (var attempts = 0; attempts <= reservations.length; attempts++) {
        final conflict = reservations.where(
            (r) => _overlap(cursor, finish, r.start, r.end));
        if (conflict.isEmpty) break;
        final first = conflict.first;
        if (!first.end.isAfter(cursor)) {
          throw StateError('Не удалось найти свободное время для «${p.title}».');
        }
        cursor = first.end;
        finish = cursor.add(length);
      }
      if (_day(cursor) != targetDay || _day(finish) != targetDay) {
        throw StateError('Задача «${p.title}» не помещается в $targetDay. '
            'Никаких изменений не внесено.');
      }
      moves.add(ViktorBulkMove(p, cursor, finish, targetDay, 'move'));
      reservations.add((start: cursor, end: finish, title: p.title));
      reservations.sort((a, b) => a.start.compareTo(b.start));
      cursor = finish;
    }
    if (moves.isEmpty && meetings.every((m) => m.alreadyExists)) {
      throw StateError('Нечего переносить или добавлять.');
    }
    return ViktorComposedDay(
      moves: moves,
      meetings: meetings,
      signature: ViktorBulkPlanner.snapshot(source, target) +
          '\nCATEGORY_FILTER:${a['source_filter']}\n' +
          sourceGroup.map((p) => '${p.recordIdForBackend}:'
              '${p.tags.map((t) => t.name).join(',')}').join('|'),
      urgentCount: chosen.where(urgent).length,
    );
  }
}
