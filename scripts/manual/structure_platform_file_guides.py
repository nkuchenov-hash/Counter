"""Concrete EN+RU guides for Tier C platform/installer files — no generic wrappers."""

from __future__ import annotations

from pathlib import PurePosixPath

from structure_ru_class_adapters import (
    has_semi_russian_or_english_leak,
    ru_prose_ok,
    sanitize_ru_prose,
)
from structure_en_ru_adapt import has_banned_filler
from structure_ru_helpers import cyrillic_count

# Exact paths — owner-reviewed examples and high-traffic platform files.
PLATFORM_PATH_GUIDES: dict[str, dict[str, str]] = {
    "windows/runner/main.cpp": {
        "what": "Точка входа native C++ Windows-приложения. Создаёт Win32 window, инициализирует Flutter engine и запускает Dart UI.",
        "why": "Windows `.exe` стартует отсюда: без `main()` Flutter desktop не поднимет окно Counter.",
        "contains": "`wWinMain`/`main`, вызовы создания окна и `flutter::FlutterViewController`.",
        "responsibilities": "Старт Windows runner: Win32 host и bootstrap Flutter engine.",
        "when": "Windows `.exe` не стартует, crash до первого кадра Flutter, неверный entry point.",
        "connected": "`windows/runner/flutter_window.cpp`, `windows/CMakeLists.txt`.",
        "layer": "Windows native entry — не Dart business logic.",
        "delete": "Нет — без него Windows `.exe` не запустится.",
    },
    "windows/CMakeLists.txt": {
        "what": "Главный CMake-файл Windows desktop runner. Описывает native targets, source files и link rules, через которые Flutter engine собирается в Windows `.exe`.",
        "why": "CMake configure/link связывает `runner/`, `flutter/` glue и plugin registrant в один desktop binary.",
        "contains": "`project()`, `add_subdirectory(flutter)`, `add_subdirectory(runner)`, toolchain settings.",
        "responsibilities": "Собрать Counter Windows `.exe` из native runner + Flutter AOT.",
        "when": "Windows desktop build падает на configure/link; installer не получит рабочий runner.",
        "connected": "`windows/runner/CMakeLists.txt`, `windows/flutter/CMakeLists.txt`.",
        "layer": "Windows native build — не Dart UI.",
        "delete": "Нет — без него `flutter build windows` не соберёт `.exe`.",
    },
    "installer/windows/prepare_stt_payload.ps1": {
        "what": "PowerShell-скрипт подготовки STT payload для Windows installer. Копирует/проверяет helper exe, model files и runtime payload перед сборкой Inno Setup.",
        "why": "Inno Setup script ожидает готовый STT bundle рядом с Flutter build — иначе installed app не найдёт speech helper.",
        "contains": "Шаги копирования `counter_stt_helper.exe`, моделей и runtime файлов в layout installer.",
        "responsibilities": "Подготовить STT файлы для `counter.iss` перед сборкой setup.",
        "when": "Installed app не видит speech helper; перед локальной сборкой `CounterSetup.exe`.",
        "connected": "`installer/windows/counter.iss`, `build_stt_helper_en.ps1`, `stt_helper_build/`.",
        "layer": "Windows installer prep — не runtime Dart.",
        "delete": "Нет — без него installer STT bundle неполный.",
    },
    "installer/windows/build_stt_helper_en.ps1": {
        "what": "PowerShell-сборка English STT helper для installer. Нужна, чтобы `counter_stt_helper.exe` попал в setup package, а desktop voice работал после установки.",
        "why": "Desktop voice на Windows вызывает GOLOS STT subprocess — exe должен быть собран до Inno Setup.",
        "contains": "Команды сборки/копирования `counter_stt_helper.exe` в `stt_helper_build/`.",
        "responsibilities": "Собрать или обновить STT helper binary для installer payload.",
        "when": "Voice работает в dev, но не в installed app; после обновления STT toolchain.",
        "connected": "`prepare_stt_payload.ps1`, `stt_helper_build/counter_stt_helper.exe`.",
        "layer": "Windows STT build script — не runtime Dart.",
        "delete": "Нет — без него installer не получит свежий STT helper.",
    },
    "installer/windows/stt_helper_build/counter_stt_helper.exe": {
        "what": "Собранный STT helper binary, который installer кладёт рядом с Windows-приложением. Desktop voice вызывает его как subprocess для transcription.",
        "why": "Installed Counter на Windows не использует mobile STT API — нужен отдельный native helper exe.",
        "contains": "Скомпилированный GOLOS STT helper (English) для subprocess voice pipeline.",
        "responsibilities": "Transcription subprocess для desktop voice после установки через setup.",
        "when": "Installed app: voice mic работает, но transcription пустая или helper not found.",
        "connected": "`lib/shared/voice/platforms/desktop/desktop_stt_helper_service.dart`, `prepare_stt_payload.ps1`.",
        "layer": "Windows STT binary — не Dart UI.",
        "delete": "Нет — удаление ломает voice в installed app.",
    },
    "android/gradle/wrapper/gradle-wrapper.properties": {
        "what": "Gradle Wrapper properties для Android build. Фиксирует Gradle distribution URL/version, чтобы CI и локальная машина запускали одну и ту же Gradle-версию.",
        "why": "Без pinned Gradle version Android sync на CI и у разработчика расходятся.",
        "contains": "`distributionUrl`, `distributionSha256Sum` для Gradle wrapper.",
        "responsibilities": "Pin Gradle distribution для всего `android/` tree.",
        "when": "Gradle wrapper version mismatch; CI Android build использует другую Gradle.",
        "connected": "`android/gradlew`, `android/settings.gradle.kts`.",
        "layer": "Android Gradle wrapper — не Dart.",
        "delete": "Нет — без него `./gradlew` не скачает нужную Gradle.",
    },
    "ios/Flutter/Debug.xcconfig": {
        "what": "Xcode build configuration для Flutter iOS target (Debug). Передаёт Flutter/CocoaPods settings в Debug сборку.",
        "why": "Xcode читает xcconfig при сборке Runner Debug — без него Flutter flags не попадут в compile.",
        "contains": "#include Flutter generated settings, Debug preprocessor flags.",
        "responsibilities": "Debug compile flags и пути Flutter engine для iOS.",
        "when": "Debug iOS build или pod integration падает после Flutter upgrade.",
        "connected": "`ios/Podfile`, `ios/Flutter/Release.xcconfig`, Xcode Runner target.",
        "layer": "Flutter iOS generated config — не править вручную без причины.",
        "delete": "Нет — без него Debug iOS build или pod integration падает.",
    },
    "ios/Flutter/Release.xcconfig": {
        "what": "Xcode build configuration для Flutter iOS target (Release). Передаёт Flutter/CocoaPods settings в Release/IPA сборку.",
        "why": "Release archive/TestFlight использует эти flags для AOT и stripped build.",
        "contains": "#include Flutter generated settings, Release optimization flags.",
        "responsibilities": "Release compile flags и пути Flutter engine для iOS IPA.",
        "when": "Release iOS archive или TestFlight build падает после Flutter upgrade.",
        "connected": "`ios/Podfile`, `ios/Flutter/Debug.xcconfig`, Xcode Runner target.",
        "layer": "Flutter iOS generated config — не править вручную без причины.",
        "delete": "Нет — без него Release iOS build или pod integration падает.",
    },
    "ios/Runner.xcodeproj/project.pbxproj": {
        "what": "Главная project database Xcode для iOS Runner. Хранит targets, build phases, signing/build settings и ссылки на resources.",
        "why": "Xcode открывает и собирает IPA только через корректный `project.pbxproj`.",
        "contains": "PBX targets, build phases, file references, code signing settings.",
        "responsibilities": "Описать iOS Runner target, resources и build pipeline для IPA.",
        "when": "Xcode-проект не открывается, scheme/signing errors, missing file references.",
        "connected": "`ios/Runner/`, `ios/Flutter/`, CocoaPods workspace.",
        "layer": "Xcode iOS project database — не Dart.",
        "delete": "Нет — повреждение файла ломает iOS Xcode-проект и IPA build.",
    },
    "macos/Runner.xcodeproj/project.pbxproj": {
        "what": "Главная project database Xcode для macOS Runner. Хранит targets, resources, entitlements, signing и build phases для `.app` bundle.",
        "why": "macOS desktop Counter собирается через этот Xcode-проект в `.app` bundle.",
        "contains": "PBX targets, entitlements refs, asset catalogs, macOS signing settings.",
        "responsibilities": "Описать macOS Runner target и build pipeline для `.app`.",
        "when": "macOS Xcode build/sign errors; project corruption после merge.",
        "connected": "`macos/Runner/`, `macos/Flutter/`, entitlements plist.",
        "layer": "Xcode macOS project database — не Dart.",
        "delete": "Нет — без него macOS `.app` не соберётся в Xcode.",
    },
    "windows/runner/resources/app_icon.ico": {
        "what": "ICO-иконка Windows runner. Встраивается в native `.exe` и installer, чтобы Counter имел правильную иконку в taskbar, Explorer и Start menu.",
        "why": "Win32 resource compiler и Inno Setup берут этот ICO для branding установленного app.",
        "contains": "Multi-size ICO raster для Windows shell icons.",
        "responsibilities": "Иконка Counter в taskbar, Explorer, Start menu и setup wizard.",
        "when": "Неверная или дефолтная Flutter иконка на Windows desktop/installer.",
        "connected": "`windows/runner/Runner.rc`, `installer/windows/counter.iss`.",
        "layer": "Windows icon asset — не Dart.",
        "delete": "Нет — `.exe`/installer покажут дефолтную или пустую иконку.",
    },
}


