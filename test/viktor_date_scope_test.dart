import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_date_scope.dart';
import 'package:counter/data/ai/viktor_executor.dart';
import 'package:counter/data/ai/viktor_existing_plan.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('Forwarded appointment note uses native editable blocks and mirrors', () {
    const source = 'Запись на 07/12 в 10-00 ЛОР. Клиника Пример, '
        'ул. Примерная, 9, телефон 8(812)000-00-00 '
        'подойти за 30 минут в регистратуру ДМС с собой паспорт родителя, '
        'полис, СНИЛС, маска и мед. Документы';
    final doc = viktorPlanNoteDocument(source);
    expect(doc.blocks.where((b) => b.type == NoteBlockType.heading)
        .map((b) => b.text), ['Информация', 'Перед посещением', 'С собой']);
    expect(doc.blocks.where((b) => b.type == NoteBlockType.divider), hasLength(2));
    expect(doc.toChecklistProjection(), [
      {'text': 'паспорт родителя', 'done': false},
      {'text': 'полис', 'done': false},
      {'text': 'СНИЛС', 'done': false},
      {'text': 'маска', 'done': false},
      {'text': 'мед. Документы', 'done': false},
    ]);
    final restored = NoteDocument.tryParse(
        notesDeltaJson: doc.encode(), notesPlain: doc.toPlainText(),
        checklist: doc.toChecklistProjection());
    expect(restored.toChecklistProjection(), doc.toChecklistProjection());
    expect(restored.blocks.where((b) => b.type == NoteBlockType.divider),
        hasLength(2));
    expect(restored.toPlainText(), contains('подойти за 30 минут'));
    expect(restored.toPlainText(), contains('8(812)000-00-00'));
    expect(restored.blocks.map((b) => b.id).toSet().length, doc.blocks.length);
  });

  test('Provider note formatting creates canonical headings and checkboxes', () {
    final doc = viktorPlanNoteDocument(
        '## Подготовка\n- [ ] Документы\n---\nОбычный текст');
    expect(doc.blocks.map((b) => b.type), [
      NoteBlockType.heading, NoteBlockType.checklist,
      NoteBlockType.divider, NoteBlockType.paragraph,
    ]);
    expect(doc.toChecklistProjection(), [{'text': 'Документы', 'done': false}]);
    expect(viktorPlanNoteDocument('Обычная заметка').blocks.single.text,
        'Обычная заметка');
  });


  test('Forwarded Russian appointment keeps clock, date and all instructions', () {
    const message = 'Запись на 07/12 в 10-00 оперирующий ЛОР. '
        'Клиника Пример, г СПб, ул. Примерная, 9, телефон 8(812)000-00-00 '
        'подойти за 30 минут до приёма, с собой паспорт, полис, СНИЛС.';
    final result = ViktorDateScope.forwardedTimedPlan(
        input: message, profileToday: DateTime(2026, 11, 25),
        requestId: 'viktor_test_appointment');
    expect(result, isNotNull);
    final args = result!.actions.single.arguments;
    expect(args['wall_day'], '2026-12-07');
    expect(args['start_time'], '10:00');
    expect(args['duration_minutes'], 30);
    expect(args['title'], 'Запись: оперирующий ЛОР.');
    expect(args['note'], message);
    expect(args['timezone'], 'Europe/Moscow');
    expect(args['conflict_policy'], 'reject');
  });

  test('Forwarded booking supports dotted and named dates, including year rollover', () {
    ViktorActionBatch? parse(String input) => ViktorDateScope.forwardedTimedPlan(
        input: input, profileToday: DateTime(2026, 12, 30),
        requestId: 'viktor_test_booking');
    expect(parse('Бронь на 02.01 в 19:30 Ресторан')!
        .actions.single.arguments['wall_day'], '2027-01-02');
    expect(parse('Встреча 2 января 2027 в 9:05 Проект')!
        .actions.single.arguments['start_time'], '09:05');
    expect(parse('Запись на 31/02 в 10:00 Приём'), isNull);
    expect(parse('Запись на 02/01/2026 в 10:00 Приём'), isNull);
    expect(parse('Запись на 02/01 в 25:00 Приём'), isNull);
    expect(parse('Запись на 02/01 в 10:00 Приём?'), isNull);
    expect(parse('Запись на 02/01 в 10:00 Приём до 11:00'), isNull);
    expect(parse('Запись на 02/01 в 10:00 Приём 45 минут'), isNull);
    expect(parse('Запись на 02/01 в 10:00 Приём отменён'), isNull);
    expect(parse('Перенеси запись на 02/01 в 10:00 Приём'), isNull);
  });


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


  test('Screenshot: November 2 produces ONE untimed plan, not a timetable', () {
    final today = DateTime(2026, 10, 28);
    final plan = ViktorDateScope.independentDateOnlyPlan(
      'November 2 - new plan LS Screening remind John to sign the Cover Letter',
      today,
    );
    expect(plan, isNotNull);
    expect(ViktorDateScope.key(plan!.day), '2026-11-02');
    expect(plan.title, 'LS Screening remind John to sign the Cover Letter');
    // No Moscow clock, previous October 28 Records or November 11 bank plan
    // can enter the action: the parser only returns this date and title.
  });

  test('Single dated plan handles EN/RU phrasing and year rollover', () {
    final today = DateTime(2026, 10, 28);
    for (final query in [
      '2 ноября - новый план Напомнить Джону подписать письмо',
      'Добавь план на 2 ноября: Напомнить Джону подписать письмо',
      'Add a plan for November 2: Remind John to sign the cover letter',
      'Nov 2 - task Remind John to sign the cover letter',
      'November 2, 2026 - new plan Remind John to sign the cover letter',
    ]) {
      final plan = ViktorDateScope.independentDateOnlyPlan(query, today);
      expect(plan, isNotNull, reason: query);
      expect(ViktorDateScope.key(plan!.day), '2026-11-02');
    }
    final january = ViktorDateScope.independentDateOnlyPlan(
      'January 5 - new plan Review contract', DateTime(2026, 12, 30));
    expect(ViktorDateScope.key(january!.day), '2027-01-05');
  });

  test('Date-only idempotency does not swallow a timed plan without an end', () {
    const title = 'LS Screening remind John to sign the Cover Letter';
    const day = '2026-11-02';
    final timed = PlanningTask(
      id: 1, categoryId: 2, title: title, dateKey: day,
      startTime: DateTime(2026, 11, 2, 9),
    );
    final untimed = PlanningTask(
      id: 2, categoryId: 2, title: title, dateKey: day,
    );
    expect(ViktorExistingPlan.findDateOnly(
      title: title, wallDay: day, plans: [timed]), isNull);
    expect(ViktorExistingPlan.findDateOnly(
      title: title, wallDay: day, plans: [untimed]), same(untimed));
  });

  test('Single-plan parser does not invent a clock or erase other intents', () {
    final today = DateTime(2026, 10, 28);
    expect(ViktorDateScope.independentDateOnlyPlan(
      'November 2 at 10:30 - new plan Call John', today), isNull);
    expect(ViktorDateScope.independentDateOnlyPlan(
      'November 31 - new plan Call John', today), isNull);
    expect(ViktorDateScope.independentDateOnlyPlan(
      'November 2 - new plan Call John and also create a plan for Nov 11',
      today), isNull);
    expect(ViktorDateScope.independentDateOnlyPlan(
      'November 2 - remind me of the plan from last month', today), isNull);
    expect(ViktorDateScope.independentDateOnlyPlan(
      'LS Screening remind John to sign the Cover Letter', today), isNull);
  });

}
