from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
lines = doc.splitlines()
for index, line in enumerate(lines):
    if line.startswith('| `plans/plan_record_link_helpers.dart` |'):
        lines[index] = '| `plans/plan_record_link_helpers.dart` | Plan↔record linkage, source-plan matching, suggestion preferences/dismissal/auto-link policy, actual-time aggregation and plan-vs-fact day statistics *(part)* |'
        break
else:
    raise RuntimeError('plan_record_link_helpers structure row not found')
for index, line in enumerate(lines):
    if line.startswith('| `app/shell/shared/shell_task_actions.dart` |'):
        lines[index] = '| `app/shell/shared/shell_task_actions.dart` | Shell task/record action orchestration and source-plan suggestion prompt presentation; preference/matching/link policy lives in Brain *(part)* |'
        break
else:
    raise RuntimeError('shell_task_actions structure row not found')
structure.write_text('\n'.join(lines) + ('\n' if doc.endswith('\n') else ''), encoding='utf-8')

# SharedPreferences was only needed by the old shell-owned link policy. Remove
# the composition-root import only when no shell part still references it.
shell_root = ROOT / 'lib/app/shell'
uses_shared_prefs = any(
    'SharedPreferences' in path.read_text(encoding='utf-8')
    for path in shell_root.rglob('*.dart')
    if path.name != 'app_shell.dart'
)
if not uses_shared_prefs:
    app = ROOT / 'lib/app/shell/app_shell.dart'
    text = app.read_text(encoding='utf-8')
    text = text.replace(
        "import 'package:shared_preferences/shared_preferences.dart';\n",
        '',
        1,
    )
    app.write_text(text, encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Source-plan link policy ownership [engineering]\n\n- Moved source-plan suggestion enable/mode/dismissal preferences and auto-link threshold policy from shell into Brain `plan_record_link_helpers.dart`.\n- Brain now prepares/auto-applies source-plan suggestions and owns accepted/dismissed persistence.\n- `shell_task_actions.dart` only hosts the user-facing suggestion prompt and forwards accept/skip/disable actions.\n\n'''
if not text.startswith('## 2026-08-18 — Source-plan link policy ownership [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
