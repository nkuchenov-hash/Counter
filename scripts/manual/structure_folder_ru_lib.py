"""App-specific RU for every curated lib/** folder in FOLDERS — no generic wrappers."""

from __future__ import annotations

from structure_en_ru_adapt import register_folder_ru

register_folder_ru(
    "lib/data/categories",
    {
        "what_ru": "Срез brain для категорий — дерево, цвета, fuzzy-match названий и привязка записей к категориям.",
        "why_ru": "Категории группируют время на Timeline, планы, stats и voice-команды вроде «Price Reporter …».",
        "inside_ru": "Семь `part`-файлов; каждый закрывает одну задачу категорий (см. file entries ниже).",
        "affects_ru": "Category picker, экран Categories, category на start/stop записи, chips на планах, stats по категориям.",
        "when_ru": "Категории пропали, неверный color/icon, fuzzy match выбрал не того клиента, запись без category.",
        "delete_ru": "Нет — category features перестанут работать.",
        "related_ru": "`lib/data/category_service.dart`, `lib/features/categories/`.",
    },
)

register_folder_ru(
    "lib/data/local_sync",
    {
        "what_ru": "Offline queue — помнит изменения records/plans при сбое сети или login и повторяет позже.",
        "why_ru": "Life OS обещает tap-first UX: start/stop/edit не должны теряться на плохом Wi‑Fi.",
        "inside_ru": "SharedPreferences outboxes, pending-count state, connectivity listener для flush очередей.",
        "affects_ru": "Верхний offline/sync banner, фоновый retry при reconnect, auth-paused state.",
        "when_ru": "«Pending sync» завис, изменения offline потерялись, tap по banner ничего не делает.",
        "delete_ru": "Нет — offline-first поведение — shipped product law.",
        "related_ru": "`lib/app_shell.dart` offline banner, `docs/UX_CONTRACT.md`.",
    },
)

register_folder_ru(
    "lib/data/models",
    {
        "what_ru": "Plain data shapes (records, plans, categories, tags, profile) — без network-кода.",
        "why_ru": "Одинаковые field names везде; совпадает с `docs/DATA_MAP.md`, чтобы UI и brain понимали «record» одинаково.",
        "inside_ru": "Dart-классы `TimelineRecord`, `PlanningTask`, `CategoryRule`, `Tag` и др.",
        "affects_ru": "Каждый экран, который показывает или редактирует user data.",
        "when_ru": "Неверная дата на Timeline, parsing errors после смены PocketBase schema.",
        "delete_ru": "Нет — типы нужны по всему приложению.",
        "related_ru": "`lib/data/models.dart` barrel, `docs/DATA_MAP.md`.",
    },
)

register_folder_ru(
    "lib/data/profile",
    {
        "what_ru": "Срез brain для profile и tags — timezone, settings, tag catalog, admin flag.",
        "why_ru": "Wall-clock «today», язык, tag chips и tag manager зависят от profile + tag rows в PocketBase.",
        "inside_ru": "Profile hydration, settings PATCH, timezone math, tag CRUD, tag display prefs.",
        "affects_ru": "Экран Profile, настройки tags, timezone в header, admin gate для Component Lab.",
        "when_ru": "Неверная «today» line, timezone не сохраняется, tags пропали на cards, settings не пишутся.",
        "delete_ru": "Нет — profile и tags сломаются.",
        "related_ru": "`lib/data/profile_service.dart`, `lib/features/profile/`.",
    },
)

register_folder_ru(
    "lib/data/cache",
    {
        "what_ru": "Performance caches для быстрого paging по дням — warm day snapshots и rendered list bodies.",
        "why_ru": "Swipe между днями Timeline/Plans должен оставаться плавным при больших history records/plans.",
        "inside_ru": "`day_snapshot_window.dart`, `rendered_day_body_cache.dart`, `render_snapshot.dart`.",
        "affects_ru": "Плавность day swipe на Timeline и Planning; не влияет на корректность данных для пользователя.",
        "when_ru": "Jank при swipe дней, stale day content после edit, perf regression.",
        "delete_ru": "Нет — paging станет медленным или рваным.",
        "related_ru": "`lib/data/records/record_timeline_vm.dart`, `lib/shared/diagnostics/performance/runtime_flags.dart`.",
    },
)

