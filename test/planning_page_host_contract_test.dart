import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/planning/widgets/planning_empty_states.dart';
import 'package:counter/core/widgets/app_settings_breadcrumb_bar.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/features/profile/menu/life_os_planning_settings_page.dart';
import 'package:counter/features/planning/widgets/planning_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _harnessDay = DateTime(2026, 6, 15);
const _harnessDayKey = '2026-06-15';

Future<void> _pumpPlanningPageHarness(
  WidgetTester tester, {
  required ShellLayoutController shellLayout,
  DateTime? selectedDate,
  bool isActivePlanningDay = true,
}) async {
  final day = selectedDate ?? DateTime(2026, 6, 15);
  final dateKey =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  shellLayout.applyShellFrame(1);
  await tester.pumpWidget(
    MaterialApp(
      home: ShellLayoutScope(
        controller: shellLayout,
        child: PlanningPage(
          selectedDateString: dateKey,
          selectedDate: day,
          isActivePlanningDay: isActivePlanningDay,
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
  await tester.pump(const Duration(milliseconds: 200));
}

PlanningTask _scheduledHarnessTask() {
  final start = DateTime(2026, 6, 15, 9, 0);
  final end = DateTime(2026, 6, 15, 10, 0);
  return PlanningTask(
    id: 42,
    title: 'Host contract task',
    categoryId: 1,
    isDone: false,
    dateKey: _harnessDayKey,
    order: 0,
    startTime: start,
    endDateTime: end,
    planRowId: 'host-contract-plan',
    pocketRecordId: 'abcdefghijklmno',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlanningPage host contract', () {
    testWidgets('PlanningPage pumps under ShellLayoutScope without throwing',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanningPage), findsOneWidget);
      expect(find.byType(PlanningSortModeBar), findsOneWidget);
    });

    testWidgets('Planning gear opens canonical Settings page, not giant sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);
      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      final gear = find.descendant(
        of: find.byType(PlanningSortModeBar),
        matching: find.byIcon(Icons.settings_rounded),
      );
      expect(gear, findsOneWidget);
      await tester.tap(gear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LifeOsPlanningSettingsPage), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Breadcrumb must name the actual origin, not a fictional Planning page.
      final breadcrumb = tester.widget<AppSettingsBreadcrumbBar>(
        find.byType(AppSettingsBreadcrumbBar),
      );
      final planLabel = t(currentLocale.value, 'tab_planning');
      expect(breadcrumb.parentLabel, planLabel);
      expect(breadcrumb.alignWithSettingsBody, isTrue);

      // The original frosted icon is the only Back affordance. It still
      // returns to the actual origin without showing a second text row.
      final backButton = find.descendant(
        of: find.byType(AppSettingsBreadcrumbBar),
        matching: find.byType(AppIconButton),
      );
      expect(backButton, findsOneWidget);
      final backWidget = tester.widget<AppIconButton>(backButton);
      expect(backWidget.variant, AppIconButtonVariant.frosted);
      expect(backWidget.tooltip, planLabel);
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PlanningPage), findsOneWidget);
      expect(find.byType(LifeOsPlanningSettingsPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty day renders PlanningDayEmptyState (no network)',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(
        tester,
        shellLayout: shellLayout,
        selectedDate: DateTime(2026, 7, 1),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanningDayEmptyState), findsOneWidget);
    });

    testWidgets('Time sort mode with local optimistic task does not throw',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DatabaseService.instance.applyOptimisticPlanningTask(
        _scheduledHarnessTask(),
      );
      addTearDown(
        () => DatabaseService.instance.clearOptimisticPlanningForPlanRow(
          'host-contract-plan',
        ),
      );

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPageHarness(tester, shellLayout: shellLayout);

      expect(find.text('Time'), findsWidgets);
      await tester.tap(find.text('Time').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PlanningPage), findsOneWidget);
      // Time View host path: hour grid uses a vertical scroll surface (not empty state).
      expect(find.byType(Scrollable), findsWidgets);
    });

    test('planning_view barrel exports Planning shell entrypoints', () {
      // Compile-time contract: PlanningPage remains the public Plans tab body symbol.
      expect(PlanningPage, isA<Type>());
      expect(PlanningSwipeWrapper, isA<Type>());
    });
  });
}
