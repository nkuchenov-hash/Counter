import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'package:flutter/material.dart';

class PathEditDraft {
  const PathEditDraft({required this.name, required this.goal});

  final String name;
  final String goal;
}

class PathStageEditDraft {
  const PathStageEditDraft({
    required this.title,
    required this.completionCriteria,
  });

  final String title;
  final String completionCriteria;
}

class PathActionEditDraft {
  const PathActionEditDraft({
    required this.text,
    required this.expectedResult,
    required this.minutes,
    required this.description,
    required this.checklist,
  });

  final String text;
  final String expectedResult;
  final int minutes;
  final String description;
  final List<PathChecklistItemSnapshot> checklist;
}

enum _PathOptionAction { edit }

/// Visible Options affordance for a Path stage/item.
///
/// Movement is intentionally not attached to this button. Paths follows the
/// same hold-to-move interaction as Plans and Notes: holding the stage header
/// or item row starts reorder, while Options remains a normal editing menu.
class PathOptionsButton extends StatelessWidget {
  const PathOptionsButton({
    super.key,
    required this.ru,
    required this.onEdit,
    this.tooltip,
  });

  final bool ru;
  final VoidCallback onEdit;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final label = tooltip ?? (ru ? 'Опции' : 'Options');
    return PopupMenuButton<_PathOptionAction>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == _PathOptionAction.edit) onEdit();
      },
      itemBuilder: (context) => [
        PopupMenuItem<_PathOptionAction>(
          value: _PathOptionAction.edit,
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 19),
              const SizedBox(width: 10),
              Text(ru ? 'Изменить' : 'Edit'),
            ],
          ),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox.square(
          dimension: 36,
          child: Icon(Icons.more_horiz_rounded, size: 21, color: color),
        ),
      ),
    );
  }
}

String? _pathRequiredField(bool ru, String? value) =>
    value == null || value.trim().isEmpty
    ? (ru ? 'Обязательное поле' : 'Required field')
    : null;

String? _pathMinutesField(bool ru, String? value) {
  final minutes = int.tryParse(value?.trim() ?? '');
  if (minutes == null || minutes < 1 || minutes > 30) {
    return ru ? 'От 1 до 30 минут' : 'Enter 1–30 minutes';
  }
  return null;
}

Future<Map<String, String>?> showPathNewActionDraft({
  required BuildContext context,
  required bool ru,
}) => showAppFormDialog(
  context: context,
  title: ru ? 'Добавить пункт этапа' : 'Add stage item',
  cancelLabel: ru ? 'Отмена' : 'Cancel',
  submitLabel: ru ? 'Добавить' : 'Add',
  fields: [
    AppFormDialogField(
      keyName: 'action',
      label: ru ? 'Пункт этапа' : 'Stage item',
      autofocus: true,
      validator: (value) => _pathRequiredField(ru, value),
    ),
    AppFormDialogField(
      keyName: 'result',
      label: ru ? 'Ожидаемый результат' : 'Expected result',
      validator: (value) => _pathRequiredField(ru, value),
    ),
    AppFormDialogField(
      keyName: 'minutes',
      label: ru ? 'Минуты' : 'Minutes',
      initialValue: '15',
      keyboardType: TextInputType.number,
      validator: (value) => _pathMinutesField(ru, value),
    ),
  ],
);

Future<Map<String, String>?> showPathNewStageDraft({
  required BuildContext context,
  required bool ru,
}) => showAppFormDialog(
  context: context,
  title: ru ? 'Добавить этап' : 'Add stage',
  cancelLabel: ru ? 'Отмена' : 'Cancel',
  submitLabel: ru ? 'Добавить этап' : 'Add stage',
  fields: [
    AppFormDialogField(
      keyName: 'title',
      label: ru ? 'Название этапа' : 'Stage title',
      autofocus: true,
      validator: (value) => _pathRequiredField(ru, value),
    ),
    AppFormDialogField(
      keyName: 'criteria',
      label: ru ? 'Готово, когда' : 'Done when',
      validator: (value) => _pathRequiredField(ru, value),
    ),
    AppFormDialogField(
      keyName: 'action',
      label: ru ? 'Первый пункт' : 'First item',
      validator: (value) => _pathRequiredField(ru, value),
    ),
    AppFormDialogField(
      keyName: 'result',
      label: ru ? 'Ожидаемый результат' : 'Expected result',
      validator: (value) => _pathRequiredField(ru, value),
    ),
    AppFormDialogField(
      keyName: 'minutes',
      label: ru ? 'Минуты' : 'Minutes',
      initialValue: '15',
      keyboardType: TextInputType.number,
      validator: (value) => _pathMinutesField(ru, value),
    ),
  ],
);

