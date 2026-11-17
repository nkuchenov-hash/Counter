import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';

import 'viktor_action_contract.dart';
import 'viktor_date_scope.dart';
import 'viktor_existing_plan.dart';
import 'viktor_plan_category.dart';
import 'viktor_plan_timezone.dart';

/// Reviewed atomic batch proposal: verified against saved rows, with no
/// network mutation until a fresh re-check and server transaction.
class ViktorMultiPlanProposal {
  const ViktorMultiPlanProposal(this.description, this.rows);
  final String description;
  final List<Map<String, Object?>> rows;

  static Future<ViktorMultiPlanProposal> prepare(
      DatabaseService db, ViktorAction action) async {
    final inputs = (action.arguments['plans'] as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList(growable: false);
    final existing = <String, List<PlanningTask>>{};
    final proposed = <({DateTime start, DateTime end, String title})>[];
    final rows = <Map<String, Object?>>[];
    final lines = <String>[
      'Создать ${inputs.length} планов одной атомарной операцией:',
    ];
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    for (final input in inputs) {
      final title = input['title'] as String;
      final day = input['wall_day'] as String;
      final start = viktorPlanStartInProfileWall(
        wallDay: day,
        startTime: input['start_time'] as String,
        timezone: input['timezone'] as String?,
        profileTimezone: db.settings.preferredTimeZone,
        toProfileWall: db.applyUserOffset,
      );
      final end = start.add(Duration(
          minutes: input['duration_minutes'] as int));
      if (ViktorDateScope.key(start) != day ||
          ViktorDateScope.key(end) != day) {
        throw StateError('«$title»: время выходит за пределы $day '
            'по часовому поясу профиля.');
      }
      if (!existing.containsKey(day)) {
        existing[day] = await db.getPlanningTasksForWallDate(
            ViktorDateScope.parseDay(day));
      }
      final saved = existing[day]!;
      if (ViktorExistingPlan.find(
              title: title, start: start, plans: saved) != null) {
        throw StateError('План «$title» уже существует на $day. '
            'Повторно создавать его нельзя.');
      }
      for (final current in saved) {
        if (current.startTime != null && current.endDateTime != null &&
            start.isBefore(current.endDateTime!) &&
            end.isAfter(current.startTime!)) {
          throw StateError('«$title» пересекается с существующим планом '
              '«${current.title}».');
        }
      }
      for (final earlier in proposed) {
        if (start.isBefore(earlier.end) && end.isAfter(earlier.start)) {
          throw StateError('«$title» пересекается с новым планом '
              '«${earlier.title}».');
        }
      }
      CategoryRule category;
      CategoryRule resolve() => resolveViktorPlanCategory(
        title: title,
        identifyCategory: db.identifyCategory,
        categoryById: db.getCategoryRuleById,
        defaultCategoryId: db.defaultCategoryId,
        rootCategories: db.rules,
      );
      try {
        category = resolve();
      } on StateError {
        await db.refreshCategoryRulesFromServer();
        category = resolve();
      }
      final categoryId = (category.backendRowId ?? '').trim();
      if (!RegExp(r'^[a-zA-Z0-9]{15}$').hasMatch(categoryId)) {
        throw StateError('«$title»: категория не синхронизирована. '
            'Групповое создание не выполнено.');
      }
      proposed.add((start: start, end: end, title: title));
      rows.add({
        'title': title,
        'category_id': categoryId,
        'start_time': db.viktorProfileWallToUtc(start).toIso8601String(),
        'end_time': db.viktorProfileWallToUtc(end).toIso8601String(),
        'initial_date_key': day,
      });
      lines.add('$day ${clock(start)}–${clock(end)}  $title');
    }
    lines.add('Все изменения будут применены только после подтверждения.');
    return ViktorMultiPlanProposal(lines.join('\n'), rows);
  }
}
