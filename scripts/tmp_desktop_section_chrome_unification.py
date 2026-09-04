from pathlib import Path
import re


def read(path):
    return Path(path).read_text(encoding='utf-8')


def write(path, text):
    Path(path).write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)


def regex_once(text, pattern, replacement, label, flags=re.S):
    out, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 regex match, got {count}')
    return out


# ---------------------------------------------------------------------------
# Shared desktop section row + shared quick-entry row.
# ---------------------------------------------------------------------------
path = 'lib/core/widgets/compact_nav_controls.dart'
text = read(path)
text = replace_once(
    text,
    "import 'package:flutter/material.dart';",
    "import 'package:counter/core/widgets/app_button.dart';\nimport 'package:flutter/material.dart';",
    'compact controls import',
)
append = r'''

/// Canonical one-line heading row for desktop primary sections.
///
/// Feature-owned controls live on the same line as the section name; the shell
/// must not add a second copy of the title above this row.
class AppDesktopSectionControlRow extends StatelessWidget {
  const AppDesktopSectionControlRow({
    super.key,
    required this.title,
    required this.controls,
  });

  final String title;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
      child: SizedBox(
        height: kAppCompactControlHeight,
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
              ),
            ),
            const SizedBox(width: 20),
            const Spacer(),
            controls,
          ],
        ),
      ),
    );
  }
}

/// Canonical quick-entry line shared by desktop Planning and Timeline.
/// The field and action are deliberately the same 44px height and 12px radius.
class AppQuickEntryRow extends StatelessWidget {
  const AppQuickEntryRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.onSubmitted,
    this.loading = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final ValueChanged<String>? onSubmitted;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = 12.0;
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: scheme.outline),
    );
    final focusedBorder = enabledBorder.copyWith(
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    );
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: kAppCompactControlHeight,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: enabledBorder,
                enabledBorder: enabledBorder,
                focusedBorder: focusedBorder,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppButton.primary(
          label: actionLabel,
          icon: actionIcon,
          onPressed: onAction,
          loading: loading,
          size: AppButtonSize.m,
        ),
      ],
    );
  }
}
'''
if 'class AppDesktopSectionControlRow' in text:
    raise SystemExit('shared desktop row already exists unexpectedly')
text = text.rstrip() + append + '\n'
write(path, text)


# ---------------------------------------------------------------------------
# Shell: stop injecting duplicate section names. Only Profile still needs the
# generic shell-owned desktop title; all requested primary screens own theirs.
# ---------------------------------------------------------------------------
path = 'lib/app/shell/shared/shell_chrome.dart'
text = read(path)
text = replace_once(
    text,
    "if (formFactor == ShellFormFactor.desktop &&\n                                      shellPageIndex != 2)",
    "if (formFactor == ShellFormFactor.desktop &&\n                                      shellPageIndex == 5)",
    'shell generic desktop title condition',
)
write(path, text)


