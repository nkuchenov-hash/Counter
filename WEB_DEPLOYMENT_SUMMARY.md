# Web deployment — summary (EN + RU)

## English

### What was done (§5 Surgical Strictness)

- **No mobile code was deleted or modified** except for two additive, non-destructive changes:
  1. **Mic on Web:** At the very start of `_startVoiceInput()` a `kIsWeb` check was added. On web, the method shows the snackbar *"Web support coming soon"* and returns. The Mic FAB is still visible on web; it does not open the voice sheet or call `Permission.microphone` or speech_to_text on web.
  2. **Speech init on Web:** At the start of `_ensureSpeechReady()` a `kIsWeb` check was added so we do not call `_speech.initialize()` on web. This avoids platform-specific issues; mobile behaviour is unchanged.

- **Midnight Bridge and all other UI** (Edit/Create record with Start/End date+time rows, collision logic, etc.) were not touched.

- **database_service.dart** was not modified. Firebase continues to work via existing `kIsWeb` usage in `main.dart` and `firebase_options.dart`.

### M1 — Web initialization

- Ran `flutter create . --platforms web` to ensure web platform is enabled.
- **index.html** already included Firebase JS SDK 11.x (v9+ compat). A short comment was added to clarify that.

### M2 — Build & Firebase Hosting

- **Build command:**  
  `flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_CANVAS=true`  
  (Run this in the project root; output is in `build/web`.)

- **Hosting config (non-interactive):**  
  - `firebase.json`: `public` = `build/web`, single-page app rewrites (`**` → `/index.html`).  
  - `.firebaserc`: default project = `lifeos-f60e7`.

- **If you have not run Firebase init before:**  
  You can run `firebase init hosting` and choose:  
  - Public directory: `build/web`  
  - Single-page app: Yes  
  - GitHub Actions: No  
  Or keep the created `firebase.json` / `.firebaserc` as-is.

- **Deploy:**  
  `firebase deploy --only hosting`

- **Live URL after deploy:**  
  - **https://lifeos-f60e7.web.app**  
  - Or **https://lifeos-f60e7.firebaseapp.com**

### M3 — Mic web compatibility

- The Mic button is **not removed** on any platform.
- On **web:** Tapping the Mic FAB shows the snackbar *"Web support coming soon"* and returns. No `Permission.microphone` or speech_to_text code runs on web.
- On **mobile:** Behaviour is unchanged; permission and voice sheet work as before.

---

## Русский

### Что сделано (§5 Хирургическая строгость)

- **Мобильный код не удалялся и не менялся**, за исключением двух добавлений:
  1. **Микрофон на Web:** В самом начале `_startVoiceInput()` добавлена проверка `kIsWeb`. На web метод показывает снекбар *"Web support coming soon"* и выходит. Кнопка микрофона на web по-прежнему видна; голосовой лист и вызовы `Permission.microphone` / speech_to_text на web не выполняются.
  2. **Инициализация речи на Web:** В начале `_ensureSpeechReady()` добавлена проверка `kIsWeb`, чтобы не вызывать `_speech.initialize()` на web. Мобильное поведение не изменилось.

- **«Полночный мост» и весь остальной UI** (диалог редактирования с датой/временем начала и конца, проверка пересечений и т.д.) не трогались.

- **database_service.dart** не менялся. Firebase по-прежнему используется через существующие проверки `kIsWeb` в `main.dart` и `firebase_options.dart`.

### M1 — Инициализация Web

- Выполнена команда `flutter create . --platforms web`.
- В **index.html** уже были подключены скрипты Firebase JS SDK 11.x (совместимы с v9+). Добавлен короткий комментарий.

### M2 — Сборка и Firebase Hosting

- **Команда сборки:**  
  `flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_CANVAS=true`  
  (запускать из корня проекта; результат в `build/web`.)

- **Конфиг хостинга:**  
  - `firebase.json`: каталог `build/web`, реврайты для SPA.  
  - `.firebaserc`: проект по умолчанию `lifeos-f60e7`.

- **Деплой:**  
  `firebase deploy --only hosting`

- **URL после деплоя:**  
  - **https://lifeos-f60e7.web.app**  
  - или **https://lifeos-f60e7.firebaseapp.com**

### M3 — Микрофон на Web

- Кнопка микрофона **нигде не удалена**.
- На **web:** нажатие на FAB микрофона показывает снекбар *"Web support coming soon"* и выход. На web не выполняется код разрешений и speech_to_text.
- На **мобильных** поведение без изменений.
