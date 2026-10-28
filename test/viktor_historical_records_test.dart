import 'package:counter/data/ai/viktor_historical_records.dart';
import 'package:counter/data/ai/viktor_date_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('The exact failed follow-up creates six historical records, not plans', () {
    final intent = ViktorHistoricalRecordIntent.parse(
      'Добавь эти записи тоже',
      const [
        {'role': 'user', 'message_day': '2026-10-28', 'content':
          'Между просыпанием и Atozed Clients сегодня у меня была '
          'зарядка, поиск информации в Интернете, заказ подарка свечей, '
          'Утренний кофе, умывание и душ.'},
      ],
      DateTime(2026, 10, 28),
    );
    expect(intent, isNotNull);
    expect(ViktorDateScope.key(intent!.day), '2026-10-28');
    expect(intent.beforeTitle, 'просыпанием');
    expect(intent.afterTitle, 'Atozed Clients');
    expect(intent.titles, [
      'зарядка', 'поиск информации в Интернете',
      'заказ подарка свечей', 'Утренний кофе', 'умывание', 'душ',
    ]);
  });

  test('Past records are not inferred from unrelated drafts', () {
    expect(ViktorHistoricalRecordIntent.parse(
      'Добавь эти записи тоже', const [
        {'role': 'assistant', 'content': '2026-10-24 расписание 17:00'},
      ], DateTime(2026, 10, 28)), isNull);
  });

  test('Completed intervals are sequential and exactly fill inspected gap', () {
    final a = DateTime.utc(2026, 10, 28, 5, 10);
    final b = DateTime.utc(2026, 10, 28, 6, 50);
    final slots = ViktorHistoricalRecords.splitGap(
        a, b, ['Зарядка', 'Кофе', 'Душ']);
    expect(slots.length, 3);
    expect(slots.first.start, a);
    expect(slots.last.end, b);
    for (var i = 1; i < slots.length; i++) {
      expect(slots[i].start, slots[i - 1].end);
    }
    expect(slots.every((s) => s.end.isAfter(s.start)), isTrue);
  });

  test('Historical backfill never invents impossible time intervals', () {
    expect(() => ViktorHistoricalRecords.splitGap(
      DateTime.utc(2026, 10, 28, 5, 0),
      DateTime.utc(2026, 10, 28, 5, 10),
      List.filled(6, 'record'),
    ), throwsStateError);
  });
}