# ---------------------------------------------------------------------------
# Planning selector: desktop title and selector share one canonical row.
# ---------------------------------------------------------------------------
path = 'lib/features/planning/widgets/planning_filter_controls.dart'
text = read(path)
text = replace_once(
    text,
    "required this.onSortModeChanged,\n  });",
    "required this.onSortModeChanged,\n    this.desktopTitle,\n  });",
    'planning sort constructor',
)
text = replace_once(
    text,
    "final ValueChanged<PlanSortMode> onSortModeChanged;",
    "final ValueChanged<PlanSortMode> onSortModeChanged;\n  final String? desktopTitle;",
    'planning sort field',
)
old_build = r'''  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          height: kAppCompactControlHeight,
          child: SegmentedButton<PlanSortMode>(
            showSelectedIcon: false,
            style: appCompactSegmentedButtonStyle(context, segmentWidth: 78),
            segments: [
              ButtonSegment<PlanSortMode>(
                value: PlanSortMode.category,
                label: AppCompactSegmentLabel(
                  text: t(currentLocale.value, 'plan_sort_category'),
                ),
              ),
              ButtonSegment<PlanSortMode>(
                value: PlanSortMode.time,
                label: AppCompactSegmentLabel(
                  text: t(currentLocale.value, 'plan_sort_time'),
                ),
              ),
              ButtonSegment<PlanSortMode>(
                value: PlanSortMode.tags,
                label: AppCompactSegmentLabel(
                  text: t(currentLocale.value, 'plan_sort_tags'),
                ),
              ),
              ButtonSegment<PlanSortMode>(
                value: PlanSortMode.custom,
                label: AppCompactSegmentLabel(
                  text: t(currentLocale.value, 'plan_sort_custom'),
                ),
              ),
            ],
            selected: {sortMode},
            onSelectionChanged: (Set<PlanSortMode> next) {
              if (next.isEmpty) return;
              final mode = next.first;
              onSortModeChanged(mode);
              unawaited(
                DatabaseService.instance.persistPlanActiveTabIndex(
                  planSortModeToPersistedIndex(mode),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
'''
new_build = r'''  @override
  Widget build(BuildContext context) {
    final selector = SizedBox(
      height: kAppCompactControlHeight,
      child: SegmentedButton<PlanSortMode>(
        showSelectedIcon: false,
        style: appCompactSegmentedButtonStyle(context, segmentWidth: 78),
        segments: [
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.category,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_category'),
            ),
          ),
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.time,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_time'),
            ),
          ),
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.tags,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_tags'),
            ),
          ),
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.custom,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_custom'),
            ),
          ),
        ],
        selected: {sortMode},
        onSelectionChanged: (Set<PlanSortMode> next) {
          if (next.isEmpty) return;
          final mode = next.first;
          onSortModeChanged(mode);
          unawaited(
            DatabaseService.instance.persistPlanActiveTabIndex(
              planSortModeToPersistedIndex(mode),
            ),
          );
        },
      ),
    );
    final title = desktopTitle;
    if (title != null) {
      return AppDesktopSectionControlRow(title: title, controls: selector);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: selector,
      ),
    );
  }
'''
text = replace_once(text, old_build, new_build, 'planning sort build')
write(path, text)


# ---------------------------------------------------------------------------
# Planning: desktop = title+selector, then shared input/add row, then tags.
# Mobile/tablet retain their existing ordering and controls.
# ---------------------------------------------------------------------------
path = 'lib/features/planning/planning_page.dart'
text = read(path)
text = replace_once(
    text,
    "import 'package:counter/core/shell_layout_state.dart';",
    "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/shell_layout_state.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';",
    'planning desktop/shared imports',
)
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
    final desktopShell = shellUsesSideNavigation(
      MediaQuery.sizeOf(context).width,
    );
    final settingsButton = IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
      ),
      icon: const Icon(Icons.settings_rounded),
      tooltip: t(currentLocale.value, 'plan_settings_tooltip'),
      onPressed: timeView.showPlanningSettingsSheet,
    );
    final smartButton = IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
      ),
      icon: const Icon(Icons.auto_awesome_rounded),
      tooltip: t(currentLocale.value, 'smart_plan_tooltip'),
      onPressed: _openSmartPlanSheet,
    );
    final tagsRow = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: PlanningQuickAddTagStrip(
              scheme: scheme,
              tagsLoading: _quickAddTags.tagsLoading,
              availableTags: _quickAddTags.availableTags,
              selectedTags: _quickAddTags.creationSelectedTags,
              onToggleTag: _quickAddTags.toggleCreationTag,
              onOpenTagManager: () =>
                  unawaited(_quickAddTags.openTagManager(context)),
              onReorder: _quickAddTags.availableTags.length >= 2
                  ? _quickAddTags.onQuickBarReorder
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        settingsButton,
        if (desktopShell) smartButton,
      ],
    );
    final inputRow = desktopShell
        ? AppQuickEntryRow(
            controller: _textController,
            focusNode: _quickAddFocus,
            hintText: t(currentLocale.value, 'input_placeholder_plan'),
            actionLabel: t(currentLocale.value, 'add'),
            actionIcon: Icons.add_rounded,
            onAction: _addTask,
            onSubmitted: (_) => _addTask(),
            loading: _planQuickAddInFlight,
          )
        : Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _quickAddFocus,
                  decoration: InputDecoration(
                    hintText: t(
                      currentLocale.value,
                      'input_placeholder_plan',
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTask(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.add_rounded),
                label: Text(t(currentLocale.value, 'add')),
              ),
              const SizedBox(width: 8),
              smartButton,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_planSelectMode)
          PlanningSortModeBar(
            sortMode: _sortMode,
            onSortModeChanged: (mode) => setState(() => _sortMode = mode),
            desktopTitle: desktopShell
                ? t(currentLocale.value, 'tab_planning')
                : null,
          ),
        Padding(
          padding: desktopShell
              ? const EdgeInsets.fromLTRB(24, 0, 16, 10)
              : const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (desktopShell) ...[
                inputRow,
                const SizedBox(height: 8),
                tagsRow,
              ] else ...[
                tagsRow,
                const SizedBox(height: 10),
                inputRow,
              ],
            ],
          ),
        ),
