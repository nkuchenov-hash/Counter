part of 'viktor_chat_page.dart';

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
                      AppIconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icons.close,
                        variant: AppIconButtonVariant.subtle,
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
