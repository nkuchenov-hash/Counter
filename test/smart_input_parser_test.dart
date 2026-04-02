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
}
