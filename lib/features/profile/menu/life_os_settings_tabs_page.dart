import 'dart:async';

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/life_color_compat.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/features/lists/notes_library_preferences.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/profile/menu/life_os_menu_page.dart';
import 'package:counter/features/profile/profile_view.dart';
import 'package:counter/features/settings/notifications/unfilled_time_notifications_section.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Settings are organized around the action the person wants to perform.
/// Uses the canonical app theme, colors and settings components throughout.
/// No parallel copy of feature preferences is stored in this page.
class LifeOsSettingsTabsPage extends StatefulWidget {
  const LifeOsSettingsTabsPage({
    super.key,
    required this.onAction,
    this.initialTab = 'profile',
  });

  final ValueChanged<LifeOsMenuAction> onAction;
  final String initialTab;

  @override
  State<LifeOsSettingsTabsPage> createState() => _LifeOsSettingsTabsPageState();
}

class _SettingsTab {
  const _SettingsTab(this.id, this.ru, this.en, this.icon, this.family);
  final String id;
  final String ru;
  final String en;
  final AppMenuIconRole icon;
  final MaterialColor family;
}

const _tabs = <_SettingsTab>[
  _SettingsTab('profile', 'Профиль', 'Profile', AppMenuIconRole.account, kCategoryNeutral),
  _SettingsTab('planning', 'Планирование', 'Planning', AppMenuIconRole.planning, kNordicWork),
  _SettingsTab('notes', 'Заметки', 'Notes', AppMenuIconRole.notes, kNordicStudy),
  _SettingsTab('categories', 'Категории и теги', 'Categories & tags', AppMenuIconRole.categories, kNordicErrands),
  _SettingsTab('people', 'Люди', 'People', AppMenuIconRole.people, kNordicPeople),
  _SettingsTab('notifications', 'Уведомления', 'Notifications', AppMenuIconRole.notifications, kNordicEntertainment),
  _SettingsTab('viktor', 'Виктор', 'Viktor', AppMenuIconRole.viktor, kNordicMovement),
  _SettingsTab('health', 'Здоровье', 'Health', AppMenuIconRole.health, kNordicHealth),
  _SettingsTab('appearance', 'Интерфейс', 'Appearance', AppMenuIconRole.appearance, kCategoryBlack),
];

class _LifeOsSettingsTabsPageState extends State<LifeOsSettingsTabsPage> {
  late String _tab;
  final _search = TextEditingController();
  final _name = TextEditingController();
  ({int start, int end})? _bounds;
  bool _afterLast = false;
  bool _loadingPlans = true;
  bool _savingPlan = false;
  bool _savingProfile = false;
  late Future<PlanAlarmPermissionStatus> _permission;

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
  String tr(String ru, String en) => _ru ? ru : en;

  @override
  void initState() {
    super.initState();
    _tab = _tabs.any((e) => e.id == widget.initialTab)
        ? widget.initialTab : 'profile';
    _name.text = DatabaseService.instance.settings.displayName ?? '';
    _search.addListener(_redraw);
    _permission = NotificationService.instance.permissionStatus();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bounds = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
      await DatabaseService.instance.loadPlanAutoPlacementMode();
      await NotesLibraryPreferences.load();
      await UnfilledTimeGapService.instance.start();
      if (!mounted) return;
      setState(() {
        _bounds = bounds;
        _afterLast = DatabaseService.instance.planAutoPlacementMode ==
            PlanAutoPlacementMode.afterLastPlan;
        _loadingPlans = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  void _redraw() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _search.removeListener(_redraw);
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  void _open(LifeOsMenuAction action) => widget.onAction(action);

  void _choose(String next) {
    FocusManager.instance.primaryFocus?.unfocus();
    _search.clear();
    setState(() => _tab = next);
  }

  _SettingsTab get selected => _tabs.firstWhere((e) => e.id == _tab);

  Widget _symbol(AppMenuIconRole icon, MaterialColor family) => SizedBox(
    height: 42, width: 42,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: family[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(AppMenuIcons.icon(icon), size: 22, color: family[700]),
    ),
  );

  Widget _link(String title, AppMenuIconRole icon, LifeOsMenuAction action,
      {String? subtitle}) =>
      AppSettingsNavigationRow(
        title: title,
        subtitle: subtitle,
        leading: _symbol(icon, selected.family),
        onTap: () => _open(action),
      );

  Widget _section(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 19, 0, 10),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ),
      AppSettingsNavigationGroup(children: rows),
    ],
  );

