import 'dart:io';

import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/planning/time_view/planning_time_view_coordinator.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/widgets/planning_filter_controls.dart';
import 'package:counter/features/planning/widgets/planning_day_swipe_region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slow date swipe always settles away from the true gesture origin', () {
    double target({
      required double page,
      required int? origin,
      double velocity = 0,
    }) {
      final physics = FeatherDateSwipePhysics(
        gestureOriginPage: () => origin,
      );
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 10000,
        pixels: page * 1000,
        viewportDimension: 1000,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1,
      );
      return physics.getTargetPixels(metrics, const Tolerance(), velocity) / 1000;
    }

    expect(target(page: 0.10, origin: 0), 0);
    expect(target(page: 0.30, origin: 0), 1);
    expect(target(page: 0.70, origin: 0), 1); // Old bug: reversed to 0.
    expect(target(page: 0.90, origin: 0), 1);
    expect(target(page: 0.70, origin: 1), 0);
    expect(target(page: 0.90, origin: 1), 1);
    expect(target(page: 1.70, origin: 1), 2);
    expect(target(page: 0.70, origin: null), 1);
    expect(target(page: 0.70, origin: 0, velocity: -900), 0);
    expect(target(page: 0.70, origin: 0, velocity: 900), 1);
  });

  test('Timeline adjacent day renders full records, never empty paint', () {
    final source = File('lib/features/timeline/timeline_view.dart')
        .readAsStringSync();
    expect(source, contains('allowImplicitScrolling: widget.shellTabActive && _prepaintNeighbors'));
    expect(source, contains('isActive: widget.isActivePage,'));
    expect(source, contains('ignoring: !widget.isActivePage,'));
    expect(source, contains('Keep the SAME element tree'));
    expect(source, contains('liveRecordMaps: null,'));
    expect(source, isNot(contains('color: Colors.transparent,\\n                        child: SizedBox.expand()')));
  });

  testWidgets('swipe changes day inside body but never on the fixed tag bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(950, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(
                height: 180,
                child: Center(child: Text('Fixed planning tags and controls')),
              ),
              Expanded(
                child: PlanningDaySwipeRegion(
                  onDayChange: changes.add,
                  child: const ColoredBox(
                    color: Colors.white,
                    child: SizedBox.expand(child: Text('Day timeline')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final before = tester.getTopLeft(find.text('Fixed planning tags and controls'));
    // Swiping on tags must do nothing.
    final tags = await tester.startGesture(
      const Offset(800, 70),
      kind: PointerDeviceKind.mouse,
    );
    await tags.moveBy(const Offset(-55, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tags.moveBy(const Offset(-500, 0));
    await tags.up();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);

    // The same gesture inside the day body changes exactly one date.
    final body = await tester.startGesture(
      const Offset(800, 420),
      kind: PointerDeviceKind.mouse,
    );
    await body.moveBy(const Offset(-55, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await body.moveBy(const Offset(-500, 0));
    await body.up();
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
    expect(
      tester.getTopLeft(find.text('Fixed planning tags and controls')),
      before,
    );
  });

  testWidgets('vertical scrolling inside a swipe region keeps scroll ownership', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(950, 750));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroller = ScrollController();
    addTearDown(scroller.dispose);
    var pageMoves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningDaySwipeRegion(
            onDayChange: (_) => pageMoves++,
            child: SingleChildScrollView(
              controller: scroller,
              child: const SizedBox(
                height: 1800,
                width: 950,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      const Offset(500, 380),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -350));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scroller.offset, greaterThan(0));
    expect(pageMoves, 0);
  });

  testWidgets('small horizontal jitter does not change the day', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningDaySwipeRegion(
            onDayChange: (_) => changes++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      const Offset(400, 300),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(4, 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, 0);
  });

  testWidgets('Planning PageView follows the finger, without moving fixed chrome', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var heavyBuilds = 0;
    final changes = <int>[];
    const bodyKey = ValueKey('live-planning-body');
    const chromeKey = ValueKey('fixed-planning-controls');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 120,
                  child: Center(key: chromeKey, child: Text('Fixed controls'))),
              Expanded(
                child: PlanningDaySwipeRegion(
                  dayKey: '2026-11-09',
                  onDayChange: changes.add,
                  adjacentDayBuilder: (context, day) => ColoredBox(
                    color: Colors.grey.shade100,
                    child: Center(child: Text('Cached day ${day.day}')),
                  ),
                  child: Builder(builder: (context) {
                    heavyBuilds++;
                    return const SizedBox.expand(
                      key: bodyKey,
                      child: ColoredBox(color: Colors.white),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final initialX = tester.getTopLeft(find.byKey(bodyKey)).dx;
    final headerPos = tester.getTopLeft(find.byKey(chromeKey));
    final initialBuilds = heavyBuilds;
    final drag = await tester.startGesture(
      const Offset(900, 400), kind: PointerDeviceKind.touch);
    await drag.moveBy(const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byKey(bodyKey)).dx,
        lessThan(initialX - 80));
    expect(heavyBuilds, initialBuilds);
    expect(changes, isEmpty);
    expect(tester.getTopLeft(find.byKey(chromeKey)), headerPos);
    await drag.moveBy(const Offset(-390, 0));
    await tester.pump(const Duration(milliseconds: 16));
    // As soon as the incoming page becomes primary it must be live;
    // delaying until pointer-up previously left cards disabled.
    expect(changes, <int>[1]);
    await drag.up();
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
    expect(tester.getTopLeft(find.byKey(chromeKey)), headerPos);
  });

  testWidgets('day navigation arrows stay at both body edges, not the header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [
        const SizedBox(
          height: 120,
          child: Center(child: Text('Fixed sort selector and tags')),
        ),
        Expanded(child: PlanningDaySwipeRegion(
          dayKey: '2026-11-10',
          onDayChange: changes.add,
          adjacentDayBuilder: (context, day) => Center(
            child: Text('Preview day ${day.day}'),
          ),
          child: const SizedBox.expand(
            child: Center(child: Text('Full width plans')),
          ),
        )),
      ])),
    ));
    // The overlay portal attaches its root entry after the first frame.
    await tester.pump();
    final left = find.byKey(const ValueKey('planning-side-previous-day'));
    final right = find.byKey(const ValueKey('planning-side-next-day'));
    final page = find.byType(PageView);
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(tester.getCenter(left).dx, closeTo(28, 5));
    expect(tester.getCenter(right).dx, closeTo(1072, 5));
    expect(tester.getTopLeft(left).dy, greaterThan(120));
    expect(tester.getTopLeft(right).dy, greaterThan(120));
    expect(tester.getSize(page).width, 1100);
    expect(find.text('Fixed sort selector and tags'), findsOneWidget);
    await tester.tap(right);
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
  });

  testWidgets('desktop arrows sit in outer gutters, not beside cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1536, 985));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 1140,
            height: 750,
            child: PlanningDaySwipeRegion(
              dayKey: '2026-11-10',
              onDayChange: changes.add,
              adjacentDayBuilder: (_, day) => Center(child: Text('Day ${day.day}')),
              child: const SizedBox.expand(
                key: ValueKey('full-size-day-canvas'),
              ),
            ),
          ),
        ),
      ),
    ));
    // The overlay portal attaches its root entry after the first frame.
    await tester.pump();
    final left = find.byKey(const ValueKey('planning-side-previous-day'));
    final right = find.byKey(const ValueKey('planning-side-next-day'));
    final canvas = find.byKey(const ValueKey('full-size-day-canvas'));
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(tester.getSize(find.byType(PageView)).width, 1140);
    // Canvas begins at 198, ends at 1338. Controls must be roughly
    // centered in the 198px outer gutters, not intrude on plan cards.
    expect(tester.getCenter(left).dx, lessThan(130));
    expect(tester.getCenter(right).dx, greaterThan(1400));
    expect(tester.getCenter(left).dx, lessThan(tester.getTopLeft(canvas).dx - 48));
    expect(tester.getCenter(right).dx, greaterThan(tester.getTopRight(canvas).dx + 48));
    await tester.tap(right);
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
  });

  testWidgets('desktop left arrow stays in workspace, never in sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1641, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const navWidth = 272.0;
    const canvasWidth = 905.0;
    final changes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [
        const SizedBox(width: navWidth, child: Text('Permanent navigation')),
        Expanded(child: Center(child: SizedBox(
          width: canvasWidth,
          height: 720,
          child: PlanningDaySwipeRegion(
            dayKey: '2026-11-11',
            workspaceLeftEdgePx: navWidth,
            onDayChange: changes.add,
            adjacentDayBuilder: (_, day) => Center(child: Text('Day ${day.day}')),
            child: const SizedBox.expand(key: ValueKey('plans-body')),
          ),
        ))),
      ])),
    ));
    await tester.pump();
    final left = find.byKey(const ValueKey('planning-side-previous-day'));
    final right = find.byKey(const ValueKey('planning-side-next-day'));
    final canvas = find.byKey(const ValueKey('plans-body'));
    final canvasLeft = tester.getTopLeft(canvas).dx;
    final canvasRight = tester.getTopRight(canvas).dx;
    final leftX = tester.getCenter(left).dx;
    final rightX = tester.getCenter(right).dx;
    expect(canvasLeft, greaterThan(navWidth + 100));
    expect(tester.getSize(find.byType(PageView)).width, canvasWidth);
    expect(leftX, greaterThan(navWidth + 30));
    expect(leftX, lessThan(canvasLeft - 40));
    expect(leftX, closeTo((navWidth + canvasLeft) / 2, 6));
    expect(rightX, closeTo((canvasRight + 1641) / 2, 6));
    expect(rightX, greaterThan(canvasRight + 40));
    await tester.tap(left);
    await tester.pumpAndSettle();
    expect(changes, [-1]);
  });

  testWidgets('hidden Planning tab does not prepaint neighbors at startup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(950, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var active = false;
    late StateSetter rebuild;
    final builtDays = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (_, setState) {
        rebuild = setState;
        return Scaffold(body: PlanningDaySwipeRegion(
          enabled: active,
          visible: active,
          dayKey: '2026-11-10',
          onDayChange: (_) {},
          adjacentDayBuilder: (_, day) {
            builtDays.add(day.day);
            return Text('Cached day ${day.day}');
          },
          child: const Center(child: Text('Visible day')),
        ));
      }),
    ));
    await tester.pump();
    expect(builtDays, isEmpty);
    expect(find.byKey(const ValueKey('planning-side-previous-day')), findsNothing);
    rebuild(() => active = true);
    await tester.pump();
    expect(builtDays, contains(9));
    expect(builtDays, contains(11));
    expect(find.text('Visible day'), findsOneWidget);
  });

  testWidgets('neighbor cards are prepared before horizontal drag', (tester) async {
    await tester.binding.setSurfaceSize(const Size(950, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final builtDays = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanningDaySwipeRegion(
        dayKey: '2026-11-10',
        onDayChange: (_) {},
        adjacentDayBuilder: (_, day) {
          builtDays.add(day.day);
          return Center(child: Text('Full cached plan day ${day.day}'));
        },
        child: const Center(child: Text('Interactive day 10')),
      )),
    ));
    await tester.pump();
    expect(builtDays, contains(9));
    expect(builtDays, contains(11));
    expect(find.text('Interactive day 10'), findsOneWidget);
  });

  testWidgets('native arrow step promotes the new day during motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pager = GlobalKey<PlanningDaySwipeRegionState>();
    final changes = <int>[];
    const contentKey = ValueKey('live-day');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanningDaySwipeRegion(
          key: pager,
          dayKey: '2026-11-09',
          onDayChange: changes.add,
          adjacentDayBuilder: (context, day) => SizedBox.expand(
            child: Center(child: Text('Day ${day.day}')),
          ),
          child: const SizedBox.expand(key: contentKey),
        ),
      ),
    ));

    pager.currentState!.animateToAdjacentDay(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 95));
    final position = tester.widget<PageView>(find.byType(PageView))
        .controller!.page!;
    expect(position, greaterThan(50000.5));
    expect(changes, <int>[1]);
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
  });

  testWidgets('Time mode has one live ScrollController during native swipe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gridScroll = ScrollController();
    addTearDown(gridScroll.dispose);
    String selected = '2026-11-09';
    final changes = <int>[];
    Widget screen() => MaterialApp(
      home: Scaffold(
        body: PlanningDaySwipeRegion(
          dayKey: selected,
          onDayChange: (d) {
            changes.add(d);
            selected = d > 0 ? '2026-11-10' : '2026-11-08';
          },
          adjacentDayBuilder: (ctx, day) => const SizedBox.expand(
            child: ColoredBox(color: Colors.white),
          ),
          child: ListView(
            controller: gridScroll,
            children: const [SizedBox(height: 1800)],
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen());
    expect(gridScroll.positions.length, 1);
    final drag = await tester.startGesture(
      const Offset(700, 350), kind: PointerDeviceKind.touch);
    // Real touch drags deliver a sequence of moves. First slop claims the
    // horizontal arena; subsequent frames physically displace the pager.
    for (var i = 0; i < 12; i++) {
      await drag.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final pager = tester.widget<PageView>(find.byType(PageView));
    expect(pager.controller!.page!, greaterThan(50000.2));
    expect(gridScroll.positions.length, 1);
    await drag.up();
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(gridScroll.positions.length, 1);
  });

  testWidgets('cached next day becomes a tappable real day before release', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var date = DateTime(2026, 11, 10);
    var taps = 0;
    final changes = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        return Scaffold(body: Column(children: [
          const SizedBox(height: 100, child: Text('Fixed header')),
          Expanded(child: PlanningDaySwipeRegion(
            dayKey: dayKey,
            adjacentDayBuilder: (context, day) => Center(
              child: Text('Static cached day ${day.day}')),
            onDayChange: (delta) => setState(() {
              changes.add(delta);
              date = DateTime(date.year, date.month, date.day + delta);
            }),
            child: Center(child: ElevatedButton(
              key: ValueKey('active-day-$dayKey'),
              onPressed: () => taps++,
              child: Text('Interactive $dayKey'),
            )),
          )),
        ]));
      }),
    ));
    final swipe = await tester.startGesture(
      const Offset(760, 360), kind: PointerDeviceKind.touch);
    await swipe.moveBy(const Offset(-50, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await swipe.moveBy(const Offset(-570, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(changes, <int>[1]);
    expect(find.byKey(const ValueKey('active-day-2026-11-11')), findsOneWidget);
    expect(find.text('Fixed header'), findsOneWidget);
    await swipe.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('active-day-2026-11-11')));
    await tester.pump();
    expect(taps, 1);
    expect(find.text('Static cached day 11'), findsNothing);
  });

  testWidgets('settled pager always mounts the real selected day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(980, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = DateTime(2026, 11, 9);
    final commits = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        final day = '${selected.year}-${selected.month.toString().padLeft(2,'0')}-'
            '${selected.day.toString().padLeft(2,'0')}';
        return Scaffold(
          body: Column(children: [
            const SizedBox(height: 100, child: Text('Fixed tags')),
            Expanded(child: PlanningDaySwipeRegion(
              dayKey: day,
              onDayChange: (delta) => setState(() {
                commits.add(delta);
                selected = DateTime(
                  selected.year, selected.month, selected.day + delta);
              }),
              adjacentDayBuilder: (context, day) => Center(
                child: Text('Cached ${day.day}')),
              child: Center(
                key: ValueKey('real-$day'),
                child: Text('Real plan day $day'),
              ),
            )),
          ]),
        );
      }),
    ));
    Future<void> swipeLeft() async {
      final gesture = await tester.startGesture(
        const Offset(760, 370), kind: PointerDeviceKind.touch);
      await gesture.moveBy(const Offset(-45, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(-660, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
    }
    expect(find.text('Real plan day 2026-11-09'), findsOneWidget);
    await swipeLeft();
    expect(find.text('Real plan day 2026-11-10'), findsOneWidget);
    await swipeLeft();
    expect(find.text('Real plan day 2026-11-11'), findsOneWidget);
    expect(find.text('Fixed tags'), findsOneWidget);
    expect(commits, <int>[1, 1]);
  });

  testWidgets('next day resets inherited Time View scroll and shows first row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroll = ScrollController(keepScrollOffset: false);
    addTearDown(scroll.dispose);
    var selectedDay = 9;
    late StateSetter changeSelectedDay;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        changeSelectedDay = setState;
        return Scaffold(
          body: Column(children: [
            const SizedBox(height: 140, child: Text('Fixed tags')),
            Expanded(child: ListView(
              key: ValueKey('time-view-day-$selectedDay'),
              controller: scroll,
              children: [
                SizedBox(height: 65, child: Text('09:00 day $selectedDay')),
                const SizedBox(height: 1500),
              ],
            )),
          ]),
        );
      }),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(200));
    PlanningTimeViewCoordinator.resetAttachedDayScrollToTop(scroll);
    changeSelectedDay(() => selectedDay = 10);
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(tester.getTopLeft(find.text('09:00 day 10')).dy,
        greaterThanOrEqualTo(140));
    expect(tester.getTopLeft(find.text('09:00 day 10')).dy,
        lessThan(220));
    expect(find.text('Fixed tags'), findsOneWidget);
  });

  test('live and cached Time View always pad first hour inside viewport', () {
    final live = File(
      'lib/features/planning/time_view/time_view_hour_grid.dart',
    ).readAsStringSync();
    final cached = File(
      'lib/features/planning/widgets/planning_frozen_day_list.dart',
    ).readAsStringSync();
    final page = File('lib/features/planning/planning_page.dart')
        .readAsStringSync();
    final coordinator = File(
      'lib/features/planning/time_view/planning_time_view_coordinator.dart',
    ).readAsStringSync();
    expect(kPlanningTimeViewTopInsetPx, greaterThanOrEqualTo(10));
    expect(8 + kPlanningTimeViewTopInsetPx - 10, greaterThanOrEqualTo(0));
    expect(live, contains('8 + kPlanningTimeViewTopInsetPx'));
    expect(cached, contains('8 + kPlanningTimeViewTopInsetPx'));
    expect(page, contains('timeView.resetHourGridScrollForNewDay()'));
    expect(coordinator, contains('ScrollController(keepScrollOffset: false)'));
  });

  test('first hour labels and dots never paint outside clipped canvas', () {
    // Both live and swipe-preview timelines use the same safe placement:
    // the original 09:00 marker was centered at -10px above the canvas.
    expect(timeViewSafeHourMarkerTopPx(0, 20), 0);
    expect(timeViewSafeHourMarkerTopPx(0, 8), 0);
    expect(timeViewSafeHourMarkerTopPx(5, 20), 0);
    expect(timeViewSafeHourMarkerTopPx(140, 20), 130);
    expect(timeViewSafeHourMarkerTopPx(140, 8), 136);

    final live = File(
      'lib/features/planning/time_view/time_view_canvas.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/planning/widgets/planning_frozen_day_list.dart',
    ).readAsStringSync();
    expect(live, contains('timeViewSafeHourMarkerTopPx('));
    expect(preview, contains('timeViewSafeHourMarkerTopPx('));
    expect(live, isNot(contains('top: grid.hourLineY(i) - hourLabelHeight / 2')));
    expect(preview, isNot(contains('top: grid.hourLineY(i) - 10')));
  });

  test('read-only adjacent cards retain full play and tracked-progress visuals', () {
    final preview = File(
      'lib/features/planning/widgets/planning_frozen_day_list.dart',
    ).readAsStringSync();
    // The parent IgnorePointer owns input blocking; preview cards still
    // render all controls and the same tracked-progress calculation as live.
    expect('onPlay: () {},'.allMatches(preview).length, 3);
    expect(preview, contains('aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay)'));
    expect(preview, contains('pocketRelationIdOrNull(task.pocketRecordId)'));
    expect(preview, contains('pocketRelationIdOrNull(t.pocketRecordId)'));
    expect(preview, contains("!layout.task.planRowIdForBackend.startsWith('optimistic-')"));
  });

  test('Time swipe preview uses canonical projection, layout and cards', () {
    final source = File(
      'lib/features/planning/widgets/planning_frozen_day_list.dart',
    ).readAsStringSync();
    expect(source, contains('PlanTimeViewLayoutCalculator.compute('));
    expect(source, contains('projectPlanForTimeMode('));
    expect(source, contains('child: PlanCard('));
    expect(source, contains('timelineBlock: true'));
    expect(source, contains('timelineBlockHeightPx: layout.heightPx'));
    expect(source, contains('layout.overlapLaneIndex'));
    expect(source, isNot(contains('static const double _hourPx = 152')));
    expect(source, isNot(contains('task.startTime!.difference(windowStart)')));
  });

  test('Timeline header lives above, not inside, the date PageView', () {
    final source = File('lib/features/timeline/timeline_view.dart')
        .readAsStringSync();
    final wrapper = source.substring(
      source.indexOf('class _TimelineSwipeWrapperState'),
      source.indexOf('class TimelinePage extends'),
    );
    final pageBody = source.substring(
      source.indexOf('class _TimelinePageState'),
    );
    expect(wrapper.indexOf('TimelineHeaderControls('),
        lessThan(wrapper.indexOf('PageView.builder(')));
    expect(wrapper, contains('Expanded('));
    expect(pageBody, isNot(contains('TimelineHeaderControls(')));
  });

  testWidgets('desktop day arrows stay outside sort bar with full body width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <int>[];
    const dayBodyKey = ValueKey('day-content');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [
        PlanningSortModeBar(
          sortMode: PlanSortMode.custom,
          onSortModeChanged: (_) {},
        ),
        Expanded(child: PlanningDaySwipeRegion(
          dayKey: '2026-11-10',
          onDayChange: changes.add,
          adjacentDayBuilder: (context, day) => Center(
            child: Text('Cached ${day.day}')),
          child: const SizedBox.expand(key: dayBodyKey),
        )),
      ])),
    ));
    // The overlay portal attaches its root entry after the first frame.
    await tester.pump();
    final left = find.byKey(const ValueKey('planning-side-previous-day'));
    final right = find.byKey(const ValueKey('planning-side-next-day'));
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(tester.getCenter(left).dx, closeTo(28, 5));
    expect(tester.getCenter(right).dx, closeTo(1072, 5));
    expect(tester.getSize(find.byKey(dayBodyKey)).width, 1100);
    expect(tester.takeException(), isNull);
    await tester.tap(left);
    await tester.pumpAndSettle();
    expect(changes, <int>[-1]);
    await tester.tap(right);
    await tester.pumpAndSettle();
    expect(changes, <int>[-1, 1]);
  });

  testWidgets('side arrows keep position but disable during date lock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanningDaySwipeRegion(
        dayKey: '2026-11-10',
        enabled: false,
        onDayChange: (_) => changes++,
        child: const SizedBox.expand(),
      )),
    ));
    // The overlay portal attaches its root entry after the first frame.
    await tester.pump();
    final left = find.byKey(const ValueKey('planning-side-previous-day'));
    final right = find.byKey(const ValueKey('planning-side-next-day'));
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(tester.getCenter(left).dx, closeTo(28, 5));
    expect(tester.getCenter(right).dx, closeTo(1072, 5));
    await tester.tap(right);
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone uses body swipe, never arrows in sort bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [
        PlanningSortModeBar(
          sortMode: PlanSortMode.custom,
          onSortModeChanged: (_) {},
        ),
        Expanded(child: PlanningDaySwipeRegion(
          onDayChange: (_) {},
          child: const SizedBox.expand(),
        )),
      ])),
    ));
    expect(find.byKey(const ValueKey('planning-side-previous-day')), findsNothing);
    expect(find.byKey(const ValueKey('planning-side-next-day')), findsNothing);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('constrained panels show no overflow side arrows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 520, height: 650,
          child: Column(children: [
            PlanningSortModeBar(
              sortMode: PlanSortMode.custom,
              onSortModeChanged: (_) {},
              desktopTitle: 'Planning',
            ),
            Expanded(child: PlanningDaySwipeRegion(
              onDayChange: (_) {},
              child: const SizedBox.expand(),
            )),
          ]),
        ),
      )),
    ));
    expect(find.byKey(const ValueKey('planning-side-previous-day')), findsNothing);
    expect(find.byKey(const ValueKey('planning-side-next-day')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Planning card width and gutters follow Timeline records', () {
    final planCard = File('lib/core/widgets/plan_card.dart').readAsStringSync();
    final timeline =
        File('lib/features/timeline/timeline_day_page.dart').readAsStringSync();
    final planning =
        File('lib/features/planning/planning_page.dart').readAsStringSync();
    expect(planCard, contains('shellReadableContentMaxWidth(viewportWidth)'));
    expect(timeline, contains('shellReadableContentMaxWidth(viewportWidth)'));
    expect(planCard, contains('2 * kShellDesktopContentHorizontalPadding'));
    expect(planning, contains(': 12,'));
    for (final path in [
      'lib/features/planning/widgets/planning_category_grouped_list.dart',
      'lib/features/planning/widgets/planning_tag_grouped_list.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains(': 12.0;'));
    }
  });

  test('Planning wrapper does not subtract horizontal side-arrow rails', () {
    final shell =
        File('lib/features/planning/planning_page_shell.dart').readAsStringSync();
    expect(shell, contains('return planningPage;'));
    expect(shell, isNot(contains('width: 96')));
    expect(shell, isNot(contains('Expanded(child: planningPage)')));
  });

}
