part of 'viktor_chat_page.dart';

// Composer has one visual surface and one compact row at rest. A multiline
// draft expands only the editable text area while controls stay at its bottom.
extension _ViktorComposerUi on _ViktorChatPageState {
  bool _canSubmitWithoutAiSettings(String text) =>
      text.trim().isNotEmpty &&
      ViktorDateScope.independentDateOnlyPlan(
        text.trim(), DatabaseService.instance.getProjectedToday()) != null;

  // Hardware Enter sends; Shift+Enter remains a native newline.
  void _sendFromKeyboard() {
    if (_busy || _listening || _transcribing || _startingMic ||
        (!_settingsReady && !_canSubmitWithoutAiSettings(_controller.text)) ||
        _controller.text.trim().isEmpty) return;
    unawaited(_send());
  }

  Widget _buildComposer(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kViktorChatContentMaxWidth),
          child: Material(
            key: const Key('viktor_composer_surface'),
            color: scheme.surfaceContainer,
            elevation: 6,
            shadowColor: scheme.shadow.withValues(alpha: 0.27),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.75),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                          // LIFE OS globally fills inputs with a contrasting
                          // surface. In this single-surface chat composer that
                          // becomes the white rectangular inset on web.
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: _listening
                              ? 'Идёт запись — нажмите стоп'
                              : 'Спросите Виктора…',
                          // Hint must not wrap and inflate the idle bar on phones.
                          hintMaxLines: 1,
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
                            horizontal: 12, vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AppIconButton(
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
                    builder: (context, value, _) {
                      final canSend = !_busy && !_listening &&
                          !_transcribing && !_startingMic &&
                          (_settingsReady ||
                           _canSubmitWithoutAiSettings(value.text)) &&
                          value.text.trim().isNotEmpty;
                      // A 48px accessible touch target surrounds the visible
                      // 42px disc, leaving even optical margins. Never paint the whole touch
                      // target as a giant disc near the capsule edges.
                      return Tooltip(
                        message: 'Отправить Виктору',
                        child: Semantics(
                          button: true,
                          enabled: canSend,
                          label: 'Отправить Виктору',
                          child: SizedBox.square(
                            key: const Key('viktor_send_touch_target'),
                            dimension: 48,
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                key: const Key('viktor_send_tap'),
                                onTap: canSend
                                    ? () => unawaited(_send())
                                    : null,
                                customBorder: const CircleBorder(),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 42,
                                    child: DecoratedBox(
                                      key: const Key('viktor_send_button_surface'),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: canSend
                                            ? scheme.onSurface
                                            : scheme.onSurface
                                                .withValues(alpha: 0.10),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 22,
                                          color: canSend
                                              ? scheme.surface
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
