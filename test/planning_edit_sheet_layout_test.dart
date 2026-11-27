import 'package:counter/core/theme.dart';
import 'package:flutter/services.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/planning_task_edit_sheet.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers.global/events', 'xyz.luan/audioplayers']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(1050, 1000), const Size(390, 844)]) {
    testWidgets(
      'dated plan keeps time and tags above the three content tabs at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = DatabaseService.instance;
        db.debugActivateRecordBrainTestHarness(
          userId: 'planeditlayout01',
          categories: [CategoryRule(id: 1, name: 'Work')],
        );
        addTearDown(db.debugResetRecordBrainTestHarness);
        CategoryTreeSource.categoryExists =
            (categoryId) => db.getCategoryRuleById(categoryId) != null;
        CategoryTreeSource.getCategoryPath = (categoryId) =>
            'Work > Price Reporter > GLOBAL SOLUTIONS GROUP';
        addTearDown(() {
          CategoryTreeSource.categoryExists = null;
          CategoryTreeSource.getCategoryPath = null;
        });

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final task = PlanningTask(
          id: 1,
          title: 'GSG Adjust the FCP file',
          categoryId: 1,
          isDone: false,
          dateKey: '2026-10-15',
          order: 0,
          startTime: DateTime(2026, 10, 15, 21, 50),
          endDateTime: DateTime(2026, 10, 15, 22, 5),
        );

        const capture = bool.fromEnvironment('LIFEOS_CAPTURE_V45');
        if (capture) await tester.runAsync(() async { await (FontLoader('Onest')..addFont(rootBundle.load('assets/fonts/Onest-Variable.ttf'))).load(); });
        await tester.pumpWidget(
          MaterialApp(
            theme: capture ? appLightTheme : null,
            home: Scaffold(
              body: RepaintBoundary(key: const ValueKey('v45-plan-capture'), child: PlanningTaskEditSheet(
                task: task,
                dateKey: task.dateKey,
                scrollController: scrollController,
              )),
            ),
          ),
        );
        await tester.pump();

        final times = find.byKey(const ValueKey('planning-edit-time-row'));
        final tags = find.byKey(const ValueKey('planning-edit-tag-strip'));
        final tabs = find.byKey(const ValueKey('planning-edit-primary-tabs'));
        final notes = find.byKey(const ValueKey('planning-edit-notes-pane'));
        final content = find.byKey(const ValueKey('planning-edit-tab-content'));
        final actions = find.byKey(const ValueKey('planning-edit-action-bar'));
        for (final element in [times, tags, tabs, notes, content, actions]) {
          expect(element, findsOneWidget);
        }
        expect(tester.getTopLeft(tags).dy, greaterThan(tester.getBottomLeft(times).dy - 1));
        expect(tester.getTopLeft(tabs).dy, greaterThan(tester.getBottomLeft(tags).dy - 1));
        expect(tester.getTopLeft(content).dy, greaterThanOrEqualTo(tester.getBottomLeft(tabs).dy - 1));
        // Approved floating footer overlays the scrollable notes viewport.
        final contentRect = tester.getRect(content);
        final actionRect = tester.getRect(actions);
        expect(actionRect.top, greaterThan(contentRect.top));
        expect(actionRect.bottom, lessThanOrEqualTo(contentRect.bottom + 1));
        final noteList = tester.widget(find.byKey(const ValueKey('notes-editor-content')));
        final listPadding = noteList is ReorderableListView ? noteList.padding : (noteList as ListView).padding;
        expect(listPadding!.resolve(TextDirection.ltr).bottom, greaterThanOrEqualTo(contentRect.bottom - actionRect.top));
        expect(tester.getSize(notes).height, greaterThan(100));
        if (capture) await expectLater(find.byKey(const ValueKey('v45-plan-capture')), matchesGoldenFile('../build/editor-v45-captures/plan-${size.width.toInt()}.png'));

        final tab = tester.widget<TabBar>(
          find.descendant(of: tabs, matching: find.byType(TabBar)),
        );
        expect(tab.tabs.length, 3);
        await tester.tap(find.byWidget(tab.tabs[1]));
        // Tag catalog may still be loading; its progress indicator is an
        // intentional perpetual animation until the backend resolves.
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
