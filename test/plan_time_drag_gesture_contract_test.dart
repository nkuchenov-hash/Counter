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

    test('drag threshold is positive', () {
      expect(planTimeViewDragMovementThresholdPx(), greaterThan(0));
    });
  });
}
