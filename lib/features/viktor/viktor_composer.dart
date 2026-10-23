part of 'viktor_chat_page.dart';

// Viktor's chat-style composer is kept separate from the conversation,
// voice lifecycle, settings, and action execution code.
extension _ViktorComposerUi on _ViktorChatPageState {
  Widget _buildComposer(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.enter):
                      _sendFromKeyboard,
                  const SingleActivator(LogicalKeyboardKey.numpadEnter):
                      _sendFromKeyboard,
                },
                child: TextField(
                  key: const Key('viktor_composer_input'),
                  controller: _controller,
                  enabled: !_busy && !_startingMic && !_transcribing,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 16, height: 1.45,
                    color: scheme.onSurface),
                  decoration: InputDecoration(
                    hintText: _listening
                        ? 'Идёт запись — нажмите стоп'
                        : 'Спросите Виктора или поручите задачу',
                    hintStyle: TextStyle(fontSize: 16,
                      color: scheme.onSurfaceVariant),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 9),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  AppIconButton(
                    icon: _listening ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                    tooltip: _listening ? 'Остановить диктовку'
                        : 'Продиктовать Виктору',
                    onPressed: _busy || _startingMic || _transcribing
                        ? null : _toggleMic,
                    selected: _listening,
                    size: AppIconButtonSize.s,
                    variant: AppIconButtonVariant.subtle,
                  ),
                  const Spacer(),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => AppIconButton(
                      icon: Icons.arrow_upward_rounded,
                      tooltip: 'Отправить Виктору',
                      onPressed: _busy || _listening ||
                              _transcribing || _startingMic ||
                              !_settingsReady ||
                              value.text.trim().isEmpty
                          ? null : () => unawaited(_send()),
                      variant: AppIconButtonVariant.filled,
                      size: AppIconButtonSize.s,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
