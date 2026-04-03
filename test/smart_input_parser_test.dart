import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmartInputParser 13:40 style', () {
    test('ASCII dot 13.40 keeps minutes', () {
      final r = SmartInputParser.parseTitleForScheduledTime('задача 13.40');
      expect(r, isNotNull);
      expect(r!.hour, 13);
      expect(r.minute, 40);
    });

    test('fullwidth dot normalizes', () {
      final r = SmartInputParser.parseTitleForScheduledTime('задача 13．40');
      expect(r, isNotNull);
      expect(r!.minute, 40);
    });

    test('comma between hour and minute (EU style)', () {
      final r = SmartInputParser.parseTitleForScheduledTime('задача 13,40');
      expect(r, isNotNull);
      expect(r!.minute, 40);
    });
  });

  group('SmartInputParser time ranges', () {
    test('from 10 to 2 → end afternoon same day', () {
      final r = SmartInputParser.parseTitleForTimeRange('reading from 10 to 2');
      expect(r, isNotNull);
      expect(r!.cleanedTitle, 'reading');
      expect(r.startHour, 10);
      expect(r.startMinute, 0);
      expect(r.endHour, 14);
      expect(r.endMinute, 0);
    });

    test('9to12 compact', () {
      final r = SmartInputParser.parseTitleForTimeRange('work 9to12');
      expect(r, isNotNull);
      expect(r!.cleanedTitle, 'work');
      expect(r.startHour, 9);
      expect(r.endHour, 12);
    });

    test('9:00-12:30 dash', () {
      final r = SmartInputParser.parseTitleForTimeRange('call 9:00-12:30');
      expect(r, isNotNull);
      expect(r!.endHour, 12);
      expect(r.endMinute, 30);
    });

    test('Russian с … до …', () {
      final r =
          SmartInputParser.parseTitleForTimeRange('уборка с 9 до 12');
      expect(r, isNotNull);
      expect(r!.cleanedTitle, 'уборка');
      expect(r.startHour, 9);
      expect(r.endHour, 12);
    });

    test('с 9:00 до 14:00', () {
      final r = SmartInputParser.parseTitleForTimeRange('задача с 9:00 до 14:00');
      expect(r, isNotNull);
      expect(r!.endHour, 14);
    });

    test('from 9:30 to 2 afternoon end', () {
      final r = SmartInputParser.parseTitleForTimeRange('x from 9:30 to 2');
      expect(r, isNotNull);
      expect(r!.endHour, 14);
      expect(r.endMinute, 0);
    });

    test('from9to5 contiguous EN (end shifts +12 when before start)', () {
      final r = SmartInputParser.parseTitleForTimeRange('from9to5');
      expect(r, isNotNull);
      expect(r!.startHour, 9);
      expect(r.endHour, 17);
      expect(r.endMinute, 0);
      expect(r.cleanedTitle, isEmpty);
    });

    test('с11до12 contiguous RU', () {
      final r = SmartInputParser.parseTitleForTimeRange('с11до12');
      expect(r, isNotNull);
      expect(r!.startHour, 11);
      expect(r.endHour, 12);
      expect(r.cleanedTitle, isEmpty);
    });
  });
}