register_folder_ru(
    "lib/shared/diagnostics",
    {
        "what_ru": "Общие runtime logs и shared kill-switch / metrics registry.",
        "why_ru": "Brain, shell, core и features нуждаются в одном месте для release-safe markers и compile-time performance toggles.",
        "inside_ru": "`runtime_log.dart`, `platform_log.dart`, `startup_log.dart`, `performance/`.",
        "affects_ru": "Только диагностика разработчика и kill switches — не UI chrome.",
        "when_ru": "Startup timing, kill-switch bisect, release-safe runtime markers.",
        "delete_ru": "Нет — Brain и shell импортируют эти пути.",
        "related_ru": "`lib/shared/diagnostics/performance/`, `docs/ARCHITECTURE.md`.",
    },
)

register_folder_ru(
    "lib/shared/diagnostics/performance",
    {
        "what_ru": "Feature flags runtime и perf metrics — полоса дат, warm window, счётчики rebuild.",
        "why_ru": "Позволяет включать дорогие features или capture frame metrics без debug code для всех users.",
        "inside_ru": "Файлы `runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart` (`PERF_DIAG` gated).",
        "affects_ru": "Perf: paging дат, tab stack оболочки, canvas bisect Planning Time View, diagnostic builds.",
        "when_ru": "Расследование jank, warm-window kill switch, perf capture tests.",
        "delete_ru": "Нет — perf tests и diagnostics ссылаются на эти flags.",
        "related_ru": "`test/perf_*`, `lib/data/cache/`, `lib/shared/diagnostics/`.",
    },
)

register_folder_ru(
    "lib/shared/voice",
    {
        "what_ru": "Одна система голосового ввода — команды, распознавание, маршрутизация, UI, платформенные адаптеры, диагностика.",
        "why_ru": "Микрофон телефона, горячая клавиша на компьютере, web и Wear должны сходиться в один путь разбора команд.",
        "inside_ru": "`commands/`, `recognition/`, `routing/`, `ui/`, `platforms/desktop/`, `platforms/mobile/`, `diagnostics/`.",
        "affects_ru": "Вся активация голосового ввода, распознавание, оверлеи и общий UI микрофона — без прямой записи в PocketBase.",
        "when_ru": "Перенос владения голосовым вводом, нарушения границ импортов, расхождение путей активации между платформами.",
        "delete_ru": "Нет — это продуктовая функция голосового ввода.",
        "related_ru": "`lib/data/voice/`, `lib/features/settings/voice/`, `lib/app/shell/shared/shell_voice_routing.dart`.",
    },
)

register_folder_ru(
    "lib/shared/voice/diagnostics",
    {
        "what_ru": "Маркеры Voice pipeline — log и step helpers.",
        "why_ru": "Desktop STT/voice и Brain voice parsing делят один quiet release / verbose debug-profile sink.",
        "inside_ru": "`desktop_voice_log.dart`, `desktop_voice_pipeline.dart`.",
        "affects_ru": "Только developer diagnostics для Voice.",
        "when_ru": "Трассировка capture, STT, overlay или submit шагов Voice.",
        "delete_ru": "Нет — используется в debug/profile Voice builds.",
        "related_ru": "`lib/shared/voice/platforms/desktop/`, `lib/shared/diagnostics/`.",
    },
)

register_folder_ru(
    "lib/shared/voice/commands",
    {
        "what_ru": "Платформенно-нейтральные Voice command / policy contracts.",
        "why_ru": "Семантика команд не должна ветвиться по способу активации (phone vs desktop vs web).",
        "inside_ru": "Transcript merge, delayed transcribe, capture-ready policy, engine/STT types, quality, correction flow.",
        "affects_ru": "Общие правила Voice interpretation для desktop runtime и Brain gates.",
        "when_ru": "Смена merge/quality/policy без redesign UX.",
        "delete_ru": "Нет — shared Voice contracts сломаются.",
        "related_ru": "`lib/shared/voice/platforms/desktop/`, `lib/data/voice/`.",
    },
)