'''
text = text[:start] + new_prefix + text[anchor:]
write(path, text)


# ---------------------------------------------------------------------------
# Timeline: desktop title+mode on one row, then the same quick-entry component
# used by Planning. Mobile/tablet keep the old raw layout.
# ---------------------------------------------------------------------------
path = 'lib/features/timeline/timeline_header_controls.dart'
text = read(path)
text = replace_once(
    text,
    "import 'package:counter/core/widgets/compact_nav_controls.dart';",
    "import 'package:counter/core/shell_adaptive.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';",
    'timeline desktop import',
)
old_method_start = text.index('  @override\n  Widget build(BuildContext context) {')
old_method_end = text.rindex('\n  }\n}') + len('\n  }')
new_method = r'''  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final desktopShell = shellUsesSideNavigation(
      MediaQuery.sizeOf(context).width,
    );
    final projectedToday = timelineLocalToday();
    final isToday =
        visibleDate.year == projectedToday.year &&
        visibleDate.month == projectedToday.month &&
        visibleDate.day == projectedToday.day;
    void submit() {
      if (visibleIsFuture) {
        onPlan();
      } else if (isToday) {
        onStart();
      } else {
        onNewTaskForPastDate();
      }
    }

    final selector = SizedBox(
      height: kAppCompactControlHeight,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        style: appCompactSegmentedButtonStyle(context, segmentWidth: 112),
        segments: [
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.list_rounded),
            label: AppCompactSegmentLabel(text: t(loc, 'list')),
          ),
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.bar_chart_rounded),
            label: AppCompactSegmentLabel(text: t(loc, 'stats')),
          ),
        ],
        selected: {showStatsView},
        onSelectionChanged: (Set<bool> sel) {
          if (sel.isEmpty) return;
          onShowStatsViewChanged(sel.first);
        },
      ),
    );
    final actionIcon = visibleIsFuture
        ? Icons.event_rounded
        : isToday
        ? Icons.play_arrow_rounded
        : Icons.add_task_rounded;
    final actionLabel = visibleIsFuture
        ? t(loc, 'plan')
        : isToday
        ? t(loc, 'start_timer')
        : t(loc, 'new_record_btn');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (desktopShell)
          AppDesktopSectionControlRow(
            title: t(loc, 'tab_timeline'),
            controls: selector,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: selector,
          ),
        if (!showStatsView) ...[
          if (desktopShell)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
              child: AppQuickEntryRow(
                controller: titleController,
                focusNode: titleFocus,
                hintText: t(loc, 'input_placeholder_record'),
                actionLabel: actionLabel,
                actionIcon: actionIcon,
                onAction: submit,
                onSubmitted: (_) => submit(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: titleController,
                      focusNode: titleFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        hintText: t(loc, 'input_placeholder_record'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: submit,
                    icon: Icon(actionIcon),
                    label: Text(actionLabel),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        const Divider(height: 1),
      ],
    );
  }'''
text = text[:old_method_start] + new_method + text[old_method_end:]
write(path, text)


# ---------------------------------------------------------------------------
# Paths: desktop section title and its two actions are exactly one row.
# ---------------------------------------------------------------------------
path = 'lib/features/paths/paths_page.dart'
text = read(path)
text = replace_once(
    text,
    "import 'package:counter/core/widgets/app_button.dart';",
    "import 'package:counter/core/widgets/app_button.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';",
    'paths shared row import',
)
header_start = text.index('  Widget _header() {')
header_end = text.index('\n  Widget _body() {', header_start)
new_header = r'''  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    final desktopShell = shellUsesSideNavigation(
      MediaQuery.sizeOf(context).width,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          icon: Icons.account_tree_outlined,
          tooltip: _ru ? 'Папки в Путях' : 'Folders in Paths',
          onPressed: _loading ? null : () => unawaited(_openFolderSelector()),
        ),
        AppIconButton(
          icon: Icons.refresh_rounded,
          tooltip: _ru ? 'Обновить' : 'Refresh',
          onPressed: _loading ? null : () => unawaited(_load()),
          loading: _loading,
        ),
      ],
    );
    if (desktopShell) {
      return AppDesktopSectionControlRow(
        title: _ru ? 'Пути' : 'Paths',
        controls: actions,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        children: [
          Icon(Icons.alt_route_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ru ? 'Пути' : 'Paths',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _ru
                      ? 'Цель → этапы → действия.'
                      : 'Goal → stages → actions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions,
        ],
      ),
    );
  }
