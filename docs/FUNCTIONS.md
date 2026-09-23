# LIFE OS — Энциклопедия функций

Каноническое описание **продуктовых функций LIFE OS** для AI-разработчиков и сопровождающих проект. Этот документ отвечает на вопрос **«что функция должна делать и где её искать»**. Физическая карта файлов остаётся в `docs/APP_STRUCTURE.md` / `docs/APP_STRUCTURE_DETAILED.md`, архитектурные законы — в `docs/ARCHITECTURE.md`, UX-инварианты — в `docs/UX_CONTRACT.md`, схема данных — в `docs/DATA_MAP.md` / `docs/POCKETBASE_MANIFEST.md`.

`FUNCTIONS.md` описывает не каждый private Dart-метод, а **каждую пользовательскую или системную возможность продукта**, которая имеет самостоятельное поведение. Если новая возможность заметна пользователю, влияет на данные, синхронизацию, расписание, интеграции или платформенный companion, у неё должен появиться стабильный function ID здесь.

## Как пользоваться энциклопедией

Перед изменением поведения AI-разработчик обязан:

1. найти соответствующий function ID;
2. проверить указанные code anchors и governing docs;
3. сравнить документацию с реальным кодом;
4. изменить код и этот раздел в одном наборе изменений, если контракт функции меняется;
5. если код и документ расходятся — считать это дефектом, а не молча выбирать одну версию;
6. новую функцию добавлять новым стабильным ID, а не прятать внутри описания другой функции.

**Статусы:** `реализовано`, `платформенно`, `admin-only`, `внутренняя функция`, `ограничено`. Ограничения должны быть записаны явно.

---

## Реестр функций

| ID | Функция | Статус | Основной владелец |
| :--- | :--- | :--- | :--- |
| `system.auth` | Вход, регистрация, OAuth, восстановление доступа | реализовано | Auth |
| `system.shell_navigation` | Навигация между Timeline / Plans / Calendar / Lists / Categories / Profile / Paths | реализовано | Shell |
| `system.optimistic_ui` | Мгновенное локальное отражение действий | реализовано | Brain + Shell |
| `system.offline_sync` | Offline queue, retry, auth-pause, global sync state | реализовано | Brain |
| `system.realtime_sync` | Realtime обновления PocketBase | реализовано | Brain |
| `system.timezones` | UTC storage + profile wall-clock | реализовано | Shared time + Brain |
| `system.localization` | RU/EN и частичные дополнительные локали | реализовано | l10n |
| `timeline.records` | Создание, старт, стоп, редактирование, удаление записей | реализовано | Timeline + Records Brain |
| `timeline.singleton_timer` | Только одна основная активная запись | реализовано | Records Brain |
| `timeline.history` | Непрерывная история и навигация по дням | реализовано | Timeline |
| `timeline.morning_start` | Утренний check-in и первый record дня | реализовано | Timeline |
| `timeline.unfilled_time` | Поиск незаполненных промежутков и их заполнение | реализовано | Records + Timeline |
| `timeline.sleep_details` | Отображение сна и деталей стадий | реализовано | Timeline + Health |
| `stats.overview` | Визуальная статистика времени | реализовано | Stats |
| `planning.crud` | Создание, редактирование, выполнение, удаление планов | реализовано | Planning + Plans Brain |
| `planning.time_mode` | Временная сетка, drag, resize, now-line | реализовано | Planning Time View |
| `planning.auto_schedule` | Анти-overlap и последовательное размещение | реализовано | Plans Brain |
| `planning.bulk` | Bulk selection и массовое изменение | реализовано | Planning |
| `planning.sort_group` | Сортировка и группировка по категориям/тегам | реализовано | Planning |
| `planning.recurring_plans` | Повторяющиеся планы и split future | реализовано | Plans Brain |
| `planning.reminders` | Напоминания планов | реализовано | Notifications + Plans |
| `planning.record_link` | Связь plan → фактический record | реализовано | Brain + Shell |
| `lists.backlog` | Несрочные / несcheduled планы в Lists | реализовано | Lists + Plans Brain |
| `lists.filters` | Фильтры категорий и тегов | реализовано | Lists |
| `lists.bulk` | Bulk actions в Lists | реализовано | Lists |
| `lists.export` | Копирование видимого списка текстом | реализовано | Lists |
| `calendar.browse` | Month / week / focused day calendar | реализовано | Calendar |
| `calendar.integrations` | Microsoft/Google calendar connection and sync | реализовано | Profile + server integration |
| `taxonomy.categories` | Иерархия категорий, picker, create/edit | реализовано | Categories |
| `taxonomy.tags` | Plan/List tags, display mode, default duration | реализовано | Profile + Brain |
| `notes.library` | Библиотека Notes в Lists | реализовано | Notes |
| `notes.editor` | Блочный редактор заметок | реализовано | Notes |
| `notes.media` | Изображения, рисунки, аудио, таблицы, ссылки | реализовано | Notes |
| `paths.domain` | Paths, stages, actions, revisions, progress | реализовано | Paths |
| `paths.planner_bridge` | Явный Path → Planner boundary | реализовано | Paths + Plans Brain |
| `voice.generic_input` | Голосовой ввод по активному разделу | реализовано | Shared Voice + Shell |
| `voice.desktop` | Desktop hotkey / STT / overlay / correction | платформенно | Shared Voice + Voice UI |
| `profile.settings` | Account, security, notifications, timezone, preferences | реализовано | Profile / Settings |
| `health.sleep_sync` | Health Connect + server cloud sleep reconciliation | реализовано | Health Brain + server |
| `people.people` | Люди и карточки контактов | реализовано | People |
| `people.circles` | Circles many-to-many | реализовано | People |
| `people.sources` | Device/cloud source review, Add/Link/Ignore/Block | реализовано | People |
| `browser_extension.companion` | Current record, new record, open web app | платформенно | Browser extension + Shell bridge |
| `wear.companion` | Wear OS timer companion | платформенно | Wear |
| `dev.component_lab` | Каталог канонических UI компонентов | admin-only | Dev / Design System |

