import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testHarness({
  ValueChanged<TimelineResizeEdge>? onResizeStart,
  void Function(double deltaPx, double globalDy)? onResizeUpdate,
  VoidCallback? onResizeEnd,
  VoidCallback? onResizeCancel,
  void Function(double fingerGrabOffsetCanvasPx)? onMoveStart,
  void Function(double deltaPx, double globalDy)? onMoveUpdate,
  VoidCallback? onMoveEnd,
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
            onResizeUpdate: onResizeUpdate,
            onResizeEnd: onResizeEnd,
            onResizeCancel: onResizeCancel,
            onVerticalDragStart: onMoveStart,
            onVerticalDragUpdate: onMoveUpdate,
            onVerticalDragEnd: onMoveEnd,
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('top grip owns pointer through resize completion', (tester) async {
    TimelineResizeEdge? edge;
    var updates = 0;
    var ended = false;
    await tester.pumpWidget(
      _testHarness(
        onResizeStart: (value) => edge = value,
        onResizeUpdate: (_, __) => updates += 1,
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
    expect(updates, greaterThan(0));
    expect(ended, isTrue);
  });

  testWidgets('bottom grip cancels resize without leaving interaction active',
      (tester) async {
    TimelineResizeEdge? edge;
    var ended = false;
    var canceled = false;
    await tester.pumpWidget(
      _testHarness(
        onResizeStart: (value) => edge = value,
        onResizeUpdate: (_, __) {},
        onResizeEnd: () => ended = true,
        onResizeCancel: () => canceled = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final bottomLeft = tester.getBottomLeft(block);
    final gesture =
        await tester.startGesture(bottomLeft + const Offset(130, -4));
    await gesture.moveBy(const Offset(0, -24));
    await gesture.cancel();
    await tester.pump();

    expect(edge, TimelineResizeEdge.bottom);
    expect(canceled, isTrue);
    expect(ended, isFalse);
  });

  testWidgets('card edge outside centered grip starts move, not resize',
      (tester) async {
    TimelineResizeEdge? resizeEdge;
    var moveStarted = false;
    var moveUpdates = 0;
    var moveEnded = false;
    await tester.pumpWidget(
      _testHarness(
        onResizeStart: (value) => resizeEdge = value,
        onMoveStart: (_) => moveStarted = true,
        onMoveUpdate: (_, __) => moveUpdates += 1,
        onMoveEnd: () => moveEnded = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final topLeft = tester.getTopLeft(block);
    final gesture = await tester.startGesture(topLeft + const Offset(20, 4));
    await gesture.moveBy(const Offset(0, 24));
    await gesture.up();
    await tester.pump();

    expect(resizeEdge, isNull);
    expect(moveStarted, isTrue);
    expect(moveUpdates, greaterThan(0));
    expect(moveEnded, isTrue);
  });
}
