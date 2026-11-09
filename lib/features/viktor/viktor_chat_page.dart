import 'package:counter/core/app_colors.dart';
import 'dart:async';
import 'dart:convert';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_executor.dart';
import 'package:counter/data/ai/viktor_historical_records.dart';
import 'package:counter/data/ai/viktor_gateway.dart';
import 'package:counter/data/ai/viktor_schedule_planner.dart';
import 'package:counter/data/ai/viktor_voice_gateway.dart';
import 'package:counter/data/ai/viktor_voice_recorder.dart';
import 'package:counter/data/ai/viktor_voice_error.dart';
import 'package:counter/data/ai/viktor_read_answer.dart';
import 'package:counter/data/ai/viktor_date_scope.dart';
import 'package:counter/data/ai/viktor_conversation_store.dart';
import 'package:counter/data/ai/viktor_thread_router.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
part 'viktor_dialogue_ui_state.dart';
part 'viktor_composer.dart';
part 'viktor_chat_layout.dart';
part 'viktor_threads_ui.dart';
const double kViktorChatContentMaxWidth = 840;
class ViktorChatPage extends StatefulWidget {
  const ViktorChatPage({super.key, required this.wallDay,
    this.selectedPlanIds = const <String>[]});
  final DateTime wallDay;
  final List<String> selectedPlanIds;
  @override
  State<ViktorChatPage> createState() => _ViktorChatPageState();
}
class _ViktorChatPageState extends State<ViktorChatPage>
    with _ViktorDialogueUiState {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _messagesScrollController = ScrollController();
  final _recorder = ViktorVoiceRecorder();
  final _voiceGateway = const ViktorVoiceGateway();
  final _messages = <ViktorDialogueTurn>[];
  final _gateway = const ViktorGateway();
  bool _busy = false;
  bool _listening = false;
  bool _startingMic = false;
  bool _transcribing = false;
  bool _speechDetected = false;
  DateTime? _lastVoiceActivity;
  String? _voiceNotice;
  @override
  void initState() {
    super.initState();
    _recorder.addListener(_onRecorderChanged);
    unawaited(_loadSettings());
    _messages.add(const ViktorDialogueTurn(role: 'assistant',
      content: 'Я Виктор. Могу работать с планами, записями, заметками, '
      'тегами, категориями, Путями и настройками LIFE OS. '
      'Опишите результат, а не последовательность нажатий. '
      'Простые команды выполняю сразу, сложные изменения сначала согласовываю.',
    ));
  }
  @override
  void dispose() {
    _disposeChatRealtime();
    _stopHistoryRetry();
    _recorder.removeListener(_onRecorderChanged);
    _recorder.dispose();
    _messagesScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
  Future<void> _send() async {
    if (_busy) return;
    final input = _resolveRepeatCommand(_controller.text.trim());
    if (input.isEmpty) return;
    final db = DatabaseService.instance;
    final profileToday = db.getProjectedToday();
    final independentPlan =
        ViktorDateScope.independentDateOnlyPlan(input, profileToday);
    // Standalone dated plans are deterministic and do not need AI settings.
    if (independentPlan == null && !_settingsReady) return;
    // A fresh self-contained dated plan must never inherit an unrelated
    // unfinished itinerary, even when remote chat history is still syncing.
    final hadPreviousRequest = _messages.skip(1).any((turn) => turn.isUser);
    if ((independentPlan != null && hadPreviousRequest) ||
        (_dialogueLoaded && ViktorThreadRouter.shouldOpenNew(
          input: input, previous: _messages.skip(1).toList(),
          nowUtc: DateTime.now().toUtc(),
        ))) {
      _startNewConversation();
    }
    final dialogContext = ViktorDialogueTurn.modelContext(_messages.skip(1));
    if (independentPlan == null &&
        _settings.mode == 'byok' && !_settings.modelConnected) {
      await _openSettings();
      if (!mounted || !_settings.modelConnected) return;
    }
    if (_listening || _transcribing || _startingMic) return;
    if (!mounted) return;
    _controller.clear();
    final revisionOfDraft = ViktorReadAnswer.isDraftRevision(input: input, history: dialogContext);
    final intentDay = ViktorDateScope.itineraryDay(input, widget.wallDay,
        dialogContext, revision: revisionOfDraft, profileToday: profileToday);
    _push(input, mine: true);
    if (ViktorReadAnswer.isExplicitCancellation(input)) {
      _push('Команда отменена. Изменения не выполнялись.');
      return;
    }
    if (_showCorrectedScheduleDraft(input)) return;
    setState(() => _busy = true);
    try {
      final executor = ViktorExecutor(db);
      final requestId = 'viktor_${DateTime.now().microsecondsSinceEpoch}';
      if (independentPlan != null) {
        await _createIndependentDateOnlyPlan(independentPlan, executor, requestId);
        return;
      }
      if (ViktorTagDurationRepair.matches(input)) {
        final repair = ViktorTagDurationRepair(db);
        final preview = await repair.prepare(profileToday);
        if (!mounted) return;
        final approved = await showDialog<bool>(
          context: context,
          builder: (ctx) => ViktorTagDurationReviewDialog(preview: preview),
        ) ?? false;
        if (!mounted) return;
        if (!approved) {
          _push('Изменения отменены.');
          return;
        }
        final result = await repair.apply(preview, profileToday, requestId);
        if (mounted) _push(result);
        return;
      }
      final plans = await db.getPlanningTasksForWallDate(intentDay);
      final lastTwoIds = ViktorSchedulePlanner.resolveLastTwoSwap(input, plans);
      final toolObservations = <String>[];
      final seenReads = <String>{};
      String? latestReadAnswer;
      var response = await _gateway.propose(
        input: input, wallDay: intentDay, plans: plans,
        settings: _settings, selectedPlanIds: widget.selectedPlanIds,
        requestId: requestId, conversationHistory: dialogContext,
        proposalFeedback: _draftRevisionFeedback(input, dialogContext),
      );
      var repairedEmptyRead = false;
      var repairedRepeatedRead = false;
      for (var step = 0; !revisionOfDraft && (response.needsMoreContext ||
          ViktorReadAnswer.requiresDocumentRead(input: input,
            actions: response.actions?.actions.map((a) => a.name).toList().cast<String>()
                ?? const <String>[])); step++) {
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
            // A second malformed continuation is not another read.
            // Never invent a tool call or apply an unvalidated write.
            if (latestReadAnswer != null) _push(latestReadAnswer);
            _push('Модель не смогла выбрать допустимую операцию чтения. '
                'Запрос завершён без изменений.');
            return;
          }
          repairedEmptyRead = true;
          response = await _gateway.propose(
            input: input,
            wallDay: intentDay,
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
          response = await _completeRepeatedRead(input, plans,
              toolObservations, requestId, dialogContext, intentDay);
          repairedRepeatedRead = true;
          if (response.actions?.hasMutations == true) break;
          _push(response.message.trim().isNotEmpty
              ? response.message.trim()
              : latestReadAnswer ?? 'Изменений нет. Повторная проверка '
                  'данных не дала нового результата.');
          return;
        }
        final observation = await executor.describe(proposed, intentDay);
        latestReadAnswer = ViktorReadAnswer.format(input, observation);
        if (ViktorReadAnswer.isDirectDayListResult(
            input: input,
            toolNames: proposed.actions.map((a) => a.name).toList().cast<String>())) {
          _push(latestReadAnswer);
          return;
        }
        toolObservations.add(jsonEncode({
          'tools': proposed.actions.map((a) => a.toJson()).toList(),
          'result': observation,
        }));
        response = await _gateway.propose(
          input: input,
          wallDay: intentDay,
          plans: plans,
          settings: _settings,
          selectedPlanIds: widget.selectedPlanIds,
          toolObservations: toolObservations,
          requestId: requestId,
            conversationHistory: dialogContext,
        );
      }
      if (!mounted) return;
      final completed = await _completeScheduleResponse(
          input, response, plans, toolObservations, requestId, dialogContext,
          intentDay);
      if (completed == null) {
        _push('Виктор не сформировал полный согласованный черновик '
            'с нужным часовым поясом. Планы не изменены.');
        return;
      }
      response = completed;
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
      if (ViktorProposedDayDraft.needsReadOnlyDraft(actions)) {
        final draft = await ViktorProposedDayDraft.describe(actions,
          loadDay: db.getPlanningTasksForWallDate);
        if (mounted) _push(draft);
        return;
      }
      final preview = await executor.describe(actions, intentDay);
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
      final approved = !repairedRepeatedRead &&
              (isUnambiguousSwap || actions.isSingleReversibleWrite)
          ? true : await _confirm(actions, preview);
      if (!mounted) return;
      if (!approved) {
        _push('Изменения отменены.');
        return;
      }
      final result = await executor.apply(actions, intentDay,
        approvedPreview: preview);
      if (mounted) _push(result);
    } catch (error) {
      if (mounted) {
        _push('Не удалось выполнить запрос. ${_friendlyError(error)}');
      }
    } finally {
      if (mounted) setState(() { _busy = false; _voiceNotice = null; });
    }
  }
  Future<bool> _confirm(ViktorActionBatch batch, String preview) =>
      _confirmPreview(preview);

  Future<bool> _confirmPreview(String preview) async {
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
  void _onSpeechProgress(ViktorSpeechStage stage, Duration elapsed) {
    if (!mounted || !_transcribing) return;
    setState(() => _voiceNotice = viktorSpeechProgressText(stage, elapsed));
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
        wav: wav, settings: _settings, onProgress: _onSpeechProgress);
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
                      AppTextField(
                        controller: folderCtrl,
                        labelText: 'ID каталога Yandex Cloud',
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
                      AppTextField(
                        controller: speechKeyCtrl,
                        variant: AppTextFieldVariant.password,
                        autocorrect: false,
                        enableSuggestions: false,
                        labelText: 'API-ключ для диктовки',
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: keyCtrl,
                      variant: AppTextFieldVariant.password,
                      autocorrect: false,
                      enableSuggestions: false,
                      labelText: provider == 'gigachat'
                          ? 'Ключ авторизации GigaChat API'
                          : 'API-ключ модели',
                      hintText: _cloudConnectionError == null &&
                              _settings.cloudProviders.contains(provider)
                          ? 'Ключ сохранён на сервере'
                          : 'Введите ключ для подключения',
                    ),
                    const SizedBox(height: 8),
                    if (_cloudConnectionError != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error),
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
                          Icon(Icons.check_circle_outline, color: AppColors.success),
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
                      fontSize: 16, color: AppColors.error)),
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
  Widget build(BuildContext context) => _buildViktorLayout(context);

}


