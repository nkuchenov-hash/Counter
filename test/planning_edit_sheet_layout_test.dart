import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/planning_task_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop dated plan reserves room for schedule controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1050, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService.instance;
    db.debugActivateRecordBrainTestHarness(
      userId: 'planeditlayout01',
      categories: [CategoryRule(id: 1, name: 'Work')],
    );
    addTearDown(db.debugResetRecordBrainTestHarness);

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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningTaskEditSheet(
            task: task,
            dateKey: task.dateKey,
            scrollController: scrollController,
          ),
        ),
      ),
    );
    await tester.pump();

    final notes = find.byKey(const ValueKey('planning-edit-notes-pane'));
    final schedule = find.byKey(const ValueKey('planning-edit-schedule-pane'));
    expect(notes, findsOneWidget);
    expect(schedule, findsOneWidget);

    // The desktop editor must not use the old 5:1 ratio that pushed the
    // recurrence tabs under Delete / Cancel / Save in the production sheet.
    expect(tester.widget<Expanded>(notes).flex, 1);
    expect(tester.widget<Expanded>(schedule).flex, 3);
    expect(tester.getSize(schedule).height, greaterThan(tester.getSize(notes).height * 2));
    expect(tester.takeException(), isNull);
  });
}