register_folder_ru(
    "lib/shared/voice/recognition",
    {
        "what_ru": "Платформенно-нейтральные контракты распознавания речи.",
        "why_ru": "Адаптеры распознавания отличаются по ОС; общие контракты остаются едиными.",
        "inside_ru": "`speech_engine_handle.dart`, `speech_listen_locale.dart`, фабрика/заглушка распознавателя, таксономия ошибок.",
        "affects_ru": "Лист микрофона на телефоне и web, а также проводка распознавателя на компьютере.",
        "when_ru": "Выбор распознавателя, разрешение локали, отображение ошибок.",
        "delete_ru": "Нет — контракты распознавания сломаются.",
        "related_ru": "`lib/shared/voice/ui/`, `lib/shared/voice/platforms/desktop/`.",
    },
)

register_folder_ru(
    "lib/shared/voice/routing",
    {
        "what_ru": "Контракты отправки голосовых команд без владения состоянием вкладок.",
        "why_ru": "Оболочка знает активный раздел; голосовой ввод только отдаёт колбэки отправки.",
        "inside_ru": "`desktop_voice_record_submit.dart`, `desktop_voice_acceptance_bridge.dart`.",
        "affects_ru": "Маршрутизация голосового ввода в оболочке и хуки приёмки.",
        "when_ru": "Мост разобранной команды к записи или тесты приёмки.",
        "delete_ru": "Нет — путь отправки голосовых команд в оболочке сломается.",
        "related_ru": "`lib/app/shell/shared/shell_voice_routing.dart`.",
    },
)

register_folder_ru(
    "lib/shared/voice/ui",
    {
        "what_ru": "Переиспользуемый интерфейс голосового ввода — лист микрофона, конфиг захвата, индикаторы уровня.",
        "why_ru": "UI активации микрофона общий для вкладок; это не UI отдельного продуктового раздела.",
        "inside_ru": "`voice_input_sheet.dart`, `voice_capture_config.dart`, `app_mic_level_bars.dart`.",
        "affects_ru": "Лист микрофона на телефоне и web и общая визуализация уровня сигнала.",
        "when_ru": "Маршрутизация листа микрофона, UI прослушивания, индикаторы уровня.",
        "delete_ru": "Нет — общий UI голосового ввода сломается.",
        "related_ru": "`lib/app/shell/shared/shell_voice_routing.dart`.",
    },
)

register_folder_ru(
    "lib/shared/voice/platforms",
    {
        "what_ru": "Платформенные адаптеры голосового ввода — рантайм/UI компьютера и аудио для телефона/web.",
        "why_ru": "Активация и распознавание отличаются по ОС; семантика команд остаётся общей.",
        "inside_ru": "`desktop/`, `desktop/ui/`, `mobile/`.",
        "affects_ru": "Горячие клавиши и оверлей на компьютере, а также аудио-адаптеры телефона и web.",
        "when_ru": "Платформенные изменения активации или распознавания голоса.",
        "delete_ru": "Нет — платформенные адаптеры голосового ввода сломаются.",
        "related_ru": "`lib/shared/voice/commands/`, `lib/data/voice/`.",
    },
)

register_folder_ru(
    "lib/shared/voice/platforms/desktop",
    {
        "what_ru": "Рантайм голосового ввода на компьютере — горячие клавиши, helper-процесс, оверлей, захват, настройки, бенчмарки.",
        "why_ru": "Активация на Windows — реализация общей системы голосового ввода, а не отдельный продукт.",
        "inside_ru": "STT helper и оркестратор, горячие клавиши, оверлей, захват, настройки, диагностика, бенчмарки.",
        "affects_ru": "Горячие клавиши, оверлей, локальный STT и настройки голосового ввода на Windows.",
        "when_ru": "Голосовой ввод на компьютере не пишет, горячая клавиша мертва, задержки оверлея, сбои STT helper.",
        "delete_ru": "Нет — функция голосового ввода на компьютере.",
        "related_ru": "`lib/shared/voice/platforms/desktop/ui/`, `lib/core/services/desktop_tray_service.dart`.",
    },
)

