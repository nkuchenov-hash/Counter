part of 'viktor_chat_page.dart';

// Composer has one visual surface and one compact row at rest. A multiline
// draft expands only the editable text area while controls stay at its bottom.
extension _ViktorComposerUi on _ViktorChatPageState {
  Widget _buildComposer(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Material(
            key: const Key('viktor_composer_surface'),
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CallbackShortcuts(
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
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          // Composer itself owns the sole input surface.
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: _listening
                              ? 'Идёт запись — нажмите стоп'
                              : 'Спросите Виктора…',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AppIconButton(
                    circular: true,
                    icon: _listening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                    tooltip: _listening
                        ? 'Остановить диктовку'
                        : 'Продиктовать Виктору',
                    onPressed: _busy || _startingMic || _transcribing
                        ? null : _toggleMic,
                    selected: _listening,
                    size: AppIconButtonSize.s,
                    variant: AppIconButtonVariant.subtle,
                  ),
                  const SizedBox(width: 4),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => AppIconButton(
                      circular: true,
                      highContrast: true,
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
            ),
          ),
        ),
      ),
    );
  }
}
