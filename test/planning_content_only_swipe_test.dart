import 'package:counter/features/planning/widgets/planning_day_swipe_region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('swipe changes day inside body but never on the fixed tag bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(950, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(
                height: 180,
                child: Center(child: Text('Fixed planning tags and controls')),
              ),
              Expanded(
                child: PlanningDaySwipeRegion(
                  onDayChange: changes.add,
                  child: const ColoredBox(
                    color: Colors.white,
                    child: SizedBox.expand(child: Text('Day timeline')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final before = tester.getTopLeft(find.text('Fixed planning tags and controls'));
    // Swiping on tags must do nothing.
    final tags = await tester.startGesture(
      const Offset(800, 70),
      kind: PointerDeviceKind.mouse,
    );
    await tags.moveBy(const Offset(-55, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tags.moveBy(const Offset(-500, 0));
    await tags.up();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);

    // The same gesture inside the day body changes exactly one date.
    final body = await tester.startGesture(
      const Offset(800, 420),
      kind: PointerDeviceKind.mouse,
    );
    await body.moveBy(const Offset(-55, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await body.moveBy(const Offset(-500, 0));
    await body.up();
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
    expect(
      tester.getTopLeft(find.text('Fixed planning tags and controls')),
      before,
    );
  });

  testWidgets('vertical scrolling inside a swipe region keeps scroll ownership', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(950, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroller = ScrollController();
    addTearDown(scroller.dispose);
    var pageMoves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningDaySwipeRegion(
            onDayChange: (_) => pageMoves++,
            child: SingleChildScrollView(
              controller: scroller,
              child: const SizedBox(
                height: 1800,
                width: 950,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      const Offset(500, 380),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -350));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scroller.offset, greaterThan(0));
    expect(pageMoves, 0);
  });

  testWidgets('small horizontal jitter does not change the day', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningDaySwipeRegion(
            onDayChange: (_) => changes++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      const Offset(400, 300),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(4, 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, 0);
  });

  testWidgets('dragging never repaints or displaces the large day canvas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var builds = 0;
    final changes = <int>[];
    const bodyKey = ValueKey('stable-day-content');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningDaySwipeRegion(
            onDayChange: changes.add,
            child: Builder(
              builder: (context) {
                builds++;
                return const SizedBox.expand(
                  key: bodyKey,
                  child: ColoredBox(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
    final initialPosition = tester.getTopLeft(find.byKey(bodyKey));
    final initialBuilds = builds;
    final gesture = await tester.startGesture(
      const Offset(900, 400),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(-32, 0));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(-12, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(find.byKey(bodyKey)), initialPosition);
      expect(builds, initialBuilds);
      expect(changes, isEmpty);
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
  });
}
