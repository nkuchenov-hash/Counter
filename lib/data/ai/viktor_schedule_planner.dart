import 'package:counter/data/models.dart';

import 'viktor_action_contract.dart';

/// Calculates a complete schedule preview without writing to PocketBase.
/// Caller must verify fresh state before applying the resulting patches.
class ViktorSchedulePreview {
  const ViktorSchedulePreview({required this.before, required this.after});
  final List<PlanningTask> before;
  final List<PlanningTask> after;

  List<PlanningTask> get changed {
    final baseline = {for (final p in before) p.recordIdForBackend: p};
    return after.where((p) {
      final old = baseline[p.recordIdForBackend];
      return old == null || old.startTime != p.startTime ||
          old.endDateTime != p.endDateTime;
    }).toList(growable: false);
  }
}

class ViktorSchedulePlanner {
  const ViktorSchedulePlanner();

  /// Deterministic positional reference resolution. Never delegate "last two"
  /// to an LLM or to the unordered PocketBase rows array.
  ///
  /// Returns null for non-positional messages. For an explicit positional swap,
  /// returns the TWO final scheduled plans in chronological order; if they
  /// cannot be identified safely, fails closed instead of guessing IDs.
  static List<String>? resolveLastTwoSwap(
      String input, List<PlanningTask> plans) {
    final text = input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final command = RegExp(
      r'(^|[\s,])(?:поменяй|переставь|обменяй|перекинь|swap|switch)(?=\s|[,.!?]|$)',
    ).hasMatch(text);
    if (!command || RegExp(
      r'(^|[\s,])не\s+(?:поменяй|переставь|обменяй|перекинь|swap|switch)',
    ).hasMatch(text)) return null;
    final russian = RegExp(
      r'(?:последн[а-яё]*\s+(?:два|две|2)\s+(?:план[а-яё]*|задач[а-яё]*|карточк[а-яё]*)'
      r'|(?:два|две|2)\s+последн[а-яё]*\s+(?:план[а-яё]*|задач[а-яё]*|карточк[а-яё]*))',
    ).hasMatch(text);
    final english = RegExp(
      r'last\s+(?:two|2)\s+(?:plans?|tasks?|cards?)',
    ).hasMatch(text);
    if (!russian && !english) return null;

    final scheduled = plans.where((p) =>
      p.startTime != null && p.endDateTime != null).toList()
      ..sort((left, right) {
        final time = left.startTime!.compareTo(right.startTime!);
        if (time != 0) return time;
        final order = left.order.compareTo(right.order);
        if (order != 0) return order;
        return left.recordIdForBackend.compareTo(right.recordIdForBackend);
      });
    if (scheduled.length < 2) {
      throw StateError('Для перестановки нужны два запланированных дела.');
    }
    final first = scheduled[scheduled.length - 2];
    final second = scheduled.last;
    if (first.startTime == second.startTime ||
        first.endDateTime!.isAfter(second.startTime!) ||
        first.pocketRecordId == null || second.pocketRecordId == null ||
        first.pocketRecordId == second.pocketRecordId) {
      throw StateError('Последние две карточки нельзя определить однозначно. '
          'Выберите две карточки вручную.');
    }
    return [first.pocketRecordId!, second.pocketRecordId!];
  }

