part of 'viktor_chat_page.dart';

// Error handling stays out of the large hot-path chat widget.
// This extension shares the same library and cannot bypass Brain execution.
extension _ViktorRecoveryDialogue on _ViktorChatPageState {
  /// An explicit "move yesterday's incomplete plans to today" is a native
  /// action. Real source/target state is loaded by ViktorExecutor. There is
  /// no LLM answer, and no alternate conversational-choice menu.
  Future<void> _runDirectCarryForward(
      ViktorActionBatch batch, ViktorExecutor executor,
      {required void Function() onWriteStarted}) async {
    final today = DatabaseService.instance.getProjectedToday();
    final preview = await executor.describe(batch, today);
    if (!mounted) return;
    if (!await _confirm(batch, preview)) {
      if (mounted) _push('Перенос отменён.');
      return;
    }
    if (!mounted) return;
    onWriteStarted();
    final saved = await executor.apply(batch, today,
        approvedPreview: preview);
    if (mounted) _push(saved);
  }

  /// Safe Plan-only fallback for a fully specified narrated chores list.
  /// Earlier reported completed activities stay in Timeline and are never
  /// fabricated as future Plans or claimed to be updated.
  Future<bool> _tryNarratedChoreFallback({
    required String input,
    required String requestId,
    required ViktorExecutor executor,
    required void Function() onWriteStarted,
  }) async {
    final today = DatabaseService.instance.getProjectedToday();
    final batch = ViktorDateScope.narratedChoreBatch(
      input: input, profileToday: today, requestId: requestId);
    if (batch == null) return false;
    final preview = await executor.describe(batch, today);
    if (!mounted) return true;
    if (!await _confirm(batch, '$preview\n'
        'Ранее выполненные записи Timeline НЕ изменяются.')) {
      if (mounted) _push('Создание планов отменено.');
      return true;
    }
    if (!mounted) return true;
    onWriteStarted();
    final receipt = await executor.apply(batch, today,
        approvedPreview: preview);
    if (mounted) _push('$receipt\n'
        'Ранее выполненные записи Timeline не изменены.');
    return true;
  }

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

  /// Failed actions are NOT decision trees. Never echo the model's
  /// speculative alternatives or start an advice-only call for an explicit
  /// command. A short factual failure keeps the user's intent intact.
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
    if (writeStarted) {
      _push('Результат сохранения не подтверждён. '
          'Проверьте расписание; повторная запись не выполнялась.');
      return;
    }
    final reason = _friendlyError(failure);
    final shortReason = reason.length > 145
        ? '${reason.substring(0, 145)}…' : reason;
    final schedule = ViktorReadAnswer.requiresScheduleAction(input) ||
        RegExp(r'план|расписан|перенес|перенос|schedule',
          caseSensitive: false).hasMatch(input);
    _push(schedule
        ? 'Расписание не изменено: $shortReason'
        : 'Изменений нет: $shortReason');
  }

}
