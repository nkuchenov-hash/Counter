import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/categories/create_category_from_picker.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _node(
  int id,
  String name, {
  String? backendRowId,
  List<CategoryRule>? children,
}) {
  return CategoryRule(
    id: id,
    name: name,
    backendRowId: backendRowId ?? 'pb$id',
    children: children,
  );
}

void main() {
  tearDown(() {
    categoryPickerAddNestedCategoryOverride = null;
    categoryCreateFromPickerAllowedOverride = null;
  });

  setUp(() {
    categoryCreateFromPickerAllowedOverride = () => true;
  });

  group('filterCategoryRootsForPickerSearch', () {
    final roots = [
      _node(1, 'Work', children: [
        _node(2, 'Meetings'),
        _node(3, 'Deep Work'),
      ]),
      _node(4, 'Health'),
    ];

    test('empty query returns all roots', () {
      final out = filterCategoryRootsForPickerSearch(
        roots,
        '',
        (r) => r.name,
      );
      expect(out.length, 2);
    });

    test('no match returns empty list', () {
      final out = filterCategoryRootsForPickerSearch(
        roots,
        'missing',
        (r) => r.name,
      );
      expect(out, isEmpty);
    });
  });

  group('category picker create chrome', () {
    test('row add shows when picker chrome enabled', () {
      expect(
        categoryTreeNodeShowsPickerAddChild(
          showPickerCreateChrome: true,
          onPickerAddChild: (_) {},
        ),
        isTrue,
      );
    });

    test('row add hidden when picker chrome disabled', () {
      expect(
        categoryTreeNodeShowsPickerAddChild(
          showPickerCreateChrome: false,
          onPickerAddChild: (_) {},
        ),
        isFalse,
      );
    });

    test('row target uses exact row category id', () {
      final priceReporter = _node(100, 'Price Reporter');
      final work = _node(1, 'Work');

      final prTarget = categoryPickerCreateTargetForRow(priceReporter);
      final workTarget = categoryPickerCreateTargetForRow(work);

      expect(prTarget.parentLocalId, 100);
      expect(prTarget.parentDisplayName, 'Price Reporter');
      expect(workTarget.parentLocalId, 1);
      expect(workTarget.parentDisplayName, 'Work');
    });

    test('folder add label includes parent name', () {
      expect(
        categoryPickerAddInsideLabel('en', 'Price Reporter'),
        contains('Price Reporter'),
      );
    });
  });

  group('createCategoryFromPickerSubmit parent contract', () {
    test('row plus on Price Reporter records parent 100 not Work 1', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return 501;
      };

      final target = CategoryPickerCreateTarget.child(
        parentLocalId: 100,
        parentDisplayName: 'Price Reporter',
      );

      final id = await createCategoryFromPickerSubmit(
        name: 'New Client',
        target: target,
      );

      expect(recordedParentId, 100);
      expect(recordedParentId, isNot(1));
      expect(id, 501);
    });

    test('row plus on Work records parent 1', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return 502;
      };

      final id = await createCategoryFromPickerSubmit(
        name: 'New Bucket',
        target: CategoryPickerCreateTarget.child(
          parentLocalId: 1,
          parentDisplayName: 'Work',
        ),
      );

      expect(recordedParentId, 1);
      expect(id, 502);
    });

    test('root add row records null parent', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return 503;
      };

      final id = await createCategoryFromPickerSubmit(
        name: 'Top Level',
        target: const CategoryPickerCreateTarget.root(),
      );

      expect(recordedParentId, isNull);
      expect(id, 503);
    });

    test('folder-scoped target for Price Reporter matches row plus', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return 504;
      };

      final priceReporter = _node(100, 'Price Reporter');
      final id = await createCategoryFromPickerSubmit(
        name: 'Folder Scoped',
        target: categoryPickerCreateTargetForRow(priceReporter),
      );

      expect(recordedParentId, 100);
      expect(id, 504);
    });

    test('returns null when create fails', () async {
      categoryPickerAddNestedCategoryOverride = (parentId, child) async => null;

      final id = await createCategoryFromPickerSubmit(
        name: 'Failed',
        target: const CategoryPickerCreateTarget.root(),
      );

      expect(id, isNull);
    });
  });

  group('resolveEditFieldCategoryIdValues selection handoff', () {
    test('new category in tree wins over stale pair list', () {
      expect(
        resolveEditFieldCategoryIdValues(
          categoryId: 999,
          existsInTree: true,
          knownPairIds: const [1, 2, 3],
        ),
        999,
      );
    });

    test('preserves explicit picker handoff id when tree momentarily stale', () {
      expect(
        resolveEditFieldCategoryIdValues(
          categoryId: 999,
          existsInTree: false,
          knownPairIds: const [1, 2, 3],
        ),
        999,
      );
    });

    test('does not substitute pairs.first for explicit create handoff', () {
      const createdId = 501;
      expect(
        resolveEditFieldCategoryIdValues(
          categoryId: createdId,
          existsInTree: false,
          knownPairIds: const [10, 20],
        ),
        createdId,
      );
      expect(
        resolveEditFieldCategoryIdValues(
          categoryId: createdId,
          existsInTree: false,
          knownPairIds: const [10, 20],
        ),
        isNot(10),
      );
    });

    test('keeps requested id when tree and pairs both empty', () {
      expect(
        resolveEditFieldCategoryIdValues(
          categoryId: 999,
          existsInTree: false,
          knownPairIds: const [],
        ),
        999,
      );
    });
  });

  group('category picker create → plan draft handoff', () {
    test('draft category id matches picker create result without reopen', () async {
      const createdId = 777;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        return createdId;
      };

      final fromCreate = await createCategoryFromPickerSubmit(
        name: 'Instant Attach',
        target: const CategoryPickerCreateTarget.root(),
      );
      expect(fromCreate, createdId);

      final draftCategoryId = resolveEditFieldCategoryIdValues(
        categoryId: fromCreate!,
        existsInTree: true,
        knownPairIds: const [10, 20],
      );
      expect(draftCategoryId, createdId);
    });

    test('existing category selection still resolves when in tree', () {
      expect(
        resolveEditFieldCategoryIdValues(
          categoryId: 10,
          existsInTree: true,
          knownPairIds: const [10, 20],
        ),
        10,
      );
    });

    test('rejects create handoff id -1 (uncategorized collision)', () async {
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        return CategoryRule.uncategorizedSyntheticId;
      };

      final fromCreate = await createCategoryFromPickerSubmit(
        name: 'RGH Products',
        target: const CategoryPickerCreateTarget.child(
          parentLocalId: 100,
          parentDisplayName: 'Price Reporter',
        ),
      );
      expect(fromCreate, isNull);
    });
  });

  group('create → select → explicit Save persists new category', () {
    test('nested create under Price Reporter wins over original Жизнь on Save',
        () async {
      const lifeCategoryId = 42; // existing plan category "Жизнь"
      const priceReporterId = 100;
      const rghProductsId = 501;
      const rghPbRowId = 'rghproductscat1'; // 15-char PB id

      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        expect(parentId, priceReporterId);
        expect(child.name, 'RGH Products');
        // Simulate successful create handoff (unique temp id upgraded).
        expect(child.id, isNot(CategoryRule.uncategorizedSyntheticId));
        return rghProductsId;
      };

      final fromCreate = await createCategoryFromPickerSubmit(
        name: 'RGH Products',
        target: const CategoryPickerCreateTarget.child(
          parentLocalId: priceReporterId,
          parentDisplayName: 'Price Reporter',
        ),
      );
      expect(fromCreate, rghProductsId);
      expect(fromCreate, isNot(lifeCategoryId));

      // Sheet visible selection / draft owner (_categoryId) after picker callback.
      final sheetCategoryId = fromCreate!;
      final draftCategoryId = resolvePlanningEditDraftCategoryId(
        draftCategoryId: sheetCategoryId,
        originalTaskCategoryId: lifeCategoryId,
        existsInTree: true,
        knownPairIds: const [lifeCategoryId, priceReporterId],
      );
      expect(draftCategoryId, rghProductsId);
      expect(draftCategoryId, isNot(lifeCategoryId));

      // Explicit Save uses the same draft snapshot (not original task category).
      final savedTask = PlanningTask(
        id: 1,
        planRowId: 'plan-uuid-life',
        pocketRecordId: 'pbplanrow000001',
        title: 'Existing task',
        categoryId: draftCategoryId,
        isDone: false,
        dateKey: '2026-07-08',
        order: 0,
      );
      expect(savedTask.categoryId, rghProductsId);
      expect(savedTask.categoryId, isNot(lifeCategoryId));

      // Plan PATCH must include the new category relation (not silently omit).
      expect(
        planPatchShouldIncludeCategoryRelation(
          localCategoryId: savedTask.categoryId,
          pocketBaseCategoryRowId: rghPbRowId,
        ),
        isTrue,
      );
      expect(
        planPatchShouldIncludeCategoryRelation(
          localCategoryId: CategoryRule.uncategorizedSyntheticId,
          pocketBaseCategoryRowId: rghPbRowId,
        ),
        isFalse,
      );
    });

    test('draft does not fall back to original when create id is in tree', () {
      const life = 42;
      const rgh = 501;
      expect(
        resolvePlanningEditDraftCategoryId(
          draftCategoryId: rgh,
          originalTaskCategoryId: life,
          existsInTree: true,
          knownPairIds: const [life],
        ),
        rgh,
      );
    });

    test('draft keeps created id when tree momentarily stale after create', () {
      const life = 42;
      const rgh = 501;
      expect(
        resolvePlanningEditDraftCategoryId(
          draftCategoryId: rgh,
          originalTaskCategoryId: life,
          existsInTree: false,
          knownPairIds: const [life],
        ),
        rgh,
      );
      expect(
        resolvePlanningEditDraftCategoryId(
          draftCategoryId: rgh,
          originalTaskCategoryId: life,
          existsInTree: false,
          knownPairIds: const [life],
        ),
        isNot(life),
      );
    });

    test('legacy -1 draft falls back to original so Save is not a silent no-op',
        () {
      const life = 42;
      expect(
        resolvePlanningEditDraftCategoryId(
          draftCategoryId: CategoryRule.uncategorizedSyntheticId,
          originalTaskCategoryId: life,
          existsInTree: false,
          knownPairIds: const [life],
        ),
        life,
      );
    });

    test('existing category selection still persists on Save draft', () {
      const life = 42;
      const work = 10;
      expect(
        resolvePlanningEditDraftCategoryId(
          draftCategoryId: work,
          originalTaskCategoryId: life,
          existsInTree: true,
          knownPairIds: const [life, work],
        ),
        work,
      );
    });

    test('Save flush uses fire-time draft snapshot category not stale rebuild',
        () {
      final gate = EditSheetAutosaveGate();
      var syncCategoryId = 0;
      // Prior autosave scheduled with old category in a closure.
      gate.schedule(() => syncCategoryId = 42);

      const rgh = 501;
      final fireTimeDraft = PlanningTask(
        id: 1,
        planRowId: 'plan-uuid',
        pocketRecordId: 'pbplanrow000002',
        title: 'Task',
        categoryId: rgh,
        isDone: false,
        dateKey: '2026-07-08',
        order: 0,
      );
      // Explicit Save: flush the snapshot captured at Save press.
      gate.flush(
        () {
          syncCategoryId = fireTimeDraft.categoryId;
        },
        force: true,
      );
      expect(syncCategoryId, rgh);
      expect(syncCategoryId, isNot(42));
      gate.dispose();
    });
  });

  group('category picker selection callback contract', () {
    test('create submit id matches row tap result shape', () async {
      const createdId = 777;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        return createdId;
      };

      final fromCreate = await createCategoryFromPickerSubmit(
        name: 'Handoff',
        target: const CategoryPickerCreateTarget.root(),
      );

      final fromRowTap = CategoryTreeSheetPicked(createdId).id;

      expect(fromCreate, fromRowTap);
      expect(fromCreate, createdId);
    });

    test('edit draft uses created id not pairs.first when in tree', () {
      const createdId = 888;
      final draftCategoryId = resolveEditFieldCategoryIdValues(
        categoryId: createdId,
        existsInTree: true,
        knownPairIds: const [10, 20],
      );
      expect(draftCategoryId, createdId);
      expect(draftCategoryId, isNot(10));
    });
  });

  group('categoryPickerCreateTarget dialog titles', () {
    test('root title is localized root string', () {
      expect(
        categoryPickerCreateDialogTitle(
          'en',
          const CategoryPickerCreateTarget.root(),
        ),
        isNotEmpty,
      );
    });

    test('child title includes parent name', () {
      final title = categoryPickerCreateDialogTitle(
        'en',
        const CategoryPickerCreateTarget.child(
          parentLocalId: 100,
          parentDisplayName: 'Price Reporter',
        ),
      );
      expect(title, contains('Price Reporter'));
    });
  });

  testWidgets('picker create list tile is tappable when enabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: categoryPickerCreateListTile(
            key: categoryPickerTopAddKey,
            label: 'Add root category',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Add root category'), findsOneWidget);
    await tester.tap(find.text('Add root category'));
    expect(tapped, isTrue);
  });

  testWidgets('top and bottom root add keys are distinct', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              categoryPickerCreateListTile(
                key: categoryPickerTopAddKey,
                label: 'Top',
                onTap: () {},
              ),
              categoryPickerCreateListTile(
                key: categoryPickerBottomAddKey,
                label: 'Bottom',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(categoryPickerTopAddKey), findsOneWidget);
    expect(find.byKey(categoryPickerBottomAddKey), findsOneWidget);
  });
}