register_folder_ru(
    "lib/shared/voice/platforms/desktop/ui",
    {
        "what_ru": "Интерфейс голосового ввода только для компьютера — виджет, капсула, лист правки, панель команд.",
        "why_ru": "Нативный оверлей и Flutter-хром голосового ввода — презентация только для компьютера.",
        "inside_ru": "`desktop_voice_widget.dart`, capsule, correction sheet, command panel.",
        "affects_ru": "Только desktop Voice overlay UI.",
        "when_ru": "Регрессии desktop Voice capsule/overlay UI.",
        "delete_ru": "Нет — desktop Voice UI сломается.",
        "related_ru": "`lib/shared/voice/platforms/desktop/`, `lib/app/shell/shared/shell_voice_routing.dart`.",
    },
)

register_folder_ru(
    "lib/shared/voice/platforms/mobile",
    {
        "what_ru": "Аудио-адаптеры голосового ввода для телефона и web, используемые общим листом микрофона.",
        "why_ru": "Web Audio и заглушка отличаются по платформе; адаптеры живут рядом с владением голосовым вводом.",
        "inside_ru": "`voice_audio_web.dart`, `voice_audio_stub.dart`.",
        "affects_ru": "Звук и тон листа микрофона на web и остальных платформах.",
        "when_ru": "Несовпадение web-аудио заглушки голосового ввода.",
        "delete_ru": "Нет — условный импорт аудио голосового ввода сломается.",
        "related_ru": "`lib/shared/voice/ui/voice_input_sheet.dart`.",
    },
)

register_folder_ru(
    "lib/data/voice",
    {
        "what_ru": "Голосовой разбор в Brain — парсер, резолвер домена, глоссарий, фильтр загрязнения, облачный STT.",
        "why_ru": "Живой индекс категорий и записи в PocketBase принадлежат Brain, а не shared Voice.",
        "inside_ru": "`voice_command_parser.dart`, резолвер домена, глоссарий, нормализация, фильтр загрязнения, постобработка, облачный backend.",
        "affects_ru": "Интерпретация голосовых команд в категории и записи, а также транспорт облачного STT с авторизацией.",
        "when_ru": "Неверный разбор команды, ошибка авторизации облачного STT, постобработка глоссария.",
        "delete_ru": "Нет — выполнение голосовых команд сломается.",
        "related_ru": "`lib/shared/voice/`, `lib/data/database_service.dart`.",
    },
)

register_folder_ru(
    "lib/features/settings/voice",
    {
        "what_ru": "Интерфейс настроек голосового ввода — горячие клавиши, микрофон, распознаватель, диагностика попыток.",
        "why_ru": "Настройки голоса принадлежат settings, а не только chrome профиля.",
        "inside_ru": "`desktop_voice_settings_section.dart`, `desktop_voice_settings_desktop.dart`, `desktop_voice_attempt_dialog.dart`.",
        "affects_ru": "Элементы управления голосовым вводом в профиле и настройках на компьютере.",
        "when_ru": "UI горячих клавиш, диалог попытки, инструменты разработчика голосового ввода.",
        "delete_ru": "Нет — UI настроек голосового ввода станет недоступен.",
        "related_ru": "`lib/shared/voice/platforms/desktop/desktop_voice_settings.dart`, `lib/features/profile/profile_view.dart`.",
    },
)

register_folder_ru(
    "lib/data/plans/diagnostics",
    {
        "what_ru": "Planning-domain diagnostics внутри Brain (дубликаты планов / stream lifecycle markers).",
        "why_ru": "Brain plan helpers эмитят эти логи; не должны жить в feature UI и создавать data→features imports.",
        "inside_ru": "`plan_duplicate_log.dart`.",
        "affects_ru": "Только diagnostic markers дубликатов / stream планов.",
        "when_ru": "Расследование duplicate plan rows или spam plan stream.",
        "delete_ru": "Нет — Brain plan helpers эмитят эти markers.",
        "related_ru": "`lib/shared/diagnostics/performance/runtime_flags.dart` только для `kPlanStreamLifecycleDiag`.",
    },
)

