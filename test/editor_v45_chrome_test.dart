import 'package:counter/features/shared/edit_sheet/editor_v45_chrome.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test('range formatter tolerates unset endpoints', () {
    expect(editorV45Range(null, null), '');
    expect(editorV45Time(null), '—:—');
    expect(editorV45Range(DateTime(2026, 11, 27, 18, 30),
        DateTime(2026, 11, 27, 19, 45)), '18:30 — 19:45');
  });

  testWidgets('B1 shows both times, duration and working endpoints', (tester) async {
    var startTapped = false;
    var endTapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 350, child: EditorV45TimeCard(
        start: DateTime(2026, 11, 27, 18, 30),
        end: DateTime(2026, 11, 27, 19, 45),
        onStart: (_) => startTapped = true,
        onEnd: (_) => endTapped = true,
      )),
    ))));
    expect(find.text('18:30'), findsOneWidget);
    expect(find.text('19:45'), findsOneWidget);
    expect(find.text(currentLocale.value == 'ru' ? '1 ч 15 мин' : '1 h 15 min'), findsOneWidget);
    await tester.tap(find.text('18:30'));
    await tester.tap(find.text('19:45'));
    expect(startTapped, isTrue);
    expect(endTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating and closing use provided host actions', (tester) async {
    var created = false;
    var cancelled = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditorV45Actions(
      primaryLabel: 'Create record',
      onPrimary: () => created = true,
      onCancel: () => cancelled = true,
    ))));
    await tester.tap(find.text('Create record'));
    await tester.tap(find.text(t(currentLocale.value, 'cancel')));
    expect(created, isTrue);
    expect(cancelled, isTrue);
  });
}