def _plat_meta(p: str) -> dict[str, str]:
    plat = p.split("/")[0]
    parent = PurePosixPath(p).parent.as_posix()
    meta = {
        "android": {
            "tool": "Gradle/Android Gradle Plugin",
            "artifact": "APK/AAB Counter",
            "delete": "Нет — без него не соберётся Android APK.",
        },
        "ios": {
            "tool": "Xcode/CocoaPods",
            "artifact": "iOS IPA/TestFlight build",
            "delete": "Нет — без него не соберётся iOS IPA.",
        },
        "macos": {
            "tool": "Xcode",
            "artifact": "macOS `.app` bundle",
            "delete": "Нет — без него не соберётся macOS `.app`.",
        },
        "windows": {
            "tool": "CMake/Win32 runner",
            "artifact": "Windows `.exe`",
            "delete": "Нет — без него не соберётся Windows `.exe`.",
        },
        "linux": {
            "tool": "CMake/GTK runner",
            "artifact": "Linux desktop binary",
            "delete": "Нет — без него не соберётся Linux desktop binary.",
        },
        "web": {
            "tool": "Flutter web tool",
            "artifact": "GitHub Pages web build",
            "delete": "Нет — без него не соберётся web deploy.",
        },
        "installer": {
            "tool": "Inno Setup/packaging scripts",
            "artifact": "`CounterSetup.exe` installer",
            "delete": "Нет — без него не соберётся Windows installer.",
        },
    }
    base = meta.get(plat, {"tool": "Flutter platform tool", "artifact": f"{plat} build", "delete": "Нет — нужен для platform build."})
    base = dict(base)
    base["plat"] = plat
    base["parent"] = parent
    return base