  Widget _form(String title, Widget child) =>
      AppSettingsSectionCard(title: title, child: child);

  Future<void> _saveBounds(int start, int end) async {
    final normalized = PlanningSheetTimelinePrefs.normalizeExtendedRange(start, end);
    setState(() => _bounds = normalized);
    try {
      await PlanningSheetTimelinePrefs.saveVisibleDayRange(
        normalized.start, normalized.end);
    } catch (_) {
      if (mounted) setState(() => _bounds = null);
      unawaited(_load());
    }
  }

  Future<void> _setPlacement(bool afterLast) async {
    if (_savingPlan) return;
    final prev = _afterLast;
    setState(() { _savingPlan = true; _afterLast = afterLast; });
    try {
      await DatabaseService.instance.setPlanAutoPlacementMode(afterLast
          ? PlanAutoPlacementMode.afterLastPlan
          : PlanAutoPlacementMode.nearestFreeSlot);
    } catch (_) {
      if (mounted) setState(() => _afterLast = prev);
    } finally {
      if (mounted) setState(() => _savingPlan = false);
    }
  }

  Future<void> _saveName() async {
    if (_savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      final db = DatabaseService.instance;
      await db.saveSettings(db.settings.copyWith(displayName: _name.text.trim()));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _setTheme(String mode) async {
    final db = DatabaseService.instance;
    await db.saveSettings(db.settings.copyWith(themeMode: mode));
    if (mounted) setState(() {});
  }

  Widget _profile() {
    final theme = Theme.of(context);
    final email = AuthBridge.currentAuthEmail ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _form(tr('Мои данные', 'My details'), Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: tr('Отображаемое имя', 'Display name'),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => unawaited(_saveName()),
          ),
          const SizedBox(height: 12),
          if (email.isNotEmpty) Text(email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: FilledButton(
            onPressed: _savingProfile ? null : () => unawaited(_saveName()),
            child: Text(tr('Сохранить имя', 'Save name')),
          )),
        ],
      )),
      _section(tr('Безопасность', 'Security'), [
        _link(tr('Пароль и защита', 'Password & protection'),
          AppMenuIconRole.shield, LifeOsMenuAction.accountSecurity,
          subtitle: tr('Восстановление пароля и биометрия', 'Password recovery and biometrics')),
      ]),
      _section(tr('Данные и помощь', 'Data & help'), [
        _link(tr('Состояние данных', 'Data status'), AppMenuIconRole.sync,
          LifeOsMenuAction.syncStatus,
          subtitle: tr('Офлайн-изменения и ошибки', 'Offline changes and errors')),
        _link(tr('О приложении', 'About'), AppMenuIconRole.about,
          LifeOsMenuAction.about),
      ]),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => _open(LifeOsMenuAction.accountSession),
        icon: const Icon(Icons.logout_rounded),
        label: Text(tr('Выйти из аккаунта', 'Sign out')),
      ),
    ]);
  }

  Widget _dayHourSelect(String label, int value, ValueChanged<int> onChanged) =>
    Flexible(child: DropdownButtonFormField<int>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label,
        border: const OutlineInputBorder()),
      items: [
        for (int h = PlanningSheetTimelinePrefs.extendedMin;
            h <= PlanningSheetTimelinePrefs.extendedMax; h++)
          DropdownMenuItem<int>(
            value: h,
            child: Text(PlanningSheetTimelinePrefs.formatExtendedHourClock(h)),
          ),
      ],
      onChanged: (next) { if (next != null) onChanged(next); },
    ));

  Widget _planning() {
    final bounds = _bounds;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _form(tr('Расписание', 'Schedule'),
        _loadingPlans || bounds == null
          ? const LinearProgressIndicator()
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                _symbol(AppMenuIconRole.clock, selected.family),
                const SizedBox(width: 12),
                Expanded(child: Text(tr('Границы видимого дня', 'Visible day hours'),
                  style: Theme.of(context).textTheme.bodyLarge)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _dayHourSelect(tr('Начало', 'Start'), bounds.start,
                  (value) => unawaited(_saveBounds(value, bounds.end))),
                const SizedBox(width: 12),
                _dayHourSelect(tr('Конец', 'End'), bounds.end,
                  (value) => unawaited(_saveBounds(bounds.start, value))),
              ]),
              const SizedBox(height: 18),
              DropdownButtonFormField<bool>(
                initialValue: _afterLast,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Размещение новых планов', 'New plan placement'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: false,
                    child: Text(tr('Ближайшее свободное время', 'Nearest free slot'))),
                  DropdownMenuItem(value: true,
                    child: Text(tr('После последнего плана', 'After last plan'))),
                ],
                onChanged: _savingPlan ? null
                  : (v) { if (v != null) unawaited(_setPlacement(v)); },
              ),
            ]),
      ),
      _section(tr('Дополнительные правила', 'Additional rules'), [
        _link(tr('Время новых планов', 'Default plan times'),
          AppMenuIconRole.defaultTime, LifeOsMenuAction.defaultPlanTimes),
        _link(tr('Фиксированное время и связь записей', 'Fixed time and record links'),
          AppMenuIconRole.link, LifeOsMenuAction.planningSettings),
        _link(tr('Подключённые календари', 'Connected calendars'),
          AppMenuIconRole.calendar, LifeOsMenuAction.calendars),
      ]),
      _section(tr('Местоположение и активность', 'Location & activity'), [
        _link(tr('Отслеживание перемещений', 'Movement tracking'),
          AppMenuIconRole.paths, LifeOsMenuAction.contextAwareness,
          subtitle: tr(
            'Фоновая геолокация и физическая активность · разрешения Android',
            'Background location and physical activity · Android permissions')),
      ]),
    ]);
  }

  Widget _notes() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _form(tr('Отображение заметок', 'Notes appearance'),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ValueListenableBuilder<String>(
            valueListenable: NotesLibraryPreferences.mode,
            builder: (context, current, _) => SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'grid', label: Text(tr('Сетка', 'Grid')),
                  icon: const Icon(Icons.grid_view_rounded)),
                ButtonSegment(value: 'list', label: Text(tr('Список', 'List')),
                  icon: const Icon(Icons.view_list_rounded)),
              ],
              selected: {current},
              onSelectionChanged: (next) =>
                unawaited(NotesLibraryPreferences.select(next.first)),
            ),
          ),
          const Divider(height: 28),
          ValueListenableBuilder<bool>(
            valueListenable: NotesLibraryPreferences.checkboxMode,
            builder: (context, checked, _) => AppSettingsControlRow(
              title: tr('Показывать чекбоксы', 'Show checkboxes'),
              leading: _symbol(AppMenuIconRole.list, selected.family),
              value: checked,
              onChanged: (v) =>
                unawaited(NotesLibraryPreferences.setCheckboxMode(v)),
            ),
          ),
          StreamBuilder(
            stream: DatabaseService.instance.userSettingsStream,
            initialData: DatabaseService.instance.settings,
            builder: (context, snapshot) {
              final settings = snapshot.data ?? DatabaseService.instance.settings;
              return AppSettingsControlRow(
                title: tr('Показывать теги на карточках', 'Show tags on cards'),
                leading: _symbol(AppMenuIconRole.tags, selected.family),
                value: settings.showListTagsOnCards,
                onChanged: (value) => unawaited(
                  DatabaseService.instance.persistShowListTagsOnCards(value)),
              );
            },
          ),
        ]),
      ),
      _form(tr('Выполненные пункты', 'Completed items'),
        StreamBuilder(
          stream: DatabaseService.instance.userSettingsStream,
          initialData: DatabaseService.instance.settings,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? DatabaseService.instance.settings;
            final value = settings.listCompletionBehavior;
            return DropdownButtonFormField<String>(
              key: ValueKey(value),
              initialValue: const ['stay','bottom','hide','archive'].contains(value)
                  ? value : 'stay',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('После выполнения', 'After completion'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'stay', child: Text(tr('Оставлять', 'Keep in place'))),
                DropdownMenuItem(value: 'bottom', child: Text(tr('Перемещать вниз', 'Move to bottom'))),
                DropdownMenuItem(value: 'hide', child: Text(tr('Скрывать', 'Hide'))),
                DropdownMenuItem(value: 'archive', child: Text(tr('В архив', 'Archive'))),
              ],
              onChanged: (next) {
                if (next == null) return;
                final db = DatabaseService.instance;
                unawaited(db.saveSettings(
                  db.settings.copyWith(listCompletionBehavior: next)));
              },
            );
          },
        ),
      ),
      _section(tr('Панель категорий', 'Category bar'), [
        _link(tr('Закреплённые категории и фильтры', 'Pinned categories and filters'),
          AppMenuIconRole.folder, LifeOsMenuAction.notesCategoryBar),
      ]),
    ]);
  }

  Widget _categories() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(tr('Категории', 'Categories'), [
        _link(tr('Дерево категорий', 'Category tree'),
          AppMenuIconRole.folder, LifeOsMenuAction.categories,
          subtitle: tr('Создание, перенос и порядок', 'Create, move and order')),
      ]),
      _section(tr('Теги', 'Tags'), [
        _link(tr('Управление тегами', 'Manage tags'),
          AppMenuIconRole.tags, LifeOsMenuAction.tags),
        _link(tr('Внешний вид тегов', 'Tag appearance'),
          AppMenuIconRole.theme, LifeOsMenuAction.tagAppearance),
        _link(tr('Длительность по тегам', 'Duration by tag'),
          AppMenuIconRole.defaultTime, LifeOsMenuAction.tagDurations),
      ]),
    ],
  );

  Widget _people() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(tr('Люди и связи', 'People & relationships'), [
        _link(tr('Список людей и круги', 'People and circles'),
          AppMenuIconRole.people, LifeOsMenuAction.people),
        _link(tr('Источники контактов', 'Contact sources'),
          AppMenuIconRole.connections, LifeOsMenuAction.peopleSources,
          subtitle: tr('Телефон, Google, Microsoft и другие', 'Device, Google, Microsoft and more')),
      ]),
    ],
  );

  Widget _gapSettings() => ValueListenableBuilder<UnfilledTimeGapSettings>(
    valueListenable: UnfilledTimeGapService.instance.settings,
    builder: (context, gap, _) => _form(
      tr('Незаполненное время', 'Unfilled time'),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppSettingsControlRow(
          title: tr('Напоминать о пробелах в записях', 'Remind about missing time'),
          leading: _symbol(AppMenuIconRole.clock, selected.family),
          value: gap.notificationsEnabled,
          onChanged: (v) => unawaited(
            UnfilledTimeGapService.instance.setNotificationsEnabled(v)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ValueKey('gap-${gap.minimumGapMinutes}'),
          initialValue: gap.minimumGapMinutes,
          decoration: InputDecoration(
            labelText: tr('Минимальный пробел', 'Minimum gap'),
            border: const OutlineInputBorder()),
          items: [5, 10, 15, 30].map((m) => DropdownMenuItem(
            value: m, child: Text('$m ' + tr('мин', 'min')))).toList(),
          onChanged: (v) { if (v != null) unawaited(
            UnfilledTimeGapService.instance.setMinimumGapMinutes(v)); },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('delay-${gap.notificationDelayMinutes}'),
          initialValue: gap.notificationDelayMinutes,
          decoration: InputDecoration(
            labelText: tr('Задержка напоминания', 'Notification delay'),
            border: const OutlineInputBorder()),
          items: [0, 15, 30, 60].map((m) => DropdownMenuItem(
            value: m, child: Text(m == 0 ? tr('Сразу', 'Immediately')
              : '$m ' + tr('мин', 'min')))).toList(),
          onChanged: (v) { if (v != null) unawaited(
            UnfilledTimeGapService.instance.setNotificationDelayMinutes(v)); },
        ),
      ]),
    ),
  );

  Widget _notifications() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(tr('Существующие уведомления', 'Available notifications'), [
        _link(tr('Перед началом плана', 'Before a plan starts'),
          AppMenuIconRole.calendar, LifeOsMenuAction.planning,
          subtitle: tr(
            'Время предупреждения задаётся отдельно в каждом плане',
            'Lead time is set on each plan')),
        _link(tr('Дни рождения', 'Birthdays'),
          AppMenuIconRole.people, LifeOsMenuAction.people,
          subtitle: tr('За сколько дней — в карточке человека',
            'Days before are configured for each person')),
      ]),
      _gapSettings(),
      _form(tr('Начало дня', 'Start of day'),
        const MorningStartSettingsSection()),
      _section(tr('Системные разрешения', 'System permissions'), [
        AppSettingsNavigationRow(
          title: tr('Доступ к уведомлениям', 'Notification permission'),
          leading: _symbol(AppMenuIconRole.notifications, selected.family),
          value: kIsWeb ? tr('Браузер', 'Browser') : null,
          onTap: () async {
            await NotificationService.instance.requestPermissions();
            if (mounted) setState(() {
              _permission = NotificationService.instance.permissionStatus();
            });
          },
        ),
      ]),
    ],
  );

  Widget _viktor() => _section(tr('Виктор', 'Viktor'), [
    _link(tr('Голосовое управление Виктором', 'Viktor voice controls'),
      AppMenuIconRole.microphone, LifeOsMenuAction.voiceSettings,
      subtitle: tr('Микрофон, горячие клавиши и запуск на Windows',
        'Microphone, hotkeys and Windows startup')),
  ]);

  Widget _health() => _section(tr('Сон', 'Sleep'), [
    _link(tr('Подключение Xiaomi / Mi Fitness', 'Connect Xiaomi / Mi Fitness'),
      AppMenuIconRole.health, LifeOsMenuAction.sleep),
  ]);

  Widget _appearance() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _form(tr('Тема', 'Theme'),
        StreamBuilder(
          stream: DatabaseService.instance.userSettingsStream,
          initialData: DatabaseService.instance.settings,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? DatabaseService.instance.settings;
            return SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'light', label: Text(tr('Светлая', 'Light'))),
                ButtonSegment(value: 'dark', label: Text(tr('Тёмная', 'Dark'))),
                ButtonSegment(value: 'system', label: Text(tr('Системная', 'System'))),
              ],
              selected: {const ['light', 'dark', 'system'].contains(settings.themeMode)
                  ? settings.themeMode : 'system'},
              onSelectionChanged: (values) =>
                  unawaited(_setTheme(values.first)),
            );
          },
        ),
      ),
      _section(tr('Язык и время', 'Language & time'), [
        _link(tr('Язык приложения', 'Application language'),
          AppMenuIconRole.language, LifeOsMenuAction.languageAndTime),
        _link(tr('Часовые пояса', 'Time zones'),
          AppMenuIconRole.clock, LifeOsMenuAction.languageAndTime,
          subtitle: tr('Параметры времени профиля', 'Profile time preferences')),
        _link(tr('Набор иконок категорий', 'Category icon collection'),
          AppMenuIconRole.appearance, LifeOsMenuAction.appearance),
      ]),
    ],
  );

  Widget _tabContent() => switch (_tab) {
    'profile' => _profile(),
    'planning' => _planning(),
    'notes' => _notes(),
    'categories' => _categories(),
    'people' => _people(),
    'notifications' => _notifications(),
    'viktor' => _viktor(),
    'health' => _health(),
    'appearance' => _appearance(),
    _ => _profile(),
  };

  Widget _tabNavigation(bool desktop) {
    if (!desktop) {
      return DropdownButtonFormField<String>(
        key: ValueKey('settings-tab-$_tab'),
        initialValue: _tab,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tr('Раздел настроек', 'Settings section'),
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final tab in _tabs)
            DropdownMenuItem(value: tab.id, child: Text(_ru ? tab.ru : tab.en)),
        ],
        onChanged: (v) { if (v != null) _choose(v); },
      );
    }
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        for (final tab in _tabs)
          ChoiceChip(
            label: Text(_ru ? tab.ru : tab.en),
            avatar: Icon(AppMenuIcons.icon(tab.icon), size: 18,
                color: tab.family[700]),
            selected: _tab == tab.id,
            selectedColor: tab.family[100],
            side: BorderSide(color: _tab == tab.id
                ? tab.family[500]! : Theme.of(context).colorScheme.outlineVariant),
            onSelected: (_) => _choose(tab.id),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    return Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) => AppSettingsPageBody(children: [
        Text(tr('Настройки', 'Settings'),
          style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        _tabNavigation(desktop),
        const SizedBox(height: 22),
        Row(children: [
          _symbol(selected.icon, selected.family),
          const SizedBox(width: 12),
          Expanded(child: Text(_ru ? selected.ru : selected.en,
            style: Theme.of(context).textTheme.titleLarge)),
        ]),
        const SizedBox(height: 8),
        _tabContent(),
      ])),
    );
  }
}
