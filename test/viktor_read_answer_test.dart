import 'package:counter/data/ai/viktor_read_answer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
