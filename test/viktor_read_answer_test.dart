import 'package:counter/data/ai/viktor_read_answer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
