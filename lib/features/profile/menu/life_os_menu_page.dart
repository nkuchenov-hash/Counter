import 'package:counter/core/app_colors.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// All menu actions have a real destination in the dashboard composition root.
/// Keeping the routing enum separate from presentation avoids parallel settings.
enum LifeOsMenuAction {
  viktor,
  paths,
  people,
  peopleSources,
  categories,
  categoryAppearance,
  tags,
  tagAppearance,
  tagDurations,
  planning,
  planningSettings,
  defaultPlanTimes,
  notes,
  notesCategoryBar,
  notesSettings,
  calendars,
  notifications,
  morning,
  sleep,
  voiceSettings,
  appearance,
  languageAndTime,
  account,
  accountSecurity,
  accountSession,
  about,
  syncStatus,
  diagnostics,
  componentLab,
  voiceDiagnostics,
}

class LifeOsMenuPage extends StatefulWidget {
  const LifeOsMenuPage({
    super.key,
    required this.onAction,
    required this.activeTab,
    this.initialSection,
    this.onBackToMenu,
  });
  final ValueChanged<LifeOsMenuAction> onAction;
  final String? initialSection;
  final VoidCallback? onBackToMenu;

  /// The shell keeps visited tabs offstage. An inactive menu must never
  /// intercept system Back from Timeline, Planning or another tab.
  final ValueListenable<int> activeTab;

  @override
  State<LifeOsMenuPage> createState() => _LifeOsMenuPageState();
}

class _LifeOsMenuRow {
  const _LifeOsMenuRow(this.id, this.ru, this.en, this.icon, this.action,
      {this.helpRu = '', this.helpEn = ''});

  final String id;
  final String ru;
  final String en;
  final String helpRu;
  final String helpEn;
  final AppMenuIconRole icon;
  final LifeOsMenuAction action;

  String title(bool ruLocale) => ruLocale ? ru : en;
  String subtitle(bool ruLocale) => ruLocale ? helpRu : helpEn;
}

class _LifeOsMenuGroup {
  const _LifeOsMenuGroup(this.ru, this.en, this.rows);
  final String ru;
  final String en;
  final List<_LifeOsMenuRow> rows;
  String title(bool ruLocale) => ruLocale ? ru : en;
}

class _LifeOsMenuSection {
  const _LifeOsMenuSection(this.id, this.ru, this.en, this.icon, this.groups,
      {this.helpRu = '', this.helpEn = ''});
  final String id;
  final String ru;
  final String en;
  final String helpRu;
  final String helpEn;
  final AppMenuIconRole icon;
  final List<_LifeOsMenuGroup> groups;

  String title(bool ruLocale) => ruLocale ? ru : en;
  String subtitle(bool ruLocale) => ruLocale ? helpRu : helpEn;
}

