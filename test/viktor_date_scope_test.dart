import 'package:counter/data/ai/viktor_date_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('UTC plan instant projects to Moscow rather than NY clock', () {
    final utc = DateTime.utc(2026, 10, 24, 17);
    final moscow = ViktorDateScope.projectUtcInstant(utc, 'Europe/Moscow');
    final newYork = ViktorDateScope.projectUtcInstant(
        utc, 'America/New_York');
    expect(ViktorDateScope.key(moscow), '2026-10-24');
    expect(moscow.hour, 20);
    expect(newYork.hour, 13);
    expect(utc.hour, 17, reason: 'Source instant must remain unchanged');
  });

  test('Cross-midnight saved instants land on next Moscow date', () {
    final utc = DateTime.utc(2026, 10, 24, 22, 30);
    final local = ViktorDateScope.projectUtcInstant(utc, 'Europe/Moscow');
    expect(ViktorDateScope.key(local), '2026-10-25');
    expect(local.hour, 1);
    expect(local.minute, 30);
  });

  final history = <Map<String, String>>[
    {'role':'user', 'content':
      'Распланируй мою субботу, 24 октября 2026 года. '
      'ЗАГС, купить тыквы, отвезти в бар, машину домой, RCC.'},
    {'role':'assistant', 'content':
      '2026-10-24\n10:00–10:30 Зарядка\n'
      '13:00–14:00 Тыквы\n20:00–21:00 RCC\n'
      '2026-10-25\n00:30–01:00 Сон'},
  ];

  test('Natural Russian date overrides visible calendar tab', () {
    final day = ViktorDateScope.itineraryDay(
        'Распланируй 24 октября 2026 года', DateTime(2026, 10, 23),
        history);
    expect(ViktorDateScope.key(day), '2026-10-24');
  });

  test('Follow-up inherits original schedule day rather than sleep date', () {
    final day = ViktorDateScope.itineraryDay(
        'И где покупка тыкв на Сенной?', DateTime(2026, 10, 23),
        history, revision: true);
    expect(ViktorDateScope.key(day), '2026-10-24');
  });

  test('Explicit new ISO day beats historic draft', () {
    final day = ViktorDateScope.itineraryDay(
        '31 октября 2026 перенеси', DateTime(2026, 10, 23),
        history, revision: true);
    expect(ViktorDateScope.key(day), '2026-10-31');
  });

  test('Unrelated requests still use visible calendar day', () {
    final day = ViktorDateScope.itineraryDay(
        'Покажи категории', DateTime(2026, 10, 23), history);
    expect(ViktorDateScope.key(day), '2026-10-23');
  });
  test('Two weeks from profile today creates a standalone 7 November plan', () {
    final today = DateTime(2026, 10, 24);
    const command = 'добавь план через две недели от сегодняшнего дня '
        'сходить в альфа банк отделение узнать статус нового заявления';
    final parsed = ViktorDateScope.independentDateOnlyPlan(command, today);
    expect(parsed, isNotNull);
    expect(ViktorDateScope.key(parsed!.day), '2026-11-07');
    expect(parsed.title, 'Сходить в альфа банк отделение узнать статус нового заявления');
    final resolved = ViktorDateScope.itineraryDay(
      command, DateTime(2026, 10, 24), history,
      profileToday: today,
    );
    expect(ViktorDateScope.key(resolved), '2026-11-07');
  });

  test('Independent plans do not inherit a stale draft date or guess time', () {
    final today = DateTime(2026, 10, 24);
    expect(ViktorDateScope.independentDateOnlyPlan(
        'добавь план через 2 недели посетить банк', today)?.title,
        'Посетить банк');
    expect(ViktorDateScope.independentDateOnlyPlan(
        'добавь план через две недели в 14:30 посетить банк', today), isNull);
    expect(ViktorDateScope.independentDateOnlyPlan(
        'добавь в наш черновик поход в банк', today), isNull);
    expect(ViktorDateScope.key(ViktorDateScope.relativeDay(
        'через три дня', today)!), '2026-10-27');
  });

}
