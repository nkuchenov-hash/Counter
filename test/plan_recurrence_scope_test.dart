import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:flutter_test/flutter_test.dart';

const _seriesPb = 'abcdefghijklmno';
const _dayKey = '2026-06-23';

PlanningTask _virtOccurrence() {
  final start = DateTime(2026, 6, 23, 9, 0);
  return PlanningTask(
    id: 0,
    title: 'Daily standup',
    categoryId: 1,
    isDone: false,
    dateKey: _dayKey,
    order: 0,
    startTime: start,
    endDateTime: start.add(const Duration(minutes: 30)),
    planRowId: 'virt-$_seriesPb-$_dayKey',
    recurrenceInstanceDateKey: _dayKey,
  );
}

PlanningTask _materialized({
  required String instDay,
  String pocketId = 'mat012345678901',
}) {
  final start = DateTime(2026, 6, 23, 9, 0);
  return PlanningTask(
    id: 0,
    title: 'Daily standup (edited)',
    categoryId: 1,
    isDone: false,
    dateKey: instDay,
    order: 0,
    startTime: start,
    endDateTime: start.add(const Duration(minutes: 30)),
    planRowId: 'biz-mat-1',
    pocketRecordId: pocketId,
    parentPlanPocketId: _seriesPb,
    recurrenceInstanceDateKey: instDay,
  );
}

void main() {
  group('expandRecurringPlans dedupe guard', () {
    test('repeated virt rows collapse to one visible card', () {
      final virt = _virtOccurrence();
      final out = DatabaseService.instance.dedupePlanningTasksForDisplay(
        [virt, virt, virt],
        traceSource: 'test',
      );
      expect(out.length, 1);
      expect(out.single.planRowIdForBackend, 'virt-$_seriesPb-$_dayKey');
    });

    test('materialized occurrence suppresses matching virtual occurrence', () {
      final out = DatabaseService.instance.dedupePlanningTasksForDisplay(
        [_virtOccurrence(), _materialized(instDay: _dayKey)],
        traceSource: 'test',
      );
      expect(out.length, 1);
      expect(out.single.parentPlanPocketId, _seriesPb);
      expect(out.single.recurrenceInstanceDateKey, _dayKey);
    });
  });

  group('recurrence scope model', () {
    test('only occurrence and this/future are user-supported', () {
      expect(
        recurrenceEditScopeIsSupported(RecurrenceEditScope.singleOccurrence),
        isTrue,
      );
      expect(
        recurrenceEditScopeIsSupported(RecurrenceEditScope.thisAndFuture),
        isTrue,
      );
      expect(
        recurrenceEditScopeIsSupported(RecurrenceEditScope.entireSeries),
        isFalse,
      );
      expect(
        canonicalRecurrenceEditScope(RecurrenceEditScope.entireSeries),
        RecurrenceEditScope.thisAndFuture,
      );
    });
  });

  group('recurrence split RRULE helpers', () {
    test('historical rule ends immediately before split boundary', () {
      final out = recurrenceRruleEndingBefore(
        'FREQ=WEEKLY;BYDAY=MO;COUNT=20',
        DateTime.utc(2026, 9, 28),
      );
      expect(out, contains('FREQ=WEEKLY'));
      expect(out, contains('BYDAY=MO'));
      expect(out, contains('UNTIL=20260927T235959Z'));
      expect(out, isNot(contains('COUNT=')));
    });

    test('COUNT is reduced only by already consumed occurrences', () {
      expect(
        recurrenceRruleWithRemainingCount('FREQ=DAILY;COUNT=10', 3),
        'FREQ=DAILY;COUNT=7',
      );
      expect(
        recurrenceRruleWithRemainingCount('FREQ=DAILY;COUNT=3', 3),
        isNull,
      );
      expect(
        recurrenceRruleWithRemainingCount('FREQ=DAILY', 500),
        'FREQ=DAILY',
      );
    });
  });

  group('planningTaskIsRecurringForScope', () {
    test('detects virtual, materialized, and series rows', () {
      expect(
        DatabaseService.instance.planningTaskIsRecurringForScope(
          _virtOccurrence(),
        ),
        isTrue,
      );
      expect(
        DatabaseService.instance.planningTaskIsRecurringForScope(
          _materialized(instDay: _dayKey),
        ),
        isTrue,
      );
      expect(
        DatabaseService.instance.planningTaskIsRecurringForScope(
          PlanningTask(
            id: 0,
            title: 'Series',
            categoryId: 1,
            isDone: false,
            dateKey: _dayKey,
            order: 0,
            planRowId: 'biz-series',
            pocketRecordId: _seriesPb,
            rrule: 'FREQ=DAILY',
          ),
        ),
        isTrue,
      );
    });

    test('detects legacy materialized rows through their recurring parent', () {
      final db = DatabaseService.instance;
      db.applyOptimisticPlanningTask(
        PlanningTask(
          id: 0,
          title: 'Series parent',
          categoryId: 1,
          isDone: false,
          dateKey: _dayKey,
          order: 0,
          startTime: DateTime(2026, 6, 23, 9),
          planRowId: 'biz-series-parent-fallback',
          pocketRecordId: _seriesPb,
          rrule: 'FREQ=DAILY',
        ),
      );

      final legacyMaterialized = PlanningTask(
        id: 0,
        title: 'Occurrence renamed by an older client',
        categoryId: 1,
        isDone: false,
        dateKey: _dayKey,
        order: 0,
        startTime: DateTime(2026, 6, 23, 9),
        planRowId: 'biz-legacy-occurrence',
        pocketRecordId: 'legacyoccurr0001',
        parentPlanPocketId: _seriesPb,
      );

      expect(
        db.planningTaskIsRecurringForScope(legacyMaterialized),
        isTrue,
      );
    });
  });

  group('virtual id guards', () {
    test('virt ids must not be treated as business UUID merge keys', () {
      final virt = _virtOccurrence();
      expect(virt.planRowIdForBackend.startsWith('virt-'), isTrue);
      final key = DatabaseService.instance.planningStableIdentityKey(virt);
      expect(key, 'virt-$_seriesPb-$_dayKey');
    });
  });
}