register_folder_ru(
    "lib/shared/time",
    {
        "what_ru": "Общий wall-clock и timezone math для Brain, shell header, Plans и settings.",
        "why_ru": "Границы дней и time bucketing следуют profile timezone law — не device local time — в нескольких секциях.",
        "inside_ru": "`app_clock.dart`, `profile_timezone_catalog.dart`, `wall_clock.dart`, `plan_time_visible_window.dart`, plan labels, category TZ options.",
        "affects_ru": "Часы в global header, окно часов Time View (−3..27 h), подписи timezone picker, plan wall projection.",
        "when_ru": "Неверный «today», label TZ в header, visible hours Time View, DST label.",
        "delete_ru": "Нет — timeline и planning time display сломаются.",
        "related_ru": "`lib/data/profile/profile_timezone.dart`, `lib/core/widgets/global_app_header.dart`, `lib/features/settings/`.",
    },
)

register_folder_ru(
    "lib/features/settings",
    {
        "what_ru": "Settings-owned helpers — timezone labels и UI настроек Voice.",
        "why_ru": "Списки timezone и Voice settings принадлежат settings, не core и не только profile chrome.",
        "inside_ru": "`timezone_settings.dart`, `voice/` (desktop Voice settings section/desktop/attempt dialog).",
        "affects_ru": "Подписи timezone в profile и desktop Voice settings controls.",
        "when_ru": "Список timezone options, UI hotkey/mic Voice.",
        "delete_ru": "Нет — сломаются settings timezone/Voice helpers.",
        "related_ru": "`lib/shared/time/`, `lib/shared/voice/`, `lib/features/profile/profile_view.dart`.",
    },
)

register_folder_ru(
    "lib/features/planning/time_view",
    {
        "what_ru": "Код визуального расписания Plans → Time View: дневная временная шкала, слой карточек, drag/resize, настройки видимого окна и поиск default time.",
        "why_ru": "Режим visual schedule — планы по clock time на шкале, resize/drag, hour grid.",
        "inside_ru": "Canvas, card layer, drag/resize controllers, settings sheet, search default times.",
        "affects_ru": "Sub-mode Time View внутри вкладки Plans.",
        "when_ru": "Карточки overlap неверно, jank drag/resize, масштаб часов, fixed-time tags, жесты Time View.",
        "delete_ru": "Нет — Time View — core feature Plans.",
        "related_ru": "`planning_page.dart`, `PlanTimeTaskCard` в `core/widgets/`.",
    },
)

register_folder_ru(
    "lib/core/widgets/plan_time_task_card",
    {
        "what_ru": "Каноническая карточка плана для list mode, Time View и calendar rows (CardPlan design).",
        "why_ru": "Plans выглядят одинаково в list, Time View и calendar; play/checkbox/menu shared.",
        "inside_ru": "Разделены density, geometry, layouts, tags, progress и controls.",
        "affects_ru": "Карточки на Plans, блоки Time View и строки calendar.",
        "when_ru": "Высота card, tag pills, play button, density bands Time View.",
        "delete_ru": "Нет — plan UI сломается везде.",
        "related_ru": "`lib/features/planning/`, `plan_card_layouts.dart`.",
    },
)

register_folder_ru(
    "lib/features/timeline",
    {
        "what_ru": "UI вкладки Timeline — day pager, running/stopped record cards, вход в stats.",
        "why_ru": "Главный экран time tracking (первая bottom tab).",
        "inside_ru": "Swipe wrapper, day list, record cards, header controls (stats toggle, input).",
        "affects_ru": "Вкладка Timeline и встроенный stats view.",
        "when_ru": "Records на неверном дне, now-line, swipe между днями, tap/edit record card.",
        "delete_ru": "Нет — вкладка Timeline исчезнет.",
        "related_ru": "`lib/data/record_service.dart`, `ActivityDetailSheet`.",
    },
)

register_folder_ru(
    "lib/features/lists",
    {
        "what_ru": "UI вкладки Lists — backlog/checklist tasks с filters, bulk select и export.",
        "why_ru": "Третья productivity tab для non-scheduled list items (та же таблица `plans`, backlog mode).",
        "inside_ru": "Filters, cards, inline add, bulk bar, clipboard export.",
        "affects_ru": "Вкладка Lists (четвёртая bottom tab, index 3).",
        "when_ru": "List filters, checkbox done, bulk delete, export visible list as text.",
        "delete_ru": "Нет — вкладка Lists исчезнет.",
        "related_ru": "`lib/data/plan_service.dart`.",
    },
)