  ViktorSchedulePreview calculate({
    required DateTime day,
    required List<PlanningTask> plans,
    required List<ViktorAction> actions,
    required bool Function(PlanningTask plan) fixedTime,
  }) {
    final edits = actions.where((a) =>
        a.name == 'update_plan_duration' ||
        a.name == 'move_plan_after' ||
        a.name == 'swap_plan_positions').toList(growable: false);
    final ordered = plans.where((p) =>
        p.startTime != null && p.endDateTime != null).toList()
      ..sort((a, b) {
        final c = a.startTime!.compareTo(b.startTime!);
        return c != 0 ? c : a.order.compareTo(b.order);
      });
    if (edits.isEmpty) {
      return ViktorSchedulePreview(before: plans, after: plans);
    }
    if (ordered.length > 100) {
      throw StateError('Слишком много задач для безопасного пересчёта.');
    }
    final originalIds = <String>{};
    final persistedIds = <String>{};
    for (final p in ordered) {
      if (!originalIds.add(p.recordIdForBackend)) {
        throw StateError('Обнаружены дубли идентификаторов планов.');
      }
      final id = p.pocketRecordId;
      if (id != null && id.isNotEmpty && !persistedIds.add(id)) {
        throw StateError('Обнаружены дубли сохранённых планов.');
      }
    }
    bool immutable(PlanningTask p) =>
        (p.rrule ?? '').isNotEmpty ||
        (p.recurrenceInstanceDateKey ?? '').isNotEmpty ||
        p.pocketRecordId == null ||
        p.recordIdForBackend.startsWith('virt-') ||
        p.recordIdForBackend.startsWith('optimistic-');
    String resolve(String id) {
      if (!persistedIds.contains(id)) {
        throw StateError('План больше не найден в выбранном дне.');
      }
      return id;
    }
    final forcedAfterIds = <String>{};
    int? swapFirstIndex;
    int? swapLastIndex;
    DateTime? swapAnchorStart;
    for (final action in edits) {
      final a = action.arguments;
      if (action.name == 'swap_plan_positions') {
        if (swapFirstIndex != null || edits.length != 1) {
          throw StateError('Обмен двух планов должен быть отдельной операцией.');
        }
        final leftId = resolve(a['first_plan_id'] as String);
        final rightId = resolve(a['second_plan_id'] as String);
        final left = ordered.indexWhere((p) => p.pocketRecordId == leftId);
        final right = ordered.indexWhere((p) => p.pocketRecordId == rightId);
        if (left == right || left < 0 || right < 0) {
          throw StateError('Две разные карточки не найдены.');
        }
        if (immutable(ordered[left]) || immutable(ordered[right]) ||
            fixedTime(ordered[left]) || fixedTime(ordered[right])) {
          throw StateError('Закреплённую или повторяющуюся задачу нельзя обменять.');
        }
        swapFirstIndex = left < right ? left : right;
        swapLastIndex = left > right ? left : right;
        swapAnchorStart = ordered[swapFirstIndex].startTime!;
        final previous = ordered[left];
        ordered[left] = ordered[right];
        ordered[right] = previous;
        continue;
      }
      final id = resolve(a['plan_id'] as String);
      var i = ordered.indexWhere((p) => p.pocketRecordId == id);
      final current = ordered[i];
      if (immutable(current)) {
        throw StateError('Повторяющиеся и несохранённые планы нельзя менять напрямую.');
      }
      if (action.name == 'update_plan_duration') {
        final oldDuration = current.endDateTime!
            .difference(current.startTime!).inMinutes;
        if (oldDuration != a['expected_duration_minutes']) {
          throw StateError('Длительность изменилась, нужно повторить запрос.');
        }
        if (fixedTime(current)) {
          throw StateError('Фиксированная задача не может менять длительность автоматически.');
        }
        ordered[i] = current.copyWith(
          endDateTime: current.startTime!.add(
            Duration(minutes: a['duration_minutes'] as int)),
        );
      } else {
        final anchorId = resolve(a['after_plan_id'] as String);
        if (id == anchorId) {
          throw StateError('Задача не может следовать сама за собой.');
        }
        if (fixedTime(current)) {
          throw StateError('Нельзя передвинуть закреплённое время.');
        }
        ordered.removeAt(i);
        final anchorIndex = ordered.indexWhere(
            (p) => p.pocketRecordId == anchorId);
        if (anchorIndex < 0) throw StateError('Опорный план не найден.');
        i = anchorIndex + 1;
        ordered.insert(i, current);
        forcedAfterIds.add(id);
      }
    }
    final updated = <PlanningTask>[];
    DateTime? cursor;
    for (var index = 0; index < ordered.length; index++) {
      final p = ordered[index];
      final duration = p.endDateTime!.difference(p.startTime!).inMinutes;
      if (duration < 10 || duration > 1440) {
        throw StateError('Некорректная длительность плана.');
      }
      var start = p.startTime!;
      // A swap exchanges ordinal positions, NOT just the two start times.
      // Reflow the affected segment from the earlier card's original start.
      if (swapFirstIndex == index) {
        start = swapAnchorStart!;
      } else if (swapFirstIndex != null &&
          index > swapFirstIndex && index <= swapLastIndex!) {
        start = cursor!;
      } else if (cursor != null &&
          (start.isBefore(cursor) || forcedAfterIds.contains(p.pocketRecordId))) {
        start = cursor;
      }
      if (start != p.startTime && (fixedTime(p) || immutable(p))) {
        throw StateError('Пересчёт затрагивает закреплённый или повторяющийся план.');
      }
      final end = start.add(Duration(minutes: duration));
      if (start.year != day.year || start.month != day.month ||
          start.day != day.day || end.year != day.year ||
          end.month != day.month || end.day != day.day) {
        throw StateError('Расписание выходит за границы выбранного дня.');
      }
      updated.add(p.copyWith(startTime: start, endDateTime: end));
      cursor = end;
    }
    final byId = {for (final p in updated) p.recordIdForBackend: p};
    final result = [
      for (final original in plans)
        byId[original.recordIdForBackend] ?? original,
    ];
    final preview = ViktorSchedulePreview(before: plans, after: result);
    if (preview.changed.isEmpty) {
      throw StateError('Изменений времени не обнаружено.');
    }
    return preview;
  }
}

