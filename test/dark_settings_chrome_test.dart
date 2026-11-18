import 'package:counter/core/app_colors.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final high = a > b ? a : b;
  final low = a > b ? b : a;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  test('dark palette has a complete ordered surface and text hierarchy', () {
    final scheme = AppColors.darkColorScheme();
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.surface, AppColors.darkAppBackground);
    expect(scheme.surface, isNot(Colors.black));
    expect(scheme.surfaceContainer, AppColors.darkCardSurface);
    expect(scheme.surface.computeLuminance(),
        lessThan(scheme.surfaceContainerLow.computeLuminance()));
    expect(scheme.surfaceContainerLow.computeLuminance(),
        lessThan(scheme.surfaceContainer.computeLuminance()));
    expect(scheme.surfaceContainer.computeLuminance(),
        lessThan(scheme.surfaceContainerHigh.computeLuminance()));
    expect(scheme.surfaceContainerHigh.computeLuminance(),
        lessThan(scheme.surfaceContainerHighest.computeLuminance()));
    expect(_contrastRatio(scheme.onSurface, scheme.surfaceContainerHigh),
        greaterThanOrEqualTo(7));
    expect(_contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(7));
  });

  testWidgets('dark frosted Back is clipped to 48dp without a shadow halo',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
      theme: appDarkTheme,
      home: Scaffold(
        body: Center(
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => presses++,
            size: AppIconButtonSize.l,
            shape: AppIconButtonShape.circular,
            variant: AppIconButtonVariant.frosted,
          ),
        ),
      ),
    ));

    final control = find.byType(AppIconButton);
    final clipped = find.descendant(of: control, matching: find.byType(ClipOval));
    final blur = find.descendant(
      of: control, matching: find.byType(BackdropFilter));
    expect(tester.getSize(control), const Size(48, 48));
    expect(clipped, findsOneWidget);
    expect(blur, findsOneWidget);
    expect(tester.getSize(clipped), const Size(48, 48));

    final decorations = tester.widgetList<DecoratedBox>(
      find.descendant(of: control, matching: find.byType(DecoratedBox)));
    for (final box in decorations) {
      if (box.decoration case BoxDecoration(:final boxShadow)) {
        expect(boxShadow, isNull,
            reason: 'Frosted Back must not paint a halo beyond its circle');
      }
    }
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(presses, 1);
  });
}