---

## 1. Системные функции

### `system.auth` — аутентификация и сессия

**Статус:** реализовано  
**Code anchors:** `lib/features/auth/`, `lib/data/auth_bridge.dart`, `lib/data/db_core.dart`

- Поддерживаются вход, регистрация, OAuth-сессия и password reset.
- PocketBase auth record является текущей identity; invalid session блокирует сетевые записи.
- После успешного восстановления сессии Brain загружает профиль и пользовательские данные.
- Auth-пауза offline queue снимается только после валидной сессии.
- Не раскрывать backend/internal данные в пользовательских ошибках восстановления доступа.

### `system.shell_navigation` — структура приложения

**Статус:** реализовано  
**Code anchors:** `lib/app/shell/`, `lib/main.dart`

- Канонические destinations: Timeline, Plans, Calendar, Lists, Categories, Profile, Paths.
- Desktop использует side navigation; phone/tablet — компактную нижнюю навигацию и More для вторичных destinations.
- Переход между главными разделами не должен создавать второй shell.
- Горизонтальный swipe внутри Timeline/Planning меняет **дату**, а не основной tab.

### `system.optimistic_ui` — мгновенная реакция

**Статус:** реализовано  
**Governing docs:** `ARCHITECTURE.md`, `UX_CONTRACT.md`

- User-driven record/plan/list mutations сначала меняют local shadow/cache/UI и только потом синхронизируются.
- Цель — видимый результат примерно за 100 ms.
- Нельзя ждать network/PocketBase до визуального ответа.
- Retriable network failure сохраняет локальный результат там, где есть outbox; non-retriable validation/schema failure откатывает один раз и показывает одну ошибку.

### `system.offline_sync` — локальная очередь изменений