/// Navigation-only catalog. No fake toggles, nonfunctional integrations or
/// duplicated preference state; every row dispatches to its owning screen.
const _sections = <_LifeOsMenuSection>[
  _LifeOsMenuSection('planning', 'Планирование и время', 'Planning & time',
      AppMenuIconRole.planning, [
    _LifeOsMenuGroup('РАСПИСАНИЕ', 'SCHEDULE', [
      _LifeOsMenuRow('dayBounds', 'Границы дня', 'Visible day hours',
          AppMenuIconRole.clock, LifeOsMenuAction.planningSettings,
          helpRu: 'Начало и конец временной шкалы',
          helpEn: 'Start and end of the timeline'),
      _LifeOsMenuRow('autoPlacement', 'Размещение планов', 'Plan placement',
          AppMenuIconRole.schedule, LifeOsMenuAction.planningSettings,
          helpRu: 'Последовательность и свободные промежутки',
          helpEn: 'Sequential placement and open slots'),
      _LifeOsMenuRow('defaultTimes', 'Время новых планов', 'Default plan times',
          AppMenuIconRole.defaultTime, LifeOsMenuAction.defaultPlanTimes,
          helpRu: 'Правила по категориям в Time View',
          helpEn: 'Category rules in Time View'),
    ]),
    _LifeOsMenuGroup('ВРЕМЕННАЯ ШКАЛА', 'TIME VIEW', [
      _LifeOsMenuRow('fixedTimeTags', 'Фиксированное время', 'Fixed-time tags',
          AppMenuIconRole.shield, LifeOsMenuAction.planningSettings),
      _LifeOsMenuRow('planRecordLink', 'Связь планов и записей',
          'Plans and records', AppMenuIconRole.link,
          LifeOsMenuAction.planningSettings),
      _LifeOsMenuRow('planDurations', 'Длительность по тегам',
          'Default tag durations', AppMenuIconRole.defaultTime,
          LifeOsMenuAction.tagDurations),
    ]),
  ], helpRu: 'Расписание и правила работы с задачами.',
     helpEn: 'Schedule and plan placement rules.'),
  _LifeOsMenuSection('notes', 'Заметки и списки', 'Notes & lists',
      AppMenuIconRole.notes, [
    _LifeOsMenuGroup('ВИД И ОТОБРАЖЕНИЕ', 'DISPLAY', [
      _LifeOsMenuRow('noteDisplay', 'Вид заметок', 'Notes appearance',
          AppMenuIconRole.notes, LifeOsMenuAction.notesSettings,
          helpRu: 'Сетка, список и карточки',
          helpEn: 'Grid, list and cards'),
      _LifeOsMenuRow('completion', 'Завершённые элементы', 'Completed items',
          AppMenuIconRole.list, LifeOsMenuAction.notesSettings),
      _LifeOsMenuRow('noteCategories', 'Панель категорий', 'Category bar',
          AppMenuIconRole.folder, LifeOsMenuAction.notesCategoryBar,
          helpRu: 'Закреплённые категории и фильтры',
          helpEn: 'Pinned categories and filters'),
    ]),
  ], helpRu: 'Порядок, фильтры и вид карточек.',
     helpEn: 'Order, filters and card presentation.'),
  _LifeOsMenuSection('categories', 'Категории и теги',
      'Categories & tags', AppMenuIconRole.categories, [
    _LifeOsMenuGroup('КАТЕГОРИИ', 'CATEGORIES', [
      _LifeOsMenuRow('allCategories', 'Все категории', 'All categories',
          AppMenuIconRole.folder, LifeOsMenuAction.categories,
          helpRu: 'Дерево, создание, перенос и сортировка',
          helpEn: 'Tree, creation, moving and ordering'),
      _LifeOsMenuRow('categoryAppearance', 'Оформление категорий',
          'Category appearance', AppMenuIconRole.appearance,
          LifeOsMenuAction.categoryAppearance),
    ]),
    _LifeOsMenuGroup('ТЕГИ', 'TAGS', [
      _LifeOsMenuRow('allTags', 'Управление тегами', 'Manage tags',
          AppMenuIconRole.tags, LifeOsMenuAction.tags),
      _LifeOsMenuRow('tagDisplay', 'Вид тегов', 'Tag appearance',
          AppMenuIconRole.theme, LifeOsMenuAction.tagAppearance),
      _LifeOsMenuRow('tagDurations', 'Длительность по тегам',
          'Durations by tag', AppMenuIconRole.defaultTime,
          LifeOsMenuAction.tagDurations),
    ]),
  ], helpRu: 'Общая организация данных приложения.',
     helpEn: 'Common organization across the application.'),
  _LifeOsMenuSection('notifications', 'Уведомления и ритуалы',
      'Notifications & routines', AppMenuIconRole.notifications, [
    _LifeOsMenuGroup('НАПОМИНАНИЯ', 'REMINDERS', [
      _LifeOsMenuRow('notificationAccess', 'Разрешения на уведомления',
          'Notification permission', AppMenuIconRole.notifications,
          LifeOsMenuAction.notifications),
      _LifeOsMenuRow('unfilledTime', 'Незаполненное время',
          'Unfilled time alerts', AppMenuIconRole.clock,
          LifeOsMenuAction.notifications,
          helpRu: 'Промежуток и задержка напоминания',
          helpEn: 'Minimum gap and notification delay'),
    ]),
    _LifeOsMenuGroup('ПРИВЫЧКИ', 'ROUTINES', [
      _LifeOsMenuRow('morning', 'Утренний сценарий',
          'Morning prompt', AppMenuIconRole.viktor,
          LifeOsMenuAction.morning),
    ]),
  ]),
  _LifeOsMenuSection('viktor', 'Виктор и голос', 'Viktor & voice',
      AppMenuIconRole.viktor, [
    _LifeOsMenuGroup('ВИКТОР', 'VIKTOR', [
      _LifeOsMenuRow('viktorChat', 'Открыть Виктора', 'Open Viktor',
          AppMenuIconRole.viktor, LifeOsMenuAction.viktor,
          helpRu: 'Чат и голосовые команды',
          helpEn: 'Chat and voice commands'),
    ]),
    _LifeOsMenuGroup('УПРАВЛЕНИЕ ГОЛОСОМ', 'VOICE CONTROLS', [
      _LifeOsMenuRow('voiceSettings', 'Голосовые настройки',
          'Voice settings', AppMenuIconRole.microphone,
          LifeOsMenuAction.voiceSettings,
          helpRu: 'Микрофон, горячие клавиши и запуск',
          helpEn: 'Microphone, shortcuts and startup'),
    ]),
  ]),
  _LifeOsMenuSection('connections', 'Подключения и данные',
      'Connections & data', AppMenuIconRole.connections, [
    _LifeOsMenuGroup('ИНТЕГРАЦИИ', 'INTEGRATIONS', [
      _LifeOsMenuRow('calendars', 'Календари', 'Connected calendars',
          AppMenuIconRole.calendar, LifeOsMenuAction.calendars,
          helpRu: 'Google и Microsoft',
          helpEn: 'Google and Microsoft'),
      _LifeOsMenuRow('contactSources', 'Источники контактов',
          'Contact sources', AppMenuIconRole.people,
          LifeOsMenuAction.peopleSources),
    ]),
    _LifeOsMenuGroup('ДАННЫЕ', 'DATA', [
      _LifeOsMenuRow('syncStatus', 'Синхронизация',
          'Synchronization', AppMenuIconRole.sync,
          LifeOsMenuAction.syncStatus,
          helpRu: 'Статус подключения и офлайн-очередь',
          helpEn: 'Connection state and offline queue'),
    ]),
  ]),
  _LifeOsMenuSection('health', 'Здоровье и сон', 'Health & sleep',
      AppMenuIconRole.health, [
    _LifeOsMenuGroup('СОН', 'SLEEP', [
      _LifeOsMenuRow('sleepSync', 'Синхронизация сна',
          'Sleep synchronization', AppMenuIconRole.health,
          LifeOsMenuAction.sleep,
          helpRu: 'Google Health и доступные источники',
          helpEn: 'Google Health and supported sources'),
    ]),
  ]),
  _LifeOsMenuSection('appearance', 'Оформление и язык',
      'Appearance & region', AppMenuIconRole.appearance, [
    _LifeOsMenuGroup('ИНТЕРФЕЙС', 'INTERFACE', [
      _LifeOsMenuRow('theme', 'Цветовая тема', 'Color theme',
          AppMenuIconRole.theme, LifeOsMenuAction.appearance,
          helpRu: 'Светлая, тёмная и системная',
          helpEn: 'Light, dark and system'),
      _LifeOsMenuRow('language', 'Язык приложения', 'App language',
          AppMenuIconRole.language, LifeOsMenuAction.languageAndTime),
      _LifeOsMenuRow('timezone', 'Часовой пояс', 'Time zone',
          AppMenuIconRole.clock, LifeOsMenuAction.languageAndTime),
    ]),
  ]),
  _LifeOsMenuSection('account', 'Аккаунт и безопасность',
      'Account & security', AppMenuIconRole.account, [
    _LifeOsMenuGroup('МОЙ ПРОФИЛЬ', 'MY ACCOUNT', [
      _LifeOsMenuRow('profile', 'Имя и данные профиля', 'Profile details',
          AppMenuIconRole.account, LifeOsMenuAction.account),
    ]),
    _LifeOsMenuGroup('ЗАЩИТА И ВХОД', 'SECURITY & SIGN-IN', [
      _LifeOsMenuRow('security', 'Пароль и биометрия',
          'Password and biometrics', AppMenuIconRole.shield,
          LifeOsMenuAction.accountSecurity),
      _LifeOsMenuRow('session', 'Управление сеансом', 'Session',
          AppMenuIconRole.account, LifeOsMenuAction.accountSession),
    ]),
  ]),
  _LifeOsMenuSection('about', 'О приложении', 'About',
      AppMenuIconRole.about, [
    _LifeOsMenuGroup('LIFE OS', 'LIFE OS', [
      _LifeOsMenuRow('version', 'Версия приложения',
          'App version', AppMenuIconRole.about, LifeOsMenuAction.about),
      _LifeOsMenuRow('support', 'Диагностика',
          'Diagnostics', AppMenuIconRole.filter,
          LifeOsMenuAction.diagnostics),
    ]),
  ]),
];

