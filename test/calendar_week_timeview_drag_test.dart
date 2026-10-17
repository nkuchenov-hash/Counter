import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_week_timeview_drag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Calendar Week uses Time View pointer gesture to commit a drop',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final task = PlanningTask(
      id: 12,
      title: 'Calendar drag target',
      categoryId: 3,
      dateKey: '2026-10-19',
      startTime: DateTime(2026, 10, 19, 9),
      endDateTime: DateTime(2026, 10, 19, 9, 30),
    );
    var taps = 0;
    var drops = 0;
    Offset? dropPointer;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            height: 70,
            child: CalendarWeekTimeViewDrag(
              tasks: [task],
              canMove: true,
              height: 70,
              onTap: () => taps++,
              onDrop: (tasks, pointer, grabOffset) async {
                drops++;
                dropPointer = pointer;
              },
              child: const ColoredBox(color: Colors.grey,
                child: Center(child: Text('Plan body'))),
            ),
          ),
        ),
      ),
    ));

    final center = tester.getCenter(find.text('Plan body'));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(25, 70));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(drops, 1);
    expect(taps, 0);
    expect(dropPointer, isNotNull);
    expect(dropPointer!.dy, greaterThan(center.dy));

    await tester.tap(find.text('Plan body'));
    await tester.pump();
    expect(taps, 1);
    expect(drops, 1);
  });
}
