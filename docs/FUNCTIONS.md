# LIFE OS — Энциклопедия функций

Канонический реестр поведения LIFE OS для AI-разработчиков и сопровождающих проект. Источники истины: реальный код + `ARCHITECTURE.md` + `APP_STRUCTURE.md` + `DATA_MAP.md` + `POCKETBASE_MANIFEST.md` + `UX_CONTRACT.md`. Пользовательское объяснение — `USER_GUIDE.md`. Расхождение документации и кода считается дефектом.

## Карта функций

| ID | Функция | Владелец | Основной код | Статус |
|---|---|---|---|---|
| `timeline.records` | Записи времени: start/stop/edit/delete | Timeline / Brain | `lib/data/records/record_crud.dart`, `lib/data/record_service.dart` | реализовано |
| `timeline.highlander` | Единственная активная запись, overlap/reconcile | Brain | `lib/data/records/record_overlap_helpers.dart`, `record_optimistic.dart` | реализовано |
| `timeline.realtime` | Realtime обновления записей | Brain | `lib/data/records/record_realtime.dart` | реализовано |
| `timeline.unfilled_time` | Поиск и заполнение незаписанных промежутков | Timeline / Brain | `lib/data/records/unfilled_time_gap_policy.dart`, `unfilled_time_gap_service.dart` | реализовано |
| `planning.plans` | Создание/редактирование/удаление планов | Planning / Brain | `lib/data/plan_service.dart` | реализовано |
| `planning.recurring_plans` | Повторяющиеся планы | Planning / Brain | `lib/data/plans/plan_recurrence_helpers.dart`, `plan_recurrence_split_helpers.dart` | реализовано |
| `planning.time_view` | Временная раскладка, snap, cascade, fixed barriers | Planning / Brain | `lib/data/plans/plan_time_cascade_helpers.dart`, `lib/data/time_view_fixed_time_policy.dart` | реализовано; fixed tags локальные |
| `planning.smart_input` | Распознавание времени из текста | Planning / Brain | `lib/data/smart_input_parser.dart` | реализовано |
| `planning.smart_plan` | AI-разбор текста в несколько планов + диктовка | Planning | `lib/features/planning/smart_plan_sheet.dart`, `lib/data/plans/plan_ai_parse_helpers.dart` | реализовано |
| `planning.plan_record_link` | Связь план ↔ фактическая запись | Planning / Brain | `lib/data/plans/plan_record_link_helpers.dart` | реализовано |
| `planning.reminders` | Напоминания планов / OS alarm bridge | Planning / Brain | `lib/data/plans/plan_alarm_helpers.dart` | реализовано |
| `lists.backlog` | Backlog/Lists, фильтры, bulk, export | Lists / Brain | `lib/features/lists/`, `lib/data/plan_service.dart` | реализовано |
| `calendar.view` | Month/week/day представление планов | Calendar | `lib/features/calendar/` | реализовано |
| `categories.tree` | Иерархия, CRUD, поиск, reorder | Categories / Brain | `lib/data/categories/`, `lib/shared/categories/` | реализовано |
| `categories.default_time` | Наследуемое default plan time | Categories / Planning | `lib/data/categories/category_default_time.dart` | реализовано |
| `tags.catalog` | Каталог тегов, CRUD, порядок, привязка | Profile / Brain | `lib/data/profile/tag_catalog.dart` | реализовано |
| `profile.settings` | Профиль, настройки, locale, timezone | Profile / Brain | `lib/data/profile/` | реализовано |
| `stats.analytics` | Агрегации и визуальная статистика | Stats / Brain | `lib/features/stats/`, `lib/data/categories/category_stats.dart` | реализовано |
| `notes.editor` | Блочный редактор, media/audio/drawing | Notes | `lib/features/notes/`, `docs/NOTES_EDITOR_CONTRACT.md` | реализовано |
| `paths.projects` | Paths, immutable revisions, stages/actions | Paths / Brain | `lib/data/paths/`, `lib/features/paths/` | реализовано |
| `paths.planner_bridge` | Единственная граница Path → Planner | Paths / Planning | `lib/data/plans/path_planner_bridge.dart` | реализовано |
| `voice.generic` | Голосовой ввод в Timeline/Planning/Backlog | Voice / Shell | `lib/app/shell/shared/shell_voice_input.dart`, `lib/shared/voice/` | реализовано |
| `voice.desktop` | Desktop GOLOS, hotkey, tray, commands | Voice / Shell | `lib/features/voice/`, `lib/shared/voice/platforms/desktop/`, `shell_voice_routing.dart` | реализовано |
| `health.sleep` | Device/cloud sleep import + reconcile | Health / Brain | `lib/data/health/`, `lib/services/health/` | реализовано по поддерживаемым источникам |
| `calendar.integrations` | Google/Microsoft calendar connection/sync | Integrations | `lib/data/calendar_integrations/`, `docs/CALENDAR_INTEGRATIONS.md` | реализовано по контракту интеграции |
| `offline.sync` | Optimistic mutations + durable outboxes | Brain / Shell | `lib/data/local_sync/`, `lib/data/db_core.dart` | реализовано |
| `browser.extension` | Browser companion start/stop/sync | Shell / browser extension | `lib/app/shell/shared/shell_browser_extension.dart`, `browser_extension/` | реализовано |
| `auth.session` | Login/OAuth/session/bootstrap | Auth / Brain | `lib/features/auth/`, `lib/data/auth_bridge.dart`, `db_core.dart` | реализовано |
| `shell.navigation` | Responsive phone/tablet/desktop navigation | Shell | `lib/app/shell/` | реализовано |
| `wear.compagnion` | Wear entry/UI | Wear | `lib/features/wear/` | реализовано в текущем Wear scope |

