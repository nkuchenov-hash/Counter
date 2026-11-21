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
      DatabaseService db, ViktorAction action,
      {DateTime? profileNow}) async {
    final inputs = (action.arguments['plans'] as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList(growable: false);
    final existing = <String, List<PlanningTask>>{};
    final proposed = <({DateTime start, DateTime end, String title})>[];
    final rows = <Map<String, Object?>>[];
    final now = profileNow ?? db.applyUserOffset(DateTime.now().toUtc());
    final nowDay = ViktorDateScope.key(now);
    final lines = <String>[
      'Создать ${inputs.length} планов одной атомарной операцией:',
    ];
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    for (final input in inputs) {
      final title = input['title'] as String;
      final day = input['wall_day'] as String;
      final date = ViktorDateScope.parseDay(day);
      if (!existing.containsKey(day)) {
        existing[day] = await db.getPlanningTasksForWallDate(date);
      }
      final saved = existing[day]!;
      final explicit = input.containsKey('start_time');
      final fills = input['fill_remaining'] == true;
      late DateTime start;
      if (explicit) {
        start = viktorPlanStartInProfileWall(
          wallDay: day,
          startTime: input['start_time'] as String,
          timezone: input['timezone'] as String?,
          profileTimezone: db.settings.preferredTimeZone,
          toProfileWall: db.applyUserOffset,
        );
      } else {
        if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          throw StateError('«$title»: нельзя автоматически назначить '
              'время в прошедший день.');
        }
        start = DateTime(date.year, date.month, date.day, 9);
        if (day == nowDay) {
          final firstMinute = now.hour * 60 + now.minute + 11;
          final rounded = ((firstMinute + 4) ~/ 5) * 5;
          final earliest = DateTime(date.year, date.month, date.day)
              .add(Duration(minutes: rounded));
          if (start.isBefore(earliest)) start = earliest;
        }
        for (final prior in proposed) {
          if (ViktorDateScope.key(prior.start) == day &&
              start.isBefore(prior.end)) start = prior.end;
        }
      }
      final occupied = <({DateTime start, DateTime end})>[
        for (final current in saved)
          if (current.startTime != null && current.endDateTime != null)
            (start: current.startTime!, end: current.endDateTime!),
        for (final prior in proposed)
          if (ViktorDateScope.key(prior.start) == day)
            (start: prior.start, end: prior.end),
      ]..sort((a, b) => a.start.compareTo(b.start));
      // Auto mode is ordered first-fit: it does NOT move saved appointments.
      // Explicit user clock remains strict, and fails on any overlap.
      if (!explicit) {
        final duration = Duration(
            minutes: (input['duration_minutes'] as int?) ?? 10);
        for (final busy in occupied) {
          if (start.isBefore(busy.end) &&
              start.add(duration).isAfter(busy.start)) {
            start = busy.end;
          }
        }
      }
      late DateTime end;
      if (fills) {
        // "Remaining time" means the remainder of the current contiguous
        // FREE interval, up to the next commitment or 23:59. No guesses
        // about any saved work-plan's length or movement.
        end = DateTime(date.year, date.month, date.day, 23, 59);
        for (final busy in occupied) {
          if (busy.start.isAfter(start) && busy.start.isBefore(end)) {
            end = busy.start;
          }
        }
        if (end.difference(start).inMinutes < 10) {
          throw StateError('«$title»: осталось меньше 10 свободных минут.');
        }
      } else {
        end = start.add(Duration(
            minutes: input['duration_minutes'] as int));
      }
      if (ViktorDateScope.key(start) != day ||
          ViktorDateScope.key(end) != day) {
        throw StateError('«$title»: время выходит за пределы $day '
            'по часовому поясу профиля.');
      }
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
      CategoryRule resolve() {
        final requestedId = input['category_id'] as String?;
        if (requestedId != null) {
          final selected = db.getCategoryRuleByBackendRowId(requestedId);
          if (selected == null || selected.isArchived) {
            throw StateError('«$title»: выбранная категория не найдена.');
          }
          return selected;
        }
        return resolveViktorPlanCategory(
        title: title,
        identifyCategory: db.identifyCategory,
        categoryById: db.getCategoryRuleById,
        defaultCategoryId: db.defaultCategoryId,
        rootCategories: db.rules,
      );
      }
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
        if (input['note'] != null) 'notes_plain': input['note'],
        'start_time': db.viktorProfileWallToUtc(start).toIso8601String(),
        'end_time': db.viktorProfileWallToUtc(end).toIso8601String(),
        'initial_date_key': day,
      });
      lines.add('$day ${clock(start)}–${clock(end)}  $title');
      lines.add('  Категория: ${db.getCategoryPath(category.id)}'
          '${input['note'] == null ? '' : '; заметка: ${input['note']}'}');
    }
    lines.add('Все изменения будут применены только после подтверждения.');
    return ViktorMultiPlanProposal(lines.join('\n'), rows);
  }
}
