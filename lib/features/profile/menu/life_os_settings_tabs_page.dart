import 'dart:async';

import 'package:counter/features/settings/categories/category_icon_collection_preference.dart';

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/widgets/app_glass_edge_fade.dart';

import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/life_color_compat.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
import 'package:counter/core/app_build_info.dart';
import 'package:counter/core/widgets/app_settings_breadcrumb_bar.dart';
import 'package:counter/features/profile/settings/account_settings_section.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/features/lists/notes_library_preferences.dart';
import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:counter/features/planning/settings/default_plan_times_settings_block.dart';
import 'package:counter/features/profile/menu/life_os_menu_page.dart';
import 'package:counter/features/profile/menu/life_os_locale_timezone_section.dart';
import 'package:counter/features/profile/profile_view.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
import 'package:flutter/material.dart';

/// Settings are organized around the action the person wants to perform.
/// Uses the canonical app theme, colors and settings components throughout.
/// No parallel copy of feature preferences is stored in this page.
class LifeOsSettingsTabsPage extends StatefulWidget {
  const LifeOsSettingsTabsPage({
    super.key,
    required this.onAction,
    this.initialTab = 'profile',
    this.initialDefaultPlanTimes = false,
    this.activeTab,
    this.shellTabIndex = 7,
  });

  final ValueChanged<LifeOsMenuAction> onAction;
  final String initialTab;
  final bool initialDefaultPlanTimes;
  final ValueListenable<int>? activeTab;
  final int shellTabIndex;

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
  _SettingsTab('notes', 'Заметки и списки', 'Notes & lists', AppMenuIconRole.notes, kNordicStudy),
  _SettingsTab('categories', 'Организация', 'Organization', AppMenuIconRole.categories, kNordicErrands),
  _SettingsTab('notifications', 'Уведомления', 'Notifications', AppMenuIconRole.notifications, kNordicEntertainment),
  _SettingsTab('data', 'Интеграции', 'Integrations', AppMenuIconRole.connections, kNordicTransport),
  _SettingsTab('appearance', 'Общие', 'General', AppMenuIconRole.appearance, kCategoryBlack),
  _SettingsTab('about', 'О приложении', 'About', AppMenuIconRole.about, kCategoryNeutral),
];

class _LifeOsSettingsTabsPageState extends State<LifeOsSettingsTabsPage> {
  late String _tab;
  // Phone Settings starts as a category list. A profile has its own screen.
  // Desktop retains the existing tabs and preference editors.
  bool _mobileDetailOpen = false;
  bool _planningDefaultTimesOpen = false;
  ({int start, int end})? _bounds;
  bool _afterLast = false;
  bool _loadingPlans = true;
  bool _savingPlan = false;

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
  String tr(String ru, String en) => _ru ? ru : en;

  @override
  void initState() {
    super.initState();
    final initial = switch (widget.initialTab) {
      'people' => 'categories', 'health' => 'data',
      'viktor' => 'appearance', _ => widget.initialTab,
    };
    _tab = _tabs.any((e) => e.id == initial) ? initial : 'profile';
    _planningDefaultTimesOpen = _mobileDetailOpen = widget.initialDefaultPlanTimes;
    _loadSection(_tab);
  }

