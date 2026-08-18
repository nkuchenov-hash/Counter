from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "docs/APP_STRUCTURE_DETAILED.md"
text = path.read_text(encoding="utf-8")

OLD_DAILY = "lib/app/shell/shared/shell_daily_routine.dart"
NEW_DAILY = "lib/data/plans/daily_routine_service.dart"
OLD_GOV = "lib/app/shell/shared/shell_path_governance.dart"
NEW_GOV = "lib/data/paths/legacy/path_governance_service.dart"

if OLD_DAILY not in text:
    raise RuntimeError(f"Detailed structure does not contain {OLD_DAILY}")
if OLD_GOV not in text:
    raise RuntimeError(f"Detailed structure does not contain {OLD_GOV}")

# The move preserves behavior; update every evidence/connection reference to the
# new owner path first, then sharpen ownership wording in the two file sections.
text = text.replace(OLD_DAILY, NEW_DAILY).replace(OLD_GOV, NEW_GOV)


def rewrite_field(section: str, prefix: str, value: str) -> str:
    lines = section.splitlines()
    found = False
    for index, line in enumerate(lines):
        if line.startswith(prefix):
            lines[index] = prefix + " " + value
            found = True
            break
    if not found:
        raise RuntimeError(f"Missing field {prefix!r} in detailed structure section")
    return "\n".join(lines)


def rewrite_file_section(file_path: str, fields: dict[str, str]) -> None:
    global text
    marker = f"### `{file_path}`"
    start = text.find(marker)
    if start == -1:
        raise RuntimeError(f"Missing detailed file section for {file_path}")
    next_section = text.find("\n### `", start + len(marker))
    end = len(text) if next_section == -1 else next_section
    section = text[start:end]
    for prefix, value in fields.items():
        section = rewrite_field(section, prefix, value)
    text = text[:start] + section + text[end:]


rewrite_file_section(
    NEW_DAILY,
    {
        "- **Human purpose:**": "Brain-owned Planner baseline routine service. It creates only missing baseline recurring series and reconciles legacy duplicates while preserving user-edited recurrence.",
        "- **What this is:**": "Planner data service for baseline personal recurring routines.",
        "- **Why needed:**": "The startup Planner baseline must be idempotent and must not live in shell UI ownership.",
        "- **Responsibilities:**": "Create deterministic baseline routine series, preserve existing/user-edited recurrence, and retire legacy duplicate baseline rows.",
        "- **Owner / layer:**": "Brain / Plans data layer.",
        "- **Connected to:**": "`lib/data/paths/legacy/path_governance_service.dart`, `lib/data/database_service.dart`, Planner models.",
        "- **Зачем файл человеку:**": "Brain-сервис базовых повторяющихся дел Planner. Он создаёт только отсутствующие базовые серии, убирает legacy-дубли и сохраняет пользовательские изменения recurrence.",
        "- **Что это:**": "Data-сервис Planner для базовых личных повторяющихся дел.",
        "- **Зачем:**": "Стартовая базовая конфигурация Planner должна быть идемпотентной и не принадлежать UI shell.",
        "- **Обязанности:**": "Создавать deterministic baseline routine series, сохранять существующий пользовательский recurrence и убирать legacy-дубли базовых записей.",
        "- **Владелец / слой:**": "Brain / data-слой Plans.",
        "- **Связано с:**": "`lib/data/paths/legacy/path_governance_service.dart`, `lib/data/database_service.dart`, моделями Planner.",
    },
)

rewrite_file_section(
    NEW_GOV,
    {
        "- **Human purpose:**": "Transitional Brain compatibility service for marker-era Path audits and Path-action → Planner orchestration. First-class Paths UI does not invoke it on page open.",
        "- **What this is:**": "Legacy compatibility service inside the Path domain, isolated from shell navigation.",
        "- **Why needed:**": "Existing plan-backed `LIFEOS_PATH` data and Planner bootstrap behavior must remain safe until durable Path revisions and an explicit Planner bridge replace them.",
        "- **Responsibilities:**": "Audit legacy Path markers, reconcile Path actions with Planner tasks, preserve approval/baseline migrations, and expose the deferred Planner baseline startup entry point.",
        "- **Owner / layer:**": "Brain / Path compatibility layer (`data/paths/legacy`).",
        "- **Connected to:**": "`lib/data/paths/path_repository.dart`, `lib/data/plans/daily_routine_service.dart`, `lib/app/shell/app_shell.dart` deferred startup, Planner data APIs.",
        "- **Зачем файл человеку:**": "Переходный Brain-сервис для аудита marker-era Paths и совместимости Path-action → Planner. Первый экран Paths не запускает эту логику при открытии.",
        "- **Что это:**": "Legacy compatibility-сервис внутри Path domain, изолированный от shell-навигации.",
        "- **Зачем:**": "Существующие plan-backed данные `LIFEOS_PATH` и Planner bootstrap нужно безопасно поддерживать до появления durable Path revisions и явного Planner bridge.",
        "- **Обязанности:**": "Аудировать legacy Path markers, сверять Path actions с Planner tasks, сохранять approval/baseline migrations и предоставлять deferred startup entry point для Planner baseline.",
        "- **Владелец / слой:**": "Brain / compatibility-слой Paths (`data/paths/legacy`).",
        "- **Связано с:**": "`lib/data/paths/path_repository.dart`, `lib/data/plans/daily_routine_service.dart`, deferred startup в `lib/app/shell/app_shell.dart`, data API Planner.",
    },
)

