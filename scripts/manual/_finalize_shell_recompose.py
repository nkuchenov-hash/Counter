from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'Anchor not found in {path}: {old[:120]}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


# Remove task/action orchestration from shell_core now that the focused part exists.
shell_core = ROOT / 'lib/app/shell/shared/shell_core.dart'
core = shell_core.read_text(encoding='utf-8')
start_marker = '  Future<void> retryWriteNewTask(\n'
end_marker = '  void jumpToConflictDate(DateTime d) {\n'
start = core.find(start_marker)
end = core.find(end_marker)
if start == -1 or end == -1 or end <= start:
    raise RuntimeError('Cannot locate shell_core task-action block')
core = core[:start] + core[end:]
shell_core.write_text(core, encoding='utf-8')

app_structure = ROOT / 'docs/APP_STRUCTURE.md'
replace_once(
    app_structure,
    '| `app/shell/app_shell.dart` | `LifeOSDashboard`, `ShellDashboardBase`, scaffold orchestration; shell index 6 hosts `PathsPage` |',
    '| `app/shell/app_shell.dart` | `LifeOSDashboard` composition root + shared shell state contract; lifecycle and responsive chrome are delegated to focused shell parts |',
)
replace_once(
    app_structure,
    '| `app/shell/shared/shell_core.dart` | Core shell logic mixin (date header, tasks load, nav) *(part)* |',
    '| `app/shell/shared/shell_core.dart` | Core shell date/task-loading state, selected-day coordination and sync-failure UI *(part)* |\n'
    '| `app/shell/shared/shell_task_actions.dart` | Shell-owned task/record action orchestration: quick start/plan, record stop/delete, Planning→record start, source-plan suggestion UX/preferences *(part)* |',
)
replace_once(
    app_structure,
    '| `app/shell/shared/shell_tab_host.dart` | Tab `IndexedStack` builders *(part)* |',
    '| `app/shell/shared/shell_tab_host.dart` | Feature destination host builders *(part)* |\n'
    '| `app/shell/shared/shell_lifecycle.dart` | Dashboard startup/dispose wiring: tab host initialization, deferred bootstrap, subscriptions, midnight watcher, desktop voice detach *(part)* |\n'
    '| `app/shell/shared/shell_chrome.dart` | Responsive shell scaffold/chrome: destination pages, app bar, form-factor frame, FAB, bottom navigation, desktop voice shortcuts *(part)* |',
)

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Shell lifecycle/chrome/task-action recomposition [engineering]\n\n- Reduced `lib/app/shell/app_shell.dart` to the dashboard composition root and shared state contract.\n- Extracted dashboard initialization/disposal wiring to `shell_lifecycle.dart` and responsive scaffold/chrome to `shell_chrome.dart`.\n- Extracted quick start/plan, record stop/delete, Planning→record start, and source-plan suggestion orchestration from `shell_core.dart` into `shell_task_actions.dart`; `shell_core.dart` is again limited to selected-day/task-loading coordination and shared shell sync UI.\n- Moved Paths selected-index ownership fully into `shell_more_menu.dart` instead of a dashboard-state override.\n- No persistence schema, Planner semantics, Timeline semantics, or navigation behavior changed.\n\n'''
if not text.startswith('## 2026-08-18 — Shell lifecycle/chrome/task-action recomposition [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')

# Detailed guide: add focused shell-part entries without invoking the noisy global generator.
detailed = ROOT / 'docs/APP_STRUCTURE_DETAILED.md'
text = detailed.read_text(encoding='utf-8')
entries = [
    (
        'lib/app/shell/shared/shell_lifecycle.dart',
        'Shell lifecycle wiring for dashboard initialization, deferred startup work, subscriptions, midnight watch, and disposal.',
        'Shell lifecycle: инициализация dashboard, deferred startup, подписки, контроль смены дня и освобождение ресурсов.',
    ),
    (
        'lib/app/shell/shared/shell_chrome.dart',
        'Responsive shell chrome and destination composition: app bar, form-factor frames, FAB, bottom navigation, and desktop voice shortcuts.',
        'Responsive chrome shell и композиция экранов: app bar, form-factor frames, FAB, нижняя навигация и desktop voice shortcuts.',
    ),
    (
        'lib/app/shell/shared/shell_task_actions.dart',
        'Shell task/record action orchestration shared by Timeline, Planning, Calendar, and quick input surfaces.',
        'Shell-оркестрация действий задач и записей для Timeline, Planning, Calendar и quick input.',
    ),
]
for filename, purpose_en, purpose_ru in entries:
    marker = f'### `{filename}`'
    if marker in text:
        continue
    folder_marker = '## Folder: `lib/app/shell/shared/`'
    folder_start = text.find(folder_marker)
    if folder_start == -1:
        raise RuntimeError('Detailed guide shell/shared folder not found')
    next_folder = text.find('\n## Folder: `', folder_start + len(folder_marker))
    insert_at = len(text) if next_folder == -1 else next_folder
    section = f'''\n### `{filename}`\n\nEN:\n\n- **Human purpose:** {purpose_en}\n- **What this is:** Focused `part of app_shell.dart` module inside the Entry/shell layer.\n- **Why needed:** Keeps the dashboard composition root and core shell state readable without moving shell-owned behavior into feature or Brain layers.\n- **Responsibilities:** Preserve current shell behavior while isolating one coherent shell responsibility.\n- **Owner / layer:** Entry / app shell.\n- **Connected to:** `lib/app/shell/app_shell.dart` and sibling shell parts.\n\nRU:\n\n- **Зачем файл человеку:** {purpose_ru}\n- **Что это:** Focused `part of app_shell.dart` модуль внутри Entry/shell слоя.\n- **Зачем:** Сохраняет `app_shell.dart` и core shell state читаемыми и не переносит shell-owned поведение в feature или Brain слои.\n- **Обязанности:** Сохранять текущее поведение shell, изолируя одну связанную ответственность.\n- **Владелец / слой:** Entry / app shell.\n- **Связано с:** `lib/app/shell/app_shell.dart` и соседними shell parts.\n\n'''
    text = text[:insert_at] + section + text[insert_at:]
detailed.write_text(text, encoding='utf-8')
