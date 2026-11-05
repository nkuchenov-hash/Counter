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

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final ru = loc.toLowerCase().startsWith('ru');
    return Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(ru ? 'Заметки и списки' : 'Notes & lists'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
        ),
        body: StreamBuilder<UserSettings>(
          stream: DatabaseService.instance.userSettingsStream,
          initialData: DatabaseService.instance.settings,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? DatabaseService.instance.settings;
            final completed = settings.listCompletionBehavior.trim().toLowerCase();
            return AppSettingsPageBody(
              children: [
                AppSettingsSectionCard(
                  title: ru ? 'Вид заметок' : 'Notes view',
                  subtitle: ru
                      ? 'Один и тот же выбор применяется в библиотеке заметок.'
                      : 'The same choice is used in the Notes library.',
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
                AppSettingsSectionCard(
                  title: ru ? 'Завершённые пункты' : 'Completed items',
                  child: AppSettingsNavigationGroup(
                    children: [
                      for (final choice in <(String, String, String)>[
                        ('stay', 'Оставлять на месте', 'Keep in place'),
                        ('bottom', 'Переносить вниз', 'Move to bottom'),
                        ('hide', 'Скрывать', 'Hide'),
                        ('archive', 'В архив', 'Archive'),
                      ])
                        AppSettingsSelectionRow(
                          title: ru ? choice.$2 : choice.$3,
                          selected: completed == choice.$1,
                          onTap: _saving ? null :
                              () => unawaited(_setCompletion(choice.$1)),
                        ),
                    ],
                  ),
                ),
                AppSettingsSectionCard(
                  title: ru ? 'Теги на карточках' : 'Tags on cards',
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ru ? 'Показывать теги' : 'Show tags'),
                    value: settings.showListTagsOnCards,
                    onChanged: _saving ? null :
                        (v) => unawaited(_setCardTags(v)),
                  ),
                ),
                AppSettingsNavigationGroup(
                  children: [
                    AppSettingsNavigationRow(
                      title: ru ? 'Панель категорий' : 'Category bar',
                      subtitle: ru
                          ? 'Закреплённые категории, фильтры, папки'
                          : 'Pinned categories, filters and folders',
                      leading: AppSettingsMenuIcon(
                        icon: AppMenuIcons.icon(AppMenuIconRole.folder)),
                      onTap: widget.onOpenCategoryBar,
                    ),
                  ],
                ),
                if (_error != null)
                  Text(_error!, style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
              ],
            );
          },
        ),
      )),
    );
  }
}
