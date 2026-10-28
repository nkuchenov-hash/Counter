import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:counter/core/widgets/app_timezone_icon.dart';
import 'package:counter/core/widgets/timezone_quick_picker.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/l10n/dictionary.dart';
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

  group('global header date picker', () {
    setUp(() => currentLocale.value = 'en');

    Future<void> openHeaderPicker(
      WidgetTester tester,
      ValueChanged<DateTime> onPicked,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlobalAppHeader(
                selectedDate: DateTime(2026, 10, 17),
                onDateSelected: onPicked,
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(GlobalAppHeader),
          matching: find.byType(InkWell),
        ).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('calendar and manual input appear together without OK', (tester) async {
      await openHeaderPicker(tester, (_) {});
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '17.10.2026',
      );
    });

    testWidgets('calendar selection dispatches immediately and closes', (tester) async {
      DateTime? selected;
      await openHeaderPicker(tester, (date) => selected = date);
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      picker.onDateChanged(DateTime(2026, 10, 18));
      expect(selected, DateTime(2026, 10, 18));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsNothing);
    });

    testWidgets('manual Go submits a valid date', (tester) async {
      DateTime? selected;
      await openHeaderPicker(tester, (date) => selected = date);
      await tester.enterText(find.byType(TextField), '24.10.2026');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      expect(selected, DateTime(2026, 10, 24));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsNothing);
    });

    testWidgets('invalid manual date leaves calendar open', (tester) async {
      DateTime? selected;
      await openHeaderPicker(tester, (date) => selected = date);
      await tester.enterText(find.byType(TextField), '31.02.2026');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump();
      expect(selected, isNull);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.errorText,
        isNotNull,
      );
    });
  });
}