legacy_folder_marker = "## Folder: `lib/data/paths/legacy/`"
if legacy_folder_marker not in text:
    parent_marker = "## Folder: `lib/data/paths/`"
    parent_start = text.find(parent_marker)
    if parent_start == -1:
        raise RuntimeError("Missing lib/data/paths folder section")
    parent_end = text.find("\n---\n", parent_start)
    if parent_end == -1:
        raise RuntimeError("Cannot locate end of lib/data/paths folder section")
    insert_at = parent_end + len("\n---\n")
    folder_section = """

## Folder: `lib/data/paths/legacy/`

EN:

- **What this folder is:** Transitional compatibility code for marker-era Path storage and Path → Planner orchestration.
- **Why it exists:** Existing plan-backed Paths must remain operational while first-class durable Path storage and the explicit Planner bridge are introduced safely.
- **What lives here:** `path_governance_service.dart`; no first-class Paths UI and no shell navigation code.
- **What part of the app it affects:** Legacy Path audits, compatibility migrations, and explicit/deferred Planner reconciliation only.
- **When to open it:** Maintaining legacy Path marker compatibility or retiring it during the durable Path migration.
- **Can it be deleted?** Not yet — only after durable Path revisions and the explicit Planner bridge replace marker-era behavior.
- **Main related paths:** `lib/data/paths/path_repository.dart`, `lib/data/plans/`, `lib/features/paths/`, `docs/ARCHITECTURE.md`.

RU:

- **Что это за папка:** Переходный compatibility-код для marker-era хранения Paths и оркестрации Path → Planner.
- **Зачем нужна:** Существующие plan-backed Paths должны работать до безопасного перехода на durable Path storage и явный Planner bridge.
- **Что здесь лежит:** `path_governance_service.dart`; здесь нет first-class UI Paths и shell-навигации.
- **На что влияет в приложении:** Только legacy-аудит Paths, compatibility migrations и явная/deferred синхронизация с Planner.
- **Когда открывать:** При поддержке legacy Path markers или при их удалении во время миграции на durable Paths.
- **Можно удалить?** Пока нет — только после замены marker-era поведения durable Path revisions и явным Planner bridge.
- **Связанные пути:** `lib/data/paths/path_repository.dart`, `lib/data/plans/`, `lib/features/paths/`, `docs/ARCHITECTURE.md`.

---
"""
    text = text[:insert_at] + folder_section + text[insert_at:]

nav_parent = "- [`lib/data/paths/`](#folder-libdatapaths)"
nav_legacy = "- [`lib/data/paths/legacy/`](#folder-libdatapathslegacy)"
if nav_legacy not in text:
    if nav_parent not in text:
        raise RuntimeError("Missing detailed structure nav entry for lib/data/paths")
    text = text.replace(nav_parent, nav_parent + "\n" + nav_legacy, 1)

note = "**Ownership parity patch (2026-08-18):** shell → Brain service moves below were updated without broad regeneration; the current generator has unrelated pre-existing RU/EN quality debt that remains a separate documentation-tooling task."
if note not in text:
    intro_anchor = "Concise architecture overview: [`APP_STRUCTURE.md`](APP_STRUCTURE.md)"
    if intro_anchor not in text:
        raise RuntimeError("Detailed structure intro anchor not found")
    text = text.replace(intro_anchor, note + "\n\n" + intro_anchor, 1)

for obsolete in (OLD_DAILY, OLD_GOV):
    if obsolete in text:
        raise RuntimeError(f"Obsolete ownership path remains in detailed structure: {obsolete}")
for required in (NEW_DAILY, NEW_GOV, legacy_folder_marker):
    if required not in text:
        raise RuntimeError(f"Required ownership path missing from detailed structure: {required}")

path.write_text(text, encoding="utf-8")
