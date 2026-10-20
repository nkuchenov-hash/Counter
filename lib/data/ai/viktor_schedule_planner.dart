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

  ViktorSchedulePreview calculate({
    required DateTime day,
    required List<PlanningTask> plans,
    required List<ViktorAction> actions,
    required bool Function(PlanningTask plan) fixedTime,
  }) {
    final edits = actions.where((a) =>
        a.name == 'update_plan_duration' ||
        a.name == 'move_plan_after').toList(growable: false);
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
    for (final action in edits) {
      final a = action.arguments;
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
    for (final p in ordered) {
      final duration = p.endDateTime!.difference(p.startTime!).inMinutes;
      if (duration < 10 || duration > 1440) {
        throw StateError('Некорректная длительность плана.');
      }
      var start = p.startTime!;
      if (cursor != null &&
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
