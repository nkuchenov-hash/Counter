import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Time View and Planning reorder use the canonical physical card layer', () {
    final timeCardLayer = File(
      'lib/features/planning/time_view/time_view_card_layer.dart',
    ).readAsStringSync();
    final hourGrid = File(
      'lib/features/planning/time_view/time_view_hour_grid.dart',
    ).readAsStringSync();
    final reorder = File(
      'lib/features/planning/widgets/planning_list_helpers.dart',
    ).readAsStringSync();

    expect(timeCardLayer, contains('AppPhysicalDragSurface('));
    expect(timeCardLayer, contains('onVerticalDragVelocityChanged:'));
    expect(hourGrid, contains('AppPhysicalDragVisual('));
    expect(hourGrid, contains('setTimelineInteractionLock(true)'));
    expect(reorder, contains('AppPhysicalDragVisual('));
  });
}