'''
text = text[:header_start] + new_header + text[header_end:]
write(path, text)


# ---------------------------------------------------------------------------
# Categories: remove obsolete edit mode and its drag/reparent implementation;
# desktop title + category actions become one row.
# ---------------------------------------------------------------------------
path = 'lib/features/settings/categories/category_list_view.dart'
text = read(path)
text = replace_once(
    text,
    "import 'package:counter/core/widgets/app_icon_button.dart';",
    "import 'package:counter/core/widgets/app_icon_button.dart';\nimport 'package:counter/core/widgets/compact_nav_controls.dart';",
    'categories shared row import',
)
text = text.replace(
    "import 'package:counter/features/settings/categories/category_appearance_sheet.dart';\n",
    '',
)
text = replace_once(
    text,
    "show CategoryBandLayout, CategoryDragData, CategoryRowWidget;",
    "show CategoryBandLayout, CategoryRowWidget;",
    'category export cleanup',
)
text = replace_once(
    text,
    "  bool _categoryEditMode = false;\n",
    '',
    'remove category edit mode state',
)
text = regex_once(
    text,
    r"\n  @override\n  void dispose\(\) \{.*?\n  Future<void> _notifyChanged\(\) async \{",
    "\n  Future<void> _notifyChanged() async {",
    'remove category edit/reorder implementation',
)
text = regex_once(
    text,
    r"\n  void _showCategoryAppearanceSheet\(BuildContext context, CategoryRule r\) \{.*?\n  \}\n\n  Future<void> _addRule",
    "\n  Future<void> _addRule",
    'remove category appearance edit-mode entry',
)
old_band = r'''    final band = CategoryRowWidget(
      depth: depth,
      items: items,
      immediateParentId: depth == 0 ? null : _selectedPath[depth - 1],
      selectedId: selectedId,
      onSelect: (id) => _selectAtDepth(depth, id),
      onFullSettingsTap: (r) => _showCategoryEditorSheet(context, r),
      onAppearanceTap: (r) => _showCategoryAppearanceSheet(context, r),
      onLongPressOpenEditor: (r) => _showCategoryEditorSheet(context, r),
      onReorder: _categoryEditMode
          ? (oldI, newI) => _onCategoryBandReorder(depth, oldI, newI)
          : null,
      canMoveToParent: _categoryEditMode ? _canMoveCategoryToParent : null,
      onMoveToParent: _categoryEditMode ? _onCategoryMove : null,
      layout: _useHorizontalScrollLayout
          ? CategoryBandLayout.horizontalPeek
          : CategoryBandLayout.wrapGrid,
      showAdd: canAddAtThisLevel,
      onAddTap: () => unawaited(_addSubcategoryAtDepth(depth)),
      editMode: _categoryEditMode,
    );'''
new_band = r'''    final band = CategoryRowWidget(
      depth: depth,
      items: items,
      immediateParentId: depth == 0 ? null : _selectedPath[depth - 1],
      selectedId: selectedId,
      onSelect: (id) => _selectAtDepth(depth, id),
      onLongPressOpenEditor: (r) => _showCategoryEditorSheet(context, r),
      layout: _useHorizontalScrollLayout
          ? CategoryBandLayout.horizontalPeek
          : CategoryBandLayout.wrapGrid,
      showAdd: canAddAtThisLevel,
      onAddTap: () => unawaited(_addSubcategoryAtDepth(depth)),
    );'''
text = replace_once(text, old_band, new_band, 'category band call cleanup')
text = replace_once(
    text,
    "    final scheme = Theme.of(context).colorScheme;\n    final textTheme = Theme.of(context).textTheme;\n",
    '',
    'category obsolete build locals',
)
body_start = text.index('            if (desktopShell)\n              Padding(', text.index('  Widget build(BuildContext context)'))
body_end_marker = "            Expanded(\n              child: roots.isEmpty"
body_end = text.index(body_end_marker, body_start)
new_desktop_header = r'''            if (desktopShell)
              AppDesktopSectionControlRow(
                title: t(loc, 'categories_title'),
                controls: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton(
                      icon: _useHorizontalScrollLayout
                          ? Icons.grid_view_rounded
                          : Icons.view_week_rounded,
                      tooltip: _useHorizontalScrollLayout
                          ? t(loc, 'switch_to_wrap')
                          : t(loc, 'switch_to_scrollable'),
                      onPressed: () => setState(
                        () => _useHorizontalScrollLayout =
                            !_useHorizontalScrollLayout,
                      ),
                    ),
                    AppIconButton(
                      tooltip: t(loc, 'add_category'),
                      onPressed: () => unawaited(_addRule()),
                      icon: Icons.add_rounded,
                    ),
                  ],
                ),
              ),
            if (desktopShell) const Divider(height: 1),