const _homeGroups = <({String ru, String en, List<String> ids})>[
  (ru: 'РАБОТА И ОРГАНИЗАЦИЯ', en: 'WORK & ORGANIZATION',
     ids: ['planning', 'notes', 'categories']),
  (ru: 'ПОМОЩНИК И ПРИВЫЧКИ', en: 'ASSISTANT & ROUTINES',
     ids: ['viktor', 'notifications']),
  (ru: 'ДАННЫЕ И ПОДКЛЮЧЕНИЯ', en: 'DATA & CONNECTIONS',
     ids: ['connections', 'health']),
  (ru: 'ПРИЛОЖЕНИЕ', en: 'APPLICATION',
     ids: ['appearance', 'about']),
];

class _LifeOsMenuPageState extends State<LifeOsMenuPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String? _activeSection;

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection;
    _search.addListener(_refreshSearch);
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.removeListener(_refreshSearch);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSection(String id) {
    FocusManager.instance.primaryFocus?.unfocus();
    _search.clear();
    setState(() => _activeSection = id);
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.initialSection != null) {
      widget.onBackToMenu?.call();
      return;
    }
    setState(() => _activeSection = null);
  }

  _LifeOsMenuSection _section(String id) =>
      _sections.firstWhere((section) => section.id == id);

  bool _matches(String query, Iterable<String> fields) =>
      fields.any((value) => value.toLowerCase().contains(query));

  List<(_LifeOsMenuSection, _LifeOsMenuRow?)> _searchResults() {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    final found = <(_LifeOsMenuSection, _LifeOsMenuRow?)>[];
    for (final section in _sections) {
      if (_matches(query, [section.ru, section.en, section.helpRu, section.helpEn])) {
        found.add((section, null));
      }
      for (final group in section.groups) {
        for (final row in group.rows) {
          if (_matches(query, [row.ru, row.en, row.helpRu, row.helpEn, row.id])) {
            found.add((section, row));
          }
        }
      }
    }
    return found;
  }

  Widget _heading(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 0, 10),
    child: Text(
      value,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _group(BuildContext context, List<Widget> items) {
    return AppSettingsNavigationGroup(children: items);
  }

  Widget _sectionRow(_LifeOsMenuSection entry) {
    return AppSettingsNavigationRow(
      title: entry.title(_ru),
      leading: AppSettingsMenuIcon(icon: AppMenuIcons.icon(entry.icon)),
      // Every category opens one detail index, never a different settings hub.
      onTap: () => _openSection(entry.id),
    );
  }

  Widget _detailRow(_LifeOsMenuRow entry, {String? subtitle}) {
    return AppSettingsNavigationRow(
      title: entry.title(_ru),
      subtitle: subtitle ?? (entry.subtitle(_ru).isNotEmpty
          ? entry.subtitle(_ru)
          : null),
      leading: AppSettingsMenuIcon(icon: AppMenuIcons.icon(entry.icon)),
      onTap: () => widget.onAction(entry.action),
    );
  }

  Widget _profileCard(BuildContext context) {
    return StreamBuilder<UserSettings>(
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, snapshot) {
        final settings = snapshot.data ?? DatabaseService.instance.settings;
        final name = (settings.displayName ?? '').trim();
        final email = AuthBridge.currentAuthEmail?.trim() ?? '';
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(21),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onAction(LifeOsMenuAction.account),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                    child: Icon(AppMenuIcons.icon(AppMenuIconRole.account),
                      color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : (_ru ? 'Мой профиль' : 'My account'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600)),
                      if (email.isNotEmpty)
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  )),
                  Icon(AppMenuIcons.icon(AppMenuIconRole.arrow),
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkSettingsChevron
                        : AppColors.settingsChevron),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _searchField() => AppTextField(
    controller: _search,
    focusNode: _searchFocus,
    textInputAction: TextInputAction.search,
    hintText: _ru ? 'Найти настройку' : 'Find a setting',
    variant: AppTextFieldVariant.search,
    suffixIcon: _search.text.isEmpty ? null : IconButton(
      tooltip: _ru ? 'Очистить поиск' : 'Clear search',
      icon: Icon(AppMenuIcons.icon(AppMenuIconRole.close)),
      onPressed: _search.clear,
    ),
  );

  Widget _home(BuildContext context) {
    final result = _searchResults();
    final searching = _search.text.trim().isNotEmpty;
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_ru ? 'Настройки' : 'Settings',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          )),
        const SizedBox(height: 18),
        _searchField(),
        const SizedBox(height: 16),
        if (searching) ...[
          _heading(context, _ru ? 'РЕЗУЛЬТАТЫ ПОИСКА' : 'SEARCH RESULTS'),
          if (result.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_ru ? 'Ничего не найдено' : 'No matching settings'),
            )
          else
            _group(context, [
              for (final (section, entry) in result)
                entry == null
                    ? _sectionRow(section)
                    : _detailRow(entry, subtitle: section.title(_ru)),
            ]),
        ] else ...[
          // Desktop already has global navigation. Mobile exposes these
          // destinations here, without adding a second navigation rail.
          if (!desktop) ...[
            _profileCard(context),
            _heading(context, _ru ? 'РАЗДЕЛЫ' : 'DESTINATIONS'),
            _group(context, [
              _detailRow(const _LifeOsMenuRow(
                'pathsShortcut', 'Пути', 'Paths',
                AppMenuIconRole.paths, LifeOsMenuAction.paths)),
              _detailRow(const _LifeOsMenuRow(
                'peopleShortcut', 'Люди', 'People',
                AppMenuIconRole.people, LifeOsMenuAction.people)),
              _detailRow(const _LifeOsMenuRow(
                'viktorShortcut', 'Виктор', 'Viktor',
                AppMenuIconRole.viktor, LifeOsMenuAction.viktor)),
            ]),
          ],
          for (final group in _homeGroups) ...[
            _heading(context, _ru ? group.ru : group.en),
            _group(context, [
              for (final id in group.ids) _sectionRow(_section(id)),
            ]),
          ],
          if (DatabaseService.instance.settings.isAdmin) ...[
            _heading(context, _ru ? 'РАЗРАБОТКА' : 'DEVELOPMENT'),
            _group(context, [
              AppSettingsNavigationRow(
                title: 'Dev / Design Lab',
                leading: AppSettingsMenuIcon(
                  icon: AppMenuIcons.icon(AppMenuIconRole.filter)),
                onTap: () => widget.onAction(LifeOsMenuAction.componentLab),
              ),
            ]),
          ],
        ],
      ],
    );
  }

  Widget _details(BuildContext context, _LifeOsMenuSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _back,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(AppMenuIcons.icon(AppMenuIconRole.back)),
                const SizedBox(width: 9),
                Text(_ru ? 'Настройки' : 'Settings',
                  style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(section.title(_ru),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          )),
        if (section.subtitle(_ru).isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(section.subtitle(_ru),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        for (final group in section.groups) ...[
          _heading(context, group.title(_ru)),
          _group(context, [
            for (final row in group.rows) _detailRow(row),
          ]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) {
        return ValueListenableBuilder<int>(
          valueListenable: widget.activeTab,
          builder: (context, selectedTab, _) => PopScope(
          canPop: !((selectedTab == 7 ||
                  (widget.initialSection != null && selectedTab == 5)) &&
              _activeSection != null),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop &&
                (selectedTab == 7 ||
                    (widget.initialSection != null && selectedTab == 5)) &&
                _activeSection != null) {
              _back();
            }
          },
          child: AppSettingsPageBody(
            // Avoid reopening a section/search at the previous menu scroll offset.
            key: ValueKey(_activeSection ??
                (_search.text.trim().isEmpty ? 'home' : 'search')),
            children: [
              _activeSection == null
                  ? _home(context)
                  : _details(context, _section(_activeSection!)),
            ],
          ),
          ),
        );
      }),
    );
  }
}
