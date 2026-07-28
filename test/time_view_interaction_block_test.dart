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
}
