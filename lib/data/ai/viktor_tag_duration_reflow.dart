import 'package:counter/data/models.dart';
import 'viktor_schedule_planner.dart';

/// Resolve flexible plan durations around immovable calendar reservations.
///
/// The ordinary AI edit planner must stay conservative for arbitrary moves.
/// This specialised, explicit two-day tag-duration command treats completed,
/// recurring, unsynced, and category-fixed plans as obstacles. No obstacle
/// is patched; only eligible owned rows enter the atomic commit preview.
class ViktorTagDurationReflow {
  const ViktorTagDurationReflow();

  static bool _protected(
    PlanningTask plan, bool Function(PlanningTask) fixedTime,
  ) =>
      plan.isDone ||
      !plan.isSynced ||
      plan.pocketRecordId == null ||
      (plan.rrule ?? '').trim().isNotEmpty ||
      (plan.recurrenceInstanceDateKey ?? '').trim().isNotEmpty ||
      plan.recordIdForBackend.startsWith('virt-') ||
      plan.recordIdForBackend.startsWith('optimistic-') ||
      fixedTime(plan);

  static bool _overlap(
    DateTime start, DateTime end, PlanningTask protected,
  ) =>
      start.isBefore(protected.endDateTime!) &&
      end.isAfter(protected.startTime!);

  List<ViktorBulkMove> calculate({
    required DateTime day,
    required List<PlanningTask> plans,
    required Map<String, int> targetDurationMinutes,
    required bool Function(PlanningTask) fixedTime,
  }) {
    final timed = plans.where((p) =>
      p.startTime != null && p.endDateTime != null).toList()
      ..sort((a,b) {
        final comparison = a.startTime!.compareTo(b.startTime!);
        return comparison != 0 ? comparison : a.order.compareTo(b.order);
      });
    if (timed.length > 100) {
      throw StateError('Более 100 планов за день. Безопасный пересчёт '
          'нужно выполнить отдельными периодами.');
    }
    final uniqueIds = <String>{};
    for (final plan in timed) {
      if (!uniqueIds.add(plan.recordIdForBackend)) {
        throw StateError('Дубли планов в расписании. Изменения отменены.');
      }
    }

    final obstacles = timed.where((p) => _protected(p, fixedTime)).toList()
      ..sort((a,b) => a.startTime!.compareTo(b.startTime!));
    final moves = <ViktorBulkMove>[];
    DateTime? cursor;
    for (final plan in timed) {
      if (_protected(plan, fixedTime)) continue;
      final originalStart = plan.startTime!;
      final originalEnd = plan.endDateTime!;
      final oldMinutes = originalEnd.difference(originalStart).inMinutes;
      final minutes = targetDurationMinutes[plan.pocketRecordId] ?? oldMinutes;
      if (minutes < 10 || minutes > 1440) {
        throw StateError('Некорректная длительность «${plan.title}». '
            'Изменения не применены.');
      }

      var candidate = originalStart;
      if (cursor != null && candidate.isBefore(cursor)) candidate = cursor;
      // Obstacles have absolute intervals, not ordinal positions. A fixed
      // meeting in the middle of a resized task moves that FLEXIBLE task to
      // the next available interval; the fixed meeting does not move.
      for (final obstacle in obstacles) {
        final end = candidate.add(Duration(minutes: minutes));
        if (_overlap(candidate, end, obstacle)) {
          candidate = obstacle.endDateTime!;
        }
      }
      final end = candidate.add(Duration(minutes: minutes));
      if (candidate.year != day.year ||
          candidate.month != day.month || candidate.day != day.day ||
          end.year != day.year || end.month != day.month ||
          end.day != day.day) {
        throw StateError('Недостаточно места ${day.day}.${day.month} '
            'для плана «${plan.title}» (${minutes} мин): '
            'нельзя сдвигать закреплённые или повторяющиеся события. '
            'Ничего не сохранено.');
      }
      if (candidate != originalStart || end != originalEnd) {
        moves.add(ViktorBulkMove(
          plan, candidate, end, ViktorBulkPlanner.key(day), 'compact',
        ));
      }
      cursor = end;
    }
    return moves;
  }
}
