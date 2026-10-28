import 'package:counter/data/ai/viktor_conversation_store.dart';
import 'package:counter/data/ai/viktor_thread_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relative today remains tied to original turn, not reopened date', () {
    final turns = [
      ViktorDialogueTurn(role: 'user',
        content: 'Сегодня были зарядка, кофе и душ',
        sentAtUtc: DateTime.utc(2026, 10, 28, 8, 15),
        messageDay: '2026-10-28',
        messageTimezone: 'Europe/Moscow'),
      const ViktorDialogueTurn(role: 'assistant',
        content: 'Запишу после подтверждения'),
    ];
    final context = ViktorDialogueTurn.modelContext(turns);
    expect(context.first['message_day'], '2026-10-28');
    expect(context.first['sent_at_utc'], '2026-10-28T08:15:00.000Z');
    expect(context.first['message_timezone'], 'Europe/Moscow');
    expect(context.last.containsKey('message_day'), false);
  });

  test('A new independent day/topic starts new context, follow-ups stay', () {
    final prior = [
      ViktorDialogueTurn(role: 'user', content: 'Распланируй субботу',
          sentAtUtc: DateTime.utc(2026, 10, 24, 11)),
      const ViktorDialogueTurn(role: 'assistant', content: 'Черновик'),
    ];
    expect(ViktorThreadRouter.shouldOpenNew(
      input: 'Добавь шесть записей за сегодня',
      previous: prior, nowUtc: DateTime.utc(2026, 10, 28, 11)), true);
    expect(ViktorThreadRouter.shouldOpenNew(
      input: 'Добавь эти записи тоже',
      previous: prior, nowUtc: DateTime.utc(2026, 10, 28, 11)), false);
    // The actual morning report is declarative; it must open a separate
    // activity context instead of inheriting the October 24 itinerary.
    expect(ViktorThreadRouter.shouldOpenNew(
      input: 'Между просыпанием и Atozed Clients сегодня у меня были '
          'зарядка, кофе и душ',
      previous: prior, nowUtc: DateTime.utc(2026, 10, 28, 11)), true);
    // A follow-up that bridges domains still needs the source records.
    expect(ViktorThreadRouter.shouldOpenNew(
      input: 'Создай заметку по этим записям',
      previous: prior, nowUtc: DateTime.utc(2026, 10, 28, 11)), false);
    expect(ViktorThreadRouter.shouldOpenNew(
      input: 'Новая тема — мои заметки', previous: prior,
      nowUtc: DateTime.utc(2026, 10, 28, 11)), true);
  });

  test('Viktor conversation keys are limited to safe owner-scoped IDs', () {
    expect(ViktorConversationStore.validConversationId('main'), true);
    expect(ViktorConversationStore.validConversationId(
        'chat_1793186789000000_1234'), true);
    expect(ViktorConversationStore.validConversationId(
        'main\" || user_id != \"owner'), false);
    expect(ViktorConversationStore.validConversationId('../main'), false);
    expect(ViktorConversationStore.validConversationId(
        ViktorConversationStore.newConversationId()), true);
  });

  test('New chat model context cannot inherit another chat messages', () {
    final old = [
      const ViktorDialogueTurn(role: 'user',
          content: '24 октября составить расписание RCC'),
    ];
    final current = [
      ViktorDialogueTurn(role: 'user',
          content: '28 октября добавь завершённые записи',
          messageDay: '2026-10-28'),
    ];
    final context = ViktorDialogueTurn.modelContext(current);
    expect(context.single['message_day'], '2026-10-28');
    expect(context.toString(), isNot(contains(old.single.content)));
  });
}
