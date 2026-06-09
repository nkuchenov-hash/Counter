# Fix documentation — Surgical restore, stats, edit dialog, collision (EN + RU)

## English

### Mission 1: Mic button restored (§5 Surgical Strictness)

**What:** The Mic/Speech-to-Text floating action button was hidden when the selected date was "today" due to a `Visibility` wrapper that only showed the FAB when the selected date was **before** projected today.

**Why:** Per §5 (Surgical Strictness Policy), the mic button must not be removed or hidden unless explicitly requested. Restoring it ensures voice input is available on the timeline tab for today as well as past dates.

**Change:** In `lib/main.dart`, the FAB was restored to its original behaviour: `floatingActionButton` is set to the Mic `FloatingActionButton` whenever `!isFutureDate` (i.e. not a future date), and `null` when `isFutureDate`. The `Visibility` widget that hid the button on "today" was removed so the mic is visible for both today and past dates.

---

### Mission 2: Live math in stats (no stored duration)

**What:** Aggregated stats must use only the difference between `endTime` and `startTime` for duration. Any pre-saved or stored duration field must be ignored so that manual edits to start/end are reflected immediately in totals.

**Why:** Stored duration can become stale after edits. Using only timestamps keeps stats consistent with what the user sees in the edit dialog.

**Change:** No code change was required. `getAggregatedStats` in `lib/database_service.dart` already uses `recordDurationSecondsWithinDayFromTimestamps`, which computes duration only from `startTime` and `endTime` (or planetary "now" when running) and does not read any stored duration field. This satisfies the requirement.

---

### Mission 3: "Midnight bridge" edit window (Start/End date + time)

**What:** The Edit/Create Record dialog was updated so that:
- **Start row:** A date picker (Date) and a time picker (Time) are shown side by side.
- **End row:** A second date picker (Date) and a second time picker (Time) are shown side by side.
- By default, both dates match the record’s existing date; the end date can be changed (e.g. to the next day) for records that cross midnight.
- The combined Start and End `DateTime` values are passed to the Save logic.

**Why:** Users need to create or edit records that span midnight (e.g. 23:00–01:00 next day). A single "date" plus two time pickers is not enough; end must have its own date.

**Change:** In `lib/main.dart`, `EditRecordSheet`:
- State: added `_endDate` (defaults to start date; for edit mode it is derived from the record’s end time).
- Added getters `_effectiveStart` and `_effectiveEnd` that build full `DateTime`s from the chosen date + time for start and end.
- Replaced the single "Date" and "Start time" / "End time" list tiles with two rows:
  - **Start:** OutlinedButton for date (`_pickDate`) and OutlinedButton for time (`_pickStartTime`).
  - **End:** OutlinedButton for date (`_pickEndDate`) and OutlinedButton for time (`_pickEndTime`).
- Added `_pickEndDate()` with `firstDate: _recordDate` so end date cannot be before start date.
- `_pickStartTime` and `_pickEndTime` now use `_recordDate` and `_endDate` respectively when building the stored `DateTime`s.
- Save uses `_effectiveStart` and `_effectiveEnd` for display→UTC conversion and for the overlap check and write/update calls.

---

### Mission 4: Global collision check and ghost-timer relay

**What:**  
1. **Universal overlap check:** Before saving a new or edited record, the new `[Start, End]` interval is checked against all relevant Firestore records. If it overlaps any existing record, the save is blocked and the UI shows: *"Time conflict! This overlaps with an existing record."*  
2. **Relay rule (ghost kill):** When starting a new timer, any record with `endTime == null` (e.g. a left-over "running" record from a previous day) is closed by setting its `endTime` to the new task’s `startTime`. Then the new running record is created.

**Why:** Overlaps would break the NO_OVERLAP contract and make stats confusing. The relay rule ensures there is at most one "running" record and that the previous segment ends exactly when the new one starts.

