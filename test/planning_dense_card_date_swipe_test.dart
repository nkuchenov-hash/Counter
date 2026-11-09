import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persisted day start is immediately reusable by subsequent pages', () async {
    PlanningSheetTimelinePrefs.resetVisibleDayRangeCacheForTesting();
    addTearDown(PlanningSheetTimelinePrefs.resetVisibleDayRangeCacheForTesting);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'visibleDayStartHourExtended': 9,
      'visibleDayEndHourExtended': 27,
      'visible_day_end_27_v1_migrated': true,
    });
    final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
    expect(range.start, 9);
    expect(PlanningSheetTimelinePrefs.cachedVisibleDayRange?.start, 9);
    await PlanningSheetTimelinePrefs.saveVisibleDayRange(10, 26);
    expect(PlanningSheetTimelinePrefs.cachedVisibleDayRange?.start, 10);
    expect((await PlanningSheetTimelinePrefs.loadVisibleDayRange()).start, 10);
  });

  Future<void> exerciseHorizontalPageSwipe(
    WidgetTester tester, {
    required double y,
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var moves = 0;
    var resizes = 0;
    var taps = 0;
    var pointerDownLocks = 0;
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollConfiguration(
            behavior: const MouseDragScrollBehavior(),
            child: PageView(
              controller: controller,
              children: <Widget>[
                TimelinePlanInteractionBlock(
                  canMove: true,
                  canResize: true,
                  holdToEditOnWideTouch: true,
                  bulkSelectMode: false,
                  resizeHandlePx: 16,
                  blockHeightPx: 800,
                  isInteracting: false,
                  onBodyTap: () => taps++,
                  onMovePointerDown: () => pointerDownLocks++,
                  onVerticalDragStart: (_) => moves++,
                  onResizeStart: (_) => resizes++,
                  child: const ColoredBox(color: Colors.white),
                ),
                const ColoredBox(color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      Offset(900, y),
      kind: kind,
    );
    // First cross Flutter's drag slop, then send movement after it is claimed.
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-820, 1));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.page, closeTo(1, 0.01));
    expect(moves, 0);
    expect(resizes, 0);
    expect(taps, 0);
    expect(pointerDownLocks, 0);
  }

  testWidgets('horizontal mouse swipe works across a dense card body', (
    tester,
  ) async {
    await exerciseHorizontalPageSwipe(tester, y: 400);
  });

  testWidgets('horizontal swipe on card top resize zone also changes day', (
    tester,
  ) async {
    await exerciseHorizontalPageSwipe(tester, y: 5);
  });

  testWidgets('horizontal touch swipe works across a dense card body', (
    tester,
  ) async {
    await exerciseHorizontalPageSwipe(
      tester,
      y: 400,
      kind: PointerDeviceKind.touch,
    );
  });

  testWidgets('wide touch drag scrolls through a full card without moving it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var moves = 0;
    var resizes = 0;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                SizedBox(
                  height: 750,
                  child: TimelinePlanInteractionBlock(
                    canMove: true,
                    canResize: true,
                    holdToEditOnWideTouch: true,
                    bulkSelectMode: false,
                    resizeHandlePx: 16,
                    blockHeightPx: 750,
                    isInteracting: false,
                    onBodyTap: () => taps++,
                    onVerticalDragStart: (_) => moves++,
                    onResizeStart: (_) => resizes++,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      const Offset(600, 350),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(moves, 0);
    expect(resizes, 0);
    expect(taps, 0);
  });
}