register_folder_ru(
    "lib/features/notes",
    {
        "what_ru": "UI Notes — GLM library, full-screen block editor, drawing canvas и карточки заметок.",
        "why_ru": "Lists Notes и standalone Notes routes собираются здесь; PocketBase I/O остаётся в Brain.",
        "inside_ru": "Library page, block editor, drawing canvas, GLM surfaces/tokens, виджеты cards/body/shell.",
        "affects_ru": "Notes во вкладке Lists, full-screen editor и drawing-блоки.",
        "when_ru": "Layout library, toolbar editor, вставка drawing, неверный preview карточки.",
        "delete_ru": "Нет — сломается Notes UI.",
        "related_ru": "`lib/core/widgets/notes/`, `notes_brain_helpers.dart`, `lib/features/lists/`.",
    },
)

register_folder_ru(
    "lib/features/notes/widgets",
    {
        "what_ru": "Виджеты Notes library — grid/list карточки, GLM production shell, library body.",
        "why_ru": "Lists встраивает эти виджеты вместо дублирования card/shell layout в `lists_view.dart`.",
        "inside_ru": "`note_card.dart`, `notes_library_body.dart`, `notes_library_production_shell.dart`.",
        "affects_ru": "Отрисовка Notes library (grid/list) внутри Lists.",
        "when_ru": "Badges карточки, grid vs list, chrome GLM library shell.",
        "delete_ru": "Нет — сломается Notes library UI.",
        "related_ru": "`lib/features/notes/`, `lists_view.dart`.",
    },
)

register_folder_ru(
    "lib/features/shared/notes_editor",
    {
        "what_ru": "Общий запуск редактора заметок и Quill-лист — полноэкранный маршрут с автосохранением Brain.",
        "why_ru": "Вкладки Lists и Plans открывают один редактор заметок, не дублируя Quill в каждом экране.",
        "inside_ru": "`notes_editor_launcher.dart`, `notes_editor_sheet.dart`.",
        "affects_ru": "Полноэкранный редактор заметок из Lists и общих edit flows.",
        "when_ru": "Маршрут редактора, автосохранение Quill, переход More → Edit details.",
        "delete_ru": "Нет — сломается общий вход в редактор заметок.",
        "related_ru": "`lib/core/widgets/notes/`, `lib/features/shared/edit_sheet/`.",
    },
)

register_folder_ru(
    "lib/core/widgets/notes",
    {
        "what_ru": "Канонический reusable Notes UI — editor surface, toolbar, save status, preview card.",
        "why_ru": "Feature Notes собирает чистые виджеты; Core не импортирует Brain или features.",
        "inside_ru": "Barrel `notes.dart`, context row, editor surface, markdown helpers, toolbar, preview card.",
        "affects_ru": "Любой Notes editor/library с import `package:counter/core/widgets/notes/`.",
        "when_ru": "Невидимый web toolbar, chip save-status, Quill↔Markdown copy/paste.",
        "delete_ru": "Нет — пропадут канонические Notes виджеты.",
        "related_ru": "`lib/features/notes/`, `lib/features/shared/notes_editor/`.",
    },
)

register_folder_ru(
    "lib/features/profile",
    {
        "what_ru": "Profile и tag settings screens из меню More.",
        "why_ru": "Аккаунт, timezone, язык, tag manager и настройки desktop voice (Windows).",
        "inside_ru": "Profile view, секции settings, страницы tag manager, диагностика desktop voice.",
        "affects_ru": "More → Profile, маршруты tag settings, карточка desktop voice.",
        "when_ru": "Login profile, смена timezone, manage tags, desktop hotkey settings.",
        "delete_ru": "Нет — profile/settings станут недоступны.",
        "related_ru": "`lib/data/profile/`, `lib/features/dev/` (admin only).",
    },
)

register_folder_ru(
    "lib/features/categories",
    {
        "what_ru": "UI менеджера категорий — дерево, создание/редактирование, настройки видимости.",
        "why_ru": "Пользователь организует work/personal/client categories из More → Categories.",
        "inside_ru": "List view, recursive tree picker, create dialog, visibility prefs.",
        "affects_ru": "More → Categories; category pickers в других экранах используют эти widgets.",
        "when_ru": "Create category, reorder, archive, pick category в tree dialog.",
        "delete_ru": "Нет — UI category management исчезнет.",
        "related_ru": "`lib/data/categories/`.",
    },
)

