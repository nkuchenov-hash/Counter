import 'dart:io';

import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/widgets/planning_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
                desktopTitle: 'Plans',
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