Future<PathEditDraft?> showPathEditSheet({
  required BuildContext context,
  required bool ru,
  required ProjectPathSnapshot path,
}) async {
  final values = await _showTwoFieldSheet(
    context: context,
    title: ru ? 'Изменить путь' : 'Edit Path',
    firstLabel: ru ? 'Название пути' : 'Path name',
    firstValue: path.name,
    secondLabel: ru ? 'Цель пути' : 'Path goal',
    secondValue: path.goal,
    secondMinLines: 3,
    saveLabel: ru ? 'Сохранить' : 'Save',
  );
  if (values == null) return null;
  return PathEditDraft(name: values.$1, goal: values.$2);
}

Future<PathStageEditDraft?> showPathStageEditSheet({
  required BuildContext context,
  required bool ru,
  required PathStageSnapshot stage,
}) async {
  final values = await _showTwoFieldSheet(
    context: context,
    title: ru ? 'Изменить этап' : 'Edit stage',
    firstLabel: ru ? 'Формулировка этапа' : 'Stage wording',
    firstValue: stage.title,
    secondLabel: ru ? 'Критерий завершения' : 'Completion criteria',
    secondValue: stage.completionCriteria,
    secondMinLines: 3,
    saveLabel: ru ? 'Сохранить' : 'Save',
  );
  if (values == null) return null;
  return PathStageEditDraft(title: values.$1, completionCriteria: values.$2);
}

Future<PathActionEditDraft?> showPathActionEditSheet({
  required BuildContext context,
  required bool ru,
  required PathActionSnapshot action,
}) {
  return showModalBottomSheet<PathActionEditDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PathActionEditSheet(ru: ru, action: action),
  );
}

Future<(String, String)?> _showTwoFieldSheet({
  required BuildContext context,
  required String title,
  required String firstLabel,
  required String firstValue,
  required String secondLabel,
  required String secondValue,
  required int secondMinLines,
  required String saveLabel,
}) {
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _TwoFieldPathEditSheet(
      title: title,
      firstLabel: firstLabel,
      firstValue: firstValue,
      secondLabel: secondLabel,
      secondValue: secondValue,
      secondMinLines: secondMinLines,
      saveLabel: saveLabel,
    ),
  );
}

class _TwoFieldPathEditSheet extends StatefulWidget {
  const _TwoFieldPathEditSheet({
    required this.title,
    required this.firstLabel,
    required this.firstValue,
    required this.secondLabel,
    required this.secondValue,
    required this.secondMinLines,
    required this.saveLabel,
  });

  final String title;
  final String firstLabel;
  final String firstValue;
  final String secondLabel;
  final String secondValue;
  final int secondMinLines;
  final String saveLabel;

  @override
  State<_TwoFieldPathEditSheet> createState() => _TwoFieldPathEditSheetState();
}

class _TwoFieldPathEditSheetState extends State<_TwoFieldPathEditSheet> {
  late final TextEditingController _first = TextEditingController(
    text: widget.firstValue,
  );
  late final TextEditingController _second = TextEditingController(
    text: widget.secondValue,
  );

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _save() {
    final first = _first.text.trim();
    final second = _second.text.trim();
    if (first.isEmpty || second.isEmpty) return;
    Navigator.of(context).pop((first, second));
  }

