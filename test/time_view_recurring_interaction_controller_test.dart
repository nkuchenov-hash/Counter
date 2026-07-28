import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/features/planning/time_view/time_view_recurring_interaction_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parentPocketId = 'abcdefghijklxyz';
  const day = '2026-07-28';

  PlanningTask task({
    required String planRowId,
    String? pocketRecordId,
    String? rrule,
    String? recurrenceInstanceDateKey,
    String? parentPlanPocketId,
  }) {
    return PlanningTask(
      id: 0,
      planRowId: planRowId,
      pocketRecordId: pocketRecordId,
      title: 'Recurring plan',
      categoryId: 1,
      dateKey: day,
      startTime: DateTime(2026, 7, 28, 9),
      endDateTime: DateTime(2026, 7, 28, 10),
      rrule: rrule,
      recurrenceInstanceDateKey: recurrenceInstanceDateKey,
      parentPlanPocketId: parentPlanPocketId,
    );
  }

  test('single scope converts stored series occurrence to virtual mutation id', () {
    final series = task(
      planRowId: 'business-series-id',
      pocketRecordId: parentPocketId,
      rrule: 'FREQ=DAILY',
    );

    expect(
      timeViewRecurringMutationRowId(
        task: series,
        scope: RecurrenceEditScope.singleOccurrence,
        instanceDateKey: day,
      ),
      'virt-$parentPocketId-$day',
    );
  });

  test('single scope keeps virtual and materialized occurrence identities', () {
    final virtual = task(
      planRowId: 'virt-$parentPocketId-$day',
      pocketRecordId: parentPocketId,
      recurrenceInstanceDateKey: day,
    );
    final materialized = task(
      planRowId: 'materialized-business-id',
      pocketRecordId: 'materializedrow',
      recurrenceInstanceDateKey: day,
      parentPlanPocketId: parentPocketId,
    );

    expect(
      timeViewRecurringMutationRowId(
        task: virtual,
        scope: RecurrenceEditScope.singleOccurrence,
        instanceDateKey: day,
      ),
      'virt-$parentPocketId-$day',
    );
    expect(
      timeViewRecurringMutationRowId(
        task: materialized,
        scope: RecurrenceEditScope.singleOccurrence,
        instanceDateKey: day,
      ),
      'materializedrow',
    );
  });

  test('entire series scope keeps the original recurrence identity', () {
    final virtual = task(
      planRowId: 'virt-$parentPocketId-$day',
      pocketRecordId: parentPocketId,
      recurrenceInstanceDateKey: day,
    );

    expect(
      timeViewRecurringMutationRowId(
        task: virtual,
        scope: RecurrenceEditScope.entireSeries,
        instanceDateKey: day,
      ),
      'virt-$parentPocketId-$day',
    );
  });
}
