part of 'viktor_chat_page.dart';

extension _ViktorChatLayout on _ViktorChatPageState {
  Widget _buildViktorLayout(BuildContext context) {
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
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: Scrollbar(
                  key: const Key('viktor_edge_scrollbar'),
                  controller: _messagesScrollController,
                  thumbVisibility: false,
                  trackVisibility: false,
                  thickness: 3,
                  radius: const Radius.circular(4),
                  interactive: false,
                  child: ListView.builder(
                    key: const Key('viktor_chat_messages_viewport'),
                    controller: _messagesScrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (ctx, index) {
                      late final Widget content;
                      if (_busy && index == 0) {
                        content = Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        );
                      } else {
                        final offset = _busy ? 1 : 0;
                        final message = _messages[
                            _messages.length - 1 - (index - offset)];
                        content = Align(
                          alignment: message.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            constraints: const BoxConstraints(maxWidth: 610),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: message.isUser
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(message.content, style: TextStyle(
                                  fontSize: 16, height: 1.45,
                                  color: message.isUser
                                      ? scheme.onPrimaryContainer : scheme.onSurface)),
                                if (!_busy && index == 0 && !message.isUser &&
                                    message.content.startsWith('Не удалось выполнить запрос.'))
                                  AppButton.ghost(
                                    label: 'Повторить',
                                    onPressed: _retryLastCommand,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Center(
                        child: ConstrainedBox(
                          key: const Key('viktor_message_content_column'),
                          constraints: const BoxConstraints(maxWidth: kViktorChatContentMaxWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            child: content,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kViktorChatContentMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_historyNotice != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.cloud_off_outlined, size: 22,
                              color: scheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              _historyNotice!,
                              style: TextStyle(fontSize: 16, height: 1.4,
                                color: scheme.onSurfaceVariant),
                            )),
                            if (_dialogueStore.pendingCount > 0) ...[
                              const SizedBox(width: 8),
                              AppButton.ghost(
                                label: 'Повторить',
                                onPressed: () => unawaited(_retryHistorySync()),
                              ),
                            ],
                          ],
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
                    _buildComposer(scheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
