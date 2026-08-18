from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
needle = '**`category_edit_draft.dart`**), **`notes_editor/`**'
replacement = '**`category_edit_draft.dart`**, **`planning_edit_result_actions.dart`**), **`notes_editor/`**'
if replacement not in doc:
    if needle not in doc:
        raise RuntimeError('Shared edit_sheet structure anchor not found')
    doc = doc.replace(needle, replacement, 1)
structure.write_text(doc, encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Planning edit result ownership [engineering]\n\n- `shell_edit_hosts.dart` now only hosts/routes the Planning sheet; persisted field edits remain owned by the editor autosave flow.\n- New-draft create/collision handling and persisted delete/rollback/undo moved to `features/shared/edit_sheet/planning_edit_result_actions.dart`.\n- Removed the Planning optimistic-delete sentinel and duplicated persistence orchestration from shell ownership.\n\n'''
if not text.startswith('## 2026-08-18 — Planning edit result ownership [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')

detailed = ROOT / 'docs/APP_STRUCTURE_DETAILED.md'
text = detailed.read_text(encoding='utf-8')
filename = 'lib/features/shared/edit_sheet/planning_edit_result_actions.dart'
marker = f'### `{filename}`'
if marker not in text:
    folder = '## Folder: `lib/features/shared/edit_sheet/`'
    start = text.find(folder)
    if start == -1:
        raise RuntimeError('Detailed edit_sheet folder not found')
    end = text.find('\n## Folder: `', start + len(folder))
    insert_at = len(text) if end == -1 else end
    section = f'''\n### `{filename}`\n\nEN:\n- **Human purpose:** Planning edit result orchestration for new-draft creation and persisted delete/rollback/undo.\n- **Owner / layer:** Feature UI / shared Planning edit-sheet layer.\n- **Connected to:** `planning_task_edit_sheet.dart`, `activity_detail_sheet.dart`, Planning data APIs, and the shell edit host.\n\nRU:\n- **Зачем файл человеку:** Оркестрация результатов Planning editor: создание нового draft и удаление сохранённого плана с rollback/undo.\n- **Владелец / слой:** Feature UI / shared Planning edit-sheet layer.\n- **Связано с:** `planning_task_edit_sheet.dart`, `activity_detail_sheet.dart`, data API Planning и shell edit host.\n\n'''
    text = text[:insert_at] + section + text[insert_at:]
detailed.write_text(text, encoding='utf-8')
