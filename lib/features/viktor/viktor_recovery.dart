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
      final providerIssue = reason.contains('провайдер') ||
          reason.contains('модел') || reason.contains('Viktor:') ||
          reason.contains('provider_');
      final scheduleRequest = RegExp(
        r'план|расписан|длительност|перенес|сдвин|встреч|schedule|duration',
        caseSensitive: false,
      ).hasMatch(input);
      if (scheduleRequest) {
        _push(providerIssue
            ? 'Выбранная модель не дала пригодного ответа, но '
              'расписание не изменено. Можно проверить частичный '
              'пересчёт длительностей, попробовать перенести гибкие '
              'задачи на другую дату или пересмотреть отдельные '
              'ограничения. Доступность этих вариантов ещё нужно '
              'проверить по расписанию. Что проверяем первым?'
            : 'Не удалось завершить проверку расписания. Ничего '
              'не изменено. Могу проверить частичный вариант, '
              'перенос гибких задач или другой временной интервал. '
              'Какой путь выбрать?');
      } else {
        _push('Не удалось подтвердить действие, поэтому ничего '
            'не изменено. Можем проверить исходные данные или '
            'разбить запрос на более узкие действия. '
            'Что проверить первым?');
      }
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
    final scheduleRequest = RegExp(
      r'план|расписан|длительност|перенес|сдвин|встреч|schedule|duration',
      caseSensitive: false,
    ).hasMatch(input);
    _push(failure is ViktorTagDurationOverflow
        ? 'В расписании не помещается «${failure.plan.title}» '
          '(${failure.minutes} мин.). Могу показать проверяемый '
          'частичный пересчёт, при котором закреплённые встречи '
          'не сдвигаются, либо сначала проверить перенос гибких '
          'задач на другой день. Что выбрать?'
        : scheduleRequest
            ? 'Первая попытка не подошла. Могу проверить '
              'другое размещение гибких задач, перенос на '
              'соседний день или сохранение только допустимых '
              'изменений. Что важнее сохранить без изменений?'
            : 'Действие не прошло проверку. Можно сначала '
              'изучить актуальные данные или уточнить, какую '
              'часть запроса выполнить. Что проверим?');
  }

}
