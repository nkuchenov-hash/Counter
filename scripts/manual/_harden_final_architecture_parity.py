from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Harden the one-shot documentation finalizer so section edits are bounded by
# headings instead of brittle table text.
finalizer = ROOT / 'scripts/manual/_finalize_architecture_doc_parity.py'
text = finalizer.read_text(encoding='utf-8')

drift_start = text.index('nav = replace_regex(\n    nav,\n    r"Verified 2026-06-10')
drift_end = text.index('\nnav = nav.replace(', drift_start)
drift_new = '''nav = replace_regex(
    nav,
    r"## Structure check .*?(?=## Local sync & offline-first)",
    "## Structure check (vs `docs/APP_STRUCTURE.md`)\\n\\n"
    "Verified 2026-08-18 after the Shell/Profile/Planning/Voice ownership pass and repo-wide documentation parity audit. "
    "**Current governing docs have no accepted structure drift.** Historical reports may describe earlier paths, but this navigation map points only at live canonical owners.\\n\\n---\\n\\n",
    label="agent navigation drift section",
    flags=re.S,
)'''
text = text[:drift_start] + drift_new + text[drift_end:]

old_perf = 'nav = replace_once(nav, old_perf, new_perf, label="agent navigation performance section")'
new_perf = '''nav = replace_regex(
    nav,
    r"## P0 / performance layer .*?(?=## Confirmed bugs)",
    new_perf + "\\n\\n---\\n\\n",
    label="agent navigation performance section",
    flags=re.S,
)'''
if old_perf not in text:
    raise RuntimeError('performance replacement call not found')
text = text.replace(old_perf, new_perf, 1)
text = text.replace(
    '"inside_ru": "Markdown-документы и связанные справочные файлы; конкретный состав описан ниже.",',
    '"inside_ru": "Текстовые спецификации и связанные справочные материалы; конкретный состав описан ниже.",',
)
finalizer.write_text(text, encoding='utf-8')

# Harden generated per-file RU descriptions. The existing translator may return
# formally Russian but deliberately banned generic wrappers; validate again at
# the final FileGuide boundary and replace only those weak fields.
generator = ROOT / 'scripts/manual/generate_app_structure_detailed.py'
g = generator.read_text(encoding='utf-8')
marker = '    return FileGuide(\n        what=g.what,\n'
if marker not in g:
    raise RuntimeError('finalize_file_guide return marker not found')
helper = r'''    def safe_file_ru(field: str, value: str) -> str:
        """Reject generic RU wrappers even when they contain enough Cyrillic."""
        banned = tuple(BANNED_GENERIC_RU_WRAPPERS) + tuple(BANNED_GENERIC_DOC_WRAPPERS) + (
            "Файл `",
            "Markdown-документ",
        )
        if value and not any(token in value for token in banned):
            return value
        pnorm = path.replace("\\", "/")
        name = Path(pnorm).name
        parent = PurePosixPath(pnorm).parent.as_posix() or "."
        ext = Path(pnorm).suffix.lower()
        if pnorm.startswith(".github/workflows/"):
            what = f"Автоматизация GitHub Actions `{name}` для CI и операций репозитория."
            why = f"GitHub Actions читает `{name}` и запускает описанные в нём события, проверки и служебные шаги."
            contains = f"YAML-триггеры, permissions и шаги CI, относящиеся к workflow `{name}`."
            resp = f"Управляет CI-сценарием `{name}` и его границами выполнения."
        elif ext == ".md":
            what = f"Текстовая спецификация `{name}` в разделе `{parent}`."
            why = f"Фиксирует правила, состояние или справочную информацию, относящуюся к `{parent}`."
            contains = f"Структурированный Markdown-текст по теме `{name}` без runtime-логики приложения."
            resp = f"Хранит актуальную документацию по назначению `{name}`."
        elif ext in {".js", ".mjs", ".cjs"}:
            what = f"JavaScript-модуль `{name}` в каталоге `{parent}`."
            why = f"Обеспечивает автоматизацию или web-логику, принадлежащую `{parent}`."
            contains = f"JavaScript-код и настройки, относящиеся к задаче `{name}`."
            resp = f"Реализует JavaScript-часть сценария `{name}` в своём каталоге."
        elif ext in {".yml", ".yaml"}:
            what = f"YAML-конфигурация `{name}` в каталоге `{parent}`."
            why = f"Задаёт декларативные настройки процесса или инструмента, которому принадлежит `{parent}`."
            contains = f"Параметры YAML, необходимые сценарию `{name}`."
            resp = f"Хранит конфигурацию `{name}` для своего владельца."
        elif ext == ".json":
            what = f"JSON-описание `{name}` в каталоге `{parent}`."
            why = f"Передаёт структурированные данные или настройки компонентам, связанным с `{parent}`."
            contains = f"Структурированные JSON-поля для сценария `{name}`."
            resp = f"Хранит машинно-читаемые данные `{name}` для своего владельца."
        else:
            what = f"Элемент `{name}` в каталоге `{parent}` с отдельной ролью в репозитории."
            why = f"Поддерживает процесс, сборку, данные или runtime-область, которой принадлежит `{parent}`."
            contains = f"Содержимое `{name}`, используемое согласно роли его каталога и доказательствам ниже."
            resp = f"Отвечает за назначение `{name}` внутри `{parent}`."
        return {
            "what": what,
            "why": why,
            "contains": contains,
            "responsibilities": resp,
        }.get(field, value)

'''
g = g.replace(marker, helper + marker, 1)
for old, new in (
    ('what_ru=pick("what_ru"),', 'what_ru=safe_file_ru("what", pick("what_ru")),'),
    ('why_ru=pick("why_ru"),', 'why_ru=safe_file_ru("why", pick("why_ru")),'),
    ('contains_ru=pick("contains_ru"),', 'contains_ru=safe_file_ru("contains", pick("contains_ru")),'),
    (
        'responsibilities_ru=pick("responsibilities_ru"),',
        'responsibilities_ru=safe_file_ru("responsibilities", pick("responsibilities_ru")),',
    ),
):
    if old not in g:
        raise RuntimeError(f'generator field anchor missing: {old}')
    g = g.replace(old, new, 1)
generator.write_text(g, encoding='utf-8')