/// Readable, bounded and independently scrollable bulk-duration preview.
/// This replaces the unreadable newline-separated 30+ row AlertDialog.
/// The footer stays fixed; scrolling the list never moves its actions.
class ViktorTagDurationReviewDialog extends StatefulWidget {
  const ViktorTagDurationReviewDialog({super.key, required this.preview});

  final ViktorBulkPreview preview;

  @override
  State<ViktorTagDurationReviewDialog> createState() =>
      _ViktorTagDurationReviewDialogState();
}

class _ViktorTagDurationReviewDialogState
    extends State<ViktorTagDurationReviewDialog> {
  final ScrollController _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  static String _clock(DateTime time) =>
      time.hour.toString().padLeft(2, '0') + ':' +
      time.minute.toString().padLeft(2, '0');

  static String _range(DateTime start, DateTime end) =>
      _clock(start) + '–' + _clock(end);

  static String _dayLabel(String key) {
    final parsed = DateTime.tryParse(key);
    if (parsed == null) return key;
    const weekdays = [
      'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница',
      'Суббота', 'Воскресенье',
    ];
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return weekdays[parsed.weekday - 1] + ', ' +
        parsed.day.toString() + ' ' + months[parsed.month - 1];
  }

  Widget _changeRow(ViktorBulkMove move, Color secondary, Color divider) {
    final previousStart = move.plan.startTime!;
    final previousEnd = move.plan.endDateTime!;
    final oldMinutes = previousEnd.difference(previousStart).inMinutes;
    final newMinutes = move.end.difference(move.start).inMinutes;
    final durationChanged = oldMinutes != newMinutes;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              move.plan.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_range(previousStart, previousEnd),
                    style: TextStyle(fontSize: 16, color: secondary)),
                Icon(Icons.arrow_forward, size: 16, color: secondary),
                Text(_range(move.start, move.end),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              durationChanged
                  ? 'Длительность: ' + oldMinutes.toString() +
                      ' → ' + newMinutes.toString() + ' мин'
                  : 'Только сдвиг времени · ' +
                      newMinutes.toString() + ' мин',
              style: TextStyle(fontSize: 16, color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 500;
    final horizontal = narrow ? 16.0 : 24.0;
    final groups = <String, List<ViktorBulkMove>>{};
    for (final move in widget.preview.moves) {
      groups.putIfAbsent(move.day, () => <ViktorBulkMove>[]).add(move);
    }
    final durationCount = widget.preview.moves.where((move) =>
      move.plan.endDateTime!.difference(move.plan.startTime!).inMinutes !=
      move.end.difference(move.start).inMinutes).length;
    final shiftCount = widget.preview.moves.length - durationCount;
    final entries = <Widget>[];
    for (final group in groups.entries) {
      entries.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 5),
        child: Row(
          children: [
            Expanded(child: Text(_dayLabel(group.key),
                style: const TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w700))),
            Text(group.value.length.toString() + ' планов',
                style: TextStyle(fontSize: 16,
                    color: scheme.onSurfaceVariant)),
          ],
        ),
      ));
      for (final move in group.value) {
        entries.add(_changeRow(
            move, scheme.onSurfaceVariant, scheme.outlineVariant));
      }
    }
    final dialogHeight = size.height < 790 ? size.height - 32 : 758.0;
    final dialogWidth = size.width < 764 ? size.width - 32 : 732.0;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Проверить длительности',
                          style: TextStyle(fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    durationCount.toString() + ' изменений длительности · ' +
                        shiftCount.toString() + ' сдвигов',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Сегодня и завтра. Завершённые, закреплённые и '
                    'повторяющиеся планы не меняются.',
                    style: TextStyle(fontSize: 16, height: 1.35,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: Scrollbar(
                controller: _listController,
                thumbVisibility: true,
                child: ListView(
                  key: const Key('viktor_duration_changes_list'),
                  controller: _listController,
                  padding: EdgeInsets.fromLTRB(
                      horizontal, 0, horizontal + 8, 12),
                  children: entries,
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Перед сохранением LIFE OS повторно проверит '
                    'все планы. Изменения применяются одной транзакцией.',
                    style: TextStyle(fontSize: 16, height: 1.35,
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton.ghost(
                        label: 'Отмена',
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      const SizedBox(width: 12),
                      AppButton.primary(
                        label: 'Применить',
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
