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
    test('thisAndFuture is not supported yet', () {
      expect(
        recurrenceEditScopeIsSupported(RecurrenceEditScope.thisAndFuture),
        isFalse,
      );
      expect(
        recurrenceEditScopeIsSupported(RecurrenceEditScope.singleOccurrence),
        isTrue,
      );
      expect(
        recurrenceEditScopeIsSupported(RecurrenceEditScope.entireSeries),
        isTrue,
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
