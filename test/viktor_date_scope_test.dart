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


  test('Current today uses profile day, never a stale calendar tab', () {
    final today = DateTime(2026, 10, 28);
    final visible = DateTime(2026, 10, 24);
    expect(ViktorDateScope.key(ViktorDateScope.itineraryDay(
      'Сегодня утром была зарядка и душ', visible, history,
      profileToday: today,
    )), '2026-10-28');
    expect(ViktorDateScope.key(ViktorDateScope.itineraryDay(
      'Запиши вчерашние дела', visible, history,
      profileToday: today,
    )), '2026-10-27');
    expect(ViktorDateScope.key(ViktorDateScope.itineraryDay(
      'Покажи дела на послезавтра', visible, history,
      profileToday: today,
    )), '2026-10-30');
  });

  test('28 October backfill follow-up retains the original day after midnight', () {
    final prior = <Map<String, String>>[
      {'role': 'user', 'message_day': '2026-10-24',
       'content': 'Распланируй субботу 24 октября 2026'},
      {'role': 'assistant', 'content': 'Составил расписание'},
      {'role': 'user', 'message_day': '2026-10-28',
       'content': 'Между просыпанием и Atozed Clients сегодня у меня были '
           'зарядка, поиск в интернете, заказ свечей, кофе, умывание и душ'},
      {'role': 'assistant', 'content': 'Найду реальные границы'},
    ];
    final day = ViktorDateScope.itineraryDay(
      'Добавь эти записи тоже', DateTime(2026, 10, 24),
      prior, profileToday: DateTime(2026, 10, 29),
    );
    expect(ViktorDateScope.key(day), '2026-10-28');
    expect(ViktorDateScope.key(ViktorDateScope.itineraryDay(
      'Добавь эти записи за 30 октября 2026 года',
      DateTime(2026, 10, 24), prior, profileToday: DateTime(2026, 10, 29),
    )), '2026-10-30');
    expect(ViktorDateScope.key(ViktorDateScope.itineraryDay(
      'Сегодня добавь эти записи', DateTime(2026, 10, 24),
      prior, profileToday: DateTime(2026, 10, 29),
    )), '2026-10-29');
  });

  test('Legacy undated today is never assigned a made-up original date', () {
    final old = <Map<String, String>>[
      {'role': 'user',
       'content': 'Сегодня делал зарядку и заказывал свечи'},
    ];
    final visible = DateTime(2026, 10, 24);
    expect(ViktorDateScope.key(ViktorDateScope.itineraryDay(
      'Добавь эти записи тоже', visible, old,
      profileToday: DateTime(2026, 10, 29),
    )), '2026-10-24');
  });

  test('Conflicting relative dates do not silently choose one day', () {
    final visible = DateTime(2026, 10, 24);
    expect(ViktorDateScope.key(ViktorDateScope.itineraryDay(
      'Не сегодня, а завтра или послезавтра?',
      visible, history, profileToday: DateTime(2026, 10, 28),
    )), '2026-10-24');
  });

}