**Статус:** реализовано с известными ограничениями  
**Code anchors:** `lib/data/local_sync/`, `lib/data/records/record_outbox_helpers.dart`, `lib/data/plans/plan_outbox_helpers.dart`, `lib/app/shell/shared/offline_sync_status_bar.dart`

- Records: start, stop, edit, delete поддерживают offline queue.
- Plans/Lists: create, update, delete, done-toggle поддерживают offline-first path.
- Очереди сохраняются между перезапусками и flushятся на boot, reconnect, resume, login/session restore и manual retry.
- 401/403 переводит sync в auth-paused; 404 приводит к reconciliation/purge ghost state.
- Global banner показывает pending/sync/error; не создавать per-row sync noise.
- Известные ограничения из roadmap: очереди device-global, часть bulk/recurrence flows может требовать сеть, optimistic overlays не переживают process death до replay.

### `system.realtime_sync` — live обновления

**Статус:** реализовано  
**Code anchors:** `lib/data/records/record_realtime.dart`, `lib/data/realtime/catalog_realtime.dart`, plan/profile realtime paths

- PocketBase realtime обновляет records, categories, tags и profile/catalog state через Brain cache.
- Realtime никогда не должен обходить ownership и optimistic reconciliation.
- Reconnect не должен требовать ручного refresh пользователя.

### `system.timezones` — время и календарный день

**Статус:** реализовано  
**Code anchors:** `lib/shared/time/`, `lib/features/settings/timezone_settings.dart`

- Persisted record/plan instants хранятся в UTC ISO.
- `preferred_timezone` + profile timezone rules определяют wall-clock day, labels, Planning Time View и Stats.
- Durable day keys нельзя строить через `DateTime.now().toLocal()`.
- Date+time edit использует Omni-Picker; date navigation может иметь date-only controls.

### `system.localization` — язык интерфейса

**Статус:** реализовано  
**Code anchors:** `lib/l10n/`

- Canonical full locale sources: `langs/en.dart` и `langs/ru.dart`.
- AR/DE/ES/FR/IT/KO/ZH могут быть частичными и наследовать английский fallback.
- Новые пользовательские строки должны попадать минимум в canonical EN/RU maps.

---

## 2. Timeline и фактическое время

### `timeline.records` — records CRUD

**Статус:** реализовано  
**Code anchors:** `lib/features/timeline/`, `lib/data/records/record_crud.dart`, `record_service.dart`

- Пользователь может создать/запустить record, остановить, открыть edit sheet, изменить и удалить его.
- Timeline card показывает фактический интервал; start/end — реальные события, а не плановое время.
- Edit/delete применяют optimistic behavior по общим законам.
- Category relation нормализуется Brain до PocketBase system ID.

### `timeline.singleton_timer` — один активный primary record

**Статус:** реализовано  
**Code anchors:** `lib/data/records/record_overlap_helpers.dart`, `record_optimistic.dart`

- Запуск нового primary record закрывает другие открытые primary intervals согласно Singleton/Highlander law.
- Active record имеет `end_time == null` и running semantics.
- Server остаётся финальным арбитром overlap cleanup.

### `timeline.history` — история и навигация

**Статус:** реализовано  
**Code anchors:** `timeline_continuous_history.dart`, `timeline_day_page.dart`, `timeline_view.dart`

- Timeline поддерживает continuous history и day pages.
- Горизонтальный swipe переводит на предыдущий/следующий день.
- Already loaded content не заменяется blank loader при фоновом refresh.

### `timeline.morning_start` — старт дня

**Статус:** реализовано  
**Code anchor:** `lib/features/timeline/timeline_morning_start.dart`

- Утренний flow подтверждает сон/начало дня и помогает создать первый Timeline record.
- Он не является отдельным источником истины для sleep sync; sleep ingestion остаётся Health/server domain.

### `timeline.unfilled_time` — незаполненные промежутки

