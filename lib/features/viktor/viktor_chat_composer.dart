import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A bounded, auto-growing ChatGPT-style composer for Viktor (web/mobile).
/// No assistant/network state is owned by this presentation widget.
class ViktorChatComposer extends StatelessWidget {
  const ViktorChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onMicrophone,
    required this.inputEnabled,
    required this.microphoneEnabled,
    required this.sendEnabled,
    required this.isListening,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMicrophone;
  final bool inputEnabled;
  final bool microphoneEnabled;
  final bool sendEnabled;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxEditorHeight =
        (MediaQuery.sizeOf(context).height * 0.34).clamp(120.0, 280.0);

    void submit() {
      if (inputEnabled && sendEnabled && controller.text.trim().isNotEmpty) {
        onSend();
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        )),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxEditorHeight),
                  child: CallbackShortcuts(
                    // Physical Enter sends; Shift+Enter adds a newline.
                    // Mobile soft keyboard adds lines; arrow sends.
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter): submit,
                      const SingleActivator(LogicalKeyboardKey.numpadEnter):
                          submit,
                    },
                    child: TextField(
                      controller: controller,
                      enabled: inputEnabled,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: isListening
                            ? 'Идёт запись — нажмите стоп'
                            : 'Спросите Виктора…',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: isListening
                          ? Icons.stop_circle_outlined
                          : Icons.mic_none_rounded,
                      tooltip: isListening
                          ? 'Остановить диктовку'
                          : 'Продиктовать Виктору',
                      onPressed: microphoneEnabled ? onMicrophone : null,
                      selected: isListening,
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, child) => AppIconButton(
                        icon: Icons.arrow_upward_rounded,
                        tooltip: 'Отправить Виктору',
                        onPressed: sendEnabled && inputEnabled &&
                                value.text.trim().isNotEmpty
                            ? submit
                            : null,
                        variant: AppIconButtonVariant.filled,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