register_folder_ru(
    "lib/features/dev",
    {
        "what_ru": "Admin-only Component Lab — preview design system, скрыт от обычных users.",
        "why_ru": "Проверяет buttons/cards/chips против `docs/DESIGN_SYSTEM.md` до production migration.",
        "inside_ru": "Component lab page и card demos.",
        "affects_ru": "More menu только когда `profiles.is_admin` true.",
        "when_ru": "Design-system QA, V7 component acceptance.",
        "delete_ru": "Возможно — runtime продукту не нужен, но V7 work использует; оставить для admins.",
        "related_ru": "`docs/DESIGN_SYSTEM.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.",
    },
)

register_folder_ru(
    "lib/features/auth",
    {
        "what_ru": "Sign-in, registration, OAuth и password-reset screens до загрузки main app.",
        "why_ru": "Users должны authenticate в PocketBase до Timeline/Plans data.",
        "inside_ru": "`auth_view.dart`, `auth_screen.dart`, `oauth_session.dart`.",
        "affects_ru": "Login gate из `main.dart` когда session invalid.",
        "when_ru": "OAuth redirect broken, login form, register flow, password reset UI.",
        "delete_ru": "Нет — users не смогут sign in.",
        "related_ru": "`lib/data/auth_bridge.dart`, `docs/DEPLOY.md` OAuth admin section.",
    },
)

register_folder_ru(
    "lib/features/calendar",
    {
        "what_ru": "UI вкладки Calendar — month view планов (когда route включён в navigation).",
        "why_ru": "Альтернативный просмотр планов по calendar month рядом с list/Time View на Plans.",
        "inside_ru": "`calendar_view.dart`.",
        "affects_ru": "Calendar tab в bottom/side navigation (когда присутствует в shell).",
        "when_ru": "Calendar month layout, plan dots на dates, calendar navigation.",
        "delete_ru": "Возможно — если calendar tab убран из shell; держать пока route существует.",
        "related_ru": "`lib/features/planning/`, plan card widgets в `core/widgets/`.",
    },
)

register_folder_ru(
    "lib/features/stats",
    {
        "what_ru": "Productivity stats views внутри Timeline — hours by category, plan vs fact.",
        "why_ru": "Stats toggle в header Timeline переключает list mode на analytics без отдельной area.",
        "inside_ru": "`stats_view.dart`, `plan_vs_fact_tab.dart`.",
        "affects_ru": "Вкладка Timeline, когда пользователь нажимает Stats segmented control.",
        "when_ru": "Stats totals неверны, plan-vs-fact chart, stats tab toggle.",
        "delete_ru": "Нет — stats mode Timeline исчезнет.",
        "related_ru": "`lib/data/categories/category_stats.dart`, `lib/features/timeline/timeline_header_controls.dart`.",
    },
)

register_folder_ru(
    "lib/features/wear",
    {
        "what_ru": "Wear OS watch companion — упрощённый timer screen на Android watches.",
        "why_ru": "Watch form factor нужен lite UI и brain path `loadInitialDataWearLite`.",
        "inside_ru": "`wear_timer_screen.dart`, `wear_main_wrapper.dart`, platform channel shims.",
        "affects_ru": "Только Wear OS APK companion — не phone Timeline UI.",
        "when_ru": "Watch timer sync, Wear build entry, companion crashes на watch.",
        "delete_ru": "Нет — если Wear OS companion — supported target.",
        "related_ru": "`lib/data/db_core.dart` Wear lite load, `android/` Wear module если настроен.",
    },
)

register_folder_ru(
    "lib/l10n/langs",
    {
        "what_ru": "Карты строк UI для каждой локали — key → переведённый текст.",
        "why_ru": "Каждый locale-файл даёт переводы для ключей из `dictionary.dart`.",
        "inside_ru": "`en.dart` и `ru.dart` — канонические; остальные локали частичные.",
        "affects_ru": "Все видимые подписи UI при смене языка в настройках.",
        "when_ru": "Пропал ключ перевода, неверная строка на выбранном языке.",
        "delete_ru": "Нет — без locale maps локализация не работает.",
        "related_ru": "`lib/l10n/dictionary.dart`, `scripts/sync_locales.dart`.",
    },
)

