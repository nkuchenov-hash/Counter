part of 'viktor_chat_page.dart';

/// Keeps cloud model bootstrap and owner-scoped dialogue state out of the
/// UI page. This mixin never owns domain writes; ViktorExecutor still does.
mixin _ViktorDialogueUiState on State<ViktorChatPage> {
  List<ViktorDialogueTurn> get _messages;
  final _dialogueStore = ViktorConversationStore(DatabaseService.instance);
  bool _dialogueLoaded = false;
  String? _historyNotice;
  Timer? _historyRetryTimer;
  bool _historyRetryInFlight = false;

  void _scheduleHistoryRetry() {
    if (_historyRetryTimer != null || _dialogueStore.pendingCount == 0) {
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
        _historyNotice = _dialogueLoaded ? null :
            'Некоторые реплики сохранены на устройстве и ожидают '
            'синхронизации. Виктор повторит отправку.';
      });
      _scheduleHistoryRetry();
    } catch (_) {
      if (mounted) setState(() {
        _dialogueLoaded = false;
        _historyNotice = 'Историю разговора не удалось загрузить. '
            'Проверьте подключение и защищённое хранилище.';
      });
    }
    if (mounted) setState(() => _settingsReady = true);
  }
  Future<void> _persistTurn(ViktorDialogueTurn turn) async {
    try {
      await _dialogueStore.append(turn);
      if (mounted && (!_dialogueLoaded || _historyNotice != null) &&
          _dialogueStore.pendingCount == 0) {
        setState(() {
          _dialogueLoaded = true;
          _historyNotice = null;
        });
        _stopHistoryRetry();
      }
    } catch (_) {
      if (mounted && (_dialogueLoaded || _historyNotice == null)) {
        setState(() {
          _dialogueLoaded = false;
          _historyNotice = 'История ещё не синхронизирована с сервером. '
              'Отправка повторится при следующем сообщении. '
              'Если защищённое хранилище недоступно, '
              'несохранённые реплики могут пропасть.';
        });
      }
      _scheduleHistoryRetry();
    }
  }

  Future<void> _retryHistorySync() async {
    if (_historyRetryInFlight) return;
    if (_dialogueStore.pendingCount == 0) {
      _stopHistoryRetry();
      return;
    }
    _historyRetryInFlight = true;
    try {
      await _dialogueStore.retryPending();
      if (mounted && _dialogueStore.pendingCount == 0) {
        setState(() {
          _dialogueLoaded = true;
          _historyNotice = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dialogueLoaded = false;
          _historyNotice = 'История пока не синхронизирована. '
              'Локальные реплики ожидают повторной отправки.';
        });
      }
    } finally {
      _historyRetryInFlight = false;
      if (_dialogueStore.pendingCount == 0) {
        _stopHistoryRetry();
      } else {
        _scheduleHistoryRetry();
      }
    }
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
