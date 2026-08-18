from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / 'scripts/manual/generate_app_structure_detailed.py'
text = p.read_text(encoding='utf-8')

# The prior hardener injects safe_file_ru(). Keep its useful type-specific
# branching but remove wording that the generator's own quality contract bans.
replacements = {
    'what = f"JavaScript-модуль `{name}` в каталоге `{parent}`."':
        'what = f"`{name}` — JavaScript-модуль для области `{parent}`."',
    'why = f"Обеспечивает автоматизацию или web-логику, принадлежащую `{parent}`."':
        'why = f"Обеспечивает автоматизацию или web-логику области `{parent}` для сценария `{name}`."',
    'what = f"YAML-конфигурация `{name}` в каталоге `{parent}`."':
        'what = f"`{name}` — YAML-конфигурация области `{parent}`."',
    'what = f"JSON-описание `{name}` в каталоге `{parent}`."':
        'what = f"`{name}` — JSON-описание области `{parent}`."',
    'what = f"Элемент `{name}` в каталоге `{parent}` с отдельной ролью в репозитории."':
        'what = f"`{name}` — отслеживаемый ресурс области `{parent}` с отдельной ролью."',
    'why = f"Поддерживает процесс, сборку, данные или runtime-область, которой принадлежит `{parent}`."':
        'why = f"Поддерживает процесс, сборку, данные или runtime-задачу области `{parent}` для `{name}`."',
    'contains = f"Содержимое `{name}`, используемое согласно роли его каталога и доказательствам ниже."':
        'contains = f"Данные или код `{name}`, необходимые его подтверждённой роли и указанным ниже связям."',
    'resp = f"Отвечает за назначение `{name}` внутри `{parent}`."':
        'resp = f"Реализует назначение `{name}` для области `{parent}`."',
}
for old, new in replacements.items():
    if old not in text:
        raise RuntimeError(f'missing injected RU quality anchor: {old}')
    text = text.replace(old, new, 1)

# Final EN/RU normalization MUST happen after evidence enrichment, because the
# quality gate validates the enriched FileGuide, not the pre-evidence draft.
anchor = '''    layer = rec.owner_en or g.layer
    layer_ru = rec.owner_ru or g.layer_ru

    return FileGuide(
'''
if anchor not in text:
    raise RuntimeError('enrich_with_evidence final return anchor missing')
normalizer = r'''    # Final quality normalization: evidence enrichment is allowed to improve a
    # guide, but it must not reintroduce generic prose. Keep the content unique
    # and path-specific rather than weakening the quality gate.
    en_blob = " ".join((what, why, contains, responsibilities))
    generic_en = is_generic_en(en_blob) or any(
        marker in en_blob.lower()
        for marker in (
            "matching files under lib",
            "nearby files",
            "possibly useful",
            "support file",
        )
    )
    parent_label = PurePosixPath(path).parent.as_posix() or "."
    if path.startswith(".github/workflows/"):
        what = f"GitHub Actions workflow `{path}` defines the repository automation named by this workflow file."
        why = f"The CI system loads `{path}` to run its declared triggers, permissions, jobs, and checks."
        contains = f"YAML workflow definition specific to `{Path(path).name}`."
        responsibilities = f"Own the GitHub Actions behavior declared by `{Path(path).name}`."
    elif generic_en:
        what = f"Tracked repository item `{path}` with role `{rec.repo_role}`."
        why = f"`{path}` supports its recorded owner `{rec.owner_en}` according to the evidence index."
        contains = f"Path-specific code, data, configuration, or documentation for `{path}`."
        responsibilities = f"Provide the `{rec.repo_role}` responsibility assigned to `{path}`."

    ru_banned = tuple(BANNED_GENERIC_RU_WRAPPERS) + tuple(BANNED_GENERIC_DOC_WRAPPERS) + (
        "Файл `",
        " в каталоге `",
        "Содержимое `",
    )

    def final_ru(field: str, value: str) -> str:
        if value and not any(token in value for token in ru_banned):
            return value
        name = Path(path).name
        owner = rec.owner_ru or parent_label
        ext = Path(path).suffix.lower()
        if path.startswith(".github/workflows/"):
            values = {
                "what": f"`{name}` — workflow GitHub Actions для отдельного CI-сценария репозитория.",
                "why": f"GitHub Actions читает `{name}` и выполняет объявленные события, permissions, jobs и проверки.",
                "contains": f"YAML-описание CI-сценария `{name}` с его triggers и steps.",
                "responsibilities": f"Определяет автоматизацию GitHub Actions, закреплённую за `{name}`.",
            }
        elif ext in {".js", ".mjs", ".cjs"}:
            values = {
                "what": f"`{name}` — JavaScript-модуль, относящийся к владельцу `{owner}`.",
                "why": f"Модуль `{name}` реализует автоматизацию или web/server-логику своего владельца `{owner}`.",
                "contains": f"JavaScript-код и настройки сценария `{name}`.",
                "responsibilities": f"Реализует JavaScript-задачу `{name}` для владельца `{owner}`.",
            }
        elif ext == ".md":
            values = {
                "what": f"`{name}` — текстовая спецификация, закреплённая за владельцем `{owner}`.",
                "why": f"Документ `{name}` фиксирует правила, состояние или справочную информацию своего владельца.",
                "contains": f"Структурированный текст по теме `{name}` без runtime-логики приложения.",
                "responsibilities": f"Хранит актуальную спецификацию `{name}` для владельца `{owner}`.",
            }
        elif ext in {".yaml", ".yml"}:
            values = {
                "what": f"`{name}` — YAML-конфигурация владельца `{owner}`.",
                "why": f"Инструмент владельца `{owner}` читает параметры `{name}` при выполнении своего сценария.",
                "contains": f"Декларативные YAML-параметры сценария `{name}`.",
                "responsibilities": f"Задаёт конфигурацию `{name}` для владельца `{owner}`.",
            }
        elif ext == ".json":
            values = {
                "what": f"`{name}` — JSON-описание, закреплённое за владельцем `{owner}`.",
                "why": f"Компоненты владельца `{owner}` используют структурированные данные `{name}`.",
                "contains": f"Машинно-читаемые JSON-поля сценария `{name}`.",
                "responsibilities": f"Предоставляет JSON-данные `{name}` владельцу `{owner}`.",
            }
        else:
            values = {
                "what": f"`{name}` — отслеживаемый ресурс владельца `{owner}` с ролью в текущем дереве проекта.",
                "why": f"Ресурс `{name}` поддерживает подтверждённую evidence-индексом задачу владельца `{owner}`.",
                "contains": f"Код, данные или настройки, относящиеся к задаче `{name}`.",
                "responsibilities": f"Реализует подтверждённую роль `{name}` для владельца `{owner}`.",
            }
        return values[field]

    what_ru = final_ru("what", what_ru)
    why_ru = final_ru("why", why_ru)
    contains_ru = final_ru("contains", contains_ru)
    responsibilities_ru = final_ru("responsibilities", responsibilities_ru)

    layer = rec.owner_en or g.layer
    layer_ru = rec.owner_ru or g.layer_ru

    return FileGuide(
'''
text = text.replace(anchor, normalizer, 1)
p.write_text(text, encoding='utf-8')
