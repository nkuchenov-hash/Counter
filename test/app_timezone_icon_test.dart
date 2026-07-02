import 'package:counter/core/widgets/app_timezone_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppTimezoneIcon renders every key at supported sizes', (
    tester,
  ) async {
    for (final key in AppTimezoneIconKey.values) {
      for (final size in <double>[24, 32, 40]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppTimezoneIcon(timezoneKey: key, size: size),
              ),
            ),
          ),
        );

        expect(find.byType(AppTimezoneIcon), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