## Общие системные инварианты

### Offline-first
Пользовательские мутации сначала отражаются локально. Retriable network/auth failures ставятся в outbox; `SyncManager` и lifecycle инициируют повторную отправку. UI состояния синхронизации читает `OfflineSyncController`. Нельзя добавлять отдельную feature-owned очередь в обход `lib/data/local_sync/`.

### Время и timezone
Постоянные timestamps хранятся в UTC; пользовательская календарная семантика вычисляется в timezone профиля через shared time contracts. Изменение timezone должно репроецировать представление, а не переписывать историю как будто она произошла в другом абсолютном времени.

### Brain ownership
PocketBase/HTTP и бизнес-мутации принадлежат Brain (`lib/data/`). Feature UI не должен становиться вторым persistence layer. Shared/core не импортируют feature UI или `DatabaseService` кроме явно разрешённых узких contracts из `APP_STRUCTURE.md`.

### Optimistic UI
CRUD записей, планов и reorder должны сохранять быстрый локальный отклик и затем синхронизировать сервер. Rollback/retry определяется соответствующим Brain owner, а не локальной копией логики в widget.

## `timeline.records` — записи времени

`writeRecord`, `stopRecordByDocId`, `updateRecord`, `deleteRecordByDocId` — канонические mutation entry points. Timeline читает Brain cache/streams. Highlander-механика не допускает несколько канонических активных записей и reconciles stale/open conflicts. Realtime не должен создавать дубль поверх optimistic shadow.

Данные: `records` и связанные category/tag/link fields — см. `DATA_MAP.md` и `POCKETBASE_MANIFEST.md`.

## `timeline.unfilled_time` — незаписанное время

Pure policy определяет gaps между интервалами, service управляет настройками, lifecycle refresh, eligibility уведомления и fill-gap action. UI только отображает состояние и инициирует действие.

## `planning.plans` — планы

`PlanServiceExtension` владеет fetch/create/update/delete/bulk operations, optimistic cache и planning stream. Backlog использует тот же домен plans, а не отдельную модель данных. Ordering синхронизируется diff-only после optimistic reorder.

## `planning.recurring_plans` — повторяющиеся планы

Одна строка `plans` с `rrule` представляет серию. Повторения JIT-генерируются для нужного диапазона; виртуальный ID `virt-{seriesPocketId}-{YYYY-MM-DD}` никогда не является PocketBase REST ID. `exception_dates` исключает даты. Изменённое/завершённое повторение материализуется отдельной строкой с `parent_plan_id` + `recurrence_instance_date_key`; при наличии materialized instance виртуальная копия скрывается.

