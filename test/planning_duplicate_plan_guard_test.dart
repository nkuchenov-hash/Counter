import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:flutter_test/flutter_test.dart';

const _dayKey = '2026-06-23';

PlanningTask _plan({
  required String planRowId,
  String? pocketRecordId,
  required int startH,
  required int startM,
  required int endH,
  required int endM,
  int order = 0,
  String? recurrenceInstanceDateKey,
}) {
  final start = DateTime(2026, 6, 23, startH, startM);
  final end = DateTime(2026, 6, 23, endH, endM);
  return PlanningTask(
    id: 0,
    title: 'Price Reporter Email check',
    categoryId: 1,
    isDone: false,
    dateKey: _dayKey,
    order: order,
    startTime: start,
    endDateTime: end,
    planRowId: planRowId,
    pocketRecordId: pocketRecordId,
    recurrenceInstanceDateKey: recurrenceInstanceDateKey,
  );
}

void main() {
  group('dedupePlanningTasksForDisplay', () {
    test('same PocketBase id collapses to one row', () {
      final a = _plan(
        planRowId: 'biz-uuid-1',
        pocketRecordId: 'abcdefghijklmno',
        startH: 0,
        startM: 10,
        endH: 0,
        endM: 40,
      );
      final b = _plan(
        planRowId: 'biz-uuid-1',
        pocketRecordId: 'abcdefghijklmno',
        startH: 0,
        startM: 10,
        endH: 0,
        endM: 40,
        order: 1,
      );
      final out = DatabaseService.instance.dedupePlanningTasksForDisplay(
        [a, b],
      );
      expect(out.length, 1);
      expect(out.first.pocketRecordId, 'abcdefghijklmno');
    });

    test('optimistic + confirmed same business plan_id collapses to one', () {
      final optimistic = _plan(
        planRowId: 'optimistic-biz-uuid-2',
        pocketRecordId: 'optimistic-biz-uuid-2',
        startH: 0,
        startM: 10,
        endH: 0,
        endM: 40,
      );
      final confirmed = _plan(
        planRowId: 'biz-uuid-2',
        pocketRecordId: 'pqrstuvwxyzabcd',
        startH: 0,
        startM: 10,
        endH: 0,
        endM: 40,
      );
      final out = DatabaseService.instance.dedupePlanningTasksForDisplay(
        [optimistic, confirmed],
      );
      expect(out.length, 1);
      expect(out.first.pocketRecordId, 'pqrstuvwxyzabcd');
    });

    test('materialized row hides matching virt occurrence', () {
      const parentPb = 'abcdefghijklmno';
      const instDay = '2026-06-23';
      final virt = _plan(
        planRowId: 'virt-$parentPb-$instDay',
        pocketRecordId: null,
        startH: 0,
        startM: 10,
        endH: 0,
        endM: 40,
      );
      final materialized = _plan(
        planRowId: 'biz-uuid-3',
        pocketRecordId: parentPb,
        startH: 0,
        startM: 10,
        endH: 0,
        endM: 40,
        recurrenceInstanceDateKey: instDay,
      );
      final out = DatabaseService.instance.dedupePlanningTasksForDisplay(
        [virt, materialized],
      );
      expect(out.length, 1);
      expect(out.first.recurrenceInstanceDateKey, instDay);
      expect(out.first.planRowId, 'biz-uuid-3');
    });
  });

  group('cascade idempotency', () {
    int resolveDuration(List<Tag> tags) => 30;

    test('second cascade produces no patches', () {
      final a = _plan(
        planRowId: 'a',
        pocketRecordId: 'aaaaaaaaaaaaaaa',
        startH: 19,
        startM: 40,
        endH: 20,
        endM: 25,
      );
      final b = _plan(
        planRowId: 'b',
        pocketRecordId: 'bbbbbbbbbbbbbbb',
        startH: 20,
        startM: 5,
        endH: 20,
        endM: 50,
        order: 1,
      );
      final first = cascadeScheduledPlansForTimeViewDay(
        [a, b],
        resolveDurationMinutes: resolveDuration,
      );
      final patches1 = diffSequentialCascadePatches([a, b], first);
      expect(patches1, isNotEmpty);
      final patches2 = diffSequentialCascadePatches(first, first);
      expect(patches2, isEmpty);
    });
  });

  group('planningStableIdentityKey', () {
    test('uses pb id when present', () {
      final t = _plan(
        planRowId: 'biz',
        pocketRecordId: 'abcdefghijklmno',
        startH: 0,
        startM: 10,
        endH: 0,
        endM: 40,
      );
      expect(
        DatabaseService.instance.planningStableIdentityKey(t),
        'pb:abcdefghijklmno',
      );
    });
  });
}
