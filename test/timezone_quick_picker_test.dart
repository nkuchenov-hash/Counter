import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:counter/core/widgets/app_timezone_icon.dart';
import 'package:counter/core/widgets/timezone_quick_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  testWidgets('timezone picker row includes AppTimezoneIcon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimezonePickerOptionRow(
            entry: kProfileTimezoneCatalog[1],
            selected: false,
          ),
        ),
      ),
    );

    expect(find.byType(AppTimezoneIcon), findsOneWidget);
    expect(find.text('London · LON'), findsOneWidget);
  });

  testWidgets('selected timezone picker row includes checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimezonePickerOptionRow(
            entry: kProfileTimezoneCatalog[4],
            selected: true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(AppTimezoneIcon), findsOneWidget);
  });
}
