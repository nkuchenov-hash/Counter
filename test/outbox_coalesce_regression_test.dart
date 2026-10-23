import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  group('category offline PATCH revision regressions', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('rapid edits coalesce; older server ACK cannot erase latest', () async {
      final prefs = await SharedPreferences.getInstance();
      const owner = 'profile12345678';
      const categoryId = 'category1234567';
      await CategoryMutationOutbox.enqueue(prefs,
          owner: owner, pocketBaseId: categoryId,
          fields: <String, dynamic>{'color_value': 0xFF969696, 'order': 3});
      final first = await CategoryMutationOutbox.load(prefs, owner);
      final oldRevision = first.single['revision'] as int;
      await CategoryMutationOutbox.enqueue(prefs,
          owner: owner, pocketBaseId: categoryId,
          fields: <String, dynamic>{'color_value': 0xFF606060});
      final latest = await CategoryMutationOutbox.load(prefs, owner);
      expect(latest, hasLength(1));
      expect((latest.single['fields'] as Map)['color_value'], 0xFF606060);
      expect((latest.single['fields'] as Map)['order'], 3);
      expect(await CategoryMutationOutbox.acknowledge(prefs,
          owner: owner, pocketBaseId: categoryId, revision: oldRevision), false);
      expect(await CategoryMutationOutbox.load(prefs, owner), hasLength(1));
      expect(await CategoryMutationOutbox.acknowledge(prefs,
          owner: owner, pocketBaseId: categoryId,
          revision: latest.single['revision'] as int), true);
      expect(await CategoryMutationOutbox.load(prefs, owner), isEmpty);
    });

    test('queued edits remain owner-scoped after persistence', () async {
      final prefs = await SharedPreferences.getInstance();
      await CategoryMutationOutbox.enqueue(prefs, owner: 'owner-a',
          pocketBaseId: 'category1234567',
          fields: <String, dynamic>{'icon_code_point': 58333});
      expect(await CategoryMutationOutbox.load(prefs, 'owner-b'), isEmpty);
      final restored = await CategoryMutationOutbox.load(prefs, 'owner-a');
      expect(restored.single['pocketBaseId'], 'category1234567');
      expect((restored.single['fields'] as Map)['icon_code_point'], 58333);
    });
  });

}