class ViktorBulkMove {
  const ViktorBulkMove(this.plan, this.start, this.end, this.day, this.kind);
  final PlanningTask plan;
  final DateTime start;
  final DateTime end;
  final String day;
  final String kind;
}

/// Status-based schedule changes resolved from actual Brain rows, not IDs
/// guessed by a model. Both days must be previewed before writing.
class ViktorBulkPreview {
  const ViktorBulkPreview(this.moves, this.signature);
  final List<ViktorBulkMove> moves;
  final String signature;

  String describe() {
    String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return [
      'Проверка массового изменения (${moves.length} планов):',
      for (final m in moves)
        '${m.kind == 'move' ? 'Перенести' : 'Уплотнить'} «${m.plan.title}»: '
        '${m.plan.dateKey} ${hm(m.plan.startTime!)} → '
        '${m.day} ${hm(m.start)}–${hm(m.end)}',
      'Изменения будут применены после подтверждения.',
    ].join('\n');
  }
}

class ViktorBulkPlanner {
  const ViktorBulkPlanner();
  static String key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

  static List<PlanningTask> sorted(Iterable<PlanningTask> tasks) =>
    tasks.toList()..sort((a, b) {
      final at = a.startTime ?? DateTime(2099);
      final bt = b.startTime ?? DateTime(2099);
      final c = at.compareTo(bt);
      return c != 0 ? c : a.order.compareTo(b.order);
    });

  static String snapshot(List<PlanningTask> source, List<PlanningTask> target) {
    final rows = [
      for (final p in [...source, ...target])
        '${p.recordIdForBackend}|${p.dateKey}|${p.isDone}|'
        '${p.startTime?.toIso8601String()}|${p.endDateTime?.toIso8601String()}|'
        '${p.rrule}|${p.recurrenceInstanceDateKey}|${p.updatedAt?.toIso8601String()}',
    ]..sort();
    return rows.join('\n');
  }

