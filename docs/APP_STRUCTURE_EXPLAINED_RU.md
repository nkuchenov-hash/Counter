# Life OS — где что лежит (для Ника)

Короткий практический гид. Полная карта — в `docs/APP_STRUCTURE.md`. Схема БД — в `docs/DATA_MAP.md`.

---

## Где экраны

Все вкладки собирает **`lib/shell/life_os_dashboard.dart`** (тонкий вход — **`lib/app_shell.dart`**). Нижняя навигация:

| Вкладка | Файл | Главный виджет |
| :--- | :--- | :--- |
| Timeline (хронология) | `lib/features/timeline/timeline_view.dart` | `TimelinePage` |
| Plans (планы) | `lib/features/planning/planning_view.dart` | `PlanningSwipeWrapper` → `PlanningPage` |
| Calendar (календарь) | `lib/features/calendar/calendar_view.dart` | `CalendarPage` |
| Lists (списки) | `lib/features/lists/lists_view.dart` | `ListsPage` |
| More (ещё) | `lib/shell/shell_more_menu.dart` (part) | Категории, профиль, Component Lab (админ) |

**Статистика** — внутри Timeline: `lib/features/stats/stats_view.dart`.

**Вход / авторизация** — `lib/features/auth/auth_view.dart` (показывает `main.dart` до загрузки данных).

**Wear OS** — `lib/features/wear/wear_timer_screen.dart`.

**Общие шторки редактирования** (запись, план, список) — `lib/features/shared/shared_widgets.dart` → `ActivityDetailSheet`.

---

## Где данные / PocketBase

**Мозг приложения** — `lib/data/database_service.dart`. Только он ходит в сеть.

| Что | Файл |
| :--- | :--- |
| Загрузка при старте, сессия | `lib/data/db_core.dart` |
| Записи (старт/стоп/таймлайн) | `lib/data/record_service.dart` |
| Планы и списки (координатор) | `lib/data/plan_service.dart` |
| Планы — Time View projection, recurrence, cascade, tags, cache, outbox | `lib/data/plans/*.dart` *(part of database_service)* |
| Категории | `lib/data/category_service.dart` |
| Профиль, теги, часовой пояс | `lib/data/profile_service.dart` |
| URL и имена коллекций PB | `lib/data/pb_config.dart` |
| Офлайн-очередь | `lib/data/local_sync/` |
| Модели данных | `lib/data/models/` + `lib/data/models.dart` |

**Серверные хуки** (не Dart): папка `pb_hooks/` в корне репо — копируется на VPS рядом с PocketBase.

**Поля и имена в БД** — всегда сверяй с `docs/DATA_MAP.md`.

---

## Где UI-компоненты

**Переиспользуемые виджеты** — `lib/core/widgets/`:

- Кнопки: `app_button.dart`, `app_icon_button.dart`
- Карточка плана: `plan_time_task_card/` (пакет), `plan_card.dart`
- Чипы тегов/категорий: `chip_component.dart`
- Шапка с датой: `global_app_header.dart`
- Выбор даты/времени: `omni_date_time_picker_dialog.dart`
- Пустое/ошибка/загрузка: `app_state_views.dart`, `app_loading.dart`

**Component Lab** (только админ) — `lib/features/dev/component_lab_view.dart`.

Правила имён и запрет «своих кнопок» — `docs/DESIGN_SYSTEM.md`.

---

## Где стили

| Что | Файл |
| :--- | :--- |
| Тема Material | `lib/core/theme.dart` |
| Цвета | `lib/core/app_colors.dart` |
| Палитра категорий | `lib/core/category_color_palette.dart` |
| Контраст тегов | `lib/core/tag_contrast.dart` |
| Константы UI | `lib/core/constants.dart` |

Экраны берут цвета через `Theme.of(context)`, не хардкодят hex.

---

## Где переводы

