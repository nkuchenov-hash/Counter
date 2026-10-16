import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => currentLocale.value = 'en');

  Future<void> openPicker(WidgetTester tester, ValueChanged<DateTime> onPicked) async {
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

  testWidgets('date header shows calendar and editable date together', (tester) async {
    await openPicker(tester, (_) {});

    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('OK'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '17.10.2026');
  });

  testWidgets('calendar selection navigates without OK confirmation', (tester) async {
    DateTime? selected;
    await openPicker(tester, (date) => selected = date);

    final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    picker.onDateChanged(DateTime(2026, 10, 18));
    expect(selected, DateTime(2026, 10, 18));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
  });

  testWidgets('manual date entry navigates on keyboard Go', (tester) async {
    DateTime? selected;
    await openPicker(tester, (date) => selected = date);

    await tester.enterText(find.byType(TextField), '24.10.2026');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    expect(selected, DateTime(2026, 10, 24));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
  });

  testWidgets('invalid manual date keeps the calendar open', (tester) async {
    DateTime? selected;
    await openPicker(tester, (date) => selected = date);

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
}
