import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_executor.dart';
import 'package:counter/data/ai/viktor_gateway.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Single LIFE OS assistant entry point. Replaces the old record-only mic FAB.
/// No overlay over the planner, no extra button beside bottom navigation.
class ViktorChatPage extends StatefulWidget {
  const ViktorChatPage({super.key, required this.wallDay});
  final DateTime wallDay;

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
  final _speech = stt.SpeechToText();
  final _messages = <_ViktorMessage>[];
  final _settings = ViktorModelSettings.instance;
  final _gateway = const ViktorGateway();
  bool _busy = false;
  bool _listening = false;
  bool _settingsReady = false;
  String _speechPrefix = '';

  @override
  void initState() {
    super.initState();
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
      _settings.ensureOwner(
        DatabaseService.instance.currentProfileId ?? 'signed_out',
      );
      if (mounted) setState(() => _settingsReady = true);
    } catch (_) {
      if (mounted) setState(() => _settingsReady = true);
    }
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
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
    if (_speech.isListening) await _speech.stop();
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
      final approved = await _confirm(actions, preview);
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

  Future<void> _toggleMic() async {
    if (_busy) return;
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!kIsWeb) {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        _push('Разрешите доступ к микрофону в настройках устройства.');
        return;
      }
    }
    try {
      final ready = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() => _listening = false);
            _push('Ошибка распознавания голоса: ${e.errorMsg}');
          }
        },
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _listening = false);
          }
        },
      );
      if (!ready) {
        _push('Распознавание речи недоступно. Можно ввести команду текстом.');
        return;
      }
      _speechPrefix = _controller.text.trim();
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          setState(() {
            _controller.text = [
              if (_speechPrefix.isNotEmpty) _speechPrefix,
              if (words.isNotEmpty) words,
            ].join(' ');
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
            if (result.finalResult) _listening = false;
          });
        },
        localeId: currentLocale.value.toLowerCase().startsWith('ru')
            ? 'ru_RU' : 'en_US',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
      );
      if (mounted) setState(() => _listening = true);
    } catch (_) {
      if (mounted) _push('Микрофон недоступен. Попробуйте текстовый ввод.');
    }
  }

  Future<void> _openSettings() async {
    if (!_settingsReady) await _loadSettings();
    if (!mounted) return;
    var mode = _settings.mode;
    var provider = _settings.provider;
    var model = _settings.model;
    final keyCtrl = TextEditingController(text: _settings.sessionApiKey);
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
                      DropdownMenuItem(value: 'hosted',
                        child: Text('ИИ LIFE OS · включено в Pro')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      updateDialog(() {
                        mode = v;
                        if (mode == 'hosted') {
                          provider = 'openai';
                          model = 'gpt-4o-mini';
                        }
                      });
                    },
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyCtrl,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'API-ключ поставщика',
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
      await _settings.save();
      if (mounted) setState(() {});
    }
    keyCtrl.dispose();
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
                          onPressed: _busy ? null : _toggleMic,
                          selected: _listening,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_busy,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintText: _listening ? 'Слушаю…' :
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
                          onPressed: _busy || !_settingsReady ? null :
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
