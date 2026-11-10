import 'package:counter/data/models.dart';
import 'viktor_schedule_planner.dart';

/// Resolve a follow-up to an already discussed duration overflow.
/// A question mentioning "partial" is NOT consent to apply anything.
abstract final class ViktorDurationConversation {
  static bool wantsFeasibleSubset(String input, {required bool pending}) {
    if (!pending) return false;
    return RegExp(
      r'^(?:покажи|примени|сделай|давай|пересчитай|'
      r'используй|show|apply|try).{0,90}'
      r'(?:частичн|subset|what fits)',
      caseSensitive: false,
    ).hasMatch(input.trim());
  }
}

/// An explicit scheduling conflict, not a provider or database failure.
/// Consumers can offer a feasible subset without changing protected events.
class ViktorTagDurationOverflow implements Exception {
  const ViktorTagDurationOverflow({
    required this.day,
    required this.plan,
    required this.minutes,
  });
  final DateTime day;
  final PlanningTask plan;
  final int minutes;

  @override
  String toString() => 'Недостаточно места '
      '${day.day}.${day.month} для плана «${plan.title}» '
      '(${minutes} мин). Закреплённые и повторяющиеся '
      'события остаются на месте. Ничего не сохранено.';
}

class ViktorTagDurationSubset {
  const ViktorTagDurationSubset(this.moves, this.excludedPlans);
  final List<ViktorBulkMove> moves;
  final List<String> excludedPlans;
}

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
        throw ViktorTagDurationOverflow(
          day: day, plan: plan, minutes: minutes,
        );
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

  /// Recompute a genuine alternative: revert only conflicting duration
  /// requests until all remaining requested changes fit the day. Every
  /// iteration uses the exact same protected barriers and standard preview.
  /// No writes occur here; the user must still approve atomic commit.
  ViktorTagDurationSubset calculateFeasibleSubset({
    required DateTime day,
    required List<PlanningTask> plans,
    required Map<String, int> targetDurationMinutes,
    required bool Function(PlanningTask) fixedTime,
  }) {
    final remaining = Map<String, int>.from(targetDurationMinutes);
    final excluded = <String>[];
    final positions = <String, int>{
      for (var i = 0; i < plans.length; i++)
        if (plans[i].pocketRecordId != null) plans[i].pocketRecordId!: i,
    };
    while (remaining.isNotEmpty) {
      try {
        return ViktorTagDurationSubset(
          calculate(
            day: day, plans: plans,
            targetDurationMinutes: remaining, fixedTime: fixedTime,
          ),
          List<String>.unmodifiable(excluded),
        );
      } on ViktorTagDurationOverflow catch (conflict) {
        final failingIndex = positions[conflict.plan.pocketRecordId] ??
            plans.length;
        final original = <String, PlanningTask>{
          for (final plan in plans)
            if (plan.pocketRecordId != null) plan.pocketRecordId!: plan,
        };
        final candidates = remaining.keys.where((id) {
          final source = original[id];
          if (source == null ||
              (positions[id] ?? plans.length) > failingIndex) {
            return false;
          }
          final currentMinutes = source.endDateTime!
              .difference(source.startTime!).inMinutes;
          // Removing a requested reduction would consume MORE time;
          // it cannot resolve an over-capacity day.
          return remaining[id]! > currentMinutes;
        }).toList();
        // Roll back the nearest preceding requested expansion, rather
        // than silently reducing a meeting or changing a recurring series.
        if (candidates.isEmpty) rethrow;
        candidates.sort((a, b) =>
            (positions[b] ?? 0).compareTo(positions[a] ?? 0));
        final removedId = candidates.first;
        remaining.remove(removedId);
        final old = plans.firstWhere((p) => p.pocketRecordId == removedId);
        excluded.add(old.title);
      }
    }
    return ViktorTagDurationSubset(const [], List.unmodifiable(excluded));
  }
}