**Change:**  
- **database_service.dart**
  - **`checkOverlapWithExistingRecords(DateTime start, DateTime end, {String? excludeDocId})`:** Queries records with `startTime < end`, then in memory checks whether `[start, end]` overlaps any record’s `[otherStart, otherEnd]` (using planetary now for missing `endTime`). If `excludeDocId` is set (edit mode), that document is skipped. Returns `true` if there is a conflict.
  - **`_closeRunningRecordWithEndTime(DateTime endTime)`:** Finds all records with `status == 'running'` and updates them to `status: 'completed'` and `endTime` set to the given `endTime` (stored as UTC).
  - **`startTimerWithCategory`:** Instead of `stopAllRunningRecords()`, it now calls `_closeRunningRecordWithEndTime(now)` with the same `now` used as the new record’s `startTime`, then creates the new running record.
- **main.dart (EditRecordSheet)**  
  - Before create or update, `_save()` calls `DatabaseService.instance.checkOverlapWithExistingRecords(start, end, excludeDocId: ...)`. If it returns `true`, the save is aborted and `_timeConflictError` is set to the message above.

---

## Русский

### Миссия 1: Восстановление кнопки микрофона (§5 Хирургическая строгость)

**Что:** Кнопка плавающего действия «Микрофон / речевой ввод» была скрыта, когда выбранная дата была «сегодня», из‑за обёртки `Visibility`, показывавшей FAB только когда выбранная дата была **раньше** проекционной «сегодня».

**Зачем:** Согласно §5 (Политика хирургической строгости), кнопку микрофона нельзя удалять или скрывать без явного запроса. Восстановление обеспечивает доступ к голосовому вводу на вкладке таймлайна и для сегодня, и для прошедших дат.

**Изменение:** В `lib/main.dart` FAB возвращён к исходному поведению: `floatingActionButton` устанавливается в кнопку микрофона, когда `!isFutureDate`, и в `null` при `isFutureDate`. Виджет `Visibility`, скрывавший кнопку в «сегодня», удалён, чтобы микрофон отображался и для сегодня, и для прошедших дат.

---

### Миссия 2: «Живая» математика в статистике (без сохранённой длительности)

**Что:** Агрегированная статистика должна считать длительность только как разницу между `endTime` и `startTime`. Любое предсохранённое или сохранённое поле длительности игнорируется, чтобы ручные правки начала/конца сразу отражались в итогах.

**Зачем:** Сохранённая длительность может устареть после правок. Использование только меток времени держит статистику в согласии с тем, что пользователь видит в диалоге редактирования.

**Изменение:** Изменение кода не потребовалось. `getAggregatedStats` в `lib/database_service.dart` уже использует `recordDurationSecondsWithinDayFromTimestamps`, который считает длительность только по `startTime` и `endTime` (или планетарному «сейчас» для активной записи) и не читает сохранённое поле длительности. Требование выполнено.

---

### Миссия 3: Окно редактирования «через полночь» (дата и время начала и конца)

**Что:** Диалог «Редактировать / Создать запись» изменён так, что:
- **Строка «Начало»:** рядом стоят выбор даты и выбор времени.
- **Строка «Конец»:** отдельно стоят вторая дата и второе время.
- По умолчанию обе даты совпадают с датой записи; дату конца можно изменить (например на следующий день) для записей через полночь.
- Собранные значения Start и End как `DateTime` передаются в логику сохранения.

**Зачем:** Нужно создавать и редактировать записи, переходящие через полночь (например 23:00–01:00 следующего дня). Одной даты и двух времени недостаточно — у конца должна быть своя дата.

**Изменение:** В `lib/main.dart` в `EditRecordSheet`:
- Состояние: добавлено `_endDate` (по умолчанию равно дате начала; в режиме редактирования берётся из времени конца записи).
- Добавлены геттеры `_effectiveStart` и `_effectiveEnd`, собирающие полные `DateTime` из выбранных даты и времени для начала и конца.
- Одна строка «Дата» и две «Время начала/конца» заменены на две строки:
  - **Начало:** кнопка даты (`_pickDate`) и кнопка времени (`_pickStartTime`).
  - **Конец:** кнопка даты (`_pickEndDate`) и кнопка времени (`_pickEndTime`).
