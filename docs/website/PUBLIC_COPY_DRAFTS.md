# Life OS / Counter — Public Copy Drafts

**Audit date:** 2026-06-24  
**Tone:** Clear, product-focused. EN primary; RU paired where useful.  
**v1 homepage copy:** Prefer `HOMEPAGE_WIREFRAME_V1.md` — this file is raw option pool.

---

## Homepage hero — headline options (EN)

1. **Plan your day. Track your time. Know the difference.**
2. **A Life OS that responds before the network does.**
3. **Timeline, planning, and plan vs fact — in one fast app.**
4. **Your day on cards — not in spreadsheets.**
5. **Track time instantly. Plan in real hours. Compare honestly.**
6. **Offline-first time tracking for people who plan.**
7. **The personal system for plan, fact, and focus.**
8. **Swipe your days. Start in one tap. Sync when you can.**
9. **Timezone-aware planning for a mobile life.**
10. **Life OS: where your calendar and your clock agree.**

### Headlines (RU)

1. **Планируйте день. Учитывайте время. Видьте разницу.**
2. **Life OS откликается раньше, чем успевает сеть.**
3. **Таймлайн, планы и «план vs факт» — в одном быстром приложении.**
4. **Ваш день на карточках — не в таблицах.**
5. **Мгновенный учёт. План по часам. Честное сравнение.**

---

## Subheadline options (EN)

1. Life OS combines timeline tracking, visual planning, lists, and calendar — with offline-first sync and profile timezone for every wall-clock day.
2. Start and stop timers without waiting. Schedule blocks in Time View. See what you planned versus what you did.
3. Personal time tracking and planning in English or Russian. Open the web app in seconds.

### Subheadlines (RU)

1. Life OS объединяет таймлайн, планирование, списки и календарь — с офлайн-синхронизацией и часовым поясом профиля.
2. Старт и стоп без ожидания сети. Блоки в Time View. Сравнение плана и факта за день.

---

## Homepage CTA band

**EN:** Ready to try it? Open Life OS in your browser — no install required.

**RU:** Попробовать? Откройте Life OS в браузере — без установки.

**Button:** Open web app / Открыть веб-приложение

---

## Feature page intros

### Time tracking (EN)

Your timeline is the honest log. Swipe between days, start or stop in one tap, and fix mistakes on the same card you use to track. Categories color every row; stats are one toggle away.

### Time tracking (RU)

Таймлайн — честный журнал. Свайп между днями, старт и стоп в одно касание, правки на той же карточке. Категории задают цвет; статистика — один переключатель.

### Planning (EN)

Plans are cards with time, tags, checklists, and notes — not a buried settings screen. List mode for the day; Time View when you want blocks on a clock. Tap play to turn intent into a running record.

### Planning (RU)

Планы — карточки со временем, тегами, чеклистами и заметками. Список на день; Time View — блоки на шкале времени. Play превращает план в активный учёт.

### Offline (EN)

Bad Wi‑Fi should not freeze your day. Life OS updates the UI first, queues changes locally, and syncs when you are back. Tap the banner to retry — no mystery spinners on every row.

### Offline (RU)

Плохой Wi‑Fi не должен останавливать день. Сначала интерфейс, очередь локально, синхронизация при появлении сети. Баннер — повторить синхронизацию.

---

## FAQ — questions and answers

### What is Life OS?

**EN:** Life OS (also built as the Counter app) is a personal app for planning your day, tracking time on a timeline, managing lists, and comparing plan vs fact. It is designed for solo use with fast local UI and secure account sync.

**RU:** Life OS (приложение Counter) — личный инструмент для планирования дня, учёта времени, списков и сравнения плана с фактом. Для одного пользователя: быстрый интерфейс и синхронизация через аккаунт.

### Is it free?

**EN:** The web app is available to use with a free account.

**RU:** Веб-приложение доступно с бесплатным аккаунтом.

*v1: Do not mention AI or Pro tier until `POSITIONING_V1.md` / owner decision.*

### Does it work offline?

