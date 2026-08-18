from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "docs/APP_STRUCTURE_DETAILED.md"
text = path.read_text(encoding="utf-8")

OLD_DAILY = "lib/app/shell/shared/shell_daily_routine.dart"
NEW_DAILY = "lib/data/plans/daily_routine_service.dart"
OLD_GOV = "lib/app/shell/shared/shell_path_governance.dart"
NEW_GOV = "lib/data/paths/legacy/path_governance_service.dart"

# Old generated docs can either contain the former shell paths or omit these
# files altogether. Both states are valid inputs; this patch only enforces the
# new final ownership state.
text = text.replace(OLD_DAILY, NEW_DAILY).replace(OLD_GOV, NEW_GOV)


def upsert_file_section(file_path: str, section: str) -> None:
    global text
    marker = f"### `{file_path}`"
    start = text.find(marker)
    if start != -1:
        next_section = text.find("\n### `", start + len(marker))
        end = len(text) if next_section == -1 else next_section
        text = text[:start] + section.rstrip() + "\n" + text[end:]
        return

    # APP_STRUCTURE_DETAILED is a generated sequence of file sections. If a
    # stale snapshot omitted this file, appending one complete section is safer
    # than inventing partial generator metadata.
    if not text.endswith("\n"):
        text += "\n"
    text += "\n" + section.rstrip() + "\n"


DAILY_SECTION = f"""### `{NEW_DAILY}`

EN:

- **Human purpose:** Brain-owned Planner baseline routine service. It creates only missing baseline recurring series and reconciles legacy duplicates while preserving user-edited recurrence.
- **What this is:** Planner data service for baseline personal recurring routines.
- **Why needed:** The startup Planner baseline must be idempotent and must not live in shell UI ownership.
- **Contents:** Baseline routine definitions, deterministic IDs, recurrence preservation, and legacy duplicate reconciliation.
- **Repository role:** production_runtime
- **Evidence of use:** Imported by `{NEW_GOV}`; the deferred Planner baseline entry point reaches this service through the Path compatibility layer.
- **Necessity status:** PROVEN_REQUIRED
- **Deletion consequence:** Deferred baseline reconciliation would lose its implementation and existing routine compatibility would regress.
- **Confidence:** HIGH
- **Owner / layer:** Brain / Plans data layer.
- **Responsibilities:** Create deterministic baseline routine series, preserve existing/user-edited recurrence, and retire legacy duplicate baseline rows.
- **When to open:** Baseline recurring Planner rows are missing, duplicated, or recurrence preservation changes.
- **Can it be deleted?** No while baseline Planner bootstrap remains part of product startup compatibility.
- **Connected to:** `{NEW_GOV}`, `lib/data/database_service.dart`, Planner models.

RU:

- **Зачем файл человеку:** Brain-сервис базовых повторяющихся дел Planner. Он создаёт только отсутствующие базовые серии, убирает legacy-дубли и сохраняет пользовательские изменения recurrence.
- **Что это:** Data-сервис Planner для базовых личных повторяющихся дел.
- **Зачем:** Стартовая базовая конфигурация Planner должна быть идемпотентной и не принадлежать UI shell.
- **Содержимое:** Описания базовых routine, deterministic ID, сохранение recurrence и сверка legacy-дублей.
- **Роль в репозитории:** production_runtime
- **Доказательства использования:** Импортируется `{NEW_GOV}`; deferred Planner baseline вызывает его через compatibility-слой Paths.
- **Статус необходимости:** PROVEN_REQUIRED
- **Что будет, если удалить:** Deferred baseline reconciliation потеряет реализацию, а совместимость существующих повторяющихся дел нарушится.
- **Уверенность:** HIGH
- **Владелец / слой:** Brain / data-слой Plans.
- **Обязанности:** Создавать deterministic baseline routine series, сохранять существующий пользовательский recurrence и убирать legacy-дубли базовых записей.
- **Когда открывать:** Когда базовые повторяющиеся планы отсутствуют, дублируются или меняются правила сохранения recurrence.
- **Можно удалить?** Нет, пока baseline bootstrap Planner остаётся частью переходной логики запуска.
- **Связано с:** `{NEW_GOV}`, `lib/data/database_service.dart`, моделями Planner.
"""

