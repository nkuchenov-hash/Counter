import 'package:counter/features/timeline/timeline_workspace_day_arrows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Timeline arrows occupy workspace gutters outside sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1641, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const navWidth = 272.0;
    final steps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [
        const SizedBox(width: navWidth, child: Text('Permanent sidebar')),
        Expanded(child: TimelineWorkspaceDayArrows(
          visible: true,
          onStep: steps.add,
          child: const SizedBox.expand(key: ValueKey('full-timeline-page')),
        )),
      ])),
    ));
    await tester.pump();
    final left = find.byKey(const ValueKey('timeline-side-previous-day'));
    final right = find.byKey(const ValueKey('timeline-side-next-day'));
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    final canvas = find.byKey(const ValueKey('full-timeline-page'));
    final leftX = tester.getCenter(left).dx;
    final rightX = tester.getCenter(right).dx;
    final expectedFrameLeft = navWidth + ((1641 - navWidth) - 960) / 2;
    final expectedFrameRight = expectedFrameLeft + 960;
    expect(tester.getSize(canvas).width, 1641 - navWidth);
    expect(leftX, greaterThan(navWidth + 24));
    expect(leftX, lessThan(expectedFrameLeft - 24));
    expect(leftX, closeTo((navWidth + expectedFrameLeft) / 2, 5));
    expect(rightX, greaterThan(expectedFrameRight + 24));
    expect(rightX, lessThan(1641 - 24));
    expect(rightX, closeTo((expectedFrameRight + 1641) / 2, 5));
    await tester.tap(left);
    await tester.tap(right);
    expect(steps, <int>[-1, 1]);
  });

  testWidgets('Timeline arrows never appear on mobile or hidden tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TimelineWorkspaceDayArrows(
        visible: true,
        onStep: (_) {},
        child: const SizedBox.expand(),
      )),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('timeline-side-previous-day')), findsNothing);
    expect(find.byKey(const ValueKey('timeline-side-next-day')), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1400, 800));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TimelineWorkspaceDayArrows(
        visible: false,
        onStep: (_) {},
        child: const SizedBox.expand(),
      )),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('timeline-side-previous-day')), findsNothing);
    expect(find.byKey(const ValueKey('timeline-side-next-day')), findsNothing);
  });
}
