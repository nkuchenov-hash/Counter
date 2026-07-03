"""Curated meaningful RU for key files — merged in finalize_file_guide."""

from __future__ import annotations

FILE_RU_CURATED: dict[str, dict[str, str]] = {
    ".github/workflows/deploy.yml": {
        "what_ru": "Workflow GitHub Actions для публикации web-версии. После push собирает Flutter web с base href `/Counter/` и выкладывает на GitHub Pages.",
        "why_ru": "Автоматизирует deploy сайта без ручного `update.ps1` на CI runner.",
        "contains_ru": "Шаги checkout, `flutter build web`, deploy в `gh-pages` branch.",
        "responsibilities_ru": "Собрать и опубликовать web build при push в main.",
        "when_ru": "Сайт не обновился после merge; проверка CI deploy log.",
        "connected_ru": "`docs/DEPLOY.md`, `update.ps1`, `web/index.html`.",
        "layer_ru": "CI deploy — не runtime приложения.",
    },
    ".github/copilot-instructions.md": {
        "what_ru": "Краткие правила для GitHub Copilot внутри repo — главные ограничения проекта.",
        "why_ru": "Copilot видит architecture laws и не предлагает запрещённые PocketBase/Brain паттерны.",
        "contains_ru": "Markdown с iron rules, ссылками на governing docs.",
        "responsibilities_ru": "Сжатый контекст для Copilot в GitHub UI.",
        "when_ru": "Copilot предлагает refactor, ломающий Brain/UI или optimistic UI.",
        "connected_ru": "`.github/`, `docs/ARCHITECTURE.md`.",
        "layer_ru": "AI instructions — не runtime.",
    },
    "android/app/src/main/kotlin/com/example/counter/MainActivity.kt": {
        "what_ru": "Минимальная Android-точка входа. Android запускает Activity, она поднимает Flutter engine и показывает Dart-UI.",
        "why_ru": "Без Activity APK не может показать Flutter интерфейс после tap по иконке.",
        "contains_ru": "Subclass `FlutterActivity` — несколько строк Kotlin.",
        "responsibilities_ru": "Boot Flutter engine при старте приложения на Android.",
        "when_ru": "Crash on launch Android, deep links на native layer.",
        "connected_ru": "`AndroidManifest.xml`, Flutter Android embedding.",
        "layer_ru": "Android entry — не Dart business logic.",
    },
    "android/app/src/main/res/drawable/launch_background.xml": {
        "what_ru": "XML-фон стартового экрана Android — показывается до первого Flutter frame.",
        "why_ru": "Убирает белую вспышку при cold start пока Flutter рисует UI.",
        "contains_ru": "Layer-list drawable с цветом/картинкой splash.",
        "responsibilities_ru": "Native splash до появления Flutter content.",
        "when_ru": "Белый flash при launch, wrong splash color на Android.",
        "connected_ru": "`styles.xml`, `AndroidManifest` theme.",
        "layer_ru": "Android splash resource.",
    },
    "android.ps1": {
        "what_ru": "Локальная сборка Android release APK — split per ABI со штампом git commit в About.",
        "why_ru": "Короче ручного `flutter build apk`; подставляет `GIT_COMMIT` и `BUILD_TIME`.",
        "contains_ru": "`flutter pub get` → `flutter build apk --release --split-per-abi`; retry `--no-tree-shake-icons`.",
        "responsibilities_ru": "APK в `build/app/outputs/flutter-apk/` (`app-arm64-v8a-release.apk` для телефонов).",
        "when_ru": "Тест release APK на физическом Android.",
        "connected_ru": "`android/` Gradle, `lib/core/app_build_info.dart`.",
        "layer_ru": "Сборка Android — не runtime логика.",
    },
}