def _heuristic_guide(p: str, name: str) -> dict[str, str] | None:
    m = _plat_meta(p)
    plat = m["plat"]
    parent = m["parent"]
    tool = m["tool"]
    artifact = m["artifact"]
    lower = name.lower()

    if lower == "main.cc" and plat == "linux":
        return {
            "what": "Native C entry point Linux GTK runner — создаёт окно и запускает Flutter engine для desktop Counter.",
            "why": "Linux desktop binary стартует отсюда; без entry point Flutter UI не поднимется.",
            "contains": "`main()` и вызовы GTK/Flutter embedding bootstrap.",
            "responsibilities": "Cold start Linux runner — GTK host + Flutter engine.",
            "when": "Linux desktop binary не стартует или crash до первого Flutter frame.",
            "connected": "`linux/runner/`, `linux/CMakeLists.txt`.",
            "layer": "Linux native entry — не Dart.",
            "delete": m["delete"],
        }

    if lower in ("flutter_window.cpp", "win32_window.cpp"):
        return {
            "what": f"Native C++ Win32 window glue (`{name}`) — создаёт/обслуживает HWND, куда Flutter рисует UI.",
            "why": "Flutter engine на Windows нуждается в Win32 surface; этот файл держит message loop окна.",
            "contains": "Классы/функции создания окна, resize, DPI и Flutter view attach.",
            "responsibilities": f"Win32 window lifecycle для Counter desktop через `{name}`.",
            "when": "Окно не появляется, wrong DPI/resize, native crash в window code.",
            "connected": "`windows/runner/main.cpp`, `windows/runner/CMakeLists.txt`.",
            "layer": "Windows native window — не Dart.",
            "delete": m["delete"],
        }

    if lower == "utils.cpp" and plat == "windows":
        return {
            "what": "Native C++ utilities Windows runner — UTF-8/Win32 helpers для desktop host.",
            "why": "Runner использует общие helpers при создании окна и консольных сообщениях сборки.",
            "contains": "Small Win32/UTF-8 helper functions linked в runner target.",
            "responsibilities": "Support code для Win32 runner — не business logic Counter.",
            "when": "Compile/link errors ссылаются на `utils.cpp`.",
            "connected": "`windows/runner/main.cpp`, `windows/runner/CMakeLists.txt`.",
            "layer": "Windows native helper — не Dart.",
            "delete": m["delete"],
        }

    if lower == "runner.rc" or (lower.endswith(".rc") and plat == "windows"):
        return {
            "what": "Win32 resource script — встраивает ICO, version info и manifest в Windows `.exe`.",
            "why": "Resource compiler читает `.rc`, чтобы `.exe` имел иконку и metadata в Explorer.",
            "contains": "Ссылки на `app_icon.ico`, VERSIONINFO, application manifest.",
            "responsibilities": "Embed icons/version into Counter Windows binary.",
            "when": "Неверная иконка/version в Properties `.exe`; RC compile errors.",
            "connected": "`windows/runner/resources/app_icon.ico`, `windows/runner/CMakeLists.txt`.",
            "layer": "Windows resources — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".manifest") and plat == "windows":
        return {
            "what": "Win32 application manifest — DPI awareness и compatibility flags для Windows `.exe`.",
            "why": "Windows loader читает manifest для Per-Monitor DPI и UAC behavior.",
            "contains": "XML assembly manifest для runner executable.",
            "responsibilities": "Метаданные DPI/compatibility, встроенные в `.exe`.",
            "when": "Blurry UI на high-DPI Windows; manifest merge errors при link.",
            "connected": "`windows/runner/Runner.rc`, CMake runner target.",
            "layer": "Windows manifest — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".xcconfig"):
        variant = "Debug" if "debug" in lower else "Release" if "release" in lower else "Warnings/AppInfo"
        scope = "Flutter iOS" if plat == "ios" and "/flutter/" in p.lower() else (
            "Flutter macOS" if plat == "macos" and "/flutter/" in p.lower() else f"Xcode {plat} Runner"
        )
        return {
            "what": f"Xcode build configuration ({variant}) для {scope}. Передаёт Flutter/CocoaPods/compiler settings в сборку.",
            "why": f"Xcode подхватывает flags из xcconfig — без них {artifact} может не собраться.",
            "contains": f"`#include` generated Flutter settings и {variant} compiler flags.",
            "responsibilities": f"Прокинуть Flutter/native build settings в {variant} {plat} compile.",
            "when": f"{plat} build или pod integration падает после Flutter/Xcode upgrade.",
            "connected": f"`{plat}/Podfile`, `{plat}/Flutter/`, Xcode Runner target.",
            "layer": f"Xcode/{plat} build config — не Dart UI.",
            "delete": m["delete"],
        }

    if lower == "podfile":
        return {
            "what": f"CocoaPods recipe для {plat} Flutter plugins — platform version и Flutter pod hook.",
            "why": f"`pod install` читает Podfile, чтобы подключить native iOS/macOS plugins к Runner.",
            "contains": "Platform iOS/macOS version, `flutter_install_all_ios_pods` hook.",
            "responsibilities": f"Resolve native plugin dependencies для {artifact}.",
            "when": f"`pod install` fail; plugin native code missing в {plat} build.",
            "connected": f"`{plat}/Flutter/`, `{plat}/Runner.xcodeproj/`.",
            "layer": f"CocoaPods config {plat} — не Dart.",
            "delete": m["delete"],
        }

    if lower == "podfile.lock":
        return {
            "what": f"Lockfile CocoaPods для {plat} — pinned versions native pods после `pod install`.",
            "why": "Фиксирует версии pods, чтобы CI и локальная машина собирали одинаковый native stack.",
            "contains": "Pinned pod versions и checksums.",
            "responsibilities": f"Reproducible CocoaPods resolve для {artifact}.",
            "when": f"Pod version drift; CI {plat} build отличается от локального.",
            "connected": f"`{plat}/Podfile`, `{plat}/Runner.xcodeproj/`.",
            "layer": f"CocoaPods lock {plat} — commit для reproducibility.",
            "delete": "Возможно — пересоздаётся `pod install`, но commit нужен для CI parity.",
        }

    if lower.endswith(".xcscheme"):
        return {
            "what": f"Xcode scheme `{name}` — какой target/configuration Xcode запускает для {plat} Runner.",
            "why": "Run/Archive/Test в Xcode используют scheme; без него team не соберёт {artifact}.",
            "contains": "Build/run/test actions, selected target Runner, configuration Debug/Release.",
            "responsibilities": f"Developer workflow: Run/Archive {artifact} из Xcode.",
            "when": "Scheme missing в Xcode; Archive использует wrong configuration.",
            "connected": f"`{plat}/Runner.xcodeproj/`, `{plat}/Runner/`.",
            "layer": f"Xcode scheme {plat} — developer workflow.",
            "delete": m["delete"],
        }

    if lower.endswith(".xcworkspacedata"):
        return {
            "what": f"Xcode workspace metadata для {plat} — связывает Runner project и CocoaPods workspace.",
            "why": "Xcode открывает `.xcworkspace`, а не `.xcodeproj`, когда подключены Flutter pods.",
            "contains": "File references на Runner project и Pods.",
            "responsibilities": f"IDE workspace glue для {tool} + Flutter pods.",
            "when": f"Xcode workspace не открывается; CocoaPods integration broken на {plat}.",
            "connected": f"`{plat}/Runner.xcodeproj/`, `{plat}/Podfile`.",
            "layer": f"Xcode workspace {plat} — IDE metadata.",
            "delete": m["delete"],
        }

    if lower.endswith(".swift"):
        role = "AppDelegate/Flutter glue"
        if "test" in lower:
            role = "XCTest smoke entry"
        elif "mainflutterwindow" in lower.replace("_", ""):
            role = "macOS Flutter window host"
        return {
            "what": f"Swift native glue ({role}) для {plat} Runner — старт Flutter engine и lifecycle hooks.",
            "why": f"Apple runner target вызывает Swift glue до первого Dart frame в {artifact}.",
            "contains": f"Swift-классы embedding Flutter на {plat}.",
            "responsibilities": f"Native lifecycle/window hooks между Apple OS и Flutter engine на {plat}.",
            "when": f"Crash on launch {plat}; plugin registration или window lifecycle issues.",
            "connected": f"`{plat}/Runner/Info.plist`, Flutter embedder.",
            "layer": f"{plat} Swift glue — не Dart UI.",
            "delete": m["delete"],
        }

    if lower.endswith(".storyboard") or lower.endswith(".xib"):
        return {
            "what": f"Launch UI storyboard/xib для {plat} Runner — native splash до первого Flutter frame.",
            "why": f"Apple показывает launch screen из storyboard/xib пока Flutter engine грузит UI.",
            "contains": f"Interface Builder layout launch screen для {plat}.",
            "responsibilities": f"Native launch appearance {plat} — не Dart widgets.",
            "when": f"Launch flash/orientation wrong на {plat}; missing launch screen.",
            "connected": f"`{plat}/Runner/Info.plist`, asset catalogs.",
            "layer": f"{plat} launch UI — native only.",
            "delete": m["delete"],
        }

    if lower.endswith(".entitlements"):
        return {
            "what": f"Entitlements plist macOS/iOS — sandbox, hardened runtime, keychain, mic permissions для signing.",
            "why": f"Codesign embeds entitlements в {artifact}; без них notarization/App Store reject.",
            "contains": "XML entitlement keys для sandbox, network, mic, etc.",
            "responsibilities": f"Declare OS capabilities allowed in signed {artifact}.",
            "when": f"Signing/notarization fail; capability missing at runtime на {plat}.",
            "connected": f"`{plat}/Runner.xcodeproj/`, signing settings.",
            "layer": f"{plat} signing entitlements — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".h") and ("generated_plugin" in lower or "flutter" in parent):
        return {
            "what": f"C/C++ header `{name}` — declares Flutter plugin registrant или engine glue для {plat}.",
            "why": f"Native {plat} runner includes этот header при linking plugin registration.",
            "contains": f"Decls для generated registrant / Flutter window API.",
            "responsibilities": f"Compile-time declarations для Flutter plugins на {plat}.",
            "when": f"Missing symbol / include errors при {plat} native compile.",
            "connected": f"`{plat}/flutter/`, `{plat}/runner/`, `pubspec.yaml` plugins.",
            "layer": f"Generated/native header {plat}.",
            "delete": m["delete"],
        }

    if lower.endswith((".cc", ".cpp")) and "runner" in parent:
        return {
            "what": f"Native C++ source `{name}` — часть {tool} runner, собирающего {artifact}.",
            "why": f"CMake/MSBuild компилирует этот файл в native host, который держит Flutter engine.",
            "contains": f"C++ implementation для {parent} runner target.",
            "responsibilities": f"Native host behavior для {artifact} (окно, plugins, utils).",
            "when": f"Native compile/link error ссылается на `{name}`.",
            "connected": f"`{parent}/CMakeLists.txt`, `{plat}/flutter/`.",
            "layer": f"{plat} native runner source — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".cmake") or lower == "generated_plugins.cmake":
        return {
            "what": f"CMake fragment `{name}` — Flutter-generated plugin build rules для {plat} desktop.",
            "why": "Flutter tool генерирует CMake glue, чтобы plugins линковались в desktop runner.",
            "contains": "add_subdirectory/target rules для plugins и registrant.",
            "responsibilities": f"Wire Flutter plugins into {artifact} native build.",
            "when": f"Plugin link fail на {plat} после `flutter pub get` или upgrade.",
            "connected": f"`{plat}/CMakeLists.txt`, `pubspec.yaml` plugins.",
            "layer": f"Flutter-generated CMake {plat}.",
            "delete": m["delete"],
        }

    if lower == "gradle-wrapper.jar":
        return {
            "what": "Gradle Wrapper JAR — bootstrap, который скачивает pinned Gradle для Android build.",
            "why": " `./gradlew` запускает wrapper jar, который читает `gradle-wrapper.properties`.",
            "contains": "Binary wrapper JAR (Gradle project standard).",
            "responsibilities": "Bootstrap Gradle distribution для `android/` tree.",
            "when": "Wrapper JAR corrupt; `./gradlew` не стартует.",
            "connected": "`android/gradle/wrapper/gradle-wrapper.properties`, `android/gradlew`.",
            "layer": "Android Gradle wrapper binary.",
            "delete": "Нет — без JAR `./gradlew` не работает.",
        }

    if lower in ("gradlew", "gradlew.bat"):
        return {
            "what": f"Gradle Wrapper launcher script (`{name}`) — entry для Android builds без глобального Gradle.",
            "why": "CI и dev machines вызывают wrapper script вместо system Gradle.",
            "contains": "Shell/batch stub, запускающий wrapper JAR.",
            "responsibilities": "Start pinned Gradle for `android/` builds.",
            "when": "Permission or path errors running `./gradlew`.",
            "connected": "`android/gradle/wrapper/`, `android/settings.gradle.kts`.",
            "layer": "Android Gradle wrapper script.",
            "delete": "Нет — без него стандартный Android build path ломается.",
        }

    if lower == "local.properties":
        return {
            "what": "Local Gradle properties — путь к Android SDK/NDK на машине разработчика (обычно gitignored).",
            "why": "Gradle ищет SDK path здесь; без него Android sync fail на новой машине.",
            "contains": "`sdk.dir=` и optional NDK paths.",
            "responsibilities": "Point Gradle to local Android SDK install.",
            "when": "Android Studio sync: SDK location not found.",
            "connected": "`android/settings.gradle.kts`, `android/app/build.gradle.kts`.",
            "layer": "Local Android dev config — не commit secrets.",
            "delete": "Возможно локально — пересоздаётся Android Studio, но нужен для build.",
        }

    if lower.endswith(".ps1"):
        stem = name.replace(".ps1", "").replace("_", " ")
        if plat == "installer":
            return {
                "what": f"PowerShell script `{name}` — шаг installer/STT pipeline для Windows setup package.",
                "why": f"Inno Setup/CI вызывает этот script перед упаковкой {artifact}.",
                "contains": f"PowerShell commands для `{stem}` workflow.",
                "responsibilities": f"Automate installer prep step: `{stem}`.",
                "when": f"Windows installer build fail на step `{name}`.",
                "connected": "`installer/windows/counter.iss`, `docs/DEPLOY.md`.",
                "layer": "Windows installer script — не runtime Dart.",
                "delete": m["delete"],
            }

    if lower.endswith(".xml") and plat == "android" and "/res/" in p:
        res_kind = "values" if "/values" in parent else "drawable" if "/drawable" in parent else "layout" if "/layout" in parent else "Android resource"
        return {
            "what": f"Android XML resource `{name}` ({res_kind}) — native UI chrome/splash/strings для APK.",
            "why": "Android packaging merges `res/` into APK before Flutter draws first frame.",
            "contains": f"XML resource definitions in `{parent}`.",
            "responsibilities": f"Native Android {res_kind} consumed by manifest/themes/splash.",
            "when": f"Wrong splash/strings/theme on Android referencing `{name}`.",
            "connected": "`AndroidManifest.xml`, `android/app/src/main/res/`.",
            "layer": "Android resource XML — не Dart.",
            "delete": "Нет — missing resource может сломать APK merge.",
        }

    if lower.endswith(".png"):
        if plat == "web":
            size_hint = name.replace("Icon-", "").replace(".png", "")
            return {
                "what": f"Web/PWA PNG icon `{name}` — браузер/manifest используют для tab/install tile.",
                "why": f"GitHub Pages PWA picks closest size ({size_hint}) for install banner.",
                "contains": f"Square PNG asset for web manifest.",
                "responsibilities": f"Branding Counter web app at {size_hint}px.",
                "when": "Missing/wrong icon on web tab or PWA install prompt.",
                "connected": "`web/manifest.json`, `web/index.html`.",
                "layer": "Web icon asset.",
                "delete": m["delete"],
            }
        if plat == "android" and "mipmap" in parent and lower != "ic_launcher.png":
            density = parent.split("-")[-1] if "-" in parent else "default"
            return {
                "what": f"Android launcher icon PNG (mipmap-{density}) — home screen icon Counter.",
                "why": f"APK picks mipmap-{density} for sharp icon on {density} screens.",
                "contains": f"Raster PNG launcher icon.",
                "responsibilities": f"Home screen icon on {density} Android devices.",
                "when": "Blurry/wrong launcher icon on specific Android density.",
                "connected": "`AndroidManifest.xml` application icon.",
                "layer": "Android mipmap asset.",
                "delete": "Нет — missing density icon looks wrong on some phones.",
            }
        if "assets.xcassets" in p.lower() or "xcassets" in parent.lower():
            scale = name.replace("LaunchImage", "").replace("@2x", " 2x").replace("@3x", " 3x")
            return {
                "what": f"PNG `{name}` в xcassets — raster {scale} для {artifact}.",
                "why": f"Xcode упаковывает imageset PNG в {artifact} bundle.",
                "contains": f"Растровый PNG в `{parent}`.",
                "responsibilities": f"Launch/icon imagery на {plat} из asset catalog.",
                "when": f"Wrong/missing launch/icon image для `{name}`.",
                "connected": f"`{plat}/Runner.xcodeproj/`, Info.plist.",
                "layer": f"{plat} asset catalog PNG.",
                "delete": m["delete"],
            }

    if lower.endswith(".json") and plat == "web":
        return {
            "what": f"Web JSON config `{name}` — metadata для browser/PWA (manifest or flutter service config).",
            "why": f"Browser/Flutter web tool reads `{name}` when loading {artifact}.",
            "contains": "JSON keys for web/PWA integration.",
            "responsibilities": f"Configure web runtime behavior referenced by `{name}`.",
            "when": f"Web deploy issue involving `{name}`.",
            "connected": "`web/index.html`, Flutter web build output.",
            "layer": "Web config JSON.",
            "delete": m["delete"],
        }

    if lower == "counter.iss":
        return {
            "what": "Inno Setup script — рецепт сборки installer `CounterSetup.exe` для Windows.",
            "why": "Упаковывает Flutter Windows build + STT helper + icons в один setup wizard.",
            "contains": "File copy rules, shortcuts, optional autostart task.",
            "responsibilities": "Define installer steps and installed file layout on disk.",
            "when": "Installer missing files or wrong install path on Windows.",
            "connected": "`prepare_stt_payload.ps1`, GitHub Actions workflow.",
            "layer": "Windows installer config — не runtime Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".md") and plat == "installer":
        return {
            "what": f"Installer documentation `{name}` — human steps для Windows setup/STT packaging.",
            "why": "Owner/CI читают notes перед сборкой `CounterSetup.exe`.",
            "contains": "Markdown instructions for installer workflow.",
            "responsibilities": f"Document how to run installer pipeline involving `{name}`.",
            "when": f"Unclear installer step documented near `{name}`.",
            "connected": "`docs/DEPLOY.md`, `installer/windows/`.",
            "layer": "Installer docs — не runtime.",
            "delete": "Возможно — только если workflow полностью описан elsewhere.",
        }

    if lower.endswith(".gitignore"):
        return {
            "what": f"Git ignore для `{parent or plat}/` — не коммитить generated build artifacts платформы.",
            "why": f"{tool} пишет локальные outputs в `{plat}/`, которые не должны попадать в git.",
            "contains": "Ignore patterns для build cache, IDE metadata, local SDK paths.",
            "responsibilities": f"Keep `{plat}/` tree free of accidental generated commits.",
            "when": f"Случайно добавили build output `{plat}/` в git.",
            "connected": f"Root `.gitignore`, `{plat}/` tooling.",
            "layer": f"Git hygiene {plat} — не runtime.",
            "delete": "Нет — без ignore repo засорится build artifacts.",
        }

    if lower.endswith(".txt") and "cmake" not in lower:
        return {
            "what": f"Text resource `{name}` в `{parent}` — platform note или bundled text для {tool} build.",
            "why": f"Native {plat} build или packaging может читать `{name}` as resource/input.",
            "contains": f"Plain text content for `{name}`.",
            "responsibilities": f"Support file consumed by {tool} when building {artifact}.",
            "when": f"Build/packaging error references `{name}`.",
            "connected": f"`{parent}/`, {tool}.",
            "layer": f"{plat} text resource — не Dart.",
            "delete": m["delete"],
        }

    if lower == "contents.json" and "xcassets" in p.lower():
        asset_kind = "AppIcon" if "appicon" in p.lower() else "LaunchImage" if "launch" in p.lower() else "asset catalog"
        return {
            "what": f"JSON manifest `{name}` в xcassets ({asset_kind}) — описывает набор PNG для {artifact}.",
            "why": f"Xcode читает `contents.json`, чтобы собрать {asset_kind} в {artifact}.",
            "contains": f"Список image scales/files для `{parent}`.",
            "responsibilities": f"Связать PNG assets с {asset_kind} в Xcode catalog.",
            "when": f"Missing/wrong {asset_kind} после сборки {plat}.",
            "connected": f"`{plat}/Runner.xcodeproj/`, Info.plist.",
            "layer": f"{plat} asset catalog manifest.",
            "delete": m["delete"],
        }

    if lower.endswith(".manifest") and plat == "windows":
        return {
            "what": "Win32 application manifest runner `.exe` — DPI awareness и compatibility flags для Windows.",
            "why": "Windows loader читает manifest при старте `.exe` (Per-Monitor DPI, UAC behavior).",
            "contains": "XML assembly manifest, встраиваемый в Counter Windows `.exe`.",
            "responsibilities": "Метаданные DPI/compatibility для установленного desktop `.exe`.",
            "when": "Blurry UI на high-DPI Windows; manifest merge/link errors.",
            "connected": "`windows/runner/Runner.rc`, CMake runner target.",
            "layer": "Windows manifest — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".h") and "bridging" in lower:
        return {
            "what": f"Bridging header `{name}` — экспортирует C/ObjC symbols в Swift Runner {plat}.",
            "why": f"Swift glue в {artifact} видит C headers Flutter/plugins через этот bridge.",
            "contains": f"#import directives для `{parent}`.",
            "responsibilities": f"Связать Swift Runner с C/ObjC Flutter embedding на {plat}.",
            "when": f"Swift compile error: unknown C symbol из bridging header.",
            "connected": f"`{plat}/Runner/`, Flutter embedder.",
            "layer": f"{plat} Swift/ObjC bridge — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".h"):
        if "resource" in lower:
            return {
                "what": f"Заголовок C `{name}` — константы ID для Win32 `.rc` compiler.",
                "why": "Runner `.rc` и C++ sources подключают header для icon/version constants.",
                "contains": f"#define IDs для resources в `{parent}`.",
                "responsibilities": "Связать Win32 resources с C++ runner compile.",
                "when": "RC compile error: unknown resource id в `resource.h`.",
                "connected": "`windows/runner/Runner.rc`, `windows/runner/CMakeLists.txt`.",
                "layer": "Windows native header — не Dart.",
                "delete": m["delete"],
            }
        return {
            "what": f"Заголовок C/C++ `{name}` — объявления для native runner {plat} ({tool}).",
            "why": f"Компилятор {tool} подключает header при сборке {artifact}.",
            "contains": f"Объявления и guards для `{name}` в `{parent}`.",
            "responsibilities": f"Compile-time интерфейс native runner для {artifact}.",
            "when": f"Ошибка native compile ссылается на `{name}`.",
            "connected": f"`{parent}/`, `{plat}/flutter/`.",
            "layer": f"{plat} native header — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".plist") and plat in ("ios", "macos"):
        return {
            "what": f"Plist `{name}` — метаданные и конфиг {tool} для {artifact}.",
            "why": f"Xcode/{tool} читает plist при сборке или packaging {artifact}.",
            "contains": f"XML plist keys для `{parent}`.",
            "responsibilities": f"Конфигурация/IDE checks для {plat} build pipeline.",
            "when": f"Build/packaging error ссылается на `{name}`.",
            "connected": f"`{plat}/Runner.xcodeproj/`, Flutter embedder.",
            "layer": f"{plat} plist config — не Dart.",
            "delete": m["delete"],
        }

    if lower.endswith(".xcsettings"):
        return {
            "what": f"Xcode workspace settings `{name}` — IDE metadata для {plat} Runner workspace.",
            "why": f"Xcode хранит workspace checks/settings для reproducible {artifact} builds.",
            "contains": "Plist workspace settings (LastUpgradeVersion, IDE prefs).",
            "responsibilities": f"Workspace consistency для команды при сборке {artifact}.",
            "when": f"Xcode workspace warnings или IDE upgrade drift на {plat}.",
            "connected": f"`{plat}/Runner.xcworkspace/`, `{plat}/Runner.xcodeproj/`.",
            "layer": f"Xcode workspace metadata {plat}.",
            "delete": m["delete"],
        }

    return _concrete_fallback(p, name, m)


def _concrete_fallback(p: str, name: str, m: dict[str, str]) -> dict[str, str]:
    tool = m["tool"]
    artifact = m["artifact"]
    parent = m["parent"]
    plat = m["plat"]
    return {
        "what": f"Platform file `{name}` в `{parent}` — читает {tool} при сборке {artifact}.",
        "why": f"Без этого файла {tool} может не собрать или упаковать {artifact}.",
        "contains": f"Содержимое native/config слоя `{parent}` (смотреть файл при build errors).",
        "responsibilities": f"Участвует в {tool} pipeline для {artifact} — не Dart business logic.",
        "when": f"Build log {plat} ссылается на `{name}` или `{parent}`.",
        "connected": f"`{plat}/`, Flutter embedder, {tool}.",
        "layer": f"{plat} platform file — не Dart UI.",
        "delete": m["delete"],
    }


def platform_file_ru_field(
    path: str, name: str, field: str, en_val: str, en: dict[str, str]
) -> str | None:
    p = path.replace("\\", "/")
    guide = PLATFORM_PATH_GUIDES.get(p)
    if not guide:
        guide = _heuristic_guide(p, name)
    if not guide:
        return None
    if field == "delete":
        v = guide.get("delete") or en.get("delete", "")
        if v.startswith("No —") or v.startswith("Maybe —"):
            from structure_ru_helpers import delete_en_to_ru

            v = delete_en_to_ru(v)
    else:
        v = guide.get(field)
    if not v:
        return None
    v = sanitize_ru_prose(v)
    if has_banned_filler(v) or has_semi_russian_or_english_leak(v):
        return None
    if (
        cyrillic_count(v) >= 4
        or ("`" in v and len(v.strip()) >= 10)
        or len(v.strip()) >= 22
    ):
        return v
    return None


def platform_file_en_guide(path: str) -> dict[str, str] | None:
    """Reserved — EN blocks come from platform_file_description / platform_guide."""
    return None
