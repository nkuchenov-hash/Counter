import 'dart:io';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/features/timeline/timeline_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Timeline date arrows are in both workspace gutters, outside records and sidebar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1641, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [
        const SizedBox(
          width: kShellSideNavWidth,
          child: Text('Permanent sidebar'),
        ),
        Expanded(child: TimelineWorkspaceDayArrows(
          visible: true,
          enabled: true,
          onPrevious: () => previous++,
          onNext: () => next++,
          child: PageView(children: const [
            SizedBox.expand(key: ValueKey('timeline-original-full-width-page')),
            SizedBox.expand(),
          ]),
        )),
      ])),
    ));
    await tester.pump();
    final left = find.byKey(const ValueKey('timeline-side-previous-day'));
    final right = find.byKey(const ValueKey('timeline-side-next-day'));
    final page = find.byType(PageView);
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(tester.getSize(page).width, 1641 - kShellSideNavWidth);

    final contentLeft =
        kShellSideNavWidth + ((1641 - kShellSideNavWidth) - 960) / 2 +
            kShellDesktopContentHorizontalPadding;
    final contentRight = 1641 - (contentLeft - kShellSideNavWidth);
    final leftX = tester.getCenter(left).dx;
    final rightX = tester.getCenter(right).dx;
    expect(leftX, closeTo((kShellSideNavWidth + contentLeft) / 2, 6));
    expect(rightX, closeTo((contentRight + 1641) / 2, 6));
    expect(tester.getRect(left).left, greaterThan(kShellSideNavWidth));
    expect(tester.getRect(left).right, lessThan(contentLeft));
    expect(tester.getRect(right).left, greaterThan(contentRight));
    expect(tester.getRect(right).right, lessThan(1641));

    await tester.tap(left);
    await tester.pump();
    await tester.tap(right);
    await tester.pump();
    expect(previous, 1);
    expect(next, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow desktop never covers Timeline cards with arrows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [
        const SizedBox(width: kShellSideNavWidth),
        Expanded(child: TimelineWorkspaceDayArrows(
          visible: true,
          enabled: true,
          onPrevious: () {},
          onNext: () {},
          child: PageView(children: const [
            SizedBox.expand(),
            SizedBox.expand(),
          ]),
        )),
      ])),
    ));
    await tester.pump();
    expect(tester.getSize(find.byType(PageView)).width,
        1100 - kShellSideNavWidth);
    expect(find.byKey(const ValueKey('timeline-side-previous-day')), findsNothing);
    expect(find.byKey(const ValueKey('timeline-side-next-day')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden Timeline paints no arrows and preserves vertical scroll',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1641, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroller = ScrollController();
    addTearDown(scroller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [
        const SizedBox(width: kShellSideNavWidth),
        Expanded(child: TimelineWorkspaceDayArrows(
          visible: false,
          enabled: false,
          onPrevious: () {},
          onNext: () {},
          child: ListView(
            controller: scroller,
            children: const [SizedBox(height: 1700, child: Text('Timeline rows'))],
          ),
        )),
      ])),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('timeline-side-previous-day')), findsNothing);
    expect(find.byKey(const ValueKey('timeline-side-next-day')), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(scroller.offset, greaterThan(0));
  });

  test('Timeline owns native PageView and its arrow route, not a replacement pager', () {
    final source = File('lib/features/timeline/timeline_view.dart')
        .readAsStringSync();
    expect(source, contains('child: TimelineWorkspaceDayArrows('));
    expect(source, contains('child: PageView.builder('));
    expect(source, contains('_navigateBySideArrow(-1)'));
    expect(source, contains('_navigateBySideArrow(1)'));
    expect(source, contains('_settleGate.onPageSettled('));
    expect(source, contains('workspace'));
  });
}