**Статус:** реализовано  
**Code anchors:** `lib/data/records/unfilled_time_gap_policy.dart`, `unfilled_time_gap_service.dart`, `lib/features/timeline/unfilled_time_gap_banner.dart`, `lib/services/unfilled_time_notification_service.dart`

- Brain вычисляет gaps между record intervals.
- Timeline показывает recovery banner и действие заполнения gap.
- Настройки уведомлений принадлежат Settings; OS notifications не должны спамить и учитывают eligibility policy.

### `timeline.sleep_details` — сон в Timeline

**Статус:** реализовано  
**Code anchors:** `lib/features/timeline/timeline_sleep_details.dart`, Health services

- Импортированный sleep отображается как Timeline data и может открывать подробности стадий.
- Sleep source определяется ingest pipeline; UI не выполняет cloud sync самостоятельно.

---

## 3. Stats

### `stats.overview` — статистика времени

**Статус:** реализовано  
**Code anchors:** `lib/features/stats/stats_view.dart`, `stats_visual_overview.dart`, `stats_detail_tree.dart`

- Stats встроен в Timeline и анализирует фактические records.
- Основные представления: waking-day time tree, top-level donut distribution и hourly category timeline.
- День и интервалы должны использовать те же profile-timezone / sleep-boundary правила, что Timeline.

---

## 4. Planning

### `planning.crud` — планы

**Статус:** реализовано  
**Code anchors:** `lib/features/planning/`, `lib/features/shared/planning_task_edit_sheet.dart`, `lib/data/plan_service.dart`

- Создание, редактирование, done-toggle, удаление и reorder планов.
- Save в edit sheet — local commit, а не network gate; explicit Save должен flushить последний draft.
- Изменения title/notes/checklist/category/tags не должны самопроизвольно менять выбранное время.
- Plan stores intent; actual work появляется как Timeline record.

### `planning.time_mode` — временная сетка

**Статус:** реализовано  
**Code anchors:** `lib/features/planning/time_view/`, `lib/core/widgets/plan_time_task_card/`, `lib/shared/time/plan_time_visible_window.dart`

- Scheduled plans размещаются по wall-clock Y scale в profile timezone.
- Поддерживаются body drag, top/bottom resize, checkbox, play, menu и edit tap с раздельными hit zones.
- Минимальная длительность — 10 минут; move/resize snap — 5 минут.
- Touching boundaries допустимы; hour-boundary start должен точно совпадать с hour line.
- Dense hour визуально ограничен; карточки используют duration-responsive density.
- Current-time line находится над cards и не перехватывает pointer.
- Cards вне выбранного wall day/visible range не показываются.

### `planning.auto_schedule` — свободный слот и каскад

**Статус:** реализовано  
**Code anchor:** `lib/data/plans/plan_time_cascade_helpers.dart`

- Новый scheduled plan, пересекающий существующий, переносится вперёд в первый свободный slot, сохраняя duration.
- Create anti-overlap не должен двигать существующие задачи.
- Последовательные auto-planning/cascade rules используют единый Brain policy, а не дублируются в UI.

### `planning.bulk` — массовые операции

**Статус:** реализовано  
**Code anchors:** `bulk_planning_edit_sheet.dart`, planning bulk widgets

- Planning имеет явный select mode и bulk action bar.
- Bulk date/time moves используют общие time picker/rules.
- Selection очищается предсказуемо при выходе.
- Bulk операции не должны блокировать gesture/UI на network.

### `planning.sort_group` — сортировка и группировка

**Статус:** реализовано  
**Code anchors:** `planning_sort_mode.dart`, `planning_list_grouping.dart`, grouped-list widgets

- Список может использовать обычную сортировку и группировку по category/tag modes, которые поддерживает текущий UI.
- Reorder отражается локально сразу; persistence не должна блокировать drag.
- Quick-add tag strip управляет выбором тегов и синхронизирует каталог через Brain.

### `planning.recurring_plans` — повторяющиеся планы

