import 'dart:ui' show PointerDeviceKind;

import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/features/planning/widgets/planning_filter_controls.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Planning toolbar actions and quick-entry share a right edge',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final textController = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(textController.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            PlanningSortModeBar(
              sortMode: PlanSortMode.time,
              onSortModeChanged: (_) {},
              desktopTitle: 'План',
              onSettings: () {},
              onSmart: () {},
              settingsTooltip: 'Settings action',
              smartTooltip: 'Viktor action',
            ),
            PlanningQuickAddChrome(
              desktop: true,
              tagStrip: const SizedBox(height: 40),
              controller: textController,
              focusNode: focusNode,
              hintText: 'Add a plan',
              addLabel: 'Add',
              onAdd: () {},
              loading: false,
            ),
          ],
        ),
      ),
    ));

    final input = find.byType(AppQuickEntryRow);
    final smart = find.byTooltip('Viktor action');
    expect(input, findsOneWidget);
    expect(smart, findsOneWidget);

    // Both chrome rows are centered within the same 1240 px maximum.
    expect(
      tester.getTopLeft(find.text('План')).dx,
      closeTo(tester.getTopLeft(input).dx, 1),
    );
    expect(
      tester.getTopRight(smart).dx,
      closeTo(tester.getTopRight(input).dx, 1),
    );
  });

  testWidgets('inactive Planning mode hover changes text color only',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanningSortModeBar(
          sortMode: PlanSortMode.time,
          onSortModeChanged: (_) {},
          desktopTitle: 'План',
          onSettings: () {},
          onSmart: () {},
          settingsTooltip: 'Settings action',
          smartTooltip: 'Viktor action',
        ),
      ),
    ));

    final inactive = find.text(t(currentLocale.value, 'plan_sort_category'));
    expect(inactive, findsOneWidget);
    final ink = find.ancestor(
      of: inactive,
      matching: find.byType(InkWell),
    );
    expect(ink, findsNothing);

    Color? tabTextColor() {
      final animated = find.ancestor(
        of: inactive,
        matching: find.byType(AnimatedDefaultTextStyle),
      ).first;
      return tester.widget<AnimatedDefaultTextStyle>(animated).style.color;
    }

    final scheme = Theme.of(tester.element(inactive)).colorScheme;
    final before = tabTextColor();
    expect(before, isNot(scheme.onSurface));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(inactive));
    await tester.pumpAndSettle();
    expect(tabTextColor(), scheme.onSurface);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tabTextColor(), before);
    await mouse.removePointer();
  });
}
