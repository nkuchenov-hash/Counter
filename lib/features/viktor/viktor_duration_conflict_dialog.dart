part of 'viktor_chat_page.dart';

enum ViktorDurationConflictChoice { dismiss, discuss, previewSubset }

/// A capacity conflict is a decision, not a terminal chat exception.
/// The only active alternative computes a NEW preview; it never writes.
class ViktorDurationConflictDialog extends StatelessWidget {
  const ViktorDurationConflictDialog({super.key, required this.conflict});

  final ViktorTagDurationOverflow conflict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final day = '${conflict.day.day.toString().padLeft(2, '0')}.'
        '${conflict.day.month.toString().padLeft(2, '0')}';
    return AlertDialog(
      title: const Text('Расписание не помещается',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$day · «${conflict.plan.title}» — '
                '${conflict.minutes} мин.',
                style: const TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'После пересчёта этой задаче не хватает места. '
                'Закреплённые встречи и повторяющиеся события '
                'сохраняют исходное время.',
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text('Что можно сделать',
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                '1. Применить изменения, которые помещаются. '
                'Для остальных сохранить исходную длительность. '
                'Виктор сначала покажет новый план на проверку.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                '2. Перенести часть гибких задач на другую дату '
                'после отдельного согласования.',
                style: TextStyle(fontSize: 16, height: 1.4,
                    color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Text(
                '3. Изменить длительности отдельных задач или '
                'освободить более ранние интервалы.',
                style: TextStyle(fontSize: 16, height: 1.4,
                    color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                'Пока ничего не сохранено. Для второго и третьего '
                'вариантов нужны дополнительные указания.',
                style: TextStyle(fontSize: 16,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton.ghost(
          label: 'Отмена',
          onPressed: () => Navigator.pop(
            context, ViktorDurationConflictChoice.dismiss),
        ),
        AppButton.secondary(
          label: 'Обсудить варианты',
          onPressed: () => Navigator.pop(
              context, ViktorDurationConflictChoice.discuss),
        ),
        AppButton.primary(
          label: 'Показать частичный вариант',
          onPressed: () => Navigator.pop(
              context, ViktorDurationConflictChoice.previewSubset),
        ),
      ],
    );
  }
}
