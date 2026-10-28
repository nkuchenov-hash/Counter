import 'viktor_conversation_store.dart';

/// Conservative routing: explicit topic breaks and independent commands can
/// open a fresh context. Pronoun follow-ups always stay with their task.
class ViktorThreadRouter {
  static bool isFollowUp(String value) {
    final q = value.toLowerCase().trim();
    if (q.startsWith('а ') || q.startsWith('ну ')) return true;
    return RegExp(
      r'^(?:да|нет|ок|хорошо|ага|почему|а\s+|ну\s+|'
      r'исправь|переделай|повтори|продолжи|'
      r'добавь\s+(?:это|эти|их|туда|тоже)|'
      r'сделай\s+(?:это|так|ещ[её])|'
      r'перенеси\s+(?:это|их|его|е[её])|'
      r'а\s+теперь\s+их)(?=\s|$|[.!?,—])',
      caseSensitive: false,
    ).hasMatch(q);
  }

  static String? topic(String input) {
    final q = input.toLowerCase();
    if (RegExp(r'запис|фактич|трекер|таймлайн|timeline|records|'
        r'просып|запущенн|закончил\s+работать').hasMatch(q)) {
      return 'records';
    }
    if (RegExp(r'план|расписан|запланир|planner|'
        r'перенеси\s+задач|встреч[ауи]').hasMatch(q)) return 'plans';
    if (RegExp(r'замет|стих|текст\s+заметк|notes').hasMatch(q)) {
      return 'notes';
    }
    if (RegExp(r'категори|тег|ярлык').hasMatch(q)) return 'categories';
    if (RegExp(r'путь|этап\s+проекта|цель|roadmap').hasMatch(q)) {
      return 'paths';
    }
    if (RegExp(r'настройк|тема\s+оформлен|шрифт').hasMatch(q)) {
      return 'settings';
    }
    return null;
  }

  static bool shouldOpenNew({
    required String input,
    required List<ViktorDialogueTurn> previous,
    required DateTime nowUtc,
  }) {
    final q = input.trim().toLowerCase();
    if (RegExp(r'^(?:новая\s+тема|другая\s+тема|'
        r'давай\s+о\s+другом|new\s+topic)(?=\s|$|[.!?,—])').hasMatch(q)) return true;
    if (isFollowUp(input)) return false;
    final users = previous.where((t) => t.isUser).toList();
    if (users.isEmpty) return false;
    final current = topic(input);
    final last = topic(users.last.content);
    if (current != null && last != null && current != last &&
        RegExp(r'^(?:создай|добавь|запиши|запланируй|'
            r'покажи|найди|объясни|составь|как\s+мне)(?=\s|$|[.!?,—])').hasMatch(q)) {
      return true;
    }
    // Clear day boundary: start a new independent activity, preserving direct
    // references and intentionally continuing previous dialogues.
    final lastAt = users.last.sentAtUtc;
    if (current != null && lastAt != null &&
        nowUtc.difference(lastAt.toUtc()) > const Duration(hours: 18) &&
        RegExp(r'^(?:создай|добавь|запиши|запланируй|'
            r'покажи|найди|составь)(?=\s|$|[.!?,—])').hasMatch(q)) return true;
    return false;
  }
}
