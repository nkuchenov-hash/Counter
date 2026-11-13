part of 'viktor_chat_page.dart';

// Error handling stays out of the large hot-path chat widget.
// This extension shares the same library and cannot bypass Brain execution.
extension _ViktorRecoveryDialogue on _ViktorChatPageState {
  /// Give the assistant one bounded opportunity to inspect additional real
  /// data and propose a different operation after a pre-write rejection.
  /// Reads cannot mutate. The caller re-previews and explicitly confirms any
  /// recovered write; no operation is applied inside this method.
  Future<({ViktorActionBatch? actions, String? preview, String? answer})>
      _retryRejectedProposal({
    required String input,
    required StateError failure,
    required DateTime day,
    required List<PlanningTask> plans,
    required String requestId,
    required List<Map<String, String>> conversation,
    required List<String> priorObservations,
    required ViktorActionBatch rejected,
    required ViktorExecutor executor,
  }) async {
    final rejectedJson = jsonEncode(
        rejected.actions.map((a) => a.toJson()).toList());
    final rejectedSummary = rejectedJson.length > 400
        ? '${rejectedJson.substring(0, 400)}…' : rejectedJson;
    final feedback = 'Previous action was rejected BEFORE any writes: '
        '$rejectedSummary. Constraint: ${_friendlyError(failure)}. '
        'Preserve the original user goal and try a DIFFERENT approach. '
        'If more real data is needed, request only read tools with '
        'continue:true. Otherwise propose a fresh actionable change, '
        'or give concrete alternatives with actions:[].';
    final observations = [...priorObservations];
    var response = await _gateway.propose(
      input: input, wallDay: day, plans: plans,
      settings: _settings, selectedPlanIds: widget.selectedPlanIds,
      requestId: requestId, conversationHistory: conversation,
      toolObservations: observations, proposalFeedback: feedback,
      allowRepair: false,
    );
    final seen = <String>{};
    for (var readStep = 0; readStep < 2 && response.needsMoreContext;
        readStep++) {
      final batch = response.actions;
      if (batch == null || batch.hasMutations) {
        return (actions: null, preview: null, answer: null);
      }
      final signature = jsonEncode(
          batch.actions.map((a) => a.toJson()).toList());
      if (!seen.add(signature)) {
        return (actions: null, preview: null, answer: null);
      }
      String observed;
      try {
        observed = await executor.describe(batch, day);
      } on StateError {
        return (actions: null, preview: null, answer: null);
      }
      observations.add(jsonEncode({
        'tools': batch.actions.map((a) => a.toJson()).toList(),
        'result': observed,
      }));
      response = await _gateway.propose(
        input: input, wallDay: day, plans: plans,
        settings: _settings, selectedPlanIds: widget.selectedPlanIds,
        requestId: requestId, conversationHistory: conversation,
        toolObservations: observations, proposalFeedback: feedback,
        allowRepair: false,
      );
    }
    if (response.needsMoreContext) {
      return (actions: null, preview: null, answer: null);
    }
    final batch = response.actions;
    if (batch == null) {
      return (actions: null, preview: null, answer: response.message);
    }
    try {
      final preview = await executor.describe(batch, day);
      return (actions: batch, preview: preview, answer: response.message);
    } on StateError {
      return (actions: null, preview: null, answer: null);
    }
  }

  /// One bounded read-to-write repair when a provider only says it will
  /// check Records. This method never writes; only a fresh validated proposal
  /// may later reach the normal consent-gated executor.
  Future<ViktorResponse?> _repairUnfinishedRecordWrite({
    required String input,
    required DateTime intentDay,
    required List<PlanningTask> plans,
    required String requestId,
    required List<Map<String, String>> conversation,
    required List<String> observations,
    required ViktorExecutor executor,
  }) async {
    final first = await _gateway.propose(
      input: input, wallDay: intentDay, plans: plans,
      settings: _settings, selectedPlanIds: widget.selectedPlanIds,
      requestId: requestId, conversationHistory: conversation,
      toolObservations: observations,
      proposalFeedback: 'The previous reply promised to check but returned '
          'no action. For two adjacent Timeline records use read_day_records '
          'and then resize_adjacent_records with exact observed IDs. '
          'Never edit Plans or create new Records for this request.',
      allowRepair: false,
    );
    if (!mounted || first.actions == null) return null;
    if (first.actions!.hasMutations) {
      if (first.needsMoreContext ||
          first.actions!.actions.length != 1 ||
          first.actions!.actions.single.name != 'resize_adjacent_records') {
        return null;
      }
      return first;
    }
    final reads = first.actions!;
    if (reads.actions.length != 1 ||
        reads.actions.single.name != 'read_day_records') {
      return null;
    }
    final observed = await executor.describe(reads, intentDay);
    if (!mounted) return null;
    final next = await _gateway.propose(
      input: input, wallDay: intentDay, plans: plans,
      settings: _settings, selectedPlanIds: widget.selectedPlanIds,
      requestId: requestId, conversationHistory: conversation,
      toolObservations: [
        ...observations,
        jsonEncode({
          'tools': reads.actions.map((a) => a.toJson()).toList(),
          'result': observed,
        }),
      ],
      proposalFeedback: 'Read complete. Final result must be one '
          'resize_adjacent_records action with actual record IDs and '
          'continue:false; never return another status-only message.',
      allowRepair: false,
    );
    if (!mounted || next.needsMoreContext ||
        next.actions?.actions.length != 1 ||
        next.actions?.actions.single.name != 'resize_adjacent_records') {
      return null;
    }
    return next;
  }

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
      final providerReason = reason.toLowerCase();
      final providerIssue = providerReason.contains('провайдер') ||
          providerReason.contains('модел') ||
          providerReason.contains('yandex') ||
          providerReason.contains('viktor:') ||
          providerReason.contains('provider_');
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