**Статус:** реализовано  
**Code anchors:** `lib/data/plans/plan_recurrence_helpers.dart`, `plan_recurrence_split_helpers.dart`, `lib/data/recurrence_edit_scope.dart`, `lib/features/planning/recurrence_scope_dialog.dart`

#### Хранение и генерация

- Одна PocketBase row `plans` с `rrule` представляет серию.
- Обычные occurrences создаются JIT для нужного диапазона и не хранятся отдельными rows.
- Virtual ID: `virt-{seriesPocketId}-{YYYY-MM-DD}`; он никогда не используется как PocketBase REST ID.
- `exception_dates` подавляет обычную генерацию конкретных дат.
- Отдельно изменённое/завершённое occurrence материализуется реальной row, связанной через `parent_plan_id` + `recurrence_instance_date_key`.

#### Scope

Пользователю доступны ровно два варианта:

1. **Только это событие** — изменяется/удаляется один occurrence.
2. **Это и все следующие события** — серия разделяется на выбранной дате; прошлое остаётся неизменным.

- User-facing «Вся серия» отсутствует.
- Legacy `entireSeries` — только compatibility value и канонизируется в `thisAndFuture`.
- Future edit создаёт новую series, historical series получает `UNTIL` перед boundary.
- Для `COUNT` будущая часть получает оставшееся число occurrences.
- Materialized future exceptions перепривязываются к новой series; прошлые остаются у historical series.
- Scope спрашивается при любом поле, включая простое переименование.
- Закрытие scope dialog отменяет recurring mutation.

### `planning.reminders` — напоминания планов

**Статус:** реализовано  
**Code anchors:** `lib/services/notification_service.dart`, `plan_alarm_schedule.dart`, planning edit sheet

- Plan может иметь reminder offset относительно start time.
- Schedule переводится из profile wall time в OS notification specification.
- Reminder dedupe и OS limits централизованы в service layer.

### `planning.record_link` — план ↔ факт

**Статус:** реализовано  
**Code anchors:** `lib/app/shell/shared/shell_task_actions.dart`, `lib/data/plans/plan_record_link_policy.dart`/related Brain paths, `records.source_plan_id`

- Timeline record может ссылаться на plan через `source_plan_id`.
- UI может предлагать связать новый record с подходящим plan согласно Brain policy/preferences.
- Relation всегда использует PocketBase plan system ID и ownership пользователя.

---

## 5. Lists / Backlog

### `lists.backlog` — несscheduled задачи

**Статус:** реализовано  
**Code anchors:** `lib/features/lists/`, `DatabaseService.fetchBacklogPlans`

- Lists использует те же `plans`, но показывает backlog/unscheduled items.
- List item можно создать, редактировать, завершить и удалить через общие plan/list Brain paths.
- Lists card не имеет Planning-style play action.

### `lists.filters` — фильтрация

**Статус:** реализовано  
**Code anchors:** `lists_filters.dart`, `category_filter_tree_field.dart`

- Фильтрация поддерживает categories и list-domain tags.
- Active filter/chip остаётся явно выбранным; current implementation перемещает active chip к началу strip.
- Lists-only «All categories» tree field принадлежит Lists, а не global category manager.

### `lists.bulk` — массовые действия

**Статус:** реализовано  
**Code anchors:** `lists_bulk_actions.dart`, `lists_view.dart`

- Есть select mode, selected state и bulk action bar.
- Bulk UI не должен перекрывать critical row controls без дополнительного bottom padding.

### `lists.export` — экспорт видимого списка

**Статус:** реализовано  
**Code anchor:** `lists_export.dart`

- Экспортирует **текущий видимый/отфильтрованный список** как нумерованный plain text в clipboard.
- Не открывает file/share workflow.

---

## 6. Calendar

### `calendar.browse` — просмотр календаря

**Статус:** реализовано  
**Code anchors:** `lib/features/calendar/calendar_view.dart`, `calendar_month_grid.dart`, `calendar_week_grid.dart`, `calendar_day_panel.dart`, `calendar_day_events.dart`

