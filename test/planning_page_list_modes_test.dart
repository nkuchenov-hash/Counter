import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/planning/widgets/planning_empty_states.dart';
import 'package:counter/features/planning/widgets/planning_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _day = DateTime(2026, 6, 20);
const _dayKey = '2026-06-20';

Future<void> _pumpPlanningPage(
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
          selectedDate: _day,
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
  await tester.pump(const Duration(milliseconds: 200));
}

PlanningTask _listModesTask() {
  final start = DateTime(2026, 6, 20, 10, 0);
  final end = DateTime(2026, 6, 20, 11, 0);
  return PlanningTask(
    id: 7,
    title: 'List modes task',
    categoryId: 1,
    isDone: false,
    dateKey: _dayKey,
    order: 0,
    startTime: start,
    endDateTime: end,
    planRowId: 'list-modes-plan',
    pocketRecordId: 'pqrstuvwxyzabce',
  );
}

Future<void> _selectSortMode(WidgetTester tester, String label) async {
  // SegmentedButton labels come from dictionary (en: Category / Time / Tags / Custom).
  final target = find.text(label);
  expect(target, findsWidgets);
  await tester.tap(target.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

double contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlanningPage list mode shell', () {
    testWidgets('empty day survives all sort mode selections', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPage(tester, shellLayout: shellLayout);

      expect(find.byType(PlanningDayEmptyState), findsOneWidget);

      // Empty data: mode switches still update chrome; body stays empty state.
      for (final label in ['Category', 'Time', 'Tags', 'Custom']) {
        await _selectSortMode(tester, label);
        expect(tester.takeException(), isNull);
        expect(find.byType(PlanningDayEmptyState), findsOneWidget);
      }
    });

    testWidgets('scheduled task renders list shell for each sort mode',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DatabaseService.instance.applyOptimisticPlanningTask(_listModesTask());
      addTearDown(
        () => DatabaseService.instance.clearOptimisticPlanningForPlanRow(
          'list-modes-plan',
        ),
      );

      final shellLayout = ShellLayoutController();
      addTearDown(shellLayout.dispose);

      await _pumpPlanningPage(tester, shellLayout: shellLayout);

      expect(tester.takeException(), isNull);
      expect(find.text('List modes task'), findsOneWidget);

      // Custom (default persisted) — ReorderableListView when select mode off.
      expect(find.byType(ReorderableListView), findsOneWidget);

      await _selectSortMode(tester, 'Category');
      expect(tester.takeException(), isNull);
      expect(find.text('List modes task'), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);

      await _selectSortMode(tester, 'Tags');
      expect(tester.takeException(), isNull);
      expect(find.text('List modes task'), findsOneWidget);

      await _selectSortMode(tester, 'Time');
      expect(tester.takeException(), isNull);
      // Time mode uses hour-grid scroll host (not ReorderableListView).
      expect(find.byType(Scrollable), findsWidgets);

      await _selectSortMode(tester, 'Custom');
      expect(tester.takeException(), isNull);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    test('PlanSortMode persistence indices remain stable for mode bar', () {
      // Protects segmented control wiring used by PlanningSortModeBar.
      expect(planSortModeToPersistedIndex(PlanSortMode.category), 0);
      expect(planSortModeToPersistedIndex(PlanSortMode.time), 1);
      expect(planSortModeToPersistedIndex(PlanSortMode.tags), 2);
      expect(planSortModeToPersistedIndex(PlanSortMode.custom), 3);
      expect(planSortModeFromPersistedIndex(1), PlanSortMode.time);
    });
  });

  group('Plan card light and dark theme contrast', () {
    Future<void> pumpCardControls(WidgetTester tester, {required bool dark}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? appDarkTheme : appLightTheme,
          home: Scaffold(
            body: Column(
              children: [
                const PlanCardTitleRow(
                  title: 'MISSION IT Refresh 33 Check',
                  displayIsDone: false,
                  hasRepeat: false,
                  maxLines: 1,
                ),
                const PlanCardTimeText(label: '17:00 – 17:30'),
                const PlanCardFooterRow(
                  categoryTrail: 'Работа',
                  categoryColor: Color(0xFF286BE3),
                  timeLabel: '',
                  scheduleConflict: false,
                ),
                PlanCardCheckbox(
                  selectMode: false,
                  isSelected: false,
                  displayIsDone: false,
                  toggleDoneEnabled: true,
                  onToggleDone: () {},
                ),
                PlanCardPlayButton(onPlay: () {}),
                PlanCardMenuButton(onOpenMenu: (_) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('dark plan card keeps title and time readable', (tester) async {
      await pumpCardControls(tester, dark: true);
      final scheme = appDarkTheme.colorScheme;
      final titleStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.descendant(
          of: find.byType(PlanCardTitleRow),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
      );
      expect(titleStyle.style.color, scheme.onSurface);

      final time = tester.widget<Text>(find.text('17:00 – 17:30'));
      expect(time.style!.color, scheme.onSurfaceVariant);

      final breadcrumb = tester.widget<Text>(find.text('Работа'));
      expect(
        contrastRatio(breadcrumb.style!.color!, scheme.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('dark plan card controls use dark surfaces and visible icons', (tester) async {
      await pumpCardControls(tester, dark: true);
      final scheme = appDarkTheme.colorScheme;
      final checkbox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PlanCardCheckbox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final checkboxDecoration = checkbox.decoration as BoxDecoration;
      expect(checkboxDecoration.color, scheme.surfaceContainerHigh);
      expect(checkboxDecoration.border!.top.color, scheme.onSurfaceVariant);

      final menu = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PlanCardMenuButton),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((menu.decoration as BoxDecoration).color, isNot(PlanCardTokens.menuBg));
      final menuIcon = tester.widget<Icon>(find.byIcon(Icons.more_vert_rounded));
      expect(menuIcon.color, scheme.onSurface);

      final iconPaint = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(PlanCardPlayButton),
          matching: find.byType(CustomPaint),
        ),
      ).firstWhere((paint) => paint.painter is PlanCardPlayIconPainter);
      expect(
        (iconPaint.painter! as PlanCardPlayIconPainter).fill,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('light plan card retains the existing canonical colors', (tester) async {
      await pumpCardControls(tester, dark: false);
      final titleStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.descendant(
          of: find.byType(PlanCardTitleRow),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
      );
      expect(titleStyle.style.color, PlanCardTokens.titleColor);
      expect(
        tester.widget<Text>(find.text('17:00 – 17:30')).style!.color,
        PlanCardTokens.timeColor,
      );
      final checkbox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PlanCardCheckbox),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((checkbox.decoration as BoxDecoration).color, Colors.white);
    });
  });
}
