import 'dart:async';

import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/lists/notes_library_preferences.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Real Notes/List preferences shared with the existing local Notes controls.
class LifeOsNotesSettingsPage extends StatefulWidget {
  const LifeOsNotesSettingsPage({super.key, required this.onOpenCategoryBar});
  final VoidCallback onOpenCategoryBar;

  @override
  State<LifeOsNotesSettingsPage> createState() =>
      _LifeOsNotesSettingsPageState();
}

class _LifeOsNotesSettingsPageState extends State<LifeOsNotesSettingsPage> {
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    NotesLibraryPreferences.mode.addListener(_refresh);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await NotesLibraryPreferences.load();
    } catch (_) {
      if (mounted) setState(() => _error = currentLocale.value == 'ru'
          ? 'Не удалось загрузить настройки вида.'
          : 'Unable to load view preferences.');
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _setView(String mode) async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await NotesLibraryPreferences.select(mode);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save Notes display.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setCompletion(String behavior) async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      final db = DatabaseService.instance;
      final ok = await db.saveSettings(
          db.settings.copyWith(listCompletionBehavior: behavior));
      if (!ok && mounted) setState(() => _error = 'Unable to save list behavior.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save list behavior.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setCardTags(bool visible) async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await DatabaseService.instance.persistShowListTagsOnCards(visible);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save tag visibility.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    NotesLibraryPreferences.mode.removeListener(_refresh);
    super.dispose();
  }

  String _completionLabel(String behavior, bool ru) => switch (behavior) {
    'bottom' => ru ? 'Перемещать вниз' : 'Move to bottom',
    'hide' => ru ? 'Скрывать' : 'Hide',
    'archive' => ru ? 'В архив' : 'Archive',
    _ => ru ? 'Оставлять на месте' : 'Keep in place',
  };

  void _showCompletionPicker(String current) {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: settingsNeutralTheme(context).colorScheme.surfaceContainerLowest,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 0, 16),
                child: Text(
                  ru ? 'Завершённые пункты' : 'Completed items',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700)),
              ),
              AppSettingsNavigationGroup(children: [
                for (final behavior in const <String>['stay', 'bottom', 'hide', 'archive'])
                  AppSettingsSelectionRow(
                    title: _completionLabel(behavior, ru),
                    selected: current == behavior,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_setCompletion(behavior));
                    },
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 20, 0, 10),
    child: Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    )),
  );

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    final ru = locale.toLowerCase().startsWith('ru');
    return Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(ru ? 'Настройки' : 'Settings'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        body: StreamBuilder<UserSettings>(
          stream: DatabaseService.instance.userSettingsStream,
          initialData: DatabaseService.instance.settings,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? DatabaseService.instance.settings;
            final completed = settings.listCompletionBehavior.trim().toLowerCase();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: AppSettingsPageBody(children: [
                  Text(
                    ru ? 'Заметки и списки' : 'Notes & lists',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800, fontSize: 31)),
                  const SizedBox(height: 7),
                  Text(
                    ru
                      ? 'Отображение заметок, списков, тегов и категорий.'
                      : 'Display options for notes, lists, tags and categories.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  _heading(context, ru ? 'ВИД ЗАМЕТОК' : 'NOTES VIEW'),
                  AppSettingsNavigationGroup(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                      child: SegmentedButton<String>(
                        selected: {NotesLibraryPreferences.mode.value},
                        onSelectionChanged: _saving ? null :
                            (next) => unawaited(_setView(next.first)),
                        segments: [
                          ButtonSegment<String>(
                            value: 'grid',
                            icon: Icon(AppMenuIcons.icon(AppMenuIconRole.categories)),
                            label: Text(ru ? 'Сетка' : 'Grid'),
                          ),
                          ButtonSegment<String>(
                            value: 'list',
                            icon: Icon(AppMenuIcons.icon(AppMenuIconRole.list)),
                            label: Text(ru ? 'Список' : 'List'),
                          ),
                        ],
                      ),
                    ),
                    AppSettingsControlRow(
                      title: ru ? 'Показывать теги на карточках' : 'Show tags on cards',
                      leading: AppSettingsMenuIcon(
                        icon: AppMenuIcons.icon(AppMenuIconRole.tags)),
                      value: settings.showListTagsOnCards,
                      onChanged: _saving ? null :
                          (v) => unawaited(_setCardTags(v)),
                    ),
                  ]),
                  _heading(context, ru ? 'СПИСКИ' : 'LISTS'),
                  AppSettingsNavigationGroup(children: [
                    AppSettingsNavigationRow(
                      title: ru ? 'Завершённые пункты' : 'Completed items',
                      subtitle: ru ? 'Что делать с выполненными' : 'What to do with completed items',
                      value: _completionLabel(completed, ru),
                      leading: AppSettingsMenuIcon(
                        icon: AppMenuIcons.icon(AppMenuIconRole.list)),
                      onTap: _saving ? null : () => _showCompletionPicker(completed),
                    ),
                  ]),
                  _heading(context, ru ? 'КАТЕГОРИИ В ЗАМЕТКАХ' : 'NOTES CATEGORIES'),
                  AppSettingsNavigationGroup(children: [
                    AppSettingsNavigationRow(
                      title: ru ? 'Панель категорий' : 'Category bar',
                      subtitle: ru
                        ? 'Закреплённые категории и фильтры'
                        : 'Pinned categories and filters',
                      leading: AppSettingsMenuIcon(
                        icon: AppMenuIcons.icon(AppMenuIconRole.folder)),
                      onTap: widget.onOpenCategoryBar,
                    ),
                  ]),
                  if (_saving) const LinearProgressIndicator(minHeight: 2),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!, style: TextStyle(
                        color: Theme.of(context).colorScheme.error))),
                ]),
              ),
            );
          },
        ),
      )),
    );
  }
}
