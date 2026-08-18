from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
needle = '**`planning_edit_result_actions.dart`**), **`notes_editor/`**'
replacement = '**`planning_edit_result_actions.dart`**, **`timeline_edit_result_actions.dart`**), **`notes_editor/`**'
if replacement not in doc:
    if needle not in doc:
        raise RuntimeError('Shared edit_sheet structure anchor not found')
    doc = doc.replace(needle, replacement, 1)
structure.write_text(doc, encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Timeline edit result ownership [engineering]\n\n- `shell_edit_hosts.dart` no longer performs Timeline record DELETE/STOP mutations directly.\n- Timeline delete/retry and stop follow-up actions now live in `features/shared/edit_sheet/timeline_edit_result_actions.dart`.\n- Shell remains the edit-sheet host/router; persistence behavior is unchanged.\n\n'''
if not text.startswith('## 2026-08-18 — Timeline edit result ownership [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')

detailed = ROOT / 'docs/APP_STRUCTURE_DETAILED.md'
text = detailed.read_text(encoding='utf-8')
filename = 'lib/features/shared/edit_sheet/timeline_edit_result_actions.dart'
marker = f'### `{filename}`'
if marker not in text:
    folder = '## Folder: `lib/features/shared/edit_sheet/`'
    start = text.find(folder)
    if start == -1:
        raise RuntimeError('Detailed edit_sheet folder not found')
    end = text.find('\n## Folder: `', start + len(folder))
    insert_at = len(text) if end == -1 else end
    section = f'''\n### `{filename}`\n\nEN:\n- **Human purpose:** Feature-owned Timeline edit follow-up actions for persisted record delete/retry and stop.\n- **Owner / layer:** Feature UI / shared Timeline edit-sheet layer.\n- **Connected to:** `timeline_record_edit_sheet.dart`, Timeline record APIs, and the shell edit host.\n\nRU:\n- **Зачем файл человеку:** Feature-owned действия Timeline editor для удаления/retry и остановки сохранённой записи.\n- **Владелец / слой:** Feature UI / shared Timeline edit-sheet layer.\n- **Связано с:** `timeline_record_edit_sheet.dart`, data API Timeline и shell edit host.\n\n'''
    text = text[:insert_at] + section + text[insert_at:]
detailed.write_text(text, encoding='utf-8')