'''
text = text[:body_start] + new_desktop_header + text[body_end:]
write(path, text)


# Remove all obsolete category edit-mode rendering and drag plumbing.
path = 'lib/features/settings/categories/category_row_widget.dart'
text = read(path)
text = replace_once(text, "    required this.iconEdit,\n", '', 'layout iconEdit ctor')
text = replace_once(text, "    required this.gearIconSize,\n", '', 'layout gear ctor')
text = replace_once(text, "  final double iconEdit;\n", '', 'layout iconEdit field')
text = replace_once(text, "  final double gearIconSize;\n", '', 'layout gear field')
text = re.sub(r"\n        iconEdit: [^\n]+,", '', text)
text = re.sub(r"\n        gearIconSize: [^\n]+,", '', text)
text = re.sub(r"\n      iconEdit: [^\n]+,", '', text)
text = re.sub(r"\n      gearIconSize: [^\n]+,", '', text)
text = regex_once(
    text,
    r"\nclass CategoryDragData \{.*?\n\}\n\nenum CategoryBandLayout",
    "\nenum CategoryBandLayout",
    'remove CategoryDragData',
)
old_ctor = r'''  const CategoryRowWidget({
    super.key,
    required this.items,
    required this.depth,
    required this.immediateParentId,
    required this.selectedId,
    required this.onSelect,
    required this.onFullSettingsTap,
    required this.onAppearanceTap,
    required this.onLongPressOpenEditor,
    this.onReorder,
    this.canMoveToParent,
    this.onMoveToParent,
    this.onAddTap,
    this.showAdd = false,
    this.editMode = false,
    this.layout = CategoryBandLayout.wrapGrid,
  });'''
new_ctor = r'''  const CategoryRowWidget({
    super.key,
    required this.items,
    required this.depth,
    required this.immediateParentId,
    required this.selectedId,
    required this.onSelect,
    required this.onLongPressOpenEditor,
    this.onAddTap,
    this.showAdd = false,
    this.layout = CategoryBandLayout.wrapGrid,
  });'''
text = replace_once(text, old_ctor, new_ctor, 'category row constructor')
old_fields = r'''  final void Function(int? id) onSelect;
  final void Function(CategoryRule r) onFullSettingsTap;
  final void Function(CategoryRule r) onAppearanceTap;
  final void Function(CategoryRule r) onLongPressOpenEditor;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final bool Function(CategoryDragData data, int? newParentId)? canMoveToParent;
  final void Function(CategoryDragData data, int? newParentId)? onMoveToParent;
  final VoidCallback? onAddTap;
  final bool showAdd;
  final bool editMode;
  final CategoryBandLayout layout;'''
new_fields = r'''  final void Function(int? id) onSelect;
  final void Function(CategoryRule r) onLongPressOpenEditor;
  final VoidCallback? onAddTap;
  final bool showAdd;
  final CategoryBandLayout layout;'''
text = replace_once(text, old_fields, new_fields, 'category row fields')
tile_start = text.index('  static Widget _buildCategoryTile({')
tile_end = text.index('\n  Widget _addTile', tile_start)
new_tile = r'''  static Widget _buildCategoryTile({
    required BuildContext context,
    required CategoryRule r,
    required bool isSelected,
    required CategoryDepthLayout layout,
    required void Function(int? id) onSelect,
    required void Function(CategoryRule r) onLongPressOpenEditor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = r.colorOrDefault;
    final label = categoryTileLabel(r);
    final glassAlpha = isSelected
        ? kCategoryGlassAlphaSelected
        : kCategoryGlassAlpha;
    final fill = Color.alphaBlend(
      color.withValues(alpha: glassAlpha),
      scheme.surface,
    );
    final labelStyle = textTheme.titleSmall?.copyWith(
      fontSize: layout.fontSize,
      fontWeight: layout.fontWeight,
      height: 1.15,
      color: textTheme.bodyLarge?.color,
    );
    final radius = layout.borderRadius;

    return SizedBox(
      width: layout.side,
      height: layout.side,
      child: Material(
        elevation: layout.elevation,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: color.withValues(alpha: isSelected ? 0.45 : 0.28),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(isSelected ? null : r.id),
          onLongPress: () => onLongPressOpenEditor(r),
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: EdgeInsets.all(layout.contentPadding),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Icon(
                      r.iconOrDefault,
                      size: layout.iconBrowse,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
'''
text = text[:tile_start] + new_tile + text[tile_end:]
cell_start = text.index('          Widget cell(CategoryRule r) => _buildCategoryTile(')
layout_anchor = text.index('          if (layout == CategoryBandLayout.horizontalPeek)', cell_start)
new_cell = r'''          Widget cell(CategoryRule r) => _buildCategoryTile(
                context: context,
                r: r,
                isSelected: selectedId == r.id,
                layout: dLayout,
                onSelect: onSelect,
                onLongPressOpenEditor: onLongPressOpenEditor,
              );

'''
text = text[:cell_start] + new_cell + text[layout_anchor:]
text = text.replace('child: dragMovable(i, cell(items[i])),', 'child: cell(items[i]),')
text = text.replace('dragMovable(i, cell(items[i])),', 'cell(items[i]),')
text = regex_once(
    text,
    r"\n    if \(editMode && onMoveToParent != null\) \{.*?\n    \}\n\n    return Padding\(",
    "\n    return Padding(",
    'remove category band parent drop target',
)
write(path, text)


# ---------------------------------------------------------------------------
# Governing desktop chrome contract.
# ---------------------------------------------------------------------------
path = 'docs/DESIGN_SYSTEM.md'
text = read(path)
old = "On wide desktop layouts, the shell owns one shared top header for every primary section. The global header keeps the LIFE OS brand/app title; the active section name is rendered once as a large heading inside the main content column, not in the brand position and not duplicated beside the navigation item. Feature pages must not stack a second page AppBar/title above their content on desktop; feature-specific commands may remain in a compact secondary toolbar below the section heading. The desktop side navigation has a visible boundary separating it from page content. This rule applies to shell/menu chrome only and does not authorize redesigning feature cards, rows, editors, or other local controls. Phone and tablet chrome remain feature-adaptive unless separately specified. Calendar is the desktop exception for section-heading placement: its section title, period navigation, and Month / Week / Day selector share one feature toolbar row directly below the global LIFE OS header."
new = "On wide desktop layouts, the shell owns the global LIFE OS header and the side-navigation boundary, but it must not inject a duplicate section title above a feature that already owns its heading. `AppDesktopSectionControlRow` is the canonical one-line desktop section row: Timeline pairs its title with List / Stats, Planning pairs its title with its sort selector, Calendar pairs its title with period navigation and Month / Week / Day, Paths pairs its title with Path actions, and Categories pairs its title with category actions. Lists / Notes keep their existing internal title and receive no extra shell title. Profile may retain a shell-owned section heading until its own feature chrome is migrated. Planning and Timeline use the same `AppQuickEntryRow` for their desktop entry line: field and primary action are both 44px high with the same 12px corner radius. Planning places that entry line directly below the title/mode row and its tags below the entry line. This contract changes desktop chrome only; feature cards, rows, editors, phone chrome, and tablet chrome are not redesigned by it. The obsolete Categories edit-mode toggle and its edit-mode-only drag/reparent chrome are removed rather than preserved as a second UI state."
text = replace_once(text, old, new, 'desktop design contract')
write(path, text)
