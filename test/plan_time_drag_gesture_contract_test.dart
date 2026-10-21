import 'package:counter/features/planning/plan_time_gesture_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plan_time_gesture_contract', () {
    test('movement below threshold is not a drag commit on desktop', () {
      expect(planTimeViewMovementBelowDragThreshold(0), isTrue);
      expect(planTimeViewMovementBelowDragThreshold(7), isTrue);
      final threshold = planTimeViewDragMovementThresholdPx();
      expect(planTimeViewMovementBelowDragThreshold(threshold - 0.01), isTrue);
      expect(planTimeViewMovementBelowDragThreshold(threshold), isFalse);
    });

    test('grabbed card stays on cursor as timeline scrolls downward', () {
      const startCardTop = 700.0;
      const pointerGrabOffset = 21.0;
      const startScroll = 220.0;
      const pointerMove = 45.0;
      const newScroll = 520.0;

      final effectiveDelta = planTimePointerAnchoredDeltaPx(
        pointerDeltaPx: pointerMove,
        scrollStartOffsetPx: startScroll,
        scrollCurrentOffsetPx: newScroll,
      );
      expect(effectiveDelta, 345);
      final cardScreenTop = startCardTop + effectiveDelta - newScroll;
      final cursorScreenY = startCardTop - startScroll +
          pointerGrabOffset + pointerMove;
      expect(cardScreenTop + pointerGrabOffset, cursorScreenY);
    });

    test('stationary cursor remains glued to card during auto-scroll', () {
      const initialCardTop = 400.0;
      const pointerOffset = 17.0;
      const initialScroll = 180.0;
      const originalCursorY = initialCardTop - initialScroll + pointerOffset;
      for (final scroll in <double>[210, 310, 450, 680, 350, 100]) {
        final effectiveDelta = planTimePointerAnchoredDeltaPx(
          pointerDeltaPx: 0,
          scrollStartOffsetPx: initialScroll,
          scrollCurrentOffsetPx: scroll,
        );
        final drawnCursorY = initialCardTop + effectiveDelta - scroll +
            pointerOffset;
        expect(drawnCursorY, originalCursorY);
      }
    });

    test('moving upward plus upward scroll never doubles or loses offset', () {
      const initialTop = 680.0;
      const initialScroll = 420.0;
      const grabOffset = 12.0;
      const pointerDelta = -75.0;
      const scroll = 170.0;
      final compensated = planTimePointerAnchoredDeltaPx(
        pointerDeltaPx: pointerDelta,
        scrollStartOffsetPx: initialScroll,
        scrollCurrentOffsetPx: scroll,
      );
      expect(compensated, -325);
      expect(initialTop + compensated - scroll + grabOffset,
          initialTop - initialScroll + grabOffset + pointerDelta);
    });

    test('auto-scroll preview resolution has independent rate from card paint', () {
      final start = DateTime(2026, 10, 21, 12);
      expect(planTimeShouldResolveAutoScrollTarget(null, start), isTrue);
      expect(
        planTimeShouldResolveAutoScrollTarget(
          start,
          start.add(const Duration(milliseconds: 16)),
        ),
        isFalse,
      );
      expect(
        planTimeShouldResolveAutoScrollTarget(
          start,
          start.add(const Duration(milliseconds: 48)),
        ),
        isFalse,
      );
      expect(
        planTimeShouldResolveAutoScrollTarget(
          start,
          start.add(const Duration(milliseconds: 64)),
        ),
        isTrue,
      );
    });

    test('drag threshold is positive', () {
      expect(planTimeViewDragMovementThresholdPx(), greaterThan(0));
    });
  });
}