  Future<void> _load() async {
    try {
      final bounds = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
      await DatabaseService.instance.loadPlanAutoPlacementMode();
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

  void _loadSection(String id) {
    if (id == 'planning' && _bounds == null) unawaited(_load());
    if (id == 'notes') unawaited(NotesLibraryPreferences.load());
    if (id == 'notifications') unawaited(UnfilledTimeGapService.instance.start());
  }

  void _open(LifeOsMenuAction action) => widget.onAction(action);

  void _choose(String next) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = next;
      _mobileDetailOpen = true; _planningDefaultTimesOpen = false;
    });
    _loadSection(next);
  }

  void _backToMobileSettings() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _mobileDetailOpen = _planningDefaultTimesOpen; _planningDefaultTimesOpen = false; });
  }

  _SettingsTab get selected => _tabs.firstWhere((e) => e.id == _tab);

  Widget _symbol(AppMenuIconRole icon, MaterialColor family) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    // Keep saved category swatches unchanged. Dark chrome uses a controlled,
    // lighter translucent plate over the actual card, not a muddy 900 shade.
    final plate = dark
        ? Color.alphaBlend(
            family[500]!.withValues(alpha: 0.18),
            scheme.surfaceContainerHigh,
          )
        : family[100]!;
    return SizedBox(
      height: 42, width: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: plate,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(AppMenuIcons.icon(icon), size: 22,
          color: dark ? family[200] : family[700]),
      ),
    );
  }

  Widget _link(String title, AppMenuIconRole icon, LifeOsMenuAction action,
      {String? subtitle}) =>
      AppSettingsNavigationRow(
        title: title, compact: true,
        subtitle: subtitle,
        leading: _symbol(icon, selected.family),
        onTap: () => _open(action),
      );

  Widget _section(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title.isNotEmpty) Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 0, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ),
      AppSettingsNavigationGroup(children: rows),
      const SizedBox(height: 8),
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

  Future<void> _setTheme(String mode) async {
    final db = DatabaseService.instance;
    await db.saveSettings(db.settings.copyWith(themeMode: mode));
    if (mounted) setState(() {});
  }


  Widget _profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _form(tr('Мои данные', 'My details'), const ProfileNameEditor()),
      _section(tr('Безопасность', 'Security'), [
        _link(tr('Пароль и защита', 'Password & protection'),
          AppMenuIconRole.shield, LifeOsMenuAction.accountSecurity),
      ]),
      const SizedBox(height: 14),
      const AccountSecuritySection(showPeopleEntry: false, showIdentity: false),
    ]);

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
    if (_planningDefaultTimesOpen) return const DefaultPlanTimesSettingsBlock();
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
                key: ValueKey('placement-$_afterLast'),
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
        AppSettingsNavigationRow(compact: true, title: t(currentLocale.value, 'plan_default_times_title'),
          leading: _symbol(AppMenuIconRole.defaultTime, selected.family),
          onTap: () => setState(() => _planningDefaultTimesOpen = true)),
        _link(tr('Фиксированное время и связь записей', 'Fixed time and record links'),
          AppMenuIconRole.link, LifeOsMenuAction.planningSettings),
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
      _form(tr('Иконки категорий', 'Category icons'),
        CategoryIconCollectionPreference(isRussian: _ru)),
      _section(tr('Теги', 'Tags'), [
        _link(tr('Управление тегами', 'Manage tags'),
          AppMenuIconRole.tags, LifeOsMenuAction.tags),
        _link(tr('Внешний вид тегов', 'Tag appearance'),
          AppMenuIconRole.theme, LifeOsMenuAction.tagAppearance),
        _link(tr('Длительность по тегам', 'Duration by tag'),
          AppMenuIconRole.defaultTime, LifeOsMenuAction.tagDurations),
      ]),
      _section(tr('Люди и связи', 'People & relationships'), [
        _link(tr('Список людей и круги', 'People and circles'),
          AppMenuIconRole.people, LifeOsMenuAction.people),
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
          items: ({5, 10, 15, 30, gap.minimumGapMinutes}.toList()..sort())
              .map((m) => DropdownMenuItem(
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
          items: ({0, 15, 30, 60, gap.notificationDelayMinutes}.toList()..sort())
              .map((m) => DropdownMenuItem(
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
          onTap: kIsWeb ? null : () async {
            await NotificationService.instance.requestPermissions();
          },
        ),
      ]),
    ],
  );

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
      const LifeOsLocaleTimezoneControls(),
      _section(tr('Голосовое управление', 'Voice controls'), [
        _link(tr('Виктор', 'Viktor'),
          AppMenuIconRole.microphone, LifeOsMenuAction.voiceSettings,
          subtitle: tr('Микрофон, горячие клавиши и запуск на Windows',
            'Microphone, hotkeys and Windows startup')),
      ]),
    ],
  );

  Widget _data() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section('', [
        _link(tr('Календари', 'Calendars'), AppMenuIconRole.calendar,
          LifeOsMenuAction.calendars,
          subtitle: tr('Google и Microsoft', 'Google and Microsoft')),
        _link(tr('Контакты', 'Contacts'),
          AppMenuIconRole.people, LifeOsMenuAction.peopleSources),
        _link(tr('Сон и здоровье', 'Sleep & health'),
          AppMenuIconRole.health, LifeOsMenuAction.sleep,
          subtitle: 'Xiaomi / Mi Fitness'),
      ]),
    ],
  );

  Widget _about() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _form(tr('Версия приложения', 'App version'), Text(
        '${AppBuildInfo.gitCommit} · ${AppBuildInfo.builtAt}',
        style: Theme.of(context).textTheme.bodyMedium)),
      if (DatabaseService.instance.settings.isAdmin)
        _section(tr('Для разработчиков', 'Developer tools'), [
          _link(tr('Диагностика', 'Diagnostics'), AppMenuIconRole.filter,
            LifeOsMenuAction.diagnostics),
          _link('Dev / Design Lab', AppMenuIconRole.appearance,
            LifeOsMenuAction.componentLab),
        ]),
    ]);

  // Sections reuse the exact canonical category families, never a
  // new palette of arbitrary bright settings colors.
  Widget _mobileMenuRow(_SettingsTab tab) => AppSettingsNavigationRow(
    title: _ru ? tab.ru : tab.en,
    leading: _symbol(tab.icon, tab.family),
    onTap: () => _choose(tab.id),
  );

  Widget _mobileMenuGroup(String ru, String en, List<String> ids) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(5, 14, 0, 4),
        child: Text(tr(ru, en), style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600, letterSpacing: 0.6)),
      ),
      AppSettingsNavigationGroup(
        children: [for (final id in ids)
          _mobileMenuRow(_tabs.firstWhere((tab) => tab.id == id))],
      ),
    ]);

  Widget _mobileProfileCard() => StreamBuilder<UserSettings>(
    stream: DatabaseService.instance.userSettingsStream,
    initialData: DatabaseService.instance.settings,
    builder: (context, snapshot) {
      final scheme = Theme.of(context).colorScheme;
      final name = ProfileServiceExtension.resolveProfileDisplayLabelFor(
        settings: snapshot.data ?? DatabaseService.instance.settings);
      final email = AuthBridge.currentAuthEmail?.trim() ?? '';
      return Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _choose('profile'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.brightness == Brightness.dark
                    ? scheme.surfaceContainerHighest : kCategoryNeutral[100],
                child: Text(name.isEmpty ? '•' : name.substring(0, 1).toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.brightness == Brightness.dark
                      ? scheme.onSurface : kCategoryNeutral[800],
                  fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? tr('Мой профиль', 'My profile') : name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600)),
                  if (email.isNotEmpty)
                    Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
                ],
              )),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      );
    },
  );

  Widget _mobileHome() => Column(
    key: const ValueKey('mobile-settings-home'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _mobileProfileCard(),
      _mobileMenuGroup('ОРГАНИЗАЦИЯ', 'ORGANIZATION',
        ['planning', 'notes', 'categories', 'notifications']),
      _mobileMenuGroup('ПРИЛОЖЕНИЕ', 'APPLICATION',
        ['data', 'appearance', 'about']),
    ],
  );

  Widget _mobileProfile() => StreamBuilder<UserSettings>(
    stream: DatabaseService.instance.userSettingsStream,
    initialData: DatabaseService.instance.settings,
    builder: (context, snapshot) {
      final scheme = Theme.of(context).colorScheme;
      final name = ProfileServiceExtension.resolveProfileDisplayLabelFor(
        settings: snapshot.data ?? DatabaseService.instance.settings);
      final email = AuthBridge.currentAuthEmail?.trim() ?? '';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Center(child: CircleAvatar(
          radius: 48,
          backgroundColor: scheme.brightness == Brightness.dark
                    ? scheme.surfaceContainerHighest : kCategoryNeutral[100],
          child: Text(name.isEmpty ? '•' : name.substring(0, 1).toUpperCase(),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: scheme.brightness == Brightness.dark
                    ? scheme.onSurface : kCategoryNeutral[800],
                fontWeight: FontWeight.w500)),
        )),
        const SizedBox(height: 14),
        Text(name.isEmpty ? tr('Мой профиль', 'My profile') : name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600)),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(email, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _mobileProfileAction(
            tr('Изменить', 'Edit'), Icons.edit_rounded,
            kNordicWork, LifeOsMenuAction.account)),
          const SizedBox(width: 9),
          Expanded(child: _mobileProfileAction(
            tr('Защита', 'Security'), Icons.shield_outlined,
            kNordicHealth, LifeOsMenuAction.accountSecurity)),
        ]),
        const SizedBox(height: 24),
        const AccountSecuritySection(showPeopleEntry: false, showIdentity: false),
      ]);
    },
  );

  Widget _mobileProfileAction(String label, IconData icon,
      MaterialColor family, LifeOsMenuAction action) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(17),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _open(action),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Theme.of(context).brightness == Brightness.dark
              ? family[200] : family[600], size: 23),
          const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );

  Widget _mobilePinnedHeader() {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    // The same canonical frosted edge as the bottom shell navigation.
    // Keep header geometry and title position fixed. Only extend the
    // noninteractive feather below its layout box to avoid a visible cutoff.
    return SizedBox(height: topInset + 114, child: Stack(
      clipBehavior: Clip.none,
      children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: topInset + 162,
        child: AppGlassEdgeFade(
          edge: AppGlassEdge.top,
          surfaceColor: scheme.surfaceContainerLowest,
          blurSigma: 16,
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
        child: Row(children: [
          if (_mobileDetailOpen)
            Expanded(child: AppSettingsBackHeader(
              parentLabel: _planningDefaultTimesOpen
                ? tr('Назад к планированию', 'Back to Planning')
                : tr('Назад к настройкам', 'Back to settings'),
              title: _planningDefaultTimesOpen
                ? t(currentLocale.value, 'plan_default_times_title')
                : (_ru ? selected.ru : selected.en),
              onBack: _backToMobileSettings,
            ))
          else
            Expanded(child: Text(tr('Настройки', 'Settings'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 30, fontWeight: FontWeight.w600))),
        ]),
      ),
    ]));
  }

  Widget _mobileDetails() => Column(
    key: ValueKey('mobile-settings-$_tab'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [if (_tab == 'profile') _mobileProfile() else _tabContent()],
  );

  Widget _mobileSettings() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.07, 0),
          end: Offset.zero).animate(animation),
        child: child,
      ),
    ),
    child: _mobileDetailOpen ? _mobileDetails() : _mobileHome(),
  );

  Widget _tabContent() => switch (_tab) {
    'profile' => _profile(),
    'planning' => _planning(),
    'notes' => _notes(),
    'categories' => _categories(),
    'notifications' => _notifications(),
    'data' => _data(),
    'appearance' => _appearance(),
    'about' => _about(),
    _ => _profile(),
  };

  Widget _tabNavigation(bool desktop) {
    if (!desktop) return const SizedBox.shrink();
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        for (final tab in _tabs)
          ChoiceChip(
            label: Text(_ru ? tab.ru : tab.en),
            avatar: Icon(AppMenuIcons.icon(tab.icon), size: 18,
                color: Theme.of(context).brightness == Brightness.dark
                    ? tab.family[200] : tab.family[700]),
            selected: _tab == tab.id,
            showCheckmark: false,
            selectedColor: Theme.of(context).brightness == Brightness.dark
                ? Color.alphaBlend(tab.family[500]!.withValues(alpha: 0.18),
                    Theme.of(context).colorScheme.surfaceContainerHigh)
                : tab.family[100],
            side: BorderSide(color: _tab == tab.id
                ? (Theme.of(context).brightness == Brightness.dark
                    ? tab.family[400]! : tab.family[500]!)
                : Theme.of(context).colorScheme.outlineVariant),
            onSelected: (_) => _choose(tab.id),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    final content = Theme(
      data: settingsNeutralTheme(context),
      child: Builder(builder: (context) => desktop
          ? AppSettingsPageBody(children: [
              if (_planningDefaultTimesOpen)
                AppSettingsBackHeader(
                  parentLabel: tr('Назад к планированию', 'Back to Planning'),
                  title: t(currentLocale.value, 'plan_default_times_title'),
                  onBack: () => setState(() => _planningDefaultTimesOpen = false),
                )
              else ...[
                Text(tr('Настройки', 'Settings'),
                  style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 16),
                _tabNavigation(desktop),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _tabContent(),
                ),
              ),
            ])
          : _MobileSettingsMotion(
              header: _mobilePinnedHeader(),
              child: KeyedSubtree(
                key: ValueKey(_mobileDetailOpen ? 'detail-$_tab' : 'settings-home'),
                child: AppSettingsPageBody(transparentBackground: true, children: [
                  // Compact first-screen spacing. The approved glass feather
                  // and pinned heading live in a separate overlay above this
                  // scrolling content; neither needs any visual adjustment.
                  SizedBox(height: 56 + MediaQuery.viewPaddingOf(context).top),
                  _mobileSettings(),
                  // Scroll the final item above the floating glass navigation.
                  const SizedBox(height: 20),
                ]),
              ),
            )),
    );
    final activeTab = widget.activeTab;
    if (activeTab == null || desktop) return content;
    return ValueListenableBuilder<int>(
      valueListenable: activeTab,
      builder: (context, currentTab, _) {
        final shouldReturnToIndex =
            currentTab == widget.shellTabIndex && _mobileDetailOpen;
        return PopScope(
          canPop: !shouldReturnToIndex,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && shouldReturnToIndex) _backToMobileSettings();
          },
          child: content,
        );
      },
    );
  }
}

/// Continuous scroll surface behind the pinned top glass and bottom nav.
class _MobileSettingsMotion extends StatelessWidget {
  const _MobileSettingsMotion({required this.child, required this.header});
  final Widget child;
  final Widget header;

  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest)),
    Positioned.fill(child: ScrollConfiguration(
      behavior: MediaQuery.disableAnimationsOf(context)
          ? ScrollConfiguration.of(context)
          : const _MobileSettingsBounceBehavior(),
      child: child,
    )),
    Positioned(top: 0, left: 0, right: 0, child: header),
  ]);
}

class _MobileSettingsBounceBehavior extends MaterialScrollBehavior {
  const _MobileSettingsBounceBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
