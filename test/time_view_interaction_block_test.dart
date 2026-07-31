import 'package:counter/features/planning/time_view/time_view_drag_state.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'tap-only Time View card opens from body without covering controls',
    (tester) async {
      var bodyTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 80,
                child: TimelinePlanInteractionBlock(
                  canMove: false,
                  canResize: false,
                  bulkSelectMode: false,
                  resizeHandlePx: 16,
                  isInteracting: false,
                  controlsLeftInset: 40,
                  controlsRightInset: 40,
                  onBodyTap: () => bodyTapCount++,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(TimelinePlanInteractionBlock));

      await tester.tapAt(Offset(rect.left + 10, rect.center.dy));
      await tester.pump();
      expect(bodyTapCount, 0);

      await tester.tapAt(rect.center);
      await tester.pump();
      expect(bodyTapCount, 1);
    },
  );

  testWidgets(
    'phone swipe scrolls without starting move or resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      var moveStarts = 0;
      var resizeStarts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 320),
                SizedBox(
                  height: 80,
                  child: TimelinePlanInteractionBlock(
                    canMove: true,
                    canResize: true,
                    bulkSelectMode: false,
                    resizeHandlePx: 16,
                    blockHeightPx: 80,
                    isInteracting: false,
                    onVerticalDragStart: (_) => moveStarts++,
                    onResizeStart: (_) => resizeStarts++,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      );

      await tester.drag(
        find.byType(TimelinePlanInteractionBlock),
        const Offset(0, -140),
      );
      await tester.pumpAndSettle();

      expect(scrollController.offset, greaterThan(0));
      expect(moveStarts, 0);
      expect(resizeStarts, 0);
    },
  );

  testWidgets(
    'phone hold uses center for move and edge for resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var moveStarts = 0;
      final resizeEdges = <TimelineResizeEdge>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 80,
                child: TimelinePlanInteractionBlock(
                  canMove: true,
                  canResize: true,
                  bulkSelectMode: false,
                  resizeHandlePx: 16,
                  blockHeightPx: 80,
                  isInteracting: false,
                  onVerticalDragStart: (_) => moveStarts++,
                  onVerticalDragUpdate: (_, __) {},
                  onVerticalDragEnd: () {},
                  onResizeStart: resizeEdges.add,
                  onResizeUpdate: (_, __) {},
                  onResizeEnd: () {},
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(TimelinePlanInteractionBlock));

      final moveGesture = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 350));
      await moveGesture.moveBy(const Offset(0, 24));
      await moveGesture.up();
      await tester.pump();

      expect(moveStarts, 1);
      expect(resizeEdges, isEmpty);

      final resizeGesture = await tester.startGesture(
        Offset(rect.center.dx, rect.top + 4),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await resizeGesture.moveBy(const Offset(0, -16));
      await resizeGesture.up();
      await tester.pump();

      expect(moveStarts, 1);
      expect(resizeEdges, [TimelineResizeEdge.top]);
    },
  );
}
