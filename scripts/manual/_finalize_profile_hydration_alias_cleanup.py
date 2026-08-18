from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

structure = ROOT / 'docs/APP_STRUCTURE.md'
doc = structure.read_text(encoding='utf-8')
lines = [
    line
    for line in doc.splitlines()
    if not line.startswith('| `app/shell/shared/profile_hydration_status_bar.dart` |')
    and not line.startswith('| `features/shared/profile_hydration_status_bar.dart` |')
]
feature_row = '| `features/profile/profile_hydration_status_bar.dart` | Profile-owned hydration error/retry status UI |'
if feature_row not in lines:
    raise RuntimeError('Profile hydration feature owner row missing')
structure.write_text('\n'.join(lines) + ('\n' if doc.endswith('\n') else ''), encoding='utf-8')

changelog = ROOT / 'CHANGELOG.md'
text = changelog.read_text(encoding='utf-8')
entry = '''## 2026-08-18 — Profile hydration alias cleanup [engineering]\n\n- `ShellTopStatusBars` now imports the Profile-owned hydration UI directly.\n- Removed obsolete shell/shared and features/shared compatibility re-exports for `ProfileHydrationStatusBar`.\n- No UI or hydration behavior changes.\n\n'''
if not text.startswith('## 2026-08-18 — Profile hydration alias cleanup [engineering]'):
    changelog.write_text(entry + text, encoding='utf-8')
