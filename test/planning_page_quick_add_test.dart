import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/planning/widgets/planning_empty_states.dart';
import 'package:counter/features/planning/widgets/planning_quick_add_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dayKey = '2026-06-18';
final _harnessDay = DateTime(2026, 6, 18);

Future<void> _pumpPlanningPageHarness(
  WidgetTester tester, {
  required ShellLayoutController shellLayout,
}) async {
  shellLayout.applyShellFrame(1);
  await tester.pumpWidget(
    MaterialApp(
      home: ShellLayoutScope(
        controller: shellLayout,
        child: PlanningPage(
          selectedDateString: _dayKey,
          selectedDate: _harnessDay,
          isActivePlanningDay: true,
          shellTabActive: true,
          selectedCategoryId: null,
          onCategoryChanged: (_) {},
          onStartRecordFromTask:
              (_, __, ___, {String? sourcePlanPocketRecordId}) async {},
          onEditTask: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  // Allow quick-add tag reload (SharedPreferences + fetchTags no-op without Brain).
  await tester.pump(const Duration(milliseconds: 200));
}

PlanningTask _quickAddHarnessTask({String title = 'Quick add harness task'}) {
  final start = DateTime(2026, 6, 18, 11, 0);
  final end = DateTime(2026, 6, 18, 12, 0);
  return PlanningTask(
    id: 11,
    title: title,
    categoryId: 1,
    isDone: false,
    dateKey: _dayKey,
    order: 0,
    startTime: start,
    endDateTime: end,
    planRowId: 'quick-add-harness-plan',
    pocketRecordId: 'quickaddabcdefg',
  );
}

Finder get _quickAddField => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Add a new plan',
    );

Finder get _quickAddButton => find.widgetWithIcon(FilledButton, Icons.add_rounded);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlanningPage quick-add contract', () {
    testWidgets('quick-add chrome renders on active planning day', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanningQuickAddTagStrip), findsOneWidget);
      expect(_quickAddField, findsOneWidget);
      expect(_quickAddButton, findsOneWidget);
    });

    testWidgets('empty quick-add submit is a no-op on empty day', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      expect(find.byType(PlanningDayEmptyState), findsOneWidget);
      await tester.tap(_quickAddButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanningDayEmptyState), findsOneWidget);
    });

    testWidgets('typed quick-add submit does not throw without PocketBase',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      await tester.enterText(_quickAddField, 'Write release notes');
      await tester.tap(_quickAddButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanningPage), findsOneWidget);
      // Brain not initialized in harness — field may retain text; no network required.
      expect(find.text('Write release notes'), findsOneWidget);
    });

    testWidgets('keyboard done on quick-add field does not throw', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      await tester.enterText(_quickAddField, 'Plan from keyboard');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('optimistic quick-add task renders in day list shell',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DatabaseService.instance.applyOptimisticPlanningTask(
        _quickAddHarnessTask(),
      );
      addTearDown(
        () => DatabaseService.instance.clearOptimisticPlanningForPlanRow(
          'quick-add-harness-plan',
        ),
      );

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanningDayEmptyState), findsNothing);
      expect(find.text('Quick add harness task'), findsWidgets);
      expect(find.byType(PlanningQuickAddTagStrip), findsOneWidget);
    });
  });
}
