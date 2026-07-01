import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('outbox coalescing regressions', () {
    test('RecordMutationOutbox coalesceQueue rebuilds update indexes after delete shifts earlier items', () {
      final queue = <Map<String, dynamic>>[
        RecordMutationOutbox.newRecordUpdateItem(
          businessId: 'c',
          patchFields: const <String, dynamic>{'title': 'c1'},
          originalQueryId: 'c1',
        ),
        RecordMutationOutbox.newRecordUpdateItem(
          businessId: 'a',
          patchFields: const <String, dynamic>{'title': 'a1'},
          originalQueryId: 'a1',
        ),
        RecordMutationOutbox.newRecordDeleteItem(
          businessId: 'c',
          originalQueryId: 'c1',
        ),
        RecordMutationOutbox.newRecordUpdateItem(
          businessId: 'a',
          patchFields: const <String, dynamic>{'title': 'a2'},
          originalQueryId: 'a2',
        ),
      ];

      final result = RecordMutationOutbox.coalesceQueue(queue);

      expect(result, hasLength(2));
      expect(result[0]['businessId'], 'a');
      expect(result[0]['payload'], <String, dynamic>{'title': 'a2'});
      expect(result[1]['kind'], RecordMutationOutbox.kindRecordDelete);
      expect(result[1]['businessId'], 'c');
    });

    test('PlanMutationOutbox coalesceQueue rebuilds update indexes after delete shifts earlier items', () {
      final queue = <Map<String, dynamic>>[
        PlanMutationOutbox.newPlanUpdateItem(
          businessId: 'c',
          patchFields: const <String, dynamic>{'title': 'c1'},
          originalQueryId: 'c1',
        ),
        PlanMutationOutbox.newPlanUpdateItem(
          businessId: 'a',
          patchFields: const <String, dynamic>{'title': 'a1'},
          originalQueryId: 'a1',
        ),
        PlanMutationOutbox.newPlanDeleteItem(
          businessId: 'c',
          originalQueryId: 'c1',
        ),
        PlanMutationOutbox.newPlanUpdateItem(
          businessId: 'a',
          patchFields: const <String, dynamic>{'title': 'a2'},
          originalQueryId: 'a2',
        ),
      ];

      final result = PlanMutationOutbox.coalesceQueue(queue);

      expect(result, hasLength(2));
      expect(result[0]['businessId'], 'a');
      expect(result[0]['payload'], <String, dynamic>{'title': 'a2'});
      expect(result[1]['kind'], PlanMutationOutbox.kindPlanDelete);
      expect(result[1]['businessId'], 'c');
    });
  });
}
