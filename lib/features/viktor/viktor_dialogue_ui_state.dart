part of 'viktor_chat_page.dart';

/// Keeps cloud model bootstrap and owner-scoped dialogue state out of the
/// UI page. This mixin never owns domain writes; ViktorExecutor still does.
mixin _ViktorDialogueUiState on State<ViktorChatPage> {
  List<ViktorDialogueTurn> get _messages;
  TextEditingController get _controller;
  Future<void> _send();
  final _dialogueStore = ViktorConversationStore(DatabaseService.instance);
  bool _dialogueLoaded = false;
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
      if (mounted) setState(() {
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
      final serverHistory = await _dialogueStore.load();
      if (mounted) {
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
    final turn = ViktorDialogueTurn(
        role: mine ? 'user' : 'assistant', content: value);
    setState(() => _messages.add(turn));
    // Even if history loading or a previous write failed, try saving new
    // turns. The store retries earlier pending turns first, preserving order.
    unawaited(_persistTurn(turn));
  }
}