- Calendar имеет month/week grids и focused-day panel.
- Он отображает app scheduling data по выбранному дню, не создавая отдельную конкурирующую модель планов.
- Day/date projection следует profile timezone.

### `calendar.integrations` — внешние календари

**Статус:** реализовано  
**Code anchors:** `lib/features/profile/calendar_integrations/`, server-owned calendar integration routes/schema

- Поддерживаются Microsoft и Google connections.
- Пользователь выбирает calendars для sync и может задавать per-calendar fallback category.
- Credentials/tokens остаются server-owned; Flutter работает через app-owned integration API.
- Imported occurrences используют documented external provenance fields и не должны дублироваться.

---

## 7. Categories и Tags

### `taxonomy.categories` — категории

**Статус:** реализовано  
**Code anchors:** `lib/features/settings/categories/`, `lib/shared/categories/`, `lib/data/categories/`

- Категории образуют иерархию и используются Timeline/Planning/Lists/Stats.
- Manager поддерживает browse/create/edit/appearance.
- Picker поддерживает selection, search, root create, child create и folder-scoped create actions.
- Create всегда получает explicit parent; нельзя вычислять parent по выбранной строке/поиску/имени.
- После successful create picker refreshes Brain catalog и выбирает новую category через тот же callback, что обычный tap.
- Record PocketBase payload использует 15-char category system ID в relation fields.
- Category может иметь default plan time/timezone для новых scheduled plans.

### `taxonomy.tags` — теги

**Статус:** реализовано  
**Code anchors:** `lib/data/profile/tag_catalog.dart`, `lib/features/profile/tag_manager_page.dart`, `tag_settings_hub.dart`, `tag_default_duration_settings_view.dart`, `lib/core/widgets/chip_component.dart`

- Есть plan-domain и list-domain tag catalogs.
- Tag manager позволяет create/edit/delete через Brain catalog API.
- Profile `tag_display_mode` управляет визуальным видом тегов.
- `default_plan_duration_minutes` может задавать default duration для auto-scheduled plan с этим tag.
- Tags many-to-many хранятся relation-ами и должны оставаться reactive без ручного refresh.

---

## 8. Notes

### `notes.library` — библиотека заметок

**Статус:** реализовано  
**Code anchors:** `lib/features/notes/widgets/notes_library_body.dart`, `notes_library_production_shell.dart`, `note_card.dart`

- Notes library находится в Lists surface и поддерживает grid/list presentation текущей production shell.
- Note card показывает preview и состояния pin/done, если они есть в документе.
- Создание новой note открывает production editor, а не отдельный legacy editor.

### `notes.editor` — блочный редактор

**Статус:** реализовано  
**Code anchors:** `note_editor_page.dart`, `notes_editor_document_controller.dart`, `note_editor_block_widgets.dart`, `notes_editor_tools.dart`, `docs/NOTES_EDITOR_CONTRACT.md`

- Документ состоит из stable-ID blocks.
- Поддерживаются Body, H1/H2/H3, list, checklist, quote, divider, table, link/reference и media blocks.
- Blocks можно select/convert/reorder согласно document controller.
- `ReorderableListView` остаётся единственным vertical scroll owner; top-level reorder widgets сохраняют stable `ValueKey(block.id)`.
- Production Notes changes обязаны соблюдать `NOTES_EDITOR_CONTRACT.md`.

### `notes.media` — изображение, рисунок, аудио и структурные блоки

**Статус:** реализовано  
**Code anchors:** `notes_image_tools.dart`, `drawing_canvas_page.dart`, `notes_audio_controller.dart`, `notes_component_media_blocks.dart`, `notes_component_structural_blocks.dart`

- Image flow: file/gallery/camera where platform allows, crop, caption, clipboard/save helpers.
- Drawing block открывает full-screen canvas и возвращает PNG data URL.
- Audio flow поддерживает record, WAV/playback и transcript modal orchestration.
- Table/link/reference UI принадлежит Notes tools и не создаёт отдельную document model.

