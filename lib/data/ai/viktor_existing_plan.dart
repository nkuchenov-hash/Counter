import 'package:counter/data/models.dart';

/// Conservative idempotency check on the requested *profile-wall* date.
/// It never treats a loosely related title or an unrelated date as a match.
class ViktorExistingPlan {
  static String normalize(String title) {
    final words = title.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+', caseSensitive: false), ' ')
        .trim().split(RegExp(r'\s+'))
        .where((x) => x.isNotEmpty && !const <String>{
          'call', 'meeting', 'созвон', 'звонок', 'встреча',
        }.contains(x)).toList();
    return words.join(' ');
  }

  static PlanningTask? find({
    required String title,
    required DateTime start,
    required Iterable<PlanningTask> plans,
  }) {
    final target = normalize(title);
    if (target.isEmpty) return null;
    for (final plan in plans) {
      if (plan.startTime == null) continue;
      final wall = plan.startTime!;
      if (wall.year != start.year || wall.month != start.month ||
          wall.day != start.day) continue;
      if (normalize(plan.title) == target) return plan;
    }
    return null;
  }

  static String describe(PlanningTask plan) {
    final start = plan.startTime!;
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return 'План «${plan.title}» уже существует на '
        '${start.year}-${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}, ${clock(start)}'
        '${plan.endDateTime == null ? '' : '–${clock(plan.endDateTime!)}'}. '
        'Повторное создание не требуется.';
  }
}