- Добавлен `_pickEndDate()` с `firstDate: _recordDate`, чтобы дата конца не могла быть раньше даты начала.
- `_pickStartTime` и `_pickEndTime` при формировании `DateTime` используют соответственно `_recordDate` и `_endDate`.
- При сохранении используются `_effectiveStart` и `_effectiveEnd` для перевода в UTC, проверки пересечений и вызова записи/обновления.

---

### Миссия 4: Глобальная проверка пересечений и реле «призрачного» таймера

**Что:**  
1. **Универсальная проверка пересечений:** Перед сохранением новой или отредактированной записи новый интервал `[Start, End]` проверяется по всем релевантным записям в Firestore. При пересечении с любой существующей записью сохранение блокируется и в интерфейсе показывается: *«Time conflict! This overlaps with an existing record.»*  
2. **Правило реле (закрытие «призрака»):** При запуске нового таймера любая запись с `endTime == null` (например, оставшаяся «активная» запись с прошлого дня) закрывается установкой `endTime` в `startTime` новой задачи. Затем создаётся новая активная запись.

**Зачем:** Пересечения нарушают контракт NO_OVERLAP и путают статистику. Правило реле гарантирует не более одной «активной» записи и то, что предыдущий отрезок заканчивается ровно в момент начала нового.

**Изменение:**  
- **database_service.dart**
  - **`checkOverlapWithExistingRecords(DateTime start, DateTime end, {String? excludeDocId})`:** Запрашивает записи с `startTime < end`, затем в памяти проверяет, пересекается ли `[start, end]` с `[otherStart, otherEnd]` любой записи (для отсутствующего `endTime` используется планетарное «сейчас»). При редактировании документ с `excludeDocId` пропускается. Возвращает `true` при конфликте.
  - **`_closeRunningRecordWithEndTime(DateTime endTime)`:** Находит все записи с `status == 'running'` и обновляет их до `status: 'completed'` и `endTime`, установленного в переданное значение (в UTC).
  - **`startTimerWithCategory`:** Вместо `stopAllRunningRecords()` вызывается `_closeRunningRecordWithEndTime(now)` с тем же `now`, который используется как `startTime` новой записи, затем создаётся новая активная запись.
- **main.dart (EditRecordSheet)**  
  - Перед созданием или обновлением `_save()` вызывает `DatabaseService.instance.checkOverlapWithExistingRecords(start, end, excludeDocId: ...)`. При `true` сохранение отменяется и выставляется `_timeConflictError` с указанным сообщением.

---

## Manual test (EN)

1. **Mic:** Open timeline tab, select today. Confirm the mic FAB is visible and tap it to open voice input.
2. **Stats:** Edit a record’s start/end times and save. Open Stats for that day and confirm the updated duration appears (no stale stored duration).
3. **Midnight bridge:** Create or edit a record: set Start to yesterday 23:00, End to today 01:00 (use End date picker for today). Save and confirm the record shows the correct span and duration.
4. **Overlap:** Create or edit a record so its interval overlaps an existing one. Confirm save is blocked and the message *"Time conflict! This overlaps with an existing record."* appears.
5. **Ghost relay:** If you have a running record (e.g. from a previous day), start a new timer. Confirm the previous record gets an `endTime` equal to the new start time and only one running record exists.

## Ручная проверка (RU)

1. **Микрофон:** Откройте вкладку таймлайна, выберите сегодня. Убедитесь, что FAB микрофона виден и по нажатию открывается голосовой ввод.
2. **Статистика:** Измените время начала/конца записи и сохраните. Откройте статистику за этот день и убедитесь, что длительность обновилась (без устаревшего сохранённого значения).
3. **Через полночь:** Создайте или отредактируйте запись: начало вчера 23:00, конец сегодня 01:00 (дату конца выберите сегодня). Сохраните и убедитесь, что запись отображает верный интервал и длительность.
4. **Пересечение:** Создайте или отредактируйте запись так, чтобы интервал пересекался с существующей. Убедитесь, что сохранение блокируется и показывается сообщение о конфликте времени.
5. **Реле «призрака»:** При наличии активной записи (например с прошлого дня) запустите новый таймер. Убедитесь, что у предыдущей записи выставился `endTime`, равный новому времени начала, и активная запись осталась только одна.
