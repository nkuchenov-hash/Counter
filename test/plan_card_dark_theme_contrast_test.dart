import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  Future<void> pumpCardControls(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? appDarkTheme : appLightTheme,
        home: Scaffold(
          body: Column(
            children: [
              const PlanCardTitleRow(
                title: 'MISSION IT Refresh 33 Check',
                displayIsDone: false,
                hasRepeat: false,
                maxLines: 1,
              ),
              const PlanCardTimeText(label: '17:00 – 17:30'),
              const PlanCardFooterRow(
                categoryTrail: 'Работа',
                categoryColor: Color(0xFF286BE3),
                timeLabel: '',
                scheduleConflict: false,
              ),
              PlanCardCheckbox(
                selectMode: false,
                isSelected: false,
                displayIsDone: false,
                toggleDoneEnabled: true,
                onToggleDone: () {},
              ),
              PlanCardPlayButton(onPlay: () {}),
              PlanCardMenuButton(onOpenMenu: (_) {}),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('dark plan card keeps title and time readable', (tester) async {
    await pumpCardControls(tester, dark: true);
    final scheme = appDarkTheme.colorScheme;
    final titleStyle = tester.widget<AnimatedDefaultTextStyle>(
      find.descendant(
        of: find.byType(PlanCardTitleRow),
        matching: find.byType(AnimatedDefaultTextStyle),
      ),
    );
    expect(titleStyle.style.color, scheme.onSurface);

    final time = tester.widget<Text>(find.text('17:00 – 17:30'));
    expect(time.style!.color, scheme.onSurfaceVariant);

    final breadcrumb = tester.widget<Text>(find.text('Работа'));
    expect(
      contrastRatio(breadcrumb.style!.color!, scheme.surfaceContainerHigh),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('dark plan card controls use dark surfaces and visible icons', (tester) async {
    await pumpCardControls(tester, dark: true);
    final scheme = appDarkTheme.colorScheme;
    final checkbox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(PlanCardCheckbox),
        matching: find.byType(DecoratedBox),
      ),
    );
    final checkboxDecoration = checkbox.decoration as BoxDecoration;
    expect(checkboxDecoration.color, scheme.surfaceContainerHigh);
    expect(checkboxDecoration.border!.top.color, scheme.onSurfaceVariant);

    final menu = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(PlanCardMenuButton),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((menu.decoration as BoxDecoration).color, isNot(PlanCardTokens.menuBg));
    final menuIcon = tester.widget<Icon>(find.byIcon(Icons.more_vert_rounded));
    expect(menuIcon.color, scheme.onSurface);

    final iconPaint = tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(PlanCardPlayButton),
        matching: find.byType(CustomPaint),
      ),
    ).firstWhere((paint) => paint.painter is PlanCardPlayIconPainter);
    expect(
      (iconPaint.painter! as PlanCardPlayIconPainter).fill,
      scheme.onSurfaceVariant,
    );
  });

  testWidgets('light plan card retains the existing canonical colors', (tester) async {
    await pumpCardControls(tester, dark: false);
    final titleStyle = tester.widget<AnimatedDefaultTextStyle>(
      find.descendant(
        of: find.byType(PlanCardTitleRow),
        matching: find.byType(AnimatedDefaultTextStyle),
      ),
    );
    expect(titleStyle.style.color, PlanCardTokens.titleColor);
    expect(
      tester.widget<Text>(find.text('17:00 – 17:30')).style!.color,
      PlanCardTokens.timeColor,
    );
    final checkbox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(PlanCardCheckbox),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((checkbox.decoration as BoxDecoration).color, Colors.white);
  });
}
