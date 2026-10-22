import 'dart:async';
import 'dart:convert';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_executor.dart';
import 'package:counter/data/ai/viktor_gateway.dart';
import 'package:counter/data/ai/viktor_schedule_planner.dart';
import 'package:counter/data/ai/viktor_voice_gateway.dart';
import 'package:counter/data/ai/viktor_voice_recorder.dart';
import 'package:counter/data/ai/viktor_voice_error.dart';
import 'package:counter/data/ai/viktor_read_answer.dart';
import 'package:counter/data/ai/viktor_conversation_store.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
/// Single LIFE OS assistant entry point. Replaces the old record-only mic FAB.
/// No overlay over the planner, no extra button beside bottom navigation.
class ViktorChatPage extends StatefulWidget {
  const ViktorChatPage({super.key, required this.wallDay,
    this.selectedPlanIds = const <String>[]});
  final DateTime wallDay;
  final List<String> selectedPlanIds;
  @override
  State<ViktorChatPage> createState() => _ViktorChatPageState();
}
class _ViktorChatPageState extends State<ViktorChatPage> {
  final _controller = TextEditingController();
  final _recorder = ViktorVoiceRecorder();
  final _voiceGateway = const ViktorVoiceGateway();
  final _messages = <ViktorDialogueTurn>[];
  final _dialogueStore = ViktorConversationStore(DatabaseService.instance);
  bool _dialogueLoaded = false;
  final _settings = ViktorModelSettings.instance;
  final _gateway = const ViktorGateway();
  bool _busy = false;
  bool _listening = false;
  bool _startingMic = false;
  bool _transcribing = false;
  bool _speechDetected = false;
  DateTime? _lastVoiceActivity;
  String? _voiceNotice;
  bool _settingsReady = false;
  String? _cloudConnectionError;
  @override
  void initState() {
    super.initState();
    _recorder.addListener(_onRecorderChanged);
    unawaited(_loadSettings());
    _messages.add(const ViktorDialogueTurn(role: 'assistant',
      content: 'Я Виктор. Могу работать с планами, записями, заметками, '
      'тегами, категориями, Путями и настройками LIFE OS. '
      'Опишите результат, а не последовательность нажатий. '
      'Перед изменениями я покажу план для подтверждения.',
    ));
  }
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
        _dialogueLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _messages.add(
        const ViktorDialogueTurn(role: 'assistant',
          content: 'История разговора временно недоступна. '
              'Новые реплики пока не сохраняются на сервере.')));
    }
    if (mounted) setState(() => _settingsReady = true);
  }
  @override
  void dispose() {
    _recorder.removeListener(_onRecorderChanged);
    _recorder.dispose();
    _controller.dispose();
    super.dispose();
  }
  void _push(String value, {bool mine = false}) {
    if (!mounted) return;
    final turn = ViktorDialogueTurn(
        role: mine ? 'user' : 'assistant', content: value);
    setState(() => _messages.add(turn));
    if (_dialogueLoaded) {
      unawaited(_dialogueStore.append(turn).catchError((Object _) {
        if (mounted && _dialogueLoaded) setState(() {
          _dialogueLoaded = false;
          _messages.add(const ViktorDialogueTurn(role: 'assistant',
            content: 'Не удалось сохранить историю разговора '
                'в PocketBase. Текущие реплики доступны до закрытия окна.'));
        });
      }));
    }
  }
  Future<void> _send() async {
    if (_busy) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    if (!_settingsReady) return;
    if (_settings.mode == 'byok' && !_settings.modelConnected) {
      await _openSettings();
      if (!mounted || !_settings.modelConnected) return;
    }
    if (_listening || _transcribing || _startingMic) return;
    if (!mounted) return;
    _controller.clear();
    final dialogContext = ViktorDialogueTurn.modelContext(
        _messages.skip(1));
    _push(input, mine: true);
    if (ViktorReadAnswer.isExplicitCancellation(input)) {
      _push('Команда отменена. Изменения не выполнялись.');
      return;
    }
    setState(() => _busy = true);
    try {
      final db = DatabaseService.instance;
      final plans = await db.getPlanningTasksForWallDate(widget.wallDay);
      final lastTwoIds = ViktorSchedulePlanner.resolveLastTwoSwap(input, plans);
      final executor = ViktorExecutor(db);
      final toolObservations = <String>[];
      final seenReads = <String>{};
      String? latestReadAnswer;
      final requestId = 'viktor_${DateTime.now().microsecondsSinceEpoch}';
      var response = await _gateway.propose(
        input: input,
        wallDay: widget.wallDay,
        plans: plans,
        settings: _settings,
        selectedPlanIds: widget.selectedPlanIds,
        requestId: requestId,
        conversationHistory: dialogContext,
      );
      var repairedEmptyRead = false;
      for (var step = 0; response.needsMoreContext ||
          ViktorReadAnswer.requiresDocumentRead(input: input,
            actions: response.actions?.actions.map((a) => a.name).toList()
                ?? const <String>[]); step++) {
        if (!mounted) return;
        if (step >= 4) {
          throw StateError('Виктор достиг предела проверки данных. '
              'Никакие изменения не выполнены.');
        }
        if (ViktorReadAnswer.hasEmptyReadContinuation(
          needsMoreContext: response.needsMoreContext,
          hasActions: response.actions != null,
        )) {
          if (repairedEmptyRead) {
            throw StateError('Виктор повторно запросил данные без указания '
                'операции чтения. Планы не изменены.');
          }
          repairedEmptyRead = true;
          response = await _gateway.propose(
            input: input,
            wallDay: widget.wallDay,
            plans: plans,
            settings: _settings,
            selectedPlanIds: widget.selectedPlanIds,
            toolObservations: toolObservations,
            requestId: requestId,
            conversationHistory: dialogContext,
            proposalFeedback: 'continue:true requires at least one read tool. '
                'For bulk_replan propose a final write with continue:false '
                'because Brain loads source and destination day records.',
            allowRepair: false,
          );
          continue;
        }
        if (!ViktorReadAnswer.shouldContinueReading(
          needsMoreContext: response.needsMoreContext,
          hasActions: response.actions != null,
          hasMutations: response.actions?.hasMutations ?? false,
        )) break;
        final proposed = response.actions!;
        final signature = jsonEncode(
            proposed.actions.map((a) => a.toJson()).toList());
        if (!seenReads.add(signature)) {
          // Showing a list is a valid outcome for a read request, but NEVER
          // claim that a write request was handled merely because a read
          // succeeded. The user can retry without unintended changes.
          if (ViktorReadAnswer.isReadOnlyRequest(input)) {
            _push(latestReadAnswer ?? 'Данные уже получены, изменений нет.');
          } else {
            _push('Виктор повторно запросил уже полученные данные, но не '
                'предложил изменения. Планы не изменены.');
          }
          return;
        }
        final observation = await executor.describe(proposed, widget.wallDay);
        latestReadAnswer = ViktorReadAnswer.format(input, observation);
        if (ViktorReadAnswer.isDirectDayListResult(
            input: input,
            toolNames: proposed.actions.map((a) => a.name).toList())) {
          _push(latestReadAnswer);
          return;
        }
        toolObservations.add(jsonEncode({
          'tools': proposed.actions.map((a) => a.toJson()).toList(),
          'result': observation,
        }));
        response = await _gateway.propose(
          input: input,
          wallDay: widget.wallDay,
          plans: plans,
          settings: _settings,
          selectedPlanIds: widget.selectedPlanIds,
          toolObservations: toolObservations,
          requestId: requestId,
            conversationHistory: dialogContext,
        );
      }
      if (!mounted) return;
      final actions = response.actions;
      if (response.needsMoreContext && actions == null) {
        throw StateError('Виктор запросил дополнительные данные, '
            'но не указал операцию чтения. Планы не изменены.');
      }
      if (actions == null) {
        if (response.message.trim().isNotEmpty) {
          _push(response.message.trim());
        }
        if (latestReadAnswer != null) {
          _push(latestReadAnswer);
        }
        return;
      }
      final preview = await executor.describe(actions, widget.wallDay);
      if (!mounted) return;
      if (!actions.hasMutations) {
        if (response.message.trim().isNotEmpty) {
          _push(response.message.trim());
        }
        final onlyDayReads = actions.actions.every(
            (action) => action.name == 'list_day_plans');
        _push(onlyDayReads
            ? ViktorReadAnswer.format(input, preview) : preview);
        return;
      }
      if (actions.isSingleReversibleWrite) {
        _push(preview);
      }
      final swapArgs = actions.actions.length == 1 &&
              actions.actions.single.name == 'swap_plan_positions'
          ? actions.actions.single.arguments
          : null;
      final firstId = swapArgs?['first_plan_id'] as String?;
      final secondId = swapArgs?['second_plan_id'] as String?;
      final selected = widget.selectedPlanIds.toSet();
      final matchedSelection = selected.length == 2 &&
          selected.contains(firstId) && selected.contains(secondId);
      bool titleSpoken(String? id) {
        if (id == null) return false;
        final matching = plans.where((p) => p.pocketRecordId == id);
        if (matching.length != 1) return false;
        final title = matching.single.title.toLowerCase().trim();
        return title.length >= 3 && input.toLowerCase().contains(title);
      }
      final groundedByPosition = lastTwoIds != null &&
          firstId == lastTwoIds[0] && secondId == lastTwoIds[1];
      final isUnambiguousSwap = swapArgs != null &&
          firstId != secondId &&
          (groundedByPosition || matchedSelection ||
              (titleSpoken(firstId) && titleSpoken(secondId)));
      final approved = isUnambiguousSwap || actions.isSingleReversibleWrite
          ? true : await _confirm(actions, preview);
      if (!mounted) return;
      if (!approved) {
        _push('Изменения отменены.');
        return;
      }
      final result = await executor.apply(actions, widget.wallDay,
        approvedPreview: preview);
      if (mounted) _push(result);
    } catch (error) {
      if (mounted) {
        var msg = error.toString().replaceFirst('FormatException: ', '')
            .replaceFirst('Bad state: ', '');
        if (msg.length > 270) msg = '${msg.substring(0, 270)}…';
        _push('Не удалось выполнить запрос. $msg');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<bool> _confirm(ViktorActionBatch batch, String preview) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Проверить действия Виктора'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Text(
              '$preview\n\nПеред применением LIFE OS повторно проверит '
              'актуальное расписание.',
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
          ),
        ),
        actions: [
          AppButton.ghost(label: 'Отмена',
            onPressed: () => Navigator.pop(ctx, false)),
          AppButton.primary(label: 'Применить',
            onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    return answer == true;
  }
  void _onRecorderChanged() {
    if (!mounted) return;
    if (_recorder.isRecording && !_startingMic && !_transcribing &&
        _recorder.capturedBytes > 16000) {
      final now = DateTime.now();
      if (_recorder.level > 0.22) {
        _speechDetected = true;
        _lastVoiceActivity = now;
      } else if (_speechDetected && _lastVoiceActivity != null &&
          now.difference(_lastVoiceActivity!).inMilliseconds > 1450 &&
          _recorder.durationMs >= 1900) {
        _speechDetected = false;
        unawaited(_finishRecording());
        return;
      }
    }
    setState(() {
      if (_recorder.isRecording && _recorder.durationMs > 3000 &&
          _recorder.capturedBytes == 0) {
        _voiceNotice = 'Микрофон открыт, но звук пока не поступает. '
            'Проверьте разрешение и устройство ввода.';
      }
    });
    if (_recorder.captureError != null && _recorder.isRecording &&
        !_startingMic && !_transcribing) {
      unawaited(_finishRecording());
      return;
    }
    if (_recorder.limitReached && _recorder.isRecording &&
        !_startingMic && !_transcribing) {
      unawaited(_finishRecording());
    }
  }
  Future<void> _finishRecording() async {
    var shouldSubmit = false;
    var captured = false;
    if (_startingMic || _transcribing || !_recorder.isRecording) return;
    setState(() {
      _startingMic = true;
      _listening = false;
      _voiceNotice = 'Завершаю запись…';
    });
    try {
      final wav = await _recorder.stop();
      captured = true;
      if (!mounted) return;
      setState(() {
        _transcribing = true;
        _voiceNotice = 'Распознаю речь…';
      });
      final transcript = await _voiceGateway.transcribe(
        wav: wav, settings: _settings);
      if (!mounted) return;
      final original = _controller.text.trim();
      setState(() {
        _controller.text = [
          if (original.isNotEmpty) original,
          transcript,
        ].join(' ');
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        _voiceNotice = 'Команда распознана. Выполняю…';
      });
      shouldSubmit = true;
    } catch (error) {
      if (!mounted) return;
      setState(() => _voiceNotice = viktorVoiceErrorText(error,
          stage: captured ? 'recognition' : 'capture'));
    } finally {
      if (mounted) {
        setState(() {
          _startingMic = false;
          _transcribing = false;
          _listening = false;
        });
        if (shouldSubmit) unawaited(_send());
      }
    }
  }
  Future<void> _toggleMic() async {
    if (_busy || _startingMic || _transcribing) return;
    if (_recorder.isRecording) {
      await _finishRecording();
      return;
    }
    if (!_settingsReady) return;
    bool missingSpeechKey() {
      final provider = _settings.provider;
      return !_settings.speechConnected;
    }
    if (missingSpeechKey() ||
        (_settings.provider == 'yandex' &&
         _settings.yandexFolderId.trim().isEmpty)) {
      await _openSettings();
      if (!mounted) return;
      final stillMissing = missingSpeechKey() ||
          (_settings.provider == 'yandex' &&
           _settings.yandexFolderId.trim().isEmpty);
      if (stillMissing) {
        setState(() => _voiceNotice =
            'Для диктовки нужны API-ключ и ID каталога Yandex Cloud '
            'либо ключ выбранного провайдера речи.');
        return;
      }
    }
    _speechDetected = false;
    _lastVoiceActivity = null;
    setState(() {
      _startingMic = true;
      _voiceNotice = 'Подключаю микрофон…';
    });
    try {
      await _recorder.start();
      if (!mounted) return;
      setState(() {
        _listening = true;
        _voiceNotice = null;
      });
    } catch (error) {
      if (mounted) setState(() => _voiceNotice =
            viktorVoiceErrorText(error, stage: 'capture'));
    } finally {
      if (mounted) setState(() => _startingMic = false);
    }
  }
  String _cloudSaveErrorText(Object error) {
    final value = error.toString().replaceAll('FormatException: ', '');
    if (value.contains('api_key_required')) {
      return 'Введите API-ключ. На сервере пока нет сохранённого ключа '
          'для этого поставщика.';
    }
    if (value.contains('api_key_too_short')) {
      return 'API-ключ слишком короткий. Проверьте, что скопирован целиком.';
    }
    if (value.contains('api_key_too_long')) {
      return 'API-ключ превышает допустимую длину.';
    }
    if (value.contains('yandex_folder_id_required')) {
      return 'Введите ID каталога Yandex Cloud (не название default).';
    }
    if (value.contains('invalid_yandex_folder_id')) {
      return 'ID каталога Yandex Cloud неверного формата.';
    }
    if (value.contains('unsupported_model')) {
      return 'Выбранная модель не поддерживается сервером LIFE OS.';
    }
    if (value.contains('HTTP 400')) {
      return 'Сервер PocketBase отклонил запрос (HTTP 400), '
          'но не вернул код ошибки. Подключение НЕ сохранено.';
    }
    if (value.contains('vault_unconfigured') ||
        value.contains('vault_unavailable') ||
        value.contains('vault_save_failed') ||
        value.contains('vault_connection_unreadable')) {
      return 'Ошибка защищённого хранилища PocketBase: $value. '
          'Не вводите новый ключ, пока проблема не исправлена.';
    }
    return 'Не удалось подтвердить сохранение: $value';
  }

  Future<void> _openSettings() async {
    if (!_settingsReady) await _loadSettings();
    try {
      await _settings.loadCloudConnection();
      _cloudConnectionError = null;
    } catch (error) {
      _cloudConnectionError = error.toString()
          .replaceAll('FormatException: ', '');
    }
    if (!mounted) return;
    var mode = _settings.mode;
    var provider = _settings.provider;
    var model = _settings.model;
    final keyCtrl = TextEditingController(text: _settings.sessionApiKey);
    final folderCtrl = TextEditingController(text: _settings.yandexFolderId);
    var gigachatScope = _settings.gigachatScope;
    var speechProvider = _settings.speechProvider;
    final speechKeyCtrl = TextEditingController(text: _settings.sessionSpeechApiKey);
    var savingConnection = false;
    var localPreferencesSaved = true;
    String? saveError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 560),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 24),
          title: const Text('Модель Виктора'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Режим', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'byok',
                        child: Text('Своя модель · свой API-ключ')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      updateDialog(() {
                        mode = v;
                        if (mode == 'hosted') {
                          keyCtrl.clear();
                          provider = 'openai';
                          model = 'gpt-4o-mini';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Бета-версия работает с вашим API-ключом. '
                    'Встроенный ИИ LIFE OS появится после запуска подписок.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (mode == 'byok') ...[
                    const Text('Поставщик', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: provider,
                      isExpanded: true,
                      items: [
                        for (final p in ViktorModelSettings.models.keys)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        updateDialog(() {
                          if (provider != v) keyCtrl.clear();
                          provider = v;
                          model = ViktorModelSettings.models[v]!.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Модель', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: model,
                      isExpanded: true,
                      items: [
                        for (final m in ViktorModelSettings.models[provider]!)
                          DropdownMenuItem(value: m,
                            child: Text(m, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) {
                        if (v != null) updateDialog(() => model = v);
                      },
                    ),
                    if (provider == 'gigachat') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: gigachatScope,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Тип доступа GigaChat API',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pers',
                            child: Text('Личный доступ')),
                          DropdownMenuItem(value: 'b2b',
                            child: Text('Бизнес · пакеты')),
                          DropdownMenuItem(value: 'corp',
                            child: Text('Бизнес · оплата по факту')),
                        ],
                        onChanged: (value) {
                          if (value != null) updateDialog(() => gigachatScope = value);
                        },
                      ),
                    ],
                    if (provider == 'yandex') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: folderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ID каталога Yandex Cloud',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (provider == 'yandex') ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Голос работает через Yandex SpeechKit с тем же '
                        'API-ключом, что и YandexGPT. Сервисному аккаунту '
                        'нужны роли ai.languageModels.user и '
                        'ai.speechkit-stt.user, а API-ключу — разрешения '
                        'на генерацию текста и распознавание речи.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                    if (provider == 'openrouter' ||
                        provider == 'gigachat') ...[
                      const SizedBox(height: 16),
                      const Text('Распознавание речи', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                        'Для диктовки выберите поставщика распознавания. '
                        'Он может отличаться от модели, управляющей планами.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: speechProvider,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'groq', child: Text('Groq · Whisper')),
                          DropdownMenuItem(value: 'openai', child: Text('OpenAI · Transcribe')),
                          DropdownMenuItem(value: 'gemini', child: Text('Gemini · Audio')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          updateDialog(() {
                            if (speechProvider != value) speechKeyCtrl.clear();
                            speechProvider = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: speechKeyCtrl,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'API-ключ для диктовки',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyCtrl,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: provider == 'gigachat'
                            ? 'Ключ авторизации GigaChat API'
                            : 'API-ключ модели',
                        hintText: _cloudConnectionError == null &&
                                _settings.cloudProviders.contains(provider)
                            ? 'Ключ сохранён на сервере'
                            : 'Введите ключ для подключения',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_cloudConnectionError != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Не удалось проверить сохранённое подключение: '
                            '$_cloudConnectionError',
                            style: const TextStyle(fontSize: 16),
                          )),
                        ],
                      ),
                    ] else if (_settings.cloudProviders.contains(provider)) ...[
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'Подключено. API-ключ сохранён на сервере LIFE OS '
                            'и доступен на всех устройствах этого аккаунта. '
                            'Поле ключа намеренно пустое: сервер не отправляет '
                            'секрет обратно в браузер.',
                            style: TextStyle(fontSize: 16),
                          )),
                        ],
                      ),
                    ] else
                      const Text(
                        'Не подключено. Введите API-ключ и нажмите «Сохранить». '
                        'После проверки подключения оно появится на всех '
                        'устройствах этого аккаунта.',
                        style: TextStyle(fontSize: 16),
                      ),
                  ] else
                    const Text(
                      'Встроенная модель станет доступна после включения '
                      'подписки и серверного учёта лимитов.',
                      style: TextStyle(fontSize: 16),
                    ),
                  if (saveError != null) ...[
                    const SizedBox(height: 16),
                    Text(saveError!, style: const TextStyle(
                      fontSize: 16, color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            AppButton.ghost(
              label: 'Отмена',
              onPressed: savingConnection
                  ? null : () => Navigator.pop(dialogContext, false),
            ),
            AppButton.primary(
              label: 'Сохранить',
              loading: savingConnection,
              onPressed: savingConnection ? null : () async {
                // Never close the dialog while the server has not accepted
                // and verified the connection. The user keeps typed keys
                // for correcting validation errors without starting over.
                if (keyCtrl.text.trim().isEmpty &&
                    !_settings.cloudProviders.contains(provider)) {
                  updateDialog(() => saveError =
                      'Введите API-ключ: серверное подключение ещё не создано.');
                  return;
                }
                if (provider == 'yandex' &&
                    folderCtrl.text.trim().isEmpty &&
                    !_settings.cloudProviders.contains(provider)) {
                  updateDialog(() => saveError =
                      'Введите ID каталога Yandex Cloud.');
                  return;
                }
                updateDialog(() {
                  savingConnection = true;
                  saveError = null;
                });
                _settings.mode = mode;
                _settings.provider = provider;
                _settings.model = model;
                if (keyCtrl.text.trim().isNotEmpty) {
                  _settings.sessionApiKey = keyCtrl.text.trim();
                }
                if (folderCtrl.text.trim().isNotEmpty) {
                  _settings.yandexFolderId = folderCtrl.text.trim();
                }
                _settings.gigachatScope = gigachatScope;
                _settings.speechProvider = speechProvider;
                if (speechKeyCtrl.text.trim().isNotEmpty) {
                  _settings.sessionSpeechApiKey = speechKeyCtrl.text.trim();
                }
                try {
                  await _settings.saveCloudConnection();
                  localPreferencesSaved = await _settings.save();
                  _cloudConnectionError = null;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    updateDialog(() => saveError = _cloudSaveErrorText(error));
                  }
                } finally {
                  if (dialogContext.mounted) {
                    updateDialog(() => savingConnection = false);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      _push(localPreferencesSaved
          ? 'Подключение проверено: сохранено на сервере LIFE OS.'
          : 'Подключение сохранено на сервере LIFE OS. '
            'Локальные настройки устройства не записались.');
      setState(() {});
    }
    keyCtrl.dispose();
    folderCtrl.dispose();
    speechKeyCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 4,
        title: const Text('Виктор', style:
            TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        actions: [
          AppIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Настройки ИИ и API-ключ',
            onPressed: _settingsReady ? _openSettings : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (ctx, index) {
                      if (_busy && index == 0) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                color: scheme.primary),
                            ),
                          ),
                        );
                      }
                      final offset = _busy ? 1 : 0;
                      final message = _messages[_messages.length - 1 -
                          (index - offset)];
                      return Align(
                        alignment: message.isUser ? Alignment.centerRight :
                            Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: const BoxConstraints(maxWidth: 610),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: message.isUser ? scheme.primaryContainer :
                                scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(message.content,
                            style: TextStyle(
                              fontSize: 16, height: 1.45,
                              color: message.isUser ? scheme.onPrimaryContainer :
                                  scheme.onSurface,
                            )),
                        ),
                      );
                    },
                  ),
                ),
                if (_listening || _transcribing || _startingMic)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_listening ? Icons.graphic_eq_rounded :
                              Icons.hourglass_top_rounded,
                              size: 20, color: scheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              _transcribing ? 'Распознаю запись…' :
                                _startingMic ? 'Подключение…' :
                                  'Запись · ${Duration(milliseconds: _recorder.durationMs).inSeconds} с',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            if (_listening)
                              Text('${(_recorder.capturedBytes / 1024).toStringAsFixed(0)} КБ',
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_listening) ...[
                          LinearProgressIndicator(
                            minHeight: 6,
                            value: _recorder.level.clamp(0.015, 1.0).toDouble(),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Команда отправится после паузы в речи. '
                            'Квадрат — остановить вручную.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ] else
                          const LinearProgressIndicator(minHeight: 3),
                      ],
                    ),
                  ),
                if (_voiceNotice != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Text(
                      _voiceNotice!,
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5))),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppIconButton(
                          icon: _listening ? Icons.stop_circle_outlined :
                            Icons.mic_none_rounded,
                          tooltip: _listening ? 'Остановить диктовку' :
                            'Продиктовать Виктору',
                          onPressed: _busy || _startingMic || _transcribing ? null : _toggleMic,
                          selected: _listening,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_busy && !_startingMic && !_transcribing,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintText: _listening ? 'Идёт запись — нажмите стоп' :
                                'Что сделать в LIFE OS?',
                              filled: true,
                              fillColor: scheme.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            ),
                            onSubmitted: (_) => unawaited(_send()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppIconButton(
                          icon: Icons.arrow_upward_rounded,
                          tooltip: 'Отправить Виктору',
                          onPressed: _busy || _listening || _transcribing || _startingMic || !_settingsReady ? null :
                            () => unawaited(_send()),
                          variant: AppIconButtonVariant.filled,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
