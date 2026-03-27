# The Entrance Build — Auth Gate & Seed Migration (EN + RU)

## English

### What This Build Does

This implements the "Front Door" of LIFE OS (Master Spec v1.6): the Brain (DatabaseService) only runs after the user is identified. That prevents the "wiped categories" issue where categories were tied to an anonymous or local user.

### Step 1: The Auth Gate (The Shell — main.dart)

- **StreamBuilder<User?>** listens to **FirebaseAuth.instance.authStateChanges()**.
- **connectionState == waiting:** The app shows the **INITIALIZATION_GUARD** loading screen (same as before: centered `CircularProgressIndicator`). No time input; minimalist.
- **snapshot.hasData == false:** The app shows **LandingPage** with a single **"Sign in with Google"** button. Tapping it triggers Google Sign-In and then **FirebaseAuth.signInWithCredential**. Auth logic lives in the Shell (LandingPage); no deletion of existing dashboard/mic/stats code.
- **snapshot.hasData == true:** The app initializes **DatabaseService** with **user.uid** by showing **_InitGuard(uid: snapshot.data!.uid)**. _InitGuard calls **DatabaseService.instance.loadInitialData(uid)** and, when it returns true, shows the **LifeOS dashboard** (HomeShell). Existing _stats map, microphone/STT logic, and Midnight Bridge code are **not modified**.

**Vault integrity:** Firebase Auth is used only in the Shell (StreamBuilder, LandingPage sign-in). The Brain receives `uid` via `loadInitialData(uid)` and does not import or call Firebase Auth.

### Step 2: Seed & Migration (The Brain — database_service.dart)

- **loadInitialData(String uid)** now takes the signed-in user's **uid**. It sets **\_currentUid = uid** so all Firestore paths use **users/{uid}/** (settings, records, plans, categories).
- **Categories load order:**
  1. Check **users/{uid}/categories** (root_tree). If it exists and has rules, load and use it.
  2. If it's empty, try to **read** **users/local/categories** (root_tree). We **never delete** users/local.
  3. If local has data, copy it into the current user's tree (patch empty IDs, then **\_saveRulesToFirestore()** → writes to **users/{uid}/categories** only).
  4. If local is also empty, trigger **SEED_CONTRACT**: inject **DefaultLifeOSSeed** and save to **users/{uid}/categories**.

So: **users/local** is only ever read from (migration source). It is never deleted or overwritten.

### Step 3: Time Protocol (Section 5)

- **LandingPage** and the **Loading** screen are minimalist and have **no time input**. If you add time pickers later, they must use **PICKER_FORCE** (e.g. `MediaQuery` builder with `alwaysUse24HourFormat: true`).

### Rules Respected

- **Strict preservation:** Existing _stats map and microphone/STT logic inside the LifeOS dashboard were not modified.
- **Vault integrity:** Firebase Auth is in the Shell; Brain only receives `uid` and uses it for paths.
- **No deletion:** The **users/local** path is never deleted; it is only read from for migration when the user's categories are empty.

---

## Русский

### Что делает эта сборка

Реализована «входная дверь» LIFE OS (Master Spec v1.6): «Мозг» (DatabaseService) запускается только после идентификации пользователя. Это предотвращает проблему «исчезнувших категорий», когда категории были привязаны к анонимному или локальному пользователю.

### Шаг 1: Auth Gate (Оболочка — main.dart)

- **StreamBuilder<User?>** подписан на **FirebaseAuth.instance.authStateChanges()**.
- **connectionState == waiting:** показывается экран загрузки **INITIALIZATION_GUARD** (как и раньше: центрированный `CircularProgressIndicator`). Без ввода времени; минималистично.
- **snapshot.hasData == false:** показывается **LandingPage** с одной кнопкой **«Sign in with Google»**. По нажатию выполняется вход через Google и **FirebaseAuth.signInWithCredential**. Логика авторизации в оболочке (LandingPage); код дашборда/микрофона/статистики не удалялся.
- **snapshot.hasData == true:** приложение инициализирует **DatabaseService** с **user.uid**, показывая **_InitGuard(uid: snapshot.data!.uid)**. _InitGuard вызывает **DatabaseService.instance.loadInitialData(uid)** и по возвращении true показывает **дашборд LifeOS** (HomeShell). Существующие _stats, логика микрофона/STT и код «полночного моста» **не изменялись**.

**Целостность хранилища:** Firebase Auth используется только в оболочке (StreamBuilder, кнопка входа на LandingPage). Мозг получает `uid` через `loadInitialData(uid)` и не импортирует/не вызывает Firebase Auth.

### Шаг 2: Сид и миграция (Мозг — database_service.dart)

- **loadInitialData(String uid)** принимает **uid** вошедшего пользователя. Устанавливается **\_currentUid = uid**; все пути Firestore используют **users/{uid}/** (настройки, records, plans, categories).
- **Порядок загрузки категорий:**
  1. Проверяется **users/{uid}/categories** (root_tree). Если есть и есть rules — загружаем и используем.
  2. Если пусто — **читаем** **users/local/categories** (root_tree). **users/local** никогда не удаляется.
  3. Если в local есть данные — копируем их в дерево текущего пользователя (дополняем пустые id, затем **\_saveRulesToFirestore()** — запись только в **users/{uid}/categories**).
  4. Если local тоже пуст — срабатывает **SEED_CONTRACT**: подставляется **DefaultLifeOSSeed** и сохраняется в **users/{uid}/categories**.

Путь **users/local** только читается (источник миграции). Он не удаляется и не перезаписывается.

### Шаг 3: Временной протокол (раздел 5)

- **LandingPage** и экран **Loading** минималистичны и **не содержат ввода времени**. Если позже добавите выбор времени — нужно соблюдать **PICKER_FORCE** (например, обёртка `MediaQuery` с `alwaysUse24HourFormat: true`).

### Соблюдённые правила

- **Строгое сохранение:** существующие _stats и логика микрофона/STT в дашборде не менялись.
- **Целостность хранилища:** Firebase Auth в оболочке; Мозг только получает `uid` и использует его для путей.
- **Без удаления:** путь **users/local** не удаляется; он только читается при миграции, когда категории пользователя пусты.

---

## Manual test (EN)

1. Run the app. You should see the Landing page with "Sign in with Google".
2. Tap "Sign in with Google" and complete sign-in. After auth, the loading spinner appears, then the LifeOS dashboard (Timeline/Planning).
3. Confirm the mic button and stats are unchanged. Create/edit a record with the midnight-bridge (Start/End date+time) and save — behaviour unchanged.
4. Sign out (if you add a sign-out button in Settings) and confirm you return to the Landing page.

## Ручная проверка (RU)

1. Запустите приложение. Должна отображаться посадочная страница с кнопкой «Sign in with Google».
2. Нажмите «Sign in with Google» и войдите. После авторизации появится индикатор загрузки, затем дашборд LifeOS (Таймлайн/Планирование).
3. Убедитесь, что кнопка микрофона и статистика работают как раньше. Создайте/отредактируйте запись с разными датами начала и конца — поведение без изменений.
4. Выйдите из учётной записи (если добавите кнопку выхода в Настройках) и убедитесь, что возвращаетесь на посадочную страницу.
