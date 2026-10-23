import 'package:counter/data/ai/viktor_read_answer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('Critiques about lost stops and New York remain read-only draft edits', () {
    const draft = '2026-10-24\n'
        '10:00–10:30 Зарядка\n'
        '13:00–14:00 Купить тыквы\n'
        '20:00–21:00 RCC';
    final history = <Map<String, String>>[
      {'role': 'user', 'content': 'Время по Москве надо'},
      {'role': 'assistant', 'content': draft},
    ];
    for (final input in [
      'Почему New York-то?',
      'И где покупка тыкв на Сенной? План не продуман',
      'Обнови план с дорогой',
    ]) {
      expect(ViktorReadAnswer.isDraftRevision(
        input: input, history: history), isTrue);
      expect(ViktorReadAnswer.requestedScheduleTimezone(
        input: input, history: history), 'Europe/Moscow');
    }
    expect(ViktorReadAnswer.mismatchedScheduleTimezone(
      input: 'Почему New York-то?', history: history,
      message: '10:00–10:30 (New York) Зарядка\n'
          '20:00–21:00 (New York) RCC'), isTrue);
    expect(ViktorReadAnswer.mismatchedScheduleTimezone(
      input: 'Почему New York-то?', history: history,
      message: '10:00–10:30 (Москва, МСК) Зарядка\n'
          '20:00–21:00 (Москва, МСК) RCC'), isFalse);
    expect(ViktorReadAnswer.mismatchedScheduleTimezone(
      input: 'Теперь по Нью-Йорку', history: history,
      message: '10:00–10:30 (New York) Зарядка'), isFalse);
  });



  test('A changed wake-up time revises an uncommitted timetable only', () {
    const draft = '2026-10-24\n'
        '08:00–08:30 Зарядка\n'
        '11:30–13:00 Купить тыквы\n'
        '20:00–21:00 RCC';
    final history = <Map<String, String>>[
      {'role': 'assistant', 'content': draft},
      {'role': 'user', 'content': 'Встану дай бог в 10'},
      {'role': 'assistant', 'content': 'Изменения отменены.'},
    ];
    expect(ViktorReadAnswer.isDraftRevision(
      input: 'Скорректируй план с учетом того, что встану в 10',
      history: history,
    ), isTrue);
    expect(ViktorReadAnswer.isDraftRevision(
      input: 'Встану дай бог в 10', history: history,
    ), isTrue);
    expect(ViktorReadAnswer.isDraftRevision(
      input: 'Подтверждаю, сохрани план', history: history,
    ), isFalse);
    expect(ViktorReadAnswer.isDraftRevision(
      input: 'Скорректируй план с учетом подъема в 10',
      history: const [{'role':'user', 'content': draft}],
    ), isFalse);
  });



  test('Moscow follow-up finishes the earlier draft without shifting clocks', () {
    const draft = 'Проект расписания (пока ничего не сохранено):\n'
        '2026-10-24\n'
        '08:00–08:30 (New York) Зарядка\n'
        '11:30–13:00 (New York) Купить тыквы и отвезти в бар\n'
        '20:00–21:00 (New York) Встреча RCC\n'
        '2026-10-25\n'
        '00:30–01:00 (New York) Лечь спать';
    final history = <Map<String, String>>[
      {'role': 'user', 'content': 'Распланируй субботу, 24 октября'},
      {'role': 'assistant', 'content': draft},
      for (var i = 0; i < 8; i++) ...[
        {'role': 'user', 'content': 'Время по Москве надо'},
        {'role': 'assistant', 'content': 'Сейчас проверю планы'},
      ],
    ];
    final corrected = ViktorReadAnswer.correctMislabeledMoscowDraft(
        input: 'Время по Москве надо', history: history);
    expect(corrected, isNotNull);
    expect(corrected, contains('20:00–21:00 (Москва, МСК)'));
    expect(corrected, contains('2026-10-25'));
    expect(corrected, contains('00:30–01:00 (Москва, МСК)'));
    expect(corrected, contains('Купить тыквы'));
    expect(corrected, isNot(contains('(New York)')));
    expect(corrected, contains('Ничего в LIFE OS не сохранено.'));
  });

  test('Timezone repair will not fabricate an itinerary or modify user text', () {
    const userDraft = '08:00–09:00 (New York) A\n'
        '09:00–10:00 (New York) B\n'
        '10:00–11:00 (New York) C';
    expect(ViktorReadAnswer.correctMislabeledMoscowDraft(
      input: 'Время по Москве надо',
      history: [{'role': 'user', 'content': userDraft}],
    ), isNull);
    expect(ViktorReadAnswer.correctMislabeledMoscowDraft(
      input: 'Время по Москве надо',
      history: [{'role': 'assistant', 'content': 'Сейчас проверю'}],
    ), isNull);
    expect(ViktorReadAnswer.correctMislabeledMoscowDraft(
      input: 'Перенеси встречу на 22:00',
      history: [{'role': 'assistant', 'content': userDraft}],
    ), isNull);
  });

  test('Status promise is never mistaken for completed itinerary', () {
    for (final incomplete in [
      'Сейчас преобразую время в расписании для субботы.',
      'Сначала проверю уже существующие планы на этот день.',
      'Проверяю текущие планы на субботу.',
    ]) {
      expect(ViktorReadAnswer.isUnfinishedScheduleReply(incomplete), isTrue);
    }
    expect(ViktorReadAnswer.isUnfinishedScheduleReply(
      'Расписание:\n08:00–08:30 зарядка\n09:00–10:00 ЗАГС'), isFalse);
  });


  test('Explicit trailing voice cancellation blocks an earlier mutation', () {
    expect(ViktorReadAnswer.isExplicitCancellation(
      'перенеси все планы за 21 октября на 22 октября отмена отмена'), isTrue);
    expect(ViktorReadAnswer.isExplicitCancellation('отмена'), isTrue);
    expect(ViktorReadAnswer.isExplicitCancellation(
      'Move all pending plans cancel'), isTrue);
    expect(ViktorReadAnswer.isExplicitCancellation(
      'Перенеси все планы на сегодня в 9 утра'), isFalse);
    expect(ViktorReadAnswer.isExplicitCancellation(
      'Покажи план с названием Отмена проекта завтра'), isFalse);
  });

  test('Empty continue:true asks for one bounded repair, never mutates', () {
    expect(ViktorReadAnswer.hasEmptyReadContinuation(
      needsMoreContext: true, hasActions: false), isTrue);
    expect(ViktorReadAnswer.hasEmptyReadContinuation(
      needsMoreContext: true, hasActions: true), isFalse);
    expect(ViktorReadAnswer.hasEmptyReadContinuation(
      needsMoreContext: false, hasActions: false), isFalse);
  });

  test('Final mutation with incorrect continue flag is never rejected as a read', () {
    expect(ViktorReadAnswer.shouldContinueReading(
      needsMoreContext: true, hasActions: true, hasMutations: true), isFalse,
      reason: 'bulk_replan must reach Brain preview and confirmation');
    expect(ViktorReadAnswer.shouldContinueReading(
      needsMoreContext: true, hasActions: true, hasMutations: false), isTrue,
      reason: 'list_day_plans can still gather observations');
    expect(ViktorReadAnswer.shouldContinueReading(
      needsMoreContext: false, hasActions: true, hasMutations: true), isFalse);
    expect(ViktorReadAnswer.shouldContinueReading(
      needsMoreContext: true, hasActions: false, hasMutations: false), isFalse);
  });

  test('Exact poem line request forces full document retrieval', () {
    expect(ViktorReadAnswer.requiresDocumentRead(
      input: 'Какая третья строчка стихотворения за январь 2023?',
      actions: ['search_notes', 'search_record_notes']), isTrue);
    expect(ViktorReadAnswer.requiresDocumentRead(
      input: 'Какие заметки были в январе 2023?',
      actions: ['search_notes']), isFalse);
    expect(ViktorReadAnswer.requiresDocumentRead(
      input: 'Какая третья строка?',
      actions: ['search_notes', 'read_note']), isFalse);
  });

  test('Poem question searches then reads instead of stopping at titles', () {
    expect(ViktorReadAnswer.isDirectDayListResult(
      input: 'Найди стихотворение января 2023, какая третья строка?',
      toolNames: ['search_notes']), isFalse);
    expect(ViktorReadAnswer.isDirectDayListResult(
      input: 'Какие сегодня планы',
      toolNames: ['list_day_plans']), isTrue);
    expect(ViktorReadAnswer.isDirectDayListResult(
      input: 'Найди старую заметку',
      toolNames: ['search_notes', 'read_note']), isFalse);
  });

  test('A simple read request ends after first successful observation', () {
    expect(ViktorReadAnswer.isReadOnlyRequest(
      'Покажи мой план AGE Solutions – ADD SIN на пятницу'), isTrue);
    expect(ViktorReadAnswer.isReadOnlyRequest(
      'Покажи планы на пятницу'), isTrue);
    expect(ViktorReadAnswer.isReadOnlyRequest(
      'Show my meetings on Friday'), isTrue);
  });

  test('Read plus mutation still needs the multi-step agent workflow', () {
    expect(ViktorReadAnswer.isReadOnlyRequest(
      'Покажи планы и перенеси встречу на пятницу'), isFalse);
    expect(ViktorReadAnswer.isReadOnlyRequest(
      'Show Friday plans and move my meeting'), isFalse);
    expect(ViktorReadAnswer.isReadOnlyRequest(
      'Добавь встречу на пятницу'), isFalse);
  });

  test('Returns the matching saved item, not an unrelated FALCON event', () {
    const result = '2026-10-23 11:30  FALCON ADD SIN Review and reply\n'
        '2026-10-23 12:00  AGE Solutions - ADD SIN\n'
        '2026-10-23 14:00  Another task';
    expect(ViktorReadAnswer.format(
      'Покажи мой план AGE Solutions – ADD SIN на пятницу', result),
      '2026-10-23 12:00  AGE Solutions - ADD SIN');
  });

  test('Broad query shows all plans without guessing a match', () {
    const result = '2026-10-23 11:00  FALCON\n'
        '2026-10-23 12:00  AGE Solutions';
    expect(ViktorReadAnswer.format('Покажи планы на пятницу', result), result);
  });

  test('Empty or single observation preserved', () {
    expect(ViktorReadAnswer.format('Покажи планы на пятницу',
      'На 2026-10-23 планов нет.'), 'На 2026-10-23 планов нет.');
  });
}