  @override
  Widget build(BuildContext context) {
    return _PathSheetFrame(
      title: widget.title,
      saveLabel: widget.saveLabel,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PathFieldLabel(widget.firstLabel),
          TextField(
            controller: _first,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 22),
          _PathFieldLabel(widget.secondLabel),
          TextField(
            controller: _second,
            minLines: widget.secondMinLines,
            maxLines: 8,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRowDraft {
  _ChecklistRowDraft({
    required this.id,
    required String text,
    required this.done,
  }) : controller = TextEditingController(text: text);

  final String id;
  final TextEditingController controller;
  bool done;
}

class _PathActionEditSheet extends StatefulWidget {
  const _PathActionEditSheet({required this.ru, required this.action});

  final bool ru;
  final PathActionSnapshot action;

  @override
  State<_PathActionEditSheet> createState() => _PathActionEditSheetState();
}

class _PathActionEditSheetState extends State<_PathActionEditSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.action.text,
  );
  late final TextEditingController _result = TextEditingController(
    text: widget.action.expectedResult,
  );
  late final TextEditingController _minutes = TextEditingController(
    text: '${widget.action.minutes}',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.action.description,
  );
  late final List<_ChecklistRowDraft> _checklist = [
    for (final item in widget.action.checklist)
      _ChecklistRowDraft(id: item.id, text: item.text, done: item.isDone),
  ];

  @override
  void dispose() {
    _text.dispose();
    _result.dispose();
    _minutes.dispose();
    _description.dispose();
    for (final item in _checklist) {
      item.controller.dispose();
    }
    super.dispose();
  }

  void _addChecklistItem() {
    setState(() {
      _checklist.add(
        _ChecklistRowDraft(
          id: 'check-${DateTime.now().microsecondsSinceEpoch}',
          text: '',
          done: false,
        ),
      );
    });
  }

  void _removeChecklistItem(int index) {
    if (index < 0 || index >= _checklist.length) return;
    final removed = _checklist.removeAt(index);
    removed.controller.dispose();
    setState(() {});
  }

  void _save() {
    final text = _text.text.trim();
    final result = _result.text.trim();
    final minutes = int.tryParse(_minutes.text.trim());
    if (text.isEmpty ||
        result.isEmpty ||
        minutes == null ||
        minutes < 1 ||
        minutes > 30) {
      return;
    }
    final checklist = <PathChecklistItemSnapshot>[];
    for (final item in _checklist) {
      final value = item.controller.text.trim();
      if (value.isEmpty) continue;
      checklist.add(
        PathChecklistItemSnapshot(id: item.id, text: value, isDone: item.done),
      );
    }
    Navigator.of(context).pop(
      PathActionEditDraft(
        text: text,
        expectedResult: result,
        minutes: minutes,
        description: _description.text.trim(),
        checklist: checklist,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ru = widget.ru;
    return _PathSheetFrame(
      title: ru ? 'Пункт этапа' : 'Stage item',
      saveLabel: ru ? 'Сохранить' : 'Save',
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PathFieldLabel(ru ? 'Формулировка' : 'Wording'),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          _PathFieldLabel(ru ? 'Конечный результат' : 'Final result'),
          TextField(
            controller: _result,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          _PathFieldLabel(ru ? 'Описание / контекст' : 'Description / context'),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 12,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: ru
                  ? 'Что важно знать, ссылки, пояснения, промежуточные детали…'
                  : 'Context, links, notes and intermediate details…',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PathFieldLabel(
                  ru ? 'Мини-чеклист' : 'Mini checklist',
                  bottom: 0,
                ),
              ),
              AppButton.ghost(
                label: ru ? 'Добавить' : 'Add',
                icon: Icons.add_rounded,
                size: AppButtonSize.s,
                onPressed: _addChecklistItem,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_checklist.isEmpty)
            Text(
              ru
                  ? 'Необязательно. Добавляйте только внутренние шаги, которые помогают выполнить этот пункт.'
                  : 'Optional. Add only internal steps that help complete this item.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var index = 0; index < _checklist.length; index++) ...[
              _PathChecklistEditorRow(
                key: ValueKey(_checklist[index].id),
                item: _checklist[index],
                onChanged: () => setState(() {}),
                onDelete: () => _removeChecklistItem(index),
              ),
              if (index != _checklist.length - 1) const SizedBox(height: 8),
            ],
          const SizedBox(height: 20),
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PathFieldLabel(ru ? 'Время, мин' : 'Minutes'),
                TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathChecklistEditorRow extends StatelessWidget {
  const _PathChecklistEditorRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final _ChecklistRowDraft item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: item.done,
          onChanged: (value) {
            item.done = value == true;
            onChanged();
          },
        ),
        Expanded(
          child: TextField(
            controller: item.controller,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.close_rounded, size: 19),
        ),
      ],
    );
  }
}

class _PathFieldLabel extends StatelessWidget {
  const _PathFieldLabel(this.text, {this.bottom = 8});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PathSheetFrame extends StatelessWidget {
  const _PathSheetFrame({
    required this.title,
    required this.saveLabel,
    required this.onSave,
    required this.child,
  });

  final String title;
  final String saveLabel;
  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: .92,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        AppButton.primary(
                          label: saveLabel,
                          size: AppButtonSize.s,
                          onPressed: onSave,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                      child: child,
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
