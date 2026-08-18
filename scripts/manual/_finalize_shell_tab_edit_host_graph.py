from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

app_path = ROOT / 'lib/app/shell/app_shell.dart'
app = app_path.read_text(encoding='utf-8')
old_order = '''        ShellTaskActions,\n        ShellTabHost,\n        ShellEditHosts,\n'''
new_order = '''        ShellTaskActions,\n        ShellEditHosts,\n        ShellTabHost,\n'''
if old_order not in app:
    raise RuntimeError('shell tab/edit mixin order anchor not found')
app_path.write_text(app.replace(old_order, new_order, 1), encoding='utf-8')

tab_path = ROOT / 'lib/app/shell/shared/shell_tab_host.dart'
tab = tab_path.read_text(encoding='utf-8')
old_decl = 'mixin ShellTabHost on ShellTaskActions {'
new_decl = 'mixin ShellTabHost on ShellTaskActions, ShellEditHosts {'
if old_decl not in tab:
    raise RuntimeError('ShellTabHost declaration not found')
tab = tab.replace(old_decl, new_decl, 1)
replacements = {
    '(this as ShellDashboardState).openNewTaskForPastDate': 'openNewTaskForPastDate',
    '(this as ShellDashboardState).showEditRecordSheetForTimeline': 'showEditRecordSheetForTimeline',
    '(this as ShellDashboardState).openEditDialog': 'openEditDialog',
}
for old, new in replacements.items():
    tab = tab.replace(old, new)
if '(this as ShellDashboardState)' in tab:
    raise RuntimeError('concrete ShellDashboardState cast remains in ShellTabHost')
tab_path.write_text(tab, encoding='utf-8')

structure_path = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure_path.read_text(encoding='utf-8')
lines = doc.splitlines()
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/shell_tab_host.dart` |'):
        lines[index] = '| `app/shell/shared/shell_tab_host.dart` | Timeline/Planning/Calendar/Lists tab composition; depends explicitly on `ShellEditHosts` instead of concrete dashboard casts *(part)* |'
        break
else:
    raise RuntimeError('shell_tab_host structure row not found')
structure_path.write_text('\n'.join(lines) + ('\n' if doc.endswith('\n') else ''), encoding='utf-8')

changelog_path = ROOT / 'CHANGELOG.md'
changelog = changelog_path.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Shell tab/edit-host dependency graph [engineering]\n\n- Declared `ShellTabHost`'s dependency on `ShellEditHosts` explicitly.\n- Reordered shell mixins so edit hosts are available before tab composition.\n- Removed concrete `(this as ShellDashboardState)` casts from tab callbacks; behavior is unchanged.\n\n'''
if not changelog.startswith('## 2026-08-18 — Shell tab/edit-host dependency graph [engineering]'):
    changelog_path.write_text(entry + changelog, encoding='utf-8')