---

## 9. Paths

### `paths.domain` — проектный путь

**Статус:** реализовано  
**Code anchors:** `lib/features/paths/`, `lib/data/paths/`

- Path — project strategy/execution structure: goal, ordered stages, completion criteria, actions и progress.
- Durable identity хранится в `paths`; revisions — append-only `path_revisions`.
- `active_revision_link` — единственная executable revision relation.
- Открытие Paths **read-only по побочным эффектам**: нельзя автоматически migrate/create/publish/schedule.
- Edit active Path создаёт новую revision и только затем переключает active pointer.
- UI/domain project-agnostic; нельзя hard-code конкретные проекты.

### `paths.planner_bridge` — передача actions в Planner

**Статус:** реализовано как единственная допустимая граница  
**Code anchor:** `lib/data/plans/path_planner_bridge.dart`

- Path отвечает «что/зачем», Planner — «когда».
- Вся executable projection идёт через tuple `path_id + revision_id + action_id`.
- Draft/review/unreferenced revisions не должны попадать в расписание.
- Planning generation является explicit action, не side effect открытия Path.

---

## 10. Voice

### `voice.generic_input` — голосовой ввод

**Статус:** реализовано  
**Code anchors:** `lib/shared/voice/`, `lib/app/shell/shared/shell_voice_input.dart`, `lib/data/voice/`

- Phone/web/desktop/Wear activation paths должны сходиться к одной command semantics layer.
- Generic VoiceInputSheet маршрутизирует намерение по активному destination: Timeline record, Planning task или Backlog task.
- Transcript normalization/domain resolution/command execution находятся в Brain, не в UI.

### `voice.desktop` — Desktop Voice

**Статус:** платформенно, Windows-focused  
**Code anchors:** `lib/shared/voice/platforms/desktop/`, `lib/features/voice/`, `lib/features/settings/voice/`, shell voice routing/integration

- Global/in-app hotkey запускает capture session.
- STT orchestrator выбирает local/helper/cloud/fallback path согласно policy.
- Overlay/capsule показывает capture/recognition/confirmation state.
- Correction flow позволяет исправить recognition до commit.
- Voice settings управляют mic/hotkey/engine и diagnostics.
- Desktop Voice не является отдельной системой команд: после transcript используется общий Brain command path.

---

## 11. Profile и Settings

### `profile.settings` — пользовательские настройки

**Статус:** реализовано  
**Code anchors:** `lib/features/profile/`, `lib/features/settings/`, profile Brain modules

В Settings/Profile находятся:

- account identity и logout;
- password reset / security / biometric controls;
- notification permission/settings;
- profile timezone;
- tag settings;
- category manager;
- Voice settings;
- health/sleep integration settings;
- unfilled-time notification settings;
- calendar integrations;
- People.

Profile settings, которые влияют на domain behavior, должны сохраняться через Brain и отражаться локально без обязательного полного reload.

---

## 12. Health / Sleep

### `health.sleep_sync` — синхронизация сна

**Статус:** реализовано  
**Code anchors:** `lib/data/health/`, `lib/services/health_connect/`, `lib/features/settings/health/`, `pb_hooks/sleep_sync.pb.js`, `docs/SERVER_SLEEP_SYNC_DEPLOY.md`

- **Server-owned primary production source:** Xiaomi Health cloud.
- Server sync должен работать при закрытых клиентах; отсутствие сна за current profile-local day запускает self-heal/retry policy независимо от открытия Flutter app.
- Xiaomi может менять границы одной ночи; сильные overlaps дедуплицируются, отдельные naps сохраняются.
- Device Health Connect — foreground/device source, а не замена server correctness.
- Flutter foreground reconcile может ускорить обновление, но не является единственным условием появления sleep data.
- Imported sleep может закрывать preceding root record на boundary сна согласно server law.
- UI settings отвечает только за connection/status/actions; credentials не выводятся в client.

---

## 13. People