Пользовательские scopes: **только это событие** и **это и все следующие**. Второй вариант split-ит серию; прошлое не переписывается. Старый enum `entireSeries` — compatibility-only и канонизируется в `thisAndFuture`. Старый RRULE получает `UNTIL`; при исходном `COUNT` будущая серия получает остаток occurrences. Будущие materialized exceptions re-parent к новой серии. Cancel scope dialog отменяет mutation. Scope обязателен и для простого rename.

## `planning.time_view` — Time View

Time View использует domain cascade/snap/collision policy, а UI отвечает за gestures/layout. Fixed-time tag barriers хранятся сейчас локально в `SharedPreferences` (`time_view_fixed_tag_ids_v1`): это известное ограничение — они не синхронизируются между устройствами до появления schema field.

## `planning.smart_input` и `planning.smart_plan`

`SmartInputParser` извлекает wall-clock time/ranges из свободного текста, включая нормализацию распространённых STT артефактов и русских time phrases. Smart Plan принимает несколько текстовых «кирпичей» или диктовку, отправляет их в Brain AI parser, показывает ошибки inline и создаёт результат только через переданный commit callback. AI output не является отдельным persistence layer.

## `planning.plan_record_link`

Brain владеет matching, suggestion preferences/dismissal/auto-link policy и фактической агрегацией plan-vs-record. Shell только показывает prompt/результат. Нельзя переносить matching policy в shell widget.

## `categories.tree` и `tags.catalog`

Categories имеют tree hierarchy, CRUD/archive, fuzzy lookup, reorder и default plan time inheritance. Shared category layer содержит reusable presentation/picker contracts без Brain dependency. Tags имеют user catalog, CRUD/order, display settings и relation resolution; plan/list tag links синхронизируются Brain.

## `notes.editor`

Канонический editor contract — `NOTES_EDITOR_CONTRACT.md`. Документ, blocks, rich types, media/audio/drawing UI должны оставаться совместимыми с persisted Notes envelope. Детальная функция не дублируется здесь, чтобы не создать второй конфликтующий contract.

## `paths.projects`

Paths используют durable immutable revisions. `paths.active_revision_link` — единственный active gate. UI не планирует задачи напрямую: `path_planner_bridge.dart` — единственная executable projection boundary, а scheduling/materialization остаётся у Planner.

## `voice.generic` и `voice.desktop`

Generic voice dispatcher маршрутизирует ввод по активному destination. Shared Voice содержит recognition/contracts/platform adapters; Brain — parser/domain/cloud STT; desktop overlay — feature UI; shell — только integration/routing. Desktop hotkey/tray не должны обходить канонический record/plan mutation path.

## `health.sleep`

Device sleep и cloud sleep имеют отдельные adapters/services, а foreground reconcile на startup/resume объединяет их через Brain-owned lifecycle. Overlap/matching policy отделён от UI. Серверный deployment описан в `SERVER_SLEEP_SYNC_DEPLOY.md`.

## `offline.sync`

Record outbox поддерживает start/stop/update/delete; plan outbox — plan/list create/update/delete. Flush all выполняется через `DatabaseService.flushPendingLocalMutations`; connectivity/resume запускает retry. Auth-paused состояние сохраняется до валидной сессии.

## `shell.navigation`

Shell destinations: Timeline, Plans, Calendar, Lists, Categories, Profile, Paths. Phone/tablet используют compact navigation + More; desktop/web — side navigation. Shell является composition root, но не владельцем feature business rules.

## Правило синхронизации документации

При изменении функции в том же change-set проверяются: `FUNCTIONS.md`; `USER_GUIDE.md` для user-visible поведения; `UX_CONTRACT.md` для UX contract; `ARCHITECTURE.md` для системных invariants; `DATA_MAP.md`/`POCKETBASE_MANIFEST.md` для schema/storage; `APP_STRUCTURE.md` + generated detailed guide для ownership/files; `CHANGELOG.md` для поставленного изменения. Новая production capability без stable function ID в этой энциклопедии считается documentation drift.
