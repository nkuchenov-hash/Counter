import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testHarness({
  required ValueChanged<TimelineResizeEdge> onResizeStart,
  required VoidCallback onResizeEnd,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 260,
          height: 100,
          child: TimelinePlanInteractionBlock(
            canMove: true,
            canResize: true,
            bulkSelectMode: false,
            resizeHandlePx: 16,
            isInteracting: false,
            onResizeStart: onResizeStart,
            onResizeUpdate: (_, __) {},
            onResizeEnd: onResizeEnd,
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('top grip starts and completes top-edge resize', (tester) async {
    TimelineResizeEdge? edge;
    var ended = false;
    await tester.pumpWidget(
      _testHarness(
        onResizeStart: (value) => edge = value,
        onResizeEnd: () => ended = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final topLeft = tester.getTopLeft(block);
    final gesture = await tester.startGesture(topLeft + const Offset(130, 4));
    await gesture.moveBy(const Offset(0, 24));
    await gesture.up();
    await tester.pump();

    expect(edge, TimelineResizeEdge.top);
    expect(ended, isTrue);
  });

  testWidgets('bottom grip starts and completes bottom-edge resize',
      (tester) async {
    TimelineResizeEdge? edge;
    var ended = false;
    await tester.pumpWidget(
      _testHarness(
        onResizeStart: (value) => edge = value,
        onResizeEnd: () => ended = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final bottomLeft = tester.getBottomLeft(block);
    final gesture =
        await tester.startGesture(bottomLeft + const Offset(130, -4));
    await gesture.moveBy(const Offset(0, -24));
    await gesture.up();
    await tester.pump();

    expect(edge, TimelineResizeEdge.bottom);
    expect(ended, isTrue);
  });
}
