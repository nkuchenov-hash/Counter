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

  testWidgets('center body captures drag immediately on pointer down',
      (tester) async {
    var moveStarted = false;
    var moveUpdates = 0;
    var moveEnded = false;
    var tapped = false;
    await tester.pumpWidget(
      _testHarness(
        onBodyTap: () => tapped = true,
        onMoveStart: (_) => moveStarted = true,
        onMoveUpdate: (_, __) => moveUpdates += 1,
        onMoveEnd: () => moveEnded = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final topLeft = tester.getTopLeft(block);
    final gesture = await tester.startGesture(topLeft + const Offset(130, 50));

    expect(moveStarted, isTrue);

    await gesture.moveBy(const Offset(0, 5));
    await gesture.up();
    await tester.pump();

    expect(moveUpdates, greaterThan(0));
    expect(moveEnded, isTrue);
    expect(tapped, isFalse);
  });

  testWidgets('short click cancels captured drag and opens the card',
      (tester) async {
    var moveStarted = false;
    var moveEnded = false;
    var moveCanceled = false;
    var tapped = false;
    await tester.pumpWidget(
      _testHarness(
        onBodyTap: () => tapped = true,
        onMoveStart: (_) => moveStarted = true,
        onMoveEnd: () => moveEnded = true,
        onMoveCancel: () => moveCanceled = true,
      ),
    );

    final block = find.byType(TimelinePlanInteractionBlock);
    final topLeft = tester.getTopLeft(block);
    final gesture = await tester.startGesture(topLeft + const Offset(130, 50));
    await gesture.up();
    await tester.pump();

    expect(moveStarted, isTrue);
    expect(moveCanceled, isTrue);
    expect(moveEnded, isFalse);
    expect(tapped, isTrue);
  });
}
