import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_executor.dart';
import 'package:counter/data/ai/viktor_gateway.dart';
import 'package:counter/data/ai/viktor_voice_gateway.dart';
import 'package:counter/data/ai/viktor_voice_recorder.dart';
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

class _ViktorMessage {
  const _ViktorMessage(this.text, {this.mine = false});
  final String text;
  final bool mine;
}

class _ViktorChatPageState extends State<ViktorChatPage> {
  final _controller = TextEditingController();
  final _recorder = ViktorVoiceRecorder();
  final _voiceGateway = const ViktorVoiceGateway();
  final _messages = <_ViktorMessage>[];
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

  @override
  void initState() {
    super.initState();
    _recorder.addListener(_onRecorderChanged);
    unawaited(_loadSettings());
    _messages.add(const _ViktorMessage(
      'Я Виктор. Могу посмотреть планы, составить расписание, изменить '
      'длительность, переставить задачи или начать запись. '
      'Напишите команду или нажмите микрофон.',
    ));
  }

  Future<void> _loadSettings() async {
    try {
      await _settings.load();
      await DatabaseService.instance.ensurePocketBaseReady();
      _settings.ensureOwner(
        DatabaseService.instance.pocketBase.authStore.record?.id ?? 'signed_out',
      );
      if (mounted) setState(() => _settingsReady = true);
    } catch (_) {
      if (mounted) setState(() => _settingsReady = true);
    }
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
    setState(() => _messages.add(_ViktorMessage(value, mine: mine)));
  }

  Future<void> _send() async {
    if (_busy) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    if (!_settingsReady) return;
    if (_settings.mode == 'byok' && _settings.sessionApiKey.isEmpty) {
      await _openSettings();
      if (!mounted || _settings.sessionApiKey.isEmpty) return;
    }
    if (_listening || _transcribing || _startingMic) return;
    if (!mounted) return;
    _controller.clear();
    _push(input, mine: true);
    setState(() => _busy = true);
    try {
      final db = DatabaseService.instance;
      final plans = await db.getPlanningTasksForWallDate(widget.wallDay);
      final response = await _gateway.propose(
        input: input,
        wallDay: widget.wallDay,
        plans: plans,
        settings: _settings,
        selectedPlanIds: widget.selectedPlanIds,
      );
      if (!mounted) return;
      if (response.message.trim().isNotEmpty) _push(response.message.trim());
      final actions = response.actions;
      if (actions == null) return;
      final executor = ViktorExecutor(db);
      final preview = await executor.describe(actions, widget.wallDay);
      if (!mounted) return;
      if (!actions.hasMutations) {
        _push(preview);
        return;
      }
      // An explicit, unambiguous two-card swap is a reversible low-scope
      // schedule command. The Brain still validates current state and guards.
      // Other mutations retain their mandatory explicit approval dialog.
      final isSimpleSwap = actions.actions.length == 1 &&
          actions.actions.single.name == 'swap_plan_positions';
      final approved = isSimpleSwap ? true : await _confirm(actions, preview);
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
    // Simple end-of-utterance detection. The stop button remains available,
    // so failure to detect silence never blocks manual completion.
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

  String _voiceErrorText(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('permission') || value.contains('not-allowed')) {
      return 'Доступ к микрофону запрещён. Разрешите запись звука '
          'в настройках браузера или устройства.';
    }
    if (value.contains('recording_too_short') ||
        value.contains('no_speech_detected')) {
      return 'Речь не обнаружена. Запишите голосовую команду ещё раз.';
    }
    if (value.contains('speech_api_key_required')) {
      return 'Укажите API-ключ для распознавания речи в настройках Виктора.';
    }
    if (value.contains('speech_provider_rejected')) {
      return 'Провайдер отклонил распознавание. Проверьте API-ключ, '
          'баланс и доступ к голосовой модели.';
    }
    if (value.contains('auth_required')) {
      return 'Для распознавания войдите в LIFE OS.';
    }
    if (value.contains('timeout') || value.contains('unreachable') ||
        value.contains('network')) {
      return 'Нет ответа от сервиса распознавания. '
          'Проверьте сеть и попробуйте ещё раз.';
    }
    return 'Не удалось обработать звук. Попробуйте ещё раз.';
  }

  Future<void> _finishRecording() async {
    var shouldSubmit = false;
    if (_startingMic || _transcribing || !_recorder.isRecording) return;
    setState(() {
      _startingMic = true;
      _listening = false;
      _voiceNotice = 'Завершаю запись…';
    });
    try {
      final wav = await _recorder.stop();
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
      setState(() => _voiceNotice = _voiceErrorText(error));
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
    final missingKey = _settings.provider == 'openrouter'
        ? _settings.sessionSpeechApiKey.isEmpty
        : _settings.sessionApiKey.isEmpty;
    if (missingKey) {
      await _openSettings();
      if (!mounted) return;
      final stillMissing = _settings.provider == 'openrouter'
          ? _settings.sessionSpeechApiKey.isEmpty
          : _settings.sessionApiKey.isEmpty;
      if (stillMissing) {
        setState(() => _voiceNotice =
            'Для диктовки нужен API-ключ провайдера распознавания.');
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
      if (mounted) setState(() => _voiceNotice = _voiceErrorText(error));
    } finally {
      if (mounted) setState(() => _startingMic = false);
    }
  }

  Future<void> _openSettings() async {
    if (!_settingsReady) await _loadSettings();
    if (!mounted) return;
    var mode = _settings.mode;
    var provider = _settings.provider;
    var model = _settings.model;
    final keyCtrl = TextEditingController(text: _settings.sessionApiKey);
    final folderCtrl = TextEditingController(text: _settings.yandexFolderId);
    var speechProvider = _settings.speechProvider;
    final speechKeyCtrl = TextEditingController(text: _settings.sessionSpeechApiKey);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
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
                    if (provider == 'openrouter' ||
                        provider == 'gigachat' || provider == 'yandex') ...[
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
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ключ используется только в этом сеансе. '
                      'Он не сохраняется в приложении или PocketBase.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ] else
                    const Text(
                      'Встроенная модель станет доступна после включения '
                      'подписки и серверного учёта лимитов.',
                      style: TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton.ghost(label: 'Отмена',
              onPressed: () => Navigator.pop(dialogContext, false)),
            AppButton.primary(label: 'Сохранить',
              onPressed: () => Navigator.pop(dialogContext, true)),
          ],
        ),
      ),
    );
    if (saved == true) {
      _settings.mode = mode;
      _settings.provider = provider;
      _settings.model = model;
      _settings.sessionApiKey = keyCtrl.text.trim();
      _settings.yandexFolderId = folderCtrl.text.trim();
      _settings.speechProvider = speechProvider;
      _settings.sessionSpeechApiKey = speechKeyCtrl.text.trim();
      await _settings.save();
      if (mounted) setState(() {});
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
                        alignment: message.mine ? Alignment.centerRight :
                            Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: const BoxConstraints(maxWidth: 610),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: message.mine ? scheme.primaryContainer :
                                scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(message.text,
                            style: TextStyle(
                              fontSize: 16, height: 1.45,
                              color: message.mine ? scheme.onPrimaryContainer :
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
                            'Нажмите квадрат, чтобы закончить запись и получить текст.',
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
