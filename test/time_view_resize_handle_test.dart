import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testHarness({
  ValueChanged<TimelineResizeEdge>? onResizeStart,
  void Function(double deltaPx, double globalDy)? onResizeUpdate,
  VoidCallback? onResizeEnd,
  VoidCallback? onResizeCancel,
  VoidCallback? onBodyTap,
  VoidCallback? onMovePointerDown,
  VoidCallback? onMovePointerRelease,
  void Function(double fingerGrabOffsetCanvasPx)? onMoveStart,
  void Function(double deltaPx, double globalDy)? onMoveUpdate,
  VoidCallback? onMoveEnd,
  VoidCallback? onMoveCancel,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 800)),
      child: Scaffold(
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
              onBodyTap: onBodyTap,
              onMovePointerDown: onMovePointerDown,
              onMovePointerRelease: onMovePointerRelease,
              onVerticalDragStart: onMoveStart,
              onVerticalDragUpdate: onMoveUpdate,
              onVerticalDragEnd: onMoveEnd,
              onVerticalDragCancel: onMoveCancel,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('top edge still resizes from any horizontal position',
      (tester) async {
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
    final gesture = await tester.startGesture(topLeft + const Offset(20, 4));
    await gesture.moveBy(const Offset(0, 24));
    await gesture.up();
    await tester.pump();

    expect(edge, TimelineResizeEdge.top);
    expect(updates, greaterThan(0));
    expect(ended, isTrue);
  });

  testWidgets('pointer down captures without visual drag; first move starts it',
      (tester) async {
    var captured = false;
    var moveStarted = false;
    var moveUpdates = 0;
    var moveEnded = false;
    await tester.pumpWidget(
      _testHarness(
        onMovePointerDown: () => captured = true,
        onMoveStart: (_) => moveStarted = true,
        onMoveUpdate: (_, __) => moveUpdates += 1,
        onMoveEnd: () => moveEnded = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final topLeft = tester.getTopLeft(block);
    final gesture = await tester.startGesture(topLeft + const Offset(130, 50));

    expect(captured, isTrue);
    expect(moveStarted, isFalse);

    await gesture.moveBy(const Offset(0, 1));
    expect(moveStarted, isTrue);
    expect(moveUpdates, greaterThan(0));

    await gesture.up();
    await tester.pump();
    expect(moveEnded, isTrue);
  });

  testWidgets('short click releases capture and opens without drag flash',
      (tester) async {
    var captured = false;
    var released = false;
    var moveStarted = false;
    var moveCanceled = false;
    var tapped = false;
    await tester.pumpWidget(
      _testHarness(
        onMovePointerDown: () => captured = true,
        onMovePointerRelease: () => released = true,
        onBodyTap: () => tapped = true,
        onMoveStart: (_) => moveStarted = true,
        onMoveCancel: () => moveCanceled = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final topLeft = tester.getTopLeft(block);
    final gesture = await tester.startGesture(topLeft + const Offset(130, 50));
    await gesture.up();
    await tester.pump();

    expect(captured, isTrue);
    expect(released, isTrue);
    expect(moveStarted, isFalse);
    expect(moveCanceled, isFalse);
    expect(tapped, isTrue);
  });
}
