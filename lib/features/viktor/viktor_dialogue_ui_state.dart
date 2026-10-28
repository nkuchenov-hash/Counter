part of 'viktor_chat_page.dart';

/// Keeps cloud model bootstrap and owner-scoped dialogue state out of the
/// UI page. This mixin never owns domain writes; ViktorExecutor still does.
String viktorSpeechProgressText(ViktorSpeechStage stage, Duration elapsed) {
  final seconds = elapsed.inSeconds;
  if (stage == ViktorSpeechStage.uploading) return 'Передаю запись…';
  return seconds >= 15
      ? 'Yandex SpeechKit обрабатывает запись · ${seconds} с'
      : 'Распознаю речь · ${seconds} с';
}

mixin _ViktorDialogueUiState on State<ViktorChatPage> {
  Future<void> _runHistoricalRecords(
      ViktorHistoricalRecordIntent intent, ViktorExecutor executor,
      String requestId,
      Future<bool> Function(ViktorActionBatch, String) confirm,
      void Function(String) report) async {
    final batch = ViktorActionBatch.fromJson({
      'version': 1, 'request_id': requestId,
      'actions': [{'name': 'create_completed_records_between',
        'arguments': {'wall_day': ViktorDateScope.key(intent.day),
          'before_title': intent.beforeTitle, 'after_title': intent.afterTitle,
          'titles': intent.titles}}],
    });
    final preview = await executor.describe(batch, intent.day);
    if (!mounted) return;
    if (await confirm(batch, preview)) {
      final result = await executor.apply(batch, intent.day,
          approvedPreview: preview);
      if (mounted) report(result);
    } else {
      if (mounted) report('Добавление записей отменено.');
    }
  }


  List<ViktorDialogueTurn> get _messages;
  TextEditingController get _controller;
  Future<void> _send();
  ViktorGateway get _gateway;


  /// One validated, idempotent Brain write. No provider call or draft repair.
  Future<void> _createIndependentDateOnlyPlan(
      ({DateTime day, String title}) plan,
      ViktorExecutor executor, String requestId) async {
    final batch = ViktorActionBatch.fromJson({
      'version': 1,
      'request_id': requestId,
      'actions': [{
        'name': 'create_plan',
        'arguments': {
          'title': plan.title,
          'wall_day': ViktorDateScope.key(plan.day),
        },
      }],
    });
    final preview = await executor.describe(batch, plan.day);
    final receipt = await executor.apply(
        batch, plan.day, approvedPreview: preview);
    if (mounted) _push(receipt);
  }

  /// A correction of an UNSAVED wall-clock draft needs no new model turn.
  bool _showCorrectedScheduleDraft(String input) {
    final draft = ViktorReadAnswer.correctMislabeledMoscowDraft(
      input: input,
      history: _messages.skip(1).map((turn) =>
          {'role': turn.role, 'content': turn.content}),
    );
    if (draft == null) return false;
    _push(draft);
    return true;
  }

  String? _draftRevisionFeedback(
      String input, List<Map<String, String>> history) {
    if (!ViktorReadAnswer.isDraftRevision(input: input, history: history)) {
      return null;
    }
    return 'REVISION OF UNSAVED ITINERARY, NOT A DATABASE COMMAND. '
        'The original request and detailed timetable are in conversation_history. '
        'Preserve EVERY original stop and newly corrected constraint. '
        'Include travel legs, realistic buffers, named places, fixed meeting '
        'times and sleep on the next date. Use schedule_timezone from the '
        'user conversation, NOT the profile if these differ. '
        'Return the FULL revised timetable with actions:[], continue:false. '
        'No read tools, no bulk_replan, no writes or promises to check later.';
  }

  /// Reject a provider's "I will check..." as an itinerary result.
  /// A single repair turn is permitted, never an unbounded status loop.
  Future<ViktorResponse?> _completeScheduleResponse(
    String input,
    ViktorResponse response,
    List<PlanningTask> plans,
    List<String> observations,
    String requestId,
    List<Map<String, String>> history,
    DateTime intentDay,
  ) async {
    final draftRevision = ViktorReadAnswer.isDraftRevision(
        input: input, history: history);
    final isSchedule = draftRevision || RegExp(
          r'распланир|расписани|черновик|составь\s+план|itinerary|schedule',
          caseSensitive: false,
        ).hasMatch(input);
    final unsafeDraftWrite = draftRevision && response.actions != null;
    final incompleteDraft = draftRevision &&
        (response.needsMoreContext ||
         !ViktorReadAnswer.hasTimedItinerary(response.message));
    final wrongTimezone = ViktorReadAnswer.mismatchedScheduleTimezone(
        message: response.message, input: input, history: history);
    if (!isSchedule || (!unsafeDraftWrite && !incompleteDraft &&
        !wrongTimezone && (response.actions != null ||
         !ViktorReadAnswer.isUnfinishedScheduleReply(response.message)))) {
      return response;
    }
    final repaired = await _gateway.propose(
      input: input,
      wallDay: intentDay,
      plans: plans,
      settings: _settings,
      selectedPlanIds: widget.selectedPlanIds,
      toolObservations: observations,
      requestId: requestId,
      conversationHistory: history,
      proposalFeedback: wrongTimezone
          ? 'WRONG TIMEZONE: this dialogue explicitly requests a different '
            'clock zone. Use schedule_timezone, not profile_timezone. '
            'Keep the intended LOCAL hours (do not convert from an invented '
            'source). Produce complete corrected timetable, actions:[], '
            'continue:false.'
          : unsafeDraftWrite
          ? 'The user corrected an UNAPPROVED draft, but you proposed a '
            'database mutation. That is not authorized. Reconstruct the '
            'entire revised timetable in message with actions:[], '
            'continue:false. Never call bulk_replan for a draft.'
          : 'The previous reply did NOT provide a complete revised '
            'timetable with at least 3 clock ranges. '
            'Return the COMPLETE chronological '
            'schedule now with dates, time ranges and explicit assumptions. '
            'Keep user wall-clock times in the requested timezone. '
            'An unapproved draft must have actions:[], continue:false. '
            'Never claim you saved plans.',
      allowRepair: false,
    );
    if (ViktorReadAnswer.mismatchedScheduleTimezone(
        message: repaired.message, input: input, history: history)) {
      return null; // Never present a New York-labelled Moscow timetable.
    }
    if (draftRevision &&
        (repaired.actions != null || repaired.needsMoreContext ||
         !ViktorReadAnswer.hasTimedItinerary(repaired.message))) {
      return null; // No reads, writes, or status-only replies for a draft.
    }
    return repaired.actions == null &&
            ViktorReadAnswer.isUnfinishedScheduleReply(repaired.message)
        ? null : repaired;
  }

  /// Recover from a model repeatedly asking for a read that the executor
  /// already completed. A conversational revision needs the prior draft,
  /// not another database query. One bounded provider retry; no writes here.
  Future<ViktorResponse> _completeRepeatedRead(
      String input, List<PlanningTask> plans, List<String> observations,
      String requestId, List<Map<String, String>> history,
      DateTime intentDay) =>
    _gateway.propose(
      input: input,
      wallDay: intentDay,
      plans: plans,
      settings: _settings,
      selectedPlanIds: widget.selectedPlanIds,
      toolObservations: observations,
      conversationHistory: history,
      requestId: requestId,
      proposalFeedback: 'You already received these tool results. '
        'Do not request the same read again. Use conversation_history and '
        'existing observations to answer the latest user correction now. '
        'For a draft, return the full revised draft in message, actions:[], '
        'continue:false. Respect explicitly requested time zone over '
        'profile setting. Do not claim any plan was saved.',
      allowRepair: false,
    );

  /// Never expose provider schema or internal tool exceptions as chat prose.
  /// Keep a transparent explanation of what failed and whether a write ran.
  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('Move target must differ from source')) {
      return 'Модель попыталась перенести план на ту же дату. '
          'Для корректировки черновика это не нужно. Планы не изменены.';
    }
    if (raw.contains('provider_content_filter') ||
        raw.contains('заблокировал ответ своим фильтром')) {
      return 'Провайдер ИИ заблокировал ответ. '
          'Расписание не изменено, данные не сохранены.';
    }
    if (raw.contains('Invalid bulk') || raw.contains('Unknown Viktor action') ||
        raw.contains('Invalid action') || raw.contains('proposal')) {
      return 'ИИ предложил некорректное действие. '
          'Оно отклонено до применения; планы не изменены.';
    }
    final cleaned = raw.replaceFirst('FormatException: ', '')
        .replaceFirst('Bad state: ', '');
    return cleaned.length > 220
        ? '${cleaned.substring(0, 220)}…' : cleaned;
  }

  final _dialogueStore = ViktorConversationStore(DatabaseService.instance);
  List<ViktorThread> _threads = const [
    ViktorThread(id: ViktorConversationStore.mainConversation,
        title: 'Общий чат'),
  ];
  bool _desktopThreadsVisible = true;
  int _historyLoadEpoch = 0;
  bool _dialogueLoaded = false;

  Future<void> _refreshThreadIndex() async {
    try {
      final threads = await _dialogueStore.loadThreads();
      if (mounted) setState(() => _threads = threads);
    } catch (_) {
      // Keep current conversation available through outages.
    }
  }

  Future<void> _selectConversation(String id,
      {bool locallyNew = false}) async {
    if (_busy || _transcribing || _listening) return;
    final epoch = ++_historyLoadEpoch;
    _dialogueStore.selectConversation(id);
    final intro = _messages.isNotEmpty ? _messages.first
        : const ViktorDialogueTurn(role: 'assistant',
            content: 'Расскажите, что нужно сделать в LIFE OS.');
    setState(() {
      _messages..clear()..add(intro);
      _historyNotice = null;
      _dialogueLoaded = locallyNew;
    });
    if (locallyNew) return;
    try {
      final turns = await _dialogueStore.load();
      if (!mounted || epoch != _historyLoadEpoch) return;
      setState(() {
        _messages..clear()..add(intro)..addAll(turns);
        _dialogueLoaded = _dialogueStore.pendingCount == 0;
      });
    } catch (_) {
      if (mounted && epoch == _historyLoadEpoch) {
        setState(() => _historyNotice =
            'Не удалось загрузить выбранный диалог. Повторяем синхронизацию.');
        _scheduleHistoryRetry();
      }
    }
  }

  void _startNewConversation() {
    if (_busy || _transcribing || _listening) return;
    final id = ViktorConversationStore.newConversationId();
    setState(() => _threads = [
      ..._threads, ViktorThread(id: id, title: 'Новый разговор'),
    ]);
    unawaited(_selectConversation(id, locallyNew: true));
  }

  String? _historyNotice;
  Timer? _historyRetryTimer;
  bool _historyRetryInFlight = false;

  void _scheduleHistoryRetry() {
    if (_historyRetryTimer != null ||
        (_dialogueLoaded && _dialogueStore.pendingCount == 0 &&
         !_dialogueStore.localOutboxUnreadable)) {
      return;
    }
    _historyRetryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) {
        _stopHistoryRetry();
      } else if (!_historyRetryInFlight) {
        unawaited(_retryHistorySync());
      }
    });
  }

  void _stopHistoryRetry() {
    _historyRetryTimer?.cancel();
    _historyRetryTimer = null;
  }

  final _settings = ViktorModelSettings.instance;
  bool _settingsReady = false;
  String? _cloudConnectionError;

  Future<void> _loadSettings() async {
    try {
      await _settings.load();
      await DatabaseService.instance.ensurePocketBaseReady();
      _settings.ensureOwner(
        DatabaseService.instance.pocketBase.authStore.record?.id ?? 'signed_out',
      );
      await _settings.loadCloudConnection();
      if (mounted) setState(() {
        _cloudConnectionError = null;
      });
    } catch (error) {
      if (mounted) setState(() {
        _cloudConnectionError = error.toString().replaceAll(
          'FormatException: ', '',
        );
      });
    }
    try {
      final earlier = await _dialogueStore.load();
      final threads = await _dialogueStore.loadThreads();
      if (mounted) setState(() {
        _threads = threads;
        _messages.addAll(earlier);
        _dialogueLoaded = _dialogueStore.pendingCount == 0;
        _historyNotice = !_dialogueLoaded
            ? 'Некоторые реплики ожидают синхронизации с сервером.'
            : _dialogueStore.localOutboxUnreadable
                ? 'Серверная история загружена, но прежнюю локальную '
                  'зашифрованную очередь пока не удалось прочитать. '
                  'Повторяем проверку, не перезаписывая её.'
                : null;
      });
      _scheduleHistoryRetry();
    } catch (_) {
      if (mounted) setState(() {
        _dialogueLoaded = false;
        _historyNotice = 'Историю разговора не удалось загрузить. '
            'Автоматически повторяем подключение к серверу.';
      });
      _scheduleHistoryRetry();
    }
    if (mounted) setState(() => _settingsReady = true);
  }
  Future<void> _persistTurn(ViktorDialogueTurn turn) async {
    try {
      await _dialogueStore.append(turn);
      if (!mounted) return;
      if (turn.isUser) unawaited(_refreshThreadIndex());
      if (_dialogueLoaded && _dialogueStore.pendingCount == 0 &&
          !_dialogueStore.localOutboxUnreadable) {
        if (_historyNotice != null) {
          setState(() => _historyNotice = null);
        }
        _stopHistoryRetry();
      } else {
        _scheduleHistoryRetry();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dialogueLoaded = false;
        _historyNotice = _dialogueStore.pendingInMemoryOnly
            ? 'Сообщения пока только в памяти: сервер недоступен, '
              'а защищённое хранилище браузера не работает. '
              'Не закрывайте вкладку до синхронизации.'
            : 'История не синхронизирована с сервером. '
              'Повторяем отправку автоматически.';
      });
      _scheduleHistoryRetry();
    }
  }

  Future<void> _retryHistorySync() async {
    if (_historyRetryInFlight) return;
    _historyRetryInFlight = true;
    try {
      await _dialogueStore.retryPending();
      // A successful send is not proof that earlier history was loaded:
      // re-fetch the server conversation, even with an empty local outbox.
      final threadAtStart = _dialogueStore.activeConversationId;
      final serverHistory = await _dialogueStore.load();
      if (mounted && _dialogueStore.activeConversationId == threadAtStart) {
        setState(() {
          final introduction = _messages.isEmpty ? null : _messages.first;
          final visible = _messages.skip(1).toList();
          final restored = ViktorDialogueTurn.reconcileVisible(
              serverHistory, visible);
          _messages.clear();
          if (introduction != null) _messages.add(introduction);
          _messages.addAll(restored);
          _dialogueLoaded = _dialogueStore.pendingCount == 0;
          _historyNotice = !_dialogueLoaded
              ? 'Сообщения ожидают синхронизации.'
              : _dialogueStore.localOutboxUnreadable
                  ? 'Серверная история доступна, но старая защищённая '
                    'локальная очередь пока не читается. '
                    'Она не будет перезаписана; проверка повторится.'
                  : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dialogueLoaded = false;
          _historyNotice = _dialogueStore.pendingInMemoryOnly
              ? 'Сообщения только в памяти. Не закрывайте вкладку, '
                'пока сервер и защищённое хранилище недоступны.'
              : 'История пока недоступна на сервере. '
                'Повторяем проверку автоматически.';
        });
      }
    } finally {
      _historyRetryInFlight = false;
      if (_dialogueLoaded && _dialogueStore.pendingCount == 0 &&
          !_dialogueStore.localOutboxUnreadable) {
        _stopHistoryRetry();
      } else {
        _scheduleHistoryRetry();
      }
    }
  }

  String _resolveRepeatCommand(String requested) {
    if (!ViktorDialogueTurn.isRepeatCommand(requested)) return requested;
    final previous = ViktorDialogueTurn.lastRepeatableUserRequest(
        _messages.skip(1));
    if (previous != null) return previous;
    _controller.clear();
    _push('Предыдущую команду не удалось восстановить из истории LIFE OS. '
        'Команда повтора не была отправлена модели. '
        'Ожидаю восстановления истории с сервера.');
    return '';
  }

  void _retryLastCommand() {
    final original = ViktorDialogueTurn.lastRepeatableUserRequest(
        _messages.skip(1));
    if (original == null) {
      _push('Предыдущая команда отсутствует в доступной истории. '
          'Сначала требуется восстановить синхронизацию.');
      unawaited(_retryHistorySync());
      return;
    }
    _controller.text = original;
    unawaited(_send());
  }

  void _push(String value, {bool mine = false}) {
    if (!mounted) return;
    final db = DatabaseService.instance;
    String? messageDay;
    String? timezone;
    try {
      messageDay = ViktorDateScope.key(db.getProjectedToday());
      timezone = db.settings.preferredTimeZone;
    } catch (_) {
      // If profile context isn't loaded, preserve the instant without
      // inventing an incorrect local date.
    }
    final turn = ViktorDialogueTurn(
        role: mine ? 'user' : 'assistant', content: value,
        sentAtUtc: DateTime.now().toUtc(), messageDay: messageDay,
        messageTimezone: timezone);
    setState(() => _messages.add(turn));
    // Even if history loading or a previous write failed, try saving new
    // turns. The store retries earlier pending turns first, preserving order.
    unawaited(_persistTurn(turn));
  }
}
