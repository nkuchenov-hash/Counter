part of 'viktor_chat_page.dart';

// Error handling stays out of the large hot-path chat widget.
// This extension shares the same library and cannot bypass Brain execution.
extension _ViktorRecoveryDialogue on _ViktorChatPageState {
  Future<void> _offerRecovery({
    required String input,
    required Object failure,
    required DateTime day,
    required List<PlanningTask> plans,
    required String requestId,
    required List<Map<String, String>> conversation,
    bool writeStarted = false,
  }) async {
    if (!mounted) return;
    // After a write starts, its result may be uncertain. Never recommend
    // replaying a potentially committed command, which could duplicate work.
    if (writeStarted) {
      _push('Не удалось подтвердить результат изменения. '
          'Проверьте текущее расписание перед повторной командой. '
          'Я не буду повторять запись автоматически.');
      return;
    }
    final reason = _friendlyError(failure);
    if (failure is FormatException ||
        failure is! StateError && failure is! ViktorTagDurationOverflow) {
      _push('Не получилось обработать запрос: $reason '
          'Попробуйте уточнить условие или повторить запрос.');
      return;
    }
    final groundedContext = failure is ViktorTagDurationOverflow
        ? 'Расписание ${ViktorDateScope.key(failure.day)}: план '
          '«${failure.plan.title}» на ${failure.minutes} минут '
          'не помещается. Закреплённые и повторяющиеся планы нельзя '
          'сдвигать. Проверяемый частичный вариант доступен по '
          'запросу «покажи частичный вариант». Перенос на другую дату '
          'ещё не проверен; ни один вариант не сохранён.'
        : 'Application validation rejected the requested operation '
          'before writing: $reason. Any new action must pass a fresh '
          'Brain preview and user confirmation.';
    _push('Этот вариант не прошёл проверку. Ищу безопасную альтернативу.');
    try {
      final result = await _gateway.propose(
        input: input, wallDay: day, plans: plans,
        settings: _settings, selectedPlanIds: widget.selectedPlanIds,
        requestId: requestId, conversationHistory: conversation,
        adviceOnly: true, recoveryContext: groundedContext,
        allowRepair: false,
      );
      if (!mounted) return;
      final explanation = result.message.trim();
      if (explanation.isNotEmpty) {
        _push(explanation);
        return;
      }
    } catch (_) {
      // Advice is optional; never allow a second provider error to overwrite
      // the grounded original rejection or initiate any mutation.
    }
    if (!mounted) return;
    _push(failure is ViktorTagDurationOverflow
        ? 'Могу показать частичный пересчёт, сохранив базовую '
          'длительность у задач, которые не помещаются. '
          'Или обсудим перенос гибких задач на другой день. '
          'Какой вариант проверить?'
        : 'Могу пересчитать гибкие задачи с другими ограничениями '
          'или проверить другой день. Какие изменения допустимы?');
  }

}