**EN:** Yes, for core actions: start and stop time entries, create and edit plans and list items, and toggle done states. Changes queue on your device and sync when connectivity returns. A banner shows pending items; tap it to retry.

**RU:** Да, для основных действий: старт/стоп учёта, создание и правка планов и списков, отметка «готово». Изменения в очереди на устройстве; при появлении сети — синхронизация. Баннер показывает ожидающие операции.

### How does timezone handling work?

**EN:** You set a profile timezone and offset. Timeline days, planning placement, stats, and the Time View now-line use that profile — not your laptop’s local timezone. Useful when you travel.

**RU:** Вы задаёте часовой пояс и смещение в профиле. Дни таймлайна, планирование, статистика и линия «сейчас» в Time View опираются на профиль — не на часовой пояс ноутбука.

### Can I use it on the web? Android? iPhone?

**EN:** The web app is live today at the Counter GitHub Pages URL. The same Flutter codebase targets Android, iOS, Windows, macOS, Linux, and Wear OS — native download links should be added to the site only when store/APK distribution is confirmed.

**RU:** Веб-приложение уже доступно. Тот же код собирается под Android, iOS, Windows, macOS, Linux и Wear OS — ссылки на скачивание на сайте только после подтверждения публикации.

### How do I sign in?

**EN:** Email and password, plus Google or Yandex when enabled on the server. Password reset is supported. On supported phones you can enable biometric unlock after signing in with email.

**RU:** Email и пароль, плюс Google или Яндекс при включении на сервере. Есть сброс пароля. На поддерживаемых телефонах — биометрическая разблокировка после входа по email.

### Can I run multiple timers at once?

**EN:** Life OS enforces consistent timelines: starting a new primary timer stops other open entries according to the app’s singleton rules, and the server prevents overlapping intervals for your account. Parallel or nested records exist for specific cases, but the product is optimized for one clear running activity at a time.

**RU:** Приложение поддерживает согласованный таймлайн: новый основной таймер останавливает другие открытые записи; сервер не допускает пересечения интервалов. Есть отдельные сценарии вложенных записей, но продукт ориентирован на один явный активный учёт.

### What is Plan vs Fact?

**EN:** On the Stats area of the Timeline tab, Plan vs Fact compares tasks scheduled for a day with time entries you actually tracked — so you can see intention vs reality without exporting to a spreadsheet.

**RU:** В разделе статистики таймлайна «План vs факт» сравнивает запланированные задачи и реальный учёт за день — без экспорта в таблицы.

### Is my data private?

**EN:** Your data is tied to your account and isolated per user on the backend. Do not share your password. The marketing site does not access your tasks or time entries.

**RU:** Данные привязаны к аккаунту и изолированы на сервере. Не передавайте пароль. Маркетинговый сайт не имеет доступа к вашим задачам и записям.

### Do you support Russian?

**EN:** Yes. English and Russian are fully supported in the app UI. Several other languages are partially available.

**RU:** Да. Английский и русский — полностью. Ещё несколько языков частично.

### Does voice input work everywhere?

**EN:** The mic button works on Timeline, Plans, and Lists, routing to the right kind of entry. Speech recognition depends on your browser or OS. Desktop has an experimental structured voice workflow for internal use — not part of the public product story.

**RU:** Микрофон работает в таймлайне, планах и списках. Распознавание зависит от браузера или ОС. На десктопе есть экспериментальный сценарий для внутреннего использования — не часть публичного продукта.

---

## Meta descriptions (SEO drafts)

**Home EN:** Life OS — fast offline-first time tracking, visual planning, lists, and plan vs fact. Open in your browser.

**Home RU:** Life OS — быстрый офлайн учёт времени, планирование и сравнение плана с фактом. Откройте в браузере.

**Planning EN:** Schedule your day in list and Time View modes. Five-minute snap, recurring plans, reminders.

**Offline EN:** Keep tracking and planning when offline. Life OS queues sync and shows a clear pending banner.

---

## Social / share (short)

**EN:** Life OS — plan on cards, track in real time, compare plan vs fact. Try the web app.

**RU:** Life OS — план на карточках, учёт в реальном времени, план vs факт. Веб-приложение.