GOV_SECTION = f"""### `{NEW_GOV}`

EN:

- **Human purpose:** Transitional Brain compatibility service for marker-era Path audits and Path-action → Planner orchestration. First-class Paths UI does not invoke it on page open.
- **What this is:** Legacy compatibility service inside the Path domain, isolated from shell navigation.
- **Why needed:** Existing plan-backed `LIFEOS_PATH` data and Planner bootstrap behavior must remain safe until durable Path revisions and an explicit Planner bridge replace them.
- **Contents:** Legacy Path marker audits, migration/reconciliation helpers, Path-action → Planner orchestration, and deferred Planner baseline startup entry point.
- **Repository role:** production_runtime
- **Evidence of use:** Imported by `lib/app/shell/app_shell.dart`; `ensurePlannerBaselineV7()` is invoked from deferred startup, not from opening the Paths destination.
- **Necessity status:** PROVEN_REQUIRED
- **Deletion consequence:** Current marker-era Path compatibility and deferred Planner baseline reconciliation would break before their replacement exists.
- **Confidence:** HIGH
- **Owner / layer:** Brain / Path compatibility layer (`data/paths/legacy`).
- **Responsibilities:** Audit legacy Path markers, reconcile Path actions with Planner tasks, preserve approval/baseline migrations, and expose the deferred Planner baseline startup entry point.
- **When to open:** Maintaining legacy Path marker compatibility or replacing it with durable Path revisions and the explicit Planner bridge.
- **Can it be deleted?** Not yet — remove only after durable Path revisions and the explicit Planner bridge replace marker-era behavior.
- **Connected to:** `lib/data/paths/path_repository.dart`, `{NEW_DAILY}`, `lib/app/shell/app_shell.dart` deferred startup, Planner data APIs.

RU:

- **Зачем файл человеку:** Переходный Brain-сервис для аудита marker-era Paths и совместимости Path-action → Planner. Первый экран Paths не запускает эту логику при открытии.
- **Что это:** Legacy compatibility-сервис внутри Path domain, изолированный от shell-навигации.
- **Зачем:** Существующие plan-backed данные `LIFEOS_PATH` и Planner bootstrap нужно безопасно поддерживать до появления durable Path revisions и явного Planner bridge.
- **Содержимое:** Аудит legacy Path markers, migration/reconciliation helpers, оркестрация Path-action → Planner и deferred startup entry point для Planner baseline.
- **Роль в репозитории:** production_runtime
- **Доказательства использования:** Импортируется `lib/app/shell/app_shell.dart`; `ensurePlannerBaselineV7()` вызывается из deferred startup, а не при открытии Paths.
- **Статус необходимости:** PROVEN_REQUIRED
- **Что будет, если удалить:** Текущая совместимость marker-era Paths и deferred Planner baseline сломаются до появления их замены.
- **Уверенность:** HIGH
- **Владелец / слой:** Brain / compatibility-слой Paths (`data/paths/legacy`).
- **Обязанности:** Аудировать legacy Path markers, сверять Path actions с Planner tasks, сохранять approval/baseline migrations и предоставлять deferred startup entry point для Planner baseline.
- **Когда открывать:** При поддержке legacy Path markers или их замене durable Path revisions и явным Planner bridge.
- **Можно удалить?** Пока нет — только после полной замены marker-era поведения durable Path revisions и явным Planner bridge.
- **Связано с:** `lib/data/paths/path_repository.dart`, `{NEW_DAILY}`, deferred startup в `lib/app/shell/app_shell.dart`, data API Planner.
"""

upsert_file_section(NEW_DAILY, DAILY_SECTION)
upsert_file_section(NEW_GOV, GOV_SECTION)

legacy_folder_marker = "## Folder: `lib/data/paths/legacy/`"
if legacy_folder_marker not in text:
    folder_section = """## Folder: `lib/data/paths/legacy/`

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
    parent_marker = "## Folder: `lib/data/paths/`"
    parent_start = text.find(parent_marker)
    if parent_start != -1:
        parent_end = text.find("\n---\n", parent_start)
        insert_at = parent_end + len("\n---\n") if parent_end != -1 else parent_start
        text = text[:insert_at] + "\n\n" + folder_section + text[insert_at:]
    else:
        text += "\n\n" + folder_section

nav_parent = "- [`lib/data/paths/`](#folder-libdatapaths)"
nav_legacy = "- [`lib/data/paths/legacy/`](#folder-libdatapathslegacy)"
if nav_legacy not in text and nav_parent in text:
    text = text.replace(nav_parent, nav_parent + "\n" + nav_legacy, 1)

note = "**Ownership parity patch (2026-08-18):** shell → Brain service moves below were updated without broad regeneration; the current generator has unrelated pre-existing RU/EN quality debt that remains a separate documentation-tooling task."
if note not in text:
    intro_anchor = "Concise architecture overview: [`APP_STRUCTURE.md`](APP_STRUCTURE.md)"
    if intro_anchor in text:
        text = text.replace(intro_anchor, note + "\n\n" + intro_anchor, 1)
    else:
        text = note + "\n\n" + text

for obsolete in (OLD_DAILY, OLD_GOV):
    if obsolete in text:
        raise RuntimeError(f"Obsolete ownership path remains in detailed structure: {obsolete}")
for required in (NEW_DAILY, NEW_GOV, legacy_folder_marker):
    if required not in text:
        raise RuntimeError(f"Required ownership path missing from detailed structure: {required}")

path.write_text(text, encoding="utf-8")