### `people.people` — люди

**Статус:** реализовано  
**Code anchors:** `lib/data/people/people_service.dart`, `lib/features/settings/people/`

- Person поддерживает photo, email, phone, relationship, birthday, reminders, circles и notes.
- People находится в Settings → Account → People, не является primary tab.
- Visible Person создаётся только явным пользовательским действием или прямым созданием, а не автоматически из source index.

### `people.circles` — круги

**Статус:** реализовано

- Circles — many-to-many grouping People.
- Circles не являются task Categories и не должны использовать category tree semantics.

### `people.sources` — источники контактов

**Статус:** реализовано  
**Code anchors:** `people_device_contacts_bridge.dart`, `people_integration_service.dart`, `people_sources_section.dart`

- Device address book импортируется только по явному действию и после OS permission; startup scan запрещён.
- Cloud/source contacts остаются hidden review index.
- Явные действия: **Add, Link, Ignore, Block**.
- Ignore/Block сохраняются после будущих sync.
- Поддерживаемые server source integrations документированы для Google/Microsoft/VK/Facebook; клиент не хранит provider credentials.
- Birthday reminder reconciliation не должно отменять plan reminders и наоборот.

---

## 14. Companion surfaces

### `browser_extension.companion` — расширение браузера

**Статус:** платформенно  
**Code anchors:** `browser_extension/`, `lib/app/shell/shared/shell_browser_extension.dart`

Popup имеет фиксированный порядок:

1. **Current record** — canonical active record, category path/accent, local elapsed timer, Stop.
2. **New record** — старт реального Timeline record через canonical Brain `startTimer`/Highlander path.
3. **Open LIFE OS** — быстрый переход в web app.

- Extension не хранит PocketBase credentials и не пишет в PocketBase напрямую.
- Команды идут через authenticated LIFE OS web bridge после normal auth/profile bootstrap.
- Request IDs дедуплицируются.
- Browser-local snapshot — только render cache; popup всегда запрашивает fresh canonical state.

### `wear.companion` — Wear OS

**Статус:** платформенно  
**Code anchors:** `lib/features/wear/`

- Wear предоставляет timer-oriented companion UI и phone/watch bridge.
- Wear bootstrap специально облегчён; необязательные heavyweight операции не должны блокировать timer interaction.
- Wear использует те же record semantics, а не отдельную модель времени.

---

## 15. Developer-only

### `dev.component_lab` — Component Lab

**Статус:** admin-only  
**Code anchors:** `lib/features/dev/`, `docs/DESIGN_SYSTEM.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`

- Component Lab показывает canonical UI components и mock states для design-system work.
- Доступен только admin profile.
- Не должен писать production user data/PocketBase и не является пользовательской функцией приложения.

---

## 16. Обязательная синхронизация документации

При изменении функции нужно обновить **в том же PR**:

- этот `docs/FUNCTIONS.md` — если меняется продуктовый контракт, ownership, status или limitation;
- `docs/USER_GUIDE.md` — если меняется видимое пользователю поведение;
- `docs/UX_CONTRACT.md` — если меняется общий interaction law;
- `docs/ARCHITECTURE.md` — если меняется системный invariant/data flow;
- `docs/DATA_MAP.md` / `docs/POCKETBASE_MANIFEST.md` — если меняется schema/storage;
- `docs/APP_STRUCTURE.md` + generated detailed structure — если добавляются/переезжают файлы/ownership;
- `AGENT_NAVIGATION.md` — если меняется canonical entry point/symbol;
- `CHANGELOG.md` — для shipped behavior.

### Coverage law

Любая новая production capability должна получить function ID **до merge**. Проверка полноты идёт по четырём слоям:

1. все primary shell destinations;
2. все secondary Settings/Profile domains;
3. все cross-cutting system capabilities, влияющие на данные или UX;
4. все companion/platform surfaces.

Если capability существует в коде, но отсутствует в этом реестре, documentation coverage считается неполной.
