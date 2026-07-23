import 'package:counter/core/widgets/app_physical_drag_surface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card tilt follows velocity direction and stays bounded', () {
    expect(appPhysicalCardTiltForVelocity(900), greaterThan(0));
    expect(appPhysicalCardTiltForVelocity(-900), lessThan(0));
    expect(
      appPhysicalCardTiltForVelocity(100000).abs(),
      lessThanOrEqualTo(kAppPhysicalCardMaxTiltRadians),
    );
  });

  test('drag lift scales the card uniformly', () {
    expect(
      appPhysicalCardScaleX(AppPhysicalCardPhase.dragging, 1),
      greaterThan(1),
    );
    expect(
      appPhysicalCardScaleY(AppPhysicalCardPhase.dragging, 1),
      appPhysicalCardScaleX(AppPhysicalCardPhase.dragging, 1),
    );
  });

  test('resize feedback is restrained and does not alter idle geometry', () {
    expect(
      appPhysicalCardScaleX(AppPhysicalCardPhase.resizing, 1),
      lessThan(1),
    );
    expect(appPhysicalCardScaleX(AppPhysicalCardPhase.idle, 1), 1);
    expect(appPhysicalCardScaleY(AppPhysicalCardPhase.idle, 1), 1);
  });
}
