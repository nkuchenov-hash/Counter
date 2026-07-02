import 'package:counter/core/services/desktop_voice_attempt_log.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// In-app Desktop Voice diagnostics dialog.
///
/// Renders the latest desktop-voice attempt (hotkey → task created) in plain
/// non-developer language with a Copy button. Replaces the requirement to tail
/// %TEMP%\counter_desktop_voice_pipeline.log: the same information is now
/// visible inside the app, refreshable in real time.
Future<void> showDesktopVoiceAttemptDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _DesktopVoiceAttemptDialog(),
  );
}

/// Test injection point for the clipboard write performed by the Copy button.
/// In production this is `null` and the dialog calls [Clipboard.setData]
/// directly; tests can override it to capture the copied text without spinning
/// up the real flutter/platform method channel.
@visibleForTesting
typedef DesktopVoiceAttemptCopyFn = Future<void> Function(String text);
@visibleForTesting
class DesktopVoiceAttemptDialogTestHooks {
  DesktopVoiceAttemptDialogTestHooks._();
  static DesktopVoiceAttemptCopyFn? copyOverride;
}

class _DesktopVoiceAttemptDialog extends StatefulWidget {
  const _DesktopVoiceAttemptDialog();

  @override
  State<_DesktopVoiceAttemptDialog> createState() =>
      _DesktopVoiceAttemptDialogState();
}

class _DesktopVoiceAttemptDialogState extends State<_DesktopVoiceAttemptDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final isRu = loc == 'ru';
    return ValueListenableBuilder<DesktopVoiceAttempt?>(
      valueListenable: DesktopVoiceAttemptLog.instance.listenable,
      builder: (context, attempt, _) {
        final hasAttempt = attempt != null;
        final text = hasAttempt
            ? attempt.toPlainText()
            : (isRu
                ? 'Голосовая команда ещё не использовалась.\n\n'
                    'Нажмите горячую клавишу голоса (по умолчанию Ctrl+Shift+Space), чтобы начать.'
                : 'No voice command attempted yet.\n\n'
                    'Press the voice hotkey (default Ctrl+Shift+Space) to start.');
        return AlertDialog(
          title: Text(isRu ? 'Голосовая команда' : 'Voice command'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: hasAttempt
                  ? _AttemptView(attempt: attempt, isRu: isRu)
                  : Text(text),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: hasAttempt
                  ? () async {
                      final fn = DesktopVoiceAttemptDialogTestHooks.copyOverride;
                      if (fn != null) {
                        await fn(text);
                      } else {
                        await Clipboard.setData(ClipboardData(text: text));
                      }
                      if (!mounted) return;
                      setState(() => _copied = true);
                    }
                  : null,
              icon: const Icon(Icons.copy_rounded),
              label: Text(_copied
                  ? (isRu ? 'Скопировано' : 'Copied')
                  : (isRu
                      ? 'Скопировать диагностику'
                      : 'Copy voice diagnostics')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isRu ? 'Закрыть' : 'Close'),
            ),
          ],
        );
      },
    );
  }
}

class _AttemptView extends StatelessWidget {
  const _AttemptView({required this.attempt, required this.isRu});
  final DesktopVoiceAttempt attempt;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = theme.textTheme.bodyMedium!;
    final fLabel = f.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusHeader(attempt: attempt, isRu: isRu),
        const SizedBox(height: 12),
        _row(isRu ? 'Горячая клавиша' : 'Hotkey received',
            _yn(attempt.hotkeyReceived, isRu), f, fLabel),
        _row(isRu ? 'Запись начата' : 'Recording started',
            _yn(attempt.recordingStarted, isRu), f, fLabel),
        _row(isRu ? 'Зафиксирован звук' : 'Microphone input detected',
            _yn(attempt.micInputDetected, isRu), f, fLabel),
        _row(
            isRu ? 'Распознанный текст' : 'Heard',
            attempt.transcript.isEmpty
                ? (isRu ? '(пусто)' : '(empty)')
                : '"${attempt.transcript}"',
            f,
            fLabel),
        _row(isRu ? 'Парсер' : 'Parser', attempt.parserConfidence, f, fLabel),
        _row(
            isRu ? 'Категория / область' : 'Matched scope',
            attempt.matchedScope.isEmpty
                ? (isRu ? '—' : '—')
                : attempt.matchedScope,
            f,
            fLabel),
        _row(
            isRu ? 'Задача' : 'Task title',
            attempt.taskTitle.isEmpty
                ? (isRu ? '—' : '—')
                : attempt.taskTitle,
            f,
            fLabel),
        _row(isRu ? 'Сохранение' : 'Save result', attempt.writeRecordResult, f,
            fLabel),
      ],
    );
  }

  Widget _row(String label, String value, TextStyle f, TextStyle fLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: fLabel),
          ),
          Expanded(child: Text(value, style: f)),
        ],
      ),
    );
  }

  String _yn(bool v, bool isRu) {
    if (isRu) return v ? 'да' : 'нет';
    return v ? 'yes' : 'no';
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.attempt, required this.isRu});
  final DesktopVoiceAttempt attempt;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final (icon, color, headline) = _visual();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
                if (attempt.statusDetail.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      attempt.statusDetail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _visual() {
    switch (attempt.status) {
      case DesktopVoiceAttemptStatus.taskCreated:
        return (
          Icons.check_circle_rounded,
          const Color(0xFF1F8A4C),
          isRu ? 'Задача создана' : 'Task created',
        );
      case DesktopVoiceAttemptStatus.inProgress:
        return (
          Icons.graphic_eq_rounded,
          const Color(0xFF1F6FEB),
          isRu ? 'Выполняется…' : 'In progress…',
        );
      case DesktopVoiceAttemptStatus.notRecognized:
        return (
          Icons.help_outline_rounded,
          const Color(0xFFB0700A),
          isRu ? 'Команда не распознана' : 'Not recognized',
        );
      case DesktopVoiceAttemptStatus.micError:
        return (
          Icons.mic_off_rounded,
          const Color(0xFFB3261E),
          isRu ? 'Ошибка микрофона' : 'Microphone error',
        );
      case DesktopVoiceAttemptStatus.sttError:
        return (
          Icons.closed_caption_disabled_rounded,
          const Color(0xFFB3261E),
          isRu ? 'Ошибка распознавания' : 'Recognition error',
        );
      case DesktopVoiceAttemptStatus.saveError:
        return (
          Icons.cloud_off_rounded,
          const Color(0xFFB3261E),
          isRu ? 'Не удалось сохранить' : 'Save failed',
        );
      case DesktopVoiceAttemptStatus.cancelled:
        return (
          Icons.cancel_outlined,
          const Color(0xFF6B6B6B),
          isRu ? 'Отменено' : 'Cancelled',
        );
    }
  }
}