| Что | Файл |
| :--- | :--- |
| **Английский (SSOT)** | `lib/l10n/langs/en.dart` → `kEnL10n` |
| **Русский (SSOT)** | `lib/l10n/langs/ru.dart` → `kRuL10n` |
| Сборка всех языков + `t()` | `lib/l10n/dictionary.dart` |
| Список языков в настройках | `lib/l10n/app_locales.dart` |
| Остальные языки | `lib/l10n/langs/*.dart` (дополняют EN) |

**Как добавить строку:** ключ в `en.dart` и `ru.dart`, затем `t(currentLocale.value, 'ключ')` в UI.

Синхронизация локалей (скрипт): `scripts/sync_locales.dart`.

---

## Где deploy-скрипты

| Команда | Что делает |
| :--- | :--- |
| `.\update.ps1` | Главная команда деплоя с корня репо |
| `.\scripts\manual\td.ps1` | analyze + build web + commit + push |
| `.github/workflows/deploy.yml` | CI: push в `main` → GitHub Pages |

Подробности: `docs/DEPLOY.md`.  
Живой сайт: https://nkuchenov-hash.github.io/Counter/

---

## Что открыть при изменении

| Задача | Открыть |
| :--- | :--- |
| **Карточка плана / списка** | `lib/core/widgets/plan_time_task_card/` (пакет, incl. `plan_card_tags.dart`), `lib/core/widgets/plan_card.dart` |
| **Time View (режим времени на Plans)** | `lib/features/planning/plan_time_view_layout.dart`, `lib/features/planning/planning_view.dart`, настройка «Длительность дня» — `planning_day_start_prefs.dart` + `lib/core/time/plan_time_visible_window.dart` |
| **Вкладка Plans** | `lib/features/planning/planning_view.dart` |
| **Timeline** | `lib/features/timeline/timeline_view.dart`, `timeline_header_controls.dart` |
| **Lists** | `lib/features/lists/lists_view.dart`, `lists_filters.dart`, `lists_bulk_actions.dart`, `lists_inline_add.dart`, `lists_empty_state.dart` |
| **Calendar** | `lib/features/calendar/calendar_view.dart` |
| **Категории** | `lib/features/categories/category_list_view.dart`, `create_category_dialog.dart` |
| **Профиль** | `lib/features/profile/profile_view.dart` |
| **Теги (менеджер, настройки)** | `tag_manager_page.dart`, `tag_settings_view.dart`, `tag_default_duration_settings_view.dart` |
| **Язык / локаль** | `lib/l10n/langs/en.dart`, `ru.dart`, `dictionary.dart` |
| **Поля БД / API** | `docs/DATA_MAP.md`, затем нужный `*_service.dart` в `lib/data/` |
| **Деплой** | `update.ps1`, `docs/DEPLOY.md` |
| **Тесты** | `test/` — например `smart_input_parser_test.dart`, `plan_time_view_layout_test.dart` |
| **Навигация / FAB / голос** | `lib/shell/life_os_dashboard.dart`, `lib/shell/shell_voice_routing.dart` |
| **Desktop Price Reporter (Windows)** | `lib/features/shared/desktop_voice_widget.dart`, `lib/core/services/desktop_voice_*.dart`, `lib/data/voice_command_parser.dart`, настройки — `lib/features/profile/desktop_voice_settings_section.dart` |
| **Часовой пояс профиля** | `lib/core/widgets/timezone_quick_picker.dart`, каталог — `lib/core/time/profile_timezone_catalog.dart`, иконки — `lib/core/widgets/app_timezone_icon.dart`, сохранение — `lib/data/profile_service.dart` (`updateTimeZone`) |
| **Старт приложения** | `lib/main.dart` |
| **Поведение тапов/сохранения** | `docs/UX_CONTRACT.md` |

---

## Три правила, которые ломают всё

1. **UI не пишет в PocketBase напрямую** — только через `DatabaseService`.
2. **После тапа UI обновляется сразу** (<100 мс), сеть — в фоне.
3. **Новые кнопки** — `AppButton` / `AppIconButton` из `core/widgets/`, не сырые `ElevatedButton`.

Проверка структуры: `.\scripts\audit\architecture_guard.ps1 -Strict`
