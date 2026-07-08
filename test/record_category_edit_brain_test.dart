import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/create_category_from_picker.dart';
import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const _testUserId = 'testuserbrain01';
const _oldCatA = 101;
const _existingCatB = 202;
const _newCat = 777;
const _oldPbA = 'oldcategory00001';
const _existingPbB = 'existingcatb0001';
const _newPb = 'newcategory00001';
const _recordPbId = 'recpbrow0000001';
const _recordBizId = '11111111-2222-4333-8444-555555555555';

CategoryRule _cat(int id, String name, String pbId, {String? slug}) {
  return CategoryRule(
    id: id,
    name: name,
    backendRowId: pbId,
    normalizedId: slug ?? name.toLowerCase().replaceAll(' ', '_'),
  );
}

void main() {
  final db = DatabaseService.instance;

  tearDown(() {
    db.debugResetRecordBrainTestHarness();
  });

  group('A — existing category B (pre-seeded, not create)', () {
    setUp(() {
      db.debugActivateRecordBrainTestHarness(
        userId: _testUserId,
        categories: [
          _cat(_oldCatA, 'Old Category A', _oldPbA),
          _cat(_existingCatB, 'Existing Category B', _existingPbB),
        ],
      );
      db.debugSeedFlatRecordRowForTest(<String, dynamic>{
        'id': _recordPbId,
        'record_id': _recordBizId,
        'user_id': _testUserId,
        'title': 'Running task',
        'status': 'running',
        'start_time': '2026-07-08T13:00:00.000Z',
        'category_id': _oldPbA,
        'category_link': _oldPbA,
        'categoryId': _oldCatA,
      });
    });

    test('select Existing B updates flat row and timeline read model immediately',
        () {
      final day = DateTime.utc(2026, 7, 8);
      final sigBefore = db.debugTimelineRecordsStreamSignatureForDay(day);
      expect(sigBefore, contains(_oldCatA.toString()));

      final result = db.applyOptimisticRecordRowEdit(
        recordId: _recordPbId,
        title: 'Running task',
        categoryId: _existingCatB,
      );
      expect(result.success, isTrue);
      expect(result.categoryApplied, isTrue);

      final sigAfter = db.debugTimelineRecordsStreamSignatureForDay(day);
      expect(sigAfter, isNot(sigBefore));
      expect(sigAfter, contains(_existingCatB.toString()));

      final path = db.categoryDisplayPathForRecordKeyOnDay(
        recordKey: _recordPbId,
        day: day,
      );
      expect(path, contains('Existing Category B'));
      expect(path, isNot(contains('Old Category A')));
    });
  });

  group('B — flat cache running record + newly-created category C', () {
    setUp(() {
      db.debugActivateRecordBrainTestHarness(
        userId: _testUserId,
        categories: [
          _cat(_oldCatA, 'Old Category A', _oldPbA),
          _cat(_newCat, 'New Created Category', _newPb),
        ],
      );
      db.debugSeedFlatRecordRowForTest(<String, dynamic>{
        'id': _recordPbId,
        'record_id': _recordBizId,
        'user_id': _testUserId,
        'title': 'Running task',
        'status': 'running',
        'start_time': '2026-07-08T13:00:00.000Z',
        'category_id': _oldPbA,
        'category_link': _oldPbA,
        'categoryId': _oldCatA,
      });
    });

    test('optimistic apply updates flat row and timeline read model', () {
      final result = db.applyOptimisticRecordRowEdit(
        recordId: _recordPbId,
        title: 'Running task',
        categoryId: _newCat,
      );
      expect(result.success, isTrue);
      expect(result.updatedFlatCache, isTrue);
      expect(result.categoryApplied, isTrue);

      final row = db.debugFlatRecordRowForTestKey(_recordPbId);
      expect(row, isNotNull);
      expect(row!['categoryId'], _newCat);
      expect(row['category_id'], _newPb);
      expect(row['category_link'], _newPb);
      expect(row['status'], 'running');
      expect(row['end_time'], isNull);

      final day = DateTime.utc(2026, 7, 8);
      final path = db.categoryDisplayPathForRecordKeyOnDay(
        recordKey: _recordPbId,
        day: day,
      );
      expect(path, contains('New Created Category'));
      expect(path, isNot(contains('Old Category A')));

      expect(db.visibleRecordCategoryLocalIdForKey(_recordPbId), _newCat);
    });

    test('Save outcome gate passes only after real apply', () {
      final apply = db.applyOptimisticRecordRowEdit(
        recordId: _recordPbId,
        categoryId: _newCat,
      );
      final visible = db.visibleRecordCategoryLocalIdForKey(_recordPbId);
      expect(
        recordCategorySaveUiOutcomeAfterApply(
          originalCategoryId: _oldCatA,
          requestedCategoryId: _newCat,
          categoryResolvableForPbPatch: true,
          applyResult: apply,
          visibleCategoryAfterApply: visible,
          patchDualFieldsAvailable: true,
        ),
        RunningRecordCategorySaveUiOutcome.saved,
      );
    });
  });

  group('C — picker create handoff then Save (category C added to tree)', () {
    setUp(() {
      db.debugActivateRecordBrainTestHarness(
        userId: _testUserId,
        categories: [
          _cat(_oldCatA, 'Old Category A', _oldPbA),
        ],
      );
      db.debugSeedFlatRecordRowForTest(<String, dynamic>{
        'id': _recordPbId,
        'record_id': _recordBizId,
        'user_id': _testUserId,
        'title': 'Running task',
        'status': 'running',
        'start_time': '2026-07-08T13:00:00.000Z',
        'category_id': _oldPbA,
        'category_link': _oldPbA,
        'categoryId': _oldCatA,
      });
    });

    test('after create POST, New Category C binds with dual PB PATCH fields', () {
      // Simulate successful picker create (category not in tree until POST returns).
      db.debugAddCategoryRuleForTest(
        _cat(_newCat, 'New Category C', _newPb, slug: 'new_category_c'),
      );
      expect(db.canResolveRecordCategoryForPbPatch(_newCat), isTrue);

      final dual = db.recordDualCategoryRelationFields(_newCat);
      expect(dual?.categoryId, _newPb);
      expect(dual?.categoryLink, _newPb);

      final result = db.applyOptimisticRecordRowEdit(
        recordId: _recordPbId,
        categoryId: _newCat,
      );
      expect(result.categoryApplied, isTrue);

      final path = db.categoryDisplayPathForRecordKeyOnDay(
        recordKey: _recordPbId,
        day: DateTime.utc(2026, 7, 8),
      );
      expect(path, contains('New Category C'));
      expect(
        recordCategorySaveUiOutcomeAfterApply(
          originalCategoryId: _oldCatA,
          requestedCategoryId: _newCat,
          categoryResolvableForPbPatch: true,
          applyResult: result,
          visibleCategoryAfterApply:
              db.visibleRecordCategoryLocalIdForKey(_recordPbId),
          patchDualFieldsAvailable: dual != null,
        ),
        RunningRecordCategorySaveUiOutcome.saved,
      );
    });

    test('blocks success when created category lacks PB row id', () {
      const orphanLocal = 999;
      db.debugAddCategoryRuleForTest(
        CategoryRule(
          id: orphanLocal,
          name: 'Orphan No PB',
          normalizedId: 'orphan_no_pb',
        ),
      );
      expect(db.canResolveRecordCategoryForPbPatch(orphanLocal), isFalse);
      expect(db.recordDualCategoryRelationFields(orphanLocal), isNull);
      expect(
        recordCategorySaveUiOutcomeAfterApply(
          originalCategoryId: _oldCatA,
          requestedCategoryId: orphanLocal,
          categoryResolvableForPbPatch: false,
          applyResult: const RecordOptimisticApplyResult(
            updatedFlatCache: false,
            updatedPendingMap: false,
            categoryApplied: false,
          ),
          visibleCategoryAfterApply: _oldCatA,
          patchDualFieldsAvailable: false,
        ),
        RunningRecordCategorySaveUiOutcome.categoryUnresolved,
      );
    });
  });

  group('D — pending optimistic start row + newly-created category', () {
    setUp(() {
      db.debugActivateRecordBrainTestHarness(
        userId: _testUserId,
        categories: [
          _cat(202, 'Old Category B', 'oldcategory00002'),
          _cat(_newCat, 'New Created Category', _newPb),
        ],
      );
      db.debugSeedPendingStartRecordForTest(<String, dynamic>{
        'id': 'optimistic-$_recordBizId',
        'backendRestPathId': 'optimistic-$_recordBizId',
        'record_id': _recordBizId,
        'title': 'Pending running',
        'type': 'record',
        'status': 'running',
        'startTime': DateTime.utc(2026, 7, 8, 14, 0),
        'endTime': null,
        'categoryId': 202,
        'calendarDayStr': '2026-07-08',
        '_optimisticPending': true,
      });
    });

    test('updates pending map when flat cache has no row', () {
      expect(db.debugFlatRecordRowForTestKey(_recordBizId), isNull);

      final result = db.applyOptimisticRecordRowEdit(
        recordId: _recordBizId,
        title: 'Pending running',
        categoryId: _newCat,
      );
      expect(result.success, isTrue);
      expect(result.updatedPendingMap, isTrue);
      expect(result.updatedFlatCache, isFalse);
      expect(result.categoryApplied, isTrue);

      final pend = db.debugPendingStartRecordForTest();
      expect(pend, isNotNull);
      expect(pend!['categoryId'], _newCat);
      expect(pend['endTime'], isNull);
      expect(pend['status'], 'running');

      expect(db.visibleRecordCategoryLocalIdForKey(_recordBizId), _newCat);

      final path = db.categoryDisplayPathForRecordKeyOnDay(
        recordKey: _recordBizId,
        day: DateTime.utc(2026, 7, 8),
      );
      expect(path, contains('New Created Category'));
    });

    test('false success when pending row cannot be matched', () {
      final result = db.applyOptimisticRecordRowEdit(
        recordId: 'unknown-record-key',
        categoryId: _newCat,
      );
      expect(result.success, isFalse);
      expect(
        recordCategorySaveUiOutcomeAfterApply(
          originalCategoryId: 202,
          requestedCategoryId: _newCat,
          categoryResolvableForPbPatch: true,
          applyResult: result,
          visibleCategoryAfterApply: null,
          patchDualFieldsAvailable: true,
        ),
        RunningRecordCategorySaveUiOutcome.categoryUnresolved,
      );
    });
  });

  group('E — PATCH payload dual PB relation fields', () {
    setUp(() {
      db.debugActivateRecordBrainTestHarness(
        userId: _testUserId,
        categories: [
          _cat(_oldCatA, 'Old Category A', _oldPbA),
          _cat(_newCat, 'New Created Category', _newPb),
        ],
      );
    });

    test('explicit new category produces matching 15-char ids', () async {
      final dual = db.recordDualCategoryRelationFields(_newCat);
      expect(dual, isNotNull);
      expect(dual!.categoryId, _newPb);
      expect(dual.categoryLink, _newPb);
      expect(dual.categoryId, dual.categoryLink);
      expect(dual.categoryId, isNot(_oldPbA));

      final updates = await db.debugRecordPatchUpdatesForCategory(
        localCategoryId: _newCat,
      );
      expect(updates['category_id'], _newPb);
      expect(updates['category_link'], _newPb);
      expect(updates['category_id'], isNot(_oldPbA));
    });
  });

  group('F — Timeline cache invalidation after category edit', () {
    setUp(() {
      db.debugActivateRecordBrainTestHarness(
        userId: _testUserId,
        categories: [
          _cat(_oldCatA, 'Old Category A', _oldPbA),
          _cat(_newCat, 'New Created Category', _newPb),
        ],
      );
      db.debugSeedFlatRecordRowForTest(<String, dynamic>{
        'id': _recordPbId,
        'record_id': _recordBizId,
        'user_id': _testUserId,
        'title': 'Running task',
        'status': 'running',
        'start_time': '2026-07-08T13:00:00.000Z',
        'category_id': _oldPbA,
        'category_link': _oldPbA,
        'categoryId': _oldCatA,
      });
    });

    test('peekTimelineRecordsForDate no longer returns stale Old Category A', () {
      final day = DateTime.utc(2026, 7, 8);
      final before = db.categoryDisplayPathForRecordKeyOnDay(
        recordKey: _recordPbId,
        day: day,
      );
      expect(before, contains('Old Category A'));

      db.applyOptimisticRecordRowEdit(
        recordId: _recordPbId,
        categoryId: _newCat,
      );

      final after = db.categoryDisplayPathForRecordKeyOnDay(
        recordKey: _recordPbId,
        day: day,
      );
      expect(after, contains('New Created Category'));
      expect(after, isNot(contains('Old Category A')));
    });
  });

  group('G — Plans control (unchanged)', () {
    test('plan create→Save draft still uses new category id', () {
      const oldPlanCat = 42;
      const newPlanCat = 501;
      expect(
        resolvePlanningEditDraftCategoryId(
          draftCategoryId: newPlanCat,
          originalTaskCategoryId: oldPlanCat,
          existsInTree: true,
          knownPairIds: const [oldPlanCat],
        ),
        newPlanCat,
      );
      expect(
        planPatchShouldIncludeCategoryRelation(
          localCategoryId: newPlanCat,
          pocketBaseCategoryRowId: 'rghproductscat1',
        ),
        isTrue,
      );
    });
  });
}
