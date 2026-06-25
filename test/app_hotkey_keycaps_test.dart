import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppHotkeyKeycaps keeps desktop keycaps in a horizontal row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AppHotkeyKeycaps(label: 'Ctrl + Shift + Space'),
          ),
        ),
      ),
    );

    expect(find.byType(Row), findsOneWidget);
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);
    expect(find.text('+'), findsNWidgets(2));
  });
}