  ViktorBulkPreview calculate({
    required ViktorAction action,
    required List<PlanningTask> source,
    required List<PlanningTask> target,
    required String sourceDay,
    required String? targetDay,
    required DateTime Function(String, String, String) wallTime,
    required bool Function(PlanningTask) fixedTime,
  }) {
    final ops = action.arguments['operations'] as List;
    if (source.length + target.length > 160) {
      throw StateError('Слишком много планов для безопасного пересчёта.');
    }
    final used = <String>{};
    final moves = <ViktorBulkMove>[];
    void guard(PlanningTask p) {
      if (p.pocketRecordId == null || !p.isSynced ||
          p.recordIdForBackend.startsWith('virt-') ||
          p.recordIdForBackend.startsWith('optimistic-') ||
          (p.rrule ?? '').isNotEmpty ||
          (p.recurrenceInstanceDateKey ?? '').isNotEmpty) {
        throw StateError('«${p.title}»: повторяющийся или несохранённый план.');
      }
      if (fixedTime(p)) {
        throw StateError('«${p.title}»: закреплённое время нельзя сдвигать.');
      }
      if (p.startTime == null || p.endDateTime == null ||
          p.endDateTime!.difference(p.startTime!).inMinutes < 10) {
        throw StateError('«${p.title}»: неизвестна длительность.');
      }
      if (!used.add(p.pocketRecordId!)) {
        throw StateError('План попал в несколько пересекающихся фильтров.');
      }
    }

    // Moving incomplete plans first makes them disappear from today's
    // collision set before completed plans are compacted.
    for (final kind in const ['move', 'compact']) {
      for (final raw in ops) {
        final op = Map<String, dynamic>.from(raw as Map);
        if (op['kind'] != kind) continue;
        if (op['source_day'] != sourceDay) {
          throw StateError('Источник должен совпадать с выбранным днём.');
        }
        final status = op['status'] as String;
        final chosen = sorted(source.where((p) =>
          status == 'all' ||
          (status == 'complete' && p.isDone) ||
          (status == 'incomplete' && !p.isDone)));
        if (chosen.isEmpty) continue;
        final move = kind == 'move';
        final date = move ? op['target_day'] as String : sourceDay;
        if (move && date != targetDay) {
          throw StateError('Несколько целевых дней: разделите запрос.');
        }
        final hhmm = op['start_time'] as String?;
        final zone = (op['timezone'] as String?) ?? 'profile';
        var cursor = hhmm != null
          ? wallTime(date, hhmm, zone) : chosen.first.startTime!;
        for (final p in chosen) {
          guard(p);
          final end = cursor.add(p.endDateTime!.difference(p.startTime!));
          if (key(cursor) != date || key(end) != date) {
            throw StateError('«${p.title}»: время выходит за границы ${date}.');
          }
          moves.add(ViktorBulkMove(p, cursor, end, date, kind));
          cursor = end;
        }
      }
    }
    if (moves.isEmpty) {
      throw StateError('Нет подходящих планов.');
    }
    final changed = moves.map((m) => m.plan.pocketRecordId).toSet();
    final intervals = <({String day, DateTime start, DateTime end, String title, bool changed})>[
      for (final p in [...source, ...target])
        if (!changed.contains(p.pocketRecordId) &&
            p.startTime != null && p.endDateTime != null)
          (day: key(p.startTime!), start: p.startTime!,
           end: p.endDateTime!, title: p.title, changed: false),
      for (final m in moves)
        (day: m.day, start: m.start, end: m.end,
         title: m.plan.title, changed: true),
    ];
    for (var i = 0; i < intervals.length; i++) {
      for (var j = i + 1; j < intervals.length; j++) {
        final a = intervals[i], b = intervals[j];
        if (!(a.changed || b.changed)) continue;
        if (a.day == b.day && a.start.isBefore(b.end) &&
            a.end.isAfter(b.start)) {
          throw StateError('Конфликт: «${a.title}» и «${b.title}». '
            'Никаких изменений не внесено.');
        }
      }
    }
    return ViktorBulkPreview(moves, snapshot(source, target));
  }
}