register_folder_ru(
    "lib/core/services",
    {
        "what_ru": "Инфраструктура окна и трея на компьютере (не владение голосовым вводом).",
        "why_ru": "Главное окно и трей — общая desktop-оболочка; голосовой ввод живёт в `lib/shared/voice/`.",
        "inside_ru": "`desktop_tray_service*.dart`, `desktop_main_window.dart`.",
        "affects_ru": "Иконка трея Windows и размер главного окна.",
        "when_ru": "Пропал трей, сломаны hide/show главного окна.",
        "delete_ru": "Нет — инфраструктура трея и окна на компьютере.",
        "related_ru": "`lib/shared/voice/platforms/desktop/`, `lib/app/shell/`.",
    },
)

register_folder_ru(
    "lib/features/planning/widgets",
    {
        "what_ru": "Мелкие виджеты вкладки Plans — filters, bulk bar, empty states, menus.",
        "why_ru": "Вынесены из большого planning page для читаемости и architecture guard.",
        "inside_ru": "Bulk selection bar, filter controls, quick-add strip, card menus.",
        "affects_ru": "Части list mode UI на вкладке Plans.",
        "when_ru": "Bulk edit bar, menu карточки plan, неверный empty state.",
        "delete_ru": "Нет — UI вкладки Plans сломается.",
        "related_ru": "`planning_page.dart`.",
    },
)

register_folder_ru(
    "lib/features/planning/settings",
    {
        "what_ru": "Sheets настроек Plans — visible hours, default category, timezone search.",
        "why_ru": "Time View и defaults планов требуют отдельного settings UI.",
        "inside_ru": "Bounds slider, prefs record→plan link, no-tags chip settings.",
        "affects_ru": "Маршруты Plans → settings и конфигурация Time View.",
        "when_ru": "Диапазон visible hours, default category/timezone search.",
        "delete_ru": "Нет — plan settings станут недоступны.",
        "related_ru": "`time_view/time_view_settings_sheet.dart`.",
    },
)

register_folder_ru(
    "lib/features/shared/edit_sheet",
    {
        "what_ru": "Helpers внутри bottom sheets редактирования plan/record.",
        "why_ru": "Autosave, time picker, checklist и repeat rules общие для plan и record sheets.",
        "inside_ru": "Omni picker entry, debounced autosave, RRULE helpers, Quill toolbar.",
        "affects_ru": "Сохранение edit sheet, смена date/time, строки checklist.",
        "when_ru": "Autosave edit sheet, date picker, неверный repeat preset.",
        "delete_ru": "Нет — edit sheets сломаются.",
        "related_ru": "`activity_detail_sheet.dart`.",
    },
)

register_folder_ru(
    "lib/features/profile/settings",
    {
        "what_ru": "Секции настроек Profile — account, notifications, security.",
        "why_ru": "Settings page разбита на секции для More → Settings.",
        "inside_ru": "Logout row, notification permission, password reset, biometric lock.",
        "affects_ru": "Маршруты settings из shell и profile.",
        "when_ru": "Logout, notification permission, password reset UI.",
        "delete_ru": "Нет — секции settings пропадут.",
        "related_ru": "`lib/app/shell/shared/settings_page.dart`.",
    },
)

register_folder_ru(
    "lib/core/widgets/plan_card",
    {
        "what_ru": "Переэкспорт совместимости на канонические файлы `plan_time_task_card/`.",
        "why_ru": "Старые import использовали путь `plan_card/` во время migration design system.",
        "inside_ru": "Тонкие export stubs без логики.",
        "affects_ru": "Legacy import paths всё ещё резолвятся.",
        "when_ru": "Удаление migration stubs после обновления всех import.",
        "delete_ru": "Возможно — после проверки, что import `plan_card/` не осталось.",
        "related_ru": "`lib/core/widgets/plan_time_task_card/`.",
    },
)
