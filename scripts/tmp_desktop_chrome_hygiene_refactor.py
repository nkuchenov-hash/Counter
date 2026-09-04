from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8')


def write(path, text):
    Path(path).write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)


# Move Planning quick-entry layout glue out of the already-oversized page.
path = 'lib/features/planning/widgets/planning_filter_controls.dart'
text = read(path)
if 'class PlanningQuickAddChrome' in text:
    raise SystemExit('PlanningQuickAddChrome already exists')
text = text.rstrip() + r'''


/// Planning quick-entry chrome. Desktop uses the same canonical entry row as
/// Timeline; phone/tablet preserve the established tag-first arrangement.
class PlanningQuickAddChrome extends StatelessWidget {
  const PlanningQuickAddChrome({
    super.key,
    required this.desktop,
    required this.scheme,
    required this.tagStrip,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.addLabel,
    required this.settingsTooltip,
    required this.smartTooltip,
    required this.onAdd,
    required this.onSettings,
    required this.onSmart,
    required this.loading,
  });

  final bool desktop;
  final ColorScheme scheme;
  final Widget tagStrip;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String addLabel;
  final String settingsTooltip;
  final String smartTooltip;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onSmart;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final settingsButton = IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
      ),
      icon: const Icon(Icons.settings_rounded),
      tooltip: settingsTooltip,
      onPressed: onSettings,
    );
    final smartButton = IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
      ),
      icon: const Icon(Icons.auto_awesome_rounded),
      tooltip: smartTooltip,
      onPressed: onSmart,
    );
    final tagsRow = Row(
      children: [
        Expanded(child: SizedBox(height: 40, child: tagStrip)),
        const SizedBox(width: 8),
        settingsButton,
        if (desktop) smartButton,
      ],
    );
    final inputRow = desktop
        ? AppQuickEntryRow(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            actionLabel: addLabel,
            actionIcon: Icons.add_rounded,
            onAction: onAdd,
            onSubmitted: (_) => onAdd(),
            loading: loading,
          )
        : Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(hintText: hintText),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(addLabel),
              ),
              const SizedBox(width: 8),
              smartButton,
            ],
          );
    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(24, 0, 16, 10)
          : const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: desktop
            ? [inputRow, const SizedBox(height: 8), tagsRow]
            : [tagsRow, const SizedBox(height: 10), inputRow],
      ),
    );
  }
}
''' + '\n'
write(path, text)

path = 'lib/features/planning/planning_page.dart'
text = read(path)
text = text.replace("import 'package:counter/core/widgets/compact_nav_controls.dart';\n", '')
start = text.index('  Widget _buildPlanningMainColumn(')
anchor = text.index(
    '        Expanded(\n          child:\n              kUseMountedDayStrip',
    start,
)
new_prefix = r'''  Widget _buildPlanningMainColumn(
    BuildContext context,
    ColorScheme scheme,
    List<PlanningTask> tasks,
  ) {
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    final tagStrip = PlanningQuickAddTagStrip(
      scheme: scheme,
      tagsLoading: _quickAddTags.tagsLoading,
      availableTags: _quickAddTags.availableTags,
      selectedTags: _quickAddTags.creationSelectedTags,
      onToggleTag: _quickAddTags.toggleCreationTag,
      onOpenTagManager: () => unawaited(_quickAddTags.openTagManager(context)),
      onReorder: _quickAddTags.availableTags.length >= 2
          ? _quickAddTags.onQuickBarReorder
          : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_planSelectMode)
          PlanningSortModeBar(
            sortMode: _sortMode,
            onSortModeChanged: (mode) => setState(() => _sortMode = mode),
            desktopTitle: desktop
                ? t(currentLocale.value, 'tab_planning')
                : null,
          ),
        PlanningQuickAddChrome(
          desktop: desktop,
          scheme: scheme,
          tagStrip: tagStrip,
          controller: _textController,
          focusNode: _quickAddFocus,
          hintText: t(currentLocale.value, 'input_placeholder_plan'),
          addLabel: t(currentLocale.value, 'add'),
          settingsTooltip: t(currentLocale.value, 'plan_settings_tooltip'),
          smartTooltip: t(currentLocale.value, 'smart_plan_tooltip'),
          onAdd: _addTask,
          onSettings: timeView.showPlanningSettingsSheet,
          onSmart: _openSmartPlanSheet,
          loading: _planQuickAddInFlight,
        ),
'''
text = text[:start] + new_prefix + text[anchor:]
write(path, text)


# Move new-stage/new-action form definitions into the existing Path editor file.
path = 'lib/features/paths/widgets/path_edit_sheet.dart'
text = read(path)
insert_at = text.index('\nFuture<PathEditDraft?> showPathEditSheet')
forms = r'''

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
}) =>
    showAppFormDialog(
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
}) =>
    showAppFormDialog(
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
'''
if 'showPathNewActionDraft' in text:
    raise SystemExit('Path new draft helpers already exist')
text = text[:insert_at] + forms + text[insert_at:]
write(path, text)

path = 'lib/features/paths/paths_page.dart'
text = read(path)
first = text.index('  String? _requiredField(')
manual = text.index('  String _manualElementId(', first)
text = text[:first] + text[manual:]
action_forms = text.index('  Future<Map<String, String>?> _actionDraft()')
add_action = text.index('  Future<void> _addAction(', action_forms)
text = text[:action_forms] + text[add_action:]
text = replace_once(
    text,
    '    final draft = await _actionDraft();',
    '    final draft = await showPathNewActionDraft(context: context, ru: _ru);',
    'Path action draft call',
)
text = replace_once(
    text,
    '    final draft = await _stageDraft();',
    '    final draft = await showPathNewStageDraft(context: context, ru: _ru);',
    'Path stage draft call',
)
write(path, text)
