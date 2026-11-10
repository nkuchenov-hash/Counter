import 'dart:io';

import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/widgets/planning_filter_controls.dart';
import 'package:counter/features/planning/widgets/planning_day_swipe_region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(changes, isEmpty);
    await drag.up();
    await tester.pumpAndSettle();
    expect(changes, <int>[1]);
    expect(tester.getTopLeft(find.byKey(chromeKey)), headerPos);
  });

  testWidgets('native arrow step uses pager motion and commits only at settle', (
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
    final origin = tester.getTopLeft(find.byKey(contentKey)).dx;
    pager.currentState!.animateToAdjacentDay(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 95));
    expect(tester.getTopLeft(find.byKey(contentKey)).dx,
        lessThan(origin - 100));
    expect(changes, isEmpty);
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

  test('Time swipe preview uses canonical projection, layout and cards', () {
    final source = File(
      'lib/features/planning/widgets/planning_frozen_day_list.dart',
    ).readAsStringSync();
    expect(source, contains('PlanTimeViewLayoutCalculator.compute('));
    expect(source, contains('projectPlanForTimeMode('));
    expect(source, contains('PlanTimeTaskCard('));
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

  testWidgets('fixed desktop date controls work without narrowing day body', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(628, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var previous = 0;
    var next = 0;
    const dayBodyKey = ValueKey('day-content');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PlanningSortModeBar(
                sortMode: PlanSortMode.custom,
                onSortModeChanged: (_) {},
                onAdjacentDayRequested: (direction) {
                  if (direction < 0) {
                    previous++;
                  } else {
                    next++;
                  }
                },
              ),
              const Expanded(
                child: ColoredBox(
                  key: dayBodyKey,
                  color: Colors.white,
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    final bodyWidth = tester.getSize(find.byKey(dayBodyKey)).width;
    expect(bodyWidth, 628);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    expect(previous, 1);
    expect(next, 1);
    expect(tester.getSize(find.byKey(dayBodyKey)).width, bodyWidth);
  });

  testWidgets('date navigation keeps its footprint while temporarily locked', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(950, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningSortModeBar(
            sortMode: PlanSortMode.time,
            onSortModeChanged: (_) {},
            onAdjacentDayRequested: (_) => changes++,
            dayNavigationEnabled: false,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layout uses day swipe rather than cramped arrow controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningSortModeBar(
            sortMode: PlanSortMode.custom,
            onSortModeChanged: (_) {},
            onAdjacentDayRequested: (_) {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebars and constrained panels never reveal overflow arrows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 520,
              child: PlanningSortModeBar(
                sortMode: PlanSortMode.custom,
                onSortModeChanged: (_) {},
                desktopTitle: 'Planning',
                onAdjacentDayRequested: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
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
